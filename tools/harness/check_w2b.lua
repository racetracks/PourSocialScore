-- Window tidy W2 (Events, Options and Chat Filters tabs): the logic the
-- three drawing files used to hold now lives in Libraries. Each case calls
-- the Libraries function the tab uses; all fail on main (the functions are
-- missing).
local fail = false
local function check(ok, msg) if not ok then print("FAIL w2b: " .. msg) fail = true end end

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window

-- G9: the Events view answers for its own query
local entry = M.PSS_PlayerAddFromText("W2bEvents-Realm1")
M.PSS_RecordPlayerBlock(entry, "CHAT_MSG_WHISPER", "buy gold now", nil, "whisper")
H.RunTimers()
win.tabs[1]._scripts.OnClick(win.tabs[1])
local players = win.pages[1]
players.select(entry)
players.pane.pages:Select("summary")
players.pane.summary.viewButton._scripts.OnClick(players.pane.summary.viewButton)
local view = win.pages[4].view
check(view and view.Scoped and view:Scoped() == true, "Scoped")
check(view.ScopeText and view:ScopeText() == "Only " .. tostring(view.name), "ScopeText")
check(view.IsCustom and view:IsCustom() == false, "IsCustom off")
view:SetPeriod("custom")
check(view:IsCustom() == true, "IsCustom on")
view:SetPeriod("day")
check(view:PeriodIs("day") and not view:PeriodIs("all"), "PeriodIs day")
view:ScopeOff()
check(view:Scoped() == false, "Scoped after ScopeOff")
view.q.period = nil
check(view:PeriodIs("all"), "PeriodIs all when unset")
win:Hide()

if not fail then print("PASS w2b") end
