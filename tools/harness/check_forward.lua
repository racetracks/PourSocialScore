-- Core uplift U3 (3.4.1.47): forward compatibility (10_CORE_UPLIFT.md 2.3).
-- A save written by a newer version, with fields, rules, a filter id and
-- history this version does not know:
--   plant  (fresh save) lists a player, two guild rules with a member each
--          and three custom filters, then plants what a newer version would
--          save: a field on a player, a guild rule, a member, a count and a
--          filter's counts; a top-level key in core and in PSS_RulesDB; an
--          option; a built-in rule; a filter tag; a number filter id with its
--          history and recent counts; a field on the upgrade record. The
--          record's version is PSS_FW_VERSION (newer or older than this one)
--   login  (validate_all.sh: a plain login of that save, its output kept)
--   check  PSS_LOGIN_OUT names that output: the report (or the downgrade
--          line) names 1 filter, 1 guild rule and 1 setting this version
--          cannot use; that rule and that filter block nothing, the others
--          still do; /pss export unused copies all three with every field;
--          the export is format 2 and carries the unknown fields; Replace
--          keeps them; a second login says nothing new (the upgrade
--          direction) or the same lines (a downgrade)
--   after  (plain lua5.1, on the file the check phase wrote) every planted
--          field, rule and line is still there, unchanged
--   oldimport (an older build's code, PSS_FW_EXPORT) imports the format 2
--          string
--   newerlog a save whose block log and recent counts are a newer layout
--          (v 3): Logging loads, says so once, a block is still counted, and
--          (plain lua5.1: lua5.1 check_forward.lua log <file>) both come back
--          unchanged
--   PSS_PHASE=plant PSS_FW_VERSION=3.4.1.99 lua5.1 tools/harness/run.lua . - <out> tools/harness/check_forward.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL forward: " .. msg) fail = true end end
local phase = os.getenv("PSS_PHASE") or (M and "check" or (arg[1] == "log" and "afterlog" or "after"))

local NEWER_TAG = "[newertag=1] spam"
local KEPT_GUILD, USED_GUILD = "Forward Kept", "Forward Used"
local KEPT_MEMBER, USED_MEMBER = "Keptmember-Testrealm", "Usedmember-Testrealm"
local PLAYER = "Forwardplayer-Testrealm"
local NUMBERED = "[contains=forwardnumbered]"

local function line(event, msg, author)
	return M.PSS_CoreFilter(nil, event, msg, author, "", "", "", "", 0, 0, "", 0, math.random(1, 1e9), nil) == true
end

------------------------------------------------------------------------
-- afterlog: the newer log and recent counts, unchanged
------------------------------------------------------------------------
if phase == "afterlog" then
	dofile(arg[2])
	local log, r = PSS_LoggingDB.blockLog, PourSocialScoreDB.recent
	check(type(log) == "table" and log.v == 3 and log.newerGroup and log.newerGroup[1] == "x", "the newer block log was changed")
	check(PSS_LoggingDB.blockKeep and PSS_LoggingDB.blockKeep.newerKeep == 1, "the newer keep was changed")
	check(type(r) == "table" and r.v == 3 and r.newerSlots and r.newerSlots[1] == 1, "the newer recent counts were changed")
	if not fail then print("PASS forward afterlog") end
	return
end

------------------------------------------------------------------------
-- after: the saved file, read with plain Lua
------------------------------------------------------------------------
if phase == "after" then
	local path = arg[1]
	dofile(path)
	local G, R, C, O = PSS_GuildsDB.guildData, PSS_RulesDB, PSS_CountsDB, PSS_OptionsDB
	local kept, used = G["forward kept"], G["forward used"]
	check(kept and kept.newerField == "keep", "the guild rule's newer field is gone")
	check(type(kept.newerTable) == "table" and kept.newerTable.a == 1, "the guild rule's newer table is gone")
	local m = used and used.members and used.members["usedmember-testrealm"]
	check(m and m.newerMember == 5, "the member's newer field is gone")
	check(m and m.blockCounts and m.blockCounts.newerCat == 2, "the member's newer count is gone")
	local p = PSS_PlayersDB.playerData["forwardplayer-testrealm"]
	check(p and p.newerPlayer == "x", "the player's newer field is gone")
	check(PourSocialScoreDB.newerCore and PourSocialScoreDB.newerCore.a == 1, "the newer core key is gone")
	check(R.newerNextFilterId == 13, "the newer PSS_RulesDB key is gone")
	check(O.newerOption == true, "the newer option is gone")
	check(PourSocialScoreDB.upgrade.newerRec == 1, "the upgrade record's newer field is gone")
	check(R.builtinRules.PSS0099 == true and C.builtinStats.PSS0099 and C.builtinStats.PSS0099.count == 3,
		"a newer built-in rule's state is gone")
	local tag, num
	for i = 1, #R.filterList do
		if R.filterList[i] == NEWER_TAG then tag = i end
		if R.filterList[i] == NUMBERED then num = i end
	end
	check(tag and R.filterActive[tag] == true, "the filter with a newer tag is gone or changed")
	check(num and R.filterID[num] == 12, "the number filter id is gone")
	check(num and C.filterBlocked[num] and C.filterBlocked[num].newerStat == 1, "the filter counts' newer field is gone")
	local log = PSS_LoggingDB and PSS_LoggingDB.blockLog
	check(type(log) == "table" and type(log["f:12"]) == "table" and #log["f:12"] >= 1, "the number filter's history lines are gone")
	local day = PourSocialScoreDB.recent and PourSocialScoreDB.recent.day
	check(day and (day["f:12"] or 0) >= 1, "the number filter's recent count is gone")
	check(type(log) == "table" and type(log["f:77"]) == "table" and #log["f:77"] == 1, "the line of an unknown filter id is gone")
	if not fail then print("PASS forward after") end
	return
end

local db = PourSocialScoreDB
local said = {}
local realPrint = print
local function capture(fn)
	said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local ok, err = pcall(fn)
	print = realPrint
	check(ok, "error: " .. tostring(err))
	return said
end
local function has(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return s end end
end

------------------------------------------------------------------------
-- plant
------------------------------------------------------------------------
if phase == "plant" then
	M.PSS_AddPlayer(PLAYER)
	local p = M.PSS_GetPlayerPrefs(PLAYER)
	p.newerPlayer = "x"
	local kept = M.PSS_GetGuild(KEPT_GUILD)
	local used = M.PSS_GetGuild(USED_GUILD)
	M.PSS_UpdateGuildMember(KEPT_GUILD, KEPT_MEMBER)
	local m = M.PSS_UpdateGuildMember(USED_GUILD, USED_MEMBER)
	M.PSS_EnsureMemberBlockData(m, true)
	m.blockCounts.newerCat = 2
	m.newerMember = 5
	kept.newerField = "keep"
	kept.newerTable = { a = 1 }
	M.PSS_MarkGuildIndexDirty()
	-- both rules block before the newer fields count (this version made them)
	check(line("CHAT_MSG_WHISPER", "hello", USED_MEMBER), "plant: the usable rule does not block")
	M.PSS_AddCustomFilter("Newer tag", NEWER_TAG, true)
	M.PSS_AddCustomFilter("Numbered", NUMBERED, true)
	local num = #db.filterList
	db.filterID[num] = 12
	M.PSS_LoadLogging()
	check(line("CHAT_MSG_CHANNEL", "forwardnumbered here", "Somebody-Testrealm"), "plant: the numbered filter does not block")
	check(#M.PSS_History.For("f:12") >= 1, "plant: no history line for f:12")
	-- a line of a filter id this version never made (the tidy keeps it)
	local log = M.PSS_History.Log()
	log[#log + 1] = setmetatable({ o = "f:77", ts = time() - 60, cat = "world", event = "CHAT_MSG_CHANNEL",
		message = "older line", member = "Somebody-Testrealm" }, M.PSS_History.EntryMT)
	M.PSS_FilterCounts(num).newerStat = nil
	db.filterBlocked[num].newerStat = 1
	db.builtinRules.PSS0099 = true
	db.builtinStats.PSS0099 = { count = 3 }
	rawset(db, "newerCore", { a = 1 })
	PSS_RulesDB.newerNextFilterId = 13
	PSS_OptionsDB.newerOption = true
	db.upgrade.newerRec = 1
	db.upgrade.version = os.getenv("PSS_FW_VERSION") or "3.4.1.99"
	if not fail then print("PASS forward plant") end
	return
end

------------------------------------------------------------------------
-- newerlog: a newer block log and recent counts (planted in the file)
------------------------------------------------------------------------
if phase == "newerlog" then
	local lines = capture(function() M.PSS_LoadLogging() end)
	check(has(lines, "saved by a newer version"), "no line about the newer block log")
	M.PSS_AddCustomFilter("Logged", "[contains=newerlogged]", true)
	local i = #db.filterList
	check(line("CHAT_MSG_CHANNEL", "newerlogged", "Someone-Testrealm"), "a block failed with a newer log")
	check((tonumber(db.filterCount[i]) or 0) == 1, "the block was not counted")
	if not fail then print("PASS forward newerlog") end
	return
end

------------------------------------------------------------------------
-- oldimport: an older build reads a format 2 string
------------------------------------------------------------------------
if phase == "oldimport" then
	local fh = io.open(os.getenv("PSS_FW_EXPORT"), "rb")
	local text = fh:read("*a")
	fh:close()
	M.PSS_Need("Libraries")
	local data, err = M.PSS_DecodeExport(text)
	check(data ~= nil, "the older build cannot read the string: " .. tostring(err))
	if data then
		local report = M.PSS_ApplyImport(data, "merge", { players = true, guilds = true, members = true, filters = true, options = true })
		check(db.guildData["forward used"] ~= nil, "the older build did not import the guild rule: " .. tostring(report))
		local found
		for i = 1, #db.filterList do if db.filterList[i] == NUMBERED then found = true end end
		check(found, "the older build did not import the filter")
	end
	if not fail then print("PASS forward oldimport") end
	return
end

------------------------------------------------------------------------
-- check
------------------------------------------------------------------------
local version = M.PSS_UpgradeText and C_AddOns.GetAddOnMetadata("PourSocialScore", "Version")
local saved = db.upgrade.version
local downgrade = M.PSS_VersionOrder(saved, version) == 1
local out = {}
local path = os.getenv("PSS_LOGIN_OUT")
if path and path ~= "" then for s in io.lines(path) do out[#out + 1] = (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end
local FILTER_LINE = "Chat Filtering: 1 custom rule(s) this version cannot use (kept, not applied): /pss export unused."
local GUILD_LINE = "Guild Ignore List: 1 guild rule(s) this version cannot use (kept, not applied): /pss export unused."
local OPTION_LINE = "Options: 1 setting(s) this version does not know (kept): /pss export unused."
check(has(out, FILTER_LINE), "the first login does not name the filter")
check(has(out, GUILD_LINE), "the first login does not name the guild rule")
check(has(out, OPTION_LINE), "the first login does not name the setting")
if downgrade then
	check(has(out, "older than your saved data"), "no downgrade line")
	check(db.upgrade.version == saved, "the record lost the newer version")
else
	check(has(out, "Upgrading your saved data:"), "no report head")
	check(has(out, "Saved data upgraded to " .. version), "no report end")
end
for _, s in ipairs(out) do check(not s:find("[\128-\255]"), "a line that is not ASCII: " .. s) end

-- what this version cannot use is not applied; the rest is
local u = M.PSS_UnusableRules()
check(#u.filters == 1 and db.filterList[u.filters[1]] == NEWER_TAG, "the unusable filters are not just the newer tag")
check(#u.guilds == 1 and u.guilds[1] == "forward kept", "the unusable guild rules are not just Forward Kept")
check(#u.options == 1 and u.options[1] == "newerOption", "the unusable settings are not just newerOption")
check(not line("CHAT_MSG_WHISPER", "hello", KEPT_MEMBER), "the unusable guild rule blocked its member")
check(line("CHAT_MSG_WHISPER", "hello", USED_MEMBER), "the usable guild rule no longer blocks")
check(not line("CHAT_MSG_CHANNEL", "spam spam", "Other-Testrealm"), "the filter with a newer tag blocked a line")
check(line("CHAT_MSG_CHANNEL", "forwardnumbered again", "Somebody-Testrealm"), "the numbered filter no longer blocks")

-- the login tidy keeps lines whose owner is a form it does not make
M.PSS_LoadLogging()
M.PSS_TidyBlockHistory()
check(#M.PSS_History.For("f:77") == 1 and #M.PSS_History.For("f:12") >= 1, "the history tidy dropped a newer filter's lines")

-- /pss export unused: the copy box, every field of all three
M.PSS_Need("Libraries")
local text = M.PSS_UnusedExportText()
check(type(text) == "string", "no export text")
local data = text and M.PSS_DecodeExport(text)
check(data and data.v == 2 and data.unused == true, "the unused export is not format 2")
check(data and data.filters and #data.filters == 1 and data.filters[1].filter == NEWER_TAG, "the unused export lacks the filter")
local g = data and data.guilds and data.guilds[1]
check(g and g.name == KEPT_GUILD and g.more and g.more.newerField == "keep" and g.more.newerTable.a == 1, "the unused export lacks the guild rule's fields")
check(g and g.members and #g.members == 1, "the unused export lacks the rule's member")
check(data and data.options and data.options.newerOption == true, "the unused export lacks the setting")
local box = capture(function() M.PSS_SlashPSS("export unused") end)
local pop = _G.PSS_TextPopup
check(pop and pop:IsShown(), "/pss export unused did not open the copy box")
check(not (_G.PSS_Window and _G.PSS_Window:IsShown()), "/pss export unused opened the window")
check(pop and pop.edit and pop.edit:GetText() == text, "the copy box does not hold the export")
if pop then pop:Hide() end

-- a full export is format 2 with every unknown field; Replace keeps them
local full = M.PSS_BuildExport({ players = true, guilds = true, members = true, filters = true, options = true })
check(full.v == 2, "the export is not format 2")
local fe
for _, e in ipairs(full.guilds or {}) do if e.name == USED_GUILD then fe = e end end
local fm = fe and fe.members and fe.members[1]
check(fm and fm.more and fm.more.newerMember == 5, "the export lacks the member's newer field")
local fp
for _, e in ipairs(full.players or {}) do if e.name and e.name:lower() == PLAYER:lower() then fp = e end end
check(fp and fp.more and fp.more.newerPlayer == "x", "the export lacks the player's newer field")
local outFile = os.getenv("PSS_FW_EXPORT")
if outFile then
	local fh = io.open(outFile, "wb")
	fh:write(M.PSS_EncodeExport(full))
	fh:close()
end
local replaced = M.PSS_DecodeExport(M.PSS_EncodeExport({ v = 2, guilds = { fe } }))
M.PSS_ApplyImport(replaced, "merge", { guilds = true, members = true })
check(db.guildData["forward used"].members["usedmember-testrealm"].newerMember == 5, "a merge lost the member's newer field")

-- a login at the same version: the upgrade direction says nothing more; a
-- downgrade says its lines again
local again = capture(function()
	M.PSS_RunUpgradeFields(false, 0)
	M.PSS_RunUpgradeData(false)
end)
if downgrade then
	check(has(again, "older than your saved data") and has(again, GUILD_LINE), "a second downgraded login is silent")
else
	check(#again == 0, "a second login printed: " .. tostring(again[1]))
end
if not fail then print("PASS forward check (" .. (downgrade and "downgrade" or "upgrade") .. ")") end
