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

-- Blizzard look by default
local art = win and win.art or {}
check(M.PSS_UISkin() == "blizzard", "default look is not Blizzard")
check(art.blizzard and art.blizzard:IsShown() and not art.modern:IsShown(), "Blizzard look not shown")
check(art.blizzardClose:IsShown() and not art.modernClose:IsShown(), "Blizzard close button not shown")

-- Modern: the open window repaints, and only a non-default value is saved
M.PSS_SetOpt("uiSkin", "global", 1)
check(M.PSS_UISkin() == "modern", "option did not switch to Modern")
check(art.modern:IsShown() and not art.blizzard:IsShown(), "window did not repaint Modern")
check(art.modernClose:IsShown() and not art.blizzardClose:IsShown(), "Modern close button not shown")
M.PSS_SetOpt("uiSkin", "global", 0)
check(art.blizzard:IsShown() and not art.modern:IsShown(), "window did not repaint Blizzard")
check(PourSocialScoreDB.uiSkin == nil, "the default look was saved")

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

-- the kit preview, in both looks
local kit = win.kit or {}
check(kit.tabs and #kit.tabs == 6, "kit preview has no tab row")
local b1, c1, e1 = kit.buttons and kit.buttons[1], kit.checks and kit.checks[1], kit.boxes and kit.boxes[1]
local function modernShown(w) return w and w.pssParts and w.pssParts.fill:IsShown() end
check(b1 and not modernShown(b1) and not b1.pssParts.edge:IsShown(), "Blizzard button shows Modern parts")
check(e1 and not modernShown(e1), "Blizzard edit box shows Modern parts")
check(kit.page and kit.page.pssParts.art and kit.page.pssParts.art:IsShown(), "Blizzard panel not shown")
local tab1, tab2 = kit.tabs[1], kit.tabs[2]
check(tab1.pssSelected and not tab2.pssSelected, "first tab not selected")
SlashCmdList["PSS"]("tui")
M.PSS_SetOpt("uiSkin", "global", 1)
SlashCmdList["PSS"]("tui")
check(modernShown(b1) and b1.pssParts.edge:IsShown(), "Modern button parts not shown")
check(c1.pssParts.box:IsShown() and c1.pssParts.edge:IsShown(), "Modern tick box parts not shown")
check(modernShown(e1), "Modern edit box parts not shown")
check(modernShown(kit.page) and not kit.page.pssParts.art:IsShown(), "Modern panel not shown")
check(tab1.pssLine:IsShown() and not tab2.pssLine:IsShown(), "Modern tab underline not on the selected tab only")
check(tab2:GetFontString():GetAlpha() == 0.5 and tab1:GetFontString():GetAlpha() == 1, "Modern tab labels not faded by alpha")
kit.tabs[3]._scripts.OnClick(kit.tabs[3])
check(kit.tabs[3].pssSelected and not tab1.pssSelected, "tab click did not select it")

-- tooltips: Modern draws its own; Blizzard uses GameTooltip
local owner = kit.tipOwner
owner._scripts.OnEnter(owner)
check(_G.PSS_Tooltip and _G.PSS_Tooltip:IsShown(), "Modern tooltip not shown")
owner._scripts.OnLeave(owner)
M.PSS_SetOpt("uiSkin", "global", 0)
check(not modernShown(b1) and not c1.pssParts.box:IsShown(), "back to Blizzard: Modern parts still shown")
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
check(face() == "Fonts\\ARIALN.TTF", "Modern look does not default to Arial Narrow")
M.PSS_SetOpt("uiFont", "global", "morpheus")
check(face() == "Fonts\\MORPHEUS.TTF", "picked font not used in Modern")
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

if not fail then print("PASS tui") end
