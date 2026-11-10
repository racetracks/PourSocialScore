-- /pss version (TST-00995, TST-00998, fix-142 F-5), as a run.lua script.
--   PSS_FLAVOUR=retail|forever|tbc lua5.1 tools/harness/run.lua . - - tools/harness/check_version.lua
-- Runs the rows of its table whose flavour is the stub's. Prints "PASS version <flavour>" or "FAIL version: <row>: <line>".
local fail = false
local function check(ok, row, msg) if not ok then print("FAIL version: " .. row .. ": " .. msg) fail = true end return ok end
local realPrint = print
local function pss(cmd)
	local said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^Pour Social Score: ", "")) end
	local ok, err = pcall(M.PSS_SlashPSS, cmd)
	print = realPrint
	if not ok then check(false, "run", "error: " .. tostring(err)) end
	return said
end
local function has(lines, text)
	for _, s in ipairs(lines) do if s == text then return true end end
end
local function hasPat(lines, pat)
	for _, s in ipairs(lines) do if s:find(pat) then return true end end
end
local function hasSub(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return true end end
end
local CORE = "3.8.0.142"
local UP = { version = CORE, step = 12 }
local MIXED = " Reinstall the 6 folders from one zip."
local function L1(client) return "^Pour Social Score 3%.8%.0%.142 on " .. client .. " %(interface [^)]*%)$" end
local REC = "Save upgrade record: 3.8.0.142, step 12"
local rows = {
	{ "row 1", "retail", {}, UP, function(out, row)
		check(hasPat(out, L1("Retail")), row, "line 1")
		check(has(out, REC), row, "record line")
		check(not hasSub(out, "Mixed install"), row, "unexpected Mixed install line")
		check(not hasSub(out, "Save record differs"), row, "unexpected differs line")
	end },
	{ "row 2", "forever", {}, UP, function(out, row)
		check(hasPat(out, L1("Forever")), row, "line 1")
		check(has(out, REC), row, "record line")
		check(not hasSub(out, "Mixed install"), row, "unexpected Mixed install line")
		check(not hasSub(out, "Save record differs"), row, "unexpected differs line")
	end },
	{ "row 3", "tbc", { PourSocialScore_GUI = "3.8.0.141" }, UP, function(out, row)
		check(hasPat(out, L1("TBC Anniversary")), row, "line 1")
		check(has(out, "Mixed install: PourSocialScore_GUI 3.8.0.141." .. MIXED), row, "mixed line")
		check(not hasSub(out, "Save record differs"), row, "unexpected differs line")
	end },
	{ "row 4", "retail", { PourSocialScore_GUI = false }, nil, function(out, row)
		check(has(out, "Mixed install: PourSocialScore_GUI not installed." .. MIXED), row, "mixed line")
		check(has(out, "Save upgrade record: none, step 0"), row, "record line")
		check(not hasSub(out, "Save record differs"), row, "unexpected differs line")
	end },
	{ "row 5", "forever", { PourSocialScore_Options = "3.8.0.139" }, UP, function(out, row)
		check(has(out, "Mixed install: PourSocialScore_Options 3.8.0.139." .. MIXED), row, "mixed line")
		check(not hasSub(out, "Save record differs"), row, "unexpected differs line")
	end },
	{ "row 6", "tbc", { PourSocialScore_Communities = "3.8.0.141", PourSocialScore_Logging = false, PourSocialScore_Libraries = "3.8.0.140" }, UP, function(out, row)
		check(has(out, "Mixed install: PourSocialScore_Libraries 3.8.0.140, PourSocialScore_Logging not installed, PourSocialScore_Communities 3.8.0.141." .. MIXED), row, "mixed line")
		check(not hasSub(out, "Save record differs"), row, "unexpected differs line")
	end },
	{ "row 7", "retail", {}, { version = "3.8.0.139", step = 12 }, function(out, row)
		check(has(out, "Save upgrade record: 3.8.0.139, step 12"), row, "record line")
		check(has(out, "Save record differs: this save was last upgraded by 3.8.0.139, this client loaded 3.8.0.142."), row, "differs line")
		check(not hasSub(out, "Mixed install"), row, "unexpected Mixed install line")
	end },
}
check(M.PSS_Need("Libraries"), "setup", "Libraries did not load")
local flavour = M.PSS_FLV.flavour
local realGet, realUp = C_AddOns.GetAddOnMetadata, PourSocialScoreDB.upgrade
local NAMES = { PourSocialScore_Options = true, PourSocialScore_Libraries = true, PourSocialScore_GUI = true, PourSocialScore_Logging = true, PourSocialScore_Communities = true, PourSocialScore = true }
local ran = 0
for _, r in ipairs(rows) do
	if r[2] == flavour then
		ran = ran + 1
		C_AddOns.GetAddOnMetadata = function(name, field)
			if field == "Version" and NAMES[name] then
				local o = r[3][name]
				if o == false then return nil end
				return o or CORE
			end
		end
		PourSocialScoreDB.upgrade = r[4]
		r[5](pss("version"), r[1])
		check(hasSub(pss("help"), "version: Show the PSS version"), r[1], "help line")
		C_AddOns.GetAddOnMetadata, PourSocialScoreDB.upgrade = realGet, realUp
	end
end
check(ran > 0, "setup", "no row for flavour " .. tostring(flavour))
if not fail then print("PASS version " .. flavour) end
