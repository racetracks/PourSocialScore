------------------------------------------------------------------------
-- POUR SOCIAL SCORE - LIST TOTALS (3.2)
--
-- One list's blocks added up, for a front end to show when nothing on that
-- list is selected: the Player Ignore List, the Guild Ignore List or the
-- Chat Filters. In PourSocialScore_Libraries (load on demand), so none of
-- it is in memory until a window opens. Reads the counters only: it never
-- loads PourSocialScore_Logging and never writes saved data.
--   M.PSS_ListTotals(kind, into, guildRows)
--     kind: "players", "guilds" or "filters"
--     into: the caller's table, reused: total and one count per block
--           type (History.ALL_CATS), plus session and day (this session,
--           last 24 hours)
--     guildRows: for "guilds", a table M.PSS_GuildRows already filled
--           (its counts are added up instead of read again); nil reads them
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local History = M.PSS_History

local PREFIX = { players = "p:", guilds = "G:", filters = "f:" }

local function add(into, c)
	if type(c) ~= "table" then return end
	into.total = into.total + (tonumber(c.total) or 0)
	for _, cat in ipairs(History.ALL_CATS) do
		into[cat] = into[cat] + (tonumber(c[cat]) or 0)
	end
end

function M.PSS_ListTotals(kind, into, guildRows)
	into = into or {}
	into.total = 0
	for _, cat in ipairs(History.ALL_CATS) do into[cat] = 0 end
	local db = PourSocialScoreDB
	if kind == "players" then
		for _, name in ipairs(db.ignoreList or {}) do
			local p = M.PSS_GetPlayerRecord(name)
			if p then add(into, M.PSS_GetPlayerBlockCounts(p)) end
		end
	elseif kind == "guilds" then
		local pool = guildRows and guildRows.pool
		if pool then
			for _, item in pairs(pool) do add(into, item.bc) end
		else
			for key, g in pairs(db.guildData or {}) do
				if type(g) == "table" then add(into, M.PSS_GetGuildBlockCounts(key)) end
			end
		end
	elseif kind == "filters" then
		-- a guild rule's blocks are on the Guild Ignore List, not here; a
		-- filter that never blocked has no counts table (none is made)
		for i = 1, #(db.filterList or {}) do
			local t = db.filterBlocked and db.filterBlocked[i]
			if type(t) == "table" and not M.PSS_IsGuildRuleFilter(i) then add(into, t.counts) end
		end
	end
	into.session, into.day = 0, 0
	if PREFIX[kind] and History.RecentTotals then
		into.session, into.day = History.RecentTotals(PREFIX[kind])
	end
	return into
end
