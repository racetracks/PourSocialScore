------------------------------------------------------------------------
-- POUR SOCIAL SCORE - SAVED DATA (3.0)
--
-- The saved data is split over three addons:
--   PourSocialScore          PourSocialScoreDB: the upgrade record and
--                            bookkeeping
--   PourSocialScore_Options  PSS_OptionsDB    options and window state
--   (always loaded,          PSS_PlayersDB    the Player Ignore List
--    data only)              PSS_GuildsDB     the Guild Ignore List
--                            PSS_RulesDB      chat rules and built-in on/off
--   PourSocialScore_Logging  PSS_LoggingDB    block history, kept lines,
--   (data only)                               hourly stats, totals and chat
--                                             rule counts
-- The block counts of each player and guild member stay on their record.
-- Code keeps reading and writing PourSocialScoreDB.<key>. A key listed in
-- LAYOUT lives in one of the Options tables: PourSocialScoreDB gets a
-- metatable that sends reads and writes of keys it does not hold to that
-- table. Keys it still holds are read directly.
--
-- The split (upgrade steps 2 and 3) moves a routed key that
-- PourSocialScoreDB still holds (a 2.0 save, a fresh or reset save, a legacy
-- import) to its table: check, count, move, validate, clean. It moves table references, so
-- nothing is copied. If the counts after the move differ, the move is undone
-- and retried at the next login.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

-- group -> saved table (global), and the addon that saves it
local GROUPS = {
	options	= "PSS_OptionsDB",
	players	= "PSS_PlayersDB",
	guilds	= "PSS_GuildsDB",
	rules	= "PSS_RulesDB",
	logging	= "PSS_LoggingDB",
}
M.PSS_SV_GROUPS = GROUPS
local OWNER = {
	options	= "PourSocialScore_Options",
	players	= "PourSocialScore_Options",
	guilds	= "PourSocialScore_Options",
	rules	= "PourSocialScore_Options",
	logging	= "PourSocialScore_Logging",
}

-- group -> the PourSocialScoreDB keys it holds. The options in
-- M.PSS_OPTIONS (PSS_Options.lua) are added to "options".
local LAYOUT = {
	options	= { "showIgnoreDebug", "windowSizes", "columnWidths", "charOptions", "optionsV2012" },
	players	= { "ignoreList", "typeList", "factionList", "dateList", "notes", "expList", "delList",
				"syncInfo", "playerData" },
	guilds	= { "guildData", "guildExclusions", "guildGroupOpen", "scanFieldsDefaultV1", "guildPlayerCleanupV3" },
	rules	= { "filterList", "filterDesc", "filterActive", "filterID", "builtinRules", "filterFormat",
				"optInFiltersV1" },
	logging	= { "blockLog", "blockKeep", "blockStats", "historyFormat", "hiddenTotal", "filterTotal",
				"filterWhisperTotal", "filterPrivateTotal", "filterCount", "filterBlocked", "filterBlockedLast",
				"builtinStats", "guildRuleCountsV1" },
}

-- PourSocialScoreDB key -> group
local ROUTE = {}
M.PSS_SV_ROUTE = ROUTE

local function buildRoute()
	for g, keys in pairs(LAYOUT) do
		for _, k in ipairs(keys) do ROUTE[k] = g end
	end
	for _, o in ipairs(M.PSS_OPTIONS or {}) do ROUTE[o.key] = "options" end
end

-- addon -> loaded (its tables are saved). A key is routed only while the
-- addon that saves its table is loaded; otherwise it stays in
-- PourSocialScoreDB.
local active = {}

local function groupTable(key)
	local g = ROUTE[key]
	return g and active[OWNER[g]] and _G[GROUPS[g]]
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

local function loaded(name)
	local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	return f ~= nil and f(name) and true or false
end

local function counts()
	return M.PSS_Validate and M.PSS_Validate().n or {}
end

-- the keys whose numbers differ ("" when none)
local function compare(before, after)
	local bad = {}
	for k, v in pairs(before) do if after[k] ~= v then bad[#bad + 1] = k end end
	for k in pairs(after) do if before[k] == nil then bad[#bad + 1] = k end end
	table.sort(bad)
	return table.concat(bad, ", ")
end

local warned = {}
local split = {}		-- addon -> its data is split

-- The Options tables exist, PourSocialScoreDB routes its moved keys, and
-- any routed key PourSocialScoreDB still holds is moved. Run at startup and
-- whenever PourSocialScoreDB is replaced (a reset). opts.wipe empties the
-- Options tables first (a reset); opts.quiet prints nothing (a new save).
-- Returns true when the data is split.
function M.PSS_PrepareSavedData(opts)
	opts = opts or {}
	local db = PourSocialScoreDB
	if type(db) ~= "table" then return false end
	buildRoute()
	if getmetatable(db) ~= router then setmetatable(db, router) end

	-- check: the data addons are loaded, so their tables will be saved
	local ok = true
	for g, name in pairs(GROUPS) do
		local owner = OWNER[g]
		active[owner] = loaded(owner)
		split[owner] = active[owner]
		if active[owner] then
			if type(_G[name]) ~= "table" then _G[name] = {} end
			if opts.wipe then for k in pairs(_G[name]) do _G[name][k] = nil end end
		else
			ok = false
			if not warned[owner] then
				warned[owner] = true
				M.ShowMsg("|cffff3333" .. owner .. " is not loaded:|r its data stays in PourSocialScore for now. Install every folder from the zip.")
			end
		end
	end

	local keys, movedTo = {}, {}
	for k, g in pairs(ROUTE) do
		if active[OWNER[g]] and rawget(db, k) ~= nil then
			keys[#keys + 1] = k
			movedTo[OWNER[g]] = true
		end
	end
	if #keys == 0 then return ok end

	-- count, move (a key PourSocialScoreDB holds wins: it is what code reads
	-- today), validate
	local before = counts()
	local old = {}
	for _, k in ipairs(keys) do
		local t = _G[GROUPS[ROUTE[k]]]
		old[k] = t[k]
		t[k] = rawget(db, k)
		rawset(db, k, nil)
	end
	local diff = compare(before, counts())
	if diff ~= "" then
		-- undo: put every key back; the step is not recorded, so it runs again
		-- at the next login
		for _, k in ipairs(keys) do
			local t = _G[GROUPS[ROUTE[k]]]
			rawset(db, k, t[k])
			t[k] = old[k]
		end
		for owner in pairs(movedTo) do split[owner] = false end
		M.ShowMsg("|cffff3333Saved data not moved|r (counts differ: " .. diff .. "). Nothing was changed; it tries again at the next login.")
		return false
	end

	if not opts.quiet then
		local n = before
		if movedTo.PourSocialScore_Options then
			M.ShowMsg(("Saved data moved to PourSocialScore_Options: %d Player Ignore List entries (%d notes), %d guild rules (%d members), %d custom chat rules, %d options."):format(
				n.list or 0, n.listNotes or 0, n.guildRules or 0, n.membersStored or 0, n.filters or 0, n.optionsSet or 0))
		end
		if movedTo.PourSocialScore_Logging then
			M.ShowMsg(("Saved data moved to PourSocialScore_Logging: %d block history lines, %d kept lines for %d people, %d chat filter blocks."):format(
				n.logLines or 0, n.keptLines or 0, n.keptPeople or 0, n.filterRowCounts or 0))
		end
	end
	return ok
end

-- the data saved by that addon is split (upgrade step 2: Options, step 3:
-- Logging)
function M.PSS_SavedDataSplit(owner) return split[owner] == true end
