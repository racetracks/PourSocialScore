-- Core popups with EllesmereUI loaded (3.4.0.23, D1). Runs on the save
-- check_eui_window.lua phase 1 wrote (the retired integration option on).
-- The note and the party warning are Blizzard's StaticPopups in every look
-- (Dan, 2026-10-08): never EllesmereUI's, in or out of combat.
local fail = false
local function check(ok, msg) if not ok then print("FAIL eui popups: " .. msg) fail = true end end
local E = EllesmereUI

local shown = {}
local realShow = StaticPopup_Show
StaticPopup_Show = function(which, a, b) shown[#shown + 1] = { which, a, b } end

check(M.PSS_Opt("euiIntegration") == true, "the save does not have the old option on")

M.PSS_AddPlayer("Badguy")
local BAD = M.Proper(M.addServer("Badguy"))	-- ASK_NOTE names the stored entry
check(M.hasAnyIgnored(BAD) > 0, "Badguy not listed")
M.Events.Fire("ASK_NOTE", BAD)
M.Events.Fire("GROUP_WARNING", { "Badguy", "Other" })
local realCombat = InCombatLockdown
InCombatLockdown = function() return true end
M.Events.Fire("GROUP_WARNING", { "Badguy" })
InCombatLockdown = realCombat
check(shown[1] and shown[1][1] == "PSS_REASON" and shown[1][2] == BAD, "the note is not the PSS popup")
check(shown[2] and shown[2][1] == "PSS_PARTYWARN" and shown[2][2] == 2 and tostring(shown[2][3]):find("Other", 1, true),
	"the party warning is not the PSS popup")
check(shown[3] and shown[3][1] == "PSS_PARTYWARN", "the party warning in combat is not the PSS popup")
check(#(E.log.inputs or {}) == 0 and #E.log.popups == 0, "an EllesmereUI popup was shown")

StaticPopup_Show = realShow
if not fail then print("PASS eui popups") end
