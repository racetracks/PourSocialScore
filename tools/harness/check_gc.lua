-- Event-driven memory cleanup and Logging load (3.4.1.52, baseline 02 C15):
-- no timer, no idle cycle, no wall-clock gate; a request made in combat or in
-- an instance waits for an event; the wake events are registered only while a
-- request waits.
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_gc.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL gc: " .. msg) fail = true end end

-- the source holds no timer
local f = io.open("PourSocialScore/PSS_Perf.lua", "r")
local src = f and f:read("*a") or ""
if f then f:close() end
check(src ~= "", "PSS_Perf.lua not readable")
check(not src:find("C_Timer", 1, true), "PSS_Perf.lua uses C_Timer")
check(not src:find("IDLE_INTERVAL", 1, true) and not src:find("COMBAT_COOLDOWN", 1, true), "an idle or cooldown gate is left")

local EV = { "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_ALIVE", "PLAYER_UNGHOST" }
-- listeners are counted by Fire's return (nothing here handles these events)
local function listeners()
	local n = 0
	for _, e in ipairs(EV) do n = n + H.Fire(e) end
	return n
end

local gc = M.PSS_GCState
local combat, inst = false, false
InCombatLockdown = function() return combat end
IsInInstance = function() return inst, inst and "party" or "none" end


-- let the login request finish
H.RunOnUpdate(400)
H.RunTimers()
check(not gc.running, "the login cycle did not finish")
local base = listeners()

-- idle: no cycle, however long the clock runs
local cycles = gc.cycles
H.Advance(7200)
H.RunTimers()
H.RunOnUpdate(50)
check(gc.cycles == cycles and not gc.running, "a cycle ran by itself (idle)")
check(not gc.waiting and listeners() == base, "wake events registered while nothing waits")

-- a request in combat waits
combat = true
M.PSS_RequestGC("test combat")
check(not gc.running and gc.pending and gc.waiting, "request in combat did not wait")
check(listeners() == base + #EV, "wake events not registered while waiting (" .. (listeners() - base) .. ")")
check(gc.lastReason == "test combat", "reason lost")
-- still in combat when the event fires: keeps waiting
H.Fire("PLAYER_REGEN_ENABLED")
check(not gc.running and gc.waiting, "started while still in combat")
-- out of combat but inside an instance
combat = false
inst = true
H.Fire("PLAYER_REGEN_ENABLED")
check(not gc.running and gc.waiting, "started inside an instance")
H.Advance(3600)
H.RunOnUpdate(20)
check(not gc.running, "time alone started a cycle")
-- the zone change that leaves the instance wakes it
inst = false
H.Fire("ZONE_CHANGED_NEW_AREA")
check(gc.running or gc.cycles > cycles, "no cycle after leaving the instance")
check(not gc.waiting and listeners() == base, "wake events left registered after the start")
H.RunOnUpdate(400)
check(gc.cycles == cycles + 1 and not gc.pending, "the cycle did not finish")

-- combat in the middle of a cycle: it stops and waits
cycles = gc.cycles
M.PSS_RequestGC("test mid")
check(gc.running, "no cycle started in a quiet moment")
combat = true
H.RunOnUpdate(1)
check(not gc.running and gc.pending and gc.waiting, "the cycle did not stop for combat")
combat = false
H.Fire("PLAYER_REGEN_ENABLED")
check(gc.running or gc.cycles > cycles, "no resume after combat")
H.RunOnUpdate(400)
check(gc.cycles == cycles + 1 and listeners() == base, "the resumed cycle")

-- the option off: a request starts nothing and registers nothing
M.PSS_SetOpt("gcEnabled", "global", false)
M.PSS_RequestGC("test off")
check(not gc.running and listeners() == base, "cleanup ran or waited with the option off")
M.PSS_SetOpt("gcEnabled", "global", true)
gc.pending = false

if not fail then print("PASS gc") end
