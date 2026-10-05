-- Saved data stays bounded (3.2): 30 days of blocks from ever new players,
-- guild members and chat lines, with rules added and removed, and a login
-- every day. After each day the sizes of the recent counts, the session,
-- the waiting lines, the log and the keep are taken; none may keep growing.
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_growth.lua
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL growth: " .. msg) fail = true end end

local function size(t, seen)
	if type(t) ~= "table" then return 0 end
	seen = seen or {}
	if seen[t] then return 0 end
	seen[t] = true
	local n = 0
	for k, v in pairs(t) do
		n = n + 1
		if type(v) == "table" then n = n + size(v, seen) end
	end
	return n
end
local function keys(t) local n = 0 for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end return n end

local lineID = 500000
local function whisper(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg, author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
end

local db = PourSocialScoreDB
local sizes = {}
-- one player never removed (the log reaches its cap, the keep fills) and a
-- guild rule that gets 20 new members a day
M.PSS_AddIgnore("Forever-Realm", true)
M.PSS_AddGuild("Growth Guild")
local DAYS = 30
for day = 1, DAYS do
	-- a login each day
	History.StartSession(true)
	-- 40 new players blocked 6 times over the day, the oldest 40 removed
	for k = 1, 40 do M.PSS_AddIgnore(("Spam%d%03d-Realm"):format(day, k), true) end
	for k = 1, 20 do M.PSS_UpdateGuildMember("Growth Guild", ("Gm%d%03d-Realm"):format(day, k)) end
	for step = 1, 144 do
		for k = 1, 40, 7 do whisper(("Spam%d%03d-Realm"):format(day, k), "spam " .. step) end
		for k = 1, 20, 4 do whisper(("Gm%d%03d-Realm"):format(day, k), "guild spam " .. step) end
		whisper("Forever-Realm", "forever " .. step)
		H.Advance(600)
	end
	H.RunTimers()
	if day > 1 then
		for k = 1, 40 do
			local pos = M.PSS_PlayerPosition(("Spam%d%03d-Realm"):format(day - 1, k))
			if pos > 0 then M.PSS_RemovePlayerAt(pos) end
		end
	end
	local recent = rawget(db, "recent")
	sizes[day] = {
		recent = size(recent), owners = recent and keys(recent.day) or 0,
		session = keys(rawget(db, "session")),
		outbox = #(rawget(db, "outbox") or {}),
		log = History.Loaded() and #History.Log() or 0,
	}
end
local first, last = sizes[3], sizes[DAYS]
for _, k in ipairs({ "recent", "owners", "session", "outbox", "log" }) do
	print(("growth: %-8s day 3 %6d   day %d %6d"):format(k, first[k], DAYS, last[k]))
	check(last[k] <= first[k] * 1.1 + 5, k .. " grows: " .. first[k] .. " -> " .. last[k])
end
check(last.log <= History.Cap(), "log over the cap")
-- the keep: at most History.KEEP lines a person (25), so it grows with the
-- number of blocked people still listed, not with time
local lines, people = History.KeepSize()
local per = 0
for _, n in pairs(History.KEEP) do per = per + n end
print(("growth: keep     %d lines for %d people (at most %d each)"):format(lines, people, per))
check(lines <= people * per, "keep over its per-person limit")
check(last.owners <= 80, "recent owners " .. last.owners)
check(last.log >= History.Cap() * 0.9, "log never reached its cap: " .. last.log)
if not fail then print("PASS growth") end
