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
	if self.state == "needsload" then return "History not loaded" end
	if self.state == "error" then
		local e = self.err or {}
		return format("Error: %s (at %s)", tostring(e.msg), tostring(e.pos))
	end
	if not self.set then return "" end
	local s = format("%d rows, %.2f ms", self.set.n or 0, (self.info and self.info.ms) or 0)
	if self.state == "partial" then s = s .. ", partial" end
	local q = self.query or ""
	local H = M.PSS_History
	if H and q:find("index=log", 1, true) and not q:find("| head", 1, true) and #H.Log() >= H.Cap() then
		s = s .. ", history holds the newest " .. H.Cap() .. " lines"
	end
	return s
end

-- one value as a query literal: a number as is, anything else quoted
local function quote(v)
	if type(v) == "number" then return tostring(v) end
	return '"' .. tostring(v):gsub("[\\\"]", "\\%0") .. '"'
end

-- one value as a query literal: a number as is, anything else quoted
local function quote(v)
	if type(v) == "number" then return tostring(v) end
	return '"' .. tostring(v):gsub("[\\\"]", "\\%0") .. '"'
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
		return quote(v)
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

------------------------------------------------------------------------
-- Console tab model (STP-00255): highlight, sidebar, row actions, left list, help
--   M.PSS_ConsoleModel() -> cm   cm:Tokens, Sidebar, ChartKinds, RowActions, LeftRows, SetText
--   CV.colorize(text, toks, hexFn)  CV.term(field, value)  CV.addTerm(text, term)
--   M.PSS_DictPageModel(index, field)  CV.HELP  M.PSS_BUTTON_QUERIES  M.PSS_DeepDiveText(keyOrText, ctx)
------------------------------------------------------------------------
local sub, gsub = string.sub, string.gsub

local function esc(s) return (gsub(s, "|", "||")) end

-- PSQL has no || operator, so every || in the bar text is one typed pipe (the client edit box stores a typed | as ||).
function CV.unpipe(s) return (gsub(s or "", "||", "|")) end
function CV.pipe(s) return (gsub(s or "", "|", "||")) end

function CV.colorize(text, toks, hexFn)
	local out, at = {}, 1
	for i = 1, toks and toks.n or 0 do
		local t = toks[i]
		local p, len, kind = t[1], t[2], t[3]
		if p > at then out[#out + 1] = esc(sub(text, at, p - 1)) end
		if p >= at and len > 0 then
			local s = esc(sub(text, p, p + len - 1))
			local hex = kind ~= "space" and hexFn and hexFn(kind)
			out[#out + 1] = hex and ("|cff" .. hex .. s .. "|r") or s
			at = p + len
		end
	end
	if at <= #text then out[#out + 1] = esc(sub(text, at)) end
	return table.concat(out)
end

function CV.term(field, value)
	if type(value) == "number" then return field .. "=" .. tostring(value) end
	return field .. '="' .. gsub(tostring(value), '[\\"]', "\\%0") .. '"'
end

-- the first | outside quotes
local function pipeAt(text)
	local q, i = false, 1
	while i <= #text do
		local c = sub(text, i, i)
		if q then
			if c == "\\" then i = i + 1 elseif c == '"' then q = false end
		elseif c == '"' then q = true
		elseif c == "|" then return i end
		i = i + 1
	end
end

function CV.addTerm(text, term)
	text = text or ""
	local i = pipeAt(text)
	local r
	if i then
		local head = gsub(sub(text, 1, i - 1), "%s+$", "")
		r = (head ~= "" and (head .. " ") or "") .. term .. " " .. sub(text, i)
	else
		local head = gsub(text, "%s+$", "")
		r = (head ~= "" and (head .. " ") or "") .. term
	end
	return r
end

local KIND_ORDER = { "column", "line", "area", "bar", "donut", "heat", "number", "table" }
local SKIPCOL = { time = true, ts = true, message = true, label = true }

local CM = {}
CM.__index = CM

-- a service call that keeps its error (the dialog shows it): set or nil, err
function CV.call(name, input) return M.PSS_Call(name, input) end

-- The Save dialog's gate (STP-00256): canSave false with why at the 200 saved searches; chartWhy at the 100 saved charts
-- save a search, then its chart when asked: put = sq.put input, ch = { kind, chart = {x,y,series,opts} } | nil
-- -> id, err, chartErr (the search stays saved when only the chart fails)
function CV.saveSearch(put, ch)
	local set, err = CV.call("sq.put", put)
	if not set then return nil, err end
	local id = set[1][1]
	if ch then
		local c = ch.chart or {}
		local cs, cerr = CV.call("sq.chart.put", { queryId = id, kind = ch.kind, x = c.x or "", y = c.y or "", series = c.series or "", opts = c.opts or {} })
		if not cs then return id, nil, cerr or "chart not saved" end
	end
	return id
end

function CV.saveState(hasChart)
	local caps = M.PSS_SQ_CAPS or {}
	local out = { canSave = true }
	local q = M.PSS_Call("sq.list", { scope = "any" })
	if q and q.n >= (caps.records or 200) then
		out.canSave, out.why = false, "You have " .. (caps.records or 200) .. " saved searches. Delete one to save another."
	end
	if hasChart then
		local c = M.PSS_Call("sq.chart.list", {})
		if c and c.n >= (caps.charts or 100) then out.chartWhy = "You have " .. (caps.charts or 100) .. " saved charts." end
	end
	return out
end

function M.PSS_ConsoleModel() return setmetatable({ text = "" }, CM) end
function CM:SetText(t) self.text = t or "" end

function CM:Tokens(text)
	local toks = M.PSS_Psql.tokens(text)
	local ok, r, e = pcall(M.PSS_Psql.parse, text)
	local err
	if ok and r == nil then ok, e = false, e or "invalid query"		-- parse returns nil, err
	elseif not ok then e = r end
	if not ok then
		err = type(e) == "table" and { pos = e.pos or 1, msg = tostring(e.msg) } or { pos = 1, msg = tostring(e) }
	end
	return toks, err
end

function CM:Sidebar(set)
	local out = {}
	if not set or (set.n or 0) == 0 then return out end
	for _, col in ipairs(set.cols or {}) do
		if #out >= 8 then break end
		if not SKIPCOL[col] then
			local top = M.PSS_Call("q.top", set, { field = col, n = 5 })
			local rows = {}
			for i = 1, top and top.n or 0 do rows[i] = { top[i][1], top[i][2] } end
			out[#out + 1] = { field = col, rows = rows }
		end
	end
	return out
end

function CM:ChartKinds(shape)
	local allowed, out = ALLOWED[shape] or {}, {}
	for _, k in ipairs(KIND_ORDER) do if allowed[k] then out[#out + 1] = k end end
	return out
end

function CM:RowActions(set, i)
	local out = { { key = "copy", text = "Copy line" } }
	local row = set and set[i]
	if not row then return out end
	local oc, ic = M.PSS_SetCol(set, "owner"), M.PSS_SetCol(set, "item")
	if oc and row[oc] ~= nil then
		out[#out + 1] = { key = "owner", text = "Show this owner", query = CV.addTerm(self.text, CV.term("owner", row[oc])) }
	end
	if ic and row[ic] ~= nil then
		out[#out + 1] = { key = "item", text = "Where is this item", query = "index=inv " .. CV.term("item", row[ic]) }
	end
	return out
end

-- the tab-joined text of result row i; a secret cell is "" (PSS 02 section 10)
function CM:CopyLine(set, i)
	local row, cells = set and set[i], {}
	if not row then return "" end
	for k = 1, #set.cols do
		local v = row[k]
		if M.PSS_IsSecret(v) then cells[k] = "" else cells[k] = v == nil and "" or tostring(v) end
	end
	return table.concat(cells, "\t")
end

function CM:LeftRows()
	local rows = { { head = "System" } }
	rows[#rows + 1] = { key = "preset:events", text = "Events", query = "index=log | head 500" }
	local sys = M.PSS_Call("sq.system", { scope = "any" })
	for i = 1, sys and sys.n or 0 do
		local r = sys[i]
		rows[#rows + 1] = { key = "sys:" .. r[1], text = r[2], query = r[4], view = r[5] }
	end
	rows[#rows + 1] = { head = "Mine" }
	local mine = M.PSS_Call("sq.list", { scope = "any" })
	for i = 1, mine and mine.n or 0 do
		local r = mine[i]
		rows[#rows + 1] = { key = "sq:" .. r[1], text = r[2] .. (r[7] and " (cannot run)" or ""), query = r[5], broken = r[7] and true or nil }
	end
	rows[#rows + 1] = { head = "Indexes" }
	local ixs = M.PSS_Call("ix.list")
	for i = 1, ixs and ixs.n or 0 do
		rows[#rows + 1] = { key = "ix:" .. ixs[i][1], text = ixs[i][1], insert = "index=" .. ixs[i][1] }
	end
	rows[#rows + 1] = { head = "Data dictionary" }
	rows[#rows + 1] = { key = "dict", text = "Data dictionary" }
	return rows
end

function M.PSS_DictPageModel(index, field)
	local set, err
	if not index then set, err = M.PSS_Call("ix.list")
	elseif not field then set, err = M.PSS_Call("ix.dict", { index = index })
	else set, err = M.PSS_Call("ix.values", { index = index, field = field, n = 10 }) end
	if not set then return nil, err or "no result" end
	return set
end

CV.HELP = {
	{ "index=log | where time>-24h", "where: keep rows that match a comparison" },
	{ "index=log | fields time, cat", "fields: keep only these columns" },
	{ "index=log | rename cat as category", "rename: give a column another name" },
	{ "index=log | sort -time", "sort: order rows, - for descending" },
	{ "index=log | head 20", "head: the first rows (tail: the last)" },
	{ "index=log | dedup cat", "dedup: one row for each value" },
	{ "index=log | stats count by cat", "stats: count, sum, avg, min, max, dc ... by a column" },
	{ "index=log | timechart span=1d count", "timechart: a count over time" },
	{ "index=log | top 5 cat", "top: the most common values (rare: the least)" },
	{ "index=gold | calc k = copper / 1000", "calc: one sum of two columns or numbers" },
	{ "index=log | table time, cat", "table: show these columns as a table" },
	{ "index=log | stats count by cat | chart bar", "chart: draw the answer (last command)" },
	{ "gold", "A bare word searches the text of every index" },
	{ "index=log cat=whisper", "field=value keeps rows where it matches" },
	{ "earliest=-7d@d", "earliest and latest set the time range" },
}

-- The button query registry (STP-00257): a key -> query text (or a function of ctx) and
-- bind(ctx) -> params, range. Buttons call ns.DeepDive("<literal key>", ctx).
local EV_OWNER = "index=log owner=$owner | sort -time | head 200"
local function ownerRow(fn)
	return { query = EV_OWNER, bind = function(ctx) return { owner = fn(ctx.id) } end }
end
M.PSS_BUTTON_QUERIES = {
	["player.events"] = ownerRow(function(id) return M.PSS_PlayerHistoryKey(id) end),
	["member.events"] = ownerRow(function(id) return M.PSS_History.MemberKey(id) end),
	["filter.events"] = ownerRow(function(id) return M.PSS_FilterOwnerKey(id) end),
	["guild.events"] = { query = "index=log guild=$guild | sort -time | head 200", bind = function(ctx) return { guild = ctx.id } end },
	["group.events"] = { query = "index=log rule=$rule | sort -time | head 200", bind = function(ctx) return { rule = ctx.id } end },
	["player.all"] = { query = 'index=log owner="p:*" | sort -time | head 200' },
	["member.all"] = { query = 'index=log owner="g:*" | sort -time | head 200' },
	["filter.all"] = { query = 'index=log owner="f:*" | sort -time | head 200' },
	["guild.all"] = { query = 'index=log guild="*" | sort -time | head 200' },
	["group.all"] = { query = 'index=log guild="*" | sort -time | head 200' },
	["pane.events"] = { pane = "events" },
	["pane.slice"] = { pane = "slice" },
	["wh.holders"] = { sys = "wh.holders", bind = function(ctx) return { item = ctx.item } end },
}

local function rowText(row, ctx)
	if row.sys then
		for _, r in ipairs(M.PSS_SQ_SYSTEM or {}) do if r.id == row.sys then return r.q end end
		return nil
	end
	return type(row.query) == "function" and row.query(ctx) or row.query
end

local function sortedNames(set)
	local out = {}
	for k, on in pairs(set or {}) do
		if on and type(k) == "string" and k:match("^[%w_]+$") then out[#out + 1] = k end
	end
	table.sort(out)
	return out
end

local function beforePipe(text, add)
	local a, b = text:find(" | ", 1, true)
	if not a then return text .. add end
	return text:sub(1, a - 1) .. add .. text:sub(a)
end

local function orList(names)
	for i, c in ipairs(names) do names[i] = "cat=" .. c end
	return table.concat(names, " OR ")
end

local PERIOD_RANGE = {
	session = function() return { advanced = { earliest = "@session" } } end,
	day = function() return { preset = "last24h" } end,
}

function M.PSS_DeepDiveText(keyOrText, ctx)
	local row = type(keyOrText) == "string" and M.PSS_BUTTON_QUERIES[keyOrText]
	if row then
		ctx = ctx or {}
		local base, range = row, nil
		local evKind = keyOrText:match("^(%a+)%.events$")
		if row.pane then
			base = M.PSS_BUTTON_QUERIES[tostring(ctx.kind) .. ".events"]
			if not base then return nil, "unknown query" end
			evKind = ctx.kind
		end
		if (row.pane or evKind) and not ctx.id then
			base = M.PSS_BUTTON_QUERIES[tostring(evKind) .. ".all"]
			if not base then return nil, "unknown query" end
		end
		local text = rowText(base, ctx)
		if not text then return nil, "unknown query" end
		local params
		if base.bind then params, range = base.bind(ctx) end
		params = params or {}
		if row.pane == "slice" then
			text = beforePipe(text, " cat=$cat")
			params.cat = ctx.cat
		elseif row.pane == "events" then
			local f = ctx.period and PERIOD_RANGE[ctx.period]
			range = f and f() or nil
		end
		local names = type(ctx) == "table" and ctx.cats and sortedNames(ctx.cats) or {}
		if #names > 0 then text = beforePipe(text, " (" .. orList(names) .. ")") end
		for name in text:gmatch("%$([%w_]+)") do
			if params[name] == nil then return nil, "nothing selected" end
		end
		return text, params, range
	end
	if type(keyOrText) == "string" then return keyOrText, ctx, nil end
	return nil, "unknown query"
end

-- the values a $name takes when the context has none (nil = nothing to fill in)
M.PSS_QUERY_SOURCES = {
	owner = function(ctx) return ctx.owner end,
	item = function()
		local ok, set = pcall(M.PSS_Search, "index=inv | sort -count | head 1", {})
		if not ok or not set or not set[1] then return nil end
		local i = M.PSS_SetCol(set, "item")
		return i and set[1][i] or nil
	end,
}

-- every $name in text put in as a literal; nil, name for the first one nothing fills
function M.PSS_ResolveQuery(text, ctx)
	ctx = ctx or {}
	local missing
	local out = text:gsub("%$([%a_][%w_]*)", function(name)
		if missing then return nil end
		local v = ctx[name]
		if v == nil and M.PSS_QUERY_SOURCES[name] then v = M.PSS_QUERY_SOURCES[name](ctx) end
		if v == nil then missing = name; return nil end
		return quote(v)
	end)
	if missing then return nil, missing end
	return out
end

M.PSS_UNBOUND_TEXT = { owner = "Select a player in Player Ignore List first", item = "No item recorded yet", other = "This search needs a value Spyglass cannot fill" }

M.PSS_PANE_OFF = "Event Logging is off. Turn it on in Optional Features."

-- types -> the log categories they stand for (party, raid and BG lines are told apart by channel)
local TYPE_CATS = { whisper = { "whisper" }, invite = { "partyInvite", "guildInvite" }, world = { "world" }, guild = { "guildChat" } }

-- the pane's text and params: the kind's .events row, hidden types (a set of type names) excluded
function M.PSS_PaneQuery(kind, id, hidden)
	local row = M.PSS_BUTTON_QUERIES[tostring(kind) .. ".events"]
	if not row then return nil, "unknown query" end
	local ctx = { kind = kind, id = id }
	local text = rowText(row, ctx)
	local params = row.bind and row.bind(ctx) or {}
	local cats = {}
	for t, on in pairs(hidden or {}) do
		if on then for _, c in ipairs(TYPE_CATS[t] or {}) do cats[#cats + 1] = c end end
	end
	if #cats > 0 then
		table.sort(cats)
		text = beforePipe(text, " NOT (" .. orList(cats) .. ")")
	end
	return text, params
end

-- the Queries drop-down of a pane: { { id, name, text, system } ... }
function M.PSS_PaneQueries(kind)
	local scope = kind == "member" and "guild" or kind
	local out = {}
	local sys = M.PSS_Call("sq.system", { scope = scope })
	for i = 1, sys and sys.n or 0 do
		out[#out + 1] = { id = sys[i][1], name = sys[i][2], text = sys[i][4], system = true }
	end
	local mine = M.PSS_Call("sq.list", { scope = scope })
	for i = 1, mine and mine.n or 0 do
		out[#out + 1] = { id = mine[i][1], name = mine[i][2], text = mine[i][5] }
	end
	return out
end
