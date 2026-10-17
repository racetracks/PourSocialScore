-- The chat filter's registration and its diagnostics (3.7.0.110, W-8; run by filterreg_phases.sh as a run.lua
-- script). On Retail 12.x GetMessageEventFilters hands back a registry object (ProcessFilters, RemoveFilter,
-- AddFilter), not a list, so what PSS reports about registration must not read a list there. Each phase prints
-- "PASS filterreg <phase>" or "FAIL filterreg: <phase>: <what>". The client's answer is PSS_FILTER_SHAPE (unset =
-- the 12.x object; functions and entries are the older lists); Camelot with PSS_CAMELOT=1.
--   base regfail retry startfault outcome passwhy
local phase = os.getenv("PSS_PHASE") or "base"
local shape = os.getenv("PSS_FILTER_SHAPE") or "object"
local fail = false
local function check(ok, msg) if not ok then print("FAIL filterreg: " .. phase .. ": " .. msg) fail = true end return ok end
local realPrint = print
local EV = assert(M.PSS__CoreTest.events, "M.PSS__CoreTest.events")
local nEvents = 0
for _ in pairs(EV) do nEvents = nEvents + 1 end
local lineID = 80000

-- how many times our function was added for an event (the stub's own record)
local function copies(ev)
	local n = 0
	for _, f in ipairs(H.filters) do if f.event == ev and f.fn == M.PSS_CoreFilter then n = n + 1 end end
	return n
end
local function allOnce()
	local bad = {}
	for ev in pairs(EV) do if copies(ev) ~= 1 then bad[#bad + 1] = ev .. "=" .. copies(ev) end end
	table.sort(bad)
	return #bad == 0, table.concat(bad, ",")
end
-- a line as the client delivers it: the event's filters in turn, hidden when one says so
local function deliver(ev, author, msg)
	lineID = lineID + 1
	return H.ProcessChat(ev, msg, author, "", "", "", 0, 0, "", 0, lineID, "Player-1-" .. author)
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
local function count(text, pat) local n = 0 for _ in text:gmatch(pat) do n = n + 1 end return n end

if phase == "base" then
	check(allOnce())
	local out = say("PSSGUILD", "chat")
	check(out:find("added by PSS: " .. nEvents .. " of " .. nEvents .. " events", 1, true) and out:find("started: yes", 1, true), "registration is not reported as every event added:\n" .. out)
	check(not out:find("refused", 1, true), "refused shown with nothing refused:\n" .. out)
	if shape == "object" then
		-- 12.x: no list to read, so it never says NO and never claims yes
		check(count(out, "cannot be read on this client") == 4 and not out:find("list: NO", 1, true) and not out:find("list: yes", 1, true), "the 12.x object is read as a list:\n" .. out)
	else
		check(count(out, "in the client's list: yes") == 4, "the list shape is not read (" .. shape .. "):\n" .. out)
	end
	check(out:find("lines that reached our filter since login: 0", 1, true) and out:find("No line has reached our filter", 1, true), "no reached-count or warning at zero:\n" .. out)
	-- the object's methods are not counted as filters, whatever the old check did
	local held = M.PSS_FilterHeld("CHAT_MSG_WHISPER")
	if shape == "object" then check(held == nil, "PSS_FilterHeld reads the 12.x object as a list: " .. tostring(held))
	else check(held == true, "PSS_FilterHeld on shape " .. shape .. ": " .. tostring(held)) end

elseif phase == "regfail" then
	-- the client refused one add (PSS_FILTER_FAIL=2): no error stops the start, the failure is named, the one retry adds it
	check(M.PSS_FilterFaults and #M.PSS_FilterFaults == 1 and tostring(M.PSS_FilterFaults[1]):find("registration", 1, true), "the failed add is not recorded once: " .. tostring(M.PSS_FilterFaults and M.PSS_FilterFaults[1]))
	check(H.Listeners("PARTY_INVITE_REQUEST") >= 1 and H.Listeners("DUEL_REQUESTED") >= 1, "the game events are not registered after a failed add")
	local ok, what = allOnce()
	check(ok, "the refused add was not retried once, or a copy was doubled: " .. what)
	local out = say("PSSGUILD", "chat")
	check(out:find("added by PSS: " .. nEvents .. " of " .. nEvents .. " events", 1, true) and not out:find("refused", 1, true), "registration after the retry:\n" .. out)

elseif phase == "retry" then
	-- the retry reads no list and adds nothing that was added: five calls, one copy per event
	for _ = 1, 5 do M.PSS_RetryFilter() end
	local ok, what = allOnce()
	check(ok, "not exactly one copy per event after 5 retries: " .. what)

elseif phase == "startfault" then
	-- PSS_FAULT=start:<stage>: a stage that throws is named and never skips the filter
	local stage = (os.getenv("PSS_FAULT") or ""):match("^start:(.+)$")
	check(stage, "no stage fault set")
	check(M.PSS_StartFaults and #M.PSS_StartFaults == 1, "faults noted: " .. tostring(M.PSS_StartFaults and #M.PSS_StartFaults))
	check(M.PSS_StartFaults and tostring(M.PSS_StartFaults[1]):find(stage, 1, true), "the fault does not name " .. stage .. ": " .. tostring(M.PSS_StartFaults and M.PSS_StartFaults[1]))
	check(allOnce())
	say("PSS", "add Spammer-Testrealm")
	local critical = stage == "expand" or stage == "upgradefields"
	if not critical then
		check(deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "buy gold"), "a failed '" .. stage .. "' stage stopped the filter from blocking")
	else
		-- the lists are not ready: loud, and the filter does not decide a line, and says why
		check(not deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "buy gold"), "a half-started filter decided a line")
		local out = say("PSSGUILD", "chat")
		check(out:find(stage, 1, true), "the faulted stage is not shown by /pssguild chat:\n" .. out)
		check(out:find("has not finished starting", 1, true), "the pass reason does not say PSS has not finished starting:\n" .. out)
	end

elseif phase == "outcome" then
	-- the drawn result through the client's own dispatch: a listed person, a word rule and a guild rule, each once, and the counters
	say("PSS", "add Spammer-Testrealm")
	local h0 = M.PSS_CoreStats.hidden
	check(deliver("CHAT_MSG_WHISPER", "Spammer-Testrealm", "hello"), "listed person's whisper shown")
	check(M.PSS_CoreStats.hidden - h0 == 1, "person block not counted once")
	M.PSS_AddCustomFilter("Zeta", "[word=zetaspam]", true)
	H.RunTimers()
	h0 = M.PSS_CoreStats.hidden
	check(deliver("CHAT_MSG_SAY", "Stranger-Testrealm", "buy zetaspam now"), "word rule line shown")
	check(M.PSS_CoreStats.hidden - h0 == 1, "word block not counted once")
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
		h0 = M.PSS_CoreStats.hidden
		check(deliver("CHAT_MSG_WHISPER", "Olyfound-Realm", "join olympus"), "guild rule line shown")
		check(M.PSS_CoreStats.hidden - h0 == 1, "guild block not counted once")
	else
		print("NOTE filterreg: no shipped guild rows on this run; the guild rule line was not driven")
	end
	local out = say("PSSGUILD", "chat")
	local calls = tonumber(out:match("reached our filter since login: (%d+)"))
	check(calls and calls >= 4 and not out:find("No line has reached", 1, true), "/pssguild chat does not show the lines that reached the filter:\n" .. out)

elseif phase == "secretsweep" then
	-- 3.7.0.111 (W-8, CON01-R-009): every argument of the filter and of each game-event handler is made secret in turn
	-- (the stub's secret is a plain string the test names, so a wrong order cannot raise here; tools/check_secretorder.lua
	-- reads the source for that). Each returns without an error, nothing hidden or counted, one more "secret" line.
	say("PSS", "add Spammer-Testrealm")
	local secretOf = {}
	_G.issecretvalue = function(v) return v ~= nil and secretOf[v] == true end
	local S = M.PSS_CoreStats
	local names = { "msg", "author", "language", "channelString", "target", "flag", "zoneChannelID", "channelIndex",
		"channelBaseName", "languageID", "lineID", "guid" }
	local base = { "hello", "Spammer-Testrealm", "", "5. Trade", "", "", 0, 5, "Trade", 0, 0, "Player-1-Spammer" }
	for i, name in ipairs(names) do
		local args = {}
		for j = 1, 12 do args[j] = base[j] end
		lineID = lineID + 1
		args[11] = lineID
		local sv = type(base[i]) == "number" and base[i] + 7777 or ("SECRET-" .. name)
		secretOf[sv] = true
		args[i] = sv
		local s0, h0, e0 = S.secret, S.hidden, S.errors
		local ok, hid = pcall(M.PSS_CoreFilter, nil, "CHAT_MSG_WHISPER", unpack(args, 1, 12))
		check(ok, name .. " secret: the filter raised " .. tostring(hid))
		check(S.errors == e0, name .. " secret: the filter counted an error: " .. tostring(S.lastError))
		if name == "author" or name == "guid" then
			check(hid == false and S.hidden == h0, name .. " secret: the line was hidden")
			check(S.secret == s0 + 1, name .. " secret: not counted as an unreadable line (" .. tostring(S.secret) .. " from " .. tostring(s0) .. ")")
		elseif name == "msg" then
			check(hid == true and S.hidden == h0 + 1, "a listed author's secret message (decision 1a) was not blocked once")
		else
			check(S.secret == s0, name .. " secret: counted as unreadable")
		end
	end
	local out = say("PSSGUILD", "chat")
	check(out:find("secret (unreadable, not filtered): 2", 1, true), "/pssguild chat does not show the 2 secret lines:\n" .. out)
	-- the game events: a secret in any argument returns quietly, nothing is declined, warned or counted
	local warned = 0
	local realShow = M.ShowMsg
	M.ShowMsg = function() warned = warned + 1 end
	local cancelled = 0
	local realCancel = _G.CancelDuel
	_G.CancelDuel = function() cancelled = cancelled + 1 end
	local events = {
		{ "CHAT_MSG_WHISPER_INFORM", 2, { "hi", "Spammer-Testrealm", "", "", "", "", 0, 0, "", 0, 90001, "Player-1-Spammer" } },
		{ "PARTY_INVITE_REQUEST", 1, { "Spammer-Testrealm", false, false, false, "", "Player-1-Spammer" } },
		{ "GUILD_INVITE_REQUEST", 1, { "Spammer-Testrealm", "Some Guild" } },
		{ "DUEL_REQUESTED", 1, { "Spammer-Testrealm" } },
		{ "TRADE_REQUEST", 1, { "Spammer-Testrealm" } },
	}
	-- e[2] is the argument that names the person: secret, the event does nothing at all; any other secret argument is
	-- dropped and the event still acts on the readable person
	local e0, quiet = S.errors, true
	-- control: the same duel from the readable listed player is declined, so the handler is reached
	secretOf = {}
	H.Fire("DUEL_REQUESTED", "Spammer-Testrealm")
	check(cancelled == 1, "control: a readable listed challenger was not declined (" .. cancelled .. ")")
	cancelled = 0
	for _, e in ipairs(events) do
		-- the person's argument first, secret but reading as the listed player: a guard that is missing acts on it
		local order = { e[2] }
		for i = 1, #e[3] do if i ~= e[2] and type(e[3][i]) == "string" then order[#order + 1] = i end end
		for _, i in ipairs(order) do
			local w0, c0 = warned, cancelled
			local args = {}
			for j = 1, #e[3] do args[j] = e[3][j] end
			args[i] = i == e[2] and e[3][i] or ("SECRET-" .. e[1] .. i)
			secretOf[args[i]] = true
			local ok, err = pcall(H.Fire, e[1], unpack(args, 1, #e[3]))
			check(ok, e[1] .. " arg " .. i .. " secret: raised " .. tostring(err))
			if i == e[2] and (warned ~= w0 or cancelled ~= c0) then quiet = false; check(false, e[1] .. " acted on a secret person (arg " .. i .. ")") end
			secretOf[args[i]] = nil
		end
	end
	M.ShowMsg, _G.CancelDuel = realShow, realCancel
	check(S.errors == e0, "a game event counted an error with a secret argument: " .. tostring(S.lastError))
	check(quiet, "a game event acted on a secret person")

elseif phase == "passwhy" then
	-- a passed line says why, with constants only (no allocation per line)
	check(not deliver("CHAT_MSG_WHISPER", "Stranger-Testrealm", "hello"), "an unlisted whisper was hidden")
	check(tostring(M.PSS_CoreStats.why):find("not on any list", 1, true), "why for an unlisted author: " .. tostring(M.PSS_CoreStats.why))
	say("PSS", "add Mixed-Testrealm")
	-- an author whose list entry allows this type: W I G P C ticked = allowed (whisper)
	local keepSecret = _G.issecretvalue
	_G.issecretvalue = function(v) return v == "Hidden-Testrealm" end
	check(not deliver("CHAT_MSG_WHISPER", "Hidden-Testrealm", "hello"), "a secret author was hidden")
	check(tostring(M.PSS_CoreStats.why):find("secret", 1, true), "why for a secret author: " .. tostring(M.PSS_CoreStats.why))
	_G.issecretvalue = keepSecret
	local out = say("PSSGUILD", "chat")
	check(out:find("last line passed because: ", 1, true), "/pssguild chat does not say why the last line passed:\n" .. out)
end

if not fail then print("PASS filterreg " .. phase) end
