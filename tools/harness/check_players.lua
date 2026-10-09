-- The new window's Player Ignore List tab (3.4.0-dev007), as a run.lua
-- script on any save, real ones included: /pss gui builds it; with nothing
-- selected the pane shows the list's totals (equal to M.PSS_ListTotals);
-- then, on 200 added players, an NPC and a server: pooled rows, sorting,
-- search, the detail pane (lines from Libraries, note, expiry, W I G P C,
-- exceptions), a block counted at once with the Summary pie, the history
-- loaded only on Show Block History, confirmed removal and Add Player; the
-- close button and the title sit above the frame art.
local fail = false
local function check(ok, msg) if not ok then print("FAIL players: " .. msg) fail = true end end

-- exceptions (3.4.0.22): ticked = it happens; a tick away from the default
-- (the Options tab, or a member's guild) is an exception, marked so, and
-- read by the engine; ticking it back removes it
local function CheckExceptions(ex, t, parent, what)
	check(ex and #ex.boxes == #M.PSS_OverrideOptions(), what .. ": no exception tick boxes")
	if not ex then return end
	for _, b in ipairs(ex.boxes) do
		local key = b.opt.key
		local base = M.PSS_Opt(key, parent and { guild = parent } or nil) == true
		check(b:GetChecked() == base and not b.label:GetText():find("exception", 1, true), what .. " " .. key .. ": not on the default")
		b:SetChecked(not base)
		b._scripts.OnClick(b)
		check(t.opts and t.opts[key] == (not base) and b:GetChecked() == (not base) and b.label:GetText():find("(exception)", 1, true) ~= nil,
			what .. " " .. key .. ": exception not made")
		check(M.PSS_Opt(key, { person = t.opts, guild = parent }) == (not base), what .. " " .. key .. ": the engine does not read the exception")
		b:SetChecked(base)
		b._scripts.OnClick(b)
		check((t.opts == nil or t.opts[key] == nil) and not b.label:GetText():find("exception", 1, true), what .. " " .. key .. ": exception not removed")
	end
end
local loaded = C_AddOns.IsAddOnLoaded

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window
check(win and win:IsShown(), "/pss gui did not open the window")
win.tabs[1]._scripts.OnClick(win.tabs[1])
local page = win.pages[1]
local list, pane = page.list, page.pane
check(page:IsShown() and list and pane, "Players tab not built")
check(page.note == nil, "the placeholder note is gone")

-- the close button and the title above the frame art (its border is drawn
-- at a fixed level of about 500)
local chrome = win.chrome
check(chrome and win.art.blizzardClose:GetParent() == chrome and win.art.darkClose:GetParent() == chrome
	and win.title:GetParent() == chrome, "close buttons or title not on the raised frame")
win.art.blizzardClose._scripts.OnClick(win.art.blizzardClose)
check(not win:IsShown(), "the close button did not close the window")
SlashCmdList["PSS"]("gui")

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

CheckExceptions(pane.exceptions, M.PSS_GetPlayerRecord(entry), nil, "player")

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

-- (3.4.0.17, C1) Add Player with the box empty adds your target (another
-- player of your faction whose name can be read)
do
	local real = { UnitExists, UnitIsPlayer, UnitIsUnit, UnitFactionGroup, UnitName }
	_G.UnitExists = function(u) return u == "target" or u == "player" end
	_G.UnitIsPlayer = function() return true end
	_G.UnitFactionGroup = function() return "Alliance", "Alliance" end
	_G.UnitName = function(u) if u == "target" then return "Targeted", "Otherrealm" end return real[5](u) end
	page.add:SetText("")
	page.addButton._scripts.OnClick(page.addButton)
	check(M.PSS_PlayerPosition("Targeted-Otherrealm") > 0, "the target was not added with the box empty")
	_G.UnitFactionGroup = function(u) if u == "target" then return "Horde", "Horde" end return "Alliance", "Alliance" end
	_G.UnitName = function(u) if u == "target" then return "Enemy", "Otherrealm" end return real[5](u) end
	page.addButton._scripts.OnClick(page.addButton)
	check(M.PSS_PlayerPosition("Enemy-Otherrealm") == 0, "a target of the other faction was added")
	_G.UnitExists, _G.UnitIsPlayer, _G.UnitIsUnit, _G.UnitFactionGroup, _G.UnitName = real[1], real[2], real[3], real[4], real[5]
end

-- (3.4.0.17, C1) Player Search: a /who from the click; the results picker
-- (listed players can't be ticked), Save adds the ticked; nobody found asks
-- to add the name anyway; Escape closes the picker
do
	local sent, answer = {}, {}
	local realSend, realNum, realInfo = C_FriendList.SendWho, C_FriendList.GetNumWhoResults, C_FriendList.GetWhoInfo
	C_FriendList.SendWho = function(filter) sent[#sent + 1] = filter end
	C_FriendList.GetNumWhoResults = function() return #answer, #answer end
	C_FriendList.GetWhoInfo = function(i) return answer[i] end
	local sb, picker = page.searchButton, page.picker
	check(sb and picker, "no Player Search button or picker")
	H.Advance(10)
	page.add:SetText("Searchme")
	sb._scripts.OnClick(sb)
	check(sent[#sent] == 'n-"Searchme"', "Player Search sent " .. tostring(sent[#sent]))
	answer = {
		{ fullName = "Searchme-Realm1", level = 70, classStr = "Mage", fullGuildName = "Some Guild" },
		{ fullName = "Searchmetoo-Realm1", level = 12, classStr = "Rogue" },
		{ fullName = "Targeted-Otherrealm", level = 80, classStr = "Priest" },
	}
	H.Fire("WHO_LIST_UPDATE")
	H.RunTimers(1)		-- the cooldown starts on the next frame
	check(not sb:IsEnabled(), "Player Search enabled during the /who cooldown")
	H.RunTimers()
	check(picker:IsShown() and not list.scroll:IsVisible() and picker.list.count == 3, "results picker not shown")
	local listed = 0
	for _, it in ipairs(picker.items) do if it.listed then listed = listed + 1 end end
	check(listed == 1, "listed players in the results: " .. listed)
	picker.list.spec.click(nil, 1)
	picker.saveButton._scripts.OnClick(picker.saveButton)
	check(not picker:IsShown() and M.PSS_PlayerPosition("Searchme-Realm1") > 0 and M.PSS_PlayerPosition("Searchmetoo-Realm1") == 0, "Save did not add the ticked player only")
	H.Advance(10)
	H.RunTimers()
	check(sb:IsEnabled(), "Player Search not enabled after the cooldown")
	-- nobody found: add anyway
	page.add:SetText("Nobodyhere")
	sb._scripts.OnClick(sb)
	answer = {}
	H.Fire("WHO_LIST_UPDATE")
	H.RunTimers()
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown() and cf.text:GetText():find("Nobodyhere", 1, true), "no add anyway question")
	check(cf.title:GetText() == "Add Player?", "add anyway title: " .. tostring(cf.title:GetText()))
	cf.accept._scripts.OnClick(cf.accept)
	check(M.PSS_IsPlayerListed("Nobodyhere"), "add anyway did not add")
	-- the picker closes on Escape (the window stays)
	H.Advance(10)
	H.RunTimers()
	page.add:SetText("Searchme")
	sb._scripts.OnClick(sb)
	answer = { { fullName = "Another-Realm1", level = 5, classStr = "Druid" } }
	H.Fire("WHO_LIST_UPDATE")
	H.RunTimers()
	check(picker:IsShown(), "picker not shown again")
	H.Advance(1)
	_G.PSS_WindowEscape:Hide()
	check(not picker:IsShown() and win:IsShown() and list.scroll:IsVisible(), "Escape did not close only the picker")
	C_FriendList.SendWho, C_FriendList.GetNumWhoResults, C_FriendList.GetWhoInfo = realSend, realNum, realInfo
	H.Advance(10)
	H.RunTimers()
end

-- (3.4.0.17, C1) Prune: a confirm with the days and how many that removes
do
	M.PSS_AddPlayer("Oldentry-Realm", "", 0)
	local pos = M.PSS_PlayerPosition("Oldentry-Realm")
	M.PSS_SetEntryDate(pos, "01 Jan 2020")
	local before = M.PSS_PlayerCount()
	page.pruneButton._scripts.OnClick(page.pruneButton)
	local cf = _G.PSS_Confirm
	check(cf:IsShown() and cf.number:IsShown() and cf.number:GetText() == "365", "Prune confirm without its days box")
	-- (3.4.0.18) the title says what it asks, no addon name; it sits above
	-- the frame art (raised over the Blizzard border)
	check(cf.title:GetText() == "Prune Players?", "Prune title: " .. tostring(cf.title:GetText()))
	local art = cf.pssParts and cf.pssParts.art
	if art and art.NineSlice and art.NineSlice.GetFrameLevel then
		check(cf.title:GetParent():GetFrameLevel() > art.NineSlice:GetFrameLevel(), "the popup title is under the frame border")
	end
	check(cf.note:GetText():find("^1 entry listed for 365 days or more") ~= nil, "Prune note: " .. tostring(cf.note:GetText()))
	cf.accept._scripts.OnClick(cf.accept)
	check(M.PSS_PlayerPosition("Oldentry-Realm") == 0 and M.PSS_PlayerCount() == before - 1, "Prune did not remove only the old entry")
	page.pruneButton._scripts.OnClick(page.pruneButton)
	cf.cancel._scripts.OnClick(cf.cancel)
	check(not cf.number:IsShown() or not cf:IsShown(), "Prune confirm stayed")
	check(M.PSS_PlayerCount() == before - 1, "Cancel pruned")
end

-- a tab click deselects
win.tabs[1]._scripts.OnClick(win.tabs[1])
check(pane.totals.frame:IsShown() and not pane.body:IsShown(), "a tab click did not deselect")

if not fail then print(("PASS players (%d listed)"):format(M.PSS_PlayerCount())) end
