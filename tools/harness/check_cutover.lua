-- Upgrade step 7 (3.4.0.25, D2), as a run.lua script on a save that had
-- step 6 (validate_all.sh plants the old keys and a leftover
-- PourSocialScore_EllesmereUI folder first):
--   PSS_PHASE=1 : the EllesmereUI integration option (euiIntegration, held in
--                 PSS_OptionsDB although it is no longer an option) and the
--                 old window's sizes, column widths and places are gone; the
--                 new window's place and tab are kept; the step is recorded
--   PSS_PHASE=2 : the next login changes nothing (validate_all.sh also
--                 checks the old-folder note was said at the first login
--                 only)
local phase = tonumber(os.getenv("PSS_PHASE") or "1")
local fail = false
local function check(ok, msg) if not ok then print("FAIL cutover: " .. msg) fail = true end end

for _, k in ipairs({ "euiIntegration", "windowSizes", "columnWidths" }) do
	check(PSS_OptionsDB[k] == nil and rawget(PourSocialScoreDB, k) == nil, k .. " not pruned")
end
local points = PSS_OptionsDB.windowPoints
check(type(points) == "table" and points.PSS == nil and points.PSSGuildDetail == nil, "the old window's places not pruned")
check(points and type(points.PSS_Window) == "table" and points.PSS_WindowTab == "guilds", "the window's place or tab lost")
check(M.PSS_UPGRADE_STEPS >= 7 and PourSocialScoreDB.upgrade.step == M.PSS_UPGRADE_STEPS, "step 7 not recorded")
-- the window opens where it was and on its tab
SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window
check(win and win:IsShown() and win.pages[2] and win.pages[2]:IsShown(), "the window did not open on its saved tab")
check(win and win._point and win._point[1] == "TOPLEFT" and win._point[4] == 300, "the window did not open at its saved place")
SlashCmdList["PSS"]("gui")

if not fail then print("PASS cutover " .. phase) end
