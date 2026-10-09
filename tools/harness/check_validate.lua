-- /pss check (3.0): as a run.lua script. The saved data loaded must have no
-- problems; then three planted faults must each be reported, and nothing
-- may be changed by the check itself.
local fail = false
local function check(ok, msg) if not ok then print("FAIL validate: " .. msg) fail = true end end

local r = M.PSS_Validate()
for _, p in ipairs(r.problems) do print("problem: " .. p) end
check(#r.problems == 0, "the loaded save has problems")
check(r.n.guildRules > 0 and r.n.filters > 0, "nothing counted")

-- read only: a second run gives the same numbers
local again = M.PSS_Validate()
for k, v in pairs(r.n) do check(again.n[k] == v, "count changed between runs: " .. k) end

-- planted faults
local db = PourSocialScoreDB
local list = M.PSS_List()
local saved = { db.filterID[2], db.guildData.zzbroken }
local planted = #list + 1
list[planted] = 42		-- a list entry that is not a record
local id1 = db.filterID[1]
db.filterID[2] = id1
db.guildData.zzbroken = 5
local bad = M.PSS_Validate()
local text = table.concat(bad.problems, "\n")
check(text:find("not a record", 1, true) ~= nil, "a list entry that is not a record was not reported")
check(text:find("chat filter ID " .. tostring(id1) .. " is used twice", 1, true) ~= nil, "duplicate filter ID not reported")
check(text:find("guild rule zzbroken is not a table", 1, true) ~= nil, "broken guild rule not reported")
list[planted] = nil
db.filterID[2], db.guildData.zzbroken = saved[1], saved[2]

-- the chat command prints the report
local seen, show = false, M.ShowMsg
M.ShowMsg = function(s) if tostring(s):find("Saved data check", 1, true) then seen = true end end
M.PSS_PrintValidation()
M.ShowMsg = show
check(seen, "/pss check printed nothing")

if not fail then print("PASS validate") end
