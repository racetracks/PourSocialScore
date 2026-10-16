-- Writes a saved file without what the Warehouse adds (one-build plan TST-p159): the PSS_WarehouseDB
-- table, the Warehouse's and the Bag manager's component options, every wh* option and the entity
-- store with the characters it named, so what is left can be compared with a build that has no Warehouse.
--   lua5.1 tools/harness/wh_strip.lua <in.lua> <out.lua> [options]     (options: only the options, to turn the Warehouse off with its data kept)
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/wow_stub.lua")
local env = {}
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
chunk()
local onlyOptions = arg[3] == "options"
if not onlyOptions then env.PSS_WarehouseDB = nil end
for _, holder in ipairs({ "PourSocialScoreDB", "PSS_OptionsDB" }) do
	local t = env[holder]
	if type(t) == "table" then
		t.useWarehouse, t.useBags = nil, nil
		for k in pairs(t) do if type(k) == "string" and k:match("^wh%u") then t[k] = nil end end
		if not onlyOptions then t.ent, t.entN = nil, nil end
	end
end
local names = {}
for k in pairs(env) do names[#names + 1] = k end
table.sort(names)
local fh = assert(io.open(arg[2], "w"))
for _, name in ipairs(names) do fh:write(name, " = ", H.serialize(env[name]), "\n") end
fh:close()
