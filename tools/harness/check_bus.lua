-- The service bus and its gates (service-bus-helper, stage S1), as a run.lua
-- script. The phase is PSS_PHASE; each prints "PASS bus <phase>" or "FAIL
-- bus: <phase>: <what>". Phases (expected results from DDS-00010 sections 2,
-- 3, 11 and 12, not from the code):
--   sets calls chain errors act budget gui listen gate
local phase = os.getenv("PSS_PHASE") or "sets"
local fail = false
local function check(ok, msg) if not ok then print("FAIL bus: " .. phase .. ": " .. msg) fail = true end return ok end
local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local function libs() check(M.PSS_Need("Libraries"), "Libraries did not load") end

if phase == "sets" then
	libs()
	local s = M.PSS_Set({ "item", "count" })
	check(M.PSS_IsSet(s) and s.n == 0, "a new set is empty")
	M.PSS_SetAdd(s, { 17, 4 }); M.PSS_SetAdd(s, { 31, 1 })
	check(s.n == 2 and s[2][1] == 31, "rows added in order")
	check(M.PSS_SetCol(s, "count") == 2 and M.PSS_SetCol(s, "item") == 1 and M.PSS_SetCol(s, "nope") == nil, "column index")
	check(not M.PSS_IsSet({}) and not M.PSS_IsSet("x") and not M.PSS_IsSet({ cols = {} }), "IsSet refuses non-sets")
	local first = s[1]
	M.PSS_SetClear(s)
	local r2 = M.PSS_SetNext(s)
	check(s.n == 1 and r2 == first, "a cleared set hands its rows back (reuse)")
elseif phase == "calls" then
	libs()
	local seen
	M.PSS_Provide("t.echo", function(input, opts) seen = { input, opts } return input end, { accepts = { "key" }, returns = { "key" } })
	local a = M.PSS_Call("t.echo", "12345")
	local b = M.PSS_Call("t.echo", { key = "12345" })
	local c = M.PSS_Call("t.echo", { cols = { "key" }, n = 1, { "12345" } })
	check(a and b and c and a.n == 1 and b.n == 1 and c.n == 1 and a[1][1] == "12345" and b[1][1] == "12345" and c[1][1] == "12345", "a key, a { key } table and a one-row set are the same call")
	M.PSS_Provide("t.q", function(input) return M.PSS_IsSet(input) and M.PSS_Set({ "x" }) or { cols = { "x" }, n = 1, { input.ent } } end, {})
	local q = M.PSS_Call("t.q", { key = "k", ent = 3 })
	check(q and q[1][1] == 3, "a query table with more than a key is passed as it is")
	M.PSS_Call("t.echo", "x", { reuse = true })
	check(seen and seen[2] and seen[2].reuse == true, "opts reach the service")
	local n1, e1 = M.PSS_Call("no.such", "x")
	check(n1 == nil and type(e1) == "string" and e1:find("no.such", 1, true), "an unknown service returns nil, err")
	M.PSS_Provide("bad name", function() end)
	M.PSS_Provide("x.y", "not a function")
	local names = {}
	local sv = M.PSS_Services()
	for i = 1, sv.n do names[sv[i][1]] = true end
	check(not names["bad name"] and not names["x.y"] and names["t.echo"], "only well-formed services are registered")
	-- a secret value is refused before the service sees it (J7)
	local realSecret = issecretvalue
	_G.issecretvalue = function(v) return v == "SECRET" end
	local called = false
	M.PSS_Provide("t.spy", function() called = true return nil end, {})
	local r, err = M.PSS_Call("t.spy", "SECRET")
	local r2, err2 = M.PSS_Call("t.spy", { key = "SECRET" })
	_G.issecretvalue = realSecret
	check(r == nil and r2 == nil and err and err2 and not called, "a secret key never reaches a service")
	check(select(2, M.PSS_Call("t.spy", "ok")) == nil and called, "a readable key does")
elseif phase == "chain" then
	-- TST-00114: every pair where A's returns cover B's accepts chains
	libs()
	local function item(input)
		local out = M.PSS_Set({ "item", "count" })
		for i = 1, input.n do M.PSS_SetAdd(out, { input[i][1], 3 }) end
		return out
	end
	local function total(input)
		local out = M.PSS_Set({ "total" })
		local t = 0
		local c = M.PSS_SetCol(input, "count")
		for i = 1, input.n do t = t + input[i][c] end
		M.PSS_SetAdd(out, { t })
		return out
	end
	M.PSS_Provide("t.item", item, { accepts = { "key" }, returns = { "item", "count" } })
	M.PSS_Provide("t.total", total, { accepts = { "count" }, returns = { "total" } })
	M.PSS_Provide("t.alone", function() return M.PSS_Set({ "z" }) end, { accepts = { "zz" }, returns = { "z" } })
	local sv = M.PSS_Services()
	local function cols(s) local t = {} for c in s:gmatch("[^,]+") do t[c] = true end return t end
	local chained, pairsRun = {}, 0
	for i = 1, sv.n do
		for j = 1, sv.n do
			local a, b = sv[i], sv[j]
			if a[1] ~= b[1] and a[1]:find("^t%.") and b[1]:find("^t%.") then
				local ret, acc = cols(a[3]), cols(b[2])
				local covers = next(acc) ~= nil
				for c in pairs(acc) do if not ret[c] then covers = false end end
				if covers then
					pairsRun = pairsRun + 1
					local mid = M.PSS_Call(a[1], "7")
					local out = mid and M.PSS_Call(b[1], mid)
					check(M.PSS_IsSet(out), a[1] .. " into " .. b[1] .. " did not return a record set")
					chained[a[1]], chained[b[1]] = true, true
				end
			end
		end
	end
	check(pairsRun == 1 and chained["t.item"] and chained["t.total"], "the one covering pair ran")
	check(not chained["t.alone"], "a service with no partner is found (the check would fail it unless its spec names the alternate)")
	check(M.PSS_Call("t.total", M.PSS_Call("t.item", "7"))[1][1] == 3, "chained values are right")
elseif phase == "errors" then
	-- TST-00117: isolation
	libs()
	local said = {}
	local realMsg = M.ChatMsg
	M.ChatMsg = function(s) said[#said + 1] = s end
	M.PSS_Provide("t.boom", function() error("kaboom") end, {})
	M.PSS_Provide("t.bad", function() return "a string" end, {})
	M.PSS_Provide("t.ok", function() return M.PSS_Set({ "a" }) end, {})
	local r1, e1 = M.PSS_Call("t.boom", "x")
	local r2 = M.PSS_Call("t.boom", "x")
	local r3, e3 = M.PSS_Call("t.bad", "x")
	local r4 = M.PSS_Call("t.ok", "x")
	M.ChatMsg = realMsg
	check(r1 == nil and e1 and e1:find("kaboom", 1, true) and r2 == nil, "an erroring service returns nil, err")
	check(r3 == nil and e3 and e3:find("record set", 1, true), "a service that returns a non-set is an error")
	check(#said == 2, "each failing service reports once (" .. #said .. " lines)")
	check(M.PSS_IsSet(r4), "the next service still works")
	check(M.Events.errors.count >= 3, "failures are counted for /pssguild status")
elseif phase == "act" then
	-- History.Act keeps Drop Cheapest Thing's lines and takes another category
	M.PSS_SetOpt("useLogging", "global", true)
	local H_ = M.PSS_History
	local e1 = H_.Act("DTT_DROP", "1,2,3")
	check(e1 and e1.o == "dtt", "dtt keeps its category: " .. tostring(e1 and e1.o))
	local e2 = H_.Act("WH_SAVED", "bags", "wh", "Warehouse")
	check(e2 and e2.o == "wh", "another category is taken: " .. tostring(e2 and e2.o))
elseif phase == "budget" then
	-- TST-00191 for this stage's files
	local B = dofile(here .. "/bus_budgets.lua")
	local path = "PourSocialScore_Libraries/PSS_Bus.lua"
	local chunk = assert(loadfile(path))
	collectgarbage("collect"); collectgarbage("collect")
	local a = collectgarbage("count")
	chunk()
	collectgarbage("collect"); collectgarbage("collect")
	local kb = collectgarbage("count") - a
	local gate = B.kb["PSS_Bus.lua"].gate
	check(kb <= gate, string.format("PSS_Bus.lua resident %.2f KB over its gate %d KB", kb, gate))
	M.PSS_Provide("t.n", function(i) return i end, {})
	M.PSS_Provide("t.n", function(i) return i end, {})
	local N = 100000
	local t0 = os.clock()
	for i = 1, N do M.PSS_Call("t.n", i) end
	local us = (os.clock() - t0) / N * 1e6
	check(us <= B.us.call.gate, string.format("a bus call %.2f us over its gate %d us", us, B.us.call.gate))
	print(string.format("NOTE bus budget: PSS_Bus.lua %.2f KB (gate %d), a call %.2f us (gate %d)", kb, gate, us, B.us.call.gate))
elseif phase == "gui" then
	-- TST-00194: nothing but the player loads the GUI
	libs()
	local frames = 0
	local realCreate = CreateFrame
	CreateFrame = function(...) frames = frames + 1 return realCreate(...) end
	M.PSS_Provide("t.n", function() return M.PSS_Set({ "a" }) end, {})
	M.PSS_Call("t.n", "x")
	M.PSS_Services()
	for _, ev in ipairs({ "PLAYERS_CHANGED", "GUILDS_CHANGED", "FILTERS_CHANGED", "OPTION_CHANGED", "WHOIS_COOLDOWN", "PLAYER_BLOCKED",
		"GUILD_BLOCKS_CHANGED", "FILTER_HISTORY_CHANGED", "GROUP_WARNING", "ADDONS_CHANGED", "WHOIS_ANSWERED", "GUILD_SCAN_DONE" }) do
		M.Events.Fire(ev, "uiSkin")
	end
	CreateFrame = realCreate
	check(not C_AddOns.IsAddOnLoaded("PourSocialScore_GUI"), "the GUI loaded")
	check(_G.PSS_Window == nil, "a window frame exists")
	check(frames == 0, frames .. " frames made by service calls and notifications")
elseif phase == "listen" then
	-- TST-00196: listens only while shown; a change made while closed shows on open
	libs()
	local live, n = {}, 0
	local reg, unreg = M.Events.Register, M.Events.Unregister
	local gui = false
	M.Events.Register = function(ev, fn)
		local id = reg(ev, fn)
		if gui then live[ev .. id] = ev end
		return id
	end
	M.Events.Unregister = function(ev, id) live[ev .. id] = nil return unreg(ev, id) end
	gui = true
	M.PSS_OpenUI(true)
	gui = false
	local win = _G.PSS_Window
	check(win and win:IsShown(), "the window did not open")
	local art = win.art
	local function count() n = 0 for _ in pairs(live) do n = n + 1 end return n end
	check(count() > 0, "shown: the window listens")
	M.PSS_SetOpt("uiSkin", "global", 1)
	check(art.dark:IsShown() and not art.blizzard:IsShown(), "shown: a look change repaints at once")
	win:Hide()
	check(count() == 0, "closed: " .. count() .. " listeners left")
	M.PSS_SetOpt("uiSkin", "global", 0)
	check(art.dark:IsShown(), "closed: nothing repainted")
	local strata
	win.SetFrameStrata = function(_, x) strata = x end
	win:Show()
	check(art.blizzard:IsShown() and not art.dark:IsShown(), "reopened: the look changed while closed shows at once")
	check(strata == M.PSS_FrameStrataName(), "reopened: the strata is applied")
	win.SetFrameStrata = nil
	win:Hide()
	check(count() == 0, "closed again: no listeners")
elseif phase == "gate" then
	-- TST-00190, TST-00193, TST-00195, TST-00199: the scratch design-proof gate on this checkout
	local scratch = os.getenv("PSS_SCRATCH")
	if not scratch or scratch == "" then
		-- a scratch checkout beside this repo is used when none is named
		local fh = io.open("../Pour-Social-Score_Scratch/.git/HEAD")
		if fh then fh:close() scratch = "../Pour-Social-Score_Scratch" end
	end
	if not scratch or scratch == "" then
		print("NOTE bus gate: PSS_SCRATCH not set, the parity, catalogue and build gate did not run (CI sets it with the SCRATCH_TOKEN secret; a scratch checkout beside this repo is found without it)")
		print("SKIP bus gate")
		os.exit(0)
	end
	local dir = scratch .. "/documents/features/service-bus-helper/08_Operations/design-proof"
	local p = io.popen('cd "' .. dir .. '" && PSS_REPO="' .. os.getenv("PWD") .. '" lua5.1 run_all.lua 2>&1')
	local out = p:read("*a")
	p:close()
	print((out:gsub("\n$", "")))
	check(out:find("GATE %d+ phases, 0 failed, 0 not listed") ~= nil, "the design-proof gate failed")
else
	check(false, "unknown phase " .. phase)
end

if not fail then print("PASS bus " .. phase) end
