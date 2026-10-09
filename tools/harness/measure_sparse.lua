-- Measured numbers for the sparse records (core uplift S3), as a run.lua
-- script: resident memory after login, and the cost of the accessors that
-- find a record's key and rule. Run with the previous build's tree and with
-- the working tree on the same save (PR numbers: 3.4.0.28 save).
--   lua5.1 tools/harness/run.lua <tree> <save> - tools/harness/measure_sparse.lua
local function kb()
	collectgarbage("collect"); collectgarbage("collect")
	return collectgarbage("count")
end
local base = kb()
local db = PourSocialScoreDB
local n, members = 0, {}
for gkey, g in pairs(db.guildData or {}) do
	for k, m in pairs(g.members or {}) do
		n = n + 1
		members[#members + 1] = { m = m, k = k, g = g }
	end
end
print(("resident after login: %.1f KB (%d stored members)"):format(base, n))

-- first read of every record through the accessors without the key and the
-- rule (what the window does): walks the rules once, fills the weak maps
local before = kb()
local t0 = os.clock()
local sum = 0
for i = 1, #members do
	local m = members[i].m
	sum = sum + #tostring(M.PSS_MemberName(m)) + #tostring(M.PSS_MemberGuildName(m))
end
local first = (os.clock() - t0) * 1000
local after = kb()
print(("first pass over all members: %.2f ms, resident +%.1f KB"):format(first, after - before))
-- later passes: the maps are filled
local t1 = os.clock()
for rep = 1, 20 do
	for i = 1, #members do
		local m = members[i].m
		sum = sum + #tostring(M.PSS_MemberName(m)) + #tostring(M.PSS_MemberGuildName(m))
	end
end
local per = (os.clock() - t1) * 1e6 / (20 * #members * 2)
print(("accessor read: %.3f us each (%d reads)"):format(per, 20 * #members * 2))
-- the same with the key and rule given
local t2 = os.clock()
for rep = 1, 20 do
	for i = 1, #members do
		local e = members[i]
		sum = sum + #tostring(M.PSS_MemberName(e.m, e.k)) + #tostring(M.PSS_MemberGuildName(e.m, e.g))
	end
end
print(("accessor read with key and rule: %.3f us each"):format((os.clock() - t2) * 1e6 / (20 * #members * 2)))
-- what the logout flush costs (sparse records, cap)
local t3 = os.clock()
if M.PSS_FlushManaged then M.PSS_FlushManaged() end
print(("logout flush of the guild members: %.2f ms"):format((os.clock() - t3) * 1000))
