-- Rewrites a 2.0.18 SavedVariables file into the shape an older version
-- saved (for versions whose code is not in this repository). The shapes are
-- the ones the upgrade code in PSS_GuildIgnoreList.lua (PSS_UpgradeLegacyData),
-- PSS_ChatFilters.lua (PSS_ExpandFilters) and PSS_ChatHistory.lua converts,
-- as described in history.txt:
--   2.0.17 : same as 2.0.18 without the Cyrillic built-in filter (PSS0017)
--   2.0.8  : historyFormat 2: a block history list on every player, guild
--            member and chat filter (newest first, with counts), no shared
--            log, guild members saved in full (counters already folded in,
--            _blockV2); no 2.0.10+ one-time flags
--   2.0.1  : no historyFormat: player lines with kind / time text, player
--            counts as blockedWhisperMessages / blockedChatMessages /
--            blockedInvites only, member counters as blockedWhispers /
--            blockedChatMessages / blockedInvites,
--            chat filter history as the 50-slot ring buffer { m, s, t, c, n }
--            with filterBlockedLast, guild rules without W I G P C (enabled /
--            declineGroup / declineGuild / partyRaid), member Allow flags
--   lua5.1 tools/harness/downgrade.lua <in.lua> <out.lua> <2.0.17|2.0.8|2.0.1>
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local inFile, outFile, target = arg[1], arg[2], arg[3]
local H = dofile(here .. "/wow_stub.lua")
dofile(inFile)
local db = PourSocialScoreDB

local CAT_KIND = { whisper = "Whisper", partyInvite = "Group Invite", guildInvite = "Guild Invite",
	partyRaid = "Party/Raid", world = "World Chat", guildChat = "Guild Chat", unknown = "Unknown" }

local function copyEntry(e)
	return { ts = e.ts, cat = e.cat, event = e.event, channel = e.channel, member = e.member, message = e.message }
end

if target == "2.0.17" then
	db.builtinRules.PSS0017 = nil
	db.builtinStats.PSS0017 = nil
else
	-- managed (shipped) guild groups came in 2.0.14
	for k, g in pairs(db.guildData) do if g.managed then db.guildData[k] = nil end end
	db.managedDelta, db.managedGroups = nil, nil
	-- one-time flags of later versions (their upgrades run again)
	db.scanFieldsDefaultV1, db.optInFiltersV1, db.guildPlayerCleanupV3, db.historyTotal = nil, nil, nil, nil
	-- the shared log back onto its owners (log is oldest first)
	local players, members, filters = {}, {}, {}
	for key, p in pairs(db.playerData) do players["p:" .. key] = p; p.blockHistory = {} end
	for _, g in pairs(db.guildData) do
		for key, m in pairs(g.members or {}) do
			members["g:" .. key] = m
			m.blockHistory = {}
			-- saved in full before 2.0.29
			m.online, m.race, m.className = false, "Orc", "Warrior"
			m._blockV2 = true      -- counters already folded in (2.0.6+)
		end
	end
	for id, st in pairs(db.builtinStats) do
		st.blocked = { counts = st.blocked and st.blocked.counts }
		filters["f:" .. id] = st.blocked
	end
	for i, text in ipairs(db.filterList) do
		db.filterBlocked[i] = { counts = db.filterBlocked[i] and db.filterBlocked[i].counts }
		if (db.filterID[i] or "") == "" then filters["f:t:" .. text] = db.filterBlocked[i] end
	end
	for i = #db.blockLog, 1, -1 do
		local e = db.blockLog[i]
		local list = (players[e.o] and players[e.o].blockHistory) or (members[e.o] and members[e.o].blockHistory) or filters[e.o]
		assert(list, "no owner for " .. tostring(e.o))
		list[#list + 1] = copyEntry(e)
	end
	db.blockLog = nil
	db.historyFormat = 2

	if target == "2.0.1" then
		db.historyFormat = nil
		local function oldLine(e)
			return { kind = CAT_KIND[e.cat], event = e.event, time = date("%d %b %Y %H:%M:%S", e.ts), message = e.message, member = e.member }
		end
		for _, p in pairs(db.playerData) do
			for i, e in ipairs(p.blockHistory) do p.blockHistory[i] = oldLine(e) end
			p.blockCounts = nil
		end
		for _, g in pairs(db.guildData) do
			g.block = nil
			for _, m in pairs(g.members or {}) do
				for i, e in ipairs(m.blockHistory) do m.blockHistory[i] = oldLine(e) end
				-- 2.0.1 kept counter fields, no blockCounts table
				m.blockedWhispers = m.blockCounts.whisper
				m.blockedChatMessages = m.blockCounts.partyRaid + m.blockCounts.world
				m.blockedInvites = m.blockCounts.partyInvite
				m.blockCounts, m._blockV2 = nil, nil
				m.block = nil
				m.excludedWhispers, m.excludedGroup, m.excludedGuildInvite, m.excludedChat = false, false, false, false
			end
		end
		-- chat filters: ring buffer, newest at filterBlockedLast
		local function ring(list)
			local out = {}
			for i = #list, 1, -1 do
				local e = list[i]
				local chNum = e.event == "CHAT_MSG_CHANNEL" and 2 or 0
				out[#out + 1] = { m = e.message, s = e.member, t = date("%Y.%m.%d %H:%M:%S", e.ts), c = chNum,
					n = chNum > 0 and "Trade" or (e.event or ""):sub(10) }
			end
			return out, #out
		end
		for _, st in pairs(db.builtinStats) do st.blocked, st.blockedLast = ring(st.blocked) end
		for i in ipairs(db.filterList) do db.filterBlocked[i], db.filterBlockedLast[i] = ring(db.filterBlocked[i]) end
	end
end

local fh = assert(io.open(outFile, "w"))
fh:write("PourSocialScoreDB = ", H.serialize(db), "\n")
fh:close()
print("wrote " .. target .. " shape to " .. outFile)
