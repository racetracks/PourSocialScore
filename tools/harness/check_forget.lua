-- Removal check (2.0.43), as a run.lua script on an upgraded save
-- (validate_all.sh): a player taken off any list leaves nothing saved.
--   PSS_PHASE=forget1 : remove Spammer-Realm (listed), Grunt-Realm (Bad
--                       Guild member) and a listed built-in list member
--   PSS_PHASE=forget2 : next login; the removals stayed, and the built-in
--                       member is still on its list with W I G P C blocked
--                       and a note
local db = PourSocialScoreDB
local History = M.PSS_History
local phase = os.getenv("PSS_PHASE") or "forget1"
local bad = 0
local function check(ok, msg) if not ok then bad = bad + 1; print("FAIL forget: " .. msg) end end
local function lines(owner) return owner and History.CountFor(owner) or 0 end

local NOTE = "My own note"
local olympus = db.guildData.olympus

local function builtInMember()
	if phase == "forget1" then
		local pick
		M.PSS_ForEachGuildMember(olympus, "olympus", function(m)
			if not pick and (m.note or "") == "" and not M.PSS_GetPlayerRecord(m.name) then pick = m.name end
		end, true)
		return pick
	end
	return db.forgetTestName
end

check(olympus ~= nil, "no built-in Olympus rule")
local shipped = olympus and builtInMember()
check(shipped ~= nil, "no built-in member to test with")

if phase == "forget1" then
	-- 1. a listed player with block lines
	check(M.PSS_GetPlayerRecord("Spammer-Realm") ~= nil, "Spammer-Realm has no record before")
	check(lines(M.PSS_PlayerHistoryKey("Spammer-Realm")) > 0, "Spammer-Realm has no lines before")
	M.PSS_DelIgnore("Spammer-Realm", true)
	check(M.PSS_GetPlayerRecord("Spammer-Realm") == nil, "Spammer-Realm record kept")
	check(lines(History.PlayerKey("Spammer-Realm")) == 0, "Spammer-Realm lines kept")
	check(M.PSS_LookupGuildMember("Spammer-Realm") == nil, "Spammer-Realm put on a guild list")

	-- 2. a guild member with block lines
	local g, gkey, m, sk = M.PSS_LookupGuildMember("Grunt-Realm")
	check(m ~= nil, "Grunt-Realm not a member before")
	local owner = m and History.MemberKey(m)
	check(lines(owner) > 0, "Grunt-Realm has no lines before")
	if m then M.PSS_RemoveGuildMember(g.name, m.name, gkey, sk) end
	check(M.PSS_LookupGuildMember("Grunt-Realm") == nil, "Grunt-Realm still a member")
	check(lines(owner) == 0, "Grunt-Realm lines kept")

	-- 3. a built-in list member who is also on the Player Ignore List
	if shipped then
		db.forgetTestName = shipped
		M.PSS_ImportListEntry(shipped, "", NOTE, "player")
		M.PSS_RecordPlayerBlock(shipped, "CHAT_MSG_WHISPER", "hello", nil, "whisper")
		check(lines(M.PSS_PlayerHistoryKey(shipped)) == 1, "built-in member: no player line")
		M.PSS_DelIgnore(shipped, true)
		check(M.PSS_GetPlayerRecord(shipped) == nil, "built-in member: player record kept")
		check(lines(History.PlayerKey(shipped)) == 0, "built-in member: player lines kept")
	end
end

-- both phases: the built-in member stays blocked on their guild list
if shipped then
	local g, gkey, m = M.PSS_LookupGuildMember(shipped)
	check(gkey == "olympus" and m ~= nil, "built-in member left the Olympus list")
	if m then
		for _, cat in ipairs(M.PSS_EXCL_CATS) do
			check(M.PSS_MemberBlocks(g, m, cat) == true, "built-in member: " .. cat .. " not blocked")
		end
		check(m.note == NOTE, "built-in member: note is " .. tostring(m.note))
	end
end

if phase == "forget2" then
	check(M.PSS_GetPlayerRecord("Spammer-Realm") == nil, "Spammer-Realm record came back")
	check(M.PSS_LookupGuildMember("Grunt-Realm") == nil, "Grunt-Realm came back")
	db.forgetTestName = nil
end

if bad == 0 then print("PASS " .. phase) end
