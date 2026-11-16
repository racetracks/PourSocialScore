local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M
local type, tonumber, tostring, error, pairs, ipairs, next = type, tonumber, tostring, error, pairs, ipairs, next
local find, time = string.find, time

-- TestKit bus services (design.md#bus-services). open, close, import, runs, checks, detail, mark, note, input.
local EMPTY = { cols = { "shown" }, n = 0 }
local SHOWN = { cols = { "shown" }, n = 1, { true } }
local HIDDEN = { cols = { "shown" }, n = 1, { false } }

local function open()
	local win = TK.GetWindow()
	if win then win:Show() end
	return SHOWN
end

M.PSS_ProvideStub("testkit.open", { returns = { "shown" }, doc = "opens the TestKit window", cost = "O(1)", writes = false, onError = "empty", default = EMPTY },
	function() return open end)

M.PSS_Provide("testkit.close", function()
	local win = TK.window
	if win then win:Hide() end
	if M.PSS_Unwant then M.PSS_Unwant("testkit.poll") end
	return HIDDEN
end, { returns = { "shown" }, doc = "closes the TestKit window", cost = "O(1)", writes = false, onError = "empty", default = EMPTY })

-- inputs: a plain table or a one-row set
local function arg(set, name)
	if type(set) ~= "table" then return nil end
	if M.PSS_IsSet(set) then
		local i = M.PSS_SetCol(set, name)
		return i and set[1] and set[1][i] or nil
	end
	return set[name]
end

local function reqId(set)
	local id = arg(set, "id")
	if type(id) ~= "string" or id == "" then error("arg: no run " .. tostring(id), 0) end
	return id
end

local LOOKORD = { modern = 1, classic = 2, dark = 3, any = 4 }
local function isAuto(c)
	for _, st in ipairs(c.steps) do
		if st.op and st.op.op == "manual" then return false end
	end
	return true
end

-- checks in window order (TK-A-05 step 1)
local function ordered(env)
	local fo = {}
	for i, f in ipairs(env.flavours) do fo[f] = i end
	fo.any = 99
	local list = {}
	for i, c in ipairs(env.checks) do list[i] = { c = c, i = i, a = isAuto(c) and 0 or 1 } end
	table.sort(list, function(x, y)
		local fx, fy = fo[x.c.client] or 98, fo[y.c.client] or 98
		if fx ~= fy then return fx < fy end
		local lx, ly = LOOKORD[x.c.look] or 5, LOOKORD[y.c.look] or 5
		if lx ~= ly then return lx < ly end
		if x.a ~= y.a then return x.a < y.a end
		return x.i < y.i
	end)
	return list
end

M.PSS_Provide("testkit.import", function(set)
	local text = arg(set, "text")
	local function fail(e) return { cols = { "id", "build", "checks", "err" }, n = 1, { "", "", 0, e } } end
	local env, err = TK.Decode(text)
	if not env then return fail(err) end
	local d = TK.DB()
	local old = d.runs[env.id]
	if old then
		TK.Say("already imported: " .. env.id)
		return { cols = { "id", "build", "checks", "err" }, n = 1, { old.id, old.build, #env.checks, "" } }
	end
	TK.Store(env, (text:gsub("[ \t\r\n]", "")))
	if TK.RunAuto then TK.RunAuto(env.id) end
	TK.Fire(env.id, "")
	return { cols = { "id", "build", "checks", "err" }, n = 1, { env.id, env.build, #env.checks, "" } }
end, { accepts = { "text" }, returns = { "id", "build", "checks", "err" }, doc = "imports a TestKit string", cost = "O(string length)", writes = true, onError = "empty" })

M.PSS_Provide("testkit.runs", function()
	local d = TK.DB()
	local out = { cols = { "id", "build", "imported", "complete", "total" }, n = 0 }
	for i = #d.order, 1, -1 do
		local run = d.runs[d.order[i]]
		if run then
			local env, done, total = TK.Env(run), 0, 0
			for _, c in pairs(run.checks or {}) do
				if TK.Shown(c) == "complete" then done = done + 1 end
			end
			total = env and #env.checks or 0
			M.PSS_SetAdd(out, { run.id, run.build, run.imported or 0, done, total })
		end
	end
	return out
end, { returns = { "id", "build", "imported", "complete", "total" }, doc = "the stored runs", cost = "O(runs)", writes = false, onError = "empty" })

M.PSS_Provide("testkit.checks", function(set)
	local run = TK.GetRun(arg(set, "id"))
	local out = { cols = { "key", "title", "group", "status", "sub", "auto" }, n = 0 }
	local env = TK.Env(run)
	if not env then return out end
	for _, e in ipairs(ordered(env)) do
		local c = e.c
		local row = TK.RowId(c)
		local s, sb = TK.Shown(run.checks and run.checks[row] or {})
		M.PSS_SetAdd(out, { row, c.title, c.client .. " / " .. c.look, s, sb or "", e.a == 0 })
	end
	return out
end, { accepts = { "id" }, returns = { "key", "title", "group", "status", "sub", "auto" }, doc = "the checks of a run, in window order", cost = "O(checks)", writes = false, onError = "empty" })

M.PSS_Provide("testkit.detail", function(set)
	local run = TK.GetRun(arg(set, "id"))
	local c, row = TK.Resolve(run, arg(set, "key"))
	local ck = run.checks and run.checks[row] or {}
	local out = { cols = { "step", "text", "expect", "op", "done" }, n = 0 }
	for n, st in ipairs(c.steps) do
		M.PSS_SetAdd(out, { n, st.text, c.expect, st.op.op, ck.steps and ck.steps[n] and ck.steps[n].ok == true or false })
	end
	return out
end, { accepts = { "id", "key" }, returns = { "step", "text", "expect", "op", "done" }, doc = "the steps of one check", cost = "O(steps)", writes = false, onError = "empty" })

local STATUS = { complete = 1, not_complete = 1, failed = 1, skipped = 1, blocked = 1, n_a = 1, clear = 1 }
M.PSS_Provide("testkit.mark", function(set)
	local run = TK.GetRun(arg(set, "id"))
	local c, row = TK.Resolve(run, arg(set, "key"))
	local status, reason, step = arg(set, "status"), arg(set, "reason"), arg(set, "step")
	if not STATUS[status] then error("arg: bad status " .. tostring(status), 0) end
	step = tonumber(step)
	if step and not c.steps[step] then error("arg: no step " .. step, 0) end
	TK.Writable()
	local ck = TK.CheckRow(run, row)
	local why = reason and reason ~= "" and TK.Cut(reason, TK.CAP.why) or nil
	local now = time()
	local stepOnly = false
	if step and (status == "complete" or status == "failed" or status == "skipped") then
		if type(ck.steps) ~= "table" then ck.steps = {} end
		local st = ck.steps[step] or {}
		st.ok = status == "complete"
		st.at = now
		ck.steps[step] = st
		stepOnly = status == "complete"
	end
	if not stepOnly then
		if status == "clear" then ck.man = nil
		elseif status == "complete" or status == "not_complete" then ck.man = { s = status, why = why, at = now }
		else ck.man = { s = "other", sub = status, why = why, at = now } end
	end
	if step then TK.Recompute(ck, c) else TK.Settle(ck) end
	TK.Touch(run)
	TK.Fire(run.id, row)
	return { cols = { "key", "status" }, n = 1, { row, (TK.Shown(ck)) } }
end, { accepts = { "id", "key", "status", "reason", "step" }, returns = { "key", "status" }, doc = "the author's Pass, Fail, Skip or overrule", cost = "O(1)", writes = true, onError = "empty" })

M.PSS_Provide("testkit.note", function(set)
	local run = TK.GetRun(arg(set, "id"))
	local key, text = arg(set, "key"), arg(set, "text")
	local c, row, n = TK.Resolve(run, key)
	if n and not c.steps[n] then error("arg: no step " .. tostring(key), 0) end
	TK.Writable()
	local ck = TK.CheckRow(run, row)
	local nk = n and ("s" .. n) or ""
	if type(ck.notes) ~= "table" then ck.notes = {} end
	if text == nil or text == "" then
		ck.notes[nk] = nil
		if next(ck.notes) == nil then ck.notes = nil end
	else
		ck.notes[nk] = TK.CapNote(text)
	end
	TK.Touch(run)
	TK.Fire(run.id, row)
	return { cols = { "key" }, n = 1, { key } }
end, { accepts = { "id", "key", "text" }, returns = { "key" }, doc = "the author's note on a check or a step", cost = "O(1)", writes = true, onError = "empty" })

local function inputDef(c, field)
	for n, st in ipairs(c.steps) do
		if st.op.op == "input" and st.op.id == field then return st.op, n end
	end
	for _, d in ipairs(c.inputs or {}) do
		if d.id == field then return d end
	end
end

local function cmpOK(cmp, v, want)
	if cmp == "eq" then return v == want end
	if cmp == "ne" then return v ~= want end
	if cmp == "lt" or cmp == "le" or cmp == "gt" or cmp == "ge" then
		if type(v) ~= "number" or type(want) ~= "number" then return false end
		if cmp == "lt" then return v < want elseif cmp == "le" then return v <= want elseif cmp == "gt" then return v > want end
		return v >= want
	end
	if cmp == "match" then return find(tostring(v), want) ~= nil end
	if cmp == "type" then return type(v) == want end
	if cmp == "len" then return (type(v) == "string" or type(v) == "table") and #v == want end
	if cmp == "has" then
		if type(v) == "table" then
			for _, x in pairs(v) do if x == want then return true end end
			return false
		end
		return type(v) == "string" and find(v, tostring(want), 1, true) ~= nil
	end
	return false
end

M.PSS_Provide("testkit.input", function(set)
	local run = TK.GetRun(arg(set, "id"))
	local c, row = TK.Resolve(run, arg(set, "key"))
	local field, value = arg(set, "field"), arg(set, "value")
	local def, stepn = inputDef(c, field)
	if not def then error("arg: no input " .. tostring(field), 0) end
	local kind, bad = def.kind, false
	if kind == "bool" then bad = type(value) ~= "boolean"
	elseif kind == "number" then
		value = tonumber(value)
		bad = value == nil or (def.min and value < def.min) or (def.max and value > def.max)
	elseif kind == "text" then
		bad = type(value) ~= "string"
		if not bad then value = TK.Cut(value, TK.CAP.text) end
	elseif kind == "choice" then
		bad = true
		for _, ch in ipairs(def.choices) do if ch == value then bad = false end end
	end
	if bad then error("arg: bad value for " .. tostring(field), 0) end
	TK.Writable()
	local ck = TK.CheckRow(run, row)
	if type(ck.inputs) ~= "table" then ck.inputs = {} end
	ck.inputs[field] = value
	if stepn then
		if type(ck.steps) ~= "table" then ck.steps = {} end
		local st = ck.steps[stepn] or {}
		st.ok = def.cmp == nil or cmpOK(def.cmp, value, def.want)
		st.got = TK.Cut(tostring(value), TK.CAP.got)
		st.at = time()
		ck.steps[stepn] = st
	end
	TK.Recompute(ck, c)
	TK.Touch(run)
	TK.Fire(run.id, row)
	return { cols = { "key", "value" }, n = 1, { row, value } }
end, { accepts = { "id", "key", "field", "value" }, returns = { "key", "value" }, doc = "a value the author typed", cost = "O(1)", writes = true, onError = "empty" })
