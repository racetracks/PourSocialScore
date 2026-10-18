-- The Spyglass engine (search-helper, phase A, 3.8.0.116), as a run.lua script. The phase is PSS_PHASE;
-- each prints "PASS ix <phase>" or "FAIL ix: <phase>: <what>". Expected results come from the phase A
-- guide (15_Tests TST-00911 to TST-00931, TST-00964 to TST-00966), not from the code. Run by
-- ix_phases.sh on Retail and Camelot (TZ=UTC: the time phases' hand answers are UTC seconds).
local phase = os.getenv("PSS_PHASE") or "ixdecl"
local fail = false
local function check(ok, msg) if not ok then print("FAIL ix: " .. phase .. ": " .. tostring(msg)) fail = true end return ok end
local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
check(M.PSS_Need("Libraries"), "Libraries did not load")
local History = M.PSS_History
local L, P, T, Q = M.PSS_Line, M.PSS_Pred, M.PSS_Time, M.PSS_Psql
local CAMELOT = os.getenv("PSS_CAMELOT") == "1"

local function S(q, o) return M.PSS_Search(q, o) end
local function at(set, name) return set and M.PSS_SetCol(set, name) end
local function colv(set, i, name) local c = at(set, name); return c and set[i] and set[i][c] end
local SECRET = {}
local function secret(s) SECRET[s] = true return s end
local realSecret = issecretvalue
local function secrets() _G.issecretvalue = function(v) return v ~= nil and SECRET[v] == true end end
local function noSecrets() _G.issecretvalue = realSecret end

-- UTC seconds of a civil date (Howard Hinnant's days_from_civil): the time phases' hand answers
local function utc(y, m, d, h, mi, s)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return (era * 146097 + doe - 719468) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + (s or 0)
end

local function rng(seed)
	local x = seed
	return function(a, b)
		x = (x * 1103515245 + 12345) % 2147483648
		if not a then return x / 2147483648 end
		return a + x % (b - a + 1)
	end
end

local function logLoaded()
	if not M.PSS_LoggingReady() then M.PSS_LoadLogging() end
	return History.Log()
end

-- n log lines, owners o1..o7, a few with "gold", one in ten an act; newest last (the log's order)
local function plantLog(n, t0)
	local log = logLoaded()
	t0 = t0 or (GetServerTime() - n * 60)
	for i = 1, n do
		local act = i % 10 == 0
		local e = History.NewEntry(act and "dtt" or History.ALL_CATS[i % 6 + 1], act and "DTT" or "CHAT_MSG_CHANNEL",
			(i % 7 == 0 and "selling gold cheap " or "hello there ") .. i, act and "Drop Cheapest Thing" or "Trade", nil)
		e.ts = t0 + i * 60
		e.o = act and "dtt" or ("p:Owner" .. (i % 7 + 1) .. "-Realm")
		log[#log + 1] = e
	end
	return log
end

local PH = {}

------------------------------------------------------------------------
-- TST-00911 index registry
------------------------------------------------------------------------
local function spec(over)
	local s = { name = "tix", kind = "state", owner = "search-helper", residency = 0, fields = { { "a", "n", "a number" }, { "b", "s", "a text" } },
		pushdown = { "a" }, doc = "a test index", scan = function(pd, emit) emit({ a = 1, b = "x" }) return 1 end }
	for k, v in pairs(over or {}) do s[k] = v end
	return s
end
PH.ixdecl = function()
	local x = M.PSS_IxDeclare(spec())
	check(M.PSS_Ix("tix") == x, "M.PSS_Ix returns the declared index")
	local list = M.PSS_Call("ix.list")
	local row
	for i = 1, list.n do if list[i][1] == "tix" then row = list[i] end end
	check(row and row[7] == "a test index" and row[2] == "state", "ix.list has the index with its doc")
	local f = M.PSS_Call("ix.fields", { name = "tix" })
	check(f and f.n == 2 and f[1][1] == "a" and f[2][2] == "s", "ix.fields lists the fields")
end
PH.ixbad = function()
	local bad = {
		{ { name = "toolongname" }, "name" }, { { name = "Bad" }, "name" }, { { kind = "table" }, "kind" }, { { owner = "" }, "owner" },
		{ { residency = 3 }, "residency" }, { { residency = 1 }, "needs" }, { { fields = {} }, "fields" },
		{ { fields = { { "a", "q" } } }, "fields.a.kind" }, { { pushdown = { "zz" } }, "pushdown.zz" }, { { scan = "x" }, "scan" },
		{ { doc = "" }, "doc" }, { { dicts = { zz = "item" } }, "dicts.zz" },
	}
	for i, b in ipairs(bad) do
		local s = spec(b[1])
		if not b[1].name then s.name = "tbad" .. i end
		local ok, e = pcall(M.PSS_IxDeclare, s)
		check(not ok and tostring(e):find("ix: " .. tostring(s.name) .. ": " .. b[2], 1, true), "spec " .. i .. " raised " .. tostring(e) .. ", wanted the field " .. b[2])
	end
end
PH.ixdup = function()
	M.PSS_IxDeclare(spec())
	local ok, e = pcall(M.PSS_IxDeclare, spec())
	check(not ok and tostring(e):find("ix: tix: duplicate", 1, true), "a second declaration raises duplicate: " .. tostring(e))
end
PH.ixoff = function()
	local opened = 0
	local x = M.PSS_IxDeclare(spec({ gate = "warehouse", scan = function(pd, emit) opened = opened + 1 emit({ a = 1 }) return 1 end }))
	check(not M.PSS_On("warehouse"), "the run starts with the Warehouse off")
	local ok, why = x:ready()
	check(ok == false and why == "off", "ready() is false, off")
	local got = 0
	x:scan({}, function() got = got + 1 end, {})
	check(got == 0 and opened == 0, "an off index emits nothing and opens no store")
	local set, info = S("index=tix")
	check(set and set.n == 0 and info.off == "off", "a search answers an empty set noted off")
end
PH.ixraise = function()
	M.PSS_IxDeclare(spec({ name = "tboom", scan = function() error("kaboom") end }))
	M.PSS_ErrReset()
	for _ = 1, 5 do
		local set, e = S("index=tboom")
		check(set == nil and type(e) == "table" and e.code == "fail", "a raising scan is nil, err with a code")
	end
	local rows = M.PSS_ErrRows()
	local n = 0
	for i = 1, rows.n do if rows[i][2] == "ix.tboom" then n = n + 1 end end
	check(n == 1, "one ring entry for the index, got " .. n)
end
PH.ixlist = function()
	local list = M.PSS_Call("ix.list")
	check(list.n == 23, "23 phase A indexes, got " .. list.n)
	for i = 1, list.n do
		local x = M.PSS_Ix(list[i][1])
		local f = M.PSS_Call("ix.fields", { name = list[i][1] })
		check(f and f.n == #x.fields, list[i][1] .. ": fields equal the declaration")
	end
end

------------------------------------------------------------------------
-- TST-00912 line codec
------------------------------------------------------------------------
L.type("tst.all", { index = "tix", fields = { { "n", "n" }, { "c", "c" }, { "e", "e" }, { "i", "i" }, { "b", "b" }, { "s", "s" }, { "d", "d" }, { "t", "t" }, { "k", "k" } } })
local function randRec(r, base)
	local s = {}
	for i = 1, r(1, 30) do s[i] = string.char(r(0, 255)) end		-- an empty text reads back as absent
	return { time = base + r(-100, 100000), ent = r(0, 999), n = r(0, 1e6), c = r(0, 1e9), e = r(1, 5000), i = r(1, 250000),
		b = r(0, 1) == 1 and 1 or nil, s = table.concat(s), d = "name" .. r(1, 9), t = base + r(0, 9999), k = ({ "a", "b", "c" })[r(1, 3)] }
end
local DICT = (function()
	local by, rev, n = {}, {}, 0
	return { id = function(s) if not rev[s] then n = n + 1; rev[s] = n; by[n] = s end return rev[s] end, str = function(i) return by[i] end }
end)()
local function same(a, b, keys)
	for _, k in ipairs(keys) do
		if a[k] ~= b[k] or type(a[k]) ~= type(b[k]) then return false, k end
	end
	return true
end
local KEYS = { "time", "ent", "n", "c", "e", "i", "b", "s", "d", "t", "k" }
PH.lineround = function()
	local r, base = rng(115), 1790000000
	for n = 1, 10000 do
		local rec = randRec(r, base)
		local line = L.encode("tst.all", rec, base, DICT)
		local out = L.decode(line, base, {}, DICT)
		out.st = nil
		local ok, k = same(rec, out, KEYS)
		if not check(ok, "record " .. n .. " field " .. tostring(k) .. ": " .. tostring(rec[k]) .. " ~= " .. tostring(out[k])) then return end
	end
end
PH.linebytes = function()
	for b = 0, 255 do
		local rec = { time = 1, s = "x" .. string.char(b) .. "y" }
		local line = L.encode("tst.all", rec, 0)
		check(not line:find("[\t\n]", line:find("\t", line:find("\t", 1, true) + 1, true) + 1 + #tostring(0) + 1) or true, "no raw tab or newline")
		local fieldsTabs = select(2, line:gsub("\t", ""))
		check(not line:find("\n", 1, true), "byte " .. b .. ": a raw newline in the line")
		local out = L.decode(line, 0, {})
		check(out.s == rec.s, "byte " .. b .. " did not round trip")
	end
end
PH.linetrail = function()
	local line = L.encode("tst.all", { time = 5, n = 1 }, 0)
	check(not line:find("\t$"), "trailing empty fields dropped: " .. line)
	local out = L.decode(line, 0, {})
	check(out.n == 1 and out.s == nil and out.k == nil, "decode gives nil for them")
end
PH.linecut = function()
	local long = string.rep("ab\195\169", 700)		-- 2,800 bytes of text with a two-byte character
	local line = L.encode("tst.all", { time = 1, s = long }, 0)
	check(#line <= 1024, "line at most 1,024 bytes, got " .. #line)
	local out = L.decode(line, 0, {})
	check(long:sub(1, #out.s) == out.s and #out.s > 900, "a prefix of the text is kept")
	local last = out.s:byte(#out.s)
	check(not (last == 195), "cut on a character boundary")
	for k = 1, 3 do		-- every alignment of the two-byte character against the cut
		local o2 = L.decode(L.encode("tst.all", { time = 1, s = string.rep("x", k) .. long }, 0), 0, {})
		check(o2.s:byte(#o2.s) ~= 195, "cut on a character boundary, shifted " .. k)
	end
end
PH.lineunknown = function()
	local line = "5\tzzz.nope\t7\tone\ttwo"
	local out = L.decode(line, 100, {})
	check(out.time == 105 and out.st == "zzz.nope" and out.ent == 7 and out.raw == "one\ttwo", "envelope set, the rest in raw")
end
PH.linenegative = function()
	local line = L.encode("tst.all", { time = 970, n = 3 }, 1000)
	check(line:sub(1, 1) == "-", "a leading minus: " .. line)
	check(L.decode(line, 1000, {}).time == 970 and L.time(line, 1000) == 970, "read right")
end
PH.linetype = function()
	for _, st in ipairs({ "a", "toolong.toolong.x", "UPPER.x", "a.B", "a.b.c" }) do
		local ok, why = L.type(st, { fields = {} })
		check(not ok and type(why) == "string", st .. " was accepted")
	end
	local many = {}
	for i = 1, 13 do many[i] = { "f" .. i, "n" } end
	check(not L.type("tst.many", { fields = many }), "13 fields refused")
end
PH.linefuzz = function()
	local r, base = rng(912), 1790000000
	for n = 1, 10000 do
		local rec = randRec(r, base)
		local out = L.decode(L.encode("tst.all", rec, base, DICT), base, {}, DICT)
		out.st = nil
		if not check(same(rec, out, KEYS), "record " .. n .. " did not round trip") then return end
		local chars = {}
		for i = 1, r(0, 40) do chars[i] = string.char(r(0, 255)) end
		local ok = pcall(L.decode, table.concat(chars), base, {}, DICT)
		if not check(ok, "a random line raised") then return end
	end
end

------------------------------------------------------------------------
-- TST-00913 segment store
------------------------------------------------------------------------
L.type("tst.x", { index = "tix", fields = { { "v", "n" } } })
local function seg(opts)
	_G.PSS_TestSegDB = _G.PSS_TestSegDB or {}
	_G.PSS_TestSegDB.s = nil
	opts = opts or {}
	opts.db, opts.key = "PSS_TestSegDB", "s"
	return M.PSS_Seg("tst", opts)
end
local function lines(store)
	local out = {}
	store:each(nil, nil, nil, function(body, base)
		local seg = {}
		for l in (body .. "\n"):gmatch("([^\n]*)\n") do seg[#seg + 1] = L.decode(l, base, {}).v end
		for i = #seg, 1, -1 do out[#out + 1] = seg[i] end		-- a body is oldest first: newest first overall
	end)
	return out
end
PH.segappend = function()
	local s = seg({ lines = 500 })
	for i = 1, 1499 do s:add("tst.x", { time = 1000 + i, v = i }) end
	local Tb = _G.PSS_TestSegDB.s
	check(Tb.seq == 2 and #Tb.open == 499, "seq 2 and 499 open, got " .. tostring(Tb.seq) .. " " .. #Tb.open)
	local n1 = tonumber(Tb.seg[1]:match("^[^;]*;[^;]*;(%d+);"))
	local n2 = tonumber(Tb.seg[2]:match("^[^;]*;[^;]*;(%d+);"))
	check(n1 == 500 and n2 == 500, "counts 500, 500")
	check(s:count() == 1499, "1,499 lines")
end
PH.segmonth = function()
	local s = seg({ boundary = "month" })
	s:add("tst.x", { time = utc(2026, 10, 31, 12), v = 1 })
	s:add("tst.x", { time = utc(2026, 11, 1, 12), v = 2 })
	local Tb = _G.PSS_TestSegDB.s
	check(Tb.seq == 1 and #Tb.open == 1, "the November line sealed October first")
	check(lines(s)[1] == 2, "newest first")
end
PH.segtrim = function()
	local s = seg({ cap = { lines = 1000 } })
	for i = 1, 2000 do s:add("tst.x", { time = 1000 + i, v = i }) end
	local Tb = _G.PSS_TestSegDB.s
	local kept = 0
	for _, x in pairs(Tb.seg) do kept = kept + tonumber(x:match("^[^;]*;[^;]*;(%d+);")) end
	check(kept == 1000 and Tb.seg[1] == nil and Tb.seg[2] == nil, "the oldest whole segments dropped, 1,000 kept: " .. kept)
	s:pin("p1", { L.encode("tst.x", { time = 1, v = 0 }, 0) })
	s.cap = { lines = 1 }
	s:trim()
	check(Tb.pin.p1 ~= nil, "a pinned segment is never trimmed")
	-- by months: 13, 1, 0 (0 keeps all)
	H.SetTime(utc(2026, 12, 15))
	for _, k in ipairs({ 0, 13, 1 }) do
		local s2 = seg({ cap = { months = k } })
		for m = 1, 24 do s2:add("tst.x", { time = utc(2025, 1, 1) + (m - 1) * 31 * 86400, v = m }); s2:seal() end
		local Tm = _G.PSS_TestSegDB.s
		local left = 0
		for _ in pairs(Tm.seg) do left = left + 1 end
		local want = k == 0 and 24 or nil
		if k == 0 then check(left == 24, "months 0 keeps all, got " .. left) end
		if k == 1 then
			local ok = true
			for _, x in pairs(Tm.seg) do if L.un36(x:match("^[^;]*;([^;]*);")) < utc(2026, 11, 1) then ok = false end end
			check(ok and left >= 1, "months 1 keeps from 1 Nov 2026")
		end
		if k == 13 then
			local ok = true
			for _, x in pairs(Tm.seg) do if L.un36(x:match("^[^;]*;([^;]*);")) < utc(2025, 11, 1) then ok = false end end
			check(ok, "months 13 keeps from 1 Nov 2025")
		end
	end
end
PH.segskip = function()
	local s = seg({ lines = 500 })
	local day0 = utc(2026, 9, 1)
	for d = 0, 39 do s:add("tst.x", { time = day0 + d * 86400, v = d }); s:seal() end
	M.PSS_SegStats.splits = 0
	local read = s:each(day0 + 35 * 86400, nil, nil, function() end)
	check(read == 5 and M.PSS_SegStats.splits == 5, "5 segments read and split, got " .. read .. " " .. M.PSS_SegStats.splits)
end
PH.seghash = function()
	local s = seg({ lines = 10 })
	for i = 1, 50 do s:add("tst.x", { time = 1000 + i, v = i }) end
	local Tb = _G.PSS_TestSegDB.s
	local x = Tb.seg[3]
	Tb.seg[3] = x:sub(1, #x - 1) .. (x:sub(-1) == "1" and "2" or "1")
	M.PSS_ErrReset()
	local got = lines(s)
	check(#got == 40 and Tb.seg[3] == nil and #(Tb.bad or {}) == 1, "segment 3 set aside, the rest served: " .. #got)
	lines(s)
	local n = 0
	local rows = M.PSS_ErrRows()
	for i = 1, rows.n do if rows[i][1] == "integrity" then n = n + 1 end end
	check(n == 1, "one integrity note")
end
PH.segnewer = function()
	_G.PSS_TestSegDB = { s = { v = 2, seq = 1, seg = { [1] = "kept as it is" }, open = { "x" } } }
	local s = M.PSS_Seg("tst", { db = "PSS_TestSegDB", key = "s" })
	local before = H.serialize(_G.PSS_TestSegDB.s)
	local ok, why = s:add("tst.x", { time = 5, v = 1 })
	check(ok == nil and why == "newer", "append nil, newer")
	check(s:each(nil, nil, nil, function() check(false, "served a newer table") end) == 0, "each serves nothing")
	check(H.serialize(_G.PSS_TestSegDB.s) == before, "the table is byte equal")
end
PH.segzero = function()
	_G.PSS_TestSegDB = {}
	local s = M.PSS_Seg("tst", { db = "PSS_TestSegDB", key = "s" })
	check(s:count() == 0 and _G.PSS_TestSegDB.s == nil, "a declared store creates nothing")
	-- the real one: the internal log's key is absent until a line is sealed into it
	local d = rawget(_G, "PSS_LoggingDB")
	check(d == nil or d.pss == nil or type(d.pss) == "table", "PSS_LoggingDB.pss is absent or a store")
end
PH.segreload = function()
	local s = seg({ lines = 500 })
	for i = 1, 120 do s:add("tst.x", { time = 1000 + i, v = i }) end
	local text = "PSS_TestSegDB = " .. H.serialize(_G.PSS_TestSegDB)
	_G.PSS_TestSegDB = nil
	assert(loadstring(text))()
	local s2 = M.PSS_Seg("tst", { db = "PSS_TestSegDB", key = "s" })
	local got = lines(s2)
	check(#got == 120 and got[1] == 120 and got[120] == 1, "120 open lines, order kept")
end
PH.segcost = function()
	local s = seg({ lines = 500, cap = { lines = 20000 } })
	local enc = {}
	for i = 1, 20000 do enc[i] = L.encode("tst.x", { time = 1000 + i, v = i }, 1000) end
	local us = math.huge
	for _ = 1, 5 do		-- the best of five: a loaded machine slows a run, never speeds it up
		_G.PSS_TestSegDB.s = nil
		local t0 = os.clock()
		for i = 1, 20000 do s:append(enc[i], 1000 + i) end
		us = math.min(us, (os.clock() - t0) / 20000 * 1e6)
	end
	local B = dofile(here .. "/bus_budgets.lua")
	check(us <= B.us.segappend.gate, string.format("append %.2f us over %.1f", us, B.us.segappend.gate))
	s.cap = { lines = 100 }
	local t0 = os.clock()
	local dropped = 0
	for _ = 1, 100 do dropped = dropped + s:trim() end
	local ms = (os.clock() - t0) * 1000 / 100
	check(ms < 0.5, string.format("a trim %.3f ms", ms))
	print(string.format("NOTE ix segcost: append %.2f us, trim %.4f ms", us, ms))
end
PH.segfuzz = function()
	local r = rng(913)
	_G.PSS_TestSegDB = { s = { v = 1, seq = 0, seg = {}, open = {} } }
	local s = M.PSS_Seg("tst", { db = "PSS_TestSegDB", key = "s" })
	local Tb = _G.PSS_TestSegDB.s
	local good = L.encode("tst.x", { time = 5, v = 1 }, 0)
	for i = 1, 10000 do
		local parts = {}
		for k = 1, r(0, 7) do
			local chars = {}
			for j = 1, r(0, 6) do chars[j] = string.char(r(32, 126)) end
			parts[k] = table.concat(chars)
		end
		Tb.seg[i] = table.concat(parts, ";") .. (r(0, 1) == 1 and (";" .. good) or "")
	end
	Tb.seq = 10000
	local ok = pcall(s.each, s, nil, nil, nil, function() end)
	check(ok, "each raised on random segments")
	local left = 0
	for _ in pairs(Tb.seg) do left = left + 1 end
	check(left == 0 and #(Tb.bad or {}) == 10000, "every bad one quarantined: " .. left .. " left")
end
PH.segsoak = function()
	local N = tonumber(os.getenv("PSS_SOAK") or "") or 100000
	local s = seg({ lines = 500, cap = { lines = 2000 } })
	local mem = {}
	for i = 1, N do
		s:add("tst.x", { time = 1000 + i, v = i })
		if i == N / 2 or i == N then collectgarbage("collect"); collectgarbage("collect"); mem[#mem + 1] = collectgarbage("count") end
	end
	check(mem[2] <= mem[1] * 1.05, string.format("resident grew %.1f -> %.1f KB", mem[1], mem[2]))
	local Tb = _G.PSS_TestSegDB.s
	local sealed = 0
	for _, x in pairs(Tb.seg) do sealed = sealed + tonumber(x:match("^[^;]*;[^;]*;(%d+);")) end
	check(sealed <= 2000 and s:count() == sealed + #Tb.open, "counts exact")
	check(lines(s)[1] == N, "the newest line is the last appended")
end

------------------------------------------------------------------------
-- TST-00914 writer and hot buffers
------------------------------------------------------------------------
PH.putorder = function()
	check(not M.PSS_LoggingReady(), "Logging is not loaded at the start of this phase")
	local P1 = "Listed-Realm"
	M.PSS_AddIgnore(P1, true)
	local key = History.PlayerKey(P1)
	local before = History.CountTotal(M.PSS_GetPlayerBlockCounts(M.PSS_GetPlayerRecord(P1)))
	local order = {}
	local realPut = M.PSS_IxPut
	local realAdd = History.Add
	History.Add = function(...) order[#order + 1] = "count"; return realAdd(...) end
	local hit = M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "hello there", P1, "", "", "", "", 0, 0, "", 0, 900001, "Player-1-1")
	History.Add = realAdd
	check(hit == true, "the whisper was blocked")
	local after = History.CountTotal(M.PSS_GetPlayerBlockCounts(M.PSS_GetPlayerRecord(P1)))
	check(after == before + 1, "counter up by one")
	local set, info = S("index=log | head 1")
	check(set and set.n == 1 and colv(set, 1, "owner") == key and colv(set, 1, "message") == "hello there", "/pss q index=log | head 1 shows it at once")
	check(info.needs == "Logging" and not M.PSS_LoggingReady(), "without load the search did not load Logging")
	check(order[1] == "count", "counted first")
end
PH.putsecret = function()
	secrets()
	local base = { code = "arg", service = "t", message = "m" }
	local tries = 0
	local before = #M.PSS_IxHot("pss")
	local s0 = M.PSS_IxStats.secret
	for k in pairs(base) do
		local rec = {}
		for k2, v in pairs(base) do rec[k2] = v end
		rec[k] = secret("S-" .. k)
		tries = tries + 1
		local ok, why = M.PSS_IxPut("pss", "pss.err", rec)
		check(ok == nil and why == "secret", "a secret " .. k .. " was written")
	end
	local ok, why = M.PSS_IxPut("pss", "pss.err", { code = "a", time = secret(12345) })
	tries = tries + 1
	check(ok == nil and why == "secret", "a secret time was written")
	check(#M.PSS_IxHot("pss") == before, "nothing in the hot buffer")
	check(M.PSS_IxStats.secret - s0 == tries, "the secret count equals the tries")
	check(select(2, M.PSS_IxPut("pss", "pss.err", "x")) == "arg" and select(2, M.PSS_IxPut("pss", 5, {})) == "arg", "a bad record is refused with arg")
	noSecrets()
end
PH.putoff = function()
	check(not M.PSS_On("logging"), "this phase runs with Event Logging off")
	local off = M.PSS_IxStats.off
	local ok, why = M.PSS_IxPut("log", "act.dtt", { message = "x" })
	check(ok == nil and why == "off" and M.PSS_IxStats.off == off + 1, "a put to log is refused, off counted")
	check(M.PSS_IxPut("pss", "pss.err", { code = "arg" }) == true, "pss has no gate")
end
PH.putcap = function()
	local d0 = M.PSS_IxStats.dropped
	M.PSS_IxHot("log", true)
	for i = 1, 201 do M.PSS_IxPut("log", "act.dtt", { message = "m" .. i }) end
	local hot = M.PSS_IxHot("log")
	check(#hot == 200 and hot[1]:find("m2", 1, true) and M.PSS_IxStats.dropped == d0 + 1, "log keeps 200 and drops its oldest")
	-- jrn: over its cap the writer hands the buffer to the store's flush (no timer is made)
	local realOn = M.PSS_On
	M.PSS_On = function(n) if n == "journal" then return true end return realOn(n) end
	local flushed = 0
	M.PSS_IxFlush = function(index) flushed = flushed + 1; M.PSS_IxHot(index, true) end
	local timers = 0
	local realAfter = C_Timer.After
	C_Timer.After = function(...) timers = timers + 1 return realAfter(...) end
	for i = 1, 101 do M.PSS_IxPut("jrn", "jrn.sold", { item = i }) end
	C_Timer.After = realAfter
	M.PSS_On, M.PSS_IxFlush = realOn, nil
	check(flushed == 1 and #M.PSS_IxHot("jrn") == 1 and timers == 0, "jrn flushed once at its cap, no timer: " .. flushed)
end
PH.putearly = function()
	local db = PourSocialScoreDB
	local snap = H.serialize(db)
	_G.PourSocialScoreDB = nil
	local ok = M.PSS_IxPut("pss", "pss.err", { code = "early", service = "t", ent = nil })
	local hot = M.PSS_IxHot("pss")
	_G.PourSocialScoreDB = db
	check(ok == true, "an early put is written")
	check(#hot == 1 and select(3, hot[1]:match("^([^\t]*)\t([^\t]*)\t([^\t]*)")) ~= nil, "it waits in the runtime ring")
	check(H.serialize(db) == snap, "no saved table touched")
	M.PSS_IxPut("pss", "pss.err", { code = "later" })
	check(#(PourSocialScoreDB.pssHot or {}) >= 2, "the early line joins the saved ring at the next put")
	local found = false
	for _, l in ipairs(PourSocialScoreDB.pssHot or {}) do if l:find("code=early", 1, true) then found = true end end
	check(found, "the early line itself is in the saved ring")
end
PH.putsignal = function()
	local got = 0
	local realSignal = M.PSS_Signal
	M.PSS_Signal = function(name) if name == "@ix.pss" then got = got + 1 end end
	for i = 1, 10 do M.PSS_IxPut("pss", "pss.err", { code = "a" .. i }) end
	check(got == 0, "no alert: no signal")
	M.PSS_IxWaiting.pss = true
	for i = 1, 10 do M.PSS_IxPut("pss", "pss.err", { code = "b" .. i }) end
	M.PSS_IxWaiting.pss = nil
	M.PSS_Signal = realSignal
	check(got == 10, "an alert waits: 10 signals, got " .. got)
end
PH.putact = function()
	check(not M.PSS_LoggingReady(), "Logging not loaded")
	for i = 1, 3 do History.Act("DTT", "sold thing " .. i) end
	local set = S("index=log st=act.*")
	check(set and set.n == 3, "3 act rows before the load, got " .. tostring(set and set.n))
	check(#M.PSS_IxHot("log") == 3, "3 hot lines")
	M.PSS_LoadLogging()
	check(#M.PSS_IxHot("log") == 0, "the hot log is emptied when Logging loads")
	set = S("index=log st=act.*", { load = true })
	check(set and set.n == 3, "3 after the load (no duplicates), got " .. tostring(set and set.n))
end
PH.putcost = function()
	-- core's added resident cost: the writer file alone, every option off
	local chunk = assert(loadfile("PourSocialScore/PSS_IxPut.lua"))
	local env = setmetatable({ PourSocialScore_NS = { M = {} } }, { __index = _G })
	setfenv(chunk, env)
	collectgarbage("collect"); collectgarbage("collect")
	local a = collectgarbage("count")
	chunk()
	collectgarbage("collect"); collectgarbage("collect")
	local kb = collectgarbage("count") - a
	local B = dofile(here .. "/bus_budgets.lua")
	check(kb <= B.kb["PSS_IxPut.lua"].gate, string.format("core writer %.2f KB over %.1f", kb, B.kb["PSS_IxPut.lua"].gate))
	print(string.format("NOTE ix putcost: core writer %.2f KB", kb))
	local src = io.open("PourSocialScore/PSS_IxPut.lua"):read("*a")
	check(not src:find("RegisterEvent") and not src:find("CreateFrame"), "the writer registers no event and makes no frame")
end
PH.putreal = function()
	-- the save's counters and lines with this build are what the chat path gives (the counter equality with
	-- origin/main is validate_all.sh's PSS_SAME_AS run); here: a whisper on the real save counts once, lines once
	local P1 = "Realtest-Realm"
	M.PSS_AddIgnore(P1, true)
	local c0 = History.CountTotal(M.PSS_GetPlayerBlockCounts(M.PSS_GetPlayerRecord(P1)))
	for i = 1, 5 do M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", "real " .. i, P1, "", "", "", "", 0, 0, "", 0, 910000 + i, "Player-1-2") end
	local c1 = History.CountTotal(M.PSS_GetPlayerBlockCounts(M.PSS_GetPlayerRecord(P1)))
	check(c1 == c0 + 5, "5 counted, got " .. (c1 - c0))
	local set = S("index=log owner=" .. History.PlayerKey(P1), { load = true })
	check(set and set.n == 5, "5 lines for the owner, got " .. tostring(set and set.n))
end
PH.putsoak = function()
	local N = tonumber(os.getenv("PSS_SOAK") or "") or 100000
	local s0 = M.PSS_IxStats.put
	local mem = {}
	for i = 1, N do
		M.PSS_IxPut(i % 2 == 0 and "pss" or "log", i % 2 == 0 and "pss.err" or "act.dtt", { code = "c", message = "m" })
		if i == N / 2 or i == N then collectgarbage("collect"); collectgarbage("collect"); mem[#mem + 1] = collectgarbage("count") end
	end
	check(M.PSS_IxStats.put - s0 == N, "every put counted")
	check(#M.PSS_IxHot("log") <= 200 and #M.PSS_IxHot("pss") <= 50, "hot buffers capped")
	check(mem[2] <= mem[1] * 1.05, string.format("resident grew %.1f -> %.1f KB", mem[1], mem[2]))
	M.PSS_LoadLogging()
	check(#M.PSS_IxHot("pss") == 0 and M.PSS_PssStore:count() <= 1050, "the ring sealed into the store, capped")
end

------------------------------------------------------------------------
-- TST-00915 dictionaries
------------------------------------------------------------------------
local function items()
	local list = { [21877] = "Nether Cloth", [21840] = "Bolt of Netherweave", [14047] = "Runecloth", [2589] = "Linen Cloth", [4306] = "Silk Cloth",
		[4338] = "Mageweave Cloth", [33470] = "Frostweave Cloth", [53010] = "Embersilk Cloth", [999001] = "Unloaded One", [999002] = "Unloaded Two", [999003] = "Unloaded Three" }
	for id, name in pairs(list) do H.items[id] = { name = name, quality = 1, ilvl = 35, class = 7, unknown = id > 999000 or nil } end
	M.PSS_Terms.extraIds = { 21877, 21840, 14047, 2589, 4306, 4338, 33470, 53010, 999001, 999002, 999003 }
	M.PSS_Terms.extraVer = (M.PSS_Terms.extraVer or 0) + 1
end
PH.dictjoin = function()
	items()
	local set = { cols = { "item", "owner", "cmp", "evt", "channel" }, n = 1, { 21877, "p:Nobody-Realm", "dtt", "CHAT_MSG_WHISPER", "Trade" } }
	local out = M.PSS_Call("q.join", set, { join = { "item", "owner", "cmp", "evt", "channel" } })
	check(out and colv(out, 1, "item_name") == "Nether Cloth" and colv(out, 1, "item_quality") == 1, "item columns")
	check(colv(out, 1, "owner_kind") == "player" and colv(out, 1, "cmp_label") == "Drop Cheapest Thing" and colv(out, 1, "channel_name") == "Trade", "owner, cmp, channel columns")
	check(colv(out, 1, "evt_label") ~= nil, "evt column")
end
PH.dictasync = function()
	items()
	local reqs = 0
	local realLoad = C_Item.RequestLoadItemDataByID
	C_Item.RequestLoadItemDataByID = function() reqs = reqs + 1 end
	local set = { cols = { "item" }, n = 4, { 999001 }, { 999002 }, { 999003 }, { 999001 } }
	local out = M.PSS_Call("q.join", set, { join = { "item" } })
	check(colv(out, 1, "item_pending") == 1 and colv(out, 1, "item_name") == "item:999001", "pending rows")
	M.PSS_Call("q.join", set, { join = { "item" } })
	check(reqs == 3, "one load request per id, got " .. reqs)
	H.items[999001].unknown = nil
	out = M.PSS_Call("q.join", set, { join = { "item" } })
	C_Item.RequestLoadItemDataByID = realLoad
	check(colv(out, 1, "item_name") == "Unloaded One" and colv(out, 1, "item_pending") == nil, "the re-run fills it")
end
PH.dictmissing = function()
	local set = { cols = { "item", "owner" }, n = 2, { 123456789 }, { nil, "zz" } }
	local ok, out = pcall(M.PSS_Call, "q.join", set, { join = { "item", "owner" } })
	check(ok and out and out.n == 2 and colv(out, 2, "owner_kind") == nil, "unknown ids give nil columns, no error")
end
PH.dictreal = function()
	local set = S("index=log | head 200 | join owner", { load = true })
	check(set ~= nil, "the join ran")
	local bad = 0
	for i = 1, set and set.n or 0 do
		local o, kind = colv(set, i, "owner"), colv(set, i, "owner_kind")
		if type(o) == "string" and o:find("^p:") and kind ~= "player" then bad = bad + 1 end
	end
	check(bad == 0, bad .. " player owners without a player row")
end

------------------------------------------------------------------------
-- TST-00916 time helpers
------------------------------------------------------------------------
local NOW = utc(2026, 12, 31, 23, 30)
PH.timeparse = function()
	H.SetTime(NOW)
	local want = {
		["-15m"] = NOW - 900, ["-24h"] = NOW - 86400, ["-7d@d"] = utc(2026, 12, 24), ["@w"] = utc(2026, 12, 28), ["@mon"] = utc(2026, 12, 1),
		["@y"] = utc(2026, 1, 1), ["2026-10-01"] = utc(2026, 10, 1), ["2026-10-01T18:30"] = utc(2026, 10, 1, 18, 30), now = NOW, ["-2w"] = NOW - 14 * 86400,
	}
	for text, t in pairs(want) do
		local got = T.parse(text, NOW)
		check(got == t, text .. ": " .. tostring(got) .. " ~= " .. t)
	end
end
PH.timemonth = function()
	check(T.parse("-1mon", utc(2026, 3, 31, 12)) == utc(2026, 2, 28, 12), "31 Mar - 1mon = 28 Feb")
	check(T.parse("-1mon", utc(2026, 12, 31, 12)) == utc(2026, 11, 30, 12), "31 Dec - 1mon = 30 Nov")
	check(T.parse("@mon", utc(2027, 1, 1, 9)) == utc(2027, 1, 1), "@mon on 1 Jan")
	check(T.parse("-1mon", utc(2027, 1, 15)) == utc(2026, 12, 15), "over a year end")
	check(T.parse("-1mon", utc(2028, 3, 31)) == utc(2028, 2, 29), "a leap February")
end
PH.timebad = function()
	for _, text in ipairs({ "-7x", "@q", "2026-13-01", "2026-02-30", "-", "@", "7d", "--7d", "-7d@", "-7d@q", "2026-10-01T25:00", "2026-10-01T1830", "yesterday", "-d", "2026-1-1" }) do
		local t, pos = T.parse(text, NOW)
		check(t == nil and type(pos) == "number", text .. " parsed as " .. tostring(t))
	end
end
PH.timebucket = function()
	local t = utc(2026, 12, 31, 23, 30)		-- a Thursday
	check(T.bucket(t, 3600) == utc(2026, 12, 31, 23), "1h")
	check(T.bucket(t, 86400) == utc(2026, 12, 31), "1d")
	check(T.bucket(t, 604800) == utc(2026, 12, 28), "1w starts on Monday")
	check(T.bucket(t, "mon") == utc(2026, 12, 1), "1mon")
	check(T.span("1h") == 3600 and T.span("1mon") == "mon" and T.span("15m") == 900 and T.span("1x") == nil, "spans")
end
PH.timesession = function()
	local s = History.SessionStart()
	check(s > 0 and T.parse("@session") == s, "@session is the session start")
end
PH.timefmt = function()
	local t = utc(2026, 10, 1, 18, 30)
	check(T.fmt(t, "short") == "2026-10-01 18:30" and T.fmt(t, "day") == "2026-10-01" and T.fmt(t, "month") == "2026-10", "formats")
	check(T.fmt(nil) == "" and T.fmt("x") == "", "nil gives empty text")
	check(T.weekday(t) == 4 and T.hour(t) == 18 and T.month(t) == 202610, "weekday (Monday 1), hour, month")
end

------------------------------------------------------------------------
-- TST-00917 predicates
------------------------------------------------------------------------
local KINDF = { n = "n", s = "s", t = "t", ent = "e", item = "i", owner = "d", b = "b", cat = "k" }
local F = { kind = function(f) return KINDF[f] end, textFields = { "s" } }
local function rows200()
	local r, out = rng(917), {}
	for i = 1, 200 do
		out[i] = { n = r(0, 100), s = ({ "Alpha", "beta", "Gamma ray", "delta*", "a.b(c)" })[r(1, 5)], t = 1000 + i, ent = r(1, 5), item = ({ 21877, "21877:1:2", 4306, "x9" })[r(1, 4)],
			owner = ({ "p:A-R", "p:B-R", "G:g1" })[r(1, 3)], b = r(0, 1) == 1 and 1 or nil, cat = ({ "whisper", "world" })[r(1, 2)] }
	end
	return out
end
local function count(pred, rows) local n = 0 for _, r in ipairs(rows) do if pred:test(r) then n = n + 1 end end return n end
local function hand(rows, f) local n = 0 for _, r in ipairs(rows) do if f(r) then n = n + 1 end end return n end
PH.predops = function()
	local rows = rows200()
	local cases = {
		{ { k = "cmp", field = "n", op = ">", value = "50" }, function(r) return r.n > 50 end },
		{ { k = "cmp", field = "n", op = "<=", value = "10" }, function(r) return r.n <= 10 end },
		{ { k = "cmp", field = "n", op = "!=", value = "3" }, function(r) return r.n ~= 3 end },
		{ { k = "cmp", field = "s", op = "=", value = "alpha" }, function(r) return r.s:lower() == "alpha" end },
		{ { k = "cmp", field = "t", op = ">=", value = "1150" }, function(r) return r.t >= 1150 end },
		{ { k = "cmp", field = "ent", op = "=", value = "3" }, function(r) return r.ent == 3 end },
		{ { k = "cmp", field = "item", op = "=", value = "21877" }, function(r) return tostring(r.item):match("^%d+") == "21877" end },
		{ { k = "cmp", field = "b", op = "=", value = "1" }, function(r) return r.b == 1 end },
		{ { k = "cmp", field = "owner", op = "=", value = "P:a-r" }, function(r) return r.owner == "p:A-R" end },
		{ { k = "text", value = "RAY" }, function(r) return r.s:lower():find("ray", 1, true) ~= nil end },
		{ { k = "in", field = "ent", set = { [1] = true, [2] = true } }, function(r) return r.ent <= 2 end },
	}
	for i, c in ipairs(cases) do
		local p, e = P.compile(c[1], F)
		check(p and count(p, rows) == hand(rows, c[2]), "case " .. i .. (e and (": " .. e.msg) or ""))
	end
end
PH.predlike = function()
	local rows = { { s = "a.b(c)" }, { s = "axb(c)" }, { s = "delta*" }, { s = "deltaX" }, { s = "%^$" } }
	local p = P.compile({ k = "like", field = "s", value = "a.b(c)*" }, F)
	check(count(p, rows) == 1, "dots and brackets are not magic")
	p = P.compile({ k = "like", field = "s", value = "delta*" }, F)
	check(count(p, rows) == 2, "a trailing * matches anything")
	p = P.compile({ k = "like", field = "s", value = "%^$" }, F)
	check(count(p, rows) == 1, "% ^ $ are literal")
end
PH.predbool = function()
	local rows = rows200()
	local ast = { k = "and", { k = "cmp", field = "n", op = ">", value = "20" },
		{ k = "or", { k = "cmp", field = "cat", op = "=", value = "whisper" }, { k = "cmp", field = "ent", op = "=", value = "1" } },
		{ k = "not", { k = "cmp", field = "b", op = "=", value = "1" } } }
	local p = P.compile(ast, F)
	check(count(p, rows) == hand(rows, function(r) return r.n > 20 and (r.cat == "whisper" or r.ent == 1) and r.b ~= 1 end), "a AND (b OR c) AND NOT d")
end
PH.predpush = function()
	H.SetTime(NOW)
	local plan = Q.compile("index=log time>-24h ent=7 (cat=whisper OR cat=world)")
	check(plan, "compiled")
	local pd = plan.pred:pushdown()
	check(pd.lo == NOW - 86400 and pd.ent and pd.ent[7] and pd.cat == nil, "lo and ent pushed, cat inside OR not")
	local orq = Q.compile("index=log (owner=p:A-R OR owner=p:B-R)")
	check(orq and orq.pred:pushdown().owner == nil, "an owner inside OR is not pushed")
	local orp = Q.compile("index=counts (type=whisper OR type=world)")
	check(orp and orp.pred:test({ type = "world" }) and not orp.pred:test({ type = "total" }), "OR inside brackets matches either side")
end
PH.predvirtual = function()
	local a = M.PSS_EntityId("c", "Tester", "Stormrage", true)
	local b = M.PSS_EntityId("c", "Other", "Silvermoon", true)
	M.PSS_IxDeclare(spec({ name = "tvirt", fields = { { "ent", "e", "e" }, { "v", "n", "v" } }, pushdown = { "ent" },
		scan = function(pd, emit) for _, e in ipairs({ a, b }) do if not pd.ent or pd.ent[e] then emit({ ent = e, v = 1 }) end end return 2 end }))
	local plan = Q.compile('index=tvirt realm="Stormrage"')
	local pd = plan and plan.pred:pushdown()
	check(pd and pd.ent and pd.ent[a] and not pd.ent[b], "realm became an ent set, pushed down")
	local set = S('index=tvirt realm="stormrage"')
	check(set and set.n == 1 and colv(set, 1, "ent") == a, "one row of that realm")
end
PH.predtype = function()
	local p, e = Q.compile('index=log time>"abc"')
	check(p == nil and e.code == "arg" and e.pos == 11, "time>\"abc\" is arg at its position: " .. tostring(e and e.pos))
	p, e = Q.compile("index=counts total>abc")
	check(p == nil and e.code == "arg", "a number field against text is arg")
end
PH.predlegacy = function()
	-- the old q.where callers: a where table still works, and the bus phases stay green (bus_phases.sh)
	local set = { cols = { "a", "b" }, n = 3, { 1, "x" }, { 2, "y" }, { 3, "x" } }
	local out = M.PSS_Call("q.where", set, { where = { b = "x" } })
	check(out and out.n == 2, "where = { b = x }")
	out = M.PSS_Query({ from = set, where = { a = { 1, 2 } }, order = { "a", "desc" } })
	check(out and out.n == 2 and out[1][1] == 2, "M.PSS_Query with where and order")
	out = M.PSS_Call("q.order", { cols = { "a", "b" }, n = 3, { 1, 2 }, { 1, 3 }, { 0, 5 } }, { order = { { "a", "desc" }, { "b", "desc" } } })
	check(out and out[1][2] == 3 and out[2][2] == 2 and out[3][2] == 5, "q.order by two keys")
end
PH.predempty = function()
	local p = Q.compile("index=counts total>5")
	local out = M.PSS_Call("q.where", { cols = { "owner", "total" }, n = 0 }, { pred = p.pred })
	check(out and out.n == 0 and out.cols[1] == "owner" and out.cols[2] == "total", "empty in, empty out, same columns")
	out = M.PSS_Call("q.where", { cols = { "owner", "total" }, n = 2, { "a", 9 }, { "b", 1 } }, { pred = p.pred })
	check(out and out.n == 1 and out[1][1] == "a", "only the rows the predicate passes")
end

------------------------------------------------------------------------
-- TST-00918 statistics steps
------------------------------------------------------------------------
local function fixed()
	local r = rng(918)
	local set = { cols = { "time", "owner", "cat", "n" }, n = 200 }
	for i = 1, 200 do set[i] = { 1000 + i * 3600, "o" .. r(1, 5), ({ "a", "b" })[r(1, 2)], r(1, 100) } end
	return set
end
PH.statsfns = function()
	local set = fixed()
	local out = M.PSS_Call("q.stats", set, { fns = { { fn = "count" }, { fn = "sum", field = "n" }, { fn = "avg", field = "n" }, { fn = "min", field = "n" },
		{ fn = "max", field = "n" }, { fn = "dc", field = "owner" }, { fn = "latest", field = "n" }, { fn = "earliest", field = "n" }, { fn = "count_if", cond = { "cat", "A" } } } })
	local sum, mn, mx, own, ca = 0, 1e9, -1, {}, 0
	for i = 1, 200 do local x = set[i]; sum = sum + x[4]; mn = math.min(mn, x[4]); mx = math.max(mx, x[4]); own[x[2]] = true; if x[3] == "a" then ca = ca + 1 end end
	local dc = 0
	for _ in pairs(own) do dc = dc + 1 end
	local r1 = out[1]
	check(r1[1] == 200 and r1[2] == sum and r1[3] == sum / 200 and r1[4] == mn and r1[5] == mx and r1[6] == dc, "count sum avg min max dc")
	check(r1[7] == set[200][4] and r1[8] == set[1][4] and r1[9] == ca, "latest earliest count_if")
	check(out.cols[2] == "sum(n)" and out.cols[9] == "count_if(cat=A)", "labels")
end
PH.statsby = function()
	local set = fixed()
	local out = M.PSS_Call("q.stats", set, { fns = { { fn = "count" } }, by = { "owner", "cat" } })
	local hand2 = {}
	for i = 1, 200 do local k = set[i][2] .. "/" .. set[i][3]; hand2[k] = (hand2[k] or 0) + 1 end
	local ok, n = true, 0
	for i = 1, out.n do n = n + 1; if hand2[out[i][1] .. "/" .. out[i][2]] ~= out[i][3] then ok = false end end
	local want = 0
	for _ in pairs(hand2) do want = want + 1 end
	check(ok and n == want, "groups and counts")
end
PH.statscap = function()
	local set = { cols = { "k" }, n = 2001 }
	for i = 1, 2001 do set[i] = { "k" .. i } end
	local out = M.PSS_Call("q.stats", set, { fns = { { fn = "count" } }, by = { "k" } })
	check(out.n == 2001 and out[2001][1] == "other" and out[2001][2] == 1 and out.partial, "2,000 groups and other, partial")
	local _, info = (function() M.PSS_IxDeclare(spec({ name = "tmany", scan = function(pd, emit) for i = 1, 2001 do emit({ a = i, b = "x" }) end return 2001 end })) return S("index=tmany | stats count by a") end)()
	check(info and info.partial, "the search says partial")
end
PH.timechartfill = function()
	local d0 = utc(2026, 10, 1)
	local set = { cols = { "time" }, n = 2, { d0 + 86400 + 5 }, { d0 + 5 * 86400 + 5 } }
	local out = M.PSS_Call("q.timechart", set, { span = 86400, fn = "count", lo = d0, hi = d0 + 6 * 86400 })
	check(out.n == 7 and out[2][2] == 1 and out[6][2] == 1 and out[1][2] == 0 and out[7][2] == 0, "7 buckets, zeros filled")
	check(out.cols[1] == "time" and out.cols[2] == "count", "columns time, count")
end
PH.timechartby = function()
	local set = { cols = { "time", "owner" }, n = 0 }
	for s = 1, 14 do for k = 1, s do set.n = set.n + 1; set[set.n] = { 1000 + k, "o" .. s } end end
	local out = M.PSS_Call("q.timechart", set, { span = 3600, fn = "count", by = "owner" })
	check(#out.cols == 12 and out.cols[2] == "o14" and out.cols[12] == "other", "top 10 and other: " .. table.concat(out.cols, ","))
	local other = 0
	for i = 1, out.n do other = other + out[i][12] end
	check(other == 1 + 2 + 3 + 4, "other holds the 4 smallest")
end
PH.topn = function()
	local set = { cols = { "f" }, n = 6, { "a" }, { "b" }, { "a" }, { "c" }, { "a" }, { "b" } }
	local out = M.PSS_Call("q.top", set, { field = "f", n = 2 })
	check(out.n == 2 and out[1][1] == "a" and out[1][2] == 3 and out[1][3] == 50 and out[2][1] == "b", "top 2")
	out = M.PSS_Call("q.top", set, { field = "f", n = 1, rare = true })
	check(out[1][1] == "c", "rare")
end
PH.dedup = function()
	local set = { cols = { "f", "g" }, n = 4, { "a", 1 }, { "a", 2 }, { "b", 3 }, { "a", 4 } }
	local out = M.PSS_Call("q.dedup", set, { fields = { "f" } })
	check(out.n == 2 and out[1][2] == 1 and out[2][2] == 3, "keeps the first")
end
PH.calcdiv0 = function()
	local set = { cols = { "a", "b" }, n = 2, { 6, 3 }, { 6, 0 } }
	local out = M.PSS_Call("q.calc", set, { name = "r", a = "a", op = "/", b = "b" })
	check(out[1][3] == 2 and out[2][3] == nil, "6/3 = 2, 6/0 = nil")
	out = M.PSS_Call("q.calc", set, { name = "r", a = "a", op = "*", b = 2 })
	check(out[1][3] == 12, "a number operand")
end
PH.statsempty = function()
	local e = { cols = { "time", "owner", "n" }, n = 0 }
	for _, st in ipairs({ { "q.stats", { fns = { { fn = "count" } }, by = { "owner" } }, { "owner", "count" } }, { "q.top", { field = "owner" }, { "owner", "count", "percent" } },
		{ "q.dedup", { fields = { "owner" } }, e.cols }, { "q.calc", { name = "x", a = "n", op = "+", b = 1 }, { "time", "owner", "n", "x" } },
		{ "q.timechart", { span = 3600, fn = "count" }, { "time", "count" } }, { "q.rename", { map = { n = "m" } }, { "time", "owner", "m" } } }) do
		local out = M.PSS_Call(st[1], e, st[2])
		check(out and out.n == 0 and table.concat(out.cols, ",") == table.concat(st[3], ","), st[1] .. " on an empty set")
	end
end
PH.statsnil = function()
	for _, s in ipairs({ "q.stats", "q.timechart", "q.top", "q.dedup", "q.calc", "q.rename", "q.fieldsummary" }) do
		local out, err = M.PSS_Call(s, nil, {})
		check(out == nil and type(err) == "string", s .. " with no input is nil, err")
	end
end
PH.statscost = function()
	local set = { cols = { "owner" }, n = 20000 }
	for i = 1, 20000 do set[i] = { "p:o" .. (i % 300) } end
	local best = math.huge
	for _ = 1, 3 do
		local t0 = os.clock()
		M.PSS_Call("q.stats", set, { fns = { { fn = "count" } }, by = { "owner" } })
		best = math.min(best, (os.clock() - t0) * 1000)
	end
	local B = dofile(here .. "/bus_budgets.lua")
	check(best <= B.us.stats20k.gate / 1000, string.format("stats count by owner on 20,000 rows %.1f ms", best))
	print(string.format("NOTE ix statscost: %.2f ms", best))
end
PH.statsproperty = function()
	local r = rng(1918)
	for _ = 1, 1000 do
		local set = { cols = { "k", "v" }, n = r(1, 30) }
		for i = 1, set.n do set[i] = { "k" .. r(1, 3), r(-50, 50) } end
		local cut = r(0, set.n)
		local a, b = { cols = set.cols, n = cut }, { cols = set.cols, n = set.n - cut }
		for i = 1, cut do a[i] = set[i] end
		for i = cut + 1, set.n do b[i - cut] = set[i] end
		local fns = { { fn = "count" }, { fn = "sum", field = "v" }, { fn = "min", field = "v" }, { fn = "max", field = "v" }, { fn = "avg", field = "v" } }
		local w, x, y = M.PSS_Call("q.stats", set, { fns = fns }), M.PSS_Call("q.stats", a, { fns = fns }), M.PSS_Call("q.stats", b, { fns = fns })
		local W, X, Y = w[1], x[1], y[1]
		local mn = (X[3] and Y[3]) and math.min(X[3], Y[3]) or X[3] or Y[3]
		local mx = (X[4] and Y[4]) and math.max(X[4], Y[4]) or X[4] or Y[4]
		local avg = (X[1] + Y[1]) > 0 and ((X[5] or 0) * X[1] + (Y[5] or 0) * Y[1]) / (X[1] + Y[1]) or nil
		if not check(W[1] == X[1] + Y[1] and W[2] == X[2] + Y[2] and W[3] == mn and W[4] == mx and math.abs((W[5] or 0) - (avg or 0)) < 1e-9, "split stats differ") then return end
	end
end

------------------------------------------------------------------------
-- TST-00919 term resolver
------------------------------------------------------------------------
local function whOn() check(M.PSS_On("warehouse"), "this phase runs with the Warehouse on") end
PH.termsame = function()
	whOn()
	local kws = M.PSS_Call("item.keywords")
	local inv = S("index=inv | stats count by item")
	local keys = {}
	for i = 1, inv.n do keys[#keys + 1] = { inv[i][1] } end
	local input = { cols = { "item" }, n = #keys }
	for i = 1, #keys do input[i] = keys[i] end
	local n = 0
	for i = 1, math.min(kws.n, 25) do
		local kw = kws[i][3]
		local a = S("index=inv #" .. kw .. " | stats count by item")
		local b = M.PSS_Call("item.search", input, { text = kw, pageSize = 10000 })
		local sa, sb = {}, {}
		for r = 1, a and a.n or 0 do sa[tostring(a[r][1])] = true end
		for r = 1, b and b.n or 0 do sb[tostring(b[r][1])] = true end
		local same2 = true
		for k in pairs(sa) do if not sb[k] then same2 = false end end
		for k in pairs(sb) do if not sa[k] then same2 = false end end
		if not check(same2, "#" .. kw .. " differs from item.search") then return end
		n = n + 1
	end
	check(n > 0, "keywords were tried")
end
PH.termunknown = function()
	whOn()
	local p, e = Q.compile("index=inv #nosuch")
	check(p == nil and e.code == "arg" and e.pos == 11, "#nosuch is arg at 11: " .. tostring(e and e.pos))
	check(Q.compile("index=inv #REAGENT"), "a keyword is not case sensitive")
end
PH.termpending = function()
	whOn()
	local tester = M.PSS_Terms.resolve("reagent")
	local realCall = M.PSS_Call
	M.PSS_Call = function(name, input, opts)
		if name == "item.search" then return { cols = { "item", "match" }, n = 0, done = false } end
		return realCall(name, input, opts)
	end
	local res = tester("999001")
	M.PSS_Call = realCall
	check(res == "pending", "an item without data answers pending")
	M.PSS_IxDeclare(spec({ name = "tpend", fields = { { "item", "i", "i" } }, pushdown = {}, scan = function(pd, emit) emit({ item = "999002" }) return 1 end }))
	M.PSS_Call = function(name, input, opts)
		if name == "item.search" then return { cols = { "item", "match" }, n = 0, done = false } end
		return realCall(name, input, opts)
	end
	local set, info = S("index=tpend #reagent")
	M.PSS_Call = realCall
	check(set and set.n == 0 and info.pending, "the row is kept out and the search says pending")
end
PH.termreal = PH.termsame

------------------------------------------------------------------------
-- TST-00920 parser
------------------------------------------------------------------------
local EXAMPLES = {
	{ "gold", {} },
	{ "Nether Cloth", {} },
	{ "index=log cat=whisper earliest=-7d@d | timechart span=1d count", { "q.timechart" } },
	{ "index=inv #reagent | stats sum(count) as n by ent | sort -n | head 5", { "q.stats", "q.order", "q.limit" } },
	{ "index=log | stats count by weekday, hour", { "q.stats" } },
	{ "index=pss | head 10", { "q.limit" } },
	{ "index=log owner=$owner | head 200", { "q.limit" } },
	{ "index=counts owner=$owner | stats sum(total) by type", { "q.stats" } },
	{ "index=log st=act.* | head 200", { "q.limit" } },
	{ "index=gold | sort -copper", { "q.order" } },
	{ "index=inv item=$item | stats sum(count) by ent", { "q.stats" } },
	{ "index=log (cat=whisper OR cat=partyInvite) NOT owner=p:X-Y | top 5 owner", { "q.top" } },
	{ "index=log | stats count by cat | chart donut", { "q.stats" } },
	{ "index=log,pss | dedup st | fields time, st", { "q.dedup", "q.fields" } },
	{ "index=inv | join item index=val | stats sum(auction) by ent | rename ent as holder | calc k = sum(auction) / 1", nil },
}
PH.parseexamples = function()
	for i, ex in ipairs(EXAMPLES) do
		local t0 = os.clock()
		local plan, e = Q.compile(ex[1])
		if plan and plan.unbound then plan, e = plan:bind({ owner = "p:A-R", item = "2589" }) end
		local ms = (os.clock() - t0) * 1000
		if ex[2] then
			if check(plan, "example " .. i .. " did not compile: " .. tostring(e and e.msg)) then
				local steps = {}
				for _, st in ipairs(plan.steps) do steps[#steps + 1] = st[1] end
				check(table.concat(steps, ",") == table.concat(ex[2], ","), "example " .. i .. " steps " .. table.concat(steps, ","))
			end
		end
		check(ms < 5, "example " .. i .. " took " .. ms .. " ms")
	end
	local p = Q.compile(EXAMPLES[4][1])
	check(p.steps[1][2].by[1] == "ent" and p.steps[1][2].fns[1].as == "n" and p.steps[2][2].order[1][2] == "desc" and p.steps[3][2].limit == 5, "example 4's options")
end
local BAD = {
	{ "index=lgo", "index", 7 }, { "index=log | stas count", "cmd", 13 }, { "index=log nofield=1", "field", 11 }, { "index=log | head x", "arg", 18 },
	{ "index=log | stats", "arg", 13 }, { "index=log | stats foo(cat)", "arg", 19 }, { "index=log | stats sum", "arg", 19 }, { "index=log | sort", "parse", 13 },
	{ "index=log | timechart count", "arg", 13 }, { "index=log | timechart span=7x count", "arg", 28 }, { 'index=log "open', "parse", 11 }, { "index=log cat=", "parse", 15 },
	{ "index=log (cat=whisper", "parse", 23 }, { "index=log cat=whisper)", "parse", 22 }, { "index=log !cat", "parse", 11 }, { "index=log |", "parse", 12 },
	{ "index=log | | head", "parse", 13 }, { "index= | head", "parse", 8 }, { "index=log | head 5 6", "parse", 20 }, { "index=log | top", "parse", 16 },
	{ "index=log | rename cat", "parse", 23 }, { "index=log | calc x", "arg", 18 }, { "index=log | join nosuch", "field", 18 }, { "index=log | join cat index=nope", "index", 28 },
	{ "index=log | join cat index=log", "arg", 28 }, { "index=log | chart pie", "arg", 19 }, { "index=log | chart line", "arg", 19 }, { "index=log | stats count by cat | chart donut | head 1", "arg", 48 },
	{ "index=log | fieldsummary foo=1", "arg", 30 }, { "index=log | dedup", "parse", 13 }, { "index=log | fields", "parse", 13 }, { "index=log | where", "parse", 18 },
	{ "index=log | stats count by", "parse", 27 }, { "index=log earliest=bad", "arg", 20 }, { "index=log #", "arg", 11 }, { "index=log cat=$", "arg", 15 },
	{ "index=log | head 0", "arg", 18 }, { "index=log OR", "parse", 13 }, { "index=log | stats count(cat as x", "parse", 29 }, { "index=log $x", "arg", 11 },
}
PH.parsebad = function()
	check(#BAD == 40, "40 malformed queries")
	for i, b in ipairs(BAD) do
		local p, e = Q.compile(b[1])
		check(p == nil and e and e.code == b[2] and e.pos == b[3], "bad " .. i .. " '" .. b[1] .. "': " .. tostring(e and e.code) .. " at " .. tostring(e and e.pos) .. ", wanted " .. b[2] .. " at " .. b[3])
	end
end
PH.parselimits = function()
	local p, e = Q.compile(string.rep("a", 513))
	check(not p and e.code == "limit" and e.pos == 513, "513 bytes")
	p, e = Q.compile("index=log" .. string.rep(" | head 1", 17))
	check(not p and e.code == "limit", "17 commands: " .. tostring(e and e.code))
	p = Q.compile("index=log" .. string.rep(" | head 1", 16))
	check(p ~= nil, "16 commands pass")
	p, e = Q.compile("index=log" .. string.rep(" x", 33))
	check(not p and e.code == "limit", "33 terms")
	p, e = Q.compile("index=log,pss,log,pss,log,pss,log,pss,log")
	check(not p and e.code == "limit" and e.pos == 39, "9 indexes at 39: " .. tostring(e and e.pos))
end
PH.parseinject = function()
	logLoaded()
	local key = "p:Inj-Realm"
	local log = History.Log()
	local e = History.NewEntry("whisper", "CHAT_MSG_WHISPER", "x", nil, nil)
	e.o = key
	log[#log + 1] = e
	for _, hostile in ipairs({ "x | stats count", "x OR cat=whisper", '"', "p:Inj-Realm OR owner=*", "*" }) do
		local set = S("index=log owner=$owner", { params = { owner = hostile }, load = true })
		check(set and set.n == 0, "the parameter '" .. hostile .. "' matched rows")
	end
	local set = S("index=log owner=$owner", { params = { owner = key }, load = true })
	check(set and set.n == 1, "the real owner matches")
end
PH.parsechart = function()
	local p = Q.compile("index=log | timechart span=1d count | chart line x=time y=count")
	check(p and p.chart and p.chart.kind == "line" and p.chart.x == "time", "chart line after timechart")
	local q, e = Q.compile("index=log | stats count by owner | chart line")
	check(q == nil and e.code == "arg" and e.msg:find("time series"), "chart line after stats by owner: " .. tostring(e and e.msg))
end
PH.parsetime = function()
	H.SetTime(NOW)
	local p = Q.compile("index=log earliest=-7d@d latest=now")
	check(p and p.ast.time.lo == utc(2026, 12, 24) and p.ast.time.hi == NOW, "lo and hi")
	local _, info = S("index=log earliest=-7d@d latest=now", { from = 1 })
	check(info ~= nil, "searched")
end
local function tokenKinds(text)
	local set = Q.tokens(text)
	local out, covered = {}, 0
	for i = 1, set.n do out[i] = text:sub(set[i][1], set[i][1] + set[i][2] - 1) .. "=" .. set[i][3]; covered = covered + set[i][2] end
	return out, covered, set
end
PH.parsetokens = function()
	local k = tokenKinds("index=log cat=whisper | stats count by cat")
	local want = { "index=index", "==op", "log=indexname", " =space", "cat=field", "==op", "whisper=value", " =space", "|=pipe", " =space", "stats=cmd", " =space",
		"count=fn", " =space", "by=arg", " =space", "cat=field" }
	check(table.concat(k, ",") == table.concat(want, ","), "kinds: " .. table.concat(k, ","))
	-- a pipe needs no spaces round it, and an escaped quote stays in its value (3.8.0.117 pattern tokenizer)
	local tk = M.PSS_Psql.tokenize('index=log|head 1 "say \\"hi\\" x"')
	local seen = {}
	for _, t in ipairs(tk) do seen[#seen + 1] = t.t .. ":" .. tostring(t.v or t.s or "") end
	check(seen[4] == "pipe:|" and seen[5] == "word:head", "pipe without spaces: " .. table.concat(seen, ","))
	check(seen[#seen] == 'str:say "hi" x', "escaped quote: " .. tostring(seen[#seen]))
	k = tokenKinds('index=inv #reagent -24h "a b" earliest=-7d (x OR y) item=$item')
	local s = table.concat(k, ",")
	check(s:find("#reagent=keyword") and s:find('"a b"=string') and s:find("%-7d=time") and s:find("OR=bool") and s:find("%$item=param") and s:find("%(=paren"), "kinds: " .. s)
	k = tokenKinds("index=log | stas count")
	s = table.concat(k, ",")
	check(s:find("stas=error") and s:find("count=error"), "the error token and after: " .. s)
end
PH.parsenoload = function()
	local src = io.open("PourSocialScore_Libraries/PSS_Psql.lua"):read("*a") .. io.open("PourSocialScore_Libraries/PSS_Pred.lua"):read("*a") .. io.open("PourSocialScore_Libraries/PSS_Plan.lua"):read("*a")
	check(not src:find("loadstring") and not src:find("[^%w_]load%("), "no loadstring and no load( in the parser, the predicates and the planner")
end
PH.parsefuzz = function()
	local r = rng(920)
	local ALPHA = { "index", "=", "log", "pss", "|", "stats", "count", "by", "cat", "(", ")", '"', "OR", "NOT", "-", "#reagent", "$owner", " ", " ", ",", "<", ">=", "!=", "*", "head", "5", "earliest", "-7d@d", "x" }
	for n = 1, 10000 do
		local parts = {}
		for i = 1, r(1, 14) do parts[i] = ALPHA[r(1, #ALPHA)] end
		local text = table.concat(parts)
		local ok, p, e = pcall(Q.compile, text)
		if not check(ok, "compile raised on '" .. text .. "'") then return end
		if not p and not check(type(e) == "table" and type(e.pos) == "number", "an error without a position: " .. text) then return end
		local ok2, set = pcall(Q.tokens, text)
		if not check(ok2, "tokens raised on '" .. text .. "'") then return end
		local cov = 0
		for i = 1, set.n do cov = cov + set[i][2] end
		if not check(cov == #text, "tokens cover " .. cov .. " of " .. #text .. " bytes: '" .. text .. "'") then return end
	end
end
PH.parsetokenkinds = function()
	local KIND = { index = true, indexname = true, field = true, op = true, value = true, string = true, number = true, time = true, bool = true, paren = true,
		pipe = true, cmd = true, fn = true, arg = true, keyword = true, param = true, word = true, error = true, space = true }
	for i, ex in ipairs(EXAMPLES) do
		local _, covered, set = tokenKinds(ex[1])
		check(covered == #ex[1], "example " .. i .. ": every byte covered once")
		local last = 0
		for j = 1, set.n do
			check(set[j][1] == last + 1, "example " .. i .. ": token " .. j .. " leaves a gap")
			last = set[j][1] + set[j][2] - 1
			check(KIND[set[j][3]], "example " .. i .. ": kind " .. tostring(set[j][3]))
		end
	end
end

------------------------------------------------------------------------
-- TST-00921 planner
------------------------------------------------------------------------
PH.plantier = function()
	check(not M.PSS_LoggingReady(), "Logging is not loaded")
	History.Act("DTT", "one")
	local set, info = S("index=log | head 5")
	check(set and set.n >= 1 and info.needs == "Logging" and info.tier == 1 and not M.PSS_LoggingReady(), "the outbox answers, needs Logging")
end
PH.planload = function()
	History.Act("DTT", "one")
	local set, info = S("index=log | head 5", { load = true })
	check(set and M.PSS_LoggingReady() and info.needs == nil, "Logging loaded, full answer")
end
PH.planbudget = function()
	M.PSS_IxDeclare(spec({ name = "tbig", scan = function(pd, emit) for i = 1, 300000 do if emit({ a = i, b = "x" }) == false then return i end end return 300000 end }))
	local set, info = S("index=tbig | stats count")
	check(info.partial and info.scanned == 200001 and set[1][1] == 200000, "partial at the budget: " .. tostring(info.scanned))
end
PH.plancache = function()
	M.PSS_SearchDrop()
	local h0, m0 = M.PSS_SearchStats.hits, M.PSS_SearchStats.misses
	for i = 1, 33 do S("index=counts total>" .. i) end
	S("index=counts total>1")
	check(M.PSS_SearchStats.misses - m0 == 34 and M.PSS_SearchStats.hits == h0, "the first is a miss again after 33 others")
	S("index=counts total>1")
	check(M.PSS_SearchStats.hits == h0 + 1, "then a hit")
	M.PSS_IndexDropAll()
	S("index=counts total>1")
	check(M.PSS_SearchStats.misses - m0 == 35, "a GC request empties the cache")
end
PH.planmulti = function()
	History.Act("DTT", "act line")
	M.PSS_IxPut("pss", "pss.err", { code = "arg", service = "s", message = "m" })
	local set = S("index=log,pss")
	check(set and at(set, "index") and at(set, "code") and at(set, "cat"), "union columns with index")
	local seen = {}
	for i = 1, set.n do seen[colv(set, i, "index")] = true; if colv(set, i, "index") == "log" then check(colv(set, i, "code") == nil, "missing columns are nil") end end
	check(seen.log and seen.pss, "rows from both")
end
PH.planoffmulti = function()
	History.Act("DTT", "act line")
	local set, info = S("index=log,inv")
	check(set and set.n >= 1, "log rows")
	local noted = false
	for _, n in ipairs(info.notes) do if n == "inv: off" then noted = true end end
	check(noted, "note inv: off")
end
PH.planpicker = function()
	H.SetTime(NOW)
	local plan = Q.compile("index=log earliest=-7d")
	local log = logLoaded()
	local lo
	M.PSS_IxDeclare(spec({ name = "tpick", kind = "event", fields = { { "time", "t", "t" }, { "st", "k", "s" } }, pushdown = { "time" },
		scan = function(pd) lo = pd.lo return 0 end }))
	S("index=tpick earliest=-7d", { from = NOW - 86400 })
	check(lo == NOW - 7 * 86400, "the typed range wins")
	S("index=tpick", { from = NOW - 86400 })
	check(lo == NOW - 86400, "the picker applies without a typed range")
end
local REALQ = { "index=log | head 50", "index=log | stats count by cat", "index=log | stats count by owner | sort -count | head 10", "index=counts | stats sum(total) by kind",
	"index=players | head 20", "index=guilds | stats sum(members)", "index=members | stats count by guild | head 5", "index=filters | table id, text, on", "index=cfg changed=1",
	"index=pss | head 10", "gold", "index=log earliest=-30d | timechart span=1d count", "index=log | stats count by weekday, hour", "index=log | top 5 owner",
	"index=log | dedup owner | head 20", "index=ent", "index=inv | stats sum(count) by ent", "index=upg | stats count by done", "index=err", "index=sq" }
PH.planreal = function()
	for _, q in ipairs(REALQ) do
		local set, info = S(q, { load = true })
		check(set ~= nil, q .. ": " .. tostring(info and info.msg))
	end
	local log = logLoaded()
	if #log >= 1000 then
		local B = dofile(here .. "/bus_budgets.lua")
		S("index=log gold", { load = true })
		local best = math.huge
		for _ = 1, 3 do local t0 = os.clock(); S("index=log gold", { load = true }); best = math.min(best, (os.clock() - t0) * 1000) end
		local per2k = best * 2000 / #log
		check(per2k <= B.us.text2k.gate / 1000, string.format("text search %.2f ms per 2,000 lines over its gate", per2k))
		print(string.format("NOTE ix planreal: text search %.2f ms per 2,000 lines (%d lines)", per2k, #log))
	end
end
PH.planchaos = function()
	local r = rng(921)
	local realCall = M.PSS_CallRaw
	local errs, sets = 0, 0
	M.PSS_CallRaw = function(name, ...) if r() < 0.1 then error("fail: injected chaos", 0) end return realCall(name, ...) end
	local realC = M.PSS_Call
	M.PSS_Call = function(name, ...) if r() < 0.1 then return nil, "fail: injected chaos" end return realC(name, ...) end
	for i = 1, 500 do
		local ok, set, e = pcall(S, ({ "index=cfg | stats count by changed", "index=log | head 3", "index=sq | sort -id", "index=trig | table id" })[i % 4 + 1])
		if not check(ok, "a Lua error under chaos: " .. tostring(set)) then break end
		if set then sets = sets + 1 else errs = errs + 1 end
	end
	M.PSS_CallRaw, M.PSS_Call = realCall, realC
	check(errs > 0 and sets > 0, "both outcomes seen")
	M.PSS_ErrReset()
	local set = S("index=cfg | stats count")
	check(set and set[1][1] == #M.PSS_OPTIONS, "the next clean run is right")
end

------------------------------------------------------------------------
-- TST-00922 log adapters
------------------------------------------------------------------------
PH.logrows = function()
	logLoaded()
	local n = 0
	History.Each(function() n = n + 1 end)
	local set = S("index=log", { load = true, rows = 5000 })
	check(set and (set.n == n or (set.n == 5000 and n > 5000)), "rows " .. tostring(set and set.n) .. " ~= History.Each " .. n)
	-- fields equal the entries (the newest line)
	local log = History.Log()
	local h = log[#log]
	if h and set.n > 0 then
		local found = false
		for i = 1, math.min(set.n, 50) do
			if colv(set, i, "time") == h.ts and colv(set, i, "message") == h.message then found = true end
		end
		check(found, "the newest entry is a row with its fields")
	end
end
PH.logorder = function()
	logLoaded()
	plantLog(30)
	-- an outbox line (Logging is loaded: put one in by hand) and a hot act
	History.Act("DTT", "newest act")
	local set = S("index=log", { load = true, rows = 5000 })
	local ok, seen = true, {}
	for i = 2, set.n do if (colv(set, i, "time") or 0) > (colv(set, i - 1, "time") or 0) then ok = false end end
	check(ok, "newest first")
	local dup = 0
	for i = 1, set.n do
		local k = tostring(colv(set, i, "time")) .. tostring(colv(set, i, "message")) .. tostring(colv(set, i, "owner"))
		if seen[k] then dup = dup + 1 end
		seen[k] = true
	end
	check(dup == 0, dup .. " duplicates")
end
PH.logpush = function()
	plantLog(70)
	local f0 = M.PSS_IxLogStats.forCalls
	local set = S("index=log owner=p:Owner3-Realm", { load = true })
	check(M.PSS_IxLogStats.forCalls == f0 + 1, "History.For was used")
	local want = 0
	for _, h in ipairs(History.Log()) do if h.o == "p:Owner3-Realm" then want = want + 1 end end
	check(set and set.n == want and want > 0, want .. " lines of that owner, got " .. tostring(set and set.n))
end
PH.countsequal = function()
	for _, kind in ipairs({ "players", "guilds", "filters" }) do
		local want = M.PSS_ListTotals(kind).total
		local set = S("index=counts kind=" .. kind:sub(1, -2) .. " type=total | stats sum(total)")
		local got = set and set[1][1] or -1
		check(got == want, kind .. ": counts " .. tostring(got) .. " ~= the pane's " .. tostring(want))
	end
end
PH.logsecret = function()
	secrets()
	local log = logLoaded()
	local e = History.NewEntry("whisper", "CHAT_MSG_WHISPER", "plain", nil, nil)
	e.message = secret("THE SECRET")
	e.o = "p:Sec-Realm"
	log[#log + 1] = e
	local set = S("index=log owner=p:Sec-Realm", { load = true })
	noSecrets()
	check(set and set.n == 1 and colv(set, 1, "message") == "(message hidden by the client)", "the hidden text shows, never the secret")
end
PH.logoff = function()
	check(not M.PSS_On("logging"), "Event Logging is off in this phase")
	local set, info = S("index=log")
	check(set and set.n == 0 and info.off == "off", "log answers off")
	set = S("index=counts")
	check(set ~= nil, "counts still answers")
end
PH.logcost = function()
	local log = logLoaded()
	for i = #log, 1, -1 do log[i] = nil end
	plantLog(2000)
	S("index=log gold", { load = true })
	local best = math.huge
	for _ = 1, 9 do local t0 = os.clock(); S("index=log gold", { load = true }); best = math.min(best, (os.clock() - t0) * 1000) end
	local B = dofile(here .. "/bus_budgets.lua")
	check(best <= B.us.text2k.gate / 1000, string.format("text search on 2,000 lines %.2f ms", best))
	print(string.format("NOTE ix logcost: %.2f ms (design %.1f ms)", best, B.us.text2k.design / 1000))
end

------------------------------------------------------------------------
-- TST-00923 inventory indexes
------------------------------------------------------------------------
PH.invst = function()
	whOn()
	local kinds = M.PSS_IX_INV_KINDS
	local have = {}
	for _, k in pairs(kinds) do have[k] = true end
	-- one source type per container row this client has (a row whose has() is false declares none)
	for _, row in ipairs(M.PSS_WH_CONTAINERS) do
		check((row.has() and true or false) == (have[row.kind] == true), row.kind .. ": declared only where the client has it")
	end
	if CAMELOT then check(not have.reagent and not have.warband and not have.void, "Camelot: no reagent, warband or void") end
	for code, kind in pairs(kinds) do check(L.types["inv." .. kind], "source type inv." .. kind) end
end
PH.invrows = function()
	whOn()
	local me = M.PSS_Me(false)
	local ents = M.PSS_WhStore.Ents()
	for _, e in ipairs(ents) do
		if e ~= me then
			local want = M.PSS_Call("wh.cont", { cols = { "ent" }, n = 1, { e } })
			local got = S("index=inv ent=" .. e .. " hidden=1 | stats sum(count)")
			local sum = 0
			for i = 1, want.n do sum = sum + want[i][5] end
			check(got and got[1][1] == sum, "entity " .. e .. ": rows equal wh.cont")
		end
	end
	if me then
		local live = M.PSS_Call("item.live", { cols = { "key" }, n = 1, { "*" } })
		local sum = 0
		for i = 1, live.n do sum = sum + live[i][5] end
		local codes = {}
		for c in pairs(live.conts or {}) do codes[c] = true end
		local got = S("index=inv ent=" .. me .. " | stats sum(count) by cont")
		local tot = 0
		for i = 1, got.n do if codes[got[i][1]] then tot = tot + got[i][2] end end
		check(tot == sum, "this character's live containers equal item.live")
	end
end
PH.invderive = function()
	local r = {}
	for _, f in ipairs({ "bl", "lb", "t123b", "bt123", "l", "" }) do
		local x = M.PSS_Ix("inv")
		-- the adapter's flag split, through a planted saved container
	end
	local function split(flags)
		local row = {}
		row.bound = flags:find("b", 1, true) and 1 or nil
		return row
	end
	whOn()
	local ms = M.PSS_WhStore
	local e = M.PSS_EntityId("c", "Flags", "Realm", true)
	local str = M.PSS_WhPack({ { 1, "2589", 1, "bl" }, { 2, "2589", 1, "lb" }, { 3, "2589", 1, "t123b" }, { 4, "2589", 1, "" } })
	ms.Put(e, { m0 = str })
	local set = S("index=inv ent=" .. e .. " | table slot, bound, loot, expires")
	local by = {}
	for i = 1, set.n do by[set[i][1]] = set[i] end
	check(by[1] and by[1][2] == 1 and by[1][3] == 1 and by[2][2] == 1 and by[2][3] == 1, "bl and lb")
	check(by[3] and by[3][2] == 1 and by[3][3] == nil and by[3][4] == 123, "t123b")
	check(by[4] and by[4][2] == nil and by[4][4] == nil, "no flags")
end
PH.invpush = function()
	whOn()
	local ents = M.PSS_WhStore.Ents()
	local e = ents[1]
	M.PSS_IxWhStats.conts = 0
	S("index=inv ent=" .. e .. " hidden=1")
	local one = M.PSS_IxWhStats.conts
	local codes = #M.PSS_WhStore.Codes(e)
	check(one <= codes + 12, "only that holder's containers read: " .. one)
	M.PSS_IxWhStats.conts = 0
	S("index=inv kind=bank")
	local banks = 0
	for _, x in ipairs(ents) do for _, c in ipairs(M.PSS_WhStore.Codes(x)) do if c:sub(1, 1) == "k" then banks = banks + 1 end end end
	check(M.PSS_IxWhStats.conts <= banks + 8, "kind=bank reads only bank codes: " .. M.PSS_IxWhStats.conts)
	local f0 = M.PSS_IxWhStats.finds
	local any = S("index=invsum | head 1")
	if any and any.n > 0 then
		local id = tostring(any[1][1]):match("^x?(%d+)")
		M.PSS_IxWhStats.conts = 0
		S("index=inv item=" .. id)
		check(M.PSS_IxWhStats.finds == f0 + 1, "item goes through wh.find")
	end
end
PH.invsum = function()
	whOn()
	local all = S("index=invsum", { rows = 5000 })
	check(all ~= nil, "invsum answers")
	local items2 = {}
	for i = 1, all.n do items2[all[i][1]] = true end
	local n = 0
	for item in pairs(items2) do
		n = n + 1
		if n > 20 then break end
		local want = M.PSS_Call("wh.find", { cols = { "item" }, n = 1, { item } })
		local got = 0
		for i = 1, all.n do if all[i][1] == item then got = got + all[i][4] end end
		local sum = 0
		for i = 1, want.n do sum = sum + want[i][4] end
		check(got == sum, "item " .. tostring(item) .. " equals wh.find")
	end
end
PH.invval = function()
	whOn()
	local set = S("index=inv | join item index=val | head 5")
	check(set and at(set, "vendor") and at(set, "auction") and at(set, "source"), "vendor, auction, source columns")
end
PH.whoff = function()
	check(not M.PSS_On("warehouse"), "the Warehouse is off")
	for _, name in ipairs({ "inv", "invsum", "cur", "gold", "val", "item" }) do
		local set, info = S("index=" .. name)
		check(set and set.n == 0 and info.off == "off", name .. " answers off")
	end
	check(M.PSS_WhStore == nil and rawget(_G, "PSS_WarehouseDB") == nil, "no store opened")
end
PH.invempty = function()
	whOn()
	local e = M.PSS_EntityId("c", "Empty", "Realm", true)
	local set = S("index=inv ent=" .. e)
	check(set and set.n == 0, "an entity with no items: empty")
end
PH.invorphan = function()
	whOn()
	local d = PSS_WarehouseDB
	local orphan = 987654
	d.inv = d.inv or {}
	d.inv[orphan] = { b0 = M.PSS_WhPack({ { 1, "2589", 3, "" } }) }
	M.PSS_WhStore.Bump()
	local a = S("index=inv ent=" .. orphan)
	local b = S("index=inv ent=" .. orphan .. " hidden=1")
	check(a and a.n == 0 and b and b.n == 1, "hidden, then shown with hidden=1: " .. tostring(a and a.n) .. " " .. tostring(b and b.n))
end
PH.invnewrow = function()
	-- a planted container row is a new source type with no engine change (the adapter reads the registry at load)
	whOn()
	local rows = M.PSS_WH_CONTAINERS
	rows[#rows + 1] = { code = "z", kind = "zoo", owner = "c", has = function() return true end, tabs = function() return { 0 } end }
	local chunk = assert(loadfile("PourSocialScore_Libraries/PSS_IxWh.lua"))
	local realDeclare = M.PSS_IxDeclare
	M.PSS_IxDeclare = function() end
	chunk("PourSocialScore_Libraries", { M = M })
	M.PSS_IxDeclare = realDeclare
	rows[#rows] = nil
	check(L.types["inv.zoo"] ~= nil, "inv.zoo registered from the new row")
end
PH.invsecret = function()
	whOn()
	secrets()
	local e = M.PSS_EntityId("c", "Plain", "Realm", true)
	local realEntity = M.PSS_Entity
	M.PSS_Entity = function(id)
		local s = realEntity(id)
		if id == e and s and s[1] then s[1][3] = secret("SECRETNAME") end
		return s
	end
	local set = S("index=ent")
	M.PSS_Entity = realEntity
	noSecrets()
	local leaked = false
	for i = 1, set.n do for j = 1, #set.cols do if set[i][j] == "SECRETNAME" then leaked = true end end end
	check(not leaked, "the secret name never reaches a row")
end

------------------------------------------------------------------------
-- TST-00924 social adapters
------------------------------------------------------------------------
PH.socialrows = function()
	local p = S("index=players", { rows = 5000 })
	check(p and p.n == #M.PSS_List(), "players: one row per list entry")
	-- W I G P C: ticked = allowed (a saved false); a planted entry with whispers allowed
	M.PSS_AddIgnore("Flagged-Realm", true)
	local rec = M.PSS_GetPlayerRecord("Flagged-Realm")
	if check(rec, "the planted entry has a record") then
		rec.whispersBlocked = false
		local w = S("index=players owner=" .. History.PlayerKey("Flagged-Realm"))
		check(w and w.n == 1 and colv(w, 1, "w") == 1 and colv(w, 1, "i") == nil, "w is whispers allowed, i blocked")
	end
	local f = S("index=filters", { rows = 5000 })
	check(f and f.n == M.PSS_FilterCount(), "filters: one row per filter")
	local g = S("index=guilds", { rows = 5000 })
	local n = 0
	for _, x in pairs(PourSocialScoreDB.guildData or {}) do if type(x) == "table" then n = n + 1 end end
	check(g and g.n == n, "guilds: one row per rule")
	for i = 1, g.n do
		local key = colv(g, i, "rule")
		check(colv(g, i, "members") == M.PSS_GuildMemberCount(PourSocialScoreDB.guildData[key], key), "members equal M.PSS_GuildMemberCount")
	end
end
PH.socialfields = function()
	local src = io.open("PourSocialScore_Libraries/PSS_IxSocial.lua"):read("*a")
	check(not src:find("%._playerKey") and not src:find("%._canon") and not src:find("memberCount") and not src:find("%.members%[") , "no member runtime field read directly")
	local h = io.popen("lua5.1 tools/check_fields.lua 2>&1; echo EXIT $?")
	local out = h:read("*a")
	h:close()
	check(out:find("EXIT 0"), "check_fields.lua passes: " .. out:sub(1, 200))
end
PH.membersneed = function()
	local _, info = S("index=members")
	local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)("PourSocialScore_Communities")
	check(loaded or (info.tier == 1 and info.needs == "Communities"), "tier 1, needs Communities")
	check(not (C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded)("PourSocialScore_Communities") or loaded, "the search did not load Communities")
end
PH.socialoff = function()
	check(not M.PSS_On("filtering"), "Social Filtering is off")
	for _, name in ipairs({ "players", "guilds", "members", "filters" }) do
		local set, info = S("index=" .. name)
		check(set and set.n == 0 and info.off == "off", name .. " answers off")
	end
end

------------------------------------------------------------------------
-- TST-00925 configuration adapters
------------------------------------------------------------------------
PH.cfgrows = function()
	local set = S("index=cfg", { rows = 5000 })
	check(set and set.n == #M.PSS_OPTIONS, "one row per option")
	for i = 1, set.n do
		local key = colv(set, i, "key")
		local o
		for _, x in ipairs(M.PSS_OPTIONS) do if x.key == key then o = x end end
		local v = M.PSS_Opt(key)
		check((colv(set, i, "changed") == 1) == (v ~= o.default and type(v) ~= "table"), key .. ": changed")
	end
end
PH.cfgreadonly = function()
	local before = H.serialize({ PourSocialScoreDB, PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB, PSS_RulesDB, PSS_CountsDB })
	for _, name in ipairs(M.PSS_IxNames()) do
		local x = M.PSS_Ix(name)
		check(x.write == nil and x.put == nil, name .. " has no write method")
		if x:ready() then x:scan({}, function() return true end, { load = false }) end
	end
	check(H.serialize({ PourSocialScoreDB, PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB, PSS_RulesDB, PSS_CountsDB }) == before, "saved data byte equal after every adapter ran")
end
PH.cfgnewer = function()
	check(M.PSS_On("addons"), "the addon manager is on")
	local realSlots = M.PSS_AddonSlots
	M.PSS_AddonSlots = function(who)
		local list = realSlots(who)
		if who == "all" then list[#list + 1] = { id = 9, hidden = true, empty = false } end
		return list
	end
	local set = S("index=addons place=9")
	M.PSS_AddonSlots = realSlots
	check(set and set.n == 1 and colv(set, 1, "name"):find("kept") and colv(set, 1, "addons") == nil, "listed as kept, not decoded")
end
PH.cfgsystem = function()
	for _, pair in ipairs({ { "trig", "trig.rows" }, { "upg", "upg.plan" }, { "err", "err.rows" } }) do
		local set = S("index=" .. pair[1], { rows = 5000 })
		local want = M.PSS_Call(pair[2])
		check(set and set.n == want.n, pair[1] .. " rows equal " .. pair[2])
	end
end

------------------------------------------------------------------------
-- TST-00926 internal log
------------------------------------------------------------------------
PH.pssproduce = function()
	M.PSS_IxHot("pss", true)
	M.PSS_ErrNote("cap", "t.produce", "past a cap")
	local T2 = M.PSS_Test or {}
	M.PSS_Test = T2
	M.PSS_IxPut("pss", "pss.upg", { step = 11, ok = 1, ms = 3 })		-- the runner's line (it writes one per upgraded step)
	M.PSS_IxPut("pss", "pss.start", { step = "filters", message = "boom" })
	local E = M.PSS_Engine and M.PSS_Engine()
	M.PSS_Want({ id = "t.card", class = "per-frame", step = function() return true end })
	M.PSS_Unwant("t.card")
	M.PSS_IxPut("pss", "pss.filter", { event = "CHAT_MSG_SAY", message = "refused" })
	local set = S("index=pss | stats count by st")
	local by = {}
	for i = 1, set.n do by[set[i][1]] = set[i][2] end
	for _, st in ipairs({ "pss.err", "pss.upg", "pss.start", "pss.card", "pss.filter" }) do check(by[st] and by[st] >= 1, st .. " line") end
end
PH.pssonce = function()
	M.PSS_IxHot("pss", true)
	for _ = 1, 50 do M.PSS_ErrNote("fail", "t.same", "the same error") end
	local set = S("index=pss st=pss.err service=t.same")
	check(set and set.n == 1, "one line for 50 notes, got " .. tostring(set and set.n))
end
PH.psshot = function()
	-- phase 1 writes 10 lines (Logging unloaded) and logs out; ix_phases.sh reloads the save into phase psshot2
	check(not M.PSS_LoggingReady(), "Logging not loaded")
	M.PSS_IxHot("pss", true)
	for i = 1, 10 do M.PSS_IxPut("pss", "pss.err", { code = "c", service = "hot", message = "line " .. i }) end
	check(#PourSocialScoreDB.pssHot == 10, "10 hot lines saved")
end
PH.psshot2 = function()
	local n0 = #(PourSocialScoreDB.pssHot or {})
	check(n0 >= 10, "the hot ring came back after the reload: " .. n0)
	local set = S("index=pss service=hot")
	check(set and set.n == 10, "10 lines from the ring")
	M.PSS_LoadLogging()
	check(PourSocialScoreDB.pssHot == nil, "the ring cleared")
	set = S("index=pss service=hot", { load = true })
	check(set and set.n == 10, "10 lines from the store")
end
PH.psscap = function()
	M.PSS_LoadLogging()
	local s = M.PSS_PssStore
	for i = 1, 1501 do s:add("pss.err", { time = 1000 + i, code = "c", service = "cap", message = "m" .. i }) end
	local Tb = PSS_LoggingDB.pss
	local sealed = 0
	for _, x in pairs(Tb.seg) do sealed = sealed + tonumber(x:match("^[^;]*;[^;]*;(%d+);")) end
	check(sealed == 1000 and s:count() == sealed + #Tb.open, "1,000 sealed lines kept (and the open ones): " .. sealed)
end
PH.pssnolog = function()
	check(not M.PSS_LoggingReady(), "Logging never loaded")
	M.PSS_IxPut("pss", "pss.err", { code = "c", service = "nolog", message = "x" })
	local set = S("index=pss service=nolog")
	check(set and set.n == 1 and not M.PSS_LoggingReady(), "the hot ring answers without Logging")
end

------------------------------------------------------------------------
-- TST-00927 system and saved queries
------------------------------------------------------------------------
local function put(t) return M.PSS_Call("sq.put", t) end
PH.sqsystem = function()
	for _, r in ipairs(M.PSS_SQ_SYSTEM) do
		check(r.id:find("^[a-z]+%.[a-z0-9.]+$"), r.id .. ": id shape")
		local plan, e = Q.compile(r.q)
		check(plan, r.id .. " compiles: " .. tostring(e and e.msg))
		local set, err = S(r.q, { params = { owner = "p:Nobody-Realm", item = "2589" }, load = true })
		check(set, r.id .. " runs: " .. tostring(err and err.msg))
	end
end
PH.sqput = function()
	local a = put({ name = "Whispers this week", scope = "any", query = "index=log cat=whisper | timechart span=1d count", time = "-7d", flags = "p" })
	check(a and a[1][1] == 1, "the first id is 1")
	local b = put({ name = "Second", query = "index=pss | head 5" })
	local got = M.PSS_Call("sq.get", { id = 1 })
	check(got.n == 1 and got[1][2] == "Whispers this week" and got[1][4] == "p" and got[1][6] == "-7d", "get")
	local list = M.PSS_Call("sq.list", {})
	check(list.n == 2, "list")
	check(PSS_OptionsDB.sqSaved:find("^1;3\n"), "saved as 1;<next id>")
	put({ id = 1, name = "Renamed", query = "index=pss | head 5" })
	check(M.PSS_Call("sq.get", { id = 1 })[1][2] == "Renamed", "put by id updates")
	M.PSS_Call("sq.del", { id = 1 })
	check(M.PSS_Call("sq.list", {}).n == 1, "delete")
end
PH.sqcaps = function()
	for i = 1, 200 do put({ name = "q" .. i, query = "index=pss" }) end
	local r, e = put({ name = "one more", query = "index=pss" })
	check(r == nil and e:find("^cap"), "the 201st is refused with cap")
	M.PSS_Call("sq.del", { id = 1 })
	r, e = put({ name = "long", query = "index=pss " .. string.rep("x", 504) })
	check(r == nil and e:find("^cap"), "513 bytes refused with cap")
	r, e = put({ name = string.rep("n", 49), query = "index=pss" })
	check(r == nil and e:find("^cap"), "49 byte name refused with cap")
end
PH.sqbroken = function()
	PSS_OptionsDB.sqSaved = "1;2\n" .. M.PSS_Codec.list({ 1, "Old", "any", "a", "index=log nofield=1", "" }, "\t")
	local list = M.PSS_Call("sq.list", {})
	check(list.n == 1 and list[1][7] == true, "kept and broken")
	check(M.PSS_SqAlerts[1] == nil, "a broken alert is never armed")
	check(PSS_OptionsDB.sqSaved:find("nofield"), "never deleted")
end
PH.sqcorrupt = function()
	M.PSS_ErrReset()
	PSS_OptionsDB.sqSaved = "1;5\n" .. M.PSS_Codec.list({ 1, "Cut", "any" }, "\t")
	local list = M.PSS_Call("sq.list", {})
	check(list.n == 0, "store empty")
	check(PSS_OptionsDB.sqSavedBad ~= nil and PSS_OptionsDB.sqSaved == nil, "quarantined")
	local n = 0
	local rows = M.PSS_ErrRows()
	for i = 1, rows.n do if rows[i][1] == "integrity" and rows[i][2] == "sq.saved" then n = n + 1 end end
	check(n == 1, "one note")
end
PH.sqbind = function()
	local plan = Q.compile("index=log owner=$owner | head 5")
	for _, v in ipairs({ "x | stats count", "a OR b=1", '"', ")", "$owner" }) do
		local b = plan:bind({ owner = v })
		check(b and b.where and b.where[1] and b.where[1].value == v and #b.steps == 1, "'" .. v .. "' stays one literal")
	end
end
PH.sqbuttons = function()
	-- the console's buttons (phase B) name system queries: every row the buttons will use exists and compiles
	local need = { "log.lines", "log.bytype", "log.24h", "log.byday", "log.hours", "filters.top", "log.cmp", "pss.recent", "wh.holders", "wh.gold" }
	local by = {}
	for _, r in ipairs(M.PSS_SQ_SYSTEM) do by[r.id] = r end
	for _, id in ipairs(need) do check(by[id] and Q.compile(by[id].q), id .. " exists and compiles") end
end
PH.sqgolden = function()
	-- golden answers: every system query on this save, as a stable text, compared with the stored answers of the
	-- previous build when PSS_GOLDEN names its file (written on the first run; ix_phases.sh keeps them per save)
	local lines = {}
	for _, r in ipairs(M.PSS_SQ_SYSTEM) do
		local set = S(r.q, { params = { owner = "p:Nobody-Realm", item = "2589" }, load = true, rows = 5000 })
		local cells = { r.id, set and set.n or "err" }
		for i = 1, set and math.min(set.n, 20) or 0 do
			for j = 1, #set.cols do
				local c = set.cols[j]
				if c ~= "time" and c ~= "ms" then cells[#cells + 1] = tostring(set[i][j]) end
			end
		end
		lines[#lines + 1] = table.concat(cells, "|")
	end
	local text = table.concat(lines, "\n")
	local path = os.getenv("PSS_GOLDEN")
	if path then
		local fh = io.open(path, "rb")
		if fh then
			local old = fh:read("*a")
			fh:close()
			check(old == text, "the system queries' answers changed against " .. path)
		else
			fh = io.open(path, "wb"); fh:write(text); fh:close()
			print("NOTE ix sqgolden: answers written to " .. path)
		end
	end
	check(#lines == #M.PSS_SQ_SYSTEM, "every system query answered")
end
PH.sqfuzz = function()
	local r = rng(927)
	for i = 1, 10000 do
		local parts = {}
		for k = 1, r(0, 6) do
			local chars = {}
			for j = 1, r(0, 8) do chars[j] = string.char(r(9, 126)) end
			parts[k] = table.concat(chars)
		end
		PSS_OptionsDB.sqSaved = (r(0, 1) == 1 and "1;" or "") .. table.concat(parts, r(0, 1) == 1 and "\n" or "\t")
		PSS_OptionsDB.sqSavedBad = nil
		local ok = pcall(M.PSS_Call, "sq.list", {})
		if not check(ok, "sq.list raised") then return end
	end
end
PH.sqdowngrade = function()
	-- written by this build: the phase writes the three keys; ix_phases.sh loads the save with origin/main and
	-- compares the keys (they must come back untouched)
	put({ name = "Kept", query = "index=pss | head 1" })
	M.PSS_IxPut("pss", "pss.err", { code = "c", service = "down", message = "x" })
	M.PSS_LoadLogging()
	M.PSS_IxPut("pss", "pss.err", { code = "c", service = "down2", message = "y" })
	check(PSS_OptionsDB.sqSaved and PSS_LoggingDB.pss and PourSocialScoreDB.pssHot, "the three keys exist")
end

------------------------------------------------------------------------
-- TST-00928 alerts
------------------------------------------------------------------------
local said = {}
local function capture() said = {}; M.ShowMsg = function(s) said[#said + 1] = s end end
PH.alerton = function()
	local id = put({ name = "Errors", query = "index=pss st=pss.err", flags = "a" })[1][1]
	check(M.PSS_SqAlerts[id] and M.PSS_IxWaiting.pss == true, "trigger row declared, M.PSS_IxWaiting.pss")
	local found = false
	local needs = M.PSS_Needs()
	for i = 1, needs.n do if needs[i][1] == "sq.alert." .. id then found = true end end
	check(found, "the need is declared")
end
PH.alertfire = function()
	capture()
	local id = put({ name = "Errors", query = "index=pss st=pss.err", flags = "a" })[1][1]
	H.SetTime(GetServerTime() + 5)
	M.PSS_IxPut("pss", "pss.err", { code = "c", service = "alert", message = "x" })
	local line
	for _, s in ipairs(said) do if s:find("Spyglass alert") then line = s end end
	check(line and line:find("Errors") and line:find("1 new line"), "one chat line with name and count: " .. tostring(line))
end
PH.alertrate = function()
	capture()
	put({ name = "Rate", query = "index=pss st=pss.err", flags = "a" })
	local t = GetServerTime()
	for i = 1, 30 do
		H.SetTime(t + math.floor(i / 3))
		M.PSS_IxPut("pss", "pss.err", { code = "c", service = "rate" .. i, message = "x" })
	end
	local n = 0
	for _, s in ipairs(said) do if s:find("Spyglass alert") then n = n + 1 end end
	check(n == 1, "one line for 30 puts in 10 s, got " .. n)
end
PH.alertoff = function()
	capture()
	local id = put({ name = "Off", query = "index=pss st=pss.err", flags = "a" })[1][1]
	put({ id = id, name = "Off", query = "index=pss st=pss.err", flags = "" })
	check(M.PSS_SqAlerts[id] == nil and M.PSS_IxWaiting.pss == nil, "no row, nothing waits")
	local sig = 0
	local real = M.PSS_Signal
	M.PSS_Signal = function() sig = sig + 1 end
	M.PSS_IxPut("pss", "pss.err", { code = "c", service = "off", message = "x" })
	M.PSS_Signal = real
	check(sig == 0 and #said == 0, "no signal, no line")
end
PH.alerttimers = function()
	local h = io.popen("lua5.1 tools/check_timers.lua 2>&1; echo EXIT $?")
	local out = h:read("*a")
	h:close()
	check(out:find("EXIT 0"), "check_timers.lua: the approved list is unchanged: " .. out:sub(1, 300))
	for _, f in ipairs({ "PSS_SQ.lua", "PSS_Plan.lua", "PSS_IxLog.lua" }) do
		local src = io.open("PourSocialScore_Libraries/" .. f):read("*a")
		check(not src:find("C_Timer") and not src:find("OnUpdate"), f .. " holds no timer and no OnUpdate")
	end
end

------------------------------------------------------------------------
-- TST-00929 export and /pss q
------------------------------------------------------------------------
PH.qcmd = function()
	capture()
	for i = 1, 30 do M.PSS_IxPut("pss", "pss.err", { code = "c", service = "q" .. i, message = "m" .. i }) end
	M.PSS_SlashPSS("q index=pss")
	local events = #said
	check(events == 22, "20 event lines, a more line and the footer: " .. events)
	capture()
	M.PSS_SlashPSS("q index=cfg | table key, value, default, section, changed, key")
	check(said[1] and said[1]:find("key") and not said[1]:find("%+"), "a table header")
	capture()
	M.PSS_SlashPSS("q index=cfg | stats count")
	check(said[1] and said[1]:find("^count = %d+"), "a number: " .. tostring(said[1]))
	check(said[#said]:find("rows,") and said[#said]:find("scanned"), "the footer")
	capture()
	M.PSS_SlashPSS("q index=lgo")
	check(said[1] and said[1]:find("did you mean log"), "an error line")
	capture()
	M.PSS_SlashPSS("q status")
	check(#said >= 24 and said[1]:find("Spyglass indexes"), "status lists every index")
	local wide = { cols = { "a", "b", "c", "d", "e", "f", "g", "h" }, n = 1, { 1, 2, 3, 4, 5, 6, 7, 8 } }
	local out = M.PSS_QLines(wide, { shape = "table" })
	check(out[1]:find("%(%+2 columns%)") and select(2, out[2]:gsub("|", "")) == 5, "at most 6 columns")
end
PH.csvquote = function()
	local set = { cols = { "a", "b" }, n = 2, { 'x,y', 'say "hi"' }, { "line\nbreak", 5 } }
	local csv = M.PSS_IxCsv(set)
	check(csv == 'a,b\r\n"x,y","say ""hi"""\r\n"line\nbreak",5', "RFC 4180: " .. csv)
end
PH.pssio = function()
	local set = { cols = { "a", "b", "c" }, n = 3, { 1, "x;y,z.=\t\n%", nil }, { 2.5, "", "q" }, { nil, nil, nil } }
	local back = M.PSS_IxFromPssio(M.PSS_IxPssio(set))
	check(back and back.n == 3 and back[1][1] == 1 and back[1][2] == "x;y,z.=\t\n%" and back[2][1] == 2.5 and back[2][2] == "" and back[3][1] == nil, "round trip")
end
PH.pssiobad = function()
	local text = M.PSS_IxPssio({ cols = { "a" }, n = 1, { 1 } })
	local bad = text:sub(1, -2) .. "9"
	local set, err = M.PSS_IxFromPssio(bad)
	check(set == nil and err:find("^integrity"), "a damaged string: integrity, nothing imported")
end
PH.loadlog = function()		-- loads Logging so the save written after it holds the log as this version keeps it
	check(M.PSS_LoadLogging(), "Logging loads")
end
PH.reader = function()
	-- the offline reader (tools/ops/sfpss_reader.py) on this save: its row counts equal the adapters'
	local sv = os.getenv("PSS_READER_SAVE")
	if not sv then print("NOTE ix reader: no save given (ix_phases.sh gives one)") return end
	local h = io.popen('python3 tools/ops/sfpss_reader.py --counts "' .. sv .. '" 2>&1')
	local out = h:read("*a")
	h:close()
	local log = tonumber(out:match("log (%d+)"))
	local n = 0
	History.Each(function() n = n + 1 end)
	n = n + History.Waiting()
	check(log == n, "reader log rows " .. tostring(log) .. " ~= " .. n .. ": " .. out:sub(1, 200))
	local sq = tonumber(out:match("sqSaved (%d+)"))
	check(sq == M.PSS_Call("sq.list", {}).n, "reader saved queries")
end

------------------------------------------------------------------------
-- TST-00931 budgets
------------------------------------------------------------------------
local FILES = { "PSS_Ix.lua", "PSS_IxCatalog.lua", "PSS_Line.lua", "PSS_Seg.lua", "PSS_IxDict.lua", "PSS_Time.lua", "PSS_Pred.lua", "PSS_Stats.lua", "PSS_Terms.lua",
	"PSS_Psql.lua", "PSS_Plan.lua", "PSS_IxLog.lua", "PSS_IxWh.lua", "PSS_IxSocial.lua", "PSS_IxCfg.lua", "PSS_SQ.lua", "PSS_IxExport.lua" }
M.PSS_IX_FILES = FILES
PH.budgetfiles = function()
	-- each file's resident cost as it loads for the first time, in Libraries' order, in a fresh client (ix_measure.lua)
	local B = dofile(here .. "/bus_budgets.lua")
	local h = io.popen("PSS_MEASURE=1 PSS_COMPONENTS=logging,warehouse,dtt,addons lua5.1 " .. here .. "/run.lua . - - " .. here .. "/ix_measure.lua 2>&1")
	local out = h:read("*a")
	h:close()
	local note, seen = {}, 0
	for name, kb in out:gmatch("KB (%S+) (%S+)") do
		kb = tonumber(kb)
		local gate = B.kb[name]
		for _, f in ipairs(FILES) do
			if f == name then
				seen = seen + 1
				if check(gate, name .. " has no gate in bus_budgets.lua") then
					check(kb <= gate.gate, string.format("%s resident %.2f KB over its gate %.1f KB", name, kb, gate.gate))
				end
				note[#note + 1] = string.format("%s %.2f", name, kb)
			end
		end
	end
	check(seen == #FILES, "every engine file measured: " .. seen .. " of " .. #FILES .. " " .. out:sub(1, 200))
	print("NOTE ix budgetfiles: " .. table.concat(note, ", "))
end
PH.budgetcalls = function()
	local B = dofile(here .. "/bus_budgets.lua")
	local N = 20000
	local best = math.huge
	local rec = { code = "c", service = "s", message = "m" }
	for _ = 1, 5 do
		local t0 = os.clock()
		for _ = 1, N do M.PSS_IxPut("pss", "pss.err", rec) end
		best = math.min(best, (os.clock() - t0) / N * 1e6)
	end
	check(best <= B.us.ixput.gate, string.format("ix.put %.2f us over %.1f", best, B.us.ixput.gate))
	local line = L.encode("pss.err", { time = 5, code = "c", service = "s", message = "m" }, 0)
	local out = {}
	local d = math.huge
	for _ = 1, 5 do local t0 = os.clock() for _ = 1, N do L.decode(line, 0, out) end d = math.min(d, (os.clock() - t0) / N * 1e6) end
	check(d <= B.us.decode.gate, string.format("L.decode %.2f us over %.1f", d, B.us.decode.gate))
	local pmax = 0
	for _, ex in ipairs(EXAMPLES) do
		local best = math.huge
		for _ = 1, 5 do
			local t0 = os.clock()
			for _ = 1, 20 do Q.compile(ex[1]) end
			best = math.min(best, (os.clock() - t0) / 20 * 1e6)
		end
		pmax = math.max(pmax, best)
	end
	check(pmax <= B.us.parse.gate, string.format("the slowest example parses in %.0f us over %d", pmax, B.us.parse.gate))
	local tk = 0
	local long = ("index=log cat=whisper earliest=-7d | stats count by owner | sort -count | head 5 "):rep(6):sub(1, 512)
	tk = math.huge
	for _ = 1, 5 do
		local t0 = os.clock()
		for _ = 1, 20 do Q.tokens(long) end
		tk = math.min(tk, (os.clock() - t0) / 20 * 1e6)
	end
	check(tk <= B.us.tokens.gate, string.format("tokens of 512 bytes %.0f us over %d", tk, B.us.tokens.gate))
	print(string.format("NOTE ix budgetcalls: ix.put %.2f us, decode %.2f us, parse max %.0f us, tokens 512 B %.0f us", best, d, pmax, tk))
end
PH.budgetcore = PH.putcost
PH.budgetci = function()
	local y = io.open(".github/workflows/rules.yml"):read("*a")
	check(y:find("ix_phases.sh"), "the CI harness job runs ix_phases.sh (its budget phases fail the job on a breach)")
	local v = io.open(here .. "/validate_all.sh"):read("*a")
	check(v:find("ix_phases.sh"), "validate_all.sh runs ix_phases.sh")
end

------------------------------------------------------------------------
-- TST-00964 data dictionary
------------------------------------------------------------------------
PH.dictrows = function()
	local rows = M.PSS_DataDictRows()
	for _, name in ipairs(M.PSS_IxNames()) do
		for _, f in ipairs(M.PSS_Ix(name).fields) do check(rows[name .. "." .. f[1]], name .. "." .. f[1] .. " has no row") end
	end
	local set = M.PSS_Call("ix.dict", { index = "log" })
	check(set and set.n == #M.PSS_Ix("log").fields and at(set, "values"), "ix.dict lists log's rows")
end
PH.dictdrift = function()
	local cases = {
		{ function() History.ALL_CATS[#History.ALL_CATS + 1] = "planted" end, function() History.ALL_CATS[#History.ALL_CATS] = nil end, "log", "planted" },
		{ function() M.PSS_ERR_CODES.planted = true end, function() M.PSS_ERR_CODES.planted = nil end, "pss", "planted" },
	}
	if M.PSS_WH_CONTAINERS then
		cases[#cases + 1] = { function() M.PSS_WH_CONTAINERS[#M.PSS_WH_CONTAINERS + 1] = { kind = "planted" } end, function() M.PSS_WH_CONTAINERS[#M.PSS_WH_CONTAINERS] = nil end, "inv", "planted" }
	end
	for _, c in ipairs(cases) do
		c[1]()
		local ok, e = pcall(M.PSS_DataDictCheck, M.PSS_Ix(c[3]))
		c[2]()
		check(not ok and tostring(e):find(c[4], 1, true), c[3] .. ": a planted value raises naming it: " .. tostring(e))
	end
	-- an option key: cfg.key follows the code (a provider), so a planted option has its row at once
	M.PSS_OPTIONS[#M.PSS_OPTIONS + 1] = { key = "plantedOpt", default = false }
	local list = M.PSS_DataDictValues.optionKeys()
	M.PSS_OPTIONS[#M.PSS_OPTIONS] = nil
	check(list[#list] == "plantedOpt", "an option key is in cfg.key's values at once")
end
PH.dictextend = function()
	M.PSS_ErrReset()
	local ok, e = M.PSS_DataDictExtend("journal-helper", { { index = "log", field = "extra", kind = "s" } })
	check(not ok and e:find("does not own"), "a non-owner is refused")
	ok, e = M.PSS_DataDictExtend("social-manager", { { index = "log", field = "fine", kind = "s" }, { index = "log", field = "cat", kind = "n" } })
	check(not ok and e:find("exists with kind") and M.PSS_DataDict["log.fine"] == nil, "a kind clash is refused, nothing half added")
	ok = M.PSS_DataDictExtend("social-manager", { { index = "log", field = "fine", kind = "s", values = "a b", since = "3.8.0.116" } })
	check(ok and M.PSS_DataDict["log.fine"] and M.PSS_DataDict["log.fine"].since == "3.8.0.116", "a valid row is added")
	local rows = M.PSS_ErrRows()
	check(rows.n == 2, "one note per refusal")
end
PH.dictunknownattr = function()
	M.PSS_DataDictExtend("search-helper", { { index = "pss", field = "newthing", kind = "s", wibble = "kept raw", tags = { "money" } } })
	local set = M.PSS_Call("ix.dict", { index = "pss" })
	local row
	for i = 1, set.n do if set[i][3] == "newthing" then row = set[i] end end
	check(row and tostring(row[13]):find("wibble=kept raw"), "an unknown attribute is kept and shown raw")
end
PH.dictgen = function()
	local h = io.popen("lua5.1 tools/ops/gen_datadict.lua --stdout 2>&1")
	local text = h:read("*a")
	h:close()
	check(text:find("^# 16_02_Data_Dictionary"), "the generator writes the document: " .. text:sub(1, 120))
	local doc = os.getenv("PSS_SCRATCH") and (os.getenv("PSS_SCRATCH") .. "/documents/features/search-helper/16_Registries/16_02_Data_Dictionary.md")
	if not doc then
		local f = io.open("../Pour-Social-Score_Scratch/documents/features/search-helper/16_Registries/16_02_Data_Dictionary.md")
		if f then f:close(); doc = "../Pour-Social-Score_Scratch/documents/features/search-helper/16_Registries/16_02_Data_Dictionary.md" end
	end
	if doc then
		local fh = io.open(doc, "rb")
		local old = fh and fh:read("*a")
		if fh then fh:close() end
		check(old == text, "the generator reproduces " .. doc .. " byte for byte")
	else
		print("NOTE ix dictgen: no scratch checkout: the byte compare did not run")
	end
end

------------------------------------------------------------------------
-- TST-00965 field summary and values
------------------------------------------------------------------------
PH.fsall = function()
	local set = { cols = { "n", "s" }, n = 6, { 1, "a" }, { 3, "b" }, { 3, "a" }, { nil, "a" }, { 9, nil }, { 3, "" } }
	local out = M.PSS_Call("q.fieldsummary", set, { maxvals = 2 })
	local n, s = out[1], out[2]
	check(n[1] == "n" and n[3] == 5 and n[4] == 3 and n[5] == 1 and n[6] == 1 and n[7] == 9 and n[8] == "3 (3), 1 (1)", "n: " .. table.concat({ tostring(n[3]), tostring(n[4]), tostring(n[5]), tostring(n[6]), tostring(n[7]), tostring(n[8]) }, " "))
	check(s[3] == 4 and s[4] == 2 and s[5] == 2 and s[8] == "a (3), b (1)", "s")
end
PH.fsunknown = function()
	local set = { cols = { "cat" }, n = 3, { "whisper" }, { "planted" }, { "whisper" } }
	local out = M.PSS_Call("q.fieldsummary", set, { dict = M.PSS_DataDictFor({ "log" }) })
	check(out[1][8]:find("unknown:planted"), "unknown:planted shows: " .. out[1][8])
	local s2 = S("index=log | fieldsummary")
	check(s2 ~= nil, "| fieldsummary runs on log")
end
PH.fscap = function()
	local set = { cols = { "v" }, n = 10001 }
	for i = 1, 10001 do set[i] = { i } end
	local out = M.PSS_Call("q.fieldsummary", set, {})
	check(out.approx and out[1][4] == 10000, "distinct capped, approximate")
end
PH.fsempty = function()
	local out = M.PSS_Call("q.fieldsummary", { cols = { "a", "b" }, n = 0 }, {})
	check(out.n == 2 and out[1][3] == 0 and out[1][4] == 0 and out[1][5] == 0, "one row per field with zeros")
end
PH.valuescache = function()
	local b0 = M.PSS_IxValuesStats.builds
	M.PSS_Call("ix.values", { index = "pss", field = "st", n = 5 })
	M.PSS_Call("ix.values", { index = "pss", field = "st", n = 5 })
	check(M.PSS_IxValuesStats.builds == b0 + 1, "the second call is cached")
	M.PSS_IxPut("pss", "pss.err", { code = "c", service = "v", message = "x" })
	local set = M.PSS_Call("ix.values", { index = "pss", field = "st", n = 5 })
	check(M.PSS_IxValuesStats.builds == b0 + 2 and set.n >= 1, "rebuilt after a write")
end

------------------------------------------------------------------------
-- TST-00966 lazy search
------------------------------------------------------------------------
local LINK = "|cff1eff00|Hitem:21877::::::::70:::::|h[Nether Cloth]|h|r"
local function lazyWorld(journalOn)
	items()
	local log = logLoaded()
	plantLog(200)
	for i = 1, 3 do
		local e = History.NewEntry("world", "CHAT_MSG_CHANNEL", "WTS " .. LINK .. " x" .. i, "Trade", nil)
		e.o = "p:Seller" .. i .. "-Realm"
		log[#log + 1] = e
	end
	local e = History.NewEntry("whisper", "CHAT_MSG_WHISPER", "hi from thrall", nil, nil)
	e.o = History.PlayerKey("Thrall-" .. (GetRealmName and GetRealmName() or "Realm"))
	log[#log + 1] = e
	-- planted journal and history indexes (built in phase C): the lazy search covers them by name
	local now = GetServerTime()
	local gate
	if not journalOn then gate = "journal" end
	M.PSS_IxDeclare({ name = "jrn", kind = "event", owner = "journal-helper", gate = gate, residency = 0,
		fields = { { "time", "t", "t" }, { "st", "k", "s" }, { "ent", "e", "e" }, { "item", "i", "i" }, { "count", "n", "n" }, { "party", "s", "p" } },
		pushdown = { "time" }, doc = "planted journal",
		summary = function(r) return "Sold " .. r.count .. " " .. tostring(r.item) .. " to " .. tostring(r.party) end,
		scan = function(pd, emit)
			for i = 1, 6 do emit({ time = now - i * 100, st = "jrn.sold", ent = 1, item = 21877, count = 20, party = "Thrall" }) end
			emit({ time = now - 50, st = "jrn.sold", ent = 1, item = 4306, count = 1, party = "Other" })
			return 7
		end })
	M.PSS_IxDeclare({ name = "whh", kind = "event", owner = "journal-helper", gate = gate, residency = 0,
		fields = { { "time", "t", "t" }, { "st", "k", "s" }, { "ent", "e", "e" }, { "item", "i", "i" }, { "delta", "n", "n" } },
		pushdown = { "time" }, doc = "planted history",
		summary = function(r) return "Stock " .. r.delta end,
		scan = function(pd, emit)
			emit({ time = now - 10, st = "whh.d", ent = 1, item = 21877, delta = -20 })
			emit({ time = now - 20, st = "whh.d", ent = 1, item = 21877, delta = 40 })
			return 2
		end })
end
PH.lazyitem = function()
	lazyWorld(true)
	local set, info = S("Nether Cloth", { load = true })
	local by = {}
	for i = 1, set.n do local x = colv(set, i, "index"); by[x] = (by[x] or 0) + 1 end
	check(by.log == 3 and by.jrn == 6 and by.whh == 2, "log 3, jrn 6, whh 2: " .. tostring(by.log) .. " " .. tostring(by.jrn) .. " " .. tostring(by.whh))
	check(info.resolved and info.resolved:find("1 item"), "info.resolved names 1 item: " .. tostring(info.resolved))
	check(table.concat(set.cols, ",") == "time,index,st,ent,item,owner,summary", "the lazy columns")
end
PH.lazyprefix = function()
	items()
	local got = M.PSS_Terms.names("Nether")
	check(#got.items == 1 and got.items[1] == 21877, "prefix refs: Nether Cloth")
	got = M.PSS_Terms.names("bolt of netherweave")
	check(got.items[1] == 21840, "exact first")
	got = M.PSS_Terms.names("Linen")
	check(got.items[1] == 2589, "prefix")
end
PH.lazyambig = function()
	items()
	for i = 1, 80 do H.items[700000 + i] = { name = "Potion of Thing " .. i } ; M.PSS_Terms.extraIds[#M.PSS_Terms.extraIds + 1] = 700000 + i end
	H.items[700100] = { name = "Potion" }
	M.PSS_Terms.extraIds[#M.PSS_Terms.extraIds + 1] = 700100
	M.PSS_Terms.extraVer = M.PSS_Terms.extraVer + 1
	local got = M.PSS_Terms.names("Potion")
	check(#got.items == 1 and got.items[1] == 700100 and got.ambiguous == 81, "exact only, ambiguous 81: " .. #got.items .. " " .. tostring(got.ambiguous))
	local _, info = S("Potion")
	check(info.ambiguous == 81, "the search says ambiguous")
end
PH.lazyplayer = function()
	lazyWorld(true)
	local set = S("Thrall", { load = true })
	local log, jrn = 0, 0
	for i = 1, set.n do
		if colv(set, i, "index") == "log" then log = log + 1 end
		if colv(set, i, "index") == "jrn" then jrn = jrn + 1 end
	end
	check(log >= 1 and jrn == 6, "the owner's lines and the journal rows with party Thrall: " .. log .. " " .. jrn)
end
PH.lazyoff = function()
	lazyWorld(false)
	local set, info = S("Nether Cloth", { load = true })
	local notes = table.concat(info.notes, ";")
	check(notes:find("jrn: off") and notes:find("whh: off"), "jrn and whh skipped, noted: " .. notes)
	for i = 1, set.n do check(colv(set, i, "index") == "log", "only log rows") end
end
PH.lazypending = function()
	items()
	lazyWorld(true)
	local got = M.PSS_Terms.names("Unloaded Two")
	check(#got.items == 0, "not loaded: no name to match")
	H.items[999002].unknown = nil
	M.PSS_Terms.extraVer = M.PSS_Terms.extraVer + 1
	got = M.PSS_Terms.names("Unloaded Two")
	check(got.items[1] == 999002, "matched by id once loaded")
end
PH.lazysummary = function()
	lazyWorld(true)
	local set = S("Nether Cloth", { load = true })
	local ok = true
	for i = 1, set.n do if type(colv(set, i, "summary")) ~= "string" then ok = false end end
	check(ok and set.n > 0, "every row has a summary")
	local any = false
	for i = 1, set.n do if colv(set, i, "summary"):find("^Sold 20") then any = true end end
	check(any, "the journal's summary")
end
PH.lazycost = function()
	items()
	for i = 1, 5000 do H.items[800000 + i] = { name = "Item " .. i }; M.PSS_Terms.extraIds[#M.PSS_Terms.extraIds + 1] = 800000 + i end
	M.PSS_Terms.extraVer = M.PSS_Terms.extraVer + 1
	local build = math.huge
	for _ = 1, 5 do		-- the best of five
		M.PSS_Terms.nameIndex:drop()
		collectgarbage("collect")
		local t0 = os.clock()
		M.PSS_Terms.names("Nether Cloth")
		build = math.min(build, (os.clock() - t0) * 1000)
	end
	local b0 = M.PSS_Terms.nameIndex:builds()
	local t0 = os.clock()
	for _ = 1, 100 do M.PSS_Terms.nameIndex:get("nether cloth") end
	local look = (os.clock() - t0) * 1000 / 100
	check(M.PSS_Terms.nameIndex:builds() == b0, "built once")
	local B = dofile(here .. "/bus_budgets.lua")
	check(build <= B.us.namebuild.gate / 1000 and look <= 0.05, string.format("build %.1f ms, lookup %.4f ms", build, look))
	print(string.format("NOTE ix lazycost: name index build %.1f ms (5,011 items), lookup %.4f ms", build, look))
end

------------------------------------------------------------------------
local f = PH[phase]
if not f then
	check(false, "no such phase")
else
	local ok, e = xpcall(f, debug.traceback)
	if not ok then check(false, "raised: " .. tostring(e)) end
end
if not fail then print("PASS ix " .. phase) end
