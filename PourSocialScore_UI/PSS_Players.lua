------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - PLAYER IGNORE LIST TAB
--
-- The list (search, sortable columns, Add Player) and a detail pane for the
-- selected entry with three pages (PSS_Detail.lua): Summary (counts and the
-- period pie), Event History and View/Edit Rule (note, expiry, W I G P C,
-- overrides, Remove, Add Guild). With nothing selected the pane shows the
-- whole list's totals. Libraries (PSS_PlayerView.lua) works out every text
-- and does every edit; the core says when the list changed
-- (PLAYERS_CHANGED, PLAYER_BLOCKED) and the tab redraws if it shows.
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local L = PourSocialScore_NS.L

local DETAIL_W = 380
local TOP_H = 32
local LINE_H = 16

-- the list's sort and search (Libraries); sel: the selected entry as
-- stored; row: the one table every drawn row is read into
local V = M.PSS_PlayerListNew()
local sel
local rowBuf = {}
local page, list, pane

ns.TabBuilders = ns.TabBuilders or {}

------------------------------------------------------------------------
-- List
------------------------------------------------------------------------
local function Resort()
	local n, _, countText, empty = V:Resort()
	list:SetSort(V.key, V.asc)
	list:SetCount(n)
	page.count:SetText(countText)
	list:SetEmptyText(empty)
end

local function DrawRow(row, i)
	local r = M.PSS_PlayerRow(V.index[i], rowBuf)
	local cells = row.cells
	if not r then
		for _, fs in pairs(cells) do fs:SetText("") end
		row.sel:Hide()
		return
	end
	cells.name:SetText(r.name)
	cells.name:SetTextColor(M.PSS_ClassColor(r.record and r.record.class))
	cells.server:SetText(r.server)
	cells.type:SetText(M.PSS_PlayerTypeText(r))
	cells.listed:SetText(r.listed .. "d")
	cells.expire:SetText(M.PSS_PlayerExpireText(r))
	cells["metric:total"]:SetText(r.record and M.PSS_PlayerTotal(r.record) or "")
	row.sel:SetShown(r.entry == sel)
end

local function RowTip(row, i)
	local r = M.PSS_PlayerRow(V.index[i], rowBuf)
	if r then ns.Tip(row, M.PSS_PlayerTip(r)) end
end

------------------------------------------------------------------------
-- Detail pane
------------------------------------------------------------------------
local function Line(parent, y)
	local fs = ns.NewText(parent, 12)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
	fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
	fs:SetJustifyH("LEFT")
	return fs
end

local function Label(parent, text)
	local fs = ns.NewText(parent, 12)
	fs:SetPoint("LEFT", parent, "LEFT", 0, 0)
	fs:SetText(text)
	fs:SetAlpha(0.7)
	return fs
end

-- The note and expiry boxes save to the entry that was shown when typing
-- started, even when the click that ends it selects another entry.
local function EditStart()
	pane.editEntry = sel
end

local function ConfirmRemove()
	local entry = sel
	if not entry then return end
	ns.Confirm({
		text = M.PSS_PlayerRemoveText(entry),
		accept = "Remove",
		onAccept = function()
			local pos = M.PSS_PlayerPosition(entry)
			if pos > 0 then M.PSS_RemovePlayerAt(pos) end
		end,
	})
end

local function OpenPlayerEvents(entry)
	if ns.OpenEvents then ns.OpenEvents(page, M.PSS_PlayerEventsSpec(entry), {}) end
end

local function BuildPane(parent)
	pane = ns.NewPanel(parent, true)
	pane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -TOP_H - 4)
	pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
	pane:SetWidth(DETAIL_W)
	pane.row = {}
	-- shown for players only (NPCs and servers have no counts)
	pane.player = {}

	-- nothing selected: the whole list's totals (a click on the selected
	-- entry deselects it)
	pane.totals = ns.NewTotals(pane, page, "players", "Player Ignore List", "Select an entry to see its details.",
		M.PSS_AllPlayersSpec)

	local body = CreateFrame("Frame", nil, pane)
	body:SetAllPoints()
	pane.body = body

	pane.heading = ns.NewHeading(body, "")
	pane.heading:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -8)
	pane.heading:SetPoint("RIGHT", body, "RIGHT", -10, 0)
	local dp = ns.NewDetailPages(body, -28, "players")
	pane.pages = dp

	-- Summary: the counts and the period pie
	pane.counts = Line(dp.summary, -6)
	pane.player[#pane.player + 1] = pane.counts
	pane.summary = ns.NewSummary(dp.summary, page, -30)
	pane.sumSpec = { specFn = M.PSS_PlayerEventsSpec, who = "this player" }

	-- View/Edit Rule
	local rule = dp.rule
	local y = -2
	pane.typeLine = Line(rule, y); y = y - LINE_H
	pane.addedLine = Line(rule, y); y = y - LINE_H
	pane.guildLine = Line(rule, y); y = y - LINE_H
	pane.inviteLine = Line(rule, y); y = y - LINE_H - 6
	pane.player[#pane.player + 1] = pane.guildLine
	pane.player[#pane.player + 1] = pane.inviteLine

	-- expiry: days after the date added, 0 = never
	local expRow = CreateFrame("Frame", nil, rule)
	expRow:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
	expRow:SetSize(DETAIL_W - 20, 22)
	Label(expRow, "Expires after")
	local exp = ns.NewNumberBox(expRow, 44)
	exp:SetPoint("LEFT", expRow, "LEFT", 90, 0)
	exp:SetMaxLetters(4)
	pane.expireNote = ns.NewText(expRow, 12)
	pane.expireNote:SetPoint("LEFT", exp, "RIGHT", 8, 0)
	ns.TipOn(exp, exp, "Days after the date added before this entry is removed by itself. 0 = never.")
	ns.OnCommit(exp, function(text)
		M.PSS_PlayerCommitExpiry(pane.editEntry or sel, text)
	end, function() ns.ShowPlayerDetail() end)
	exp:SetScript("OnEditFocusGained", EditStart)
	pane.expireBox = exp
	y = y - 26

	local noteRow = CreateFrame("Frame", nil, rule)
	noteRow:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
	noteRow:SetSize(DETAIL_W - 20, 22)
	Label(noteRow, "Note")
	local note = ns.NewEditBox(noteRow, 200, 128)
	note:SetPoint("LEFT", noteRow, "LEFT", 94, 0)
	note:SetPoint("RIGHT", noteRow, "RIGHT", -4, 0)
	ns.OnCommit(note, function(text)
		M.PSS_PlayerCommitNote(pane.editEntry or sel, text)
	end, function() ns.ShowPlayerDetail() end)
	note:SetScript("OnEditFocusGained", EditStart)
	pane.noteBox = note
	y = y - 28

	-- W I G P C (ticked = allowed)
	local exRow = CreateFrame("Frame", nil, rule)
	exRow:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
	exRow:SetSize(DETAIL_W - 20, 24)
	Label(exRow, "Allowed")
	pane.excl = {}
	local prev
	for _, e in ipairs(M.EXCL) do
		local c = ns.NewCheck(exRow)
		if prev then c:SetPoint("LEFT", prev, "RIGHT", 22, 0) else c:SetPoint("LEFT", exRow, "LEFT", 90, 0) end
		local letter = ns.NewText(exRow, 12)
		letter:SetPoint("LEFT", c, "RIGHT", 0, 0)
		letter:SetText(e.letter)
		ns.TipOn(c, c, e.label .. "\n\nTicked = allowed from this player, unticked = blocked.")
		c:SetScript("OnClick", function(self) M.PSS_PlayerToggleAllowed(sel, e.field, self:GetChecked()) end)
		pane.excl[e.cat] = c
		prev = letter
	end
	pane.player[#pane.player + 1] = exRow
	y = y - 28

	-- overrides of the Options for this player: Default > On > Off
	pane.overrides = {}
	local bw = (DETAIL_W - 26) / 2
	for n, o in ipairs(M.PSS_OverrideOptions()) do
		local b = ns.NewButton(rule, "", bw, function(self)
			M.PSS_PlayerCycleOverride(pane.record, self.opt.key)
			ns.ShowPlayerDetail()
		end)
		b.opt = o
		local col, r = (n - 1) % 2, math.floor((n - 1) / 2)
		b:SetPoint("TOPLEFT", rule, "TOPLEFT", 10 + col * (bw + 6), y - r * 24)
		ns.TipOn(b, b, o.label .. "\n\nClick to change: Default (the Options tab) > On > Off.")
		pane.overrides[#pane.overrides + 1] = b
		pane.player[#pane.player + 1] = b
	end

	-- the rule's actions: Remove, Add Guild
	local remove = ns.NewButton(rule, "Remove", 100, ConfirmRemove)
	remove:SetPoint("BOTTOMLEFT", rule, "BOTTOMLEFT", 10, 4)
	pane.removeButton = remove
	local addGuild = ns.NewButton(rule, "Add Guild", 100, function(self)
		M.PSS_PlayerAddGuild(self.guild)
		ns.ShowPlayerDetail()
	end)
	addGuild:SetPoint("LEFT", remove, "RIGHT", 6, 0)
	ns.TipOn(addGuild, addGuild, "Adds this player's current guild to the Guild Ignore List.")
	pane.addGuild = addGuild

	-- Event History: the block history, the whole page, Reset under it
	pane.hist = ns.NewHistory(dp.history, -2, {
		empty = "Nothing blocked from this player yet.",
		open = OpenPlayerEvents,
	})
	pane.player[#pane.player + 1] = pane.hist.frame
	local reset = ns.NewButton(dp.history, L["HISTORY_RESET"] or "Reset Block History", 130, function()
		if sel then M.PSS_ResetPlayerBlockHistory(sel) end
	end)
	reset:SetPoint("BOTTOMLEFT", dp.history, "BOTTOMLEFT", 10, 4)
	pane.resetButton = reset
	pane.player[#pane.player + 1] = reset
end

-- Redraw the pane for the selected entry (none: the list's totals).
function ns.ShowPlayerDetail(newEntry)
	if not pane then return end
	local pos = M.PSS_PlayerPosition(sel)
	local r = pos > 0 and M.PSS_PlayerRow(pos, pane.row)
	pane.body:SetShown(r and true or false)
	if not r then
		sel, pane.record = nil, nil
		pane.hist:Clear()
		pane.totals:Show()
		return
	end
	pane.totals:Hide()
	local p = r.record or nil
	pane.record = p
	local isPlayer = p ~= nil
	for _, f in ipairs(pane.player) do f:SetShown(isPlayer) end
	-- NPCs and servers have no counts or history: View/Edit Rule only
	pane.pages:Limit(not isPlayer and { rule = true } or nil)

	pane.heading:SetText(M.PSS_PlayerHeading(r))
	pane.typeLine:SetText(M.PSS_PlayerTypeLine(r))
	pane.addedLine:SetText(M.PSS_PlayerAddedLine(r))
	if not pane.expireBox:HasFocus() then pane.expireBox:SetText(tostring(tonumber(r.expire) or 0)) end
	pane.expireNote:SetText(M.PSS_PlayerExpireNote(r))
	if not pane.noteBox:HasFocus() then pane.noteBox:SetText(r.note or "") end

	pane.addGuild:Hide()
	if not p then
		pane.hist:Clear()
		return
	end
	pane.guildLine:SetText(M.PSS_PlayerGuildLine(p))
	pane.inviteLine:SetText(M.PSS_PlayerInviteLine(p))
	local guild, listed = M.PSS_PlayerGuildState(p)
	if guild then
		pane.addGuild.guild = guild
		pane.addGuild:SetText(listed and "Guild listed" or "Add Guild")
		pane.addGuild:SetEnabled(not listed)
		pane.addGuild:Show()
	end

	for _, e in ipairs(M.EXCL) do pane.excl[e.cat]:SetChecked(M.PSS_PlayerAllowed(p, e.field)) end
	for _, b in ipairs(pane.overrides) do
		b:SetText(M.PSS_OverrideText(b.opt, M.PSS_OverrideValue(p, b.opt.key)))
	end

	local c = M.PSS_GetPlayerBlockCounts(p)
	pane.counts:SetText(M.PSS_CountsText(c))

	-- read again only when the entry or its count changed; the block
	-- history (PourSocialScore_Logging) loads only when asked for
	pane.hist:Set(r.entry, c.total or 0, M.PSS_GetPlayerBlockHistory, newEntry)
	local s = pane.sumSpec
	s.owner, s.allTime, s.title, s.id = M.PSS_PlayerHistoryKey(r.entry), c.total or 0, r.name or r.entry, r.entry
	pane.summary:Set(s)
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
local function Refresh()
	if V.dirty then Resort() else list:Redraw() end
	ns.ShowPlayerDetail()
end

local function SelectEntry(entry)
	if pane then
		-- saves what was typed first
		pane.noteBox:ClearFocus()
		pane.expireBox:ClearFocus()
		pane.editEntry = nil
	end
	sel = entry
	list:Redraw()
	ns.ShowPlayerDetail(true)
end

ns.TabBuilders.players = function(pg)
	page = pg

	-- top: search on the left, Add Player on the right
	local search = ns.NewSearchBox(pg, 200, "Search name, server or note", function(text)
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

	local add = ns.NewEditBox(pg, 170, 64)
	local addHint = ns.NewText(add, 12)
	addHint:SetPoint("LEFT", add, "LEFT", 2, 0)
	addHint:SetAlpha(0.4)
	addHint:SetText("Name-Realm")
	local function AddPlayer()
		local text = add:GetText()
		add:SetText("")
		add:ClearFocus()
		local entry = M.PSS_PlayerAddFromText(text)
		if entry then SelectEntry(entry) end
	end
	local addButton = ns.NewButton(pg, "Add Player", 100, AddPlayer)
	addButton:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -8, -5)
	add:SetPoint("RIGHT", addButton, "LEFT", -8, 0)
	add:SetScript("OnTextChanged", function(self) addHint:SetShown((self:GetText() or "") == "") end)
	add:SetScript("OnEnterPressed", AddPlayer)
	add:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	ns.TipOn(addButton, addButton, "Adds the player typed in the box (Name or Name-Realm). Everything from them is blocked until you tick what to allow.")
	pg.add, pg.addButton = add, addButton

	BuildPane(pg)

	local lf = CreateFrame("Frame", nil, pg)
	lf:SetPoint("TOPLEFT", pg, "TOPLEFT", 8, -TOP_H - 4)
	lf:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", -8, 0)
	list = ns.NewRows(lf, {
		rowH = 20,
		cols = {
			{ key = "name", text = "Name" },
			{ key = "server", text = "Server", width = 112 },
			{ key = "type", text = "Type", width = 72 },
			{ key = "listed", text = "Listed", width = 54, justify = "RIGHT",
				tip = "Days since the entry was added." },
			{ key = "expire", text = "Expires", width = 62, justify = "RIGHT",
				tip = "Days left before the entry is removed by itself." },
			{ key = "metric:total", text = "Blocked", width = 62, justify = "RIGHT",
				tip = "Messages and invites blocked from this player." },
		},
		sort = function(key)
			V:SortBy(key)
			Resort()
		end,
		draw = DrawRow,
		enter = RowTip,
		click = function(_, i)
			local pos = V.index[i]
			local entry = pos and M.PSS_PlayerEntry(pos)
			if entry then SelectEntry(entry ~= sel and entry or nil) end
		end,
		emptyClick = function() if sel then SelectEntry(nil) end end,
	})
	-- a tab click (PSS_Window.lua): nothing selected
	pg.navReset = function() if sel then SelectEntry(nil) end end
	pg.list, pg.pane = list, pane
	pg.stale = function() V.dirty = true end
	pg.select = SelectEntry
	V.dirty = true
	return Refresh
end

-- The core says the list changed: redraw now if the tab shows, else when it
-- next shows. Blocked lines only change counts: at most 4 redraws a second.
ns.Listen("PLAYERS_CHANGED", function()
	V.dirty = true
	if page and page:IsVisible() then Refresh() end
end)

local redrawCounts = M.PSS_Throttle(function()
	if page and page:IsVisible() then
		list:Redraw()
		ns.ShowPlayerDetail()
	end
end)
ns.Listen("PLAYER_BLOCKED", function()
	if page and page:IsVisible() then redrawCounts() end
end)
