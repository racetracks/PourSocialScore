-- The new window's Chat Filters tab (3.4.0-dev010), as a run.lua script on
-- any save, real ones included: /pss tui builds it; with nothing selected
-- the pane shows every filter's totals (M.PSS_ListTotals); the rows are the
-- core's with Libraries' text; search, sort; a built-in is read only (On
-- works); Copy, New Filter, Save, Test; a link shift-clicked in chat goes
-- into the box being edited (hooked on ChatFrameUtil.InsertLink as on
-- Retail 12.x, never acting while the pane is hidden); a blocked Trade line
-- is counted at once with the Summary pie, the history only on Show Block
-- History; Reset Count keeps the history; a guild rule has View/Edit Rule
-- only; Remove and Reset Defaults ask first. Neither old window loads.
local fail = false
local function check(ok, msg) if not ok then print("FAIL filters: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local db = PourSocialScoreDB

-- Retail 12.x: links are inserted by ChatFrameUtil.InsertLink, the old
-- ChatEdit_InsertLink is the same function kept for old addons
local inserted = {}
ChatFrameUtil.InsertLink = function(text) inserted[#inserted + 1] = text return true end
ChatEdit_InsertLink = ChatFrameUtil.InsertLink

SlashCmdList["PSS"]("tui")
local win = _G.PSS_Window
win.tabs[3]._scripts.OnClick(win.tabs[3])
local page = win.pages[3]
local list, pane, V = page.list, page.pane, page.state
check(page:IsShown() and list and pane and V, "Chat Filters tab not built")
check(not page.note:IsShown(), "the built tab still shows its note")
check(page.linkHook() == "ChatFrameUtil.InsertLink", "link hook not on ChatFrameUtil.InsertLink: " .. tostring(page.linkHook()))

-- nothing selected: every filter's totals
local want = M.PSS_ListTotals("filters", {})
check(pane.totals.frame:IsShown() and not pane.body:IsShown(), "totals not shown with nothing selected")
local tv = pane.totals.summary.values
check(tv.all == (want.total or 0) and tv.session == (want.session or 0) and tv.day == (want.day or 0), "totals pie differs from M.PSS_ListTotals")

-- the rows: the core's, with Libraries' text; built-ins first
list.scroll:SetHeight(300)
list:Layout()
local total = M.PSS_FilterCount()
check(list.count == total, "list count " .. list.count .. " of " .. total)
local function rowAt(i)
	list.scroll:SetVerticalScroll((i - 1) * list.rowH)
	for _, r in ipairs(list.rows) do if r.index == i then return r end end
end
local cells, rb = {}, {}
local r1 = rowAt(1)
M.PSS_FilterRowCells(M.PSS_FilterRow(V.index[1], rb), cells)
check(r1.cells.desc:GetText() == cells.desc and r1.cells.blocked:GetText() == cells.blocked, "row text")
check(M.PSS_IsBuiltinFilter(V.index[1]), "first row not a built-in")
check((page.count:GetText() or ""):find("Custom", 1, true) ~= nil, "counts line")
local function selectFilter(fi)
	for i = 1, V.count do
		if V.index[i] == fi then
			local r = rowAt(i)
			r._scripts.OnClick(r, "LeftButton")
			H.Advance(1)
			return true
		end
	end
	check(false, "filter " .. tostring(fi) .. " not listed")
end

-- search and sort
local a = M.PSS_AddCustomFilter("Zeta spam", "[word=zetaspam]", false)
H.RunTimers()
check(list.count == total + 1, "list not redrawn after a new filter")
page.search:SetText("zetaspam")
page.search._scripts.OnTextChanged(page.search, true)
check(list.count == 1 and (page.count:GetText() or ""):find("^1 of") ~= nil, "search " .. list.count)
page.search:SetText("")
page.search._scripts.OnTextChanged(page.search, true)
local head
for _, h in ipairs(list.heads) do if h.key == "state" then head = h end end
head._scripts.OnClick(head)
check(V.key == "state" and V.asc, "sort by On")
for _, h in ipairs(list.heads) do if h.key == "desc" then head = h end end
head._scripts.OnClick(head)

-- a built-in: read only, On works; a second click deselects
local bi
for i = 1, #db.filterList do if M.PSS_IsBuiltinFilter(i) and not M.PSS_IsGuildRuleFilter(i) then bi = i break end end
selectFilter(bi)
check(pane.body:IsShown() and page.selected() == bi, "built-in not selected")
check(pane.heading:GetText() == M.PSS_FilterHeading(M.PSS_FilterRow(bi, rb)), "heading")
check(not pane.descBox:IsEnabled() and not pane.filterBox:IsEnabled() and not pane.saveButton:IsEnabled() and not pane.removeButton:IsEnabled(), "built-in editable")
check(pane.copyButton:IsEnabled() and pane.lock:IsShown(), "built-in copy / lock note")
local was = db.filterActive[bi] == true
pane.onBox:SetChecked(not was)
pane.onBox._scripts.OnClick(pane.onBox)
check((db.filterActive[bi] == true) == not was, "On did not switch the built-in")
pane.onBox:SetChecked(was)
pane.onBox._scripts.OnClick(pane.onBox)
H.RunTimers()
selectFilter(bi)
check(page.selected() == nil and pane.totals.frame:IsShown(), "second click did not deselect")

-- Copy makes an editable custom filter, selected
selectFilter(bi)
local before = #db.filterList
pane.copyButton._scripts.OnClick(pane.copyButton)
H.RunTimers()
check(#db.filterList == before + 1 and page.selected() == before + 1 and pane.descBox:IsEnabled(), "Copy")

-- New Filter, edit, Save
page.newButton._scripts.OnClick(page.newButton)
H.RunTimers()
local nf = page.selected()
check(nf == #db.filterList and not M.PSS_IsBuiltinFilter(nf) and pane.pages.shown == "rule", "New Filter not selected on View/Edit Rule")
pane.descBox:SetText("Gold sellers")
pane.filterBox:SetText("[word=goldsale]")
pane.saveButton._scripts.OnClick(pane.saveButton)
H.RunTimers()
check(db.filterDesc[nf] == "Gold sellers" and db.filterList[nf] == "[word=goldsale]", "Save: " .. tostring(db.filterDesc[nf]))

-- Test
pane.testBox:SetText("cheap GOLDSALE here")
pane.testButton._scripts.OnClick(pane.testButton)
check((pane.result:GetText() or ""):find("BLOCKED", 1, true) ~= nil, "test result " .. tostring(pane.result:GetText()))
pane.testBox:SetText("hello")
pane.testButton._scripts.OnClick(pane.testButton)
check((pane.result:GetText() or ""):find("PASSED", 1, true) ~= nil, "test passed result")

-- a shift-clicked link: into the box being edited, only while the pane shows
pane.filterBox._focus = true
ChatFrameUtil.InsertLink("|cffa335ee|Hitem:19019::::|h[Thunderfury]|h|r")
pane.filterBox._focus = nil
check((pane.filterBox:GetText() or ""):match("%[item=19019%]$") ~= nil, "link into the filter box: " .. tostring(pane.filterBox:GetText()))
check(#inserted == 1, "Blizzard's own insert did not run")
pane.linkBox._focus = true
ChatFrameUtil.InsertLink("|Hspell:133|h[Fireball]|h")
pane.linkBox._focus = nil
check(pane.linkBox:GetText() == "[spell=133]", "link box " .. tostring(pane.linkBox:GetText()))
pane.filterBox:SetText("[word=goldsale]")
win:Hide()
pane.testBox._focus = true
ChatFrameUtil.InsertLink("|Hspell:133|h[Fireball]|h")
pane.testBox._focus = nil
check(pane.testBox:GetText() == "hello", "a link went into the hidden pane")
SlashCmdList["PSS"]("tui")

-- On, then a blocked Trade line: counted at once, the history only on request
-- (selected straight: it is still the one selected, a row click would deselect it)
page.select(nf)
pane.onBox:SetChecked(true)
pane.onBox._scripts.OnClick(pane.onBox)
check(db.filterActive[nf] == true, "On not saved")
local hadLogging = loaded("PourSocialScore_Logging")
local lineID = 96000
local function trade(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_CHANNEL", msg, author, "", "2. Trade", "", "", 2, 2, "Trade", 0, lineID, nil) == true
end
check(trade("Seller-Realm1", "goldsale cheap"), "Trade line not blocked by the new filter")
H.Advance(1)
H.RunTimers()
check(tonumber(db.filterCount[nf]) == 1, "filter count " .. tostring(db.filterCount[nf]))
check((pane.info:GetText() or ""):find("Blocked |cffffff001|r", 1, true) ~= nil, "pane count " .. tostring(pane.info:GetText()))
pane.pages:Select("summary")
local v = pane.summary.values
check(v.session == 1 and v.day == 1 and v.all == 1, ("filter summary %s/%s/%s"):format(tostring(v.session), tostring(v.day), tostring(v.all)))
check(pane.counts:GetText() == M.PSS_FilterHistoryLine(M.PSS_FilterRow(nf, rb)), "history line")
check(loaded("PourSocialScore_Logging") == hadLogging, "a blocked line shown in the pane loaded Logging")
pane.pages:Select("history")
local hv = pane.hist
if not hadLogging then
	check(hv.gate:IsShown() and hv.gate:GetText() == "Show Block History (1)" and hv.list.count == 0, "no Show Block History button")
	hv.gate._scripts.OnClick(hv.gate)
end
check(loaded("PourSocialScore_Logging") and hv.list.count == 1, "Show Block History: " .. hv.list.count)
check(hv.list.rows[1].cells.name and hv.list.rows[1].cells.name:GetText() == "Seller", "history name")

-- Reset Count keeps the history
pane.pages:Select("rule")
pane.resetCount._scripts.OnClick(pane.resetCount)
H.RunTimers()
check(tonumber(db.filterCount[nf]) == 0 and hv.list.count == 1, "Reset Count")

-- a guild rule: View/Edit Rule only, no copy or count
local gi
for i = 1, #db.filterList do if M.PSS_IsGuildRuleFilter(i) then gi = i break end end
if gi then
	selectFilter(gi)
	local dp = pane.pages
	check(dp.shown == "rule" and not dp.buttons[1]:IsEnabled() and not dp.buttons[2]:IsEnabled()
		and not pane.copyButton:IsEnabled() and not pane.resetCount:IsEnabled(), "guild rule pane")
end

-- Remove asks first
page.select(nf)
pane.removeButton._scripts.OnClick(pane.removeButton)
local cf = _G.PSS_Confirm
check(cf and cf:IsShown() and cf.text:GetText():find("Gold sellers", 1, true), "Remove not confirmed")
cf.cancel._scripts.OnClick(cf.cancel)
check(db.filterDesc[nf] == "Gold sellers", "cancel removed the filter")
pane.removeButton._scripts.OnClick(pane.removeButton)
cf.accept._scripts.OnClick(cf.accept)
H.RunTimers()
check(db.filterDesc[nf] ~= "Gold sellers" and page.selected() == nil and pane.totals.frame:IsShown(), "filter not removed")
check(list.count == #db.filterList, "list not redrawn after Remove")

-- Reset Defaults asks first and leaves the built-ins only
page.resetButton._scripts.OnClick(page.resetButton)
check(cf:IsShown(), "Reset Defaults not confirmed")
cf.accept._scripts.OnClick(cf.accept)
H.RunTimers()
local _, builtin, custom = M.PSS_FilterCount()
check(custom == 0 and list.count == builtin, "Reset Defaults left custom filters: " .. tostring(custom))
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

if not fail then print(("PASS filters (%d filters)"):format(M.PSS_FilterCount())) end
