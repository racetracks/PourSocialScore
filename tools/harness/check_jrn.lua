-- The Journal harness (build J1), as a run.lua script: loads every tools/harness/jrn/<area>.lua sorted by
-- name, or only PSS_JRN_AREA. Each area prints "PASS <area> <flavour>" or "FAIL jrn: <area>: <what>".
-- With no area file it prints "PASS jrn none". Run by jrn_phases.sh on every flavour.
local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local only = os.getenv("PSS_JRN_AREA")
local names = {}
local p = io.popen('ls "' .. here .. '/jrn" 2>/dev/null')
if p then
	for n in p:lines() do
		local a = n:match("^(.*)%.lua$")
		if a and not a:match("_mutants$") and (not only or only == "" or only == a) then names[#names + 1] = a end
	end
	p:close()
end
table.sort(names)
if #names == 0 then
	print("PASS jrn none")
else
	for i = 1, #names do
		local ok, e = xpcall(function() dofile(here .. "/jrn/" .. names[i] .. ".lua") end, debug.traceback)
		if not ok then print("FAIL jrn: " .. names[i] .. ": raised: " .. tostring(e)) end
	end
end
