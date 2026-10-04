-- PourSocialScore_GUI on demand (3.0 Step 3.1), as a run.lua script on a
-- fresh save: the windows are not loaded at login; chat, the note popup,
-- the group warning and window refreshes work without them; the Friends
-- window (when the option is on) and /pss gui load them.
local fail = false
local function check(ok, msg) if not ok then print("FAIL gui: " .. msg) fail = true end end
local loaded = function() return C_AddOns.IsAddOnLoaded("PourSocialScore_GUI") end

check(not loaded(), "GUI loaded at login")

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
PourSocialScoreDB.openWithFriends = opt

-- /pss gui opens it (the stub was replaced by the real function)
SlashCmdList["PSS"]("gui")
check(_G.PSS and _G.PSS:IsShown(), "/pss gui did not open the window")

if not fail then print("PASS gui") end
