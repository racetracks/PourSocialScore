-- Checks (2.0.44) for the group and whisper alerts, on a fresh save:
--   * a group warning names players from the Player Ignore List and from a
--     guild rule that is on, once per player per group, not in combat
--   * a guild rule that is off, or a guild on the Guild Exclusion List,
--     does not warn
--   * a whisper you send warns once per player, only when a list blocks
--     their whispers (W ticked = allowed = no warning)
--   * the option turns both off
--   sh: lua5.1 tools/harness/run.lua . - - tools/harness/check_alerts.lua
local fails = 0
local realPrint = print
local function eq(what, got, want)
	if got ~= want then realPrint(("  FAIL %s: %s, expected %s"):format(what, tostring(got), tostring(want))); fails = fails + 1 end
end

-- count chat lines and fired events
local said = {}
print = function(s) said[#said + 1] = tostring(s) end
local function saidCount(pat)
	local n = 0
	for _, s in ipairs(said) do if s:find(pat, 1, true) then n = n + 1 end end
	return n
end
local groupFired, whisperFired, lastNames = 0, {}, ""
M.Events.Register("GROUP_WARNING", function(names) groupFired = groupFired + 1; lastNames = table.concat(names, ",") end)
M.Events.Register("WHISPER_WARNING", function(name, label) whisperFired[#whisperFired + 1] = name .. "|" .. label end)

-- lists: two players (one with whispers allowed) and a guild with a member
M.PSS_AddPlayer("Badguy")
M.PSS_AddPlayer("Chatty")
M.PSS_SetPlayerSetting("Chatty", "whispersBlocked", false)
M.PSS_AddGuild("Spam Guild")
M.PSS_UpdateGuildMember("Spam Guild", "Spammer")
M.PSS_UpdateGuildMember("Spam Guild", "Quiet")
local qe = assert(M.PSS_PersonHits("Quiet", "whisper"), "guild member not blocked")[1].entry
M.PSS_SetMemberBlock(qe.g, qe.m, "whisper", false)
H.RunTimers()

eq("listed: player", M.PSS_PersonListed("Badguy"), true)
eq("listed: player with W allowed", M.PSS_PersonListed("Chatty"), true)
eq("listed: guild member", M.PSS_PersonListed("Spammer"), true)
eq("listed: stranger", M.PSS_PersonListed("Friendly"), false)

-- group
local roster = {}
IsInGroup = function() return #roster > 0 end
IsInRaid = function() return #roster > 4 end
GetNumGroupMembers = function() return #roster end
GetUnitName = function(u)
	if u == "player" then return "Tester" end
	local i = tonumber(u:match("(%d+)$"))
	return i and roster[i] or nil
end
local function rosterUpdate()
	H.Fire("GROUP_ROSTER_UPDATE")
	H.RunTimers()
end

roster = { "Friendly", "Badguy" }
rosterUpdate()
eq("group warn fired", groupFired, 1)
eq("group warn names", lastNames, "Badguy-" .. GetRealmName())
rosterUpdate()
eq("group warn once", groupFired, 1)
roster = { "Friendly", "Badguy", "Spammer" }
rosterUpdate()
eq("group warn new member", groupFired, 2)

-- combat: deferred until combat ends
local inCombat = true
InCombatLockdown = function() return inCombat end
roster = { "Friendly", "Badguy", "Spammer", "Chatty" }
rosterUpdate()
eq("no group warn in combat", groupFired, 2)
inCombat = false
H.Fire("PLAYER_REGEN_ENABLED")
eq("group warn after combat", groupFired, 3)

-- leaving the group resets; guild excluded and a rule that is off do not warn
roster = {}
rosterUpdate()
M.PSS_AddGuildExclusion("Spam Guild")
eq("excluded guild member not listed", M.PSS_PersonListed("Spammer"), false)
roster = { "Spammer" }
rosterUpdate()
eq("no warn for excluded guild", groupFired, 3)
M.PSS_RemoveGuildExclusion("Spam Guild")
H.RunTimers()

-- whispers you send
local function sent(to)
	H.Fire("CHAT_MSG_WHISPER_INFORM", "hello", to, "", "", "", "", 0, 0, "", 0, 1, nil)
end
sent("Friendly")
eq("no whisper warn: stranger", #whisperFired, 0)
sent("Chatty")
eq("no whisper warn: W allowed", #whisperFired, 0)
sent("Quiet")
eq("no whisper warn: member W allowed", #whisperFired, 0)
sent("Badguy")
eq("whisper warn", #whisperFired, 1)
eq("whisper warn text", saidCount("You whispered"), 1)
sent("Badguy")
eq("whisper warn once", #whisperFired, 1)
sent("Spammer")
eq("whisper warn guild member", #whisperFired, 2)
eq("whisper warn list", whisperFired[2] and whisperFired[2]:match("|(.*)$"), "Guild Ignore List")

-- the option turns both off
M.PSS_SetOpt("listWarnings", "global", false)
M.PSS__CoreTest.resetWhisperWarned()
sent("Badguy")
eq("option off: no whisper warn", #whisperFired, 2)
roster = {}
rosterUpdate()
roster = { "Badguy" }
rosterUpdate()
eq("option off: no group warn", groupFired, 3)
M.PSS_SetOpt("listWarnings", "global", true)

print = realPrint
if fails == 0 then print("PASS alerts") else print("FAIL alerts: " .. fails) end
