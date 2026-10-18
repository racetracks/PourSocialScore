-- The Spyglass console (search-helper, phase B, 3.8.0.119), as a run.lua script. The phase is PSS_PHASE;
-- each prints "PASS console <phase>" or "FAIL console: <phase>: <what>". Run by console_phases.sh.
local phase = os.getenv("PSS_PHASE") or "skeleton"
local fail = false
local function check(ok, msg) if not ok then print("FAIL console: " .. phase .. ": " .. tostring(msg)) fail = true end return ok end
check(M.PSS_Need("Libraries"), "Libraries did not load")
local PH = {}

local ui
local function GUI()
	if not ui then
		check(M.PSS_Need("GUI"), "GUI did not load")
		ui = H.Private("PourSocialScore_GUI")
	end
	return ui
end

-- fn(n, name) in Modern (2), Classic (0), Dark (1); the look is restored to Modern
local function looks(fn)
	local u = GUI()
	for _, p in ipairs({ { 2, "modern" }, { 0, "classic" }, { 1, "dark" } }) do
		M.PSS_SetOpt("uiSkin", "global", p[1])
		u.Fresh()
		fn(p[1], p[2])
	end
	M.PSS_SetOpt("uiSkin", "global", 2)
	u.Fresh()
end

-- UTC seconds of a civil date (Howard Hinnant's days_from_civil)
local function utc(y, m, d, h, mi, s)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return (era * 146097 + doe - 719468) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + (s or 0)
end

-- a record set from column names and rows (n = row count)
local function set(cols, rows)
	local s = M.PSS_Set(cols)
	for i, r in ipairs(rows or {}) do s[i] = r end
	s.n = #(rows or {})
	return s
end

PH.skeleton = function()
	check(M.PSS_CONSOLE_NAME == "Spyglass", "M.PSS_CONSOLE_NAME is " .. tostring(M.PSS_CONSOLE_NAME))
end

-- TST-00932 chart kit
local function COL() local r = {} for i = 1, 5 do r[i] = { string.char(96 + i), i } end return set({ "k", "v" }, r) end
local function SER(nc)
	local cols, rows = { "_time" }, {}
	for c = 1, nc or 2 do cols[#cols + 1] = "s" .. c end
	for i = 1, 10 do
		local r = { "t" .. i }
		for c = 1, nc or 2 do r[#r + 1] = i * c end
		rows[i] = r
	end
	return set(cols, rows)
end
local function HEAT(nx, ny)
	local rows = {}
	for x = 1, nx do for y = 1, ny do rows[#rows + 1] = { "d" .. x, "h" .. y, x + y } end end
	return set({ "weekday", "hour", "count" }, rows)
end
local function NUM() return set({ "count" }, { { 42 } }) end
local function TAB() local r = {} for i = 1, 5 do r[i] = { "o" .. i, i } end return set({ "owner", "n" }, r) end
local function newChart(w, h) return GUI().NewChart(UIParent, w or 300, h or 140) end
local function nshown(f, pool)
	local n = 0
	for _, o in ipairs(f.p[pool]) do if o:IsShown() then n = n + 1 end end
	return n
end
local function geom(f)
	local t = {}
	for _, pool in ipairs({ "bars", "cells", "hits", "fills" }) do
		for i, o in ipairs(f.p[pool]) do
			if o:IsShown() then
				local p = o._point or {}
				t[#t + 1] = pool .. i .. ":" .. tostring(o._w) .. "x" .. tostring(o._h) .. "@" .. tostring(p[1]) .. "," .. tostring(p[4]) .. "," .. tostring(p[5])
			end
		end
	end
	return table.concat(t, "|")
end

PH.chartkinds = function()
	local cases = {
		{ "column", COL(), function(f) return nshown(f, "bars") == 5 end },
		{ "bar", COL(), function(f) return nshown(f, "bars") == 5 end },
		{ "line", SER(), function(f) return nshown(f, "segs") == 18 end },
		{ "area", SER(), function(f) return nshown(f, "segs") == 18 and nshown(f, "fills") == 20 end },
		{ "donut", COL(), function(f) return f.pie and f.pie.frame:IsShown() and #f.pie.slices == 5 end },
		{ "heat", HEAT(7, 24), function(f) return nshown(f, "cells") == 168 end },
		{ "number", NUM(), function(f) return f.num:IsShown() and f.num:GetText() == "42" end },
		{ "table", TAB(), function(f) return f.tableList and f.tableList.count == 5 end },
	}
	for _, c in ipairs(cases) do
		local sig
		looks(function(n, name)
			local f = newChart()
			f:Draw(c[2], { kind = c[1] })
			check(f:Kind() == c[1], c[1] .. " Kind in " .. name)
			check(c[3](f), c[1] .. " objects in " .. name)
			local g = geom(f)
			if sig == nil then sig = g else check(sig == g, c[1] .. " geometry differs in " .. name) end
		end)
	end
end

PH.chartcaps = function()
	local f = newChart()
	local rows = {}
	for i = 1, 61 do rows[i] = { "x" .. i, i } end
	f:Draw(set({ "k", "v" }, rows), { kind = "column" })
	check(nshown(f, "bars") == 61, "61 bars, got " .. nshown(f, "bars"))
	local last = f.p.bars[61]
	check(last.tipTitle == "other" and last.tipText == "v: 61", "last bar is other = row 61: " .. tostring(last.tipTitle) .. " " .. tostring(last.tipText))
	f:Draw(SER(7), { kind = "line" })
	check(nshown(f, "segs") == 7 * 9, "7 series, segments " .. nshown(f, "segs"))
	local sl = {}
	for i = 1, 9 do sl[i] = { "x" .. i, i } end
	f:Draw(set({ "k", "v" }, sl), { kind = "donut" })
	check(#f.pie.slices == 9, "9 slices (8 + other), got " .. #f.pie.slices)
	f:Draw(HEAT(8, 25), { kind = "heat" })
	check(nshown(f, "cells") == 7 * 24, "7 x 24 cells, got " .. nshown(f, "cells"))
end

PH.chartempty = function()
	local f = newChart()
	f:Draw(COL(), { kind = "column" })
	f:Draw(set({ "k", "v" }, {}), { kind = "column" })
	check(f.noText:IsShown() and f.noText:GetText() == "No results", "No results not shown")
	for _, pool in ipairs({ "bars", "segs", "cells", "fills", "hits" }) do check(nshown(f, pool) == 0, pool .. " still shown") end
	f:Draw(nil, { kind = "heat" })
	check(f.noText:IsShown(), "nil set not empty")
end

PH.chartpending = function()
	local f = newChart()
	f:Draw(COL(), { kind = "column", pending = true })
	check(f.pendText:IsShown() and f.pendText:GetText() == "Loading items", "Loading items not shown")
	f:Draw(COL(), { kind = "column" })
	check(not f.pendText:IsShown(), "Loading items still shown")
end

PH.chartrepaint = function()
	local f = newChart()
	f:Draw(COL(), { kind = "column" })
	local u = GUI()
	-- every frame, texture, line and font string the stub makes is in H.frames
	local before = #H.frames
	for _, p in ipairs({ { 0, "classic" }, { 1, "dark" }, { 2, "modern" } }) do
		M.PSS_SetOpt("uiSkin", "global", p[1])
		u.Fresh()
		local c = f.grid[1]._color
		local want = p[1] == 1 and u.CHART.gridDark or u.CHART.grid
		check(c and c[1] == want[1] and c[2] == want[2] and c[3] == want[3] and c[4] == want[4], "grid colour in " .. p[2])
	end
	M.PSS_SetOpt("uiFont", "global", "Fonts\\FRIZQT__.TTF")
	u.Fresh()
	M.PSS_SetOpt("uiFont", "global", nil)
	u.Fresh()
	check(#H.frames == before, "repaint created " .. (#H.frames - before) .. " objects")
end

PH.chartpool = function()
	local f = newChart()
	local function creates()
		local n = 0
		for _, p in pairs(f.p) do n = n + #p end
		for _ in pairs(f.lists) do n = n + 1000 end
		return n
	end
	local sets = { { COL(), "column" }, { SER(), "line" }, { HEAT(7, 24), "heat" } }
	for _, s in ipairs(sets) do f:Draw(s[1], { kind = s[2] }) end
	local before, frames = creates(), #H.frames
	for i = 1, 100 do
		for _, s in ipairs(sets) do f:Draw(s[1], { kind = s[2] }) end
	end
	check(creates() == before, "pool grew")
	check(#H.frames == frames, "objects created after the first draws: " .. (#H.frames - frames))
end

PH.chartalpha = function()
	looks(function(n, name)
		local f = newChart()
		f:Draw(COL(), { kind = "column" })
		local ls = { f.ylab[1], f.ylab[2], f.xlab[1], f.xlab[2], f.xlab[3] }
		for i, fs in ipairs(ls) do
			local tc = fs:GetTextColor()
			check(fs:GetAlpha() == 0.7, "label " .. i .. " alpha in " .. name)
			check(select(4, fs:GetTextColor()) == 1, "label " .. i .. " text alpha in " .. name)
		end
	end)
end

PH.charthover = function()
	local f = newChart()
	local u = GUI()
	local calls = {}
	local old = u.Tip
	u.Tip = function(o, t) calls[#calls + 1] = { o, t } end
	f:Draw(COL(), { kind = "column" })
	local b = f.p.bars[2]
	b._scripts.OnEnter(b)
	check(calls[1] and calls[1][1] == b and calls[1][2].title == "b" and calls[1][2].text == "v: 2", "bar tip")
	f:Draw(HEAT(2, 2), { kind = "heat" })
	local c = f.p.cells[1]
	c._scripts.OnEnter(c)
	check(calls[2] and calls[2][2].title == "d1" and calls[2][2].text == "h1: 2", "heat tip")
	f:Draw(SER(), { kind = "line" })
	local h = f.p.hits[3]
	h._scripts.OnEnter(h)
	check(calls[3] and calls[3][2].title == "t3" and calls[3][2].text == "s1: 3\ns2: 6", "line tip")
	for _, pool in ipairs({ "bars", "cells", "hits" }) do
		for _, o in ipairs(f.p[pool]) do check(o._scripts.OnUpdate == nil, pool .. " has OnUpdate") end
	end
	u.Tip = old
end

-- TST-00933 query view
local History = M.PSS_History
local function plantLog(n)
	if not M.PSS_LoggingReady() then M.PSS_LoadLogging() end
	local log = History.Log()
	local t0 = GetServerTime() - n * 60
	for i = 1, n do
		local e = History.NewEntry(History.ALL_CATS[i % 6 + 1], "CHAT_MSG_CHANNEL", "hello there " .. i, "Trade", nil)
		e.ts = t0 + i * 60
		e.o = "p:Owner" .. (i % 7 + 1) .. "-Realm"
		log[#log + 1] = e
	end
	return log
end
local function newView(o)
	local v = GUI().NewQueryView(UIParent, o)
	return v
end

PH.qvrun = function()
	plantLog(200)
	local cases = {
		{ "index=log | head 5", "table" },
		{ "index=log | stats count by cat", "bar", "table" },
		{ "index=log | timechart span=1h count", "column" },
	}
	for _, c in ipairs(cases) do
		local v = newView({ w = 400, h = 240, query = c[1] })
		v:Run(true)
		local k = v.chart:Kind()
		check(k == c[2] or k == c[3], c[1] .. ": kind " .. tostring(k) .. " state " .. tostring(v.vm.state) .. " " .. v.vm:Status())
		check(v.vm:Status():match("^%d+ rows, [%d.]+ ms") ~= nil, c[1] .. ": status " .. v.vm:Status())
	end
end

PH.qvtier = function()
	check(not M.PSS_LoggingReady(), "Logging not loaded at the start")
	local v = newView({ w = 400, h = 240, query = "index=log | head 5" })
	v:Run(false)
	check(v.vm.state == "needsload", "state " .. tostring(v.vm.state))
	check(not M.PSS_LoggingReady(), "the view loaded Logging")
	check(v.load:IsShown(), "Load history not shown")
	v.load._scripts.OnClick(v.load)
	check(M.PSS_LoggingReady(), "Load history did not load Logging")
	check(v.vm.state == "shown", "state after load " .. tostring(v.vm.state))
	check(not v.load:IsShown(), "Load history still shown")
end

PH.qvlisten = function()
	local ui = GUI()
	SlashCmdList["PSS"]("gui")
	local win = _G.PSS_Window
	win:Hide()
	local mine = {}
	for _, ev in pairs(M.PSS_QV_EVENTS) do mine[ev] = true end
	local realReg = M.Events.Register
	local n = 0
	M.Events.Register = function(ev, ...) if mine[ev] then n = n + 1 end return realReg(ev, ...) end
	if win:IsShown() then win:Hide() end
	SlashCmdList["PSS"]("gui")
	local base = n
	win:Hide()
	n = 0
	local v = newView({ w = 400, h = 240, query = "index=log | head 5" })
	check(n == 0, "window hidden: " .. n .. " registrations")
	SlashCmdList["PSS"]("gui")
	check(n == base + 3, ("window shown: %d registrations, expected %d"):format(n, base + 3))
	M.Events.Register = realReg
	win:Hide()
end

PH.qvburst = function()
	plantLog(50)
	GUI()
	SlashCmdList["PSS"]("gui")
	local win = _G.PSS_Window
	local v = newView({ w = 400, h = 240, query = "index=log | head 5" })
	v:Run(true)
	local calls = 0
	local real = M.PSS_Search
	M.PSS_Search = function(...) calls = calls + 1 return real(...) end
	for _ = 1, 50 do M.Events.Fire("HISTORY_CHANGED") end
	check(calls == 0, "searched before the timer: " .. calls)
	H.RunTimers()
	M.PSS_Search = real
	check(calls == 1, "searches after the burst: " .. calls)
	win:Hide()
end

PH.qvdeep = function()
	plantLog(20)
	local ui = GUI()
	local got
	local old = ui.DeepDive
	ui.DeepDive = function(text, params) got = { text, params } end
	local v = newView({ w = 400, h = 240, query = "index=log owner=$owner", params = { owner = "p:A-R" }, deepDive = true })
	v:Run(true)
	v.deep._scripts.OnClick(v.deep)
	check(got and type(got[1]) == "string" and got[1]:find("p:A-R", 1, true), "deep dive text: " .. tostring(got and got[1]))
	ui.DeepDive = old
end

PH.qvlook = function()
	plantLog(100)
	local v = newView({ w = 400, h = 240, query = "index=log | stats count by cat" })
	v:Run(true)
	local sig
	local creates = 0
	local realCreate = CreateFrame
	looks(function(n, name)
		CreateFrame = function(...) creates = creates + 1 return realCreate(...) end
		v:Refresh()
		CreateFrame = realCreate
		local g = geom(v.chart) .. "|" .. v:GetWidth() .. "x" .. v:GetHeight()
		if sig == nil then sig = g else check(sig == g, "geometry differs in " .. name) end
	end)
	CreateFrame = realCreate
	check(creates == 0, "create calls after the first draw: " .. creates)
end

PH.qvlayers = function()
	local p = io.popen("lua5.1 tools/check_layers.lua 2>&1")
	local out = p:read("*a")
	p:close()
	for line in out:gmatch("[^\n]+") do
		check(not line:find("PSS_QueryView.lua", 1, true), "check_layers: " .. line)
	end
end

PH.qvchaos = function()
	plantLog(100)
	local v = newView({ w = 400, h = 240, query = "index=log | head 5" })
	v:Run(true)
	local real = M.PSS_Search
	local rnd = 12345
	local function nextMode()
		rnd = (rnd * 1103515245 + 12345) % 2147483648
		return rnd % 3
	end
	for i = 1, 200 do
		local mode = nextMode()
		M.PSS_Search = function(...)
			if mode == 0 then error("boom " .. i) end
			if mode == 1 then return nil, { code = "x", pos = 1, msg = "bad" } end
			return real(...)
		end
		local ok, e = pcall(v.Refresh, v)
		check(ok, "Refresh raised: " .. tostring(e))
		if mode < 2 then
			check(v.vm.state == "error" and v.status:GetText():find("^Error"), "no error state at " .. i)
		else
			check(v.vm.state == "shown", "not shown at " .. i .. ": " .. tostring(v.vm.state))
		end
	end
	M.PSS_Search = real
end

-- TST-00967 time picker
local CV = M.PSS_ConsoleView
local NOW = utc(2026, 10, 17, 13, 35)
local function U(d, h) return utc(2026, 10, d, h or 0) end

PH.pickpresets = function()
	local want = {
		last15m = { NOW - 900, NOW }, last60m = { NOW - 3600, NOW }, last4h = { NOW - 14400, NOW },
		last24h = { NOW - 86400, NOW }, last7d = { NOW - 604800, NOW }, last30d = { NOW - 2592000, NOW },
		today = { U(17), NOW }, yesterday = { U(16), U(17) }, thisweek = { U(12), NOW },
		lastweek = { U(5), U(12) }, thismonth = { U(1), NOW }, lastmonth = { utc(2026, 9, 1), U(1) },
		all = { nil, nil },
	}
	check(#CV.PRESETS == 13, "13 presets, got " .. #CV.PRESETS)
	for _, r in ipairs(CV.PRESETS) do
		local e, l, label = CV.pickerRange({ preset = r.key }, NOW)
		local w = want[r.key]
		check(w ~= nil, "unexpected preset " .. r.key)
		if w then
			check(e == w[1], r.key .. ": earliest " .. tostring(e) .. " want " .. tostring(w[1]))
			check(l == w[2], r.key .. ": latest " .. tostring(l) .. " want " .. tostring(w[2]))
			check(label == r.text, r.key .. ": label " .. tostring(label))
		end
	end
end

PH.pickrelative = function()
	local e, l, label, term = CV.pickerRange({ relative = true, n = 3, unit = "d", snap = "d" }, NOW)
	check(e == U(14) and l == NOW, "3d@d range " .. tostring(e) .. " " .. tostring(l))
	check(term == "earliest=-3d@d", "term " .. tostring(term))
	check(label == "Last 3 days, from start of day", "label " .. tostring(label))
	local a, pos, msg = CV.pickerRange({ relative = true, n = 0, unit = "d" }, NOW)
	check(a == nil and pos == 1 and msg == "a whole number 1 to 9999", "n = 0 refused: " .. tostring(msg))
end

PH.pickrange = function()
	local e, l = CV.pickerRange({ between = true, from = "2026-10-01", to = "2026-10-07T18:00" }, NOW)
	check(e == U(1) and l == U(7, 18), "between " .. tostring(e) .. " " .. tostring(l))
	local e2, l2 = CV.pickerRange({ between = true, from = "2026-10-01", to = "2026-10-07" }, NOW)
	check(l2 == U(8), "date-only end is the next midnight: " .. tostring(l2))
	local a, pos, msg = CV.pickerRange({ between = true, from = "2026-10-09", to = "2026-10-07" }, NOW)
	check(a == nil and msg == "the start is after the end", "from after to: " .. tostring(msg))
	local b = CV.pickerRange({ before = true, to = "2026-10-07T18:00" }, NOW)
	check(b == nil, "before has no start")
	local off, days = CV.monthGrid(2026, 10)
	check(off == 3 and days == 31, "October 2026 grid " .. tostring(off) .. " " .. tostring(days))
	local y, m = CV.monthStep(2026, 12, 1)
	check(y == 2027 and m == 1, "monthStep forward")
	y, m = CV.monthStep(2026, 1, -1)
	check(y == 2025 and m == 12, "monthStep back")
	local cal = GUI().NewCalendar(UIParent, function(day) PH.picked = day end)
	cal:SetMonth(2026, 10)
	local shown = 0
	for _, b in ipairs(cal.days) do if b:IsShown() then shown = shown + 1 end end
	check(shown == 31, "calendar shows 31 days, " .. shown)
	cal.days[off + 1]:GetScript("OnClick")(cal.days[off + 1])
	check(PH.picked == "2026-10-01", "day 1 writes " .. tostring(PH.picked))
end

PH.pickadvanced = function()
	local e, l = CV.pickerRange({ advanced = true, earliest = "-7d@d", latest = "now" }, NOW)
	check(e == U(10) and l == NOW, "advanced " .. tostring(e) .. " " .. tostring(l))
	local a, pos, msg = CV.pickerRange({ advanced = true, earliest = "-7x", latest = "" }, NOW)
	check(a == nil and tostring(msg):find("^earliest: "), "bad earliest: " .. tostring(msg))
	a, pos, msg = CV.pickerRange({ advanced = true, earliest = "-7d", latest = "zzz" }, NOW)
	check(a == nil and tostring(msg):find("^latest: "), "bad latest: " .. tostring(msg))
end

PH.picktyped = function()
	check(CV.typedTime("index=log earliest=-7d") == true, "earliest typed")
	check(CV.typedTime("index=log gold") == false, "no time typed")
	local seen
	local real = M.PSS_Search
	M.PSS_Search = function(q, o) seen = o; return real(q, o) end
	local v = newView({ w = 400, h = 240, query = "index=log earliest=-7d" })
	v:SetRange({ earliest = NOW - 86400, latest = NOW })
	v:Run(true)
	check(seen and seen.from == nil, "typed time ignores the picker range: " .. tostring(seen and seen.from))
	local v2 = newView({ w = 400, h = 240, query = "index=log gold" })
	v2:SetRange({ earliest = NOW - 86400, latest = NOW })
	v2:Run(true)
	check(seen and seen.from == NOW - 86400, "plain query uses the range: " .. tostring(seen and seen.from))
	M.PSS_Search = real
end

PH.pickaxis = function()
	local save = GetServerTime
	GetServerTime = function() return NOW end
	if not M.PSS_LoggingReady() then M.PSS_LoadLogging() end
	local log = History.Log()
	for i, d in ipairs({ 9, 11, 13, 13, 17 }) do
		local e = History.NewEntry(History.ALL_CATS[i % 6 + 1], "CHAT_MSG_CHANNEL", "hello " .. i, "Trade", nil)
		e.ts = utc(2026, 10, d, 9, 0)
		e.o = "p:Owner-Realm"
		log[#log + 1] = e
	end
	local v = newView({ w = 400, h = 240, query = "index=log | timechart span=1d count" })
	local p = GUI().NewTimePicker(UIParent)
	p:SetChoice({ preset = "last7d" })
	local e, l = p:Range()
	v:SetRange({ earliest = e, latest = l })
	v:Run(true)
	local rs = v:Result()
	GetServerTime = save
	check(rs and rs.n == 8, "8 day rows, got " .. tostring(rs and rs.n) .. " " .. tostring(v.vm:Status()))
	if rs and rs.n == 8 then
		check(rs[1][2] == 0 and rs[8][2] == 1, "empty first day 0, last day 1: " .. tostring(rs[1][2]) .. " " .. tostring(rs[8][2]))
	end
end

PH.picklooks = function()
	local function sig(f, out, depth)
		for _, c in ipairs({ f:GetChildren() }) do
			if c:IsShown() then
				local pt, rel, rp, x, y = c:GetPoint(1)
				out[#out + 1] = format("%d:%s %.1fx%.1f %s %s %.1f %.1f", depth, tostring(c:GetObjectType()), c:GetWidth() or 0, c:GetHeight() or 0, tostring(pt), tostring(rp), x or 0, y or 0)
				sig(c, out, depth + 1)
			end
		end
	end
	local ref = {}
	looks(function(n, name)
		local p = GUI().NewTimePicker(UIParent)
		p:SetPoint("CENTER")
		for _, mode in ipairs({ "relative", "range", "advanced" }) do
			p:OpenPanel(mode)
			local panel, cal = p:Panel()
			if mode == "range" then cal:SetMonth(2026, 10); cal:Show() end
			local out = {}
			sig(panel, out, 0)
			if mode == "range" then sig(cal, out, 0) end
			local r = ref[mode]
			if not r then ref[mode] = out
			else
				check(#out == #r, name .. " " .. mode .. ": " .. #out .. " shown, modern " .. #r)
				for i = 1, math.min(#out, #r) do
					if out[i] ~= r[i] then check(false, name .. " " .. mode .. " #" .. i .. ": " .. out[i] .. " vs " .. r[i]) break end
				end
			end
			panel:Hide()
		end
	end)
end

PH.pickperview = function()
	local a, b = GUI().NewTimePicker(UIParent), GUI().NewTimePicker(UIParent)
	a:SetChoice({ preset = "today" })
	b:SetChoice({ preset = "last4h" })
	check(a:Choice().preset == "today" and b:Choice().preset == "last4h", "choices are per picker")
	a:SetTyped(true)
	check(a:Choice().preset == "today", "typed keeps the choice")
end


-- TST-00934 console tab (model level)
PH.conopts = function()
	local all, base = M.PSS_OPTION_REG, nil
	check(all.conTime and all.conTime.default == "all" and all.conRows.default == 500, "con options declared")
	local ch = all.conTime.choices
	check(#ch == 13 and ch[1][1] == "all", "13 conTime choices, got " .. #ch)
	local CV = M.PSS_ConsoleView
	for i, r in ipairs(CV.PRESETS) do
		local found
		for _, c in ipairs(ch) do if c[1] == r.key and c[2] == r.text then found = true end end
		check(found, "preset " .. r.key .. " in conTime choices")
	end
	local db = PSS_OptionsDB
	local function dump() local n = 0 for k in pairs(db) do if tostring(k):find("^con") then n = n + 1 end end return n end
	base = dump()
	M.PSS_SetOpt("conRows", "global", 800)
	M.PSS_SetOpt("conTime", "global", "last7d")
	check(M.PSS_Opt("conRows") == 800 and M.PSS_Opt("conTime") == "last7d", "set values read back")
	M.PSS_SetOpt("conRows", "global", 500)
	M.PSS_SetOpt("conTime", "global", "all")
	check(dump() == base, "defaults stored sparse: " .. dump() .. " vs " .. base)
	local found
	for _, t in ipairs(M.PSS_UI_TABS) do if t.key == "console" then found = true end end
	check(found, "console tab in M.PSS_UI_TABS")
end

PH.conmodel = function()
	local CV = M.PSS_ConsoleView
	check(CV.colorize("a|b", { n = 1, { 1, 3, "word" } }, function() return "ff0000" end) == "|cffff0000a||b|r", "colorize wraps and escapes")
	check(CV.colorize("a b", { n = 3, { 1, 1, "word" }, { 2, 1, "space" }, { 3, 1, "word" } }, function(k) return k == "word" and "00ff00" or nil end)
		== "|cff00ff00a|r |cff00ff00b|r", "space plain")
	check(CV.term("owner", 'a"b') == 'owner="a\\"b"' or CV.term("owner", 'a"b') == 'owner="a\"b"', "term escapes quote")
	check(CV.term("n", 5) == "n=5", "number bare")
	check(CV.addTerm("index=log | head 5", 'x="1"') == 'index=log x="1" | head 5', "addTerm before pipe: " .. CV.addTerm("index=log | head 5", 'x="1"'))
	check(CV.addTerm('index=log m="a|b"', "x=1") == 'index=log m="a|b" x=1', "addTerm pipe inside quotes")
	check(CV.addTerm("", "x=1") == "x=1", "addTerm empty")
	local q, p, r = M.PSS_DeepDiveText("index=log")
	check(q == "index=log", "text passes through")
	M.PSS_BUTTON_QUERIES.k = { query = "index=pss", bind = function(c) return { a = c }, "R" end }
	q, p, r = M.PSS_DeepDiveText("k", 7)
	check(q == "index=pss" and p.a == 7 and r == "R", "key resolves")
	M.PSS_BUTTON_QUERIES.k = nil
	q, p = M.PSS_DeepDiveText(42)
	check(q == nil and p == "unknown query", "bad input")
	local cm = M.PSS_ConsoleModel()
	local rows, heads = cm:LeftRows(), {}
	for _, x in ipairs(rows) do if x.head then heads[#heads + 1] = x.head end end
	check(table.concat(heads, ",") == "System,Mine,Indexes,Data dictionary", "four groups: " .. table.concat(heads, ","))
	check(next(cm:Sidebar(set({ "a" }, {}))) == nil, "empty sidebar")
	check(#CV.HELP == 15, "15 help rows")
	for i, h in ipairs(CV.HELP) do
		local ok, e = pcall(M.PSS_Psql.parse, h[1])
		check(ok, "help " .. i .. " parses: " .. h[1] .. " " .. tostring(type(e) == "table" and e.msg or e))
	end
	local kinds = cm:ChartKinds("series")
	check(table.concat(kinds, ",") == "column,line,area,table", "series kinds " .. table.concat(kinds, ","))
	local s = cm:Sidebar(set({ "owner", "n", "time" }, { { "a", 1, 5 }, { "a", 2, 6 }, { "b", 3, 7 } }))
	check(#s == 2 and s[1].field == "owner" and s[1].rows[1][1] == "a" and s[1].rows[1][2] == 2, "sidebar owner top")
end


-- TST-00934 console tab (window level)
local function click(b, button) local fn = b and b:GetScript("OnClick") if fn then fn(b, button or "LeftButton") end end
local function conIndex() return M.PSS_UITabIndex("console") end
local function openCon()
	GUI()
	if not (_G.PSS_Window and _G.PSS_Window:IsShown()) then SlashCmdList.PSS("gui") end
	local win = _G.PSS_Window
	click(win.tabs[conIndex()])
	return win.pages[conIndex()], win
end
local function hexOf(t, text) return ui.SyntaxHex and M.PSS_ConsoleView.colorize(text, t, ui.SyntaxHex) end

PH.contab = function()
	GUI()
	local n, orig = 0, ui.TabBuilders.console
	check(orig, "console builder registered")
	ui.TabBuilders.console = function(pg) n = n + 1 return orig(pg) end
	SlashCmdList.PSS("gui")
	local win = _G.PSS_Window
	check(win.pages[conIndex()].bar == nil, "no console frame before the tab is opened")
	click(win.tabs[conIndex()]); click(win.tabs[conIndex()])
	check(n == 1, "built once, got " .. n)
	check(win.pages[conIndex()].bar ~= nil, "console built")
	ui.TabBuilders.console = orig
end

local EXAMPLES = nil
local BAD = { "index=lgo", "| stats", '"open', "a ((", "index=log | chart line", "index=log | head x", "earliest=-7x", "|", "= =", "index=log | bogus" }
PH.conhighlight = function()
	local pg = openCon()
	local CV = M.PSS_ConsoleView
	local function colored(text)
		pg.bar:SetText(text)
		pg.highlight()
		local toks = M.PSS_Psql.tokens(text)
		check(pg.overlay:GetText() == CV.colorize(text, toks, ui.SyntaxHex), "overlay matches tokens for " .. text)
	end
	for _, h in ipairs(CV.HELP) do colored(h[1]) end
	for _, t in ipairs(BAD) do
		colored(t)
		local err = pg.barError()
		check(err and err.msg, "error for " .. t)
		if err and err.pos <= #t then check(pg.underline:IsShown(), "underline shown for " .. t) end
	end
end

PH.considebar = function()
	local pg = openCon()
	plantLog(20)
	pg.bar:SetText("index=log | head 50")
	pg.run(true)
	local set = pg.qv.vm.set
	check(set and set.n > 0, "rows planted")
	local side = pg.cm:Sidebar(set)
	for _, g in ipairs(side) do
		local top = M.PSS_Call("q.top", set, { field = g.field, n = 5 })
		check(#g.rows == top.n, g.field .. " row count")
		for i = 1, top.n do check(g.rows[i][1] == top[i][1] and g.rows[i][2] == top[i][2], g.field .. " value " .. i) end
	end
	local flat = pg.sideFlat()
	check(#flat > 0, "sidebar drawn")
	for i, d in ipairs(flat) do
		if d.field then
			pg.sideList.spec.click(nil, i)
			check(pg.bar:GetText():find(M.PSS_ConsoleView.term(d.field, d.value), 1, true), "click adds the term")
			break
		end
	end
end

PH.conactions = function()
	local pg = openCon()
	local cm, CV = pg.cm, M.PSS_ConsoleView
	cm:SetText("index=log | head 5")
	local s = set({ "owner", "item" }, { { "bob", "item:5" } })
	local a = cm:RowActions(s, 1)
	check(#a == 3 and a[1].key == "copy" and a[2].key == "owner" and a[3].key == "item", "three actions")
	check(a[2].query == CV.addTerm("index=log | head 5", CV.term("owner", "bob")), "owner query " .. tostring(a[2].query))
	check(a[3].query == "index=inv " .. CV.term("item", "item:5"), "item query " .. tostring(a[3].query))
end

PH.conescape = function()
	local pg = openCon()
	pg.toggleHelp()
	check(pg.help:IsShown(), "help open")
	pg.bar:SetFocus()
	pg.bar:GetScript("OnEscapePressed")(pg.bar)
	check(not pg.help:IsShown(), "help closed")
	pg.bar:SetFocus()
	pg.bar:GetScript("OnEscapePressed")(pg.bar)
	check(not pg.bar:HasFocus(), "second Escape leaves the box")
	print("NOTE conescape: window ns.NavUp is E06's")
end

PH.condict = function()
	local pg = openCon()
	click(pg.nav.rows[#pg.nav.rows], "LeftButton")
	pg.nav:Select("dict", true)
	local d = pg.dictPanel()
	check(d and d:IsShown(), "dictionary shown")
	local names = M.PSS_DictPageModel()
	local f = M.PSS_DictPageModel(names[1][1])
	check(f and d.fieldList.count == f.n, "field rows equal ix.dict: " .. tostring(d.fieldList.count) .. " vs " .. tostring(f and f.n))
	local fc = M.PSS_SetCol(f, "field") or 1
	d.fieldList.spec.click(nil, 1)
	local v = M.PSS_DictPageModel(names[1][1], f[1][fc])
	check(v and d.valueList.count == v.n, "value rows equal ix.values")
end

PH.conoff = function()
	check(_G.PSS_Window == nil, "window never opened: no frame")
	check(not M.PSS_ConsoleBuilt, "no console state")
end

PH.conlook = function()
	local sizes = {}
	looks(function(_, name)
		local pg = openCon()
		sizes[name] = { pg.bar:GetWidth(), pg.qv:GetWidth(), pg.qv:GetHeight() }
	end)
	for _, k in ipairs({ "classic", "dark" }) do
		for i = 1, 3 do check(sizes[k][i] == sizes.modern[i], k .. " size " .. i) end
	end
end

PH.conreal = function()
	local pg = openCon()
	local one = M.PSS_Search("index=log | head 1", {})
	local owner = one and one.n > 0 and one[1][M.PSS_SetCol(one, "owner") or 1] or "x"
	local inv = M.PSS_Search("index=inv | head 1", {})
	local item = inv and inv.n > 0 and inv[1][M.PSS_SetCol(inv, "item") or 1] or "item:1"
	local function same(text, params)
		pg.qv:SetQuery(text, params)
		pg.qv:Run(true)
		local want = M.PSS_Search(text, { params = params, load = true, rows = pg.qv.vm.o.rows })
		local got = pg.qv.vm.set
		check(pg.qv.vm.state ~= "error" or not want, text .. ": " .. tostring(pg.qv.vm.err and pg.qv.vm.err.msg))
		if want and got then check(got.n == want.n, text .. ": " .. got.n .. " rows vs " .. want.n) end
	end
	for _, q in ipairs(M.PSS_SQ_SYSTEM) do same(q.q, { owner = owner, item = item }) end
	local ex = { "index=log | stats count by cat", "index=log | timechart span=1d count", "index=log | top 5 cat",
		"index=log | head 20", "index=log | sort -time | head 5", "index=log | dedup cat", "index=log | table time, cat" }
	for _, t in ipairs(ex) do same(t) end
	local names = M.PSS_DictPageModel()
	for i = 1, math.min(3, names and names.n or 0) do same("index=" .. names[i][1] .. " | head 5") end
end

PH.conchart = function()
	local pg = openCon()
	plantLog(30)
	pg.bar:SetText("index=log | timechart span=1d count | chart line")
	pg.run(true)
	check(pg.qv.vm.chart and pg.qv.vm.chart.kind == "line", "chart kind line, got " .. tostring(pg.qv.vm.chart and pg.qv.vm.chart.kind))
	check(pg.tabs[3].pssSelected, "Chart tab selected")
end

local KINDTEXT = "index=log cat=\"x\" n>5 | head 5"
PH.conhicolors = function()
	local CV = M.PSS_ConsoleView
	looks(function(_, name)
		local pg = openCon()
		pg.bar:SetText(KINDTEXT)
		pg.highlight()
		local toks = M.PSS_Psql.tokens(KINDTEXT)
		local seen = {}
		for i = 1, toks.n do
			local k = toks[i][3]
			local hex = k ~= "space" and ui.SyntaxHex(k)
			if hex then
				local piece = KINDTEXT:sub(toks[i][1], toks[i][1] + toks[i][2] - 1):gsub("|", "||")
				check(pg.overlay:GetText():find("|cff" .. hex .. piece, 1, true), name .. ": " .. k .. " carries its colour")
				seen[k] = true
			end
		end
		check(next(seen), name .. ": some kinds coloured")
	end)
end

PH.conhilive = function()
	local pg = openCon()
	local calls, base = 0, M.PSS_Psql.tokens
	M.PSS_Psql.tokens = function(...) calls = calls + 1 return base(...) end
	local text, t0 = "", os.clock()
	for i = 1, 60 do
		text = text .. (("index=log | head 10 "):sub(((i - 1) % 19) + 1, ((i - 1) % 19) + 1))
		pg.bar:SetText(text)
		pg.highlight()
	end
	local avg = (os.clock() - t0) / 60 * 1000
	M.PSS_Psql.tokens = base
	check(calls == 60, "60 recolours, got " .. calls)
	check(avg < 20, "tokenize loop average " .. avg .. " ms (harness bound 20)")
	check(not pg.bar:GetScript("OnUpdate"), "no OnUpdate on the bar")
end

PH.conhierror = function()
	local pg = openCon()
	local text = "index=log | bogus x"
	pg.bar:SetText(text)
	pg.highlight()
	local hex = ui.SyntaxHex("error")
	check(hex, "error colour defined")
	local at = pg.overlay:GetText():find("|cff" .. tostring(hex) .. "bogus", 1, true)
	check(at, "bogus is error coloured: " .. tostring(pg.overlay:GetText()))
	check(pg.underline:IsShown(), "underline shown")
end

PH.conhireadonly = function()
	local pg = openCon()
	local CV = M.PSS_ConsoleView
	local text = "index=log | head 3"
	local d
	for _, r in ipairs(pg.cm:LeftRows()) do if r.key and r.key:find("^sys:") then d = r break end end
	check(d, "a list row exists")
	pg.nav:Select(d.key, true)
	check(pg.bar:GetText() == d.query, "list query in the bar")
	pg.highlight()
	check(pg.overlay:GetText() == CV.colorize(d.query, M.PSS_Psql.tokens(d.query), ui.SyntaxHex), "coloured as the bar")
end

local f = PH[phase]
if not f then
	check(false, "no such phase")
else
	local ok, e = xpcall(f, debug.traceback)
	if not ok then check(false, "raised: " .. tostring(e)) end
end
if not fail then print("PASS console " .. phase) end
