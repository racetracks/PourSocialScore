-- Real save check (validate_all.sh with PSS_REAL_SAVES).
-- As a run.lua script: fails on any Lua error printed to chat.
-- Standalone: lua5.1 check_real.lua <before.lua> <after.lua> checks that two
-- logins kept every rule, member, listed player, chat filter and block
-- total, dropped the records of players no longer listed (2.0.43) and left
-- no copied or empty fields on the records that stay.
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

if M then
	for _, line in ipairs(H.chat) do
		if line:find("error", 1, true) and line:find("%.lua:%d+") then
			print("FAIL real save: " .. line)
			os.exit(1)
		end
	end
	print(("real save loaded: %d rules, %d players, %d log lines"):format(
		count(PourSocialScoreDB.guildData), count(PourSocialScoreDB.playerData), #(PourSocialScoreDB.blockLog or {})))
	return
end

local function load(path)
	PourSocialScoreDB, PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB, PSS_RulesDB, PSS_CountsDB, PSS_LoggingDB = nil, nil, nil, nil, nil, nil, nil
	dofile(path)
	local db = PourSocialScoreDB
	-- a 3.0 save keeps options, players, guilds and rules in the
	-- PourSocialScore_Options tables (counts in PSS_CountsDB) and the history
	-- in PSS_LoggingDB
	-- (written to the same file by run.lua)
	for _, t in ipairs({ PSS_OptionsDB or {}, PSS_PlayersDB or {}, PSS_GuildsDB or {}, PSS_RulesDB or {}, PSS_CountsDB or {}, PSS_LoggingDB or {} }) do
		for k, v in pairs(t) do if db[k] == nil then db[k] = v end end
	end
	local s = { rules = {}, players = {}, filters = {}, total = 0 }
	for k, g in pairs(db.guildData or {}) do s.rules[k] = count(g.members) end
	local listed = {}
	-- (a save of either layout: the list's records from 3.4.1.51, the arrays before)
	-- (a legacy duplicate of one kind and name is merged by the migration: counted once)
	local entries, nlist, seen = db.list, 0, {}
	local function once(kind, name)
		local key = kind .. ":" .. tostring(name):lower()
		if not seen[key] then seen[key] = true; nlist = nlist + 1 end
	end
	if type(entries) == "table" then
		for _, e in ipairs(entries) do
			once(e.kind or "player", e.name)
			if (e.kind or "player") == "player" then listed[tostring(e.name):lower()] = true end
		end
	else
		for i, name in ipairs(db.ignoreList or {}) do
			once((db.typeList or {})[i] or "player", name)
			if ((db.typeList or {})[i] or "player") == "player" then listed[name:lower()] = true end
		end
	end
	s.records = db.playerData or {}
	for k, p in pairs(s.records) do
		-- a record only counts as needed while its player is on the list
		s.players[k] = listed[tostring(p.name):lower()] == true
	end
	for i, f in ipairs(db.filterList or {}) do s.filters[i] = f end
	s.list = nlist
	s.filterTotal = db.filterTotal
	s.countsV1 = db.guildRuleCountsV1	-- 2.0.39 moves guild rule blocks out of the filter total once
	return s
end

local a, b = load(arg[1]), load(arg[2])
local bad = 0
local function fail(msg) bad = bad + 1; print("FAIL real save: " .. msg) end
for k, n in pairs(a.rules) do
	if b.rules[k] == nil then fail("rule lost: " .. k)
	elseif b.rules[k] < n then fail(("rule %s lost members: %d -> %d"):format(k, n, b.rules[k])) end
end
for k, needed in pairs(a.players) do if needed and not b.players[k] then fail("player record lost: " .. k) end end
local DROPPED = { "nickname", "note", "expireDays", "online", "blockedWhispers", "blockHistory",
	"blockedInvites", "blockedWhisperMessages", "blockedPrivateMessages", "blockedChatMessages" }
for k, needed in pairs(b.players) do
	if not needed then fail("record of a player not on the list kept: " .. k) end
	local p = b.records[k]
	for _, f in ipairs(DROPPED) do
		if p[f] ~= nil and not (f == "nickname" and p[f] ~= p.name) then fail("old field kept: " .. k .. "." .. f) end
	end
	for f, v in pairs(p) do if v == "" then fail("empty field kept: " .. k .. "." .. f) end end
end
for i, f in ipairs(a.filters) do if b.filters[i] ~= f then fail("chat filter changed: " .. i) end end
if a.list ~= b.list then fail(("player list size %d -> %d"):format(a.list, b.list)) end
if a.countsV1 and a.filterTotal ~= b.filterTotal then fail("filter total changed") end
if bad == 0 then print("PASS real save") end
os.exit(bad == 0 and 0 or 1)
