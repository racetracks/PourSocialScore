-- The new window's Events tab (3.4.0-dev011), as a run.lua script on any
-- save, real ones included: opened from a player's Summary (View Events and
-- a slice), a pane's history double-click and a list's totals; the lines,
-- the Time (custom range), Types and Source drop-downs, the search, sorting,
-- link hover (never a profession link's tooltip), a double-click copy,
-- Reset Block History, back / forward and Escape back to the tab that
-- opened it, and new blocks shown while it is open. Neither old window loads.
local fail = false
local function check(ok, msg) if not ok then print("FAIL events: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

SlashCmdList["PSS"]("tui")
local win = _G.PSS_Window
local ui = H.Private("PourSocialScore_UI")
win.tabs[1]._scripts.OnClick(win.tabs[1])
local players = win.pages[1]
local pane = players.pane

-- a listed player with two blocked whispers, one with an item link
local entry = M.PSS_PlayerAddFromText("Eventer-Realm1")
check(entry ~= nil, "player not added")
M.PSS_RecordPlayerBlock(entry, "CHAT_MSG_WHISPER", "buy gold now", nil, "whisper")
H.Advance(2)
M.PSS_RecordPlayerBlock(entry, "CHAT_MSG_WHISPER", "wts |cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r", nil, "whisper")
H.RunTimers()
players.select(entry)

-- View Events on the Summary: the Events tab, this player, the widest period ticked
pane.pages:Select("summary")
local sm = pane.summary
check(sm.viewButton:IsShown(), "no View Events")
sm.viewButton._scripts.OnClick(sm.viewButton)
local page = win.pages[4]
local view, list, eu = page.view, page.list, page.ui
check(page:IsShown() and view and view.q.scope and view.q.scope.id == entry, "View Events did not open this player's events")
check(loaded("PourSocialScore_Logging"), "the Events tab did not load Logging")
check(list.count == 2, "lines " .. list.count)
check(view.q.period == M.PSS_WidestPeriodOn() or (view.q.period == nil and M.PSS_WidestPeriodOn() == nil), "period not the widest ticked")
check((eu.heading:GetText() or ""):find(entry, 1, true) ~= nil, "heading " .. tostring(eu.heading:GetText()))
check(win.where:GetText():find("^Events  >  ") ~= nil, "the line by the arrows " .. tostring(win.where:GetText()))
check(eu.resetButton:IsShown(), "no Reset Block History for an entry")
-- Escape goes back to the tab that opened it
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and players:IsShown(), "Escape did not go back to the Players tab")

-- a slice: its period only
sm:Open("session")
check(page:IsShown() and view.q.period == "session" and view.q.scope.id == entry, "the session slice")
_G.PSS_WindowEscape:Hide()

-- a double-click on a line of the pane's Event History
pane.pages:Select("history")
local hv = pane.hist
hv.list.scroll:SetHeight(200)
hv.list:Layout()
check(hv.list.count == 2, "pane history " .. hv.list.count)
local hr = hv.list.rows[1]
hr._scripts.OnClick(hr, "LeftButton")
check(not page:IsShown(), "one click opened the Events tab")
hr._scripts.OnClick(hr, "LeftButton")
check(page:IsShown() and view.q.scope and view.q.scope.id == entry and view.q.period == nil, "history double-click")

-- the list: cells, sort, search
list.scroll:SetHeight(300)
list:Layout()
local r1 = list.rows[1]
check(r1.cells.member:GetText() == "Eventer" and r1.cells.source:GetText() == entry, "player / source cells")
check((r1.cells.kind:GetText() or ""):match("|c%x+whisper|r") ~= nil, "type cell")
check((r1.cells.time:GetText() or ""):match("^%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d$") ~= nil, "time cell")
check((r1.cells.message:GetText() or ""):find("Thunderfury", 1, true) ~= nil, "newest first")
local head
for _, h in ipairs(list.heads) do if h.key == "time" then head = h end end
head._scripts.OnClick(head)
check(view.sortKey == "time" and view.sortAsc and (list.rows[1].cells.message:GetText() or ""):find("buy gold", 1, true), "oldest first")
head._scripts.OnClick(head)
local function find(text)
	eu.search:SetText(text)
	eu.search._scripts.OnTextChanged(eu.search, true)
	return list.count
end
check(find("thunderfury") == 1, "message search")
check(find("eventer") == 2, "player search")
check(find("") == 2, "search not cleared")

-- links: hover shows an item's tooltip, never a profession link's (that
-- opens the profession window)
do
	local row, set = list.rows[1], {}
	local oldSet, oldLines = GameTooltip.SetHyperlink, GameTooltip.NumLines
	GameTooltip.SetHyperlink = function(_, link) set[#set + 1] = link end
	GameTooltip.NumLines = function() return 1 end
	row._scripts.OnHyperlinkEnter(row, "item:19019::::::::60:::::")
	row._scripts.OnHyperlinkEnter(row, "trade:Player-1-0001:2259:171")
	check(#set == 1 and set[1]:find("^item:"), "link hover: " .. table.concat(set, ", "))
	GameTooltip.SetHyperlink, GameTooltip.NumLines = oldSet, oldLines
end

-- a double-click copies the message
H.Advance(1)
list.rows[2]._scripts.OnClick(list.rows[2], "LeftButton")
list.rows[2]._scripts.OnClick(list.rows[2], "LeftButton")
local tp = _G.PSS_TextPopup
check(tp and tp:IsShown() and tp.edit:GetText() == "buy gold now", "copy popup " .. tostring(tp and tp.edit:GetText()))
tp:Hide()

-- the drop-downs (Classic look: Blizzard's menus, read as entries)
M.PSS_SetOpt("uiSkin", "global", 0)
local function entries(dd) return dd.blizz:MenuButtons() end
local function pick(dd, text)
	for _, it in ipairs(entries(dd)) do if it.text == text then it.fn() return it end end
	check(false, "no menu entry " .. text)
end
local function isOn(dd, text)
	for _, it in ipairs(entries(dd)) do if it.text == text then return it.on end end
end
-- Types: untick whisper, then All types
local wl = M.PSS_History.CAT_LABEL.whisper
check(isOn(eu.typeDrop, wl), "whisper not ticked")
pick(eu.typeDrop, wl)
check(list.count == 0 and eu.typeDrop.label:GetText() ~= "All types" and not isOn(eu.typeDrop, wl), "Types drop-down")
pick(eu.typeDrop, "All types")
check(list.count == 2 and view.q.cats == nil and eu.typeDrop.label:GetText() == "All types", "All types")
-- Time: this session; custom range with a bad date, then a good one
pick(eu.timeDrop, "This session")
check(view.q.period == "session", "This session")
pick(eu.timeDrop, "Custom range")
check(view.q.period == "custom" and eu.custom:IsShown() and eu.fromBox:GetText() ~= "", "Custom range")
eu.fromBox:SetText("not a date")
eu.applyButton._scripts.OnClick(eu.applyButton)
check((eu.rangeError:GetText() or ""):find("Dates as", 1, true) ~= nil, "bad date not reported")
eu.fromBox:SetText("2000-01-01")
eu.toBox:SetText("")
eu.applyButton._scripts.OnClick(eu.applyButton)
check(eu.rangeError:GetText() == "" and list.count == 2, "custom range from 2000")
eu.toBox:SetText("2000-01-02")
eu.applyButton._scripts.OnClick(eu.applyButton)
check(list.count == 0, "custom range to 2000")
pick(eu.timeDrop, "All time")
check(view.q.period == nil and not eu.custom:IsShown(), "All time")
-- Source: from this player to the whole Player Ignore List, then off
pick(eu.sourceDrop, "Only " .. entry)
check(view.q.scope == nil and view.q.sources.players and view.q.sources.guilds and list.count >= 2, "Only <entry> off")
pick(eu.sourceDrop, "Guild Ignore List")
pick(eu.sourceDrop, "Chat Filters")
check(view.q.sources.players and not view.q.sources.guilds and not view.q.sources.filters, "sources")
check(eu.sourceDrop.label:GetText() == "Player Ignore List" and not eu.resetButton:IsShown(), "source label / reset hidden for a list")
check(list.rows[1].cells.source:GetText() ~= "", "source cell for a list")
M.PSS_SetOpt("uiSkin", "global", 2)

-- back / forward step through the queries
ui.NavBack()
check(view.q.sources.filters and not view.q.sources.guilds, "back did not step to the query before")
ui.NavForward()
check(not view.q.sources.filters and not view.q.sources.guilds, "forward")

-- a new block shows while the tab is open
local before = list.count
M.PSS_RecordPlayerBlock(entry, "CHAT_MSG_WHISPER", "third line", nil, "whisper")
M.Events.Fire("PLAYER_BLOCKED", entry)
H.RunTimers()
check(list.count == before + 1, "a new block not shown: " .. list.count .. " was " .. before)

-- the list's totals: View Events opens the whole list
win.tabs[1]._scripts.OnClick(win.tabs[1])
local tsm = pane.totals.summary
check(pane.totals.frame:IsShown() and tsm.viewButton:IsShown(), "no View Events on the totals")
tsm.viewButton._scripts.OnClick(tsm.viewButton)
check(page:IsShown() and view.q.scope == nil and view.q.sources.players and not view.q.sources.guilds, "totals View Events")
_G.PSS_WindowEscape:Hide()

-- Reset Block History of an entry (a player: no confirm)
players.select(entry)
pane.pages:Select("summary")
pane.summary.viewButton._scripts.OnClick(pane.summary.viewButton)
eu.resetButton._scripts.OnClick(eu.resetButton)
H.RunTimers()
check(list.count == 0 or (list.rows[1].cells.message:GetText() or ""):find("expired", 1, true), "Reset Block History left lines: " .. list.count)
-- a tab click: every list, every time and type
win.tabs[4]._scripts.OnClick(win.tabs[4])
check(view.q.scope == nil and view.q.period == nil and view.q.cats == nil and view.q.sources.guilds, "a tab click did not reset the query")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

if not fail then print(("PASS events (%d lines in all)"):format(#view.all)) end
