-- Resident KB of each Libraries file as the harness loaded it (run.lua measures every file with loadfile plus
-- collectgarbage("count"), baseline 02 C17; check_ix.lua phase budgetfiles). Prints "KB <file> <kb>".
-- O2: pre-grow Lua's string table so no measured file is charged its doubling (kept referenced to the end)
local warm = {}
for i = 1, 40000 do warm[i] = "pssWarm" .. i end
collectgarbage("collect")
print("NOTE ix strtab warm 40000")
M.PSS_Need("Libraries")
for file, kb in pairs(H.sizes or {}) do
	local name = file:match("([%w_]+%.lua)$")
	if name then print(string.format("KB %s %.2f", name, kb)) end
end
if #warm == 0 then print("warm") end
