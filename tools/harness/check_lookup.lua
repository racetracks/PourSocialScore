-- Checks (2.0.45) for the Dashboard tab's Ignore List Lookup, on a fresh save:
--   * the main window opens on the Dashboard (first tab)
--   * a lookup finds players on the Player Ignore List, a guild list and a
--     built-in list, one row per player, highlighted when on the Player
--     Ignore List and a guild list
--   * typing waits for the pause before it searches
--   * Duplicate Lookup lists only players on more than one list
--   * the right-click menu offers each list, and removing follows 2.0.43:
--     off the Player Ignore List only, a built-in member stays there with
--     W I G P C blocked and a note; off a guild list, they stay on the
--     Player Ignore List
--   sh: lua5.1 tools/harness/run.lua . - - tools/harness/check_lookup.lua
local fails = 0
local realPrint = print
local function eq(what, got, want)
	if got ~= want then realPrint(("  FAIL %s: %s, expected %s"):format(what, tostring(got), tostring(want))); fails = fails + 1 end
end
print = function() end

local SHIPPED = "Skibert Toilet-ClassicBetaPvP"		-- on the built-in Olympus list

-- lists
M.PSS_AddPlayer("Lookupboth")			-- Player Ignore List and Spam Guild
M.PSS_AddPlayer("Lookuponly")			-- Player Ignore List only
M.PSS_AddPlayer(SHIPPED)				-- Player Ignore List and a built-in list
M.PSS_AddGuild("Spam Guild")
M.PSS_AddGuild("Other Guild")
M.PSS_UpdateGuildMember("Spam Guild", "Lookupboth")
M.PSS_UpdateGuildMember("Spam Guild", "Lookuptwice")		-- two guild lists
M.PSS_UpdateGuildMember("Other Guild", "Lookuptwice")
M.PSS_UpdateGuildMember("Other Guild", "Lookupguild")		-- one guild list
H.RunTimers()

local function find(list, name)
	local ck = M.PSS_CanonPlayer(name)
	for _, e in ipairs(list) do if e.ck == ck then return e end end
end

-- core lookup
local res, more = M.PSS_ListLookup("lookup")
eq("lookup found", #res, 4)
eq("lookup not cut", more, false)
eq("lookup both lists", find(res, "Lookupboth") and find(res, "Lookupboth").lists, 2)
eq("lookup both: player", find(res, "Lookupboth") and find(res, "Lookupboth").player ~= nil, true)
eq("lookup twice", find(res, "Lookuptwice") and find(res, "Lookuptwice").lists, 2)
eq("lookup guild only", find(res, "Lookupguild") and find(res, "Lookupguild").lists, 1)
res = M.PSS_ListLookup("skibert")
eq("lookup built-in", #res, 1)
eq("lookup built-in lists", res[1] and res[1].lists, 2)
eq("lookup built-in flagged", res[1] and res[1].guilds[1] and res[1].guilds[1].builtIn, true)
eq("lookup with realm", #M.PSS_ListLookup("skibert toilet-classic beta"), 1)
eq("lookup empty", #M.PSS_ListLookup("  "), 0)
res, more = M.PSS_ListLookup("-", 3)
eq("lookup max", #res, 3)
eq("lookup max: more", more, true)

local dup = M.PSS_ListDuplicates()
eq("duplicates both", find(dup, "Lookupboth") ~= nil, true)
eq("duplicates twice", find(dup, "Lookuptwice") ~= nil, true)
eq("duplicates built-in", find(dup, SHIPPED) ~= nil, true)
eq("duplicates not single", find(dup, "Lookuponly") == nil and find(dup, "Lookupguild") == nil, true)

-- window: opens on the Dashboard
M.PSS_GUI()
_G.PSS:Show()
H.RunTimers()
local f = M.PSSDashFrame
eq("dashboard shown", f and f:IsShown(), true)
eq("player tab hidden", _G.PSSFrame1:IsShown(), false)
_G.PSSTab1:GetScript("OnClick")(_G.PSSTab1, "LeftButton")
eq("tab switch", f:IsShown(), false)
_G.PSS:Hide()
_G.PSS:Show()
eq("reopens on dashboard", f:IsShown(), true)

-- the stub has no layout: give the list room for every row
f.scroll.GetHeight = function() return 400 end
local function typeText(text)
	f.box:SetText(text)
	f.box:GetScript("OnTextChanged")(f.box, true)
	H.RunTimers()
end

-- typing waits for the pause
f.box:SetText("lookup")
f.box:GetScript("OnTextChanged")(f.box, true)
eq("no search before the pause", #f.entries, 0)
H.RunTimers()
eq("search after the pause", #f.entries, 4)
local function row(name)
	for _, r in ipairs(f.rows) do
		if r:IsShown() and r.entry and r.entry.name == M.PSS_DisplayPlayer(name) then return r end
	end
end
eq("row highlighted (both)", row("Lookupboth") and row("Lookupboth").both:IsShown(), true)
eq("row not highlighted (two guilds)", row("Lookuptwice") and row("Lookuptwice").both:IsShown(), false)

-- right-click menu
local items
MenuUtil.CreateContextMenu = function(owner, build)
	items = {}
	local root = {
		CreateTitle = function() end, CreateDivider = function() end,
		CreateButton = function(_, text, fn) items[#items + 1] = { text = text, fn = fn } end,
	}
	build(owner, root)
end
local function menu(name)
	local r = row(name)
	items = nil
	if r then r:GetScript("OnClick")(r, "RightButton") end
	return items or {}
end
local function pick(list, text)
	for _, it in ipairs(list) do if it.text == text then it.fn(); H.RunTimers(); return true end end
	realPrint("  menu: " .. text .. " not found")
	fails = fails + 1
end
local m = menu("Lookuptwice")
eq("menu twice: entries", #m, 4)		-- each guild, every guild list, all lists
m = menu("Lookupboth")
eq("menu both: entries", #m, 3)		-- Player Ignore List, Spam Guild, all lists

-- off a guild list only: stays on the Player Ignore List
pick(menu("Lookupboth"), "Remove from Spam Guild")
eq("guild removal: still listed", M.PSS_IsPlayerListed("Lookupboth"), true)
eq("guild removal: off guild", M.PSS_LookupGuildMember("Lookupboth"), nil)
eq("guild removal: row not highlighted", row("Lookupboth") and row("Lookupboth").both:IsShown(), false)

-- built-in member off the Player Ignore List only: kept blocked with a note
typeText("skibert")
pick(menu(SHIPPED), "Remove from Player Ignore List")
eq("built-in: off player list", M.PSS_IsPlayerListed(SHIPPED), false)
local g, _, mem = M.PSS_LookupGuildMember(SHIPPED)
eq("built-in: still on guild list", g ~= nil, true)
local blocks = mem and M.PSS_MemberBlock(mem) or {}
eq("built-in: W I G P C blocked", blocks.whisper and blocks.partyInvite and blocks.guildInvite and blocks.partyRaid and blocks.world, true)
eq("built-in: note", mem and mem.note, "Removed from player list")
eq("built-in: one row left", #f.entries, 1)

-- all lists
typeText("lookuptwice")
pick(menu("Lookuptwice"), "Remove from all lists")
eq("all lists: gone", #M.PSS_ListLookup("lookuptwice"), 0)
eq("all lists: table empty", #f.entries, 0)

-- duplicate lookup button
_G.PSSDashDuplicateButton:GetScript("OnClick")(_G.PSSDashDuplicateButton)
eq("duplicate button", f.mode, "duplicates")
eq("duplicate rows", #f.entries, #M.PSS_ListDuplicates())

print = realPrint
if fails == 0 then print("PASS lookup") else print("FAIL lookup (" .. fails .. ")") end
