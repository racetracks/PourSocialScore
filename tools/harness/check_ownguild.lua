-- Your own guild (3.2): a guild rule never blocks the members of the guild
-- you are in; a Player Ignore List entry for one of them still blocks.
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_ownguild.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL own guild: " .. msg) fail = true end end

local lineID = 600000
local function whisper(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg, author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
end

M.PSS_AddGuild("Home Guild")
local m = M.PSS_UpdateGuildMember("Home Guild", "Mate-Realm")
check(m ~= nil, "member not captured")
if m then m.guild = "Home Guild" end
M.PSS_AddGuild("Other Guild")
local o = M.PSS_UpdateGuildMember("Other Guild", "Stranger-Realm")
if o then o.guild = "Other Guild" end
if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end

-- not in a guild: both rules block
_G.GetGuildInfo = function() return nil end
check(whisper("Mate-Realm", "one"), "not in a guild: Home Guild rule did not block")
check(whisper("Stranger-Realm", "one"), "not in a guild: Other Guild rule did not block")

-- in Home Guild: its rule no longer blocks (any case), the other still does
_G.GetGuildInfo = function(unit) if unit == "player" then return "home guild", "Member", 5 end end
check(not whisper("Mate-Realm", "two"), "own guild member blocked by the guild rule")
check(whisper("Stranger-Realm", "two"), "other guild rule stopped blocking")
check(M.PSS_IsOwnGuild("Home Guild") and not M.PSS_IsOwnGuild("Other Guild"), "PSS_IsOwnGuild")

-- the same person on the Player Ignore List: blocked
M.PSS_AddIgnore("Mate-Realm", true)
check(whisper("Mate-Realm", "three"), "Player Ignore List entry of a guildmate not honoured")

if not fail then print("PASS own guild") end
