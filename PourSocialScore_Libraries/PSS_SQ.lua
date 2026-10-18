------------------------------------------------------------------------
-- POUR SOCIAL SCORE - SAVED AND SYSTEM QUERIES, ALERTS (search-helper,
-- STP-00248 and STP-00249, SAV-00080).
--   M.PSS_SQ_SYSTEM       the system queries (code, never saved): { id, name, scope, q, view, owner }
--   sq.list { scope }     id name scope flags query time broken (saved, then system)
--   sq.get { id }  sq.put { id?, name, scope, query, time, flags } -> id  sq.del { id }  sq.system { scope }
--   M.PSS_SqAlert(id, on) the alert flag: a matching line prints one chat line, at most once a minute
-- Saved as PSS_OptionsDB.sqSaved = "1;<next id>\n" .. records, a record
-- C.list({ id, name, scope, flags, query, time }, "\t"); caps 200 records,
-- 512 bytes a query, 48 a name. A query that no longer compiles is kept and
-- listed broken, never run, never deleted. A string this build cannot read is
-- moved whole to sqSavedBad (once, noted integrity); a newer layout (v above
-- 1) is kept untouched and nothing is written over it. An alert is a trigger
-- row on the signal "@ix.<index>"; while one exists M.PSS_IxWaiting[index]
-- is true, so a put signals (and only then). No timer: the minute is checked
-- when the alert runs. Loaded with Libraries.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, pairs, ipairs, tonumber, tostring, error = type, pairs, ipairs, tonumber, tostring, error
local find, match, gmatch, sub = string.find, string.match, string.gmatch, string.sub
local concat, sort = table.concat, table.sort

local C = M.PSS_Codec
local CAP = { records = 200, query = 512, name = 48 }
M.PSS_SQ_CAPS = CAP
local SCOPES = { any = true, player = true, guild = true, filter = true, journal = true, bagcat = true }
local RATE = 60

M.PSS_SQ_SYSTEM = {
	{ id = "log.lines", name = "Lines of one owner", scope = "player", q = "index=log owner=$owner | head 200", view = "events", owner = "social-manager" },
	{ id = "log.bytype", name = "Blocks by type", scope = "player", q = "index=counts owner=$owner | stats sum(total) by type", view = "table", owner = "social-manager" },
	{ id = "log.24h", name = "The last 24 hours", scope = "any", q = "index=log earliest=-24h | stats count by cat", view = "table", owner = "social-manager" },
	{ id = "log.byday", name = "Lines a day", scope = "player", q = "index=log owner=$owner | timechart span=1d count", view = "series", owner = "social-manager" },
	{ id = "log.hours", name = "By weekday and hour", scope = "any", q = "index=log | stats count by weekday, hour", view = "matrix", owner = "social-manager" },
	{ id = "filters.top", name = "Busiest chat filters", scope = "filter", q = "index=counts kind=filter type=total | sort -total | head 10", view = "table", owner = "social-manager" },
	{ id = "log.cmp", name = "What PSS did", scope = "any", q = "index=log st=act.* | head 200", view = "events", owner = "search-helper" },
	{ id = "pss.recent", name = "PSS's own lines", scope = "any", q = "index=pss | head 100", view = "events", owner = "search-helper" },
	{ id = "wh.holders", name = "Who holds an item", scope = "any", q = "index=inv item=$item | stats sum(count) by ent", view = "table", owner = "warehouse-helper" },
	{ id = "wh.gold", name = "Gold by holder", scope = "any", q = "index=gold | sort -copper", view = "table", owner = "money-helper" },
}

local store, storeRaw		-- the parsed records and the string they came from
local newerKept = false

local function raw() return type(PourSocialScoreDB) == "table" and PourSocialScoreDB.sqSaved or nil end

local function quarantine(s, why)
	if PourSocialScoreDB.sqSavedBad == nil then PourSocialScoreDB.sqSavedBad = s end
	PourSocialScoreDB.sqSaved = nil
	if M.PSS_ErrNote then M.PSS_ErrNote("integrity", "sq.saved", why) end
end

local function load()
	local s = raw()
	if store and storeRaw == s then return store end
	store, storeRaw, newerKept = { next = 1, list = {} }, s, false
	if s == nil then return store end
	if type(s) ~= "string" then quarantine(s, "the saved queries are not text") store, storeRaw = { next = 1, list = {} }, nil return store end
	local v, nextId, body = match(s, "^(%d+);(%d+)\n?(.*)$")
	if not v then quarantine(s, "the saved queries have no header") store, storeRaw = { next = 1, list = {} }, nil return store end
	if tonumber(v) > 1 then newerKept = true return store end		-- a newer layout: kept, read as nothing
	store.next = tonumber(nextId)
	local seen = {}
	for line in gmatch(body, "[^\n]+") do
		local f = C.unlist(line, "\t")
		local id = tonumber(f[1])
		if #f ~= 6 or not id or seen[id] or id >= store.next then
			quarantine(s, "a saved query record is cut or wrong")
			store, storeRaw = { next = 1, list = {} }, nil
			return store
		end
		seen[id] = true
		store.list[#store.list + 1] = { id = id, name = f[2], scope = f[3], flags = f[4], query = f[5], time = f[6] }
	end
	return store
end

local function save()
	local out = { "1;" .. store.next }
	for _, r in ipairs(store.list) do out[#out + 1] = C.list({ r.id, r.name, r.scope, r.flags, r.query, r.time }, "\t") end
	local s = #store.list == 0 and store.next == 1 and nil or concat(out, "\n")
	PourSocialScoreDB.sqSaved = s
	storeRaw = s
end

local broken = {}
local function isBroken(q)
	local b = broken[q]
	if b == nil then b = not M.PSS_Psql.compile(q); broken[q] = b end
	return b
end

local COLS = { "id", "name", "scope", "flags", "query", "time", "broken" }

local function find1(id)
	for i, r in ipairs(load().list) do if r.id == id then return r, i end end
end

local function arg(input, k)
	if type(input) ~= "table" then return nil end
	if input[k] ~= nil then return input[k] end
	local c = input.cols and M.PSS_SetCol(input, k)
	return c and input[1] and input[1][c] or nil
end

M.PSS_Provide("sq.list", function(input)
	local scope = arg(input, "scope")
	local out = { cols = COLS, n = 0 }
	for _, r in ipairs(load().list) do
		if not scope or scope == "any" or r.scope == scope then
			out.n = out.n + 1
			out[out.n] = { r.id, r.name, r.scope, r.flags, r.query, r.time, isBroken(r.query) }
		end
	end
	return out
end, { accepts = { "scope" }, returns = COLS, doc = "the saved queries", cost = "O(records)", writes = false, onError = "empty" })

M.PSS_Provide("sq.get", function(input)
	local r = find1(tonumber(arg(input, "id") or arg(input, "key")))
	local out = { cols = COLS, n = 0 }
	if r then out.n, out[1] = 1, { r.id, r.name, r.scope, r.flags, r.query, r.time, isBroken(r.query) } end
	return out
end, { accepts = { "id" }, returns = COLS, doc = "one saved query", writes = false })

local function checkFlags(f)
	if type(f) ~= "string" then return "" end
	if find(f, "[^hap]") then error("arg: flags are h, a and p", 0) end
	return f
end

M.PSS_Provide("sq.put", function(input)
	local s = load()
	if newerKept then error("newer: the saved queries were written by a newer version and are kept as they are", 0) end
	local id = tonumber(arg(input, "id"))
	local name, scope, query = arg(input, "name"), arg(input, "scope") or "any", arg(input, "query")
	local time, flags = arg(input, "time") or "", checkFlags(arg(input, "flags"))
	if M.PSS_IsSecret(name) or M.PSS_IsSecret(query) then error("secret: a secret value", 0) end
	if type(name) ~= "string" or name == "" then error("arg: a saved query needs a name", 0) end
	if #name > CAP.name then error("cap: a name is at most " .. CAP.name .. " bytes", 0) end
	if type(query) ~= "string" or #query > CAP.query then error("cap: a query is at most " .. CAP.query .. " bytes", 0) end
	if not SCOPES[scope] then error("arg: scope is any, player, guild, filter, journal or bagcat", 0) end
	local ok, perr = M.PSS_Psql.compile(query)
	if not ok then error("parse: " .. tostring(perr.msg) .. " (at " .. tostring(perr.pos) .. ")", 0) end
	local r = id and find1(id)
	if not r then
		if #s.list >= CAP.records then error("cap: at most " .. CAP.records .. " saved queries", 0) end
		r = { id = s.next }
		s.next = s.next + 1
		s.list[#s.list + 1] = r
	end
	local wasAlert = r.flags and find(r.flags, "a", 1, true)
	r.name, r.scope, r.query, r.time, r.flags = name, scope, query, time, flags
	broken[query] = nil
	save()
	if wasAlert and not find(flags, "a", 1, true) then M.PSS_SqAlert(r.id, false)
	elseif find(flags, "a", 1, true) then M.PSS_SqAlert(r.id, true) end
	return { cols = { "id" }, n = 1, { r.id } }
end, { accepts = { "name", "scope", "query", "time", "flags" }, returns = { "id" }, doc = "saves a query (a new one or by id)", writes = true })

M.PSS_Provide("sq.del", function(input)
	local id = tonumber(arg(input, "id") or arg(input, "key"))
	local r, i = find1(id)
	if r then
		M.PSS_SqAlert(id, false)
		table.remove(store.list, i)
		save()
	end
	return { cols = { "id", "done" }, n = 1, { id, r ~= nil } }
end, { accepts = { "id" }, returns = { "id", "done" }, doc = "deletes a saved query", writes = true })

M.PSS_Provide("sq.system", function(input)
	local scope = arg(input, "scope")
	local out = { cols = { "id", "name", "scope", "query", "view", "owner" }, n = 0 }
	for _, r in ipairs(M.PSS_SQ_SYSTEM) do
		if not scope or scope == "any" or r.scope == scope then
			out.n = out.n + 1
			out[out.n] = { r.id, r.name, r.scope, r.q, r.view, r.owner }
		end
	end
	return out
end, { accepts = { "scope" }, returns = { "id", "name", "scope", "query", "view", "owner" }, doc = "the system queries", writes = false })

------------------------------------------------------------------------
-- Alerts
------------------------------------------------------------------------
local alerts = {}		-- [id] = { index, last, printed }
local waiting = {}		-- [index] = how many alerts wait on it
M.PSS_SqAlerts = alerts

local function run(id)
	local a, r = alerts[id], find1(id)
	if not a or not r then return end
	local now = GetServerTime and GetServerTime() or 0
	local set = M.PSS_Search(r.query, { from = a.last, load = false })
	a.last = now + 1
	if set and set.n > 0 and now - (a.printed or -RATE) >= RATE then
		a.printed = now
		M.ShowMsg("Spyglass alert |cffffff00" .. tostring(r.name) .. "|r: " .. set.n .. (set.n == 1 and " new line" or " new lines") .. " (/pss q " .. r.query .. ")")
	end
end

function M.PSS_SqAlert(id, on)
	id = tonumber(id)
	local r = id and find1(id)
	if on then
		if not r then return nil, "arg: no saved query " .. tostring(id) end
		if alerts[id] then return true end
		local plan = M.PSS_Psql.compile(r.query)
		local names = plan and plan:indexNames()
		if not names or #names ~= 1 then return nil, "arg: an alert watches one index (index=<name>)" end
		local index = names[1]
		alerts[id] = { index = index, last = (GetServerTime and GetServerTime() or 0) }
		waiting[index] = (waiting[index] or 0) + 1
		M.PSS_IxWaiting[index] = true
		M.PSS_Want({ id = "sq.alert." .. id, class = "coalesce", signal = "@ix." .. index, fn = function() run(id) end })
		if not find(r.flags or "", "a", 1, true) then r.flags = (r.flags or "") .. "a"; save() end
		return true
	end
	local a = alerts[id]
	if a then
		alerts[id] = nil
		M.PSS_Unwant("sq.alert." .. id)
		waiting[a.index] = (waiting[a.index] or 1) - 1
		if waiting[a.index] <= 0 then waiting[a.index] = nil; M.PSS_IxWaiting[a.index] = nil end
	end
	if r and find(r.flags or "", "a", 1, true) then r.flags = r.flags:gsub("a", ""); save() end
	return true
end

-- the saved alerts are armed when Libraries loads (they are off unless the player set them)
for _, r in ipairs(load().list) do
	if find(r.flags or "", "a", 1, true) and not isBroken(r.query) then M.PSS_SqAlert(r.id, true) end
end

------------------------------------------------------------------------
-- The sq index
------------------------------------------------------------------------
M.PSS_IxDeclare({
	name = "sq", kind = "state", owner = "search-helper", residency = 0,
	fields = { { "st", "k", "sq.user or sq.system" }, { "id", "s", "the query id" }, { "name", "s", "its name" }, { "scope", "k", "where it is offered" },
		{ "flags", "s", "h hidden, a alert, p pinned" }, { "query", "s", "the PSQL text" }, { "time", "s", "its time range" }, { "broken", "b", "no longer compiles" } },
	pushdown = { "st" }, schemaKeys = { "options.sqSaved", "options.sqSavedBad" },
	doc = "the saved and system queries",
	newer = function() load() return newerKept end,
	scan = function(pd, emit)
		local r, n = {}, 0
		if not pd.st or pd.st["sq.user"] then
			for _, x in ipairs(load().list) do
				r.st, r.id, r.name, r.scope, r.flags, r.query, r.time = "sq.user", tostring(x.id), x.name, x.scope, x.flags, x.query, x.time
				r.broken = isBroken(x.query) and 1 or nil
				n = n + 1
				if emit(r) == false then return n end
			end
		end
		if not pd.st or pd.st["sq.system"] then
			for _, x in ipairs(M.PSS_SQ_SYSTEM) do
				r.st, r.id, r.name, r.scope, r.flags, r.query, r.time, r.broken = "sq.system", x.id, x.name, x.scope, "", x.q, "", nil
				n = n + 1
				if emit(r) == false then return n end
			end
		end
		return n
	end,
})
