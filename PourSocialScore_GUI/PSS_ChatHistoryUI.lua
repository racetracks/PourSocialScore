------------------------------------------------------------------------
-- POUR SOCIAL SCORE - BLOCK HISTORY WINDOWS
--
-- The client side of PSS_ChatHistory.lua: the block history table, the
-- in-place Block History panel, the Block History popup window and the
-- right-click menu on a history line. The data and its migration stay in
-- PSS_ChatHistory.lua; this file only draws it.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M
local L = addon.L

local History = M.PSS_History
local UNKNOWN = History.UNKNOWN
local CAT_LABEL, CAT_COLOR = History.CAT_LABEL, History.CAT_COLOR

------------------------------------------------------------------------
-- Right-click a history line
------------------------------------------------------------------------
-- Default options for the sender: add to / remove from the Player Ignore
-- List. extra(root, entry) can add more (e.g. Edit Filter).
function History.RowMenu(entry, extra)
	if not entry or not MenuUtil then return end
	local name = entry.member
	local valid = type(name) == "string" and name ~= "" and name ~= UNKNOWN
	local full = valid and M.Proper and M.Proper(M.addServer(name)) or name
	MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
		root:CreateTitle(valid and full or "Blocked line")
		if valid then
			root:CreateDivider()
			if M.hasGlobalIgnored and M.hasGlobalIgnored(full) > 0 then
				root:CreateButton(L["RCM_4"] or "Remove from ignore", function() M.PSS_DelIgnore(full) end)
			else
				root:CreateButton(L["RCM_6"] or "Add to ignore", function() M.PSS_AddOrDelIgnore(full) end)
			end
		end
		if extra then extra(root, entry) end
		root:CreateDivider()
		root:CreateButton(L["RCM_5"] or "Cancel", function() end)
	end)
end

------------------------------------------------------------------------
-- History table (the widget every Block History view uses)
-- Columns: Time | Player | Type | Channel | Message (tooltip: full text).
-- opts.onRowClick(entry, mouseButton) replaces the default right-click menu;
-- opts.rowMenu(root, entry) adds items to the default menu.
------------------------------------------------------------------------
local listCount = 0
local SORT = {
	time	= function(h) return tonumber(h.ts) or 0 end,
	member	= function(h) return string.lower(h.member or "") end,
	kind	= function(h) return string.lower(h.kind or "") end,
	channel = function(h) return string.lower(h.channel or "") end,
	message = function(h) return string.lower(h.message or "") end,
}

function History.CreateList(parent, numRows, rowH, width, opts)
	opts = opts or {}
	local UI = M.UI
	listCount = listCount + 1
	rowH = UI.ROW_H
	numRows = numRows or 10
	-- visible: our own on/off flag. Never use scroll:IsShown() for this -
	-- FauxScrollFrame_Update hides the scroll frame whenever every entry
	-- fits on screen, which used to hide all rows of a short history.
	local HL = { entries = {}, source = {}, numRows = numRows, rowH = rowH, rows = {}, sortKey = "time", sortAsc = false, visible = true }
	local cols = { time = 132, member = 150, kind = 100, channel = 140 }
	cols.message = math.max(80, (width or 860) - 26 - cols.time - cols.member - cols.kind - cols.channel)

	local update
	local function applySort()
		local key, asc = HL.sortKey, HL.sortAsc
		local fn = SORT[key] or SORT.time
		local list, vals, order = {}, {}, {}
		for i, h in ipairs(HL.source) do list[i] = h; vals[h] = fn(h); order[h] = i end
		table.sort(list, function(a, b)
			local A, B = vals[a], vals[b]
			if A ~= B then if asc then return A < B else return A > B end end
			return order[a] < order[b]
		end)
		HL.entries = list
		if HL.header then HL.header:SetSort(key, asc) end
	end
	local function onSort(key)
		if HL.sortKey == key then HL.sortAsc = not HL.sortAsc
		else HL.sortKey, HL.sortAsc = key, (key ~= "time") end		-- time starts newest first
		applySort()
		update()
	end

	HL.header = UI.CreateHeaderRow(parent, {
		{ key = "time",		text = "Time",		width = cols.time },
		{ key = "member",	text = "Player",	width = cols.member },
		{ key = "kind",		text = "Type",		width = cols.kind },
		{ key = "channel", text = "Channel", width = cols.channel },
		{ key = "message", text = "Message", width = cols.message, fill = true, minWidth = 80 },
	}, 0, 0, onSort, { id = "history" })
	-- the widths in use (the header row owns them; kept for older callers)
	HL.cols = HL.header.w

	HL.empty = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	HL.empty:SetPoint("TOP", parent, "TOP", 0, -UI.HEADER_H - 30)
	HL.empty:SetText("No blocked messages or invites recorded.")

	local scroll = CreateFrame("ScrollFrame", "PSSHistoryList" .. listCount .. "Scroll", parent, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -UI.HEADER_H)
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 0)
	HL.scroll = scroll

	update = function()
		local n = #HL.entries
		local rowsShown = HL.numRows
		FauxScrollFrame_Update(scroll, n, rowsShown, rowH)
		local offset = FauxScrollFrame_GetOffset(scroll) or 0
		HL.empty:SetShown(n == 0 and HL.visible)
		for i = rowsShown + 1, #HL.rows do HL.rows[i].entry = nil; HL.rows[i]:Hide() end
		for i = 1, rowsShown do
			local row = HL.rows[i]
			local h = HL.entries[i + offset]
			if h and HL.visible then
				local cat = h.cat or "unknown"
				row.time:SetText(h.time or UNKNOWN)
				row.member:SetText(h.member or UNKNOWN)
				row.kind:SetText("|c" .. (CAT_COLOR[cat] or "ffffffff") .. (h.kind or CAT_LABEL[cat] or UNKNOWN) .. "|r")
				row.channel:SetText(h.channel or UNKNOWN)
				local msg = h.message or ""
				row.msg:SetText(msg ~= "" and msg or "|cff888888(no message text)|r")
				row.entry = h
				row:Show()
			else
				row.entry = nil
				row:Hide()
			end
		end
	end
	HL.update = update
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, rowH, update)
	end)

	local function makeRow(i)
		local row = UI.CreateRow(parent)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -UI.HEADER_H - (i - 1) * rowH)
		row:SetPoint("RIGHT", parent, "RIGHT", -26, 0)
		local hr = HL.header
		row.time = UI.TCell(row, hr, "time")
		row.member = UI.TCell(row, hr, "member")
		row.kind = UI.TCell(row, hr, "kind")
		row.channel = UI.TCell(row, hr, "channel")
		row.msg = UI.TCell(row, hr, "message")

		-- Links in the message (items, recipes, professions, spells,
		-- achievements...) work like in chat: hover for the tooltip, click
		-- to open it, shift-click to paste it into chat.
		if row.SetHyperlinksEnabled then
			row:SetHyperlinksEnabled(true)
			row:SetScript("OnHyperlinkClick", function(self, link, text, button)
				self.linkClickAt = GetTime()
				if SetItemRef then pcall(SetItemRef, link, text, button, DEFAULT_CHAT_FRAME) end
			end)
			row:SetScript("OnHyperlinkEnter", function(self, link)
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
				if ok and GameTooltip:NumLines() > 0 then
					GameTooltip:Show()
				else
					GameTooltip:Hide()
					local onEnter = self:GetScript("OnEnter")
					if onEnter then onEnter(self) end
				end
			end)
			row:SetScript("OnHyperlinkLeave", function(self)
				GameTooltip:Hide()
				if self:IsMouseOver() then
					local onEnter = self:GetScript("OnEnter")
					if onEnter then onEnter(self) end
				end
			end)
		end

		row:SetScript("OnEnter", function(self)
			local h = self.entry
			if not h then return end
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddDoubleLine(h.member or UNKNOWN, h.time or UNKNOWN, 1, 1, 1, 0.85, 0.85, 0.85)
			GameTooltip:AddDoubleLine(h.kind or UNKNOWN, h.channel or UNKNOWN, 1, 0.82, 0, 0.6, 0.6, 0.4)
			local src = History.sourceLabel[h]
			if src then GameTooltip:AddLine(src, 0.7, 0.7, 0.7) end
			if (h.message or "") ~= "" then GameTooltip:AddLine(h.message, 1, 0.75, 0.75, true) end
			GameTooltip:AddLine("Right-click for options. Click a link in the message to open it.", 0.6, 0.6, 0.6, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:SetScript("OnClick", function(self, button)
			if not self.entry then return end
			-- the click was on a link in the message: that is handled above
			if self.linkClickAt and GetTime() - self.linkClickAt < 0.05 then return end
			if opts.onRowClick then opts.onRowClick(self.entry, button)
			elseif button == "RightButton" then History.RowMenu(self.entry, opts.rowMenu) end
		end)
		row:Hide()
		HL.rows[i] = row
	end
	for i = 1, numRows do makeRow(i) end

	-- Fit the row count and Message column to the parent's size (the windows
	-- holding this list can be resized).
	local function relayout()
		local pw, ph = parent:GetWidth() or 0, parent:GetHeight() or 0
		if pw <= 0 or ph <= 0 then return end
		HL.numRows = math.max(1, math.floor((ph - UI.HEADER_H) / rowH))
		for i = #HL.rows + 1, HL.numRows do makeRow(i) end
		-- the Message column takes the width the other columns leave
		HL.header:SetAvailableWidth(pw - 26)
		update()
	end
	HL.relayout = relayout
	parent:HookScript("OnSizeChanged", relayout)

	function HL:SetEntries(entries, resetScroll)
		self.source = entries or {}
		if resetScroll then
			self.sortKey, self.sortAsc = "time", false
			FauxScrollFrame_SetOffset(scroll, 0)
			local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
			if bar and bar.SetValue then bar:SetValue(0) end
		end
		applySort()
		update()
	end
	function HL:SetShown(on)
		self.visible = on and true or false
		self.header:SetShown(on)
		scroll:SetShown(on)
		if not on then for _, r in ipairs(self.rows) do r:Hide() end; self.empty:Hide() else update() end
	end
	applySort()
	return HL
end
M.PSS_CreateHistoryList = History.CreateList

------------------------------------------------------------------------
-- In-place Block History panel for a tab (the Guild Ignore List design)
--
-- Shown instead of the tab's list; its header row sits where the list
-- header was, the tab title shows what is listed, and the bar holds
-- Close (right) / Reset Block History / All <things> [/ extra button].
--
-- opts = {
--   baseTitle  = "Guild Ignore List",       title to restore on Close
--   allText    = "all guilds",              title text for the "all" view
--   allButton  = "All Guilds",              bar button
--   setListShown(on)                         hide/show the tab's own list
--   entries(key)  -> list                    key nil = everything
--   label(key)    -> name or nil             nil = gone (falls back to all)
--   reset(key)                               key nil = everything (asks first)
--   extra = { text=, onClick(key), shown(key) }   optional bar button
--   rowMenu(root, entry)                     optional right-click items
-- }
------------------------------------------------------------------------
StaticPopupDialogs["PSS_HISTORY_RESET_ALL"] = {
	preferredIndex = STATICPOPUPS_NUMDIALOGS or 3,
	text = "%s",
	whileDead = 1,
	hideOnEscape = 1,
	button1 = (L and L["BOX_4"]) or "Reset",
	button2 = (L and L["BOX_5"]) or CANCEL,
	OnAccept = function(self, data) if data and data.run then data.run() end end,
}

function History.CreatePanel(tab, opts)
	local UI = M.UI
	local P = CreateFrame("Frame", nil, tab)
	P:SetPoint("TOPLEFT", 1, opts.headerY or UI.HEADER_Y)
	P:SetPoint("BOTTOMRIGHT", -1, 4)
	P:Hide()
	P.opts = opts

	P.close = UI.BarButton(tab, L["BUT_10"] or "Close"); P.close:SetParent(P)
	P.reset = UI.BarButton(tab, L["HISTORY_RESET"] or "Reset Block History", P.close, 140); P.reset:SetParent(P)
	P.all = UI.BarButton(tab, opts.allButton or "All", P.reset); P.all:SetParent(P)
	if opts.extra then
		P.extra = UI.BarButton(tab, opts.extra.text, P.all); P.extra:SetParent(P)
		P.extra:SetScript("OnClick", function() opts.extra.onClick(P.key) end)
	end
	P.list = History.CreateList(P, 11, UI.ROW_H, 860, { rowMenu = opts.rowMenu })

	function P:Refresh(resetScroll)
		if not self:IsShown() then return end
		local key = self.key
		local name = key ~= nil and opts.label(key) or nil
		if key ~= nil and not name then key = nil; self.key = nil end	-- removed meanwhile
		local entries = opts.entries(key)
		if tab.title then
			tab.title:SetText("Block History: |cffffff00" .. (name or opts.allText or "all") .. "|r (" .. #entries .. ")")
		end
		self.all:SetShown(key ~= nil)
		if self.extra then self.extra:SetShown(not opts.extra.shown or opts.extra.shown(key)) end
		self.list:SetEntries(entries, resetScroll)
	end
	function P:Open(key)
		self.key = key
		opts.setListShown(false)
		self:Show()
		self:Refresh(true)
	end
	function P:Close()
		if not self:IsShown() then return end
		self:Hide()
		if tab.title and opts.baseTitle then tab.title:SetText(opts.baseTitle) end
		opts.setListShown(true)
	end

	P.close:SetScript("OnClick", function() P:Close() end)
	P.all:SetScript("OnClick", function() P.key = nil; P:Refresh(true) end)
	P.reset:SetScript("OnClick", function()
		if P.key ~= nil then
			opts.reset(P.key)
			P:Refresh(true)
		else
			StaticPopup_Show("PSS_HISTORY_RESET_ALL",
				"|cffffff00Reset Block History|cffffffff\n\nClear the block history and counts of " .. (opts.allText or "everything") .. "?",
				nil, { run = function() opts.reset(nil); P:Refresh(true) end })
		end
	end)
	P.reset:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L["HISTORY_RESET"] or "Reset Block History", 1, 1, 1)
		GameTooltip:AddLine(P.key ~= nil and "Clears this history and its counts." or "Clears the history and counts of everything listed (asks first).", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	P.reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return P
end

------------------------------------------------------------------------
-- Block History popup window (member / player / guild history opened
-- from other windows)
------------------------------------------------------------------------
local popup

local function getPopup()
	if popup then return popup end
	local UI = M.UI
	local f = UI.CreateWindow("PSSRuleBlockHistory", "Block History", 860, 500,
		{ strata = "FULLSCREEN_DIALOG", minW = 640, minH = 300, saveKey = "ruleHistory" })
	popup = f
	local inset = f.inset
	f.heading, f.info = UI.CreateSummary(inset, "", 500)
	-- block metrics of the player / guild shown (same table everywhere)
	f.metrics = UI.CreateMetricsTable(inset)
	f.metrics:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -6)
	f.reset = UI.BarButton(inset, L["HISTORY_RESET"] or "Reset Block History", nil, 140)
	local body = CreateFrame("Frame", nil, inset)
	body:SetPoint("TOPLEFT", 1, UI.HEADER_Y)
	body:SetPoint("BOTTOMRIGHT", -1, 4)
	f.list = History.CreateList(body, 11, UI.ROW_H, 830)
	return f
end

-- source: function returning (title, entries, counts|nil); onReset optional.
function History.ShowPopup(source, onReset)
	local f = getPopup()
	f.source = source
	f.onReset = onReset
	f.reset:SetShown(onReset ~= nil)
	f.reset:SetScript("OnClick", function()
		if f.onReset then f.onReset() end
		History.RefreshPopup(true)
	end)
	f:Show()
	f:Raise()
	History.RefreshPopup(true)
end
M.PSS_ShowHistoryPopup = function(...) return History.ShowPopup(...) end

function History.RefreshPopup(resetScroll)
	local f = popup
	if not f or not f:IsShown() or not f.source then return end
	local title, entries, counts = f.source()
	entries = entries or {}
	f.title:SetText(title or "Block History")
	f.heading:SetText((title or "Block History") .. " (" .. #entries .. ")")
	f.info:SetText("")
	if counts then f.metrics:Set(counts); f.metrics:Show() else f.metrics:Hide() end
	f.list:SetEntries(entries, resetScroll)
end
M.PSS_RefreshHistoryPopup = History.RefreshPopup
