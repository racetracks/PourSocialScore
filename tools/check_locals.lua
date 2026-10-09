-- check_locals.lua
-- Every addon file that uses M (the shared table, addon.M) declares it as a
-- local first: there is no global M in the game. (3.4.1.47: a window file
-- without it passed the harness, which had a global M, and broke in game.)
-- Run by tools/check_rules.sh from the repo root (Lua 5.1).
local segments = dofile((arg[0]:match("^(.*[/\\])") or "") .. "lua_segments.lua")

local problems = 0
local p = io.popen("ls PourSocialScore*/*.lua")
for path in p:lines() do
	local fh = assert(io.open(path, "rb"))
	local src = fh:read("*a")
	fh:close()
	local code = {}
	for _, seg in ipairs(segments(src)) do
		if seg.kind == "code" then code[#code + 1] = seg.text end
	end
	code = table.concat(code, " ")
	local uses = code:find("%f[%w_%.]M[%.%[]")
	local declared = code:find("local%s+M%s*=") or code:find("local%s+[%w_,%s]*%f[%w_]M%f[^%w_][%w_,%s]*=")
	if uses and not declared then
		print(path .. ": uses M without a local M (there is no global M in the game)")
		problems = problems + 1
	end
end
p:close()
os.exit(problems == 0 and 0 or 1)
