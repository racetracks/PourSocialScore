----------------------------------
-- Pour Social Score Variables --
----------------------------------
local addonName, addon 	= ...
local L = addon.L -- localization entries
local V = addon.V -- shared variables
local M = addon.M -- shared methods

V.PSS_Loaded			= false
V.PSS_SyncOK			= false
V.PSS_InSync			= false
V.lastFilterError		= false

-- Startup, saved-variable defaults/upgrades, one-time legacy import and
-- the group warning. Chat, invites, duels and trades are decided in
-- PSS_ChatBlock.lua; the lists live in PSS_PlayerIgnoreList.lua,
-- PSS_GuildIgnoreList.lua and PSS_ChatFilters.lua.
local PSSFRAME			= nil
local gotLoaded			= false
local gotUpdate			= false
local gotEntering		= false
local safeToLoad		= false
local gotGroup          = IsInGroup()
V.groupWarning          = {}

----------------------------------
-- Pour Social Score Functions --
----------------------------------

-- Post-upgrade tidy-up of the block history (every login): lines of players
-- no longer on the Player Ignore List, of guild members in no guild rule
-- (whose rule is gone too) and of chat filters that no longer exist are
-- dropped; rule tags that point at a removed rule are cleared. Block counts
-- are not changed. Returns the number of lines removed.
function M.PSS_TidyBlockHistory()
	local db = PourSocialScoreDB
	local History = M.PSS_History
	if type(db) ~= "table" or not History then return 0 end
	local alive = {}
	if type(db.ignoreList) == "table" and type(db.typeList) == "table" and M.PSS_PlayerHistoryKey then
		local listed = {}
		for i, name in ipairs(db.ignoreList) do
			if (db.typeList[i] or "player") == "player" then
				local k = M.PSS_PlayerHistoryKey(name)
				if k then listed[k] = true end
			end
		end
		alive.p = function(o) return listed[o] == true end
	end
	if type(db.guildData) == "table" and M.PSS_LookupGuildMember then
		local seen = {}
		alive.g = function(o, h)
			local v = seen[o]
			if v == nil then
				v = M.PSS_LookupGuildMember(o:sub(3)) ~= nil
				seen[o] = v
			end
			return v or (h.gk ~= nil and db.guildData[h.gk] ~= nil)
		end
		alive.guild = function(gkey) return db.guildData[gkey] ~= nil end
	end
	if type(db.filterList) == "table" and M.PSS_FilterOwnerKey then
		local keys, ids = {}, {}
		for i = 1, #db.filterList do
			keys[M.PSS_FilterOwnerKey(i)] = true
			local id = db.filterID[i]
			if id and id ~= "" then ids[id] = true end
		end
		alive.f = function(o) return keys[o] == true end
		alive.rule = function(id) return ids[id] == true end
	end
	return History.Tidy(alive)
end

local function ApplicationStartup(self)

	if V.PSS_Loaded == true or safeToLoad == false then
		return
	end

	M.ShowMsg(L["LOAD_1"])

	V.faction = UnitFactionGroup("player")

	if PourSocialScoreDB == nil then	
		M.PSS_ResetIgnoreDB()
	end

	-- Ensure all core list fields exist before any UI or upgrade code uses #field.
	PourSocialScoreDB.ignoreList = PourSocialScoreDB.ignoreList or {}
	PourSocialScoreDB.factionList = PourSocialScoreDB.factionList or {}
	PourSocialScoreDB.dateList = PourSocialScoreDB.dateList or {}
	PourSocialScoreDB.notes = PourSocialScoreDB.notes or {}
	PourSocialScoreDB.expList = PourSocialScoreDB.expList or {}
	PourSocialScoreDB.typeList = PourSocialScoreDB.typeList or {}
	PourSocialScoreDB.delList = PourSocialScoreDB.delList or {}
	PourSocialScoreDB.syncInfo = PourSocialScoreDB.syncInfo or {}
	PourSocialScoreDB.playerData = PourSocialScoreDB.playerData or {}
	PourSocialScoreDB.guildData = PourSocialScoreDB.guildData or {}
	if PourSocialScoreDB.imported == nil then PourSocialScoreDB.imported = false end

	-- set missing defaults or upgrade if needed

	if PourSocialScoreDB.showIgnoreDebug == nil then
		PourSocialScoreDB.showIgnoreDebug = false
	end

	if PourSocialScoreDB.filterTotal == nil then
		PourSocialScoreDB.filterTotal = 0
	end

	-- (autoIgnore / autoUpdate / autoCount / autoTime / attachFriends were
	-- never used; they are dropped from saved settings.)
	PourSocialScoreDB.autoIgnore, PourSocialScoreDB.autoUpdate = nil, nil
	PourSocialScoreDB.autoCount, PourSocialScoreDB.autoTime = nil, nil
	PourSocialScoreDB.attachFriends = nil

	if PourSocialScoreDB.filterList == nil or PourSocialScoreDB.filterDesc == nil or PourSocialScoreDB.filterCount == nil then
		M.ResetSpamFilters()
	end

	if PourSocialScoreDB.delList == nil then
		PourSocialScoreDB.delList = {}
	end

	-- Every option in the Options tab (defaults live in PSS_Options.lua)
	M.PSS_ApplyOptionDefaults()
	if not tonumber(PourSocialScoreDB.defexpire) then
		PourSocialScoreDB.defexpire = 0
	end

	if PourSocialScoreDB.expList == nil then
		PourSocialScoreDB.expList = {}

		for  count = 1, #PourSocialScoreDB.ignoreList do
			PourSocialScoreDB.expList[count] = 0
		end
	end

	if PourSocialScoreDB.syncList then
		PourSocialScoreDB.syncList = nil
	end

	if PourSocialScoreDB.syncInfo == nil then
		PourSocialScoreDB.syncInfo = {}

		for count = 1, #PourSocialScoreDB.ignoreList do
			PourSocialScoreDB.syncInfo[count] = {}
		end
	end

	if PourSocialScoreDB.typeList == nil then
		PourSocialScoreDB.typeList = {}

		for count = 1, #PourSocialScoreDB.ignoreList do
			PourSocialScoreDB.typeList[count] = "player"
		end
	end

	if PourSocialScoreDB.revision == nil then
		PourSocialScoreDB.revision = 1

		for count = 1, #PourSocialScoreDB.ignoreList do
			PourSocialScoreDB.ignoreList[count] = M.Proper(PourSocialScoreDB.ignoreList[count])
		end
	end

	if PourSocialScoreDB.filterActive == nil then
		PourSocialScoreDB.filterActive = {}

		for count = 1, #PourSocialScoreDB.filterDesc do
			PourSocialScoreDB.filterActive[count] = true
		end
	end

	if PourSocialScoreDB.filterID == nil then
		M.PSS_AssignLegacyFilterIDs()
	end

	-- Erase some old alpha data that could be out there
	if PourSocialScoreDB.filterHistory ~= nil then
		PourSocialScoreDB.filterHistory = nil
	end

	if PourSocialScoreDB.filterBlocked == nil then
		PourSocialScoreDB.filterBlocked = {}

		for count = 1, #PourSocialScoreDB.filterDesc do
			PourSocialScoreDB.filterBlocked[count] = {}
		end		
	end

	if PourSocialScoreDB.filterBlockedLast == nil then
		PourSocialScoreDB.filterBlockedLast = {}

		for count = 1, #PourSocialScoreDB.filterDesc do
			PourSocialScoreDB.filterBlockedLast[count] = 0
		end
	end

	PourSocialScoreDB.filterWhisperTotal = tonumber(PourSocialScoreDB.filterWhisperTotal) or 0
	PourSocialScoreDB.filterPrivateTotal = tonumber(PourSocialScoreDB.filterPrivateTotal) or 0

	-- Built-in rules come from code; SavedVariables only hold their on/off state.
	M.PSS_ExpandFilters()

	V.PSS_LoadedTime = GetTime()

	--M.SyncIgnoreList(PourSocialScoreDB.chatmsg == false)

	V.PSS_Loaded = true

	-- Player/guild data upgrade (guild module), now that the core lists exist.
	if M.PSS_UpgradeLegacyData then M.PSS_UpgradeLegacyData() end
	-- session / last 24 hours block counts (created on first login, PSS_BlockStats.lua)
	if M.PSS_UpgradeBlockStats then M.PSS_UpgradeBlockStats() end
	-- then tidy the block history (lines of things that are gone)
	local tidied = M.PSS_TidyBlockHistory()
	if tidied > 0 and M.PSS_RequestGC then M.PSS_RequestGC("history tidied") end

	M.PSS_HookFunctions()

	self:UnregisterEvent("IGNORELIST_UPDATE")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("ADDON_LOADED")

	-- (The old "auto-update default chat filters" pass is gone: built-in rules
	-- are rebuilt from code on every load by M.PSS_ExpandFilters.)
end

-------------------
-- EVENT HANDLER --
-------------------

-- One-time import from a previous build's saved variables. PourSocialScore
-- uses its own SavedVariables (PourSocialScoreDB), so nothing is shared with
-- older builds. If an older build is enabled for one login alongside this one
-- (it loads first via OptionalDeps), its data is copied in here once.
-- Newest first. Names are split so the rebrand never rewrites them.
local LEGACY_DB_NAMES = {
	{ var = "Poor" .. "SocialScoreDB" },
	{ var = "Global" .. "IgnoreDB" },
}

local function deepCopy(v, seen)
	if type(v) ~= "table" then return v end
	seen = seen or {}
	if seen[v] then return seen[v] end
	local t = {}
	seen[v] = t
	for k, val in pairs(v) do t[deepCopy(k, seen)] = deepCopy(val, seen) end
	return t
end

function M.PSS_ImportLegacyDB()
	if PourSocialScoreDB ~= nil then return false end
	local old, from
	for _, src in ipairs(LEGACY_DB_NAMES) do
		if type(_G[src.var]) == "table" then old, from = _G[src.var], src break end
	end
	if not old then return false end
	PourSocialScoreDB = deepCopy(old)
	-- default chat filter IDs were renamed GILnnnn -> PSSnnnn
	if type(PourSocialScoreDB.filterID) == "table" then
		for i, id in ipairs(PourSocialScoreDB.filterID) do
			if type(id) == "string" then PourSocialScoreDB.filterID[i] = (id:gsub("^G" .. "IL", "PSS")) end
		end
	end
	PourSocialScoreDB.importedLegacyAt = date("%Y-%m-%d %H:%M:%S")
	PourSocialScoreDB.importedFrom = from.var
	-- (the source's old name is recorded in importedFrom, not shown)
	M.ShowMsg("Imported your ignore list, chat filters and guild rules from your previous version of this addon. You can now disable the old one.")
	return true
end

-- Warn about listed players in the group (once per player per group).
local rosterCheckQueued, rosterCheckDeferred = false, false
local function CheckGroupForIgnored()
	rosterCheckQueued = false
	if not IsInGroup() or not PourSocialScoreDB then return end
	if InCombatLockdown and InCombatLockdown() then rosterCheckDeferred = true return end
	gotGroup = true
	local prefix  = IsInRaid() and "raid" or "party"
	local doWarn  = false
	for count = 1, GetNumGroupMembers() do
		local name = GetUnitName(prefix..count, true)
		-- O(1) list lookup on the raw name; the display name is only built
		-- for a player who is actually listed
		if type(name) == "string" and not M.PSS_IsSecret(name) and name ~= "" and M.PSS_IsPlayerListed(name) then
			name = M.Proper(M.addServer(name))
			if M.hasGroupWarning(name) == 0 then
				doWarn = true
				V.groupWarning[#V.groupWarning + 1] = name
			end
		end
	end
	if doWarn then
		M.ShowMsg(format(L["CHAT_1"], #V.groupWarning, table.concat(V.groupWarning, "\n")))
		StaticPopup_Show("PSS_PARTYWARN", #V.groupWarning, "\n" .. table.concat(V.groupWarning, "\n"))
	end
end

local function EventHandler (self, event, sender, ...)

	--print ("DEBUG event=".. (event or "nil") .. " sender=" .. (sender or "nil"))

	--if (event == "CHANNEL_INVITE_REQUEST") then
	--	print ("DEBUG RECEIVED CHANNEL INVITE REQUEST")
	--end

	if event == "PLAYER_LOGOUT" then
		-- Fires on logout and /reload, before SavedVariables are written.
		M.PSS_CollapseFilters()
		-- managed guild lists: write only the delta
		if M.PSS_FlushManaged then pcall(M.PSS_FlushManaged) end
		return
	end

	if (event == "ADDON_LOADED") and (sender == "PourSocialScore") then
		M.PSS_ImportLegacyDB()
		gotLoaded = true
	end

	if event == "IGNORELIST_UPDATE" then
		gotUpdate = true
	end

	if event == "PLAYER_ENTERING_WORLD" then
		gotEntering = true
	end

	if event == "GROUP_ROSTER_UPDATE" then
		-- Raids fire this many times in a row: check once, 1 s after the
		-- last one, and never while in combat (checked when combat ends).
		if not IsInGroup() then
			gotGroup       = false
			V.groupWarning = {}
		elseif V.PSS_Loaded and PourSocialScoreDB and not rosterCheckQueued then
			rosterCheckQueued = true
			C_Timer.After(1, CheckGroupForIgnored)
		end
	end
	if event == "PLAYER_REGEN_ENABLED" and rosterCheckDeferred then
		rosterCheckDeferred = false
		CheckGroupForIgnored()
	end

	-- Party/guild invites, duels and trades: handled by PSS_ChatBlock.lua

	if gotLoaded == true and gotEntering == true then
		safeToLoad = true
	end	

	if safeToLoad == true then
		ApplicationStartup(self)
	end
end

-----------------------------
-- Pour Social Score Main --
-----------------------------

PSSFRAME = CreateFrame("FRAME")

PSSFRAME:RegisterEvent("PLAYER_ENTERING_WORLD")
PSSFRAME:RegisterEvent("ADDON_LOADED")
PSSFRAME:RegisterEvent("IGNORELIST_UPDATE")
PSSFRAME:RegisterEvent("GROUP_ROSTER_UPDATE")
PSSFRAME:RegisterEvent("PLAYER_LOGOUT")
PSSFRAME:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_PSS1		= "/pss"

PSSFRAME:SetScript("OnEvent", EventHandler)

-------------
-- THE END --
-------------
