-- The new window's Player Ignore List tab (3.4.0-dev007), as a run.lua
-- script on any save, real ones included: /pss tui builds it; with nothing
-- selected the pane shows the list's totals (equal to M.PSS_ListTotals);
-- then, on 200 added players, an NPC and a server: pooled rows, sorting,
-- search, the detail pane (lines from Libraries, note, expiry, W I G P C,
-- overrides), a block counted at once with the Summary pie, the history
-- loaded only on Show Block History, confirmed removal and Add Player; the
-- close button and the title sit above the frame art. Neither old window
-- loads.
local fail = false
local function check(ok, msg) if not ok then print("FAIL players: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

SlashCmdList["PSS"]("tui")
local win = _G.PSS_Window
check(win and win:IsShown(), "/pss tui did not open the window")
win.tabs[1]._scripts.OnClick(win.tabs[1])
local page = win.pages[1]
local list, pane = page.list, page.pane
check(page:IsShown() and list and pane, "Players tab not built")
check(not page.note:IsShown(), "the built tab still shows its note")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

-- the close button and the title above the frame art (its border is drawn
-- at a fixed level of about 500)
local chrome = win.chrome
check(chrome and win.art.blizzardClose:GetParent() == chrome and win.art.darkClose:GetParent() == chrome
	and win.title:GetParent() == chrome, "close buttons or title not on the raised frame")
win.art.blizzardClose._scripts.OnClick(win.art.blizzardClose)
check(not win:IsShown(), "the close button did not close the window")
SlashCmdList["PSS"]("tui")

-- nothing selected: the list's totals
local want = M.PSS_ListTotals("players", {})
check(pane.totals.frame:IsShown() and not pane.body:IsShown(), "totals not shown with nothing selected")
check(pane.totals.info:GetText():find(("Blocked |cffffff00%d|r"):format(want.total or 0), 1, true) ~= nil, "totals text")
local tv = pane.totals.summary.values
check(tv.session == (want.session or 0) and tv.day == (want.day or 0) and tv.all == (want.total or 0), "totals pie differs from M.PSS_ListTotals")

-- 200 players, an NPC and a server
local before = M.PSS_PlayerCount()
local N = 200
for i = 1, N do
	local note = (i % 3 == 0) and ("note " .. i) or ""
	M.PSS_ImportListEntry(("Tuiplayer%03d-Realm%d"):format(i, i % 4), (i % 2 == 0) and "Horde" or "Alliance", note, "player")
end
M.PSS_ImportListEntry("Gossip Vendor", "Horde", "", "npc")
M.PSS_ImportListEntry("SpamRealm", "Horde", "spam", "server")
M.PSS_PlayersChanged()
local total = M.PSS_PlayerCount()
check(total == before + N + 2, "count " .. total)
check(list.count == total, "list count " .. list.count .. " of " .. total)
check(page.count:GetText() == ("%d on the list"):format(total), "count text " .. tostring(page.count:GetText()))

-- a screenful of rows, whatever the list size
list.scroll:SetHeight(320)
list:Layout()
check(#list.rows == 16, "rows made: " .. #list.rows)
list.scroll:SetVerticalScroll(50 * list.rowH)
check(list.first == 50 and list.rows[1].index == 51, "scroll did not move the rows")
list.scroll:SetVerticalScroll(0)

-- a header click reverses the sort
local head
for _, h in ipairs(list.heads) do if h.key == "name" then head = h end end
head._scripts.OnClick(head)
check(list.sortKey == "name" and list.sortAsc == false, "header click did not reverse the sort")
head._scripts.OnClick(head)
local blocked
for _, h in ipairs(list.heads) do if h.key == "metric:total" then blocked = h end end
blocked._scripts.OnClick(blocked)
check(list.sortKey == "metric:total", "Blocked column does not sort")
head._scripts.OnClick(head)

-- search (name, server or note)
page.search:SetText("realm2")
page.search._scripts.OnTextChanged(page.search, true)
check(list.count == N / 4, "search shows " .. list.count)
check(page.count:GetText() == ("%d of %d"):format(N / 4, total), "search count text")
page.search:SetText("")
page.search._scripts.OnTextChanged(page.search, true)
check(list.count == total, "search not cleared")

-- select a row: the pane shows it, every line from Libraries
local entry = "Tuiplayer003-Realm3"
page.select(entry)
check(pane.body:IsShown() and not pane.totals.frame:IsShown(), "pane not shown on select")
local row = M.PSS_PlayerRow(M.PSS_PlayerPosition(entry), {})
check(pane.heading:GetText() == M.PSS_PlayerHeading(row), "heading")
check(pane.typeLine:GetText() == M.PSS_PlayerTypeLine(row) and pane.addedLine:GetText() == M.PSS_PlayerAddedLine(row), "rule lines")
check(pane.noteBox:GetText() == "note 3" and pane.expireBox:GetText() == "0", "note or expiry box")
local c = M.PSS_GetPlayerBlockCounts(row.record)
check(pane.counts:GetText() == M.PSS_CountsText(c), "counts line")

-- note and expiry save through the core
pane.noteBox:SetText("  from the pane ")
pane.noteBox._scripts.OnEnterPressed(pane.noteBox)
check(M.PSS_PlayerRow(M.PSS_PlayerPosition(entry), {}).note == "from the pane", "note not saved")
pane.expireBox:SetText("30")
pane.expireBox._scripts.OnEnterPressed(pane.expireBox)
check(M.PSS_PlayerRow(M.PSS_PlayerPosition(entry), {}).expire == 30, "expiry not saved")

-- W (whispers) ticked = allowed
local w = pane.excl.whisper
check(w:GetChecked() == false, "a new entry allows whispers")
w:SetChecked(true)
w._scripts.OnClick(w)
check(M.PSS_GetPlayerRecord(entry).whispersBlocked == false, "W not saved as allowed")
w:SetChecked(false)
w._scripts.OnClick(w)
check(M.PSS_GetPlayerRecord(entry).whispersBlocked == true, "W not saved as blocked")

-- an override cycles Default > On > Off > Default
local ob = pane.overrides[1]
check(ob ~= nil, "no override buttons")
local okey = ob.opt.key
local p = M.PSS_GetPlayerRecord(entry)
ob._scripts.OnClick(ob)
check(p.opts and p.opts[okey] == true and ob:GetText():find("On", 1, true), "override not On")
ob._scripts.OnClick(ob)
check(p.opts[okey] == false, "override not Off")
ob._scripts.OnClick(ob)
check(p.opts == nil or p.opts[okey] == nil, "override not back to Default")

-- the detail pages
local dp, hv = pane.pages, pane.hist
check(#dp.buttons == 3 and pane.counts:GetParent() == dp.summary and hv.frame:GetParent() == dp.history
	and pane.removeButton:GetParent() == dp.rule, "detail pages")
dp:Select("rule")
check(pane.noteBox:IsVisible() and not hv.frame:IsVisible(), "rule page")
dp:Select("history")
check(hv.frame:IsVisible() and not pane.noteBox:IsVisible(), "history page")
check(hv.list.count == 0 and not hv.gate:IsShown(), "history before any block")

-- a block is counted at once; Logging loads only on Show Block History
local hadLogging = loaded("PourSocialScore_Logging")
M.PSS_RecordPlayerBlock(entry, "CHAT_MSG_WHISPER", "buy gold", nil, "whisper")
H.RunTimers()
check(pane.counts:GetText():find("^Blocked 1") ~= nil, "counts " .. tostring(pane.counts:GetText()))
check(loaded("PourSocialScore_Logging") == hadLogging, "a block shown in the pane loaded Logging")
dp:Select("summary")
local sm = pane.summary
local v = sm.values
local s, d = M.PSS_History.RecentCounts(M.PSS_PlayerHistoryKey(entry))
check(v.session == s and v.day == d and v.all == 1, ("summary %s/%s/%s"):format(tostring(v.session), tostring(v.day), tostring(v.all)))
check(#sm.slices == 2 and not sm.boxes.all:GetChecked(), "All time ticked by default")
sm.boxes.all:SetChecked(true)
sm.boxes.all._scripts.OnClick(sm.boxes.all)
check(#sm.slices == 3 and sm.slices[3].draw == 0, "all time slice not nested")
sm.boxes.all:SetChecked(false)
sm.boxes.all._scripts.OnClick(sm.boxes.all)
check(sm.viewButton:IsShown(), "no View Events on the Summary")
dp:Select("history")
if not hadLogging then
	check(hv.gate:IsShown() and hv.gate:GetText() == "Show Block History (1)", "no Show Block History button")
	hv.gate._scripts.OnClick(hv.gate)
	check(loaded("PourSocialScore_Logging"), "Show Block History did not load Logging")
end
check(not hv.gate:IsShown() and hv.list.count == 1, "history after Show Block History: " .. hv.list.count)
local hc = hv.list.rows[1].cells
check((hc.message:GetText() or ""):find("buy gold", 1, true) ~= nil, "history row text")
check((hc.kind:GetText() or ""):match("|c%x+whisper|r") ~= nil, "type not one word")
hv.boxes.whisper:SetChecked(false)
hv.boxes.whisper._scripts.OnClick(hv.boxes.whisper)
check(hv.list.count == 0, "whisper line not filtered")
hv.boxes.whisper:SetChecked(true)
hv.boxes.whisper._scripts.OnClick(hv.boxes.whisper)
check(hv.list.count == 1, "whisper line not back")

-- an NPC: View/Edit Rule only
page.select("Gossip Vendor")
check(dp.shown == "rule", "NPC not on View/Edit Rule")
check(not dp.buttons[1]:IsEnabled(), "NPC Summary page offered")
check(not pane.excl.whisper:IsVisible(), "NPC shows W I G P C")

-- Remove asks first
page.select(entry)
dp:Select("rule")
pane.removeButton._scripts.OnClick(pane.removeButton)
local cf = _G.PSS_Confirm
check(cf and cf:IsShown() and cf.text:GetText():find(entry, 1, true), "no confirm before removing")
cf.cancel._scripts.OnClick(cf.cancel)
check(M.PSS_PlayerPosition(entry) > 0, "cancel removed the entry")
pane.removeButton._scripts.OnClick(pane.removeButton)
cf.accept._scripts.OnClick(cf.accept)
check(M.PSS_PlayerPosition(entry) == 0 and M.PSS_GetPlayerRecord(entry) == nil, "accept did not remove the entry")
check(pane.totals.frame:IsShown(), "removed entry still shown")

-- Add Player selects the new entry
page.add:SetText("Newcomer-Realm1")
page.addButton._scripts.OnClick(page.addButton)
check(M.PSS_PlayerPosition("Newcomer-Realm1") > 0 and pane.row.entry == "Newcomer-Realm1", "Add Player did not add and select")
check(pane.excl.whisper:GetChecked() == false, "a new entry is not fully blocked")

-- a tab click deselects
win.tabs[1]._scripts.OnClick(win.tabs[1])
check(pane.totals.frame:IsShown() and not pane.body:IsShown(), "a tab click did not deselect")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

if not fail then print(("PASS players (%d listed)"):format(M.PSS_PlayerCount())) end
