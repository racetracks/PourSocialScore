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

local f = PH[phase]
if not f then
	check(false, "no such phase")
else
	local ok, e = xpcall(f, debug.traceback)
	if not ok then check(false, "raised: " .. tostring(e)) end
end
if not fail then print("PASS console " .. phase) end
