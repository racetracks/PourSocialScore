------------------------------------------------------------------------
-- POUR SOCIAL SCORE - THE SPYGLASS CONSOLE'S MODELS (search-helper, phase B)
-- Logic for the console's views; the GUI folder only draws what these return.
--   M.PSS_QV_EVENTS                 index name -> the core event that says it changed
--   M.PSS_ChartSpec(shape, want, set)   the chart a result shape gets
--   M.PSS_QueryViewModel(o)         vm:SetQuery, Run, Status, Text, Events, Drop
-- Loads on demand with the Libraries folder; nothing registers or runs at load.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, tostring, tonumber, ipairs, pcall, setmetatable = type, tostring, tonumber, ipairs, pcall, setmetatable
local format = string.format

local CV = M.PSS_ConsoleView or {}
M.PSS_ConsoleView = CV

M.PSS_QV_EVENTS = { log = "HISTORY_CHANGED", inv = "WH_CHANGED", jrn = "JRN_CHANGED" }

local ALLOWED = {
	events = {}, table = { bar = true, donut = true, table = true },
	series = { column = true, line = true, area = true, table = true },
	matrix = { heat = true, table = true }, number = { number = true },
}

local function numericCols(set)
	local row, n = set[1], 0
	if not row then return 0 end
	for i = 2, #set.cols do if type(row[i]) == "number" then n = n + 1 end end
	return n
end

function M.PSS_ChartSpec(shape, want, set)
	local allowed = shape and ALLOWED[shape]
	if want and allowed and allowed[want.kind] then return want end
	local cols = set and set.cols or {}
	if shape == "series" then
		return { kind = #cols > 2 and "line" or "column", x = cols[1] }
	elseif shape == "table" then
		return { kind = (set and numericCols(set) == 1) and "bar" or "table" }
	elseif shape == "matrix" then
		return { kind = (cols[1] == "weekday" and cols[2] == "hour") and "heat" or "table" }
	elseif shape == "number" then
		return { kind = "number" }
	end
	return { kind = "table" }
end

local VM = {}
VM.__index = VM

function M.PSS_QueryViewModel(o)
	return setmetatable({ o = o or {}, state = "idle", loaded = false }, VM)
end

function VM:SetQuery(text, params)
	self.query, self.params = text, params
	self.err, self.set, self.info, self.chart = nil, nil, nil, nil
	self.state, self.loaded = "idle", false
	self.plan = nil
	if type(text) == "string" then
		local ok, plan, e = pcall(M.PSS_Psql.compile, text)
		if ok and plan then self.plan = plan
		else
			self.err = (ok and type(e) == "table" and e) or { code = "parse", pos = 1, msg = ok and "invalid query" or tostring(plan) }
		end
	end
end

function VM:Run(load, range)
	self.loaded = self.loaded or load == true
	self.state = "running"
	local ok, set, info = pcall(M.PSS_Search, self.query, {
		params = self.params, load = self.loaded or nil,
		from = range and range.earliest, to = range and range.latest,
		rows = self.o.rows or 500, reuse = self.set,
	})
	if not ok or not set then
		local e = (not ok) and { code = "lua", pos = 1, msg = tostring(set) }
			or (type(info) == "table" and info) or { code = "lua", pos = 1, msg = "no result" }
		self.err = { code = e.code, pos = e.pos, msg = e.msg }
		self.state = "error"
		self.set, self.info, self.chart = nil, nil, nil
		return
	end
	self.err = nil
	self.set, self.info = set, info
	if info.needs and not self.loaded then self.state = "needsload"
	elseif info.partial then self.state = "partial"
	else self.state = "shown" end
	local okC, spec = pcall(M.PSS_ChartSpec, info.shape, self.plan and self.plan.chart, set)
	self.chart = okC and spec or { kind = "table" }
	self.chart.pending = info.pending or nil
end

function VM:Status()
	if self.state == "needsload" then return "Load history" end
	if self.state == "error" then
		local e = self.err or {}
		return format("Error: %s (at %s)", tostring(e.msg), tostring(e.pos))
	end
	if not self.set then return "" end
	local s = format("%d rows, %.2f ms", self.set.n or 0, (self.info and self.info.ms) or 0)
	if self.state == "partial" then s = s .. ", partial" end
	return s
end

-- the plan's text with each $name put in as one quoted literal (plan:text() keeps the $name)
function VM:Text()
	if not self.plan then return nil end
	local text = self.plan:text()
	local params = self.params
	if not params or not text then return text end
	return (text:gsub("%$([%a_][%w_]*)", function(name)
		local v = params[name]
		if v == nil then return nil end
		return '"' .. tostring(v):gsub("[\\\"]", "\\%0") .. '"'
	end))
end

function VM:Events()
	local out, seen = {}, {}
	local names = self.plan and self.plan:indexNames()
	for _, n in ipairs(names or {}) do
		local ev = M.PSS_QV_EVENTS[n]
		if ev and not seen[ev] then seen[ev] = true; out[#out + 1] = ev end
	end
	return out
end

function VM:Drop()
	self.set, self.info = nil, nil
	self.state = "idle"
end
