-- The EllesmereUI switch is retired (3.4.0.23, D1; PSS_EUI.lua):
--   /pss eui (enable | disable) and /pss gui force only say the old windows
--   are gone; nothing switches, nothing loads
--   the option is not listed on the Options tab and asks for no reload
--   /pss gui opens the Pour Social Score window, never an old one
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local L = PourSocialScore_NS.L

local shown = {}
local oldShow = StaticPopup_Show
StaticPopup_Show = function(which, a) shown[#shown + 1] = { which, a } end
local said, realMsg = {}, M.ShowMsg
M.ShowMsg = function(x) said[#said + 1] = tostring(x) end

check(M.PSS_Opt("euiIntegration") == false, "default not off")
for _, cmd in ipairs({ "eui enable", "eui", "gui force" }) do
	said = {}
	SlashCmdList.PSS(cmd)
	check(said[1] == L["CMD_GONE"], "/pss " .. cmd .. " did not say the old windows are gone")
end
check(M.PSS_Opt("euiIntegration") == false and rawget(PSS_OptionsDB, "euiIntegration") == nil, "/pss eui enable still switches it")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI") and not loaded("PourSocialScore_UI"),
	"a retired command loaded a window")

-- a save with it on (an older version): no reload prompt, not listed
M.PSS_SetOpt("euiIntegration", "global", true)
check(#shown == 0, "the retired option asked for a reload")
M.PSS_Need("Libraries")
for _, g in ipairs(M.PSS_OptGroups()) do
	for _, it in ipairs(g.items) do check(it.o.key ~= "euiIntegration", "the retired option is listed") end
end

-- /pss gui: the Pour Social Score window, even with EllesmereUI loaded
EllesmereUI = { ShowConfirmPopup = function() end, RegisterPlugin = function() return true end }
SlashCmdList.PSS("gui")
check(_G.PSS_Window and _G.PSS_Window:IsShown(), "/pss gui did not open the window")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "/pss gui loaded an old window")

EllesmereUI = nil
M.ShowMsg = realMsg
StaticPopup_Show = oldShow
if not fail then print("PASS eui") end
