------------------------------------------------------------------------
-- POUR SOCIAL SCORE - MEMORY / GARBAGE COLLECTION
--
-- WoW's Lua heap is shared by every addon and collected incrementally by the
-- game. A full collectgarbage("collect") stops the whole UI for as long as
-- it takes (a visible hitch), so Pour Social Score NEVER calls it.
--
-- Instead, when there is something to clean up, it adds small incremental
-- collection steps - collectgarbage("step") - spread over many frames:
--   * never in combat, in a boss encounter or while the player is dead /
--     loading; a step cycle stops the moment combat starts
--   * at most STEP_BUDGET_MS per frame (less when the frame rate is low)
--   * not at all below MIN_FPS
--   * a cycle runs when asked for (after a /who scan, an import, closing the
--     window, building the shipped guild index ...), when the Lua heap has
--     grown by GROWTH_KB since the last cycle, or every IDLE_INTERVAL seconds
--     (once a minute)
-- Options > "Background memory cleanup (out of combat)" turns it off.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

local CHECK_INTERVAL  = 15        -- seconds between checks
local IDLE_INTERVAL   = 60        -- a cycle at least once a minute (when safe)
local GROWTH_KB       = 8 * 1024  -- or when the heap grew this much
local STEP_KB         = 8         -- size of one collector step (small: fine-grained budget)
local STEP_BUDGET_MS  = 1.0       -- max time per frame
local MIN_FPS         = 30
local MAX_FRAMES      = 900       -- give up a cycle after this many frames

local gc = { pending = false, running = false, lastCycle = 0, heapAfter = nil, supported = true, frames = 0,
			cycles = 0, lastReason = nil, lastMs = 0 }
M.PSS_GCState = gc

local function enabled()
	return not (M.PSS_Opt and M.PSS_Opt("gcEnabled") == false)
end

local function inCombatOrBusy()
	if InCombatLockdown and InCombatLockdown() then return true end
	if UnitAffectingCombat and UnitAffectingCombat("player") then return true end
	if IsEncounterInProgress and IsEncounterInProgress() then return true end
	if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return true end
	return false
end

local function heapKB()
	local ok, kb = pcall(collectgarbage, "count")
	return ok and kb or 0
end

local runner = CreateFrame("Frame")
runner:Hide()

local function stopCycle(completed)
	runner:Hide()
	gc.running = false
	if completed then
		gc.pending = false
		gc.lastCycle = GetTime()
		gc.heapAfter = heapKB()
		gc.cycles = gc.cycles + 1
	end
end

runner:SetScript("OnUpdate", function(self, elapsed)
	if not gc.running then self:Hide() return end
	if inCombatOrBusy() or not enabled() then stopCycle(false) return end
	gc.frames = gc.frames + 1
	if gc.frames > MAX_FRAMES then stopCycle(true) return end

	-- frame budget: never more than STEP_BUDGET_MS, and a smaller share of a
	-- slow frame (5 % of the last frame time)
	local fps = GetFramerate and GetFramerate() or 60
	if fps < MIN_FPS then return end        -- wait for a calmer moment
	local budget = math.min(STEP_BUDGET_MS, (elapsed or 0.016) * 1000 * 0.05)
	local clock = debugprofilestop
	local start = clock and clock() or 0
	repeat
		local ok, done = pcall(collectgarbage, "step", STEP_KB)
		if not ok then gc.supported = false; stopCycle(false) return end
		if done then
			gc.lastMs = (clock and (clock() - start)) or 0
			stopCycle(true)
			return
		end
	until not clock or (clock() - start) >= budget
end)

local function startCycle(reason)
	if gc.running or not gc.supported or not enabled() or inCombatOrBusy() then return false end
	gc.running = true
	gc.frames = 0
	gc.lastReason = reason
	runner:Show()
	return true
end

-- Ask for a cleanup soon (it waits for a safe moment).
function M.PSS_RequestGC(reason)
	gc.pending = true
	gc.lastReason = reason or gc.lastReason
end

local function check()
	if gc.running or not gc.supported or not enabled() or inCombatOrBusy() then return end
	local now = GetTime()
	local grew = gc.heapAfter and (heapKB() - gc.heapAfter) >= GROWTH_KB
	if gc.pending or grew or (now - gc.lastCycle) >= IDLE_INTERVAL then
		startCycle(gc.pending and gc.lastReason or (grew and "heap grew") or "idle")
	end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if gc.running then stopCycle(false); gc.pending = true end   -- resume after combat
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- not straight away: leaving combat is busy too
		if gc.pending and C_Timer then C_Timer.After(5, check) end
	elseif event == "PLAYER_LOGIN" then
		gc.lastCycle = GetTime()
		gc.heapAfter = heapKB()
		-- loading is over; tidy up once things have settled
		M.PSS_RequestGC("login")
		if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(CHECK_INTERVAL, check) end
	end
end)

------------------------------------------------------------------------
-- /pss mem [full] - what Pour Social Score is holding in memory.
-- Numbers marked ~ are estimates (Lua cannot measure one table exactly);
-- "addon memory" is the game's own figure for the whole addon.
------------------------------------------------------------------------
local function kb(bytes) return ("%.0f KB"):format((bytes or 0) / 1024) end

function M.PSS_MemReport(full)
	local out = function(s) if M.ShowMsg then M.ShowMsg(s) else print(s) end end
	local db = PourSocialScoreDB
	if type(db) ~= "table" then out("Pour Social Score: not loaded yet.") return end
	local H = M.PSS_History

	out("|cffff99ffPour Social Score memory|r")

	-- the game's figure for this addon (walks every addon: not in combat)
	local addonKB
	local inCombat = InCombatLockdown and InCombatLockdown()
	local getMem = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
	local updMem = UpdateAddOnMemoryUsage or (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)
	if not inCombat and updMem and getMem then
		pcall(updMem)
		local ok, v = pcall(getMem, addonName)
		if ok then addonKB = v end
	end
	out(("  addon memory: %s   |   game Lua heap (all addons): %.1f MB"):format(
		addonKB and ("%.2f MB"):format(addonKB / 1024) or (inCombat and "(not measured in combat)" or "n/a"),
		heapKB() / 1024))

	-- the shared block log
	if H then
		local bytes, n = H.EstimateBytes()
		local log = H.Log()
		local byType = { p = 0, g = 0, f = 0 }
		local byOwner = full and {} or nil
		for i = 1, #log do
			local o = log[i].o
			local t = type(o) == "string" and o:sub(1, 1)
			if t and byType[t] then byType[t] = byType[t] + 1 end
			if byOwner and o then byOwner[o] = (byOwner[o] or 0) + 1 end
		end
		local keptLines, keptPeople = H.KeepSize()
		out(("  block history: %d / %d lines (~%s)  -  players %d, guild members %d, filters %d"):format(
			n, H.Cap(), kb(bytes), byType.p, byType.g, byType.f))
		out(("  kept per person (older than the log): %d lines for %d people"):format(keptLines, keptPeople))
		if byOwner then
			local top = {}
			for o, c in pairs(byOwner) do top[#top + 1] = { o = o, c = c } end
			table.sort(top, function(a, b) return a.c > b.c end)
			for i = 1, math.min(10, #top) do
				local o = top[i].o
				local kind = ({ p = "player", g = "guild member", f = "filter" })[o:sub(1, 1)] or "?"
				out(("      %4d  %s %s"):format(top[i].c, kind, o:sub(3)))
			end
		end
	end

	-- lists
	local players = 0
	for i = 1, #(db.ignoreList or {}) do if (db.typeList and db.typeList[i] or "player") == "player" then players = players + 1 end end
	local rules, stored, managedRules = 0, 0, 0
	for _, g in pairs(db.guildData or {}) do
		if type(g) == "table" then
			rules = rules + 1
			if g.managed then managedRules = managedRules + 1 end
			for _ in pairs(g.members or {}) do stored = stored + 1 end
		end
	end
	local pd = 0
	for _ in pairs(db.playerData or {}) do pd = pd + 1 end
	out(("  Player Ignore List: %d players (%d player records)   |   Guild Ignore List: %d rules, %d saved members"):format(
		players, pd, rules, stored))
	if M.PSS_ManagedStats then
		local ms = M.PSS_ManagedStats()
		out(("  shipped guild lists: %d names in %d rules, %d indexed, %d records in use, %d changed (saved at logout)"):format(
			ms.shipped, managedRules, ms.indexed, ms.cached, ms.kept))
	end
	local active = 0
	for i = 1, #(db.filterList or {}) do if db.filterActive[i] then active = active + 1 end end
	out(("  chat filters: %d (%d on)"):format(#(db.filterList or {}), active))

	-- collector
	local gcs = M.PSS_GCState
	out(("  memory cleanup: %s, %d cycle(s) this session%s"):format(
		(M.PSS_Opt and M.PSS_Opt("gcEnabled") == false and "off") or (gcs.supported and (gcs.running and "running now" or "idle") or "not supported"),
		gcs.cycles or 0, gcs.lastReason and (", last: " .. gcs.lastReason) or ""))
	if not full then out("  |cffaaaaaa/pss mem full|r also lists who has the most history lines.") end
end
