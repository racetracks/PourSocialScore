-- PSS_BuildManaged.lua
-- Builds PourSocialScore's managed / default guild lists from OlympusMute
-- SavedVariables (Olympus.lua, variable OlympusDB). Two files (3.0):
--   PourSocialScore_Communities/PSS_GuildIgnore_Managed.lua  the member lists
--     and their lookup index (the on-demand Communities addon)
--   PourSocialScore/PSS_Communities.lua  the manifest the core keeps: each
--     group's rule, and each guild's name and member count
--
-- Usage (Lua 5.1, e.g. lua5.1 or luajit), from the repo root:
--   lua PSS_BuildManaged.lua <path to Olympus.lua> [data out] [manifest out]
--   lua PSS_BuildManaged.lua --reindex <data file> [data out] [manifest out]
-- The outputs default to the two files above.
--
-- --reindex rewrites an existing data file (any format, e.g. one that was
-- merged by hand, or a 2.0 single file) in the current format with a fresh
-- lookup index, and writes the manifest to match. Run it after every hand
-- merge and whenever PSS_CanonPlayer's rules change.
--
-- One file = one influencer group. To add more groups later, run this per
-- source file and merge the `groups` entries, giving each a unique id
-- (PSSG0001, PSSG0002, ...) that is never reused.
--
-- Members taken from each guild's census: leader, officers, top players,
-- the reporter and every name in the officer vouch lists. Characters listed
-- in OlympusDB.myCharacters (the account that produced the file) are left out.
-- A character found under several guilds goes to the guild with the newest
-- census (field t).
--
-- The file also carries the lookup index (canon key -> guild number and
-- position), so the game does not have to build it at login.

local GROUP = {
	key		= "olympus",
	name = "Managed Communities - Asmongold",
	rule = "Managed Communities - Asmongold",
	filter = "InfluencerGuild=Olympus",
	id		= "PSSG0001",
}

------------------------------------------------------------------------
-- Lookup key. MUST match M.PSS_CanonPlayer in PSS_ChatBlock.lua exactly
-- (every shipped name has a realm, so the own-realm case never applies).
------------------------------------------------------------------------
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function canonPlayer(name)
	name = trim(name)
	local base, realm = name:match("^([^%-]+)%-(.+)$")
	assert(base, "shipped name without a realm: " .. name)
	base = trim(base):gsub("%s+", " ")
	realm = realm:gsub("[%s%-']", "")
	return (base .. "-" .. realm):lower()
end

------------------------------------------------------------------------
-- The game's string.lower also lowers non-ASCII letters ("\195\141nsane" ->
-- "\195\173nsane"), plain Lua only lowers A-Z. Names with such letters get a
-- second index key in the game's spelling. UPPER_RANGES: { first, last,
-- delta, step } code point runs (Latin, Greek, Cyrillic, Armenian, Latin
-- Extended Additional, Greek Extended), from Unicode simple lowercase.
------------------------------------------------------------------------
local UPPER_RANGES = {
	{ 0xC0, 0xD6, 32, 1 }, { 0xD8, 0xDE, 32, 1 }, { 0x100, 0x12E, 1, 2 }, { 0x132, 0x136, 1, 2 },
	{ 0x139, 0x147, 1, 2 }, { 0x14A, 0x176, 1, 2 }, { 0x178, 0x178, -121, 1 }, { 0x179, 0x17D, 1, 2 },
	{ 0x181, 0x181, 210, 1 }, { 0x182, 0x184, 1, 2 }, { 0x186, 0x186, 206, 1 },
	{ 0x187, 0x187, 1, 1 }, { 0x189, 0x18A, 205, 1 }, { 0x18B, 0x18B, 1, 1 }, { 0x18E, 0x18E, 79, 1 },
	{ 0x18F, 0x18F, 202, 1 }, { 0x190, 0x190, 203, 1 }, { 0x191, 0x191, 1, 1 },
	{ 0x193, 0x193, 205, 1 }, { 0x194, 0x194, 207, 1 }, { 0x196, 0x196, 211, 1 },
	{ 0x197, 0x197, 209, 1 }, { 0x198, 0x198, 1, 1 }, { 0x19C, 0x19C, 211, 1 },
	{ 0x19D, 0x19D, 213, 1 }, { 0x19F, 0x19F, 214, 1 }, { 0x1A0, 0x1A4, 1, 2 },
	{ 0x1A6, 0x1A6, 218, 1 }, { 0x1A7, 0x1A7, 1, 1 }, { 0x1A9, 0x1A9, 218, 1 },
	{ 0x1AC, 0x1AC, 1, 1 }, { 0x1AE, 0x1AE, 218, 1 }, { 0x1AF, 0x1AF, 1, 1 },
	{ 0x1B1, 0x1B2, 217, 1 }, { 0x1B3, 0x1B5, 1, 2 }, { 0x1B7, 0x1B7, 219, 1 },
	{ 0x1B8, 0x1B8, 1, 1 }, { 0x1BC, 0x1BC, 1, 1 }, { 0x1C4, 0x1C4, 2, 1 }, { 0x1C5, 0x1C5, 1, 1 },
	{ 0x1C7, 0x1C7, 2, 1 }, { 0x1C8, 0x1C8, 1, 1 }, { 0x1CA, 0x1CA, 2, 1 }, { 0x1CB, 0x1DB, 1, 2 },
	{ 0x1DE, 0x1EE, 1, 2 }, { 0x1F1, 0x1F1, 2, 1 }, { 0x1F2, 0x1F4, 1, 2 }, { 0x1F6, 0x1F6, -97, 1 },
	{ 0x1F7, 0x1F7, -56, 1 }, { 0x1F8, 0x21E, 1, 2 }, { 0x220, 0x220, -130, 1 },
	{ 0x222, 0x232, 1, 2 }, { 0x23A, 0x23A, 10795, 1 }, { 0x23B, 0x23B, 1, 1 },
	{ 0x23D, 0x23D, -163, 1 }, { 0x23E, 0x23E, 10792, 1 }, { 0x241, 0x241, 1, 1 },
	{ 0x243, 0x243, -195, 1 }, { 0x244, 0x244, 69, 1 }, { 0x245, 0x245, 71, 1 },
	{ 0x246, 0x24E, 1, 2 }, { 0x370, 0x372, 1, 2 }, { 0x376, 0x376, 1, 1 }, { 0x37F, 0x37F, 116, 1 },
	{ 0x386, 0x386, 38, 1 }, { 0x388, 0x38A, 37, 1 }, { 0x38C, 0x38C, 64, 1 },
	{ 0x38E, 0x38F, 63, 1 }, { 0x391, 0x3A1, 32, 1 }, { 0x3A3, 0x3AB, 32, 1 }, { 0x3CF, 0x3CF, 8, 1 },
	{ 0x3D8, 0x3EE, 1, 2 }, { 0x3F4, 0x3F4, -60, 1 }, { 0x3F7, 0x3F7, 1, 1 }, { 0x3F9, 0x3F9, -7, 1 },
	{ 0x3FA, 0x3FA, 1, 1 }, { 0x3FD, 0x3FF, -130, 1 }, { 0x400, 0x40F, 80, 1 },
	{ 0x410, 0x42F, 32, 1 }, { 0x460, 0x480, 1, 2 }, { 0x48A, 0x4BE, 1, 2 }, { 0x4C0, 0x4C0, 15, 1 },
	{ 0x4C1, 0x4CD, 1, 2 }, { 0x4D0, 0x52E, 1, 2 }, { 0x531, 0x556, 48, 1 }, { 0x1E00, 0x1E94, 1, 2 },
	{ 0x1E9E, 0x1E9E, -7615, 1 }, { 0x1EA0, 0x1EFE, 1, 2 }, { 0x1F08, 0x1F0F, -8, 1 },
	{ 0x1F18, 0x1F1D, -8, 1 }, { 0x1F28, 0x1F2F, -8, 1 }, { 0x1F38, 0x1F3F, -8, 1 },
	{ 0x1F48, 0x1F4D, -8, 1 }, { 0x1F59, 0x1F5F, -8, 2 }, { 0x1F68, 0x1F6F, -8, 1 },
	{ 0x1F88, 0x1F8F, -8, 1 }, { 0x1F98, 0x1F9F, -8, 1 }, { 0x1FA8, 0x1FAF, -8, 1 },
	{ 0x1FB8, 0x1FB9, -8, 1 }, { 0x1FBA, 0x1FBB, -74, 1 }, { 0x1FBC, 0x1FBC, -9, 1 },
	{ 0x1FC8, 0x1FCB, -86, 1 }, { 0x1FCC, 0x1FCC, -9, 1 }, { 0x1FD8, 0x1FD9, -8, 1 },
	{ 0x1FDA, 0x1FDB, -100, 1 }, { 0x1FE8, 0x1FE9, -8, 1 }, { 0x1FEA, 0x1FEB, -112, 1 },
	{ 0x1FEC, 0x1FEC, -7, 1 }, { 0x1FF8, 0x1FF9, -128, 1 }, { 0x1FFA, 0x1FFB, -126, 1 },
	{ 0x1FFC, 0x1FFC, -9, 1 }
}

local function lowerCode(cp)
	for _, r in ipairs(UPPER_RANGES) do
		if cp >= r[1] and cp <= r[2] and (cp - r[1]) % r[4] == 0 then return cp + r[3] end
	end
	return cp
end

local function utf8Char(cp)
	if cp < 0x80 then return string.char(cp) end
	if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64) end
	return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

-- s:lower() plus non-ASCII letters (2 and 3 byte UTF-8 sequences)
local function gameLower(s)
	s = s:lower()
	if not s:find("[\192-\239]") then return s end
	return (s:gsub("[\192-\223][\128-\191]", function(c)
		local a, b = c:byte(1, 2)
		return utf8Char(lowerCode((a - 0xC0) * 64 + (b - 0x80)))
	end):gsub("[\224-\239][\128-\191][\128-\191]", function(c)
		local a, b, d = c:byte(1, 3)
		return utf8Char(lowerCode((a - 0xE0) * 4096 + (b - 0x80) * 64 + (d - 0x80)))
	end))
end

-- every index key for a name: plain Lua's and, when different, the game's
local function indexKeys(name)
	local ck = canonPlayer(name)
	local gk = gameLower(ck)
	if gk ~= ck then return ck, gk end
	return ck
end

-- Quoted Lua string, ASCII only: bytes 128-255 become decimal escapes
-- ("\195\169"), which Lua 5.1 reads back as the same bytes.
local function q(s)
	return (string.format("%q", s):gsub("[\128-\255]", function(c) return "\\" .. c:byte() end))
end
local function byLower(a, b) return a:lower() < b:lower() end

local DATA_OUT, MANIFEST_OUT = "PourSocialScore_Communities/PSS_GuildIgnore_Managed.lua", "PourSocialScore/PSS_Communities.lua"
local function save(path, lines)
	local fh = assert(io.open(path, "wb"))
	fh:write(table.concat(lines, "\n"), "\n")
	fh:close()
end

------------------------------------------------------------------------
-- Writer: group = { key, name, rule, filter, id }, members = { [guild] = { names } }
------------------------------------------------------------------------
local function write(group, members, notes, dataOut, manifestOut)
	-- guilds whose names differ only in case / outer spaces are one guild
	-- in game (normalizeGuild), so they are merged here
	local merged, byKey = {}, {}
	for g, list in pairs(members) do
		local key = trim(g):lower()
		local into = byKey[key]
		if not into then
			byKey[key] = g
			merged[g] = {}
			into = g
		end
		for _, n in ipairs(list) do table.insert(merged[into], n) end
	end
	members = merged
	local gl = {}
	for g in pairs(members) do gl[#gl + 1] = g end
	table.sort(gl, byLower)
	assert(#gl < 65536, "too many guilds")

	-- each character once per group: the first guild (sorted) keeps them
	local taken, total, dropped = {}, 0, 0
	local lists = {}
	for gi, g in ipairs(gl) do
		local src = members[g]
		table.sort(src, byLower)
		local list = {}
		for _, n in ipairs(src) do
			local ck, gk = indexKeys(n)
			if taken[ck] or (gk and taken[gk]) then
				dropped = dropped + 1
			else
				list[#list + 1] = n
				taken[ck] = gi * 65536 + #list
				if gk then taken[gk] = taken[ck] end
			end
		end
		assert(#list < 65536, "too many members in " .. g)
		lists[gi] = list
		total = total + #list
	end

	local head = ("\tkey = %s, name = %s, rule = %s, filter = %s, id = %s,"):format(q(group.key), q(group.name), q(group.rule), q(group.filter), q(group.id))

	-- the member lists and the index (PourSocialScore_Communities)
	local out = {}
	out[#out + 1] = "------------------------------------------------------------------------"
	out[#out + 1] = "-- POUR SOCIAL SCORE - MANAGED (DEFAULT) GUILD LISTS: MEMBERS"
	out[#out + 1] = "-- Generated by tools/PSS_BuildManaged.lua - do not edit by hand."
	out[#out + 1] = "-- Read only in game: your changes are stored as a delta in SavedVariables."
	out[#out + 1] = "-- Loaded on demand; the core keeps the manifest (PourSocialScore/PSS_Communities.lua)."
	for _, line in ipairs(notes or {}) do out[#out + 1] = line end
	out[#out + 1] = ("-- %d guilds, %d entries."):format(#gl, total)
	out[#out + 1] = "------------------------------------------------------------------------"
	out[#out + 1] = "local addon = PourSocialScore_NS"
	out[#out + 1] = "addon.MANAGED_DATA = addon.MANAGED_DATA or {}"
	out[#out + 1] = ("addon.MANAGED_DATA[%s] = {"):format(q(group.key))
	out[#out + 1] = head
	out[#out + 1] = "\t-- guilds[n] = { name = guild, members... } (same order as the manifest)"
	out[#out + 1] = "\tguilds = {"
	for gi, g in ipairs(gl) do
		local parts = { "name = " .. q(g) }
		for _, n in ipairs(lists[gi]) do parts[#parts + 1] = q(n) end
		out[#out + 1] = ("\t\t{ %s },"):format(table.concat(parts, ", "))
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "\t-- index[canon key] = guild number * 65536 + position in that guild"
	out[#out + 1] = "\tindex = {"
	for gi, list in ipairs(lists) do
		local parts = {}
		for pos, n in ipairs(list) do
			local ck, gk = indexKeys(n)
			parts[#parts + 1] = ("[%s] = %d"):format(q(ck), gi * 65536 + pos)
			if gk then parts[#parts + 1] = ("[%s] = %d"):format(q(gk), gi * 65536 + pos) end
		end
		if #parts > 0 then out[#out + 1] = ("\t\t%s,"):format(table.concat(parts, ", ")) end
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	save(dataOut or DATA_OUT, out)

	-- the manifest (core): rule, guild names and member counts
	local man = {}
	man[#man + 1] = "------------------------------------------------------------------------"
	man[#man + 1] = "-- POUR SOCIAL SCORE - MANAGED (DEFAULT) GUILD LISTS: MANIFEST"
	man[#man + 1] = "-- Generated by tools/PSS_BuildManaged.lua - do not edit by hand."
	man[#man + 1] = "-- The member lists are in PourSocialScore_Communities, loaded when the"
	man[#man + 1] = "-- group's rule is on or its members are needed (PSS_GuildIgnoreList.lua)."
	man[#man + 1] = ("-- %d guilds, %d entries."):format(#gl, total)
	man[#man + 1] = "------------------------------------------------------------------------"
	man[#man + 1] = "local addonName, addon = ..."
	man[#man + 1] = "addon.MANAGED = addon.MANAGED or { groups = {} }"
	man[#man + 1] = "addon.MANAGED.groups[#addon.MANAGED.groups + 1] = {"
	man[#man + 1] = head
	man[#man + 1] = "\t-- guilds[n] = { name = guild, n = shipped members }"
	man[#man + 1] = "\tguilds = {"
	for gi, g in ipairs(gl) do
		man[#man + 1] = ("\t\t{ name = %s, n = %d },"):format(q(g), #lists[gi])
	end
	man[#man + 1] = "\t},"
	man[#man + 1] = "}"
	save(manifestOut or MANIFEST_OUT, man)
	io.stderr:write(("%d guilds, %d members (%d duplicates dropped)\n"):format(#gl, total, dropped))
end

local function loadInto(path, env, ...)
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	chunk(...)
end

------------------------------------------------------------------------
-- --reindex: an existing managed file (old map format or current format)
------------------------------------------------------------------------
if arg and arg[1] == "--reindex" then
	local path = assert(arg[2], "usage: lua PSS_BuildManaged.lua --reindex <data file> [data out] [manifest out]")
	local addon = {}
	loadInto(path, { PourSocialScore_NS = addon }, "PourSocialScore", addon)
	-- 2.0 single file (addon.MANAGED.groups) or 3.0 data file (addon.MANAGED_DATA)
	local groups = addon.MANAGED and addon.MANAGED.groups or {}
	for _, d in pairs(addon.MANAGED_DATA or {}) do groups[#groups + 1] = d end
	assert(#groups == 1, "expected one group per file")
	local grp = groups[1]
	local members = {}
	for k, v in pairs(grp.guilds or {}) do
		if type(k) == "string" then
			members[k] = v						-- old format: [guild] = { names }
		else
			local list = {}
			for _, n in ipairs(v) do list[#list + 1] = n end
			members[v.name] = list				-- current format
		end
	end
	-- keep the merge notes from the old header
	local notes = {}
	for line in io.lines(path) do
		if line:match("^%-%- Merged") then notes[#notes + 1] = line end
	end
	write(grp, members, notes, arg[3], arg[4])
	return
end

------------------------------------------------------------------------
-- OlympusDB -> managed file
------------------------------------------------------------------------
local path = arg and arg[1]
assert(path, "usage: lua PSS_BuildManaged.lua <Olympus.lua>")
local env = {}
loadInto(path, env)
local DB = assert(env.OlympusDB, "no OlympusDB in " .. path)

local mine = {}
for k in pairs(DB.myCharacters or {}) do mine[k:lower()] = true end

local function full(name, realm)
	if type(name) ~= "string" or name == "" then return nil end
	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	if not name:find("-", 1, true) then
		if not realm or realm == "" then return nil end
		name = name .. "-" .. realm
	end
	if mine[name:lower()] then return nil end
	return name
end

local guildOf, guildT, guildNames = {}, {}, {}
local function add(guild, t, name)
	if not name then return end
	local key = name:lower()
	if not guildOf[key] or (t or 0) > (guildT[key] or 0) then
		guildOf[key], guildT[key] = { guild = guild, name = name }, t or 0
	end
end

for _, realmData in pairs(DB.realms or {}) do
	for gname, g in pairs(realmData.guilds or {}) do
		guildNames[gname] = true
		local realm = g.home or g.realm
		local t = tonumber(g.t) or 0
		add(gname, t, full(g.leader, realm))
		add(gname, t, full(g.reporterFull or g.reporter, realm))
		for _, o in ipairs(g.officers or {}) do add(gname, t, full(o.name, realm)) end
		for _, o in ipairs(g.top or {}) do add(gname, t, full(o.name, realm)) end
		for reporter, v in pairs(g.vouch or {}) do
			add(gname, t, full(reporter, realm))
			for n in pairs(type(v) == "table" and v.ranks or {}) do add(gname, t, full(n, realm)) end
		end
	end
	for gname in pairs(realmData.seen or {}) do guildNames[gname] = true end
end

local members = {}
for g in pairs(guildNames) do members[g] = {} end
for _, rec in pairs(guildOf) do table.insert(members[rec.guild], rec.name) end

write(GROUP, members, nil, arg[2], arg[3])
