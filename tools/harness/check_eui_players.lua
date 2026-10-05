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
-- a double-click on a line opens its events on the Events tab
H.Advance(1)
local hr = hv.list.rows[1]
hr:GetScript("OnClick")(hr, "LeftButton")
hr:GetScript("OnClick")(hr, "LeftButton")
local view = win.pages[4].view
check(view and view:IsOpen() and not page:IsShown() and win.pages[4]:IsShown() and view.list.count == 1
	and view.q.scope and view.q.scope.id == sel, "player events not opened on the Events tab")
check(E.log.tabSel[win.tabs[4]] == true, "Events tab not selected")
check((view.sourceDrop.shownText or ""):find("Only ", 1, true), "source drop-down " .. tostring(view.sourceDrop.shownText))
check((win.where:GetText() or ""):find("Events  >  ", 1, true), "where line " .. tostring(win.where:GetText()))
-- the Source drop-down: this player's list as a whole
local function menu(d, text)
	for _, it in ipairs(d:MenuButtons()) do if it.text == text then return it end end
end
local function pick(d, text)
	local it = menu(d, text)
	check(it, "no menu entry " .. text)
	if it then it.fn() end
end
pick(view.sourceDrop, "Player Ignore List")
check(view.q.scope == nil and view.q.sources.players and not view.q.sources.guilds and view.list.count >= 1,
	"All Players: " .. view.list.count)
check(view.sourceDrop.shownText == "Player Ignore List", "source text " .. tostring(view.sourceDrop.shownText))
check(view.shown[1] and view.list.rows[1].cells.source:GetText() == "Player Ignore List", "Source column")
check(EllesmereUI.PressEscape() and not view:IsOpen() and page:IsShown(),
	"Escape did not go back to the player tab")
H.Advance(1)
-- a pie slice: that period's events; All Time: every event; View Events
do
	local sm = pane.summary
	pane.pages:Select("summary")
	local start = M.PSS_History.SessionStart()
	sm.pie.frame:GetScript("OnClick")(sm.pie.frame)		-- not on a slice (the cursor is away)
	check(not view:IsOpen(), "a click off the ring opened the view")
	sm:Open("session")
	check(view:IsOpen() and view.q.period == "session" and view.list.count == 1, "session slice")
	check(view.timeDrop.shownText == "This session", "time drop-down " .. tostring(view.timeDrop.shownText))
	local function radio(text) local it = menu(view.timeDrop, text) return it and it.on end
	check(radio("This session") and not radio("All time"), "time drop-down not on the session")
	EllesmereUI.PressEscape()
	sm:Open("day")
	check(view:IsOpen() and view.q.period == "day" and radio("Last 24 hours"), "day slice")
	-- the time drop-down: All time shows every event, the period again filters
	pick(view.timeDrop, "All time")
	check(view.q.period == nil and radio("All time") and view.list.count == 1
		and view.timeDrop.shownText == "All time", "time drop-down All time")
	EllesmereUI.PressEscape()
	-- View Events (top right): the widest period ticked
	check(sm.viewButton:IsShown(), "no View Events")
	check(sm.boxes.all:GetChecked(), "all time not ticked here")
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	check(view:IsOpen() and view.q.period == nil and view.q.scope.id == sel, "View Events: " .. tostring(view.q.period))
	EllesmereUI.PressEscape()
	sm.boxes.all:SetChecked(false)
	sm.boxes.all:GetScript("OnClick")(sm.boxes.all)
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	check(view.q.period == "day", "View Events without all time: " .. tostring(view.q.period))
	EllesmereUI.PressEscape()
	sm.boxes.all:SetChecked(true)
	sm.boxes.all:GetScript("OnClick")(sm.boxes.all)
	-- an event from before the session is not in the session slice
	local old = M.PSS_History.NewEntry("whisper", "CHAT_MSG_WHISPER", "old line", "Whisper", sel)
	old.ts = start - 60
	M.PSS_History.Add(M.PSS_History.PlayerKey(sel), nil, old)
	sm:Open("session")
	check(view.list.count == 1 and #view.all == 2, "session slice shows an older event: " .. view.list.count)
	pick(view.timeDrop, "All time")
	check(view.list.count == 2, "All time hides the older event")
	-- a custom range: from before the older event to before the newer one
	pick(view.timeDrop, "Custom range")
	check(view.q.period == "custom" and view.custom:IsShown(), "custom range not shown")
	view.fromBox:SetText(date("%Y-%m-%d %H:%M", start - 3600))
	view.toBox:SetText(date("%Y-%m-%d %H:%M", start - 1))
	view.applyButton:GetScript("OnClick")(view.applyButton)
	check(view.list.count == 1 and view.shown[1].message == "old line", "custom range: " .. view.list.count)
	view.toBox:SetText("")
	view.applyButton:GetScript("OnClick")(view.applyButton)
	check(view.list.count == 2 and view.q.to == nil, "custom range up to now: " .. view.list.count)
	view.fromBox:SetText("yesterday")
	view.applyButton:GetScript("OnClick")(view.applyButton)
	check(view.list.count == 2 and (view.rangeError:GetText() or "") ~= "", "a bad date not reported")
	EllesmereUI.PressEscape()
	-- where the blocks are (Logging is loaded by now): in the log, as every
	-- line again since core 3.2.0-dev007 (the older line above was added
	-- without a count: 2 lines)
	pane.pages:Select("summary")
	check((sm.where:GetText() or "") == "Stored: 2 in the log.", "where line " .. tostring(sm.where:GetText()))
	-- the lines leave the block history, the counts stay: the view shows
	-- the block as expired, with its type and 10 minutes (from the core's
	-- recent counts) and the message "Data expired from logs"
	local key = M.PSS_PlayerHistoryKey(sel)
	M.PSS_History.Clear(function(h) return h.o == key end)
	sm:Refresh()
	check((sm.where:GetText() or ""):find("1 expired from logs", 1, true), "where after expiry " .. tostring(sm.where:GetText()))
	sm.viewButton:GetScript("OnClick")(sm.viewButton)
	local x = view.shown[1]
	-- (the counted block and the older line fall in the same 10 minutes)
	check(view.list.count == 1 and x and x.expired == 2 and x.cat == "whisper" and x.ts > 0 and x.ts % 600 == 0
		and (x.message or ""):find("Data expired from logs", 1, true), "expired line " .. view.list.count)
	check((view.list.rows[1].cells.time:GetText() or "") ~= "Unknown", "expired line without its time")
	-- older than a day: still shown, time unknown, on All time only
	H.Advance(86400 + 600)
	EllesmereUI.PressEscape()
	sm:Open("all")
	x = view.shown[1]
	check(view.list.count == 1 and x.ts == 0 and x.cat == "whisper", "expired line after a day")
	pick(view.timeDrop, "Last 24 hours")
	check(view.list.count == 0, "an expired line of unknown time in Last 24 hours")
	EllesmereUI.PressEscape()
	-- the player's world chat is stored again (core 3.2.0-dev007): its
	-- line, no "Not stored" row
	M.PSS_RecordPlayerBlock(sel, "CHAT_MSG_CHANNEL", "trade spam", nil, "world")
	sm:Open("all")
	local ns_, line = 0, 0
	for i = 1, view.list.count do
		local y = view.shown[i]
		if y.channel == "Not stored" then ns_ = ns_ + 1 end
		if y.cat == "world" and y.message == "trade spam" then line = line + 1 end
	end
	check(ns_ == 0 and line == 1, "world chat not shown as its line")
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
	-- the type ticks (3.2.0-dev010): an unticked type leaves every period
	-- pie, this session, 24 hours and all time alike; a click on its label
	-- (not only its box) unticks it, again ticks it
	do
		local ttp = tot.typePie
		local k1 = ttp.keys[1]
		local cat = k1.cat
		local s0, d0 = v.session, v.day
		local by = M.PSS_History.RecentByCat(nil, nil, "p:")
		local allOn = 0
		for _, c in ipairs(M.PSS_History.ALL_CATS) do
			if c ~= cat then allOn = allOn + (tonumber(ttp.counts[c]) or 0) end
		end
		k1.check.hit:GetScript("OnClick")(k1.check.hit)
		check(not k1.check:GetChecked(), "a label click did not untick its type")
		local v2 = tot.summary.values
		print(("eui players: type %s off, totals %d/%d -> %d/%d/%d"):format(cat, s0, d0, v2.session, v2.day, v2.all))
		check(v2.session == s0 - (by.session[cat] or 0) and v2.day == d0 - (by.day[cat] or 0) and v2.all == allOn,
			("type unticked: %d/%d/%d, want %d/%d/%d"):format(v2.session, v2.day, v2.all,
				s0 - (by.session[cat] or 0), d0 - (by.day[cat] or 0), allOn))
		check((tot.summary.boxes.session.count:GetText() or "") == tostring(v2.session), "period count not of the ticked types")
		-- View Events: the ticked types only
		tot.summary.viewButton:GetScript("OnClick")(tot.summary.viewButton)
		local ev = win.pages[4].view
		check(ev and ev:IsOpen() and ev.q.cats and not ev.q.cats[cat] and ev.typeDrop.shownText ~= "All types",
			"View Events not of the ticked types")
		EllesmereUI.PressEscape()
		k1.check.hit:GetScript("OnClick")(k1.check.hit)
		check(k1.check:GetChecked() and tot.summary.values.session == s0 and tot.summary.values.day == d0,
			"a second label click did not tick it again")
		-- a type slice: that type's events, the whole list
		ttp.pie.SliceAt = function() return 1 end
		ttp.pie.frame:GetScript("OnClick")(ttp.pie.frame)
		ttp.pie.SliceAt = nil
		local only = ev.q.cats
		local n = 0
		for _ in pairs(only or {}) do n = n + 1 end
		check(ev:IsOpen() and n == 1 and only[cat] and ev.q.scope == nil and ev.q.sources.players
			and not ev.q.sources.guilds, "a type slice did not open its events")
		local same = true
		for i = 1, ev.list.count do if (ev.shown[i].cat or "unknown") ~= cat then same = false end end
		check(same, "a type slice shows other types")
		EllesmereUI.PressEscape()
	end
	-- its slices and View Events open the whole list's events (EUI 1.1.0-dev010)
	local tsm = pane.totals.summary
	check(tsm.viewButton:IsShown(), "player totals: no View Events")
	tsm.viewButton:GetScript("OnClick")(tsm.viewButton)
	local tv = win.pages[4].view
	check(tv and tv:IsOpen() and tv.q.scope == nil and tv.q.sources.players and not tv.q.sources.filters
		and tv.q.period == "day", "player totals: View Events did not open the whole list")
	EllesmereUI.PressEscape()
	tsm:Open("session")
	check(tv:IsOpen() and tv.q.period == "session" and tv.q.scope == nil, "player totals: the session slice")
	EllesmereUI.PressEscape()
	tsm:Open("all")
	check(tv:IsOpen() and tv.q.period == nil, "player totals: All time after a slice")
	EllesmereUI.PressEscape()
	H.Advance(1)
	selectEntry("Player0003-Realm3")
	check(pane.body:IsShown() and not tot.frame:IsShown(), "pane not back after selecting again")
	-- a click under the rows deselects too, and so does a click on the tab
	page.list.scroll:GetScript("OnMouseUp")(page.list.scroll, "LeftButton")
	check(not pane.body:IsShown() and tot.frame:IsShown(), "a click under the players did not deselect")
	selectEntry("Player0003-Realm3")
	_G.PSS_EllesmereUIWindow.tabs[1]:GetScript("OnClick")(_G.PSS_EllesmereUIWindow.tabs[1])
	check(not pane.body:IsShown() and tot.frame:IsShown(), "the tab shown did not deselect")
	selectEntry("Player0003-Realm3")
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
