-- Window tidy W2 (Options and Chat Filters tabs): the logic the
-- three drawing files used to hold now lives in Libraries. Each case calls
-- the Libraries function the tab uses; all fail on main (the functions are
-- missing).
local fail = false
local function check(ok, msg) if not ok then print("FAIL w2b: " .. msg) fail = true end end
SlashCmdList["PSS"]("gui")
_G.PSS_Window:Hide()


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

-- G5: Reset Block History marks the Filters list by the event it fires,
-- not by a flag the tab sets
SlashCmdList["PSS"]("gui")
local w2 = _G.PSS_Window
w2.tabs[3]._scripts.OnClick(w2.tabs[3])
local fpage = w2.pages[3]
local V = fpage.state
V.dirty = false
M.PSS_ResetFilterHistory(n)
check(V.dirty == true, "Reset Block History did not mark the Filters list")
w2:Hide()

if not fail then print("PASS w2b") end
