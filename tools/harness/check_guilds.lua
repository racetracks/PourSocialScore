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
check(pane.totals.frame:IsShown() and not pane.body:IsShown(), "totals not shown with nothing selected")
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
	check(V.selKind == "managed" and not V.rows[1].open and pane.body:IsShown(), "Managed Communities row click")
	check(pane.heading:GetText() == "Managed Communities", "Managed Communities heading")
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
check(V.selKind == "guild" and V.sel == key and pane.body:IsShown() and pane.heading:GetText() == "Tui Guild 010", "guild not selected")
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
check(V.selKind == "excl" and pane.heading:GetText() == "Friendly Guild", "excluded guild not selected")

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

if not fail then print(("PASS guilds (%d rules)"):format(M.PSS_GuildCount())) end
