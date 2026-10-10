-- PSS Drop Cheapest Thing fixtures (made up): item database and bag layout,
-- with the expected order written from the documented rule (DDS-00009
-- section 3), not from any addon's code. Prices in copper. Player level 80
-- in the stub, so "low level" means a required level of 70 or less.
-- quality: 0 poor .. 4 epic. class 0 = consumable (sub 5 food, 1 potion,
-- 7 bandage, 4 scroll), 12 = quest, 15 = other, 2 = weapon.
local items = {
	[101] = { name = "Rag", quality = 0, price = 5 },
	[102] = { name = "Fang", quality = 0, price = 30 },
	[103] = { name = "Tin Cup", quality = 0, price = 12, stack = 20 },
	[104] = { name = "Old Boot", quality = 0, price = 0 },				-- no value
	[105] = { name = "Quest Rag", quality = 0, price = 3, class = 12 },
	[106] = { name = "Worn Cloak", quality = 0, price = 8, bind = 1 },			-- bound by the bag row
	[107] = { name = "Gray Sword", quality = 0, price = 40, class = 2, equip = "INVTYPE_WEAPON" },
	[201] = { name = "Linen", quality = 1, price = 20, stack = 20 },
	[202] = { name = "Green Gem", quality = 2, price = 900 },
	[203] = { name = "Rare Ring", quality = 3, price = 5000 },
	[301] = { name = "Old Bread", quality = 1, price = 4, class = 0, sub = 5, minLevel = 5 },
	[302] = { name = "Minor Potion", quality = 1, price = 6, class = 0, sub = 1, minLevel = 5 },
	[303] = { name = "Linen Bandage", quality = 1, price = 7, class = 0, sub = 7, minLevel = 5 },
	[304] = { name = "Scroll of Might", quality = 1, price = 9, class = 0, sub = 4, minLevel = 5 },
	[305] = { name = "New Bread", quality = 1, price = 2, class = 0, sub = 5, minLevel = 75 },	-- not low level
	[401] = { name = "Hearthstone", quality = 1, price = 0 },
	[501] = { name = "Unknown Thing", quality = 0, price = 1, unknown = true },
}
-- bag 0: slot -> { id, count, bound, noValue }
local bags = {
	[0] = {
		size = 20,
		[1] = { id = 101, count = 3 },		-- 15
		[2] = { id = 102, count = 1 },		-- 30
		[3] = { id = 103, count = 5 },		-- 60
		[4] = { id = 104, count = 1 },		-- no value
		[5] = { id = 105, count = 1 },		-- quest
		[6] = { id = 106, count = 1, bound = true },	-- soulbound, 8
		[7] = { id = 201, count = 10 },		-- quality 1
		[8] = { id = 202, count = 1 },
		[9] = { id = 203, count = 1 },
		[10] = { id = 301, count = 2 },		-- 8
		[11] = { id = 302, count = 1 },		-- 6
		[12] = { id = 303, count = 4 },		-- 28
		[13] = { id = 304, count = 1 },		-- 9
		[14] = { id = 305, count = 1 },
		[15] = { id = 401, count = 1 },
		[16] = { id = 501, count = 1 },
	},
	[1] = { size = 4, [1] = { id = 101, count = 1 } },		-- 5, the cheapest
}
return { items = items, bags = bags }
