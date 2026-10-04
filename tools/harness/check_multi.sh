#!/bin/sh
# Multi-addon harness check (3.0): run.lua loads child addons next to the
# core like the game does. A copy of this checkout gets two test addons:
#   PourSocialScore_TestData   always loaded, own SavedVariables
#   PourSocialScore_TestLoD    LoadOnDemand, own SavedVariables
# Checks: the data addon loads at login with its saved table, the LoD addon
# only when C_AddOns.LoadAddOn is called, every SavedVariables global is
# written back, and a second login reads them again.
#   sh tools/harness/check_multi.sh   (from the repo root)
here=$(cd "$(dirname "$0")" && pwd)
work=${TMPDIR:-/tmp}/pss-multi
rm -rf "$work"; mkdir -p "$work/root"
git ls-files | tar -c -T - | tar -x -C "$work/root"
mkdir -p "$work/root/PourSocialScore_TestData" "$work/root/PourSocialScore_TestLoD"
printf '## Interface: 120007, 16001\n## Title: Test data\n## SavedVariables: PSS_TestDataDB\n\ndata.lua\n' \
	> "$work/root/PourSocialScore_TestData/PourSocialScore_TestData.toc"
printf 'local name, private = ...\nPSS_TestDataDB = PSS_TestDataDB or { logins = 0 }\nPSS_TestDataDB.logins = PSS_TestDataDB.logins + 1\nPSS_TestDataDB.private = (private ~= nil) and name or "none"\n' \
	> "$work/root/PourSocialScore_TestData/data.lua"
printf '## Interface: 120007, 16001\n## Title: Test LoD\n## LoadOnDemand: 1\n## Dependencies: PourSocialScore\n## SavedVariables: PSS_TestLoDDB\n\nlod.lua [AllowLoadGameType standard]\n' \
	> "$work/root/PourSocialScore_TestLoD/PourSocialScore_TestLoD.toc"
printf 'PSS_TestLoDDB = PSS_TestLoDDB or { loads = 0 }\nPSS_TestLoDDB.loads = PSS_TestLoDDB.loads + 1\n' \
	> "$work/root/PourSocialScore_TestLoD/lod.lua"
cat > "$work/script.lua" <<'LUA'
local fail = false
local function check(ok, what) if not ok then print("FAIL multi: " .. what) fail = true end end
check(M ~= nil, "core namespace")
check(C_AddOns.IsAddOnLoaded("PourSocialScore"), "core loaded")
check(C_AddOns.IsAddOnLoaded("PourSocialScore_TestData"), "data addon loaded at login")
check(PSS_TestDataDB and PSS_TestDataDB.private == "PourSocialScore_TestData", "data addon has its own private table")
check(not C_AddOns.IsAddOnLoaded("PourSocialScore_TestLoD"), "LoD addon not loaded at login")
check(PSS_TestLoDDB == nil or PSS_TestLoDDB.loads == tonumber(os.getenv("PSS_LOD_BEFORE")), "LoD saved table untouched before load")
local ok = C_AddOns.LoadAddOn("PourSocialScore_TestLoD")
check(ok == true and C_AddOns.IsAddOnLoaded("PourSocialScore_TestLoD"), "LoD addon loads on demand")
local ok2, why = C_AddOns.LoadAddOn("PourSocialScore_Missing")
check(ok2 == false and why == "MISSING", "missing addon reports MISSING")
check(PSS_TestDataDB.logins == tonumber(os.getenv("PSS_LOGINS")), "data saved table read back")
if not fail then print("PASS multi " .. os.getenv("PSS_LOGINS")) end
LUA
fail=0
cd "$work/root"
out=$(PSS_LOGINS=1 PSS_LOD_BEFORE=0 lua5.1 "$here/run.lua" . - "$work/sv1.lua" "$work/script.lua" 2>&1 | grep -v '^|cff')
echo "$out"; echo "$out" | grep -q "PASS multi 1" || fail=1
grep -q '^PourSocialScoreDB = ' "$work/sv1.lua" || { echo "FAIL multi: core saved table not written"; fail=1; }
grep -q '^PSS_TestDataDB = ' "$work/sv1.lua" || { echo "FAIL multi: data saved table not written"; fail=1; }
grep -q '^PSS_TestLoDDB = ' "$work/sv1.lua" || { echo "FAIL multi: LoD saved table not written"; fail=1; }
out=$(PSS_LOGINS=2 PSS_LOD_BEFORE=1 lua5.1 "$here/run.lua" . "$work/sv1.lua" "$work/sv2.lua" "$work/script.lua" 2>&1 | grep -v '^|cff')
echo "$out"; echo "$out" | grep -q "PASS multi 2" || fail=1
[ $fail -eq 0 ] && echo "PASS multi-addon harness" || echo "FAIL multi-addon harness"
exit $fail
