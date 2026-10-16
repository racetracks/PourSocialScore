-- Seeded generator of warehouse worlds (one-build plan, STP-p00): the same
-- shape as wh_world.lua, any seed, any size. The same seed gives the same
-- world on every machine (own generator, not math.random).
--   local gen = dofile("tools/harness/fixtures/wh_gen.lua")
--   local world, rng = gen.world(seed, size)   size: "small" | "account" | n characters
local G = {}
local WF = nil
local HERE = debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or "."

function G.rng(seed)
	local x = (seed * 7919 + 17) % 2147483647
	local function nextInt(n)
		x = (x * 1103515245 + 12345) % 2147483648
		return (x % n) + 1
	end
	return nextInt
end

local FACTION = { "Alliance", "Horde" }
local REALMS = { "Realm", "OtherRealm", "ConnectedRealm" }
local CLASSES = { "MAGE", "WARRIOR", "PRIEST", "ROGUE", "HUNTER", "DRUID" }

function G.world(seed, size)
	WF = WF or dofile(HERE .. "/wh_world.lua")
	local rnd = G.rng(seed)
	local nchar = type(size) == "number" and size or size == "account" and 12 or 4
	local perChar = size == "account" and 640 or 40		-- about 7,600 slots for 12 characters
	-- the pool: plain items and the variants of the fixture
	local pool = {}
	for id in pairs(WF.items) do if id ~= 82800 and id ~= 180653 and not WF.items[id].unknown then pool[#pool + 1] = { id = id } end end
	table.sort(pool, function(a, b) return a.id < b.id end)
	for _, k in ipairs({ "blade_a", "blade_b", "mantle", "pet", "keystone" }) do pool[#pool + 1] = WF.V[k] end
	local function row()
		local p = pool[rnd(#pool)]
		local t = { id = p.id, count = rnd(5) == 1 and rnd(200) or 1 }
		if p.link then t.link, t.key = p.link, p.key; t.count = 1 end
		if rnd(4) == 1 then t.bound = true end
		return t
	end
	local w = { chars = {}, guilds = {}, warband = {} }
	local ng = math.max(1, math.floor(nchar / 4))
	for gi = 1, ng do
		local g = { name = "Gen Guild " .. gi, realm = REALMS[(gi - 1) % 3 + 1], money = rnd(100000), tabs = {} }
		for t = 1, 3 do
			local tab = { name = "Tab " .. t, icon = 133784, viewable = t ~= 3, cont = {} }
			for s = 1, rnd(60) do tab.cont[s] = row() end
			g.tabs[t] = tab
		end
		w.guilds[gi] = g
	end
	for ci = 1, nchar do
		local c = { name = "Gen" .. ci, realm = REALMS[(ci - 1) % 3 + 1], faction = FACTION[(ci - 1) % 2 + 1], class = CLASSES[(ci - 1) % 6 + 1],
			race = "Human", sex = 2, money = rnd(10000000), bagSizes = {}, cont = {}, bankTabs = {}, currencies = {} }
		if rnd(2) == 1 then c.guild = w.guilds[(ci - 1) % ng + 1].name end
		local left = perChar
		local function fill(code, size, maxFill)
			c.bagSizes[code] = size
			local rows = {}
			local n = math.min(size, maxFill, left)
			for s = 1, size do if n > 0 and rnd(size) <= n then rows[s] = row(); n = n - 1; left = left - 1 end end
			c.cont[code] = rows
		end
		for b = 0, 4 do fill("b" .. b, b == 0 and 16 or 20, 20) end
		fill("b5", 18, 12)
		if size == "account" or rnd(2) == 1 then
			for t = 1, (size == "account" and 6 or rnd(3)) do
				c.bankTabs[t] = { name = "T" .. t, icon = 133784 }
				fill("k" .. t, 98, size == "account" and 90 or 12)
			end
		end
		c.cont.e0 = {}
		for s = 1, rnd(6) do c.cont.e0[s] = row() end
		c.cont.m0 = {}
		for s = 1, rnd(4) do local rw = row(); rw.exp = 1790000000 + rnd(30) * 86400; c.cont.m0[(rnd(10) - 1) * 16 + 1 + s % 16] = rw end
		c.cont.a0 = {}
		for s = 1, rnd(3) do local rw = row(); rw.exp = 1790000000 + rnd(48) * 3600; c.cont.a0[s] = rw end
		for i = 1, rnd(4) do c.currencies[i] = { id = 1000 + i, name = "Cur" .. i, quantity = rnd(5000), icon = 1 } end
		w.chars[ci] = c
	end
	w.warband = { money = rnd(1000000000), tabs = { { name = "WB", icon = 1, cont = {} } }, currencies = {} }
	for s = 1, rnd(80) do w.warband.tabs[1].cont[s] = row() end
	return w, rnd
end

return G
