-- EllesmereUI front end (3.1 Steps E.2, E.3), with the EllesmereUI stand-in and
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

check(M.PSS_UseEUI(), "integration not in use")
check(E.log.plugins[1] == NAME and #E.log.plugins == 1, "panel section not registered once")
local spec = E.GetPlugin(NAME)
check(spec and spec.label == "Pour Social Score", "label")
check(not loaded(NAME), "loaded at login")
check(not loaded("PourSocialScore_GUI"), "GUI loaded at login")

local opts, io = spec.modules[1], spec.modules[2]
check(opts and #opts.pages == #M.PSS_OPTION_SECTIONS, "one Options page per section")
check(io and io.key == "ImportExport", "no Import/Export module")

-- search pre-build pass before the addon is loaded: nothing loads
E.prebuild = true
check(opts.buildPage(opts.pages[1], {}, -10) == 0, "pre-build drew a page")
check(not loaded(NAME), "pre-build loaded the addon")
E.prebuild = false

-- every page builds; DualRow slots are filled left to right, never nil, and
-- only the last row of a section may end in a blank; every option has a row
local function BLANK(c) return c.type == "label" and c.text == "" end
local function buildPage(mod, page)
	E.rows = {}
	local h = mod.buildPage(page, {}, -10)
	check(h and h > 10, page .. ": page height " .. tostring(h))
	for i, r in ipairs(E.rows) do
		if r[1] == "dual" then
			check(r[2] ~= nil and r[3] ~= nil, page .. ": a DualRow with a nil slot")
			check(not BLANK(r[2]), page .. ": a blank left slot")
			local last = not E.rows[i + 1] or E.rows[i + 1][1] ~= "dual"
			check(last or not BLANK(r[3]), page .. ": a blank slot before the last row")
		end
	end
	return E.rows
end
local seen = {}
for _, page in ipairs(opts.pages) do
	for _, r in ipairs(buildPage(opts, page)) do
		if r[1] == "dual" then seen[r[2].text or ""] = r[2]; seen[r[3].text or ""] = r[3] end
	end
end
check(loaded(NAME), "page build did not load the addon")
for _, o in ipairs(M.PSS_OPTIONS) do
	local text = (o.label or o.key):gsub("[:%s]+$", "")
	check(seen[text], "no panel row for option " .. o.key)
end
local ioRow = {}
for _, r in ipairs(buildPage(io, io.pages[1])) do
	if r[1] == "dual" then ioRow[r[2].text] = r[2]; ioRow[r[3].text] = r[3] end
end
check(type(PSS_EllesmereUIDB) == "table", "no saved table")

-- a change in the panel saves through the core and redraws the other surface
local row = seen[(M.PSS_OPTION_REG.skipParty.label:gsub("[:%s]+$", ""))]
E.active = E.GetPluginModuleKey(NAME, "Options")
local before = E.log.refreshed
row.setValue(true)
check(M.PSS_Opt("skipParty") == true, "panel toggle not saved")
check(E.log.refreshed > before, "panel not refreshed after a change")
row.setValue(false)
check(PourSocialScoreDB.skipParty == nil, "default value saved")
local cap = seen["Enable scan level cap"]
cap.setValue(true)
check(M.PSS_Opt("whoLevelCapOn") ~= true, "level cap ticked with no cap")
seen["Scan level cap"].setValue("70")
cap.setValue(true)
check(M.PSS_Opt("whoLevelCapOn") == true and M.PSS_Opt("whoLevelCap") == 70, "level cap not set")

-- the window
SlashCmdList.PSS("gui")
local win = _G.PSS_EllesmereUIWindow
check(win and win:IsShown(), "/pss gui did not show the window")
check(not loaded("PourSocialScore_GUI"), "/pss gui loaded PourSocialScore_GUI")
check(#E.log.escape == 1, "Escape not registered")
local shells = 0
for _, k in ipairs(E.log.skinned) do if k == "Shell" then shells = shells + 1 end end
check(shells == 1, "window not painted with S.Shell (" .. shells .. ")")
-- every tab builds on first open, and only
-- the clicked tab shows as selected (S.Tab's accent underline)
for _, i in ipairs({ 1, 2, 3, 4, 5 }) do
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
marks(5)
local ul = win.tabs[5].pssUnderline
check(ul._color and ul._color[1] == 0.2 and ul._color[3] == 0.6, "underline not in the accent colour")
E.ChangeLooks(0.9, 0.5, 0.1)
check(ul._color and ul._color[1] == 0.9, "underline did not follow an accent change")
-- an EllesmereUI without S.SetTabSelection (skin API 1): the button's
-- isSelected carries it for S.Tab's label, our marks still show
E.S.apiVersion = 1
win.tabs[2]:GetScript("OnClick")(win.tabs[2])
marks(2)
check(win.tabs[2].isSelected == true and win.tabs[5].isSelected == false, "isSelected not set for an older EllesmereUI")
E.S.apiVersion = 3

-- the Options search: in the tab row with the Options tab only; it keeps
-- the matching options and hides empty sections
win.tabs[5]:GetScript("OnClick")(win.tabs[5])
local opage = win.pages[5]
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

M.PSS_SetOpt("skipParty", "global", true)
M.PSS_SetOpt("skipParty", "global", false)

-- Import/Export through EllesmereUI's popups
SlashCmdList.PSS("gui")
check(not win:IsShown(), "/pss gui did not toggle it off")
M.PSS_SetOpt("skipParty", "global", true)
ioRow["Options (all characters)"].setValue(true)
ioRow["Export the ticked sections"].onClick()
local str = E.log.copies[1]
check(type(str) == "string" and M.PSS_DecodeExport(str), "no export string")
M.PSS_SetOpt("skipParty", "global", false)
E.importText = str
ioRow["Import a string"].onClick()
check(M.PSS_Opt("skipParty") == true, "merge import did not apply the options")
E.importText = "nonsense"
ioRow["Import a string"].onClick()
local n = #E.log.popups
ioRow["Import mode"].setValue("replace")
E.importText = str
ioRow["Import a string"].onClick()
check(#E.log.popups == n + 1 and E.log.popups[n + 1].confirmText == "Replace", "replace not confirmed")

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
