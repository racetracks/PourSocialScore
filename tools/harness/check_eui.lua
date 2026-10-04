-- EllesmereUI integration switch (3.1 Step E.1, PSS_EUI.lua):
--   the option defaults off and is not saved while off
--   /pss eui enable | disable switch it and ask for a reload: the PSS popup
--   without EllesmereUI, EllesmereUI's own (reload = true) with it
--   /pss gui opens the PSS windows (no EllesmereUI front end yet), gui force too
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

local shown = {}
local oldShow = StaticPopup_Show
StaticPopup_Show = function(which, a) shown[#shown + 1] = { which, a } end

check(M.PSS_Opt("euiIntegration") == false, "default not off")
check(not M.PSS_UseEUI(), "in use without EllesmereUI")

SlashCmdList.PSS("eui enable")
check(M.PSS_Opt("euiIntegration") == true, "enable did not switch it on")
check(#shown == 1 and shown[1][1] == "PSS_RELOAD" and shown[1][2]:find("now on"), "no PSS reload prompt on enable")
SlashCmdList.PSS("eui enable")
check(#shown == 1, "asked again when already on")
check(not M.PSS_UseEUI(), "in use without EllesmereUI loaded")

-- /pss gui: still the PSS windows
SlashCmdList.PSS("gui")
check(loaded("PourSocialScore_GUI"), "/pss gui did not open the PSS windows")

-- EllesmereUI loaded: its popup, reload = true
local asked
EllesmereUI = { ShowConfirmPopup = function(self, o) asked = o end, RegisterPlugin = function() return true end }
check(M.PSS_UseEUI(), "not in use with EllesmereUI and the option on")
SlashCmdList.PSS("eui disable")
check(M.PSS_Opt("euiIntegration") == false, "disable did not switch it off")
check(rawget(PSS_OptionsDB, "euiIntegration") == nil, "the default is saved")
check(asked and asked.reload == true and asked.message:find("now off"), "no EllesmereUI reload prompt")
check(#shown == 1, "PSS popup shown with EllesmereUI loaded")

-- the Options tab tickbox goes through the same path
asked = nil
M.PSS_SetOpt("euiIntegration", "global", true)
check(asked and asked.reload == true, "tickbox did not ask for a reload")
check(rawget(PSS_OptionsDB, "euiIntegration") == true, "on is not saved")
SlashCmdList.PSS("gui force")
SlashCmdList.PSS("eui")

EllesmereUI = nil
StaticPopup_Show = oldShow
if not fail then print("PASS eui") end
