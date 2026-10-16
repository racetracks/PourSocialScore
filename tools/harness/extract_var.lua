-- Prints one saved variable of a saved file as text (sorted, so two files compare with cmp).
--   lua5.1 tools/harness/extract_var.lua <file.lua> <VarName>
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/wow_stub.lua")
local env = {}
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
chunk()
if env[arg[2]] ~= nil then print(H.serialize(env[arg[2]])) end
