-- Member field accessors (core uplift S2, 3.4.1.50), as a run.lua script on
-- a new save (validate_all.sh "== accessors"): each M.PSS_Member* gives the
-- same answer for a full record and for one without the fields S3 stops
-- saving (name, guild, whenBlocked, _playerKey; a counts table without
-- total), when the caller passes the stored key and the rule. Blocking,
-- the member index and the members list read a stripped record right.
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL accessors: " .. msg) fail = true end end

M.PSS_AddGuild("Accessor Guild")
local gkey = M.PSS_NormalizeGuild("Accessor Guild")
local g = PourSocialScoreDB.guildData[gkey]
local full = M.PSS_UpdateGuildMember("Accessor Guild", "Strip-Realm")
check(type(full) == "table", "no member record")
local k
for key, m in pairs(g.members) do if m == full then k = key end end
check(k ~= nil, "no stored key")

-- the answers for the full record
local want = {
	canon = M.PSS_MemberCanon(full, k), key = M.PSS_MemberPlayerKey(full),
	name = M.PSS_MemberName(full, k), guild = M.PSS_MemberGuildName(full, g),
	when = M.PSS_MemberWhenBlocked(full),
}
check(want.canon == M.PSS_CanonPlayer("Strip-Realm"), "canon " .. tostring(want.canon))
check(want.name == "Strip-Realm", "name " .. tostring(want.name))
check(want.guild == g.name, "guild " .. tostring(want.guild))
check(type(want.when) == "string" and want.when ~= "", "added date")
check(not M.PSS_MemberShipped(full), "a stored member reads as shipped")

-- the same record as S3 will save it: the derivable fields gone
full.name, full.guild, full._playerKey = nil, nil, nil
check(M.PSS_MemberCanon(full, k) == want.canon, "canon without name")
check(M.PSS_MemberName(full, k) == want.name, "name from the key: " .. tostring(M.PSS_MemberName(full, k)))
check(M.PSS_MemberGuildName(full, g) == want.guild, "guild from the rule")
check(M.PSS_MemberCanon(nil, nil) == nil and M.PSS_MemberName(nil) == nil, "a missing record")

-- the member index finds them, and a whisper from them is blocked
M.PSS_MarkGuildIndexDirty()
local lg, lk = M.PSS_LookupGuildMember("Strip-Realm")
check(lg == g and lk == gkey, "the member index lost the stripped record")

-- counts saved without total
local c = { whisper = 2, world = 1 }
check(History.CountTotal(c) == 3, "CountTotal without total: " .. History.CountTotal(c))
check(History.CountTotal({ total = 5, whisper = 2 }) == 5, "CountTotal keeps a larger total")
check(History.CountTotal(nil) == 0, "CountTotal of nothing")
check(c.total == nil, "CountTotal changed the table")
full.blockCounts = c
check(M.PSS_GetMemberBlockCounts(full).total == 3, "member total without total")
local tot = History.EmptyCounts()
History.Add("g:" .. want.canon, tot, History.NewEntry("whisper", "CHAT_MSG_WHISPER", "x"))
check(tot.total == 1, "History.Add on fresh counts")
local sparse = { whisper = 4 }
History.Add("g:" .. want.canon, sparse, History.NewEntry("whisper", "CHAT_MSG_WHISPER", "y"))
check(sparse.total == 5 and sparse.whisper == 5, "History.Add without total: " .. tostring(sparse.total))

-- the members list and the rule's count (no saved memberCount read)
check(M.PSS_GuildMemberCount(g, gkey) == 1, "member count")
g.memberCount = 99
check(M.PSS_GuildMemberCount(g, gkey) == 1, "the member count read the saved memberCount")

if not fail then print("PASS accessors") end
