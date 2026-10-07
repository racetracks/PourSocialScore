-- The new PSS window (3.4.0), as a run.lua script on a fresh save:
-- PourSocialScore_UI and PourSocialScore_Libraries are not loaded at login;
-- /pss tui loads them (not the old windows) and toggles the window; Escape
-- closes it; a dragged place is remembered; the look follows the uiSkin
-- option (Blizzard by default) and repaints the open window.
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

if not fail then print("PASS tui") end
