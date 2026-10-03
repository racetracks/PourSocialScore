-- Scenario (2.0.39): a shipped guild rule (InfluencerGuild=Olympus) with a
-- member found in game (stored in SavedVariables under one of its guilds).
-- Up to 2.0.38 each block was counted twice: on the guild and again on the
-- rule's Chat Filters row and total. Writes what the upgrade must show to
-- PSS_EXPECT. Works on 2.0.18 and later.
local db = PourSocialScoreDB
local lineID = 70000

local function whisper(author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "join olympus", author, "", "", "", "", 0, 0, "", 0, lineID, nil)
end

M.PSS_SetManagedGroupActive("olympus", true)
local keys = {}
for k, g in pairs(db.guildData) do if type(g) == "table" and g.managed == "olympus" then keys[#keys + 1] = k end end
table.sort(keys)
local gkey = assert(keys[1], "no managed guild rows")
local g = db.guildData[gkey]
g.members = g.members or {}
g.members["olyfound-realm"] = { name = "Olyfound-Realm", guild = g.name, whenBlocked = "01 Oct 2026 10:00:00", _playerKey = "olyfound-realm" }
if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
H.RunTimers()

local ruleIndex = M.PSS_ManagedGroupFilterIndex("olympus")
local blocked = 0
-- two days ago (outside the 24 hours), then two in the last hour
if whisper("Olyfound-Realm") then blocked = blocked + 1 end
H.Advance(48 * 3600)
for _ = 1, 2 do
	if whisper("Olyfound-Realm") then blocked = blocked + 1 end
	H.Advance(600)
end
H.RunTimers()
assert(blocked == 3, "found member not blocked: " .. blocked)
local doubled = tonumber(db.filterCount[ruleIndex]) or 0
local expect = {
	time = GetServerTime(), gkey = gkey, blocked = blocked,
	guild = M.PSS_GetGuildBlockCounts().total,
	oldFilterTotal = tonumber(db.filterTotal) or 0, oldRuleCount = doubled,
}
local fh = assert(io.open(assert(os.getenv("PSS_EXPECT")), "w"))
fh:write("return ", H.serialize(expect), "\n")
fh:close()
print(("made guild rule data: %d blocked, guild %d, filter total %d (rule %d)"):format(blocked, expect.guild, expect.oldFilterTotal, doubled))
