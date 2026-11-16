local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M

-- TestKit store: PSS_TestKitDB (savedvariables.md sections 2 to 5, api-saved.md).
local type, pairs, ipairs, tonumber, tostring, error = type, pairs, ipairs, tonumber, tostring, error
local sub, find, time = string.sub, string.find, time
local tremove = table.remove
local pcall = pcall

local MAXRUNS, MAXSRC, MAXWHY, MAXGOT, MAXNOTE, MAXTEXT, MAXM, MAXCHECKS = 5, 64000, 200, 200, 500, 200, 20, 100
local NEWER = "PSS_TestKitDB is from a newer kit; results are read-only."
local SKINS = { [0] = "classic", [1] = "dark", [2] = "modern" }

local db, told
local envs = {}			-- [run id] = decoded envelope, or false when it does not decode (session cache)

local function cut(s, n)
	s = tostring(s)
	if #s > n then s = sub(s, 1, n) end
	return s
end
TK.Cut = cut

local function say(text)
	if M.ShowMsg then M.ShowMsg(text) else print(text) end
end
TK.Say = say

-- the root: missing or not a table is replaced; stray runs and order ids dropped (TK-A-54)
function TK.DB()
	if db then return db end
	local d = PSS_TestKitDB
	if type(d) ~= "table" then d = { v = 1, order = {}, runs = {} }; PSS_TestKitDB = d end
	if type(d.v) ~= "number" then d.v = 1 end
	if type(d.order) ~= "table" then d.order = {} end
	if type(d.runs) ~= "table" then d.runs = {} end
	M.PSS_TK_DEV = d.devMode == true
	if M.PSS_TK_DEV and M.Events and M.Events.Fire then M.Events.Fire("ADDONS_CHANGED") end
	if d.v <= 1 then
		local seen, o = {}, {}
		for _, id in ipairs(d.order) do
			if type(id) == "string" and type(d.runs[id]) == "table" and not seen[id] then seen[id] = true; o[#o + 1] = id end
		end
		while #o > MAXRUNS do d.runs[o[1]] = nil; tremove(o, 1) end
		d.order = o
		for id in pairs(d.runs) do
			if not seen[id] then d.runs[id] = nil end
		end
	end
	db = d
	return d
end

function TK.ReadOnly()
	local d = TK.DB()
	return d.v > 1
end

-- called by every write before it writes
function TK.Writable()
	if TK.ReadOnly() then
		if not told then told = true; say(NEWER) end
		error("newer: results are read-only", 0)
	end
end

function TK.Look()
	local ok, v = pcall(M.PSS_Opt, "uiSkin")
	return SKINS[ok and tonumber(v) or 2] or "modern"
end

function TK.Here()
	return M.PSS_FLV and M.PSS_FLV.flavour or "any"
end

function TK.Env(run)
	local e = envs[run.id]
	if e == nil then
		e = TK.Decode(run.src) or false
		envs[run.id] = e
	end
	return e or nil
end

function TK.GetRun(id)
	local d = TK.DB()
	local run = type(id) == "string" and d.runs[id]
	if not run then error("arg: no run " .. tostring(id), 0) end
	return run
end

local function rowid(c) return c.key .. "@" .. c.client end
TK.RowId = rowid

-- one key input to (env check, row id, step n or nil), api-bus.md header 6
function TK.Resolve(run, key)
	if type(key) ~= "string" then error("arg: no check " .. tostring(key), 0) end
	local base, stepn = key, nil
	local b, n = key:match("^(.-)%.s(%d+)$")
	if b then base, stepn = b, tonumber(n) end
	local k, cl = base:match("^(CHK%-%d%d%d%d%d)@?(%w*)$")
	local env = TK.Env(run)
	if not k or not env then error("arg: no check " .. key, 0) end
	local found, here, any, count, one = nil, nil, nil, 0, nil
	for _, c in ipairs(env.checks) do
		if c.key == k then
			count = count + 1; one = c
			if cl ~= "" and c.client == cl then found = c end
			if c.client == TK.Here() then here = c end
			if c.client == "any" then any = c end
		end
	end
	if cl == "" then found = here or any or (count == 1 and one) or nil end
	if not found then
		if count > 1 and cl == "" then error("arg: key " .. key .. " needs @<client>", 0) end
		error("arg: no check " .. key, 0)
	end
	return found, rowid(found), stepn
end

function TK.Touch(run) run.updated = time() end

function TK.Fire(id, key)
	if M.Events and M.Events.Fire then M.Events.Fire("TESTKIT_CHANGED", id, key or "") end
end

-- the row of a check, created on first write (cap 100 per run)
function TK.CheckRow(run, id)
	if type(run.checks) ~= "table" then run.checks = {} end
	local c = run.checks[id]
	if not c then
		local n = 0
		for _ in pairs(run.checks) do n = n + 1 end
		if n >= MAXCHECKS then error("arg: too many checks", 0) end
		c = {}
		run.checks[id] = c
	end
	return c
end

-- shown s, sub, why: man when set, else auto (TK-A-58)
function TK.Shown(c)
	local x = c.man or c.auto
	if x then return x.s or "not_complete", x.sub, x.why end
	return "not_complete"
end

local function settle(c)
	local s, sb, w = TK.Shown(c)
	c.s, c.sub, c.why = s, sb, w
	c.look = TK.Look()
	if s == "complete" and not c.at then c.at = time() end
end
TK.Settle = settle

-- auto from the steps and objectives (TK-A-07 step 2)
function TK.Recompute(c, ec)
	local ok = true
	local steps = c.steps or {}
	for n = 1, #ec.steps do
		local st = steps[n]
		if not (st and st.ok == true) then ok = false end
	end
	for _, o in ipairs(ec.objectives or {}) do
		local have = c.obj and c.obj[o.id] or 0
		if have < (o.need or 1) then ok = false end
	end
	c.auto = { s = ok and "complete" or "not_complete", at = time() }
	settle(c)
end

-- the first selection of a check on this client; set once, no event (F12)
function TK.Seen(id, key)
	local d = TK.DB()
	if d.v > 1 then return end
	local run = d.runs[id]
	if not run then return end
	local ok, _, row = pcall(TK.Resolve, run, key)
	if not ok then return end
	local c = run.checks and run.checks[row]
	if c and c.seen then return end
	c = TK.CheckRow(run, row)
	c.seen = time()
end

-- stores a decoded run; returns its id (api-saved.md TK-A-53, TK-A-55 to TK-A-57)
function TK.Store(env, text)
	TK.Writable()
	local d = TK.DB()
	local id = env.id
	local gbi = GetBuildInfo
	local ver, bld, _, toc = nil, nil, nil, nil
	if gbi then ver, bld, _, toc = gbi() end
	local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local now = time()
	d.runs[id] = {
		id = id, build = env.build, title = env.title or env.build, src = sub(text, 1, MAXSRC), kit = "TK." .. (TK.N or 1),
		suite = meta and meta("PourSocialScore", "Version") or "", flavour = TK.Here(),
		client = { ver = ver, bld = bld, toc = toc, locale = GetLocale and GetLocale() or "" },
		imported = now, updated = now, checks = {},
	}
	envs[id] = env
	d.order[#d.order + 1] = id
	while #d.order > MAXRUNS do
		local old = tremove(d.order, 1)
		d.runs[old] = nil
		envs[old] = nil
	end
	return id
end

function TK.CapNote(text) return cut(text or "", MAXNOTE) end
TK.CAP = { why = MAXWHY, got = MAXGOT, note = MAXNOTE, text = MAXTEXT, m = MAXM }
