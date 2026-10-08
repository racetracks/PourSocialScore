-- PourSocialScore_Communities on demand (3.0 Step 3.3), as a run.lua script
-- on a fresh save (the shipped group's rule starts off):
--   * the member lists are not loaded at login, and the shipped guilds still
--     show with their member counts (from the manifest in the core)
--   * chat and opening the window do not load them (seeing a member of a
--     shipped guild in the world does: check_communities_seen.lua)
--   * switching the rule on loads them: counts are unchanged and a shipped
--     member is blocked from the next line
local fail = false
local function check(ok, msg) if not ok then print("FAIL communities: " .. msg) fail = true end end
local loaded = function() return C_AddOns.IsAddOnLoaded("PourSocialScore_Communities") end
local db = PourSocialScoreDB

check(not loaded(), "lists loaded at login with the rule off")
check(not M.PSS_ManagedDataLoaded(), "core thinks the lists are loaded")

-- counts from the manifest
local grp = M.PSS_ManagedGroups().olympus
check(grp and #grp.guilds > 100, "manifest groups")
local before, total = {}, 0
for _, entry in ipairs(grp.guilds) do
	local gkey = entry.name:lower()
	local g = db.guildData[gkey]
	check(g and g.managed == "olympus", "shipped guild rule missing: " .. entry.name)
	if g then
		before[gkey] = M.PSS_GuildMemberCount(g, gkey)
		total = total + before[gkey]
	end
end
check(before["olympus"] == 197, "OLYMPUS count without the lists: " .. tostring(before["olympus"]))

-- chat with the rule off
local lineID = 90000
local function whisper(author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "hello", author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
end
check(not whisper("Somebody-Realm"), "chat blocked a stranger")
check(not loaded(), "chat loaded the lists")

-- empty "left this guild" marks are not saved (3.0 Step 5.2)
local empty = 0
for _, g in pairs(db.guildData) do if type(g) == "table" and g.managedGone ~= nil then empty = empty + 1 end end
check(empty == 0, empty .. " guilds have an empty mark table")
-- a mark for someone the shipped list does not have in that guild
db.guildData["olympus"].managedGone = { ["nobody here-classicbetapvp"] = true }

-- the rule on: loaded, the same counts, a shipped member blocked
M.PSS_SetManagedGroupActive("olympus", true)
check(loaded() and M.PSS_ManagedDataLoaded(), "switching the rule on did not load the lists")
check(db.guildData["olympus"].managedGone == nil, "an unneeded mark was kept")
-- a mark for a shipped member stays
local first = M.PSS_ShippedNames("olympus")[1]
M.PSS_ManagedTombstone("olympus", M.PSS_CanonPlayer(first))
M.PSS_PruneManagedMarks()
check(db.guildData["olympus"].managedGone and db.guildData["olympus"].managedGone[M.PSS_CanonPlayer(first)] == true, "a needed mark was removed")
check(M.PSS_GuildMemberCount(db.guildData["olympus"], "olympus") == 196, "a marked member still counted")
db.guildData["olympus"].managedGone = nil
local after = 0
for gkey, n in pairs(before) do
	local c = M.PSS_GuildMemberCount(db.guildData[gkey], gkey)
	check(c == n, ("count changed for %s: %d -> %d"):format(gkey, n, c))
	after = after + c
end
check(after == total, "total count changed")
local shipped = M.PSS_ShippedNames(M.PSS_NormalizeGuild(PourSocialScore_NS.MANAGED_DATA.olympus.guilds[1].name))[1]
check(whisper(shipped), "shipped member not blocked with the rule on")

if not fail then print("PASS communities") end
