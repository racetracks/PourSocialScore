-- Journal index (build J1I): the segment store, retention, postings, the gate, newer saves, damage, reload, dictionary rows.
local M = PourSocialScore_NS.M
local function fail(w) print("FAIL jrn: index: " .. w) end
local L = M.PSS_Line
local flv = M.PSS_FLV.flavour
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local DAY = 86400

-- the 13 declared source types and their fields (journal 05 section 2), names only
local SPEC = {
	sold = "item count value deposit consignment buyer", bought = "item count value seller",
	post = "item count unit deposit duration", fail = "item count kind",
	vend = "item count unit kind currencies items", repair = "copper guild",
	mailout = "party copper cod items subject", mailin = "party copper cod items subject",
	trade = "party copperOut copperIn itemsOut itemsIn", taxi = "copper from to", train = "copper spell",
	quest = "quest copper xp rep items currencies", loot = "container copper items currencies",
}
local NUMK = { n = true, c = true, e = true, i = true }

local on = false
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "journal" then return on end return realOn(n) end
PSS_WarehouseDB = PSS_WarehouseDB or {}
local function reset(gate)
	PSS_WarehouseDB.jrn = nil
	if M.PSS_JrnStore then M.PSS_JrnStore:drop() end
	M.PSS_IxHot("jrn", true)
	M.PSS_IndexDrop("jrn.item")
	on = gate
	M.PSS_SetOpt("jrnMonths", "global", 13)
end
local function split(s)
	local out = {}
	for v in (s .. ","):gmatch("([^,]*),") do out[#out + 1] = v end
	return out
end
local function names(s)
	local out = {}
	for w in s:gmatch("%S+") do out[#out + 1] = w end
	return out
end
local function put(st, rec)
	local ok = M.PSS_IxPut("jrn", st, rec)
	if ok then M.PSS_IxFlush("jrn") end
	return ok
end
local function rows(pd)
	local out = {}
	local n, partial, why = M.PSS_Ix("jrn"):scan(pd or {}, function(r)
		local c = {}
		for k, v in pairs(r) do if k ~= "__f" then c[k] = v end end
		out[#out + 1] = c
	end, { load = true })
	return out, n, why
end

-- declared types match the spec (names and kinds present)
for s, f in pairs(SPEC) do
	local ty = L.types["jrn." .. s]
	if not ty then return fail("source type jrn." .. s .. " not declared") end
	local got = {}
	for _, x in ipairs(ty.fields) do got[#got + 1] = x[1] end
	if table.concat(got, " ") ~= f then return fail("jrn." .. s .. " fields " .. table.concat(got, " ") .. " want " .. f) end
end

-- fxshape + jrnstore: the fixture day lands in two month segments, every record reads back
reset(true)
local fx = dofile(here .. "/fixtures/jrn_day.lua").expect
local all = {}
for stream, list in pairs(fx) do
	if SPEC[stream] then
		local nm = names(SPEC[stream])
		for _, line in ipairs(list) do
			local p = split(line)
			if #p ~= 2 + #nm then return fail("fxshape: " .. stream .. " line has " .. #p .. " fields, want " .. (2 + #nm)) end
			all[#all + 1] = { stream = stream, p = p, t = tonumber(p[1]) }
		end
	end
end
table.sort(all, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.stream < b.stream end)
for _, a in ipairs(all) do
	local rec, nm = { time = a.t, ent = tonumber(a.p[2]) }, names(SPEC[a.stream])
	local ty = L.types["jrn." .. a.stream]
	for i, f in ipairs(nm) do
		local v, kind = a.p[2 + i], ty.fields[i][2]
		if v ~= "" then
			if NUMK[kind] then rec[f] = tonumber(v) elseif kind == "b" then rec[f] = v == "1" and 1 or nil else rec[f] = v end
		end
	end
	if not put("jrn." .. a.stream, rec) then return fail("jrnstore: put refused for " .. a.stream) end
end
local T = PSS_WarehouseDB.jrn
if type(T) ~= "table" or not T.seg or not T.seg[1] or #(T.open or {}) == 0 then return fail("jrnstore: not two month segments") end
if M.PSS_JrnStore:count() ~= #all then return fail("jrnstore: count " .. M.PSS_JrnStore:count() .. " want " .. #all) end
local got = rows()
if #got ~= #all then return fail("jrnstore: read " .. #got .. " rows, want " .. #all) end
local byKey = {}
for _, r in ipairs(got) do byKey[r.st .. "|" .. r.time] = r end
for _, a in ipairs(all) do
	local r = byKey["jrn." .. a.stream .. "|" .. a.t]
	if not r then return fail("jrnstore: " .. a.stream .. " " .. a.t .. " missing") end
	local nm = names(SPEC[a.stream])
	local ty = L.types["jrn." .. a.stream]
	for i, f in ipairs(nm) do
		local v, kind = a.p[2 + i], ty.fields[i][2]
		if kind == "b" then
			if (r[f] ~= nil and r[f] ~= 0) ~= (v == "1") then return fail("jrnstore: " .. a.stream .. "." .. f .. " flag") end
		elseif v == "" then
			if r[f] ~= nil and r[f] ~= "" then return fail("jrnstore: " .. a.stream .. "." .. f .. " not empty") end
		elseif tostring(r[f]) ~= v then return fail("jrnstore: " .. a.stream .. "." .. f .. " is " .. tostring(r[f]) .. " want " .. v) end
	end
end

-- jrndict: a dictionary row per stream field
for s, f in pairs(SPEC) do
	for _, fld in ipairs(names(f)) do
		if not M.PSS_DataDict["jrn." .. fld] then return fail("jrndict: no row jrn." .. fld) end
	end
end

-- jrnmonths: 15 months of lines; 0 keeps all, 13 then 1 drop the older months
reset(true)
local now = GetServerTime()
M.PSS_SetOpt("jrnMonths", "global", 0)
local times = {}
for i = 0, 15 do
	local t = now - (15 - i) * 31 * DAY
	times[#times + 1] = t
	put("jrn.repair", { time = t, ent = 1, copper = 100 + i })
end
local function count() return M.PSS_JrnStore:count() end
if count() ~= 16 then return fail("jrnmonths: stored " .. count()) end
M.PSS_SetOpt("jrnMonths", "global", 0)
M.PSS_JrnTrim()
if count() ~= 16 then return fail("jrnmonths: 0 dropped lines: " .. count()) end
local function edge(k)
	local d = os.date("*t", now)
	local m, y = d.month - k, d.year
	while m < 1 do m = m + 12; y = y - 1 end
	return os.time({ year = y, month = m, day = 1, hour = 0, min = 0, sec = 0 })
end
local function want(k)
	local n = 0
	for _, t in ipairs(times) do if t >= edge(k) then n = n + 1 end end
	return n
end
local c0 = count()
M.PSS_SetOpt("jrnMonths", "global", 13)
local d13 = M.PSS_JrnTrim()
if count() ~= want(13) or c0 - count() < 1 or d13 ~= 0 then return fail("jrnmonths: 13 keeps " .. count() .. " want " .. want(13) .. ", option dropped " .. (c0 - count()) .. ", later trim " .. d13) end
M.PSS_SetOpt("jrnMonths", "global", 1)
M.PSS_JrnTrim()
if count() ~= want(1) then return fail("jrnmonths: 1 keeps " .. count() .. " want " .. want(1)) end

-- jrncorrupt: one damaged segment is set aside, the rest served
reset(true)
for i = 0, 2 do put("jrn.repair", { time = now - (2 - i) * 31 * DAY, ent = 1, copper = 500 + i }) end
T = PSS_WarehouseDB.jrn
local id = T.first or 1
if type(T.seg[id]) ~= "string" then return fail("jrncorrupt: no sealed segment") end
T.seg[id] = T.seg[id]:sub(1, -2) .. (T.seg[id]:sub(-1) == "x" and "y" or "x")
local got2, _, why = rows()
if #got2 ~= 2 or T.seg[id] ~= nil or not T.bad then return fail("jrncorrupt: served " .. #got2 .. " rows, bad=" .. tostring(T.bad)) end

-- jrnreload: an open month of 30 lines is read back in order by a new store object
reset(true)
for i = 1, 30 do put("jrn.taxi", { time = now - 3600 + i, ent = 1, copper = i, from = "A" .. (i % 3), to = "B" }) end
local fresh = M.PSS_Seg("jrn", { db = "PSS_WarehouseDB", key = "jrn", boundary = "month", lines = 500 })
local seen, last = 0, 0
fresh:each(nil, nil, nil, function(body, base)
	for line in body:gmatch("[^\n]+") do
		local r = L.decode(line, base, {}, fresh:dict())
		seen = seen + 1
		if r.copper ~= seen or r.time < last or r.from ~= "A" .. (seen % 3) then return fail("jrnreload: line " .. seen .. " " .. tostring(r.copper) .. tostring(r.from)) end
		last = r.time
	end
end)
if seen ~= 30 then return fail("jrnreload: read " .. seen) end

-- jrnnewer: a store with v above 1 is kept byte for byte
reset(true)
PSS_WarehouseDB.jrn = { v = 2, seg = { "x" }, open = {}, future = "kept" }
local before = tostring(PSS_WarehouseDB.jrn.v) .. #PSS_WarehouseDB.jrn.seg .. #PSS_WarehouseDB.jrn.open .. PSS_WarehouseDB.jrn.future
put("jrn.repair", { time = now, ent = 1, copper = 1 })
M.PSS_JrnTrim()
local J = PSS_WarehouseDB.jrn
if tostring(J.v) .. #J.seg .. #J.open .. J.future ~= before or J.seq ~= nil or J.dict ~= nil then return fail("jrnnewer: a newer store changed") end

-- jrnoff: with the Journal off nothing is opened, even for a line that waited in the hot buffer
reset(true)
M.PSS_IxPut("jrn", "jrn.repair", { time = now, ent = 1, copper = 9 })
PSS_WarehouseDB.jrn = nil
on = false
local offBefore = M.PSS_IxStats.off
if M.PSS_IxPut("jrn", "jrn.repair", { time = now, ent = 1, copper = 9 }) then return fail("jrnoff: put accepted") end
M.PSS_IxFlush("jrn")
M.PSS_JrnTrim()
if M.PSS_IxStats.off ~= offBefore + 1 or PSS_WarehouseDB.jrn ~= nil then return fail("jrnoff: the store was opened") end
if #rows() ~= 0 then return fail("jrnoff: rows served") end

-- jrnpost: 2,000 lines, 40 items; item postings give the same rows and read fewer segments
reset(true)
for i = 0, 1999 do
	put("jrn.sold", { time = now - 130000 + i * 60, ent = 1, item = 1000 + math.floor(i / 50), count = 1, value = i })
end
rows({ item = { [1017] = true } })		-- builds the postings
local decodes = 0
local realDecode = L.decode
L.decode = function(...) decodes = decodes + 1 return realDecode(...) end
local item = 1017
local viaPost = rows({ item = { [item] = true } })
local withPost = decodes
decodes = 0
local viaScan = {}
for _, r in ipairs(rows({})) do if r.item == item then viaScan[#viaScan + 1] = r end end
local withoutPost = decodes
L.decode = realDecode
if #viaPost ~= 50 or #viaScan ~= 50 then return fail("jrnpost: rows " .. #viaPost .. " vs " .. #viaScan) end
if withPost >= withoutPost then return fail("jrnpost: postings read " .. withPost .. " lines, a scan " .. withoutPost) end
-- a line written after the postings were built is found
put("jrn.sold", { time = now, ent = 1, item = item, count = 1, value = 7 })
if #rows({ item = { [item] = true } }) ~= 51 then return fail("jrnpost: stale postings") end

on = false
M.PSS_On = realOn
print("PASS index " .. flv)
