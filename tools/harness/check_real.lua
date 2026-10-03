-- Real save check (validate_all.sh with PSS_REAL_SAVES).
-- As a run.lua script: fails on any Lua error printed to chat.
-- Standalone: lua5.1 check_real.lua <before.lua> <after.lua> checks that two
-- logins kept every rule, member, player, chat filter and block total.
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

if M then
	for _, line in ipairs(H.chat) do
		if line:find("error", 1, true) and line:find("%.lua:%d+") then
			print("FAIL real save: " .. line)
			os.exit(1)
		end
	end
	print(("real save loaded: %d rules, %d players, %d log lines"):format(
		count(PourSocialScoreDB.guildData), count(PourSocialScoreDB.playerData), #(PourSocialScoreDB.blockLog or {})))
	return
end

local function load(path)
	PourSocialScoreDB = nil
	dofile(path)
	local db = PourSocialScoreDB
	local s = { rules = {}, players = {}, filters = {}, total = 0 }
	for k, g in pairs(db.guildData or {}) do s.rules[k] = count(g.members) end
	for k in pairs(db.playerData or {}) do s.players[k] = true end
	for i, f in ipairs(db.filterList or {}) do s.filters[i] = f end
	s.list = #(db.ignoreList or {})
	s.filterTotal = db.filterTotal
	s.countsV1 = db.guildRuleCountsV1	-- 2.0.39 moves guild rule blocks out of the filter total once
	return s
end

local a, b = load(arg[1]), load(arg[2])
local bad = 0
local function fail(msg) bad = bad + 1; print("FAIL real save: " .. msg) end
for k, n in pairs(a.rules) do
	if b.rules[k] == nil then fail("rule lost: " .. k)
	elseif b.rules[k] < n then fail(("rule %s lost members: %d -> %d"):format(k, n, b.rules[k])) end
end
for k in pairs(a.players) do if not b.players[k] then fail("player record lost: " .. k) end end
for i, f in ipairs(a.filters) do if b.filters[i] ~= f then fail("chat filter changed: " .. i) end end
if a.list ~= b.list then fail(("player list size %d -> %d"):format(a.list, b.list)) end
if a.countsV1 and a.filterTotal ~= b.filterTotal then fail("filter total changed") end
if bad == 0 then print("PASS real save") end
os.exit(bad == 0 and 0 or 1)
