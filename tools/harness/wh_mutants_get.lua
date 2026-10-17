-- reads the mutant list for wh_mutants.sh: lua5.1 wh_mutants_get.lua <count | id | phases | file | from | to> [index]
local list = dofile((arg[0]:match("^(.*)/[^/]*$") or ".") .. "/wh_mutants.lua")
local what, i = arg[1], tonumber(arg[2] or "")
if what == "count" then io.write(#list) return end
local m = list[i]
local field = { id = 1, file = 2, from = 3, to = 4, phases = 5 }
io.write(m[field[what]])
