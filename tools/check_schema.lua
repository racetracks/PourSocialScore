-- check_schema.lua
-- The schema map (PourSocialScore/PSS_Schema.lua, core uplift U3): every
-- field PSS saves is listed there, so a newer or older version knows it.
-- Lua 5.1, from the repo root.
--
--   lua5.1 tools/check_schema.lua
--     (tools/check_rules.sh) every top-level key the code writes is in the
--     map: LAYOUT (PSS_SavedData.lua), an option (PSS_Options.lua) or the
--     map's "core" keys; every record kind parses
--   lua5.1 tools/check_schema.lua --saves <file> [<file> ...]
--     (tools/harness/validate_all.sh) every field of every record in those
--     saved files is in the map (its fields or its "old" fields). Fields a
--     test planted on purpose start with "newer".
local segments = dofile((arg[0]:match("^(.*[/\\])") or "") .. "lua_segments.lua")

local function read(path)
	local fh = assert(io.open(path, "rb"), path)
	local s = fh:read("*a")
	fh:close()
	return s
end

PourSocialScore_NS = { M = {} }
dofile("PourSocialScore/PSS_Schema.lua")
local SCHEMA = PourSocialScore_NS.M.PSS_SCHEMA

-- kind -> { field = true } (its fields and its old fields)
local function fields(kind)
	local t = {}
	for _, k in ipairs({ kind, kind .. "Old" }) do
		for word in (SCHEMA[k] or ""):gmatch("%S+") do
			local name = word:match("^([%a_][%w_]*)")
			assert(name, "PSS_Schema.lua: " .. k .. ": bad entry " .. word)
			t[name] = true
		end
	end
	return t
end

local problems = 0
local function problem(fmt, ...)
	print(fmt:format(...))
	problems = problems + 1
end

-- the top-level keys: LAYOUT, the options and the core keys
local top = fields("core")
local src = read("PourSocialScore/PSS_SavedData.lua")
local layout = src:match("local LAYOUT = (%b{})")
assert(layout, "PSS_SavedData.lua: no LAYOUT")
for key in layout:gmatch('"([%a_][%w_]*)"') do top[key] = true end
-- the owned keys (<key>Of, PSS_Entity.lua) are Options keys too
for word in (SCHEMA.owned or ""):gmatch("%S+") do top[word:match("^[%a_][%w_]*")] = true end
for key in read("PourSocialScore/PSS_Options.lua"):gmatch('{ key = "([%a_][%w_]*)"') do top[key] = true end

if arg[1] ~= "--saves" then
	-- every write of PourSocialScoreDB.<key> (or a local db / sv / t that is
	-- PourSocialScoreDB) in the folders that save data
	local files = {}
	for _, dir in ipairs({ "PourSocialScore", "PourSocialScore_Libraries", "PourSocialScore_Logging" }) do
		local p = io.popen('ls "' .. dir .. '"/*.lua')
		for f in p:lines() do files[#files + 1] = f end
		p:close()
	end
	for _, path in ipairs(files) do
		local code, line = {}, 1
		local text = read(path)
		local aliases = { PourSocialScoreDB = true }
		for name in text:gmatch("local%s+([%a_][%w_]*)%s*=%s*PourSocialScoreDB%s*\n") do aliases[name] = true end
		for name in text:gmatch("local%s+([%a_][%w_]*)%s*=%s*PourSocialScoreDB%s+or%s") do aliases[name] = true end
		for _, seg in ipairs(segments(text)) do
			if seg.kind == "code" then
				for pre, var, key in seg.text:gmatch("()([%a_][%w_]*)%.([%a_][%w_]*)%s*=[^=]") do
					if aliases[var] and seg.text:sub(pre - 1, pre - 1) ~= "." and not top[key] then
						local at = line + select(2, seg.text:sub(1, pre):gsub("\n", ""))
						problem("%s:%d: %s.%s is saved but not in the schema map (PSS_Schema.lua)", path, at, var, key)
					end
				end
			end
			if seg.kind == "code" or seg.kind == "string" then code[#code + 1] = seg.text end
			line = line + select(2, seg.text:gsub("\n", ""))
		end
		-- rawset(db, "key", ...): the code with its strings, without comments
		for key in table.concat(code):gmatch('rawset%(%s*[%a_][%w_]*%s*,%s*"([%a_][%w_]*)"') do
			if not top[key] then problem("%s: rawset of %s, which is not in the schema map (PSS_Schema.lua)", path, key) end
		end
	end
	if problems == 0 then print("schema: every saved top-level key is in the map") end
	os.exit(problems == 0 and 0 or 1)
end

------------------------------------------------------------------------
-- --saves: walk the saved files
------------------------------------------------------------------------
local KIND = {}
for _, k in ipairs({ "upgrade", "player", "guild", "member", "block", "counts", "filterStat", "builtinStat", "line", "logGroup", "ent" }) do
	KIND[k] = fields(k)
end
for _, c in ipairs({ "guildChat", "unknown" }) do KIND.counts[c] = true end

-- keys the harness's own checks plant
local HARNESS = { forgetTestName = true }

local function check(t, kind, where)
	if type(t) ~= "table" then return end
	local known = KIND[kind]
	for k in pairs(t) do
		if type(k) == "string" and not known[k] and not k:match("^newer") and not HARNESS[k] then
			problem("%s: %s field %s is not in the schema map", where, kind, k)
		end
	end
end

local function counts(c, where) check(c, "counts", where) end

local function lines(list, where)
	if type(list) ~= "table" then return end
	for i = 1, #list do
		if type(list[i]) == "table" then check(list[i], "line", where) end
	end
end

local STORES = { "PourSocialScoreDB", "PSS_CharDB", "PSS_OptionsDB", "PSS_PlayersDB", "PSS_GuildsDB", "PSS_RulesDB", "PSS_CountsDB", "PSS_LoggingDB" }
for i = 2, #arg do
	local path = arg[i]
	for _, g in ipairs(STORES) do _G[g] = nil end
	if not pcall(dofile, path) then problem("%s: not a saved file", path) end
	for _, g in ipairs(STORES) do
		local t = _G[g]
		if type(t) == "table" then
			for k in pairs(t) do
				if type(k) == "string" and not top[k] and not k:match("^newer") and not HARNESS[k] then
					problem("%s: %s.%s is not in the schema map", path, g, k)
				end
			end
		end
	end
	local db = PourSocialScoreDB or {}
	local P, G, C, Lg = PSS_PlayersDB or db, PSS_GuildsDB or db, PSS_CountsDB or db, PSS_LoggingDB or db
	check(db.upgrade, "upgrade", path)
	if type(PSS_OptionsDB) == "table" then check(PSS_OptionsDB.ent, "ent", path .. " ent") end
	for key, p in pairs(type(P.playerData) == "table" and P.playerData or {}) do
		check(p, "player", path .. " player " .. tostring(key))
		if type(p) == "table" then counts(p.blockCounts, path) end
	end
	for gkey, g in pairs(type(G.guildData) == "table" and G.guildData or {}) do
		local w = path .. " guild " .. tostring(gkey)
		check(g, "guild", w)
		if type(g) == "table" then
			check(g.block, "block", w)
			for mk, m in pairs(type(g.members) == "table" and g.members or {}) do
				check(m, "member", w .. " member " .. tostring(mk))
				if type(m) == "table" then
					check(m.block, "block", w)
					counts(m.blockCounts, w)
				end
			end
		end
	end
	for _, b in ipairs(type(C.filterBlocked) == "table" and C.filterBlocked or {}) do
		check(b, "filterStat", path .. " filterBlocked")
		if type(b) == "table" then counts(b.counts, path) end
	end
	for id, s in pairs(type(C.builtinStats) == "table" and C.builtinStats or {}) do
		check(s, "builtinStat", path .. " builtinStats " .. tostring(id))
		if type(s) == "table" and type(s.blocked) == "table" then counts(s.blocked.counts, path) end
	end
	local log = Lg.blockLog
	if type(log) == "table" then
		lines(log, path .. " blockLog")
		if log.v == 2 then
			for o, grp in pairs(log) do
				if type(grp) == "table" then check(grp, "logGroup", path .. " log group " .. tostring(o)) end
			end
		end
	end
	for o, l in pairs(type(Lg.blockKeep) == "table" and Lg.blockKeep or {}) do lines(l, path .. " blockKeep " .. tostring(o)) end
	lines(db.outbox, path .. " outbox")
end
if problems == 0 then print(("PASS schema (%d saves)"):format(#arg - 1)) end
os.exit(problems == 0 and 0 or 1)
