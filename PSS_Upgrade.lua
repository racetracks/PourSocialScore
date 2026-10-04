-----------------------------------
-- Pour Social Score Upgrade Steps --
-----------------------------------
local addonName, addon	= ...
local M = addon.M -- shared methods

-- Saved data upgrades as numbered steps (the Questie model):
--   * STEPS[1..N] run first to last. Append new steps at the end; never
--     reorder, renumber or change a step once it has been released.
--   * PourSocialScoreDB.upgrade = { step = N, version = "3.0.0", at = time }
--     records how many steps this save has had, the addon version that last
--     upgraded it and when (server time). Older versions ignore it.
--   * At login a step runs when the save has not had it yet. A step marked
--     "always" also runs at every login: step 1 is the 2.0 login pass, which
--     still mixes one-time conversions with per-login work (index rebuild,
--     log trim, block-count prune, tidy-ups); those are separated when the
--     upgrade code moves out of the core.
--   * Every step must be safe to run twice.
-- A step has up to two parts: "fields" runs before the built-in chat filters
-- are rebuilt from code (M.PSS_ExpandFilters), "data" runs after it.

local db	-- PourSocialScoreDB while a pass runs

local STEPS = {
	-- 1: everything 2.0 did at login, moved here unchanged.
	{
		always = true,
		fields = function()
			if db.showIgnoreDebug == nil then
				db.showIgnoreDebug = false
			end

			if db.filterTotal == nil then
				db.filterTotal = 0
			end

			-- (autoIgnore / autoUpdate / autoCount / autoTime / attachFriends were
			-- never used; they are dropped from saved settings.)
			db.autoIgnore, db.autoUpdate = nil, nil
			db.autoCount, db.autoTime = nil, nil
			db.attachFriends = nil

			if db.filterList == nil or db.filterDesc == nil or db.filterCount == nil then
				M.ResetSpamFilters()
			end

			if db.delList == nil then
				db.delList = {}
			end

			if db.expList == nil then
				db.expList = {}

				for count = 1, #db.ignoreList do
					db.expList[count] = 0
				end
			end

			if db.syncList then
				db.syncList = nil
			end

			if db.syncInfo == nil then
				db.syncInfo = {}

				for count = 1, #db.ignoreList do
					db.syncInfo[count] = {}
				end
			end

			if db.typeList == nil then
				db.typeList = {}

				for count = 1, #db.ignoreList do
					db.typeList[count] = "player"
				end
			end

			if db.revision == nil then
				db.revision = 1

				for count = 1, #db.ignoreList do
					db.ignoreList[count] = M.Proper(db.ignoreList[count])
				end
			end

			if db.filterActive == nil then
				db.filterActive = {}

				for count = 1, #db.filterDesc do
					db.filterActive[count] = true
				end
			end

			if db.filterID == nil then
				M.PSS_AssignLegacyFilterIDs()
			end

			-- Erase some old alpha data that could be out there
			if db.filterHistory ~= nil then
				db.filterHistory = nil
			end

			if db.filterBlocked == nil then
				db.filterBlocked = {}

				for count = 1, #db.filterDesc do
					db.filterBlocked[count] = {}
				end
			end

			if db.filterBlockedLast == nil then
				db.filterBlockedLast = {}

				for count = 1, #db.filterDesc do
					db.filterBlockedLast[count] = 0
				end
			end

			db.filterWhisperTotal = tonumber(db.filterWhisperTotal) or 0
			db.filterPrivateTotal = tonumber(db.filterPrivateTotal) or 0
		end,
		data = function()
			-- Player/guild data upgrade (guild module), now that the core lists exist.
			if M.PSS_UpgradeLegacyData then M.PSS_UpgradeLegacyData() end
			-- guild rule blocks are guild blocks only (2.0.39): undo the second count
			if M.PSS_UnlinkGuildRuleCounts then M.PSS_UnlinkGuildRuleCounts() end
			-- session / last 24 hours block counts (created on first login, PSS_BlockStats.lua)
			if M.PSS_UpgradeBlockStats then M.PSS_UpgradeBlockStats() end
			-- records of players no longer listed, and fields records no longer keep
			if M.PSS_TidyPlayerData then M.PSS_TidyPlayerData() end
			-- then tidy the block history (lines of things that are gone)
			local tidied = M.PSS_TidyBlockHistory()
			if tidied > 0 and M.PSS_RequestGC then M.PSS_RequestGC("history tidied") end
		end,
	},
}

M.PSS_UPGRADE_STEPS = #STEPS

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

local function runPart(part)
	db = PourSocialScoreDB
	if type(db) ~= "table" then return end
	local done = stepsDone()
	for i = 1, #STEPS do
		local step = STEPS[i]
		if step[part] and (i > done or step.always) then step[part]() end
	end
	db = nil
end

function M.PSS_RunUpgradeFields() runPart("fields") end

-- The "data" parts, then the record. fresh: a new save built this login
-- (nothing to report).
function M.PSS_RunUpgradeData(fresh)
	runPart("data")
	local sv = PourSocialScoreDB
	if type(sv) ~= "table" then return end
	local done = stepsDone()
	local rec = type(sv.upgrade) == "table" and sv.upgrade or {}
	sv.upgrade = rec
	local version = addonVersion()
	if done < #STEPS or rec.version ~= version then
		rec.step = math.max(done, #STEPS)
		rec.version = version
		rec.at = (GetServerTime and GetServerTime()) or time()
	end
	if done < #STEPS and not fresh then
		M.ShowMsg(("Saved data upgraded to %s (step %d)."):format(version, #STEPS))
	end
end

-- For /pss mem: "step 1, version 3.0.0-dev4, 04 Oct 2026 07:40".
function M.PSS_UpgradeText()
	local rec = type(PourSocialScoreDB) == "table" and PourSocialScoreDB.upgrade
	if type(rec) ~= "table" then return "none yet" end
	local at = tonumber(rec.at)
	return ("step %s of %d, version %s, %s"):format(tostring(rec.step), #STEPS, tostring(rec.version),
		at and date("%d %b %Y %H:%M", at) or "time unknown")
end
