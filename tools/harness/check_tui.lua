-- The new PSS window (3.4.0), as a run.lua script on a fresh save:
-- PourSocialScore_GUI and PourSocialScore_Libraries are not loaded at login;
-- chat, the note popup, the group warning and list changes work without
-- them (core's popups are StaticPopups); a chat command loads Libraries
-- only; from 3.4.0.23 (D1, moved from check_gui.lua) the Friends and
-- Social windows (with the option on), /pss gui, /pss ui and the Addon
-- Compartment open it; from 3.4.0.25 (D2) it is PourSocialScore_GUI, the
-- loader has no other window part and /pss tui is gone; from 3.4.0.28
-- /pss on its own opens it (gui, ui and eui are the same command) and
-- /pss help lists the commands; it toggles; Escape
-- closes it; a dragged place is remembered; the look follows the uiSkin
-- option (Blizzard by default) and repaints the open window; the kit's
-- controls and tooltips follow the look; the uiFont option picks a Blizzard
-- font or, only while another addon has loaded it, a LibSharedMedia font.
local fail = false
local function check(ok, msg) if not ok then print("FAIL tui: " .. msg) fail = true end end
local loaded = function(name) return C_AddOns.IsAddOnLoaded(name) end

check(not loaded("PourSocialScore_GUI"), "GUI loaded at login")
check(not loaded("PourSocialScore_Libraries"), "Libraries loaded at login")
check(M.PSS_PARTS.GUI == "PourSocialScore_GUI" and M.PSS_PARTS.UI == nil and M.PSS_PARTS.EllesmereUI == nil,
	"loader parts: the window is GUI, no UI or EllesmereUI part")
check(M.PSS_TUI == nil and M.PSS_GUI == nil and M.PSS_OpenUI and M.PSS_AskReload == nil, "core's window entry points")

-- a list change with the window asleep loads nothing
M.PSS_AddPlayer("Badguy")
M.Events.Fire("PLAYERS_CHANGED", true)
M.Events.Fire("OPTION_CHANGED", "uiSkin")
check(not loaded("PourSocialScore_GUI"), "GUI loaded by a change")

-- what fires during play, with the window asleep: core's popups
local shown = {}
local realPopup = StaticPopup_Show
StaticPopup_Show = function(which) shown[#shown + 1] = which end
M.Events.Fire("ASK_NOTE", "Badguy")
M.Events.Fire("GROUP_WARNING", { "Badguy" })
StaticPopup_Show = realPopup
check(shown[1] == "PSS_REASON" and shown[2] == "PSS_PARTYWARN", "note popup and group warning")
check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_Libraries"), "a popup loaded the window")

-- chat commands load Libraries, not the window
local said, realShow, realChat = {}, M.ShowMsg, M.ChatMsg
M.ShowMsg = function(x) said[#said + 1] = tostring(x) end
M.ChatMsg = M.ShowMsg
SlashCmdList["PSS"]("mem")
SlashCmdList["PSSGUILD"]("")
check(loaded("PourSocialScore_Libraries"), "/pss did not load Libraries")
check(not loaded("PourSocialScore_GUI"), "/pss mem loaded the window")
check(table.concat(said, "\n"):find("PSS guild:", 1, true) ~= nil, "/pssguild did not run")
-- /pss help (or a word /pss does not know) lists the commands, says /pss
-- opens the window, and no longer lists tui or gui force (3.4.0.28)
said = {}
SlashCmdList["PSS"]("help")
M.ShowMsg, M.ChatMsg = realShow, realChat
local help = table.concat(said, "\n")
check(help:find("/pss to open the window", 1, true) ~= nil and help:find("gui", 1, true) ~= nil, "/pss help does not say /pss opens the window")
check(not help:find("tui", 1, true) and not help:find("force", 1, true), "/pss help lists a retired command")
check(not loaded("PourSocialScore_GUI"), "/pss help loaded the window")

-- Friends with the option off: stays asleep
local opt = PourSocialScoreDB.openWithFriends
PourSocialScoreDB.openWithFriends = false
FriendsFrame:Show(); FriendsFrame:Hide()
check(not loaded("PourSocialScore_GUI"), "Friends loaded the window with the option off")
-- option on: loads it and shows it beside Friends, closes with it
PourSocialScoreDB.openWithFriends = true
FriendsFrame:Show()
local win = _G.PSS_Window
check(loaded("PourSocialScore_GUI") and win and win:IsShown(), "Friends did not open the window")
check(win._point and win._point[1] == "TOPLEFT" and win._point[2] == FriendsFrame and win._point[4] == 12, "window not beside Friends")
FriendsFrame:Hide()
check(not win:IsShown(), "window not closed with Friends")
-- Retail 12.1's Social window: beside it, clear of its tabs; Social going
-- to the Who tab (FriendsFrame) keeps it open and it follows
SocialUIFrame:Show()
check(win:IsShown() and win._point[2] == SocialUIFrame and win._point[4] == 55, "window not beside the Social window")
FriendsFrame:Show(); SocialUIFrame:Hide()
check(win:IsShown() and win._point[2] == FriendsFrame, "window did not follow Social to the Who tab")
FriendsFrame:Hide()
check(not win:IsShown(), "window not closed with the Social window")
-- opened by command, it is at its own place and stays when a Friends
-- window it was not opened with closes
SlashCmdList["PSS"]("gui")
check(win:IsShown() and not win.byFriends and win._point[2] ~= FriendsFrame, "/pss gui opened it docked")
SocialUIFrame:Hide()
check(win:IsShown(), "a Friends window closing closed the window opened by command")
SlashCmdList["PSS"]("gui")
check(not win:IsShown(), "/pss gui did not close it")
PourSocialScoreDB.openWithFriends = opt
-- /pss on its own toggles it, and gui, ui and eui are the same command, with
-- anything after them (3.4.0.28, Dan); /pss tui is gone (it lists the
-- commands); the Addon Compartment opens it
for _, cmd in ipairs({ "", "ui", "eui", "gui force", "  GUI  " }) do
	SlashCmdList["PSS"](cmd)
	check(win:IsShown(), "/pss " .. cmd .. " did not open the window")
	SlashCmdList["PSS"](cmd)
	check(not win:IsShown(), "/pss " .. cmd .. " did not close the window")
end
SlashCmdList["PSS"]("tui")
check(not win:IsShown(), "/pss tui still opens the window")
local entry
for _, info in ipairs(AddonCompartmentFrame.registered) do
	if info.text == "Pour Social Score" then entry = info end
end
check(entry ~= nil, "no Addon Compartment entry")
if entry then entry.func() end
check(win:IsShown(), "the Addon Compartment did not open the window")
SlashCmdList["PSS"]("gui")
win._point = nil

-- /pss gui opens it at its own place, loading Libraries and GUI only
SlashCmdList["PSS"]("gui")
check(loaded("PourSocialScore_GUI") and loaded("PourSocialScore_Libraries"), "/pss gui did not load GUI and Libraries")
check(win and win:IsShown(), "/pss gui did not show the window")
check(win and win:GetWidth() == 960 and win:GetHeight() == 494, "window is not 960 x 494")
check(win and win.title and win.title:GetText() == "Pour Social Score", "no title")
check(win and win._point and win._point[1] == "CENTER", "first open is not centred")

-- Modern by default (Dan, dev008_4); without its art (here) it paints the
-- Classic look
local art = win and win.art or {}
check(M.PSS_UISkin() == "modern", "default look is not Modern")
check(art.blizzard and art.blizzard:IsShown() and not art.dark:IsShown(), "Blizzard frame not shown")
check(art.blizzardClose:IsShown() and not art.darkClose:IsShown(), "Blizzard close button not shown")

-- Dark: the open window repaints, and only a non-default value is saved
M.PSS_SetOpt("uiSkin", "global", 1)
check(M.PSS_UISkin() == "dark", "option did not switch to Dark")
check(art.dark:IsShown() and not art.blizzard:IsShown(), "window did not repaint Dark")
check(art.darkClose:IsShown() and not art.blizzardClose:IsShown(), "Dark close button not shown")
M.PSS_SetOpt("uiSkin", "global", 2)
check(art.blizzard:IsShown() and not art.dark:IsShown(), "window did not repaint Modern")
check(PourSocialScoreDB.uiSkin == nil, "the default look was saved")
-- the three choices: Modern (Default), Classic, Dark
local labels = {}
for _, ch in ipairs(M.PSS_OPTION_REG.uiSkin.choices) do labels[#labels + 1] = ch[2] end
check(table.concat(labels, ",") == "Modern (Default),Classic,Dark", "look choices are not Modern (Default), Classic, Dark")
M.PSS_SetOpt("uiSkin", "global", 0)
check(M.PSS_UISkin() == "blizzard" and PourSocialScoreDB.uiSkin == 0 and art.blizzard:IsShown() and not art.dark:IsShown(), "Classic not chosen and saved")

-- a dragged place is saved and used next time
win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 120.4, -80.6)
win._scripts.OnDragStop(win)
local p = PourSocialScoreDB.windowPoints and PourSocialScoreDB.windowPoints.PSS_Window
check(p and p[1] == "TOPLEFT" and p[3] == 120 and p[4] == -81, "dragged place not saved")
SlashCmdList["PSS"]("gui")
check(not win:IsShown(), "second /pss gui did not close the window")
SlashCmdList["PSS"]("gui")
check(win:IsShown() and win._point[1] == "TOPLEFT" and win._point[4] == 120, "saved place not used")

-- Escape closes it (the helper frame in UISpecialFrames is hidden by Escape)
local listed = false
for _, n in ipairs(UISpecialFrames) do if n == "PSS_WindowEscape" then listed = true end end
check(listed, "Escape helper not in UISpecialFrames")
check(_G.PSS_WindowEscape:IsShown(), "Escape helper not shown with the window")
_G.PSS_WindowEscape:Hide()
check(not win:IsShown(), "Escape did not close the window")

------------------------------------------------------------------------
-- dev006: seven tabs, back / forward, the line by the arrows, Escape
------------------------------------------------------------------------
SlashCmdList["PSS"]("gui")
check(win:IsShown(), "window did not open again")
local names = {}
for i, t in ipairs(win.tabs or {}) do names[i] = t:GetText() end
check(table.concat(names, ",") == "Player Ignore List,Guild Ignore List,Chat Filters,Events,Import/Export,Options,AddOns", "tabs are not the seven (the six of the port and AddOns)")
check(win.tabs[1].pssSelected and win.pages[1]:IsShown() and not win.pages[2]:IsShown(), "first tab not shown first")
check(win.pages[6].note == nil and not win.pages[6].refresh, "a tab not opened yet is not built, and has no placeholder note")
check(win.where:GetText() == "Player Ignore List", "the line by the arrows does not name the tab")
check(win.where:GetAlpha() == 0.9, "the line by the arrows is not at 0.9")
check(not win.back:IsEnabled() and not win.forward:IsEnabled(), "arrows enabled with nowhere to go")
check(win.kit == nil and _G.PSS_KitPage == nil, "the kit preview is still in the window")
-- a tab click shows it, saves it (the first tab is not saved), and records a step
win.tabs[3]._scripts.OnClick(win.tabs[3])
check(win.tabs[3].pssSelected and win.pages[3]:IsShown() and not win.pages[1]:IsShown(), "tab click did not show the tab")
check(PourSocialScoreDB.windowPoints.PSS_WindowTab == "filters", "tab shown not saved")
check(win.back:IsEnabled() and win.where:GetText() == "Chat Filters", "tab click is not a step back")
-- a page with a sub-view (as the Guilds tab's members view): the Options
-- page, not built yet, stands in
local pg = win.pages[6]
local sub
pg.navState = function() return sub end
pg.navApply = function(v) sub = v end
pg.navUp = function() if sub then sub = nil return true end return false end
pg.navTitle = function(v) return "Members of " .. v end
win.tabs[6]._scripts.OnClick(win.tabs[6])
sub = "Badguild"
local ui = H.Private("PourSocialScore_GUI")
ui.NavRecord()
check(win.where:GetText() == "Options  >  Members of Badguild", "the line does not name the sub-view")
check(win.crumbs[1] and win.crumbs[1]:IsShown() and win.crumbs[1].tipText == "Back to Options.", "no link back to the tab")
-- back, back, forward
ui.NavBack()
check(sub == nil and win.where:GetText() == "Options", "back did not leave the sub-view")
ui.NavBack()
check(win.pages[3]:IsShown() and win.forward:IsEnabled(), "back did not return to the tab before")
ui.NavForward()
ui.NavForward()
check(win.pages[6]:IsShown() and sub == "Badguild", "forward did not return to the sub-view")
-- mouse buttons 4 / 5 over the window only
win._mouseOver = true
win._scripts.OnEvent(win, "GLOBAL_MOUSE_UP", "Button4")
check(sub == nil, "mouse button 4 did not step back")
win._scripts.OnEvent(win, "GLOBAL_MOUSE_UP", "Button5")
check(sub == "Badguild", "mouse button 5 did not step forward")
win._mouseOver = false
win._scripts.OnEvent(win, "GLOBAL_MOUSE_UP", "Button4")
check(sub == "Badguild", "mouse button 4 away from the window stepped back")
-- the link back to the tab, and Escape up one level, then closed
win.crumbs[1]._scripts.OnClick(win.crumbs[1])
check(sub == nil and win.where:GetText() == "Options", "the link did not reset the tab")
sub = "Badguild"
ui.NavRecord()
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and sub == nil and _G.PSS_WindowEscape:IsShown(), "Escape did not step up one level")
-- (3.4.0.14) a popup open at an Escape takes it: the window stays where it
-- is, whichever of the two the Escape hides first
sub = "Badguild"
ui.NavRecord()
H.Advance(1)
ui.Confirm({ text = "Escape test" })
_G.PSS_WindowEscape:Hide()
_G.PSS_Confirm:Hide()
check(sub == "Badguild" and win:IsShown() and _G.PSS_WindowEscape:IsShown(), "Escape on a popup also stepped the window (helper hidden first)")
H.Advance(1)
ui.Confirm({ text = "Escape test" })
_G.PSS_Confirm:Hide()
_G.PSS_WindowEscape:Hide()
check(sub == "Badguild" and win:IsShown() and _G.PSS_WindowEscape:IsShown(), "Escape on a popup also stepped the window (popup hidden first)")
H.Advance(1)
_G.PSS_WindowEscape:Hide()
check(sub == nil and win:IsShown(), "the next Escape did not step up one level")
-- Events opened from another tab: Escape goes back there
win.tabs[4]._scripts.OnClick(win.tabs[4])
check(win.pages[4]:IsShown(), "Events tab not shown")
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and win.pages[6]:IsShown(), "Escape on Events did not go back to the tab before")
_G.PSS_WindowEscape:Hide()
check(not win:IsShown(), "Escape at the top did not close the window")
pg.navState, pg.navApply, pg.navUp, pg.navTitle = nil, nil, nil, nil
-- the tab shown last opens next time; the first tab clears the saved one
SlashCmdList["PSS"]("gui")
check(win.pages[6]:IsShown() and M.PSS_UITab() == 6, "saved tab not reopened")
win.tabs[1]._scripts.OnClick(win.tabs[1])
check(PourSocialScoreDB.windowPoints.PSS_WindowTab == nil, "the first tab was saved")
-- (3.4.0.15) Events is never the tab the window opens on (it would load
-- Logging before any click): the tab before it stays saved
win.tabs[6]._scripts.OnClick(win.tabs[6])
win.tabs[4]._scripts.OnClick(win.tabs[4])
check(M.PSS_UITab() == 6, "the Events tab was saved: " .. tostring(M.PSS_UITab()))
PourSocialScoreDB.windowPoints.PSS_WindowTab = "events"
check(M.PSS_UITab() == 1, "a saved Events tab was reopened")
win.tabs[1]._scripts.OnClick(win.tabs[1])
-- a tab with a builder is built on first open and redrawn when shown
-- (the Import/Export tab's own builder, counted)
local built, drawn = 0, 0
local realBuild = ui.TabBuilders.importExport
ui.TabBuilders.importExport = function(page)
	built = built + 1
	local redraw = realBuild(page)
	return function() drawn = drawn + 1 redraw() end
end
win.tabs[5]._scripts.OnClick(win.tabs[5])
win.tabs[5]._scripts.OnClick(win.tabs[5])
check(built == 1 and drawn == 2 and win.pages[5].refresh, "a tab builder did not build once and redraw")
ui.TabBuilders.importExport = realBuild
win.tabs[1]._scripts.OnClick(win.tabs[1])
-- frame strata follows the option
local strata
win.SetFrameStrata = function(_, x) strata = x end
M.PSS_SetOpt("frameStrata", "global", 2)
check(strata ~= nil and strata == M.PSS_FrameStrataName(), "strata did not follow the option")
win.SetFrameStrata = nil
M.PSS_SetOpt("frameStrata", "global", 3)
win:Hide()

-- the kit preview (tools/harness/kit_page.lua, on a frame of its own), in every look
local dir = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."
assert(loadfile(dir .. "/kit_page.lua"))("PourSocialScore_GUI", ui)
local host = CreateFrame("Frame", nil, UIParent)
host:SetSize(960, 494)
ui.BuildKitPage(host)
local kit = host.kit or {}
check(kit.tabs and #kit.tabs == 3, "kit preview has no tab row of three")
local b1, c1, e1 = kit.buttons and kit.buttons[1], kit.checks and kit.checks[1], kit.boxes and kit.boxes[1]
local function darkShown(w) return w and w.pssParts and w.pssParts.fill:IsShown() end
check(b1 and not darkShown(b1) and not b1.pssParts.edge:IsShown(), "Blizzard button shows Dark parts")
check(e1 and not darkShown(e1), "Blizzard edit box shows Dark parts")
check(kit.page and kit.page.pssParts.art and kit.page.pssParts.art:IsShown(), "Blizzard panel not shown")
-- W3: the kit additions, in the Classic look (the harness starts in it)
local b3, h1 = kit.buttons[3], kit.boxes[4]
check(b3.pssPrimary == true and kit.buttons[1].pssPrimary == nil, "NewButton's primary argument not kept")
check(h1.hint and h1.hint:IsShown() and h1.hint:GetText() == "Name-Realm" and h1.hint:GetAlpha() == 0.4, "edit box hint not shown while empty")
h1:SetText("x")
h1._scripts.OnTextChanged(h1)
check(not h1.hint:IsShown(), "edit box hint did not hide with text")
h1:SetText("")
h1._scripts.OnTextChanged(h1)
check(h1.hint:IsShown(), "edit box hint did not come back when emptied")
local ta = kit.textArea
check(ta and ta.edit and ta.scroll and ta.pssParts.art and ta.pssParts.art:IsShown(), "text area has no panel, box or scroll frame")
check(ta.edit:GetText():find("A text area"), "text area holds no text")
local n = 0
for _ in pairs(kit.allowed) do n = n + 1 end
check(n == #M.EXCL and kit.allowed.whisper ~= nil, "the W I G P C row has not one box per category")
local pk = kit.menus.picker
check(pk.saveButton.pssPrimary == true and pk.allButton.pssPrimary == nil and #pk.items == 3 and pk:IsShown(), "results picker not built")
check(kit.line:GetText() == "A pane line" and kit.label:GetAlpha() == 0.7, "pane line or label wrong")
local tab1, tab2 = kit.tabs[1], kit.tabs[2]
check(tab1.pssSelected and not tab2.pssSelected, "first tab not selected")
-- Blizzard tabs: the label centred (not Blizzard's 4 / 8 px drop), the
-- active art on the selected tab only, the width our own
local lp, lp2 = tab1:GetFontString()._point, tab2:GetFontString()._point
check(lp and lp[1] == "CENTER" and lp[3] == "CENTER" and lp[5] == 0, "selected tab label not centred")
check(lp2 and lp2[1] == "CENTER" and lp2[5] == -1, "unselected tab label not 1 below centre")
check(tab1.MiddleActive:IsShown() and not tab1.Middle:IsShown(), "selected tab not showing the active art")
check(tab2.Middle:IsShown() and not tab2.MiddleActive:IsShown(), "unselected tab showing the active art")
check(tab1._scripts.OnShow == nil, "tab template still resizes itself on show")
check(tab1:GetWidth() == tab1:GetFontString():GetStringWidth() + 32, "tab not sized to its label + 32")
-- the accent is always your class colour (here a Druid's orange)
local realClass, realColor = UnitClass, C_ClassColor.GetClassColor
UnitClass = function() return "Druid", "DRUID", 11 end
C_ClassColor.GetClassColor = function(c) if c == "DRUID" then return { r = 1, g = 0.49, b = 0.04 } end end
SlashCmdList["PSS"]("gui")
M.PSS_SetOpt("uiSkin", "global", 1)
SlashCmdList["PSS"]("gui")
local lc = tab1.pssLine._color
check(lc and lc[1] == 1 and lc[2] == 0.49 and lc[3] == 0.04, "Dark underline is not the class colour")
check(M.PSS_OPTION_REG.uiAccent == nil, "the accent has an option (the class colour is mandatory)")
check(darkShown(b1) and b1.pssParts.edge:IsShown(), "Dark button parts not shown")
check(c1.pssParts.box:IsShown() and c1.pssParts.edge:IsShown(), "Dark tick box parts not shown")
check(darkShown(e1), "Dark edit box parts not shown")
check(darkShown(kit.page) and not kit.page.pssParts.art:IsShown(), "Dark panel not shown")
check(darkShown(kit.textArea) and darkShown(kit.boxes[4]), "Dark text area or hinted box not shown")
check(darkShown(kit.buttons[3]) and darkShown(kit.menus.picker.saveButton), "Dark primary buttons not shown")
check(tab1.pssLine:IsShown() and not tab2.pssLine:IsShown(), "Dark tab underline not on the selected tab only")
check(tab2:GetFontString():GetAlpha() == 0.7 and tab1:GetFontString():GetAlpha() == 1, "Dark tab labels not faded to 0.7 by alpha")
kit.tabs[3]._scripts.OnClick(kit.tabs[3])
check(kit.tabs[3].pssSelected and not tab1.pssSelected, "tab click did not select it")
check(kit.pages[3]:IsShown() and not kit.pages[1]:IsShown(), "tab click did not show its page")
kit.tabs[1]._scripts.OnClick(kit.tabs[1])

UnitClass, C_ClassColor.GetClassColor = realClass, realColor

-- tooltips: Dark draws its own; Blizzard uses GameTooltip
local owner = kit.tipOwner
owner._scripts.OnEnter(owner)
check(_G.PSS_Tooltip and _G.PSS_Tooltip:IsShown(), "Dark tooltip not shown")
owner._scripts.OnLeave(owner)
M.PSS_SetOpt("uiSkin", "global", 0)
check(not darkShown(b1) and not c1.pssParts.box:IsShown(), "back to Blizzard: Dark parts still shown")
local tipOwner
local realOwner = GameTooltip.SetOwner
GameTooltip.SetOwner = function(_, o) tipOwner = o end
owner._scripts.OnEnter(owner)
GameTooltip.SetOwner = realOwner
check(tipOwner ~= nil, "Blizzard tooltip not shown on GameTooltip")
owner._scripts.OnLeave(owner)

-- fonts: the look's own by default; a picked Blizzard font in both looks
local function face() return (_G.PSS_Font1:GetFont()) end
check(M.PSS_UIFontPath() == nil, "a font is picked by default")
check(face() ~= "Fonts\\ARIALN.TTF", "Blizzard look uses Arial Narrow by default")
M.PSS_SetOpt("uiSkin", "global", 1)
check(face() == "Fonts\\ARIALN.TTF", "Dark look does not default to Arial Narrow")
M.PSS_SetOpt("uiFont", "global", "morpheus")
check(face() == "Fonts\\MORPHEUS.TTF", "picked font not used in Dark")
M.PSS_SetOpt("uiSkin", "global", 0)
check(face() == "Fonts\\MORPHEUS.TTF", "picked font not used in Blizzard")
check(PourSocialScoreDB.uiFont == "morpheus", "picked font not saved")
M.PSS_SetOpt("uiFont", "global", "")
check(PourSocialScoreDB.uiFont == nil, "the default font was saved")

-- LibSharedMedia: never created by us; read only when another addon has it
check(_G.LibStub == nil, "LibStub appeared without another addon")
local before = #M.PSS_OPTION_REG.uiFont.choices
M.PSS_UIFontChoices()
check(#M.PSS_OPTION_REG.uiFont.choices == before, "font choices grew without LibSharedMedia")
local lsm = {
	List = function(_, kind) return kind == "font" and { "Shared Face" } or {} end,
	Fetch = function(_, kind, name) if kind == "font" and name == "Shared Face" then return "Interface\\AddOns\\Other\\face.ttf" end end,
}
_G.LibStub = setmetatable({}, { __call = function(_, name) if name == "LibSharedMedia-3.0" then return lsm end end })
SlashCmdList["PSS"]("gui")
SlashCmdList["PSS"]("gui")
local found
for _, ch in ipairs(M.PSS_OPTION_REG.uiFont.choices) do if ch[2] == "Shared Face" then found = ch[1] end end
check(found ~= nil, "a shared font not listed once the window opened")
M.PSS_SetOpt("uiFont", "global", found)
check(M.PSS_UIFontPath() == "Interface\\AddOns\\Other\\face.ttf" and face() == "Interface\\AddOns\\Other\\face.ttf", "shared font not used")
_G.LibStub = nil
check(M.PSS_UIFontPath() == nil, "a shared font without LibSharedMedia did not fall back")
M.PSS_SetOpt("uiFont", "global", "")

------------------------------------------------------------------------
-- dev003: menus, popups, row list, pie (Blizzard first, then Dark)
------------------------------------------------------------------------
local mk, ls = kit.menus, kit.lists
check(mk and ls, "kit has no menus or lists page")
M.PSS_SetOpt("uiSkin", "global", 0)
local dd = mk.pick
check(dd.blizz and dd.blizz:IsShown() and not dd.dark:IsShown(), "Blizzard drop-down not shown")
local items = dd.blizz:MenuButtons()
check(#items == 4 and items[1].kind == "radio" and items[1].on and not items[2].on, "Blizzard drop-down entries wrong")
items[2].fn()
check(mk.result:GetText() == "Last: Last 24 hours", "Blizzard drop-down pick did not run")
local tk = mk.ticks.blizz:MenuButtons()
check(#tk == 8 and tk[1].kind == "checkbox", "Blizzard tick menu entries wrong")
-- right-click: Blizzard's context menu
local made
local realCtx = MenuUtil.CreateContextMenu
MenuUtil.CreateContextMenu = function(o, gen) made = o end
mk.area._scripts.OnClick(mk.area, "RightButton")
MenuUtil.CreateContextMenu = realCtx
check(made == mk.area, "Blizzard right-click menu not opened")
-- confirm: accept and cancel
mk.confirm._scripts.OnClick(mk.confirm)
local cf = _G.PSS_Confirm
check(cf and cf:IsShown(), "confirm popup not shown")
-- Classic and Modern popups: the window's own frame and background (Dan, dev011_3)
check(cf.pssParts.art and cf.pssParts.art:IsShown() and not cf.pssParts.dim:IsShown() and not cf.pssParts.fill:IsShown(), "Classic confirm not in the window's frame")
check(cf.pssParts.art._template == win.art.blizzard._template and not cf.pssParts.art.pssBlack:IsShown(), "Classic confirm not the window's frame and stone")
cf.accept._scripts.OnClick(cf.accept)
check(not cf:IsShown() and mk.result:GetText() == "Last: Confirmed", "confirm accept did not run")
mk.confirm._scripts.OnClick(mk.confirm)
cf:Hide()	-- Escape hides it
check(mk.result:GetText() == "Last: Cancelled", "confirm Escape did not cancel")
-- copy (read only) and import
mk.copy._scripts.OnClick(mk.copy)
local tp = _G.PSS_TextPopup
check(tp and tp:IsShown() and tp.edit:GetText():find("^PSS1:") and not tp.accept:IsShown(), "copy popup wrong")
tp:Hide()
mk.import._scripts.OnClick(mk.import)
check(tp:IsShown() and tp.accept:IsShown(), "import popup wrong")
tp.edit:SetText("PSS1:xyz")
tp.accept._scripts.OnClick(tp.accept)
check(not tp:IsShown() and mk.result:GetText() == "Last: Imported 8 characters", "import did not hand over the text")
for _, n in ipairs({ "PSS_Confirm", "PSS_TextPopup" }) do
	local listed = false
	for _, x in ipairs(UISpecialFrames) do if x == n then listed = true end end
	check(listed, n .. " does not close on Escape")
end

-- Dark: our own menu list
M.PSS_SetOpt("uiSkin", "global", 1)
check(dd.dark:IsShown() and not dd.blizz:IsShown(), "Dark drop-down not shown")
check(cf.pssParts.dim:IsShown() and cf.pssParts.fill:IsShown(), "Dark confirm has no dimmed screen")
check(not cf.pssParts.art:IsShown(), "Dark popup shows the window frame")
dd.dark._scripts.OnClick(dd.dark)
local menu = _G.PSS_Menu
check(menu and menu:IsShown(), "Dark drop-down did not open our menu")
local shownSlots = 0
for _, sl in ipairs(menu.slots) do if sl:IsShown() then shownSlots = shownSlots + 1 end end
check(shownSlots == 4, "Dark menu does not show 4 entries")
check(menu.slots[2].mark:IsShown() and not menu.slots[1].mark:IsShown(), "Dark menu does not mark the picked entry")
menu.slots[3]._scripts.OnClick(menu.slots[3])
check(not menu:IsShown() and mk.result:GetText() == "Last: All time", "Dark radio pick did not run and close")
mk.ticks.dark._scripts.OnClick(mk.ticks.dark)
check(menu.slots[1].entry.kind == "title", "tick menu has no title")
menu.slots[2]._scripts.OnClick(menu.slots[2])
check(menu:IsShown() and mk.types[1] == false, "a tick did not stay open or did not toggle")
menu:Hide()
mk.long.dark._scripts.OnClick(mk.long.dark)
local longShown = 0
for _, sl in ipairs(menu.slots) do if sl:IsShown() then longShown = longShown + 1 end end
check(menu.slots[1].text:GetText() == "Entry 1" and longShown == 7, "long menu does not show 7 entries")
menu._scripts.OnMouseWheel(menu, -1)
check(menu.slots[1].text:GetText() == "Entry 2", "mouse wheel did not scroll the long menu")
menu:Hide()
mk.area._scripts.OnClick(mk.area, "RightButton")
check(menu:IsShown() and menu.slots[2].text:GetText() == "Show details", "Dark right-click menu not ours")
-- compact: 20 px entries, a slim title and divider
check(menu.slots[2]:GetHeight() == 20 and menu.slots[1]:GetHeight() == 18 and menu.slots[4]:GetHeight() == 7, "right-click menu not compact")
check(menu:GetHeight() == 18 + 20 + 20 + 7 + 20 + 2, "right-click menu height not the sum of its entries")
menu:Hide()

-- the row list: only the rows that fit, header sort in the accent, selection
local list = ls.list
check(list.count == 200 and list.shown and list.shown > 0 and list.shown < 200, "row list not virtual")
check(list.rows[1].cells.name:GetText() == "Sample-001", "row list did not draw")
list.heads[2]._scripts.OnClick(list.heads[2])
check(list.sortKey == "n" and list.heads[2].label:GetText() == "Blocked ^", "header sort not shown")
list.rows[1]._scripts.OnClick(list.rows[1], "LeftButton")
check(list.rows[1].sel:IsShown(), "row click did not select")
-- the pie: shares and hover
local pie = ls.pie
check(pie.total == 65, "pie total wrong")
local seen = {}
for s = 1, 60 do seen[pie.segSlice[s]] = (seen[pie.segSlice[s]] or 0) + 1 end
check(seen[1] and seen[2] and seen[3] and seen[0] == nil, "pie does not draw every slice")
M.PSS_SetOpt("uiSkin", "global", 0)

------------------------------------------------------------------------
-- Modern: Blizzard's new Social window art (here faked as present)
------------------------------------------------------------------------
local realAtlas = C_Texture.GetAtlasInfo
C_Texture.GetAtlasInfo = function() return { width = 32, height = 64 } end
M.PSS_SetOpt("uiSkin", "global", 2)
local red, tert = b1.pssParts.red, b1.pssParts.tertiary
check(tert.texture:IsShown() and not red.left:IsShown(), "Modern button is not the gold-framed plate")
check(not b1.pssParts.fill:IsShown(), "Modern button shows Dark parts")
local c2 = kit.checks[2]
check(c1.pssParts.modernBox:IsShown() and c1.pssParts.modernTick:IsShown(), "Modern ticked box not drawn")
check(c2.pssParts.modernBox:IsShown() and not c2.pssParts.modernTick:IsShown(), "Modern unticked box shows a tick")
c2:SetChecked(true)
check(c2.pssParts.modernTick:IsShown(), "Modern tick does not follow SetChecked")
c2:SetChecked(false)
check(e1.pssParts.modernBox:IsShown() and not e1.pssParts.fill:IsShown(), "Modern box art not shown")
-- the window on black, pages under a divider, boxes as cards
check(win.art.black and win.art.black:IsShown() and art.blizzard:IsShown(), "Modern window not the metal frame on black")
-- the template's stone fades; behind the tabs and the arrows' line our stone
-- band with our streaks over it (the stub's template has neither stone nor
-- streaks: stand-ins)
do
	local bz = art.blizzard
	bz.Bg, bz.TopTileStreaks = bz:CreateTexture(), bz:CreateTexture()
	H.Private("PourSocialScore_GUI").Repaint()
	local band, streaks = win.art.band, win.art.streaks
	check(band and band:IsShown() and band._texture == "Interface\\FrameGeneral\\UI-Background-Rock" and band:GetHeight() == 63,
		"Modern has no stone band behind the tabs")
	-- the streaks reach the pages (past the arrows' line), ours over the template's
	check(streaks and streaks:IsShown() and streaks._atlas == "_UI-Frame-TopTileStreaks" and streaks:GetHeight() == 63
		and bz.TopTileStreaks:GetAlpha() == 0, "Modern streaks do not reach under the arrows")
	M.PSS_SetOpt("uiSkin", "global", 0)
	check(bz.Bg:GetAlpha() == 1 and not win.art.band:IsShown(), "Classic lost its background or shows the band")
	check(streaks:IsShown() and streaks:GetHeight() == 63 and bz.TopTileStreaks:GetAlpha() == 0, "Classic streaks do not reach under the arrows")
	M.PSS_SetOpt("uiSkin", "global", 2)
end
local pg = kit.pages[1]
check(pg.pssParts.divider:IsShown() and not pg.pssParts.card:IsShown() and not pg.pssParts.art:IsShown(), "Modern page not on black under a divider")
-- tabs: the gold-framed plate, the selected glow on the selected one only
check(kit.tabs[1].pssSide.plate:IsShown() and not kit.tabs[1].pssLine:IsShown() and not kit.tabs[1].pssPlate:IsShown(), "Modern tabs not the gold-framed plate")
check(kit.tabs[1].pssSide.plate._atlas == "common-button-tertiary-normal", "Modern tab not the straight plate")
check(kit.tabs[1].pssSide.lit:IsShown() and not kit.tabs[2].pssSide.lit:IsShown(), "Modern selected tab not brighter")
-- popups: newer border, the accept button red, cancel dark
check(cf.pssParts.art:IsShown() and cf.pssParts.art.pssBlack:IsShown() and cf.pssParts.art.pssBlack._color[4] == 1 and not cf.pssParts.dim:IsShown(), "Modern popup not the window's frame on black")
check(cf.accept.pssParts.red.left:IsShown() and cf.cancel.pssParts.tertiary.texture:IsShown(), "Modern popup buttons not red accept and dark cancel")
check(cf.accept.pssParts.red.left:GetWidth() == 13.5, "red button end not scaled to the height")
check(dd.blizz:IsShown() and not dd.dark:IsShown(), "Modern drop-down is not Blizzard's")
-- without the art (Camelot) Modern is the Blizzard look
C_Texture.GetAtlasInfo = realAtlas
M.PSS_SetOpt("uiSkin", "global", 2)
check(not win.art.streaks:IsShown() and art.blizzard.TopTileStreaks:GetAlpha() == 1, "without the art the template's own streaks are not shown")
check(not tert.texture:IsShown() and not c1.pssParts.modernBox:IsShown() and not win.art.black:IsShown() and kit.pages[1].pssParts.art:IsShown() and not kit.tabs[1].pssSide.plate:IsShown(), "Modern without the art is not the Blizzard look")
kit.tabs[1]._scripts.OnClick(kit.tabs[1])
M.PSS_SetOpt("uiSkin", "global", 0)

-- (3.5.0) the timed confirm and the graphics settings popup (/pss gfx), built
-- and painted in every look; every button is a one-line call into Libraries
-- (stood in for here by a tiny fake of the M.PSS_Gfx* functions, put back
-- after; the real ones are driven by check_gfx.lua)
do
	local fakes = true
	local real = {}
	for _, n in ipairs({ "ExportText", "Parse", "RestorePlan", "Summary", "Apply", "History", "SetDiff", "Reload", "KeepSpec" }) do
		real[n] = M["PSS_Gfx" .. n]
	end
	local glog = {}
	local sets = { { i = 1, when = 1790000000, whenText = "2026-10-09 10:00", changed = 3 },
		{ i = 2, when = 1789999000, whenText = "2026-10-09 09:43", changed = 0 } }
	if fakes then
		M.PSS_GfxExportText = function() return "PSSGFX1 Camelot 16001\nrenderScale=1", 1 end
		M.PSS_GfxParse = function(text)
			if not text:find("^PSSGFX1") then return nil, "Not a graphics settings string." end
			return { changes = { { "renderScale", "1", "2" } } }
		end
		M.PSS_GfxRestorePlan = function() return { changes = { { "renderScale", "2", "1" } } } end
		M.PSS_GfxSummary = function(plan) return #plan.changes .. " settings will change." end
		M.PSS_GfxApply = function(plan) glog[#glog + 1] = "apply" return true end
		M.PSS_GfxHistory = function() return sets end
		M.PSS_GfxSetDiff = function(i) return "Saved " .. sets[i].whenText .. "\nrenderScale: 2 -> 1" end
		M.PSS_GfxReload = function() glog[#glog + 1] = "reload" end
		M.PSS_GfxKeepSpec = function()
			return { title = "Keep Graphics Settings?", text = "Keep?", accept = "Keep", cancel = "Revert", timeout = 15,
				onAccept = function() glog[#glog + 1] = "keep" end, onCancel = function() glog[#glog + 1] = "cancel" end,
				onTimeout = function() glog[#glog + 1] = "timeout" end }
		end
	end
	for _, skin in ipairs({ 2, 0, 1 }) do
		local look = ({ [0] = "Classic", [1] = "Dark", [2] = "Modern" })[skin]
		for k in pairs(glog) do glog[k] = nil end
		M.PSS_SetOpt("uiSkin", "global", skin)
		-- the kit preview's timed confirm
		mk.timed._scripts.OnClick(mk.timed)
		local c = _G.PSS_Confirm
		check(c:IsShown() and c.cancel._text == "Revert (15)", look .. " timed confirm: cancel button not counting")
		check(c.title:GetText() == "Keep Settings?", look .. " timed confirm title")
		H.RunOnUpdate(100)
		check(c.cancel._text == "Revert (13)" or c.cancel._text == "Revert (14)", look .. " timed confirm did not count down: " .. tostring(c.cancel._text))
		H.RunOnUpdate(700)
		check(not c:IsShown() and mk.result:GetText() == "Last: Timed out", look .. " timed confirm: timeout did not run onTimeout only")
		check(c._scripts.OnUpdate == nil, look .. " timed confirm left its OnUpdate")
		mk.timed._scripts.OnClick(mk.timed)
		c.cancel._scripts.OnClick(c)
		check(mk.result:GetText() == "Last: Reverted", look .. " timed confirm: cancel")
		mk.timed._scripts.OnClick(mk.timed)
		c.accept._scripts.OnClick(c)
		check(mk.result:GetText() == "Last: Kept" and c._scripts.OnUpdate == nil, look .. " timed confirm: accept")
		mk.confirm._scripts.OnClick(mk.confirm)
		check(c.cancel._text == (CANCEL or "Cancel"), look .. " plain confirm keeps the plain cancel")
		c:Hide()
		-- the keep prompt
		M.PSS_GfxKeepPrompt()
		H.RunOnUpdate(800)
		check(glog[#glog] == "timeout" and #glog == 1, look .. " keep prompt timeout: " .. table.concat(glog, ","))
		M.PSS_GfxKeepPrompt()
		c:Hide()	-- Escape
		check(glog[#glog] == "cancel", look .. " keep prompt Escape is not a revert")
		-- the graphics popup
		M.PSS_GfxBox()
		local g = _G.PSS_GfxPopup
		check(g and g:IsShown() and g.title:GetText() == "Graphics Settings", look .. " graphics popup")
		local dark = skin == 1
		check(g.pssParts.dim:IsShown() == dark and g.pssParts.fill:IsShown() == (dark or not g.pssParts.art), look .. " graphics popup paint")
		g.export._scripts.OnClick(g.export)
		check(g.edit:GetText():find("^PSSGFX1") and g.subtitle:GetText() == "1 settings", look .. " Export")
		g.edit:SetText("junk")
		g.import._scripts.OnClick(g.import)
		check(g.subtitle:GetText() == "Not a graphics settings string.", look .. " Import refusal text")
		g.edit:SetText("PSSGFX1 Camelot 16001\nrenderScale=2")
		g.import._scripts.OnClick(g.import)
		check(c:IsShown() and c.title:GetText() == "Apply Graphics Settings?" and c.text:GetText() == "1 settings will change.", look .. " Import preview")
		c.accept._scripts.OnClick(c)
		check(glog[#glog] == "apply", look .. " Apply did not call Libraries")
		g.reload._scripts.OnClick(g.reload)
		check(glog[#glog] == "reload", look .. " Reload UI")
		-- History
		g.history._scripts.OnClick(g.history)
		check(g.listFrame:IsShown() and g.restore:IsShown() and g.back:IsShown() and not g.import:IsShown(), look .. " History view not shown")
		g.list.scroll:SetHeight(88)	-- the stub does not size it from its anchors
		g.list:Layout()
		check(g.list.count == 2 and g.list.rows[1].cells.when:GetText() == "2026-10-09 10:00" and g.list.rows[1].cells.changed:GetText() == "3", look .. " History rows")
		check(not g.restore:IsEnabled(), look .. " Restore enabled with nothing picked")
		g.list.rows[2]._scripts.OnClick(g.list.rows[2], "LeftButton")
		check(g.list.rows[2].sel:IsShown() and not g.list.rows[1].sel:IsShown() and g.edit:GetText():find("^Saved 2026%-10%-09 09:43"), look .. " History row click")
		g.restore._scripts.OnClick(g.restore)
		check(c:IsShown() and c.title:GetText() == "Apply Graphics Settings?", look .. " Restore preview")
		c:Hide()
		g.hexport._scripts.OnClick(g.hexport)
		check(g.edit:GetText():find("^PSSGFX1"), look .. " History Export")
		g.back._scripts.OnClick(g.back)
		check(not g.listFrame:IsShown() and g.import:IsShown() and not g.restore:IsShown(), look .. " Back")
		g.history._scripts.OnClick(g.history)
		g:Hide()	-- Escape from the History view: the next open starts on the main view
		M.PSS_GfxBox()
		check(not g.histOn and g.import:IsShown() and g.edit:GetText() == "", look .. " reopened in the History view")
		g:Hide()
		local listed = false
		for _, n in ipairs(UISpecialFrames) do if n == "PSS_GfxPopup" then listed = true end end
		check(listed, "PSS_GfxPopup does not close on Escape")
	end
	if fakes then
		for _, n in ipairs({ "ExportText", "Parse", "RestorePlan", "Summary", "Apply", "History", "SetDiff", "Reload", "KeepSpec" }) do
			M["PSS_Gfx" .. n] = real[n]
		end
	end
	M.PSS_SetOpt("uiSkin", "global", 0)
end

-- (3.4.0.16) the tabs hear core events only while the window shows
do
	local realReg, realUnreg = M.Events.Register, M.Events.Unregister
	local reg, unreg = 0, 0
	M.Events.Register = function(...) reg = reg + 1 return realReg(...) end
	M.Events.Unregister = function(...) unreg = unreg + 1 return realUnreg(...) end
	if not win:IsShown() then SlashCmdList["PSS"]("gui") end
	reg, unreg = 0, 0
	win:Hide()
	check(unreg >= 15 and reg == 0, ("closing the window removed %d listeners (added %d)"):format(unreg, reg))
	SlashCmdList["PSS"]("gui")
	check(reg == unreg, ("opening the window added %d listeners, %d were removed"):format(reg, unreg))
	M.Events.Register, M.Events.Unregister = realReg, realUnreg
	win:Hide()
end

------------------------------------------------------------------------
-- (3.6.0) the AddOns tab: opened by /pss acp, drawn in all three looks, built
-- only when opened, its list dropped when the window closes
------------------------------------------------------------------------
do
	local ui = H.Private("PourSocialScore_GUI")
	win:Hide()
	check(not win.pages[7].refresh, "the AddOns tab is built before it is opened")
	SlashCmdList["PSS"]("acp")
	local pg = win.pages[7]
	check(win:IsShown() and pg:IsShown() and pg.refresh, "/pss acp did not open the AddOns tab")
	SlashCmdList["PSS"]("acp")
	check(not win:IsShown(), "/pss acp again did not close the window")
	win.tabs[1]._scripts.OnClick(win.tabs[1])
	win:Show()
	M.PSS_OpenUI("addons")
	check(win:IsShown() and pg:IsShown(), "M.PSS_OpenUI(\"addons\") did not select the tab")
	check(PourSocialScoreDB.windowPoints.PSS_WindowTab == "addons", "the AddOns tab is not remembered as the last tab")
	-- the tab row clears the Options search box (real fonts run wider than the stub's: 15 percent)
	local right = 10
	for _, t in ipairs(win.tabs) do right = right + t:GetWidth() + 2 end
	local opts = win.pages[6]
	if not opts.search then win.tabs[6]._scripts.OnClick(win.tabs[6]) end
	local boxW = win.pages[6].search and win.pages[6].search:GetWidth() or 0
	check(boxW >= 160, "the Options search box is narrower than 160")
	check(right * 1.15 < 960 - 12 - boxW, ("the tab row (%d) reaches the Options search box (from %d)"):format(right * 1.15, 960 - 12 - boxW))
	win.tabs[7]._scripts.OnClick(win.tabs[7])
	local V = pg.state
	-- the stub's frames are 20 high: give the list its real height (15 rows)
	pg.list.scroll:SetSize(900, 300)
	pg.list:Layout()
	for _, look in ipairs({ 2, 0, 1 }) do
		M.PSS_SetOpt("uiSkin", "global", look)
		local name = ({ [2] = "Modern", [0] = "Classic", [1] = "Dark" })[look]
		pg.refresh()
		check(V:Count() > 10 and #pg.list.rows >= 10, name .. ": the AddOns list is empty")
		local header, withLoad, plain
		for _, row in ipairs(pg.list.rows) do
			local text = row.cells.title:GetText() or ""
			if row.arrow:IsShown() or text:find("^%[[-+]%]") then header = header or row end
			if row.load:IsShown() then withLoad = withLoad or row end
			if row.tick:IsShown() and not row.arrow:IsShown() and text ~= "" then plain = plain or row end
		end
		check(header and withLoad and plain, name .. ": no header, Load button or addon row")
		-- the stats row and the footer say what they must
		check(pg.refresh and tostring(V:Stats()):find("Memory", 1, true), name .. ": no memory in the stats line")
	end
	M.PSS_SetOpt("uiSkin", "global", 0)
	-- a search narrows the list; a tick turns an addon on; Escape of the search clears it
	local search = pg.search
	search:SetText("zedone")
	search._scripts.OnTextChanged(search)
	check(V:Count() == 1, "the search did not narrow the list to one addon: " .. V:Count())
	local row = pg.list.rows[1]
	row.tick:SetChecked(true)
	row.tick._scripts.OnClick(row.tick)
	local zed
	for _, r in ipairs(H.AddonList()) do if r.name == "ZedOne" then zed = r end end
	check(zed and zed.me, "the tick did not turn the addon on")
	-- the Load button of a load on demand addon
	search:SetText("atlas_options")
	search._scripts.OnTextChanged(search)
	row = pg.list.rows[1]
	check(row.load:IsShown(), "no Load button on a load on demand addon")
	row.load._scripts.OnClick(row.load)
	local loadedNow
	for _, r in ipairs(H.AddonList()) do if r.name == "Atlas_Options" then loadedNow = r.loaded end end
	check(loadedNow, "the Load button did not load the addon")
	search:SetText("")
	search._scripts.OnTextChanged(search)
	-- a group header collapses
	local before = V:Count()
	for k = 1, V:Count() do
		local o = V:Row(k, {})
		if o.header then
			pg.list.rows[k]._scripts.OnClick(pg.list.rows[k], "LeftButton")
			break
		end
	end
	check(V:Count() < before, "a header click did not collapse its group")
	V:CollapseAll(false)
	-- the window closing drops the list (the choices stay)
	win:Hide()
	check(V:Count() == 0 and V.L == nil, "the AddOns list is kept after the window closes")
	-- the kit: a name field on the confirm, and the file helper
	local got
	ui.Confirm({ title = "Save Set?", text = "x", name = { text = "Raid", max = 32 }, onAccept = function(_, typed) got = typed end })
	local c = _G.PSS_Confirm
	check(c.name:IsShown() and c.name:GetText() == "Raid", "the name field is not shown with its text")
	c.name:SetText("Other")
	c.accept._scripts.OnClick(c.accept)
	check(got == "Other", "Accept did not hand over the name: " .. tostring(got))
	ui.Confirm({ title = "Delete?", text = "x", onAccept = function() end })
	check(not c.name:IsShown(), "the name field shows on a popup without one")
	c:Hide()
	local t = { SetTexture = function() return false end, SetTexCoord = function() error("coords on a missing file") end }
	check(ui.FileTexture(t, "x", { 0, 1, 0, 1 }) == false, "FileTexture does not report a missing file")
	local coords
	t = { SetTexture = function() return true end, SetTexCoord = function(_, ...) coords = { ... } end }
	check(ui.FileTexture(t, "x", { 0.75, 1, 0, 1 }) == true and coords[1] == 0.75, "FileTexture does not set the coords")
end

if not fail then print("PASS tui") end
