-- The new PSS window (3.4.0), as a run.lua script on a fresh save:
-- PourSocialScore_UI and PourSocialScore_Libraries are not loaded at login;
-- /pss tui loads them (not the old windows) and toggles the window; Escape
-- closes it; a dragged place is remembered; the look follows the uiSkin
-- option (Blizzard by default) and repaints the open window; the kit's
-- controls and tooltips follow the look; the uiFont option picks a Blizzard
-- font or, only while another addon has loaded it, a LibSharedMedia font.
local fail = false
local function check(ok, msg) if not ok then print("FAIL tui: " .. msg) fail = true end end
local loaded = function(name) return C_AddOns.IsAddOnLoaded(name) end

check(not loaded("PourSocialScore_UI"), "UI loaded at login")
check(not loaded("PourSocialScore_Libraries"), "Libraries loaded at login")
check(M.PSS_PARTS.UI == "PourSocialScore_UI", "loader has no UI part")

-- a list change with the window asleep loads nothing
M.PSS_AddPlayer("Badguy")
M.Events.Fire("PLAYERS_CHANGED", true)
M.Events.Fire("OPTION_CHANGED", "uiSkin")
check(not loaded("PourSocialScore_UI"), "UI loaded by a change")

-- /pss lists the command
local said, realShow = {}, M.ShowMsg
M.ShowMsg = function(x) said[#said + 1] = tostring(x) end
SlashCmdList["PSS"]("")
M.ShowMsg = realShow
check(table.concat(said, "\n"):find("tui", 1, true) ~= nil, "/pss help does not list tui")

-- /pss tui opens it, loading Libraries and UI only
SlashCmdList["PSS"]("tui")
local win = _G.PSS_Window
check(loaded("PourSocialScore_UI") and loaded("PourSocialScore_Libraries"), "/pss tui did not load UI and Libraries")
check(not loaded("PourSocialScore_GUI"), "/pss tui loaded the old GUI")
check(not loaded("PourSocialScore_EllesmereUI"), "/pss tui loaded the EllesmereUI window")
check(win and win:IsShown(), "/pss tui did not show the window")
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
SlashCmdList["PSS"]("tui")
check(not win:IsShown(), "second /pss tui did not close the window")
SlashCmdList["PSS"]("tui")
check(win:IsShown() and win._point[1] == "TOPLEFT" and win._point[4] == 120, "saved place not used")

-- Escape closes it (the helper frame in UISpecialFrames is hidden by Escape)
local listed = false
for _, n in ipairs(UISpecialFrames) do if n == "PSS_WindowEscape" then listed = true end end
check(listed, "Escape helper not in UISpecialFrames")
check(_G.PSS_WindowEscape:IsShown(), "Escape helper not shown with the window")
_G.PSS_WindowEscape:Hide()
check(not win:IsShown(), "Escape did not close the window")

------------------------------------------------------------------------
-- dev006: six tabs, back / forward, the line by the arrows, Escape
------------------------------------------------------------------------
SlashCmdList["PSS"]("tui")
check(win:IsShown(), "window did not open again")
local names = {}
for i, t in ipairs(win.tabs or {}) do names[i] = t:GetText() end
check(table.concat(names, ",") == "Player Ignore List,Guild Ignore List,Chat Filters,Events,Import/Export,Options", "tabs are not the six of the port")
check(win.tabs[1].pssSelected and win.pages[1]:IsShown() and not win.pages[2]:IsShown(), "first tab not shown first")
check(win.pages[3].note and win.pages[3].note:GetText():find("later", 1, true), "an unbuilt tab has no note")
check(win.where:GetText() == "Player Ignore List", "the line by the arrows does not name the tab")
check(win.where:GetAlpha() == 0.9, "the line by the arrows is not at 0.9")
check(not win.back:IsEnabled() and not win.forward:IsEnabled(), "arrows enabled with nowhere to go")
check(win.kit == nil and _G.PSS_KitPage == nil, "the kit preview is still in the window")
-- a tab click shows it, saves it (the first tab is not saved), and records a step
win.tabs[3]._scripts.OnClick(win.tabs[3])
check(win.tabs[3].pssSelected and win.pages[3]:IsShown() and not win.pages[1]:IsShown(), "tab click did not show the tab")
check(PourSocialScoreDB.windowPoints.PSS_WindowTab == "filters", "tab shown not saved")
check(win.back:IsEnabled() and win.where:GetText() == "Chat Filters", "tab click is not a step back")
-- a page with a sub-view (as the Guilds tab's members view will be)
local pg = win.pages[2]
local sub
pg.navState = function() return sub end
pg.navApply = function(v) sub = v end
pg.navUp = function() if sub then sub = nil return true end return false end
pg.navTitle = function(v) return "Members of " .. v end
win.tabs[2]._scripts.OnClick(win.tabs[2])
sub = "Badguild"
local ui = H.Private("PourSocialScore_UI")
ui.NavRecord()
check(win.where:GetText() == "Guild Ignore List  >  Members of Badguild", "the line does not name the sub-view")
check(win.crumbs[1] and win.crumbs[1]:IsShown() and win.crumbs[1].tipText == "Back to Guild Ignore List.", "no link back to the tab")
-- back, back, forward
ui.NavBack()
check(sub == nil and win.where:GetText() == "Guild Ignore List", "back did not leave the sub-view")
ui.NavBack()
check(win.pages[3]:IsShown() and win.forward:IsEnabled(), "back did not return to the tab before")
ui.NavForward()
ui.NavForward()
check(win.pages[2]:IsShown() and sub == "Badguild", "forward did not return to the sub-view")
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
check(sub == nil and win.where:GetText() == "Guild Ignore List", "the link did not reset the tab")
sub = "Badguild"
ui.NavRecord()
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and sub == nil and _G.PSS_WindowEscape:IsShown(), "Escape did not step up one level")
-- Events opened from another tab: Escape goes back there
win.tabs[4]._scripts.OnClick(win.tabs[4])
check(win.pages[4]:IsShown(), "Events tab not shown")
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and win.pages[2]:IsShown(), "Escape on Events did not go back to the tab before")
_G.PSS_WindowEscape:Hide()
check(not win:IsShown(), "Escape at the top did not close the window")
pg.navState, pg.navApply, pg.navUp, pg.navTitle = nil, nil, nil, nil
-- the tab shown last opens next time; the first tab clears the saved one
SlashCmdList["PSS"]("tui")
check(win.pages[2]:IsShown() and M.PSS_UITab() == 2, "saved tab not reopened")
win.tabs[1]._scripts.OnClick(win.tabs[1])
check(PourSocialScoreDB.windowPoints.PSS_WindowTab == nil, "the first tab was saved")
-- a tab with a builder is built on first open and redrawn when shown
local built, drawn = 0, 0
ui.TabBuilders.importExport = function(page) built = built + 1 return function() drawn = drawn + 1 end end
win.tabs[5]._scripts.OnClick(win.tabs[5])
win.tabs[5]._scripts.OnClick(win.tabs[5])
check(built == 1 and drawn == 2 and not win.pages[5].note:IsShown(), "a tab builder did not build once and redraw")
ui.TabBuilders.importExport = nil
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
assert(loadfile(dir .. "/kit_page.lua"))("PourSocialScore_UI", ui)
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
SlashCmdList["PSS"]("tui")
M.PSS_SetOpt("uiSkin", "global", 1)
SlashCmdList["PSS"]("tui")
local lc = tab1.pssLine._color
check(lc and lc[1] == 1 and lc[2] == 0.49 and lc[3] == 0.04, "Dark underline is not the class colour")
check(M.PSS_OPTION_REG.uiAccent == nil, "the accent has an option (the class colour is mandatory)")
check(darkShown(b1) and b1.pssParts.edge:IsShown(), "Dark button parts not shown")
check(c1.pssParts.box:IsShown() and c1.pssParts.edge:IsShown(), "Dark tick box parts not shown")
check(darkShown(e1), "Dark edit box parts not shown")
check(darkShown(kit.page) and not kit.page.pssParts.art:IsShown(), "Dark panel not shown")
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
SlashCmdList["PSS"]("tui")
SlashCmdList["PSS"]("tui")
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
check(cf.pssParts.art and cf.pssParts.art:IsShown() and not cf.pssParts.dim:IsShown(), "Blizzard confirm not in Blizzard art")
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
	H.Private("PourSocialScore_UI").Repaint()
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
check(cf.pssParts.modernArt and cf.pssParts.modernArt:IsShown() and not cf.pssParts.art:IsShown() and not cf.pssParts.dim:IsShown(), "Modern popup not in the newer dialog border")
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

if not fail then print("PASS tui") end
