-- Checks (2.0.39) on a save from make_guildrule.lua:
--   * guild rule blocks are counted once, as guild blocks: the double count
--     is gone from the Chat Filters total, 24 hours and the rule's row,
--     which shows n/a, and no history line keeps the rule tag
--   * new blocks count on the guild only
--   * the rule switched off stops its guilds blocking, the shipped members
--     and the ones found in game; switched on again they block again
--   * no guild discovery from mouseover or nameplates in combat
local expect = dofile(assert(os.getenv("PSS_EXPECT")))
local db = PourSocialScoreDB
local fails = 0
local function eq(what, got, want)
	if got ~= want then print(("  FAIL %s: %s, expected %s"):format(what, tostring(got), tostring(want))); fails = fails + 1 end
end
local lineID = 80000
local function whisper(author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "join olympus", author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
end
local S = M.PSS_Stats
local i = M.PSS_ManagedGroupFilterIndex("olympus")

-- the upgrade
eq("filter total", tonumber(db.filterTotal) or 0, expect.oldFilterTotal - expect.oldRuleCount)
eq("filter 24h", S.Last24("filter").total, 0)
eq("rule count", tonumber(db.filterCount[i]) or 0, 0)
eq("guild total", M.PSS_GetGuildBlockCounts().total, expect.guild)
local tagged = 0
M.PSS_History.Each(function(h) if h.r ~= nil then tagged = tagged + 1 end end)
eq("lines with a rule tag", tagged, 0)
eq("rule history", #M.PSS_FilterHistory(i), 0)

-- the Chat Filters row reads n/a
SlashCmdList.PSS("gui")
H.RunTimers()
_G.PSSTab2:GetScript("OnClick")(_G.PSSTab2)
local na = false
local realOffset = FauxScrollFrame_GetOffset
for off = 0, #db.filterList do
	FauxScrollFrame_GetOffset = function() return off end
	M.FilterListDrawUpdate(nil)
	for _, f in ipairs(H.frames) do if f._text == "n/a" and f:IsVisible() then na = true end end
end
FauxScrollFrame_GetOffset = realOffset
eq("Chat Filters row shows n/a", na, true)

-- a shipped member and the found member: counted on the guild only
-- (3.0: the rule is on, so the member lists were loaded at login)
eq("shipped lists loaded at login", C_AddOns.IsAddOnLoaded("PourSocialScore_Communities"), true)
local data = PourSocialScore_NS.MANAGED_DATA and PourSocialScore_NS.MANAGED_DATA.olympus
local shipped = data and M.PSS_ShippedNames(M.PSS_NormalizeGuild(data.guilds[1].name))[1]
local gBefore, fBefore = S.Session("guild").total, S.Session("filter").total
eq("rule on: found member blocked", whisper("Olyfound-Realm"), true)
eq("rule on: shipped member blocked", whisper(shipped), true)
eq("guild session", S.Session("guild").total - gBefore, 2)
eq("filter session", S.Session("filter").total - fBefore, 0)
eq("filter total after", tonumber(db.filterTotal) or 0, expect.oldFilterTotal - expect.oldRuleCount)
eq("rule count after", tonumber(db.filterCount[i]) or 0, 0)

-- linked: the rule off stops every guild block of the group
M.PSS_SetFilterActive(i, false)
eq("rule off: found member", whisper("Olyfound-Realm"), false)
eq("rule off: shipped member", whisper(shipped), false)
M.PSS_SetFilterActive(i, true)
eq("rule on again: found member", whisper("Olyfound-Realm"), true)
eq("rule on again: shipped member", whisper(shipped), true)

-- no mouseover / nameplate discovery in combat
local seen = 0
local realUpdate = M.PSS_UpdatePlayerUnit
M.PSS_UpdatePlayerUnit = function() seen = seen + 1 end
local guid = 0
local function mouseover()
	guid = guid + 1
	local g = "Player-1-" .. guid
	_G.UnitExists = function() return true end
	_G.UnitIsPlayer = function() return true end
	_G.UnitGUID = function(u) return g .. u end
	_G.UnitName = function(u) if u == "player" then return "Tester" end return "Mouse" .. guid, "Realm" end
	_G.GetGuildInfo = function() return "OLYMPUS" end
	H.Fire("UPDATE_MOUSEOVER_UNIT")
	H.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
end
mouseover()
eq("out of combat: looked at", seen, 2)
seen = 0
H.Fire("PLAYER_REGEN_DISABLED")
mouseover()
eq("in combat: looked at", seen, 0)
H.Fire("PLAYER_REGEN_ENABLED")
mouseover()
eq("after combat: looked at", seen, 2)
M.PSS_UpdatePlayerUnit = realUpdate
_G.UnitExists = function() return false end

print(fails == 0 and "PASS guild rule" or ("FAILED guild rule: " .. fails))
if fails > 0 then os.exit(1) end
