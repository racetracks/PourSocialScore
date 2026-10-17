-- Resident KB of each Libraries file as the harness loaded it (run.lua measures every file with loadfile plus
-- collectgarbage("count"), baseline 02 C17; check_ix.lua phase budgetfiles). Prints "KB <file> <kb>".
M.PSS_Need("Libraries")
for file, kb in pairs(H.sizes or {}) do
	local name = file:match("([%w_]+%.lua)$")
	if name then print(string.format("KB %s %.2f", name, kb)) end
end
