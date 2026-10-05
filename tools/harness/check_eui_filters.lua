-- Chat Filter queries (core, 3.1 Step E.6) and the Chat Filters tab of the
-- EllesmereUI window. Runs on the save check_eui_window.lua phase 1 wrote
-- (integration on), with PourSocialScore_EllesmereUI from PSS_EXTRA_ADDONS.
--   core: (PourSocialScore_Libraries) M.PSS_FilterCount, M.PSS_FilterRow,
--         M.PSS_FilterRows (built-ins first, sort, search, reused table),
--         M.PSS_TestChatFilter, M.PSS_ConvertChatLink; the setters fire
--         FILTERS_CHANGED; removing a filter with nothing counted leaves
--         PourSocialScore_Logging unloaded
--   tab:  list, search, sort, the editor pane (On, read-only built-ins,
--         New / Save / Copy / Remove / Reset Count / Reset Defaults, Test,
--         links into the boxes), a guild rule (no count or history), the
--         block history on demand and its Block History view (All Filters);
--         PourSocialScore_GUI never loads
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui filters: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local E = EllesmereUI
local db = PourSocialScoreDB

------------------------------------------------------------------ core
check(M.PSS_FilterRows == nil, "filter queries loaded before a window opened")
M.PSS_Need("Libraries")
local total, builtin, custom, on = M.PSS_FilterCount()
check(total == #db.filterList and builtin + custom == total and builtin > 0, "counts " .. total .. " " .. builtin .. " " .. custom)

local fired = 0
local id = M.Events.Register("FILTERS_CHANGED", function() fired = fired + 1 end)
local a = M.PSS_AddCustomFilter("Zeta spam", "[word=zetaspam]", false)
local b = M.PSS_AddCustomFilter("Alpha spam", "[word=alphaspam]", true)
check(fired == 2, "adding did not fire FILTERS_CHANGED: " .. fired)
local row = {}
check(M.PSS_FilterRow(a, row) == row and row.desc == "Zeta spam" and not row.active and not row.builtin and row.blocked == 0 and row.lines == 0, "custom row")
check(M.PSS_FilterRow(total + 99, row) == nil, "row past the end")
local idx, n = M.PSS_FilterRows("desc", true, nil, {})
check(n == total + 2, "rows " .. n)
local seenCustom = false
for i = 1, n do
	if M.PSS_IsBuiltinFilter(idx[i]) then
		if seenCustom then check(false, "a built-in after a custom filter") break end
	else
		seenCustom = true
	end
end
check(idx[n - 1] == b and idx[n] == a, "custom A-Z")
local again, n2 = M.PSS_FilterRows("desc", false, "SPAM", idx)
check(again == idx and n2 >= 2, "search reuses the table")
check(again[1] ~= nil and (again[1] == a or M.PSS_IsBuiltinFilter(again[1])), "Z-A search order")
local _, n3 = M.PSS_FilterRows("filter", true, "zetaspam", idx)
check(n3 == 1 and idx[1] == a and idx[2] == nil, "search on the filter text")
check(M.PSS_TestChatFilter("[word=gold]", "Buy GOLD now") == "blocked", "test blocked")
check(M.PSS_TestChatFilter("[word=gold]", "hello") == "passed", "test passed")
check(M.PSS_TestChatFilter("[bogus=1]", "gold") == "error", "test error")
check(M.PSS_ConvertChatLink("|cffa335ee|Hitem:19019::::|h[Thunderfury]|h|r") == "[item=19019]", "item link")
check(M.PSS_ConvertChatLink("|Hspell:133|h") == "[spell=133]" and M.PSS_ConvertChatLink("|Hclubticket:x|h") == "[community]", "spell / community link")
check(M.PSS_ConvertChatLink("plain") == "UNKNOWN", "not a link")
fired = 0
M.PSS_SetFilterActive(a, true)
M.PSS_SaveChatFilter(a, "Zeta spam", "[word=zetaspam]")
M.PSS_ResetFilterCount(a)
check(fired == 3, "setters fired " .. fired)
M.Events.Unregister(id)

-- removing a filter with nothing counted has nothing to clear
check(not loaded("PourSocialScore_Logging"), "Logging loaded before any history was asked for")
local q = M.PSS_AddCustomFilter("Quiet", "[word=quietword]", false)
M.RemoveChatFilter(q)
check(not loaded("PourSocialScore_Logging"), "removing a filter with no blocks loaded Logging")

------------------------------------------------------------------ window
SlashCmdList.PSS("gui")
local win = _G.PSS_EllesmereUIWindow
check(win and win:IsShown(), "no window")
win.tabs[3]:GetScript("OnClick")(win.tabs[3])
local page = win.pages[3]
local list, pane, st = page.list, page.pane, page.state
check(page:IsShown() and list and pane and st, "Chat Filters tab not built")
check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded")
check(E.log.tabSel[win.tabs[3]] == true, "Chat Filters tab not selected")

list.scroll:SetHeight(300)
list:Layout()
total = M.PSS_FilterCount()
check(list.count == total, "list count " .. list.count .. " of " .. total)
check((list.rows[1].cells.desc:GetText() or ""):match("%(built%-in%)") or (list.rows[1].cells.desc:GetText() or ""):match("%(guild rule%)"), "first row not a built-in")
check((page.count:GetText() or ""):match("Custom"), "counts line " .. tostring(page.count:GetText()))

local function rowAt(i)
	list.scroll:SetVerticalScroll((i - 1) * list.rowH)
	for _, r in ipairs(list.rows) do if r.index == i then return r end end
end
local function selectFilter(fi)
	for i = 1, st.count do
		if st.index[i] == fi then
			local r = rowAt(i)
			r:GetScript("OnClick")(r, "LeftButton")
			H.Advance(1)
			return true
		end
	end
	check(false, "filter " .. tostring(fi) .. " not listed")
end

-- search
page.search:SetText("zetaspam")
page.search:GetScript("OnTextChanged")(page.search, true)
check(list.count == 1 and (page.count:GetText() or ""):match("^1 of"), "search " .. list.count)
page.search:SetText("")
page.search:GetScript("OnTextChanged")(page.search, true)
check(list.count == total, "search not cleared")

-- sort by On: a header click
local head
for _, h in ipairs(list.heads) do if h.key == "state" then head = h end end
head:GetScript("OnClick")(head)
check(st.key == "state" and st.asc, "sort by On")
for _, h in ipairs(list.heads) do if h.key == "desc" then head = h end end
head:GetScript("OnClick")(head)

-- a built-in: read only, On works
local bi
for i = 1, #db.filterList do if M.PSS_IsBuiltinFilter(i) and not M.PSS_IsGuildRuleFilter(i) then bi = i break end end
selectFilter(bi)
check(pane.body:IsShown() and st.sel == bi, "built-in not selected")
-- a click on the selected filter deselects it: every filter's totals
-- (guild rules left out: their blocks are on the Guild Ignore List)
selectFilter(bi)
check(not pane.body:IsShown() and st.sel == nil and pane.totals.frame:IsShown(), "filter deselect: totals not shown")
check(pane.totals.counts.total == M.PSS_ListTotals("filters", {}).total, "filter totals")
-- a click under the rows deselects too, and so does a click on the tab
selectFilter(bi)
list.scroll:GetScript("OnMouseUp")(list.scroll, "LeftButton")
check(st.sel == nil and pane.totals.frame:IsShown(), "a click under the filters did not deselect")
selectFilter(bi)
win.tabs[3]:GetScript("OnClick")(win.tabs[3])
check(st.sel == nil and pane.totals.frame:IsShown(), "the tab shown did not deselect")
selectFilter(bi)
check(pane.body:IsShown() and st.sel == bi and not pane.totals.frame:IsShown(), "built-in not selected again")
check(not pane.descBox:IsEnabled() and not pane.filterBox:IsEnabled() and not pane.saveButton:IsEnabled() and not pane.removeButton:IsEnabled(), "built-in editable")
check(pane.copyButton:IsEnabled() and pane.lock:IsShown(), "built-in copy / lock note")
-- a long filter scrolls inside its panel: the box is the scroll child, and
-- picking another filter starts at the top
check(pane.filterScroll and pane.filterScroll:GetScrollChild() == pane.filterBox, "filter box not in a scroll frame")
pane.filterScroll:SetVerticalScroll(40)
selectFilter(bi == 1 and 2 or 1)
check(pane.filterScroll:GetVerticalScroll() == 0, "filter scroll not reset on a new filter")
selectFilter(bi)
local was = db.filterActive[bi] == true
pane.onBox:SetChecked(not was)
pane.onBox:GetScript("OnClick")(pane.onBox)
check((db.filterActive[bi] == true) == not was, "On did not switch the built-in")
H.RunTimers()
pane.onBox:SetChecked(was)
pane.onBox:GetScript("OnClick")(pane.onBox)

-- Copy makes an editable custom filter, selected
local before = #db.filterList
pane.copyButton:GetScript("OnClick")(pane.copyButton)
H.RunTimers()
check(#db.filterList == before + 1 and st.sel == before + 1 and pane.descBox:IsEnabled(), "Copy")
check((db.filterDesc[before + 1] or ""):match("^Copy of"), "copy description")

-- New Filter, edit, Save
page.newButton:GetScript("OnClick")(page.newButton)
H.RunTimers()
local nf = st.sel
check(nf == #db.filterList and not M.PSS_IsBuiltinFilter(nf), "New Filter not selected")
pane.descBox:SetText("Gold sellers")
pane.filterBox:SetText("[word=goldsale]")
pane.saveButton:GetScript("OnClick")(pane.saveButton)
H.RunTimers()
check(db.filterDesc[nf] == "Gold sellers" and db.filterList[nf] == "[word=goldsale]", "Save: " .. tostring(db.filterDesc[nf]))
check(list.count == #db.filterList, "list not redrawn after New")

-- Test
pane.testBox:SetText("cheap GOLDSALE here")
pane.testButton:GetScript("OnClick")(pane.testButton)
check((pane.result:GetText() or ""):match("BLOCKED"), "test result " .. tostring(pane.result:GetText()))
pane.testBox:SetText("hello")
pane.testButton:GetScript("OnClick")(pane.testButton)
check((pane.result:GetText() or ""):match("PASSED"), "test passed result")

-- a shift-clicked link: the filter box gets its [tag], the Link box too
pane.filterBox._focus = true
ChatEdit_InsertLink("|cffa335ee|Hitem:19019::::|h[Thunderfury]|h|r")
pane.filterBox._focus = nil
check((pane.filterBox:GetText() or ""):match("%[item=19019%]$"), "link into the filter box: " .. tostring(pane.filterBox:GetText()))
pane.linkBox._focus = true
ChatEdit_InsertLink("|Hspell:133|h[Fireball]|h")
pane.linkBox._focus = nil
check(pane.linkBox:GetText() == "[spell=133]", "link box " .. tostring(pane.linkBox:GetText()))
pane.filterBox:SetText("[word=goldsale]")

-- On, then a blocked Trade line: counted at once, the history only on request
pane.onBox:SetChecked(true)
pane.onBox:GetScript("OnClick")(pane.onBox)
check(db.filterActive[nf] == true, "On not saved")
local lineID = 95000
-- (Trade: whispers skip the chat filters by default)
local function trade(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_CHANNEL", msg, author, "", "2. Trade", "", "", 2, 2, "Trade", 0, lineID, nil) == true
end
check(trade("Seller-Realm1", "goldsale cheap"), "Trade line not blocked by the new filter")
H.Advance(1)
H.RunTimers()
check(tonumber(db.filterCount[nf]) == 1, "filter count " .. tostring(db.filterCount[nf]))
pane.pages:Select("summary")
check(pane.summary.values.session == 1 and pane.summary.values.day == 1 and pane.summary.values.all == 1, "filter summary")
pane.pages:Select("history")
check((pane.info:GetText() or ""):match("Blocked |cffffff001|r"), "pane count " .. tostring(pane.info:GetText()))
local hv = pane.hist
check(not loaded("PourSocialScore_Logging"), "a blocked line shown in the pane loaded Logging")
check(hv.gate:IsShown() and hv.gate:GetText() == "Show Block History (1)" and hv.list.count == 0, "no Show Block History button")
hv.gate:GetScript("OnClick")(hv.gate)
check(loaded("PourSocialScore_Logging") and hv.list.count == 1, "Show Block History: " .. hv.list.count)
check(hv.list.rows[1].cells.name and hv.list.rows[1].cells.name:GetText() == "Seller", "history name " .. tostring(hv.list.rows[1].cells.name and hv.list.rows[1].cells.name:GetText()))

-- a double-click on a line: its events on the Events tab, then the
-- Chat Filters as a whole (the Source drop-down)
local hr = hv.list.rows[1]
hr:GetScript("OnClick")(hr, "LeftButton")
hr:GetScript("OnClick")(hr, "LeftButton")
local view = win.pages[4].view
check(view and view:IsOpen() and not page:IsShown() and view.list.count == 1, "filter events not opened")
check(win.where:GetText() == "Events  >  Gold sellers", "where line " .. tostring(win.where:GetText()))
for _, it in ipairs(view.sourceDrop:MenuButtons()) do if it.text == "Chat Filters" then it.fn() end end
check(view.q.scope == nil and view.q.sources.filters and not view.q.sources.players and view.list.count >= 1
	and view.shown[1].message == "goldsale cheap", "All Filters")
check(view.list.rows[1].cells.source:GetText() ~= "", "no source on a filter line")
check(E.PressEscape() and not view:IsOpen() and page:IsShown(), "Escape did not go back to the filter tab")
H.Advance(1)

-- the detail pages: three buttons, one page at a time, the pick is kept
do
	local dp = pane.pages
	check(dp and #dp.buttons == 3 and dp.buttons[1]:GetText() == "Summary"
		and dp.buttons[2]:GetText() == "Event History" and dp.buttons[3]:GetText() == "View/Edit Rule", "page buttons")
	for i, key in ipairs({ "summary", "history", "rule" }) do
		dp.buttons[i]:GetScript("OnClick")(dp.buttons[i])
		check(dp.shown == key and dp[key]:IsShown(), "page " .. key .. " not shown")
		local others = 0
		for _, k in ipairs({ "summary", "history", "rule" }) do if k ~= key and dp[k]:IsShown() then others = others + 1 end end
		check(others == 0, "page " .. key .. " shown with another")
	end
	check(pane.filterBox:GetParent():GetParent():GetParent() == dp.rule, "editor not on the rule page")
	check(hv.frame:GetParent() == dp.history and pane.counts:GetParent() == dp.summary, "history or counts on the wrong page")
	dp:Select("history")
end

-- Reset Count keeps the history
pane.resetCount:GetScript("OnClick")(pane.resetCount)
H.RunTimers()
check(tonumber(db.filterCount[nf]) == 0 and hv.list.count == 1, "Reset Count")

-- a guild rule: no count, no history, no copy
local gi
for i = 1, #db.filterList do if M.PSS_IsGuildRuleFilter(i) then gi = i break end end
if gi then
	selectFilter(gi)
	check(not hv.frame:IsVisible() and not pane.copyButton:IsEnabled() and not pane.resetCount:IsEnabled(), "guild rule pane")
	-- only its settings: the Summary and Event History buttons are off
	local dp = pane.pages
	check(dp.shown == "rule" and dp.rule:IsVisible() and not dp.buttons[1]:IsEnabled()
		and not dp.buttons[2]:IsEnabled() and dp.buttons[3]:IsEnabled(), "guild rule pages")
else
	print("eui filters: no guild rules in this save (not checked)")
end

-- Remove asks first
selectFilter(nf)
local nPopups = #E.log.popups
pane.removeButton:GetScript("OnClick")(pane.removeButton)
check(#E.log.popups == nPopups + 1 and E.log.popups[#E.log.popups].confirmText == "Remove", "Remove not confirmed")
E.log.popups[#E.log.popups].onConfirm()
H.RunTimers()
check(db.filterDesc[nf] ~= "Gold sellers" and st.sel == nil and not pane.body:IsShown(), "filter not removed")
check(list.count == #db.filterList, "list not redrawn after Remove")

-- its slices and View Events open the whole list's events (EUI 1.1.0-dev010)
pane.totals:Show()
local tsm = pane.totals.summary
check(tsm.viewButton:IsShown(), "filter totals: no View Events")
tsm.viewButton:GetScript("OnClick")(tsm.viewButton)
local tv = win.pages[4].view
check(tv and tv:IsOpen() and tv.q.scope == nil and tv.q.sources.filters and not tv.q.sources.guilds
	and tv.q.period == (tsm.boxes.all:GetChecked() and nil or "day"),
	"filter totals: View Events did not open the whole list")
E.PressEscape()
tsm:Open("session")
check(tv:IsOpen() and tv.q.period == "session" and tv.q.scope == nil, "filter totals: the session slice")
E.PressEscape()
tsm:Open("all")
check(tv:IsOpen() and tv.q.period == nil, "filter totals: All time after a slice")
E.PressEscape()
H.Advance(1)

-- Reset Defaults asks first and leaves the built-ins only
page.resetButton:GetScript("OnClick")(page.resetButton)
E.log.popups[#E.log.popups].onConfirm()
H.RunTimers()
local _, _, c2 = M.PSS_FilterCount()
check(c2 == 0 and list.count == #db.filterList, "Reset Defaults left " .. c2 .. " custom filters")

check(not loaded("PourSocialScore_GUI"), "PourSocialScore_GUI loaded by the tab")
if not fail then print("PASS eui filters") end
