-- The unstripped undo guarantee (one-build plan A13; the coordinator's condition):
--   lua5.1 tools/harness/undo_check.lua 1-to-2 <login1.lua> <login2.lua>
--     login 2 differs from login 1 ONLY by the removal of the upgrade record's undo slot
--   lua5.1 tools/harness/undo_check.lua same <login2.lua> <login3.lua>
--     login 3 is byte-identical to login 2 (nothing is stripped)
-- Exit 1 with a line naming the first differing store.
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/wow_stub.lua")
local function load(path, dropUndo)
	local env = {}
	local chunk = assert(loadfile(path))
	setfenv(chunk, env)
	chunk()
	local db = env.PourSocialScoreDB
	if dropUndo and type(db) == "table" and type(db.upgrade) == "table" then db.upgrade.undo = nil end
	local out = {}
	for k, v in pairs(env) do out[k] = H.serialize(v) end
	return out
end
local mode = arg[1]
local a, b = load(arg[2], mode == "1-to-2"), load(arg[3], false)
local bad
for k in pairs(a) do if a[k] ~= b[k] then bad = bad or k end end
for k in pairs(b) do if a[k] ~= b[k] then bad = bad or k end end
if bad then print("FAIL undo " .. mode .. ": " .. arg[2] .. " and " .. arg[3] .. " differ in " .. bad); os.exit(1) end
print("PASS undo " .. mode)
