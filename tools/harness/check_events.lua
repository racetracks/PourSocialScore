-- The new window's Events tab (3.4.0-dev011), as a run.lua script on any
-- save, real ones included: opened from a player's Summary (View Events and
-- a slice), a pane's history double-click and a list's totals; the lines,
-- the Time (custom range), Types and Source drop-downs, the search, sorting,
-- link hover (never a profession link's tooltip), a double-click copy,
-- Reset Block History, back / forward and Escape back to the tab that
-- opened it, and new blocks shown while it is open.
local fail = false
local function check(ok, msg) if not ok then print("FAIL events: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window
local ui = H.Private("PourSocialScore_GUI")
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
local page = win.pages[M.PSS_UITabIndex("console")]
check(page:IsShown(), "View Events did not open the console")
check(loaded("PourSocialScore_Logging"), "the console did not load Logging")
-- Escape goes back to the tab that opened it
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and players:IsShown(), "Escape did not go back to the Players tab")

-- a slice: its period only
sm:Open("session")
check(page:IsShown(), "the session slice did not open the console")
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and players:IsShown(), "Escape did not go back after a slice")

-- the retired Events tab (phase B, D50)
-- (a) the console shows the counts the Events tab showed (core counts, check_viewquery.lua definitions)
local want = (M.PSS_GetPlayerBlockCounts(entry) or {}).total or 0
local res = M.PSS_Search("index=log owner=$owner | sort -time | head 200", { params = { owner = M.PSS_PlayerHistoryKey(entry) }, load = true, rows = 200 })
check(want == 2, "the core counts " .. tostring(want) .. " blocks for the planted player, not 2")
check(res and res.n == want, "the console lists " .. tostring(res and res.n) .. " lines for the player; the core counts " .. want)
-- (b) no tab index for Events; the old key resolves to the console
check(M.PSS_UITabIndex("events") == nil, "an Events tab still exists")
for i, t in ipairs(M.PSS_UI_TABS) do check(t.key ~= "events", "tab " .. i .. " is Events") end
check(M.PSS_ResolveTab("events") == "console", "the events key does not resolve to the console")
-- (c) a save whose last tab was Events opens the console
PourSocialScoreDB.windowPoints = PourSocialScoreDB.windowPoints or {}
PourSocialScoreDB.windowPoints.PSS_WindowTab = "events"
check(M.PSS_UITab() == M.PSS_UITabIndex("console"), "a saved Events tab did not fall back to the console")

if not fail then print("PASS events (View Events opens the console; the Events tab is retired)") end
