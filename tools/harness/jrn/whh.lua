-- Warehouse history (build J1W): deltas, moves, gold, compaction, cap, gate, reload.
local M = PourSocialScore_NS.M
local function fail(w) print("FAIL jrn: whh: " .. w) end
local DAY = 86400
local base = math.floor(GetServerTime() / DAY) * DAY + 3600

local on = false
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "journal" then return on end return realOn(n) end
PSS_WarehouseDB = PSS_WarehouseDB or {}
local function reset(gate)
	PSS_WarehouseDB.whh = nil
	if M.PSS_WhHistStore then M.PSS_WhHistStore:drop() end
	M.PSS_IxHot("whh", true)
	on = gate
	if gate then M.PSS_WatchStart() end
	M.PSS_SetOpt("jrnMonths", "global", 13)
end
local function set(...)
	local s = { n = 0 }
	for _, r in ipairs({ ... }) do s.n = s.n + 1; s[s.n] = r end
	return s
end
local function rows()
	local out = {}
	M.PSS_Ix("whh"):scan({}, function(r)
		local c = {}
		for k, v in pairs(r) do if k ~= "__f" then c[k] = v end end
		out[#out + 1] = c
	end, { load = true })
	return out
end
local function count(st)
	local n = 0
	for _, r in ipairs(rows()) do if r.st == st then n = n + 1 end end
	return n
end
if not M.PSS_WhHistDelta then return fail("M.PSS_WhHistDelta missing") end
if not M.PSS_Ix("whh") then return fail("index whh not declared") end

-- whhdelta: the net of a window, signed, with the container letter
reset(true)
M.PSS_WhHistDelta(1, "a0", set(), set({ 1, "a0", 1, 100, 5, "" }))
M.PSS_WhHistDelta(1, "a0", set({ 1, "a0", 1, 200, 5, "" }), set({ 1, "a0", 1, 200, 2, "" }))
H.Fire("BAG_UPDATE_DELAYED")
local r = rows()
if #r ~= 2 then return fail("whhdelta: expected 2 lines, got " .. #r) end
local by = {}
for _, x in ipairs(r) do by[x.item] = x end
if not by[100] or by[100].delta ~= 5 or by[100].where ~= "a" or by[100].st ~= "whh.d" then return fail("whhdelta: item 100") end
if not by[200] or by[200].delta ~= -3 then return fail("whhdelta: item 200 delta " .. tostring(by[200] and by[200].delta)) end

-- whhmove: a bank deposit in one window writes nothing, one settle queued
reset(true)
M.PSS_WhHistDelta(1, "a0", set({ 1, "a0", 1, 100, 5, "" }), set())
M.PSS_WhHistDelta(1, "b0", set(), set({ 1, "b0", 1, 100, 5, "" }))
H.Fire("BAG_UPDATE_DELAYED")
if #rows() ~= 0 then return fail("whhmove: a move wrote " .. #rows() .. " lines") end

-- whhgold: the last value of an hour, one line per hour
reset(true)
local clock = GetServerTime
local t0 = math.floor(clock() / 3600) * 3600 + 10
GetServerTime = function() return t0 end
M.PSS_WhHistGold(1, 1000)
GetServerTime = function() return t0 + 600 end
M.PSS_WhHistGold(1, 2000)
if #rows() ~= 0 then GetServerTime = clock return fail("whhgold: a line before the hour ended") end
GetServerTime = function() return t0 + 3700 end
M.PSS_WhHistGold(1, 3000)
GetServerTime = clock
r = rows()
if #r ~= 1 or r[1].st ~= "whh.g" or r[1].copper ~= 2000 then return fail("whhgold: expected one line of 2000, got " .. #r .. " " .. tostring(r[1] and r[1].copper)) end
M.PSS_Call("whh.logout")
if count("whh.g") ~= 2 then return fail("whhgold: logout did not put the open hour") end

-- whhcompact: a closed day's d lines fold to day lines; one g per character stays
reset(true)
local function put(st, rec) M.PSS_IxPut("whh", st, rec) end
put("whh.d", { time = base, ent = 1, item = 100, delta = 5, where = "a" })
put("whh.d", { time = base + 60, ent = 1, item = 100, delta = 3, where = "a" })
put("whh.d", { time = base + 120, ent = 1, item = 200, delta = -2, where = "b" })
put("whh.g", { time = base + 130, ent = 1, copper = 10 })
put("whh.g", { time = base + 7200, ent = 1, copper = 20 })
M.PSS_IxFlush("whh")
put("whh.d", { time = base + DAY, ent = 1, item = 100, delta = 1, where = "a" })
M.PSS_IxFlush("whh")
r = rows()
local d, day, g = 0, {}, {}
for _, x in ipairs(r) do
	if x.st == "whh.d" then d = d + 1 elseif x.st == "whh.day" then day[x.item] = x.net elseif x.st == "whh.g" then g[#g + 1] = x.copper end
end
if d ~= 1 then return fail("whhcompact: d lines left " .. d .. " (the new day's only)") end
if day[100] ~= 8 or day[200] ~= -2 then return fail("whhcompact: day nets " .. tostring(day[100]) .. " " .. tostring(day[200])) end
if #g ~= 1 or g[1] ~= 20 then return fail("whhcompact: g lines " .. #g) end

-- whhcap: months older than jrnMonths go
reset(true)
local now = GetServerTime()
put("whh.d", { time = now - 200 * DAY, ent = 1, item = 100, delta = 1, where = "a" })
M.PSS_IxFlush("whh")
M.PSS_WhHistStore:seal()
put("whh.d", { time = now, ent = 1, item = 100, delta = 2, where = "a" })
M.PSS_IxFlush("whh")
M.PSS_SetOpt("jrnMonths", "global", 1)
M.PSS_WhHistStore:trim()
r = rows()
if #r ~= 1 or r[1].delta ~= 2 then return fail("whhcap: " .. #r .. " lines left") end

-- whhoff: Journal off writes nothing, creates nothing
reset(false)
M.PSS_WhHistDelta(1, "a0", set(), set({ 1, "a0", 1, 100, 5, "" }))
M.PSS_WhHistGold(1, 5)
M.PSS_IxPut("whh", "whh.d", { ent = 1, item = 100, delta = 1, where = "a" })
H.Fire("BAG_UPDATE_DELAYED")
if PSS_WarehouseDB.whh ~= nil or #M.PSS_IxHot("whh") ~= 0 then return fail("whhoff: something was written") end

-- whhreload: sealed lines read the same after the runtime store is dropped
reset(true)
put("whh.d", { time = base, ent = 1, item = 100, delta = 4, where = "a" })
M.PSS_IxFlush("whh")
M.PSS_WhHistStore:seal()
local before = rows()
M.PSS_WhHistStore:drop()
local after = rows()
if #before ~= 1 or #after ~= 1 or after[1].delta ~= 4 or after[1].item ~= 100 then return fail("whhreload: " .. #before .. "/" .. #after) end

reset(false)
M.PSS_On = realOn
print("PASS whh " .. M.PSS_FLV.flavour)
