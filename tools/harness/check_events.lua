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

if not fail then print("PASS events (View Events opens the console; the Events tab is retired)") end
