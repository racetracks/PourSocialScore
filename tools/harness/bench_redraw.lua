-- CPU and garbage per redraw caused by a block, with the tab open (W4,
-- 3.4.1): a run.lua script on any save.
--   lua5.1 tools/harness/run.lua . <save.lua> - tools/harness/bench_redraw.lua
-- Per tab it fires the core's block event (PLAYER_BLOCKED, GUILD_BLOCKS_CHANGED,
-- FILTER_HISTORY_CHANGED), runs the throttle's timer, and reports the mean
-- microseconds and KB of garbage per redraw over N rounds (collection stopped
-- while counting), and the calls into the core per redraw. The stub's frames
-- stand in for the game's, so read the difference between two builds, not
-- the absolute numbers.
local N = tonumber(os.getenv("PSS_BENCH_N") or "") or 200

local calls = {}

local function bench(name, fire)
	for _ = 1, 20 do fire() end
	calls = {}
	collectgarbage("collect")
	collectgarbage("stop")
	local m0, t0 = collectgarbage("count"), os.clock()
	for _ = 1, N do fire() end
	local t1, m1 = os.clock(), collectgarbage("count")
	collectgarbage("restart")
	local c = {}
	for k, v in pairs(calls) do c[#c + 1] = ("%s=%.2f"):format(k:gsub("^PSS_", ""), v / N) end
	table.sort(c)
	print(("bench %-34s %8.1f us  %8.2f KB garbage per redraw  [%s]"):format(name, (t1 - t0) / N * 1e6, (m1 - m0) / N,
		table.concat(c, " ")))
end

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window

-- calls into the core, counted next to the time
for _, k in ipairs({ "PSS_GetGuildBlockCounts", "PSS_GetPlayerBlockCounts", "PSS_ExceptionState", "PSS_ExceptionTip" }) do
	local f = M[k]
	if f then
		M[k] = function(...)
			calls[k] = (calls[k] or 0) + 1
			return f(...)
		end
	end
end

-- Players: three listed players, the first selected
for i = 1, 3 do M.PSS_PlayerAddFromText("Benchplayer" .. i .. "-Area52") end
win.tabs[1]._scripts.OnClick(win.tabs[1])
local pg = win.pages[1]
pg.select(M.PSS_PlayerEntry(1))
bench("players: PLAYER_BLOCKED", function()
	M.Events.Fire("PLAYER_BLOCKED")
	H.RunTimers()
end)

-- Guilds: the guild with the most members selected
win.tabs[2]._scripts.OnClick(win.tabs[2])
local gp = win.pages[2]
-- the stub's list frame is one row tall: give it a screenful (20 rows)
gp.list.scroll:SetHeight(400)
gp.list:Layout()
gp.list:Redraw()
local key, most = nil, -1
-- one of the rows drawn (the first screenful), as a guild is usually on screen
for i = 1, (gp.list.shown or 1) do
	local it = gp.state.rows[i]
	if it and it.g and it.key then
		local n = it.count or 0
		if n > most then key, most = it.key, n end
	end
end
if key then
	gp.select("guild", key)
	print(("bench guild rows drawn: %d"):format(gp.list.shown or 0))
	print(("bench guild selected: %s (%d members)"):format(tostring(key), most))
end
bench("guilds: GUILD_BLOCKS_CHANGED", function()
	M.Events.Fire("GUILD_BLOCKS_CHANGED")
	H.RunTimers()
end)

-- Chat Filters: the first row selected
win.tabs[3]._scripts.OnClick(win.tabs[3])
local fp = win.pages[3]
if fp.select then fp.select(1) end
bench("filters: FILTER_HISTORY_CHANGED", function()
	M.Events.Fire("FILTER_HISTORY_CHANGED", 1)
	H.RunTimers()
end)
