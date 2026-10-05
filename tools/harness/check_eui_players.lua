-- Player Ignore List queries (core, 3.1 Step E.4) and the Players tab of the
-- EllesmereUI window. Runs on the save check_eui_window.lua phase 1 wrote
-- (integration on), with PourSocialScore_EllesmereUI from PSS_EXTRA_ADDONS.
--   core: M.PSS_PlayerRow, M.PSS_SortPlayers (keys, blanks last, search),
--         M.PSS_RemovePlayerAt, M.PSS_PlayersChanged
--   tab:  pooled rows (1,200 entries draw with a screenful of rows),
--         scrolling, sorting, search, the detail pane (note, expiry,
--         W I G P C, overrides), history on a block, confirmed removal,
--         Add Player; PourSocialScore_GUI never loads
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui players: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local E = EllesmereUI
local db = PourSocialScoreDB

-- 1,200 players, an NPC and a server
local N = 1200
local t0 = os.clock()
for i = 1, N do
	local note = (i % 3 == 0) and ("note " .. i) or ""
	M.PSS_ImportListEntry(("Player%04d-Realm%d"):format(i, i % 4), (i % 2 == 0) and "Horde" or "Alliance", note, "player")
end
M.PSS_ImportListEntry("Gossip Vendor", "Horde", "", "npc")
M.PSS_ImportListEntry("SpamRealm", "Horde", "spam", "server")
local total = M.PSS_PlayerCount()
check(total == N + 2, "count " .. total)
print(("eui players: listed %d in %.2fs"):format(total, os.clock() - t0))

-- rows as shown
local row = {}
local pos = M.PSS_PlayerPosition("Player0003-Realm3")
check(pos > 0, "no position for a listed player")
check(M.PSS_PlayerRow(pos, row) == row, "row not written into the given table")
check(row.kind == "player" and row.name == "Player0003" and row.note == "note 3" and row.expire == 0, "player row")
check(type(row.record) == "table", "player row without its record")
M.PSS_PlayerRow(M.PSS_PlayerPosition("Gossip Vendor"), row)
check(row.kind == "npc" and row.server == "All" and row.record == false, "NPC row")
M.PSS_PlayerRow(total, row)
check(row.kind == "server" and row.name == "All" and row.record == false, "server row")
check(M.PSS_PlayerRow(total + 1, row) == nil, "row past the end")

-- sorting: name A-Z and Z-A, blank notes last both ways, search
-- the names of the players in that order (NPC and server rows left out)
local function names(idx, n)
	local out = {}
	for i = 1, n do
		local e, kind = M.PSS_PlayerEntry(idx[i])
		if kind == "player" then out[#out + 1] = string.lower(M.removeServer(e, true)) end
	end
	return out
end
local idx, n = M.PSS_SortPlayers("name", true)
check(n == total, "sort lost entries")
local a = names(idx, n)
for i = 2, #a do if a[i - 1] > a[i] then check(false, "name A-Z out of order at " .. i) break end end
idx = M.PSS_SortPlayers("name", false, nil, idx)
a = names(idx, n)
for i = 2, #a do if a[i - 1] < a[i] then check(false, "name Z-A out of order at " .. i) break end end
for _, asc in ipairs({ true, false }) do
	idx, n = M.PSS_SortPlayers("note", asc, nil, idx)
	local blank = false
	for i = 1, n do
		local note = db.notes[idx[i]] or ""
		if note == "" then blank = true elseif blank then check(false, "a note after a blank one") break end
	end
end
idx, n = M.PSS_SortPlayers("name", true, "NOTE 30", idx)
check(n == 5, "search on notes found " .. n)	-- 30, 300-309 (every third): 30, 300, 303, 306, 309
idx, n = M.PSS_SortPlayers("name", true, "realm2", idx)
check(n == N / 4, "search on realms found " .. n)
idx, n = M.PSS_SortPlayers("metric:total", false, nil, idx)
check(n == total, "metric sort")

-- the window: Players is the first tab and opens with /pss gui
local fired = 0
local id = M.Events.Register("PLAYERS_CHANGED", function() fired = fired + 1 end)
SlashCmdList.PSS("gui")
local win = _G.PSS_EllesmereUIWindow
check(win and win:IsShown(), "no window")
win.tabs[1]:GetScript("OnClick")(win.tabs[1])
local page = win.pages[1]
local list, pane = page.list, page.pane
check(page:IsShown() and list and pane, "Players tab not built")
check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded")

-- a screenful of rows, whatever the list size
list.scroll:SetHeight(320)
list:Layout()
check(list.count == total, "list count " .. list.count)
check(#list.rows == 16 and list.shown == 16, "rows made: " .. #list.rows)
check(list.rows[1].cells.name:GetText() ~= "", "first row empty")
list.scroll:SetVerticalScroll(100 * list.rowH)
check(list.first == 100 and list.rows[1].index == 101, "scroll did not move the rows")
list.scroll:SetVerticalScroll(total * list.rowH)
check(list.rows[1].index <= total, "scrolled past the end")

-- sorting by a header: Name again turns it Z-A
local head
for _, h in ipairs(list.heads) do if h.key == "name" then head = h end end
head:GetScript("OnClick")(head)
check(list.sortKey == "name" and list.sortAsc == false, "header click did not reverse the sort")
head:GetScript("OnClick")(head)

-- search
page.search:SetText("realm2")
page.search:GetScript("OnTextChanged")(page.search, true)
check(list.count == N / 4, "search shows " .. list.count)
check(page.count:GetText():match("^300 of"), "count text " .. tostring(page.count:GetText()))
page.search:SetText("")
page.search:GetScript("OnTextChanged")(page.search, true)
check(list.count == total, "search not cleared")

-- select a row: the detail pane shows it
local function selectEntry(name)
	local order = M.PSS_SortPlayers(list.sortKey, list.sortAsc, nil)
	for i = 1, #order do
		if M.PSS_PlayerEntry(order[i]) == name then
			list.scroll:SetVerticalScroll((i - 1) * list.rowH)
			list.rows[1]:GetScript("OnClick")(list.rows[1], "LeftButton")
			return
		end
	end
end
selectEntry("Player0003-Realm3")
local r1 = list.rows[1]
check(pane.body:IsShown() and not pane.none:IsShown(), "pane not shown on select")
local sel = pane.row.entry
check(type(sel) == "string" and sel:match("^Player"), "pane entry " .. tostring(sel))
check(r1.sel:IsShown(), "selected row not marked")


-- note and expiry save through the core
pane.noteBox:SetText("  from the pane ")
pane.noteBox:GetScript("OnEnterPressed")(pane.noteBox)
M.PSS_PlayerRow(M.PSS_PlayerPosition(sel), row)
check(row.note == "from the pane", "note not saved: " .. tostring(row.note))
pane.expireBox:SetText("30")
pane.expireBox:GetScript("OnEnterPressed")(pane.expireBox)
M.PSS_PlayerRow(M.PSS_PlayerPosition(sel), row)
check(row.expire == 30, "expiry not saved")
check(fired >= 2, "no PLAYERS_CHANGED after the edits")

-- W (whispers) ticked = allowed
local w = pane.excl.whisper
check(w:GetChecked() == false, "a new entry allows whispers")
w:SetChecked(true)
w:GetScript("OnClick")(w)
check(M.PSS_GetPlayerRecord(sel).whispersBlocked == false, "W not saved as allowed")
w:SetChecked(false)
w:GetScript("OnClick")(w)
check(M.PSS_GetPlayerRecord(sel).whispersBlocked == true, "W not saved as blocked")

-- an override cycles Default > On > Off > Default
local ob = pane.overrides[1]
check(ob ~= nil, "no override buttons")
local okey = ob.opt.key
local p = M.PSS_GetPlayerRecord(sel)
ob:GetScript("OnClick")(ob)
check(p.opts and p.opts[okey] == true, "override not On")
ob:GetScript("OnClick")(ob)
check(p.opts[okey] == false, "override not Off")
ob:GetScript("OnClick")(ob)
check(p.opts == nil or p.opts[okey] == nil, "override not back to Default")

-- a block from them is counted at once; the block history
-- (PourSocialScore_Logging) loads only on Show Block History, not for a
-- click on the row
local hv = pane.hist
-- the detail pages: counts on Summary, history on Event History, settings
-- and Remove / Add Guild on View/Edit Rule, Reset under the history
do
	local dp = pane.pages
	check(dp and #dp.buttons == 3 and pane.counts:GetParent() == dp.summary and hv.frame:GetParent() == dp.history
		and pane.removeButton:GetParent() == dp.rule and pane.addGuild:GetParent() == dp.rule, "detail pages")
	dp:Select("rule")
	check(pane.noteBox:IsVisible() and not hv.frame:IsVisible() and not pane.counts:IsVisible(), "rule page")
	dp:Select("history")
	check(hv.frame:IsVisible() and not pane.noteBox:IsVisible(), "history page")
end
check(hv.list.count == 0 and not hv.gate:IsShown(), "history before any block")
check(not loaded("PourSocialScore_Logging"), "Logging loaded before the history was asked for")
M.PSS_RecordPlayerBlock(sel, "CHAT_MSG_WHISPER", "buy gold", nil, "whisper")
H.RunTimers()
check(pane.counts:GetText():match("^Blocked 1"), "counts " .. tostring(pane.counts:GetText()))
check(not loaded("PourSocialScore_Logging"), "a block shown in the pane loaded Logging")
-- the Summary: this session / last 24 hours / all time from the core's
-- counts (no Logging); a tick box takes its period out of the pie (every tab)
do
	local sm = pane.summary
	pane.pages:Select("summary")
	local v = sm.values
	check(v.session == 1 and v.day == 1 and v.all == 1, ("summary %s/%s/%s"):format(tostring(v.session), tostring(v.day), tostring(v.all)))
	-- All time starts unticked (EUI 1.1.0-dev007); ticked, the one block
	-- counted in all three periods is drawn once, in the session's slice
	check(#sm.slices == 2 and not sm.boxes.all:GetChecked(), "All time ticked by default")
	sm.boxes.all:SetChecked(true)
	sm.boxes.all:GetScript("OnClick")(sm.boxes.all)
	check(#sm.slices == 3 and sm.pie.total == 1 and sm.slices[3].value == 1 and sm.slices[3].draw == 0
		and sm.boxes.day.count:GetText() == "1", "pie slices")
	local segs = 0
	for s = 1, #sm.pie.segSlice do if sm.pie.segSlice[s] ~= 0 then segs = segs + 1 end end
	check(segs == #sm.pie.segSlice, "pie not full: " .. segs)
	sm.boxes.day:SetChecked(false)
	sm.boxes.day:GetScript("OnClick")(sm.boxes.day)
	check(#sm.slices == 2 and sm.map[1] == "session" and sm.map[2] == "all", "unticked period still in the pie")
	sm.boxes.day:SetChecked(true)
	sm.boxes.day:GetScript("OnClick")(sm.boxes.day)
	check(#sm.slices == 3, "ticked period not back")
	check(not sm.empty:IsShown() and sm.viewButton:IsEnabled(), "summary empty or no View Events")
	check(not loaded("PourSocialScore_Logging"), "the Summary loaded Logging")
	pane.pages:Select("history")
end
check(hv.gate:IsShown() and hv.gate:GetText() == "Show Block History (1)", "no Show Block History button")
check(hv.list.count == 0, "history read without Logging")
hv.gate:GetScript("OnClick")(hv.gate)
check(loaded("PourSocialScore_Logging"), "Show Block History did not load Logging")
check(not hv.gate:IsShown(), "button still shown once loaded")
check(hv.list.count == 1, "history after Show Block History: " .. hv.list.count)
local hc = hv.list.rows[1].cells
check((hc.message:GetText() or ""):match("buy gold"), "history row text")
check((hc.kind:GetText() or ""):match("|c%x+whisper|r"), "type not one word: " .. tostring(hc.kind:GetText()))
check((hc.time:GetText() or ""):match("^%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d$"), "time format " .. tostring(hc.time:GetText()))
check(hc.name == nil, "a Name column in the player view")
-- untick whisper: its lines hide (every list), tick again: back
hv.boxes.whisper:SetChecked(false)
hv.boxes.whisper:GetScript("OnClick")(hv.boxes.whisper)
check(hv.list.count == 0, "whisper line not filtered")
hv.boxes.whisper:SetChecked(true)
hv.boxes.whisper:GetScript("OnClick")(hv.boxes.whisper)
check(hv.list.count == 1, "whisper line not back")
-- one word per type, party and raid lines by channel
local T = hv.typeOf
check(T({ cat = "partyInvite" }) == "invite" and T({ cat = "guildInvite" }) == "invite", "invite type")
check(T({ cat = "world", channel = "2. Trade" }) == "world" and T({ cat = "guildChat" }) == "guild", "world / guild type")
check(T({ cat = "partyRaid", channel = "Party Leader" }) == "party", "party type")
check(T({ cat = "partyRaid", channel = "Raid Warning" }) == "raid", "raid type")
check(T({ cat = "partyRaid", channel = "Battleground" }) == "BG" and T({ cat = "partyRaid", channel = "Instance" }) == "BG", "BG type")
-- a double-click on a line opens the Block History view in place of the tab
H.Advance(1)
local hr = hv.list.rows[1]
hr:GetScript("OnClick")(hr, "LeftButton")
hr:GetScript("OnClick")(hr, "LeftButton")
local view = page.hview
check(view and view:IsOpen() and not page:IsShown() and view.list.count == 1, "player Block History view not opened")
view.allButton:GetScript("OnClick")(view.allButton)
check(view.spec.id == false and view.list.count >= 1, "All Players: " .. view.list.count)
check(EllesmereUI.PressEscape() and not view:IsOpen() and page:IsShown(), "Escape did not close the player view")
H.Advance(1)
-- a pie slice: that period's events; All Time: every event; View Events
do
	local sm = pane.summary
	pane.pages:Select("summary")
	local start = M.PSS_History.SessionStart()
	sm.pie.frame:GetScript("OnClick")(sm.pie.frame)		-- not on a slice (the cursor is away)
	check(not view:IsOpen(), "a click off the ring opened the view")
	sm:Open("session")
	check(view:IsOpen() and view.period == "session" and view.list.count == 1, "session slice")
	check((view.heading:GetText() or ""):find(", this session", 1, true), "slice heading " .. tostring(view.heading:GetText()))
	check(view.periodButtons.session.isSelected and not view.periodButtons.all.isSelected, "time picker not on the session")
	EllesmereUI.PressEscape()
	sm:Open("day")
	check(view:IsOpen() and view.period == "day" and view.periodButtons.day.isSelected, "day slice")
	-- the time picker: All time shows every event, the period again filters
	view.periodButtons.all:GetScript("OnClick")(view.periodButtons.all)
	check(view.period == nil and view.periodButtons.all.isSelected and view.list.count == 1
		and not (view.heading:GetText() or ""):find(", ", 1, true), "time picker All time")
	EllesmereUI.PressEscape()
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	check(view:IsOpen() and view.period == nil and view.spec.id == sel and not view.pick:IsShown(), "View Events")
	EllesmereUI.PressEscape()
	-- an event from before the session is not in the session slice
	local old = M.PSS_History.NewEntry("whisper", "CHAT_MSG_WHISPER", "old line", "Whisper", sel)
	old.ts = start - 60
	M.PSS_History.Add(M.PSS_History.PlayerKey(sel), nil, old)
	sm:Open("session")
	check(view.list.count == 1 and #view.all == 2, "session slice shows an older event: " .. view.list.count)
	view.periodButtons.all:GetScript("OnClick")(view.periodButtons.all)
	check(view.list.count == 2, "All time hides the older event")
	EllesmereUI.PressEscape()
	-- where the blocks are (Logging is loaded by now): kept for the player,
	-- never in the log since core 3.2-dev3 (the older line above was added
	-- without a count: 2 lines)
	pane.pages:Select("summary")
	check((sm.where:GetText() or "") == "Stored: 2 kept for this player.", "where line " .. tostring(sm.where:GetText()))
	-- the lines leave the block history, the counts stay: the view shows
	-- the block as expired, with its type and 10 minutes (from the core's
	-- recent counts) and the message "Data expired from logs"
	local key = M.PSS_PlayerHistoryKey(sel)
	M.PSS_History.Clear(function(h) return h.o == key end)
	sm:Refresh()
	check((sm.where:GetText() or ""):find("1 not stored or expired", 1, true), "where after expiry " .. tostring(sm.where:GetText()))
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	local x = view.shown[1]
	-- (the counted block and the older line fall in the same 10 minutes)
	check(view.list.count == 1 and x and x.expired == 2 and x.cat == "whisper" and x.ts > 0 and x.ts % 600 == 0
		and (x.message or ""):find("Data expired from logs", 1, true), "expired line " .. view.list.count)
	check((view.list.rows[1].cells.time:GetText() or "") ~= "Unknown", "expired line without its time")
	-- older than a day: still shown, time unknown, on All time only
	H.Advance(86400 + 600)
	EllesmereUI.PressEscape()
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	x = view.shown[1]
	check(view.list.count == 1 and x.ts == 0 and x.cat == "whisper", "expired line after a day")
	view.periodButtons.day:GetScript("OnClick")(view.periodButtons.day)
	check(view.list.count == 0, "an expired line of unknown time in Last 24 hours")
	EllesmereUI.PressEscape()
	-- the player's world chat is counted, not stored: a "Not stored" row
	M.PSS_RecordPlayerBlock(sel, "CHAT_MSG_CHANNEL", "trade spam", nil, "world")
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	local ns_ = 0
	for i = 1, view.list.count do
		local y = view.shown[i]
		if y.cat == "world" and y.channel == "Not stored" and (y.message or ""):find("not stored", 1, true) then ns_ = ns_ + 1 end
	end
	check(ns_ == 1, "world chat not shown as not stored")
	EllesmereUI.PressEscape()
	pane.pages:Select("history")
	H.Advance(1)
end

-- NPC entry: the player-only parts hide
idx = M.PSS_SortPlayers(list.sortKey, list.sortAsc, nil)
local npcPos = M.PSS_PlayerPosition("Gossip Vendor")
for i = 1, #idx do
	if idx[i] == npcPos then
		list.scroll:SetVerticalScroll((i - 1) * list.rowH)
		list.rows[1]:GetScript("OnClick")(list.rows[1], "LeftButton")
		break
	end
end
check(pane.row.entry == "Gossip Vendor", "NPC not selected: " .. tostring(pane.row.entry))
check(not pane.excl.whisper:IsVisible() and not pane.counts:IsVisible(), "player parts shown for an NPC")
check(pane.pages.shown == "rule" and not pane.pages.buttons[1]:IsEnabled() and not pane.pages.buttons[2]:IsEnabled(), "NPC offered Summary or Event History")

-- removal asks first (EllesmereUI's popup), then removes
selectEntry(sel)
check(pane.row.entry == sel, "player not selected again")
-- a click on the selected entry deselects it: the pane shows the whole
-- list's totals (3.2.0-dev004 / EUI 1.1.0-dev007), Logging still unloaded
do
	local logging = C_AddOns.IsAddOnLoaded("PourSocialScore_Logging")
	selectEntry("Player0003-Realm3")
	local tot = pane.totals
	check(not pane.body:IsShown() and tot.frame:IsShown() , "deselect: totals not shown")
	local want = M.PSS_ListTotals("players", {})
	local v = tot.summary.values
	check(want.total > 0 and v.all == want.total and v.session == want.session and v.day == want.day,
		("player totals %s/%s/%s"):format(tostring(v.session), tostring(v.day), tostring(v.all)))
	check(tot.typePie.count >= 1, "player totals type pie empty")
	-- All time starts unticked; ticked, the nested slices take only their
	-- own part (the overlap is drawn once, in the smaller slice)
	local box = tot.summary.boxes.all
	check(box:GetChecked() == pane.summary.boxes.all:GetChecked(), "tick boxes not shared with the entry's Summary")
	box:SetChecked(false)
	box:GetScript("OnClick")(box)
	check(#tot.summary.slices == 2, "unticked All time still in the totals pie")
	box:SetChecked(true)
	box:GetScript("OnClick")(box)
	local sl = tot.summary.slices
	check(#sl == 3 and sl[1].draw == v.session and sl[2].draw == math.max(0, v.day - v.session)
		and sl[3].draw == math.max(0, v.all - math.max(v.session, v.day)) and sl[3].within[1] and sl[3].within[2]
		and not sl[1].within[2], "nested period slices")
	box:SetChecked(false)
	box:GetScript("OnClick")(box)
	check(C_AddOns.IsAddOnLoaded("PourSocialScore_Logging") == logging, "totals loaded the block history")
	selectEntry("Player0003-Realm3")
	check(pane.body:IsShown() and not tot.frame:IsShown(), "pane not back after selecting again")
end
local nPopups = #E.log.popups
pane.removeButton:GetScript("OnClick")(pane.removeButton)
check(#E.log.popups == nPopups + 1 and E.log.popups[#E.log.popups].confirmText == "Remove", "remove not confirmed")
check(M.PSS_PlayerPosition(sel) > 0, "removed before the confirmation")
E.log.popups[#E.log.popups].onConfirm()
check(M.PSS_PlayerPosition(sel) == 0, "not removed after the confirmation")
check(M.PSS_GetPlayerRecord(sel) == nil, "record left after removal")
check(list.count == total - 1, "list not redrawn after removal")
check(not pane.body:IsShown() and pane.totals.frame:IsShown(), "pane still shows a removed entry")

-- Add Player selects the new entry
page.add:SetText("Newbie-Realm1")
page.add:GetScript("OnEnterPressed")(page.add)
check(M.PSS_PlayerPosition("Newbie-Realm1") > 0, "Add Player did not add")
check(pane.row.entry == "Newbie-Realm1", "Add Player did not select: " .. tostring(pane.row.entry))
check(list.count == total, "list count after add " .. list.count)

-- the native window keeps working on the same functions
M.Events.Unregister("PLAYERS_CHANGED", id)
check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded by the tab")
SlashCmdList.PSS("gui force")
check(loaded("PourSocialScore_GUI") and _G.PSS and _G.PSS:IsShown(), "/pss gui force")

if not fail then print("PASS eui players") end
