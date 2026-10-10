------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - MENUS
--
-- Drop-downs and right-click menus. A menu is described the same way in
-- every look, by a build function that adds its entries:
--   build(m)  m:Button(text, fn)              runs fn, closes
--             m:Radio(text, isOn, fn)          one of a set; runs fn, closes
--             m:Check(text, isOn, fn)          a tick; runs fn, stays open
--             m:Divider()   m:Title(text)
-- Blizzard: Blizzard's menus (MenuUtil, the Menu API). Dark, or a client
-- without the Menu API: our menu list (PSS_Menu), built on first use: a
-- dark list with a faint edge, the picked or ticked entries marked in the
-- accent, scrolled by the mouse wheel past its height cap. A drop-down's
-- list has the port's 26 px items and is at most 200 tall; a right-click
-- menu is compact (20 px items, a slim title and divider, as wide as its
-- longest entry) and at most 400 tall, where Blizzard's menu scrolls.
--   ns.NewDropdown(parent, w, build, cap)   dd:SetLabel(text)
--                                      (cap: our list's height before it scrolls, default 200)
--                                      (always opens downward; our list is
--                                      as wide as its longest entry)
--   ns.ContextMenu(owner, build)       at the cursor
--   build(m): m:Title m:Button m:Radio m:Check m:Divider m:Sub(text, build)
--   ns.RowMenu(owner, entries, run)    a row's right-click menu from the
--                                      entries Libraries describes
--                                      (PSS_RowMenus.lua); run(act, arg)
------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local DARK = ns.DARK
local ITEM_H, PAD = 26, 1
local MENU_FILL = { 0.103, 0.095, 0.088, 0.98 }
local MENU_EDGE = { 1, 1, 1, 0.20 }
local floor, max, min = math.floor, math.max, math.min

------------------------------------------------------------------------
-- The entries of a menu: build(m) fills a plain list we can draw or hand
-- to Blizzard's menu.
------------------------------------------------------------------------
local Entries = {}
Entries.__index = Entries
local Collect

function Entries:Button(text, fn) self[#self + 1] = { kind = "button", text = text, fn = fn } end
function Entries:Radio(text, isOn, fn) self[#self + 1] = { kind = "radio", text = text, on = isOn, fn = fn } end
function Entries:Check(text, isOn, fn) self[#self + 1] = { kind = "check", text = text, on = isOn, fn = fn } end
function Entries:Divider() self[#self + 1] = { kind = "divider" } end
function Entries:Title(text) self[#self + 1] = { kind = "title", text = text } end
-- a submenu: build(sm) fills its entries (Blizzard's menu opens it beside the
-- entry; our list opens a side panel beside the row on hover or click, one level)
-- tick = { on, fn }: a tick box next to the entry (its own click toggles it,
-- fn(); anywhere else opens the submenu)
function Entries:Sub(text, build, tick) self[#self + 1] = { kind = "sub", text = text, children = Collect(build), tick = tick } end

function Collect(build)
	local list = setmetatable({}, Entries)
	build(list)
	return list
end

-- isOn may be a value or a function (read when drawn)
local function IsOn(e)
	if type(e.on) == "function" then return e.on() and true or false end
	return e.on and true or false
end

-- Blizzard's menu from the same entries
local FillBlizzard
function FillBlizzard(root, list)
	for _, e in ipairs(list) do
		if e.kind == "button" then
			root:CreateButton(e.text, function() if e.fn then e.fn() end end)
		elseif e.kind == "radio" then
			root:CreateRadio(e.text, function() return IsOn(e) end, function() if e.fn then e.fn() end end)
		elseif e.kind == "check" then
			root:CreateCheckbox(e.text, function() return IsOn(e) end, function()
				if e.fn then e.fn() end
				-- a tick keeps the menu open
				return MenuResponse and MenuResponse.Refresh
			end)
		elseif e.kind == "sub" then
			if e.tick then
				local t = e.tick
				FillBlizzard(root:CreateCheckbox(e.text, function() return IsOn(t) end, function()
					if t.fn then t.fn() end
					return MenuResponse and MenuResponse.Refresh
				end), e.children)
			else
				FillBlizzard(root:CreateButton(e.text), e.children)
			end
		elseif e.kind == "divider" and root.CreateDivider then
			root:CreateDivider()
		elseif e.kind == "title" and root.CreateTitle then
			root:CreateTitle(e.text)
		end
	end
	if #list > 20 and root.SetScrollMode then root:SetScrollMode(400) end
end

------------------------------------------------------------------------
-- Our menu list: panel 1 (PSS_Menu), and panel 2 (PSS_MenuSide), the side
-- menu of a sub entry, built on its first hover. Both are drawn by the same
-- code from a panel table { frame, slots, shown, offset, size }.
------------------------------------------------------------------------
local menu, catcher
local FitWidth, minWidth
local owner = nil
local main = { offset = 0 }
local side

-- Two sizes: a drop-down's list (the port's 26 px items) and a compact
-- right-click menu. Titles and dividers take less room than items; cap is
-- the height past which the menu scrolls.
local SIZES = {
	list = { item = ITEM_H, title = 22, divider = 9, font = 13, inset = 10, cap = 200 },
	compact = { item = 20, title = 18, divider = 7, font = 12, inset = 8, cap = 400 },
}
main.size = SIZES.list

local function HeightOf(p, e)
	if e.kind == "title" then return p.size.title end
	if e.kind == "divider" then return p.size.divider end
	return p.size.item
end

-- do the entries from first on fit under the panel's height cap?
local function FitsFrom(p, first)
	local h = 0
	for i = first, #p.shown do
		h = h + HeightOf(p, p.shown[i])
		if h > p.size.cap - PAD * 2 then return false end
	end
	return true
end

local function Close()
	if menu then menu:Hide() end
end

local Draw, OpenSide

-- the side panel goes; the sub row that opened it loses its mark
local function HideSide()
	main.open = nil
	if side and side.frame:IsShown() then
		side.frame:Hide()
		if menu and menu:IsShown() then Draw(main) end
	end
end

local function MakeSlot(p, i)
	local sl = CreateFrame("Button", nil, p.frame)
	sl:SetPoint("RIGHT", p.frame, "RIGHT", -PAD, 0)
	sl.picked = sl:CreateTexture(nil, "BACKGROUND")
	sl.picked:SetAllPoints()
	sl.picked:SetColorTexture(1, 1, 1, 0.04)
	sl.hl = sl:CreateTexture(nil, "HIGHLIGHT")
	sl.hl:SetAllPoints()
	sl.hl:SetColorTexture(1, 1, 1, 0.08)
	sl.box = sl:CreateTexture(nil, "ARTWORK")
	sl.box:SetSize(12, 12)
	sl.box:SetPoint("LEFT", sl, "LEFT", 8, 0)
	sl.box:SetColorTexture(1, 1, 1, 0.12)
	sl.mark = sl:CreateTexture(nil, "OVERLAY")
	sl.mark:SetSize(8, 8)
	sl.mark:SetPoint("CENTER", sl.box, "CENTER")
	sl.text = ns.NewText(sl, 13)
	sl.text:SetJustifyH("LEFT")
	sl.text:SetWordWrap(false)
	sl.line = sl:CreateTexture(nil, "ARTWORK")
	ns.NoSnap(sl.line)
	sl.line:SetPoint("LEFT", sl, "LEFT", 8, 0)
	sl.line:SetPoint("RIGHT", sl, "RIGHT", -8, 0)
	sl.line:SetColorTexture(1, 1, 1, 0.10)
	sl:SetScript("OnEnter", function(self)
		self.text:SetAlpha(1)
		if p ~= main then return end
		local e = self.entry
		if e and e.kind == "sub" then OpenSide(self, e) else HideSide() end
	end)
	sl:SetScript("OnLeave", function(self)
		local e = self.entry
		self.text:SetAlpha(e and e.kind == "title" and 0.41 or 0.53)
	end)
	sl:SetScript("OnClick", function(self)
		local e = self.entry
		if not e or e.kind == "title" or e.kind == "divider" then return end
		if e.kind == "sub" and e.tick then
			-- the tick box is the left edge of the row; a click there toggles
			local x = GetCursorPosition() / self:GetEffectiveScale()
			if x - (self:GetLeft() or 0) < 24 then
				if e.tick.fn then e.tick.fn() end
				ns.DrawMenu()
				return
			end
		end
		if e.kind == "sub" then
			-- a click opens the side panel too (keyboard, touch)
			OpenSide(self, e)
			return
		end
		if e.fn then e.fn() end
		if e.kind == "check" or e.keep then ns.DrawMenu() else Close() end
	end)
	p.slots[i] = sl
	return sl
end

-- Lay the entries from offset down until the height cap; returns how many.
function Draw(p)
	local shown, slots, frame, size = p.shown, p.slots, p.frame, p.size
	local marks = false
	for _, e in ipairs(shown) do
		if e.kind == "radio" or e.kind == "check" or (e.kind == "sub" and e.tick) then marks = true break end
	end
	local y, n = PAD, 0
	for i = p.offset + 1, #shown do
		local e = shown[i]
		local h = HeightOf(p, e)
		if y + h > size.cap - PAD then break end
		n = n + 1
		local sl = slots[n] or MakeSlot(p, n)
		sl.entry = e
		sl:SetHeight(h)
		sl:ClearAllPoints()
		sl:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
		sl:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
		sl:Show()
		local title, divider = e.kind == "title", e.kind == "divider"
		sl.text:SetFontObject(ns.Font(title and size.font - 1 or size.font))
		sl.text:SetText(divider and "" or (e.kind == "sub" and (e.text or "") .. " >" or e.text) or "")
		sl.text:ClearAllPoints()
		sl.text:SetPoint("LEFT", sl, "LEFT", marks and 24 or size.inset, 0)
		sl.text:SetPoint("RIGHT", sl, "RIGHT", -8, 0)
		sl.text:SetTextColor(1, 1, 1)
		sl.text:SetAlpha(title and 0.41 or 0.53)
		sl.line:SetShown(divider)
		if divider then sl.line:SetHeight(ns.OnePixel(sl)) end
		local on = ((e.kind == "radio" or e.kind == "check") and IsOn(e) or (e.kind == "sub" and e.tick and IsOn(e.tick))) and true or false
		sl.mark:SetShown(on)
		sl.mark:SetColorTexture(ns.Accent())
		sl.box:SetShown(e.kind == "check" or (e.kind == "sub" and e.tick ~= nil))
		sl.picked:SetShown((on and e.kind == "radio" or p.open == e) and true or false)
		-- titles and dividers still hear the pointer (it closes a side panel)
		sl.hl:SetShown(not (title or divider))
		sl:EnableMouse(true)
		y = y + h
	end
	for i = n + 1, #slots do
		slots[i].entry = nil
		slots[i]:Hide()
	end
	frame:SetHeight(y + PAD)
	-- a list longer than the panel: a thin thumb on the right
	if n < #shown then
		local h = max(20, (frame:GetHeight() - 8) * n / #shown)
		local room = #shown - n
		frame.thumb:SetHeight(h)
		frame.thumb:ClearAllPoints()
		frame.thumb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -4 - (frame:GetHeight() - 8 - h) * min(1, p.offset / room))
		frame.thumb:Show()
	else
		frame.thumb:Hide()
	end
	return n
end
ns.DrawMenu = function()
	if menu and menu:IsShown() then
		Draw(main)
		if side and side.frame:IsShown() then Draw(side) end
	end
end

local function MakePanel(p, name, level)
	local f = CreateFrame("Frame", name, UIParent)
	p.frame, p.slots = f, {}
	f.slots = p.slots
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(level)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:Hide()
	ns.Fill(f, MENU_FILL, -6)
	ns.PixelBorder(f, MENU_EDGE)
	f.thumb = f:CreateTexture(nil, "OVERLAY")
	f.thumb:SetWidth(4)
	f.thumb:SetColorTexture(1, 1, 1, 0.27)
	f:SetScript("OnMouseWheel", function(_, delta)
		-- down only while the rest does not fit yet; up to the first entry
		if delta < 0 and not FitsFrom(p, p.offset + 1) then
			p.offset = p.offset + 1
		elseif delta > 0 and p.offset > 0 then
			p.offset = p.offset - 1
		end
		Draw(p)
	end)
	return f
end

local function BuildMenu()
	menu = MakePanel(main, "PSS_Menu", 200)
	-- a click anywhere else closes the menu (a full-screen catcher under it)
	catcher = CreateFrame("Button", nil, UIParent)
	catcher:SetAllPoints(UIParent)
	catcher:SetFrameStrata("FULLSCREEN_DIALOG")
	catcher:SetFrameLevel(199)
	catcher:RegisterForClicks("AnyUp")
	catcher:SetScript("OnClick", Close)
	catcher:Hide()
	menu:SetScript("OnShow", function() catcher:Show() end)
	menu:SetScript("OnHide", function()
		catcher:Hide()
		owner = nil
		HideSide()
	end)
	ns.EscapeCloses(menu, "PSS_Menu")	-- after its OnHide (SetScript drops hooks)
	-- measures every entry for a right-click menu's width, shown or not
	menu.measure = ns.NewText(menu, 13)
	menu.measure:SetPoint("TOPLEFT")
	menu.measure:SetAlpha(0)
end

-- the side menu of a sub entry, beside its row (one level; a sub entry
-- inside it opens nothing)
function OpenSide(slot, e)
	if main.open == e and side and side.frame:IsShown() then return end
	if not side then
		side = { offset = 0 }
		MakePanel(side, "PSS_MenuSide", 201)
	end
	side.shown, side.offset, side.size = e.children, 0, main.size
	FitWidth(e.children, 60, side)
	local f = side.frame
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", slot, "TOPRIGHT", 2, 0)
	if (slot:GetRight() or 0) + 2 + f:GetWidth() > (UIParent:GetRight() or UIParent:GetWidth()) then
		f:ClearAllPoints()
		f:SetPoint("TOPRIGHT", slot, "TOPLEFT", -2, 0)
	end
	main.open = e
	Draw(side)
	f:Show()
	f:Raise()
	Draw(main)
end

-- Show our list for the entries; place(frame) anchors it.
local function OpenOurs(list, width, place, by, compact, cap)
	if not menu then BuildMenu() end
	if menu:IsShown() then Close() end
	main.shown, main.offset, owner = list, 0, by
	local size = compact and SIZES.compact or SIZES.list
	if cap then size = setmetatable({ cap = cap }, { __index = size }) end
	main.size = size
	menu:SetWidth(width)
	menu:ClearAllPoints()
	place(menu)
	Draw(main)
	menu:Show()
	menu:Raise()
end

-- the panel as wide as its longest entry (every entry, also those below the
-- height cap) and no narrower than minW; p is panel 1 unless given
function FitWidth(list, minW, p)
	p = p or main
	local widest, fs = 0, menu.measure
	for _, e in ipairs(list) do
		if e.kind ~= "divider" then
			fs:SetFontObject(ns.Font(e.kind == "title" and p.size.font - 1 or p.size.font))
			fs:SetText(e.text or "")
			widest = max(widest, fs:GetStringWidth())
		end
	end
	if p == main then minWidth = minW end
	p.frame:SetWidth(max(minW, widest + 28))
end

------------------------------------------------------------------------
-- Drop-down: a Blizzard DropdownButton and our Dark button in the same
-- place; the look shows one. dd:SetLabel(text) sets what both show.
------------------------------------------------------------------------
local function Chevron(parent)
	-- a small down chevron from two lines (no art)
	local a = parent:CreateLine(nil, "OVERLAY")
	local b = parent:CreateLine(nil, "OVERLAY")
	for _, l in ipairs({ a, b }) do
		l:SetThickness(1.5)
		l:SetColorTexture(1, 1, 1, 0.7)
	end
	a:SetStartPoint("RIGHT", parent, -14, 2)
	a:SetEndPoint("RIGHT", parent, -10, -2)
	b:SetStartPoint("RIGHT", parent, -10, -2)
	b:SetEndPoint("RIGHT", parent, -6, 2)
	return { a, b }
end

function ns.NewDropdown(parent, w, build, cap)
	local dd = CreateFrame("Frame", nil, parent)
	dd:SetSize(w, 24)
	local ok, blizz = pcall(CreateFrame, "DropdownButton", nil, dd, "WowStyle1DropdownTemplate")
	if ok and blizz and blizz.SetupMenu then
		blizz:SetAllPoints(dd)
		blizz:SetupMenu(function(_, root) FillBlizzard(root, Collect(build)) end)
	else
		blizz = nil
	end
	local dark = CreateFrame("Button", nil, dd)
	dark:SetAllPoints(dd)
	ns.Fill(dark, DARK.control, -6)
	local hover = dark:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.05)
	ns.PixelBorder(dark, DARK.checkBorder)
	local label = ns.NewText(dark, 12)
	label:SetPoint("LEFT", dark, "LEFT", 8, 0)
	label:SetPoint("RIGHT", dark, "RIGHT", -22, 0)
	label:SetJustifyH("LEFT")
	label:SetWordWrap(false)
	Chevron(dark)
	dark:SetScript("OnClick", function(self)
		if menu and menu:IsShown() and owner == self then Close() return end
		local list = Collect(build)
		OpenOurs(list, w, function(m)
			m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		end, self, false, cap)
		FitWidth(list, w)
	end)
	dd.blizz, dd.dark, dd.label = blizz, dark, label
	function dd:SetLabel(text)
		label:SetText(text or "")
		if blizz then
			if blizz.OverrideText then blizz:OverrideText(text or "") elseif blizz.SetDefaultText then blizz:SetDefaultText(text or "") end
		end
	end
	ns.OnPaint(function(isDark)
		local ours = isDark or not blizz
		dark:SetShown(ours)
		if blizz then blizz:SetShown(not ours) end
		if not ours and menu and owner == dark then Close() end
	end)
	return dd
end

------------------------------------------------------------------------
-- Right-click menu at the cursor
------------------------------------------------------------------------
function ns.ContextMenu(by, build)
	if not ns.IsDark() and MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(by, function(_, root) FillBlizzard(root, Collect(build)) end)
		return
	end
	local list = Collect(build)
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	local width = 100
	OpenOurs(list, width, function(m)
		m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x or 0) / scale, (y or 0) / scale)
	end, by, true)
	FitWidth(list, width)
end

-- A row's right-click menu: entries from Libraries (PSS_RowMenus.lua), each
-- a title, a divider, a tick or a button whose act run(act, arg) carries out.
function ns.RowMenu(by, entries, run)
	if not entries then return end
	ns.ContextMenu(by, function(m)
		for _, e in ipairs(entries) do
			if e.kind == "title" then
				m:Title(e.text)
			elseif e.kind == "divider" then
				m:Divider()
			elseif e.kind == "check" then
				m:Check(e.text, e.on, function() run(e.act, e.arg) end)
			else
				m:Button(e.text, function() run(e.act, e.arg) end)
			end
		end
	end)
end
