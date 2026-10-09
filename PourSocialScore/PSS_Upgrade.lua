-----------------------------------
-- Pour Social Score Upgrade Steps --
-----------------------------------
local addonName, addon	= ...
local M = addon.M -- shared methods
local L = addon.L -- localization entries
local V = addon.V -- runtime state

-- Saved data upgrades as numbered steps (the Questie model):
--   * STEPS[1..N] run first to last; each has its id (its place, the number
--     recorded) and its parts. Append new steps at the end; never reorder,
--     renumber or change a step once it has been released.
--   * PourSocialScoreDB.upgrade = { step = N, version = "3.0.0", at = time }
--     records how many steps this save has had, the addon version that last
--     upgraded it and when (server time). Older versions ignore it.
--   * At login a step runs when the save has not had it yet. A step marked
--     "always" also runs at every login: step 1 is the 2.0 login pass (its
--     one-time conversions are guarded by a nil check or a format marker).
--   * Every step must be safe to run twice.
-- A step's parts run in the order listed (step 1's order is 2.0's). A part
-- has a feature (FEATURES, the upgrade report's groups) and up to two
-- functions: "fields" runs before the built-in chat filters are rebuilt from
-- code (M.PSS_ExpandFilters), "data" after it. A function returning false
-- pauses its step and every later one for this login (not recorded).
-- Keys nothing reads any more are named once in RETIRED and dropped at every
-- login, after the data parts (a step may still read one first).

local db	-- PourSocialScoreDB while a pass runs
local blocked	-- first step whose part returned false this login (not recorded)
local out	-- counts per feature, only on a login that reports (see tally)

-- The report's groups, in print order (U2 prints them).
local FEATURES = { "filters", "players", "guilds", "managed", "history", "options", "cleanup" }
M.PSS_UPGRADE_FEATURES = FEATURES

-- Adds n to out[feature][key]. Nothing is counted (or built) on a login
-- that does not report.
local function tally(feature, key, n)
	if not out or not n or n == 0 then return end
	local f = out[feature]
	if not f then
		f = {}
		out[feature] = f
	end
	f[key] = (f[key] or 0) + n
end

-- Keys nothing reads any more, dropped at every login (step 1 dropped the
-- first seven, steps 1, 5, 7 and 8 the rest, each in its own place). Only
-- keys named here are ever deleted, so a newer version's fields are kept.
local RETIRED = {
	"autoIgnore", "autoUpdate", "autoCount", "autoTime", "attachFriends",	-- never used (2.0)
	"syncList", "filterHistory",	-- 2.0 alpha data
	"blockStats",		-- the hourly session / 24 hour counts (3.3.0-dev002: History.Recent*)
	"optionsV2012", "charOptions",	-- 2.0.12 marker, per-character overrides (step 5)
	"historySize",		-- never read (historyTotal is the setting)
	"euiIntegration", "windowSizes", "columnWidths",	-- the old windows (3.4.0.25, step 7)
	"blizzardSync",		-- a per-player tick from 3.4.1.35 (step 8 reads it first)
}
M.PSS_UPGRADE_RETIRED = RETIRED

local function dropRetired()
	for i = 1, #RETIRED do
		local k = RETIRED[i]
		if db[k] ~= nil then
			db[k] = nil
			tally("cleanup", "retired", 1)
		end
	end
end

-- a parallel list of n entries: each one value, or each a new table
local function fill(n, value)
	local t = {}
	for i = 1, n do t[i] = value end
	return t
end

local function fillTables(n)
	local t = {}
	for i = 1, n do t[i] = {} end
	return t
end

local STEPS = {
	-- 1: everything 2.0 did at login, split by feature.
	{
		id = 1,
		always = true,
		parts = {
			{
				feature = "options",
				fields = function()
					if db.showIgnoreDebug == nil then
						db.showIgnoreDebug = false
					end
				end,
			},
			{
				feature = "players",
				fields = function()
					local n = #db.ignoreList
					if db.delList == nil then
						db.delList = {}
						tally("players", "lists", 1)
					end
					if db.expList == nil then
						db.expList = fill(n, 0)
						tally("players", "lists", 1)
					end
					if db.syncInfo == nil then
						db.syncInfo = fillTables(n)
						tally("players", "lists", 1)
					end
					if db.typeList == nil then
						db.typeList = fill(n, "player")
						tally("players", "lists", 1)
					end
					if db.revision == nil then
						db.revision = 1
						for count = 1, n do
							db.ignoreList[count] = M.Proper(db.ignoreList[count])
						end
						tally("players", "renamed", n)
					end
				end,
			},
			{
				feature = "filters",
				fields = function()
					if db.filterTotal == nil then
						db.filterTotal = 0
					end

					if db.filterList == nil or db.filterDesc == nil or db.filterCount == nil then
						M.ResetSpamFilters()
						tally("filters", "reset", 1)
					end

					local n = #db.filterDesc
					if db.filterActive == nil then
						db.filterActive = fill(n, true)
						tally("filters", "lists", 1)
					end

					if db.filterID == nil then
						M.PSS_AssignLegacyFilterIDs()
						tally("filters", "ids", n)
					end

					if db.filterBlocked == nil then
						db.filterBlocked = fillTables(n)
						tally("filters", "lists", 1)
					end

					if db.filterBlockedLast == nil then
						db.filterBlockedLast = fill(n, 0)
						tally("filters", "lists", 1)
					end

					db.filterWhisperTotal = tonumber(db.filterWhisperTotal) or 0
					db.filterPrivateTotal = tonumber(db.filterPrivateTotal) or 0
				end,
			},
			{
				-- player records, guild rules and members, shipped rules and
				-- the block history format (guild module), now that the core
				-- lists exist; it counts into each feature itself
				feature = "guilds",
				data = function()
					if M.PSS_UpgradeLegacyData then M.PSS_UpgradeLegacyData(tally) end
				end,
			},
			{
				feature = "filters",
				data = function()
					-- guild rule blocks are guild blocks only (2.0.39): undo the second count
					if M.PSS_UnlinkGuildRuleCounts then tally("filters", "unlinked", M.PSS_UnlinkGuildRuleCounts()) end
				end,
			},
			{
				feature = "players",
				data = function()
					-- records of players no longer listed, and fields records no longer keep
					if M.PSS_TidyPlayerData then tally("players", "tidied", M.PSS_TidyPlayerData()) end
				end,
			},
			{
				feature = "history",
				data = function()
					-- then tidy the block history (lines of things that are gone); not
					-- loaded yet: done when PourSocialScore_Logging loads
					if M.PSS_LoggingReady and M.PSS_LoggingReady() then
						local tidied = M.PSS_TidyBlockHistory()
						tally("history", "tidied", tidied)
						if tidied > 0 and M.PSS_RequestGC then M.PSS_RequestGC("history tidied") end
					end
				end,
			},
		},
	},
	-- 2: options, players, guilds and rules live in PourSocialScore_Options.
	-- The move itself runs before any other startup code reads the data
	-- (M.PSS_PrepareSavedData, PSS_SavedData.lua); this records it, and
	-- returns false (step not recorded) when it did not happen.
	{
		id = 2,
		parts = {
			{ feature = "options", fields = function() return M.PSS_SavedDataSplit("PourSocialScore_Options") end },
		},
	},
	-- 3: the block history, kept lines, hourly stats, totals and chat rule
	-- counts live in PourSocialScore_Logging (moved the same way)
	{
		id = 3,
		parts = {
			{ feature = "history", fields = function() return M.PSS_SavedDataSplit("PourSocialScore_Logging") end },
		},
	},
	-- 4: PourSocialScore_Logging loads on demand: the counts and format
	-- markers live in PSS_CountsDB (PourSocialScore_Options) and only the
	-- lines in PSS_LoggingDB. M.PSS_PrepareSavedData moves them at login.
	{
		id = 4,
		parts = {
			{ feature = "options", fields = function() return M.PSS_SavedDataSplit("PourSocialScore_Options") end },
		},
	},
	-- 5: minimal settings. Options equal to their default are not saved
	-- (M.PSS_ApplyOptionDefaults drops them at every login). A 2.0 save from
	-- before 2.0.12 (no optionsV2012) gets the 2.0.12 switch-off of
	-- ignoreResponse and blizzardSync, as 2.0 did at login. (optionsV2012,
	-- charOptions and historySize are in RETIRED.)
	{
		id = 5,
		parts = {
			{
				feature = "options",
				fields = function()
					if type(db.upgrade) ~= "table" and not db.optionsV2012 then
						if db.ignoreResponse ~= nil or db.blizzardSync ~= nil then tally("options", "switchedOff", 1) end
						db.ignoreResponse, db.blizzardSync = nil, nil
					end
				end,
			},
		},
	},
	-- 6 (3.4.0.22): decline messages are Off by default for listed players
	-- and guilds (Dan). Show declines was On by default, so a saved On is
	-- a leftover (2.0 saved every option), never a choice: drop it.
	{
		id = 6,
		parts = {
			{
				feature = "players",
				fields = function()
					if db.showDeclines == true then
						db.showDeclines = nil
						tally("players", "declines", 1)
					end
				end,
			},
		},
	},
	-- 7 (3.4.0.25, D2): one window. The old window's places are gone (the
	-- new window keeps only its own place and tab in windowPoints; the EUI
	-- option, sizes and widths are in RETIRED). Says once if a folder the
	-- window no longer uses is still in the AddOns folder.
	{
		id = 7,
		parts = {
			{
				feature = "options",
				fields = function()
					local points = db.windowPoints
					if type(points) == "table" then
						for key in pairs(points) do
							if key ~= "PSS_Window" and key ~= "PSS_WindowTab" then
								points[key] = nil
								tally("options", "places", 1)
							end
						end
						if next(points) == nil then db.windowPoints = nil end
					end
				end,
			},
			{
				feature = "cleanup",
				data = function()
					local exists = C_AddOns and C_AddOns.DoesAddOnExist
					if not exists then return end
					local left = {}
					for _, name in ipairs({ "PourSocialScore_EllesmereUI", "PourSocialScore_UI" }) do
						if exists(name) then left[#left + 1] = name end
					end
					if #left > 0 then
						M.ShowMsg(L["OLD_FOLDERS"]:format(table.concat(left, ", ")))
						tally("cleanup", "oldFolders", #left)
					end
				end,
			},
		},
	},
	-- 8 (3.4.1.35, B1): "Also put listed players on Blizzard's ignore list"
	-- is a tick for each player now (PSS is authoritative). A save with the
	-- global option on ticks every listed player Blizzard's list has, then
	-- the global key goes (RETIRED). Blizzard's list may not have arrived
	-- yet at login, so the first list update ticks again (V.PSS_TickOnSync).
	{
		id = 8,
		parts = {
			{
				feature = "players",
				data = function()
					if db.blizzardSync == true then
						if M.PSS_TickBlizzardIgnored then M.PSS_TickBlizzardIgnored() end
						V.PSS_TickOnSync = true
						tally("players", "blizzardTicks", 1)
					end
				end,
			},
		},
	},
}

M.PSS_UPGRADE_STEPS = #STEPS
M.PSS_UPGRADE_REGISTRY = STEPS	-- read only (the harness checks its shape)

local function addonVersion()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local v = get and get(addonName, "Version")
	return type(v) == "string" and v or "?"
end

-- Steps this save has had (0 for any 2.0 save).
local function stepsDone()
	local rec = type(PourSocialScoreDB) == "table" and PourSocialScoreDB.upgrade
	return type(rec) == "table" and tonumber(rec.step) or 0
end

-- Orders two versions: -1 when a is older than b, 0 the same, 1 newer; nil
-- when either is not a version. X.Y.Z.B orders by its numbers (build
-- numbers never reset); any older name (2.0.44, 3.3.1, 3.4.0-dev008_4) is
-- older than every X.Y.Z.B, and among them X.Y.Z-devN is older than X.Y.Z.
local function numbers(v)
	local t = {}
	for d in v:gmatch("%d+") do t[#t + 1] = tonumber(d) end
	return t
end

local function compareLists(a, b, n)
	for i = 1, n do
		local x, y = a[i] or 0, b[i] or 0
		if x ~= y then return x < y and -1 or 1 end
	end
	return 0
end

function M.PSS_VersionOrder(a, b)
	if type(a) ~= "string" or type(b) ~= "string" then return nil end
	if not a:match("^%d+%.%d+") or not b:match("^%d+%.%d+") then return nil end
	if a == b then return 0 end
	local fa = a:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
	local fb = b:match("^%d+%.%d+%.%d+%.%d+$") ~= nil
	local na, nb = numbers(a), numbers(b)
	if fa and fb then return compareLists(na, nb, 4) end
	if fa ~= fb then return fa and 1 or -1 end
	local o = compareLists(na, nb, 3)
	if o ~= 0 then return o end
	local devA, devB = a:find("dev", 1, true) ~= nil, b:find("dev", 1, true) ~= nil
	if devA ~= devB then return devA and -1 or 1 end
	return compareLists(na, nb, math.max(#na, #nb))
end

local function runPart(part)
	db = PourSocialScoreDB
	if type(db) ~= "table" then return end
	local done = stepsDone()
	for i = 1, #STEPS do
		local step = STEPS[i]
		if blocked and i >= blocked then break end
		if i > done or step.always then
			local parts = step.parts
			for j = 1, #parts do
				local f = parts[j][part]
				if f and f() == false then
					blocked = i
					break
				end
			end
		end
	end
	db = nil
end

-- The "fields" parts. fresh: a new save built this login (nothing to
-- report); defaults: options M.PSS_ApplyOptionDefaults dropped just before.
-- A login reports when the save is not new and a step is due or the
-- version changed; only then are the counts kept (out).
function M.PSS_RunUpgradeFields(fresh, defaults)
	local sv = PourSocialScoreDB
	out = nil
	if not fresh and type(sv) == "table" then
		local rec = type(sv.upgrade) == "table" and sv.upgrade or nil
		local from = rec and rec.version
		if stepsDone() < #STEPS or from ~= addonVersion() then
			out = { from = type(from) == "string" and from or nil, done = stepsDone() }
			tally("cleanup", "defaults", defaults)
		end
	end
	runPart("fields")
end

-- The "data" parts, the retired keys, then the record. fresh: a new save
-- built this login (nothing to report). Returns the counts of a login that
-- reports (out: from, to, done, step, and a table per feature), else nil.
function M.PSS_RunUpgradeData(fresh)
	runPart("data")
	local sv = PourSocialScoreDB
	if type(sv) ~= "table" then
		out = nil
		return
	end
	db = sv
	dropRetired()
	db = nil
	local done = stepsDone()
	local reached = blocked and blocked - 1 or #STEPS
	local paused = blocked
	blocked = nil
	local rec = type(sv.upgrade) == "table" and sv.upgrade or {}
	sv.upgrade = rec
	local version = addonVersion()
	if done < reached or rec.version ~= version then
		rec.step = math.max(done, reached)
		rec.version = version
		rec.at = (GetServerTime and GetServerTime()) or time()
	end
	if done < reached and not fresh then
		M.ShowMsg(("Saved data upgraded to %s (step %d)."):format(version, reached))
	end
	local counts = out
	out = nil
	if counts then
		counts.to, counts.step, counts.paused = version, math.max(done, reached), paused
	end
	return counts
end

-- For /pss mem: "step 1, version 3.0.0-dev4, 04 Oct 2026 07:40".
function M.PSS_UpgradeText()
	local rec = type(PourSocialScoreDB) == "table" and PourSocialScoreDB.upgrade
	if type(rec) ~= "table" then return "none yet" end
	local at = tonumber(rec.at)
	return ("step %s of %d, version %s, %s"):format(tostring(rec.step), #STEPS, tostring(rec.version),
		at and date("%d %b %Y %H:%M", at) or "time unknown")
end

------------------------------------------------------------------------
-- VALIDATION REPORT
--
-- M.PSS_Validate() counts and type-checks every saved data set without
-- changing anything. report.n holds the numbers (the same keys before and
-- after a moving step, so they can be compared), report.problems lists
-- anything malformed. /pss check prints it.
------------------------------------------------------------------------
local LIST_ARRAYS = { "typeList", "notes", "expList", "dateList", "factionList", "syncInfo" }
local FILTER_ARRAYS = { "filterList", "filterDesc", "filterActive", "filterID", "filterCount", "filterBlocked", "filterBlockedLast" }

local function size(t)
	local n = 0
	if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
	return n
end

function M.PSS_Validate()
	local sv = PourSocialScoreDB
	local n, problems = {}, {}
	local report = { n = n, problems = problems }
	local function problem(fmt, ...) problems[#problems + 1] = fmt:format(...) end
	if type(sv) ~= "table" then problem("no saved data") return report end
	local cats = (M.PSS_History and M.PSS_History.ALL_CATS) or {}

	-- the type of every table the rest of the report reads
	for _, k in ipairs({ "ignoreList", "typeList", "notes", "expList", "dateList", "factionList", "syncInfo",
			"delList", "playerData", "guildData", "guildExclusions", "blockLog", "blockKeep", "blockStats",
			"builtinRules", "builtinStats", "upgrade" }) do
		if sv[k] ~= nil and type(sv[k]) ~= "table" then problem("%s is a %s, not a table", k, type(sv[k])) end
	end
	local function tbl(k) return type(sv[k]) == "table" and sv[k] or {} end

	-- Player Ignore List: entries per type, parallel lists, notes, records
	local list, types = tbl("ignoreList"), tbl("typeList")
	n.list = #list
	n.listPlayer, n.listNpc, n.listServer, n.listOther = 0, 0, 0, 0
	local seen, dupes = {}, 0
	for i = 1, #list do
		local name, kind = list[i], types[i] or "player"
		if type(name) ~= "string" or name == "" then problem("list entry %d has no name", i) end
		if kind == "player" then n.listPlayer = n.listPlayer + 1
		elseif kind == "npc" then n.listNpc = n.listNpc + 1
		elseif kind == "server" then n.listServer = n.listServer + 1
		else n.listOther = n.listOther + 1 end
		local key = kind .. ":" .. tostring(name):lower()
		if seen[key] then dupes = dupes + 1 end
		seen[key] = true
	end
	n.listDuplicates = dupes
	if dupes > 0 then problem("%d duplicate entries on the Player Ignore List", dupes) end
	for _, k in ipairs(LIST_ARRAYS) do
		for i in pairs(tbl(k)) do
			if type(i) ~= "number" or i < 1 or i > #list or i % 1 ~= 0 then
				problem("%s has an entry (%s) beyond the list's %d entries", k, tostring(i), #list)
				break
			end
		end
	end
	local notes = 0
	for i = 1, #list do
		local note = tbl("notes")[i]
		if type(note) == "string" and note ~= "" then notes = notes + 1 end
	end
	n.listNotes = notes
	n.playerRecords = size(sv.playerData)
	n.deleted = #tbl("delList")

	-- Guild Ignore List: rules, members, member notes, exclusions
	n.guildRules, n.guildRulesShipped, n.membersStored, n.membersShown, n.memberNotes = 0, 0, 0, 0, 0
	n.leftMarks = 0		-- shipped members marked "left this guild"
	for gkey, g in pairs(tbl("guildData")) do
		if type(g) ~= "table" then
			problem("guild rule %s is not a table", tostring(gkey))
		else
			n.guildRules = n.guildRules + 1
			if g.managed then n.guildRulesShipped = n.guildRulesShipped + 1 end
			n.leftMarks = n.leftMarks + size(g.managedGone)
			if g.members ~= nil and type(g.members) ~= "table" then problem("guild rule %s: members is not a table", tostring(gkey)) end
			for key, m in pairs(type(g.members) == "table" and g.members or {}) do
				n.membersStored = n.membersStored + 1
				if type(m) ~= "table" then
					problem("guild rule %s: member %s is not a table", tostring(gkey), tostring(key))
				elseif type(m.note) == "string" and m.note ~= "" then
					n.memberNotes = n.memberNotes + 1
				end
			end
			n.membersShown = n.membersShown + (M.PSS_GuildMemberCount and M.PSS_GuildMemberCount(g, gkey) or size(g.members))
		end
	end
	n.guildExclusions = size(sv.guildExclusions)

	-- Chat Filters (in memory the built-in rules sit in the same arrays)
	local flist = tbl("filterList")
	n.filters = #flist
	for _, k in ipairs(FILTER_ARRAYS) do
		if sv[k] ~= nil and #tbl(k) ~= #flist then problem("%s has %d entries, filterList has %d", k, #tbl(k), #flist) end
	end
	n.filtersCustom, n.filtersBuiltinOn, n.filtersCustomOn = 0, 0, 0
	local ids = {}
	for i = 1, #flist do
		local id = tbl("filterID")[i]
		local on = tbl("filterActive")[i] == true
		if type(id) == "string" and id ~= "" then
			if ids[id] then problem("chat filter ID %s is used twice", id) end
			ids[id] = true
			if on then n.filtersBuiltinOn = n.filtersBuiltinOn + 1 end
		else
			n.filtersCustom = n.filtersCustom + 1
			if on then n.filtersCustomOn = n.filtersCustomOn + 1 end
		end
		if type(flist[i]) ~= "string" then problem("chat filter %d has no text", i) end
	end

	-- block history: log lines and lines kept per person
	n.logLines = #tbl("blockLog")
	n.keptLines, n.keptPeople = 0, 0
	-- the saved log of 3.2.0-dev007: one group per person, kept lines first
	if tbl("blockLog").v == 2 then
		for o, g in pairs(tbl("blockLog")) do
			if type(g) == "table" then
				local k = tonumber(g.k) or 0
				n.logLines = n.logLines + #g - k
				if k > 0 then n.keptLines, n.keptPeople = n.keptLines + k, n.keptPeople + 1 end
			elseif o ~= "v" then
				problem("saved log lines of %s are not a table", tostring(o))
			end
		end
	end
	for o, l in pairs(tbl("blockKeep")) do
		if type(l) ~= "table" then
			problem("kept lines of %s are not a table", tostring(o))
		else
			n.keptLines = n.keptLines + #l
			n.keptPeople = n.keptPeople + 1
		end
	end

	-- block counts: the sum of every counter per source and category
	local function addCounts(prefix, c)
		if type(c) ~= "table" then return end
		n[prefix .. "Total"] = (n[prefix .. "Total"] or 0) + (tonumber(c.total) or 0)
		for _, cat in ipairs(cats) do
			n[prefix .. "." .. cat] = (n[prefix .. "." .. cat] or 0) + (tonumber(c[cat]) or 0)
		end
	end
	n.playerCountsTotal, n.memberCountsTotal, n.filterCountsTotal = 0, 0, 0
	for _, p in pairs(tbl("playerData")) do if type(p) == "table" then addCounts("playerCounts", p.blockCounts) end end
	for _, g in pairs(tbl("guildData")) do
		for _, m in pairs(type(g) == "table" and type(g.members) == "table" and g.members or {}) do
			if type(m) == "table" then addCounts("memberCounts", m.blockCounts) end
		end
	end
	for i = 1, #flist do
		local b = tbl("filterBlocked")[i]
		addCounts("filterCounts", type(b) == "table" and b.counts)
	end
	n.filterTotal = tonumber(sv.filterTotal) or 0
	n.filterWhisperTotal = tonumber(sv.filterWhisperTotal) or 0
	n.filterPrivateTotal = tonumber(sv.filterPrivateTotal) or 0
	local rowSum = 0
	for i = 1, #flist do rowSum = rowSum + (tonumber(tbl("filterCount")[i]) or 0) end
	n.filterRowCounts = rowSum

	-- options: how many differ from their default (only those are saved
	-- since 3.0)
	n.optionsChanged = 0
	for _, o in ipairs(M.PSS_OPTIONS or {}) do
		if sv[o.key] ~= nil and sv[o.key] ~= o.default then n.optionsChanged = n.optionsChanged + 1 end
	end
	return report
end

-- /pss check
function M.PSS_PrintValidation()
	if M.PSS_LoadLogging then M.PSS_LoadLogging() end
	local r = M.PSS_Validate()
	local n = r.n
	local out = M.ShowMsg
	local function v(k) return tostring(n[k] or 0) end
	out("|cffff99ffSaved data check|r")
	out(("  Player Ignore List: %s entries (%s players, %s NPCs, %s servers%s), %s notes, %s player records, %s on the deleted list"):format(
		v("list"), v("listPlayer"), v("listNpc"), v("listServer"),
		(n.listOther or 0) > 0 and (", " .. v("listOther") .. " other") or "", v("listNotes"), v("playerRecords"), v("deleted")))
	out(("  Guild Ignore List: %s guilds (%s from shipped lists), %s members shown, %s stored, %s member notes, %s excluded guilds, %s shipped members marked as left"):format(
		v("guildRules"), v("guildRulesShipped"), v("membersShown"), v("membersStored"), v("memberNotes"), v("guildExclusions"), v("leftMarks")))
	out(("  Chat Filters: %s rules (%s custom), %s built-in on, %s custom on"):format(
		v("filters"), v("filtersCustom"), v("filtersBuiltinOn"), v("filtersCustomOn")))
	out(("  Block history: %s log lines, %s kept lines for %s people"):format(v("logLines"), v("keptLines"), v("keptPeople")))
	out(("  Block counts: players %s, guild members %s, chat filters %s (tab total %s, whispers %s, Battle.net %s)"):format(
		v("playerCountsTotal"), v("memberCountsTotal"), v("filterRowCounts"), v("filterTotal"), v("filterWhisperTotal"), v("filterPrivateTotal")))
	out(("  Last 24 hours: players %s, guilds %s, filters %s"):format(v("stats24h.player"), v("stats24h.guild"), v("stats24h.filter")))
	out(("  Options: %s changed from default"):format(v("optionsChanged")))
	out("  Upgrade: " .. M.PSS_UpgradeText())
	if #r.problems == 0 then
		out("  |cff33ff33No problems found.|r")
	else
		out(("  |cffff3333%d problem(s):|r"):format(#r.problems))
		for i = 1, math.min(#r.problems, 20) do out("    " .. r.problems[i]) end
		if #r.problems > 20 then out(("    ... and %d more"):format(#r.problems - 20)) end
	end
	return r
end
