-- Core uplift U2 (3.4.1.46): the upgrade report, 10 cases.
--   1  the registry and the report's phrases (every count has a phrase)
--   2  a 2.0.44 save: the report's shape, and planted player records counted
--   3  the next login at the same version prints nothing
--   4  a new save prints nothing and is stamped
--   5  a version-only change: head, "nothing to tidy", the last line
--   6  planted retired keys: counted on the cleanup line and gone
--   7  a save from a newer version: one line, the record keeps its version
--   8  a paused step: the red line, the step not recorded, reported again
--   9  a real login's output (PSS_LOGIN_OUT, a file): the same shape as 2,
--      and M.PSS_Validate finds no problems
--   10 a login that does not report builds next to nothing
-- As a run.lua script, on any save (validate_all.sh runs it on a new save,
-- the 2.0.44 test save and every real save):
--   PSS_LOGIN_OUT=<first login's output> lua5.1 tools/harness/run.lua . <save|-> - tools/harness/check_upgrade_report.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL upgrade report: " .. msg) fail = true end end
local db = PourSocialScoreDB
local version = db.upgrade.version
local steps_n = M.PSS_UPGRADE_STEPS

local LABELS = {
	"Chat Filtering", "Player Ignore List", "Guild Ignore List", "Managed Communities",
	"Block History", "Options", "SavedVariables performance cleanup",
}
local PREFIX = "Pour Social Score: "
local CLEANUP = PREFIX .. "  SavedVariables performance cleanup: "

-- one login's upgrade, as ApplicationStartup runs it; returns its lines
-- without colour codes
local realPrint = print
local function login(fresh, keep)
	local lines = {}
	print = function(s) lines[#lines + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	M.PSS_RunUpgradeFields(fresh, 0)
	M.PSS_ExpandFilters()
	local counts = M.PSS_RunUpgradeData(fresh)
	print = realPrint
	return lines, counts
end

local function find(lines, text)
	for i, s in ipairs(lines) do if s:find(text, 1, true) then return i, s end end
end

-- the report's shape: a head line, feature lines in print order (each label
-- once), the cleanup line once and last, then the upgraded line; ASCII
local function shape(lines, what)
	local head = find(lines, "Upgrading your saved data:")
	check(head, what .. ": no head line")
	if not head then return end
	local at, n = 0, 0
	local i = head + 1
	while lines[i] and lines[i]:sub(1, #PREFIX + 2) == PREFIX .. "  " do
		local label = lines[i]:sub(#PREFIX + 3):match("^([^:]+): ")
		local pos
		for j, l in ipairs(LABELS) do if l == label then pos = j end end
		check(pos and pos > at, what .. ": a line out of order or unknown: " .. lines[i])
		at = pos or at
		n = n + 1
		i = i + 1
	end
	check(at == #LABELS, what .. ": the cleanup line is not last")
	check(lines[i] and lines[i]:find("Saved data upgraded to " .. version .. " (step " .. steps_n .. ").", 1, true),
		what .. ": the last line is " .. tostring(lines[i]))
	check(n + 2 <= 9, what .. ": more than 9 report lines")
	for _, s in ipairs(lines) do check(not s:find("[\128-\255]"), what .. ": a line that is not ASCII: " .. s) end
end

------------------------------------------------------------------------
-- 1: the registry and the phrases
------------------------------------------------------------------------
-- (the English strings, read from the file: the locale table is private)
local text = {}
for s in io.lines("PourSocialScore/PSS_Localization.lua") do
	local k = s:match('^L%["(UPG_[%w_]+)"%]')
	if k and not text[k] then text[k] = true end
end
local phrases = M.PSS_UPGRADE_PHRASES
for _, f in ipairs(M.PSS_UPGRADE_FEATURES) do
	check(type(phrases[f]) == "table", "no phrases for " .. f)
	check(text["UPG_" .. f], "no label for " .. f)
	for _, key in ipairs(phrases[f] or {}) do
		check(text["UPG_" .. f .. "_" .. key], ("no text for %s.%s"):format(f, key))
	end
end
-- every count a step keeps today has a phrase (an unknown key would not print)
local known = {}
for f, keys in pairs(phrases) do for _, k in ipairs(keys) do known[f .. "." .. k] = true end end
for _, file in ipairs({ "PourSocialScore/PSS_Upgrade.lua", "PourSocialScore/PSS_GuildIgnoreList.lua" }) do for s in io.lines(file) do
	for f, k in s:gmatch('tally%("(%w+)", "(%w+)"') do
		check(known[f .. "." .. k] or (f == "cleanup" and k == "oldFolders"), ("a count with no phrase: %s.%s"):format(f, k))
	end
end end

------------------------------------------------------------------------
-- 2, 6: from 2.0.44 with every step due, planted records and retired keys
------------------------------------------------------------------------
local PLANT = { "autoIgnore", "historySize", "windowSizes", "blockStats" }
for _, k in ipairs(PLANT) do db[k] = (k == "blockStats") and {} or 1 end
db.playerData["planted one-nowhere"] = { note = "x" }
db.playerData["planted two-nowhere"] = { note = "y" }
db.upgrade.step, db.upgrade.version = 0, "2.0.44"
local lines, counts = login(false)
shape(lines, "from 2.0.44")
check(find(lines, "Updated from 2.0.44 to " .. version .. "."), "the head line names the versions")
check(counts and counts.players and (counts.players.tidied or 0) >= 2, "planted records not counted")
local _, players = find(lines, PREFIX .. "  Player Ignore List: ")
check(players and players:find(tostring(counts and counts.players and counts.players.tidied) .. " record(s) of players no longer listed removed", 1, true),
	"the Player Ignore List line does not count the planted records: " .. tostring(players))
local _, cleanup = find(lines, CLEANUP)
check(cleanup and cleanup:find(#PLANT .. " retired key(s) removed", 1, true), "retired keys not on the cleanup line: " .. tostring(cleanup))
for _, k in ipairs(PLANT) do
	check(rawget(PourSocialScoreDB, k) == nil and rawget(PSS_OptionsDB, k) == nil, "retired key kept: " .. k)
end

------------------------------------------------------------------------
-- 3: the same version again prints nothing
------------------------------------------------------------------------
lines = login(false)
check(#lines == 0, "a login at the same version printed: " .. tostring(lines[1]))

------------------------------------------------------------------------
-- 4: a new save prints nothing and is stamped
------------------------------------------------------------------------
db.upgrade.step = 0
lines = login(true)
check(#lines == 0, "a new save printed: " .. tostring(lines[1]))
check(db.upgrade.step == steps_n, "a new save is not stamped")

------------------------------------------------------------------------
-- 5: a version-only change
------------------------------------------------------------------------
-- A save holding rules or settings this version cannot use (Dan's real
-- 3.4.1.50 save has two custom filters) legitimately adds one line per
-- feature that has some (U3), so the expected count follows the save.
local function unusableLines()
	local u, n = M.PSS_UnusableRules(), 0
	for _, list in pairs(u) do if #list > 0 then n = n + 1 end end
	return n
end
db.upgrade.version = "3.4.1.30"
local extra = unusableLines()
lines = login(false)
check(#lines == 3 + extra, ("a version-only change printed %d lines, expected %d"):format(#lines, 3 + extra))
check(lines[1] == PREFIX .. "Updated from 3.4.1.30 to " .. version .. ". Upgrading your saved data:", "head: " .. tostring(lines[1]))
check(lines[2 + extra] == CLEANUP .. "nothing to tidy.", "cleanup: " .. tostring(lines[2 + extra]))
for i = 2, 1 + extra do
	check(lines[i]:find("cannot use", 1, true) or lines[i]:find("does not know", 1, true), "a feature line that is not about unusable rules: " .. tostring(lines[i]))
end
shape(lines, "version-only")

------------------------------------------------------------------------
-- 7: a save from a newer version
------------------------------------------------------------------------
db.upgrade.version = "9.9.9.999"
lines, counts = login(false)
check(counts == nil, "a downgrade reported counts")
check(#lines == 1 + unusableLines() and lines[1] == PREFIX .. "Running " .. version .. ", older than your saved data (9.9.9.999). Nothing was upgraded.",
	"downgrade: " .. tostring(lines[1]))
check(db.upgrade.version == "9.9.9.999" and db.upgrade.step == steps_n, "the record lost the newer version")
db.upgrade.version = version
check(#login(false) == 0, "back at the same version printed")

------------------------------------------------------------------------
-- 8: a paused step
------------------------------------------------------------------------
local split = M.PSS_SavedDataSplit
M.PSS_SavedDataSplit = function() return false end
db.upgrade.step = 1
lines = login(false)
M.PSS_SavedDataSplit = split
check(find(lines, "Saved data upgrade paused at step 2. It tries again at the next login."), "no paused line")
check(not find(lines, "Saved data upgraded"), "the upgraded line with a paused step")
check(db.upgrade.step == 1, "a paused step was recorded")
lines = login(false)
check(find(lines, "Saved data upgraded to " .. version .. " (step " .. steps_n .. ")."), "the next login did not report")
check(db.upgrade.step == steps_n, "the next login did not finish")

------------------------------------------------------------------------
-- 9: a real first login's output
------------------------------------------------------------------------
local path = os.getenv("PSS_LOGIN_OUT")
if path and path ~= "" then
	local real = {}
	for s in io.lines(path) do real[#real + 1] = (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	shape(real, path)
	local r = M.PSS_Validate()
	check(#r.problems == 0, path .. ": " .. tostring(r.problems[1]))
end

------------------------------------------------------------------------
-- 10: a login that does not report builds next to nothing
------------------------------------------------------------------------
M.PSS_ExpandFilters()
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
M.PSS_RunUpgradeFields(false, 0)
local reported = M.PSS_RunUpgradeData(false)
local grew = collectgarbage("count") - before
collectgarbage("restart")
check(reported == nil, "a login at the same version reported")
check(grew < 16, ("a login without a report built %.1f KB"):format(grew))

print(fail and "FAIL upgrade report" or ("PASS upgrade report (no report: %.1f KB)"):format(grew))
