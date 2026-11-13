-- Journal monitor fuzz (build J2X): the FX-day events in 1,000 seeded orders with duplicates; the lines equal
-- expect, or M.PSS_JrnUnmatched grew; never a different copper value. Fails until the monitors exist (J2A, J2B).
local M = PourSocialScore_NS.M
local function fail(w) print("FAIL jrn: fuzz: " .. w) end
local here = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local fx = dofile(here .. "/fixtures/jrn_day.lua")
local unpack = unpack
local VAL = { sold = 5, post = 5, vend = 5, repair = 3, mailout = 4, mailin = 4, taxi = 3, train = 3, quest = 4, loot = 3 }
local on = true
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "journal" then return on end return realOn(n) end
local want, total, okVal = {}, 0, {}
for st, list in pairs(fx.expect) do
	if VAL[st] then
		for _, line in ipairs(list) do
			local i, v = 0, nil
			for x in (line .. ","):gmatch("([^,]*),") do
				i = i + 1
				if i == VAL[st] then v = x end
			end
			total = total + 1
			okVal[st .. "|" .. tostring(v)] = true
		end
	end
end
local function rows()
	local out = {}
	M.PSS_Ix("jrn"):scan({}, function(r) out[#out + 1] = { st = r.st, v = r[({ sold = "value", post = "unit", vend = "unit", repair = "copper", mailout = "copper", mailin = "copper", taxi = "copper", train = "copper", quest = "copper", loot = "copper" })[(r.st or ""):gsub("^jrn%.", "")] or "x"] } end, { load = true })
	return out
end
local pool = {}
for _, list in pairs(fx.events) do for _, e in ipairs(list) do pool[#pool + 1] = e end end
table.sort(pool, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.name < b.name end)
for seed = 1, 1000 do
	math.randomseed(seed)
	PSS_WarehouseDB = PSS_WarehouseDB or {}
	PSS_WarehouseDB.jrn = nil
	if M.PSS_JrnStore then M.PSS_JrnStore:drop() end
	local order = {}
	for i = 1, #pool do order[i] = pool[i] end
	for i = #order, 2, -1 do local j = math.random(i); order[i], order[j] = order[j], order[i] end
	for i = #order, 1, -1 do if math.random(4) == 1 then table.insert(order, i, order[i]) end end
	local u0 = M.PSS_JrnUnmatched or 0
	for _, e in ipairs(order) do
		if e.kind == "hook" then
			if _G[e.name] then _G[e.name](unpack(e.args)) end
		else
			H.Fire(e.name, unpack(e.args))
		end
	end
	local got = rows()
	for _, r in ipairs(got) do
		local st = (r.st or ""):gsub("^jrn%.", "")
		if VAL[st] and not okVal[st .. "|" .. tostring(r.v)] then return fail("seed " .. seed .. ": copper value " .. tostring(r.v) .. " in " .. st) end
	end
	if #got ~= total and (M.PSS_JrnUnmatched or 0) <= u0 then return fail("seed " .. seed .. ": " .. #got .. " lines, want " .. total .. ", unmatched did not grow") end
end
print("PASS monfuzz " .. M.PSS_FLV.flavour)
