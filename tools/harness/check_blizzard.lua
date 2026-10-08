-- Blizzard's ignore list and PSS (core uplift B1, 3.4.1.35): PSS is
-- authoritative; a player goes on Blizzard's list only when ticked.
--   flow:  lua5.1 tools/harness/run.lua . - - tools/harness/check_blizzard.lua
--   make:  PSS_PHASE=make  ... run.lua . - <save> check_blizzard.lua   writes a 3.4.1.34-style save:
--          two listed players, the global option on, upgrade step 7
--   login: PSS_PHASE=login PSS_BLIZZ_IGNORES="Alpha;Stranger" [PSS_BLIZZ_LATE=1] ... run.lua . <save> - check_blizzard.lua
--          the upgrade (step 8) and the login sync
local phase = os.getenv("PSS_PHASE") or "flow"
local fail = 0
local function check(ok, msg) if not ok then print("FAIL blizzard: " .. msg); fail = fail + 1 end end
local V = PourSocialScore_NS.V
local function full(n) return M.Proper(M.addServer(n)) end
local function idx(n) return M.hasGlobalIgnored(full(n)) end
local function note(n) local i = idx(n); return i > 0 and PourSocialScoreDB.notes[i] or nil end
local function rec(n) return M.PSS_GetPlayerRecord(full(n)) end
local function ticked(n) local p = rec(n); return p ~= nil and p.blizzardIgnore == true end
local function onBlizz(n)
	for i = 1, C_FriendList.GetNumIgnores() do
		if C_FriendList.GetIgnoreName(i):lower() == n:lower() then return true end
	end
	return false
end
local function update() H.Fire("IGNORELIST_UPDATE") end
local DATE = "Synced from Blizzard ignore list on "

if phase == "make" then
	M.PSS_AddIgnore("Alpha", true)
	M.PSS_AddIgnore("Beta", true)
	PourSocialScoreDB.blizzardSync = true
	PourSocialScoreDB.upgrade.step = 7
	print("PASS blizzard make")
	return
end

if phase == "login" then
	-- upgrade step 8: Alpha is on Blizzard's list, so it is ticked; Beta is not
	check(PourSocialScoreDB.blizzardSync == nil, "the global option is still saved")
	check(PourSocialScoreDB.upgrade.step == 8, "step " .. tostring(PourSocialScoreDB.upgrade.step) .. ", not 8")
	check(ticked("Alpha"), "Alpha (listed, on Blizzard's list) was not ticked")
	check(not ticked("Beta"), "Beta (listed, not on Blizzard's list) was ticked")
	check(onBlizz("Alpha"), "Alpha was taken off Blizzard's list")
	-- the login sync: Stranger is listed with the note and ticked, and stays
	check(idx("Stranger") > 0, "Stranger (only on Blizzard's list) was not listed")
	check((note("Stranger") or ""):sub(1, #DATE) == DATE, "Stranger's note: " .. tostring(note("Stranger")))
	check(ticked("Stranger"), "Stranger was not ticked")
	check(onBlizz("Stranger"), "Stranger was taken off Blizzard's list")
	check(C_FriendList.GetNumIgnores() == 2, "Blizzard's list has " .. C_FriendList.GetNumIgnores() .. " names")
	check(not onBlizz("Beta"), "Beta was put on Blizzard's list")
	-- a second list update changes nothing
	local before = #PourSocialScoreDB.ignoreList
	update()
	check(#PourSocialScoreDB.ignoreList == before and C_FriendList.GetNumIgnores() == 2, "a later update changed the lists")
	print(fail == 0 and "PASS blizzard login" or ("FAIL blizzard login: " .. fail))
	return
end

------------------------------------------------------------------------
-- flow, on a fresh save
------------------------------------------------------------------------
V.PSS_Loaded = true
check(C_FriendList.GetNumIgnores() == 0, "the stub's list is not empty")

-- 1. PSS adds nothing to Blizzard's list on its own
M.PSS_AddIgnore("Plain", true)
check(idx("Plain") > 0 and not onBlizz("Plain"), "/pss add put someone on Blizzard's list")
check(rec("Plain") and rec("Plain").blizzardIgnore == nil, "a new player starts ticked")

-- 2. the tick puts them on Blizzard's list and takes them off
check(M.PSS_SetBlizzardIgnore("Plain", true) == true, "ticking failed")
check(onBlizz("Plain") and ticked("Plain"), "the tick did not put Plain on Blizzard's list")
update()
check(onBlizz("Plain") and idx("Plain") > 0, "a list update took a ticked player off Blizzard's list")
M.PSS_SetBlizzardIgnore("Plain", false)
check(not onBlizz("Plain") and not ticked("Plain"), "unticking left Plain on Blizzard's list")
check(rec("Plain").blizzardIgnore == nil, "an unticked field is saved (true only)")

-- 3. a new Blizzard ignore moves into PSS: listed with the note, then off Blizzard's list
C_FriendList.AddIgnore("Mover")
check(idx("Mover") > 0, "Blizzard's Ignore did not list Mover")
check((note("Mover") or ""):sub(1, #DATE) == DATE, "Mover's note: " .. tostring(note("Mover")))
check(onBlizz("Mover"), "Mover came off before Blizzard's list update")
update()
check(not onBlizz("Mover"), "Mover is still on Blizzard's list after the update")
check(idx("Mover") > 0 and not ticked("Mover"), "Mover lost the listing or was ticked")

-- 4. someone PSS already lists comes off too and keeps their note
M.PSS_AddIgnore("Noted", true)
M.PSS_SetNote(idx("Noted"), "my own note")
C_FriendList.AddIgnore("Noted")
update()
check(not onBlizz("Noted"), "a listed player stayed on Blizzard's list")
check(note("Noted") == "my own note", "a listed player's note changed: " .. tostring(note("Noted")))

-- 5. ... unless they are ticked
M.PSS_SetBlizzardIgnore("Noted", true)
C_FriendList.DelIgnore("Noted")		-- (Blizzard's own Unignore removes them from PSS, below)
M.PSS_AddIgnore("Keeper", true)
M.PSS_SetBlizzardIgnore("Keeper", true)
C_FriendList.AddIgnore("Keeper")
update()
check(onBlizz("Keeper"), "a ticked player was taken off Blizzard's list")

-- 6. removing from either removes from both
check(idx("Noted") == 0, "Blizzard's Unignore did not remove Noted from PSS")
M.PSS_DelIgnore(idx("Keeper"), true)
check(idx("Keeper") == 0 and not onBlizz("Keeper"), "removing Keeper in PSS left them on Blizzard's list")
M.PSS_AddIgnore("Gone", true)
M.PSS_SetBlizzardIgnore("Gone", true)
C_FriendList.DelIgnore("Gone")
check(idx("Gone") == 0, "Unignore in Blizzard's window kept Gone in PSS")

-- 7. a full Blizzard list refuses the tick
local names = H.blizzList.names
for i = #names + 1, 50 do names[i] = "Block" .. i end		-- fill it without hooks
M.PSS_AddIgnore("Late", true)
check(M.PSS_SetBlizzardIgnore("Late", true) == false, "the tick worked on a full list")
check(not ticked("Late") and not onBlizz("Late"), "a refused tick was kept")
print(fail == 0 and "PASS blizzard" or ("FAIL blizzard: " .. fail))
