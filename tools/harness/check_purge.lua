-- Purge by owner (core uplift S1, 3.4.1.49), as a run.lua script on a save
-- whose login does not load Logging (validate_all.sh "== purge"):
--   PSS_PHASE=1 : list Gone-Realm, Again-Realm, Stay-Realm and a guild
--                 member Member-Realm; block each; load Logging so the
--                 lines are saved with it. Logout.
--   PSS_PHASE=2 : Logging not loaded. Gone-Realm blocks again (a waiting
--                 line); remove Gone-Realm and Member-Realm; remove
--                 Again-Realm, list them again and block them once more.
--                 Logging stays unloaded, the waiting lines of the removed
--                 go at once, and their owners are marked in
--                 PourSocialScoreDB.purge. Logout.
--   PSS_PHASE=3 : the marks were saved; loading Logging applies them:
--                 Gone-Realm and Member-Realm have no lines, Again-Realm
--                 only the line after they were listed again, Stay-Realm
--                 all of theirs; the marks are gone.
--   PSS_PHASE=4 : (on phase 1's save) the marks are full (PURGE_CAP):
--                 a removal loads Logging and clears at once.
local phase = tonumber(os.getenv("PSS_PHASE") or "1")
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL purge " .. phase .. ": " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

local lineID = 80000 + phase * 1000
local function whisper(msg, author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg, author, "", "", "", "", 0, 0, "", 0, lineID, nil)
end
local function owners(name) return History.PlayerKey(name) end
local MEMBER = "g:" .. M.PSS_CanonPlayer("Member-Realm")
local function waiting(o)
	local n = 0
	for _, e in ipairs(rawget(PourSocialScoreDB, "outbox") or {}) do if e.o == o then n = n + 1 end end
	return n
end
local function messages(o)
	local out = {}
	for _, h in ipairs(History.For(o)) do out[#out + 1] = h.message end
	return table.concat(out, ",")
end
local function remove(name)
	local pos = M.PSS_PlayerPosition(name)
	check(pos > 0, name .. " not listed")
	M.PSS_RemovePlayerAt(pos)
	check(M.PSS_PlayerPosition(name) == 0, name .. " not removed")
end

check(not loaded("PourSocialScore_Logging"), "Logging loaded at login")

if phase == 1 then
	for _, n in ipairs({ "Gone-Realm", "Again-Realm", "Stay-Realm" }) do
		M.PSS_AddIgnore(n, true)
		check(whisper("old " .. n, n), n .. " not blocked")
	end
	M.PSS_AddGuild("Purge Guild")
	check(M.PSS_UpdateGuildMember("Purge Guild", "Member-Realm") ~= nil, "member not captured")
	check(whisper("old Member-Realm", "Member-Realm"), "member not blocked")
	check(History.CountFor(MEMBER) == 1, "member line: " .. History.CountFor(MEMBER))
	check(loaded("PourSocialScore_Logging"), "Logging not loaded")
	for _, n in ipairs({ "Gone-Realm", "Again-Realm", "Stay-Realm" }) do
		check(History.CountFor(owners(n)) == 1, n .. " lines: " .. History.CountFor(owners(n)))
	end
elseif phase == 2 then
	check(whisper("waiting Gone-Realm", "Gone-Realm"), "Gone-Realm not blocked")
	check(waiting(owners("Gone-Realm")) == 1, "Gone-Realm line not waiting")
	remove("Gone-Realm")
	check(waiting(owners("Gone-Realm")) == 0, "Gone-Realm waiting line kept")
	check(M.PSS_RemoveGuildMember("Purge Guild", "Member-Realm"), "member not removed")
	remove("Again-Realm")
	M.PSS_AddIgnore("Again-Realm", true)
	check(whisper("new Again-Realm", "Again-Realm"), "Again-Realm not blocked again")
	check(waiting(owners("Again-Realm")) == 1, "Again-Realm new line not waiting")
	check(not loaded("PourSocialScore_Logging"), "a removal loaded Logging")
	local purge = rawget(PourSocialScoreDB, "purge")
	check(type(purge) == "table", "no purge marks")
	purge = purge or {}
	check(purge[owners("Gone-Realm")] and purge[MEMBER] and purge[owners("Again-Realm")], "marks missing")
	check(not purge[owners("Stay-Realm")], "Stay-Realm marked")
elseif phase == 3 then
	local purge = rawget(PourSocialScoreDB, "purge")
	check(type(purge) == "table" and purge[owners("Gone-Realm")], "marks not saved")
	check(messages(owners("Gone-Realm")) == "", "Gone-Realm lines: " .. messages(owners("Gone-Realm")))
	check(loaded("PourSocialScore_Logging"), "History.For did not load Logging")
	check(rawget(PourSocialScoreDB, "purge") == nil, "marks not cleared")
	check(messages(MEMBER) == "", "Member-Realm lines: " .. messages(MEMBER))
	check(messages(owners("Again-Realm")) == "new Again-Realm", "Again-Realm lines: " .. messages(owners("Again-Realm")))
	check(messages(owners("Stay-Realm")) == "old Stay-Realm", "Stay-Realm lines: " .. messages(owners("Stay-Realm")))
	check(M.PSS_GetPlayerBlockCounts("Stay-Realm").total == 1, "Stay-Realm count changed")
elseif phase == 4 then
	local purge = {}
	for i = 1, History.PURGE_CAP do purge["p:filler" .. i .. "-realm"] = true end
	rawset(PourSocialScoreDB, "purge", purge)
	remove("Gone-Realm")
	check(loaded("PourSocialScore_Logging"), "a full purge did not load Logging")
	check(rawget(PourSocialScoreDB, "purge") == nil, "marks not applied")
	check(messages(owners("Gone-Realm")) == "", "Gone-Realm lines: " .. messages(owners("Gone-Realm")))
	check(messages(owners("Stay-Realm")) == "old Stay-Realm", "Stay-Realm lines: " .. messages(owners("Stay-Realm")))
end

if not fail then print("PASS purge " .. phase) end
