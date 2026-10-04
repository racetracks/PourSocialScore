-- Saved data split (3.0 Step 4.2), as a run.lua script on any save: after
-- login options, players, guilds and rules live in the PourSocialScore_Options
-- tables, PourSocialScoreDB keeps only its own keys (upgrade record,
-- bookkeeping, history and counts), code still reads everything through
-- PourSocialScoreDB, a failed move is undone, and a reset empties both.
local fail = false
local function check(ok, msg) if not ok then print("FAIL saved data: " .. msg) fail = true end end

check(C_AddOns.IsAddOnLoaded("PourSocialScore_Options"), "PourSocialScore_Options not loaded")
for _, name in pairs(M.PSS_SV_GROUPS) do check(type(_G[name]) == "table", name .. " missing") end
check(M.PSS_SavedDataSplit(), "split not done")
check(PourSocialScoreDB.upgrade and PourSocialScoreDB.upgrade.step == M.PSS_UPGRADE_STEPS, "upgrade step not recorded")

-- every routed key left PourSocialScoreDB and is read from its table
local ROUTE, GROUPS = M.PSS_SV_ROUTE, M.PSS_SV_GROUPS
local held = 0
for k, g in pairs(ROUTE) do
	check(rawget(PourSocialScoreDB, k) == nil, k .. " still in PourSocialScoreDB")
	local t = _G[GROUPS[g]]
	if t[k] ~= nil then held = held + 1 end
	check(PourSocialScoreDB[k] == t[k], k .. " not read from " .. GROUPS[g])
end
check(held > 10, "Options tables hold only " .. held .. " keys")
for _, k in ipairs({ "ignoreList", "typeList", "notes", "playerData" }) do check(type(PSS_PlayersDB[k]) == "table", "PSS_PlayersDB." .. k) end
check(type(PSS_GuildsDB.guildData) == "table", "PSS_GuildsDB.guildData")
check(type(PSS_RulesDB.filterList) == "table", "PSS_RulesDB.filterList")
check(PSS_OptionsDB.chatmsg ~= nil, "PSS_OptionsDB.chatmsg")
for _, k in ipairs({ "blockLog", "blockStats", "filterCount", "filterBlocked", "upgrade" }) do
	check(rawget(PourSocialScoreDB, k) ~= nil, k .. " left PourSocialScoreDB")
end

-- a new key of a routed name goes to its table; another key stays
PourSocialScoreDB.guildExclusions = PourSocialScoreDB.guildExclusions or {}
check(rawget(PourSocialScoreDB, "guildExclusions") == nil and PSS_GuildsDB.guildExclusions ~= nil, "routed write")
PourSocialScoreDB.zzOther = 1
check(rawget(PourSocialScoreDB, "zzOther") == 1, "an unrouted key left PourSocialScoreDB")
PourSocialScoreDB.zzOther = nil

-- a move whose counts differ is undone
local before = M.PSS_Validate().n.list
local list = PSS_PlayersDB.ignoreList
rawset(PourSocialScoreDB, "ignoreList", list)
PSS_PlayersDB.ignoreList = { "Someone" }
local validate, calls = M.PSS_Validate, 0
M.PSS_Validate = function()
	calls = calls + 1
	local r = validate()
	if calls == 2 then r.n.list = -1 end
	return r
end
check(M.PSS_PrepareSavedData({ quiet = true }) == false, "a bad move reported success")
M.PSS_Validate = validate
check(rawget(PourSocialScoreDB, "ignoreList") == list, "undo: list not put back")
check(PSS_PlayersDB.ignoreList[1] == "Someone", "undo: Options value not put back")
check(M.PSS_SavedDataSplit() == false, "undo: split still reported")
-- and the next try moves it
check(M.PSS_PrepareSavedData({ quiet = true }) == true, "retry failed")
check(rawget(PourSocialScoreDB, "ignoreList") == nil and PSS_PlayersDB.ignoreList == list, "retry: list not moved")
check(M.PSS_Validate().n.list == before, "retry: list count changed")

-- a reset replaces PourSocialScoreDB and empties the Options tables
PSS_GuildsDB.zzStale = true
M.PSS_ResetIgnoreDB()
check(PSS_GuildsDB.zzStale == nil, "reset left old Options data")
check(rawget(PourSocialScoreDB, "ignoreList") == nil and type(PSS_PlayersDB.ignoreList) == "table", "reset: list not routed")
check(#PourSocialScoreDB.ignoreList == 0, "reset: list not empty")
check(PourSocialScoreDB.chatmsg == true and PSS_OptionsDB.chatmsg == true, "reset: options not routed")

if not fail then print("PASS saved data") end
