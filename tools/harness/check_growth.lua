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
-- one player never removed (the keep fills) and a
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
		keep = History.Loaded() and History.KeepSize() or 0,
	}
end
local first, last = sizes[3], sizes[DAYS]
for _, k in ipairs({ "recent", "owners", "session", "outbox", "log" }) do
	print(("growth: %-8s day 3 %6d   day %d %6d"):format(k, first[k], DAYS, last[k]))
	check(last[k] <= first[k] * 1.1 + 5, k .. " grows: " .. first[k] .. " -> " .. last[k])
end
check(last.log <= History.Cap(), "log over the cap")
-- the keep (3.2): every person's lines, at most History.KEEP a person (20)
-- and History.KEEP_TOTAL (2000, 5 % over before a trim) in all
local lines, people = History.KeepSize()
local per = 0
for _, n in pairs(History.KEEP) do per = per + n end
print(("growth: keep     %d lines for %d people (at most %d each)"):format(lines, people, per))
check(lines <= people * per, "keep over its per-person limit")
local most = 0
for day = 1, DAYS do most = math.max(most, sizes[day].keep) end
check(most <= History.KEEP_TOTAL * 1.05, "keep over its total: " .. most)
-- past the total the oldest lines go, whoever they belong to: 2500 more
-- people with one whisper each, one minute apart
for k = 1, 2500 do
	local h = History.NewEntry("whisper", "CHAT_MSG_WHISPER", "one " .. k)
	H.Advance(60)
	h.ts = GetServerTime()
	History.Add(("p:capped%04d"):format(k), nil, h)
end
lines = History.KeepSize()
print(("growth: keep     %d lines after 2500 more people"):format(lines))
check(lines >= History.KEEP_TOTAL and lines <= History.KEEP_TOTAL * 1.05, "keep total " .. lines)
local keep = History.Keep()
check(keep["p:capped2500"] ~= nil, "newest line dropped")
check(keep["p:capped0001"] == nil, "oldest line kept")
check(keep[History.PlayerKey("Forever-Realm")] == nil, "older person's lines kept past the total")
check(last.log == 0, "a person's line in the log: " .. last.log)
check(last.owners <= 80, "recent owners " .. last.owners)
if not fail then print("PASS growth") end
