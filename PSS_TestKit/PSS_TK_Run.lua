local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M

-- TestKit ops part 1 and comparators (api-ops.md#ops, api-ops.md#comparators).
-- TK.Op.<name>(op, ctx) returns value, err. err is a string (the step fails) or a table
-- { status = "other", sub = "blocked", why = text } / { status = "not_complete" } (the check is not decided).
-- ctx: id, key, n, action (true inside an action), value (a stored input). TK.Exec runs one op and its cmp.
local type, tonumber, tostring, pairs, ipairs, pcall, rawget, select, unpack = type, tonumber, tostring, pairs, ipairs, pcall, rawget, select, unpack
local find, sub = string.find, string.sub
local time, CreateFrame = time, CreateFrame

local Cmp, Op = {}, {}
TK.Cmp, TK.Op = Cmp, Op

local function deep(a, b)
	if a == b then return true end
	if type(a) ~= "table" or type(b) ~= "table" then return false end
	for k, v in pairs(a) do
		if not deep(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

local function got(v) return "got " .. tostring(v) end

Cmp.eq = function(v, want)
	if deep(v, want) then return true end
	return false, got(v)
end
Cmp.ne = function(v, want)
	if not deep(v, want) then return true end
	return false, got(v)
end

local function order(f)
	return function(v, want)
		local a, b = tonumber(v), tonumber(want)
		if a == nil or b == nil then return false, "not a number" end
		if f(a, b) then return true end
		return false, got(v)
	end
end
Cmp.lt = order(function(a, b) return a < b end)
Cmp.le = order(function(a, b) return a <= b end)
Cmp.gt = order(function(a, b) return a > b end)
Cmp.ge = order(function(a, b) return a >= b end)

Cmp.match = function(v, want)
	if type(want) ~= "string" then return false, "bad pattern" end
	local ok, r = pcall(find, tostring(v), want)
	if not ok then return false, "bad pattern" end
	if r ~= nil then return true end
	return false, got(v)
end

Cmp["type"] = function(v, want)
	if type(v) == want then return true end
	return false, "got " .. type(v)
end

Cmp.len = function(v, want)
	local t = type(v)
	if t ~= "string" and t ~= "table" then return false, "no length" end
	if #v == want then return true end
	return false, "got " .. #v
end

Cmp.has = function(v, want)
	if type(v) == "table" then
		for _, x in pairs(v) do
			if x == want then return true end
		end
		return false, "not found"
	elseif type(v) == "string" then
		if find(v, tostring(want), 1, true) then return true end
		return false, "not found"
	end
	return false, "not a table or string"
end

-- results that are not a pass or a fail
local function blocked(why) return nil, { status = "other", sub = "blocked", why = why } end
local function pending() return nil, { status = "not_complete" } end

-- D2: a writing service never runs automatically; inside an action it is blocked as well. Returns nil to go on.
function TK.WriterGuard(service, ctx)
	local info = M.PSS_ServiceInfo and M.PSS_ServiceInfo(service)
	if info and info.writes == true then
		if ctx and ctx.action then return blocked("writing service not allowed: " .. tostring(service)) end
		return pending()
	end
end

-- walk _G by dotted path with rawget; nil when a part is missing
local function walk(path)
	if type(path) ~= "string" then return nil end
	local v = _G
	for part in path:gmatch("[^%.]+") do
		if type(v) ~= "table" then return nil end
		v = rawget(v, part)
		if v == nil then return nil end
	end
	return v
end

local function inputSet(op)
	if type(op.cols) ~= "table" then return nil end
	local set = { cols = op.cols, n = 0 }
	for i, row in ipairs(op.rows or {}) do set[i] = row; set.n = i end
	return set
end

local function callService(op, ctx)
	local a, b = TK.WriterGuard(op.service, ctx)
	if b then return a, b end
	local set, err = M.PSS_Call(op.service, inputSet(op))
	if set == nil then return nil, err or ("no result from " .. tostring(op.service)) end
	return set
end

Op.call = function(op, ctx)
	local set, err = callService(op, ctx)
	if err then return nil, err end
	if op.col == "#" then return set.n end
	local i = M.PSS_SetCol(set, op.col)
	local row = set[op.row or 1]
	if not i or not row then return nil end
	return row[i]
end

Op.api = function(op)
	local fn = op.fn
	if type(fn) ~= "string" or not TK.ALLOW[fn] then return blocked("api not allowed: " .. tostring(fn)) end
	local f = walk(fn)
	if type(f) ~= "function" then return nil, "no function " .. fn end
	local args = op.args or {}
	local r = { pcall(f, unpack(args, 1, #args)) }
	if not r[1] then return nil, tostring(r[2]) end
	return r[1 + (op.ret or 1)]
end

Op.field = function(op)
	local v = walk(op.path)
	if type(v) == "function" then return "function" end
	return v
end

local READ = {
	shown = function(f) return f:IsShown() end,
	point = function(f) return (f:GetPoint(1)) end,
	relativeTo = function(f)
		local rel = select(2, f:GetPoint(1))
		return rel and rel.GetName and rel:GetName() or nil
	end,
	width = function(f) return f:GetWidth() end,
	height = function(f) return f:GetHeight() end,
	text = function(f) return f:GetText() end,
	enabled = function(f) return f:IsEnabled() end,
}
local NEED = { shown = "IsShown", point = "GetPoint", relativeTo = "GetPoint", width = "GetWidth", height = "GetHeight", text = "GetText", enabled = "IsEnabled" }

Op.frame = function(op)
	local f = walk(op.path)
	if type(f) ~= "table" then return nil end
	local read, need = READ[op.prop], NEED[op.prop]
	if not read or type(f[need]) ~= "function" then return nil, "no " .. tostring(op.prop) end
	local ok, v = pcall(read, f)
	if not ok then return nil, "no " .. tostring(op.prop) end
	return v
end

Op.load = function(op)
	local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
	local v = f and f(op.addon) and true or false
	if not v then return false, "not loaded" end
	return true
end

Op.unit = function(op, ctx)
	local set, err = callService(op, ctx)
	if err then return nil, err end
	local want = type(op.want) == "table" and op.want or {}
	if not deep(set.cols, want.cols) then return set, "cols differ" end
	if want.rows ~= nil then
		local rows = {}
		for i = 1, set.n do rows[i] = set[i] end
		if not deep(rows, want.rows) then return set, "rows differ" end
	end
	return set
end

-- the author's own steps: the window settles them (testkit.mark, testkit.input)
Op.manual = function() return pending() end
Op.input = function(op, ctx)
	local v = ctx and ctx.value
	if v == nil then
		if op.required == false then return nil end
		return pending()
	end
	return v
end

local function text(v)
	if type(v) == "table" then
		return v.cols and ("set n=" .. tostring(v.n)) or "table"
	end
	local s = tostring(v)
	if #s > 200 then s = sub(s, 1, 200) end
	return s
end

-- ops part 2 (K161b): event, cmd, measure, print, action; the automatic runner
local GetTime = GetTime
local floor = math.floor
local sort = table.sort
local wait = {}	-- event waits: "<id>|<key>|<n>" -> { name, since, within, seen }
local evf
local combatWait	-- { id, key } while waiting for PLAYER_REGEN_ENABLED
local profile = debugprofilestop

local function kitFrame()
	if not evf then
		evf = CreateFrame("Frame")
		evf:SetScript("OnEvent", function(self, event)
			if event == "PLAYER_REGEN_ENABLED" then
				self:UnregisterEvent(event)
				local w = combatWait
				combatWait = nil
				if w and TK.RunAuto then pcall(TK.RunAuto, w.id, w.key) end
				return
			end
			for k, w in pairs(wait) do
				if w.name == event and not w.seen then
					w.seen = true
					local id, key = k:match("^(.-)|(.-)|")
					if TK.RunAuto and id then pcall(TK.RunAuto, id, key) end
				end
			end
			local live = false
			for _, w in pairs(wait) do
				if w.name == event and not w.seen then live = true end
			end
			if not live then self:UnregisterEvent(event) end
		end)
	end
	return evf
end

local function waitKey(ctx) return tostring(ctx.id) .. "|" .. tostring(ctx.key) .. "|" .. tostring(ctx.n) end

-- the author selects a check (or presses Retry): within counts from now (TK-A-33)
function TK.Select(runId, row, c)
	if not c or not c.steps then return end
	for n, st in ipairs(c.steps) do
		local op = st.op
		if op and op.op == "event" and type(op.name) == "string" then
			wait[runId .. "|" .. row .. "|" .. n] = { name = op.name, since = GetTime(), within = op.within, seen = false }
			pcall(kitFrame().RegisterEvent, kitFrame(), op.name)
		end
	end
end

function TK.Waiting(runId, row, n)
	local w = wait[runId .. "|" .. row .. "|" .. n]
	return w ~= nil and not w.seen
end

function TK.CombatWaiting() return combatWait ~= nil end

Op.event = function(op, ctx)
	local k = waitKey(ctx)
	local w = wait[k]
	if not w then return pending() end
	if w.seen then return true end
	local within = tonumber(op.within) or 60
	if within < 1 then within = 1 elseif within > 600 then within = 600 end
	if GetTime() - w.since >= within then return nil, "not seen in " .. within .. " s" end
	return pending()
end

local function msgs()
	local set = M.PSS_Call and M.PSS_Call("core.messages")
	if type(set) ~= "table" then return 0, {} end
	local ni, ti = M.PSS_SetCol(set, "n"), M.PSS_SetCol(set, "text")
	local last, rows = 0, {}
	for i = 1, set.n or 0 do
		local r = set[i]
		local n = r[ni]
		if n > last then last = n end
		rows[n] = r[ti]
	end
	return last, rows
end

Op.cmd = function(op, ctx)
	if not ctx.action then return pending() end
	local line = type(op.line) == "string" and op.line or ""
	local word = line:match("^/pss%s+(%S+)")
	if not word then return blocked("command not allowed: " .. line) end
	if not TK.CMD_ALLOW[word] then return blocked("command not allowed: " .. word) end
	local before = msgs()
	local ok, e = pcall(M.PSS_SlashPSS, (line:gsub("^/pss%s+", "")))
	if not ok then return nil, tostring(e) end
	local after, rows = msgs()
	local out = {}
	for n = before + 1, after do
		if rows[n] then out[#out + 1] = rows[n] end
	end
	return table.concat(out, "\n")
end

Op.print = function(op, ctx)
	if not ctx.action then return blocked("unknown op print") end
	local t = op.text
	if type(t) ~= "string" or t == "" then return nil, "no text" end
	if #t > 200 then t = sub(t, 1, 200) end
	DEFAULT_CHAT_FRAME:AddMessage(t)
	return true
end

Op.measure = function(op, ctx)
	if InCombatLockdown and InCombatLockdown() then
		combatWait = { id = ctx.id, key = ctx.key }
		kitFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
		return pending()
	end
	local a, b = TK.WriterGuard(op.service, ctx)
	if b then return a, b end
	local runs = tonumber(op.runs) or 5
	if runs < 1 then runs = 1 elseif runs > 50 then runs = 50 end
	runs = floor(runs)
	local times = {}
	for i = 1, runs do
		local t0 = profile()
		local set, err = M.PSS_Call(op.service, inputSet(op))
		times[i] = profile() - t0
		if set == nil then return nil, err or ("no result from " .. tostring(op.service)) end
	end
	sort(times)
	local ms = times[floor((runs + 1) / 2)]
	if ctx.m then
		ctx.m[#ctx.m + 1] = { label = op.service, ms = ms, runs = runs }
		while #ctx.m > ((TK.CAP and TK.CAP.m) or 20) do table.remove(ctx.m, 1) end
	end
	return ms
end

local INNER = { call = true, cmd = true, print = true }
Op.action = function(op, ctx)
	if not ctx.action then return pending() end
	local inner = op["then"]
	local name = type(inner) == "table" and inner.op
	if not INNER[name] then return blocked("unknown op " .. tostring(name)) end
	local r = TK.Exec(inner, ctx)
	if r.status then return nil, { status = r.status, sub = r.sub, why = r.why } end
	if not r.ok then return nil, r.why or "failed" end
	return r.got
end

-- stores one step result on a stored check row; false when the step was only pending
function TK.ApplyStep(ck, n, r)
	if r.status == "not_complete" then return false end
	if type(ck.steps) ~= "table" then ck.steps = {} end
	local st = ck.steps[n] or {}
	st.ok = r.ok == true
	st.got = TK.Cut(tostring(r.got or r.why or ""), TK.CAP.got)
	st.at = time()
	ck.steps[n] = st
	return true
end

local function runCheck(run, c, row)
	local ck = TK.CheckRow(run, row)
	local blockedBy
	local ctx = { id = run.id, key = row, m = nil }
	for n, st in ipairs(c.steps) do
		local o = st.op
		if o and o.op ~= "manual" and o.op ~= "input" and o.op ~= "action" then
			ctx.n = n
			ctx.m = ck.m
			if o.op == "measure" and type(ck.m) ~= "table" then ck.m = {}; ctx.m = ck.m end
			local r = TK.Exec(o, ctx)
			if r.status == "other" then
				blockedBy = blockedBy or r
				TK.ApplyStep(ck, n, { ok = false, why = r.why })
			else
				TK.ApplyStep(ck, n, r)
			end
		end
	end
	TK.Recompute(ck, c)
	if blockedBy then
		ck.auto = { s = "other", sub = blockedBy.sub, why = blockedBy.why, at = time() }
		TK.Settle(ck)
	end
	TK.Touch(run)
	return row, (TK.Shown(ck))
end

-- re-runs the automatic steps of one run (one check when key is given); returns rows { key, status }
function TK.RunAuto(id, key)
	local run = TK.GetRun(id)
	TK.Writable()
	local env = TK.Env(run)
	local out = {}
	if not env then return out end
	local here = TK.Here()
	local only
	if key ~= nil and key ~= "" then
		local _, row = TK.Resolve(run, key)
		only = row
	end
	for _, c in ipairs(env.checks) do
		local row = TK.RowId(c)
		if (c.client == "any" or c.client == here) and (not only or only == row) then
			local r, s = runCheck(run, c, row)
			out[#out + 1] = { r, s }
			TK.Fire(run.id, row)
		end
	end
	return out
end

-- one op and its comparator: returns { ok, got, status, sub, why }
function TK.Exec(op, ctx)
	local f = type(op) == "table" and Op[op.op]
	if not f then return { status = "other", sub = "blocked", why = "unknown op " .. tostring(type(op) == "table" and op.op) } end
	local value, err = f(op, ctx or {})
	if type(err) == "table" then return { ok = false, status = err.status, sub = err.sub, why = err.why } end
	if err then return { ok = false, got = value ~= nil and text(value) or err, why = err } end
	local r = { ok = true, got = text(value) }
	if op.cmp ~= nil then
		local c = Cmp[op.cmp]
		if not c then return { status = "other", sub = "blocked", why = "unknown cmp " .. tostring(op.cmp) } end
		local ok, why = c(value, op.want)
		r.ok = ok and true or false
		if not ok then r.why = why end
	end
	return r
end
