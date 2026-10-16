-- A stand-in for the Syndicator addon (harness only): the API table with data from the warehouse
-- test world, so the import and the "Syndicator is loaded" checks have something to read.
-- Not Syndicator's code: shapes only, written from its documented API (a character holds bags,
-- bankTabs, mail, auctions, equipped and void as arrays of slots; a slot is a table with itemID,
-- itemCount, itemLink, quality, iconTexture and isBound, an empty slot is an empty table).
local world = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or ".") .. "/../wh_world.lua")
local w = world.world()
Syndicator = { API = {}, Constants = {}, SYN_STUB = true }
local function name(c) return c.name .. "-" .. c.realm end
local function slot(r)
	return { itemID = r.id, itemCount = r.count or 1, itemLink = r.link or ("|cffffffff|Hitem:%d::::::::|h[x]|h|r"):format(r.id), quality = 1, iconTexture = 1, isBound = r.bound == true }
end
local function slots(rows, size)
	local out = {}
	for i = 1, size do out[i] = rows and rows[i] and slot(rows[i]) or {} end
	return out
end
local function listOf(rows)
	local out, top = {}, 0
	for s in pairs(rows or {}) do if s > top then top = s end end
	return slots(rows, top)
end
function Syndicator.API.IsReady() return true end
function Syndicator.API.GetAllCharacters()
	local out = {}
	for i, c in ipairs(w.chars) do out[i] = name(c) end
	return out
end
function Syndicator.API.GetCharacter(n)
	for _, c in ipairs(w.chars) do
		if name(c) == n then
			if c.name == "Boom" then error("character exploded") end
			local t = { details = { character = c.name, realm = c.realm, faction = c.faction, className = c.class, race = c.race, sex = c.sex, guild = c.guild },
				money = c.money, bags = {}, bankTabs = {}, mail = listOf(c.cont.m0), auctions = listOf(c.cont.a0), equipped = listOf(c.cont.e0), void = {} }
			for i = 0, 5 do
				local rows = c.cont["b" .. i]
				if rows or (c.bagSizes or {})["b" .. i] then t.bags[i + 1] = slots(rows, (c.bagSizes or {})["b" .. i] or 16) end
			end
			for code, rows in pairs(c.cont) do
				local k = code:match("^k(%d+)$")
				if k then t.bankTabs[tonumber(k)] = { name = "Tab", iconTexture = 1, slots = slots(rows, 98) } end
			end
			return t
		end
	end
end
function Syndicator.API.GetAllGuilds()
	local out = {}
	for i, g in ipairs(w.guilds) do out[i] = g.name .. "-" .. g.realm end
	return out
end
function Syndicator.API.GetGuild(n)
	for _, g in ipairs(w.guilds) do
		if g.name .. "-" .. g.realm == n then
			local t = { details = { guild = g.name, realm = g.realm }, money = g.money, bank = {} }
			for i, tab in ipairs(g.tabs) do
				if tab.viewable then t.bank[i] = { name = tab.name, iconTexture = tab.icon, slots = slots(tab.cont, 98) } end
			end
			return t
		end
	end
end
function Syndicator.API.GetWarband()
	local t = { money = w.warband.money, bank = {} }
	for i, tab in ipairs(w.warband.tabs) do t.bank[i] = { name = tab.name, iconTexture = tab.icon, slots = slots(tab.cont, 98) } end
	return t
end
