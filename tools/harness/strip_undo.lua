-- Writes a saved file without the upgrade record's undo slot and failure note
-- (one-build plan A13): the undo copy a step leaves is dropped by the next
-- login that has nothing due, so a second login is compared with the first
-- after both are stripped. Everything else is written as it is.
--   lua5.1 tools/harness/strip_undo.lua <in.lua> <out.lua>
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/wow_stub.lua")
local env = {}
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
chunk()
local names = {}
for k in pairs(env) do names[#names + 1] = k end
table.sort(names)
local fh = assert(io.open(arg[2], "w"))
for _, name in ipairs(names) do
	local t = env[name]
	if name == "PourSocialScoreDB" and type(t) == "table" and type(t.upgrade) == "table" then t.upgrade.undo = nil t.upgrade.fail = nil end
	fh:write(name, " = ", H.serialize(t), "\n")
end
fh:close()
