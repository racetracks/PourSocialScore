-- The warehouse checks (warehouse-helper, one-build plan), as a run.lua
-- script. The phase is PSS_PHASE; each prints "PASS wh <phase>" or "FAIL
-- wh: <phase>: <what>". Run on Retail and on Camelot (PSS_CAMELOT=1) by
-- wh_phases.sh. Expected results come from the plan (03_Design, 05_Tests),
-- not from the code. Phases are added with their packages:
--   stub (TST-p001..p006)  err (TST-p010..p025)  codec (TST-p026..p029, p223)  codecprop (TST-p130..p135)
local phase = os.getenv("PSS_PHASE") or "stub"
local camelot = os.getenv("PSS_CAMELOT") == "1"
local fail = false
local function check(ok, msg) if not ok then print("FAIL wh: " .. phase .. ": " .. msg) fail = true end return ok end
local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local WORLD = dofile(here .. "/fixtures/wh_world.lua")
local GEN = dofile(here .. "/fixtures/wh_gen.lua")
local client = camelot and "camelot" or "retail"
local function libs() check(M.PSS_Need("Libraries"), "Libraries did not load") end

if phase == "stub" then
	-- TST-p001: before SeedWorld the stub offers nothing new
	check(C_Bank == nil and C_CurrencyInfo == nil and TooltipDataProcessor == nil and GetInboxNumItems == nil, "TST-p001: nothing exists before SeedWorld")
	check(type(H.SeedWorld) == "function" and type(H.Interact) == "function", "TST-p001: SeedWorld and Interact exist")
	-- TST-p002: every client API answers the fixture
	local w = WORLD.world()
	WORLD.apply(H, w, 1, client)
	check(UnitName("player") == "Alpha" and GetRealmName() == "Realm" and GetMoney() == 12345678, "TST-p002: identity and money")
	check(C_Container.GetContainerNumSlots(0) == 16 and C_Container.GetContainerItemInfo(0, 1).stackCount == 120, "TST-p002: bag 0 slot 1 holds 120")
	local blade = C_Container.GetContainerItemInfo(0, 5)
	check(blade and blade.itemID == 207791 and blade.hyperlink:find("bonus", 1, true) == nil and blade.hyperlink:find("|Hitem:207791:", 1, true) and blade.isBound, "TST-p002: variant link and bound flag")
	check(C_Item.DoesItemExist({ bagID = 0, slotIndex = 5 }) and C_Item.GetItemID({ bagID = 0, slotIndex = 5 }) == 207791 and not C_Item.DoesItemExist({ bagID = 0, slotIndex = 3 }), "TST-p002: item locations")
	check(GetInventoryItemID("player", 16) == 207791 and GetInventoryItemLink("player", 3):find("210001", 1, true), "TST-p002: equipped")
	check(GetInboxNumItems() == 2 and GetInboxItem(1, 1) == "Crystal Vial" and select(2, GetInboxItem(1, 1)) == 3371 and select(4, GetInboxItem(1, 1)) == 3, "TST-p002: mail attachment")
	check(IsInGuild() and GetGuildInfo("player") == "Guild One" and GetNumGuildBankTabs() == 3 and GetGuildBankMoney() == 2000000, "TST-p002: guild bank")
	check(select(3, GetGuildBankTabInfo(3)) == false and select(3, GetGuildBankTabInfo(1)) == true, "TST-p002: tab 3 is not viewable")
	check(select(2, GetGuildBankItemInfo(1, 1)) == 400, "TST-p002: guild bank slot count")
	check(C_CurrencyInfo.GetCurrencyListSize() == 3 and C_CurrencyInfo.GetCurrencyListInfo(1).quantity == 350, "TST-p002: currencies")
	check(C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)[2].name == "Gear; spare", "TST-p002: bank tab data")
	check(C_Bank.FetchDepositedMoney(Enum.BankType.Account) == 77777777, "TST-p002: warband money")
	check(Enum.BagIndex.CharacterBankTab_1 == 6 and C_Container.GetContainerNumSlots(Enum.BagIndex.CharacterBankTab_1) == 98, "TST-p002: bank tab 1 is a container")
	-- TST-p003: Retail and Camelot differ the way the clients do
	WORLD.apply(H, w, 1, "retail")
	check(C_Bank.FetchBankLockedReason(Enum.BankType.Account) == nil and C_AuctionHouse ~= nil and GetNumAuctionItems == nil and CanUseVoidStorage ~= nil, "TST-p003: retail has warband, modern auctions, void")
	WORLD.apply(H, w, 1, "camelot")
	check(C_Bank.FetchBankLockedReason(Enum.BankType.Account) ~= nil and C_AuctionHouse == nil and GetNumAuctionItems("owner") == 2 and CanUseVoidStorage == nil, "TST-p003: camelot has no warband, legacy auctions, no void")
	check(Enum.BagIndex.ReagentBag == 5 and Enum.BagIndex.Keyring == nil, "TST-p003: camelot has a reagent bag and no keyring")
	WORLD.apply(H, w, 1, "era")
	check(C_Bank == nil and Enum.BagIndex.Keyring == -2 and Enum.BagIndex.Bank == -1 and Enum.BagIndex.CharacterBankTab_1 == nil, "TST-p003: era has the classic bank and a keyring")
	check(C_Container.GetContainerNumSlots(6) == 98, "TST-p003: era bank bag 1 (id 6) holds the world's bank tab 2")
	WORLD.apply(H, w, 1, client)
	-- TST-p004: ITEM_DATA_LOAD_RESULT fires once after the request
	local got = {}
	local f = CreateFrame("Frame")
	f:RegisterEvent("ITEM_DATA_LOAD_RESULT")
	f:SetScript("OnEvent", function(_, e, id, ok) got[#got + 1] = id .. ":" .. tostring(ok) end)
	check(C_Item.IsItemDataCachedByID(230000) == false and C_Item.GetItemInfo(230000) == nil, "TST-p004: the uncached item has no info")
	C_Item.RequestLoadItemDataByID(230000); C_Item.RequestLoadItemDataByID(230000)
	check(#got == 0 and H.PendingItemData() == 1, "TST-p004: a repeated request queues once, nothing fires yet")
	H.LoadItemData()
	check(#got == 1 and got[1] == "230000:true" and C_Item.IsItemDataCachedByID(230000) and C_Item.GetItemInfo(230000) == "Unseen Trinket", "TST-p004: fires once, then cached")
	-- TST-p005: tooltip post calls
	local seen
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data) seen = { tip, data } end)
	H.RunTooltip(Enum.TooltipDataType.Item, "TIP", "DATA")
	check(seen and seen[1] == "TIP" and seen[2] == "DATA", "TST-p005: the post call ran with the tooltip and data")
	-- TST-p006: the generator is deterministic and the oracle counts it
	local a = GEN.world(11, "small")
	local b = GEN.world(11, "small")
	local c = GEN.world(12, "small")
	local function dump(x)
		local parts = {}
		for ci, ch in ipairs(x.chars) do
			local codes = {}
			for code in pairs(ch.cont) do codes[#codes + 1] = code end
			table.sort(codes)
			for _, code in ipairs(codes) do
				local slots = {}
				for s in pairs(ch.cont[code]) do slots[#slots + 1] = s end
				table.sort(slots)
				for _, s in ipairs(slots) do local r = ch.cont[code][s]; parts[#parts + 1] = ci .. code .. s .. ":" .. WORLD.keyOf(r) .. "x" .. (r.count or 1) end
			end
		end
		return table.concat(parts, ",")
	end
	check(dump(a) == dump(b) and dump(a) ~= dump(c), "TST-p006: the same seed gives the same world, another seed another")
	check(#GEN.world(1, "account").chars == 12 and WORLD.oracle(GEN.world(1, "account")).slots() > 4000, "TST-p006: the account-sized world has 12 characters and thousands of slots")
	local o = WORLD.oracle(w)
	check(o.sum("2589").total == 120 + 80 + 200 + 60 + 7 + 9 + 1 + 400 + 999 and o.sum("2589").by["g:Guild One-Realm"] == 400, "TST-p006: the oracle sums plain Linen Cloth over characters, a guild and the warband")
end

if phase == "err" then
	libs()
	local T = M.PSS_Test
	local function rows() return M.PSS_Call("err.rows") end
	local function ringCount(service)
		local r, n = rows(), 0
		for i = 1, r.n do if r[i][2] == service then n = n + r[i][4] end end
		return n
	end
	local said = {}
	local realMsg = M.ChatMsg
	M.ChatMsg = function(str) said[#said + 1] = str end
	local function set1(v) return { cols = { "a" }, n = 1, { v } } end
	local function boom() error("kaboom") end
	-- TST-p010: err.rows
	M.PSS_Provide("t.e0", boom, { returns = { "a" } })
	M.PSS_Call("t.e0", "x")
	local r = rows()
	check(r and r.cols[1] == "code" and r.cols[6] == "last" and #r.cols == 6 and r.n >= 1, "TST-p010: err.rows columns")
	local q = M.PSS_Query({ from = "err.rows", where = { service = "t.e0" } })
	check(q and q.n == 1 and q[1][1] == "fail", "TST-p010: err.rows composes with q.where")
	-- TST-p011: onError = empty
	M.PSS_Provide("t.e1", boom, { returns = { "x", "y" }, onError = "empty" })
	local s1, e1 = M.PSS_Call("t.e1", "k")
	check(s1 and s1.n == 0 and s1.cols[2] == "y" and e1 and e1:find("^fail: ") and e1:find("kaboom", 1, true), "TST-p011: empty set with the declared columns and a fail code")
	-- TST-p012: onError = last, while the source version is unchanged
	local ver, mode = 1, "ok"
	M.PSS_Provide("t.e2", function() if mode == "fail" then error("down") end return set1(ver) end, { returns = { "a" }, onError = "last", ver = function() return ver end })
	local g = M.PSS_Call("t.e2", "k")
	mode = "fail"
	local l, le = M.PSS_Call("t.e2", "k")
	check(l == g and le and le:find("^fail: "), "TST-p012: the last good set while the version is unchanged")
	ver = 2
	local l2 = M.PSS_Call("t.e2", "k")
	check(l2 and l2.n == 0 and l2.cols[1] == "a", "TST-p012: empty after the version changes")
	-- TST-p013: onError = default
	local dflt = set1("dflt")
	M.PSS_Provide("t.e3", boom, { returns = { "a" }, onError = "default", default = dflt })
	check(M.PSS_Call("t.e3", "k") == dflt, "TST-p013: the declared default")
	-- TST-p014: 1,000 failures, showErrors off: no chat line, the ring counts all
	T.loud = false
	said = {}
	M.PSS_Provide("t.e4", boom, { returns = { "a" }, onError = "empty" })
	for _ = 1, 1000 do M.PSS_Call("t.e4", "k") end
	check(#said == 0, "TST-p014: no chat line with showErrors off (" .. #said .. ")")
	check(ringCount("t.e4") == 1000, "TST-p014: the ring counts 1,000 (" .. ringCount("t.e4") .. ")")
	-- TST-p015: showErrors on: one line per service
	M.PSS_SetOpt("showErrors", "global", true)
	said = {}
	M.PSS_Provide("t.e5", boom, { returns = { "a" } })
	for _ = 1, 3 do M.PSS_Call("t.e5", "k") end
	check(#said == 1 and said[1]:find("service t.e5", 1, true), "TST-p015: one line for the service (" .. #said .. ")")
	M.PSS_SetOpt("showErrors", "global", nil)
	-- TST-p016: 51 distinct errors keep 50
	M.PSS_ErrReset()
	for i = 1, 51 do M.PSS_ErrNote("fail", "t.ring", "m" .. i) end
	local rr = rows()
	check(rr.n == 50 and rr[1][3] == "m2" and rr[50][3] == "m51", "TST-p016: 50 kept, the oldest dropped (" .. rr.n .. ")")
	M.PSS_ErrNote("fail", "t.ring", "m51")
	check(rows()[50][4] == 2, "TST-p016: a repeat counts, it does not add a row")
	-- TST-p017: five failures open the breaker; the function is not called
	local calls = 0
	M.PSS_Provide("t.e6", function() calls = calls + 1 error("down") end, { returns = { "a" }, onError = "empty" })
	for _ = 1, 5 do M.PSS_Call("t.e6", "k") end
	local c5 = calls
	local fb = M.PSS_Call("t.e6", "k")
	check(c5 == 5 and calls == 5 and M.PSS_ErrOpen("t.e6") and fb and fb.n == 0, "TST-p017: open after five failures, not called again (" .. calls .. ")")
	-- TST-p018: a settle half-opens, one success closes
	mode2 = "down"
	M.PSS_Provide("t.e7", function() if mode2 == "down" then error("x") end return set1(1) end, { returns = { "a" }, onError = "empty" })
	for _ = 1, 5 do M.PSS_Call("t.e7", "k") end
	check(M.PSS_ErrOpen("t.e7"), "TST-p018: open")
	M.PSS_ErrSettle()
	mode2 = "up"
	local ok7 = M.PSS_Call("t.e7", "k")
	check(ok7 and ok7.n == 1 and not M.PSS_ErrOpen("t.e7") and M.PSS_ErrCount("t.e7") == 0, "TST-p018: one success after the settle closes it")
	-- TST-p019: a secret never counts toward the breaker
	local realSecret = issecretvalue
	_G.issecretvalue = function(v) return v == "SECRET" end
	local sc = 0
	M.PSS_Provide("t.e8", function() sc = sc + 1 return set1(1) end, { returns = { "a" }, onError = "empty" })
	local first, ferr
	for i = 1, 100 do local a, b = M.PSS_Call("t.e8", "SECRET"); if i == 1 then first, ferr = a, b end end
	_G.issecretvalue = realSecret
	check(sc == 0 and not M.PSS_ErrOpen("t.e8") and M.PSS_ErrCount("t.e8") == 0 and ringCount("t.e8") == 100, "TST-p019: refused, never counted toward the breaker")
	check(first and first.n == 0 and ferr and ferr:find("^secret: "), "TST-p019: a secret code and the policy set")
	-- TST-p020, p021: a failed write is retried once after the next settle, out of combat
	local runs, failOnce = 0, true
	M.PSS_Provide("t.w1", function(set) runs = runs + 1 if failOnce then failOnce = false error("busy") end return set end, { returns = { "*" }, retry = 1, writes = true })
	M.PSS_Call("t.w1", set1("w"))
	check(runs == 1, "TST-p020: failed once")
	M.PSS_ErrSettle()
	check(runs == 2, "TST-p020: retried after the settle (" .. runs .. ")")
	M.PSS_ErrSettle()
	check(runs == 2, "TST-p020: only once (" .. runs .. ")")
	failOnce = true
	runs = 0
	H.combat = true
	M.PSS_Call("t.w1", set1("w"))
	M.PSS_ErrSettle()
	check(runs == 1, "TST-p021: waits in combat")
	H.combat = false
	H.Fire("PLAYER_REGEN_ENABLED")
	check(runs == 2, "TST-p021: runs when combat ends (" .. runs .. ")")
	-- TST-p022: a bad provide
	T.strict = true
	check(not pcall(M.PSS_Provide, "bad name", function() end), "TST-p022: raises under strict")
	T.strict = false
	M.PSS_Provide("bad name", function() end)
	local arg
	local ar = rows()
	for i = 1, ar.n do if ar[i][1] == "arg" and ar[i][2] == "bad name" then arg = true end end
	check(arg, "TST-p022: an arg ring entry in game")
	-- TST-p023: key calls allocate nothing once warm; nested calls have their own set
	local fixed = set1("fixed")
	M.PSS_Provide("t.k1", function() return fixed end, { returns = { "a" } })
	local innerSeen, outerBefore, outerAfter
	M.PSS_Provide("t.k2", function(input) outerBefore = input[1][1]; M.PSS_Call("t.k1", "inner"); outerAfter = input[1][1]; return fixed end, { returns = { "a" } })
	M.PSS_Call("t.k2", "outer")
	check(outerBefore == "outer" and outerAfter == "outer", "TST-p023: a nested call does not touch the outer key set")
	for _ = 1, 200 do M.PSS_Call("t.k1", "warm") end
	collectgarbage("collect"); collectgarbage("stop")
	local a0 = collectgarbage("count")
	for i = 1, 10000 do M.PSS_Call("t.k1", i) end
	local grew = collectgarbage("count") - a0
	collectgarbage("restart")
	check(grew < 2, string.format("TST-p023: 10,000 key calls grew %.2f KB", grew))
	-- TST-p024: a failing query step is one ring entry
	M.PSS_ErrReset()
	local qs, qe = M.PSS_Query({ from = "err.rows", where = { nocol = 1 }, order = { "nocol2" } })
	check(qs == nil and qe and qe:find("^fail: ") and ringCount("q.query") == 1, "TST-p024: one guarded pipeline, one ring entry (" .. ringCount("q.query") .. ")")
	-- TST-p025: every error text starts with a known code
	M.PSS_ErrReset()
	local texts = {}
	texts[#texts + 1] = select(2, M.PSS_Call("no.such", "x"))
	texts[#texts + 1] = select(2, M.PSS_Call("t.e0", "x"))
	M.PSS_Provide("t.e9", function() return "str" end, {})
	texts[#texts + 1] = select(2, M.PSS_Call("t.e9", "x"))
	_G.issecretvalue = function(v) return v == "SECRET" end
	texts[#texts + 1] = select(2, M.PSS_Call("t.e9", "SECRET"))
	_G.issecretvalue = realSecret
	texts[#texts + 1] = select(2, M.PSS_Query({ from = "nonsense" }))
	for i = 1, 5 do M.PSS_Call("t.e0", "x") end
	texts[#texts + 1] = select(2, M.PSS_Call("t.e0", "x"))		-- breaker open
	for i, t in ipairs(texts) do
		local code = tostring(t):match("^(%a+): ")
		check(code and M.PSS_ERR_CODES[code], "TST-p025: text " .. i .. " starts with a known code: " .. tostring(t))
	end
	M.ChatMsg = realMsg
end

if phase == "codec" then
	libs()
	local C = M.PSS_Codec
	-- TST-p026: every byte round trips and the output holds no separator
	local all = {}
	for b = 0, 255 do
		local one = string.char(b)
		local e = C.esc(one)
		check(C.unesc(e) == one, "TST-p026: byte " .. b .. " round trip")
		check(not e:find("[;,%.=\n\t]"), "TST-p026: byte " .. b .. " leaves a separator in the output")
		all[#all + 1] = one
	end
	local every = table.concat(all)
	check(C.unesc(C.esc(every)) == every and not C.esc(every):find("[;,%.=\n\t]"), "TST-p026: all 256 bytes together")
	check(C.unesc(C.esc("%41")) == "%41", "TST-p026: a literal %41 survives")
	-- TST-p027: list, map, rec
	local l = { "a;b", "c,d", "e.f", "g=h", "plain", "" }
	local back = C.unlist(C.list({ "a;b", "c,d", "e.f", "g=h", "plain" }))
	check(#back == 5 and back[1] == "a;b" and back[2] == "c,d" and back[3] == "e.f" and back[4] == "g=h" and back[5] == "plain", "TST-p027: list round trip")
	local rec = C.unrec(C.rec({ "1", "x.y", "z" }))
	check(#rec == 3 and rec[2] == "x.y", "TST-p027: rec round trip")
	check(C.map({ b = "2", a = "1" }) == "a=1;b=2" and C.map({ a = "1", b = "2" }) == "a=1;b=2", "TST-p027: map output is sorted")
	local m = C.unmap(C.map({ ["k;1"] = "v=1", k2 = "" }))
	check(m["k;1"] == "v=1" and m.k2 == "" , "TST-p027: map round trip with separators and an empty value")
	check(next(C.unmap("")) == nil and #C.unlist("") == 0, "TST-p027: empty strings give empty tables")
	-- TST-p028: layout
	local v1, b1 = C.layout("2;x")
	local v0, b0 = C.layout("abc")
	check(v1 == 2 and b1 == "x" and v0 == 0 and b0 == "abc" and C.withLayout(3, "q") == "3;q", "TST-p028: layout prefix")
	-- TST-p029: hash
	check(C.hash("") == 0 and C.hash("a") == 97 and C.hash("hello world") == 425269365, "TST-p029: known short values")
	check(C.hash("1;3;24;1840317;1.6948.20,2.x1,3.6948.4.b") == 478611304 and C.hash(string.rep("x", 500)) == 1626725048, "TST-p029: known long values")
	local worst = 0
	for _, str in ipairs({ "", "z", every, string.rep("q", 4000) }) do worst = math.max(worst, C.hash(str)) end
	check(worst < 2147483629, "TST-p029: below 2147483629")
	-- TST-p223 (the envelope; the warehouse kinds are added with their package)
	local text = M.PSS_IoPack("test.kind", 1, "body;with,separators")
	local kind, ver, body = M.PSS_IoUnpack(text)
	check(kind == "test.kind" and ver == 1 and body == "body;with,separators", "TST-p223: envelope round trip")
	local ukind, _, ubody = M.PSS_IoUnpack(M.PSS_IoPack("future.kind", 9, "kept"))
	check(ukind == "future.kind" and ubody == "kept" and M.PSS_IoKinds["future.kind"] == nil, "TST-p223: an unknown kind is returned whole so the caller keeps and reports it")
	local bad, why = M.PSS_IoUnpack(text:sub(1, #text - 3))
	check(bad == nil and why and why:find("^integrity: "), "TST-p223: a damaged envelope is refused")
elseif phase == "codecprop" then
	libs()
	local C = M.PSS_Codec
	local rnd = GEN.rng(2024)
	local function rstr(n)
		local t = {}
		for i = 1, n do t[i] = string.char(rnd(256) - 1) end
		return table.concat(t)
	end
	-- TST-p130
	local bad = 0
	for i = 1, 10000 do local s = rstr(rnd(40) - 1); if C.unesc(C.esc(s)) ~= s then bad = bad + 1 end end
	check(bad == 0, "TST-p130: " .. bad .. " of 10,000 strings failed the round trip")
	-- TST-p131
	bad = 0
	for i = 1, 2000 do
		local t = {}
		for _ = 1, rnd(6) do t[rstr(rnd(8))] = rstr(rnd(12) - 1) end
		local u = C.unmap(C.map(t))
		for k, v in pairs(t) do if u[k] ~= v then bad = bad + 1 end end
		for k in pairs(u) do if t[k] == nil then bad = bad + 1 end end
	end
	check(bad == 0, "TST-p131: " .. bad .. " map differences")
	-- containers: a body of entries slot.ref.count
	local function body()
		local e = {}
		for i = 1, rnd(30) do e[i] = i .. "." .. rnd(300000) .. (rnd(2) == 1 and ("." .. rnd(200)) or "") end
		return table.concat(e, ","), #e
	end
	-- TST-p132: one byte flipped
	local missed = 0
	for i = 1, 10000 do
		local b, n = body()
		local str = C.header(b, n, 7)
		local at = #str - #b + rnd(#b)
		local c = str:byte(at)
		local d = (c + rnd(255)) % 256
		local bent = str:sub(1, at - 1) .. string.char(d) .. str:sub(at + 1)
		if C.check(bent) then missed = missed + 1 end
	end
	check(missed == 0, "TST-p132: " .. missed .. " of 10,000 flipped bytes passed the check")
	-- TST-p133: two entries swapped
	missed = 0
	local tried = 0
	for i = 1, 3000 do
		local e = {}
		for k = 1, rnd(20) + 1 do e[k] = k .. "." .. rnd(300000) end
		local a, b2 = rnd(#e), rnd(#e)
		if e[a] ~= e[b2] then
			local str = C.header(table.concat(e, ","), #e, 1)
			e[a], e[b2] = e[b2], e[a]
			tried = tried + 1
			if C.check(C.header(table.concat(e, ","), #e, 1):gsub("^(%d+;%d+;%d+;)%d+", "%1" .. str:match("^%d+;%d+;%d+;(%d+)"))) then missed = missed + 1 end
		end
	end
	check(tried > 1000 and missed == 0, "TST-p133: " .. missed .. " of " .. tried .. " swaps passed")
	-- TST-p134: every truncation fails and never raises
	local b, n = body()
	local full = C.header(b, n, 7)
	local raised, passed = 0, 0
	for len = 0, #full - 1 do
		local ok, res = pcall(C.check, full:sub(1, len))
		if not ok then raised = raised + 1 elseif res then passed = passed + 1 end
	end
	check(raised == 0 and passed == 0, "TST-p134: raised " .. raised .. ", passed " .. passed)
	check(C.check(full), "TST-p134: the whole string passes")
	-- TST-p135: deterministic
	check(C.header(b, n, 7) == C.header(b, n, 7), "TST-p135: the same body gives the same header")
end

if not fail then print("PASS wh " .. phase) end
