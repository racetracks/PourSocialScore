-- Core uplift U1 (3.4.1.45): the upgrade step registry, invisible.
--   the registry's shape (ids, features, parts)
--   M.PSS_VersionOrder (X.Y.Z.B, older names, not a version)
--   counts per feature on a login that reports: a save from 2.0.44 at step
--     0 with planted retired keys; the keys are gone afterwards
--   nothing counted (nil) on a login at the same version and on a new save
--   a version-only change reports with no feature counts
-- As a run.lua script, on any save (a real save after login works too):
--   lua5.1 tools/harness/run.lua . <save|-> - tools/harness/check_upgrade_steps.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL upgrade steps: " .. msg) fail = true end end
local db = PourSocialScoreDB

------------------------------------------------------------------------
-- the registry
------------------------------------------------------------------------
local steps, features = M.PSS_UPGRADE_REGISTRY, {}
for _, f in ipairs(M.PSS_UPGRADE_FEATURES) do features[f] = true end
check(#M.PSS_UPGRADE_FEATURES == 7 and features.cleanup, "seven features, cleanup among them")
check(#steps == M.PSS_UPGRADE_STEPS and #steps >= 8, "M.PSS_UPGRADE_STEPS is the registry's length")
check(steps[1].always == true, "step 1 runs every login")
for i, step in ipairs(steps) do
	check(step.id == i, ("step %d has id %s"):format(i, tostring(step.id)))
	check(type(step.parts) == "table" and #step.parts > 0, ("step %d has no parts"):format(i))
	for j, part in ipairs(step.parts or {}) do
		check(features[part.feature], ("step %d part %d: feature %s"):format(i, j, tostring(part.feature)))
		check(type(part.fields) == "function" or type(part.data) == "function", ("step %d part %d does nothing"):format(i, j))
	end
	check(i == 1 or not step.always, ("step %d runs every login"):format(i))
end
local retired = {}
for _, k in ipairs(M.PSS_UPGRADE_RETIRED) do
	check(not retired[k], "retired twice: " .. k)
	retired[k] = true
end
for _, o in ipairs(M.PSS_OPTIONS) do check(not retired[o.key], "an option is retired: " .. o.key) end

------------------------------------------------------------------------
-- version order
------------------------------------------------------------------------
local order = M.PSS_VersionOrder
for _, c in ipairs({
	{ "3.4.1.44", "3.4.1.45", -1 }, { "3.4.1.45", "3.4.1.45", 0 }, { "3.4.2.52", "3.4.1.51", 1 },
	{ "3.4.0.29", "3.4.1.30", -1 }, { "3.4.0.9", "3.4.0.13", -1 }, { "9.9.9.999", "3.4.1.45", 1 },
	{ "2.0.44", "3.4.1.45", -1 }, { "3.4.0-dev012", "3.4.0.13", -1 }, { "3.3.1", "3.4.0.13", -1 },
	{ "3.3.0-dev004", "3.3.0", -1 }, { "3.3.0", "3.3.0-dev004", 1 }, { "3.4.0-dev008_4", "3.4.0-dev008_3", 1 },
	{ "3.4.0-dev008", "3.4.0-dev008_2", -1 }, { "2.0.9", "2.0.10", -1 }, { "3.2.0-dev3", "3.2.0-dev011", -1 },
	{ "?", "3.4.1.45", nil }, { nil, "3.4.1.45", nil }, { "3.4.1.45", "", nil },
}) do
	local got = order(c[1], c[2])
	check(got == c[3], ("order(%s, %s) is %s, not %s"):format(tostring(c[1]), tostring(c[2]), tostring(got), tostring(c[3])))
end

------------------------------------------------------------------------
-- one login's upgrade, as ApplicationStartup runs it
------------------------------------------------------------------------
-- (M.ShowMsg prints)
local realPrint, printed = print, {}
local function login(fresh)
	print = function(s) printed[#printed + 1] = tostring(s) end
	M.PSS_RunUpgradeFields(fresh, 0)
	M.PSS_ExpandFilters()
	local out = M.PSS_RunUpgradeData(fresh)
	print = realPrint
	return out
end
local version = db.upgrade.version
local steps_n = M.PSS_UPGRADE_STEPS

-- from 2.0.44 with every step due and retired keys planted (routed ones
-- land in the PourSocialScore_Options tables)
local PLANT = { "autoIgnore", "historySize", "windowSizes", "blockStats", "charOptions", "euiIntegration" }
for _, k in ipairs(PLANT) do db[k] = (k == "blockStats") and {} or 1 end
db.upgrade.step, db.upgrade.version = 0, "2.0.44"
local out = login(false)
check(type(out) == "table", "a login from 2.0.44 reports")
out = out or {}
check(out.from == "2.0.44" and out.to == version and out.done == 0 and out.step == steps_n,
	("from %s to %s, steps %s to %s"):format(tostring(out.from), tostring(out.to), tostring(out.done), tostring(out.step)))
check(out.cleanup and out.cleanup.retired == #PLANT, ("retired keys counted: %s"):format(tostring(out.cleanup and out.cleanup.retired)))
for f in pairs(out) do
	if type(out[f]) == "table" then check(features[f], "counts under an unknown feature: " .. f) end
end
local function anywhere(k)
	for _, t in ipairs({ PourSocialScoreDB, PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB, PSS_RulesDB, PSS_CountsDB }) do
		if type(t) == "table" and rawget(t, k) ~= nil then return true end
	end
	return false
end
for _, k in ipairs(PLANT) do check(not anywhere(k), "retired key kept: " .. k) end
check(db.upgrade.step == steps_n and db.upgrade.version == version, "the record is the newest")
local said = false
for _, s in ipairs(printed) do if s:find(("Saved data upgraded to %s (step %d)."):format(version, steps_n), 1, true) then said = true end end
check(said, "the upgrade line is printed")

-- the same version again: nothing counted
check(login(false) == nil, "a login at the same version reports")
-- a new save: nothing counted, even when a step is due
db.upgrade.step = 0
check(login(true) == nil, "a new save reports")
check(db.upgrade.step == steps_n, "a new save is stamped")

-- a version-only change: reported, no feature counts
db.upgrade.version = "3.4.1.30"
out = login(false) or {}
check(out.from == "3.4.1.30" and out.done == steps_n and out.step == steps_n, "version-only change reported")
-- (rules this version cannot use are counted after a version change, U3:
-- a save that holds some has only that key on its feature)
for _, f in ipairs({ "filters", "players", "guilds", "managed", "history", "options" }) do
	for k in pairs(out[f] or {}) do
		check(k == "unusable", "a version-only change counted " .. f .. "." .. k)
	end
end
check(db.upgrade.version == version, "the record has the new version")

print(fail and "FAIL upgrade steps" or "PASS upgrade steps")
