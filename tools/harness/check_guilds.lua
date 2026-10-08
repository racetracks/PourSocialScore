-- The new window's Guild Ignore List tab, part 1 (3.4.0-dev008), as a
-- run.lua script on any save, real ones included: /pss tui builds it; with
-- nothing selected the pane shows the list's totals (equal to
-- M.PSS_ListTotals); the rows are the core's (M.PSS_GuildRows with the
-- Managed Communities row) with Libraries' text; then, on 300 added
-- guilds: pooled rows, sorting, search, selection, headings that open and
-- close, Exclude, Scan All with its status tip and the /who cooldown,
-- Guild Search with the results picker (Save, Tick All, Escape) for this
-- window only, an exclusion search with nothing found, Add Guild. Neither
-- old window loads.
local fail = false
local function check(ok, msg) if not ok then print("FAIL guilds: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

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
local lineID = 0

SlashCmdList["PSS"]("tui")
local win = _G.PSS_Window
win.tabs[2]._scripts.OnClick(win.tabs[2])
local page = win.pages[2]
local list, pane, V, picker = page.list, page.pane, page.state, page.picker
check(page:IsShown() and list and pane and V and picker, "Guilds tab not built")
check(not page.note:IsShown(), "the built tab still shows its note")
check(win.where:GetText() == "Guild Ignore List", "the line by the arrows")

-- nothing selected: the list's totals
local want = M.PSS_ListTotals("guilds", {}, V.rows)
check(pane.totals.frame:IsShown() and not pane.guild:IsShown() and not pane.group:IsShown(), "totals not shown with nothing selected")
local tv = pane.totals.summary.values
check(tv.all == (want.total or 0) and tv.session == (want.session or 0) and tv.day == (want.day or 0),
	("totals pie %d/%d/%d, want %d/%d/%d"):format(tv.session, tv.day, tv.all, want.session or 0, want.day or 0, want.total or 0))

-- the rows: the core's, with Libraries' text
local function rowFor(i)
	list.scroll:SetVerticalScroll((i - 1) * list.rowH)
	for _, r in ipairs(list.rows) do if r.index == i then return r end end
end
local function clickAt(i)
	local r = rowFor(i)
	check(r ~= nil, "no row for entry " .. tostring(i))
	if r then r._scripts.OnClick(r, "LeftButton") end
	H.Advance(1)		-- never a double-click by accident
end
local function indexOf(pred)
	for i = 1, V.n do if pred(V.rows[i]) then return i end end
end
local core, cn = M.PSS_GuildRows("guild", true, nil, { nest = true })
check(list.count == cn and V.n == cn, ("rows %d, core %d"):format(list.count, cn))
list.scroll:SetHeight(300)
list:Layout()
local cells = {}
for i = 1, math.min(cn, 10) do
	local r = rowFor(i)
	M.PSS_GuildRowCells(V.rows[i], "", V.rows.managedHead and true or false, cells)
	check(r and r.cells.guild:GetText() == cells.guild and r.cells.scan:GetText() == tostring(cells.scan), "row " .. i .. " text")
end
if V.rows[1] and V.rows[1].managedHeader then
	-- the Managed Communities row: a click closes it, and selects it
	local mh = V.rows[1]
	check(mh.open, "Managed Communities row starts closed")
	clickAt(1)
	check(V.selKind == "managed" and not V.rows[1].open and pane.group:IsShown(), "Managed Communities row click")
	local gp = pane.group
	check(gp.heading:GetText() == "Managed Communities" and not gp.toggle:IsShown() and gp.open:GetText() == "Expand", "Managed Communities body")
	check(gp.summary.values.all == (V.rows[1].bc.total or 0), "Managed Communities totals")
	clickAt(1)
	check(V.rows[1].open and PourSocialScoreDB.guildGroupOpen[M.PSS_GUILD_MANAGED_SHUT] == nil, "Managed Communities row did not open again")
	local hi = indexOf(function(it) return it.header end)
	local r = rowFor(hi)
	check(r and r.cells.guild:GetText():sub(1, 3) == "   " and not r.cells.guild:GetText():find("Managed Communities -", 1, true), "nested group row text")
end

-- 300 guilds
local before = M.PSS_GuildCount()
for i = 1, 300 do M.PSS_AddGuild(("Tui Guild %03d"):format(i)) end
H.RunTimers()
check(M.PSS_GuildCount() == before + 300, "guild count")
check(V.n >= 300 and list.count == V.n, "list did not redraw after the adds: " .. list.count)
check(page.count:GetText() == ("%d guild rules"):format(M.PSS_GuildCount()), "count text " .. tostring(page.count:GetText()))
check(#list.rows == 15, "rows made: " .. #list.rows)

-- sort and search
local head
for _, h in ipairs(list.heads) do if h.key == "guild" then head = h end end
head._scripts.OnClick(head)
check(list.sortKey == "guild" and list.sortAsc == false, "header click did not reverse the sort")
head._scripts.OnClick(head)
page.search:SetText("tui guild 01")
page.search._scripts.OnTextChanged(page.search, true)
check(list.count == 10 and page.count:GetText() == ("10 of %d"):format(M.PSS_GuildCount()), "search shows " .. list.count)
page.search:SetText("")
page.search._scripts.OnTextChanged(page.search, true)

-- select a guild; again: deselected; Escape and a tab click deselect too
local key = M.PSS_NormalizeGuild("Tui Guild 010")
local gi = indexOf(function(it) return it.key == key end)
clickAt(gi)
check(V.selKind == "guild" and V.sel == key and pane.guild:IsShown() and pane.guild.heading:GetText() == "Tui Guild 010", "guild not selected")
check(rowFor(gi).sel:IsShown(), "selected row not marked")
clickAt(gi)
check(V.selKind == nil and pane.totals.frame:IsShown(), "second click did not deselect")
clickAt(gi)
win.tabs[2]._scripts.OnClick(win.tabs[2])
check(V.selKind == nil, "a tab click did not deselect")

-- Exclude, the exclusion heading and an excluded guild
page.excl:SetText("Friendly Guild")
page.exclButton._scripts.OnClick(page.exclButton)
check(M.PSS_IsGuildExcluded("Friendly Guild") and page.excl:GetText() == "", "Exclude did not add")
H.RunTimers()
M.PSS_SetGuildGroupOpen(M.PSS_GUILD_EXCL_OPEN, false)
V.dirty = true
page.refresh()
local ei = indexOf(function(it) return it.exclHeader end)
clickAt(ei)
check(M.PSS_GuildGroupOpen(M.PSS_GUILD_EXCL_OPEN) and V.selKind == "exclHeader", "exclusion heading click")
local xi = indexOf(function(it) return it.exclItem and it.name == "Friendly Guild" end)
check(xi ~= nil, "excluded guild not listed")
clickAt(xi)
check(V.selKind == "excl" and pane.info:IsShown() and pane.info.heading:GetText() == "Friendly Guild" and pane.info.removeButton:IsShown(), "excluded guild not selected")

-- Scan All: one /who, its status tip, the cooldown disables the scans
H.Advance(10)
local n0 = #sent
page.scanAll._scripts.OnClick(page.scanAll)
check(#sent == n0 + 1, "Scan All sent nothing")
local tipText
local realTip = H.Private("PourSocialScore_UI").Tip
H.Private("PourSocialScore_UI").Tip = function(_, t) tipText = t end
page.scanAll._scripts.OnEnter(page.scanAll)
H.Private("PourSocialScore_UI").Tip = realTip
check(tipText and tipText:find("Guilds swept", 1, true) and tipText:find("Waiting for the /who answer", 1, true), "Scan All tip: " .. tostring(tipText))
answerWho({})
H.RunTimers(1)
if M.PSS_ScanCooldownActive() then
	check(not page.scanAll:IsEnabled() and not page.searchButton:IsEnabled(), "scan buttons enabled while cooling down")
end
H.RunTimers()
check(page.scanAll:IsEnabled() and page.searchButton:IsEnabled(), "scan buttons not enabled after the cooldown")

-- Guild Search: the picker for this window only
H.Advance(10)
page.add:SetText("Tui")
page.searchButton._scripts.OnClick(page.searchButton)
check(lastSent() and lastSent():find('g-"Tui"', 1, true), "Guild Search sent " .. tostring(lastSent()))
answerWho({
	{ fullName = "Newbie-Realm1", fullGuildName = "Tui New Guild", level = 70 },
	{ fullName = "Old-Realm1", fullGuildName = "Tui Guild 001", level = 70 },
})
H.RunTimers()
check(picker:IsShown() and #picker.items == 2 and not list.scroll:IsVisible(), "Guild Search results not shown")
check(picker.title:GetText():find("2 guild(s) found", 1, true), "picker title")
local pi
for i, it in ipairs(picker.items) do
	if it.name == "Tui New Guild" then pi = i end
	if it.name == "Tui Guild 001" then check(it.listed, "listed guild not marked") end
end
local pr
picker.list.scroll:SetHeight(240)
picker.list:Layout()
picker.list.scroll:SetVerticalScroll(0)
for _, r in ipairs(picker.list.rows) do if r.index == pi then pr = r end end
pr._scripts.OnClick(pr, "LeftButton")
check(picker.items[pi].ticked, "picker click did not tick")
picker.saveButton._scripts.OnClick(picker.saveButton)
H.RunTimers()
check(M.PSS_IsGuildListed("Tui New Guild"), "Save did not add the guild")
check(not picker:IsShown() and list.scroll:IsVisible(), "results not closed")
check(M.PSS_GuildSearchCache == nil, "search cache kept")
-- Escape closes the results, the window stays
H.Advance(10)
page.add:SetText("Tui")
page.searchButton._scripts.OnClick(page.searchButton)
answerWho({ { fullName = "Other-Realm1", fullGuildName = "Tui Other Guild", level = 70 } })
H.RunTimers()
check(picker:IsShown(), "second Guild Search not shown")
picker.allButton._scripts.OnClick(picker.allButton)
check(picker.items[1].ticked, "Tick All")
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and not picker:IsShown() and list.scroll:IsVisible(), "Escape did not close the results")
check(not M.PSS_IsGuildListed("Tui Other Guild"), "Escape saved the ticked guild")
-- another window's search does not open ours
M.Events.Fire("GUILD_SEARCH_RESULTS", { "Elsewhere Guild" }, "Else", nil, "eui")
check(not picker:IsShown(), "another window's results opened here")

-- an exclusion search with nothing found offers to add the name anyway
H.Advance(10)
page.excl:SetText("Nobody Guild")
page.exclSearchButton._scripts.OnClick(page.exclSearchButton)
check(lastSent() and lastSent():find('g-"Nobody Guild"', 1, true), "exclusion search sent " .. tostring(lastSent()))
answerWho({})
H.RunTimers()
local cf = _G.PSS_Confirm
check(cf and cf:IsShown() and cf.text:GetText():find("Nobody Guild", 1, true), "no Add Anyway confirm")
cf.accept._scripts.OnClick(cf.accept)
check(M.PSS_IsGuildExcluded("Nobody Guild"), "Add Anyway did not exclude")

-- Add Guild selects the new rule
H.Advance(10)
page.add:SetText("Tui Added Guild")
page.addButton._scripts.OnClick(page.addButton)
H.RunTimers()
check(M.PSS_IsGuildListed("Tui Added Guild") and V.selKind == "guild" and V.sel == M.PSS_NormalizeGuild("Tui Added Guild"),
	"Add Guild did not add and select")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

------------------------------------------------------------------------
-- B4 (3.4.0-dev009): the detail bodies, the members view, the confirms
------------------------------------------------------------------------
local ui = H.Private("PourSocialScore_UI")
local function reselect(k)
	V.dirty = true
	page.refresh()
	local i = indexOf(function(it) return it.key == k end)
	check(i ~= nil, "no row for " .. tostring(k))
	clickAt(i)
end

-- the exclusion bodies: the heading row's text; Remove from the list
local ei2 = indexOf(function(it) return it.exclHeader end)
clickAt(ei2)
-- (a heading click opens or closes it: open it again when it closed)
if not M.PSS_GuildGroupOpen(M.PSS_GUILD_EXCL_OPEN) then clickAt(indexOf(function(it) return it.exclHeader end)) end
check(pane.info:IsShown() and pane.info.heading:GetText() == "Guild Exclusion List" and not pane.info.removeButton:IsShown(), "exclusion heading body")
local xi2 = indexOf(function(it) return it.exclItem and it.name == "Friendly Guild" end)
clickAt(xi2)
pane.info.removeButton._scripts.OnClick(pane.info.removeButton)
H.RunTimers()
check(not M.PSS_IsGuildExcluded("Friendly Guild") and V.selKind == nil, "exclusion not removed")

-- a guild: lines, W I G P C, overrides, Scan, Custom Scan
local gkey = M.PSS_NormalizeGuild("Tui Guild 010")
reselect(gkey)
local gb = pane.guild
local _, g = M.PSS_FindGuildRule(gkey)
check(gb:IsShown() and gb.info:GetText() == M.PSS_GuildInfoLine(g), "guild body lines")
check(gb.counts:GetText() == M.PSS_CountsText(M.PSS_GetGuildBlockCounts(gkey)), "guild counts line")
local gw = gb.excl.whisper
check(gw:GetChecked() == false, "a new guild allows whispers")
gw:SetChecked(true)
gw._scripts.OnClick(gw, "LeftButton")
check(M.PSS_GuildBlock(g).whisper == false, "guild W not saved as allowed")
gw:SetChecked(false)
gw._scripts.OnClick(gw, "LeftButton")
check(M.PSS_GuildBlock(g).whisper ~= false, "guild W not saved as blocked")
local go = gb.overrides[1]
go._scripts.OnClick(go)
check(g.opts and g.opts[go.opt.key] == true and go:GetText():find("On", 1, true), "guild override not On")
go._scripts.OnClick(go)
go._scripts.OnClick(go)
check(g.opts == nil or g.opts[go.opt.key] == nil, "guild override not back to Default")
H.Advance(10)
H.RunTimers()
local s0 = #sent
gb.scan._scripts.OnClick(gb.scan)
check(#sent == s0 + 1 and lastSent():find('g-"Tui Guild 010"', 1, true), "Scan sent " .. tostring(lastSent()))
answerWho({
	{ fullName = "Scanned-Realm1", fullGuildName = "Tui Guild 010", level = 80, classStr = "Mage", filename = "MAGE" },
	{ fullName = "Scanned Two-Realm1", fullGuildName = "Tui Guild 010", level = 80, classStr = "Rogue", filename = "ROGUE" },
})
H.RunTimers()
check(gb.scan:GetText() == M.PSS_GuildSweepLabel(gkey), "Scan label " .. tostring(gb.scan:GetText()))
H.Advance(10)
H.RunTimers()
pane.fieldsBox:SetText("80")
s0 = #sent
gb.custom._scripts.OnClick(gb.custom)
-- (the Options scan level cap may rewrite the level: a real save's does)
check(#sent == s0 + 1 and lastSent():find('g-"Tui Guild 010" %d') and g.customScan == "80", "Custom Scan sent " .. tostring(lastSent()))
answerWho({})
H.RunTimers()

-- Members: the members view in place of the list, a step of its own
gb.pages:Select("rule")
gb.membersButton._scripts.OnClick(gb.membersButton)
local mview, mlist = page.membersView, page.members
check(V.view == "members" and mview:IsShown() and not list.scroll:IsVisible(), "Members did not open the members view")
check(mlist.count == 2 and page.count:GetText() == "2 members", "members " .. mlist.count .. " " .. tostring(page.count:GetText()))
check(mview.heading:GetText():find("Tui Guild 010", 1, true) and win.where:GetText() == "Guild Ignore List  >  Members of <Tui Guild 010>",
	"members heading or the line by the arrows: " .. tostring(win.where:GetText()))
check(pane.guild:IsShown() and not gb.membersButton:IsShown(), "the guild's pane not shown in the members view")
-- search the members
page.search:SetText("two")
page.search._scripts.OnTextChanged(page.search, true)
check(mlist.count == 1 and page.count:GetText() == "1 of 2 members", "member search")
page.search:SetText("")
page.search._scripts.OnTextChanged(page.search, true)

-- a member: note, W I G P C (own or following the guild), overrides
local m = V.members[1]
page.selectMember(m)
local mb = pane.member
check(mb:IsShown() and mb.heading:GetText() == M.PSS_MemberHeading(m) and mb.guildLine:GetText() == M.PSS_MemberGuildLine(m), "member body")
mb.pages:Select("rule")
pane.noteBox:SetText("  spammer ")
pane.noteBox._scripts.OnEnterPressed(pane.noteBox)
check(m.note == "spammer", "member note not saved: " .. tostring(m.note))
local mw = mb.excl.whisper
check(mw:GetAlpha() == 0.45, "a member's box does not follow the guild")
mw:SetChecked(true)
mw._scripts.OnClick(mw, "LeftButton")
check(M.PSS_MemberBlock(m).whisper == false and mw:GetAlpha() == 1, "member W not set as their own")
mw._scripts.OnClick(mw, "RightButton")
check(M.PSS_MemberBlock(m).whisper == nil and mw:GetAlpha() == 0.45, "right-click did not follow the guild again")
local mo = mb.overrides[1]
mo._scripts.OnClick(mo)
check(m.opts and m.opts[mo.opt.key] == true, "member override not On")
mo._scripts.OnClick(mo)
mo._scripts.OnClick(mo)
-- a block from the member counts at once (no Logging needed)
lineID = lineID + 1
local author = m.name:find("-", 1, true) and m.name or (m.name .. "-Realm1")
local blocked = M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "cheap gold", author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
H.RunTimers()
check(blocked, "the member's whisper was not blocked (" .. author .. ")")
check(mb.counts:GetText():find("^Blocked 1") ~= nil, "member counts " .. tostring(mb.counts:GetText()))

-- back to the guild list and forward again; Escape goes up one level
ui.NavBack()
check(V.view == "members" and V.msel == nil or V.view == "guilds", "back")
while V.view == "members" do ui.NavBack() end
check(list.scroll:IsVisible() and not mview:IsShown(), "back did not return to the guild list")
ui.NavForward()
check(V.view == "members" and V.mguild == gkey, "forward did not return to the members")
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and V.view == "guilds", "Escape did not go up to the guild list")

-- a double-click on a guild opens its members
local di = indexOf(function(it) return it.key == gkey end)
local dr = rowFor(di)
dr._scripts.OnClick(dr, "LeftButton")
dr._scripts.OnClick(dr, "LeftButton")
check(V.view == "members" and V.mguild == gkey, "double-click did not open the members")

-- Remove Member asks first
page.selectMember(V.members[1])
local cf2 = _G.PSS_Confirm
mb.removeButton._scripts.OnClick(mb.removeButton)
check(cf2:IsShown() and cf2.text:GetText():find("Remove ", 1, true), "no confirm before removing a member")
cf2.cancel._scripts.OnClick(cf2.cancel)
check(mlist.count == 2, "cancel removed the member")
mb.removeButton._scripts.OnClick(mb.removeButton)
cf2.accept._scripts.OnClick(cf2.accept)
H.RunTimers()
check(mlist.count == 1 and V.msel == nil, "accept did not remove the member: " .. mlist.count)

-- Remove Guild asks first; from the members view it goes back to the list
page.selectMember(nil)
gb.pages:Select("rule")
gb.removeButton._scripts.OnClick(gb.removeButton)
check(cf2:IsShown() and cf2.text:GetText():find("Tui Guild 010", 1, true), "no confirm before removing a guild")
cf2.accept._scripts.OnClick(cf2.accept)
H.RunTimers()
check(select(2, M.PSS_FindGuildRule(gkey)) == nil and V.view == "guilds" and pane.totals.frame:IsShown(), "accept did not remove the guild")

-- a default guild list: its rule on and off, open and closed
local hk
for k in pairs(V.rows.heads or {}) do hk = k break end
if hk then
	local hi2 = indexOf(function(it) return it.header and it.groupKey == hk end)
	clickAt(hi2)
	local gp = pane.group
	check(V.selKind == "group" and gp:IsShown() and gp.toggle:IsShown(), "default list body")
	local was = M.PSS_ManagedGroupActive(hk)
	gp.toggle._scripts.OnClick(gp.toggle)
	H.RunTimers()
	check(M.PSS_ManagedGroupActive(hk) ~= was and gp.toggle:GetText() == (was and "Turn Rule On" or "Turn Rule Off"), "rule toggle")
	gp.toggle._scripts.OnClick(gp.toggle)
	H.RunTimers()
	check(M.PSS_ManagedGroupActive(hk) == was, "rule toggle back")
	local open0 = M.PSS_GuildGroupOpen(hk)
	gp.open._scripts.OnClick(gp.open)
	check(M.PSS_GuildGroupOpen(hk) ~= open0, "Expand / Collapse")
	gp.open._scripts.OnClick(gp.open)
	-- a static default-list guild cannot be removed
	local sk = V.rows.groups and V.rows.groups[hk] and V.rows.groups[hk][1] and V.rows.groups[hk][1].key
	if sk then
		-- (its list may be collapsed: selected straight away)
		page.select("guild", sk)
		check(gb.removeButton:IsEnabled() == not M.PSS_IsStaticManagedGuild(sk), "Remove Guild on a default list guild")
	end
end
-- (3.4.0.15) a blocked line while the tab shows: the rows on screen count
-- again without re-sorting the whole list; the next Resort catches up
do
	M.PSS_AddGuild("Countcheck Guild")
	local m = M.PSS_UpdateGuildMember("Countcheck Guild", "Counted-Realm")
	if m then m.guild = "Countcheck Guild" end
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	H.RunTimers()
	page.search:SetText("countcheck")
	page.search._scripts.OnTextChanged(page.search, true)
	check(list.count == 1, "count check guild not found: " .. list.count)
	local row = rowFor(1)
	local before = tonumber(row and row.cells["metric:total"]:GetText() or "") or -1
	local resorts, real = 0, M.PSS_GuildRows
	M.PSS_GuildRows = function(...) resorts = resorts + 1 return real(...) end
	lineID = lineID + 1
	local hit = M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "spam", "Counted-Realm", "", "", "", "", 0, 0, "", 0, 900000 + lineID, nil)
	H.RunTimers()
	H.Advance(1)
	H.RunTimers()
	M.PSS_GuildRows = real
	check(hit == true, "the guild member's whisper was not blocked")
	check(tonumber(row.cells["metric:total"]:GetText() or "") == before + 1, ("row total %s, was %d"):format(tostring(row.cells["metric:total"]:GetText()), before))
	check(resorts == 0, "a blocked line re-sorted the whole list " .. resorts .. " times")
	check(V.dirty, "the list not marked for the next Resort")
	page.search:SetText("")
	page.search._scripts.OnTextChanged(page.search, true)
	-- the members view: its list dropped when it closes
	local key = M.PSS_CanonGuild("Countcheck Guild")
	V:OpenMembers(key)
	V:MResort()
	check(#V.members >= 1, "members view empty")
	V:CloseMembers()
	check(#V.members == 0 and V.mn == 0, "the members list kept after closing")
	M.PSS_RemoveGuild("Countcheck Guild")
	H.RunTimers()
end
win.tabs[2]._scripts.OnClick(win.tabs[2])
check(V.selKind == nil and V.view == "guilds" and pane.totals.frame:IsShown(), "a tab click did not reset the tab")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

if not fail then print(("PASS guilds (%d rules)"):format(M.PSS_GuildCount())) end
