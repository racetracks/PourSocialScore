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
check(gb.counts:GetText():match("^Blocked 1"), "guild counts " .. tostring(gb.counts:GetText()))
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
local removeMember = pane.member.removeButton
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
	local gk = st.rows[hi].groupKey
	local wasOpen = M.PSS_GuildGroupOpen(gk)
	clickAt(list, hi)
	check(M.PSS_GuildGroupOpen(gk) ~= wasOpen and pane.group:IsShown(), "group header click")
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
check(pane.none:IsShown(), "pane still shows a removed guild")

-- the PSS window keeps working on the same functions
check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded by the tab")
SlashCmdList.PSS("gui force")
check(loaded("PourSocialScore_GUI") and _G.PSS and _G.PSS:IsShown(), "/pss gui force")
M.PSS_ShowGuildDetail(bigKey)
local f = M.PSSGuildDetailFrame
check(f and f:IsShown() and f.count:GetText():match("^" .. (MEMBERS - 1) .. " members"), "native members window " .. tostring(f and f.count:GetText()))

if not fail then print("PASS eui guilds") end
