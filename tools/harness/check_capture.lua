-- Capture events only while they can be used (core uplift P3, 3.4.1.52):
-- target, mouseover, nameplate and group scans, and /who answers read from
-- chat or the Who list, are registered only while a listed player exists, a
-- guild rule of the player's own or a switched-on shipped list exists, or a
-- /who of ours waits. A fresh save (no players, every shipped list off) hears
-- none of them.
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_capture.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL capture: " .. msg) fail = true end end

local UNIT = { "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }
local WHO = { "WHO_LIST_UPDATE", "CHAT_MSG_SYSTEM" }
local function count(list)
	local n = 0
	for _, e in ipairs(list) do n = n + H.Listeners(e) end
	return n
end

-- none of the shipped lists is on and nobody is listed
check(#M.PSS_List() == 0, "the test save lists players")
check(not M.PSS_CaptureNeeded(), "capture needed on a bare save")
check(count(UNIT) == 0, "unit events registered with nothing to use them: " .. count(UNIT))
check(count(WHO) == 0, "who events registered with nothing to use them: " .. count(WHO))

-- a /who of ours waits: the answer events are heard, then dropped
M.Whois.Request({ kind = "guildSearch", filter = 'g-"Nothing"', query = "Nothing", found = {} })
check(M.Whois.Pending() ~= nil, "no request pending")
check(count(WHO) == #WHO, "who events not registered while a /who waits")
check(count(UNIT) == 0, "a /who registered the unit events")
H.Fire("WHO_LIST_UPDATE")
check(M.Whois.Pending() == nil, "the answer did not finish the request")
check(count(WHO) == 0, "who events left registered after the answer")
H.RunTimers()

-- a listed player
M.PSS_AddIgnore("Capture-Realm", true)
check(M.PSS_CaptureNeeded(), "a listed player does not ask for capture")
check(count(UNIT) == #UNIT, "unit events not registered for a listed player (" .. count(UNIT) .. ")")
check(count(WHO) == #WHO, "who events not registered for a listed player")
local idx
for i in ipairs(M.PSS_List()) do if (M.PSS_EntryName(i) or ""):lower():find("capture", 1, true) then idx = i end end
check(idx ~= nil, "entry not found")
if idx then M.PSS_DelIgnore(idx, true, true) end
check(not M.PSS_CaptureNeeded(), "still needed with nobody listed")
check(count(UNIT) == 0 and count(WHO) == 0, "events left registered with nobody listed")

-- a guild rule of the player's own
M.PSS_AddGuild("Capture Guild")
check(count(UNIT) == #UNIT and count(WHO) == #WHO, "events not registered for a guild rule")
M.PSS_RemoveGuildNow(M.PSS_NormalizeGuild("Capture Guild"))
check(count(UNIT) == 0 and count(WHO) == 0, "events left registered after the rule went")

-- a shipped list switched on, then off
local gk
for _, g in pairs(PourSocialScoreDB.guildData or {}) do if g.managed then gk = g.managed break end end
if gk then
	M.PSS_SetManagedGroupActive(gk, true)
	check(count(UNIT) == #UNIT and count(WHO) == #WHO, "events not registered with a shipped list on")
	M.PSS_SetManagedGroupActive(gk, false)
	check(count(UNIT) == 0 and count(WHO) == 0, "events left registered with the shipped list off")
else
	check(false, "no shipped group found")
end

if not fail then print("PASS capture") end
