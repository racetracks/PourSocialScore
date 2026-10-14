-- A small WoW client for the trigger engine checks (check_trig.lua, TST-00177 to TST-00201). Our own code, tests only.
-- Frames with events and scripts, widget interactions, a Cooldown widget, animation groups,
-- one-shot timers on a simulated clock, combat state. It counts every OnUpdate ever set, so a
-- test can prove none was. Each dofile returns a fresh client.

local C = { ms = 0, now = 0, combat = false, frames = {}, timers = {}, onUpdateSets = 0, timerCalls = 0 }

local Frame = {}
Frame.__index = Frame
function Frame:RegisterEvent(e) self.ev[e] = true end
function Frame:UnregisterEvent(e) self.ev[e] = nil end
function Frame:IsEventRegistered(e) return self.ev[e] == true end
function Frame:SetScript(k, fn)
	if k == "OnUpdate" and fn then C.onUpdateSets = C.onUpdateSets + 1 end
	self.scripts[k] = fn
end
function Frame:HookScript(k, fn)
	if k == "OnUpdate" then C.onUpdateSets = C.onUpdateSets + 1 end
	local old = self.scripts[k]
	self.scripts[k] = old and function(...) old(...); fn(...) end or fn
end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
-- Cooldown widget: the client draws the sweep and the numbers; OnCooldownDone is not relied on
function Frame:SetCooldown(start, duration) self.cdStart, self.cdDuration = start, duration end
function Frame:Clear() self.cdStart, self.cdDuration = nil, nil end
function Frame:SetHideCountdownNumbers(h) self.hideNumbers = h end
-- Animation groups: the client animates; OnFinished fires when Finish() is driven by the test
function Frame:CreateAnimationGroup()
	local g = { anims = {}, scripts = {}, playing = false }
	function g:CreateAnimation(kind) local a = { kind = kind }; self.anims[#self.anims + 1] = a
		function a:SetFromAlpha(v) self.from = v end
		function a:SetToAlpha(v) self.to = v end
		function a:SetDuration(v) self.duration = v end
		return a
	end
	function g:SetScript(k, fn) self.scripts[k] = fn end
	function g:Play() self.playing = true end
	function g:Stop() self.playing = false end
	function g:Finish() self.playing = false; if self.scripts.OnFinished then self.scripts.OnFinished(self) end end
	self.groups = self.groups or {}
	self.groups[#self.groups + 1] = g
	return g
end

function C.CreateFrame(kind, name, parent)
	local f = setmetatable({ kind = kind, ev = {}, scripts = {}, shown = true, parent = parent }, Frame)
	C.frames[#C.frames + 1] = f
	return f
end

function C.Fire(e, ...)
	for i = 1, #C.frames do
		local f = C.frames[i]
		if f.ev[e] and f.scripts.OnEvent then f.scripts.OnEvent(f, e, ...) end
	end
end
function C.Interact(f, script, ...)
	if f.scripts[script] then f.scripts[script](f, ...) end
end
function C.GetTime() return C.now end
function C.debugprofilestop() return C.ms end
function C.InCombatLockdown() return C.combat end
C.afk = false
function C.UnitIsAFK(unit) return unit == "player" and C.afk end

C.C_Timer = {}
function C.C_Timer.After(delay, fn)
	C.timerCalls = C.timerCalls + 1
	C.timers[#C.timers + 1] = { at = C.now + delay, fn = fn }
end
-- Advance the clock, running due timers in time order (each once).
function C.Advance(seconds)
	local target = C.now + seconds
	while true do
		local best, bi
		for i = 1, #C.timers do
			local t = C.timers[i]
			if t.at <= target and (not best or t.at < best.at) then best, bi = t, i end
		end
		if not best then break end
		table.remove(C.timers, bi)
		C.now = best.at
		best.fn()
	end
	C.now = target
end
function C.Registered()
	local n = 0
	for i = 1, #C.frames do for _ in pairs(C.frames[i].ev) do n = n + 1 end end
	return n
end

return C
