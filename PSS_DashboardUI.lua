------------------------------------------------------------------------
-- POUR SOCIAL SCORE - DASHBOARD TAB
--
-- The client side of PSS_ListLookup.lua: the Dashboard tab, the first tab
-- of the main window and the one it opens on. Same page as the other tabs
-- (block counts strip, entry row top right, column header and list), with
-- one view only:
--   [ Ignore List Lookup... ] [Lookup] [Duplicate Lookup]
-- Typing looks the name up on the Player Ignore List and every guild list
-- after a short pause; Duplicate Lookup lists the people on more than one
-- list. One row per person; a person on the Player Ignore List and a guild
-- list is highlighted. Right-click a row to take them off a list.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

local UI = M.UI
local W = M.Widgets
local trim = M.PSS_Trim

local SEARCH_PAUSE = 0.25		-- seconds of no typing before the lookup runs (as the members search)
local BOTH_COLOR = { 1, 0.55, 0, 0.18 }		-- row tint: Player Ignore List and a guild list

local COLS = {
	{ key = "name",		text = "Name",				width = 180 },
	{ key = "lists",	text = "Lists",				width = 60, justify = "RIGHT",
		tip = "How many lists the player is on. Highlighted rows are on the Player Ignore List and a guild list." },
	{ key = "player",	text = "Player Ignore List", width = 130 },
	{ key = "guild",	text = "Guild Ignore List",	width = 300, tip = "The guild lists the player is on. (built-in) = a list that ships with the addon; dimmed = its guild rule is off." },
	{ key = "note",		text = "Note",				width = 200, fill = true, minWidth = 80 },
}

local function hideTip() GameTooltip:Hide() end

local function say(msg) M.ChatMsg("PSS: " .. msg) end

------------------------------------------------------------------------
-- cells
------------------------------------------------------------------------
local function guildText(e)
	local parts = {}
	for _, gl in ipairs(e.guilds) do
		local t = tostring(gl.name) .. (gl.builtIn and " |cffaaaaaa(built-in)|r" or "")
		if not gl.ruleOn then t = "|cff808080" .. tostring(gl.name) .. (gl.builtIn and " (built-in)" or "") .. "|r" end
		parts[#parts + 1] = t
	end
	return table.concat(parts, ", ")
end

local function noteText(e)
	local idx = e.player and e.player.index
	local note = idx and PourSocialScoreDB.notes and PourSocialScoreDB.notes[idx]
	if type(note) == "string" and note ~= "" then return note end
	for _, gl in ipairs(e.guilds) do
		if gl.member and (gl.member.note or "") ~= "" then return gl.member.note end
	end
	return ""
end

local function sortValue(e, key)
	if key == "lists" then return e.lists
	elseif key == "player" then return e.player and 1 or 0
	elseif key == "guild" then return string.lower(e.guilds[1] and tostring(e.guilds[1].name) or "")
	elseif key == "note" then return string.lower(noteText(e))
	end
	return string.lower(e.name or "")
end

local function sortEntries(f)
	local key, asc = f.sortKey or "name", f.sortAsc ~= false
	for _, e in ipairs(f.entries) do e.sv = sortValue(e, key); e.nv = string.lower(e.name or "") end
	table.sort(f.entries, function(a, b)
		if a.sv ~= b.sv then
			if asc then return a.sv < b.sv else return a.sv > b.sv end
		end
		return a.nv < b.nv		-- stable tie-break by name
	end)
	f.header:SetSort(key, asc)
end

------------------------------------------------------------------------
-- block counts strip (Player and Guild Ignore Lists together)
------------------------------------------------------------------------
local function addCounts(a, b)
	local out = { total = 0 }
	for _, c in ipairs({ a or {}, b or {} }) do
		for k, n in pairs(c) do out[k] = (out[k] or 0) + (tonumber(n) or 0) end
	end
	return out
end

local function playerTotals()
	local sum = { total = 0 }
	for i, name in ipairs(PourSocialScoreDB.ignoreList or {}) do
		if PourSocialScoreDB.typeList[i] == "player" and M.PSS_GetPlayerRecord(name) then
			for k, n in pairs(M.PSS_GetPlayerBlockCounts(name)) do
				if type(n) == "number" then sum[k] = (sum[k] or 0) + n end
			end
		end
	end
	return sum
end

local function updateStats(f)
	local S = M.PSS_Stats
	f.stats:Set(1, addCounts(S and S.Session("player"), S and S.Session("guild")))
	f.stats:Set(2, addCounts(S and S.Last24("player"), S and S.Last24("guild")))
	f.stats:Set(3, addCounts(playerTotals(), M.PSS_GetGuildBlockCounts()))
end

------------------------------------------------------------------------
-- rows: a pool for the rows in view (as the guild members window)
------------------------------------------------------------------------
local function updateSelection(f)
	for _, r in ipairs(f.rows) do
		r:SetSelected(r:IsShown() and r.entry ~= nil and r.entry.ck == f.selectedCk)
	end
end

local function removeFrom(f, e, what)
	local n = M.PSS_RemoveFromLists(e.ck, what)
	if n > 0 then
		say(("%s taken off %d list(s)."):format(tostring(e.name), n))
	end
	f.refresh()
end

-- Right-click: where to take the player off.
local function rowMenu(f, e)
	MenuUtil.CreateContextMenu(UIParent, function(owner, root)
		root:CreateTitle(tostring(e.name))
		root:CreateDivider()
		if e.player then
			root:CreateButton("Remove from Player Ignore List", function() removeFrom(f, e, "player") end)
		end
		for _, gl in ipairs(e.guilds) do
			local key = gl.key
			root:CreateButton("Remove from " .. tostring(gl.name) .. (gl.builtIn and " (built-in)" or ""), function() removeFrom(f, e, key) end)
		end
		if #e.guilds > 1 then
			root:CreateButton("Remove from every guild list", function() removeFrom(f, e, "guilds") end)
		end
		if e.lists > 1 then
			root:CreateDivider()
			root:CreateButton("Remove from all lists", function() removeFrom(f, e, "all") end)
		end
	end)
end

local function rowTip(self)
	local e = self.entry
	if not e then return end
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	GameTooltip:AddLine(tostring(e.name), 1, 1, 1)
	if e.player then GameTooltip:AddLine("Player Ignore List", 0.8, 0.8, 0.8) end
	for _, gl in ipairs(e.guilds) do
		GameTooltip:AddLine("Guild list: " .. tostring(gl.name) .. (gl.builtIn and " (built-in)" or "") ..
			(gl.ruleOn and "" or " - rule off"), 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine("Right-click to remove the player from a list.", 0.6, 0.6, 0.6, true)
	for _, gl in ipairs(e.guilds) do
		if e.player and gl.builtIn then
			GameTooltip:AddLine("Off the Player Ignore List only, they stay on the built-in list with W I G P C blocked.", 0.6, 0.6, 0.6, true)
			break
		end
	end
	GameTooltip:Show()
end

local function makeRow(f, i)
	local hr = f.header
	local r = UI.CreateRow(f.content, hr.total)
	r.both = r:CreateTexture(nil, "BACKGROUND")
	r.both:SetAllPoints(r)
	r.both:SetColorTexture(BOTH_COLOR[1], BOTH_COLOR[2], BOTH_COLOR[3], BOTH_COLOR[4])
	r:SetScript("OnClick", function(self, button)
		if not self.entry then return end
		f.selectedCk = self.entry.ck
		updateSelection(f)
		if button == "RightButton" then rowMenu(f, self.entry) end
	end)
	r:SetScript("OnEnter", rowTip)
	r:SetScript("OnLeave", hideTip)
	r.name = UI.TCell(r, hr, "name")
	r.lists = UI.TCell(r, hr, "lists", "RIGHT")
	r.player = UI.TCell(r, hr, "player")
	r.guild = UI.TCell(r, hr, "guild")
	r.note = UI.TCell(r, hr, "note")
	f.rows[i] = r
	return r
end

local function fillRow(r, e)
	r.entry = e
	local both = e.player ~= nil and #e.guilds > 0
	r.both:SetShown(both)
	r.name:SetText(e.name or "")
	local gm = e.guilds[1] and e.guilds[1].member
	local cc = gm and gm.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[gm.class]
	if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(1, 1, 1) end
	r.lists:SetText((both and "|cffff9933" or "") .. tostring(e.lists) .. (both and "|r" or ""))
	r.player:SetText(e.player and "|cffff9933Yes|r" or "")
	r.guild:SetText(guildText(e))
	r.note:SetText(noteText(e))
	r:Show()
end

local function layoutRows(f)
	local entries = f.entries or {}
	local rowH = UI.ROW_H
	local first = math.floor((f.scroll:GetVerticalScroll() or 0) / rowH) + 1
	local slots = math.ceil(math.max(f.scroll:GetHeight() or 0, f:GetHeight() or 0) / rowH) + 1
	for j = 1, slots do
		local i = first + j - 1
		local e = entries[i]
		local r = f.rows[j]
		if e then
			r = r or makeRow(f, j)
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, 0, -(i - 1) * rowH)
			fillRow(r, e)
		elseif r then
			r:Hide()
			r.entry = nil
		end
	end
	for j = slots + 1, #f.rows do f.rows[j]:Hide(); f.rows[j].entry = nil end
	updateSelection(f)
end

------------------------------------------------------------------------
-- running a lookup
------------------------------------------------------------------------
local function refresh(f)
	if not f:IsVisible() then return end
	updateStats(f)
	local entries, found
	if f.mode == "duplicates" then
		entries, found = M.PSS_ListDuplicates()
		f.title:SetText(("Duplicate Lookup: |cffffff00%d|r player(s) on more than one list"):format(found) ..
			(found > #entries and ((" (first %d shown)"):format(#entries)) or ""))
	else
		local q = trim(f.box:GetText() or "")
		local more
		entries, more = M.PSS_ListLookup(q)
		if q == "" then
			f.title:SetText("Type a name in Ignore List Lookup to search the Player and Guild Ignore Lists.")
		elseif more then
			f.title:SetText(("More than |cffffff00%d|r players found for \"%s\". Type more of the name."):format(#entries, q))
		else
			f.title:SetText(("|cffffff00%d|r player(s) found for \"%s\""):format(#entries, q))
		end
	end
	f.entries = entries
	sortEntries(f)
	if f.selectedCk then
		local keep = false
		for _, e in ipairs(entries) do if e.ck == f.selectedCk then keep = true break end end
		if not keep then f.selectedCk = nil end
	end
	f.content:SetWidth(math.max(f.scroll:GetWidth() or 0, f.header.total))
	f.content:SetHeight(math.max(1, #entries * UI.ROW_H))
	for _, r in ipairs(f.rows) do r:Hide() end
	layoutRows(f)
end

-- One redraw per frame however many list changes arrive in it.
local function requestRefresh(f)
	if f.redrawQueued or not f:IsVisible() then return end
	f.redrawQueued = true
	C_Timer.After(0, function()
		f.redrawQueued = false
		f.refresh()
	end)
end

------------------------------------------------------------------------
-- building the tab
------------------------------------------------------------------------
-- top right: [ Ignore List Lookup... ] [Lookup] [Duplicate Lookup]
-- (the shape of the EntryRow widget, PSS_Widgets.lua)
local function buildEntryRow(f)
	local dup = UI.TopButton(f, "Duplicate Lookup", nil, 120, "PSSDashDuplicateButton")
	local look = UI.TopButton(f, "Lookup", dup, nil, "PSSDashLookupButton")
	local box = UI.SearchBox(f, look, 150, "PSSDashSearchBox")
	W.BoxHint(box, "Ignore List Lookup...")
	f.box, f.lookupButton, f.duplicateButton = box, look, dup

	local function lookupNow()
		f.mode = "lookup"
		f.searchToken = (f.searchToken or 0) + 1
		f.refresh()
	end
	-- typing waits for a short pause; a change made by the addon refreshes at once
	box:SetScript("OnTextChanged", function(self, userInput)
		f.mode = "lookup"
		if not userInput then f.refresh() return end
		f.searchToken = (f.searchToken or 0) + 1
		local token = f.searchToken
		C_Timer.After(SEARCH_PAUSE, function()
			if f.searchToken == token and f:IsVisible() then f.refresh() end
		end)
	end)
	box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		lookupNow()
	end)
	look:SetScript("OnClick", lookupNow)
	dup:SetScript("OnClick", function()
		f.mode = "duplicates"
		f.selectedCk = nil
		f.refresh()
	end)

	look:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Lookup - Ignore List Lookup", 1, 1, 1)
		GameTooltip:AddLine("Lists the players on the Player Ignore List and the guild lists whose name contains the text in the box. The list also updates as you type.", nil, nil, nil, true)
		GameTooltip:AddLine("Name or Name-Realm. A player on more than one list has one row; on the Player Ignore List and a guild list the row is highlighted.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	dup:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Duplicate Lookup", 1, 1, 1)
		GameTooltip:AddLine("Lists every player on more than one list: the Player Ignore List and a guild list, or two guild lists.", nil, nil, nil, true)
		GameTooltip:AddLine("Right-click a row to choose which list to take them off.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	look:SetScript("OnLeave", hideTip)
	dup:SetScript("OnLeave", hideTip)
end

local function buildList(f)
	f.sortKey, f.sortAsc = "name", true
	local function onSort(key)
		if f.sortKey == key then f.sortAsc = not f.sortAsc else f.sortKey, f.sortAsc = key, true end
		f.refresh()
	end
	local hr = UI.CreateHeaderRow(f, COLS, 1, UI.COMPACT_HEADER_Y, onSort, { id = "dashboard", onLayout = function(h)
		if f.content then f.content:SetWidth(math.max(f.scroll:GetWidth() or 0, h.total)) end
		for _, r in ipairs(f.rows or {}) do r:SetWidth(h.total) end
	end })
	f.header = hr

	local scroll, content = UI.ScrollList(f, "PSSDashScroll", hr.total)
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", 1, -UI.COMPACT_LIST_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -27, 4)
	scroll:HookScript("OnVerticalScroll", function() layoutRows(f) end)
	f.scroll, f.content, f.rows, f.entries = scroll, content, {}, {}
end

function M.PSS_BuildDashboardTab(parent)
	if M.PSSDashFrame then return M.PSSDashFrame end

	-- Same panel as every other tab (see PSS_UIKit.lua).
	local f = CreateFrame("Frame", "PSSDashFrame", parent, "InsetFrameTemplate")
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -84)
	f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -11, 29)
	M.PSSDashFrame = f

	f.title = UI.CreateSummary(f, "", 520)
	f.stats = UI.CreateBlockStats(f, parent, UI.STATS_BLOCK_CATS, "messages and invites")
	f.mode = "lookup"

	buildEntryRow(f)
	buildList(f)

	f.refresh = function() refresh(f) end
	f:SetScript("OnShow", function() f.refresh() end)
	f:SetScript("OnSizeChanged", function(self, w)
		if w and w > 0 then f.header:SetAvailableWidth(w - 28) end
		if f:IsVisible() then layoutRows(f) end
	end)

	-- list changes redo the lookup; blocks only recount the strip, at most
	-- 4 times a second (spam can block several lines a second)
	local function queue() requestRefresh(f) end
	local function queueStats()
		if f.statsQueued or not f:IsVisible() then return end
		f.statsQueued = true
		C_Timer.After(0.25, function()
			f.statsQueued = false
			if f:IsVisible() then updateStats(f) end
		end)
	end
	M.Events.Register("PLAYERS_CHANGED", queue)
	M.Events.Register("GUILDS_CHANGED", queue)
	M.Events.Register("PLAYER_BLOCKED", queueStats)
	M.Events.Register("GUILD_BLOCKS_CHANGED", queueStats)
	return f
end
