-- Core uplift F1 (3.4.1.42), one case per fix, on a fresh save:
--   N40 expiry is applied by itself (combat end once a day, /pss list, the window)
--   N41 the menu and Group Finder hooks follow their options without a /reload
--   N42 the link converter's [talent=N] is a tag the filter language knows
--   N45 Import with Replace on guilds keeps the shipped guild rules
--   N46 a listener that errors is reported once and counted
--   N47 the group warning names only who is in the group now
--   N48 /pss list with an entry that has no note
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_fixes.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL fixes: " .. msg) fail = true end end
local function said(pat)
	for _, s in ipairs(H.chat) do if s:find(pat, 1, true) then return true end end
	return false
end
local db = PourSocialScoreDB
local DAY = 86400
local function listed(name) return M.hasGlobalIgnored(M.Proper(M.addServer(name))) > 0 end

------------------------------------------------------------------------
-- N40: expiry
------------------------------------------------------------------------
local realPrint, printed = print, {}
print = function(s) printed[#printed + 1] = tostring(s) end
local function printedHas(pat)
	for _, s in ipairs(printed) do if s:find(pat, 1, true) then return true end end
	return false
end
local function listFor(name, daysAgo, exp, kind)
	if kind == "npc" then M.PSS_ImportListEntry(name, "", "", "npc") else M.PSS_AddPlayer(name) end
	local i = #db.ignoreList
	check(db.ignoreList[i] ~= nil, "could not list " .. name)
	db.dateList[i] = date("%d %b %Y", time() - daysAgo * DAY)
	db.expList[i] = exp
end
listFor("Oldtimer", 10, 5)
listFor("Freshone", 2, 5)
listFor("Neverexp", 400, 0)
M.PSS_ExpireEntries()
check(not listed("Oldtimer"), "N40: an expired player was not removed")
check(listed("Freshone"), "N40: a player not yet expired was removed")
check(listed("Neverexp"), "N40: a player with no expiry was removed")
check(printedHas("Expired: 1 entry removed"), "N40: no expiry chat line")

-- combat end: at most once a day
listFor("Combatexp", 8, 3)
H.Fire("PLAYER_REGEN_ENABLED")
check(listed("Combatexp"), "N40: combat end ran twice on the same day")
H.Advance(DAY)
H.Fire("PLAYER_REGEN_ENABLED")
check(not listed("Combatexp"), "N40: combat end on a new day did not expire")

-- /pss list (Libraries) and an NPC entry
M.PSS_Need("Libraries")
listFor("Old Npc", 30, 7, "npc")
local before = #db.ignoreList
M.PSS_SlashPSS("list")
check(#db.ignoreList == before - 1, "N40: /pss list did not expire an NPC entry")
print = realPrint

------------------------------------------------------------------------
-- N48: /pss list with no note
------------------------------------------------------------------------
M.PSS_AddPlayer("Nonote")
db.notes[#db.ignoreList] = nil
local ok, err = pcall(M.PSS_SlashPSS, "list")
check(ok, "N48: /pss list errors on a missing note: " .. tostring(err))

------------------------------------------------------------------------
-- N41: hooks follow their options
------------------------------------------------------------------------
local function menuEntries()
	local n = 0
	local root = {}
	function root:CreateDivider() end
	function root:CreateTitle() n = n + 1 end
	function root:CreateButton() n = n + 1 return {} end
	M.PSS_UnitMenuPlayer(nil, root, { name = "Menuman", server = "Realm" })
	return n
end
check(menuEntries() > 0, "N41: the unit menu adds nothing with its option on")
M.PSS_SetOpt("useUnitHacks", "global", false)
check(menuEntries() == 0, "N41: the unit menu still adds entries with its option off")
M.PSS_SetOpt("useUnitHacks", "global", true)
check(menuEntries() > 0, "N41: the unit menu adds nothing after turning it back on")

-- the Group Finder arrives later; its option off then on installs the hooks
local hasInfo = 0
_G.C_LFGList = {
	HasSearchResultInfo = function() hasInfo = hasInfo + 1 return true end,
	GetSearchResultInfo = function() return { leaderName = "Oldtimer" } end,
}
local modified = {}
local realModify = Menu.ModifyMenu
Menu.ModifyMenu = function(tag, fn) modified[tag] = fn end
M.PSS_SetOpt("useLFGHacks", "global", false)
_G.LFGListSearchEntry_Update = function() end
_G.LFGListSearchEntry_OnEnter = function() end
H.Fire("ADDON_LOADED", "Blizzard_GroupFinder")
check(modified.MENU_LFG_FRAME_SEARCH_ENTRY == nil, "N41: Group Finder hooked with its option off")
M.PSS_SetOpt("useLFGHacks", "global", true)
check(modified.MENU_LFG_FRAME_SEARCH_ENTRY ~= nil, "N41: Group Finder not hooked when its option was turned on")
local row = { resultID = 1, Name = { SetTextColor = function() end } }
_G.LFGListSearchEntry_Update(row)
check(hasInfo == 1, "N41: the Group Finder hook did not run")
M.PSS_SetOpt("useLFGHacks", "global", false)
_G.LFGListSearchEntry_Update(row)
check(hasInfo == 1, "N41: the Group Finder hook ran with its option off")
M.PSS_SetOpt("useLFGHacks", "global", true)
Menu.ModifyMenu = realModify

------------------------------------------------------------------------
-- N42: the talent tag
------------------------------------------------------------------------
local link = "|cff71d5ff|Htalent:12345:0|h[Some Talent]|h|r"
local tag = M.PSS_ConvertChatLink(link)
check(tag == "[talent=12345]", "N42: converter gave " .. tostring(tag))
check(M.PSS_TestChatFilter(tag, "look " .. link) == "blocked", "N42: [talent=12345] did not block its link")
check(M.PSS_TestChatFilter("[talent=999]", "look " .. link) == "passed", "N42: [talent=999] blocked another talent")
check(M.PSS_TestChatFilter("[talent]", "look " .. link) == "blocked", "N42: [talent] did not block a talent link")
check(M.PSS_TestChatFilter("[talent]", "no links here") == "passed", "N42: [talent] blocked plain text")

------------------------------------------------------------------------
-- N45: Import with Replace on guilds
------------------------------------------------------------------------
M.PSS_AddGuild("Old  Guild")
local shipped = {}
for k, g in pairs(db.guildData) do if g.managed then shipped[#shipped + 1] = k end end
check(#shipped > 0, "N45: no shipped guild rules on a fresh save")
M.PSS_ApplyImport({ v = 1, guilds = { { name = "New Guild" }, { name = "Old  Guild" } } }, "replace", { guilds = true })
for _, k in ipairs(shipped) do
	check(db.guildData[k] and db.guildData[k].managed, "N45: Replace removed the shipped rule " .. k)
end
check(db.guildData["new guild"] ~= nil, "N45: the imported guild is missing")
check(db.guildData["old  guild"] ~= nil, "N45: a name with a double space was not imported under its key")
local n = 0
for k, g in pairs(db.guildData) do if not g.managed then n = n + 1 end end
check(n == 2, "N45: " .. n .. " own guild rules after Replace, expected 2")

------------------------------------------------------------------------
-- N46: listener errors
------------------------------------------------------------------------
local id = M.Events.Register("PSS_TEST_EVENT", function() error("boom") end)
local errs0 = M.Events.errors.count
local chat0 = #H.chat
M.Events.Fire("PSS_TEST_EVENT")
M.Events.Fire("PSS_TEST_EVENT")
M.Events.Unregister("PSS_TEST_EVENT", id)
check(M.Events.errors.count == errs0 + 2, "N46: listener errors not counted")
local shown = 0
for i = chat0 + 1, #H.chat do if H.chat[i]:find("error in PSS_TEST_EVENT", 1, true) then shown = shown + 1 end end
check(shown == 1, "N46: the error was shown " .. shown .. " times, expected once")

------------------------------------------------------------------------
-- N47: the group warning
------------------------------------------------------------------------
M.PSS_AddPlayer("Badguy")
M.PSS_AddPlayer("Otherbad")
local fired, names = 0, ""
M.Events.Register("GROUP_WARNING", function(list) fired = fired + 1; names = table.concat(list, ",") end)
local roster = {}
IsInGroup = function() return #roster > 0 end
IsInRaid = function() return false end
GetNumGroupMembers = function() return #roster end
GetUnitName = function(u)
	if u == "player" then return "Tester" end
	local i = tonumber(u:match("(%d+)$"))
	return i and roster[i] or nil
end
local function update() H.Fire("GROUP_ROSTER_UPDATE"); H.RunTimers() end
roster = { "Friendly", "Badguy" }
update()
check(fired == 1 and names == "Badguy-Realm", "N47: first warning: " .. fired .. " " .. names)
roster = { "Friendly", "Otherbad" }
update()
check(fired == 2 and names == "Otherbad-Realm", "N47: a player who left is still named: " .. names)
roster = { "Friendly", "Otherbad" }
update()
check(fired == 2, "N47: warned again with nobody new")

if not fail then print("PASS fixes") end
