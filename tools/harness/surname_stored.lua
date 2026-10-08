-- Prints how many members a save stores under a key the shipped lists held
-- as a surname-as-realm name ("First-Last") before the 3.4.1.37 rebuild
-- (N3). Each was counted once with its shipped entry and now counts on its
-- own, so the split check expects membersShown 196 lower, plus this.
-- Usage: lua5.1 surname_stored.lua <pre-N3 data file> <save file>
local REALMS = { classicbetapvp = true, classicbetapvp2 = true }

local addon = {}
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, { PourSocialScore_NS = addon })
chunk()
local d = addon.MANAGED_DATA.olympus
local bad = {}
for _, g in ipairs(d.guilds) do
	for n in g.members:gmatch("[^\n]+") do
		local base, r = n:match("^(.+)%-(%d+)$")
		local realm = d.realms[tonumber(r)]
		if not REALMS[realm:lower()] then bad[(base .. "-" .. realm):lower()] = true end
	end
end

local env = {}
chunk = assert(loadfile(arg[2]))
setfenv(chunk, env)
chunk()
local n = 0
for _, v in pairs(env) do
	if type(v) == "table" and type(v.guildData) == "table" then
		for _, g in pairs(v.guildData) do
			if type(g) == "table" and type(g.members) == "table" then
				for key in pairs(g.members) do
					if type(key) == "string" and bad[key:lower()] then n = n + 1 end
				end
			end
		end
	end
end
print(n)
