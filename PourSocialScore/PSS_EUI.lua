------------------------------------------------------------------------
-- POUR SOCIAL SCORE - ELLESMEREUI INTEGRATION SWITCH
--
-- The euiIntegration option (PSS_Options.lua) picks the front end: off,
-- the PSS windows (PourSocialScore_GUI); on, the EllesmereUI style
-- (PourSocialScore_EllesmereUI: a PSS window at Friends in EllesmereUI's
-- style, and a "Pour Social Score" section in the EllesmereUI panel). It is
-- read at login, so a change asks for a reload. With EllesmereUI loaded the
-- prompt is its own (its Reload Now button works on the Forever client,
-- where addon code may not call ReloadUI).
--   M.PSS_HasEUI()        EllesmereUI is loaded
--   M.PSS_UseEUI()        the option is on and EllesmereUI is loaded
--   M.PSS_OpenUI(force)   /pss gui: the EllesmereUI window when in use,
--                         else (or with force) the PSS windows
--   M.PSS_RegisterEUI()   at login: the panel section (EllesmereUI plugin
--                         API); its pages load PourSocialScore_EllesmereUI
--   M.PSS_OpenEUIPanel()  /pss eui: the panel on that section
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

-- The plugin id is the folder that draws the pages (EllesmereUI's rule).
local PLUGIN = "PourSocialScore_EllesmereUI"

local function pageBuilder(module)
	return function(page, parent, y)
		-- the search pre-build pass indexes a page only once its addon is loaded
		if not M.EUI_BuildPage and EllesmereUI.IsSearchPrebuild and EllesmereUI.IsSearchPrebuild() then return 0 end
		if M.PSS_Need("EllesmereUI") and M.EUI_BuildPage then return M.EUI_BuildPage(module, page, parent, y) end
		return 0
	end
end

function M.PSS_RegisterEUI()
	if not (M.PSS_UseEUI() and EllesmereUI.RegisterPlugin) then return end
	if EllesmereUI.IsPluginRegistered and EllesmereUI.IsPluginRegistered(PLUGIN) then return end
	EllesmereUI.RegisterPlugin(PLUGIN, {
		label	= "Pour Social Score",
		modules	= {
			{ key = "Options", title = "Options", description = "Settings for every character on this account.",
				pages = { "General" }, buildPage = pageBuilder("Options") },
		},
	})
end

function M.PSS_OpenEUIPanel()
	if not EllesmereUI.OpenPlugin then M.ShowMsg(L["EUI_7"]) return end
	if InCombatLockdown() then M.ShowMsg(L["EUI_6"]) return end
	EllesmereUI.OpenPlugin(PLUGIN)
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
