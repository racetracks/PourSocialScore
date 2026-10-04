#!/bin/sh
# Multi-addon harness check (3.0): run.lua loads child addons next to the
# core like the game does. A copy of this checkout gets two test addons:
#   PourSocialScore_TestData   always loaded, own SavedVariables
#   PourSocialScore_TestLoD    LoadOnDemand, own SavedVariables
#   PourSocialScore_TestPart   LoadOnDemand, reached through the 3.0 loader
# Checks: the data addon loads at login with its saved table, the LoD addon
# only when C_AddOns.LoadAddOn is called, every SavedVariables global is
# written back, and a second login reads them again. The loader: a stub
# loads its part on first call and hands the call on, a missing part and a
# version mismatch are each reported once, and the shared global is set.
#   sh tools/harness/check_multi.sh   (from the repo root)
here=$(cd "$(dirname "$0")" && pwd)
work=${TMPDIR:-/tmp}/pss-multi
rm -rf "$work"; mkdir -p "$work/root"
git ls-files -co --exclude-standard | tar -c -T - | tar -x -C "$work/root"
mkdir -p "$work/root/PourSocialScore_TestData" "$work/root/PourSocialScore_TestLoD"
printf '## Interface: 120007, 16001\n## Title: Test data\n## SavedVariables: PSS_TestDataDB\n\ndata.lua\n' \
	> "$work/root/PourSocialScore_TestData/PourSocialScore_TestData.toc"
printf 'local name, private = ...\nPSS_TestDataDB = PSS_TestDataDB or { logins = 0 }\nPSS_TestDataDB.logins = PSS_TestDataDB.logins + 1\nPSS_TestDataDB.private = (private ~= nil) and name or "none"\n' \
	> "$work/root/PourSocialScore_TestData/data.lua"
printf '## Interface: 120007, 16001\n## Title: Test LoD\n## LoadOnDemand: 1\n## Dependencies: PourSocialScore\n## SavedVariables: PSS_TestLoDDB\n\nlod.lua [AllowLoadGameType standard]\n' \
	> "$work/root/PourSocialScore_TestLoD/PourSocialScore_TestLoD.toc"
printf 'PSS_TestLoDDB = PSS_TestLoDDB or { loads = 0 }\nPSS_TestLoDDB.loads = PSS_TestLoDDB.loads + 1\n' \
	> "$work/root/PourSocialScore_TestLoD/lod.lua"
mkdir -p "$work/root/PourSocialScore_TestPart"
printf '## Interface: 120007, 16001\n## Title: Test part\n## Version: 0.0-old\n## LoadOnDemand: 1\n## Dependencies: PourSocialScore\n\npart.lua\n' \
	> "$work/root/PourSocialScore_TestPart/PourSocialScore_TestPart.toc"
printf 'local M = PourSocialScore_NS.M\nfunction M.PSS_TestEcho(a, b) return a + b, "part" end\n' \
	> "$work/root/PourSocialScore_TestPart/part.lua"
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
-- 3.0 loader
check(PourSocialScore_NS ~= nil and PourSocialScore_NS.M == M, "shared global PourSocialScore_NS")
local said, show = {}, M.ShowMsg
M.ShowMsg = function(s) said[#said + 1] = tostring(s) end
M.PSS_PARTS.TestPart = "PourSocialScore_TestPart"
M.PSS_PARTS.Gone = "PourSocialScore_Gone"
M.PSS_Stub("PSS_TestEcho", "TestPart")
check(not C_AddOns.IsAddOnLoaded("PourSocialScore_TestPart"), "part not loaded before the stub is called")
local sum, from = M.PSS_TestEcho(2, 3)
check(sum == 5 and from == "part", "stub loads the part and hands the call on")
check(C_AddOns.IsAddOnLoaded("PourSocialScore_TestPart"), "part loaded by the stub")
check(M.PSS_TestEcho(1, 1) == 2, "part's function replaced the stub")
check(#said == 1 and said[1]:find("0.0-old", 1, true), "version mismatch reported once")
M.PSS_Stub("PSS_TestGone", "Gone")
check(M.PSS_TestGone() == nil and M.PSS_TestGone() == nil, "missing part: stub does nothing")
check(#said == 2 and said[2]:find("PourSocialScore_Gone", 1, true), "missing part reported once")
check(M.PSS_Need("NoSuchKey") == false, "unknown key")
M.ShowMsg = show
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
