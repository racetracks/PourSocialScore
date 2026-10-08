------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - GUILD IGNORE LIST TAB
--
-- The guild list (Managed Communities and its default lists, the Guild
-- Exclusion List, the other guilds), Scan All, the Add and Exclude entry
-- rows with Guild Search, the Guild Search results picker in place of the
-- list, and a pane: the list's totals with nothing selected. Libraries
-- (PSS_GuildView.lua) works out every text and does every change; the core
-- says when guilds changed (GUILDS_CHANGED, GUILD_SCAN_DONE, GUILD_REMOVED,
-- GUILD_BLOCKS_CHANGED) and the tab redraws if it shows. Scan buttons are
-- disabled while /who cools down (WHOIS_COOLDOWN).
-- The selected entry's details and a guild's members come in the next
-- stage (B4): until then a selection shows its name and a note.
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M

local DETAIL_W = 380
local TOP_H = 58

local V = M.PSS_GuildListNew()
local cells = {}
local page, list, lf, pane, picker
local scanButtons = {}

ns.TabBuilders = ns.TabBuilders or {}

-- Scan buttons follow the /who cooldown.
local function ScanButton(b)
	scanButtons[#scanButtons + 1] = b
	b:SetEnabled(not M.PSS_ScanCooldownActive())
	return b
end

local ShowDetail

------------------------------------------------------------------------
-- Guild list
------------------------------------------------------------------------
local function Resort()
	local n = V:Resort()
	list:SetSort(V.key, V.asc)
	list:SetCount(n)
	list:SetEmptyText(V.find ~= "" and "Nothing matches the search." or "No guilds yet. Add one above.")
	page.count:SetText(V:CountText())
end

local function DrawRow(row, i)
	local item = V.rows[i]
	local c = row.cells
	row:SetAlpha(1)
	if not item then
		for _, fs in pairs(c) do fs:SetText("") end
		row.sel:Hide()
		return
	end
	M.PSS_GuildRowCells(item, V.find, V.rows.managedHead and true or false, cells)
	c.guild:SetText(cells.guild)
	c.members:SetText(cells.members)
	c["metric:total"]:SetText(cells.total)
	c.scan:SetText(cells.scan)
	-- a group whose rule is off: dimmed (nothing in it is blocked)
	if cells.dim then row:SetAlpha(0.55) end
	row.sel:SetShown(V:IsSel(item))
end

local function RowTip(row, i)
	local item = V.rows[i]
	if item then ns.Tip(row, M.PSS_GuildRowTip(item)) end
end

local function Select(kind, value)
	V:Select(kind, value)
	list:Redraw()
	ShowDetail()
end

local function ClickRow(_, i)
	local what = V:Click(V.rows[i])
	if what == "resort" then
		Resort()
	else
		list:Redraw()
	end
	ShowDetail()
end

------------------------------------------------------------------------
-- Pane: the list's totals; a selection's name until B4 draws its details
------------------------------------------------------------------------
local function BuildPane(parent)
	pane = ns.NewPanel(parent, true)
	pane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -TOP_H - 4)
	pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
	pane:SetWidth(DETAIL_W)
	-- nothing selected: every guild's totals (a click on the selected guild
	-- deselects it)
	pane.totals = ns.NewTotals(pane, page, "guilds", "Guild Ignore List", "Select a guild to see its details.",
		M.PSS_AllGuildsSpec)

	local body = CreateFrame("Frame", nil, pane)
	body:SetAllPoints()
	body:Hide()
	pane.body = body
	pane.heading = ns.NewHeading(body, "")
	pane.heading:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -8)
	pane.heading:SetPoint("RIGHT", body, "RIGHT", -10, 0)
	pane.soon = ns.NewText(body, 12)
	pane.soon:SetPoint("CENTER")
	pane.soon:SetAlpha(0.7)
	pane.soon:SetText("Its details come in the next 3.4.0 build.")
end

-- the name of what is selected, or nil
local function SelectedName()
	local kind, sel = V.selKind, V.sel
	if kind == "guild" then
		local _, g = M.PSS_FindGuildRule(sel)
		return g and tostring(g.name or sel) or nil
	elseif kind == "group" or kind == "managed" then
		return M.PSS_GuildGroupLabel(kind == "managed" and M.PSS_GUILD_MANAGED or sel)
	elseif kind == "exclHeader" then
		return "Guild Exclusion List"
	elseif kind == "excl" then
		return M.PSS_IsGuildExcluded(sel) and sel or nil
	end
end

function ShowDetail()
	if not pane then return end
	local name = SelectedName()
	if not name then V:Select(nil, nil) end
	pane.body:SetShown(name and true or false)
	if name then
		pane.heading:SetText(name)
		pane.totals:Hide()
	else
		pane.totals:Show(V.rows.pool and V.rows or nil)
	end
end

------------------------------------------------------------------------
-- Guild Search results (in place of the list)
------------------------------------------------------------------------
local function ClosePicker()
	if not picker:IsShown() then return end
	picker:Hide()
	M.PSS_GuildPickerClose(picker.mode)
	lf:Show()
end

local function DrawPick(row, i)
	local it = picker.items[i]
	local c = row.cells
	if not it then
		for _, fs in pairs(c) do fs:SetText("") end
		row.sel:Hide()
		return
	end
	c.tick:SetText(it.listed and "|cff808080[x]|r" or (it.ticked and "|cff00ff00[x]|r" or "[  ]"))
	c.guild:SetText(it.name)
	c.state:SetText(it.listed and "|cff808080listed|r" or "")
	row.sel:SetShown(it.ticked and not it.listed)
end

local function BuildPicker(parent)
	picker = CreateFrame("Frame", nil, parent)
	picker:SetPoint("TOPLEFT", lf, "TOPLEFT", 0, 0)
	picker:SetPoint("BOTTOMRIGHT", lf, "BOTTOMRIGHT", 0, 0)
	picker:Hide()
	picker.items = {}
	picker.title = ns.NewText(picker, 12)
	picker.title:SetPoint("TOPLEFT", picker, "TOPLEFT", 4, -4)
	picker.title:SetPoint("RIGHT", picker, "RIGHT", -4, 0)
	picker.title:SetJustifyH("LEFT")
	local rf = CreateFrame("Frame", nil, picker)
	rf:SetPoint("TOPLEFT", picker, "TOPLEFT", 0, -24)
	rf:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", 0, 34)
	picker.list = ns.NewRows(rf, {
		rowH = 20, height = 240,
		cols = {
			{ key = "tick", text = "", width = 36, justify = "CENTER" },
			{ key = "guild", text = "Guild" },
			{ key = "state", text = "", width = 70 },
		},
		draw = DrawPick,
		click = function(_, i)
			local it = picker.items[i]
			if it and not it.listed then
				it.ticked = not it.ticked
				picker.list:Redraw()
			end
		end,
	})
	local save = ns.NewButton(picker, "Save", 90, function()
		M.PSS_GuildPickerSave(picker.items, picker.mode)
		ClosePicker()
	end)
	save.pssPrimary = true
	save.pssPaint()
	save:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 4, 4)
	picker.saveButton = save
	local all = ns.NewButton(picker, "Tick All", 90, function()
		for _, it in ipairs(picker.items) do it.ticked = not it.listed end
		picker.list:Redraw()
	end)
	all:SetPoint("LEFT", save, "RIGHT", 6, 0)
	picker.allButton = all
	local cancel = ns.NewButton(picker, "Cancel", 90, ClosePicker)
	cancel:SetPoint("LEFT", all, "RIGHT", 6, 0)
	picker.cancelButton = cancel
end

local function ShowSearchResults(found, query, mode)
	if not found or #found == 0 then
		local text, name = M.PSS_GuildNoneFound(query, mode)
		if text then
			ns.Confirm({ text = text, accept = "Add Anyway", onAccept = function() M.PSS_GuildExcludeAnyway(name) end })
		end
		return
	end
	picker.mode = mode
	M.PSS_GuildPickerItems(found, mode, picker.items)
	picker.title:SetText(M.PSS_GuildPickerTitle(#found, query, mode))
	lf:Hide()
	picker:Show()
	picker.list:SetCount(#picker.items)
	picker.list:Top()
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
local function Refresh()
	if V.dirty then Resort() else list:Redraw() end
	page.count:SetText(V:CountText())
	ShowDetail()
end

-- [box] [Guild Search] [Add]: the top right entry rows
local function EntryRow(pg, y, hintText, addText, onSearch, onAdd, searchTip, addTip)
	local addButton = ns.NewButton(pg, addText, 90)
	addButton:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -8, y)
	local search = ns.NewButton(pg, "Guild Search", 100)
	search:SetPoint("RIGHT", addButton, "LEFT", -6, 0)
	local box = ns.NewEditBox(pg, 150, 64)
	box:SetPoint("RIGHT", search, "LEFT", -8, 0)
	local hint = ns.NewText(box, 12)
	hint:SetPoint("LEFT", box, "LEFT", 2, 0)
	hint:SetAlpha(0.4)
	hint:SetText(hintText)
	box:SetScript("OnTextChanged", function(self) hint:SetShown((self:GetText() or "") == "") end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	-- /who must go out straight from the click (hardware event)
	local function doSearch()
		if onSearch(box:GetText()) then box:SetText("") end
	end
	local function doAdd()
		if onAdd(box:GetText()) then box:SetText("") end
		box:ClearFocus()
	end
	search:SetScript("OnClick", doSearch)
	addButton:SetScript("OnClick", doAdd)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); doSearch() end)
	ns.TipOn(search, search, searchTip)
	ns.TipOn(addButton, addButton, addTip)
	ScanButton(search)
	return box, search, addButton
end

ns.TabBuilders.guilds = function(pg)
	page = pg

	-- top left: search (guild names) and the count
	local search = ns.NewSearchBox(pg, 200, "Search guild name", function(text)
		if V:SetFind(text) then
			Resort()
			list:Top()
		end
	end)
	search:SetPoint("TOPLEFT", pg, "TOPLEFT", 16, -6)
	pg.search = search
	pg.count = ns.NewText(pg, 12)
	pg.count:SetPoint("LEFT", search, "RIGHT", 12, 0)
	pg.count:SetAlpha(0.7)

	-- top right: Scan All, [Add a Guild] [Guild Search] [Add Guild], under
	-- it [Exclude a Guild] [Guild Search] [Exclude]
	pg.add, pg.searchButton, pg.addButton = EntryRow(pg, -5, "Add a Guild", "Add Guild",
		function(text) return M.PSS_GuildSearchFromText(text) end,
		function(text)
			local key = M.PSS_GuildAddFromText(text)
			if not key then return false end
			if V:SetFind("") then pg.search:SetText("") end
			Resort()
			Select("guild", key)
			return true
		end,
		"Guild Search\n\nRuns a /who and lists every guild found (not the players). Type part of a guild name, or a full /who filter containing quotes, e.g. g-\"Name\" 10-80.",
		"Add Guild\n\nAdds the guild typed in the box to the Guild Ignore List.")
	pg.excl, pg.exclSearchButton, pg.exclButton = EntryRow(pg, -31, "Exclude a Guild", "Exclude",
		function(text) return M.PSS_GuildSearchFromText(text, "exclude") end,
		function(text) return M.PSS_GuildExcludeFromText(text) end,
		"Guild Search\n\nRuns a /who for the guild name in the box and lets you pick which guilds found go on the Guild Exclusion List. If none is found you can add the name anyway.",
		"Exclude\n\nAdds the guild typed in the box to the Guild Exclusion List: no guild rule ever blocks it, even one whose name it contains.")

	-- /who first, the window after
	local scanAll = ns.NewButton(pg, "Scan All", 80, function() M.PSS_ScanAll() end)
	scanAll:SetPoint("RIGHT", pg.add, "LEFT", -10, 0)
	scanAll:SetScript("OnEnter", function(self) ns.Tip(self, M.PSS_GuildScanTip(nil)) end)
	scanAll:SetScript("OnLeave", ns.HideTip)
	pg.scanAll = ScanButton(scanAll)

	BuildPane(pg)

	lf = CreateFrame("Frame", nil, pg)
	lf:SetPoint("TOPLEFT", pg, "TOPLEFT", 8, -TOP_H - 4)
	lf:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", -8, 0)
	list = ns.NewRows(lf, {
		rowH = 20,
		cols = {
			{ key = "guild", text = "Guild" },
			{ key = "members", text = "Members", width = 70, justify = "RIGHT" },
			{ key = "metric:total", text = "Blocked", width = 62, justify = "RIGHT",
				tip = "Messages and invites blocked from the guild's members." },
			{ key = "scan", text = "Scan", width = 90, justify = "RIGHT",
				tip = "Scan n/m = /who searches sent / planned so far this session. Sorts by searches sent." },
		},
		sort = function(key)
			V:SortBy(key)
			Resort()
		end,
		draw = DrawRow,
		enter = RowTip,
		click = ClickRow,
		emptyClick = function() if V.selKind then Select(nil, nil) end end,
	})

	BuildPicker(pg)

	-- back / forward and Escape (PSS_Window.lua): the Guild Search results
	-- are an overlay over the list
	pg.navClose = function()
		if not picker:IsShown() then return false end
		ClosePicker()
		return true
	end
	-- a tab click: nothing selected, the picker closed
	pg.navReset = function()
		pg.navClose()
		if V.selKind then Select(nil, nil) end
	end

	pg.list, pg.pane, pg.picker, pg.state = list, pane, picker, V
	pg.select = Select
	V.dirty = true
	return Refresh
end

------------------------------------------------------------------------
-- Core events: redraw now if the tab shows, else when it next shows.
------------------------------------------------------------------------
local queued = false
local function Changed()
	V.dirty = true
	if queued or not (page and page:IsVisible()) then return end
	-- one redraw however many changes arrive in a frame (saving Guild
	-- Search results adds many guilds at once)
	queued = true
	C_Timer.After(0, function()
		queued = false
		if page and page:IsVisible() then Refresh() end
	end)
end
M.Events.Register("GUILDS_CHANGED", Changed)
M.Events.Register("GUILD_SCAN_DONE", Changed)

M.Events.Register("GUILD_REMOVED", function(key)
	if V.selKind == "guild" and V.sel == key then V:Select(nil, nil) end
	Changed()
end)

-- Blocked lines only change counts: at most 4 redraws a second, the whole
-- list again (a heading's counts are its guilds' added up)
local redrawCounts = M.PSS_Throttle(function()
	if page and page:IsVisible() then
		Resort()
		ShowDetail()
	else
		V.dirty = true
	end
end)
M.Events.Register("GUILD_BLOCKS_CHANGED", function()
	if page and page:IsVisible() then redrawCounts() else V.dirty = true end
end)

M.Events.Register("WHOIS_COOLDOWN", function(active)
	for _, b in ipairs(scanButtons) do b:SetEnabled(not active) end
	if not active then Changed() end
end)

M.Events.Register("GUILD_SEARCH_RESULTS", function(found, query, mode, owner)
	if owner ~= M.PSS_GUILD_SEARCH_OWNER or not picker then return end
	ShowSearchResults(found, query, mode)
end)
