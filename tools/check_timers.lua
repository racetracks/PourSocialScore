-- Every OnUpdate and timer call in the addon, against the approved list
-- (service-bus-helper STP-00126, TST-00156 and TST-00186; baseline 02 C3).
-- The approved list is the sites that exist today; it only shrinks (the
-- service bus roadmap moves each one onto the trigger engine, STP-00128). A
-- new site, or a file with more than it was approved for, fails. The trigger
-- engine and its parts hold no OnUpdate, and the engine holds the one timer
-- call (its clock; PSS 02 section 12).
-- Usage: lua5.1 tools/check_timers.lua   (from the repo root)
local APPROVED = {		-- { OnUpdate, timer calls }
	["PourSocialScore/PSS_ChatBlock.lua"] = { 0, 2 },
	["PourSocialScore/PSS_ChatHistory.lua"] = { 0, 1 },
	["PourSocialScore/PSS_GuildIgnoreList.lua"] = { 0, 6 },
	["PourSocialScore/PSS_Perf.lua"] = { 1, 0 },
	["PourSocialScore/PSS_Whois.lua"] = { 0, 4 },
	["PourSocialScore/PourSocialScore.lua"] = { 0, 1 },
	["PourSocialScore_GUI/PSS_Addons.lua"] = { 0, 1 },
	["PourSocialScore_GUI/PSS_Filters.lua"] = { 0, 1 },
	["PourSocialScore_GUI/PSS_Guilds.lua"] = { 0, 1 },
	["PourSocialScore_GUI/PSS_Pie.lua"] = { 2, 0 },
	["PourSocialScore_GUI/PSS_Popups.lua"] = { 2, 0 },
	["PourSocialScore_Libraries/PSS_ViewNav.lua"] = { 0, 1 },
}
local ENGINE = { ["PourSocialScore/PSS_Watch.lua"] = 0, ["PourSocialScore_Libraries/PSS_Bus.lua"] = 0, ["PourSocialScore_Libraries/PSS_Trig.lua"] = 1 }

local fail = false
local function bad(msg) print("FAIL timers: " .. msg) fail = true end

local p = io.popen("ls PourSocialScore*/*.lua")
local total_o, total_t = 0, 0
for path in p:lines() do
	local fh = io.open(path)
	local code = fh:read("*a"):gsub("%-%-[^\n]*", "")
	fh:close()
	local _, o = code:gsub("OnUpdate", "")
	local _, t1 = code:gsub("C_Timer%.", "")
	local _, t2 = code:gsub("[^%w_%.]After%(", "")
	local t = t1 + t2
	local ap = APPROVED[path]
	if ENGINE[path] then
		if o ~= 0 then bad(path .. " has " .. o .. " OnUpdate; the trigger engine holds none") end
		if t ~= ENGINE[path] then bad(path .. " has " .. t .. " timer calls, expected " .. ENGINE[path]) end
	else
		total_o, total_t = total_o + o, total_t + t
		if (o > 0 or t > 0) and not ap then
			bad(path .. " is not approved for " .. o .. " OnUpdate and " .. t .. " timer calls (use the trigger engine, M.PSS_Want)")
		elseif ap and (o > ap[1] or t > ap[2]) then
			bad(path .. " has " .. o .. " OnUpdate and " .. t .. " timer calls, approved " .. ap[1] .. " and " .. ap[2])
		elseif ap and (o < ap[1] or t < ap[2]) then
			print("NOTE timers: " .. path .. " now has fewer sites (" .. o .. ", " .. t .. "); lower its approved row")
		end
	end
end
p:close()
if not fail then print(string.format("PASS timers: %d OnUpdate and %d timer calls outside the engine, none new; the engine has one timer call", total_o, total_t)) end
os.exit(fail and 1 or 0)
