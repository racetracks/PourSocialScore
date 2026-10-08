------------------------------------------------------------------------
-- POUR SOCIAL SCORE - OPENING THE WINDOW AND THE RELOAD PROMPT
--
-- From 3.4.0.23 (D1) every way in opens the Pour Social Score window
-- (PourSocialScore_UI, loaded on demand): /pss gui, /pss ui, the Addon
-- Compartment. The EllesmereUI integration is gone (its option is retired
-- and pruned at D2, when this file goes too); the old windows' folders are
-- no longer loaded. The reload prompt is Blizzard's StaticPopup in every
-- look (Dan, 2026-10-08).
--   M.PSS_OpenUI(show)    the window (show true: open, never toggle shut)
--   M.PSS_AskReload(text) the reload prompt
------------------------------------------------------------------------
local addonName, addon = ...
local L = addon.L
local M = addon.M

function M.PSS_OpenUI(show)
	if M.PSS_Need("UI") and M.PSS_OpenWindow then M.PSS_OpenWindow(show) end
end

-- Camelot (interface 16001) blocks ReloadUI() from addon code
local camelot = GetBuildInfo and (select(4, GetBuildInfo()) or 0) < 20000

StaticPopupDialogs["PSS_RELOAD"] = {
	preferredIndex	= STATICPOPUPS_NUMDIALOGS,
	text			= "%s",
	button1			= RELOADUI or "Reload UI",
	button2			= LATER or "Later",
	whileDead		= 1,
	hideOnEscape	= 1,
	OnAccept		= function() ReloadUI() end,
}

function M.PSS_AskReload(text)
	if camelot then
		M.ShowMsg(text .. " Type /reload.")
	else
		StaticPopup_Show("PSS_RELOAD", text)
	end
end
