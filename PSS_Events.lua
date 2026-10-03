------------------------------------------------------------------------
-- POUR SOCIAL SCORE - EVENTS
--
-- A tiny register / fire list, so the core (data, /who) can say
-- "something changed" without knowing which UI is loaded. Any UI - this
-- addon's own windows or another addon - listens with Register.
--
--   local id = M.Events.Register("WHOIS_COOLDOWN", function(active) ... end)
--   M.Events.Unregister("WHOIS_COOLDOWN", id)
--   M.Events.Fire("WHOIS_COOLDOWN", true)
--
-- Events fired so far (see PSS_Whois.lua):
--   WHOIS_COOLDOWN (active)  the shared /who cooldown started (true) or ended (false)
--   WHOIS_ANSWERED (req)     a /who answer (or a timeout) was handled; req may be nil
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

local Events = {}
M.Events = Events

local listeners = {}   -- [event] = { [id] = fn }
local nextId = 0

function Events.Register(event, fn)
	nextId = nextId + 1
	listeners[event] = listeners[event] or {}
	listeners[event][nextId] = fn
	return nextId
end

function Events.Unregister(event, id)
	if listeners[event] then listeners[event][id] = nil end
end

-- A listener that errors does not stop the others.
function Events.Fire(event, ...)
	local list = listeners[event]
	if not list then return end
	for _, fn in pairs(list) do
		local ok, err = pcall(fn, ...)
		if not ok and M.debugMsg then M.debugMsg("PSS event " .. event .. ": " .. tostring(err)) end
	end
end
