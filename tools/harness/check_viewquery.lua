-- The new window's Libraries maths (3.4.0, PSS_DetailQuery.lua and
-- PSS_ViewNav.lua), as a run.lua script on any save, real ones included;
-- changes nothing that is saved. The pane numbers equal the core's counts
-- the port shows (History.RecentCounts, History.RecentByCat,
-- M.PSS_ListTotals) for every listed player, guild and chat filter, with
-- every type ticked and with one unticked; the period and type slices add up; back / forward,
-- double-click, the redraw throttle and the override cycle behave.
local fails = 0
local function check(ok, msg) if not ok then print("  FAIL viewquery: " .. msg); fails = fails + 1 end end

check(M.PSS_Need("Libraries"), "Libraries did not load")
local History = M.PSS_History

-- One pane: this session / last 24 hours / all time equal the core's
-- counts, with every type ticked and with one type unticked (the ticked
-- types only, from the core's counts by type).
local cat = History.ALL_CATS and History.ALL_CATS[1]
local panes = { players = 0, guilds = 0, filters = 0 }

local function CheckPane(kind, label, key, counts)
	panes[kind] = panes[kind] + 1
	local total = counts and counts.total or 0
	local s, d = History.RecentCounts(key)
	local v = M.PSS_SummaryValues({ owner = key, allTime = total }, {})
	check(v.session == (s or 0) and v.day == (d or 0) and v.all == total,
		("%s %s: %d/%d/%d, core %d/%d/%d"):format(kind, label, v.session, v.day, v.all, s or 0, d or 0, total))
	local t = M.PSS_SummaryValues({ owner = key, allTime = total, counts = counts }, {})
	check(t.session == v.session and t.day == v.day and t.all == v.all, kind .. " " .. label .. ": typed differs with every type ticked")
	if cat and History.RecentByCat then
		M.PSS_SetTypeOff(cat, true)
		local by = History.RecentByCat(key, { session = {}, day = {} })
		local ws, wd, wa = 0, 0, 0
		for _, c in ipairs(History.ALL_CATS) do
			if c ~= cat then
				ws = ws + (by.session[c] or 0)
				wd = wd + (by.day[c] or 0)
				wa = wa + (tonumber(counts and counts[c]) or 0)
			end
		end
		local u = M.PSS_SummaryValues({ owner = key, allTime = total, counts = counts }, {})
		check(u.session == ws and u.day == wd and u.all == wa, kind .. " " .. label .. ": unticked type still counted")
		M.PSS_SetTypeOff(cat, false)
	end
end

-- every listed player, guild and chat filter
local row = {}
for i = 1, M.PSS_PlayerCount() do
	local r = M.PSS_PlayerRow(i, row)
	if r and r.entry then CheckPane("players", r.entry, M.PSS_PlayerHistoryKey(r.entry), M.PSS_GetPlayerBlockCounts(r.entry)) end
end
for gkey in pairs(PourSocialScoreDB.guildData or {}) do
	CheckPane("guilds", tostring(gkey), History.GuildKey(gkey), M.PSS_GetGuildBlockCounts(gkey))
end
for i = 1, #(PourSocialScoreDB.filterList or {}) do
	CheckPane("filters", "#" .. i, M.PSS_FilterOwnerKey(i), M.PSS_FilterCounts(i))
end
check(not M.PSS_AnyTypeOff() and M.PSS_TypesOn() == nil, "type tick not cleared")
if cat then
	M.PSS_SetTypeOff(cat, true)
	check(M.PSS_AnyTypeOff() and M.PSS_TypesOn() and not M.PSS_TypesOn()[cat], "type tick state")
	M.PSS_SetTypeOff(cat, false)
end

-- whole lists: the core's totals
for _, kind in ipairs({ "players", "guilds", "filters" }) do
	local want = M.PSS_ListTotals(kind, {})
	local got = M.PSS_TotalsView(kind, {})
	check(got.total == (want.total or 0) and got.recent.session == want.session and got.recent.day == want.day,
		kind .. " totals differ from M.PSS_ListTotals")
	local v = M.PSS_SummaryValues({ recent = got.recent, allTime = got.total }, {})
	check(v.session == want.session and v.day == want.day and v.all == (want.total or 0), kind .. " totals pie differs")
	-- the type slices hold each type's count
	local slices = {}
	local n = M.PSS_TypeSlices(got.counts, slices)
	for i = 1, n do check(slices[i].value == got.counts[slices[i].cat], kind .. " type slice " .. i) end
end

-- period slices: nested, each drawing only what the smaller does not hold
M.PSS_SetPeriodOn("all", true)
local slices, map, pool = {}, {}, {}
local n = M.PSS_PeriodSlices({ session = 3, day = 10, all = 25 }, slices, map, pool)
check(n == 3 and slices[1].draw == 3 and slices[2].draw == 7 and slices[3].draw == 15, "period slices not nested")
check(slices[3].within[1] and slices[3].within[2] and slices[2].inner == 3, "period slices within / inner")
check(map[1] == "session" and map[3] == "all" and M.PSS_WidestPeriodOn() == nil, "period map / widest")
M.PSS_SetPeriodOn("all", false)
check(M.PSS_PeriodSlices({ session = 3, day = 10, all = 25 }, slices, map, pool) == 2 and M.PSS_WidestPeriodOn() == "day",
	"all time not unticked by default")
check(M.PSS_PeriodTip("X", slices[2], true):find("3 of them also in this session", 1, true) ~= nil, "period tip")

-- back / forward
local nav = M.PSS_NavNew(3)
check(nav:Record(1, nil) and not nav:Record(1, nil), "record the same view twice")
nav:Record(2, "members:A")
nav:Record(4, nil)
check(nav:CanBack() and not nav:CanForward(), "back / forward state")
local st = nav:Back()
check(st.tab == 2 and st.view == "members:A" and nav:CanForward(), "back")
nav:Record(3, nil)
check(not nav:CanForward() and #nav.steps == 3, "a new step drops the forward steps")
nav:Record(4, nil)
check(#nav.steps == 3 and nav.steps[1].tab == 2, "the oldest step is dropped past the cap")
check(nav:BackToOther(4).tab == 3, "Escape from Events returns to the tab before")

-- double-click, throttle, exceptions
local dc = {}
check(not M.PSS_DoubleClick(dc, "a", 10) and M.PSS_DoubleClick(dc, "a", 10.2), "double-click within 0.35 s")
check(not M.PSS_DoubleClick(dc, "a", 11) and not M.PSS_DoubleClick(dc, "a", 11.5), "slow clicks are not a double-click")
check(not M.PSS_DoubleClick(dc, "b", 12) and not M.PSS_DoubleClick(dc, "c", 12.1), "different keys are not a double-click")
local ran = 0
local redraw = M.PSS_Throttle(function() ran = ran + 1 end)
redraw(); redraw(); redraw()
check(ran == 0, "the throttle ran at once")
H.RunTimers()
check(ran == 1, "the throttle did not run once for the burst")
-- what happens to listed players and guilds by default (Dan, 3.4.0.22):
-- no ignore response, no decline messages, duels and trades declined
local want = { ignoreResponse = false, showDeclines = false, declineDuel = true, declineTrade = true }
local nOpts = 0
for _, o in ipairs(M.PSS_OverrideOptions()) do
	nOpts = nOpts + 1
	check(want[o.key] == o.default, "default of " .. o.key)
end
check(nOpts == 4, "exception options " .. nOpts)
-- exceptions: away from the default is stored, back to it removes it; a
-- member's default is its guild's; an Off exception is an exception
local base = M.PSS_Opt("declineDuel") == true
local t = {}
check(M.PSS_ExceptionState(t, "declineDuel") == base and not select(2, M.PSS_ExceptionState(t, "declineDuel")), "a new entry is on the default")
M.PSS_ToggleException(t, "person", "declineDuel")
check(t.opts and t.opts.declineDuel == (not base) and select(2, M.PSS_ExceptionState(t, "declineDuel")), "toggle made no exception")
check(M.PSS_OverrideValue(t, "declineDuel") == (not base), "an exception's value read back")
M.PSS_ToggleException(t, "person", "declineDuel")
check(t.opts == nil or t.opts.declineDuel == nil, "toggle back left an exception")
local gopts = { declineDuel = not base }
local mem = {}
check(M.PSS_ExceptionState(mem, "declineDuel", gopts) == (not base) and not select(2, M.PSS_ExceptionState(mem, "declineDuel", gopts)),
	"a member does not follow its guild")
M.PSS_SetException(mem, "person", "declineDuel", base, gopts)
check(mem.opts and mem.opts.declineDuel == base and select(2, M.PSS_ExceptionState(mem, "declineDuel", gopts)), "a member's own exception")
check(M.PSS_ExceptionText({ key = "declineDuel" }, true):find("(exception)", 1, true) ~= nil, "exception text")
check(M.PSS_CountsText({ total = 5, whisper = 2 }):find("Blocked 5", 1, true) ~= nil, "counts text")

if fails == 0 then print(("PASS viewquery (%d players, %d guilds, %d filters)"):format(panes.players, panes.guilds, panes.filters)) end
