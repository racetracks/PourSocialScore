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
	if range and CV.typedTime(self.query) then range = nil end
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

------------------------------------------------------------------------
-- Time picker (STP-00288): presets, the range a choice means, month grid
--   CV.PRESETS  CV.pickerRange(choice, now) -> earliest, latest, label, term | nil, pos, msg
--   CV.typedTime(text)  CV.monthGrid(y, m) -> offset, days   CV.monthStep(y, m, k) -> y2, m2
------------------------------------------------------------------------
local T = M.PSS_Time
local date = date or os.date

CV.PRESETS = {
	{ key = "last15m", text = "Last 15 minutes", e = "-15m" },
	{ key = "last60m", text = "Last 60 minutes", e = "-60m" },
	{ key = "last4h", text = "Last 4 hours", e = "-4h" },
	{ key = "last24h", text = "Last 24 hours", e = "-24h" },
	{ key = "last7d", text = "Last 7 days", e = "-7d" },
	{ key = "last30d", text = "Last 30 days", e = "-30d" },
	{ key = "today", text = "Today", e = "@d" },
	{ key = "yesterday", text = "Yesterday", e = "-1d@d", l = "@d" },
	{ key = "thisweek", text = "This week", e = "@w" },
	{ key = "lastweek", text = "Last week", e = "-1w@w", l = "@w" },
	{ key = "thismonth", text = "This month", e = "@mon" },
	{ key = "lastmonth", text = "Last month", e = "-1mon@mon", l = "@mon" },
	{ key = "all", text = "All time" },
}

local UNIT_WORD = { m = "minutes", h = "hours", d = "days", w = "weeks", mon = "months" }
local SNAP_WORD = { d = "day", w = "week", mon = "month" }

local function stamp(t) return date("%Y-%m-%dT%H:%M", t) end

-- one end of a date range: "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM"
local function endTime(text, isTo, now)
	if type(text) ~= "string" or text == "" then return nil, 1, "a date is needed" end
	if isTo and not text:find("T", 1, true) then
		local t, pos, msg = T.parse(text .. "T23:59", now)
		if not t then return nil, pos, msg end
		return t + 60
	end
	return T.parse(text, now)
end

function CV.pickerRange(choice, now)
	now = now or T.now()
	choice = choice or {}
	if choice.preset then
		for _, r in ipairs(CV.PRESETS) do
			if r.key == choice.preset then
				if not r.e then return nil, nil, r.text, "" end
				local e = T.parse(r.e, now)
				local l = r.l and T.parse(r.l, now) or now
				return e, l, r.text, "earliest=" .. r.e .. (r.l and (" latest=" .. r.l) or "")
			end
		end
		return nil, 1, "no such preset"
	elseif choice.relative then
		local n = tonumber(choice.n)
		if not n or n ~= math.floor(n) or n < 1 or n > 9999 then return nil, 1, "a whole number 1 to 9999" end
		local unit, snap = choice.unit, choice.snap
		if not UNIT_WORD[unit] then return nil, 1, "unit m, h, d, w or mon" end
		if snap and not SNAP_WORD[snap] then return nil, 1, "snap d, w or mon" end
		local txt = format("-%d%s%s", n, unit, snap and ("@" .. snap) or "")
		local e, pos, msg = T.parse(txt, now)
		if not e then return nil, pos, msg end
		local label = format("Last %d %s", n, UNIT_WORD[unit]) .. (snap and (", from start of " .. SNAP_WORD[snap]) or "")
		return e, now, label, "earliest=" .. txt
	elseif choice.between or choice.before or choice.since then
		local e, l, pos, msg
		if not choice.before then
			e, pos, msg = endTime(choice.from, false, now)
			if not e then return nil, pos, msg end
		end
		if not choice.since then
			l, pos, msg = endTime(choice.to, true, now)
			if not l then return nil, pos, msg end
		end
		if e and l and e > l then return nil, 1, "the start is after the end" end
		local label = choice.between and (choice.from .. " to " .. choice.to)
			or choice.before and ("Before " .. choice.to) or ("Since " .. choice.from)
		local term = (e and ("earliest=" .. stamp(e)) or "") .. ((e and l) and " " or "") .. (l and ("latest=" .. stamp(l)) or "")
		return e, l or now, label, term
	elseif choice.advanced then
		local etxt = choice.earliest
		local e, pos, msg = T.parse(etxt, now)
		if not e then return nil, pos, "earliest: " .. msg end
		local ltxt = (choice.latest ~= nil and choice.latest ~= "") and choice.latest or "now"
		local l
		l, pos, msg = T.parse(ltxt, now)
		if not l then return nil, pos, "latest: " .. msg end
		return e, l, etxt .. " to " .. ltxt, "earliest=" .. etxt .. " latest=" .. ltxt
	end
	return nil, 1, "no choice"
end

local TIMEFIELD = { earliest = true, latest = true, time = true }
function CV.typedTime(text)
	if type(text) ~= "string" then return false end
	local ok, toks = pcall(M.PSS_Psql.tokens, text)
	if not ok or not toks then return false end
	for i = 1, toks.n or 0 do
		local r = toks[i]
		if (r[3] == "field" or r[3] == "index") and TIMEFIELD[text:sub(r[1], r[1] + r[2] - 1):lower()] then return true end
	end
	return false
end

function CV.monthGrid(y, m)
	local t = T.parse(format("%04d-%02d-01", y, m))
	local y2, m2 = CV.monthStep(y, m, 1)
	local t2 = T.parse(format("%04d-%02d-01", y2, m2))
	return T.weekday(t) - 1, math.floor((t2 - t) / 86400 + 0.5)
end

function CV.monthStep(y, m, k)
	local i = y * 12 + (m - 1) + k
	return math.floor(i / 12), i % 12 + 1
end
