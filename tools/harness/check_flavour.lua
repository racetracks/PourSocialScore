-- Flavour checks (multi-version suite, tests#stub-per-flavour); run by flv_phases.sh.
--   lua5.1 tools/harness/check_flavour.lua <phase>          (stub, conflict: the stub alone)
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_flavour.lua  with PSS_PHASE=<phase> (the rest)
local phase = arg and arg[1] or os.getenv("PSS_PHASE")
local here = (arg and arg[0] or "tools/harness/check_flavour.lua"):match("^(.*)/[^/]*$") or "."
local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1; print("FAIL flv " .. phase .. ": " .. msg) end end
local function done() if fails == 0 then print("PASS flv " .. phase) end os.exit(fails == 0 and 0 or 1) end

if phase == "stub" then
	-- PSS_EXPECT is the flavour the environment must resolve to; PSS_EXPECT_PID its WOW_PROJECT_ID
	local H = dofile(here .. "/wow_stub.lua")
	local want, pid = os.getenv("PSS_EXPECT"), tonumber(os.getenv("PSS_EXPECT_PID") or "")
	ok(H.flavour == want, "stub.flavour " .. tostring(H.flavour) .. " expected " .. tostring(want))
	ok(WOW_PROJECT_ID == pid, "WOW_PROJECT_ID " .. tostring(WOW_PROJECT_ID) .. " expected " .. tostring(pid))
	ok(WOW_PROJECT_CAMELOT == 18 and WOW_PROJECT_MISTS_CLASSIC == 19 and WOW_PROJECT_CLASSIC == 2 and WOW_PROJECT_BURNING_CRUSADE_CLASSIC == 5 and WOW_PROJECT_MAINLINE == 1, "constants")
	done()
elseif phase == "conflict" then
	local good, err = pcall(dofile, here .. "/wow_stub.lua")
	ok(not good, "stub loaded without error")
	ok(tostring(err) == "PSS_FLAVOUR=tbc conflicts with PSS_CAMELOT=1", "error was: " .. tostring(err))
	done()
else
	-- detect can probe alias levels mem nogrep: need the flavour module (B1T2)
	local M = rawget(_G, "H") and H.Private and nil
	print("FAIL flv " .. tostring(phase) .. ": flavour module not present yet (B1T2)")
	os.exit(1)
end
