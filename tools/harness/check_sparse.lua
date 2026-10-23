-- Sparse records and the SavedVariables performance cleanup (core uplift S3,
-- 3.4.1.52, upgrade step 10). validate_all.sh runs it as "== sparse".
--
--   lua5.1 tools/harness/check_sparse.lua --plant <base> <out>
--     <base> is a fresh save (run.lua . - <base>); <out> is it with a 3.4.1.51
--     save's data planted over it (upgrade step 9): a rule of 1600 stored
--     members (four of them with something of their own), a managed rule with
--     a found member, a shipped one, a name the key does not give, counts
--     with a total above the sum, a member with no date, a field of a newer
--     version; two players (switches, zero counts); three custom chat filters
--     with no id (two with the same text) with recent counts, a waiting line
--     and saved log lines under "f:t:<text>"; two saved log groups.
--     A third argument "unique" plants the same without what the previous
--     build reads differently on purpose (the cap, a member with no date, two
--     filters sharing a text): sparse_saves.sh compares that one
--   PSS_PHASE=login  lua5.1 tools/harness/run.lua . <out> <out1> check_sparse.lua
--     the migrating login: the cap, sparse records, switches, ids and the
--     history moved to them, the report's lines, every accessor reading the
--     same, unknown fields kept
--   PSS_PHASE=again  ... run.lua . <out1> <out2> check_sparse.lua
--     the next login reads the sparse file back and changes nothing
--   lua5.1 tools/harness/check_sparse.lua --after <out1>
--     the saved file: sparse, ids and their counter, the log groups
--   lua5.1 tools/harness/check_sparse.lua --plant-camelot <base> <names> <out>
--   PSS_CAMELOT=1 PSS_PHASE=camelot ...
--     the Camelot name repair (PSS_PHASE=names prints a shipped member's name
--     for the plant); on the Retail stub the same save changes no name
local mode = arg and arg[1]

------------------------------------------------------------------------
-- standalone: plant and after
------------------------------------------------------------------------
local T1, T2 = "[word=customone]", "[word=customtwo]"		-- the custom filters' texts

local function lit(v, ind)
	ind = ind or ""
	if type(v) == "table" then
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local t = {}
		for _, k in ipairs(keys) do
			local ks = type(k) == "string" and ("[%q]"):format(k) or ("[" .. tostring(k) .. "]")
			t[#t + 1] = ind .. "\t" .. ks .. " = " .. lit(v[k], ind .. "\t")
		end
		return "{\n" .. table.concat(t, ",\n") .. "\n" .. ind .. "}"
	end
	if type(v) == "string" then return ("%q"):format(v) end
	return tostring(v)
end

local function readEnv(path)
	local env = {}
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)()
	return env
end

local function date(i) return os.date("!%d %b %Y %H:%M:%S", 1760000000 + i * 3600) end

local function managedRule(env)
	return "american olympus", env.PSS_GuildsDB.guildData["american olympus"]
end

local function zeros(t)
	local c = { whisper = 0, partyInvite = 0, guildInvite = 0, partyRaid = 0, world = 0, guildChat = 0, unknown = 0, total = 0 }
	for k, v in pairs(t or {}) do c[k] = v end
	return c
end

local function save(base, out, lines)
	local fh = assert(io.open(base, "rb"))
	local text = fh:read("*a")
	fh:close()
	fh = assert(io.open(out, "wb"))
	fh:write(text, "\n", table.concat(lines, "\n"), "\n")
	fh:close()
end

if mode == "--plant" then
	local base, out = arg[2], arg[3]
	local env = readEnv(base)
	local mk, mg = managedRule(env)
	local L = {}
	local function set(path, v) L[#L + 1] = path .. " = " .. lit(v) end
	L[#L + 1] = "PourSocialScoreDB.upgrade.step = 9"
	-- a rule of 1600 stored members (3.4.1.51 layout: full records)
	local members = {}
	for i = 1, (arg[4] == "unique" and 100 or 1600) do
		local key = ("plain%04d-realm"):format(i)
		members[key] = { name = ("Plain%04d-Realm"):format(i), guild = "CapGuild", whenBlocked = date(i), _playerKey = key }
	end
	members["plain0001-realm"].note = "keep me"
	members["plain0002-realm"].blockCounts = zeros({ whisper = 3, total = 3 })
	members["plain0003-realm"].excludedWhispers = true
	members["plain0004-realm"].block = { whisper = false }
	local block = { whisper = true, partyInvite = true, guildInvite = true, partyRaid = true, world = true }
	set('PSS_GuildsDB.guildData["capguild"]', { name = "CapGuild", enabled = true, declineGuild = true, declineGroup = true,
		partyRaid = true, customScan = "1-60", block = block, memberCount = 1600, members = members, ruleOrigin = "manual" })
	-- a managed rule with the kinds of record 3.4.1.51 saved
	local ms = {
		["foundm-realm"] = { name = "Foundm-Realm", guild = mg.name, whenBlocked = date(5), _playerKey = "foundm-realm",
			class = "MAGE", faction = "Alliance", level = 20, blockCounts = zeros({ whisper = 2, world = 1, total = 3 }) },
		["shipx-realm"] = { name = "Shipx-Realm", guild = mg.name, whenBlocked = "Managed list", _managed = true,
			_playerKey = "shipx-realm", note = "n" },
		["mcodd-realm"] = { name = "McOdd-Realm", guild = "Other Guild", whenBlocked = date(6), _playerKey = "mcodd-realm" },
		["nodate-realm"] = arg[4] ~= "unique" and { name = "Nodate-Realm", guild = mg.name, class = "ROGUE" } or nil,
		["cnt-realm"] = { name = "Cnt-Realm", guild = mg.name, whenBlocked = date(7),
			blockCounts = zeros({ whisper = 1, world = 3, total = 9 }) },
		["newerf-realm"] = { name = "Newerf-Realm", guild = mg.name, whenBlocked = date(8), newerField = 5 },
	}
	set('PSS_GuildsDB.guildData[' .. ("%q"):format(mk) .. '].members', ms)
	L[#L + 1] = ('PSS_GuildsDB.guildData[%q].memberCount = 6'):format(mk)
	-- players
	set("PSS_PlayersDB.list", { { name = "Pa-Realm", date = "01 Oct 2026" }, { name = "Pb-Realm", date = "02 Oct 2026" } })
	set("PSS_PlayersDB.playerData", {
		["pa-realm"] = { name = "Pa-Realm", whenBlocked = date(1), whispersBlocked = true, partyInvitesBlocked = false,
			guildInvitesBlocked = true, partyRaidBlocked = true, channelsBlocked = true, blockCounts = zeros() },
		["pb-realm"] = { name = "Pb-Realm", whenBlocked = date(2), whispersBlocked = true, partyInvitesBlocked = true,
			guildInvitesBlocked = true, partyRaidBlocked = true, channelsBlocked = true, blockCounts = zeros({ whisper = 2, total = 2 }) },
	})
	-- three custom chat filters without an id; two have the same text
	set("PSS_RulesDB.filterList", { T1, T2, arg[4] == "unique" and "[word=customthree]" or T1 })
	set("PSS_RulesDB.filterDesc", { "One", "Two", "One again" })
	set("PSS_RulesDB.filterActive", { true, true, false })
	set("PSS_RulesDB.filterID", { "", "", "" })
	set("PSS_CountsDB.filterCount", { 7, 2, 0 })
	set("PSS_CountsDB.filterBlocked", { { counts = zeros({ world = 7, total = 7 }) }, { counts = zeros({ whisper = 2, total = 2 }) }, { counts = zeros() } })
	set("PSS_CountsDB.filterBlockedLast", { 0, 0, 0 })
	-- recent counts and a waiting line under the filters' texts
	local cur = math.floor(1790000000 / 600)
	local slot = {}
	slot[cur % 144 + 1] = { world = { ["f:t:" .. T1] = 7, ["f:t:" .. T2] = 1 }, whisper = { ["p:pb-realm"] = 2 } }
	local recent = { v = 2, last = cur, day = { ["f:t:" .. T1] = 7, ["f:t:" .. T2] = 1, ["p:pb-realm"] = 2 } }
	for k, v in pairs(slot) do recent[k] = v end
	set("PourSocialScoreDB.recent", recent)
	set("PourSocialScoreDB.outbox", { { ts = 1789999000, cat = "world", event = "CHAT_MSG_CHANNEL", channel = "2. Trade", member = "S-Realm",
		message = "waiting", o = "f:t:" .. T2 } })
	-- saved log groups
	set("PSS_LoggingDB.blockLog", {
		v = 2,
		["f:t:" .. T1] = { m = "S-Realm", "c1789990000\tCHAT_MSG_CHANNEL\t\t\tspam one", "c+10\tCHAT_MSG_CHANNEL\t\t\tspam two" },
		["g:mcodd-realm"] = { m = "McOdd-Realm", gk = "capguild", "c1789990100\tCHAT_MSG_CHANNEL\t\t\thi" },
		["p:pb-realm"] = { m = "Pb-Realm", "w1789990200\tCHAT_MSG_WHISPER\t\t\tpsst" },
	})
	save(base, out, L)
	print("PASS sparse plant")
	return
end

if mode == "--plant-camelot" then
	local base, names, out = arg[2], arg[3], arg[4]
	local env = readEnv(base)
	local mk, mg = managedRule(env)
	local fh = assert(io.open(names))
	local ship = fh:read("*l")			-- a shipped member of the rule, "first last-classicbetapvp"
	fh:close()
	local first, last = ship:match("^([^%s%-]+) ([^%s%-]+)%-")
	assert(first and last, "no two-word shipped name: " .. tostring(ship))
	local L = {}
	local function set(path, v) L[#L + 1] = path .. " = " .. lit(v) end
	L[#L + 1] = "PourSocialScoreDB.upgrade.step = 9"
	local ms = {
		-- found by a unit: merged into the shipped member, its note kept
		[first .. "-" .. last] = { name = first .. "-" .. last, guild = mg.name, whenBlocked = date(1), faction = "Alliance", class = "MAGE", note = "from unit" },
		-- found by a unit, a stored twin exists: merged into it
		["zorro-blackmane"] = { name = "Zorro-Blackmane", guild = mg.name, whenBlocked = date(2), faction = "Horde", class = "ROGUE", level = 30 },
		["zorro blackmane-classicbetapvp"] = { name = "Zorro Blackmane-Classicbetapvp", guild = mg.name, whenBlocked = date(3), note = "twin" },
		-- found by a unit, nothing else: stored again under its new key
		["alpha-beta"] = { name = "Alpha-Beta", guild = mg.name, whenBlocked = date(4), faction = "Alliance", class = "MAGE",
			blockCounts = zeros({ world = 2, total = 2 }) },
		-- not touched: no faction, a key from /who, a realm of this client
		["gamma-delta"] = { name = "Gamma-Delta", guild = mg.name, whenBlocked = date(5) },
		["eps-zeta"] = { name = "Eps-Zeta", guild = mg.name, whenBlocked = date(6), faction = "Horde", _playerKey = "eps-zeta" },
		["ownrealm-classicbetapvp"] = { name = "Ownrealm-Classicbetapvp", guild = mg.name, whenBlocked = date(7), faction = "Horde" },
	}
	set('PSS_GuildsDB.guildData[' .. ("%q"):format(mk) .. '].members', ms)
	set("PSS_PlayersDB.list", {
		{ name = "Hatti-Fnatt", date = "01 Oct 2026", faction = "Alliance" },
		{ name = "Dup-Name", date = "01 Oct 2026" },
		{ name = "Dup Name-Classicbetapvp", date = "02 Oct 2026", note = "listed" },
		{ name = "Archdruid-Classicbetapvp", date = "03 Oct 2026", faction = "Horde" },
	})
	set("PSS_PlayersDB.playerData", {
		["hatti-fnatt"] = { name = "Hatti-Fnatt", whenBlocked = date(1), partyInvitesBlocked = false },
		["dup-name"] = { name = "Dup-Name", whenBlocked = date(1) },
		["dup name-classicbetapvp"] = { name = "Dup Name-Classicbetapvp", whenBlocked = date(2) },
	})
	set("PSS_PlayersDB.delList", { "Erlirrin-Softgale", "Plain-Classicbetapvp" })
	save(base, out, L)
	print("PASS camelot plant")
	return
end

if mode == "--after" then
	local env = readEnv(arg[2])
	local fail = 0
	local function check(ok, msg) if not ok then print("FAIL sparse after: " .. msg); fail = fail + 1 end end
	local gd = env.PSS_GuildsDB.guildData
	for gkey, g in pairs(gd) do
		check(g.memberCount == nil, gkey .. " saved its memberCount")
		for k, m in pairs(g.members or {}) do
			for _, f in ipairs({ "_playerKey", "_canon", "_gkey", "_managed", "_virtual" }) do
				check(m[f] == nil, gkey .. "/" .. k .. " saved " .. f)
			end
			check(m.guild ~= g.name, gkey .. "/" .. k .. " saved the rule's name as its guild")
			if g.managed then check(m.whenBlocked ~= "Managed list", gkey .. "/" .. k .. " saved the Managed list date") end
			local bc = m.blockCounts
			if bc then
				for c, n in pairs(bc) do check(n ~= 0, gkey .. "/" .. k .. " saved a zero count " .. c) end
			end
		end
	end
	for key, p in pairs(env.PSS_PlayersDB.playerData) do
		for _, f in ipairs({ "whispersBlocked", "partyInvitesBlocked", "guildInvitesBlocked", "partyRaidBlocked", "channelsBlocked" }) do
			check(p[f] ~= true, key .. " saved " .. f .. " = true")
		end
	end
	local ids = env.PSS_RulesDB.filterID
	local cap = env.PSS_GuildsDB.guildData["capguild"]
	if cap then
		local n = 0
		for _ in pairs(cap.members) do n = n + 1 end
		check(n == 1500, "capguild saved " .. n .. " members")
	end
	if arg[3] == "ids" then
		check(env.PSS_RulesDB.nextFilterId == 3, "nextFilterId " .. tostring(env.PSS_RulesDB.nextFilterId))
		check(type(ids) == "table" and ids[1] == 1 and ids[2] == 2 and ids[3] == 3, "filter ids not saved as 1 2 3")
		local log = env.PSS_LoggingDB.blockLog
		check(type(log["f:1"]) == "table" and #log["f:1"] == 2, "the lines of filter 1 are not under f:1")
		check(log["f:t:" .. T1] == nil, "lines left under the filter's text")
		check(type(log["g:mcodd-realm"]) == "table" and log["g:mcodd-realm"].m == "McOdd-Realm", "a name that is not the key's form lost its m")
		check(type(log["p:pb-realm"]) == "table" and log["p:pb-realm"].m == nil, "a name the key gives kept its m")
		local r = env.PourSocialScoreDB.recent
		check(r and r.day and r.day["f:1"] == 7 and r.day["f:2"] == 1 and r.day["f:t:" .. T1] == nil, "recent counts not moved to the ids")
	end
	print(fail == 0 and "PASS sparse after" or "FAIL sparse after")
	os.exit(fail == 0 and 0 or 1)
end

------------------------------------------------------------------------
-- under run.lua
------------------------------------------------------------------------
local H = _G.H
local phase = os.getenv("PSS_PHASE") or "login"
local fail = 0
local function check(ok, msg) if not ok then print("FAIL sparse " .. phase .. ": " .. msg); fail = fail + 1 end end
local db = PourSocialScoreDB
local History = M.PSS_History

if phase == "names" then
	-- a shipped member with a first and a last name, for the Camelot plant
	M.PSS_LoadManagedData()
	for k, g in pairs(db.guildData) do
		if g.managed then
			for _, n in ipairs(M.PSS_ShippedNames(k) or {}) do
				if n:find("^[^%s%-]+ [^%s%-]+%-") then
					local fh = assert(io.open(os.getenv("PSS_NOTE"), "w"))
					fh:write(n, "\n")
					fh:close()
					return
				end
			end
		end
	end
	error("no shipped member with two names")
end

local function members(gkey) return db.guildData[gkey] and db.guildData[gkey].members or {} end
local function managedKey()
	for k, g in pairs(db.guildData) do if g.managed and k == "american olympus" then return k end end
end

if phase == "login" or phase == "again" then
	M.PSS_Need("Libraries")
	local cap = members("capguild")
	local n = 0
	for _ in pairs(cap) do n = n + 1 end
	check(n == 1500, "capguild holds " .. n .. " members, not 1500")
	for _, k in ipairs({ "plain0001-realm", "plain0002-realm", "plain0003-realm", "plain0004-realm", "plain0105-realm", "plain1600-realm" }) do
		check(cap[k] ~= nil, k .. " (a member with something of its own, or newer than the cap cut) is gone")
	end
	check(cap["plain0005-realm"] == nil and cap["plain0104-realm"] == nil, "the oldest plain members were not the ones removed")
	local plain = cap["plain0500-realm"]
	check(plain and plain.name == nil and plain.guild == nil and plain._playerKey == nil and plain.whenBlocked ~= nil, "a plain member is not sparse")
	check(next(plain or {}) == "whenBlocked" and next(plain, "whenBlocked") == nil, "a plain member keeps more than its date")
	check(cap["plain0001-realm"].note == "keep me" and cap["plain0002-realm"].blockCounts.whisper == 3 and cap["plain0002-realm"].blockCounts.total == nil,
		"a counted member's counts")
	check(cap["plain0003-realm"].block and cap["plain0003-realm"].block.whisper == false and cap["plain0003-realm"].excludedWhispers == nil
		and cap["plain0004-realm"].block.whisper == false, "a member's own choices were lost")
	-- every accessor, with and without the key and the rule
	local g = db.guildData["capguild"]
	local m = cap["plain0500-realm"]
	check(M.PSS_MemberName(m) == "Plain0500-Realm" and M.PSS_MemberName(m, "plain0500-realm") == "Plain0500-Realm", "name through the accessor")
	check(M.PSS_MemberGuildName(m) == "CapGuild" and M.PSS_MemberGuildName(m, g) == "CapGuild", "guild through the accessor")
	check(M.PSS_MemberCanon(m) == "plain0500-realm" and M.PSS_MemberPlayerKey(m) == "plain0500-realm", "canon and key through the accessors")
	check(M.PSS_MemberShipped(m, g) == false and M.PSS_MemberWhenBlocked(m) == m.whenBlocked, "a found member in an unmanaged rule")
	check(M.PSS_StoreMemberCount(g) == 1500 and g.memberCount == nil, "the member count is worked out, not saved")
	local mk = managedKey()
	local ms, mg = members(mk), db.guildData[mk]
	local found, ship, odd, nodate, cnt, newer = ms["foundm-realm"], ms["shipx-realm"], ms["mcodd-realm"], ms["nodate-realm"], ms["cnt-realm"], ms["newerf-realm"]
	check(found and ship and odd and nodate and cnt and newer, "a planted member of the managed rule is gone")
	check(found.name == nil and found.guild == nil and found._playerKey == nil, "a found member is not sparse")
	check(found.blockCounts and found.blockCounts.whisper == 2 and found.blockCounts.world == 1 and found.blockCounts.partyInvite == nil and found.blockCounts.total == nil,
		"a found member's counts are not sparse")
	check(M.PSS_GetMemberBlockCounts(found).total == 3, "the counts total reads wrong")
	check(ship._managed == nil and ship.whenBlocked == nil and ship.guild == nil and ship.note == "n", "a shipped member is not sparse")
	check(M.PSS_MemberShipped(ship) == true and M.PSS_MemberWhenBlocked(ship) == "Managed list" and M.PSS_MemberGuildName(ship) == mg.name,
		"a shipped member through the accessors (no key, no rule given)")
	check(odd.name == "McOdd-Realm" and odd.guild == "Other Guild", "a name and a guild the key and rule do not give were dropped")
	check(nodate.whenBlocked ~= nil and M.PSS_MemberShipped(nodate) == false, "a found member with no date was not stamped")
	check(cnt.blockCounts.total == 9 and History.CountTotal(cnt.blockCounts) == 9, "a total above the sum of the types was lost")
	check(newer.newerField == 5, "a field of a newer version was dropped")
	check(M.PSS_GuildMemberCount(mg, mk) >= 5, "the managed rule's member count")
	-- players
	local pa, pb = db.playerData["pa-realm"], db.playerData["pb-realm"]
	check(pa.partyInvitesBlocked == false and pa.whispersBlocked == nil and pa.guildInvitesBlocked == nil and pa.channelsBlocked == nil, "player switches")
	check(pa.blockCounts == nil and pb.blockCounts and pb.blockCounts.whisper == 2 and pb.blockCounts.total == nil, "player counts are not sparse")
	check(M.PSS_PlayerAllowed(pa, "partyInvitesBlocked") and not M.PSS_PlayerAllowed(pa, "whispersBlocked"), "allowed reads wrong")
	check(M.PSS_PlayerBlocksAnything(pa) and M.PSS_PlayerBlocksAnything(pb), "a player that blocks reads as blocking nothing")
	-- the chat decision still blocks what a missing switch blocks
	-- custom filters
	local ids = {}
	for i = 1, #db.filterList do
		if not M.PSS_IsBuiltinFilter(i) then ids[#ids + 1] = db.filterID[i] end
	end
	check(#ids == 3 and ids[1] == 1 and ids[2] == 2 and ids[3] == 3, "custom filter ids " .. table.concat(ids, ","))
	check(db.nextFilterId == 3, "nextFilterId " .. tostring(db.nextFilterId))
	local newId = M.PSS_NewFilterId()
	check(newId == 4, "the next id is " .. tostring(newId))
	local added = M.PSS_AddCustomFilter("Added", "added text", false)
	check(db.filterID[added] == 5, "an added filter's id " .. tostring(db.filterID[added]))
	M.RemoveChatFilter(added)
	check(M.PSS_NewFilterId() == 6, "an id was used twice")
	local first
	for i = 1, #db.filterList do if db.filterID[i] == 1 then first = i end end
	check(first and M.PSS_FilterOwnerKey(first) == "f:1", "the owner key of filter 1")
	local s, d = History.RecentCounts("f:1")
	check(d == 7, "recent counts of filter 1: " .. tostring(d))
	check(select(2, History.RecentCounts("f:2")) == 1, "recent counts of filter 2")
	check(select(2, History.RecentCounts("f:t:" .. T1)) == 0, "recent counts left under the text")
	check(#History.For("f:1") == 2 and #History.For("f:2") == 1 and #History.For("f:3") == 0, "the lines of the filters")
	-- an edit keeps the history; a copy starts its own
	M.PSS_SaveChatFilter(first, "One edited", "[word=customoneedited]")
	check(M.PSS_FilterOwnerKey(first) == "f:1" and #History.For("f:1") == 2, "editing a filter lost its history")
	local copy = M.PSS_CopyChatFilter(first)
	check(copy and db.filterID[copy] ~= 1 and #History.For(M.PSS_FilterOwnerKey(copy)) == 0, "a copy shares the history")
	M.RemoveChatFilter(copy)
	-- the log's groups
	check(#History.For("g:mcodd-realm") == 1 and #History.For("p:pb-realm") == 1, "saved log groups")
	check(History.For("p:pb-realm")[1].member == "Pb-Realm", "a person's name from the owner key")
	-- fields of a newer version are still there; counters in the check
	local v = M.PSS_Validate()
	check(#v.problems == 0, "/pss check: " .. tostring(v.problems[1]))
	if phase == "login" then
		-- the report said what happened
		local seen = os.getenv("PSS_LOGIN_OUT")
		if seen then
			local fh = assert(io.open(seen))
			local text = fh:read("*a")
			fh:close()
			check(text:find("100 stored member%(s%) over the 1500", 1) ~= nil, "the cap is not in the report")
			check(text:find("custom rule%(s%) given an ID", 1) ~= nil, "the filter ids are not in the report")
			check(text:find("saved record%(s%) made smaller", 1) ~= nil, "sparse records are not in the report")
			check(text:find("player record%(s%) no longer store", 1) ~= nil, "the player switches are not in the report")
		end
	end
	-- unknown fields survive the next save
	db.guildData["capguild"].members["plain0500-realm"].newerMore = "x"
	print(fail == 0 and ("PASS sparse " .. phase) or ("FAIL sparse " .. phase))
	return
end

if phase == "camelot" then
	local camelot = (os.getenv("PSS_FLAVOUR") == "forever" or os.getenv("PSS_CAMELOT") == "1")
	local mk = managedKey()
	local ms = members(mk)
	local function has(k) return ms[k] ~= nil end
	local ship = os.getenv("PSS_SHIPPED")
	if camelot then
		check(not has("zorro-blackmane") and not has("alpha-beta"), "a surname key is still stored")
		local twin = ms["zorro blackmane-classicbetapvp"]
		check(twin and twin.note == "twin" and twin.faction == "Horde" and twin.level == 30, "the stored twin did not take the unit's details")
		local moved = ms["alpha beta-classicbetapvp"]
		check(moved and moved.faction == "Alliance" and moved.blockCounts and moved.blockCounts.world == 2, "the re-keyed member")
		check(moved and M.PSS_MemberName(moved) == "Alpha Beta-Classicbetapvp", "the re-keyed name " .. tostring(moved and M.PSS_MemberName(moved)))
		check(M.PSS_LookupGuildMember("Alpha Beta") ~= nil, "the repaired member is not found by chat's spelling")
		check(has("gamma-delta") and has("eps-zeta") and has("ownrealm-classicbetapvp"), "a member that was not a unit's surname was touched")
		-- a shipped member: no stored copy, the note on its shipped record
		local first, last = (ship or ""):match("^([^%s%-]+) ([^%s%-]+)%-")
		check(first and not has((first .. "-" .. last):lower()), "the shipped member was stored again")
		local r = M.PSS_LookupGuildMember(ship)
		check(r and (M.PSS_LookupGuildMember(ship)) ~= nil, "the shipped member is not found")
		local _, _, rec = M.PSS_LookupGuildMember(ship)
		check(rec and rec.note == "from unit", "the shipped member did not take the note")
		-- the Player Ignore List
		local names = {}
		for _, e in ipairs(db.list) do names[e.name] = true end
		check(names["Hatti Fnatt-Classicbetapvp"] and not names["Hatti-Fnatt"], "a listed surname was not repaired")
		check(names["Dup Name-Classicbetapvp"] and not names["Dup-Name"], "a duplicate listing stayed")
		check(names["Archdruid-Classicbetapvp"], "a name that cannot be repaired was changed")
		check(db.playerData["hatti fnatt-classicbetapvp"] and db.playerData["hatti fnatt-classicbetapvp"].partyInvitesBlocked == false
			and not db.playerData["hatti-fnatt"], "the player record did not move")
		check(not db.playerData["dup-name"] and db.playerData["dup name-classicbetapvp"], "the duplicate's record")
		local del = {}
		for _, n in ipairs(db.delList) do del[n] = true end
		check(del["Erlirrin Softgale-Classicbetapvp"] and del["Plain-Classicbetapvp"] and not del["Erlirrin-Softgale"], "the recently removed names")
		local out = os.getenv("PSS_LOGIN_OUT")
		if out and phase == "camelot" and os.getenv("PSS_FIRST") == "1" then
			local fh = assert(io.open(out))
			local text = fh:read("*a")
			fh:close()
			check(text:find("Camelot name%(s%) repaired", 1) ~= nil, "the repair is not in the report")
			check(text:find("Archdruid%-Classicbetapvp", 1) ~= nil and text:find("may have lost their surname", 1, true) ~= nil, "the names that may be first name only are not listed")
		end
	else
		-- Retail: the same save keeps every name (a realm there can look like this)
		check(has("zorro-blackmane") and has("alpha-beta"), "a Retail save was repaired")
		local names = {}
		for _, e in ipairs(db.list) do names[e.name] = true end
		check(names["Hatti-Fnatt"], "a Retail list entry was repaired")
	end
	print(fail == 0 and "PASS sparse camelot" or "FAIL sparse camelot")
	return
end

error("unknown phase " .. phase)
