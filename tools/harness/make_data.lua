-- Scenario: list a player, a guild with a member and a custom chat filter,
-- then block chat from each through the chat core. Works on 2.0.18 and
-- later. Writes the totals the version shows to PSS_EXPECT (a Lua file).
local db = PourSocialScoreDB
local lineID = tonumber(os.getenv("PSS_LINE") or "") or 1000

local function chat(event, msg, author)
	lineID = lineID + 1
	local r = M.PSS_CoreFilter(nil, event, msg, author, "", "", "", "", 0,
		event == "CHAT_MSG_CHANNEL" and 2 or 0, event == "CHAT_MSG_CHANNEL" and "Trade" or "", 0, lineID, nil)
	return r
end
_G.PSS_TestChat = chat

-- the listed player
M.PSS_AddPlayer("Spammer-Realm", "", 0)
-- the guild and one member
M.PSS_AddGuild("Bad Guild")
local gkey = M.PSS_NormalizeGuild("Bad Guild")
local g = db.guildData[gkey]
assert(g, "guild not added")
g.members = g.members or {}
g.members["grunt-realm"] = { name = "Grunt-Realm", guild = "Bad Guild", whenBlocked = "01 Oct 2026 10:00:00", _playerKey = "grunt-realm" }
if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
-- a custom chat filter (whispers are filtered too)
db.skipPrivate = false
local i = #db.filterList + 1
db.filterList[i], db.filterDesc[i], db.filterCount[i] = "[word=buygold]", "Gold test", 0
db.filterActive[i], db.filterID[i], db.filterBlocked[i], db.filterBlockedLast[i] = true, "", {}, 0
H.RunTimers()

-- what this version shows as totals
local function totals()
	local sum = { total = 0, whisper = 0, partyInvite = 0, guildInvite = 0, partyRaid = 0, world = 0 }
	-- (any version: the list's records from 3.4.1.51, the parallel arrays before)
	local function eachPlayer(fn)
		if M.PSS_List then
			for _, e in ipairs(M.PSS_List()) do if (e.kind or "player") == "player" then fn(e.name) end end
		else
			for idx, name in ipairs(db.ignoreList or {}) do if db.typeList[idx] == "player" then fn(name) end end
		end
	end
	eachPlayer(function(name)
		if M.PSS_GetPlayerRecord(name) then
			local c = M.PSS_GetPlayerBlockCounts(name)
			for k in pairs(sum) do sum[k] = sum[k] + (c[k] or 0) end
		end
	end)
	local gc = M.PSS_GetGuildBlockCounts()
	return {
		player = sum,
		guild = { total = gc.total, whisper = gc.whisper, partyInvite = gc.partyInvite, partyRaid = gc.partyRaid, world = gc.world, guildInvite = gc.guildInvite },
		filter = { total = db.filterTotal or 0, whisper = db.filterWhisperTotal or 0, private = db.filterPrivateTotal or 0 },
	}
end

local function round()
	local blocked = 0
	if chat("CHAT_MSG_WHISPER", "hello there", "Spammer-Realm") then blocked = blocked + 1 end
	if chat("CHAT_MSG_CHANNEL", "selling stuff", "Spammer-Realm") then blocked = blocked + 1 end
	if chat("CHAT_MSG_WHISPER", "join us", "Grunt-Realm") then blocked = blocked + 1 end
	if chat("CHAT_MSG_CHANNEL", "buygold cheap", "Random-Realm") then blocked = blocked + 1 end
	if chat("CHAT_MSG_WHISPER", "buygold here", "Other-Realm") then blocked = blocked + 1 end
	if chat("CHAT_MSG_BN_WHISPER", "buygold friend", "Friend") then blocked = blocked + 1 end
	H.RunTimers()
	return blocked
end

-- two days ago: one round (falls outside the 24 hour window), then
-- PSS_ROUNDS rounds in the last hours
local blocked = round()
local old = totals()
H.Advance(48 * 3600)
for _ = 1, tonumber(os.getenv("PSS_ROUNDS") or "") or 2 do
	blocked = blocked + round()
	H.Advance(600)
end

local function diff(a, b)
	local out = {}
	for k, v in pairs(a) do out[k] = v - (b[k] or 0) end
	return out
end
local expect = totals()
expect.blocked = blocked
expect.recent = { player = diff(expect.player, old.player), guild = diff(expect.guild, old.guild), filter = diff(expect.filter, old.filter) }
expect.logLines = db.blockLog and #db.blockLog or 0
expect.time = GetServerTime()
local out = os.getenv("PSS_EXPECT")
if out then
	local fh = assert(io.open(out, "w"))
	fh:write("return ", H.serialize(expect), "\n")
	fh:close()
end
print(("made data: %d blocked, player %d, guild %d, filter %d (%d/%d), log %d"):format(blocked, expect.player.total,
	expect.guild.total, expect.filter.total, expect.filter.whisper, expect.filter.private, expect.logLines))
