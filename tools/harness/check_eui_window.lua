-- EllesmereUI front end (3.1 Step E.2), with the EllesmereUI stand-in and
-- PourSocialScore_EllesmereUI loaded through PSS_EXTRA_ADDONS.
--   PSS_PHASE=1 : switch the option on (saved; logout)
--   PSS_PHASE=3 : the window with EllesmereUI's skinning off for us
--   PSS_PHASE=2 : the login after the reload:
--   our panel section is registered at login, the new addon is not loaded
--   a page build loads it and draws its rows (DualRow slots filled, no nil)
--   the search pre-build never loads it
--   /pss gui and Friends open the EllesmereUI window, never PourSocialScore_GUI
--   /pss gui force opens PourSocialScore_GUI; /pss eui opens the panel
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui window: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local E = EllesmereUI
local NAME = "PourSocialScore_EllesmereUI"

if os.getenv("PSS_PHASE") == "1" then
	check(#E.log.plugins == 0, "registered while off")
	SlashCmdList.PSS("eui enable")
	check(#E.log.popups == 1 and E.log.popups[1].reload, "no EllesmereUI reload prompt")
	check(not loaded(NAME), "enable loaded the addon")
	if not fail then print("PASS eui window 1") end
	return
end

-- PSS_PHASE=3 : skinning off for us in EllesmereUI: the plain look
if os.getenv("PSS_PHASE") == "3" then
	E.skinsOn = false
	SlashCmdList.PSS("gui")
	local win = _G.PSS_EllesmereUIWindow
	check(win and win:IsShown(), "no window without skinning")
	check(#E.log.skinned == 0, "skinned with skinning off")
	if not fail then print("PASS eui window 3") end
	return
end

check(M.PSS_UseEUI(), "integration not in use")
check(E.log.plugins[1] == NAME and #E.log.plugins == 1, "panel section not registered once")
local spec = E.GetPlugin(NAME)
check(spec and spec.label == "Pour Social Score", "label")
check(not loaded(NAME), "loaded at login")
check(not loaded("PourSocialScore_GUI"), "GUI loaded at login")

-- search pre-build pass before the addon is loaded: nothing loads
E.prebuild = true
check(spec.modules[1].buildPage("General", {}, -10) == 0, "pre-build drew a page")
check(not loaded(NAME), "pre-build loaded the addon")
E.prebuild = false

-- a real page build
local h = spec.modules[1].buildPage("General", {}, -10)
check(loaded(NAME), "page build did not load the addon")
check(h and h > 10, "page height " .. tostring(h))
for _, r in ipairs(E.rows) do
	if r[1] == "dual" then check(r[2] ~= nil and r[3] ~= nil, "a DualRow with an empty slot") end
end
check(type(PSS_EllesmereUIDB) == "table", "no saved table")

-- the window
SlashCmdList.PSS("gui")
local win = _G.PSS_EllesmereUIWindow
check(win and win:IsShown(), "/pss gui did not show the window")
check(not loaded("PourSocialScore_GUI"), "/pss gui loaded PourSocialScore_GUI")
check(#E.log.escape == 1, "Escape not registered")
local shells = 0
for _, k in ipairs(E.log.skinned) do if k == "Shell" then shells = shells + 1 end end
check(shells == 1, "window not painted with S.Shell (" .. shells .. ")")
SlashCmdList.PSS("gui")
check(not win:IsShown(), "/pss gui did not toggle it off")

FriendsFrame:Show()
check(win:IsShown() and win.byFriends, "Friends did not show the window")
FriendsFrame:Hide()
check(not win:IsShown(), "closing Friends left it open")
check(not loaded("PourSocialScore_GUI"), "Friends loaded PourSocialScore_GUI")

SlashCmdList.PSS("eui")
check(E.log.opened[1] == NAME, "/pss eui did not open the panel")

SlashCmdList.PSS("gui force")
check(loaded("PourSocialScore_GUI"), "/pss gui force did not open PourSocialScore_GUI")

if not fail then print("PASS eui window 2") end
