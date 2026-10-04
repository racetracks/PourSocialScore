-- Seeing members of a shipped guild in the world (3.0 Step 3.3), as a
-- run.lua script on a fresh save (rule off, lists asleep): it loads the
-- lists; a shipped member is not stored, someone new is (as in 2.0).
local fail = false
local function check(ok, msg) if not ok then print("FAIL communities seen: " .. msg) fail = true end end
local loaded = function() return C_AddOns.IsAddOnLoaded("PourSocialScore_Communities") end
local db = PourSocialScoreDB

check(not loaded(), "lists loaded at login with the rule off")
local function stored()
	local n = 0
	for _ in pairs(db.guildData.olympus.members or {}) do n = n + 1 end
	return n
end
M.PSS_UpdatePlayerUnit("Newface-Realm", nil, "OLYMPUS")
check(loaded(), "seeing a member of a shipped guild did not load the lists")
check(stored() == 1, "someone new seen in a shipped guild was not stored")
local shipped
for _, entry in ipairs(PourSocialScore_NS.MANAGED_DATA.olympus.guilds) do
	if entry.name == "OLYMPUS" then shipped = M.PSS_ShippedNames(M.PSS_NormalizeGuild(entry.name))[1] end
end
M.PSS_UpdatePlayerUnit(shipped, nil, "OLYMPUS")
check(stored() == 1, "a shipped member seen in the world was stored")

if not fail then print("PASS communities seen") end
