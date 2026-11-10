-- Search Everywhere timing (TST-00988, specs/search.md#8-timing-harness and #9-thresholds): a run.lua script.
--   PSS_WH_SEED=1 PSS_COMPONENTS=addons,gfx,warehouse,bags PSS_BENCH_LABEL=<client>/<version> lua5.1 tools/harness/run.lua . <save|-> - tools/harness/bench_search.lua
-- Prints seven `CASE <case> <label> k=v ...` lines, three `TERM <client> <version> <term> max_ms= total_ms=` lines
-- (CHK-00232: the longest single run between stub timer yields) and nine `ADMIT <id> yes|no k=v` lines for this save.
-- The stub's clock and frames stand in for the game's: read the difference between two builds, not the absolute numbers.
local PULSE_MS = 1.0		-- PSS_Trig.lua:80
local label = os.getenv("PSS_BENCH_LABEL") or "fresh"
local client, version = label:match("^([^/]+)/(.+)$")
client, version = client or "fresh", version or "-"
local clock = os.clock
local function ms(t0) return (clock() - t0) * 1000 end
local function kbNow() return collectgarbage("count") end

M.PSS_Need("Libraries")
M.PSS_Need("GUI")

local function median(f)
	local v = {}
	for i = 1, 5 do v[i] = f() end
	table.sort(v)
	return v[3]
end
-- one run of f with collection stopped: returns ms, kb
local function measure(f)
	collectgarbage("collect")
	collectgarbage("stop")
	local k0, t0 = kbNow(), clock()
	f()
	local t1, k1 = clock(), kbNow()
	collectgarbage("restart")
	return (t1 - t0) * 1000, k1 - k0
end
local function stepDone(text, cap)
	local worst = 0
	for _ = 1, cap or 2000 do
		if M.PSS_ItemSearchDone(text) then break end
		local t0 = clock()
		local idle = M.PSS_ItemSearchStep()
		local d = ms(t0)
		if d > worst then worst = d end
		if idle then break end
	end
	return worst
end
local function out(case, ...)
	local p = { ... }
	print(("CASE %s %s %s"):format(case, label, table.concat(p, " ")))
end
local function f3(x) return ("%.3f"):format(x) end

local adm = {}

-- holders
M.PSS_IndexDropAll()
local hms, hkb = measure(function() M.PSS_WhHolders:size() end)
local hn = M.PSS_WhHolders:size()
out("holders", "ms=" .. f3(hms), "kb=" .. f3(hkb), "n=" .. hn)
adm.J7 = hms

-- keys
local win = M.PSS_EverywhereShow("")
local msMax, kbMax = 0, 0
for _, t in ipairs({ "e", "ep", "epi", "epic" }) do
	local m, k = measure(function() win.Search(t) end)
	if m > msMax then msMax = m end
	if k > kbMax then kbMax = k end
end
local open = 0
for _, t in ipairs({ "e", "ep", "epi", "epic" }) do
	if M.PSS_ItemSearchDebug(t) and not M.PSS_ItemSearchDone(t) then open = open + 1 end
end
local stepMax = stepDone("epic", 2000)
out("keys", "ms_max=" .. f3(msMax), "kb_max=" .. f3(kbMax), "open=" .. open, "step_max=" .. f3(stepMax))
adm.J2a, adm.J3, adm.J4 = msMax, open, stepMax

-- watch (text "pot": no cache entry yet, so its watchers start empty)
local redraws, per, worstRedraw = 0, 0, 0
local realRedraw = win.list.Redraw
win.list.Redraw = function(...) redraws = redraws + 1; return realRedraw(...) end
win.Search("pot")
for _ = 1, 20 do
	redraws = 0
	M.PSS_ItemSearchStep()
	H.RunTimers(1)
	if redraws > worstRedraw then worstRedraw = redraws end
end
win.list.Redraw = realRedraw
local watches = 0
local e = M.PSS_ItemSearchDebug("pot")
if e and e.watch then for _ in pairs(e.watch) do watches = watches + 1 end end
out("watch", "watches=" .. watches, "redraws=" .. worstRedraw)
adm.J1w, adm.J1r = watches, worstRedraw

-- rows
stepDone("epic", 2000)
local calls = 0
local function wrap(name)
	local f = M[name]
	if not f then return function() end end
	M[name] = function(...) calls = calls + 1; return f(...) end
	return function() M[name] = f end
end
local un1, un2 = wrap("PSS_CallSet"), wrap("PSS_WhHolderList")
M.PSS_WhSearchRows("e")
un1(); un2()
local rms = median(function() return (measure(function() M.PSS_WhSearchRows("e") end)) end)
local _, rkb = measure(function() M.PSS_WhSearchRows("e") end)
win.search:SetText("epic")
local refms = measure(function() win.Refresh() end)
out("rows", "ms=" .. f3(rms), "kb=" .. f3(rkb), "bus=" .. calls, "refresh_ms=" .. f3(refms))
adm.J2b, adm.J5 = rms, refms

-- restale
local rsms = measure(function()
	M.Events.Fire("WH_CHANGED", { n = 0 })
	M.PSS_WhSearchRows("epic")
	stepDone("epic", 2000)
end)
out("restale", "ms=" .. f3(rsms))
adm.J6 = rsms

-- mine
local mms = median(function() return (measure(function() M.PSS_WhMineRows() end)) end)
local _, mkb = measure(function() M.PSS_WhMineRows() end)
out("mine", "ms=" .. f3(mms), "kb=" .. f3(mkb))
adm.J8 = mms

-- spyglass: the model PSS_QueryView.lua builds (PSS_QueryView.lua:119-127), query text "inv"
local vm = M.PSS_QueryViewModel({})
vm:SetQuery("inv")
local sms, skb = measure(function() vm:Run(false) end)
out("spyglass", "ms=" .. f3(sms), "kb=" .. f3(skb), "rows=" .. tostring(vm.set and vm.set.n or 0))

-- TERM (CHK-00232): the longest single run between stub timer yields, per term
for _, t in ipairs({ "a", "ar", "ore" }) do
	local worst, total = 0, 0
	local t0 = clock()
	win.Search(t)
	local d = ms(t0)
	worst, total = d, d
	for _ = 1, 3000 do
		if M.PSS_ItemSearchDone(t) then break end
		local t1 = clock()
		H.RunTimers(1)
		local idle = true
		if not M.PSS_ItemSearchDone(t) then
			-- no timer was queued: take the slice the engine would
			idle = M.PSS_ItemSearchStep()
		end
		d = ms(t1)
		total = total + d
		if d > worst then worst = d end
		if idle and not M.PSS_ItemSearchDone(t) then break end
	end
	print(("TERM %s %s %s max_ms=%.3f total_ms=%.3f"):format(client, version, t, worst, total))
end

-- TYPED (CHK-00232, brief Q01 step 5): a cold item cache, typed through the box as in game; items load 20 per slice
do
	local was, queue = {}, {}
	for id, it in pairs(H.items) do was[id] = it.unknown; it.unknown = true end
	local realReq = C_Item.RequestLoadItemDataByID
	C_Item.RequestLoadItemDataByID = function(id) queue[#queue + 1] = id end
	local refreshes, loads = 0, 0
	local realRefresh = win.Refresh
	win.Refresh = function(...) refreshes = refreshes + 1; return realRefresh(...) end
	local worst, total = 0, 0
	local function slice(pre)
		local t0 = clock()
		if pre then pre() end
		for _ = 1, 20 do
			local id = table.remove(queue, 1)
			if not id then break end
			if H.items[id] then H.items[id].unknown = nil end
			loads = loads + 1
			H.Fire("ITEM_DATA_LOAD_RESULT", id, true)
		end
		H.RunTimers(1)
		if not M.PSS_ItemSearchDone(win.search:GetText()) then M.PSS_ItemSearchStep() end
		local d = ms(t0)
		total = total + d
		if d > worst then worst = d end
	end
	slice(function() win.search:SetText("a") end)
	for _ = 1, 2 do slice() end
	slice(function() win.search:SetText("ar") end)
	for _ = 1, 2 do slice() end
	slice(function() win.search:SetText("are") end)
	for _ = 1, 3000 do
		if M.PSS_ItemSearchDone("are") and #queue == 0 then break end
		slice()
	end
	print(("TYPED %s %s a/ar/are max_ms=%.3f total_ms=%.3f loads=%d refreshes=%d"):format(client, version, worst, total, loads, refreshes))
	win.Refresh = realRefresh
	C_Item.RequestLoadItemDataByID = realReq
	for id, it in pairs(H.items) do it.unknown = was[id] end
end

local function yn(v, lim) return v > lim and "yes" or "no" end
print(("ADMIT J1 %s watches=%d redraws=%d"):format((adm.J1w > 1 or adm.J1r > 1) and "yes" or "no", adm.J1w, adm.J1r))
print(("ADMIT J2a %s ms_max=%s"):format(yn(adm.J2a, PULSE_MS), f3(adm.J2a)))
print(("ADMIT J2b %s ms=%s"):format(yn(adm.J2b, PULSE_MS), f3(adm.J2b)))
print(("ADMIT J3 %s open=%d"):format(yn(adm.J3, 1), adm.J3))
print(("ADMIT J4 %s step_max=%s"):format(yn(adm.J4, PULSE_MS), f3(adm.J4)))
print(("ADMIT J5 %s refresh_ms=%s"):format(yn(adm.J5, PULSE_MS), f3(adm.J5)))
print(("ADMIT J6 %s ms=%s"):format(yn(adm.J6, PULSE_MS), f3(adm.J6)))
print(("ADMIT J7 %s ms=%s"):format(yn(adm.J7, PULSE_MS), f3(adm.J7)))
print(("ADMIT J8 %s ms=%s"):format(yn(adm.J8, PULSE_MS), f3(adm.J8)))
