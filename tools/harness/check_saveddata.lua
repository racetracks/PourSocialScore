-- Saved data split (3.0 Steps 4.2 to 4.5), as a run.lua script on a fresh or
-- a 2.0 save (both load PourSocialScore_Logging at that login): options,
-- players, guilds, rules and counts live in the PourSocialScore_Options
-- tables, the history in PourSocialScore_Logging, PourSocialScoreDB keeps
-- only the upgrade record and bookkeeping, code still reads everything
-- through PourSocialScoreDB, a failed move is undone, and a reset empties
-- every table. (check_ondemand.lua covers a login without Logging.)
local fail = false
local function check(ok, msg) if not ok then print("FAIL saved data: " .. msg) fail = true end end

check(C_AddOns.IsAddOnLoaded("PourSocialScore_Options"), "PourSocialScore_Options not loaded")
check(C_AddOns.IsAddOnLoaded("PourSocialScore_Logging"), "PourSocialScore_Logging not loaded")
for _, name in pairs(M.PSS_SV_GROUPS) do check(type(_G[name]) == "table", name .. " missing") end
check(M.PSS_SavedDataSplit("PourSocialScore_Options"), "Options split not done")
check(M.PSS_SavedDataSplit("PourSocialScore_Logging"), "Logging split not done")
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
-- minimal settings (Step 4.5): no option is saved at its default, the
-- dead keys are gone, and a missing option reads its default
for _, o in ipairs(M.PSS_OPTIONS) do
	check(PSS_OptionsDB[o.key] == nil or PSS_OptionsDB[o.key] ~= o.default, o.key .. " saved at its default")
end
for _, k in ipairs({ "optionsV2012", "charOptions", "euiIntegration", "windowSizes", "columnWidths" }) do check(PSS_OptionsDB[k] == nil, k .. " not removed") end
check(rawget(PourSocialScoreDB, "historySize") == nil, "historySize not removed")
local was = PSS_OptionsDB.chatmsg
M.PSS_SetOpt("chatmsg", "global", false)
check(PSS_OptionsDB.chatmsg == false and M.PSS_Opt("chatmsg") == false, "a changed option not saved")
M.PSS_SetOpt("chatmsg", "global", true)
check(PSS_OptionsDB.chatmsg == nil and M.PSS_Opt("chatmsg") == true, "an option set to its default still saved")
PSS_OptionsDB.chatmsg = was
for _, k in ipairs({ "blockLog", "blockKeep" }) do
	check(type(PSS_LoggingDB[k]) == "table", "PSS_LoggingDB." .. k)
end
check(PSS_CountsDB.blockStats == nil, "PSS_CountsDB.blockStats not pruned (3.3.0-dev002)")
for _, k in ipairs({ "filterCount", "filterBlocked", "builtinStats" }) do
	check(type(PSS_CountsDB[k]) == "table", "PSS_CountsDB." .. k)
end
check(type(PSS_CountsDB.filterTotal) == "number", "PSS_CountsDB.filterTotal")
check(type(rawget(PourSocialScoreDB, "upgrade")) == "table", "upgrade left PourSocialScoreDB")
-- the block counts of a player or member stay on the record
for _, g in pairs(PSS_GuildsDB.guildData) do
	for _, m in pairs(type(g) == "table" and g.members or {}) do
		check(type(m) ~= "table" or m.blockCounts == nil or type(m.blockCounts) == "table", "member counts")
	end
end
-- a new block, a filter's or a person's, is logged in PSS_LoggingDB
-- (3.2.0-dev007: a person's too)
local log = PSS_LoggingDB.blockLog
M.PSS_History.Add("f:zztest", nil, M.PSS_History.NewEntry("whisper", "CHAT_MSG_WHISPER", "hi"))
check(log[#log] and log[#log].o == "f:zztest", "new line not in PSS_LoggingDB")
M.PSS_History.Add("p:zztest", nil, M.PSS_History.NewEntry("whisper", "CHAT_MSG_WHISPER", "hi"))
check(log[#log] and log[#log].o == "p:zztest", "person line not in PSS_LoggingDB's log")
M.PSS_History.Clear(function(h) return h.o == "p:zztest" end)

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
M.PSS_PrepareSavedData({ quiet = true })
M.PSS_Validate = validate
check(rawget(PourSocialScoreDB, "ignoreList") == list, "undo: list not put back")
check(PSS_PlayersDB.ignoreList[1] == "Someone", "undo: Options value not put back")
check(M.PSS_SavedDataSplit("PourSocialScore_Options") == false, "undo: split still reported")
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
check(PSS_OptionsDB.chatmsg == nil and M.PSS_Opt("chatmsg") == true, "reset: options not at their default")
check(M.PSS_Opt("showWarning") == true, "reset: showWarning not at its default")
PourSocialScoreDB.sameserver = false
check(rawget(PourSocialScoreDB, "sameserver") == nil and PSS_OptionsDB.sameserver == false, "reset: options not routed")
PourSocialScoreDB.sameserver = nil
check(rawget(PourSocialScoreDB, "filterCount") == nil and type(PSS_CountsDB.filterCount) == "table", "reset: counts not routed")
check(PSS_LoggingDB.blockLog == nil or #PSS_LoggingDB.blockLog == 0, "reset: history not emptied")

if not fail then print("PASS saved data") end
