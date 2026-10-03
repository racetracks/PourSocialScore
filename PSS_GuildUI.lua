------------------------------------------------------------------------
-- POUR SOCIAL SCORE - GUILD IGNORE LIST WINDOWS
--
-- The client side of PSS_GuildIgnoreList.lua: the Guild Ignore List tab,
-- the guild members window, the Guild Search results picker and the
-- guild / member Block History popups. Guild rules, members, scans and
-- counts stay in PSS_GuildIgnoreList.lua; this file reads them through M
-- and redraws when the core fires an event.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M
local L = addon.L

local Whois				= M.Whois
local History			= M.PSS_History
local CAT_ORDER, CAT_LABEL = History.CAT_ORDER, History.CAT_LABEL
local parseTimeString	= History.ParseTime
local normalizeGuild	= M.PSS_NormalizeGuild
local ensureDB			= M.PSS_EnsureGuildDB
local findGuildRecord	= M.PSS_FindGuildRecord
local guildBlock		= M.PSS_GuildBlock
local memberBlock		= M.PSS_MemberBlock
local memberBlocks		= M.PSS_MemberBlocks
local forEachMember		= M.PSS_ForEachGuildMember
local isStaticGuild		= M.PSS_IsStaticManagedGuild
local keepManaged		= M.PSS_KeepManaged
local ensureMemberBlockData = M.PSS_EnsureMemberBlockData
local pssSay			= M.PSS_Say
local guildSearchChat	= M.PSS_Say
local trim				= M.PSS_Trim
local saveGuildSearch	= M.PSS_SaveGuildSearch
local saveGuildExclusions = M.PSS_SaveGuildExclusions

-- Scan / Guild Search buttons are disabled while /who cools down (PSS_UIKit.lua).
local function registerGuildScanButton(button) M.UI.RegisterWhoisButton(button) end

-- the cooldown ending re-enables the row Scan buttons: redraw the list
M.Events.Register("WHOIS_COOLDOWN", function(active)
	if not active and M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end)

local showHistoryPopup = History.ShowPopup

function M.PSS_ShowMemberBlockHistory(member, guildLabel)
	if type(member) ~= "table" then return end
	showHistoryPopup(function()
		ensureMemberBlockData(member)
		return "Block History: " .. tostring(member.name or "?") ..
				(guildLabel and ("  |cffaaaaaa<" .. guildLabel .. ">|r") or ""),
				M.PSS_GetMemberBlockHistory(member), M.PSS_GetMemberBlockCounts(member)
	end, function() M.PSS_ResetMemberBlockHistory(member) end)
end

function M.PSS_ShowGuildBlockHistory(guildNameOrKey)
	local g = findGuildRecord(guildNameOrKey)
	if not g then return end
	showHistoryPopup(function()
		local gg = findGuildRecord(guildNameOrKey)
		if not gg then return "Guild Block History (removed)", {}, nil end
		return "Guild Block History: " .. tostring(gg.name or guildNameOrKey),
				M.PSS_GetGuildBlockHistory(guildNameOrKey), M.PSS_GetGuildBlockCounts(guildNameOrKey)
	end, function() M.PSS_ResetGuildBlockHistory(guildNameOrKey) end)
end

-- Guild Search results: the shared picker (UI.Picker in PSS_UIKit.lua).
--   mode nil       : ticked guilds become guild rules, with the players the
--                    search saw in them as members
--   mode "exclude" : ticked guilds go on the Guild Exclusion List
local function showGuildSearchResults(list, query, mode)
	ensureDB()
	local exclude = mode == "exclude"

	if not list or #list == 0 then
		if exclude then
			-- nobody online in a guild by that name: offer to add it anyway
			M.Widgets.PromptAddAnyway(trim((query or ""):gsub('"', "")), {
				say			= guildSearchChat,
				what		= "guild",
				listName = "Guild Exclusion List",
				add			= M.PSS_AddGuildExclusion,
			})
		else
			guildSearchChat(("Guild Search found no guilds for \"%s\"."):format(query or ""))
		end
		return
	end

	local items = {}
	for _, name in ipairs(list) do
		local listed
		if exclude then
			listed = M.PSS_IsGuildExcluded(name)
		else
			listed = PourSocialScoreDB.guildData[normalizeGuild(name)] ~= nil
		end
		items[#items + 1] = { cells = { guild = name }, value = name, listed = listed }
	end

	M.PSSGuildSearchFrame = M.Widgets.Picker({
		name		= "PSSGuildSearchFrame",
		saveKey		= "guildSearch",
		title		= exclude and "Guild Exclusion Search" or "Guild Search Results",
		subtitle = ("%d guild(s) found for \"%s\"."):format(#list, query or "")
			.. (exclude and " Tick the guilds to exclude." or ""),
		columns		= { { key = "guild", text = "Guild", width = 330, minWidth = 120 } },
		items		= items,
		onSave		= exclude and saveGuildExclusions or saveGuildSearch,
		-- closing the results (Save, Cancel, Escape, X) forgets the cached players
		onHide		= function() if not exclude then C_Timer.After(0, function() M.PSS_GuildSearchCache = nil end) end end,
	})
end
M.Events.Register("GUILD_SEARCH_RESULTS", showGuildSearchResults)

-- Core events (PSS_GuildIgnoreList.lua): redraw what shows guild data.
local function refreshDetail()
	local d = M.PSSGuildDetailFrame
	if d and d:IsShown() and d.refresh then d.refresh(true) end
end
M.Events.Register("GUILDS_CHANGED", function()
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end)
M.Events.Register("GUILD_BLOCKS_CHANGED", function()
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	refreshDetail()
	if M.PSS_RefreshHistoryPopup then M.PSS_RefreshHistoryPopup() end
end)
M.Events.Register("GUILD_SCAN_DONE", function()
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	M.PSS_RefreshScanTooltip()
	refreshDetail()
	if M.PSSUpdateUI then M.PSSUpdateUI(true) end
end)
M.Events.Register("GUILD_REMOVED", function()
	if M.PSSGuildTabFrame then M.PSSGuildTabFrame.selectedGuildKey = nil end
end)

------------------------------------------------------------------------
-- GUILD ENTRY ROWS (Guild Ignore List tab, top right)
--
-- Each row is the shared EntryRow widget (PSS_Widgets.lua): a box, Guild
-- Search and Add Guild. This fills in what both guild rows share.
------------------------------------------------------------------------
local function canSendWho() return not Whois.BlockedMsg() end

local function createGuildEntryRow(frame, opts)
	opts.searchText = "Guild Search"
	opts.addText	= "Add Guild"
	opts.canSend	= canSendWho
	opts.say		= pssSay
	local row = M.Widgets.EntryRow(frame, opts)
	registerGuildScanButton(row.search)
	return row
end

------------------------------------------------------------------------
-- GUILD IGNORE LIST TAB
--
-- M.PSS_BuildGuildUI builds the tab once from the parts below, in this
-- order: entry rows and Scan All, the column header and list, the bottom
-- bar, the Block History panel. The list rows are made on first use and
-- filled by refreshGuildList. Shared parts live on the tab frame:
-- frame.header, frame.scroll, frame.content, frame.removeButton,
-- frame.histPanel, frame.updateSelection.
------------------------------------------------------------------------
local UI = M.UI
local EXCL_OPEN_KEY = "__exclusions"	-- the Guild Exclusion List header

-- Open / closed state of the collapsible rows (managed groups and the
-- Guild Exclusion List), a window preference kept in the save.
local function groupOpen(k)
	PourSocialScoreDB.guildGroupOpen = type(PourSocialScoreDB.guildGroupOpen) == "table" and PourSocialScoreDB.guildGroupOpen or {}
	return PourSocialScoreDB.guildGroupOpen[k] == true
end
local function setGroupOpen(k, on)
	groupOpen(k)
	PourSocialScoreDB.guildGroupOpen[k] = on and true or nil
end

local function refreshTab(frame)
	if frame.refresh then frame.refresh() end
end

local function hideTip() GameTooltip:Hide() end

-- top right, two rows built the same way (see createGuildEntryRow):
--   [ Add a Guild...     ] [Guild Search] [Add Guild]   -> Guild Ignore List
--   [ Exclude a Guild... ] [Guild Search] [Add Guild]   -> Guild Exclusion List
-- and Scan All to the left of the first row.
local function buildGuildEntryRows(frame)
	local ignoreRow = createGuildEntryRow(frame, {
		hint		= "Add a Guild...",
		listName	= "Guild Ignore List",
		emptyMsg	= "Type part of a guild name in the box next to Guild Search first.",
		searchTip = {
			"Runs a /who and lists every guild found (not the players).",
			"Type part of a guild name, or a full /who filter containing quotes, e.g. g-\"Name\" 10-80",
		},
		isListed	= function(name)
			return PourSocialScoreDB.guildData[normalizeGuild(name)] ~= nil
		end,
		add			= function(name) M.PSS_AddGuild(name) end,
		search		= function(text) return M.PSS_GuildSearch(text) end,
	})
	frame.addButton, frame.searchButton, frame.searchBox = ignoreRow.add, ignoreRow.search, ignoreRow.box

	local exclRow = createGuildEntryRow(frame, {
		below		= ignoreRow,
		hint		= "Exclude a Guild...",
		listName	= "Guild Exclusion List",
		emptyMsg	= "Type a guild name in the box beneath Guild Search first.",
		searchTip = {
			"Runs a /who for the guild name in the box and lets you pick which guilds found go on the Guild Exclusion List. If none is found you can add the name anyway.",
			"Excluded guilds are never blocked by a guild rule, even one whose name they contain (a rule for \"Olympus\" no longer catches an excluded <Olympus Friends>).",
		},
		isListed	= function(name) return M.PSS_IsGuildExcluded(name) end,
		add			= function(name) M.PSS_AddGuildExclusion(name) end,
		search		= function(text)
			-- always a guild name here, never a raw /who filter
			return M.PSS_GuildSearch((text:gsub('"', "")), "exclude")
		end,
		clearOnSearch = true,
	})
	frame.exclAddButton, frame.exclSearchButton, frame.exclBox = exclRow.add, exclRow.search, exclRow.box

	-- Scan All: the next /who of the guild sweep, across every guild row.
	-- (Both boxes are 150 wide, leaving room for it before the summary text.)
	local scanAll = UI.TopButton(frame, "Scan All", ignoreRow.box, 80, "PSSGuildScanAllButton")
	scanAll:ClearAllPoints()
	scanAll:SetPoint("RIGHT", ignoreRow.box, "LEFT", -10, 0)
	scanAll:SetScript("OnClick", function() M.PSS_ScanAll() end)	-- /who first, UI after
	scanAll:SetScript("OnEnter", function(self) M.PSS_ScanTipEnter(self, nil) end)
	scanAll:SetScript("OnLeave", function() M.PSS_ScanTipLeave() end)
	registerGuildScanButton(scanAll)
	frame.scanAllButton = scanAll
end

-- Columns (every column sorts): the block metrics, then the per-guild
-- W I G P C exclusions (tickboxes).
local function guildColumns()
	local COLS = {
		{ key = "guild",	text = "Guild",		width = 150 },
		{ key = "members", text = "Members", width = 70, justify = "RIGHT" },
	}
	for _, c in ipairs(UI.MetricColumns()) do COLS[#COLS + 1] = c end
	for _, c in ipairs({
		{ key = "excl",		letters = "excl", width = UI.EXCL_W, lettersTitle = "Per-guild exclusions",
			lettersNote = "Ticked = allowed from every member of the guild, unticked = blocked. A member's own W I G P C (members window) wins." },
		{ key = "scan",		text = "Scan",		width = 86, tip = "Sweeps the guild with /who, one search per click: the whole guild first, then any answer capped at 50 is split by level bracket, class and single level. Scan n/m = searches sent / planned so far. Hover a Scan button for the full status. Sorts by searches sent this session." },
		{ key = "fields",	text = "Scan Fields", width = 120, tip = "Extra /who filters sent with the guild name by Custom Scan, e.g. 80  or  70-80 c-\"Mage\"." },
		{ key = "custom",	text = "Custom",	width = 72, tip = "Custom Scan: /who for the guild plus its Scan Fields. Sorts by whether Scan Fields are set." },
	}) do COLS[#COLS + 1] = c end
	return COLS
end

-- The sortable column header and the scrolling list under it.
local function buildGuildList(frame)
	-- Sorting: a new column sorts ascending, the same column again flips it.
	-- The tab always opens on guild name A-Z.
	frame.sortKey, frame.sortAsc = "guild", true
	local function onSort(key)
		if frame.sortKey == key then frame.sortAsc = not frame.sortAsc else frame.sortKey, frame.sortAsc = key, true end
		refreshTab(frame)
	end
	local hr = UI.CreateHeaderRow(frame, guildColumns(), 1, UI.HEADER_Y, onSort, { id = "guilds", onLayout = function(h)
		-- rows and the scroll area follow the new total width
		if frame.content then frame.content:SetWidth(math.max(frame.scroll:GetWidth() or 0, h.total)) end
		for _, r in ipairs(frame.rows or {}) do r:SetWidth(h.total) end
		for _, r in ipairs(frame.groupRows or {}) do r:SetWidth(h.total) end
		for _, r in ipairs(frame.exclRows or {}) do r:SetWidth(h.total) end
	end })
	frame.header = hr
	frame.headerButtons = hr.sortables
	frame.columns, frame.columnX = hr.w, hr.x

	local scroll, content = UI.ScrollList(frame, "PSSGuildListScroll", hr.total)
	frame.scroll = scroll
	frame.content = content
	frame.rows = {}
	frame.groupRows = {}
	frame.exclRows = {}
end

-- Remove Guild and Block History on the bottom bar.
local function buildGuildBottomBar(frame)
	local removeBtn = UI.BarButton(frame, "Remove Guild")
	removeBtn:SetScript("OnClick", function()
		if frame.selectedGuildKey then M.PSS_RemoveGuildNow(frame.selectedGuildKey) end
	end)
	removeBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Remove Guild", 1, 1, 1)
		GameTooltip:AddLine("Removes the selected guild rule straight away.", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	removeBtn:SetScript("OnLeave", hideTip)
	frame.removeButton = removeBtn

	local histButton = UI.BarButton(frame, L["BUT_9"] or "Block History", removeBtn, nil, "PSSGuildBlockHistoryButton")
	histButton:SetScript("OnClick", function()
		if M.PSS_ShowGuildHistoryPanel then M.PSS_ShowGuildHistoryPanel(frame.selectedGuildKey) end
	end)
	histButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Block History", 1, 1, 1)
		GameTooltip:AddLine("Click a guild first to see only that guild. With no guild selected, every guild's history is shown.", nil, nil, nil, true)
		GameTooltip:AddLine("Double-click a guild for its members and each member's own history.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	histButton:SetScript("OnLeave", hideTip)
	frame.historyButton = histButton
	frame.listButtons = { removeBtn, histButton }
end

-- The shared Block History panel (PSS_ChatHistoryUI.lua), in place of the list.
local function buildGuildHistoryPanel(frame)
	local function setListShown(on)
		frame.header:SetShown(on)
		frame.scroll:SetShown(on)
		for _, b in ipairs(frame.listButtons) do b:SetShown(on) end
	end
	local hist = History.CreatePanel(frame, {
		baseTitle = "",
		allText = "all guilds", allButton = "All Guilds",
		setListShown = setListShown,
		entries = function(key) return M.PSS_GetGuildBlockHistory(key) end,
		label = function(key)
			local g = PourSocialScoreDB.guildData[key]
			return g and tostring(g.name or key) or nil
		end,
		reset = function(key)
			if key then
				M.PSS_ResetGuildBlockHistory(key)
			else
				for k in pairs(PourSocialScoreDB.guildData or {}) do M.PSS_ResetGuildBlockHistory(k) end
				if M.PSS_Stats then M.PSS_Stats.Reset("guild") end
			end
		end,
		extra = { text = "Show Members", onClick = function(key) if key then M.PSS_ShowGuildDetail(key) end end,
					shown = function(key) return key ~= nil end },
	})
	frame.histPanel = hist
	frame.updateHistoryPanel = function(resetScroll) hist:Refresh(resetScroll) end
	function M.PSS_ShowGuildHistoryPanel(guildKey)
		if not frame:IsShown() then return end
		hist:Open(guildKey)
	end
	frame.closeHistoryPanel = function() hist:Close() end
end

-- The selected row is highlighted; Remove Guild needs a removable selection.
local function updateGuildSelection(frame)
	for _, r in ipairs(frame.rows) do
		r:SetSelected(r:IsShown() and r.guildKey ~= nil and r.guildKey == frame.selectedGuildKey)
	end
	local sel = frame.selectedGuildKey
	frame.removeButton:SetEnabled(sel ~= nil and PourSocialScoreDB.guildData[sel] ~= nil and not isStaticGuild(sel))
end

---------------------------------------------------------------- managed group headers
-- One collapsible row per managed group ("Olympus"); its guilds are listed
-- under it when expanded. Left-click toggles, right-click for options.
local function makeGroupRow(frame, i)
	local hr = frame.header
	local row = UI.CreateRow(frame.content, hr.total)
	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(row)
	bg:SetColorTexture(1, 0.82, 0, 0.08)
	row.label = UI.TCell(row, hr, "guild", "LEFT", "GameFontNormal")
	row.count = UI.TCell(row, hr, "members", "RIGHT")
	row.blocks = UI.CreateMetricCells(row, hr)
	row.state = UI.TCell(row, hr, "excl", "CENTER")
	row:SetScript("OnClick", function(self, button)
		local k = self.groupKey
		if not k then return end
		if button == "RightButton" then
			local on = M.PSS_ManagedGroupActive and M.PSS_ManagedGroupActive(k)
			MenuUtil.CreateContextMenu(UIParent, function(owner, root)
				root:CreateTitle(self.groupName or k)
				root:CreateButton(on and "Turn rule Off" or "Turn rule On", function()
					M.PSS_SetManagedGroupActive(k, not on)
					refreshTab(frame)
				end)
				root:CreateButton(groupOpen(k) and "Collapse" or "Expand", function()
					setGroupOpen(k, not groupOpen(k))
					refreshTab(frame)
				end)
			end)
			return
		end
		setGroupOpen(k, not groupOpen(k))
		refreshTab(frame)
	end)
	row:SetScript("OnEnter", function(self)
		local k = self.groupKey
		if not k then return end
		local grp = M.PSS_ManagedGroups()[k] or {}
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:AddLine(self.groupName or k, 1, 0.82, 0)
		GameTooltip:AddLine(("Default guild list. Rule on the Chat Filters tab: %s (%s)."):format(tostring(grp.rule), tostring(grp.filter)), 1, 1, 1, true)
		GameTooltip:AddLine(M.PSS_ManagedGroupActive(k) and "|cff00ff00Rule is ON|r - its guilds are blocked (minus each guild's exclusions)."
			or "|cffff5555Rule is OFF|r - nothing in this group is blocked.", 1, 1, 1, true)
		GameTooltip:AddLine("Click to expand / collapse. Right-click to turn the rule on or off.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", hideTip)
	frame.groupRows[i] = row
	return row
end

---------------------------------------------------------------- exclusion list
-- One collapsible "Guild Exclusion List" row (styled like a managed group)
-- with its guilds listed under it when expanded.
local function removeExclusion(name)
	if M.PSS_RemoveGuildExclusion(name) then
		M.ChatMsg(("PSS: <%s> removed from the Guild Exclusion List."):format(name))
	end
end

local function makeExclHeader(frame)
	local hr = frame.header
	local row = UI.CreateRow(frame.content, hr.total)
	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(row)
	bg:SetColorTexture(0.3, 0.8, 1, 0.08)
	row.label = UI.TCell(row, hr, "guild", "LEFT", "GameFontNormal")
	row.state = UI.TCell(row, hr, "excl", "CENTER")
	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			MenuUtil.CreateContextMenu(UIParent, function(owner, root)
				root:CreateTitle("Guild Exclusion List")
				root:CreateButton(groupOpen(EXCL_OPEN_KEY) and "Collapse" or "Expand", function()
					setGroupOpen(EXCL_OPEN_KEY, not groupOpen(EXCL_OPEN_KEY))
					refreshTab(frame)
				end)
			end)
			return
		end
		setGroupOpen(EXCL_OPEN_KEY, not groupOpen(EXCL_OPEN_KEY))
		refreshTab(frame)
	end)
	row:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:AddLine("Guild Exclusion List", 0.3, 0.8, 1)
		GameTooltip:AddLine("Guilds that no guild rule ever blocks, captures or scans in, even a rule whose name they contain or a default list such as Olympus.", 1, 1, 1, true)
		GameTooltip:AddLine("Add guilds with the second row of Guild Search / Add Guild (the \"Exclude a Guild...\" box).", 0.7, 0.7, 0.7, true)
		GameTooltip:AddLine("Click to expand / collapse. Right-click a guild under it to remove it.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", hideTip)
	frame.exclHeader = row
	return row
end

local function makeExclRow(frame, i)
	local hr = frame.header
	local row = UI.CreateRow(frame.content, hr.total)
	row.name = UI.TCell(row, hr, "guild")
	row.state = UI.TCell(row, hr, "excl", "CENTER")
	row.remove = UI.TRowButton(row, hr, "scan", "Remove")
	row.remove:SetScript("OnClick", function() if row.exclName then removeExclusion(row.exclName) end end)
	row:SetScript("OnClick", function(self, button)
		if button ~= "RightButton" or not self.exclName then return end
		local name = self.exclName
		MenuUtil.CreateContextMenu(UIParent, function(owner, root)
			root:CreateTitle(name)
			root:CreateButton("Remove from Exclusion List", function() removeExclusion(name) end)
		end)
	end)
	row:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:AddLine(self.exclName or "", 1, 1, 1)
		GameTooltip:AddLine("Excluded: never blocked by a guild rule.", 0.3, 0.8, 1, true)
		GameTooltip:AddLine("Right-click or Remove to take it off the list.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", hideTip)
	frame.exclRows[i] = row
	return row
end

---------------------------------------------------------------- rows
local function guildRowMenu(frame, row)
	local guildKey = row.guildKey
	local guildName = row.guildName or guildKey
	frame.selectedGuildKey = guildKey
	frame.updateSelection()
	local historyCount = #M.PSS_GetGuildBlockHistory(guildKey)
	MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
		root:CreateTitle(guildName)
		root:CreateDivider()
		root:CreateButton(L["HISTORY_GUILD"] .. " (" .. historyCount .. ")", function()
			if M.PSS_ShowGuildHistoryPanel then M.PSS_ShowGuildHistoryPanel(guildKey) end
		end)
		root:CreateButton("Show Members", function()
			if M.PSS_ShowGuildDetail then M.PSS_ShowGuildDetail(guildKey) end
		end)
		root:CreateDivider()
		root:CreateButton(L["HISTORY_RESET"], function()
			if M.PSS_ResetGuildBlockHistory then M.PSS_ResetGuildBlockHistory(guildKey or guildName) end
		end)
		if not isStaticGuild(guildKey) then
			root:CreateButton("Remove Guild", function() frame.removeButton:Click() end)
		end
		local gRec = guildKey and PourSocialScoreDB.guildData[guildKey]
		if gRec and M.PSS_AddOverrideMenu then
			M.PSS_AddOverrideMenu(root, gRec, "guild")
		end
	end)
end

local function makeGuildRow(frame, i)
	local hr = frame.header
	local row = UI.CreateRow(frame.content, hr.total)
	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then guildRowMenu(frame, self) return end
		local now = GetTime()
		if self._lastClick and self._lastClickKey == self.guildKey and now - self._lastClick < 0.35 then
			self._lastClick = nil
			frame.selectedGuildKey = self.guildKey
			frame.updateSelection()
			if M.PSS_ShowGuildDetail then M.PSS_ShowGuildDetail(self.guildKey) end
		else
			frame.selectedGuildKey = self.guildKey
			frame.updateSelection()
			self._lastClick = now
			self._lastClickKey = self.guildKey
		end
	end)

	row.name = UI.TCell(row, hr, "guild")
	row.count = UI.TCell(row, hr, "members", "RIGHT")
	row.blocks = UI.CreateMetricCells(row, hr)

	row.ex = UI.CreateExclusionBoxes(row, hr, "excl", function(box, cat)
		if row.guildKey then M.PSS_SetGuildBlock(row.guildKey, cat, UI.ExclBlocked(box)) end
	end, function(box, e)
		GameTooltip:AddLine(e.letter .. " - " .. e.label, 1, 1, 1, true)
		GameTooltip:AddLine(box:GetChecked() and "|cff00ff00Allowed|r for this guild." or "|cffff5555Blocked|r for this guild.", 1, 1, 1)
	end)

	row.scan = UI.TRowButton(row, hr, "scan", "Scan")
	row.scan:SetScript("OnLeave", function() M.PSS_ScanTipLeave() end)

	-- Custom Scan Fields: one free-text /who filter
	row.customScan = UI.TRowEditBox(row, hr, "fields", 128)
	row.customScan:SetAltArrowKeyMode(false)
	row.customScan:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Custom Scan Fields", 1, 1, 1)
		GameTooltip:AddLine("Extra /who filters sent with the guild name when you press Custom.", nil, nil, nil, true)
		GameTooltip:AddLine('Sent as: g-"' .. tostring(row.guildName or "Guild") .. '" <this text>', 0.7, 0.7, 0.7, true)
		GameTooltip:AddLine('Examples: 80   70-80   80 c-"Mage"   r-"Orc"   n-"ab"', 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	row.customScan:SetScript("OnLeave", hideTip)

	row.customScanButton = UI.TRowButton(row, hr, "custom", "Scan")

	registerGuildScanButton(row.scan)
	registerGuildScanButton(row.customScanButton)
	frame.rows[i] = row
	return row
end

---------------------------------------------------------------- list contents
-- Every guild rule as { key, g, bc }: the top-level ones, and each managed
-- group's under groups[group key].
local function collectGuilds()
	local list, groups = {}, {}
	for key, g in pairs(PourSocialScoreDB.guildData or {}) do
		if type(g) == "table" then
			g.memberCount = M.PSS_GuildMemberCount(g, key)
			local item = { key = key, g = g, bc = M.PSS_GetGuildBlockCounts(key) }
			if g.managed then
				groups[g.managed] = groups[g.managed] or {}
				table.insert(groups[g.managed], item)
			else
				list[#list + 1] = item
			end
		end
	end
	return list, groups
end

-- Sorts items in place by the tab's sort column; ties by guild name A-Z.
local function sortGuildItems(frame, items)
	local sortKey, asc = frame.sortKey or "guild", frame.sortAsc ~= false
	local group, cat = sortKey:match("^(%a+):(%a+)$")
	local function flag(v) return UI.ExclChecked(v == true) and 1 or 0 end		-- by tick (allowed)
	local function sortValue(item)
		local g, bc = item.g, item.bc
		if group == "metric" then return bc[cat] or 0
		elseif group == "excl" then return flag(guildBlock(g)[cat])
		elseif sortKey == "guild" then return string.lower(g.name or item.key or "")
		elseif sortKey == "members" then return g.memberCount or 0
		elseif sortKey == "scan" then return M.PSS_GuildSweepSent(item.key)
		elseif sortKey == "fields" then return string.lower(g.customScan or "")
		elseif sortKey == "custom" then return ((g.customScan or "") ~= "") and 1 or 0
		end
		return 0
	end
	for _, item in ipairs(items) do
		item.sv = sortValue(item)
		item.nv = string.lower(item.g.name or item.key or "")
	end
	table.sort(items, function(a, b)
		if a.sv ~= b.sv then
			if asc then return a.sv < b.sv else return a.sv > b.sv end
		end
		-- ties: always guild name A-Z (then key, so the order is stable)
		if a.nv ~= b.nv then return a.nv < b.nv end
		return tostring(a.key) < tostring(b.key)
	end)
end

-- Display order: managed groups (headers) first, then the Guild Exclusion
-- List, then the other guilds.
local function guildDisplayList(frame, list, groups)
	local display = {}
	local gkeys = {}
	for k in pairs(groups) do gkeys[#gkeys + 1] = k end
	table.sort(gkeys)
	for _, k in ipairs(gkeys) do
		local items = groups[k]
		sortGuildItems(frame, items)
		local grp = M.PSS_ManagedGroups()[k] or {}
		local total, bc = 0, History.EmptyCounts()
		for _, it in ipairs(items) do
			total = total + (it.g.memberCount or 0)
			for c, v in pairs(it.bc) do bc[c] = (bc[c] or 0) + (tonumber(v) or 0) end
		end
		local open = groupOpen(k)
		display[#display + 1] = { header = true, groupKey = k, name = grp.name or k, guilds = #items, members = total, bc = bc, open = open }
		if open then
			local on = M.PSS_ManagedGroupActive(k)
			for _, it in ipairs(items) do it.inGroup = true; it.groupOn = on; display[#display + 1] = it end
		end
	end
	-- then the Guild Exclusion List (always shown, so it can be found)
	local excluded = M.PSS_GuildExclusions()
	local exclOpen = groupOpen(EXCL_OPEN_KEY)
	display[#display + 1] = { exclHeader = true, count = #excluded, open = exclOpen }
	if exclOpen then
		for _, name in ipairs(excluded) do display[#display + 1] = { exclItem = true, name = name } end
	end
	for _, it in ipairs(list) do display[#display + 1] = it end
	return display
end

local function placeRow(frame, row, i)
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(i - 1) * UI.ROW_H)
end

-- One guild rule's row: its cells, and the Scan / Custom Scan actions.
local function fillGuildRow(row, item)
	local g, key = item.g, item.key
	row.guildName = g.name
	row.guildKey = key
	row.name:SetText((item.inGroup and "      " or "") .. tostring(g.name))
	row.count:SetText(tostring(g.memberCount or 0))
	UI.SetMetricCells(row.blocks, item.bc)
	local gb = guildBlock(g)
	for c, box in pairs(row.ex) do box:SetChecked(UI.ExclChecked(gb[c] == true)) end
	if not row.customScan:HasFocus() then row.customScan:SetText(g.customScan or "") end
	row.scan:SetText(M.PSS_GuildSweepLabel(key))
	row.customScanButton:SetText("Scan")
	row.scan:SetEnabled(not M.PSS_ScanCooldownActive())
	row.customScanButton:SetEnabled(not M.PSS_ScanCooldownActive())
	-- a group whose rule is off: shown dimmed (nothing is blocked)
	row:SetAlpha((item.inGroup and not item.groupOn) and 0.55 or 1)
	row:Show()

	local function readCustom()
		-- reads the box into the saved setting; no widget changes
		g.customScan = trim(row.customScan:GetText() or "")
	end
	row.customScan:SetScript("OnEnterPressed", function(self) readCustom(); self:ClearFocus() end)
	row.customScan:SetScript("OnEditFocusLost", readCustom)
	row.scan:SetScript("OnClick", function()
		if M.PSS_ScanBlockedMsg() then return end
		M.PSS_ScanGuild(g.name, "sweep", IsShiftKeyDown())		-- /who first, UI after
	end)
	row.scan:SetScript("OnEnter", function(self) M.PSS_ScanTipEnter(self, g) end)
	row.customScanButton:SetScript("OnClick", function()
		if M.PSS_ScanBlockedMsg() then return end
		readCustom()
		M.PSS_ScanGuild(g.name, "custom")	-- /who first, UI after
		C_Timer.After(0, function() row.customScan:ClearFocus() end)
	end)
end

local function refreshGuildList(frame)
	ensureDB()
	-- Nothing to draw while hidden; OnShow refreshes.
	if not frame:IsVisible() then return end

	local S = M.PSS_Stats
	frame.stats:Set(1, S and S.Session("guild"))
	frame.stats:Set(2, S and S.Last24("guild"))
	frame.stats:Set(3, M.PSS_GetGuildBlockCounts())
	if frame.histPanel:IsShown() then frame.updateHistoryPanel() end

	for _, row in ipairs(frame.rows) do row:Hide() end
	for _, row in ipairs(frame.groupRows) do row:Hide() end
	for _, row in ipairs(frame.exclRows) do row:Hide() end
	if frame.exclHeader then frame.exclHeader:Hide() end

	local list, groups = collectGuilds()
	sortGuildItems(frame, list)
	frame.header:SetSort(frame.sortKey or "guild", frame.sortAsc ~= false)
	if frame.selectedGuildKey and not PourSocialScoreDB.guildData[frame.selectedGuildKey] then
		frame.selectedGuildKey = nil
	end
	local display = guildDisplayList(frame, list, groups)

	frame.content:SetWidth(math.max(frame.scroll:GetWidth() or 0, frame.header.total))
	frame.content:SetHeight(math.max(1, #display * UI.ROW_H))

	local gi, hi, ei = 0, 0, 0
	for i, item in ipairs(display) do
		if item.exclHeader then
			local row = frame.exclHeader or makeExclHeader(frame)
			placeRow(frame, row, i)
			row.label:SetText((item.open and "[-] " or "[+] ") .. "Guild Exclusion List" .. ("  |cffaaaaaa(%d guilds)|r"):format(item.count))
			row.state:SetText("|cff4dccffNever blocked|r")
			row:Show()
		elseif item.exclItem then
			ei = ei + 1
			local row = frame.exclRows[ei] or makeExclRow(frame, ei)
			row.exclName = item.name
			placeRow(frame, row, i)
			row.name:SetText("      " .. item.name)
			row.state:SetText("|cff4dccffExcluded|r")
			row:Show()
		elseif item.header then
			hi = hi + 1
			local row = frame.groupRows[hi] or makeGroupRow(frame, hi)
			row.groupKey, row.groupName = item.groupKey, item.name
			placeRow(frame, row, i)
			row.label:SetText((item.open and "[-] " or "[+] ") .. item.name .. ("  |cffaaaaaa(%d guilds)|r"):format(item.guilds))
			row.count:SetText(tostring(item.members))
			UI.SetMetricCells(row.blocks, item.bc)
			local on = M.PSS_ManagedGroupActive(item.groupKey)
			row.state:SetText(on and "|cff00ff00Rule ON|r" or "|cffff5555Rule OFF|r")
			row:Show()
		else
			gi = gi + 1
			local row = frame.rows[gi] or makeGuildRow(frame, gi)
			placeRow(frame, row, i)
			fillGuildRow(row, item)
		end
	end
	frame.updateSelection()
end

function M.PSS_BuildGuildUI(parent)
	if M.PSSGuildTabFrame then return M.PSSGuildTabFrame end

	-- Same panel as every other tab (see PSS_UIKit.lua).
	local frame = CreateFrame("Frame", "PSSGuildTabFrame", parent, "InsetFrameTemplate")
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -84)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -11, 29)
	M.PSSGuildTabFrame = frame

	-- no title in list view (the tab says where you are); Block History uses it
	frame.title = UI.CreateSummary(frame, "", 700)
	frame.stats = UI.CreateBlockStats(frame, parent, UI.STATS_BLOCK_CATS, "messages and invites")

	buildGuildEntryRows(frame)
	buildGuildList(frame)
	buildGuildBottomBar(frame)
	buildGuildHistoryPanel(frame)
	frame.updateSelection = function() updateGuildSelection(frame) end

	local function refresh() refreshGuildList(frame) end
	frame:SetScript("OnShow", function()
		-- Always come back to the list view, sorted by guild name A-Z.
		frame.closeHistoryPanel()
		frame.sortKey, frame.sortAsc = "guild", true
		refresh()
	end)
	-- Re-flow the list when the main window is resized.
	frame:SetScript("OnSizeChanged", function(self, w)
		if w and w > 0 then frame.header:SetAvailableWidth(w - 28) end
		if frame:IsVisible() then refresh() end
	end)
	frame.refresh = refresh
	M.PSSUpdateGuildUI = refresh
	refresh()
	return frame
end

-- Guild members window columns (W I G P C = the Player Ignore List header)
local MEMBER_COLS = {
	{ key = "name",		text = "Name",		width = 150 },
	{ key = "guild",	text = "Guild",		width = 120 },
	{ key = "added",	text = "Added",		width = 124 },
	{ key = "note",		text = "Note",		width = 130 },
}
-- block metrics (same columns as the Player and Guild Ignore Lists), then W I G P C
for _, c in ipairs(M.UI.MetricColumns()) do MEMBER_COLS[#MEMBER_COLS + 1] = c end
for _, c in ipairs({
	{ key = "excl",		letters = "excl", width = 154, lettersTitle = "Per-player exclusions",
		lettersNote = "Ticked = allowed from that player, unticked = blocked. Dimmed boxes follow the guild's setting; click one to set it for that player, right-click to go back to the guild's setting." },
	{ key = "addGuild", text = "Guild Rule", width = 90, tip = "Add Guild appears when the player's actual guild is not this rule: it creates a rule for that guild and moves its members there." },
}) do MEMBER_COLS[#MEMBER_COLS + 1] = c end

function M.PSS_ShowGuildDetail(guildNameOrKey)
	ensureDB()
	local UI = M.UI

	-- Prefer the exact persisted guild key. This avoids accidentally creating a
	-- new empty guild object when a UI row is opened after a scan.
	local requestedKey = normalizeGuild(guildNameOrKey)
	local g = requestedKey and PourSocialScoreDB.guildData and PourSocialScoreDB.guildData[requestedKey]
	if not g then
		-- Compatibility: callers may still pass the display name.
		for key, candidate in pairs(PourSocialScoreDB.guildData or {}) do
			if normalizeGuild(candidate.name) == requestedKey then
				requestedKey, g = key, candidate
				break
			end
		end
	end
	if not g then return end

	g.members = g.members or {}
	local guildKey = requestedKey

	local f = M.PSSGuildDetailFrame
	if not f then
		-- Same window style as the main window. Above the main window whatever
		-- strata it was given in Options, so nothing can sit over this one.
		local hrWidth = 0
		for _, c in ipairs(MEMBER_COLS) do hrWidth = hrWidth + c.width end
		local winW = hrWidth + 2 + 28 + 19
		f = UI.CreateWindow("PSSGuildDetailFrame", "Guild Members", winW, 560,
			{ strata = "FULLSCREEN", minW = winW, minH = 320, saveKey = "guildDetail" })
		M.PSSGuildDetailFrame = f
		local inset = f.inset

		f.heading, f.count = UI.CreateSummary(inset, "", 360)
		-- the guild's block metrics (same table as every player/guild report)
		f.metrics = UI.CreateMetricsTable(inset)
		f.metrics:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -6)

		local search = UI.SearchBox(inset)
		search:ClearAllPoints()
		search:SetPoint("TOPRIGHT", f.metrics, "TOPLEFT", -20, 1)
		search:SetScript("OnTextChanged", function() if f.refresh then f.refresh() end end)
		f.search = search
		local hint = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hint:SetPoint("RIGHT", search, "LEFT", -10, 0)
		hint:SetText("Search:")

		f.sortKey, f.sortAsc = "name", true
		local function onSort(key)
			if f.sortKey == key then f.sortAsc = not f.sortAsc else f.sortKey, f.sortAsc = key, true end
			if f.refresh then f.refresh() end
		end
		f.hr = UI.CreateHeaderRow(inset, MEMBER_COLS, 1, UI.HEADER_Y, onSort, { id = "members", onLayout = function(h)
			f.tableWidth = h.total
			if f.content then f.content:SetWidth(math.max(f.scroll:GetWidth() or 0, h.total)) end
			for _, r in ipairs(f.rows or {}) do r:SetWidth(h.total) end
		end })
		f.tableWidth = f.hr.total
		inset:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then f.hr:SetAvailableWidth(w - 28) end end)

		local scroll, content = UI.ScrollList(inset, nil, f.tableWidth)
		f.scroll = scroll; f.content = content; f.rows = {}

		-- bottom bar: Remove Member (right), Block History
		local removeBtn = UI.BarButton(inset, "Remove Member")
		removeBtn:SetScript("OnClick", function()
			local r = f.selectedRow
			if r and r.member and M.PSS_RemoveGuildMember then
				M.PSS_RemoveGuildMember(f.guildKey, r.memberName, r.memberGuildKey, r.storedKey)
				f.selectedMember = nil
				if f.refresh then f.refresh() end
				if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
			end
		end)
		removeBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Remove Member", 1, 1, 1)
			GameTooltip:AddLine("Removes the selected player from this guild rule (not from the Player Ignore List).", nil, nil, nil, true)
			GameTooltip:Show()
		end)
		removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.removeButton = removeBtn

		local histBtn = UI.BarButton(inset, L["BUT_9"] or "Block History", removeBtn)
		histBtn:SetScript("OnClick", function()
			local m = f.selectedMember
			if m then
				M.PSS_ShowMemberBlockHistory(m, (m.guild and m.guild ~= "") and m.guild or f.guildName)
			elseif f.guildKey then
				M.PSS_ShowGuildBlockHistory(f.guildKey)
			end
		end)
		histBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Block History", 1, 1, 1)
			GameTooltip:AddLine("Click a player first to see only that player. With no player selected, the whole guild's history is shown.", nil, nil, nil, true)
			GameTooltip:Show()
		end)
		histBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

		-- show each W I G P C box: ticked = allowed (own choice or the
		-- guild's), dimmed = following the guild's setting
		function f.paintExclusions(r)
			local m = r.member
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			if not m or not gg or not r.ex then return end
			local own = memberBlock(m)
			for cat, c in pairs(r.ex) do
				c:SetChecked(UI.ExclChecked(memberBlocks(gg, m, cat)))
				c:SetAlpha(own[cat] == nil and 0.45 or 1)
			end
		end
		function f.updateSelection()
			f.selectedRow = nil
			for _, r in ipairs(f.rows) do
				local sel = r:IsShown() and r.member ~= nil and r.member == f.selectedMember
				r:SetSelected(sel)
				if sel then f.selectedRow = r end
			end
			removeBtn:SetEnabled(f.selectedRow ~= nil)
		end
	end

	f.guildKey = guildKey
	f.guildName = g.name or guildNameOrKey
	f.title:SetText("Guild Members: " .. tostring(f.guildName))
	if f.lastGuildKey ~= guildKey then f.selectedMember = nil end
	f.lastGuildKey = guildKey
	f:Show(); f:Raise()

	local function collectMembers()
		local all = {}
		local gg = PourSocialScoreDB.guildData[f.guildKey]
		if not gg or type(gg.members) ~= "table" then return all end
		-- Each guild rule shows ONLY the members stored under that rule
		-- (plus, for a managed guild, its shipped members).
		forEachMember(gg, f.guildKey, function(m, key)
			all[#all + 1] = { member = m, sourceKey = f.guildKey, storedKey = key }
		end, true)
		return all
	end

	local function sortValue(entry, key)
		local m = entry.member
		local mcat = key:match("^metric:(.+)$")
		if mcat then return tonumber(M.PSS_GetMemberBlockCounts(m)[mcat]) or 0 end
		local cat = key:match("^excl:(.+)$")
		if cat then
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			return UI.ExclChecked(gg and memberBlocks(gg, m, cat)) and 1 or 0	-- by tick (allowed)
		elseif key == "name" then return string.lower(m.name or "")
		elseif key == "guild" then return string.lower(m.guild or "")
		elseif key == "note" then return string.lower(m.note or "")
		elseif key == "added" then return parseTimeString(m.whenBlocked) or 0
		elseif key == "addGuild" then
			-- members whose actual guild differs from this rule (Add Guild shown)
			local ag = normalizeGuild(m.guild or "")
			return (ag and ag ~= "" and ag ~= normalizeGuild(f.guildName)) and 1 or 0
		end
		return 0
	end

	-- Save a note box into its member record.
	local function commitNote(r)
		if not r or not r.note or not r.member then return end
		local text = trim(r.note:GetText() or ""):sub(1, 25)
		if (r.member.note or "") ~= text then keepManaged(r.member) end
		r.member.note = (text ~= "") and text or nil
	end
	f.commitNote = commitNote

	local function makeRow(i)
		local hr = f.hr
		local r = UI.CreateRow(f.content, f.tableWidth)
		r:SetScript("OnClick", function(self, button)
			f.selectedMember = self.member
			f.updateSelection()
			if button == "RightButton" then
				-- per-player option overrides
				if self.member and M.PSS_AddOverrideMenu then
					MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
						root:CreateTitle(tostring(self.member.name))
						root:CreateButton(L["BUT_9"] or "Block History", function()
							M.PSS_ShowMemberBlockHistory(self.member, (self.member.guild ~= "" and self.member.guild) or f.guildName)
						end)
						M.PSS_AddOverrideMenu(root, self.member, "person")
					end)
				end
				return
			end
			local now = GetTime()
			if self._lastClick and now - self._lastClick < 0.35 and self.member then
				self._lastClick = nil
				M.PSS_ShowMemberBlockHistory(self.member, (self.member.guild ~= "" and self.member.guild) or f.guildName)
			else
				self._lastClick = now
			end
		end)
		r:SetScript("OnEnter", function(self)
			local m = self.member
			if not m then return end
			local c = M.PSS_GetMemberBlockCounts(m)
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine("Blocked from " .. tostring(m.name), 1, 1, 1)
			for _, cat in ipairs(CAT_ORDER) do
				GameTooltip:AddDoubleLine(CAT_LABEL[cat], tostring(c[cat] or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			end
			GameTooltip:AddLine("Double-click for this player's block history.", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)

		r.name = UI.TCell(r, hr, "name")
		r.guild = UI.TCell(r, hr, "guild")
		r.added = UI.TCell(r, hr, "added")

		-- Note (max 25 characters), saved on the member record
		r.note = UI.TRowEditBox(r, hr, "note", 25)
		r.note:SetScript("OnEditFocusGained", function() f.editingRow = r end)
		r.note:SetScript("OnEditFocusLost", function()
			f.commitNote(r)
			if f.editingRow == r then f.editingRow = nil end
			if f.refreshPending and f.refresh then f.refresh() end
		end)
		r.note:SetScript("OnEnterPressed", function(self) f.commitNote(r); self:ClearFocus() end)
		r.note:SetScript("OnEscapePressed", function(self)
			self:SetText(r.member and r.member.note or "")
			self:ClearFocus()
		end)

		-- W I G P C, bound to the member RECORD on this row (never a name
		-- lookup - realm spellings vary).
		r.ex = UI.CreateExclusionBoxes(r, hr, "excl", function(box, cat, button)
			local m = r.member
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			if not m or not gg then return end
			if button == "RightButton" then
				M.PSS_SetMemberBlock(gg, m, cat, nil)
			else
				M.PSS_SetMemberBlock(gg, m, cat, UI.ExclBlocked(box))
			end
			f.paintExclusions(r)
			if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
			if box:IsMouseOver() and box:GetScript("OnEnter") then box:GetScript("OnEnter")(box) end
		end, function(box, e)
			local m = r.member
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			GameTooltip:AddLine(e.letter .. " - " .. e.label, 1, 1, 1, true)
			if not m or not gg then return end
			local own = memberBlock(m)[e.cat]
			if own == nil then
				GameTooltip:AddLine("Following the guild: " .. (guildBlock(gg)[e.cat] and "|cffff5555blocked|r" or "|cff00ff00allowed|r"), 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Click to set it for this player.", 0.7, 0.7, 0.7)
			else
				GameTooltip:AddLine("Set for this player: " .. (own and "|cffff5555blocked|r" or "|cff00ff00allowed|r"), 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Right-click to follow the guild's setting again.", 0.7, 0.7, 0.7)
			end
		end)

		r.metrics = UI.CreateMetricCells(r, f.hr)

		r.addGuild = UI.TRowButton(r, hr, "addGuild", "Add Guild")
		r.addGuild:SetScript("OnClick", function()
			local actual = r.memberGuild
			local base = normalizeGuild(f.guildName)
			if actual and actual ~= "" and normalizeGuild(actual) ~= base and M.PSS_AddCapturedGuild then
				local srcG = PourSocialScoreDB.guildData[f.guildKey]
				local added, migrated, removedRefs, perSource, leftover = M.PSS_AddCapturedGuild(actual, srcG and srcG.managed)
				do
					local from = {}
					for _, s in ipairs(perSource or {}) do
						from[#from + 1] = ("%s (%d)"):format(s.name, s.moved)
					end
					M.ChatMsg(("PSS: Added guild %q. Added %d new member(s) (%d total matched). Removed %d old record(s)%s. Blocked history moved with them."):format(
						actual, added or 0, migrated or 0, removedRefs or 0,
						#from > 0 and (" from: " .. table.concat(from, ", ")) or ""))
					if (leftover or 0) > 0 then
						M.ChatMsg(("PSS: WARNING - %d old record(s) for %q could not be removed."):format(leftover, actual))
					end
				end
				if f.refresh then f.refresh() end
			end
		end)
		f.rows[i] = r
		return r
	end

	local function refresh(auto)
		if not PourSocialScoreDB.guildData[f.guildKey] then
			-- guild rule was removed while the window was open
			f:Hide()
			return
		end
		if f.editingRow then
			if auto then
				-- background refresh (a block came in) while a note is being
				-- typed: wait until editing finishes so rows don't move under it
				f.refreshPending = true
				return
			end
			local er = f.editingRow
			commitNote(er)
			f.editingRow = nil
			er.note:ClearFocus()
		end
		f.refreshPending = false
		local query = string.lower(trim(f.search:GetText() or ""))
		local rows = collectMembers()
		local filtered = {}
		for _, entry in ipairs(rows) do
			local m = entry.member
			local hay = string.lower((m.name or "") .. " " .. (m.guild or "") .. " " .. (m.note or ""))
			if query == "" or hay:find(query, 1, true) then filtered[#filtered + 1] = entry end
		end
		local key, asc = f.sortKey or "name", f.sortAsc ~= false
		for _, e in ipairs(filtered) do e.sv = sortValue(e, key); e.nv = string.lower(e.member.name or "") end
		table.sort(filtered, function(a, b)
			if a.sv ~= b.sv then
				if asc then return a.sv < b.sv else return a.sv > b.sv end
			end
			return a.nv < b.nv		-- stable tie-break by name
		end)
		f.hr:SetSort(key, asc)

		f.heading:SetText("Members of |cffffff00" .. tostring(f.guildName) .. "|r")
		f.count:SetText((#rows) .. " member" .. (#rows == 1 and "" or "s") .. " found" ..
			(query ~= "" and ((" (%d shown)"):format(#filtered)) or ""))
		f.metrics:Set(M.PSS_GetGuildBlockCounts(f.guildKey))
		local rowH = UI.ROW_H
		f.content:SetWidth(math.max(f.scroll:GetWidth() or 0, f.tableWidth))
		f.content:SetHeight(math.max(1, #filtered * rowH))
		for _, r in ipairs(f.rows) do r:Hide() end

		local baseGuild = normalizeGuild(f.guildName)
		for i, entry in ipairs(filtered) do
			local r = f.rows[i] or makeRow(i)
			local m = entry.member
			r.member = m
			r.memberName = m.name
			r.memberGuildKey = entry.sourceKey
			r.storedKey = entry.storedKey
			r.memberGuild = m.guild or ""
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, 0, -(i - 1) * rowH)
			r.name:SetText(m.name or "")
			local cc = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
			if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(1, 1, 1) end
			r.guild:SetText(m.guild or "")
			r.added:SetText(m.whenBlocked or "")
			if not r.note:HasFocus() then r.note:SetText(m.note or "") end
			f.paintExclusions(r)
			UI.SetMetricCells(r.metrics, M.PSS_GetMemberBlockCounts(m))
			local actualGuild = normalizeGuild(m.guild or "")
			r.addGuild:SetShown(actualGuild ~= nil and actualGuild ~= "" and actualGuild ~= baseGuild)
			r:Show()
		end
		f.updateSelection()
	end

	f.refresh = refresh
	if f.search:GetText() ~= "" then
		f.search:SetText("")	-- OnTextChanged refreshes
	end
	refresh()
end
