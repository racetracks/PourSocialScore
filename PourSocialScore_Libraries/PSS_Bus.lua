------------------------------------------------------------------------
-- POUR SOCIAL SCORE - THE SERVICE BUS (service-bus-helper, DDS-00010
-- sections 2 and 3). The one shape every service speaks is a record set:
--   set = { cols = { "item", "count" }, n = 2, { 17, 4 }, { 31, 1 } }
-- rows are values by position; n is the row count. Services are named
-- "<store>.<verb>" and called by name, so the output of one is the input
-- of the next:
--   M.PSS_Provide(name, fn, { accepts = { cols }, returns = { cols }, doc })
--   local set, err = M.PSS_Call(name, input, opts)
--   M.PSS_Services()          the bus describes itself, as a record set
-- Loaded with Libraries. Nothing registers an event, makes a frame or
-- touches the window; a failing service returns nil, err and is reported
-- once (M.PSS_NoteListenerError).
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, pairs, pcall, tostring, next = type, pairs, pcall, tostring, next
local sort, concat = table.sort, table.concat

local services = {}		-- [name] = { fn, accepts, returns, doc }
local colIndex = setmetatable({}, { __mode = "k" })		-- [set] = { name = column }

------------------------------------------------------------------------
-- Record sets
------------------------------------------------------------------------
function M.PSS_Set(cols)
	return { cols = cols, n = 0 }
end

function M.PSS_IsSet(v)
	return type(v) == "table" and type(v.cols) == "table" and type(v.n) == "number"
end

function M.PSS_SetAdd(set, row)
	local n = set.n + 1
	set.n = n
	set[n] = row
	return row
end

-- the row after the last, reused when one is left from an earlier fill
-- (opts.reuse: a redraw allocates nothing); the caller sets every column
function M.PSS_SetNext(set)
	local n = set.n + 1
	local row = set[n]
	if not row then row = {}; set[n] = row end
	set.n = n
	return row
end

function M.PSS_SetClear(set)
	set.n = 0
end

-- the index of a column by name (cached per set), nil when it has none
function M.PSS_SetCol(set, name)
	local idx = colIndex[set]
	if not idx then
		idx = {}
		for i = 1, #set.cols do idx[set.cols[i]] = i end
		colIndex[set] = idx
	end
	return idx[name]
end

------------------------------------------------------------------------
-- The bus
------------------------------------------------------------------------
function M.PSS_Provide(name, fn, spec)
	if type(name) ~= "string" or not name:find("^[%w_]+%.[%w_.]+$") or type(fn) ~= "function" then return end
	spec = spec or {}
	services[name] = { fn = fn, accepts = spec.accepts or {}, returns = spec.returns or {}, doc = spec.doc }
end

local function Fail(name, err)
	M.PSS_NoteListenerError("service " .. name, err)		-- counted every time, shown once per service
	return nil, err
end

-- a key, a { key = ... } table and a one-row set are the same call
local function Normalize(input)
	local t = type(input)
	if t == "string" or t == "number" then
		return { cols = { "key" }, n = 1, { input } }
	end
	if t == "table" and not M.PSS_IsSet(input) and input.key ~= nil and next(input, "key") == nil and next(input) == "key" then
		return { cols = { "key" }, n = 1, { input.key } }
	end
	return input
end

function M.PSS_Call(name, input, opts)
	local svc = services[name]
	if not svc then return nil, "no service " .. tostring(name) end
	local secret = M.PSS_IsSecret
	if secret then
		local t = type(input)
		if t == "string" or t == "number" then
			if secret(input) then return nil, "secret value" end
		elseif t == "table" and secret(input.key) then
			return nil, "secret value"
		end
	end
	local ok, out = pcall(svc.fn, Normalize(input), opts)
	if not ok then return Fail(name, out) end
	if out ~= nil and not M.PSS_IsSet(out) then return Fail(name, "returned a value that is not a record set") end
	return out
end

-- name, accepts, returns (column lists joined by commas), sorted by name
function M.PSS_Services()
	local names = {}
	for name in pairs(services) do names[#names + 1] = name end
	sort(names)
	local set = { cols = { "name", "accepts", "returns" }, n = #names }
	for i = 1, #names do
		local svc = services[names[i]]
		set[i] = { names[i], concat(svc.accepts, ","), concat(svc.returns, ",") }
	end
	return set
end
