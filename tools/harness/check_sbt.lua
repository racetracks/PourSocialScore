-- Scrolling Battle Text switch (3.4.0-dev001), as a run.lua script:
--   PSS_FOREVER=1 PSS_PHASE=1 : the option is there, off; nothing loaded for
--                               it; /pss sbt on loads Libraries and the SBT
--                               folder and starts the engine; off stops it;
--                               left on at logout.
--   PSS_FOREVER=1 PSS_PHASE=2 : on from the save: started at login.
--   (no PSS_FOREVER)          : Retail: no option, no section, no part;
--                               /pss sbt says Forever only, loads nothing.
local forever = os.getenv("PSS_FOREVER") == "1"
local phase = tonumber(os.getenv("PSS_PHASE") or "1")
local fail = false
local function check(ok, msg) if not ok then print("FAIL sbt: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local SBT = "PourSocialScore_ScrollingBattleText"

local row
for _, o in ipairs(M.PSS_OPTIONS) do if o.key == "sbtEnabled" then row = o end end

-- M.ShowMsg prints; keep the last line printed
local said = ""
M.ShowMsg = function(msg) said = tostring(msg) end
local function lastChat()
	return said
end

-- nothing may ever register the combat log (forbidden on Retail and Forever)
local function noCombatLog()
	for f in pairs(H.EventFrames and H.EventFrames() or {}) do
		check(not (f._events and f._events.COMBAT_LOG_EVENT_UNFILTERED), "a frame registered COMBAT_LOG_EVENT_UNFILTERED")
	end
end

if not forever then
	check(row == nil, "option row on Retail")
	check(M.PSS_OPTION_SECTIONS[6] == nil, "section on Retail")
	check(M.PSS_PARTS.ScrollingBattleText == nil, "part key on Retail")
	SlashCmdList.PSS("sbt on")
	check(lastChat():find("WoW Forever only", 1, true) ~= nil, "no Forever-only message: " .. lastChat())
	check(M.PSS_Opt("sbtEnabled") ~= true, "option set on Retail")
	check(not loaded(SBT), "SBT folder loaded on Retail")
	check(not M.PSS_Need("ScrollingBattleText"), "PSS_Need loaded the SBT part on Retail")
	check(not loaded(SBT), "SBT folder loaded on Retail by PSS_Need")
	noCombatLog()
	if not fail then print("PASS sbt retail") end
	return
end

check(row ~= nil and row.default == false and row.section == 6, "option row missing or not off by default")
check(M.PSS_OPTION_SECTIONS[6] ~= nil, "section missing")
check(M.PSS_PARTS.ScrollingBattleText == SBT, "part key missing")

if phase == 1 then
	check(M.PSS_Opt("sbtEnabled") == false, "option not off")
	check(not loaded(SBT), "SBT folder loaded while off")
	check(M.PSS_SBTRunning == nil or not M.PSS_SBTRunning(), "engine running while off")
	SlashCmdList.PSS("sbt")
	check(M.PSS_Opt("sbtEnabled") == true, "/pss sbt did not turn it on")
	check(loaded("PourSocialScore_Libraries") and loaded(SBT), "turning it on did not load Libraries and the SBT folder")
	check(M.PSS_SBTRunning(), "engine not started")
	SlashCmdList.PSS("sbt off")
	check(M.PSS_Opt("sbtEnabled") == false, "/pss sbt off did not turn it off")
	check(not M.PSS_SBTRunning(), "engine not stopped")
	check(rawget(PourSocialScoreDB, "sbtEnabled") == nil, "the default (off) is saved")
	SlashCmdList.PSS("sbt test")
	check(lastChat():find("not in this build", 1, true) ~= nil, "sbt test message: " .. lastChat())
	SlashCmdList.PSS("SBT ON")
	check(M.PSS_SBTRunning(), "/pss SBT ON did not start it")
elseif phase == 2 then
	check(M.PSS_Opt("sbtEnabled") == true, "option not saved on")
	check(loaded(SBT), "SBT folder not loaded at login")
	check(M.PSS_SBTRunning(), "engine not started at login")
	M.PSS_SetOpt("sbtEnabled", "global", false)
	check(not M.PSS_SBTRunning(), "option off did not stop it")
end
noCombatLog()
if not fail then print("PASS sbt " .. phase) end
