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
-- dark list with a faint edge, 26 px items, the picked or ticked ones
-- marked in the accent, at most 200 tall and scrolled by the mouse wheel.
--   ns.NewDropdown(parent, w, build)   dd:SetLabel(text)
--   ns.ContextMenu(owner, build)       at the cursor
------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local DARK = ns.DARK
local ITEM_H, MAX_H, PAD = 26, 200, 1
local MENU_FILL = { 0.103, 0.095, 0.088, 0.98 }
local MENU_EDGE = { 1, 1, 1, 0.20 }
local floor, max, min = math.floor, math.max, math.min

------------------------------------------------------------------------
-- The entries of a menu: build(m) fills a plain list we can draw or hand
-- to Blizzard's menu.
------------------------------------------------------------------------
local Entries = {}
Entries.__index = Entries

function Entries:Button(text, fn) self[#self + 1] = { kind = "button", text = text, fn = fn } end
function Entries:Radio(text, isOn, fn) self[#self + 1] = { kind = "radio", text = text, on = isOn, fn = fn } end
function Entries:Check(text, isOn, fn) self[#self + 1] = { kind = "check", text = text, on = isOn, fn = fn } end
function Entries:Divider() self[#self + 1] = { kind = "divider" } end
function Entries:Title(text) self[#self + 1] = { kind = "title", text = text } end

local function Collect(build)
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
local function FillBlizzard(root, list)
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
		elseif e.kind == "divider" and root.CreateDivider then
			root:CreateDivider()
		elseif e.kind == "title" and root.CreateTitle then
			root:CreateTitle(e.text)
		end
	end
	if #list > 20 and root.SetScrollMode then root:SetScrollMode(400) end
end

------------------------------------------------------------------------
-- Our menu list (one, shared)
------------------------------------------------------------------------
local menu, slots, catcher
local shown, offset, owner = nil, 0, nil

local function Visible()
	return min(#shown, floor((MAX_H - PAD * 2) / ITEM_H))
end

local function Close()
	if menu then menu:Hide() end
end
ns.CloseMenu = Close

local function Draw()
	local n = Visible()
	local marks = false
	for _, e in ipairs(shown) do
		if e.kind == "radio" or e.kind == "check" then marks = true break end
	end
	for i, s in ipairs(slots) do
		local e = shown[offset + i]
		if i <= n and e then
			s.entry = e
			s:Show()
			local title, divider = e.kind == "title", e.kind == "divider"
			s.text:SetText(divider and "" or e.text or "")
			s.text:ClearAllPoints()
			s.text:SetPoint("LEFT", s, "LEFT", marks and 24 or 10, 0)
			s.text:SetPoint("RIGHT", s, "RIGHT", -8, 0)
			s.text:SetTextColor(1, 1, 1, title and 0.41 or 0.53)
			s.line:SetShown(divider)
			local on = (e.kind == "radio" or e.kind == "check") and IsOn(e)
			s.mark:SetShown(on)
			s.mark:SetColorTexture(ns.Accent())
			s.box:SetShown(e.kind == "check")
			s.picked:SetShown(on and e.kind == "radio")
			s:EnableMouse(not (title or divider))
		else
			s.entry = nil
			s:Hide()
		end
	end
	menu:SetHeight(n * ITEM_H + PAD * 2)
	-- a list longer than the menu: a thin thumb on the right
	local extra = #shown - n
	if extra > 0 then
		local h = max(20, (menu:GetHeight() - 8) * n / #shown)
		menu.thumb:SetHeight(h)
		menu.thumb:ClearAllPoints()
		menu.thumb:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -4 - (menu:GetHeight() - 8 - h) * offset / extra)
		menu.thumb:Show()
	else
		menu.thumb:Hide()
	end
end

local function BuildMenu()
	menu = CreateFrame("Frame", "PSS_Menu", UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(200)
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:EnableMouseWheel(true)
	menu:Hide()
	ns.Fill(menu, MENU_FILL, -6)
	ns.PixelBorder(menu, MENU_EDGE)
	menu.thumb = menu:CreateTexture(nil, "OVERLAY")
	menu.thumb:SetWidth(4)
	menu.thumb:SetColorTexture(1, 1, 1, 0.27)
	menu:SetScript("OnMouseWheel", function(_, delta)
		local extra = #shown - Visible()
		offset = max(0, min(extra, offset - delta))
		Draw()
	end)
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
	end)
	tinsert(UISpecialFrames, "PSS_Menu")
	slots = {}
	menu.slots = slots
	for i = 1, floor((MAX_H - PAD * 2) / ITEM_H) do
		local s = CreateFrame("Button", nil, menu)
		s:SetHeight(ITEM_H)
		s:SetPoint("TOPLEFT", menu, "TOPLEFT", PAD, -PAD - (i - 1) * ITEM_H)
		s:SetPoint("RIGHT", menu, "RIGHT", -PAD, 0)
		s.picked = s:CreateTexture(nil, "BACKGROUND")
		s.picked:SetAllPoints()
		s.picked:SetColorTexture(1, 1, 1, 0.04)
		local hl = s:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetColorTexture(1, 1, 1, 0.08)
		s.box = s:CreateTexture(nil, "ARTWORK")
		s.box:SetSize(12, 12)
		s.box:SetPoint("LEFT", s, "LEFT", 8, 0)
		s.box:SetColorTexture(1, 1, 1, 0.12)
		s.mark = s:CreateTexture(nil, "OVERLAY")
		s.mark:SetSize(8, 8)
		s.mark:SetPoint("CENTER", s.box, "CENTER")
		s.text = ns.NewText(s, 13)
		s.text:SetJustifyH("LEFT")
		s.text:SetWordWrap(false)
		s.line = s:CreateTexture(nil, "ARTWORK")
		s.line:SetHeight(1)
		s.line:SetPoint("LEFT", s, "LEFT", 8, 0)
		s.line:SetPoint("RIGHT", s, "RIGHT", -8, 0)
		s.line:SetColorTexture(1, 1, 1, 0.10)
		s:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1, 1) end)
		s:SetScript("OnLeave", function() Draw() end)
		s:SetScript("OnClick", function(self)
			local e = self.entry
			if not e then return end
			if e.fn then e.fn() end
			if e.kind == "check" then Draw() else Close() end
		end)
		slots[i] = s
	end
end

-- Show our list for the entries; anchor(frame) places it.
local function OpenOurs(list, width, place, by)
	if not menu then BuildMenu() end
	if menu:IsShown() then Close() end
	shown, offset, owner = list, 0, by
	menu:SetWidth(width)
	menu:ClearAllPoints()
	place(menu)
	Draw()
	menu:Show()
	menu:Raise()
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

function ns.NewDropdown(parent, w, build)
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
		OpenOurs(Collect(build), w, function(m) m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2) end, self)
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
	local width = 120
	OpenOurs(list, width, function(m)
		m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (x or 0) / scale, (y or 0) / scale)
	end, by)
	-- as wide as its longest entry
	local widest = 0
	for _, s in ipairs(slots) do
		if s:IsShown() then widest = max(widest, s.text:GetStringWidth()) end
	end
	menu:SetWidth(max(width, widest + 40))
end
