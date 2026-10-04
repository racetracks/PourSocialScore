------------------------------------------------------------------------
-- POUR SOCIAL SCORE - BLOCK STATS (this session / last 24 hours)
--
-- The totals stay where they always were (per player, member and filter
-- counters). This module only adds the two shorter windows shown above
-- them at the top of the Player Ignore List, Guild Ignore List and Chat
-- Filters tabs:
--
--   this session   : counted in memory since login or /reload, never saved
--   last 24 hours  : one small table per hour that had a block, at most 24
--                    per source, older hours dropped (no per-block log)
--
-- Saved shape (PourSocialScoreDB.blockStats):
--   { v = 1,
--     player = { [hour] = { total = n, whisper = n, ... } },
--     guild  = { [hour] = { ... } },
--     filter = { [hour] = { total = n, whisper = n, private = n } } }
-- hour = floor(server time / 3600); only non-zero counts are stored.
--
-- Sources and their categories:
--   player, guild : the block history categories (whisper, partyInvite,
--                   guildInvite, partyRaid, world, guildChat, unknown)
--   filter        : whisper (character whispers), private (Battle.net
--                   whispers); every other filter block counts in total only
--
-- Upgrade (v1): created on the first login with this version and filled
-- from the block history lines of the last 24 hours that are still in the
-- shared log, so the 24 hour line is not empty straight after updating.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

local Stats = {}
M.PSS_Stats = Stats

Stats.VERSION = 1
Stats.HOURS = 24
Stats.SOURCES = { "player", "guild", "filter" }

local floor = math.floor

local session = { player = { total = 0 }, guild = { total = 0 }, filter = { total = 0 } }

local function now()
	return (GetServerTime and GetServerTime()) or time()
end

local function hourOf(ts) return floor((tonumber(ts) or 0) / 3600) end

-- The saved table; created empty when missing (Upgrade fills it once).
local function store()
	local db = PourSocialScoreDB
	if type(db) ~= "table" then return nil end
	local s = db.blockStats
	if type(s) ~= "table" then s = {}; db.blockStats = s end
	for _, src in ipairs(Stats.SOURCES) do
		if type(s[src]) ~= "table" then s[src] = {} end
	end
	return s
end

-- Drop hours that have left the 24 hour window.
function Stats.Prune(nowHour)
	local s = store()
	if not s then return end
	local oldest = (nowHour or hourOf(now())) - Stats.HOURS + 1
	for _, src in ipairs(Stats.SOURCES) do
		for h in pairs(s[src]) do
			if type(h) ~= "number" or h < oldest then s[src][h] = nil end
		end
	end
end

local function bump(t, cat)
	t.total = (t.total or 0) + 1
	if cat then t[cat] = (t[cat] or 0) + 1 end
end

local lastHour
local function addHour(src, cat, ts)
	local s = store()
	if not s or not s[src] then return end
	local h = hourOf(ts)
	local b = s[src][h]
	if not b then
		b = {}
		s[src][h] = b
		-- a new hour: forget the one that just left the window
		if h ~= lastHour then lastHour = h; Stats.Prune(h) end
	end
	bump(b, cat)
end

-- One block. src: "player" | "guild" | "filter"; cat may be nil (total only).
function Stats.Count(src, cat)
	local t = session[src]
	if not t then return end
	bump(t, cat)
	addHour(src, cat, now())
end

-- Take one block back out of the saved 24 hour counts (total only), for
-- a line that was counted by mistake. Older hours are gone already.
function Stats.Uncount(src, ts)
	local s = store()
	if not s or not s[src] then return end
	local h = hourOf(ts)
	local b = s[src][h]
	if type(b) ~= "table" then return end
	b.total = (tonumber(b.total) or 0) - 1
	if b.total <= 0 then s[src][h] = nil end
end

-- Filter category of a chat event (nil = total only).
function Stats.FilterCat(event)
	if event == "CHAT_MSG_WHISPER" then return "whisper" end
	if event == "CHAT_MSG_BN_WHISPER" then return "private" end
	return nil
end

-- Counts since login / reload (read only: do not change the table).
function Stats.Session(src)
	return session[src] or { total = 0 }
end

-- Counts of the last 24 hours (a new table).
function Stats.Last24(src)
	local out = { total = 0 }
	local s = store()
	if not s or not s[src] then return out end
	local oldest = hourOf(now()) - Stats.HOURS + 1
	for h, b in pairs(s[src]) do
		if type(h) == "number" and h >= oldest and type(b) == "table" then
			for k, n in pairs(b) do out[k] = (out[k] or 0) + (tonumber(n) or 0) end
		end
	end
	return out
end

-- "Reset Block History" of a whole tab: its session and 24 hour counts go too,
-- so they never show more than the total.
function Stats.Reset(src)
	if session[src] then session[src] = { total = 0 } end
	local s = store()
	if s and s[src] then s[src] = {} end
end

-- Source of a block log line (see PSS_ChatHistory.lua): o = "p:" player,
-- "g:" guild member, "f:" chat filter. (2.0.38 and older also tagged guild
-- rule blocks with r and counted them on the Chat Filters tab too; that tag
-- is cleared before this runs, see PSS_UnlinkGuildRuleCounts.)
local function seedFromLog(s)
	local History = M.PSS_History
	if not History then return 0 end
	local oldest = hourOf(now()) - Stats.HOURS + 1
	local n = 0
	local db = PourSocialScoreDB
	local left = { whisper = tonumber(db.filterWhisperTotal) or 0, private = tonumber(db.filterPrivateTotal) or 0 }
	local function add(src, h, cat)
		local b = s[src][h]
		if not b then b = {}; s[src][h] = b end
		bump(b, cat)
		n = n + 1
	end
	-- the log and the per-player keep: every line is in one of them only
	History.Each(function(e)
		local h = type(e) == "table" and hourOf(e.ts) or 0
		if h > 0 and h >= oldest then
			local o = type(e.o) == "string" and e.o:sub(1, 2) or ""
			if o == "p:" then add("player", h, e.cat)
			elseif o == "g:" then add("guild", h, e.cat)
			elseif o == "f:" then
				-- never more than the saved whisper / private totals (older
				-- builds did not count every filtered whisper there)
				local cat = Stats.FilterCat(e.event)
				if cat then
					left[cat] = left[cat] - 1
					if left[cat] < 0 then cat = nil end
				end
				add("filter", h, cat)
			end
		end
	end)
	return n
end

-- Create / bring the saved table up to date. Runs once per login, after the
-- block history upgrade (PSS_UpgradeLegacyData) so the log is in its
-- current shape. Safe to run again.
function Stats.Upgrade()
	local db = PourSocialScoreDB
	if type(db) ~= "table" then return end
	local had = type(db.blockStats) == "table"
	local s = store()
	if not had or (tonumber(s.v) or 0) < 1 then
		for _, src in ipairs(Stats.SOURCES) do s[src] = {} end
		seedFromLog(s)
		s.v = 1
	end
	s.v = Stats.VERSION
	Stats.Prune()
end
M.PSS_UpgradeBlockStats = Stats.Upgrade
