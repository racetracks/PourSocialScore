------------------------------------------------------------------------
-- POUR SOCIAL SCORE - SCROLLING BATTLE TEXT ENGINE (WoW Forever only)
--
-- Started and stopped by core (PSS_SBT.lua) when the sbtEnabled option
-- changes or at login. Later 3.4.0 builds add the sources here (combat
-- from UNIT_COMBAT, loot, money, XP, reputation, honor, skill); this one
-- only starts and stops. Draws nothing: PourSocialScore_ScrollingBattleText
-- draws. Its event frame is made on the first start, never at load.
--   M.PSS_SBTStart()      register the sources that are switched on
--   M.PSS_SBTStop()       unregister everything
--   M.PSS_SBTRunning()    true between a start and a stop
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local V = addon.V
local M = addon.M

local frame
local running = false

function M.PSS_SBTStart()
	if running or not V.wowIsForever then return end
	if not frame then frame = CreateFrame("Frame") end
	running = true
end

function M.PSS_SBTStop()
	if not running then return end
	frame:UnregisterAllEvents()
	running = false
end

function M.PSS_SBTRunning()
	return running
end
