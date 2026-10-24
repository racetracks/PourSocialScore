-- The service bus and its gates (service-bus-helper, stage S1), as a run.lua
-- script. The phase is PSS_PHASE; each prints "PASS bus <phase>" or "FAIL
-- bus: <phase>: <what>". Phases (expected results from DDS-00010 sections 2,
-- 3, 11 and 12, not from the code):
--   sets calls chain errors act budget gui listen store query strict gate
-- (store: TST-00192, query: TST-00115, strict: TST-00204)
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
	if M.PSS_Can("secretValues") then check(r == nil and r2 == nil and err and err2 and not called, "a secret key never reaches a service") end
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
	-- TST-00207: the query steps declare contracts and chain with each other
	local steps = { "q.where", "q.join", "q.by", "q.order", "q.limit" }
	local sv2 = M.PSS_Services()
	local byName = {}
	for i = 1, sv2.n do byName[sv2[i][1]] = sv2[i] end
	for _, name in ipairs(steps) do
		local row = byName[name]
		check(row ~= nil, name .. " is not on the bus")
		if row then
			check(row[2] == "*" or row[2] ~= "", name .. " declares no accepts")
			check(row[3] == "*" or row[3] ~= "", name .. " declares no returns")
		end
	end
	check(byName["q.where"][3] == "*" and byName["q.order"][3] == "*" and byName["q.limit"][3] == "*" and byName["q.join"][3] == "*", "steps whose columns follow their input return *")
	check(byName["q.by"][3] == "total,n", "q.by returns its own columns")
	local fixture = M.PSS_Set({ "item", "count" })
	for i = 1, 6 do M.PSS_SetAdd(fixture, { i, i * 2 }) end
	M.PSS_QueryDict("item", { "name" }, function(id, row, at) row[at] = "n" .. tostring(id) end)
	local opts = { ["q.where"] = { where = { item = { 1, 2, 3, 4 } } }, ["q.join"] = { join = { "item" } }, ["q.by"] = { by = "item" },
		["q.order"] = { order = { "item", "desc" } }, ["q.limit"] = { limit = 3 } }
	local pairsRun = 0
	for _, a in ipairs(steps) do
		for _, b in ipairs(steps) do
			local mid = M.PSS_Call(a, fixture, opts[a])
			local out = mid and M.PSS_Call(b, mid, opts[b])
			check(M.PSS_IsSet(out), a .. " into " .. b .. " did not return a record set")
			pairsRun = pairsRun + 1
		end
	end
	check(pairsRun == 25, "twenty-five query pairs ran, got " .. pairsRun)
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
	local note = {}
	for _, name in ipairs({ "PSS_Err.lua", "PSS_Bus.lua", "PSS_Store.lua", "PSS_Index.lua", "PSS_Query.lua", "PSS_Entity.lua" }) do
		local chunk = assert(loadfile("PourSocialScore_Libraries/" .. name))
		collectgarbage("collect"); collectgarbage("collect")
		local a = collectgarbage("count")
		chunk()
		collectgarbage("collect"); collectgarbage("collect")
		local kb = collectgarbage("count") - a
		local gate = B.kb[name].gate
		check(kb <= gate, string.format("%s resident %.2f KB over its gate %d KB", name, kb, gate))
		note[#note + 1] = string.format("%s %.2f KB (gate %d)", name, kb, gate)
	end
	local fixed = { cols = { "a" }, n = 1, { 1 } }
	M.PSS_Provide("t.n", function() return fixed end, {})
	local N = 100000
	local us = math.huge
	for _ = 1, 3 do		-- the best of three: a loaded machine slows a run, never speeds it up
		local t0 = os.clock()
		for i = 1, N do M.PSS_Call("t.n", i) end
		us = math.min(us, (os.clock() - t0) / N * 1e6)
	end
	check(us <= B.us.call.gate, string.format("a bus call %.2f us over its gate %.1f us", us, B.us.call.gate))
	-- a store read by key (DEC-00192: 3 us)
	local S = M.PSS_Store("tbudget", { key = "tbudget", v = 1, fields = { { "a", "s" }, { "b", "n" } } })
	for i = 1, 1000 do S.Set(i, { a = "x" .. i, b = i }) end
	t0 = os.clock()
	for i = 1, N do S.Get(i % 1000 + 1, "b") end
	local rus = (os.clock() - t0) / N * 1e6
	check(rus <= B.us.read.gate, string.format("a store read %.2f us over its gate %d us", rus, B.us.read.gate))
	PourSocialScoreDB.tbudget = nil
	print(string.format("NOTE bus budget: %s; a call %.2f us (gate %d), a store read %.2f us (gate %d)",
		table.concat(note, ", "), us, B.us.call.gate, rus, B.us.read.gate))
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
elseif phase == "store" then
	-- TST-00192: the key/value store
	libs()
	local db = PourSocialScoreDB
	local S = M.PSS_Store("tstore", { key = "tstore", v = 1, cap = 4, fields = { { "name", "d" }, { "count", "n", 0 }, { "flag", "b", false }, { "note", "s" } } })
	check(db.tstore == nil and S.Get(1, "name") == nil and S.Count() == 0, "a read writes nothing")
	local a = S.Add({ name = "Guild Bank", count = 5 })
	local b = S.Add({ name = "Guild Bank", count = 0, flag = false })
	check(a == 1 and b == 2, "ids count up from 1")
	check(db.tstore.rec[2] == "1", "defaults are not stored: " .. tostring(db.tstore.rec[2]))
	check(db.tstore.rec[1] == "1;5", "trailing empty fields are dropped: " .. tostring(db.tstore.rec[1]))
	check(db.tstore.dict[1] == "Guild Bank" and db.tstore.dict[2] == nil, "a repeated string is saved once")
	check(S.Get(1, "name") == "Guild Bank" and S.Get(1, "count") == 5 and S.Get(2, "count") == 0 and S.Get(2, "flag") == false and S.Get(1, "nope") == nil, "reads give values or the default")
	S.Set(3, { name = "Bank", note = "a;b" })
	check(S.Get(3, "note") == "a,b", "a separator in a string is replaced")
	S.Delete(2)
	local c = S.Add({ count = 9 })
	check(c == 4, "an id is never reused: " .. tostring(c))
	check(S.Add({ count = 2 }) == 5 and S.Count() == 4, "the fourth record fits the cap")
	local d, why = S.Add({ count = 1 })
	check(d == nil and why == "cap" and S.Count() == 4, "the cap refuses the fifth record")
	db.tstore.extra = "kept"
	S.Set(1, { name = "Other", count = 6 })
	check(db.tstore.extra == "kept" and S.Get(1, "name") == "Other", "an unknown key is kept")
	check(db.tstore.dict[1] == "Guild Bank" and db.tstore.dict[3] == "Other", "another string is a new dictionary entry")
	local rows = S.Rows({ "count" }, { n = 2, { 1 }, { 9 } })
	check(M.PSS_IsSet(rows) and rows.n == 1 and rows[1][1] == 1 and rows[1][2] == 6 and M.PSS_SetCol(rows, "id") == 1, "Rows is a record set on id")
	local top = M.PSS_Query({ from = S.Rows({ "count" }), order = { "count", "desc" }, limit = 1 })
	check(top and top.n == 1 and top[1][2] == 9, "rows feed a query")
	db.tstore.v = 2
	check(S.ReadOnly() and S.Set(1, { count = 1 }) == false and S.Add({ count = 1 }) == nil and S.Delete(1) == nil and S.Get(1, "count") == 6, "a newer layout is read only")
	db.tstore.v = 1
	db.tstore = nil
	local big = M.PSS_Store("tbig", { key = "tbig", v = 1, fields = { { "name", "d" }, { "n", "n" }, { "on", "b" } } })
	for i = 1, 10000 do big.Set(i, { name = "Character " .. (i % 12), n = i, on = i % 3 == 0 }) end
	local len = 0
	for _, str in pairs(db.tbig.rec) do len = len + #str end
	local dl = 0
	for _, str in pairs(db.tbig.dict) do dl = dl + #str end
	check(len + dl < 150000, "10,000 records pack small: " .. (len + dl) .. " bytes")
	check(db.tbig.dn == 12, "twelve distinct strings are saved once each")
	db.tbig = nil
elseif phase == "query" then
	-- TST-00115: where, join, by, order, limit against hand-written rows
	libs()
	local function sample()
		local s = M.PSS_Set({ "tent", "item", "cont", "count" })
		M.PSS_SetAdd(s, { 17, 2, "b", 20 }); M.PSS_SetAdd(s, { 17, 5, "k", 4 }); M.PSS_SetAdd(s, { 31, 2, "b", 1 })
		M.PSS_SetAdd(s, { 31, 9, "m", 7 })
		return s
	end
	M.PSS_QueryDict("tent", { "name" }, function(id, dest, at) dest[at] = "E" .. id end)
	local function rowsOf(s) local t = {} for i = 1, s.n do t[i] = table.concat(s[i], ",") end return table.concat(t, "|") end
	local w = M.PSS_Query({ from = sample(), where = { cont = { "b", "k" } } })
	check(w and rowsOf(w) == "17,2,b,20|17,5,k,4|31,2,b,1", "where, a list: " .. tostring(w and rowsOf(w)))
	w = M.PSS_Query({ from = sample(), where = { cont = "b", tent = 17 } })
	check(w and rowsOf(w) == "17,2,b,20", "where, two columns: " .. tostring(w and rowsOf(w)))
	local j = M.PSS_Query({ from = sample(), join = { "tent" }, limit = 1 })
	check(j and j.cols[5] == "tent_name" and j[1][5] == "E17" and j.n == 1, "join adds the dictionary column")
	local g = M.PSS_Query({ from = sample(), by = "tent", sum = "count" })
	check(g and rowsOf(g) == "17,24,2|31,8,2", "by and sum, first-seen order: " .. tostring(g and rowsOf(g)))
	local chain = M.PSS_Query({ from = sample(), where = { cont = { "b", "k" } }, by = "tent", sum = "count", order = { "total", "desc" }, limit = 1 })
	check(chain and rowsOf(chain) == "17,24,2", "the whole chain: " .. tostring(chain and rowsOf(chain)))
	local asc = M.PSS_Query({ from = sample(), order = { "count", "asc" } })
	check(asc and rowsOf(asc) == "31,2,b,1|17,5,k,4|31,9,m,7|17,2,b,20" or asc and asc[1][4] == 1 and asc[4][4] == 20, "order ascending")
	local from = M.PSS_Query({ from = "ent.get", key = 12345 })
	check(from and from.n == 0, "from a service")
	local r1, e1 = M.PSS_Query({ from = sample(), where = { nope = 1 } })
	check(r1 == nil and e1 and e1:find("no column", 1, true), "a bad column is nil, err: " .. tostring(e1))
	local r2, e2 = M.PSS_Query({ from = sample(), join = { "zzz" } })
	check(r2 == nil and e2 and e2:find("no dictionary", 1, true), "a bad dictionary is nil, err")
	local r3, e3 = M.PSS_Query({ from = "no.such" })
	check(r3 == nil and e3 and e3:find("no.such", 1, true), "a missing service is nil, err")
	-- reuse: a warm pool allocates nothing per row
	local big = M.PSS_Set({ "tent", "item", "cont", "count" })
	for i = 1, 10000 do M.PSS_SetAdd(big, { i % 50, i, "b", 1 }) end
	local spec = { from = big, join = { "tent" }, reuse = true }
	local first = M.PSS_Query(spec)
	local row1 = first[1]
	collectgarbage("collect"); collectgarbage("collect")
	local before = collectgarbage("count")
	for _ = 1, 5 do M.PSS_Query(spec) end
	local reused = (collectgarbage("count") - before) / 5
	check(M.PSS_Query(spec)[1] == row1, "reuse hands the same row tables back")
	spec.reuse = nil
	collectgarbage("collect"); collectgarbage("collect")
	before = collectgarbage("count")
	for _ = 1, 5 do M.PSS_Query(spec) end
	local fresh = (collectgarbage("count") - before) / 5
	check(reused < 20 and fresh > 200, string.format("allocation per call: %.1f KB with reuse, %.1f KB without", reused, fresh))
	-- a join on 10,000 rows under its budget
	local B = dofile(here .. "/bus_budgets.lua")
	spec.reuse = true
	local t0 = os.clock()
	for _ = 1, 20 do M.PSS_Query(spec) end
	local ms = (os.clock() - t0) / 20 * 1000
	check(ms <= B.us.join10k.gate / 1000, string.format("a join on 10,000 rows %.2f ms over its gate %d ms", ms, B.us.join10k.gate / 1000))
	print(string.format("NOTE bus query: a join on 10,000 rows %.2f ms (gate %d), %.1f KB allocated per call with reuse", ms, B.us.join10k.gate / 1000, reused))
elseif phase == "strict" then
	-- TST-00204: a SKIP of the scratch gate is not a pass under PSS_GATE_STRICT
	local function gate(strict)
		local p = io.popen("PSS_PHASE=gate PSS_SCRATCH=- " .. (strict and "PSS_GATE_STRICT=1 " or "PSS_GATE_STRICT=0 ") .. 'lua5.1 "' .. here .. '/run.lua" . - - "' .. here .. '/check_bus.lua" 2>&1')
		local out = p:read("*a")
		p:close()
		return out
	end
	local lax, strict = gate(false), gate(true)
	check(lax:find("SKIP bus gate", 1, true) and lax:find("NOTE bus gate", 1, true) and not lax:find("FAIL", 1, true), "without strict mode a missing scratch is a SKIP and a NOTE")
	check(strict:find("FAIL bus: gate", 1, true) and not strict:find("SKIP bus gate", 1, true), "with PSS_GATE_STRICT=1 a missing scratch fails")
elseif phase == "gate" then
	-- TST-00190, TST-00193, TST-00195, TST-00199: the scratch design-proof gate on this checkout
	local scratch = os.getenv("PSS_SCRATCH")
	local strict = os.getenv("PSS_GATE_STRICT") == "1"
	if scratch == "-" then
		scratch = nil		-- none on purpose (the strict-mode test)
	elseif not scratch or scratch == "" then
		-- a scratch checkout beside this repo is used when none is named
		local fh = io.open("../Pour-Social-Score_Scratch/.git/HEAD")
		if fh then fh:close() scratch = "../Pour-Social-Score_Scratch" end
	end
	if not scratch or scratch == "" then
		print("NOTE bus gate: PSS_SCRATCH not set, the parity, catalogue and build gate did not run (CI sets it with the SCRATCH_TOKEN secret; a scratch checkout beside this repo is found without it)")
		if strict then
			check(false, "PSS_GATE_STRICT=1 and no scratch checkout: a SKIP is not a pass")
		else
			print("SKIP bus gate")
			os.exit(0)
		end
	end
	if scratch and scratch ~= "" then
		local dir = scratch .. "/documents/features/service-bus-helper/08_Operations/design-proof"
		local p = io.popen('cd "' .. dir .. '" && PSS_REPO="' .. os.getenv("PWD") .. '" lua5.1 run_all.lua 2>&1')
		local out = p:read("*a")
		p:close()
		print((out:gsub("\n$", "")))
		check(out:find("GATE %d+ phases, 0 failed, 0 not listed") ~= nil, "the design-proof gate failed")
	end
else
	check(false, "unknown phase " .. phase)
end

if not fail then print("PASS bus " .. phase) end
