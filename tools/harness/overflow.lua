-- Adds more block history than the 2,000 line cap to a save made by
-- make_data.lua (any version's shape), so the upgrade has to trim it:
--   Grunt-Realm (guild member): 8 old chat lines, 8 emotes, 8 party and
--     8 guild invites, 20 days before the test data
--   Filler-Realm (new member of Bad Guild): 2,100 whispers, 10 days before
-- Neither gets counters for these lines: the totals must not change when
-- the lines are moved, kept or trimmed. (2.0.1 had no member counters of
-- its own: its upgrade counts a member's lines once, so for that shape the
-- expected guild totals in <expectOut> include the new lines.)
--   lua5.1 tools/harness/overflow.lua <in.lua> <out.lua> [expectIn expectOut]
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local inFile, outFile, expectIn, expectOut = arg[1], arg[2], arg[3], arg[4]
local H = dofile(here .. "/wow_stub.lua")
dofile(inFile)
local db = PourSocialScoreDB
local t0 = 1790000000

local g = assert(db.guildData["bad guild"], "no Bad Guild")
local grunt = assert(g.members["grunt-realm"], "no Grunt")
local logShape = type(db.blockLog) == "table"
local oldShape = db.historyFormat == nil and not logShape		-- 2.0.1

local KINDS = {
	{ cat = "whisper", event = "CHAT_MSG_WHISPER", kind = "Whisper", text = "old text" },
	{ cat = "world", event = "CHAT_MSG_EMOTE", kind = "World Chat", text = "old emote" },
	{ cat = "partyInvite", event = "PARTY_INVITE", kind = "Group Invite", text = "old party" },
	{ cat = "guildInvite", event = "GUILD_INVITE", kind = "Guild Invite", text = "old guild" },
}

local function line(k, ts, msg, who)
	if oldShape then
		return { kind = k.kind, event = k.event, time = date("%d %b %Y %H:%M:%S", ts), message = msg, member = who }
	end
	return { ts = ts, cat = k.cat, event = k.event, member = who, message = msg }
end

-- oldest first
local gruntLines, fillerLines = {}, {}
local ts = t0 - 20 * 86400
for n = 1, 8 do
	for _, k in ipairs(KINDS) do
		ts = ts + 60
		gruntLines[#gruntLines + 1] = line(k, ts, k.text .. " " .. n, "Grunt-Realm")
	end
end
ts = t0 - 10 * 86400
for n = 1, 2100 do
	ts = ts + 10
	fillerLines[#fillerLines + 1] = line(KINDS[1], ts, "filler " .. n, "Filler-Realm")
end

-- the new member: Grunt's record without any counters
local filler = {}
for k, v in pairs(grunt) do if type(v) ~= "table" then filler[k] = v end end
filler.name, filler._playerKey = "Filler-Realm", "filler-realm"
for _, k in ipairs({ "blockedWhispers", "blockedChatMessages", "blockedInvites" }) do
	if filler[k] then filler[k] = 0 end
end
if type(grunt.blockCounts) == "table" then
	filler.blockCounts = { total = 0, whisper = 0, partyInvite = 0, guildInvite = 0, partyRaid = 0, world = 0, guildChat = 0, unknown = 0 }
end
if type(grunt.block) == "table" then filler.block = {} end
g.members["filler-realm"] = filler

if logShape then
	-- the shared log, oldest first: the new lines go in front
	local log = {}
	for _, h in ipairs(gruntLines) do h.o = "g:grunt-realm"; h.gk = "bad guild"; log[#log + 1] = h end
	for _, h in ipairs(fillerLines) do h.o = "g:filler-realm"; h.gk = "bad guild"; log[#log + 1] = h end
	for _, h in ipairs(db.blockLog) do log[#log + 1] = h end
	db.blockLog = log
else
	-- one list per member, newest first
	local function prepend(list, add)
		local out = {}
		for _, h in ipairs(list or {}) do out[#out + 1] = h end
		for i = #add, 1, -1 do out[#out + 1] = add[i] end
		return out
	end
	grunt.blockHistory = prepend(grunt.blockHistory, gruntLines)
	filler.blockHistory = prepend(nil, fillerLines)
end

local fh = assert(io.open(outFile, "w"))
fh:write("PourSocialScoreDB = ", H.serialize(db), "\n")
fh:close()
if expectIn and expectOut then
	local e = dofile(expectIn)
	if oldShape then
		local g = e.guild
		g.whisper = g.whisper + 8 + #fillerLines
		g.world, g.partyInvite, g.guildInvite = g.world + 8, g.partyInvite + 8, g.guildInvite + 8
		g.total = g.total + #gruntLines + #fillerLines
	end
	local fh2 = assert(io.open(expectOut, "w"))
	fh2:write("return ", H.serialize(e), "\n")
	fh2:close()
end
print(("overflow: +%d lines (%s shape)"):format(#gruntLines + #fillerLines, logShape and "log" or (oldShape and "2.0.1" or "2.0.8")))
