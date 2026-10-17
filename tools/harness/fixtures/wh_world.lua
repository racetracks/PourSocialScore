-- The warehouse test world (one-build plan, STP-p00): a small account kept
-- by hand, plus the code <-> client mapping and the oracle every warehouse
-- check compares against. A container is named by its registry code
-- (b0..b5 bags, k<tab> bank, r0 reagent bank, w<tab> warband, y0 keyring,
-- e0 equipped, m0 mail, v<page> void, a0 auctions, t<tab> guild tab); its
-- rows are { id, count, link?, key?, bound?, hasLoot?, exp? } by slot.
--   local W = dofile("tools/harness/fixtures/wh_world.lua")
--   W.world()                      the account (chars, guilds, warband)
--   W.apply(H, char, client)       seeds the stub as that character
--   W.oracle(world).sum(key)       totals by holder kind
local F = {}

-- item pool: plain items, variants (bonus ids), a pet, a keystone, an uncached item
F.items = {
	[6948] = { name = "Hearthstone", quality = 1, price = 0, icon = 134414 },
	[2589] = { name = "Linen Cloth", quality = 1, price = 13, icon = 132889, stack = 200, class = 7, sub = 5 },
	[2592] = { name = "Wool Cloth", quality = 1, price = 41, icon = 132889, stack = 200, class = 7 },
	[4306] = { name = "Silk Cloth", quality = 1, price = 120, icon = 132889, stack = 200, class = 7 },
	[207791] = { name = "Harbinger's Blade", quality = 4, price = 5600, icon = 135349, equip = "INVTYPE_WEAPON", class = 2, sub = 7, bind = 2, exp = 10, ilvl = 415, collected = false, tip = "Crafted by hand\nEngravable" },
	[210001] = { name = "Weaver's Mantle", quality = 3, price = 2100, icon = 132500, equip = "INVTYPE_SHOULDER", class = 4, sub = 1, bind = 1, exp = 10, ilvl = 372, collected = true, tip = "Woven with Spellthread" },
	[190000] = { name = "Potion of Odd; Name, With.Dots%", quality = 2, price = 900, icon = 134823, class = 0, sub = 1, stack = 20, exp = 9 },
	[82800] = { name = "Pet Cage", quality = 1, price = 0, icon = 132599 },
	[180653] = { name = "Mythic Keystone", quality = 4, price = 0, icon = 525134 },
	[230000] = { name = "Unseen Trinket", quality = 3, price = 7000, icon = 133440, unknown = true, class = 4 },
	[3371] = { name = "Crystal Vial", quality = 1, price = 4, icon = 134828, class = 0 },
	[6265] = { name = "Soul Shard", quality = 1, price = 0, icon = 134075 },
	[5512] = { name = "Healthstone", quality = 1, price = 0, icon = 538745 },
}

-- id, link, expected key for every variant (the real field order of an item link:
-- id, enchant, 4 gems, suffix, unique id, level, spec, modifiers mask, context, number of bonus ids, bonus ids)
local function iv(id, bonus, lvl, spec)
	local f = { "", "", "", "", "", "", "", tostring(lvl or 80), tostring(spec or 0), "", "", tostring(#bonus) }
	for _, b in ipairs(bonus) do f[#f + 1] = tostring(b) end
	local link = ("|cffa335ee|Hitem:%d:%s|h[%s]|h|r"):format(id, table.concat(f, ":"), F.items[id].name)
	local key = ("%d:0:0:0:0:0:0:%s"):format(id, table.concat(bonus, ":"))
	return { id = id, link = link, key = key }
end
F.V = {
	blade_a = iv(207791, { 6652, 1540 }),
	blade_b = iv(207791, { 6652, 1550 }, 70, 66),
	mantle = iv(210001, { 7881 }),
	pet = { id = 82800, link = "|cff0070dd|Hbattlepet:1234:25:3:1500:300:300:0000000000000000|h[Pet Cage]|h|r", key = "p:1234:25:3" },
	keystone = { id = 180653, link = "|cffa335ee|Hkeystone:180653:375:10:9:0:0:0|h[Keystone: Spires]|h|r", key = "k:375:10" },
}

local C = F.V
local function r(id, count, extra) local t = { id = id, count = count }; for k, v in pairs(extra or {}) do t[k] = v end return t end
local function v(var, count, extra) local t = { id = var.id, count = count, link = var.link, key = var.key }; for k, x in pairs(extra or {}) do t[k] = x end return t end

function F.world()
	local w = { chars = {}, guilds = {}, warband = {} }
	w.chars[1] = { name = "Alpha", realm = "Realm", faction = "Alliance", class = "MAGE", race = "Human", sex = 2, guild = "Guild One",
		money = 12345678, bagSizes = { b0 = 16, b1 = 18, b2 = 20, b3 = 0, b4 = 0, b5 = 12 },
		cont = {
			b0 = { [1] = r(2589, 120), [2] = r(2589, 80), [5] = v(C.blade_a, 1, { bound = true }), [9] = r(6948, 1) },
			b1 = { [3] = r(190000, 5), [4] = v(C.pet, 1) },
			b2 = { [1] = r(4306, 20), [7] = v(C.keystone, 1) },
			b5 = { [2] = r(2592, 200) },
			k1 = { [1] = r(2589, 200), [2] = v(C.blade_b, 1), [30] = r(230000, 1) },
			k2 = { [4] = r(190000, 12) },
			e0 = { [16] = v(C.blade_a, 1, { bound = true }), [3] = v(C.mantle, 1, { bound = true }) },
			m0 = { [1] = r(3371, 3, { exp = 1790000000 + 20 * 86400 }), [17] = r(5512, 1, { exp = 1790000000 - 86400 }) },
			a0 = { [1] = r(2592, 40, { exp = 1790000000 + 3600 }), [2] = r(190000, 2, { exp = 1790000000 - 60 }) },
		},
		bankTabs = { { name = "Mats", icon = 133784 }, { name = "Gear; spare", icon = 133785 } },
		currencies = { { id = 1792, name = "Honor", quantity = 350, icon = 1 }, { id = 2003, name = "Dragon Isles Supplies", quantity = 12, icon = 2 },
			{ id = 2032, name = "Trader's Tender", quantity = 77, icon = 3, shared = true } } }
	w.chars[2] = { name = "Bravo", realm = "Realm", faction = "Alliance", class = "WARRIOR", race = "Dwarf", sex = 2, guild = "Guild One",
		money = 500000, bagSizes = { b0 = 16, b1 = 14 },
		cont = { b0 = { [1] = r(2589, 60), [2] = r(6265, 3) }, b1 = { [1] = v(C.mantle, 1, { bound = true }) }, k1 = { [1] = r(2592, 100) },
			e0 = { [16] = v(C.blade_b, 1, { bound = true }) } },
		bankTabs = { { name = "Bank", icon = 133784 } },
		currencies = { { id = 1792, name = "Honor", quantity = 900, icon = 1 }, { id = 2032, name = "Trader's Tender", quantity = 77, icon = 3, shared = true } } }
	w.chars[3] = { name = "Charlie", realm = "OtherRealm", faction = "Horde", class = "PRIEST", race = "Orc", sex = 3, money = 99,
		bagSizes = { b0 = 16 }, cont = { b0 = { [1] = r(2589, 7), [2] = r(190000, 1) } }, bankTabs = {}, currencies = {} }
	w.chars[4] = { name = "Delta", realm = "ConnectedRealm", faction = "Alliance", class = "ROGUE", race = "Gnome", sex = 2, money = 0,
		bagSizes = { b0 = 16 }, cont = { b0 = { [1] = r(4306, 5) } }, bankTabs = {}, currencies = {} }
	w.chars[5] = { name = "Echo", realm = "ClassicBetaPvP", faction = "Alliance", class = "HUNTER", race = "Human", sex = 2, money = 1000,
		bagSizes = { b0 = 16 }, cont = { b0 = { [1] = r(2589, 9) } }, bankTabs = {}, currencies = {}, surname = "Von Echo" }
	w.chars[6] = { name = "Foxtrot", realm = "Realm", faction = "Horde", class = "DRUID", race = "Tauren", sex = 2, money = 321, hidden = true,
		bagSizes = { b0 = 16 }, cont = { b0 = { [1] = r(2589, 1) } }, bankTabs = {}, currencies = {} }
	w.guilds[1] = { name = "Guild One", realm = "Realm", money = 2000000,
		tabs = { { name = "Raid; mats", icon = 133784, viewable = true, cont = { [1] = r(2589, 400), [2] = v(C.blade_a, 1) } },
			{ name = "Trade%", icon = 133785, viewable = true, cont = { [1] = r(190000, 30) } },
			{ name = "Officers", icon = 133786, viewable = false, cont = {} } } }
	w.guilds[2] = { name = "Guild Two", realm = "OtherRealm", money = 10, tabs = { { name = "Bank", icon = 1, viewable = true, cont = { [1] = r(2592, 9) } } } }
	w.warband = { money = 77777777, tabs = { { name = "Warband", icon = 133784, cont = { [1] = r(2589, 999), [2] = r(4306, 2) } } },
		currencies = { { id = 2032, quantity = 77 } } }
	-- PSS_WH_REALM: the home realm of the world is spelled another way (a spaced realm name, W-7 phase realmspace)
	local home = os.getenv("PSS_WH_REALM")
	if home and home ~= "" then
		for _, c in ipairs(w.chars) do if c.realm == "Realm" then c.realm = home end end
		for _, g in ipairs(w.guilds) do if g.realm == "Realm" then g.realm = home end end
	end
	return w
end

-- the key an oracle uses for a row
local function keyOf(row) return row.key or tostring(row.id) end
F.keyOf = keyOf

-- seed the stub as character `ci` of the world on `client`
function F.apply(H, w, ci, client)
	local c = w.chars[ci]
	local g
	for _, gg in ipairs(w.guilds) do if gg.name == c.guild then g = gg end end
	local spec = { client = client,
		player = { name = c.name, realm = c.realm, faction = c.faction, class = c.class, race = c.race, sex = c.sex, guild = c.guild, guildRealm = g and g.realm },
		money = c.money, accountMoney = w.warband.money, items = {}, bags = {}, equipped = {}, mail = {}, void = {}, auctions = {},
		bankTabs = c.bankTabs, accountTabs = {}, currencies = c.currencies }
	for id, it in pairs(F.items) do spec.items[id] = it end
	for code, rows in pairs(c.cont) do
		local kind, n = code:sub(1, 1), tonumber(code:sub(2))
		if kind == "b" then
			local bag = spec.bags[n] or { size = c.bagSizes[code] or 16 }; spec.bags[n] = bag
			for s, row in pairs(rows) do bag[s] = row end
		elseif kind == "k" then
			local id = (client == "era") and (n == 0 and -1 or 4 + n) or (5 + n)
			local bag = { size = 98 }; spec.bags[id] = bag
			for s, row in pairs(rows) do bag[s] = row end
		elseif kind == "e" then
			for s, row in pairs(rows) do spec.equipped[s] = row end
		elseif kind == "m" then
			local mail = {}
			for s, row in pairs(rows) do
				local mi, ai = math.floor((s - 1) / 16) + 1, (s - 1) % 16 + 1
				mail[mi] = mail[mi] or { sender = "Mailer", subject = "Parcel", items = {}, daysLeft = row.exp and (row.exp - 1790000000) / 86400 or 30 }
				mail[mi].items[ai] = row
			end
			local top = 0
			for i in pairs(mail) do if i > top then top = i end end
			for i = 1, top do spec.mail[i] = mail[i] or { sender = "Mailer", subject = "", items = {} } end
		elseif kind == "a" then
			for s, row in pairs(rows) do spec.auctions[s] = { id = row.id, count = row.count, link = row.link, time = row.exp and (row.exp - 1790000000) or 3600 } end
		end
	end
	if g then
		spec.guildbank = { money = g.money, tabs = {} }
		for i, t in ipairs(g.tabs) do spec.guildbank.tabs[i] = { name = t.name, icon = t.icon, viewable = t.viewable, items = t.cont } end
	end
	H.SeedWorld(spec)
	return spec
end

-- totals by key for a world: { total, by = { [entity] = n }, kinds = { bags = n, ... } }
local KIND = { b = "bags", k = "bank", r = "reagent", w = "warband", y = "bags", e = "equipped", m = "mail", v = "void", a = "auctions", t = "guild" }
function F.oracle(w)
	local o = { rows = {} }
	local function add(ent, code, row)
		local key = keyOf(row)
		local t = o.rows[key]
		if not t then t = { total = 0, by = {}, kinds = {} }; o.rows[key] = t end
		local n = row.count or 1
		t.total = t.total + n
		t.by[ent] = (t.by[ent] or 0) + n
		local k = KIND[code:sub(1, 1)]
		t.kinds[k] = (t.kinds[k] or 0) + n
	end
	for _, c in ipairs(w.chars) do
		for code, rows in pairs(c.cont) do for _, row in pairs(rows) do add("c:" .. c.name .. "-" .. c.realm, code, row) end end
	end
	for _, g in ipairs(w.guilds) do
		for i, t in ipairs(g.tabs) do for _, row in pairs(t.cont) do add("g:" .. g.name .. "-" .. g.realm, "t" .. i, row) end end
	end
	for i, t in ipairs(w.warband.tabs) do for _, row in pairs(t.cont) do add("w:", "w" .. i, row) end end
	function o.sum(key) return o.rows[key] or { total = 0, by = {}, kinds = {} } end
	function o.slots()
		local n = 0
		for _, c in ipairs(w.chars) do for _, rows in pairs(c.cont) do for _ in pairs(rows) do n = n + 1 end end end
		return n
	end
	return o
end

return F
