-- PourSocialScore_Logging on demand (3.0 Step 4.4), as a run.lua script on a
-- save that has already been upgraded (a login after the split):
--   PSS_PHASE=1 : Logging is not loaded at login. A block is counted at once
--                 (PSS_CountsDB) and its line waits in the outbox; removing
--                 a player with nothing blocked leaves it unloaded. Logout.
--   PSS_PHASE=2 : still not loaded at login, the line still waits. Opening
--                 the history loads Logging and the waiting line joins the
--                 log once; a removal loads it too.
--   PSS_PHASE=3 : 200 waiting lines load Logging by itself at a quiet moment.
local phase = tonumber(os.getenv("PSS_PHASE") or "1")
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL on demand: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

check(not loaded("PourSocialScore_Logging"), "Logging loaded at login")
check(type(PSS_LoggingDB) ~= "table", "PSS_LoggingDB exists before Logging loads")
check(type(PSS_CountsDB) == "table" and type(PSS_CountsDB.filterCount) == "table", "counts not loaded")

local lineID = 70000 + phase * 1000
local function whisper(msg, author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg, author, "", "", "", "", 0, 0, "", 0, lineID, nil)
end

if phase == 1 then
	M.PSS_AddIgnore("Ondemand-Realm", true)
	local before = M.PSS_GetPlayerBlockCounts("Ondemand-Realm").total
	check(whisper("waiting line", "Ondemand-Realm"), "whisper not blocked")
	check(M.PSS_GetPlayerBlockCounts("Ondemand-Realm").total == before + 1, "block not counted at once")
	check(not loaded("PourSocialScore_Logging"), "a block loaded Logging")
	check(History.Waiting() == 1, "line not waiting (" .. History.Waiting() .. ")")
	M.PSS_MemReport()
	check(not loaded("PourSocialScore_Logging"), "/pss mem loaded Logging")
	-- removing a player with nothing blocked has no lines to clear
	M.PSS_AddIgnore("Quiet-Realm", true)
	local pos = M.PSS_PlayerPosition("Quiet-Realm")
	check(pos > 0, "Quiet-Realm not listed")
	M.PSS_RemovePlayerAt(pos)
	check(M.PSS_PlayerPosition("Quiet-Realm") == 0, "Quiet-Realm not removed")
	check(not loaded("PourSocialScore_Logging"), "removing a player with no blocks loaded Logging")
elseif phase == 2 then
	check(History.Waiting() == 1, "waiting line lost over the logout")
	local n = 0
	for _, h in ipairs(M.PSS_GetPlayerBlockHistory("Ondemand-Realm")) do
		if h.message == "waiting line" then n = n + 1 end
	end
	check(loaded("PourSocialScore_Logging"), "history view did not load Logging")
	check(n == 1, "waiting line shows " .. n .. " times")
	check(History.Waiting() == 0, "outbox not emptied")
	check(rawget(PourSocialScoreDB, "outbox") == nil, "outbox still saved")
	check(M.PSS_GetPlayerBlockCounts("Ondemand-Realm").total >= 1, "counts lost")
elseif phase == 3 then
	M.PSS_AddIgnore("Flood-Realm", true)
	for i = 1, 205 do whisper("flood " .. i, "Flood-Realm") end
	check(not loaded("PourSocialScore_Logging"), "loaded inside the chat filter")
	H.RunTimers()
	check(loaded("PourSocialScore_Logging"), "200 waiting lines did not load Logging")
	check(History.Waiting() == 0, "outbox not emptied after the load")
	local n = 0
	for _, h in ipairs(History.Log()) do if h.o == History.PlayerKey("Flood-Realm") then n = n + 1 end end
	check(n == 205, "flood lines in the log: " .. n)
end

if not fail then print("PASS on demand " .. phase) end
