-- Checks the block counts the window shows for the Player Ignore List, Guild
-- Ignore List and Chat Filters against PSS_EXPECT (from make_data.lua). With
-- nothing selected each tab's pane shows its list's totals: this session,
-- the last 24 hours and all time (the period pie), and all time by type
-- (the type pie). From 3.4.0.25 (D2) these are read from the window
-- (PourSocialScore_GUI); this session and the last 24 hours by type, which
-- the window shows only through its pies' ticks, are read from the same
-- counters (History.RecentByCat). The old hourly blockStats table is gone.
--   PSS_PHASE=2 : first login after the upgrade. Session 0, Total = what the
--                 old version showed. Then blocks one more line per tab and
--                 checks that all three periods go up by one.
--   PSS_PHASE=3 : a login more than 24 hours after the old blocks. Session 0,
--                 last 24 hours = only the phase 2 lines, Total unchanged.
local expect = dofile(assert(os.getenv("PSS_EXPECT")))
local phase = tonumber(os.getenv("PSS_PHASE") or "2")
local fails = 0

local lineID = 50000 + phase * 1000
local function chat(event, msg, author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, event, msg, author, "", "", "", "", 0,
		event == "CHAT_MSG_CHANNEL" and 2 or 0, event == "CHAT_MSG_CHANNEL" and "Trade" or "", 0, lineID, nil)
end

local function fail(msg)
	print("  FAIL " .. msg)
	fails = fails + 1
end

local function add(a, b)
	local out = {}
	for k, v in pairs(a) do out[k] = v end
	for k, v in pairs(b) do out[k] = (out[k] or 0) + v end
	return out
end
local ZERO = { total = 0 }

-- the window's tab for each list, and the counters' owner prefix
local TAB = { player = 1, guild = 2, filter = 3 }
local KIND = { player = "players", guild = "guilds", filter = "filters" }
local PREFIX = { player = "p:", guild = "G:", filter = "f:" }

-- this session and the last 24 hours by type, from the counters
local function recent(src)
	local s, d = { total = 0 }, { total = 0 }
	s.total, d.total = M.PSS_History.RecentTotals(PREFIX[src])
	local by = M.PSS_History.RecentByCat(nil, {}, PREFIX[src])
	for cat, n in pairs(by.session) do s[cat] = n end
	for cat, n in pairs(by.day) do d[cat] = n end
	return s, d
end

-- what a tab's pane shows with nothing selected: { session, day, all } and
-- all time by type
local function shown(src)
	local win = _G.PSS_Window
	local tab = win.tabs[TAB[src]]
	tab._scripts.OnClick(tab)
	local tt = win.pages[TAB[src]].pane.totals
	if not tt.frame:IsShown() then fail(src .. ": the totals are not shown") end
	local v = tt.summary.values
	local byType = {}
	for _, k in ipairs(tt.typePie.keys or {}) do
		if k.cat and k.check:IsShown() then byType[k.cat] = tonumber(k.count:GetText()) end
	end
	return { total = v.session }, { total = v.day }, { total = v.all }, byType
end

-- want: total and, for "all", per type ("private" is not one of them)
local function compare(what, got, want, byType)
	for k, n in pairs(want) do
		local g
		if k == "total" then g = got.total
		elseif byType then g = byType[k] or 0
		else g = got[k] or 0 end
		if k ~= "private" and g ~= (tonumber(n) or 0) then
			fail(("%s %s: shows %s, expected %s"):format(what, k, tostring(g), tostring(n)))
		end
	end
end

local function check(label, rowsWant)
	-- opened afresh, as a player would see it
	if _G.PSS_Window and _G.PSS_Window:IsShown() then SlashCmdList["PSS"]("gui") end
	SlashCmdList["PSS"]("gui")
	H.RunTimers()
	for src in pairs(TAB) do
		local s, d, all, byType = shown(src)
		local rs, rd = recent(src)
		local want = rowsWant[src]
		compare(label .. " " .. src .. " session", s, { total = want[1].total })
		compare(label .. " " .. src .. " 24h", d, { total = want[2].total })
		-- (filters: all time by type is the counters' own, checked below;
		-- the old filterWhisperTotal / filterPrivateTotal count differently)
		compare(label .. " " .. src .. " total", all, src == "filter" and { total = want[3].total } or want[3], byType)
		compare(label .. " " .. src .. " session (counters)", rs, want[1])
		compare(label .. " " .. src .. " 24h (counters)", rd, want[2])
		-- every type the pie lists is the list's own all-time count
		local lt = M.PSS_ListTotals(KIND[src], {})
		for cat, n in pairs(byType) do
			if n ~= (lt[cat] or 0) then fail(("%s %s type pie %s: %d, the counter %s"):format(label, src, cat, n, tostring(lt[cat]))) end
		end
	end
	SlashCmdList["PSS"]("gui")
end

local db = PourSocialScoreDB
assert(db.blockStats == nil, "blockStats not pruned by the upgrade")

local newP = { total = 1, whisper = 1 }
local newG = { total = 1, whisper = 1 }
local newF = { total = 1 }
local function only(t, keys)
	local out = {}
	for _, k in ipairs(keys) do out[k] = t[k] end
	return out
end

if phase == 2 then
	-- the last 24 hours as the counters hold them after the upgrade
	M.PSS_Need("Libraries")
	local seed = {}
	for src in pairs(TAB) do seed[src] = only(select(2, recent(src)), { "total", "whisper" }) end
	check("after upgrade", {
		player = { ZERO, seed.player, expect.player },
		guild = { ZERO, seed.guild, expect.guild },
		filter = { ZERO, seed.filter, expect.filter },
	})
	-- one more line for each tab
	assert(chat("CHAT_MSG_WHISPER", "again", "Spammer-Realm"), "player line not blocked")
	assert(chat("CHAT_MSG_WHISPER", "again", "Grunt-Realm"), "guild line not blocked")
	assert(chat("CHAT_MSG_CHANNEL", "buygold again", "Random-Realm"), "filter line not blocked")
	H.RunTimers()
	check("after new blocks", {
		player = { newP, add(seed.player, newP), add(expect.player, newP) },
		guild = { newG, add(seed.guild, newG), add(expect.guild, newG) },
		filter = { newF, add(seed.filter, newF), add(expect.filter, newF) },
	})
else
	check("next day", {
		player = { ZERO, newP, add(expect.player, newP) },
		guild = { ZERO, newG, add(expect.guild, newG) },
		filter = { ZERO, newF, add(expect.filter, newF) },
	})
end

print(fails == 0 and ("PASS phase " .. phase) or ("FAILED phase " .. phase .. ": " .. fails))
if fails > 0 then os.exit(1) end
