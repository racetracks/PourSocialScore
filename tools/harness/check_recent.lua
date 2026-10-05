-- Recent counts (3.2): each owner's blocks this session and in the last 24
-- hours, kept in PourSocialScoreDB without loading PourSocialScore_Logging.
--   PSS_PHASE=1 : login. Blocks of a player, a guild member (and its guild)
--                 and a chat filter are counted; 10-minute slots older than
--                 24 hours drop out; at most 144 slots per owner; a reset
--                 forgets them; lookups are cheap. Logout.
--   PSS_PHASE=2 : a /reload (PSS_RELOAD=1): the session and the day stay.
--   PSS_PHASE=3 : a new login: the session starts again, the day stays.
local phase = tonumber(os.getenv("PSS_PHASE") or "1")
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL recent " .. phase .. ": " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

local lineID = 81000 + phase * 1000
local function whisper(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg or "spam", author, "", "", "", "", 0, 0, "", 0, lineID, nil) == true
end
local function trade(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_CHANNEL", msg, author, "", "2. Trade", "", "", 2, 2, "Trade", 0, lineID, nil) == true
end
local P = "Recent-Realm"
local function pkey() return History.PlayerKey(P) end
local GK = M.PSS_NormalizeGuild and M.PSS_NormalizeGuild("Recent Guild")
local function rc(owner) return History.RecentCounts(owner) end

if phase == 1 then
	check(rawget(PourSocialScoreDB, "session") == nil, "session table before any block")
	local start = History.SessionStart()
	check(start == GetServerTime(), "session start " .. start)
	M.PSS_AddIgnore(P, true)
	for _ = 1, 3 do check(whisper(P), "whisper not blocked") end
	local s, d = rc(pkey())
	check(s == 3 and d == 3, ("player session/day %d/%d"):format(s, d))
	-- a line from before the session counts on the day, not the session
	History.CountRecent(pkey(), start - 60)
	s, d = rc(pkey())
	check(s == 3 and d == 4, ("older line %d/%d"):format(s, d))
	History.CountRecent(pkey(), nil)	-- (back to 4 / 4 for the rest)
	check(not loaded("PourSocialScore_Logging"), "recent counts loaded Logging")

	-- 23 h 50 later one more; 20 minutes after that the first three are older than a day
	H.Advance(23 * 3600 + 50 * 60)
	check(whisper(P), "late whisper not blocked")
	s, d = rc(pkey())
	check(s == 5 and d == 6, ("before the day ends %d/%d"):format(s, d))
	H.Advance(20 * 60)
	s, d = rc(pkey())
	check(s == 5 and d == 1, ("after the day %d/%d"):format(s, d))

	-- at most a day of slots: one block every 10 minutes for 25 hours
	-- (150 lines: under the 200 that make Logging load by itself)
	for _ = 1, 150 do
		whisper(P)
		H.Advance(600)
	end
	s, d = rc(pkey())
	-- the day's slots hold exactly the day total
	local r = rawget(PourSocialScoreDB, "recent")
	local slots, sum = 0, 0
	for k, t in pairs(r) do
		if type(k) == "number" then
			check(k >= 1 and k <= History.DAY_SLOTS, "slot index " .. k)
			slots = slots + 1
			for _, owners in pairs(t) do sum = sum + (owners[pkey()] or 0) end
		end
	end
	check(slots <= History.DAY_SLOTS and sum == d and d >= 143 and d <= 144, ("slots %d sum %d day %d"):format(slots, sum, d))
	-- by 10 minutes and type, newest first: whispers, one a slot
	local list = History.RecentSlots(pkey())
	local n, ordered, typed = 0, true, true
	for i, x in ipairs(list) do
		n = n + x.n
		if x.cat ~= "whisper" then typed = false end
		if i > 1 and x.ts > list[i - 1].ts then ordered = false end
	end
	check(n == d and ordered and typed and list[1].ts % History.SLOT == 0, ("slots list %d of %d"):format(n, d))
	check(s == 5 + 150, "session " .. s)

	-- a guild member: counted on the member and on the guild
	M.PSS_AddGuild("Recent Guild")
	M.PSS_UpdateGuildMember("Recent Guild", "Gmember-Realm1")
	H.RunTimers()
	check(whisper("Gmember-Realm1"), "member whisper not blocked")
	check(whisper("Gmember-Realm1"), "member whisper not blocked")
	local gs, gd = rc(History.GuildKey(GK))
	check(gs == 2 and gd == 2, ("guild %d/%d"):format(gs, gd))
	local m = M.PSS_FindGuildMember and M.PSS_FindGuildMember(GK, "Gmember-Realm1")

	-- a chat filter (Trade)
	local f = M.PSS_AddCustomFilter("Recent spam", "[word=recentspam]", true)
	check(trade("Seller-Realm1", "recentspam here"), "Trade line not blocked")
	local fs, fd = rc(M.PSS_FilterOwnerKey(f))
	check(fs == 1 and fd == 1, ("filter %d/%d"):format(fs, fd))
	M.PSS_ResetFilterCount(f)
	fs, fd = rc(M.PSS_FilterOwnerKey(f))
	check(fs == 0 and fd == 0, "Reset Count kept the recent counts")
	check(trade("Seller-Realm1", "recentspam again"), "Trade line not blocked")

	-- lookups: one index each
	local t0 = os.clock()
	for _ = 1, 100000 do rc(pkey()) end
	local per = (os.clock() - t0) / 100000 * 1e6
	print(("recent: lookup %.2f us"):format(per))
	check(per < 20, "lookup too slow")
	-- where the lines are, without loading Logging: only the waiting ones
	local inLog, kept, waiting = History.Where(pkey())
	-- (a person's waiting lines follow the keep's limits: 10 whispers)
	check(inLog == nil and kept == nil and waiting == 10, ("where %s %s %s"):format(tostring(inLog), tostring(kept), tostring(waiting)))
	check(not loaded("PourSocialScore_Logging"), "Logging loaded in phase 1")

	-- the saved size: owners with a block in the last day only
	local owners = 0
	for _ in pairs(rawget(PourSocialScoreDB, "recent").day) do owners = owners + 1 end
	check(owners == 4, "recent owners " .. owners)
	-- a busy owner: a block in every slot of the day
	local now = GetServerTime()
	for k = 0, History.DAY_SLOTS - 1 do History.CountRecent("x:full", now - k * History.SLOT) end
	local _, fd = rc("x:full")
	check(fd == History.DAY_SLOTS, "full owner day " .. fd)
	History.ForgetRecent("x:full")
	check(select(2, rc("x:full")) == 0, "full owner not forgotten")
	-- many owners blocked once (one spammer each)
	collectgarbage("collect")
	local before = collectgarbage("count")
	for k = 1, 1000 do History.CountRecent("x:one" .. k, now) end
	collectgarbage("collect")
	print(("recent: 1000 owners blocked once (with their session counts and names) %.2f KB"):format(collectgarbage("count") - before))
	for k = 1, 1000 do History.ForgetRecent("x:one" .. k) end
elseif phase == 2 or phase == 3 then
	local s, d = rc(pkey())
	if phase == 2 then
		check(s == 155 and d >= 142, ("reload lost counts %d/%d"):format(s, d))
		check(History.SessionStart() == 1790000000, "a /reload moved the session start: " .. History.SessionStart())
	else
		check(s == 0 and d >= 142, ("new login: session %d day %d"):format(s, d))
		check(History.SessionStart() == GetServerTime(), "a login did not start the session now")
		-- a reset forgets the player's recent counts (Reset Block History)
		-- once Logging is loaded: kept (a person's lines never join the log)
		M.PSS_LoadLogging()
		local inLog, kept, waiting = History.Where(pkey())
		check(inLog == 0 and kept == 10 and waiting == 0, ("where after loading %s %s %s"):format(tostring(inLog), tostring(kept), tostring(waiting)))
		M.PSS_ResetPlayerBlockHistory(P)
		s, d = rc(pkey())
		check(s == 0 and d == 0, ("reset kept %d/%d"):format(s, d))
		M.PSS_ResetGuildBlockHistory(GK)
		s, d = rc(History.GuildKey(GK))
		check(s == 0 and d == 0, "guild reset kept the guild's counts")
	end
	check(loaded("PourSocialScore_Logging") == (phase == 3), "Logging loaded state")
end
if not fail then print("PASS recent " .. phase) end
