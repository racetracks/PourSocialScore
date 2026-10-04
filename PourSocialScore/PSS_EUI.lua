------------------------------------------------------------------------
-- POUR SOCIAL SCORE - ELLESMEREUI INTEGRATION SWITCH
--
-- The euiIntegration option (PSS_Options.lua) picks the front end: off,
-- the PSS windows (PourSocialScore_GUI); on, the EllesmereUI style
-- (PourSocialScore_EllesmereUI, step E.2 on). It is read at login, so a
-- change asks for a reload. With EllesmereUI loaded the prompt is its own
-- (its Reload Now button works on the Forever client, where addon code may
-- not call ReloadUI).
--   M.PSS_HasEUI()        EllesmereUI is loaded
--   M.PSS_UseEUI()        the option is on and EllesmereUI is loaded
--   M.PSS_OpenUI(force)   /pss gui: the EllesmereUI front end when in use,
--                         else (or with force) the PSS windows
--   M.PSS_SetEUI(on)      /pss eui enable | disable
--   M.PSS_AskReload(text) the reload prompt
------------------------------------------------------------------------
local addonName, addon = ...
local L = addon.L
local M = addon.M

function M.PSS_HasEUI()
	return type(EllesmereUI) == "table" and EllesmereUI.ShowConfirmPopup ~= nil
end

function M.PSS_UseEUI()
	return M.PSS_Opt("euiIntegration") == true and M.PSS_HasEUI()
end

function M.PSS_OpenUI(force)
	if not force and M.PSS_UseEUI() and M.PSS_PARTS.EllesmereUI
		and M.PSS_Need("EllesmereUI") and M.EUI_Toggle then
		return M.EUI_Toggle()
	end
	M.PSS_GUI()
end

function M.PSS_SetEUI(on)
	if (M.PSS_Opt("euiIntegration") == true) == on then
		M.ShowMsg(format(L["EUI_4"], on and L["ON"] or L["OFF"]))
		return
	end
	if on and not M.PSS_HasEUI() then M.ShowMsg(L["EUI_5"]) end
	M.PSS_SetOpt("euiIntegration", "global", on)	-- asks for the reload
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
	if M.PSS_HasEUI() then
		EllesmereUI:ShowConfirmPopup({
			title		= "Pour Social Score",
			message		= text,
			confirmText	= "Reload Now",
			cancelText	= "Later",
			reload		= true,
		})
	elseif camelot then
		M.ShowMsg(text .. " Type /reload.")
	else
		StaticPopup_Show("PSS_RELOAD", text)
	end
end
