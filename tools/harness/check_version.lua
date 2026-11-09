-- /pss version (TST-00995, fix-142 F-5), as a run.lua script.
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
local UP = { version = "3.8.0.142", step = 12 }
local MIXED = "Reinstall the 3 folders from one zip."
local rows = {
	{ "row 1", "retail", { "3.8.0.142", "3.8.0.142", "3.8.0.142" }, UP, function(out, row)
		check(hasPat(out, "^Pour Social Score 3%.8%.0%.142 on Retail %(interface [^)]*%)$"), row, "line 1")
		check(not hasSub(out, "Mixed install"), row, "unexpected Mixed install line")
		check(has(out, "Save upgrade record: 3.8.0.142, step 12"), row, "record line")
	end },
	{ "row 2", "forever", { "3.8.0.142", "3.8.0.142", "3.8.0.142" }, UP, function(out, row)
		check(hasSub(out, "on Forever"), row, "line 1")
		check(not hasSub(out, "Mixed install"), row, "unexpected Mixed install line")
	end },
	{ "row 3", "tbc", { "3.8.0.142", "3.8.0.141", "3.8.0.142" }, UP, function(out, row)
		check(hasSub(out, "on TBC Anniversary"), row, "line 1")
		check(has(out, "Mixed install: PourSocialScore_GUI 3.8.0.141, PourSocialScore_Libraries 3.8.0.142. " .. MIXED), row, "mixed line")
	end },
	{ "row 4", "retail", { "3.8.0.142", nil, "3.8.0.142" }, nil, function(out, row)
		check(has(out, "Mixed install: PourSocialScore_GUI not installed, PourSocialScore_Libraries 3.8.0.142. " .. MIXED), row, "mixed line")
		check(has(out, "Save upgrade record: none, step 0"), row, "record line")
	end },
}
check(M.PSS_Need("Libraries"), "setup", "Libraries did not load")
local flavour = M.PSS_FLV.flavour
local realGet, realUp = C_AddOns.GetAddOnMetadata, PourSocialScoreDB.upgrade
local NAMES = { "PourSocialScore", "PourSocialScore_GUI", "PourSocialScore_Libraries" }
local ran = 0
for _, r in ipairs(rows) do
	if r[2] == flavour then
		ran = ran + 1
		C_AddOns.GetAddOnMetadata = function(name, field)
			for i = 1, 3 do if NAMES[i] == name and field == "Version" then return r[3][i] end end
		end
		PourSocialScoreDB.upgrade = r[4]
		r[5](pss("version"), r[1])
		check(hasSub(pss("help"), "version: Show the PSS version"), r[1], "help line")
		C_AddOns.GetAddOnMetadata, PourSocialScoreDB.upgrade = realGet, realUp
	end
end
check(ran > 0, "setup", "no row for flavour " .. tostring(flavour))
if not fail then print("PASS version " .. flavour) end
