-- A stand-in for the Syndicator addon (harness only): the API table with data from the warehouse
-- test world, so the import and the "Syndicator is loaded" checks have something to read.
-- Not Syndicator's code: shapes only, written from the documented API.
local world = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$") or ".") .. "/../wh_world.lua")
local w = world.world()
Syndicator = { API = {}, Constants = {}, SYN_STUB = true }
local function name(c) return c.name .. "-" .. c.realm end
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
			return { details = { character = c.name, realm = c.realm, faction = c.faction, className = c.class, guild = c.guild }, money = c.money, cont = c.cont }
		end
	end
end
function Syndicator.API.GetAllGuilds()
	local out = {}
	for i, g in ipairs(w.guilds) do out[i] = g.name .. "-" .. g.realm end
	return out
end
function Syndicator.API.GetGuild(n)
	for _, g in ipairs(w.guilds) do if g.name .. "-" .. g.realm == n then return { details = { guild = g.name, realm = g.realm }, money = g.money, tabs = g.tabs } end end
end
function Syndicator.API.GetWarband() return { money = w.warband.money, tabs = w.warband.tabs } end
