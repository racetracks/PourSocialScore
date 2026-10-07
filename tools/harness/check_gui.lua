-- On-demand addons (3.0 Steps 3.1 and 3.2), as a run.lua script on a fresh
-- save: PourSocialScore_GUI and PourSocialScore_Libraries are not loaded at
-- login; chat, the note popup, the group warning and window refreshes work
-- without them; a chat command loads Libraries only; the Friends window
-- (when the option is on) and /pss gui load the windows and Libraries.
local fail = false
local function check(ok, msg) if not ok then print("FAIL gui: " .. msg) fail = true end end
local loaded = function() return C_AddOns.IsAddOnLoaded("PourSocialScore_GUI") end
local libs = function() return C_AddOns.IsAddOnLoaded("PourSocialScore_Libraries") end

check(not loaded(), "GUI loaded at login")
check(not libs(), "Libraries loaded at login")

-- what fires during play, with the GUI asleep
local shown = {}
local realShow = StaticPopup_Show
StaticPopup_Show = function(which) shown[#shown + 1] = which end
M.Events.Fire("ASK_NOTE", "Badguy")
M.Events.Fire("GROUP_WARNING", { "Badguy" })
StaticPopup_Show = realShow
check(shown[1] == "PSS_REASON" and shown[2] == "PSS_PARTYWARN", "note popup and group warning")
check(StaticPopupDialogs["PSS_REASON"] and StaticPopupDialogs["PSS_PARTYWARN"], "resident popups defined")
local ok, err = pcall(function()
	M.PSS_AddPlayer("Badguy")
	M.PSSUpdateUI(true)
	M.Events.Fire("PLAYERS_CHANGED", true)
	M.Events.Fire("FILTERS_CHANGED")
end)
check(ok, "changes with the GUI asleep: " .. tostring(err))
check(not loaded(), "GUI loaded by a list change")
check(not libs(), "Libraries loaded by a list change")

-- chat commands load Libraries, not the windows
local said, realPrint, realChat = {}, print, M.ChatMsg
print = function(x) said[#said + 1] = tostring(x) end
M.ChatMsg = print
SlashCmdList["PSS"]("mem")
SlashCmdList["PSSGUILD"]("")
print, M.ChatMsg = realPrint, realChat
local text = table.concat(said, "\n")
check(libs(), "/pss did not load Libraries")
check(not loaded(), "/pss mem loaded the GUI")
check(text:find("PourSocialScore_Libraries: loaded", 1, true) ~= nil, "/pss mem did not run")
check(text:find("PSS guild:", 1, true) ~= nil, "/pssguild did not run")

-- Friends window with the option off: stays asleep
local opt = PourSocialScoreDB.openWithFriends
PourSocialScoreDB.openWithFriends = false
FriendsFrame:Show(); FriendsFrame:Hide()
check(not loaded(), "Friends window loaded the GUI with the option off")

-- option on: loads and shows the window next to it
PourSocialScoreDB.openWithFriends = true
FriendsFrame:Show()
check(loaded(), "Friends window did not load the GUI")
check(_G.PSS and _G.PSS:IsShown(), "window not shown with the Friends window")
FriendsFrame:Hide()
check(not (_G.PSS and _G.PSS:IsShown()), "window not hidden with the Friends window")

-- Retail 12.1 Social window: shows the window next to it, clear of its tabs
SocialUIFrame:Show()
check(_G.PSS:IsShown(), "window not shown with the Social window")
check(_G.PSS._point and _G.PSS._point[2] == SocialUIFrame and _G.PSS._point[4] == 55, "window not anchored to the Social window")
-- Social switching to the Who tab (FriendsFrame): the window stays and follows
FriendsFrame:Show(); SocialUIFrame:Hide()
check(_G.PSS:IsShown() and _G.PSS._point[2] == FriendsFrame, "window did not follow Social to the Who tab")
FriendsFrame:Hide()
check(not _G.PSS:IsShown(), "window not hidden with the Social window")
PourSocialScoreDB.openWithFriends = opt

-- /pss gui opens it (the stub was replaced by the real function)
SlashCmdList["PSS"]("gui")
check(_G.PSS and _G.PSS:IsShown(), "/pss gui did not open the window")

if not fail then print("PASS gui") end
