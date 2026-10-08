-- The EllesmereUI front end is retired (3.4.0.23, D1), with the EllesmereUI
-- stand-in and PourSocialScore_EllesmereUI loaded through PSS_EXTRA_ADDONS.
--   PSS_PHASE=1 : a save with the old integration option on (no reload
--                 prompt, nothing registered or loaded)
--   PSS_PHASE=2 : the login after: no panel section is registered and the
--                 old folder is not loaded; /pss gui and Friends / Social
--                 open the Pour Social Score window; the old window, opened
--                 directly (until D2 deletes it), still builds its tabs
--   PSS_PHASE=3 : the old window with EllesmereUI's skinning off for us
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui window: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local E = EllesmereUI
local NAME = "PourSocialScore_EllesmereUI"

local function OpenOld()
	if M.PSS_Need("EllesmereUI") and M.EUI_Toggle then M.EUI_Toggle() end
end

if os.getenv("PSS_PHASE") == "1" then
	check(#E.log.plugins == 0, "registered at login")
	M.PSS_SetOpt("euiIntegration", "global", true)
	check(#E.log.popups == 0, "the retired option asked for a reload")
	check(not loaded(NAME), "the option loaded the old folder")
	if not fail then print("PASS eui window 1") end
	return
end

-- PSS_PHASE=3 : skinning off for us in EllesmereUI: the plain look
if os.getenv("PSS_PHASE") == "3" then
	E.skinsOn = false
	-- a tab saved by number (before 3.2.0-dev010, five tabs): 4 was Import/Export
	PSS_EllesmereUIDB = { tab = 4 }
	OpenOld()
	local win = _G.PSS_EllesmereUIWindow
	check(win and win:IsShown(), "no window without skinning")
	check(win.pages[5]:IsShown() and win.tabs[4]:GetText() == "Events" and PSS_EllesmereUIDB.tab == "BuildImportExportTab",
		"an old saved tab number not moved past Events: " .. tostring(PSS_EllesmereUIDB.tab))
	check(#E.log.skinned == 0, "skinned with skinning off")
	-- the plain look: the list tabs build, the selected tab is underlined
	for _, i in ipairs({ 1, 2 }) do
		win.tabs[i]:GetScript("OnClick")(win.tabs[i])
		check(win.pages[i]:IsShown() and win.pages[i].refresh, "plain tab " .. i .. " not built")
		for j = 1, #win.tabs do
			check(win.tabs[j].pssUnderline:IsShown() == (i == j), ("plain underline on tab %d after clicking tab %d"):format(j, i))
			check(win.tabs[j].pssWash:IsShown() == (i == j), ("plain wash on tab %d after clicking tab %d"):format(j, i))
		end
	end
	if not fail then print("PASS eui window 3") end
	return
end

check(M.PSS_Opt("euiIntegration") == true, "the save does not have the old option on")
check(#E.log.plugins == 0, "a panel section was registered at login")
check(not loaded(NAME), "loaded at login")
check(not loaded("PourSocialScore_GUI"), "GUI loaded at login")

-- /pss gui and Friends / Social: the Pour Social Score window
SlashCmdList.PSS("gui")
local pss = _G.PSS_Window
check(pss and pss:IsShown(), "/pss gui did not open the Pour Social Score window")
check(not loaded(NAME) and not loaded("PourSocialScore_GUI"), "/pss gui loaded an old window")
SlashCmdList.PSS("gui")
check(not pss:IsShown(), "/pss gui did not close it")
FriendsFrame:Show()
check(pss:IsShown() and pss.byFriends and pss._point[2] == FriendsFrame and pss._point[4] == 12, "Friends did not show the window beside it")
FriendsFrame:Hide()
check(not pss:IsShown(), "closing Friends left it open")
SocialUIFrame:Show()
check(pss:IsShown() and pss._point and pss._point[2] == SocialUIFrame and pss._point[4] == 55, "Social did not show the window clear of its tabs")
SocialUIFrame:Hide()
check(not pss:IsShown(), "closing Social left it open")
check(not loaded(NAME) and not loaded("PourSocialScore_GUI"), "Friends or Social loaded an old window")

-- the old window itself, opened directly (nothing else opens it now)
OpenOld()
local win = _G.PSS_EllesmereUIWindow
check(win and win:IsShown(), "the old window did not open")
check(not loaded("PourSocialScore_GUI"), "it loaded PourSocialScore_GUI")
check(#E.log.escape == 1, "Escape not registered")
local shells = 0
for _, k in ipairs(E.log.skinned) do if k == "Shell" then shells = shells + 1 end end
check(shells == 1, "window not painted with S.Shell (" .. shells .. ")")
-- every tab builds on first open, and only
-- the clicked tab shows as selected (S.Tab's accent underline)
for _, i in ipairs({ 1, 2, 3, 4, 5, 6 }) do
	win.tabs[i]:GetScript("OnClick")(win.tabs[i])
	check(win.pages[i]:IsShown() and win.pages[i].refresh, "tab " .. i .. " not built")
	for j = 1, #win.tabs do
		check(E.log.tabSel[win.tabs[j]] == (i == j), ("tab %d selected %s after clicking tab %d"):format(j, tostring(E.log.tabSel[win.tabs[j]]), i))
	end
end
-- the selected tab, as EllesmereUI's Friends tabs: a white wash and an
-- accent underline (ours, so they show on any EllesmereUI version)
local function marks(sel)
	for j = 1, #win.tabs do
		local t = win.tabs[j]
		check(t.pssWash:IsShown() == (j == sel) and t.pssUnderline:IsShown() == (j == sel), ("wash / underline on tab %d with tab %d selected"):format(j, sel))
	end
end
marks(6)
local ul = win.tabs[6].pssUnderline
check(ul._color and ul._color[1] == 0.2 and ul._color[3] == 0.6, "underline not in the accent colour")
E.ChangeLooks(0.9, 0.5, 0.1)
check(ul._color and ul._color[1] == 0.9, "underline did not follow an accent change")
-- an EllesmereUI without S.SetTabSelection (skin API 1): the button's
-- isSelected carries it for S.Tab's label, our marks still show
E.S.apiVersion = 1
win.tabs[2]:GetScript("OnClick")(win.tabs[2])
marks(2)
check(win.tabs[2].isSelected == true and win.tabs[6].isSelected == false, "isSelected not set for an older EllesmereUI")
E.S.apiVersion = 3

-- the Options search: in the tab row with the Options tab only; it keeps
-- the matching options and hides empty sections
win.tabs[6]:GetScript("OnClick")(win.tabs[6])
local opage = win.pages[6]
local search = opage.search
check(search and search:IsVisible(), "no Options search box")
local function shownRows()
	local n, heads = 0, 0
	for _, g in ipairs(opage.groups) do
		if g.heading:IsShown() then heads = heads + 1 end
		for _, it in ipairs(g.items) do if it.row:IsShown() then n = n + 1 end end
	end
	return n, heads
end
local all, allHeads = shownRows()
check(all > 10 and allHeads > 1, "not every option shown before a search")
search:SetText("level cap")
search:GetScript("OnTextChanged")(search)
local n, heads = shownRows()
check(n >= 1 and n < all and heads == 1, ("search 'level cap' shows %d options in %d sections"):format(n, heads))
check(search.clear:IsShown() and not search.hint:IsShown(), "clear button / hint while searching")
search:SetText("zzzz-nothing")
search:GetScript("OnTextChanged")(search)
check(select(1, shownRows()) == 0, "search for nothing shows options")
search.clear:GetScript("OnClick")(search.clear)
search:GetScript("OnTextChanged")(search)
check(select(1, shownRows()) == all and search.hint:IsShown(), "clearing the search did not bring every option back")
win.tabs[1]:GetScript("OnClick")(win.tabs[1])
check(not search:IsVisible(), "Options search shows on another tab")

if not fail then print("PASS eui window 2") end
