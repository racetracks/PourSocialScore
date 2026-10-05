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

-- a block from them shows in the pane (history read only once something
-- was blocked)
check(#pane.history == 0 and pane.histList.count == 0, "history before any block")
M.PSS_RecordPlayerBlock(sel, "CHAT_MSG_WHISPER", "buy gold", nil, "whisper")
H.RunTimers()
check(pane.histList.count == 1, "history after a block: " .. pane.histList.count)
check(pane.counts:GetText():match("^Blocked 1"), "counts " .. tostring(pane.counts:GetText()))
check((pane.histList.rows[1].cells.message:GetText() or ""):match("buy gold"), "history row text")

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

-- removal asks first (EllesmereUI's popup), then removes
selectEntry(sel)
check(pane.row.entry == sel, "player not selected again")
local nPopups = #E.log.popups
pane.removeButton:GetScript("OnClick")(pane.removeButton)
check(#E.log.popups == nPopups + 1 and E.log.popups[#E.log.popups].confirmText == "Remove", "remove not confirmed")
check(M.PSS_PlayerPosition(sel) > 0, "removed before the confirmation")
E.log.popups[#E.log.popups].onConfirm()
check(M.PSS_PlayerPosition(sel) == 0, "not removed after the confirmation")
check(M.PSS_GetPlayerRecord(sel) == nil, "record left after removal")
check(list.count == total - 1, "list not redrawn after removal")
check(not pane.body:IsShown() and pane.none:IsShown(), "pane still shows a removed entry")

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
