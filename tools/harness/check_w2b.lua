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

-- G10: Import/Export state and the import chain
check(M.PSS_IOOn and M.PSS_IOOn("players") == true and M.PSS_IOOn("options") == false, "PSS_IOOn")
check(M.PSS_IOMode and M.PSS_IOMode() == "merge", "PSS_IOMode")
M.PSS_IOSetMode("replace")
check(M.PSS_IOMode() == "replace", "PSS_IOMode replace")
local text, sub = M.PSS_ExportText()
check(type(text) == "string" and sub == ("Copy the string below (%d characters)"):format(#text), "export subtitle: " .. tostring(sub))
local err, ask, apply = M.PSS_ImportStart("not an export")
check(type(err) == "string" and err:find("Import failed", 1, true) and ask == nil and apply == nil, "bad string")
err, ask, apply = M.PSS_ImportStart(text)
check(err == nil and type(ask) == "string" and ask:find("^Replace the ticked") and type(apply) == "function", "replace asks")
M.PSS_IOSetMode("merge")
err, ask, apply = M.PSS_ImportStart(text)
check(err == nil and ask == nil and type(apply) == "function", "merge does not ask")
check(tostring(apply()):find("^Merged: ") ~= nil, "apply report")

-- G7: the Chat Filters Summary spec is filled in Libraries
local into, r = {}, {}
local n = M.PSS_AddCustomFilter("W2b filter", "[word=w2bfilterword]", false)
M.PSS_FilterRow(n, r)
check(M.PSS_FilterSummarySpec and M.PSS_FilterSummarySpec(r, into) == into, "PSS_FilterSummarySpec")
check(into.owner == M.PSS_FilterOwnerKey(n) and into.allTime == (r.blocked or 0) and into.title == r.desc and into.id == n, "filter summary spec")

if not fail then print("PASS w2b") end
