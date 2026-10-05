-- Core popups under EllesmereUI (3.1 Step E.7). Runs on the save
-- check_eui_window.lua phase 1 wrote (integration on).
--   ASK_NOTE:      EllesmereUI's input popup with the current note; Save
--                  stores it (an empty note clears it)
--   GROUP_WARNING: EllesmereUI's confirm popup (Accept only), closed after
--                  the timeout only while it still shows that warning;
--                  in combat, or over another EllesmereUI confirm, the PSS
--                  popup instead
--   integration off: the PSS popups (StaticPopup) as before
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui popups: " .. msg) fail = true end end
local E = EllesmereUI
local db = PourSocialScoreDB
local L = PourSocialScore_NS.L

local shown = {}
local realShow = StaticPopup_Show
StaticPopup_Show = function(which) shown[#shown + 1] = which end

check(M.PSS_UseEUI(), "integration not in use")

-- the note: input popup with the current note
M.PSS_AddPlayer("Badguy")
local BAD = M.Proper(M.addServer("Badguy"))	-- ASK_NOTE names the stored entry
local idx = M.hasAnyIgnored(BAD)
check(idx > 0, "Badguy not listed")
M.PSS_SetNote(idx, "old note")
M.Events.Fire("ASK_NOTE", BAD)
local inp = E.log.inputs[1]
check(#shown == 0, "PSS note popup shown under EllesmereUI")
check(inp and inp.initialText == "old note" and inp.maxLetters == 128 and inp.allowEmpty, "input popup options")
check(inp and inp.message:find("Badguy", 1, true), "input popup does not name the player")
local changed = 0
local id = M.Events.Register("PLAYERS_CHANGED", function() changed = changed + 1 end)
inp.onConfirm("spams trade")
check(db.notes[M.hasAnyIgnored(BAD)] == "spams trade", "note not saved")
check(changed > 0, "saving the note did not redraw")
M.Events.Fire("ASK_NOTE", BAD)
E.log.inputs[2].onConfirm("")
check((db.notes[M.hasAnyIgnored(BAD)] or "") == "", "empty note did not clear it")

-- the party warning: confirm popup, Accept only, closes after the timeout
local n = #E.log.popups
M.Events.Fire("GROUP_WARNING", { "Badguy", "Other" })
local w = E.log.popups[n + 1]
check(#shown == 0, "PSS party warning shown under EllesmereUI")
check(w and w.hideCancel and w.confirmText == L["BOX_6"] and w.message:find("Other", 1, true), "party warning popup options")
check(EUIConfirmDimmer:IsShown(), "warning not on screen")
H.RunTimers()
check(not EUIConfirmDimmer:IsShown(), "warning did not close after the timeout")

-- accepted, then another confirm opens: the timer leaves that one alone
M.Events.Fire("GROUP_WARNING", { "Badguy" })
E.log.popups[#E.log.popups].onConfirm()
EUIConfirmDimmer:Hide()
E:ShowConfirmPopup({ message = "something else" })
H.RunTimers()
check(EUIConfirmDimmer:IsShown(), "timeout closed another popup")

-- another confirm is open: the PSS warning, not over it
n = #E.log.popups
M.Events.Fire("GROUP_WARNING", { "Badguy" })
check(#E.log.popups == n and shown[#shown] == "PSS_PARTYWARN", "warning replaced an open confirm")
EUIConfirmDimmer:Hide()

-- in combat: the PSS warning (EllesmereUI's covers the screen)
local realCombat = InCombatLockdown
InCombatLockdown = function() return true end
M.Events.Fire("GROUP_WARNING", { "Badguy" })
InCombatLockdown = realCombat
check(#E.log.popups == n and shown[#shown] == "PSS_PARTYWARN", "EllesmereUI warning in combat")

-- integration off: both PSS popups
shown = {}
M.PSS_SetOpt("euiIntegration", "global", false)
check(not M.PSS_UseEUI(), "integration still on")
local inputs = #E.log.inputs
n = #E.log.popups
M.Events.Fire("ASK_NOTE", BAD)
M.Events.Fire("GROUP_WARNING", { "Badguy" })
check(shown[1] == "PSS_REASON" and shown[2] == "PSS_PARTYWARN", "PSS popups with integration off")
check(#E.log.inputs == inputs, "EllesmereUI note popup with integration off")

StaticPopup_Show = realShow
M.Events.Unregister("PLAYERS_CHANGED", id)
if not fail then print("PASS eui popups") end
