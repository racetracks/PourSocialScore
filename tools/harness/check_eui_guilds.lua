-- Guild Ignore List queries (core, 3.1 Step E.5) and the Guilds tab of the
-- EllesmereUI window. Runs on the save check_eui_window.lua phase 1 wrote
-- (integration on), with PourSocialScore_EllesmereUI from PSS_EXTRA_ADDONS.
--   core: (PourSocialScore_Libraries) M.PSS_GuildRows (order, search, reused tables), M.PSS_GuildMembers
--         (sort, search), Guild Search results for the window that asked
--   tab:  pooled rows (400 guilds, 1,500 members draw with a screenful of
--         rows), sorting, search, the pane (W I G P C, Scan Fields), Scan,
--         Scan All and the key binding with the /who cooldown, the members
--         view (note, W I G P C, confirmed removal), managed groups, the
--         Guild Exclusion List, Guild Search with Save, confirmed Remove
--         Guild, block history on demand (type filters, names), the
--         Block History view (search, sort, links, copy, All), back /
--         forward, mouse buttons 4 / 5, Escape up a level;
--         PourSocialScore_GUI never loads
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui guilds: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local E = EllesmereUI

-- /who: every filter sent, and the answer the next WHO_LIST_UPDATE reads
local sent, answer = {}, {}
C_FriendList.SendWho = function(filter) sent[#sent + 1] = filter end
C_FriendList.GetNumWhoResults = function() return #answer, #answer end
C_FriendList.GetWhoInfo = function(i) return answer[i] end
local function answerWho(list)
	answer = list
	H.Fire("WHO_LIST_UPDATE")
	answer = {}
end
local function lastSent() return sent[#sent] end

-- 400 guilds, one of them with 1,500 members
local N, MEMBERS = 400, 1500
local t0 = os.clock()
for i = 1, N do M.PSS_AddGuild(("Tour Guild %03d"):format(i)) end
M.PSS_AddGuild("Big Guild")
for i = 1, MEMBERS do M.PSS_UpdateGuildMember("Big Guild", ("Member%04d-Realm1"):format(i)) end
H.RunTimers()
local bigKey = M.PSS_NormalizeGuild("Big Guild")
print(("eui guilds: %d guild rules added, %d members in %.2fs"):format(N + 1, MEMBERS, os.clock() - t0))

------------------------------------------------------------------ core
-- the queries are in PourSocialScore_Libraries (load on demand): nothing in
-- memory until a window opens
check(loaded("PourSocialScore_Libraries") or M.PSS_GuildRows == nil, "guild queries loaded without PourSocialScore_Libraries")
M.PSS_Need("Libraries")
check(M.PSS_GuildRows ~= nil, "no guild queries after PourSocialScore_Libraries loaded")
-- display order: managed group headers, the exclusion header, the guilds A-Z
local rows, n = M.PSS_GuildRows("guild", true, nil, {})
local exclAt, firstGuild
for i = 1, n do
	local it = rows[i]
	if it.exclHeader then exclAt = i
	elseif not it.header and not it.exclItem and not firstGuild then firstGuild = i end
end
check(exclAt and firstGuild and exclAt < firstGuild, "exclusion header not before the guilds")
for i = 1, (exclAt or 1) - 1 do check(rows[i].header or rows[i].inGroup, "row before the exclusion header that is not a group") end
local prev
for i = firstGuild or 1, n do
	local it = rows[i]
	if not it.inGroup and not it.header then
		local nv = string.lower(it.g.name)
		if prev and prev > nv then check(false, "guilds out of order at " .. i) break end
		prev = nv
	end
end
-- the same tables on the next call (no garbage per redraw)
local item = rows[firstGuild]
local again = M.PSS_GuildRows("guild", true, nil, rows)
check(again == rows and rows[firstGuild] == item, "rows not reused")
-- into.nest (3.2.0-dev005): one Managed Communities row over the groups,
-- open unless closed; the PSS window (no nest) has none
do
	local plain = 0
	for i = 1, n do if rows[i].managedHeader then plain = plain + 1 end end
	check(plain == 0, "Managed Communities row without nest")
	local nr = { nest = true }
	local _, nn = M.PSS_GuildRows("guild", true, nil, nr)
	local heads = 0
	for k in pairs(nr.groups) do heads = heads + 1 end
	if heads > 0 then
		local mh = nr[1]
		check(mh.managedHeader and mh.open and mh.groups == heads, "Managed Communities row not first")
		local guilds, total = 0, 0
		for k, items in pairs(nr.groups) do
			guilds = guilds + #items
			total = total + (nr.heads[k].bc.total or 0)
			check(nr.heads[k].nested, "group header not nested")
		end
		check(mh.guilds == guilds and mh.bc.total == total, "Managed Communities row sums")
		check(nn == n + 1, ("nest rows %d, want %d"):format(nn, n + 1))
		check(PourSocialScoreDB.guildGroupOpen[M.PSS_GUILD_MANAGED_SHUT] == nil, "an open row was saved")
		M.PSS_SetGuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT, true)
		local _, shut = M.PSS_GuildRows("guild", true, nil, nr)
		local inside = 0
		for i = 1, shut do if nr[i].header or nr[i].inGroup then inside = inside + 1 end end
		check(not nr[1].open and inside == 0 and nr.heads[next(nr.groups)] ~= nil, "closed row still lists the groups")
		M.PSS_SetGuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT, false)
		check(PourSocialScoreDB.guildGroupOpen[M.PSS_GUILD_MANAGED_SHUT] == nil, "reopened row still saved")
	end
end
local all = M.PSS_GuildCount()
check(all >= N + 1, "guild count " .. all)
local _, found = M.PSS_GuildRows("guild", true, "TOUR GUILD 01", {})
check(found == 10, "guild search found " .. tostring(found))
rows = M.PSS_GuildRows("members", false, "guild", rows)
check(rows[1].key == bigKey, "members sort: Big Guild not first")

local mem, mn, mtotal = M.PSS_GuildMembers(bigKey, "name", true, nil, {})
check(mn == MEMBERS and mtotal == MEMBERS, ("members %s / %s"):format(tostring(mn), tostring(mtotal)))
for i = 2, mn do
	if string.lower(mem[i - 1].name) > string.lower(mem[i].name) then check(false, "members out of order at " .. i) break end
end
check(mem.stored[mem[1]] ~= nil, "stored key missing")
local again2, mn2 = M.PSS_GuildMembers(bigKey, "name", false, "member01", mem)
check(again2 == mem and mn2 == 100, "member search found " .. tostring(mn2))
check(string.lower(mem[1].name) > string.lower(mem[2].name), "members Z-A")
check(select(2, M.PSS_GuildMembers("no such guild", "name", true, nil, {})) == nil, "members of a missing rule")

------------------------------------------------------------------ window
SlashCmdList.PSS("gui")
local win = _G.PSS_EllesmereUIWindow
check(win and win:IsShown(), "no window")
win.tabs[2]:GetScript("OnClick")(win.tabs[2])
local page = win.pages[2]
local list, pane, st = page.list, page.pane, page.state
check(page:IsShown() and list and pane and st, "Guilds tab not built")
check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded")

-- a screenful of rows, whatever the list size
list.scroll:SetHeight(300)
list:Layout()
check(list.count == st.n and st.n > N, "list count " .. list.count)
check(#list.rows == 15 and list.shown == 15, "rows made: " .. #list.rows)
list.scroll:SetVerticalScroll(200 * list.rowH)
check(list.first == 200 and list.rows[1].index == 201, "scroll did not move the rows")
list.scroll:SetVerticalScroll(st.n * list.rowH)
check(list.rows[1].index <= st.n, "scrolled past the end")

local function rowFor(lst, i)
	lst.scroll:SetVerticalScroll((i - 1) * lst.rowH)
	for _, r in ipairs(lst.rows) do if r.index == i then return r end end
end
local function clickAt(lst, i, button)
	local r = rowFor(lst, i)
	check(r ~= nil, "no row for entry " .. i)
	if r then r:GetScript("OnClick")(r, button or "LeftButton") end
	H.Advance(1)		-- never a double-click by accident
end
local function indexOf(pred)
	for i = 1, st.n do if pred(st.rows[i]) then return i end end
end
local function selectGuild(key)
	clickAt(list, indexOf(function(it) return it.key == key end))
end

-- a header click sorts, again reverses it
local head
for _, h in ipairs(list.heads) do if h.key == "members" then head = h end end
head:GetScript("OnClick")(head)
check(st.key == "members" and st.asc == true, "header did not sort")
head:GetScript("OnClick")(head)
check(st.asc == false, "header did not reverse")
for _, h in ipairs(list.heads) do if h.key == "guild" then head = h end end
head:GetScript("OnClick")(head)

-- search
page.search:SetText("tour guild 01")
page.search:GetScript("OnTextChanged")(page.search, true)
check(list.count == 10, "search shows " .. list.count)
check(page.count:GetText():match("^10 of"), "count text " .. tostring(page.count:GetText()))
page.search:SetText("")
page.search:GetScript("OnTextChanged")(page.search, true)
check(list.count == st.n and st.n > N, "search not cleared")

-- select a guild: the pane shows it
local key = M.PSS_NormalizeGuild("Tour Guild 010")
selectGuild(key)
local gb = pane.guild
check(gb:IsShown() and not pane.none:IsShown(), "guild pane not shown")
check(gb.heading:GetText() == "Tour Guild 010", "pane heading " .. tostring(gb.heading:GetText()))
-- a click on the selected guild deselects it: every guild's totals
selectGuild(key)
check(not gb:IsShown() and pane.totals.frame:IsShown(), "guild deselect: totals not shown")
do
	local want = M.PSS_ListTotals("guilds", {})
	check(pane.totals.summary.values.all == want.total and pane.totals.counts.total == want.total, "guild totals")
end
selectGuild(key)
check(gb:IsShown() and not pane.totals.frame:IsShown(), "guild not selected again")
local _, g = M.PSS_FindGuildRule(key)

-- W unticked = blocked from the guild
local w = gb.excl.whisper
w:SetChecked(true)
w:GetScript("OnClick")(w, "LeftButton")
check(M.PSS_GuildBlock(g).whisper == false, "W not saved as allowed")
w:SetChecked(false)
w:GetScript("OnClick")(w, "LeftButton")
check(M.PSS_GuildBlock(g).whisper == true, "W not saved as blocked")

-- Scan Fields
pane.fieldsBox:SetText(" 80 ")
pane.fieldsBox:GetScript("OnEnterPressed")(pane.fieldsBox)
check(g.customScan == "80", "Scan Fields not saved: " .. tostring(g.customScan))

-- Scan: the /who, its answer adds members, the cooldown disables the scans
local before = #sent
gb.scan:GetScript("OnClick")(gb.scan)
check(#sent == before + 1 and lastSent():find('g-"Tour Guild 010"', 1, true), "Scan sent " .. tostring(lastSent()))
answerWho({
	{ fullName = "Scanned-Realm1", fullGuildName = "Tour Guild 010", level = 80, classStr = "Mage", filename = "MAGE" },
	{ fullName = "Scanned Two-Realm1", fullGuildName = "Tour Guild 010", level = 80, classStr = "Rogue", filename = "ROGUE" },
})
H.RunTimers(1)
check(M.PSS_ScanCooldownActive(), "no cooldown after a scan")
check(not gb.scan:IsEnabled() and not page.scanAll:IsEnabled() and not page.searchButton:IsEnabled(), "scan buttons enabled while cooling down")
before = #sent
M.PSS_ScanGuild(g.name, "sweep")
check(#sent == before, "a /who went out while cooling down")
H.RunTimers()
check(gb.scan:IsEnabled() and page.scanAll:IsEnabled(), "scan buttons not enabled after the cooldown")
local _, sn = M.PSS_GuildMembers(key, "name", true, nil, {})
check(sn == 2, "scan did not add the members: " .. tostring(sn))
check(gb.scan:GetText() == M.PSS_GuildSweepLabel(key) and gb.scan:GetText() ~= "Scan", "Scan label " .. tostring(gb.scan:GetText()))

-- Custom Scan sends the Scan Fields
H.Advance(10)
before = #sent
gb.custom:GetScript("OnClick")(gb.custom)
check(#sent == before + 1 and lastSent():find('g-"Tour Guild 010" 80', 1, true), "Custom Scan sent " .. tostring(lastSent()))
answerWho({})
H.RunTimers()

-- Scan All, from the window and from the key binding
H.Advance(10)
before = #sent
page.scanAll:GetScript("OnClick")(page.scanAll)
check(#sent == before + 1, "Scan All sent nothing")
answerWho({})
H.RunTimers()
H.Advance(10)
before = #sent
PSS_ScanAllBinding()
check(#sent == before + 1, "the key binding sent nothing")
answerWho({})
H.RunTimers()

-- a blocked line redraws only the counts of the rows on screen
local drawn = list.rows[1].index
M.Events.Fire("GUILD_BLOCKS_CHANGED")
M.Events.Fire("GUILD_BLOCKS_CHANGED")
H.RunTimers()
check(list.rows[1].index == drawn and list.rows[1]:IsShown(), "rows lost after a block")

------------------------------------------------------------------ block history
-- a blocked whisper is counted at once; the block history
-- (PourSocialScore_Logging) loads only on Show Block History
check(not loaded("PourSocialScore_Logging"), "Logging loaded before any history was asked for")
local lineID = 90000
local function whisper(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg, author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
end
check(whisper("Member0100-Realm1", "cheap gold"), "member whisper not blocked")
H.RunTimers()
selectGuild(bigKey)
local hv = gb.hist
do
	local dp = gb.pages
	check(dp and #dp.buttons == 3 and gb.counts:GetParent() == dp.summary and hv.frame:GetParent() == dp.history
		and gb.membersButton:GetParent() == dp.rule and gb.removeButton:GetParent() == dp.rule, "guild detail pages")
	dp:Select("history")
	check(hv.frame:IsVisible() and not gb.removeButton:IsVisible(), "guild history page")
end
check(gb.counts:GetText():match("^Blocked 1"), "guild counts " .. tostring(gb.counts:GetText()))
-- the guild's Summary: the core's counts for the guild rule (not Logging)
gb.pages:Select("summary")
check(gb.summary.values.session == 1 and gb.summary.values.day == 1 and gb.summary.values.all == 1,
	("guild summary %s/%s/%s"):format(tostring(gb.summary.values.session), tostring(gb.summary.values.day), tostring(gb.summary.values.all)))
gb.pages:Select("history")
check(not loaded("PourSocialScore_Logging"), "selecting a guild with blocks loaded Logging")
check(hv.gate:IsShown() and hv.list.count == 0, "guild history read without Logging")
hv.gate:GetScript("OnClick")(hv.gate)
check(loaded("PourSocialScore_Logging") and hv.list.count == 1, "Show Block History: " .. hv.list.count)
local hc = hv.list.rows[1].cells
check(hc.name and hc.name:GetText() == "Member0100", "guild history name " .. tostring(hc.name and hc.name:GetText()))
check((hc.kind:GetText() or ""):match("|c%x+whisper|r"), "guild history type " .. tostring(hc.kind:GetText()))
check((hc.time:GetText() or ""):match("^%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d$"), "guild history time " .. tostring(hc.time:GetText()))

-- the Block History view: a double-click on a line opens it in place of
-- the tab, with the type boxes and a search over player, channel, message
check(whisper("Member0101-Realm1", "wts |cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"), "second whisper not blocked")
H.Advance(1)
H.RunTimers()
check(hv.list.count == 2, "pane history after a second block: " .. hv.list.count)
local r1 = hv.list.rows[1]
r1:GetScript("OnClick")(r1, "LeftButton")
check(not page.hview, "one click opened the Block History view")
r1:GetScript("OnClick")(r1, "LeftButton")
local view = page.hview
check(view and view:IsOpen() and view.frame:IsShown() and not page:IsShown(), "double-click did not open the Block History view")
check(view.list.count == 2 and (view.heading:GetText() or ""):match("Big Guild"), "view of the guild: " .. view.list.count)
check((win.where:GetText() or ""):match("Block History: Big Guild"), "where line " .. tostring(win.where:GetText()))
check(view.list.rows[1]._links == true, "links in the view not clickable")
check(view.list.rows[1].cells.member:GetText() ~= "" and view.list.rows[1].cells.channel:GetText() == "Whisper", "player / channel cells")
local function find(text)
	view.search:SetText(text)
	view.search:GetScript("OnTextChanged")(view.search, true)
	return view.list.count
end
check(find("thunderfury") == 1, "message search")
check(find("member0100") == 1, "player search")
check(find("whisper") == 2, "channel search")
check(find("") == 2, "search not cleared")
-- the Guilds drop-down: every guild rule A-Z; a pick shows that guild
do
	check(view.pick:IsShown(), "no Guilds drop-down in a guild's view")
	local items = view.pick:MenuButtons()
	local rules = 0
	for _, g in pairs(PourSocialScoreDB.guildData) do if type(g) == "table" then rules = rules + 1 end end
	check(#items == rules and rules >= N + 1, ("drop-down guilds %d of %d"):format(#items, rules))
	local ok = true
	for i = 2, #items do if string.lower(items[i - 1].text) > string.lower(items[i].text) then ok = false end end
	check(ok, "drop-down not A-Z")
	local tour
	for _, it in ipairs(items) do if it.text == "Tour Guild 001" then tour = it end end
	tour.fn()
	check(view:IsOpen() and (view.heading:GetText() or ""):match("Tour Guild 001") and view.list.count == 0, "drop-down pick " .. tostring(view.heading:GetText()))
	check(view.allButton:IsShown() and view.allButton:GetText() == "All Guilds", "All Guilds button gone")
	for _, it in ipairs(view.pick:MenuButtons()) do if it.text == "Big Guild" then it.fn() end end
	check(view.list.count == 2, "back to Big Guild: " .. view.list.count)
end
-- a type box in the view filters the pane too, and back
local vw = view.boxes.whisper
vw:SetChecked(false)
vw:GetScript("OnClick")(vw)
check(view.list.count == 0 and not hv.boxes.whisper:GetChecked() and hv.list.count == 0, "type box not shared")
vw:SetChecked(true)
vw:GetScript("OnClick")(vw)
check(view.list.count == 2 and hv.list.count == 2, "type box not back")
-- sort by Player (A-Z)
local ph
for _, h in ipairs(view.list.heads) do if h.key == "member" then ph = h end end
ph:GetScript("OnClick")(ph)
check(view.sortKey == "member" and view.sortAsc and view.shown[1].member < view.shown[2].member, "sort by player")
-- a double-click on a line: the message in the copy box
H.Advance(1)
local vr = view.list.rows[1]
local copies = #E.log.copies
vr:GetScript("OnClick")(vr, "LeftButton")
vr:GetScript("OnClick")(vr, "LeftButton")
check(#E.log.copies == copies + 1, "double-click did not copy the message")
-- All Guilds, Back to the guild, Escape back to the tab
view.allButton:GetScript("OnClick")(view.allButton)
check(view.spec.id == false and (view.heading:GetText() or ""):match("All Guilds") and view.list.count >= 2, "All Guilds")
win.back:GetScript("OnClick")(win.back)
check(view:IsOpen() and view.spec.id == bigKey, "Back did not return to the guild's history")
check(E.PressEscape() and win:IsShown() and not view:IsOpen() and page:IsShown(), "Escape did not close the Block History view")
win.back:GetScript("OnClick")(win.back)
check(view:IsOpen() and view.spec.id == bigKey, "Back did not reopen the Block History view")
win.tabs[1]:GetScript("OnClick")(win.tabs[1])
check(not view.frame:IsShown() and not page:IsShown(), "view shown on another tab")
win.tabs[2]:GetScript("OnClick")(win.tabs[2])
check(view.frame:IsShown() and not page:IsShown(), "view not back with its tab")
check(E.PressEscape() and not view:IsOpen() and page:IsShown(), "Escape did not close the view")

------------------------------------------------------------------ members view
selectGuild(bigKey)
gb.membersButton:GetScript("OnClick")(gb.membersButton)
local mlist, mview = page.members, page.membersView
check(mview:IsShown() and not list.scroll:IsVisible(), "members view not shown")
mlist.scroll:SetHeight(280)
mlist:Layout()
check(mlist.count == MEMBERS and #mlist.rows == 14, ("members %d, rows %d"):format(mlist.count, #mlist.rows))
mlist.scroll:SetVerticalScroll(1000 * mlist.rowH)
check(mlist.rows[1].index == 1001, "members scroll")
check(page.count:GetText() == MEMBERS .. " members", "members count " .. tostring(page.count:GetText()))
page.search:SetText("member01")
page.search:GetScript("OnTextChanged")(page.search, true)
check(mlist.count == 100 and page.count:GetText():match("^100 of"), "member search " .. mlist.count)
page.search:SetText("")
page.search:GetScript("OnTextChanged")(page.search, true)
check(mlist.count == MEMBERS, "member search not cleared")
check(pane.guild:IsShown(), "guild pane hidden with no member selected")

clickAt(mlist, 5)
local m = st.msel
check(m and pane.member:IsShown() and not pane.guild:IsShown(), "member pane not shown")
pane.noteBox:SetText("  spammer  ")
pane.noteBox:GetScript("OnEnterPressed")(pane.noteBox)
check(m.note == "spammer", "member note not saved: " .. tostring(m.note))
local mw = pane.member.excl.whisper
check(mw:GetAlpha() < 1, "a member box not dimmed while following the guild")
mw:SetChecked(true)
mw:GetScript("OnClick")(mw, "LeftButton")
check(M.PSS_MemberBlock(m).whisper == false and mw:GetAlpha() == 1, "member W not set")
mw:GetScript("OnClick")(mw, "RightButton")
check(M.PSS_MemberBlock(m).whisper == nil, "member W not back to the guild's")

local nPopups = #E.log.popups
pane.member.pages:Select("summary")
check(pane.member.summary.values.all == pane.member.summary.allTime and pane.member.summary.owner == M.PSS_History.MemberKey(m), "member summary")
pane.member.pages:Select("rule")
local removeMember = pane.member.removeButton
check(pane.member.pages and removeMember:GetParent() == pane.member.pages.rule
	and pane.member.hist.frame:GetParent() == pane.member.pages.history, "member detail pages")
removeMember:GetScript("OnClick")(removeMember)
check(#E.log.popups == nPopups + 1 and E.log.popups[#E.log.popups].confirmText == "Remove", "member removal not confirmed")
E.log.popups[#E.log.popups].onConfirm()
check(mlist.count == MEMBERS - 1 and st.msel == nil, "member not removed: " .. mlist.count)
mview.back:GetScript("OnClick")(mview.back)
check(list.scroll:IsVisible() and not mview:IsShown(), "back to the guilds")

------------------------------------------------------------------ back / forward, Escape
-- Escape goes up a level, back / forward step through the views
local eo = E.log.escapeOpts[win]
check(eo and eo.onEscape, "Escape not handed to EllesmereUI with a step back")
gb.membersButton:GetScript("OnClick")(gb.membersButton)
check(mview:IsShown(), "members view not shown again")
check((win.where:GetText() or ""):match("Members of <Big Guild>"), "where line " .. tostring(win.where:GetText()))
check(E.PressEscape() and win:IsShown() and not mview:IsShown() and list.scroll:IsVisible(), "Escape did not go back to the guilds")
check(win.back:IsEnabled() and not win.forward:IsEnabled(), "arrows after Escape")
win.back:GetScript("OnClick")(win.back)
check(mview:IsShown() and st.mguild == bigKey, "Back did not return to the members")
check(win.forward:IsEnabled(), "Forward disabled after Back")
win.forward:GetScript("OnClick")(win.forward)
check(not mview:IsShown() and list.scroll:IsVisible(), "Forward did not return to the guilds")
-- mouse buttons 4 / 5, over the window only
win._mouseOver = false
H.Fire("GLOBAL_MOUSE_UP", "Button4")
check(not mview:IsShown(), "mouse button 4 away from the window went back")
win._mouseOver = true
H.Fire("GLOBAL_MOUSE_UP", "Button4")
check(mview:IsShown(), "mouse button 4 did not go back")
H.Fire("GLOBAL_MOUSE_UP", "LeftButton")
check(mview:IsShown(), "a left click stepped")
H.Fire("GLOBAL_MOUSE_UP", "Button5")
check(not mview:IsShown(), "mouse button 5 did not go forward")
-- across tabs
win.tabs[5]:GetScript("OnClick")(win.tabs[5])
check(win.pages[5]:IsShown(), "Options tab not shown")
H.Fire("GLOBAL_MOUSE_UP", "Button4")
check(page:IsShown() and not win.pages[5]:IsShown(), "Back did not return to the Guilds tab")
-- at the top Escape closes; closed, the mouse buttons are not listened to
check(E.PressEscape() and not win:IsShown(), "Escape at the top did not close the window")
check(not win:IsEventRegistered("GLOBAL_MOUSE_UP"), "mouse buttons listened to while closed")
SlashCmdList.PSS("gui")
check(win:IsShown() and page:IsShown() and win:IsEventRegistered("GLOBAL_MOUSE_UP"), "window not back")
win._mouseOver = nil

------------------------------------------------------------------ groups, exclusions
local hi = indexOf(function(it) return it.header end)
if hi then
	-- the window's list (EUI 1.1.0-dev008): the groups under the Managed
	-- Communities row, indented, without the "Managed Communities - " prefix
	check(st.rows[1].managedHeader and st.rows[hi].nested, "no Managed Communities row in the window")
	local hr = rowFor(list, hi)
	local ht = hr and hr.cells.guild:GetText() or ""
	check(not ht:find("Managed Communities -", 1, true) and ht:sub(1, 3) == "   ", "nested group row text: " .. ht)
	local gk = st.rows[hi].groupKey
	local wasOpen = M.PSS_GuildGroupOpen(gk)
	clickAt(list, hi)
	check(M.PSS_GuildGroupOpen(gk) ~= wasOpen and pane.group:IsShown(), "group header click")
	-- the list's two pies (EUI 1.1.0-dev006): periods summed over its
	-- guilds' own counts, all-time blocks by type; Logging stays unloaded
	local History = M.PSS_History
	local items = st.rows.groups[gk]
	local g1, g2 = items[1].key, items[2] and items[2].key or items[1].key
	History.CountRecent(History.GuildKey(g1), nil, "whisper")
	History.CountRecent(History.GuildKey(g2), nil, "world")
	local s, d = 0, 0
	for _, it in ipairs(items) do
		local a, b = History.RecentCounts(History.GuildKey(it.key))
		s, d = s + a, d + b
	end
	local logging = loaded("PourSocialScore_Logging")
	st.dirty = true
	page.refresh()
	local gp = pane.group
	local hdr = st.rows[indexOf(function(it) return it.header and it.groupKey == gk end)]
	check(gp.charts:IsShown() and gp.summary.pie ~= nil, "group pies not shown")
	local v = gp.summary.values
	check(v.session == s and v.day == d and s >= 2 and d >= 2,
		("group period pie %s/%s, want %d/%d"):format(tostring(v.session), tostring(v.day), s, d))
	check(v.all == (hdr.bc.total or 0), "group all-time count is not the list's total")
	-- the same tick boxes as a guild's Summary; All time starts unticked
	check(gp.summary.boxes.all and not gp.summary.boxes.all:GetChecked() and gp.summary.boxes.session:GetChecked(),
		"group tick boxes (All time should start off)")
	check(gp.summary.viewButton:IsShown(), "no View Events on a default guild list")
	local want = 0
	for _, cat in ipairs(History.ALL_CATS) do if (hdr.bc[cat] or 0) > 0 then want = want + 1 end end
	local tp = gp.typePie
	check(tp.count == want, ("group type pie %s types, want %d"):format(tostring(tp.count), want))
	for i = 1, tp.count do
		local sl = tp.slices[i]
		check(sl.value == hdr.bc[sl.cat], "group type slice " .. tostring(sl.cat))
	end
	check(tp.empty:IsShown() == (want == 0), "group type pie empty text")
	check(loaded("PourSocialScore_Logging") == logging, "group pies loaded the block history")
	-- a type tick box takes its slice out (the count stays), shared by the
	-- type pies; ticked again, it is back
	if tp.count > 0 then
		local k1 = tp.keys[1]
		local cat = k1.cat
		local sum = 0
		for i = 1, tp.count do sum = sum + tp.slices[i].value end
		k1.check:SetChecked(false)
		k1.check:GetScript("OnClick")(k1.check)
		check(tp.slices[1].draw == 0 and tp.slices[1].value == hdr.bc[cat] and tp.pie.total == sum - hdr.bc[cat],
			"unticked type still in the pie")
		pane.totals:Show(st.rows)
		local ttp = pane.totals.typePie
		local shared = false
		for i = 1, ttp.count do if ttp.keys[i].cat == cat then shared = not ttp.keys[i].check:GetChecked() and ttp.slices[i].draw == 0 end end
		check(shared, "type tick box not shared with the list totals")
		pane.totals:Hide()
		k1.check:SetChecked(true)
		k1.check:GetScript("OnClick")(k1.check)
		check(tp.slices[1].draw == nil and tp.pie.total == sum, "ticked type not back")
	end
	-- View Events and a slice: the list's lines in the Block History view
	-- every counted block shows: its line, or a "Counted, not stored" /
	-- expired row (world chat of a list's guilds is counted, never stored)
	-- (the two blocks counted above are in no line: they show as rows)
	local wantBlocks = s
	for _, it in ipairs(items) do wantBlocks = math.max(wantBlocks, M.PSS_GetGuildBlockCounts(it.key).total or 0) end
	local t0 = os.clock()
	gp.summary.viewButton:GetScript("OnClick")(gp.summary.viewButton)
	print(("eui guilds: a default guild list's view (%d guilds) read in %.3fs"):format(#items, os.clock() - t0))
	local gv = page.hview
	local shownBlocks = 0
	for _, h in ipairs(gv and gv.all or {}) do shownBlocks = shownBlocks + (h.expired or 1) end
	check(gv and gv:IsOpen() and gv.spec.kind == "group" and gv.spec.id == gk and shownBlocks >= wantBlocks and wantBlocks >= 2,
		("View Events on a default guild list: %d blocks shown, %d counted"):format(shownBlocks, wantBlocks))
	-- one counted row per type and 10 minutes for the whole list
	local seen, dup = {}, false
	for _, h in ipairs(gv.all) do
		if h.expired then
			local k = h.cat .. "/" .. tostring(h.ts) .. "/" .. h.channel
			if seen[k] then dup = true end
			seen[k] = true
		end
	end
	check(not dup, "counted rows of a default guild list not merged")
	-- its Reset asks first (it clears every guild in the list)
	local asked = #E.log.popups
	gv.resetButton:GetScript("OnClick")(gv.resetButton)
	check(#E.log.popups == asked + 1, "a default guild list's Reset did not ask")
	if EUIConfirmDimmer then EUIConfirmDimmer:Hide() end
	check(E.PressEscape() and not gv:IsOpen() and page:IsShown(), "Escape did not close the list's view")
	gp.summary:Open(gp.summary.map[1])
	check(gv:IsOpen() and gv.spec.kind == "group" and gv.period == "session", "a slice of a default guild list")
	-- this session's blocks show even when their 10 minutes began before it
	local sessionBlocks = 0
	for i = 1, gv.list.count do sessionBlocks = sessionBlocks + (gv.shown[i].expired or 1) end
	check(sessionBlocks >= s, ("this session's slice shows %d of %d blocks"):format(sessionBlocks, s))
	check(E.PressEscape() and not gv:IsOpen(), "Escape did not close the slice's view")
	-- the Managed Communities row: every list added up, a click opens or
	-- closes it (only a closed row is saved)
	clickAt(list, 1)
	check(st.selKind == "managed" and pane.group:IsShown() and not gp.toggle:IsShown(), "Managed Communities row click")
	check(PourSocialScoreDB.guildGroupOpen[M.PSS_GUILD_MANAGED_SHUT] == true and st.rows[1].open == false, "Managed Communities row did not close")
	local mh = st.rows[1]
	check(gp.summary.values.all == (mh.bc.total or 0) and gp.typePie.count >= tp.count, "Managed Communities totals")
	check(gp.summary.viewButton:IsShown(), "no View Events on Managed Communities")
	local inside = 0
	for i = 1, st.n do if st.rows[i].header or st.rows[i].inGroup then inside = inside + 1 end end
	check(inside == 0, "closed Managed Communities row still lists groups")
	-- a block in a list's guild (not on screen) updates the row and pane
	do
		local real, before = M.PSS_GetGuildBlockCounts, mh.bc.total or 0
		M.PSS_GetGuildBlockCounts = function(key)
			local c = real(key)
			if key ~= g1 then return c end
			local t = {}
			for k, v in pairs(c) do t[k] = v end
			t.total, t.world = (t.total or 0) + 1, (t.world or 0) + 1
			return t
		end
		M.Events.Fire("GUILD_BLOCKS_CHANGED")
		H.Advance(1)
		H.RunTimers()
		M.PSS_GetGuildBlockCounts = real
		check(st.rows[1].bc.total == before + 1 and gp.summary.values.all == before + 1,
			("Managed Communities after a block: %s / %s, want %d"):format(tostring(st.rows[1].bc.total), tostring(gp.summary.values.all), before + 1))
		st.dirty = true
		page.refresh()
	end
	gp.open:GetScript("OnClick")(gp.open)
	check(PourSocialScoreDB.guildGroupOpen[M.PSS_GUILD_MANAGED_SHUT] == nil and st.rows[1].open, "Expand on Managed Communities")
	local ii = indexOf(function(it) return it.inGroup end)
	if ii then
		local sk = st.rows[ii].key
		selectGuild(sk)
		check(not gb.removeButton:IsEnabled() == (M.PSS_IsStaticManagedGuild(sk) and true or false), "Remove Guild on a default list guild")
	end
else
	print("eui guilds: no default guild lists in this save (group rows not checked)")
end

page.excl:SetText("Friendly Guild")
page.exclButton:GetScript("OnClick")(page.exclButton)
check(M.PSS_IsGuildExcluded("Friendly Guild"), "Exclude did not add")
H.RunTimers()
M.PSS_SetGuildGroupOpen(M.PSS_GUILD_EXCL_OPEN, false)
st.dirty = true
page.refresh()
local ei = indexOf(function(it) return it.exclHeader end)
clickAt(list, ei)
check(M.PSS_GuildGroupOpen(M.PSS_GUILD_EXCL_OPEN) and pane.info:IsShown(), "exclusion header click")
local xi = indexOf(function(it) return it.exclItem and it.name == "Friendly Guild" end)
check(xi ~= nil, "excluded guild not listed")
clickAt(list, xi)
pane.info.removeButton:GetScript("OnClick")(pane.info.removeButton)
check(not M.PSS_IsGuildExcluded("Friendly Guild"), "exclusion not removed")
H.RunTimers()

------------------------------------------------------------------ Guild Search
H.Advance(10)
page.add:SetText("Tour")
page.searchButton:GetScript("OnClick")(page.searchButton)
check(lastSent() and lastSent():find('g-"Tour"', 1, true), "Guild Search sent " .. tostring(lastSent()))
answerWho({
	{ fullName = "Newbie-Realm1", fullGuildName = "Tour New Guild", level = 70 },
	{ fullName = "Old-Realm1", fullGuildName = "Tour Guild 001", level = 70 },
})
H.RunTimers()
local picker = page.picker
check(picker:IsShown() and #picker.items == 2, "Guild Search results not shown")
check(M.PSSGuildSearchFrame == nil, "the PSS window picker opened")
local pi
for i, it in ipairs(picker.items) do if it.name == "Tour New Guild" then pi = i end end
for _, it in ipairs(picker.items) do if it.name == "Tour Guild 001" then check(it.listed, "listed guild not marked") end end
clickAt(picker.list, pi)
picker.saveButton:GetScript("OnClick")(picker.saveButton)
H.RunTimers()
check(M.PSS_IsGuildListed("Tour New Guild"), "Save did not add the guild")
check(not picker:IsShown() and list.scroll:IsVisible(), "results not closed")
check(M.PSS_GuildSearchCache == nil, "search cache kept")
-- Escape closes the Guild Search results, the window stays
H.Advance(10)
page.add:SetText("Tour")
page.searchButton:GetScript("OnClick")(page.searchButton)
answerWho({ { fullName = "Other-Realm1", fullGuildName = "Tour Other Guild", level = 70 } })
H.RunTimers()
check(picker:IsShown(), "second Guild Search not shown")
check(E.PressEscape() and win:IsShown() and not picker:IsShown() and list.scroll:IsVisible(), "Escape did not close the Guild Search results")

-- Add Guild selects the new rule
page.add:SetText("Tour Added Guild")
page.addButton:GetScript("OnClick")(page.addButton)
check(M.PSS_IsGuildListed("Tour Added Guild"), "Add Guild did not add")
check(st.selKind == "guild" and st.sel == M.PSS_NormalizeGuild("Tour Added Guild"), "Add Guild did not select")

-- Remove Guild asks first
nPopups = #E.log.popups
gb.removeButton:GetScript("OnClick")(gb.removeButton)
check(#E.log.popups == nPopups + 1, "guild removal not confirmed")
check(M.PSS_IsGuildListed("Tour Added Guild"), "removed before the confirmation")
E.log.popups[#E.log.popups].onConfirm()
H.RunTimers()
check(not M.PSS_IsGuildListed("Tour Added Guild"), "guild not removed")
check(pane.totals.frame:IsShown(), "pane still shows a removed guild")

-- the PSS window keeps working on the same functions
check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded by the tab")
SlashCmdList.PSS("gui force")
check(loaded("PourSocialScore_GUI") and _G.PSS and _G.PSS:IsShown(), "/pss gui force")
M.PSS_ShowGuildDetail(bigKey)
local f = M.PSSGuildDetailFrame
check(f and f:IsShown() and f.count:GetText():match("^" .. (MEMBERS - 1) .. " members"), "native members window " .. tostring(f and f.count:GetText()))

if not fail then print("PASS eui guilds") end
