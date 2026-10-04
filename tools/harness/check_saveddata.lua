-- Saved data split groundwork (3.0 Step 4.1), as a run.lua script on any
-- save: the PourSocialScore_Options tables exist after login, and a key
-- routed to one of them is read and written there while PourSocialScoreDB
-- keeps everything else (also after a reset replaces PourSocialScoreDB).
local fail = false
local function check(ok, msg) if not ok then print("FAIL saved data: " .. msg) fail = true end end

check(C_AddOns.IsAddOnLoaded("PourSocialScore_Options"), "PourSocialScore_Options not loaded")
for _, name in pairs(M.PSS_SV_GROUPS) do check(type(_G[name]) == "table", name .. " missing") end
check(next(M.PSS_SV_ROUTE) == nil, "something is routed before the split")

local function routedRoundTrip(label)
	M.PSS_SV_ROUTE.zzTest = "options"
	PourSocialScoreDB.zzTest = 5
	check(rawget(PourSocialScoreDB, "zzTest") == nil, label .. ": routed key stored in PourSocialScoreDB")
	check(PSS_OptionsDB.zzTest == 5, label .. ": routed key not in PSS_OptionsDB")
	check(PourSocialScoreDB.zzTest == 5, label .. ": routed key not read back")
	PourSocialScoreDB.zzTest = nil
	check(PSS_OptionsDB.zzTest == nil, label .. ": routed key not cleared")
	M.PSS_SV_ROUTE.zzTest = nil
	PourSocialScoreDB.zzOther = 1
	check(rawget(PourSocialScoreDB, "zzOther") == 1, label .. ": an unrouted key left PourSocialScoreDB")
	PourSocialScoreDB.zzOther = nil
end
routedRoundTrip("after login")
check(type(PourSocialScoreDB.ignoreList) == "table", "PourSocialScoreDB lost its data")

-- a reset replaces PourSocialScoreDB: the routing comes back with it
M.PSS_ResetIgnoreDB()
routedRoundTrip("after a reset")

if not fail then print("PASS saved data") end
