-- Per-person block history kept past the 2,000 line log (2.0.37; every line
-- goes in the log first again since 3.2.0-dev007), run after
-- validate.sh phases 2 and 3 on a save that had overflow.lua applied.
--   PSS_PHASE=4 : the overflow lines were trimmed at the upgrade; Grunt keeps
--                 his newest old lines past his log lines (no emotes: world
--                 chat is not kept once it leaves the log). Then Spammer-Realm gets 12 whispers, 7 emotes,
--                 7 party and 7 guild invites, and 2,200 chat filter lines
--                 push every person out of the log.
--                 Counts must go up by the blocks only, never by kept lines.
--   PSS_PHASE=5 : after a reload: the kept lines are still there, a tidy-up
--                 drops lines of things that are gone, Reset clears the keep.
local phase = tonumber(os.getenv("PSS_PHASE") or "4")
local db = PourSocialScoreDB
local History = M.PSS_History
local fails = 0
local function fail(s) print("  FAIL " .. s); fails = fails + 1 end
local function eq(what, got, want)
	if got ~= want then fail(("%s: %s, expected %s"):format(what, tostring(got), tostring(want))) end
end

local lineID = 90000 + phase * 10000
local function chat(event, msg, author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, event, msg, author, "", "", "", "", 0,
		event == "CHAT_MSG_CHANNEL" and 2 or 0, event == "CHAT_MSG_CHANNEL" and "Trade" or "", 0, lineID, nil)
end

-- kind -> messages (newest first) of a person's history view
local function view(list)
	local by = { text = {}, emote = {}, party = {}, guild = {} }
	for _, h in ipairs(list) do
		local t = by[History.KeepKind(h) or (h.channel == "Emote" and "emote") or "text"]
		t[#t + 1] = h.message
	end
	return by
end
local function inLog()
	local s = {}
	for _, h in ipairs(History.Log()) do s[h] = true end
	return s
end
-- every kept line is a packed string (3.2), and none is also in the log
local function checkNoCopies()
	local logged = {}
	for _, h in ipairs(History.Log()) do
		if History.KeepsOwner(h.o) and History.PackLine(h) then logged[h.o .. History.PackLine(h)] = true end
	end
	for o, list in pairs(History.Keep()) do
		for _, s in ipairs(list) do
			if type(s) ~= "string" then fail("kept line not packed (" .. o .. ")") break end
			if logged[o .. s] then fail("a line both in the log and kept (" .. o .. ")") break end
		end
	end
end
local function expectList(what, got, prefix, from, to)
	local want = {}
	for n = from, to, -1 do want[#want + 1] = prefix .. n end
	eq(what .. " lines", #got, #want)
	for i = 1, math.min(#got, #want) do eq(what .. " line " .. i, got[i], want[i]) end
end

-- this session / last 24 hours as both windows count them (History.Recent*,
-- 3.3.0-dev002: PSS_BlockStats is gone)
local PREFIX = { player = "p:", guild = "G:", filter = "f:" }
local S = {
	Session = function(src) return { total = (M.PSS_History.RecentTotals(PREFIX[src])) } end,
	Last24 = function(src) return { total = select(2, M.PSS_History.RecentTotals(PREFIX[src])) } end,
}
local function counts()
	local p = M.PSS_GetPlayerBlockCounts("Spammer-Realm")
	local s, l = S.Session("player"), S.Last24("player")
	local gc = M.PSS_GetGuildBlockCounts()
	return { p = p.total, ps = s.total or 0, pl = l.total or 0, g = gc.total, gl = S.Last24("guild").total or 0,
		f = db.filterTotal or 0, fl = S.Last24("filter").total or 0 }
end

if phase == 4 then
	-- Grunt: 4 chat lines in the log (make_data 3, check_stats 1), so 6 old
	-- ones are kept; 5 of each other kind. Filler (2,000+ lines) keeps none.
	local g = view(M.PSS_GetMemberBlockHistory({ name = "Grunt-Realm", _playerKey = "grunt-realm" }))
	eq("Grunt chat lines", #g.text, 10)
	eq("Grunt emotes", #g.emote, 0)
	expectList("Grunt party invites", g.party, "old party ", 8, 4)
	expectList("Grunt guild invites", g.guild, "old guild ", 8, 4)
	-- his 4 log lines stay in the log (3.2.0-dev007), the 6 older are kept
	local kept = view(History.KeptLines("g:grunt-realm"))
	eq("Grunt kept chat lines", #kept.text, 6)
	local logged = 0
	for _, h in ipairs(History.Log()) do if h.o == "g:grunt-realm" then logged = logged + 1 end end
	eq("Grunt lines in the log", logged, 4)
	eq("Filler kept lines at most 20", #(History.Keep()["g:filler-realm"] or {}) <= 20, true)
	eq("log within the cap", #History.Log() <= History.Cap(), true)
	checkNoCopies()

	-- new blocks for Spammer (listed player)
	local before = counts()
	local blocked = 0
	for n = 1, 12 do if chat("CHAT_MSG_WHISPER", "spam text " .. n, "Spammer-Realm") then blocked = blocked + 1 end end
	for n = 1, 7 do if chat("CHAT_MSG_EMOTE", "spam emote " .. n, "Spammer-Realm") then blocked = blocked + 1 end end
	for n = 1, 7 do M.PSS_RecordPlayerBlock("Spammer-Realm", nil, "", "party"); blocked = blocked + 1 end
	for n = 1, 7 do M.PSS_RecordPlayerBlock("Spammer-Realm", nil, "", "guild"); blocked = blocked + 1 end
	H.RunTimers()
	eq("Spammer lines blocked", blocked, 33)
	local mid = counts()
	eq("player total after 33 blocks", mid.p, before.p + 33)
	eq("player session after 33 blocks", mid.ps, before.ps + 33)
	eq("player 24h after 33 blocks", mid.pl, before.pl + 33)

	-- 2,200 chat filter lines: every person's lines leave the log
	for n = 1, 2200 do
		if not chat("CHAT_MSG_CHANNEL", "buygold flood " .. n, "Random-Realm") then fail("flood line not blocked") break end
	end
	H.RunTimers()
	local after = counts()
	eq("player total after flood", after.p, mid.p)
	eq("player session after flood", after.ps, mid.ps)
	eq("player 24h after flood", after.pl, mid.pl)
	eq("guild total after flood", after.g, mid.g)
	eq("guild 24h after flood", after.gl, mid.gl)
	eq("filter total after flood", after.f, mid.f + 2200)
	eq("filter 24h after flood", after.fl, mid.fl + 2200)
	for _, h in ipairs(History.Log()) do
		if History.KeepsOwner(h.o) then fail("a person's line is still in the log") break end
	end
	local s = view(M.PSS_GetPlayerBlockHistory("Spammer-Realm"))
	expectList("Spammer chat lines", s.text, "spam text ", 12, 3)
	eq("Spammer emotes", #s.emote, 0)
	eq("Spammer party invites", #s.party, 5)
	eq("Spammer guild invites", #s.guild, 5)
	local gv = view(M.PSS_GetMemberBlockHistory({ name = "Grunt-Realm", _playerKey = "grunt-realm" }))
	eq("Grunt lines after flood", #gv.text + #gv.emote + #gv.party + #gv.guild, 20)
	eq("Grunt newest chat line kept", gv.text[1], "again")
	eq("player history count", History.CountFor(History.PlayerKey("Spammer-Realm")), 20)
	checkNoCopies()
	-- for phase 5
	db._testCounts = counts()
else
	local want = db._testCounts
	db._testCounts = nil
	local now = counts()
	eq("player total after reload", now.p, want.p)
	eq("guild total after reload", now.g, want.g)
	eq("filter total after reload", now.f, want.f)
	local s = view(M.PSS_GetPlayerBlockHistory("Spammer-Realm"))
	expectList("Spammer chat lines after reload", s.text, "spam text ", 12, 3)
	eq("Spammer emotes after reload", #s.emote, 0)
	eq("Spammer invites after reload", #s.party + #s.guild, 10)
	checkNoCopies()

	-- tidy-up: lines of a player, member and filter that are gone, and a
	-- rule tag of a removed rule
	local log = History.Log()
	local keep = History.Keep()
	keep["p:ghost-realm"] = { History.PackLine(History.NewEntry("whisper", "CHAT_MSG_WHISPER", "ghost", nil, "Ghost-Realm")) }
	local function add(o, gk)
		local h = History.NewEntry("whisper", "CHAT_MSG_WHISPER", "gone", nil, "Gone-Realm")
		h.o, h.gk = o, gk
		log[#log + 1] = h
	end
	add("p:gone-realm")
	add("g:nobody-realm", "no such guild")
	add("f:PSS9999")
	local tagged = log[#log - 4]
	tagged.r = "PSS9998"
	-- a tag of a form this version never makes (a newer version's rule id) stays (U3)
	local newer = log[#log - 5]
	newer.r = 12
	local n = #log
	local removed = M.PSS_TidyBlockHistory()
	eq("lines tidied", removed, 4)
	eq("log after tidy", #log, n - 3)
	eq("ghost keep after tidy", History.Keep()["p:ghost-realm"], nil)
	eq("rule tag after tidy", tagged.r, nil)
	eq("newer rule tag after tidy", newer.r, 12)
	local after = counts()
	eq("player total after tidy", after.p, want.p)
	eq("filter total after tidy", after.f, want.f)
	eq("Spammer lines after tidy", History.CountFor(History.PlayerKey("Spammer-Realm")), 20)

	-- Reset Block History clears the kept lines too, counts go to 0
	M.PSS_ResetPlayerBlockHistory("Spammer-Realm")
	eq("Spammer keep after reset", History.Keep()[History.PlayerKey("Spammer-Realm")], nil)
	eq("Spammer lines after reset", History.CountFor(History.PlayerKey("Spammer-Realm")), 0)
end

print(fails == 0 and ("PASS phase " .. phase) or ("FAILED phase " .. phase .. ": " .. fails))
if fails > 0 then os.exit(1) end
