-- Player Ignore List records (core uplift S2b, 3.4.1.51): one sparse record
-- per listed entry in PourSocialScoreDB.list, in place of the eight parallel
-- arrays (ignoreList, typeList, factionList, dateList, notes, expList,
-- syncInfo; delList and playerData stay).
--
--   PSS_PHASE=login  PSS_SV_IN=<save> lua5.1 tools/harness/run.lua . <save> <out1> tools/harness/check_listrecords.lua
--     the save (fresh, the 2.0.44 test save, a real save, the planted one)
--     migrated on this one login: `list` holds every entry of the old arrays
--     in order (a legacy duplicate of the same kind and lower-case name
--     dropped, the first kept) with its note, kind, faction, date, expiry and
--     sync, no retired array is left in memory, `M.PSS_Validate` gives the
--     counters computed from the old save's own arrays (apart from the
--     duplicates merged), records are sparse; an unknown field is planted
--   PSS_PHASE=again  PSS_SV_IN=<out1> ... run.lua . <out1> <out2> ...
--     the second login: nothing changed, the planted fields survived, the
--     counters equal the ones of <out1>, no retired key in the saved file
--   PSS_PHASE=drift  ... run.lua . <save> - ...    (any save, also fresh)
--     adds and removes entries in the middle (player, NPC, server kinds, the
--     same name as two kinds): every other entry keeps its note, kind,
--     faction, date, expiry and sync; the setters stay sparse and keep
--     unknown fields; removing a player clears their record and history,
--     removing an NPC of the same name does not
--   lua5.1 tools/harness/check_listrecords.lua --plant <out>
--     writes a 3.4.1.50 save in the old layout (four listed players, an NPC,
--     a server, a duplicate, the same name as two kinds, holes in the arrays)
local RETIRED = { "ignoreList", "typeList", "factionList", "dateList", "notes", "expList", "syncInfo" }

------------------------------------------------------------------------
-- --plant: standalone, no addon
------------------------------------------------------------------------
if arg and arg[1] == "--plant" then
	local out = assert(arg[2], "usage: check_listrecords.lua --plant <out>")
	local fh = assert(io.open(out, "w"))
	fh:write([[
PourSocialScoreDB = {
	["imported"] = false,
	["logAllV1"] = true,
	["revision"] = 1,
	["upgrade"] = {
		["at"] = 1790000000,
		["step"] = 8,
		["version"] = "3.4.1.50",
	},
}
PSS_PlayersDB = {
	["ignoreList"] = { "Alpha-Realm", "Beta-Realm", "Wolf", "Realmx", "Gamma-Realm", "Delta-Realm", "ALPHA-realm", "Wolf-Realm", "Wolf" },
	["typeList"] = { [1] = "player", [2] = "player", [3] = "npc", [4] = "server", [5] = "player", [7] = "player", [8] = "player", [9] = "npc" },
	["factionList"] = { [1] = "Alliance", [2] = "Alliance", [3] = "Horde", [5] = "Horde", [7] = "Horde" },
	["dateList"] = { "20 Sep 2026", "19 Sep 2026", "18 Sep 2026", "17 Sep 2026", "16 Sep 2026", "15 Sep 2026", "14 Sep 2026", "13 Sep 2026", "12 Sep 2026" },
	["notes"] = { [1] = "note a", [2] = "", [3] = "npc note", [4] = "", [5] = "g", [6] = "", [7] = "dup note", [8] = "wolf the player", [9] = "dup npc" },
	["expList"] = { [1] = 5, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 30, [7] = 0, [8] = 0, [9] = 0 },
	["syncInfo"] = { [1] = { "Me@3" }, [2] = {}, [3] = {}, [4] = {}, [5] = { "Me@1", "Other@2" }, [6] = {}, [7] = {}, [8] = {}, [9] = {} },
	["delList"] = { "gone-realm", "gone2-realm" },
	["playerData"] = {
		["alpha-realm"] = { ["name"] = "Alpha-Realm", ["whispersBlocked"] = true, ["partyInvitesBlocked"] = true, ["guildInvitesBlocked"] = true, ["partyRaidBlocked"] = true, ["channelsBlocked"] = true },
		["beta-realm"] = { ["name"] = "Beta-Realm", ["whispersBlocked"] = true, ["partyInvitesBlocked"] = true, ["guildInvitesBlocked"] = true, ["partyRaidBlocked"] = true, ["channelsBlocked"] = true },
		["gamma-realm"] = { ["name"] = "Gamma-Realm", ["whispersBlocked"] = true, ["partyInvitesBlocked"] = true, ["guildInvitesBlocked"] = true, ["partyRaidBlocked"] = true, ["channelsBlocked"] = true },
		["wolf-realm"] = { ["name"] = "Wolf-Realm", ["whispersBlocked"] = true, ["partyInvitesBlocked"] = true, ["guildInvitesBlocked"] = true, ["partyRaidBlocked"] = true, ["channelsBlocked"] = true },
		["delta-realm"] = { ["name"] = "Delta-Realm", ["whispersBlocked"] = true, ["partyInvitesBlocked"] = true, ["guildInvitesBlocked"] = true, ["partyRaidBlocked"] = true, ["channelsBlocked"] = true },
	},
}
]])
	fh:close()
	print("PASS listrecords plant")
	return
end

local H = _G.H
local phase = os.getenv("PSS_PHASE") or "login"
local fail = 0
local function check(ok, msg) if not ok then print("FAIL listrecords " .. phase .. ": " .. msg); fail = fail + 1 end end

local function lowerName(n) return tostring(n):lower() end
local function nonEmpty(s) return type(s) == "string" and s ~= "" and s or nil end

-- one comparable line per entry: every attribute in its sparse reading
local function shape(e)
	local sync
	if type(e.sync) == "table" and #e.sync > 0 then sync = table.concat(e.sync, "|") end
	return table.concat({
		tostring(e.name), tostring(e.kind or "player"), tostring(nonEmpty(e.faction)), tostring(nonEmpty(e.date)),
		tostring(nonEmpty(e.note)), tostring((tonumber(e.exp) or 0) > 0 and e.exp or nil), tostring(sync),
	}, "\t")
end

------------------------------------------------------------------------
-- the old save, read raw: entries (either layout), records, deleted names
------------------------------------------------------------------------
local function loadRaw(paths)
	local env = {}
	for path in tostring(paths or ""):gmatch("[^,]+") do
		if path ~= "-" then
			local chunk = assert(loadfile(path))
			setfenv(chunk, env)
			chunk()
		end
	end
	return env
end

local function rawState(env)
	local db, pl = env.PourSocialScoreDB or {}, env.PSS_PlayersDB or {}
	local function get(k) if db[k] ~= nil then return db[k] end return pl[k] end
	local out = {}
	local list = get("list")
	if type(list) == "table" then
		for i = 1, #list do
			local e = list[i]
			out[i] = { name = e.name, kind = e.kind, faction = e.faction, date = e.date, note = e.note, exp = e.exp, sync = e.sync }
		end
	else
		local names, kinds, factions = get("ignoreList") or {}, get("typeList") or {}, get("factionList") or {}
		local dates, notes, exps, syncs = get("dateList") or {}, get("notes") or {}, get("expList") or {}, get("syncInfo") or {}
		for i = 1, #names do
			local kind = kinds[i]
			if kind == "player" then kind = nil end
			out[i] = { name = names[i], kind = kind, faction = factions[i], date = dates[i], note = notes[i], exp = exps[i], sync = syncs[i] }
		end
	end
	local retired = {}
	for _, k in ipairs(RETIRED) do if get(k) ~= nil then retired[#retired + 1] = k end end
	local records = 0
	for _ in pairs(get("playerData") or {}) do records = records + 1 end
	return { entries = out, records = records, deleted = #(get("delList") or {}), retired = retired }
end

-- what M.PSS_Validate must say about it, and the entries that must be kept:
-- the first of a kind and lower-case name stays, later ones are merged
local function expected(state)
	local kept, seen = {}, {}
	local n = { list = 0, listPlayer = 0, listNpc = 0, listServer = 0, listOther = 0, listNotes = 0, listDuplicates = 0,
		playerRecords = state.records, deleted = state.deleted }
	for _, e in ipairs(state.entries) do
		local kind = e.kind or "player"
		local key = kind .. ":" .. lowerName(e.name)
		if not seen[key] then
			seen[key] = true
			kept[#kept + 1] = e
			n.list = n.list + 1
			if kind == "player" then n.listPlayer = n.listPlayer + 1
			elseif kind == "npc" then n.listNpc = n.listNpc + 1
			elseif kind == "server" then n.listServer = n.listServer + 1
			else n.listOther = n.listOther + 1 end
			if nonEmpty(e.note) then n.listNotes = n.listNotes + 1 end
		end
	end
	return n, kept
end

local function noRetired(where)
	local db, pl = PourSocialScoreDB, _G.PSS_PlayersDB or {}
	for _, k in ipairs(RETIRED) do
		check(rawget(db, k) == nil, where .. ": PourSocialScoreDB." .. k .. " is still there")
		check(pl[k] == nil, where .. ": PSS_PlayersDB." .. k .. " is still there")
		check(db[k] == nil, where .. ": " .. k .. " still reads")
	end
end

local function sameCounters(want, label)
	local r = M.PSS_Validate()
	for _, p in ipairs(r.problems) do print("problem: " .. p) end
	check(#r.problems == 0, label .. ": the saved data has problems")
	-- (a listed player with no record gets one at login: bounded, not exact)
	check(r.n.playerRecords >= want.playerRecords and r.n.playerRecords <= want.playerRecords + want.listPlayer,
		label .. ": playerRecords is " .. tostring(r.n.playerRecords) .. ", the save had " .. want.playerRecords)
	for k, v in pairs(want) do check(k == "playerRecords" or r.n[k] == v, ("%s: %s is %s, not %s"):format(label, k, tostring(r.n[k]), tostring(v))) end
	return r
end

local function sparse(list, label)
	for i = 1, #list do
		local e = list[i]
		local at = ("%s: entry %d (%s)"):format(label, i, tostring(e.name))
		check(type(e.name) == "string" and e.name ~= "", at .. " has no name")
		check(e.note == nil or (type(e.note) == "string" and e.note ~= ""), at .. " stores an empty note")
		check(e.exp == nil or (type(e.exp) == "number" and e.exp > 0), at .. " stores an expiry of " .. tostring(e.exp))
		check(e.sync == nil or (type(e.sync) == "table" and #e.sync > 0), at .. " stores an empty sync")
		check(e.kind == nil or (type(e.kind) == "string" and e.kind ~= "player" and e.kind ~= ""), at .. " stores kind " .. tostring(e.kind))
		check(e.faction == nil or (type(e.faction) == "string" and e.faction ~= ""), at .. " stores an empty faction")
		check(e.date == nil or (type(e.date) == "string" and e.date ~= ""), at .. " stores an empty date")
	end
end

local function listShapes(list)
	local t = {}
	for i = 1, #list do t[i] = shape(list[i]) end
	return t
end

local function same(a, b, label)
	check(#a == #b, ("%s: %d entries, not %d"):format(label, #a, #b))
	for i = 1, math.max(#a, #b) do
		if a[i] ~= b[i] then
			check(false, ("%s: entry %d is [%s], not [%s]"):format(label, i, tostring(a[i]), tostring(b[i])))
			return
		end
	end
end

------------------------------------------------------------------------
-- login: one login migrates the old arrays
------------------------------------------------------------------------
if phase == "login" then
	local state = rawState(loadRaw(os.getenv("PSS_SV_IN")))
	local want, kept = expected(state)
	local list = M.PSS_List()
	check(type(list) == "table", "M.PSS_List() is not a table")
	local before = {}
	for i, e in ipairs(kept) do before[i] = shape(e) end
	same(listShapes(list), before, "migrated list")
	sparse(list, "migrated")
	noRetired("after one login")
	sameCounters(want, "counters")
	check(M.PSS_PlayerCount() == #list, "M.PSS_PlayerCount is not the list length")
	-- the lookup follows the records
	for i = 1, #list do
		if (list[i].kind or "player") == "player" then
			check(M.hasGlobalIgnored(list[i].name) > 0, "a listed player is not found: " .. tostring(list[i].name))
		end
	end
	-- plant fields a newer version could have written
	if #list == 0 then M.PSS_ImportListEntry("Plantee-Realm", "", "", "player") end
	list = M.PSS_List()
	list[1].newerField = "keep me"
	list[1].newerTable = { 1, 2, 3 }
	print(fail == 0 and "PASS list records login" or ("FAIL list records login: " .. fail))
	return
end

------------------------------------------------------------------------
-- again: the next login changes nothing
------------------------------------------------------------------------
if phase == "again" then
	local env = loadRaw(os.getenv("PSS_SV_IN"))
	local state = rawState(env)
	check(#state.retired == 0, "the saved file still holds " .. table.concat(state.retired, ", "))
	local want = expected(state)
	local list = M.PSS_List()
	local saved = (env.PSS_PlayersDB or {}).list or (env.PourSocialScoreDB or {}).list or {}
	check(#list == want.list, ("%d entries, the file holds %d"):format(#list, want.list))
	check(H.serialize(list) == H.serialize(saved), "a second login changed the list")
	check(want.listDuplicates == 0, "duplicates in the saved list")
	sparse(list, "second login")
	noRetired("second login")
	sameCounters(want, "second login counters")
	if #list > 0 then
		check(list[1].newerField == "keep me", "an unknown string field was lost")
		check(type(list[1].newerTable) == "table" and #list[1].newerTable == 3, "an unknown table field was lost")
	end
	print(fail == 0 and "PASS list records again" or ("FAIL list records again: " .. fail))
	return
end

------------------------------------------------------------------------
-- drift: changes in the middle leave every other entry alone
------------------------------------------------------------------------
local History = M.PSS_History
M.PSS_Need("Libraries")
local function find(name, kind)
	local list = M.PSS_List()
	for i = 1, #list do
		if list[i].name == name and (list[i].kind or "player") == kind then return i end
	end
	return nil
end
local function lines(owner) return owner and History.CountFor(owner) or 0 end

-- what was there before (the save's own entries): untouched at the end
local start = listShapes(M.PSS_List())
local startN = #start

-- seven entries of three kinds; Dzdup and Dzsix are one name as two kinds
local plan = {
	{ "Dzone-Realm", "player", "Alliance", "note one", 11, "02 Sep 2026", { "Me@1" } },
	{ "Dzwolf", "npc", "Horde", "wolf note", 0, "03 Sep 2026" },
	{ "Dzrealm", "server", "", "", 0, "04 Sep 2026" },
	{ "Dzdup-Realm", "player", "", "player twin", 3, "05 Sep 2026", { "Me@2", "Him@4" } },
	{ "Dzdup-Realm", "npc", "Horde", "npc twin", 0, "06 Sep 2026" },
	{ "Dzsix-Realm", "player", "", "", 0, "07 Sep 2026" },
	{ "Dzsix-Realm", "server", "Alliance", "server twin", 9, "08 Sep 2026", { "Me@9" } },
}
local want = {}	-- "kind:name" -> expected shape
local order = {}
for _, p in ipairs(plan) do
	local i = M.PSS_ImportListEntry(p[1], p[3], p[4], p[2], p[6], p[5])
	check(i == #M.PSS_List() and M.PSS_EntryName(i) == p[1], "add: " .. p[1] .. " not at the end")
	for _, s in ipairs(p[7] or {}) do M.PSS_EntryAddSync(i, s) end
	local key = p[2] .. ":" .. p[1]
	want[key] = shape(M.PSS_List()[i])
	order[#order + 1] = key
end
local function verify(label)
	local list = M.PSS_List()
	-- the save's own entries, then ours in order, nothing else
	local at = startN
	for i = 1, startN do
		if shape(list[i]) ~= start[i] then check(false, label .. ": an entry of the save moved or changed at " .. i) break end
	end
	for _, key in ipairs(order) do
		local kind, name = key:match("^(%w+):(.*)$")
		local i = find(name, kind)
		if want[key] then
			check(i ~= nil, label .. ": " .. key .. " is gone")
			if i then
				check(i > at, label .. ": " .. key .. " is out of order")
				at = i
				check(shape(list[i]) == want[key], ("%s: %s drifted: [%s], not [%s]"):format(label, key, shape(list[i]), want[key]))
			end
		else
			check(i == nil, label .. ": " .. key .. " is still listed")
		end
	end
	local n = startN
	for _, key in ipairs(order) do if want[key] then n = n + 1 end end
	check(#list == n, ("%s: %d entries, not %d"):format(label, #list, n))
	sparse(list, label)
	local r = M.PSS_Validate()
	check(#r.problems == 0, label .. ": " .. table.concat(r.problems, "; "))
	check(r.n.list == n and r.n.listDuplicates == 0, label .. ": the counters say " .. tostring(r.n.list))
end
verify("added")

-- removal in the middle: an NPC, the twin player, a server
M.PSS_RemoveListEntryAt(find("Dzwolf", "npc"))
want["npc:Dzwolf"] = nil
verify("after removing the NPC")
M.PSS_DelIgnore(find("Dzdup-Realm", "player"), true)
want["player:Dzdup-Realm"] = nil
verify("after removing the player twin")
check(find("Dzdup-Realm", "npc") ~= nil, "removing the player took the NPC of the same name")
M.PSS_RemoveListEntryAt(find("Dzsix-Realm", "server"))
want["server:Dzsix-Realm"] = nil
verify("after removing the server twin")
check(find("Dzsix-Realm", "player") ~= nil, "removing the server took the player of the same name")

-- an add after the removals goes to the end and nothing shifts
local i = M.PSS_ImportListEntry("Dzlate-Realm", "Horde", "late note", "player", "10 Sep 2026", 2)
M.PSS_EntryAddSync(i, "Me@5")
want["player:Dzlate-Realm"] = shape(M.PSS_List()[i])
order[#order + 1] = "player:Dzlate-Realm"
verify("after a late add")
-- and the first and the last of ours out
M.PSS_DelIgnore(find("Dzone-Realm", "player"), true)
want["player:Dzone-Realm"] = nil
verify("after removing the first")
M.PSS_DelIgnore(find("Dzlate-Realm", "player"), true)
want["player:Dzlate-Realm"] = nil
verify("after removing the last")

-- the setters write sparse and keep what they do not know
local k = find("Dzsix-Realm", "player")
M.PSS_List()[k].newerField = "keep"
M.PSS_SetEntryNote(k, "x"); M.PSS_SetEntryNote(k, "")
M.PSS_SetEntryExp(k, 7); M.PSS_SetEntryExp(k, 0)
M.PSS_SetEntryFaction(k, "Horde"); M.PSS_SetEntryFaction(k, "")
M.PSS_SetEntryDate(k, "09 Sep 2026")
M.PSS_SetNote(k, "viaSetNote"); M.PSS_SetNote(k, "")
M.PSS_SetExpiry(k, 4); M.PSS_SetExpiry(k, 0)
local e = M.PSS_List()[k]
check(e.note == nil and e.exp == nil and e.faction == nil, "a setter stored an empty value")
check(e.date == "09 Sep 2026" and e.newerField == "keep" and e.name == "Dzsix-Realm", "a setter lost the date, the name or an unknown field")
M.PSS_SetEntryExp(k, 7)
M.PSS_SetEntryNote(k, "kept note")
check(M.PSS_List()[k].exp == 7 and M.PSS_List()[k].note == "kept note" and M.PSS_EntryKind(k) == "player", "a setter did not store its value")
M.PSS_SetEntryNote(k, "")
M.PSS_SetEntryExp(k, 0)
-- the sync table is made on demand and dropped nowhere but by the entry
check(M.PSS_EntrySync(k) == nil, "an entry without sync has a sync table")
M.PSS_EntryAddSync(k, "Me@1")
check(M.PSS_EntrySync(k)[1] == "Me@1" and #M.PSS_EntrySync(k) == 1, "EntryAddSync did not make the table")
want["player:Dzsix-Realm"] = shape(M.PSS_List()[k])
-- (the planted field stays outside the compared shape)
verify("after the setters")

-- removing a listed player clears their record and history; an NPC of the
-- same name (Dzdup, still listed) is not a player and clears nothing
M.PSS_ImportListEntry("Dzgone-Realm", "", "", "player")
M.PSS_RecordPlayerBlock("Dzgone-Realm", "CHAT_MSG_WHISPER", "hello", nil, "whisper")
local owner = M.PSS_PlayerHistoryKey("Dzgone-Realm")
check(M.PSS_GetPlayerRecord("Dzgone-Realm") ~= nil, "removal: the player has no record before")
check(lines(owner) == 1, "removal: the player has no line before")
M.PSS_ImportListEntry("Dzgone-Realm", "", "", "npc")
M.PSS_RemoveListEntryAt(find("Dzgone-Realm", "npc"))
check(M.PSS_GetPlayerRecord("Dzgone-Realm") ~= nil and lines(owner) == 1, "removing the NPC of the same name cleared the player")
M.PSS_DelIgnore(find("Dzgone-Realm", "player"), true)
check(find("Dzgone-Realm", "player") == nil, "removal: the player is still listed")
check(M.PSS_GetPlayerRecord("Dzgone-Realm") == nil, "removal: the player record is kept")
check(lines(History.PlayerKey("Dzgone-Realm")) == 0, "removal: the player's lines are kept")
verify("after the removal check")

-- the retired arrays do not come back
noRetired("after the drift test")

print(fail == 0 and "PASS list records drift" or ("FAIL list records drift: " .. fail))
