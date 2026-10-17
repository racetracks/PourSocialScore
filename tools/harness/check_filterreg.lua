-- The chat filter's registration (3.7.0.110, W-8; run by filterreg_phases.sh as a run.lua script). The author's
-- /pssguild chat read "ours: NO" on every event with Social Filtering on: the filter was not in the client's lists.
-- Each phase prints "PASS filterreg <phase>" or "FAIL filterreg: <phase>: <what>". The client's list shape
-- (functions or { func = fn } entries) is PSS_FILTER_SHAPE, both are run; Camelot with PSS_CAMELOT=1.
--   base regfail regdrop idem startfault outcome
local phase = os.getenv("PSS_PHASE") or "base"
local fail = false
local function check(ok, msg) if not ok then print("FAIL filterreg: " .. phase .. ": " .. msg) fail = true end return ok end
local realPrint = print
local EV = assert(M.PSS__CoreTest.events, "M.PSS__CoreTest.events")
local lineID = 80000

-- the client's own view: every function in the event's list (either shape), read as the client hands it back
local function listFns(ev)
	local out = {}
	for _, f in pairs(ChatFrameUtil.GetMessageEventFilters(ev) or {}) do out[#out + 1] = type(f) == "table" and f.func or f end
	return out
end
local function copies(ev)
	local n = 0
	for _, f in ipairs(listFns(ev)) do if f == M.PSS_CoreFilter then n = n + 1 end end
	return n
end
local function allHeld(want)
	local bad = {}
	for ev in pairs(EV) do if copies(ev) ~= (want or 1) then bad[#bad + 1] = ev .. "=" .. copies(ev) end end
	table.sort(bad)
	return #bad == 0, table.concat(bad, ",")
end
-- a line as the client delivers it: every filter in the list, hidden when one says so
local function deliver(ev, author, msg)
	lineID = lineID + 1
	for _, f in ipairs(listFns(ev)) do
		if f(nil, ev, msg, author, "", "", "", 0, 0, "", 0, lineID, "Player-1-" .. author) == true then return true end
	end
	return false
end
local function say(cmd, rest)
	local lines = {}
	local realChat = M.ChatMsg
	local function take(s) lines[#lines + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	print = take
	M.ChatMsg = take
	local ok, err = pcall(SlashCmdList[cmd], rest)
	print = realPrint
	M.ChatMsg = realChat
	check(ok, cmd .. " " .. rest .. " error: " .. tostring(err))
	return table.concat(lines, "\n")
end
local function stats() return M.PSS_CoreStats.hidden, M.PSS_CoreStats.checked end

if phase == "base" then
	check(allHeld())
	local out = say("PSSGUILD", "chat")
	check(out:find("started: yes", 1, true), "/pssguild chat has no 'started: yes' line:\n" .. out)
	local n = 0 for _ in out:gmatch("ours: yes") do n = n + 1 end
	check(n == 4, "ours: yes on " .. n .. " of 4 events:\n" .. out)

elseif phase == "regfail" then
	-- the client refused one add (PSS_FILTER_FAIL=2): no error stops the start, the failure is named, nothing else is skipped
	check(M.PSS_FilterFaults and #M.PSS_FilterFaults >= 1, "the failed add is not recorded")
	check(M.PSS_FilterFaults and tostring(M.PSS_FilterFaults[1]):find("registration", 1, true), "the fault does not say registration: " .. tostring(M.PSS_FilterFaults and M.PSS_FilterFaults[1]))
	check(H.Listeners("PARTY_INVITE_REQUEST") >= 1, "the invite event is not registered after a failed add")
	check(H.Listeners("DUEL_REQUESTED") >= 1, "the duel event is not registered after a failed add")
	local ok, what = allHeld()
	check(ok, "the add that failed was not retried: " .. what)
	local out = say("PSSGUILD", "chat")
	check(out:find("started: yes", 1, true), "no 'started: yes':\n" .. out)

elseif phase == "regdrop" then
	-- another chat addon rebuilt the lists at its own PLAYER_LOGIN (PSS_CHAT_ADDON=1): ours is back once the world is up
	local ok, what = allHeld()
	check(ok, "ours is not back after the chat addon's rebuild: " .. what)
	-- and dropped again later: /pssguild chat re-adds it, reads yes, says so
	H.DropFilters()
	check(copies("CHAT_MSG_WHISPER") == 0, "stub did not drop")
	local out = say("PSSGUILD", "chat")
	check(out:find("re-added", 1, true), "/pssguild chat does not say re-added:\n" .. out)
	check(allHeld(), "not held after /pssguild chat")
	local n = 0 for _ in out:gmatch("ours: yes") do n = n + 1 end
	check(n == 4, "ours: yes on " .. n .. " of 4 events:\n" .. out)
	-- looked at and not missing: nothing is added, nothing is said
	out = say("PSSGUILD", "chat")
	check(not out:find("re-added", 1, true), "re-added said with nothing missing")

elseif phase == "idem" then
	-- called again and again: one copy per event, one block for one whisper
	for _ = 1, 5 do M.PSS_EnsureFilter() end
	local ok, what = allHeld(1)
	check(ok, "not exactly one copy per event after 5 calls: " .. what)
	say("PSS", "add Spammer-Testrealm")
	local h0 = stats()
	check(deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "buy gold"), "listed whisper not hidden")
	local h1 = stats()
	check(h1 - h0 == 1, "one whisper counted " .. (h1 - h0) .. " times")

elseif phase == "startfault" then
	-- PSS_FAULT=start:<stage>: a stage that throws is named and never skips the filter
	local stage = (os.getenv("PSS_FAULT") or ""):match("^start:(.+)$")
	check(stage, "no stage fault set")
	check(M.PSS_StartFaults and #M.PSS_StartFaults == 1, "faults noted: " .. tostring(M.PSS_StartFaults and #M.PSS_StartFaults))
	check(M.PSS_StartFaults and tostring(M.PSS_StartFaults[1]):find(stage, 1, true), "the fault does not name " .. stage .. ": " .. tostring(M.PSS_StartFaults and M.PSS_StartFaults[1]))
	local critical = stage == "expand" or stage == "upgradefields"
	if not critical then
		check(allHeld(), "a failed '" .. stage .. "' stage left the filter unregistered")
		say("PSS", "add Spammer-Testrealm")
		check(deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "buy gold"), "a failed '" .. stage .. "' stage stopped the filter from blocking")
	else
		-- the lists are not readable: loud, and the filter does not decide a line
		check(allHeld(), "the filter is registered even when the lists are not ready (the start-up registers at ADDON_LOADED)")
		say("PSS", "add Spammer-Testrealm")
		check(not deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "buy gold"), "a half-started filter decided a line")
		local out = say("PSSGUILD", "chat")
		check(out:find("started: yes", 1, true), "registration is not shown as started:\n" .. out)
		check(out:find(stage, 1, true), "the faulted stage is not shown by /pssguild chat:\n" .. out)
	end

elseif phase == "outcome" then
	-- the drawn result, through the client's own list: a listed person, a word rule and a guild rule, each once
	local h0
	say("PSS", "add Spammer-Testrealm")
	h0 = stats()
	check(deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "hello"), "listed person's whisper shown")
	check(select(1, stats()) - h0 == 1, "person block not counted once")
	M.PSS_AddCustomFilter("Zeta", "[word=zetaspam]", true)
	H.RunTimers()
	h0 = stats()
	check(deliver("CHAT_MSG_SAY", "Stranger-Testrealm", "buy zetaspam now"), "word rule line shown")
	check(select(1, stats()) - h0 == 1, "word block not counted once")
	check(not deliver("CHAT_MSG_SAY", "Stranger-Testrealm", "hello there"), "an innocent line was hidden")
	M.PSS_SetManagedGroupActive("olympus", true)
	local db = PourSocialScoreDB
	local gkey
	for k, g in pairs(db.guildData) do if type(g) == "table" and g.managed == "olympus" then gkey = k break end end
	if gkey then
		local g = db.guildData[gkey]
		g.members = g.members or {}
		g.members["olyfound-realm"] = { name = "Olyfound-Realm", guild = g.name, whenBlocked = "01 Oct 2026 10:00:00", _playerKey = "olyfound-realm" }
		if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
		H.RunTimers()
		h0 = stats()
		check(deliver("CHAT_MSG_WHISPER", "Olyfound-Realm", "join olympus"), "guild rule line shown")
		check(select(1, stats()) - h0 == 1, "guild block not counted once")
	else
		print("NOTE filterreg: no shipped guild rows on this run; the guild rule line was not driven")
	end
end

if not fail then print("PASS filterreg " .. phase) end
