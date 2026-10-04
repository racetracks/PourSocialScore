------------------------------------------------------------------------
-- POUR SOCIAL SCORE - SAVED DATA (3.0)
--
-- The saved data is split over two addons:
--   PourSocialScore          PourSocialScoreDB (the upgrade record)
--   PourSocialScore_Options  PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB,
--                            PSS_RulesDB (always loaded, data only)
-- Code keeps reading and writing PourSocialScoreDB.<key>. A key listed in
-- ROUTE lives in one of the Options tables instead: PourSocialScoreDB gets
-- a metatable that sends reads and writes of keys it does not hold to that
-- table. Keys it still holds are read directly, as before.
--
-- 3.0.0-dev12 (Step 4.1): ROUTE is empty and nothing has moved. The split
-- upgrade step (Step 4.2) fills it and moves the data.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

-- group -> saved table (global) in PourSocialScore_Options
local GROUPS = {
	options	= "PSS_OptionsDB",
	players	= "PSS_PlayersDB",
	guilds	= "PSS_GuildsDB",
	rules	= "PSS_RulesDB",
}
M.PSS_SV_GROUPS = GROUPS

-- PourSocialScoreDB key -> group (empty until the data moves)
local ROUTE = {}
M.PSS_SV_ROUTE = ROUTE

local function groupTable(key)
	local g = ROUTE[key]
	return g and _G[GROUPS[g]]
end

local router = {
	__index = function(_, key)
		local t = groupTable(key)
		if t then return t[key] end
	end,
	__newindex = function(db, key, value)
		local t = groupTable(key)
		if t then t[key] = value else rawset(db, key, value) end
	end,
}

-- The Options tables exist (empty on a first login), and PourSocialScoreDB
-- routes its moved keys. Run at startup and whenever PourSocialScoreDB is
-- replaced (a reset).
function M.PSS_PrepareSavedData()
	for _, name in pairs(GROUPS) do
		if type(_G[name]) ~= "table" then _G[name] = {} end
	end
	if type(PourSocialScoreDB) == "table" and getmetatable(PourSocialScoreDB) ~= router then
		setmetatable(PourSocialScoreDB, router)
	end
end
