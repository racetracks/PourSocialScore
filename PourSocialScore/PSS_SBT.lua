------------------------------------------------------------------------
-- POUR SOCIAL SCORE - SCROLLING BATTLE TEXT SWITCH (WoW Forever only)
--
-- Core keeps only the switch: the sbtEnabled option (PSS_Options.lua, its
-- own section), /pss sbt (routed here from the /pss slash) and the start
-- at login. The engine is in PourSocialScore_Libraries (PSS_SBTEngine.lua)
-- and the drawing in PourSocialScore_ScrollingBattleText, both loaded only
-- when the option is on. Off, nothing loads and nothing is registered.
-- Other clients never start it and do not show the option; they keep
-- only the one-line answer to /pss sbt.
--   M.PSS_SBTApply()       start or stop to match the option (login, option change)
--   M.PSS_SlashSBT(msg)    /pss sbt [on | off]
------------------------------------------------------------------------
local addonName, addon = ...
local L = addon.L
local V = addon.V
local M = addon.M

-- other clients keep only the answer to /pss sbt
if not V.wowIsForever then
	function M.PSS_SBTApply() end
	function M.PSS_SlashSBT() M.ShowMsg(L["SBT_1"]) end
	return
end

M.PSS_PARTS.ScrollingBattleText = "PourSocialScore_ScrollingBattleText"

function M.PSS_SBTApply()
	if M.PSS_Opt("sbtEnabled") == true then
		-- the window part needs Libraries (PSS_Loader.lua), which holds the engine
		if M.PSS_Need("ScrollingBattleText") and M.PSS_SBTStart then M.PSS_SBTStart() end
	elseif M.PSS_SBTStop then
		M.PSS_SBTStop()
	end
end

M.Events.Register("OPTION_CHANGED", function(key)
	if key == "sbtEnabled" and V.PSS_Loaded then M.PSS_SBTApply() end
end)

function M.PSS_SlashSBT(msg)
	local cmd = M.trim(msg or ""):lower()
	if cmd == "" then cmd = M.PSS_Opt("sbtEnabled") == true and "off" or "on" end
	if cmd == "on" or cmd == "off" then
		M.PSS_SetOpt("sbtEnabled", "global", cmd == "on")
		M.ShowMsg(format(L["SBT_2"], cmd == "on" and L["ON"] or L["OFF"]))
	elseif cmd == "test" or cmd == "unlock" or cmd == "config" then
		M.ShowMsg(format(L["SBT_3"], cmd))
	else
		M.ShowMsg(L["SBT_4"])
	end
end
