------------------------------------------------------------
-- POUR SOCIAL SCORE - GUILD IGNORE LIST
--
-- Guild rules, their captured members (scans / invites / units seen),
-- per-member allow flags, block history, the guild tab and members window,
-- and the "guild" person source the core (PSS_ChatBlock.lua) uses.
------------------------------------------------------------

local addonName, addon = ...
local M = addon.M
local V = addon.V
local L = addon.L -- localization entries

local showGuildSearchResults
local Whois = M.Whois	-- /who sending, cooldown and answers (PSS_Whois.lua)

-- Scan / Guild Search buttons are disabled while /who cools down (PSS_UIKit.lua).
local function registerGuildScanButton(button) M.UI.RegisterWhoisButton(button) end

-- the cooldown ending re-enables the row Scan buttons: redraw the list
M.Events.Register("WHOIS_COOLDOWN", function(active)
	if not active and M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end)

local trim				= M.PSS_Trim
local normalizePlayer = M.PSS_NormalizePlayer
local displayPlayer		= M.PSS_DisplayPlayer

local function normalizeGuild(name)
	if type(name) ~= "string" then return nil end
	name = trim(name)
	if name == "" then return nil end
	return name:lower()
end
M.PSS_NormalizeGuild = normalizeGuild

-- A guild row is a match key. Scans send g-"<row name>" to /who, and every
-- result is then checked here against the member's actual guild name. The
-- match is a case-insensitive "contains" on purpose: a row named "Olympus"
-- captures Olympus Tycoons, Olympus III and so on. When a more specific row
-- also exists ("Olympus Tycoons"), PSS_BestGuildRowFor gives the member to
-- that row instead.
local function guildMatches(rowName, actualGuild)
	rowName = normalizeGuild(rowName)
	actualGuild = normalizeGuild(actualGuild)
	if not rowName or not actualGuild then return false end
	return actualGuild:find(rowName, 1, true) ~= nil
end

local canonPlayer = M.PSS_CanonPlayer
local canonGuild	= M.PSS_CanonGuild
local isSecret		= M.PSS_IsSecret
local nowString		= M.PSS_NowString

local function classTokenFromInfo(infoClass)
	if not infoClass then return "" end
	if RAID_CLASS_COLORS and RAID_CLASS_COLORS[infoClass] then return infoClass end
	if LOCALIZED_CLASS_NAMES_MALE then
		for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
			if localized == infoClass then return token end
		end
	end
	if LOCALIZED_CLASS_NAMES_FEMALE then
		for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
			if localized == infoClass then return token end
		end
	end
	return infoClass
end

local function ensureDB()
	PourSocialScoreDB = PourSocialScoreDB or {}
	PourSocialScoreDB.playerData = PourSocialScoreDB.playerData or {}
	PourSocialScoreDB.guildData = PourSocialScoreDB.guildData or {}
	PourSocialScoreDB.imported = PourSocialScoreDB.imported or false
end

-- Forward declaration: PSS_UpgradeLegacyData runs after the file loads, so this
-- must refer to the local cleanup function declared later in this file.
local cleanupLegacyGuildPlayers

-- Capture player/guild metadata from target, mouseover, nameplates and group units.
-- Older builds referenced scanUnit from the event handler but never defined it,
-- which caused the login/mouseover nil-call errors.
-- Each player is looked at no more than once every SEEN_TTL seconds (keyed
-- by GUID), and nothing is done in combat: nameplates and mouseover fire
-- constantly there, and this information can wait. In combat the mouseover
-- and nameplate events are not even listened to (see the frame below).
local SEEN_TTL, SEEN_MAX = 120, 600
local seenGUID, seenCount = {}, 0

local function inCombat()
	if InCombatLockdown and InCombatLockdown() then return true end
	return UnitAffectingCombat ~= nil and UnitAffectingCombat("player") == true
end

local function scanUnit(unit)
	if not unit or not UnitExists or not UnitExists(unit) then return end
	if UnitIsPlayer and not UnitIsPlayer(unit) then return end
	if inCombat() then return end
	local guid = UnitGUID and UnitGUID(unit)
	if type(guid) ~= "string" or isSecret(guid) then return end
	local now = GetTime()
	local last = seenGUID[guid]
	if last and now - last < SEEN_TTL then return end
	if not last then
		seenCount = seenCount + 1
		if seenCount > SEEN_MAX then seenGUID, seenCount = {}, 1 end
	end
	seenGUID[guid] = now

	-- In instances the client can hand addons "secret" names; those can't be
	-- compared or stored, so the unit is skipped.
	local name, realm = UnitName(unit)
	if type(name) ~= "string" or isSecret(name) or name == "" then return end
	if realm ~= nil and (type(realm) ~= "string" or isSecret(realm)) then return end

	local fullName = name
	if realm and realm ~= "" and (not GetNormalizedRealmName or realm ~= GetNormalizedRealmName()) then
		fullName = name .. "-" .. realm
	end

	local guild = GetGuildInfo and GetGuildInfo(unit) or ""
	if type(guild) ~= "string" or isSecret(guild) then guild = "" end
	M.PSS_UpdatePlayerUnit(fullName, unit, guild)
end

-- Player-list metadata for listed players (PSS_PlayerIgnoreList.lua)
local function setPlayerMeta(name, unit, guild)
	return M.PSS_SetPlayerMeta and M.PSS_SetPlayerMeta(name, unit, guild)
end

local function memberKey(name)
	return normalizePlayer(name)
end

-- Custom Scan Fields: one free-text /who filter sent with the guild name.
-- Older saves had separate Start/End Level values; carry them over once as
-- "start-end" so the custom scan behaves the same.
function M.PSS_MigrateCustomScan(g)
	if type(g) ~= "table" then return end
	if type(g.customScan) ~= "string" then
		local lo, hi = tonumber(g.levelStart), tonumber(g.levelEnd)
		if not (lo and hi) then
			lo, hi = tostring(g.levelBrackets or ""):match("^(%d+)%s*%-%s*(%d+)$")
			lo, hi = tonumber(lo), tonumber(hi)
		end
		g.customScan = (lo and hi) and ("%d-%d"):format(lo, hi) or M.PSS_DEFAULT_SCAN_FIELDS
	end
	g.levelStart, g.levelEnd, g.levelBrackets = nil, nil, nil
end

------------------------------------------------------------------------
-- W I G P C EXCLUSIONS (per guild rule, optionally per member)
--   W whisper, I partyInvite, G guildInvite, P partyRaid, C world
--   (C = chat channels such as Trade/General/LFG/communities, plus say,
--    yell and emotes).
--    Stored as BLOCKED; the tickboxes show the inverse (ticked = allowed).
-- Guild:  g.block[cat] = true/false
-- Member: m.block[cat] = true/false, or nil = use the guild's setting
-- g.enabled is kept as a derived flag ("this rule blocks something"), which
-- the member index and scan code use.
------------------------------------------------------------------------
-- Scan Fields a new guild rule starts with (sent after g-"Guild" by Custom).
M.PSS_DEFAULT_SCAN_FIELDS = "1-60"

local EXCL_CATS = {}
M.PSS_EXCL_INFO = {}
for _, e in ipairs(M.UI.EXCL) do			-- order and wording: PSS_UIKit.lua
	EXCL_CATS[#EXCL_CATS + 1] = e.cat
	M.PSS_EXCL_INFO[e.cat] = { letter = e.letter, label = e.label }
end
M.PSS_EXCL_CATS = EXCL_CATS

-- The guild's flags; converts the pre-2.0.4 Filter / Guild Inv / Group Inv
-- settings the first time a rule is seen.
local function guildBlock(g)
	if type(g.block) ~= "table" then
		local on = g.enabled ~= false
		g.block = {
			whisper = on,
			partyInvite = on and g.declineGroup ~= false,
			guildInvite = on and g.declineGuild ~= false,
			partyRaid = on and g.partyRaid ~= false,
			world = on,
		}
	end
	for _, c in ipairs(EXCL_CATS) do g.block[c] = g.block[c] == true end
	return g.block
end
M.PSS_GuildBlock = guildBlock

-- The member's own flags (nil entries inherit); converts the old
-- Allow Whispers / Allow Group Invites / Allow Guild Invites / Allow All Chat.
-- Most members never get a choice of their own, so reading one that has no
-- flags returns the shared NO_BLOCK (never written to) instead of storing an
-- empty table on every member. Writers use memberBlockW.
local NO_BLOCK = setmetatable({}, { __newindex = function() error("PSS: write to NO_BLOCK", 2) end })
local function memberBlock(m)
	if type(m.block) == "table" then return m.block end
	if m.excludedWhispers ~= true and m.excludedGroup ~= true and m.excludedGuildInvite ~= true and m.excludedChat ~= true then
		return NO_BLOCK
	end
	local b = {}
	if m.excludedWhispers == true then b.whisper = false end
	if m.excludedGroup == true then b.partyInvite = false end
	if m.excludedGuildInvite == true then b.guildInvite = false end
	if m.excludedChat == true then b.partyRaid = false; b.world = false end
	m.block = b
	m.excludedWhispers, m.excludedGroup, m.excludedGuildInvite, m.excludedChat = nil, nil, nil, nil
	return b
end
M.PSS_MemberBlock = memberBlock

-- the member's own flags, created to be written
local function memberBlockW(m)
	local b = memberBlock(m)
	if b == NO_BLOCK then b = {}; m.block = b end
	return b
end

-- Effective setting for a member (own flag, else the guild's).
local function memberBlocks(g, m, cat)
	local own = memberBlock(m)[cat]
	if own ~= nil then return own == true end
	return guildBlock(g)[cat] == true
end
M.PSS_MemberBlocks = memberBlocks

-- g.enabled = the rule blocks anything for anyone.
local function refreshGuildActive(g)
	if type(g) ~= "table" then return false end
	local any = false
	for _, c in ipairs(EXCL_CATS) do if guildBlock(g)[c] then any = true break end end
	if not any then
		for _, m in pairs(g.members or {}) do
			if type(m) == "table" and type(m.block) == "table" then
				for _, c in ipairs(EXCL_CATS) do if m.block[c] == true then any = true break end end
			end
			if any then break end
		end
	end
	g.enabled = any
	return any
end
M.PSS_RefreshGuildActive = refreshGuildActive

-- Does this guild rule block right now? A guild that belongs to a group with
-- a Chat Filters rule (the shipped influencer lists, and any guild rule group
-- added later) is linked to that rule: with the rule off, none of its guilds
-- block, neither the shipped members nor the ones found in game and stored
-- in SavedVariables (they live on the same guild row, g.managed).
local function guildRuleActive(g)
	if type(g) ~= "table" or not g.enabled then return false end
	if g.managed then return M.PSS_ManagedGroupActive ~= nil and M.PSS_ManagedGroupActive(g.managed) end
	return true
end
M.PSS_GuildRuleActive = guildRuleActive

local function ensureGuild(name)
	ensureDB()
	local key = normalizeGuild(name)
	if not key then return nil end
	local g = PourSocialScoreDB.guildData[key]
	if not g then
		-- Adding a guild opts it IN to blocking: everything from its members
		-- is blocked. The W I G P C boxes are exclusions and start unticked.
		g = {
			name = trim(name),
			enabled = true,
			declineGuild = true,
			declineGroup = true,
			partyRaid = true,
			block = { whisper = true, partyInvite = true, guildInvite = true, partyRaid = true, world = true },
			customScan = M.PSS_DEFAULT_SCAN_FIELDS,
			members = {},
			memberCount = 0,
		}
		PourSocialScoreDB.guildData[key] = g
	else
		g.name = g.name or trim(name)
		if g.enabled == nil then g.enabled = true end
		if g.declineGuild == nil then g.declineGuild = true end
		if g.declineGroup == nil then g.declineGroup = true end
		if g.partyRaid == nil then g.partyRaid = true end
		M.PSS_MigrateCustomScan(g)
		g.scan, g.scanTotal, g.scanBrackets = nil, nil, nil		-- the old Scan n/9 progress
		g.members = g.members or {}
		g.memberCount = tonumber(g.memberCount) or 0
	end
	-- Block history and counters live on the MEMBER records only (see the
	-- GUILD BLOCK RECORDING section), so they travel with a player whenever
	-- that player is moved to another guild rule.
	-- (memberCount is display only; the Guild Ignore List recounts when it
	-- draws. It is no longer recounted here on every call, which made each
	-- scan result / unit seen walk the whole member list.)
	guildBlock(g)
	refreshGuildActive(g)
	return g, key
end

function M.PSS_GetGuild(name)
	return ensureGuild(name)
end

local function findGuildForPlayer(name)
	local key = memberKey(name)
	if not key then return nil end
	for guildKey, g in pairs(PourSocialScoreDB.guildData or {}) do
		if g.members and g.members[key] then return g, guildKey, g.members[key] end
	end
	return nil
end

function M.PSS_UpdatePlayerUnit(name, unit, guild)
	local p = setPlayerMeta(name, unit, guild)
	if guild and guild ~= "" then
		-- IMPORTANT: merely seeing a player in the world must never create a
		-- new Guild Ignore rule.  The old code called PSS_UpdateGuildMember()
		-- here, which calls ensureGuild() and therefore created a guild entry
		-- for every guild encountered while targeting/mousing over/grouping.
		-- This was the source of the random guilds appearing after login.
		-- Only attach the player to an already-existing guild rule.  Guild
		-- scan results and the explicit "Add Guild" action are the only
		-- operations allowed to create/populate Guild Ignore rules.
		local guildKey = normalizeGuild(guild)
		local existing = guildKey and PourSocialScoreDB.guildData and PourSocialScoreDB.guildData[guildKey]
		if existing then
			-- a shipped member of a managed guild: already known, store nothing
			local ck = existing.managed and canonPlayer(name)
			if not (ck and M.PSS_IsManagedStaticMember and M.PSS_IsManagedStaticMember(guildKey, ck)) then
				M.PSS_UpdateGuildMember(guild, name, unit)
			end
		end
	end
	return p
end

function M.PSS_UpdateGuildMember(guildName, playerName, unit)
	local g, gkey = ensureGuild(guildName)
	local pkey = memberKey(playerName)
	if not g or not pkey then return end

	-- A new member stores only what is known about them. Everything else
	-- reads as its default when missing (Allow flags false, no block
	-- choices, no counts, no last invite), so a guild sweep that captures
	-- thousands of players keeps each one small (see compactMember).
	local isNew = g.members[pkey] == nil
	local m = g.members[pkey] or {
		name = displayPlayer(playerName),
		guild = g.name,
		whenBlocked = nowString(),
	}
	m.name = displayPlayer(playerName)
	m.guild = guildName
	if m.excludedGroup == true and m.excludedGuildInvite == nil then m.excludedGuildInvite = true end
	if not m.whenBlocked or m.whenBlocked == "" then m.whenBlocked = nowString() end
	if M.PSS_EnsureMemberBlockData then M.PSS_EnsureMemberBlockData(m) end
	if isNew and M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	if isNew and guildRuleActive(g) then
		local ck = canonPlayer(playerName)
		if ck then
			if M.PSS__purgeBatch then M.PSS__purgeBatch[ck] = true
			elseif M.PSS_PurgeChatFrom then M.PSS_PurgeChatFrom({ [ck] = true }) end
		end
		if M.PSS_PersonIdentified then M.PSS_PersonIdentified(playerName) end
	end
	if unit and UnitExists(unit) then
		local faction = UnitFactionGroup(unit)
		local _, classToken = UnitClass(unit)
		if classToken and not isSecret(classToken) then m.class = classToken end
		if faction and not isSecret(faction) then m.faction = faction end
	end
	g.members[pkey] = m
	if isNew then g.memberCount = (tonumber(g.memberCount) or 0) + 1 end
	return m, g, gkey
end

------------------------------------------------------------------------
-- GUILD BLOCK RECORDING
--
-- Categories tracked for the Guild Ignore List:
--   whisper     : CHAT_MSG_WHISPER / CHAT_MSG_BN_WHISPER (one bucket - they
--                 were previously split into "Whispers" / "Private Messages")
--   partyInvite : party/raid invites (PARTY_INVITE_REQUEST)
--   partyRaid   : party / raid / raid warning / instance chat
--   world       : every other chat type that is not specifically captured
--                 above (channels such as Trade/General/LFG, say, yell, emote)
--   guildInvite : guild invites (GUILD_INVITE_REQUEST)
--
-- Counters are stored on member records:
--   member.blockCounts  = { whisper=, partyInvite=, partyRaid=, world=, guildInvite= }
-- The lines themselves go into the shared block log (PSS_ChatHistory.lua),
-- owned by "g:<character>", so they follow a player who is moved to another
-- guild rule. A guild's history / totals are built from its members.
------------------------------------------------------------------------

-- Entries, categories, counts and the history UI: PSS_ChatHistory.lua
local History = M.PSS_History
local CAT_ORDER, CAT_LABEL, CAT_COLOR = History.CAT_ORDER, History.CAT_LABEL, History.CAT_COLOR
M.PSS_GUILD_BLOCK_CATEGORIES = CAT_ORDER
M.PSS_GUILD_BLOCK_LABELS = CAT_LABEL

-- Event categories and channel labels are shared with the core.
local eventCategory = M.PSS_EventCategory
M.PSS_GuildEventCategory = eventCategory
local channelLabel = M.PSS_ChannelLabel
local parseTimeString = History.ParseTime
local normalizeEntry = History.Normalize

local entrySig = History.Sig

-- Bring a member record to the current block-data format. Older counter
-- fields are folded in once (flag _blockV2). Old per-member history lists
-- are moved into the shared log by the 2.0.17 upgrade.
-- blockCounts is only kept by members that were blocked at least once: a
-- member without it reads as all zero (memberCounts). Pass create = true
-- before writing to it.
local LEGACY_COUNT_FIELDS = { "blockedWhispers", "blockedPrivateMessages", "privateMessagesBlocked", "blockedChatMessages",
								"chatMessagesBlocked", "blockedInvites", "partyInvitesBlocked", "partyRaidMessagesBlocked" }
local function hasLegacyBlockData(m)
	if type(m.blockHistory) == "table" and #m.blockHistory > 0 then return true end
	for _, f in ipairs(LEGACY_COUNT_FIELDS) do
		if m[f] ~= nil then return true end
	end
	return false
end

local function ensureMemberBlockData(m, create)
	if type(m) ~= "table" then return end
	if not m._blockV2 and hasLegacyBlockData(m) then
		m.blockCounts = History.EnsureCounts(m.blockCounts)
		if type(m.blockHistory) == "table" and #m.blockHistory > 0 then
			-- very old saves wrote a line once per chat window: collapse repeats
			local out, prev = {}, nil
			for _, h in ipairs(m.blockHistory) do
				if History.Normalize(h) then
					local sig = History.Sig(h)
					if sig ~= prev then
						h.member = h.member or m.name
						out[#out + 1] = h
						m.blockCounts[h.cat] = (m.blockCounts[h.cat] or 0) + 1
					end
					prev = sig
				end
			end
			m.blockHistory = out
		else
			m.blockCounts.whisper = m.blockCounts.whisper + (tonumber(m.blockedWhispers) or 0)
				+ (tonumber(m.blockedPrivateMessages) or tonumber(m.privateMessagesBlocked) or 0)
			m.blockCounts.partyRaid = m.blockCounts.partyRaid
				+ (tonumber(m.blockedChatMessages) or tonumber(m.chatMessagesBlocked) or 0)
			m.blockCounts.partyInvite = m.blockCounts.partyInvite
				+ (tonumber(m.blockedInvites) or tonumber(m.partyInvitesBlocked) or 0)
		end
		-- Old counter fields are superseded by blockCounts.
		for _, f in ipairs(LEGACY_COUNT_FIELDS) do m[f] = nil end
		m._blockV2 = true
	end
	if create or m.blockCounts ~= nil then m.blockCounts = History.EnsureCounts(m.blockCounts) end
end
M.PSS_EnsureMemberBlockData = ensureMemberBlockData

-- Drop every field a stored member holds at its default, so SavedVariables
-- (and the memory it is loaded into) only carry what is known about them.
-- Before 2.0.29 each member was saved with four Allow flags, an empty block
-- table, a zero blockCounts table and session-only /who details: about
-- 1.2 KB each, which full guild sweeps (2.0.19) multiplied by thousands.
local DROP_ALWAYS = { "online", "race", "className" }	-- never read for members
local ALLOW_FLAGS = { "excludedGroup", "excludedGuildInvite", "excludedWhispers", "excludedChat" }
local function compactMember(m)
	if type(m) ~= "table" then return end
	ensureMemberBlockData(m)
	if type(m.block) ~= "table" then memberBlock(m) end		-- folds true Allow flags into m.block
	for _, f in ipairs(ALLOW_FLAGS) do
		if m[f] ~= true then m[f] = nil end
	end
	if type(m.block) == "table" and next(m.block) == nil then m.block = nil end
	if m.lastBlockedInvite == "" then m.lastBlockedInvite = nil end
	local bc = m.blockCounts
	if type(bc) == "table" then
		local zero = (tonumber(bc.total) or 0) == 0
		for _, c in ipairs(History.ALL_CATS) do
			if (tonumber(bc[c]) or 0) ~= 0 then zero = false break end
		end
		if zero then m.blockCounts = nil end
	end
	if m._blockV2 and not hasLegacyBlockData(m) then m._blockV2 = nil end
	for _, f in ipairs(DROP_ALWAYS) do m[f] = nil end
end
M.PSS_CompactMember = compactMember

-- every stored member of every guild rule
local function compactAllMembers()
	local n = 0
	for _, g in pairs((PourSocialScoreDB and PourSocialScoreDB.guildData) or {}) do
		if type(g) == "table" and type(g.members) == "table" then
			for _, m in pairs(g.members) do
				if type(m) == "table" then compactMember(m); n = n + 1 end
			end
		end
	end
	return n
end
M.PSS_CompactAllMembers = compactAllMembers

-- forget a member's counts (Reset): no counts stored = all zero
local function clearMemberBlockData(m)
	m.blockHistory, m.blockCounts, m.lastBlockedInvite, m._blockV2 = nil, nil, nil, nil
	for _, f in ipairs(LEGACY_COUNT_FIELDS) do m[f] = nil end
end

-- Fields that must never be copied by reference between member records.
local BLOCK_FIELDS = {
	blockCounts = true, blockHistory = true, _blockV2 = true,
	blockedWhispers = true, blockedPrivateMessages = true, blockedChatMessages = true, blockedInvites = true,
	privateMessagesBlocked = true, chatMessagesBlocked = true, partyInvitesBlocked = true,
	partyRaidMessagesBlocked = true,
}

-- Merge src's blocked counts INTO dst (used whenever a player moves between
-- guild rules). Counts are summed (only one record is ever hit for a given
-- block); the history lines belong to the character and need no moving.
local function mergeBlockData(dst, src)
	if type(dst) ~= "table" or type(src) ~= "table" or dst == src then return end
	ensureMemberBlockData(dst)
	ensureMemberBlockData(src)
	if src.blockCounts then
		ensureMemberBlockData(dst, true)
		for _, c in ipairs(History.ALL_CATS) do
			dst.blockCounts[c] = (dst.blockCounts[c] or 0) + (src.blockCounts[c] or 0)
		end
		dst.blockCounts.total = (dst.blockCounts.total or 0) + (src.blockCounts.total or 0)
	end
	if (src.lastBlockedInvite or "") ~= "" and (dst.lastBlockedInvite or "") == "" then
		dst.lastBlockedInvite = src.lastBlockedInvite
	end
end
M.PSS_MergeMemberBlockData = mergeBlockData

------------------------------------------------------------------------
-- MANAGED (DEFAULT) GUILDS
--
-- PSS_GuildIgnore_Managed.lua ships read-only groups of guilds ("Olympus")
-- with their members. Each group has a built-in rule on the Chat Filters tab
-- (InfluencerGuild=<Name>) that switches the whole group on or off, and a
-- collapsible entry on the Guild Ignore List.
--
-- Only the DELTA is saved in PourSocialScoreDB:
--   * the guild rule records themselves (settings, W I G P C, Scan Fields)
--   * members found by scans / invites that are NOT in the shipped list
--   * shipped members you changed (note, exclusions, overrides) or that have
--     block history - written at logout
--   * g.managedGone[canon] = true for shipped members that left the guild
--     (seen in another guild by /who) or that you removed
-- Every other shipped member is "virtual": built from the shipped list when
-- needed and never written to SavedVariables.
------------------------------------------------------------------------
local MANAGED = addon.MANAGED or { groups = {} }
local managed = nil				-- guild-level data, built on first use
-- canon -> record for shipped members looked at this session. Weak: a record
-- nobody uses any more is freed by the garbage collector. Records you
-- changed are also held in vkeep until they are saved at logout.
local vcache = setmetatable({}, { __mode = "v" })
local vkeep = {}

-- Guild-level data (cheap: one entry per guild). The per-member index
-- (canon key -> guild number * 65536 + position) ships prebuilt in
-- PSS_GuildIgnore_Managed.lua (tools/PSS_BuildManaged.lua), so nothing is
-- built per member at login and every shipped member matches from the
-- first chat line.
local function buildManaged()
	if managed then return managed end
	managed = { lists = {}, names = {}, groupOf = {}, guildName = {}, groups = {} }
	for _, grp in ipairs(MANAGED.groups or {}) do
		managed.groups[grp.key] = grp
		local gkeys = {}
		for gi, list in ipairs(grp.guilds or {}) do
			local gkey = normalizeGuild(list.name)
			gkeys[gi] = gkey or false
			if gkey then
				managed.groupOf[gkey] = grp.key
				managed.guildName[gkey] = list.name
				managed.names[gkey] = list
			end
		end
		managed.lists[#managed.lists + 1] = { index = grp.index or {}, gkeys = gkeys }
	end
	return managed
end

-- canon key -> shipped guild key, position in its list (nil if not shipped).
-- A character listed by two groups belongs to the first.
local function shippedOf(ck)
	if not ck then return nil end
	local lists = (managed or buildManaged()).lists
	for i = 1, #lists do
		local v = lists[i].index[ck]
		if v then
			local gi = math.floor(v / 65536)
			local gkey = lists[i].gkeys[gi]
			if gkey then return gkey, v - gi * 65536 end
		end
	end
	return nil
end

-- numbers for /pss mem
function M.PSS_ManagedStats()
	local m = buildManaged()
	local shipped, indexed = 0, 0
	for _, list in pairs(m.names) do shipped = shipped + #list end
	for _, l in ipairs(m.lists) do
		for _ in pairs(l.index) do indexed = indexed + 1 end
	end
	local kept, cached = 0, 0
	for _ in pairs(vkeep) do kept = kept + 1 end
	for _ in pairs(vcache) do cached = cached + 1 end
	return { shipped = shipped, indexed = indexed, kept = kept, cached = cached }
end

function M.PSS_ManagedGroups() return buildManaged().groups end
function M.PSS_ManagedGroupOfGuild(gkey) return buildManaged().groupOf[gkey] end

-- shipped (static) guild rule? (those can't be removed)
local function isStaticGuild(gkey) return buildManaged().groupOf[gkey] ~= nil end
M.PSS_IsStaticManagedGuild = isStaticGuild

local function isGone(g, ck) return type(g) == "table" and type(g.managedGone) == "table" and g.managedGone[ck] == true end

-- the shipped guild a character belongs to (nil if none, or they left it)
local function staticGuildOf(ck)
	local gkey = shippedOf(ck)
	if not gkey then return nil end
	local g = PourSocialScoreDB and PourSocialScoreDB.guildData and PourSocialScoreDB.guildData[gkey]
	if not g or isGone(g, ck) then return nil end
	return gkey, g
end

local function isStaticMember(gkey, ck)
	if ck == nil then return false end
	return shippedOf(ck) == gkey
end
M.PSS_IsManagedStaticMember = isStaticMember

-- The record for a shipped member (one per character while in use).
local function vrec(ck, gkey)
	local r = vkeep[ck] or vcache[ck]
	if r and r._gkey == gkey then return r end
	local m = buildManaged()
	local gk, pos = shippedOf(ck)
	local name = (gk == gkey) and m.names[gkey][pos]
	if not name then return nil end
	-- flags, counts and block choices are created when first set
	r = {
		name = displayPlayer(name), guild = m.guildName[gkey] or gkey, whenBlocked = "Managed list",
		_managed = true, _virtual = true, _canon = ck, _gkey = gkey,
		_playerKey = normalizePlayer(name),
	}
	vcache[ck] = r
	return r
end
M.PSS_ManagedRecord = vrec

-- A shipped member's record was changed: hold it until it is saved.
local function keepManaged(r)
	if type(r) == "table" and r._virtual and r._canon then vkeep[r._canon] = r end
end
M.PSS_KeepManaged = keepManaged

-- has the record got anything worth saving?
local function managedDirty(r)
	if type(r) ~= "table" then return false end
	if type(r.note) == "string" and r.note ~= "" then return true end
	if type(r.block) == "table" and next(r.block) ~= nil then return true end
	if type(r.opts) == "table" and next(r.opts) ~= nil then return true end
	if type(r.blockCounts) == "table" and (tonumber(r.blockCounts.total) or 0) > 0 then return true end
	if (r.lastBlockedInvite or "") ~= "" then return true end
	return false
end

-- A shipped member is no longer in that guild (seen elsewhere, or removed).
local function tombstone(gkey, ck)
	local g = PourSocialScoreDB.guildData[gkey]
	if not g then return end
	g.managedGone = type(g.managedGone) == "table" and g.managedGone or {}
	g.managedGone[ck] = true
	if vcache[ck] and vcache[ck]._gkey == gkey then vcache[ck] = nil end
	if vkeep[ck] and vkeep[ck]._gkey == gkey then vkeep[ck] = nil end
	local key
	for k, mm in pairs(g.members or {}) do
		if type(mm) == "table" and (canonPlayer(type(k) == "string" and k or nil) or canonPlayer(mm.name)) == ck then key = k break end
	end
	if key then g.members[key] = nil end
end
M.PSS_ManagedTombstone = tombstone

-- Members of a guild rule including shipped members:
-- fn(member, storedKey or nil, isVirtual)
--   includeUntouched = false: only shipped members that have a record this
--   session (only those can have counts / history) - cheap
--   includeUntouched = true : every shipped member (members window)
local function forEachMember(g, gkey, fn, includeUntouched)
	local seen = g.managed and {} or nil
	for k, m in pairs(g.members or {}) do
		if type(m) == "table" then
			if seen then
				local ck = canonPlayer(type(k) == "string" and k or nil) or canonPlayer(m.name)
				if ck then seen[ck] = true end
			end
			fn(m, k, false)
		end
	end
	if not g.managed then return end
	if includeUntouched then
		local mm = buildManaged()
		for _, name in ipairs(mm.names[gkey] or {}) do
			local ck = canonPlayer(name)
			if ck and shippedOf(ck) == gkey and not seen[ck] and not isGone(g, ck) then
				seen[ck] = true
				local r = vrec(ck, gkey)
				if r then fn(r, nil, true) end
			end
		end
	else
		local done = {}
		for _, t in ipairs({ vkeep, vcache }) do
			for ck, r in pairs(t) do
				if r._gkey == gkey and not seen[ck] and not done[ck] and not isGone(g, ck) then
					done[ck] = true
					fn(r, nil, true)
				end
			end
		end
	end
end
M.PSS_ForEachGuildMember = forEachMember

-- Number of members, without building any records: stored members, plus
-- the shipped list minus those who left (simple arithmetic).
function M.PSS_GuildMemberCount(g, gkey)
	if type(g) ~= "table" then return 0 end
	local n = 0
	if not g.managed then
		for _ in pairs(g.members or {}) do n = n + 1 end
		return n
	end
	local m = buildManaged()
	n = #(m.names[gkey] or {})
	for k, mm in pairs(g.members or {}) do
		local ck = canonPlayer(type(k) == "string" and k or nil) or (type(mm) == "table" and canonPlayer(mm.name))
		if not (ck and shippedOf(ck) == gkey) then n = n + 1 end
	end
	for ck in pairs(g.managedGone or {}) do
		if shippedOf(ck) == gkey then n = n - 1 end
	end
	return math.max(0, n)
end

-- Create / tag the shipped guild rules (startup).
local function ensureManagedRules()
	local m = buildManaged()
	for gkey, groupKey in pairs(m.groupOf) do
		local g = ensureGuild(m.guildName[gkey])
		if g then
			g.managed = groupKey
			g.ruleOrigin = g.ruleOrigin or "managed"
			g.managedGone = type(g.managedGone) == "table" and g.managedGone or {}
		end
	end
end
M.PSS_EnsureManagedRules = ensureManagedRules

-- Logout: keep only the delta. Changed shipped members are written into
-- the guild record; unchanged shipped members are dropped from it.
function M.PSS_FlushManaged()
	if not PourSocialScoreDB or not PourSocialScoreDB.guildData then return end
	for _, t in ipairs({ vkeep, vcache }) do
		for ck, r in pairs(t) do
			local g = PourSocialScoreDB.guildData[r._gkey]
			if g and not isGone(g, ck) and managedDirty(r) then
				g.members = g.members or {}
				local key = r._playerKey or normalizePlayer(r.name)
				if key and not g.members[key] then
					r._virtual = nil
					g.members[key] = r
				end
			end
		end
	end
	for gkey, g in pairs(PourSocialScoreDB.guildData) do
		if type(g) == "table" and g.managed and type(g.members) == "table" then
			local drop = {}
			for k, mm in pairs(g.members) do
				local ck = canonPlayer(type(k) == "string" and k or nil) or (type(mm) == "table" and canonPlayer(mm.name))
				if ck and isStaticMember(gkey, ck) and not managedDirty(mm) then drop[#drop + 1] = k end
			end
			for _, k in ipairs(drop) do g.members[k] = nil end
			g.memberCount = nil
		end
	end
	compactAllMembers()
end

------------------------------------------------------------------------
-- Member lookup index: canonical player key -> guild key, stored key.
-- Chat events arrive with several name spellings ("Name", "Name-Realm",
-- "Name-Aman'Thul", Proper-cased names from the core filter...). The index
-- uses canonPlayer() so all of them resolve to the stored member record.
------------------------------------------------------------------------
-- Two flat maps (ck -> guild key, ck -> stored key) rather than a small
-- table per member: no per-member allocation on each rebuild.
local memberIndexG, memberIndexK, memberIndexDirty, memberIndexBuilt = {}, {}, true, 0

local function markMemberIndexDirty() memberIndexDirty = true end
M.PSS_MarkGuildIndexDirty = markMemberIndexDirty

local function rebuildMemberIndex()
	local idxG, idxK, score = {}, {}, {}
	local bestCache = {}
	for gkey, g in pairs((PourSocialScoreDB and PourSocialScoreDB.guildData) or {}) do
		if type(g) == "table" and type(g.members) == "table" then
			for storedKey, m in pairs(g.members) do
				if type(m) == "table" then
					local ck = canonPlayer(type(storedKey) == "string" and storedKey or nil)
						or canonPlayer(m._playerKey) or canonPlayer(m.name)
					if ck then
						-- Prefer an enabled rule, then the rule that best owns the
						-- member's actual guild (duplicates across rules).
						local actual = m.guild or ""
						local best = bestCache[actual]
						if best == nil then
							best = (M.PSS_BestGuildRowFor and M.PSS_BestGuildRowFor(actual)) or false
							bestCache[actual] = best
						end
						local s = (guildRuleActive(g) and 2 or 0) + ((best == gkey) and 1 or 0)
						if not idxG[ck] or s > score[ck] then
							idxG[ck], idxK[ck] = gkey, storedKey
							score[ck] = s
						end
					end
				end
			end
		end
	end
	memberIndexG, memberIndexK = idxG, idxK
	memberIndexDirty = false
	memberIndexBuilt = GetTime and GetTime() or 0
end

-- Returns g, gkey, member, storedKey for a canon key (PSS_CanonPlayer).
-- The chat core already has the key, so this is the per-line path.
local function lookupGuildMemberCanon(ck)
	if not ck or not PourSocialScoreDB or not PourSocialScoreDB.guildData then return nil end
	-- rebuilt only when members changed (stale hits are re-checked below)
	if memberIndexDirty then rebuildMemberIndex() end

	for attempt = 1, 2 do
		local hitG, hitK = memberIndexG[ck], memberIndexK[ck]
		if not hitG then
			-- a shipped member of a managed guild (not stored)
			local gkey, g = staticGuildOf(ck)
			if gkey and g.managed then
				local r = vrec(ck, gkey)
				if r then return g, gkey, r, nil end
			end
			return nil
		end
		local g = PourSocialScoreDB.guildData[hitG]
		local m = g and g.members and g.members[hitK]
		if m then return g, hitG, m, hitK end
		if attempt == 1 then rebuildMemberIndex() end	-- stale entry
	end
	return nil
end

-- Same, for any spelling of a player's name.
local function lookupGuildMember(name)
	if type(name) ~= "string" or name == "" or isSecret(name) then return nil end
	return lookupGuildMemberCanon(canonPlayer(name))
end
M.PSS_LookupGuildMember = lookupGuildMember

------------------------------------------------------------------------
-- UI refresh throttle (spam can fire many blocks per second).
------------------------------------------------------------------------
local guildUIRefreshPending = false
local function requestGuildUIRefresh()
	if guildUIRefreshPending then return end
	guildUIRefreshPending = true
	local function run()
		guildUIRefreshPending = false
		if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
		local d = M.PSSGuildDetailFrame
		if d and d:IsShown() and d.refresh then d.refresh(true) end
		if M.PSS_RefreshHistoryPopup then M.PSS_RefreshHistoryPopup() end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end
M.PSS_RequestGuildUIRefresh = requestGuildUIRefresh

local function recordGuildBlock(g, m, cat, event, message, channel, gkey)
	keepManaged(m)
	ensureMemberBlockData(m, true)
	local entry = History.NewEntry(cat, event, message, channel, m.name)
	entry.gk = gkey			-- the rule at the time (used if they leave every rule)
	History.Add(History.MemberKey(m), m.blockCounts, entry)
	if M.PSS_Stats then M.PSS_Stats.Count("guild", entry.cat) end
	if entry.cat == "partyInvite" or entry.cat == "guildInvite" then
		m.lastBlockedInvite = entry.time
	end
	requestGuildUIRefresh()
	return entry
end

-- W I G P C setters.
-- Member: value true/false sets the member's own choice; nil = use the guild's.
function M.PSS_SetMemberBlock(g, member, cat, value)
	if type(member) ~= "table" or not M.PSS_EXCL_INFO[cat] then return false end
	local was = g and memberBlocks(g, member, cat)
	keepManaged(member)
	if value == nil then memberBlockW(member)[cat] = nil else memberBlockW(member)[cat] = value == true end
	if g then
		refreshGuildActive(g)
		-- newly blocked: clear their earlier lines from chat, decline an open invite
		if not was and memberBlocks(g, member, cat) then
			local ck = canonPlayer(member._playerKey) or canonPlayer(member.name)
			if ck and M.PSS_PurgeChatFrom then M.PSS_PurgeChatFrom({ [ck] = true }) end
			if M.PSS_PersonIdentified and member.name then M.PSS_PersonIdentified(member.name) end
		end
	end
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	return true
end

function M.PSS_SetGuildBlock(guildNameOrKey, cat, value)
	ensureDB()
	local g = PourSocialScoreDB.guildData[normalizeGuild(guildNameOrKey) or ""]
	if not g or not M.PSS_EXCL_INFO[cat] then return end
	guildBlock(g)[cat] = value == true
	refreshGuildActive(g)
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end

-- "W I G P C" with blocked letters lit, for diagnostics.
function M.PSS_ExclusionText(g, m)
	local out = {}
	for _, c in ipairs(EXCL_CATS) do
		local on = m and memberBlocks(g, m, c) or (not m and guildBlock(g)[c])
		local L = M.PSS_EXCL_INFO[c].letter
		out[#out + 1] = on and ("|cffff5555" .. L .. "|r") or ("|cff666666" .. L:lower() .. "|r")
	end
	return table.concat(out, " ")
end

-- Older API (Allow* = "do not block"), kept for compatibility.
local ALLOW_FIELD = { allowGroup = { "partyInvite" }, allowGuildInvite = { "guildInvite" }, allowWhispers = { "whisper" },
						allowChat = { "partyRaid", "world" },
						excludedGroup = { "partyInvite" }, excludedGuildInvite = { "guildInvite" }, excludedWhispers = { "whisper" },
						excludedChat = { "partyRaid", "world" } }
function M.PSS_SetMemberFlag(member, field, value)
	local cats = ALLOW_FIELD[field]
	if type(member) ~= "table" or not cats then return false end
	keepManaged(member)
	local b = memberBlockW(member)
	for _, c in ipairs(cats) do
		if value == true then b[c] = false else b[c] = nil end		-- (x and false or nil) is always nil
	end
	return true
end

function M.PSS_SetGuildMemberSetting(guildName, playerName, field, value, sourceGuildKey)
	ensureDB()
	local ck = canonPlayer(playerName)
	if not ck then return false end
	local function findIn(g)
		if not g or type(g.members) ~= "table" then return nil end
		for k, m in pairs(g.members) do
			if type(m) == "table" and (canonPlayer(type(k) == "string" and k or nil) == ck or canonPlayer(m.name) == ck) then
				return m
			end
		end
	end
	local m = findIn(sourceGuildKey and PourSocialScoreDB.guildData[sourceGuildKey])
		or findIn(PourSocialScoreDB.guildData[normalizeGuild(guildName) or ""])
	if not m then
		local _, _, mm = lookupGuildMember(playerName)
		m = mm
	end
	return M.PSS_SetMemberFlag(m, field, value)
end

function M.PSS_RemoveGuildMember(guildName, playerName, sourceGuildKey, storedKey)
	ensureDB()
	local g = (sourceGuildKey and PourSocialScoreDB.guildData[sourceGuildKey])
		or PourSocialScoreDB.guildData[normalizeGuild(guildName) or ""]
	if not g or type(g.members) ~= "table" then return false end

	local removed = false
	local rck = canonPlayer(playerName)
	if g.managed and rck then
		local gk = sourceGuildKey or normalizeGuild(guildName)
		if gk and isStaticMember(gk, rck) and not isGone(g, rck) then
			tombstone(gk, rck)
			removed = true
		end
	end
	if storedKey ~= nil and g.members[storedKey] then
		g.members[storedKey] = nil
		removed = true
	else
		local ck = canonPlayer(playerName)
		local doomed = {}
		for k, m in pairs(g.members) do
			if ck and (canonPlayer(type(k) == "string" and k or nil) == ck or (type(m) == "table" and canonPlayer(m.name) == ck)) then
				doomed[#doomed + 1] = k
			end
		end
		for _, k in ipairs(doomed) do g.members[k] = nil; removed = true end
	end
	if removed then
		g.memberCount = 0
		for _ in pairs(g.members) do g.memberCount = g.memberCount + 1 end
		markMemberIndexDirty()
	end
	return removed
end

------------------------------------------------------------------------
-- Totals and history (guild = sum/merge of its members)
------------------------------------------------------------------------
local function emptyCounts() return History.EmptyCounts() end
-- a member's counts for reading (members never blocked keep none)
local NO_COUNTS = History.EmptyCounts()
local function memberCounts(m) return m.blockCounts or NO_COUNTS end

local function findGuildRecord(guildNameOrKey)
	if not PourSocialScoreDB or not PourSocialScoreDB.guildData then return nil end
	local key = normalizeGuild(guildNameOrKey)
	local g = key and PourSocialScoreDB.guildData[key]
	if g then return g, key end
	for k, cand in pairs(PourSocialScoreDB.guildData) do
		if type(cand) == "table" and normalizeGuild(cand.name) == key then return cand, k end
	end
	return nil
end

-- Returns a counts table { whisper=, partyInvite=, partyRaid=, world=, guildInvite=, total= }.
-- With no argument, sums every guild rule.
function M.PSS_GetGuildBlockCounts(guildNameOrKey)
	local out = emptyCounts()
	local guilds = {}
	if guildNameOrKey then
		local g, k = findGuildRecord(guildNameOrKey)
		if g then guilds[1] = { g = g, key = k } end
	else
		for k, g in pairs((PourSocialScoreDB and PourSocialScoreDB.guildData) or {}) do
			if type(g) == "table" then guilds[#guilds + 1] = { g = g, key = k } end
		end
	end
	for _, gg in ipairs(guilds) do
		forEachMember(gg.g, gg.key, function(m)
			ensureMemberBlockData(m)
			local bc = memberCounts(m)
			for _, c in ipairs(History.ALL_CATS) do out[c] = out[c] + (bc[c] or 0) end
		end)
	end
	local total = 0
	for _, c in ipairs(History.ALL_CATS) do total = total + out[c] end
	out.total = total
	return out
end

function M.PSS_GetMemberBlockCounts(m)
	local out = emptyCounts()
	if type(m) ~= "table" then out.total = 0 return out end
	ensureMemberBlockData(m)
	local bc, total = memberCounts(m), 0
	for _, c in ipairs(History.ALL_CATS) do out[c] = bc[c] or 0; total = total + out[c] end
	out.total = total
	return out
end

-- Compatibility wrapper: total, whispers, partyInvites, partyRaid, world, guildInvites
function M.PSS_GetGuildBlockTotals(guildName)
	local c = M.PSS_GetGuildBlockCounts(guildName)
	return c.total, c.whisper, c.partyInvite, c.partyRaid, c.world, c.guildInvite
end

-- Does a log line belong to guild rule gkey? A line is owned by a
-- character ("g:<canon>"); it shows under the rule that character is in now
-- (so it follows them when moved), or - if they are in no rule any more -
-- under the rule they were in when it was blocked.
local function guildLineMatcher(g, gkey)
	local stored = {}
	for k, m in pairs(g.members or {}) do
		if type(m) == "table" then
			local ck = canonPlayer(type(k) == "string" and k or nil) or canonPlayer(m._playerKey) or canonPlayer(m.name)
			if ck then stored[ck] = true end
		end
	end
	local where = {}		-- ck -> in this rule (true) / not (false), per view
	return function(h)
		local o = h.o
		if type(o) ~= "string" or o:sub(1, 2) ~= "g:" then return false end
		local ck = o:sub(3)
		local w = where[ck]
		if w == nil then
			if stored[ck] or (g.managed and isStaticMember(gkey, ck) and not isGone(g, ck)) then
				w = true
			else
				w = (h.gk == gkey) and lookupGuildMember(ck) == nil
			end
			where[ck] = w
		end
		return w
	end
end

-- Newest-first history for one guild rule (or every rule when nil), from
-- the shared log.
function M.PSS_GetGuildBlockHistory(guildNameOrKey)
	local matchers = {}
	if guildNameOrKey then
		local g, gkey = findGuildRecord(guildNameOrKey)
		if not g then return {} end
		matchers[1] = { fn = guildLineMatcher(g, gkey), label = "Guild rule: " .. tostring(g.name or gkey) }
		return History.Collect(function(h)
			if matchers[1].fn(h) then History.SetSource(h, matchers[1].label) return true end
			return false
		end)
	end
	local label = {}		-- ck -> "Guild rule: X" / false
	return History.Collect(function(h)
		local o = h.o
		if type(o) ~= "string" or o:sub(1, 2) ~= "g:" then return false end
		local ck = o:sub(3)
		local l = label[ck]
		if l == nil then
			local g, gkey = lookupGuildMember(ck)
			l = g and ("Guild rule: " .. tostring(g.name or gkey)) or false
			label[ck] = l
		end
		if not l and h.gk then
			local g = PourSocialScoreDB.guildData[h.gk]
			if g then l = "Guild rule: " .. tostring(g.name or h.gk) end
		end
		if l then History.SetSource(h, l) end
		return true
	end)
end

function M.PSS_ResetGuildBlockHistory(guildNameOrKey)
	local g, gkey = findGuildRecord(guildNameOrKey)
	if not g then return end
	History.Clear(guildLineMatcher(g, gkey))
	forEachMember(g, gkey, clearMemberBlockData)
	g.blockHistory = nil
	requestGuildUIRefresh()
end

function M.PSS_GetMemberBlockHistory(member)
	local key = History.MemberKey(member)
	return key and History.For(key) or {}
end

function M.PSS_ResetMemberBlockHistory(member)
	if type(member) ~= "table" then return end
	local key = History.MemberKey(member)
	if key then History.Clear(function(h) return h.o == key end) end
	clearMemberBlockData(member)
	requestGuildUIRefresh()
end

local createHistoryList = History.CreateList
local showHistoryPopup = History.ShowPopup

function M.PSS_ShowMemberBlockHistory(member, guildLabel)
	if type(member) ~= "table" then return end
	showHistoryPopup(function()
		ensureMemberBlockData(member)
		return "Block History: " .. tostring(member.name or "?") ..
				(guildLabel and ("  |cffaaaaaa<" .. guildLabel .. ">|r") or ""),
				M.PSS_GetMemberBlockHistory(member), M.PSS_GetMemberBlockCounts(member)
	end, function() M.PSS_ResetMemberBlockHistory(member) end)
end

function M.PSS_ShowGuildBlockHistory(guildNameOrKey)
	local g = findGuildRecord(guildNameOrKey)
	if not g then return end
	showHistoryPopup(function()
		local gg = findGuildRecord(guildNameOrKey)
		if not gg then return "Guild Block History (removed)", {}, nil end
		return "Guild Block History: " .. tostring(gg.name or guildNameOrKey),
				M.PSS_GetGuildBlockHistory(guildNameOrKey), M.PSS_GetGuildBlockCounts(guildNameOrKey)
	end, function() M.PSS_ResetGuildBlockHistory(guildNameOrKey) end)
end

-- Store one /who result under a guild rule. Returns "new" (not stored under
-- that rule before), "known", or nil (no rule / no guild).
local function addWhoResultToGuildMember(info, guildRowName, actualGuild)
	local fullName = info.fullName or info.name
	if type(fullName) ~= "string" or isSecret(fullName) or fullName == "" then return nil end

	actualGuild = actualGuild or info.fullGuildName or info.guild or ""
	if M.PSS_IsGuildExcluded(actualGuild) then return nil end	-- Guild Exclusion List
	-- WHO's lazy guild search means a scan for "Olympus" also returns members of
	-- "Olympus Tycoons". If a more specific saved guild rule matches this
	-- member's ACTUAL guild, the member belongs to that rule, not to the broad
	-- one that happened to catch them.
	local ownerKey, owner = M.PSS_BestGuildRowFor(actualGuild)
	if owner and ownerKey ~= normalizeGuild(guildRowName) then
		guildRowName = owner.name or guildRowName
	end

	local rowKey = normalizeGuild(guildRowName)
	local g = rowKey and PourSocialScoreDB.guildData and PourSocialScoreDB.guildData[rowKey]
	if not g then return nil end
	local pkey = normalizePlayer(fullName)
	local status = (pkey and g.members and g.members[pkey]) and "known" or "new"

	-- managed guild + shipped member: nothing is stored (it is in the shipped
	-- list); the session record just gets the fresh /who details
	local wck = canonPlayer(fullName)
	if g.managed and wck and isStaticMember(rowKey, wck) and not (pkey and g.members and g.members[pkey]) then
		local wasGone = isGone(g, wck)
		if wasGone then g.managedGone[wck] = nil end
		local r = vrec(wck, rowKey)
		if r then
			local moved = M.PSS_MoveOtherCopies and M.PSS_MoveOtherCopies(fullName, rowKey, r) or 0
			r.guild = actualGuild
			r.class = classTokenFromInfo(info.filename or info.classFileName or info.classFile or info.classStr or info.class) or r.class
			r.level = tonumber(info.level) or r.level
			markMemberIndexDirty()
			if moved > 0 then return "moved" end
			return wasGone and "new" or "known"
		end
	end

	local member = M.PSS_UpdateGuildMember(guildRowName, fullName)
	-- /who shows the player's guild NOW: if they are stored under any other
	-- guild rule (they changed guild, or a broad rule caught them), their
	-- record - settings, exclusions and block history - is merged into this
	-- rule and removed from the old one(s).
	if member and M.PSS_MoveOtherCopies and M.PSS_MoveOtherCopies(fullName, rowKey, member) > 0 and status == "new" then
		status = "moved"
	end
	if member then
		member.guild = actualGuild
		member.name = displayPlayer(fullName)
		member.class = classTokenFromInfo(
			info.filename or info.classFileName or info.classFile or
			info.classStr or info.class
		) or member.class or ""
		member.level = tonumber(info.level) or member.level
		-- Store the canonical player key on the member record. This makes the
		-- later exact-guild migration independent of display-name formatting,
		-- realm-name casing, or which broad guild filter originally captured it.
		member._playerKey = normalizePlayer(fullName)
	end

	-- Keep actual-guild metadata current for later explicit Add Guild promotion.
	local p = pkey and PourSocialScoreDB.playerData and PourSocialScoreDB.playerData[pkey]
	if p then
		p.currentGuild = actualGuild
		p.online = true
		if member then
			p.class = member.class or p.class or ""
			p.className = info.classStr or info.className or p.className
		end
	end
	return member and status or nil
end

function M.PSS_ScanGuild(guildName, mode, restart)
	local g = ensureGuild(guildName)
	if not g then return false end
	if not g.ruleOrigin then g.ruleOrigin = "scan" end

	-- mode "custom": the guild plus its Scan Fields; anything else: the
	-- next search of the guild's sweep (PSS_WhoisHarvest.lua)
	mode = (mode == "custom") and "custom" or "sweep"
	local filter, bracket, step, sw, item
	if mode == "custom" then
		-- Custom Scan Fields text is sent as-is after the guild name,
		-- e.g. g-"Olympus" 80 c-"Mage"
		bracket = trim(g.customScan or "")
		filter = 'g-"' .. g.name:gsub('"', "") .. '"' .. (bracket ~= "" and (" " .. bracket) or "")
		filter = M.PSS_CapWhoFilter(filter)		-- Options: scan level cap
		bracket = filter:match('^g%-".-"%s*(.*)$') or ""
	else
		sw, item, filter = M.PSS_HarvestNext(g, restart)
		if not item then
			M.ShowMsg(("Scan <%s>: waiting for the answer to the last search."):format(g.name))
			return false
		end
		bracket = filter:match('^g%-".-"%s*(.*)$') or ""
		step = sw.sent + 1
	end

	local req = {
		kind = "guildScan",
		guildKey = normalizeGuild(g.name),
		guildName = g.name,
		bracket = bracket or "",
		filter = filter,
		mode = mode,
		step = step,
		sweep = sw,
		item = item,
		startedAt = GetTime(),
		seen = 0, matched = 0, added = 0, other = 0, moved = 0,
	}

	-- Mirrors OlympusMute's WhoScan(): the /who goes out straight from the
	-- button's OnClick with nothing UI-related having run first.  Cooldown,
	-- button state and list refresh all happen on the next frame, so the
	-- click handler never disables/hides/re-scripts the button it is running
	-- from before the protected call has been made.
	-- (Whois.Request starts the cooldown and the 5 s "nobody answered"
	-- timer itself, both after the /who has gone out.)
	if not Whois.Request(req) then return false end
	if sw then M.PSS_HarvestSent(sw, filter) end	-- only advance when the /who really went out
	C_Timer.After(0, function()
		if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	end)
	return true
end

------------------------------------------------------------------------
-- /who RESULTS (from PSS_Whois.lua)
--
-- Every /who answer - from a Scan, a Guild Search, a Player Search or your
-- own /who - is read here: each player is stored under the saved guild rule
-- that owns their guild. (A /who never CREATES a guild rule.) A guild Scan
-- or Guild Search request also keeps its own counts and results.
------------------------------------------------------------------------
-- one result; returns "new" / "known" / "moved" / nil
local function captureWho(info, req)
	local guild = info.fullGuildName or info.guild or ""
	if type(guild) ~= "string" or isSecret(guild) then guild = "" end
	local scan = (req and req.kind == "guildScan") and req or nil
	local search = (req and req.kind == "guildSearch") and req or nil
	if scan then scan.seen = scan.seen + 1 end

	if search and guild ~= "" then
		local gkey = normalizeGuild(guild)
		search.found = search.found or {}
		search.players = search.players or {}
		if gkey and not search.found[gkey] then search.found[gkey] = trim(guild) end
		-- remembered so the guilds you add from the results get these players
		local fn = info.fullName or info.name
		if gkey and type(fn) == "string" and not isSecret(fn) and fn ~= "" then
			local list = search.players[gkey] or {}
			search.players[gkey] = list
			list[#list + 1] = {
				fullName = fn, fullGuildName = guild, level = info.level,
				classStr = info.classStr, className = info.className, filename = info.filename,
				raceStr = info.raceStr or info.race,
			}
		end
	end

	if guild == "" then
		if scan then scan.other = scan.other + 1 end
		return nil
	end
	local res
	if scan and guildMatches(scan.guildName, guild) then
		scan.matched = scan.matched + 1
		res = addWhoResultToGuildMember(info, scan.guildName, guild)
	else
		if scan then scan.other = scan.other + 1 end
		local ownerKey, owner = M.PSS_BestGuildRowFor(guild)
		if owner then res = addWhoResultToGuildMember(info, owner.name or ownerKey, guild) end
	end
	if scan and res == "new" then scan.added = scan.added + 1 end
	if scan and res == "moved" then scan.moved = (scan.moved or 0) + 1 end
	if res then M.PSS__whoCaptured = true end
	return res
end

-- After a /who answer: show Guild Search results, move members to the most
-- specific rule, report what the scan did, refresh.
local function finishScan(req, numWhos, total, how)
	if M.PSS_RequestGC then M.PSS_RequestGC("who results") end
	local scan = (req and req.kind == "guildScan") and req or nil
	local searchState = (req and req.kind == "guildSearch") and req or nil
	local captured = M.PSS__whoCaptured
	M.PSS__whoCaptured = nil
	if searchState then
		local list = {}
		for _, name in pairs(searchState.found or {}) do list[#list + 1] = name end
		table.sort(list, function(a, b) return a:lower() < b:lower() end)
		-- temporary cache of who was seen in each guild (used by Save)
		M.PSS_GuildSearchCache = { at = GetTime(), byGuild = searchState.players or {} }
		C_Timer.After(0, function()
			if showGuildSearchResults then showGuildSearchResults(list, searchState.query, searchState.mode) end
		end)
	end

	local moved = scan and scan.moved or 0
	if (scan or captured) and M.PSS_ReconcileGuildMembers then moved = moved + (M.PSS_ReconcileGuildMembers() or 0) end

	local split = scan and scan.sweep and M.PSS_HarvestAnswered(scan, numWhos, total) or 0

	if scan then
		local sw = scan.sweep
		local what = (scan.mode == "custom") and ("Custom (" .. (scan.bracket ~= "" and scan.bracket or "no fields") .. ")")
			or ("Scan %d/%d (%s)"):format(scan.step or 0, (sw and (sw.sent + #sw.queue)) or 0, scan.bracket ~= "" and scan.bracket or "whole guild")
		if scan.seen == 0 then
			M.ShowMsg(("%s for <%s>: /who found nobody. Only online players show in /who - try another bracket or Custom."):format(what, scan.guildName))
		else
			M.ShowMsg(("%s for <%s>: %d player(s) found, %d in a matching guild, %d newly captured%s%s."):format(
				what, scan.guildName, scan.seen, scan.matched, scan.added,
				moved > 0 and (", " .. moved .. " moved here from another guild rule") or "",
				scan.other > 0 and (", " .. scan.other .. " in other guilds skipped") or ""))
		end
		if split > 0 then
			M.ShowMsg(("|cffff9900/who capped at %d: split into %d narrower searches - keep clicking Scan.|r"):format(M.PSS_WHO_CAP, split))
		elseif sw and sw.done then
			M.ShowMsg(("|cff00ff00Sweep of <%s> complete|r: %d searches, %d players found, %d newly captured."):format(scan.guildName, sw.sent, sw.seen, sw.added))
		elseif not sw and tonumber(total) and tonumber(numWhos) and total > numWhos then
			M.ShowMsg(("|cffff9900/who shows at most %d players; this search matched %d. Narrow it with Custom and the Scan Fields (e.g. 85-90 or 90 c-\"Mage\") to reach the rest.|r"):format(numWhos, total))
		end
	elseif moved > 0 then
		M.ChatMsg(("PSS: %d member(s) belonged to a more specific saved guild and were moved there."):format(moved))
	end

	C_Timer.After(0, function()
		if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
		M.PSS_RefreshScanTooltip()
		local d = M.PSSGuildDetailFrame
		if d and d:IsShown() and d.refresh then d.refresh(true) end
		if M.PSSUpdateUI then M.PSSUpdateUI(true) end
	end)
end

Whois.Listen({
	-- one chat-history sweep for everyone newly captured by this answer
	begin = function()
		M.PSS__purgeBatch = M.PSS__purgeBatch or {}
	end,
	info = function(info, req)
		captureWho(info, req)
	end,
	finish = function(req, numWhos, total, how)
		local batch = M.PSS__purgeBatch
		M.PSS__purgeBatch = nil
		if batch and next(batch) and M.PSS_PurgeChatFrom then pcall(M.PSS_PurgeChatFrom, batch) end
		finishScan(req, numWhos, total, how)
	end,
})

-- GUILD SEARCH ---------------------------------------------------------
-- Sends a normal /who and collects the distinct guild names in the results.
-- Plain text is wrapped as g-"text". Anything containing a double quote is
-- treated as a complete /who filter and sent untouched.
-- mode "exclude" (the Guild Exclusion List search): the text is always a
-- guild name, and the results picker adds to the exclusion list instead.
function M.PSS_GuildSearch(text, mode)
	text = trim(text or "")
	if text == "" then return false end

	local filter
	if mode ~= "exclude" and text:find('"', 1, true) then
		filter = text
	else
		filter = 'g-"' .. (text:gsub('"', "")) .. '"'
	end
	filter = M.PSS_CapWhoFilter(filter)		-- Options: scan level cap

	-- /who must go out straight from the click (hardware event)
	return Whois.Request({ kind = "guildSearch", filter = filter, query = text, mode = mode, found = {} })
end

local function guildSearchChat(msg)
	M.ChatMsg("PSS: " .. msg)
end

-- How long Guild Search results are kept for Save (seconds).
local GUILD_SEARCH_CACHE_TTL = 600

-- Guild Search results: the shared picker (UI.Picker in PSS_UIKit.lua).
--   mode nil       : ticked guilds become guild rules, with the players the
--                    search saw in them as members
--   mode "exclude" : ticked guilds go on the Guild Exclusion List
local function saveGuildSearch(names)
	local added, members, moved = 0, 0, 0
	local cache = M.PSS_GuildSearchCache
	-- the cache is only trusted for a while: players move guilds
	if cache and GetTime() - (cache.at or 0) > GUILD_SEARCH_CACHE_TTL then cache = nil end
	M.PSS__purgeBatch = M.PSS__purgeBatch or {}

	for _, name in ipairs(names) do
		M.PSS_AddGuild(name)
		added = added + 1
		-- everyone the search saw in this guild becomes a member of it
		local seen = cache and cache.byGuild[normalizeGuild(name)]
		for _, info in ipairs(seen or {}) do
			local res = addWhoResultToGuildMember(info, name, info.fullGuildName or name)
			if res == "new" then
				members = members + 1
			elseif res == "moved" then
				moved = moved + 1
				members = members + 1
			end
		end
	end

	M.PSS_GuildSearchCache = nil
	local batch = M.PSS__purgeBatch
	M.PSS__purgeBatch = nil
	if batch and next(batch) and M.PSS_PurgeChatFrom then pcall(M.PSS_PurgeChatFrom, batch) end
	if M.PSS_ReconcileGuildMembers then M.PSS_ReconcileGuildMembers() end
	guildSearchChat(("%d guild(s) added to the Guild Ignore List with %d member(s) seen by the search%s."):format(
		added, members, moved > 0 and (" (" .. moved .. " moved from another guild rule)") or ""))
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end

local function saveGuildExclusions(names)
	local added = 0
	for _, name in ipairs(names) do
		if M.PSS_AddGuildExclusion(name) then added = added + 1 end
	end
	guildSearchChat(("%d guild(s) added to the Guild Exclusion List."):format(added))
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end

showGuildSearchResults = function(list, query, mode)
	ensureDB()
	local exclude = mode == "exclude"

	if not list or #list == 0 then
		if exclude then
			-- nobody online in a guild by that name: offer to add it anyway
			M.Widgets.PromptAddAnyway(trim((query or ""):gsub('"', "")), {
				say			= guildSearchChat,
				what		= "guild",
				listName = "Guild Exclusion List",
				add			= M.PSS_AddGuildExclusion,
			})
		else
			guildSearchChat(("Guild Search found no guilds for \"%s\"."):format(query or ""))
		end
		return
	end

	local items = {}
	for _, name in ipairs(list) do
		local listed
		if exclude then
			listed = M.PSS_IsGuildExcluded(name)
		else
			listed = PourSocialScoreDB.guildData[normalizeGuild(name)] ~= nil
		end
		items[#items + 1] = { cells = { guild = name }, value = name, listed = listed }
	end

	M.PSSGuildSearchFrame = M.Widgets.Picker({
		name		= "PSSGuildSearchFrame",
		saveKey		= "guildSearch",
		title		= exclude and "Guild Exclusion Search" or "Guild Search Results",
		subtitle = ("%d guild(s) found for \"%s\"."):format(#list, query or "")
			.. (exclude and " Tick the guilds to exclude." or ""),
		columns		= { { key = "guild", text = "Guild", width = 330, minWidth = 120 } },
		items		= items,
		onSave		= exclude and saveGuildExclusions or saveGuildSearch,
		-- closing the results (Save, Cancel, Escape, X) forgets the cached players
		onHide		= function() if not exclude then C_Timer.After(0, function() M.PSS_GuildSearchCache = nil end) end end,
	})
end

local rosterScanQueued = false
local function handleUnitEvents(event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		scanUnit("target")
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		scanUnit("mouseover")
	elseif event == "NAME_PLATE_UNIT_ADDED" and unit then
		scanUnit(unit)
	elseif event == "GROUP_ROSTER_UPDATE" then
		-- raids fire this in bursts: look once, 2 s after the last one
		if rosterScanQueued then return end
		rosterScanQueued = true
		C_Timer.After(2, function()
			rosterScanQueued = false
			if IsInRaid() then
				for i=1,GetNumGroupMembers() do scanUnit("raid"..i) end
			else
				for i=1,4 do scanUnit("party"..i) end
			end
		end)
	end
end

-- Mouseover and nameplates: listened to out of combat only, so no guild
-- discovery is attempted from them while fighting.
local function listenUnitScans(f, on)
	if on then
		f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
		f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	else
		f:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
		f:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
	if event == "PLAYER_LOGIN" then
		-- Do NOT create/upgrade the database here: on a fresh install the main
		-- addon has not built its default lists yet. The legacy upgrade runs
		-- from the main addon once it has finished loading (V.PSS_Loaded).
		self:UnregisterEvent("PLAYER_LOGIN")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("GROUP_ROSTER_UPDATE")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		listenUnitScans(self, not inCombat())
		if V.PSS_Loaded and M.PSS_UpgradeLegacyData then M.PSS_UpgradeLegacyData() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		listenUnitScans(self, false)
	elseif event == "PLAYER_REGEN_ENABLED" then
		listenUnitScans(self, true)
	elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" or
			event == "NAME_PLATE_UNIT_ADDED" or event == "GROUP_ROSTER_UPDATE" then
		handleUnitEvents(event, arg1)
	end
end)

-- (Chat lines and invites are decided by PSS_ChatBlock.lua; this file
-- registers the "guild" person source further down.)

function M.PSS_UpgradeLegacyData()
	ensureDB()
	for i, name in ipairs(PourSocialScoreDB.ignoreList or {}) do
		local p = ((PourSocialScoreDB.typeList or {})[i] or "player") == "player" and M.PSS_GetPlayerPrefs and M.PSS_GetPlayerPrefs(name)
		if p then
		p.name = name
		p.nickname = p.nickname or name
		p.whenBlocked = p.whenBlocked or PourSocialScoreDB.dateList[i] or nowString()
		p.note = p.note or PourSocialScoreDB.notes[i] or ""
		p.expireDays = p.expireDays or PourSocialScoreDB.expList[i] or 0
		p.faction = p.faction ~= "" and p.faction or (PourSocialScoreDB.factionList[i] or "")
		end
	end
	cleanupLegacyGuildPlayers()
	ensureManagedRules()
	-- 2.0.6: one block-history format for every list (PSS_ChatHistory.lua).
	-- Bring stored player and member history lines up to date once; fields
	-- that were never recorded become "Unknown". (Chat filter history is
	-- converted when the filters load.)
	if (tonumber(PourSocialScoreDB.historyFormat) or 0) < 2 then
		local function upgrade(owner, ownerName)
			if type(owner) ~= "table" then return end
			if type(owner.blockHistory) ~= "table" then owner.blockHistory = {} end
			local kept = {}
			for _, h in ipairs(owner.blockHistory) do
				if History.Normalize(h) then
					h.member = h.member or ownerName or History.UNKNOWN
					kept[#kept + 1] = h
				end
			end
			owner.blockHistory = kept
			owner.blockCounts = History.EnsureCounts(owner.blockCounts)
		end
		for key, p in pairs(PourSocialScoreDB.playerData or {}) do
			if type(p) == "table" then
				if M.PSS_GetPlayerBlockCounts then M.PSS_GetPlayerBlockCounts(p) end	-- counts from older saves
				upgrade(p, p.name or key)
			end
		end
		for _, g in pairs(PourSocialScoreDB.guildData or {}) do
			for key, m in pairs((type(g) == "table" and g.members) or {}) do
				if type(m) == "table" then
					ensureMemberBlockData(m)
					upgrade(m, m.name or key)
				end
			end
		end
		PourSocialScoreDB.historyFormat = 2
	end

	-- 2.0.17: ONE shared block log with a total cap instead of a list per
	-- player / member. Move every old list into it once (newest lines kept).
	if (tonumber(PourSocialScoreDB.historyFormat) or 0) < 3 then
		local sources = {}
		for key, p in pairs(PourSocialScoreDB.playerData or {}) do
			if type(p) == "table" then
				if M.PSS_GetPlayerBlockCounts then M.PSS_GetPlayerBlockCounts(p) end
				if type(p.blockHistory) == "table" and #p.blockHistory > 0 then
					sources[#sources + 1] = { list = p.blockHistory, owner = History.PlayerKey(p.name or key), member = p.name or key }
				end
				p.blockHistory = nil
			end
		end
		for gkey, g in pairs(PourSocialScoreDB.guildData or {}) do
			for key, m in pairs((type(g) == "table" and g.members) or {}) do
				if type(m) == "table" then
					ensureMemberBlockData(m)
					if type(m.blockHistory) == "table" and #m.blockHistory > 0 then
						local owner = History.MemberKey(m) or History.MemberKey({ name = key })
						for _, h in ipairs(m.blockHistory) do if type(h) == "table" then h.gk = gkey end end
						sources[#sources + 1] = { list = m.blockHistory, owner = owner, member = m.name or key }
					end
					m.blockHistory = nil
				end
			end
		end
		if #sources > 0 then History.Absorb(sources) end
		PourSocialScoreDB.historyFormat = 3
	end
	-- 2.0.37: every person keeps their newest 10 chat lines, 5 emotes,
	-- 5 party and 5 guild invites (PourSocialScoreDB.blockKeep) when lines
	-- leave the log. Lines are moved there, never copied or counted again.
	if (tonumber(PourSocialScoreDB.historyFormat) or 0) < 4 then
		History.Keep()
		PourSocialScoreDB.historyFormat = 4
	end
	-- keep the log within the setting (it may have been lowered); lines that
	-- leave it go to the per-player keep
	History.Trim(true)

	-- 2.0.4: Filter / Guild Inv / Group Inv and the members' Allow boxes
	-- became W I G P C. Convert every rule and member once.
	for _, g in pairs(PourSocialScoreDB.guildData or {}) do
		if type(g) == "table" then
			guildBlock(g)
			for _, m in pairs(g.members or {}) do if type(m) == "table" then memberBlock(m) end end
			refreshGuildActive(g)
		end
	end
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end

	-- 2.0.10: Scan Fields default to 1-60. Fill the empty ones once (a value
	-- you typed yourself is kept; you can clear it again afterwards).
	if not PourSocialScoreDB.scanFieldsDefaultV1 then
		for _, g in pairs(PourSocialScoreDB.guildData or {}) do
			if type(g) == "table" and (g.customScan == nil or trim(tostring(g.customScan)) == "") then
				g.customScan = M.PSS_DEFAULT_SCAN_FIELDS
			end
		end
		PourSocialScoreDB.scanFieldsDefaultV1 = true
	end

	-- Guild block data v2: history/counters live on members only. Older builds
	-- also kept a duplicate copy on the guild record; drop it.
	for _, g in pairs(PourSocialScoreDB.guildData or {}) do
		if type(g) == "table" then
			for _, m in pairs(g.members or {}) do
				if type(m) == "table" then
					-- guild invites used to share the "Allow Group Invites" box
					if m.excludedGroup == true and m.excludedGuildInvite == nil then m.excludedGuildInvite = true end
					compactMember(m)
				end
			end
			g.blockHistory = nil
			g.blockedWhispers, g.blockedPrivateMessages, g.blockedChatMessages, g.blockedInvites = nil, nil, nil, nil
			M.PSS_MigrateCustomScan(g)
		end
	end
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
end

local OLD_GUILD_FIELD = { declineGuild = "guildInvite", declineGroup = "partyInvite", partyRaid = "partyRaid" }
function M.PSS_SetGuildSetting(guildName, field, value)
	if M.PSS_EXCL_INFO[field] or OLD_GUILD_FIELD[field] then
		return M.PSS_SetGuildBlock(guildName, M.PSS_EXCL_INFO[field] and field or OLD_GUILD_FIELD[field], value)
	end
	local g = ensureGuild(guildName)
	if not g then return end
	g[field] = value == true
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end

function M.PSS_AddGuild(guildName)
	local g = ensureGuild(guildName)
	if not g then return end
	g.ruleOrigin = "manual"
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
end

-- canonPlayer / canonGuild are defined near the top of this file.

local function recountGuildMembers()
	for _, g in pairs(PourSocialScoreDB.guildData or {}) do
		if type(g) == "table" then
			g.members = g.members or {}
			g.memberCount = 0
			for _ in pairs(g.members) do g.memberCount = g.memberCount + 1 end
		end
	end
end

-- Merge one stored member record into another (settings kept, allow-flags
-- OR-ed, counters take the highest value).
-- Block history and counts are merged (not copied by reference), so a moved
-- player's blocked chat history arrives intact in the new guild rule.
local MERGE_SKIP = {
	blockCounts = true, blockHistory = true, _blockV2 = true, block = true,
	blockedWhispers = true, blockedPrivateMessages = true, blockedChatMessages = true, blockedInvites = true,
	privateMessagesBlocked = true, chatMessagesBlocked = true, partyInvitesBlocked = true,
	partyRaidMessagesBlocked = true,
}
local function mergeMemberRecord(existing, m)
	if existing == m then return end
	-- Bring both records to the current block-data format first, so legacy
	-- counters are never double counted.
	if M.PSS_EnsureMemberBlockData then
		M.PSS_EnsureMemberBlockData(existing)
		M.PSS_EnsureMemberBlockData(m)
	end
	for field, value in pairs(m) do
		if not MERGE_SKIP[field] and (existing[field] == nil or existing[field] == "") then existing[field] = value end
	end
	-- (only true is stored: a missing flag means false)
	for _, f in ipairs({ "excludedGroup", "excludedGuildInvite", "excludedWhispers", "excludedChat" }) do
		if m[f] == true then existing[f] = true end
	end
	-- W I G P C: keep the existing record's own choices, fill the gaps from m
	local eb, mb = memberBlockW(existing), memberBlock(m)
	for _, c in ipairs(EXCL_CATS) do
		if eb[c] == nil and mb[c] ~= nil then eb[c] = mb[c] end
	end
	if M.PSS_MergeMemberBlockData then M.PSS_MergeMemberBlockData(existing, m) end
end

-- Move every copy of a player stored under a guild rule OTHER than keepKey
-- into target (that rule's record for them): settings, exclusions and block
-- history are merged, then the old copies are removed. Returns how many
-- copies were moved.
function M.PSS_MoveOtherCopies(playerName, keepKey, target)
	local ck = canonPlayer(playerName)
	if not ck or type(target) ~= "table" then return 0 end
	local moved = 0
	for gkey, g in pairs(PourSocialScoreDB.guildData or {}) do
		if gkey ~= keepKey and type(g) == "table" and type(g.members) == "table" then
			local doomed = {}
			for k, m in pairs(g.members) do
				if type(m) == "table" and m ~= target then
					local mk = canonPlayer(type(k) == "string" and k or nil) or canonPlayer(m._playerKey) or canonPlayer(m.name)
					if mk == ck then doomed[#doomed + 1] = k end
				end
			end
			for _, k in ipairs(doomed) do
				keepManaged(target)
				mergeMemberRecord(target, g.members[k])
				g.members[k] = nil
				moved = moved + 1
			end
			if #doomed > 0 then
				g.memberCount = 0
				for _ in pairs(g.members) do g.memberCount = g.memberCount + 1 end
				refreshGuildActive(g)
			end
		end
	end
	-- a shipped member of ANOTHER managed guild: they left it
	local sk = staticGuildOf(ck)
	if sk and sk ~= keepKey then
		local r = vkeep[ck] or vcache[ck]
		if r and r ~= target and r._gkey == sk then keepManaged(target); mergeMemberRecord(target, r) end
		tombstone(sk, ck)
		moved = moved + 1
	end
	if moved > 0 then markMemberIndexDirty() end
	return moved
end

-- GUILD EXCLUSION LIST
-- Exact guild names (case-insensitive) that no guild rule ever applies to:
-- a broad rule like "Olympus" would otherwise catch <Olympus Friends> too.
-- Their members are not blocked, not captured by scans, searches or invites,
-- and belong to no rule. Saved as PourSocialScoreDB.guildExclusions[canon] = display name.
local function exclusions()
	if type(PourSocialScoreDB) ~= "table" then return {} end
	if type(PourSocialScoreDB.guildExclusions) ~= "table" then PourSocialScoreDB.guildExclusions = {} end
	return PourSocialScoreDB.guildExclusions
end

function M.PSS_IsGuildExcluded(actualGuild)
	local ck = canonGuild(actualGuild)
	return ck ~= nil and exclusions()[ck] ~= nil
end

-- Sorted list of excluded guild names.
function M.PSS_GuildExclusions()
	local list = {}
	for _, name in pairs(exclusions()) do list[#list + 1] = tostring(name) end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

-- Returns true when added, false when already listed, nil for an empty name.
function M.PSS_AddGuildExclusion(name)
	local ck = canonGuild(name)
	if not ck then return nil end
	local ex = exclusions()
	if ex[ck] then return false end
	ex[ck] = trim(name):gsub("%s+", " ")
	markMemberIndexDirty()
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	return true
end

function M.PSS_RemoveGuildExclusion(name)
	local ck = canonGuild(name)
	local ex = exclusions()
	if not ck or not ex[ck] then return false end
	ex[ck] = nil
	markMemberIndexDirty()
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	return true
end

-- The saved guild rule that a given ACTUAL guild name belongs to: the rule with
-- the longest name contained in it (so "Olympus Tycoons" beats "Olympus" for a
-- member of <Olympus Tycoons>, and an exact match always wins).
function M.PSS_BestGuildRowFor(actualGuild)
	ensureDB()
	local ac = canonGuild(actualGuild)
	if not ac then return nil end
	if M.PSS_IsGuildExcluded(actualGuild) then return nil end	-- excluded guilds belong to no rule
	local bestKey, bestG, bestLen
	for key, g in pairs(PourSocialScoreDB.guildData or {}) do
		if type(g) == "table" then
			local rc = canonGuild(g.name or key)
			if rc and ac:find(rc, 1, true) and (not bestLen or #rc > bestLen) then
				bestKey, bestG, bestLen = key, g, #rc
			end
		end
	end
	return bestKey, bestG
end

-- Validate stored data: every member whose recorded actual guild belongs to a
-- different (more specific) saved rule is moved there and every stray copy is
-- removed. Members with no recorded guild are left alone. Returns moved count.
function M.PSS_ReconcileGuildMembers()
	ensureDB()
	local guilds = PourSocialScoreDB.guildData or {}
	local moves = {}
	for srcKey, src in pairs(guilds) do
		if type(src) == "table" and type(src.members) == "table" then
			for storedKey, m in pairs(src.members) do
				if type(m) == "table" and canonGuild(m.guild) then
					local bestKey = M.PSS_BestGuildRowFor(m.guild)
					if bestKey and bestKey ~= srcKey then
						moves[#moves + 1] = { srcKey = srcKey, storedKey = storedKey, dstKey = bestKey }
					end
				end
			end
		end
	end
	if #moves == 0 then return 0 end

	local dstIndex = {}		-- dstKey -> canon -> storedKey
	local function indexFor(dstKey)
		local idx = dstIndex[dstKey]
		if not idx then
			idx = {}
			for k, mm in pairs(guilds[dstKey].members) do
				local ck = canonPlayer(type(k) == "string" and k or nil) or (type(mm) == "table" and canonPlayer(mm.name))
				if ck then idx[ck] = k end
			end
			dstIndex[dstKey] = idx
		end
		return idx
	end

	local movedCanon, moved = {}, 0
	for _, mv in ipairs(moves) do
		local src, dst = guilds[mv.srcKey], guilds[mv.dstKey]
		local m = src and src.members and src.members[mv.storedKey]
		if m and dst then
			dst.members = dst.members or {}
			local ck = canonPlayer(type(mv.storedKey) == "string" and mv.storedKey or nil) or canonPlayer(m.name)
			local idx = indexFor(mv.dstKey)
			local tKey = ck and idx[ck]
			local existing = tKey and dst.members[tKey]
			if not existing then
				tKey = mv.storedKey
				existing = {}
				dst.members[tKey] = existing
				if ck then idx[ck] = tKey end
			end
			mergeMemberRecord(existing, m)
			existing._playerKey = existing._playerKey or normalizePlayer(existing.name or tKey) or tKey
			src.members[mv.storedKey] = nil
			if ck then movedCanon[ck] = mv.dstKey end
			moved = moved + 1
		end
	end

	-- Remove any remaining copy of a moved player from every rule except the
	-- one that now owns them.
	for srcKey, src in pairs(guilds) do
		if type(src) == "table" and type(src.members) == "table" then
			local doomed = {}
			for storedKey, mm in pairs(src.members) do
				local ck = canonPlayer(type(storedKey) == "string" and storedKey or nil)
					or (type(mm) == "table" and canonPlayer(mm.name))
				if ck and movedCanon[ck] and movedCanon[ck] ~= srcKey then doomed[#doomed + 1] = storedKey end
			end
			for _, k in ipairs(doomed) do src.members[k] = nil end
		end
	end

	recountGuildMembers()
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	return moved
end

-- Promote an exact guild name to its own guild rule.
--   ADD    : every player stored under ANY other saved guild rule whose actual
--            guild is `actualGuild` is copied into the new rule (settings and
--            counters preserved, whitelist flags OR-ed together).
--   REMOVE : every reference to those players is then deleted from ALL other
--            guild rules, and the result is re-checked.
-- Returns added, migrated, removedRefs, perSource, leftover
--   added      = players new to the target rule
--   migrated   = added + players the target already had
--   perSource  = { {name=, moved=} ... } per old guild rule
--   leftover   = references still present in other rules after cleanup (expected 0)
function M.PSS_AddCapturedGuild(actualGuild, fromGroup)
	ensureDB()
	actualGuild = trim(actualGuild or "")
	local targetKey = normalizeGuild(actualGuild)
	local targetCanon = canonGuild(actualGuild)
	if not targetKey or not targetCanon then return 0, 0, 0, {}, 0 end

	local target = ensureGuild(actualGuild)
	if not target then return 0, 0, 0, {}, 0 end
	target.ruleOrigin = "manual"
	-- promoted from a managed group's guild: it joins that group's list
	if fromGroup and not target.managed then target.managed = fromGroup; target.managedGone = target.managedGone or {} end
	target.name = actualGuild
	target.members = target.members or {}

	local playerData = PourSocialScoreDB.playerData or {}

	---------------------------------------------------------------- collect
	-- Search every OTHER guild rule for players whose recorded actual guild
	-- (member.guild, or playerData.currentGuild as a fallback) is the target.
	local hits, order = {}, {}
	for sourceKey, source in pairs(PourSocialScoreDB.guildData or {}) do
		if sourceKey ~= targetKey and type(source) == "table" and type(source.members) == "table" then
			for storedKey, member in pairs(source.members) do
				if type(member) == "table" then
					local ck = canonPlayer(type(storedKey) == "string" and storedKey or nil)
						or canonPlayer(member._playerKey) or canonPlayer(member.name)
					if ck then
						local pd = playerData[storedKey] or (member._playerKey and playerData[member._playerKey])
						if canonGuild(member.guild) == targetCanon
							or (pd and canonGuild(pd.currentGuild) == targetCanon) then
							local rec = hits[ck]
							if not rec then
								rec = { canon = ck, list = {}, player = pd }
								hits[ck] = rec
								order[#order + 1] = rec
							end
							rec.list[#rec.list + 1] = { sourceKey = sourceKey, storedKey = storedKey, member = member }
						end
					end
				end
			end
		end
	end

	-- Existing target members, indexed canonically so we never create a
	-- second copy of a player the target rule already holds.
	local targetIndex = {}
	for storedKey, member in pairs(target.members) do
		if type(member) == "table" then
			local ck = canonPlayer(type(storedKey) == "string" and storedKey or nil) or canonPlayer(member.name)
			if ck then targetIndex[ck] = storedKey end
		end
	end

	------------------------------------------------------------------- add
	local added, alreadyThere = 0, 0
	local perSource = {}
	local movedCanon = {}

	for _, rec in ipairs(order) do
		local tKey = targetIndex[rec.canon]
		local existing = tKey and target.members[tKey]
		if existing then
			alreadyThere = alreadyThere + 1
		else
			tKey = rec.list[1].storedKey
			existing = {}
			target.members[tKey] = existing
			targetIndex[rec.canon] = tKey
			added = added + 1
		end

		for _, hit in ipairs(rec.list) do
			-- Settings kept, allow-flags OR-ed, and the player's blocked chat
			-- history + counts carried across into the new guild rule.
			mergeMemberRecord(existing, hit.member)
		end
		existing.name = displayPlayer(existing.name or tKey)
		existing._playerKey = existing._playerKey or normalizePlayer(existing.name) or tKey
		existing.guild = actualGuild
		if rec.player then
			rec.player.currentGuild = actualGuild
		end
		movedCanon[rec.canon] = true
	end

	---------------------------------------------------------------- remove
	-- Remove EVERY reference to every promoted player from EVERY other rule.
	local function purge()
		local removed = 0
		for sourceKey, source in pairs(PourSocialScoreDB.guildData or {}) do
			if sourceKey ~= targetKey and type(source) == "table" and type(source.members) == "table" then
				local doomed = {}
				for storedKey, member in pairs(source.members) do
					local ck = canonPlayer(type(storedKey) == "string" and storedKey or nil)
						or (type(member) == "table" and (canonPlayer(member._playerKey) or canonPlayer(member.name)))
					if ck and movedCanon[ck] then doomed[#doomed + 1] = storedKey end
				end
				for _, storedKey in ipairs(doomed) do
					source.members[storedKey] = nil
					removed = removed + 1
				end
				if #doomed > 0 then
					perSource[#perSource + 1] = { name = source.name or sourceKey, moved = #doomed }
				end
			end
		end
		return removed
	end

	local removedRefs = purge()

	-- Verify: a second pass must find nothing left behind.
	local leftover = 0
	for sourceKey, source in pairs(PourSocialScoreDB.guildData or {}) do
		if sourceKey ~= targetKey and type(source) == "table" and type(source.members) == "table" then
			for storedKey, member in pairs(source.members) do
				local ck = canonPlayer(type(storedKey) == "string" and storedKey or nil)
					or (type(member) == "table" and (canonPlayer(member._playerKey) or canonPlayer(member.name)))
				if ck and movedCanon[ck] then leftover = leftover + 1 end
			end
		end
	end

	recountGuildMembers()
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	table.sort(perSource, function(a, b) return (a.moved or 0) > (b.moved or 0) end)
	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	return added, added + alreadyThere, removedRefs, perSource, leftover
end

function M.PSS_GetGuildRemovalInfo(guildNameOrKey)
	ensureDB()
	local key = normalizeGuild(guildNameOrKey)
	local g = key and PourSocialScoreDB.guildData[key]
	if not g then return nil, 0, 0 end
	local members = g.members or {}
	local memberCount = 0
	local globalCount = 0
	for memberKey in pairs(members) do
		memberCount = memberCount + 1
		for i, ignoredName in ipairs(PourSocialScoreDB.ignoreList or {}) do
			if normalizePlayer(ignoredName) == memberKey and PourSocialScoreDB.typeList[i] == "player" then
				globalCount = globalCount + 1
				break
			end
		end
	end
	return g, memberCount, globalCount
end

function M.PSS_RemoveGuild(guildNameOrKey)
	ensureDB()
	local key = normalizeGuild(guildNameOrKey)
	local g = key and PourSocialScoreDB.guildData[key]
	if not g then return 0, 0, false end
	if isStaticGuild(key) then return 0, 0, false end	-- shipped guilds can't be removed

	local memberKeys = {}
	local memberCount = 0
	for memberKey in pairs(g.members or {}) do
		memberKeys[memberKey] = true
		memberCount = memberCount + 1
	end

	-- The Player Ignore List is NOT touched: players you ignored yourself
	-- stay ignored when a guild rule they were captured under is removed.
	-- (2.0.8 also deleted every Player Ignore List entry with a member's name.)
	local removedGlobal = 0

	PourSocialScoreDB.guildData[key] = nil
	if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
	if M.PSSGuildTabFrame then M.PSSGuildTabFrame.selectedGuildKey = nil end
	if PourSocialScoreDB.playerData then
		for memberKey in pairs(memberKeys) do
			-- Keep playerData if the player is still present elsewhere in the
			-- Pour Social Score; otherwise discard the guild-only metadata.
			if M.hasGlobalIgnored then
				local stillIgnored = false
				for _, ignoredName in ipairs(PourSocialScoreDB.ignoreList or {}) do
					if normalizePlayer(ignoredName) == memberKey then stillIgnored = true break end
				end
				if not stillIgnored then PourSocialScoreDB.playerData[memberKey] = nil end
			end
		end
	end

	if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
	if M.PSSUpdateUI then M.PSSUpdateUI(true) end
	return removedGlobal, memberCount, true
end

cleanupLegacyGuildPlayers = function()
	ensureDB()
	if PourSocialScoreDB.guildPlayerCleanupV3 then return end
	local guildMembers = {}
	for _, g in pairs(PourSocialScoreDB.guildData or {}) do
		for key, m in pairs(g.members or {}) do
			guildMembers[key] = guildMembers[key] or {}
			guildMembers[key][m.whenBlocked or ""] = true
		end
	end
	PourSocialScoreDB.ignoreList = PourSocialScoreDB.ignoreList or {}
	for i = #PourSocialScoreDB.ignoreList, 1, -1 do
		local name = PourSocialScoreDB.ignoreList[i]
		local key = normalizePlayer(name)
		local p = PourSocialScoreDB.playerData and PourSocialScoreDB.playerData[key]
		if key and p and guildMembers[key] and guildMembers[key][p.whenBlocked or ""] then
			table.remove(PourSocialScoreDB.ignoreList, i)
			table.remove(PourSocialScoreDB.factionList, i)
			table.remove(PourSocialScoreDB.dateList, i)
			table.remove(PourSocialScoreDB.notes, i)
			table.remove(PourSocialScoreDB.expList, i)
			table.remove(PourSocialScoreDB.typeList, i)
			table.remove(PourSocialScoreDB.syncInfo, i)
			PourSocialScoreDB.playerData[key] = nil
		end
	end
	PourSocialScoreDB.guildPlayerCleanupV3 = true
end

------------------------------------------------------------------------
-- GUILD ENTRY ROWS (Guild Ignore List tab, top right)
--
-- Each row is the shared EntryRow widget (PSS_Widgets.lua): a box, Guild
-- Search and Add Guild. This fills in what both guild rows share.
------------------------------------------------------------------------
local function pssSay(msg)
	M.ChatMsg("PSS: " .. msg)
end
M.PSS_Say = pssSay

local function canSendWho() return not Whois.BlockedMsg() end

local function createGuildEntryRow(frame, opts)
	opts.searchText = "Guild Search"
	opts.addText	= "Add Guild"
	opts.canSend	= canSendWho
	opts.say		= pssSay
	local row = M.Widgets.EntryRow(frame, opts)
	registerGuildScanButton(row.search)
	return row
end

function M.PSS_BuildGuildUI(parent)
	if M.PSSGuildTabFrame then return M.PSSGuildTabFrame end
	local UI = M.UI

	-- Same panel as every other tab (see PSS_UIKit.lua).
	local frame = CreateFrame("Frame", "PSSGuildTabFrame", parent, "InsetFrameTemplate")
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -84)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -11, 29)
	M.PSSGuildTabFrame = frame

	-- no title in list view (the tab says where you are); Block History uses it
	frame.title = UI.CreateSummary(frame, "", 700)
	frame.stats = UI.CreateBlockStats(frame, parent, UI.STATS_BLOCK_CATS, "messages and invites")

	-- top right, two rows built the same way (see createGuildEntryRow):
	--   [ Add a Guild...     ] [Guild Search] [Add Guild]   -> Guild Ignore List
	--   [ Exclude a Guild... ] [Guild Search] [Add Guild]   -> Guild Exclusion List
	local ignoreRow = createGuildEntryRow(frame, {
		hint		= "Add a Guild...",
		listName	= "Guild Ignore List",
		emptyMsg	= "Type part of a guild name in the box next to Guild Search first.",
		searchTip = {
			"Runs a /who and lists every guild found (not the players).",
			"Type part of a guild name, or a full /who filter containing quotes, e.g. g-\"Name\" 10-80",
		},
		isListed	= function(name)
			return PourSocialScoreDB.guildData[normalizeGuild(name)] ~= nil
		end,
		add			= function(name) M.PSS_AddGuild(name) end,
		search		= function(text) return M.PSS_GuildSearch(text) end,
	})
	frame.addButton, frame.searchButton, frame.searchBox = ignoreRow.add, ignoreRow.search, ignoreRow.box

	local exclRow = createGuildEntryRow(frame, {
		below		= ignoreRow,
		hint		= "Exclude a Guild...",
		listName	= "Guild Exclusion List",
		emptyMsg	= "Type a guild name in the box beneath Guild Search first.",
		searchTip = {
			"Runs a /who for the guild name in the box and lets you pick which guilds found go on the Guild Exclusion List. If none is found you can add the name anyway.",
			"Excluded guilds are never blocked by a guild rule, even one whose name they contain (a rule for \"Olympus\" no longer catches an excluded <Olympus Friends>).",
		},
		isListed	= function(name) return M.PSS_IsGuildExcluded(name) end,
		add			= function(name) M.PSS_AddGuildExclusion(name) end,
		search		= function(text)
			-- always a guild name here, never a raw /who filter
			return M.PSS_GuildSearch((text:gsub('"', "")), "exclude")
		end,
		clearOnSearch = true,
	})
	frame.exclAddButton, frame.exclSearchButton, frame.exclBox = exclRow.add, exclRow.search, exclRow.box

	-- Scan All: the next /who of the guild sweep, across every guild row.
	-- (Both boxes are 150 wide, leaving room for it before the summary text.)
	local scanAll = UI.TopButton(frame, "Scan All", ignoreRow.box, 80, "PSSGuildScanAllButton")
	scanAll:ClearAllPoints()
	scanAll:SetPoint("RIGHT", ignoreRow.box, "LEFT", -10, 0)
	scanAll:SetScript("OnClick", function() M.PSS_ScanAll() end)	-- /who first, UI after
	scanAll:SetScript("OnEnter", function(self) M.PSS_ScanTipEnter(self, nil) end)
	scanAll:SetScript("OnLeave", function() M.PSS_ScanTipLeave() end)
	registerGuildScanButton(scanAll)
	frame.scanAllButton = scanAll

	-- Columns (every column sorts): the block metrics, then the per-guild
	-- W I G P C exclusions (tickboxes).
	local COLS = {
		{ key = "guild",	text = "Guild",		width = 150 },
		{ key = "members", text = "Members", width = 70, justify = "RIGHT" },
	}
	for _, c in ipairs(UI.MetricColumns()) do COLS[#COLS + 1] = c end
	for _, c in ipairs({
		{ key = "excl",		letters = "excl", width = UI.EXCL_W, lettersTitle = "Per-guild exclusions",
			lettersNote = "Ticked = allowed from every member of the guild, unticked = blocked. A member's own W I G P C (members window) wins." },
		{ key = "scan",		text = "Scan",		width = 86, tip = "Sweeps the guild with /who, one search per click: the whole guild first, then any answer capped at 50 is split by level bracket, class and single level. Scan n/m = searches sent / planned so far. Hover a Scan button for the full status. Sorts by searches sent this session." },
		{ key = "fields",	text = "Scan Fields", width = 120, tip = "Extra /who filters sent with the guild name by Custom Scan, e.g. 80  or  70-80 c-\"Mage\"." },
		{ key = "custom",	text = "Custom",	width = 72, tip = "Custom Scan: /who for the guild plus its Scan Fields. Sorts by whether Scan Fields are set." },
	}) do COLS[#COLS + 1] = c end

	-- Sorting: a new column sorts ascending, the same column again flips it.
	-- The tab always opens on guild name A-Z.
	frame.sortKey, frame.sortAsc = "guild", true
	local function onSort(key)
		if frame.sortKey == key then frame.sortAsc = not frame.sortAsc else frame.sortKey, frame.sortAsc = key, true end
		if frame.refresh then frame.refresh() end
	end
	local hr = UI.CreateHeaderRow(frame, COLS, 1, UI.HEADER_Y, onSort, { id = "guilds", onLayout = function(h)
		-- rows and the scroll area follow the new total width
		if frame.content then frame.content:SetWidth(math.max(frame.scroll:GetWidth() or 0, h.total)) end
		for _, r in ipairs(frame.rows or {}) do r:SetWidth(h.total) end
		for _, r in ipairs(frame.groupRows or {}) do r:SetWidth(h.total) end
		for _, r in ipairs(frame.exclRows or {}) do r:SetWidth(h.total) end
	end })
	frame.header = hr
	frame.headerButtons = hr.sortables
	local X, W = hr.x, hr.w
	frame.columns, frame.columnX = W, X

	local scroll, content = UI.ScrollList(frame, "PSSGuildListScroll", hr.total)
	frame.scroll = scroll
	frame.content = content
	frame.rows = {}

	---------------------------------------------------------------- bottom bar
	local removeBtn = UI.BarButton(frame, "Remove Guild")
	removeBtn:SetScript("OnClick", function()
		if frame.selectedGuildKey then M.PSS_RemoveGuildNow(frame.selectedGuildKey) end
	end)
	removeBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Remove Guild", 1, 1, 1)
		GameTooltip:AddLine("Removes the selected guild rule straight away.", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local histButton = UI.BarButton(frame, L["BUT_9"] or "Block History", removeBtn, nil, "PSSGuildBlockHistoryButton")
	histButton:SetScript("OnClick", function()
		if M.PSS_ShowGuildHistoryPanel then M.PSS_ShowGuildHistoryPanel(frame.selectedGuildKey) end
	end)
	histButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Block History", 1, 1, 1)
		GameTooltip:AddLine("Click a guild first to see only that guild. With no guild selected, every guild's history is shown.", nil, nil, nil, true)
		GameTooltip:AddLine("Double-click a guild for its members and each member's own history.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
	end)
	histButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame.historyButton = histButton
	frame.listButtons = { removeBtn, histButton }

	---------------------------------------------------------------- history
	-- the shared Block History panel (PSS_ChatHistory.lua), in place of the list
	local function setListShown(on)
		hr:SetShown(on)
		scroll:SetShown(on)
		for _, b in ipairs(frame.listButtons) do b:SetShown(on) end
	end
	local hist = History.CreatePanel(frame, {
		baseTitle = "",
		allText = "all guilds", allButton = "All Guilds",
		setListShown = setListShown,
		entries = function(key) return M.PSS_GetGuildBlockHistory(key) end,
		label = function(key)
			local g = PourSocialScoreDB.guildData[key]
			return g and tostring(g.name or key) or nil
		end,
		reset = function(key)
			if key then
				M.PSS_ResetGuildBlockHistory(key)
			else
				for k in pairs(PourSocialScoreDB.guildData or {}) do M.PSS_ResetGuildBlockHistory(k) end
				if M.PSS_Stats then M.PSS_Stats.Reset("guild") end
			end
		end,
		extra = { text = "Show Members", onClick = function(key) if key then M.PSS_ShowGuildDetail(key) end end,
					shown = function(key) return key ~= nil end },
	})
	frame.histPanel = hist
	local function updateHistoryPanel(resetScroll) hist:Refresh(resetScroll) end
	frame.updateHistoryPanel = updateHistoryPanel
	function M.PSS_ShowGuildHistoryPanel(guildKey)
		if not frame:IsShown() then return end
		hist:Open(guildKey)
	end
	local function closeHistoryPanel() hist:Close() end
	frame.closeHistoryPanel = closeHistoryPanel

	local function updateSelection()
		for _, r in ipairs(frame.rows) do
			r:SetSelected(r:IsShown() and r.guildKey ~= nil and r.guildKey == frame.selectedGuildKey)
		end
		local sel = frame.selectedGuildKey
		removeBtn:SetEnabled(sel ~= nil and PourSocialScoreDB.guildData[sel] ~= nil and not isStaticGuild(sel))
	end
	frame.updateSelection = updateSelection

	---------------------------------------------------------------- managed group headers
	-- One collapsible row per managed group ("Olympus"); its guilds are listed
	-- under it when expanded. Left-click toggles, right-click for options.
	frame.groupRows = {}
	local function groupOpen(k)
		PourSocialScoreDB.guildGroupOpen = type(PourSocialScoreDB.guildGroupOpen) == "table" and PourSocialScoreDB.guildGroupOpen or {}
		return PourSocialScoreDB.guildGroupOpen[k] == true
	end
	local function setGroupOpen(k, on)
		groupOpen(k)
		PourSocialScoreDB.guildGroupOpen[k] = on and true or nil
	end
	local function makeGroupRow(i)
		local row = UI.CreateRow(content, hr.total)
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetColorTexture(1, 0.82, 0, 0.08)
		row.label = UI.TCell(row, hr, "guild", "LEFT", "GameFontNormal")
		row.count = UI.TCell(row, hr, "members", "RIGHT")
		row.blocks = UI.CreateMetricCells(row, hr)
		row.state = UI.TCell(row, hr, "excl", "CENTER")
		row:SetScript("OnClick", function(self, button)
			local k = self.groupKey
			if not k then return end
			if button == "RightButton" then
				local on = M.PSS_ManagedGroupActive and M.PSS_ManagedGroupActive(k)
				MenuUtil.CreateContextMenu(UIParent, function(owner, root)
					root:CreateTitle(self.groupName or k)
					root:CreateButton(on and "Turn rule Off" or "Turn rule On", function()
						M.PSS_SetManagedGroupActive(k, not on)
						if frame.refresh then frame.refresh() end
					end)
					root:CreateButton(groupOpen(k) and "Collapse" or "Expand", function()
						setGroupOpen(k, not groupOpen(k))
						if frame.refresh then frame.refresh() end
					end)
				end)
				return
			end
			setGroupOpen(k, not groupOpen(k))
			if frame.refresh then frame.refresh() end
		end)
		row:SetScript("OnEnter", function(self)
			local k = self.groupKey
			if not k then return end
			local grp = M.PSS_ManagedGroups()[k] or {}
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine(self.groupName or k, 1, 0.82, 0)
			GameTooltip:AddLine(("Default guild list. Rule on the Chat Filters tab: %s (%s)."):format(tostring(grp.rule), tostring(grp.filter)), 1, 1, 1, true)
			GameTooltip:AddLine(M.PSS_ManagedGroupActive(k) and "|cff00ff00Rule is ON|r - its guilds are blocked (minus each guild's exclusions)."
				or "|cffff5555Rule is OFF|r - nothing in this group is blocked.", 1, 1, 1, true)
			GameTooltip:AddLine("Click to expand / collapse. Right-click to turn the rule on or off.", 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.groupRows[i] = row
		return row
	end

	---------------------------------------------------------------- exclusion list
	-- One collapsible "Guild Exclusion List" row (styled like a managed group)
	-- with its guilds listed under it when expanded.
	local EXCL_OPEN_KEY = "__exclusions"
	frame.exclRows = {}
	local function removeExclusion(name)
		if M.PSS_RemoveGuildExclusion(name) then
			M.ChatMsg(("PSS: <%s> removed from the Guild Exclusion List."):format(name))
		end
	end
	local function makeExclHeader()
		local row = UI.CreateRow(content, hr.total)
		local bg = row:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(row)
		bg:SetColorTexture(0.3, 0.8, 1, 0.08)
		row.label = UI.TCell(row, hr, "guild", "LEFT", "GameFontNormal")
		row.state = UI.TCell(row, hr, "excl", "CENTER")
		row:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				MenuUtil.CreateContextMenu(UIParent, function(owner, root)
					root:CreateTitle("Guild Exclusion List")
					root:CreateButton(groupOpen(EXCL_OPEN_KEY) and "Collapse" or "Expand", function()
						setGroupOpen(EXCL_OPEN_KEY, not groupOpen(EXCL_OPEN_KEY))
						if frame.refresh then frame.refresh() end
					end)
				end)
				return
			end
			setGroupOpen(EXCL_OPEN_KEY, not groupOpen(EXCL_OPEN_KEY))
			if frame.refresh then frame.refresh() end
		end)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine("Guild Exclusion List", 0.3, 0.8, 1)
			GameTooltip:AddLine("Guilds that no guild rule ever blocks, captures or scans in, even a rule whose name they contain or a default list such as Olympus.", 1, 1, 1, true)
			GameTooltip:AddLine("Add guilds with the second row of Guild Search / Add Guild (the \"Exclude a Guild...\" box).", 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine("Click to expand / collapse. Right-click a guild under it to remove it.", 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.exclHeader = row
		return row
	end
	local function makeExclRow(i)
		local row = UI.CreateRow(content, hr.total)
		row.name = UI.TCell(row, hr, "guild")
		row.state = UI.TCell(row, hr, "excl", "CENTER")
		row.remove = UI.TRowButton(row, hr, "scan", "Remove")
		row.remove:SetScript("OnClick", function() if row.exclName then removeExclusion(row.exclName) end end)
		row:SetScript("OnClick", function(self, button)
			if button ~= "RightButton" or not self.exclName then return end
			local name = self.exclName
			MenuUtil.CreateContextMenu(UIParent, function(owner, root)
				root:CreateTitle(name)
				root:CreateButton("Remove from Exclusion List", function() removeExclusion(name) end)
			end)
		end)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine(self.exclName or "", 1, 1, 1)
			GameTooltip:AddLine("Excluded: never blocked by a guild rule.", 0.3, 0.8, 1, true)
			GameTooltip:AddLine("Right-click or Remove to take it off the list.", 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.exclRows[i] = row
		return row
	end

	---------------------------------------------------------------- rows
	local function rowMenu(row)
		local guildKey = row.guildKey
		local guildName = row.guildName or guildKey
		frame.selectedGuildKey = guildKey
		updateSelection()
		local historyCount = #M.PSS_GetGuildBlockHistory(guildKey)
		MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
			root:CreateTitle(guildName)
			root:CreateDivider()
			root:CreateButton(L["HISTORY_GUILD"] .. " (" .. historyCount .. ")", function()
				if M.PSS_ShowGuildHistoryPanel then M.PSS_ShowGuildHistoryPanel(guildKey) end
			end)
			root:CreateButton("Show Members", function()
				if M.PSS_ShowGuildDetail then M.PSS_ShowGuildDetail(guildKey) end
			end)
			root:CreateDivider()
			root:CreateButton(L["HISTORY_RESET"], function()
				if M.PSS_ResetGuildBlockHistory then M.PSS_ResetGuildBlockHistory(guildKey or guildName) end
			end)
			if not isStaticGuild(guildKey) then
				root:CreateButton("Remove Guild", function() removeBtn:Click() end)
			end
			local gRec = guildKey and PourSocialScoreDB.guildData[guildKey]
			if gRec and M.PSS_AddOverrideMenu then
				M.PSS_AddOverrideMenu(root, gRec, "guild")
			end
		end)
	end

	local function makeRow(i)
		local row = UI.CreateRow(content, hr.total)
		row:SetScript("OnClick", function(self, button)
			if button == "RightButton" then rowMenu(self) return end
			local now = GetTime()
			if self._lastClick and self._lastClickKey == self.guildKey and now - self._lastClick < 0.35 then
				self._lastClick = nil
				frame.selectedGuildKey = self.guildKey
				updateSelection()
				if M.PSS_ShowGuildDetail then M.PSS_ShowGuildDetail(self.guildKey) end
			else
				frame.selectedGuildKey = self.guildKey
				updateSelection()
				self._lastClick = now
				self._lastClickKey = self.guildKey
			end
		end)

		row.name = UI.TCell(row, hr, "guild")
		row.count = UI.TCell(row, hr, "members", "RIGHT")
		row.blocks = UI.CreateMetricCells(row, hr)

		row.ex = UI.CreateExclusionBoxes(row, hr, "excl", function(box, cat)
			if row.guildKey then M.PSS_SetGuildBlock(row.guildKey, cat, UI.ExclBlocked(box)) end
		end, function(box, e)
			GameTooltip:AddLine(e.letter .. " - " .. e.label, 1, 1, 1, true)
			GameTooltip:AddLine(box:GetChecked() and "|cff00ff00Allowed|r for this guild." or "|cffff5555Blocked|r for this guild.", 1, 1, 1)
		end)

		row.scan = UI.TRowButton(row, hr, "scan", "Scan")
		row.scan:SetScript("OnLeave", function() M.PSS_ScanTipLeave() end)

		-- Custom Scan Fields: one free-text /who filter
		row.customScan = UI.TRowEditBox(row, hr, "fields", 128)
		row.customScan:SetAltArrowKeyMode(false)
		row.customScan:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine("Custom Scan Fields", 1, 1, 1)
			GameTooltip:AddLine("Extra /who filters sent with the guild name when you press Custom.", nil, nil, nil, true)
			GameTooltip:AddLine('Sent as: g-"' .. tostring(row.guildName or "Guild") .. '" <this text>', 0.7, 0.7, 0.7, true)
			GameTooltip:AddLine('Examples: 80   70-80   80 c-"Mage"   r-"Orc"   n-"ab"', 0.7, 0.7, 0.7, true)
			GameTooltip:Show()
		end)
		row.customScan:SetScript("OnLeave", function() GameTooltip:Hide() end)

		row.customScanButton = UI.TRowButton(row, hr, "custom", "Scan")

		registerGuildScanButton(row.scan)
		registerGuildScanButton(row.customScanButton)
		frame.rows[i] = row
		return row
	end

	local function refresh()
		ensureDB()
		-- Nothing to draw while hidden; OnShow refreshes.
		if not frame:IsVisible() then return end

		local S = M.PSS_Stats
		frame.stats:Set(1, S and S.Session("guild"))
		frame.stats:Set(2, S and S.Last24("guild"))
		frame.stats:Set(3, M.PSS_GetGuildBlockCounts())
		if hist:IsShown() then updateHistoryPanel() end

		for _, row in ipairs(frame.rows) do row:Hide() end
		for _, row in ipairs(frame.groupRows) do row:Hide() end
		for _, row in ipairs(frame.exclRows) do row:Hide() end
		if frame.exclHeader then frame.exclHeader:Hide() end

		-- top-level guilds, and each managed group's guilds
		local list, groups = {}, {}
		for key, g in pairs(PourSocialScoreDB.guildData or {}) do
			if type(g) == "table" then
				g.memberCount = M.PSS_GuildMemberCount(g, key)
				local item = { key = key, g = g, bc = M.PSS_GetGuildBlockCounts(key) }
				if g.managed then
					groups[g.managed] = groups[g.managed] or {}
					table.insert(groups[g.managed], item)
				else
					list[#list + 1] = item
				end
			end
		end

		local sortKey, asc = frame.sortKey or "guild", frame.sortAsc ~= false
		local group, cat = sortKey:match("^(%a+):(%a+)$")
		local function flag(v) return UI.ExclChecked(v == true) and 1 or 0 end		-- by tick (allowed)
		local function sortValue(item)
			local g, bc = item.g, item.bc
			if group == "metric" then return bc[cat] or 0
			elseif group == "excl" then return flag(guildBlock(g)[cat])
			elseif sortKey == "guild" then return string.lower(g.name or item.key or "")
			elseif sortKey == "members" then return g.memberCount or 0
			elseif sortKey == "scan" then return M.PSS_GuildSweepSent(item.key)
			elseif sortKey == "fields" then return string.lower(g.customScan or "")
			elseif sortKey == "custom" then return ((g.customScan or "") ~= "") and 1 or 0
			end
			return 0
		end
		local function sortItems(items)
			for _, item in ipairs(items) do
				item.sv = sortValue(item)
				item.nv = string.lower(item.g.name or item.key or "")
			end
			table.sort(items, function(a, b)
				if a.sv ~= b.sv then
					if asc then return a.sv < b.sv else return a.sv > b.sv end
				end
				-- ties: always guild name A-Z (then key, so the order is stable)
				if a.nv ~= b.nv then return a.nv < b.nv end
				return tostring(a.key) < tostring(b.key)
			end)
		end
		sortItems(list)
		hr:SetSort(sortKey, asc)
		if frame.selectedGuildKey and not PourSocialScoreDB.guildData[frame.selectedGuildKey] then
			frame.selectedGuildKey = nil
		end

		-- display order: managed groups (headers) first, then the other guilds
		local display = {}
		local gkeys = {}
		for k in pairs(groups) do gkeys[#gkeys + 1] = k end
		table.sort(gkeys)
		for _, k in ipairs(gkeys) do
			local items = groups[k]
			sortItems(items)
			local grp = M.PSS_ManagedGroups()[k] or {}
			local total, bc = 0, History.EmptyCounts()
			for _, it in ipairs(items) do
				total = total + (it.g.memberCount or 0)
				for c, v in pairs(it.bc) do bc[c] = (bc[c] or 0) + (tonumber(v) or 0) end
			end
			local open = groupOpen(k)
			display[#display + 1] = { header = true, groupKey = k, name = grp.name or k, guilds = #items, members = total, bc = bc, open = open }
			if open then
				local on = M.PSS_ManagedGroupActive(k)
				for _, it in ipairs(items) do it.inGroup = true; it.groupOn = on; display[#display + 1] = it end
			end
		end
		-- then the Guild Exclusion List (always shown, so it can be found)
		local excluded = M.PSS_GuildExclusions()
		local exclOpen = groupOpen(EXCL_OPEN_KEY)
		display[#display + 1] = { exclHeader = true, count = #excluded, open = exclOpen }
		if exclOpen then
			for _, name in ipairs(excluded) do display[#display + 1] = { exclItem = true, name = name } end
		end
		for _, it in ipairs(list) do display[#display + 1] = it end

		local rowHeight = UI.ROW_H
		content:SetWidth(math.max(scroll:GetWidth() or 0, hr.total))
		content:SetHeight(math.max(1, #display * rowHeight))

		local gi, hi, ei = 0, 0, 0
		for i, item in ipairs(display) do
			if item.exclHeader then
				local row = frame.exclHeader or makeExclHeader()
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
				row.label:SetText((item.open and "[-] " or "[+] ") .. "Guild Exclusion List" .. ("  |cffaaaaaa(%d guilds)|r"):format(item.count))
				row.state:SetText("|cff4dccffNever blocked|r")
				row:Show()
			elseif item.exclItem then
				ei = ei + 1
				local row = frame.exclRows[ei] or makeExclRow(ei)
				row.exclName = item.name
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
				row.name:SetText("      " .. item.name)
				row.state:SetText("|cff4dccffExcluded|r")
				row:Show()
			elseif item.header then
				hi = hi + 1
				local row = frame.groupRows[hi] or makeGroupRow(hi)
				row.groupKey, row.groupName = item.groupKey, item.name
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
				row.label:SetText((item.open and "[-] " or "[+] ") .. item.name .. ("  |cffaaaaaa(%d guilds)|r"):format(item.guilds))
				row.count:SetText(tostring(item.members))
				UI.SetMetricCells(row.blocks, item.bc)
				local on = M.PSS_ManagedGroupActive(item.groupKey)
				row.state:SetText(on and "|cff00ff00Rule ON|r" or "|cffff5555Rule OFF|r")
				row:Show()
			else
				gi = gi + 1
				local g, key = item.g, item.key
				local row = frame.rows[gi] or makeRow(gi)
				row.guildName = g.name
				row.guildKey = key
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
				row.name:SetText((item.inGroup and "      " or "") .. tostring(g.name))
				row.count:SetText(tostring(g.memberCount or 0))
				UI.SetMetricCells(row.blocks, item.bc)
				local gb = guildBlock(g)
				for c, box in pairs(row.ex) do box:SetChecked(UI.ExclChecked(gb[c] == true)) end
				if not row.customScan:HasFocus() then row.customScan:SetText(g.customScan or "") end
				row.scan:SetText(M.PSS_GuildSweepLabel(key))
				row.customScanButton:SetText("Scan")
				row.scan:SetEnabled(not M.PSS_ScanCooldownActive())
				row.customScanButton:SetEnabled(not M.PSS_ScanCooldownActive())
				-- a group whose rule is off: shown dimmed (nothing is blocked)
				row:SetAlpha((item.inGroup and not item.groupOn) and 0.55 or 1)
				row:Show()

				local function readCustom()
					-- reads the box into the saved setting; no widget changes
					g.customScan = trim(row.customScan:GetText() or "")
				end
				row.customScan:SetScript("OnEnterPressed", function(self) readCustom(); self:ClearFocus() end)
				row.customScan:SetScript("OnEditFocusLost", readCustom)
				row.scan:SetScript("OnClick", function()
					if M.PSS_ScanBlockedMsg() then return end
					M.PSS_ScanGuild(g.name, "sweep", IsShiftKeyDown())		-- /who first, UI after
				end)
				row.scan:SetScript("OnEnter", function(self) M.PSS_ScanTipEnter(self, g) end)
				row.customScanButton:SetScript("OnClick", function()
					if M.PSS_ScanBlockedMsg() then return end
					readCustom()
					M.PSS_ScanGuild(g.name, "custom")	-- /who first, UI after
					C_Timer.After(0, function() row.customScan:ClearFocus() end)
				end)
			end
		end
		updateSelection()
	end

	frame:SetScript("OnShow", function()
		-- Always come back to the list view, sorted by guild name A-Z.
		closeHistoryPanel()
		frame.sortKey, frame.sortAsc = "guild", true
		refresh()
	end)
	-- Re-flow the list when the main window is resized.
	frame:SetScript("OnSizeChanged", function(self, w)
		if w and w > 0 then hr:SetAvailableWidth(w - 28) end
		if frame:IsVisible() then refresh() end
	end)
	frame.refresh = refresh
	M.PSSUpdateGuildUI = refresh
	refresh()
	return frame
end

-- Guild members window columns (W I G P C = the Player Ignore List header)
local MEMBER_COLS = {
	{ key = "name",		text = "Name",		width = 150 },
	{ key = "guild",	text = "Guild",		width = 120 },
	{ key = "added",	text = "Added",		width = 124 },
	{ key = "note",		text = "Note",		width = 130 },
}
-- block metrics (same columns as the Player and Guild Ignore Lists), then W I G P C
for _, c in ipairs(M.UI.MetricColumns()) do MEMBER_COLS[#MEMBER_COLS + 1] = c end
for _, c in ipairs({
	{ key = "excl",		letters = "excl", width = 154, lettersTitle = "Per-player exclusions",
		lettersNote = "Ticked = allowed from that player, unticked = blocked. Dimmed boxes follow the guild's setting; click one to set it for that player, right-click to go back to the guild's setting." },
	{ key = "addGuild", text = "Guild Rule", width = 90, tip = "Add Guild appears when the player's actual guild is not this rule: it creates a rule for that guild and moves its members there." },
}) do MEMBER_COLS[#MEMBER_COLS + 1] = c end

function M.PSS_ShowGuildDetail(guildNameOrKey)
	ensureDB()
	local UI = M.UI

	-- Prefer the exact persisted guild key. This avoids accidentally creating a
	-- new empty guild object when a UI row is opened after a scan.
	local requestedKey = normalizeGuild(guildNameOrKey)
	local g = requestedKey and PourSocialScoreDB.guildData and PourSocialScoreDB.guildData[requestedKey]
	if not g then
		-- Compatibility: callers may still pass the display name.
		for key, candidate in pairs(PourSocialScoreDB.guildData or {}) do
			if normalizeGuild(candidate.name) == requestedKey then
				requestedKey, g = key, candidate
				break
			end
		end
	end
	if not g then return end

	g.members = g.members or {}
	local guildKey = requestedKey

	local f = M.PSSGuildDetailFrame
	if not f then
		-- Same window style as the main window. Above the main window whatever
		-- strata it was given in Options, so nothing can sit over this one.
		local hrWidth = 0
		for _, c in ipairs(MEMBER_COLS) do hrWidth = hrWidth + c.width end
		local winW = hrWidth + 2 + 28 + 19
		f = UI.CreateWindow("PSSGuildDetailFrame", "Guild Members", winW, 560,
			{ strata = "FULLSCREEN", minW = winW, minH = 320, saveKey = "guildDetail" })
		M.PSSGuildDetailFrame = f
		local inset = f.inset

		f.heading, f.count = UI.CreateSummary(inset, "", 360)
		-- the guild's block metrics (same table as every player/guild report)
		f.metrics = UI.CreateMetricsTable(inset)
		f.metrics:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -6)

		local search = UI.SearchBox(inset)
		search:ClearAllPoints()
		search:SetPoint("TOPRIGHT", f.metrics, "TOPLEFT", -20, 1)
		search:SetScript("OnTextChanged", function() if f.refresh then f.refresh() end end)
		f.search = search
		local hint = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hint:SetPoint("RIGHT", search, "LEFT", -10, 0)
		hint:SetText("Search:")

		f.sortKey, f.sortAsc = "name", true
		local function onSort(key)
			if f.sortKey == key then f.sortAsc = not f.sortAsc else f.sortKey, f.sortAsc = key, true end
			if f.refresh then f.refresh() end
		end
		f.hr = UI.CreateHeaderRow(inset, MEMBER_COLS, 1, UI.HEADER_Y, onSort, { id = "members", onLayout = function(h)
			f.tableWidth = h.total
			if f.content then f.content:SetWidth(math.max(f.scroll:GetWidth() or 0, h.total)) end
			for _, r in ipairs(f.rows or {}) do r:SetWidth(h.total) end
		end })
		f.tableWidth = f.hr.total
		inset:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then f.hr:SetAvailableWidth(w - 28) end end)

		local scroll, content = UI.ScrollList(inset, nil, f.tableWidth)
		f.scroll = scroll; f.content = content; f.rows = {}

		-- bottom bar: Remove Member (right), Block History
		local removeBtn = UI.BarButton(inset, "Remove Member")
		removeBtn:SetScript("OnClick", function()
			local r = f.selectedRow
			if r and r.member and M.PSS_RemoveGuildMember then
				M.PSS_RemoveGuildMember(f.guildKey, r.memberName, r.memberGuildKey, r.storedKey)
				f.selectedMember = nil
				if f.refresh then f.refresh() end
				if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
			end
		end)
		removeBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Remove Member", 1, 1, 1)
			GameTooltip:AddLine("Removes the selected player from this guild rule (not from the Player Ignore List).", nil, nil, nil, true)
			GameTooltip:Show()
		end)
		removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.removeButton = removeBtn

		local histBtn = UI.BarButton(inset, L["BUT_9"] or "Block History", removeBtn)
		histBtn:SetScript("OnClick", function()
			local m = f.selectedMember
			if m then
				M.PSS_ShowMemberBlockHistory(m, (m.guild and m.guild ~= "") and m.guild or f.guildName)
			elseif f.guildKey then
				M.PSS_ShowGuildBlockHistory(f.guildKey)
			end
		end)
		histBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Block History", 1, 1, 1)
			GameTooltip:AddLine("Click a player first to see only that player. With no player selected, the whole guild's history is shown.", nil, nil, nil, true)
			GameTooltip:Show()
		end)
		histBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

		-- show each W I G P C box: ticked = allowed (own choice or the
		-- guild's), dimmed = following the guild's setting
		function f.paintExclusions(r)
			local m = r.member
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			if not m or not gg or not r.ex then return end
			local own = memberBlock(m)
			for cat, c in pairs(r.ex) do
				c:SetChecked(UI.ExclChecked(memberBlocks(gg, m, cat)))
				c:SetAlpha(own[cat] == nil and 0.45 or 1)
			end
		end
		function f.updateSelection()
			f.selectedRow = nil
			for _, r in ipairs(f.rows) do
				local sel = r:IsShown() and r.member ~= nil and r.member == f.selectedMember
				r:SetSelected(sel)
				if sel then f.selectedRow = r end
			end
			removeBtn:SetEnabled(f.selectedRow ~= nil)
		end
	end

	f.guildKey = guildKey
	f.guildName = g.name or guildNameOrKey
	f.title:SetText("Guild Members: " .. tostring(f.guildName))
	if f.lastGuildKey ~= guildKey then f.selectedMember = nil end
	f.lastGuildKey = guildKey
	f:Show(); f:Raise()

	local function collectMembers()
		local all = {}
		local gg = PourSocialScoreDB.guildData[f.guildKey]
		if not gg or type(gg.members) ~= "table" then return all end
		-- Each guild rule shows ONLY the members stored under that rule
		-- (plus, for a managed guild, its shipped members).
		forEachMember(gg, f.guildKey, function(m, key)
			all[#all + 1] = { member = m, sourceKey = f.guildKey, storedKey = key }
		end, true)
		return all
	end

	local function sortValue(entry, key)
		local m = entry.member
		local mcat = key:match("^metric:(.+)$")
		if mcat then return tonumber(M.PSS_GetMemberBlockCounts(m)[mcat]) or 0 end
		local cat = key:match("^excl:(.+)$")
		if cat then
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			return UI.ExclChecked(gg and memberBlocks(gg, m, cat)) and 1 or 0	-- by tick (allowed)
		elseif key == "name" then return string.lower(m.name or "")
		elseif key == "guild" then return string.lower(m.guild or "")
		elseif key == "note" then return string.lower(m.note or "")
		elseif key == "added" then return parseTimeString(m.whenBlocked) or 0
		elseif key == "addGuild" then
			-- members whose actual guild differs from this rule (Add Guild shown)
			local ag = normalizeGuild(m.guild or "")
			return (ag and ag ~= "" and ag ~= normalizeGuild(f.guildName)) and 1 or 0
		end
		return 0
	end

	-- Save a note box into its member record.
	local function commitNote(r)
		if not r or not r.note or not r.member then return end
		local text = trim(r.note:GetText() or ""):sub(1, 25)
		if (r.member.note or "") ~= text then keepManaged(r.member) end
		r.member.note = (text ~= "") and text or nil
	end
	f.commitNote = commitNote

	local function makeRow(i)
		local hr = f.hr
		local r = UI.CreateRow(f.content, f.tableWidth)
		r:SetScript("OnClick", function(self, button)
			f.selectedMember = self.member
			f.updateSelection()
			if button == "RightButton" then
				-- per-player option overrides
				if self.member and M.PSS_AddOverrideMenu then
					MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
						root:CreateTitle(tostring(self.member.name))
						root:CreateButton(L["BUT_9"] or "Block History", function()
							M.PSS_ShowMemberBlockHistory(self.member, (self.member.guild ~= "" and self.member.guild) or f.guildName)
						end)
						M.PSS_AddOverrideMenu(root, self.member, "person")
					end)
				end
				return
			end
			local now = GetTime()
			if self._lastClick and now - self._lastClick < 0.35 and self.member then
				self._lastClick = nil
				M.PSS_ShowMemberBlockHistory(self.member, (self.member.guild ~= "" and self.member.guild) or f.guildName)
			else
				self._lastClick = now
			end
		end)
		r:SetScript("OnEnter", function(self)
			local m = self.member
			if not m then return end
			local c = M.PSS_GetMemberBlockCounts(m)
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddLine("Blocked from " .. tostring(m.name), 1, 1, 1)
			for _, cat in ipairs(CAT_ORDER) do
				GameTooltip:AddDoubleLine(CAT_LABEL[cat], tostring(c[cat] or 0), 0.8, 0.8, 0.8, 1, 1, 1)
			end
			GameTooltip:AddLine("Double-click for this player's block history.", 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)

		r.name = UI.TCell(r, hr, "name")
		r.guild = UI.TCell(r, hr, "guild")
		r.added = UI.TCell(r, hr, "added")

		-- Note (max 25 characters), saved on the member record
		r.note = UI.TRowEditBox(r, hr, "note", 25)
		r.note:SetScript("OnEditFocusGained", function() f.editingRow = r end)
		r.note:SetScript("OnEditFocusLost", function()
			f.commitNote(r)
			if f.editingRow == r then f.editingRow = nil end
			if f.refreshPending and f.refresh then f.refresh() end
		end)
		r.note:SetScript("OnEnterPressed", function(self) f.commitNote(r); self:ClearFocus() end)
		r.note:SetScript("OnEscapePressed", function(self)
			self:SetText(r.member and r.member.note or "")
			self:ClearFocus()
		end)

		-- W I G P C, bound to the member RECORD on this row (never a name
		-- lookup - realm spellings vary).
		r.ex = UI.CreateExclusionBoxes(r, hr, "excl", function(box, cat, button)
			local m = r.member
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			if not m or not gg then return end
			if button == "RightButton" then
				M.PSS_SetMemberBlock(gg, m, cat, nil)
			else
				M.PSS_SetMemberBlock(gg, m, cat, UI.ExclBlocked(box))
			end
			f.paintExclusions(r)
			if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end
			if box:IsMouseOver() and box:GetScript("OnEnter") then box:GetScript("OnEnter")(box) end
		end, function(box, e)
			local m = r.member
			local gg = PourSocialScoreDB.guildData[f.guildKey]
			GameTooltip:AddLine(e.letter .. " - " .. e.label, 1, 1, 1, true)
			if not m or not gg then return end
			local own = memberBlock(m)[e.cat]
			if own == nil then
				GameTooltip:AddLine("Following the guild: " .. (guildBlock(gg)[e.cat] and "|cffff5555blocked|r" or "|cff00ff00allowed|r"), 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Click to set it for this player.", 0.7, 0.7, 0.7)
			else
				GameTooltip:AddLine("Set for this player: " .. (own and "|cffff5555blocked|r" or "|cff00ff00allowed|r"), 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Right-click to follow the guild's setting again.", 0.7, 0.7, 0.7)
			end
		end)

		r.metrics = UI.CreateMetricCells(r, f.hr)

		r.addGuild = UI.TRowButton(r, hr, "addGuild", "Add Guild")
		r.addGuild:SetScript("OnClick", function()
			local actual = r.memberGuild
			local base = normalizeGuild(f.guildName)
			if actual and actual ~= "" and normalizeGuild(actual) ~= base and M.PSS_AddCapturedGuild then
				local srcG = PourSocialScoreDB.guildData[f.guildKey]
				local added, migrated, removedRefs, perSource, leftover = M.PSS_AddCapturedGuild(actual, srcG and srcG.managed)
				do
					local from = {}
					for _, s in ipairs(perSource or {}) do
						from[#from + 1] = ("%s (%d)"):format(s.name, s.moved)
					end
					M.ChatMsg(("PSS: Added guild %q. Added %d new member(s) (%d total matched). Removed %d old record(s)%s. Blocked history moved with them."):format(
						actual, added or 0, migrated or 0, removedRefs or 0,
						#from > 0 and (" from: " .. table.concat(from, ", ")) or ""))
					if (leftover or 0) > 0 then
						M.ChatMsg(("PSS: WARNING - %d old record(s) for %q could not be removed."):format(leftover, actual))
					end
				end
				if f.refresh then f.refresh() end
			end
		end)
		f.rows[i] = r
		return r
	end

	local function refresh(auto)
		if not PourSocialScoreDB.guildData[f.guildKey] then
			-- guild rule was removed while the window was open
			f:Hide()
			return
		end
		if f.editingRow then
			if auto then
				-- background refresh (a block came in) while a note is being
				-- typed: wait until editing finishes so rows don't move under it
				f.refreshPending = true
				return
			end
			local er = f.editingRow
			commitNote(er)
			f.editingRow = nil
			er.note:ClearFocus()
		end
		f.refreshPending = false
		local query = string.lower(trim(f.search:GetText() or ""))
		local rows = collectMembers()
		local filtered = {}
		for _, entry in ipairs(rows) do
			local m = entry.member
			local hay = string.lower((m.name or "") .. " " .. (m.guild or "") .. " " .. (m.note or ""))
			if query == "" or hay:find(query, 1, true) then filtered[#filtered + 1] = entry end
		end
		local key, asc = f.sortKey or "name", f.sortAsc ~= false
		for _, e in ipairs(filtered) do e.sv = sortValue(e, key); e.nv = string.lower(e.member.name or "") end
		table.sort(filtered, function(a, b)
			if a.sv ~= b.sv then
				if asc then return a.sv < b.sv else return a.sv > b.sv end
			end
			return a.nv < b.nv		-- stable tie-break by name
		end)
		f.hr:SetSort(key, asc)

		f.heading:SetText("Members of |cffffff00" .. tostring(f.guildName) .. "|r")
		f.count:SetText((#rows) .. " member" .. (#rows == 1 and "" or "s") .. " found" ..
			(query ~= "" and ((" (%d shown)"):format(#filtered)) or ""))
		f.metrics:Set(M.PSS_GetGuildBlockCounts(f.guildKey))
		local rowH = UI.ROW_H
		f.content:SetWidth(math.max(f.scroll:GetWidth() or 0, f.tableWidth))
		f.content:SetHeight(math.max(1, #filtered * rowH))
		for _, r in ipairs(f.rows) do r:Hide() end

		local baseGuild = normalizeGuild(f.guildName)
		for i, entry in ipairs(filtered) do
			local r = f.rows[i] or makeRow(i)
			local m = entry.member
			r.member = m
			r.memberName = m.name
			r.memberGuildKey = entry.sourceKey
			r.storedKey = entry.storedKey
			r.memberGuild = m.guild or ""
			r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.content, 0, -(i - 1) * rowH)
			r.name:SetText(m.name or "")
			local cc = m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
			if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(1, 1, 1) end
			r.guild:SetText(m.guild or "")
			r.added:SetText(m.whenBlocked or "")
			if not r.note:HasFocus() then r.note:SetText(m.note or "") end
			f.paintExclusions(r)
			UI.SetMetricCells(r.metrics, M.PSS_GetMemberBlockCounts(m))
			local actualGuild = normalizeGuild(m.guild or "")
			r.addGuild:SetShown(actualGuild ~= nil and actualGuild ~= "" and actualGuild ~= baseGuild)
			r:Show()
		end
		f.updateSelection()
	end

	f.refresh = refresh
	if f.search:GetText() ~= "" then
		f.search:SetText("")	-- OnTextChanged refreshes
	end
	refresh()
end

-- Remove a guild rule straight away (no confirmation) and report in chat.
function M.PSS_RemoveGuildNow(guildKey)
	local g = guildKey and PourSocialScoreDB.guildData[guildKey]
	if not g then return end
	if isStaticGuild(guildKey) then
		M.ShowMsg(("<%s> is part of the default guild list and can't be removed. Turn its rule off on the Chat Filters tab instead."):format(tostring(g.name or guildKey)))
		return
	end
	local name = g.name or guildKey
	local removedGlobal, memberCount = M.PSS_RemoveGuild(guildKey)
	M.ShowMsg(("Guild |cffffff00%s|r removed with its %d captured member(s). Your Player Ignore List was not changed.")
		:format(tostring(name), memberCount or 0))
end


------------------------------------------------------------------------
-- "guild" person source for the core (PSS_ChatBlock.lua)
--   W I G P C per guild rule, overridable per member (see EXCLUSIONS near
--   the top of this file). Guild chat of your own guild is never touched.
------------------------------------------------------------------------
local function gopt(key, e)
	local ctx = { person = e.m.opts, guild = e.g.opts }
	if M.PSS_Opt then return M.PSS_Opt(key, ctx) end
	return PourSocialScoreDB[key]
end

-- The lookup result of a listed member, kept for their next chat line
-- instead of a new table per line (checked against the current lookup, so
-- it is never stale). At most LOOKUP_KEEP people; then it starts over.
local LOOKUP_KEEP = 300
local lookupKept, lookupKeptCount = {}, 0

if M.PSS_RegisterBlockSource then
	M.PSS_RegisterBlockSource({
		id = "guild", order = 20, label = "Guild Ignore List",
		lookup = function(canon)
			local g, gkey, m, storedKey = lookupGuildMemberCanon(canon)
			if not g then return nil end
			local e = lookupKept[canon]
			if e and e.g == g and e.gkey == gkey and e.m == m and e.storedKey == storedKey then return e end
			e = { g = g, gkey = gkey, m = m, storedKey = storedKey }
			if lookupKept[canon] == nil then
				if lookupKeptCount >= LOOKUP_KEEP then lookupKept, lookupKeptCount = {}, 0 end
				lookupKeptCount = lookupKeptCount + 1
			end
			lookupKept[canon] = e
			return e
		end,
		decide = function(e, cat, ctx)
			local g, m = e.g, e.m
			-- a managed group blocks only while its Chat Filters rule is on
			if g.managed and not guildRuleActive(g) then return false end
			-- a guild on the Guild Exclusion List is never blocked by a guild rule
			if M.PSS_IsGuildExcluded(m.guild or g.name) then return false end
			if cat == "whisper" or cat == "partyInvite" or cat == "guildInvite" or cat == "partyRaid" or cat == "world" then
				return memberBlocks(g, m, cat)
			elseif cat == "duel" or cat == "trade" then
				-- only for members this rule blocks in some way
				local any = false
				for _, c in ipairs(EXCL_CATS) do if memberBlocks(g, m, c) then any = true break end end
				if not any then return false end
				return gopt(cat == "duel" and "declineDuel" or "declineTrade", e) ~= false
			end
			return false		-- guild/officer chat, achievements, notices
		end,
		record = function(e, cat, ctx)
			if cat == "duel" or cat == "trade" then return end
			local rc = (cat == "guildChat" or cat == "other") and "world" or cat
			-- counted once, here: a managed group's Chat Filters rule only
			-- switches it on or off and counts nothing itself
			recordGuildBlock(e.g, e.m, rc, ctx.event, ctx.msg,
				(cat == "partyInvite" or cat == "guildInvite") and CAT_LABEL[cat]
					or channelLabel(ctx.event, ctx.channelString, ctx.chNumber, ctx.chName), e.gkey)
		end,
		optionContext = function(e) return { person = e.m.opts, guild = e.g.opts } end,
		describe = function(e)
			return ("Guild Ignore List <%s> (%s), stored as %s, actual guild %s"):format(
				tostring(e.g.name), M.PSS_ExclusionText(e.g, e.m), tostring(e.storedKey), tostring(e.m.guild))
		end,
		-- A guild invite names the guild: capture an unscanned inviter of an
		-- ignored guild under the rule that owns that guild.
		inviteByGuild = function(inviter, guildName)
			if type(guildName) ~= "string" or guildName == "" then return nil end
			local bestKey, bestG = M.PSS_BestGuildRowFor(guildName)
			if not guildRuleActive(bestG) then return nil end
			local ick = canonPlayer(inviter)
			if bestG.managed and ick and isStaticMember(bestKey, ick) then
				-- shipped member: no stored record needed
				if isGone(bestG, ick) then bestG.managedGone[ick] = nil end
				local r = vrec(ick, bestKey)
				if r then r.guild = guildName; return { g = bestG, gkey = bestKey, m = r } end
			end
			local m = M.PSS_UpdateGuildMember(bestG.name or bestKey, inviter)
			if not m then return nil end
			m.guild = guildName
			m._playerKey = normalizePlayer(inviter)
			if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
			return { g = bestG, gkey = bestKey, m = m, storedKey = normalizePlayer(inviter) }
		end,
	})
end

------------------------------------------------------------------------
-- DIAGNOSTICS: /pssguild [status | test | chat | debug [all] | check]
------------------------------------------------------------------------
local function gp(msg) M.ChatMsg("|cff33ff99PSS guild:|r " .. msg) end

SLASH_PSSGUILD1 = "/pssguild"
SlashCmdList = SlashCmdList or {}
SlashCmdList["PSSGUILD"] = function(msg)
	msg = trim(msg or "")
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	ensureDB()
	local stats, dbg = M.PSS_CoreStats or {}, M.PSS_CoreDebug or {}

	if cmd == "debug" then
		if rest:lower() == "all" then
			dbg.allUntil = GetTime() + 120
			gp("debug ALL for 2 minutes: every chat line checked is reported, listed or not.")
			return
		end
		dbg.on = not dbg.on
		dbg.allUntil = 0
		gp("debug " .. (dbg.on and "ON - every line from a listed player or guild member is reported." or "OFF"))
		return
	end

	if cmd == "test" then
		-- Dry run across EVERY list (player + guild). Nothing is recorded.
		local name = rest
		if name == "" and UnitExists and UnitExists("target") and UnitIsPlayer and UnitIsPlayer("target") then
			local n, r = UnitName("target")
			name = (r and r ~= "") and (n .. "-" .. r) or n
		end
		if not name or name == "" then gp("usage: /pssguild test Name-Realm   (or target the player and type /pssguild test)") return end
		local ex = M.PSS_ExplainPerson(name)
		gp(("test %q -> lookup key %q"):format(name, tostring(ex.canon)))
		if #ex.sources == 0 then
			gp("|cffff5555NOT BLOCKED|r: not on the Player Ignore List and not stored under any guild rule.")
			gp("Guild rules only block characters captured by a guild Scan (or a guild invite). Run Scan (or Scan All) / Custom Scan on the guild, then /pssguild check " .. name)
			return
		end
		local labels = { whisper = "Whispers", partyRaid = "Party/Raid", world = "World chat", guildChat = "Guild chat",
						partyInvite = "Party invite", guildInvite = "Guild invite", duel = "Duel", trade = "Trade" }
		local order = { "whisper", "partyRaid", "world", "guildChat", "partyInvite", "guildInvite", "duel", "trade" }
		local any = {}
		for _, row in ipairs(ex.sources) do
			gp("listed: " .. tostring(row.describe or row.src.label))
			for _, cat in ipairs(order) do if row.blocked[cat] then any[cat] = true end end
		end
		for _, cat in ipairs(order) do
			gp(("  %-13s %s"):format(labels[cat], any[cat] and "|cff00ff00BLOCKED|r" or "|cffff5555shown|r"))
		end
		gp("A message is hidden if ANY list blocks it. If this says BLOCKED but you still see it, run /pssguild chat.")
		return
	end

	if cmd == "chat" then
		local CFU = type(ChatFrameUtil) == "table" and ChatFrameUtil or nil
		local getFilters = (CFU and CFU.GetMessageEventFilters) or ChatFrame_GetMessageEventFilters
		gp(("filter registration API: %s"):format(M.PSS_FilterAvailable and "found" or "|cffff5555MISSING - chat blocking cannot work|r"))
		for _, ev in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_PARTY" }) do
			local list = getFilters and getFilters(ev)
			local ours, n = false, 0
			if type(list) == "table" then
				for _, fn in pairs(list) do n = n + 1; if fn == M.PSS_CoreFilter then ours = true end end
			end
			local frames, shown = 0, 0
			for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 10) do
				local cf = _G["ChatFrame" .. i]
				if type(cf) == "table" and cf.IsEventRegistered and cf:IsEventRegistered(ev) then
					frames = frames + 1
					if cf:IsShown() then shown = shown + 1 end
				end
			end
			gp(("  %-17s filters: %s, ours: %s | Blizzard chat windows listening: %d (%d shown)"):format(
				ev, getFilters and tostring(n) or "?", getFilters and (ours and "|cff00ff00yes|r" or "|cffff5555NO|r") or "?", frames, shown))
		end
		local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
		local found = {}
		if isLoaded then
			for _, a in ipairs({ "Chattynator", "Prat-3.0", "Glass", "Chatter", "WIM", "ElvUI", "EllesmereUI", "BasicChatMods", "OlympusMute", "Asmonmute", "AsmonMute" }) do
				if isLoaded(a) then found[#found + 1] = a end
			end
		end
		gp("chat addons loaded: " .. (#found > 0 and table.concat(found, ", ") or "none detected"))
		gp("If Blizzard chat windows show 0 listening, another addon is drawing chat itself. Messages only disappear if that addon applies Blizzard's chat filters.")
		local lc = stats.lastChecked
		if lc and lc.event then gp(("last line checked: %s from %s, %d s ago"):format(lc.event, tostring(lc.name), math.floor(GetTime() - lc.at))) end
		return
	end

	if cmd == "check" then
		if rest == "" then gp("usage: /pssguild check Name-Realm") return end
		local ck = canonPlayer(rest)
		gp(("check %q -> lookup key %q"):format(rest, tostring(ck)))
		local g, gkey, m, storedKey = lookupGuildMember(rest)
		if g then
			local c = M.PSS_GetMemberBlockCounts(m)
			gp(("FOUND under rule <%s>, stored as %q, actual guild %q"):format(
				tostring(g.name), tostring(storedKey), tostring(m.guild)))
			gp(("exclusions (red = blocked): %s   guild: %s | blocked: W %d, PI %d, P/R %d, World %d, GI %d"):format(
				M.PSS_ExclusionText(g, m), M.PSS_ExclusionText(g), c.whisper, c.partyInvite, c.partyRaid, c.world, c.guildInvite))
		else
			gp("NOT FOUND in any guild rule. Stored members with the same character name:")
			local base = (rest:match("^([^%-]+)") or rest):lower()
			local n = 0
			for gk, gg in pairs(PourSocialScoreDB.guildData or {}) do
				for k, mm in pairs((type(gg) == "table" and gg.members) or {}) do
					if type(k) == "string" and k:match("^([^%-]+)") == base then
						n = n + 1
						gp(("  <%s> key %q name %q -> lookup key %q"):format(tostring(gg.name or gk), k,
							tostring(type(mm) == "table" and mm.name), tostring(canonPlayer(k))))
					end
				end
			end
			if n == 0 then gp("  none - this character has not been captured by a scan or invite yet.") end
		end
		if M.PSS_IsPlayerListed and M.PSS_IsPlayerListed(rest) then gp("also on the Player Ignore List.") end
		return
	end

	-- status (default)
	local bySrc = {}
	for id, n in pairs(stats.bySource or {}) do bySrc[#bySrc + 1] = id .. " " .. n end
	gp(("chat filter: %s | this session: %d lines checked, %d from listed people, %d hidden (%s), %d errors | all-time hidden: %d"):format(
		M.PSS_FilterAvailable and "registered" or "|cffff5555MISSING|r", stats.checked or 0, stats.personHits or 0, stats.hidden or 0,
		#bySrc > 0 and table.concat(bySrc, ", ") or "-", stats.errors or 0, tonumber(PourSocialScoreDB.hiddenTotal) or 0))
	if stats.lastError then gp("last error: " .. stats.lastError) end
	local gcs = M.PSS_GCState
	if gcs then
		local heap = (pcall(collectgarbage, "count") and collectgarbage("count") or 0) / 1024
		gp(("memory cleanup: %s, %d cycle(s) this session%s | game Lua heap (all addons): %.1f MB"):format(
			(M.PSS_Opt("gcEnabled") == false and "off") or (gcs.supported and (gcs.running and "running now" or "idle") or "not supported by this client"),
			gcs.cycles or 0, gcs.lastReason and (", last: " .. gcs.lastReason) or "", heap))
	end
	local list = {}
	for k, g in pairs(PourSocialScoreDB.guildData or {}) do if type(g) == "table" then list[#list + 1] = { k = k, g = g } end end
	table.sort(list, function(a, b) return tostring(a.g.name or a.k) < tostring(b.g.name or b.k) end)
	if #list == 0 then gp("no guild rules.") end
	for _, it in ipairs(list) do
		local n = 0
		for _ in pairs(it.g.members or {}) do n = n + 1 end
		local c = M.PSS_GetGuildBlockCounts(it.k)
		gp(("<%s> %s, %d members | W %d, PI %d, P/R %d, World %d, GI %d"):format(
			tostring(it.g.name or it.k), M.PSS_ExclusionText(it.g), n,
			c.whisper, c.partyInvite, c.partyRaid, c.world, c.guildInvite))
	end
	gp("commands: /pssguild test Name-Realm  |  /pssguild chat  |  /pssguild debug [all]  |  /pssguild check Name-Realm")
end
