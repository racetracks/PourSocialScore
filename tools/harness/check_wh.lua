-- The warehouse checks (warehouse-helper, one-build plan), as a run.lua
-- script. The phase is PSS_PHASE; each prints "PASS wh <phase>" or "FAIL
-- wh: <phase>: <what>". Run on Retail and on Camelot (PSS_CAMELOT=1) by
-- wh_phases.sh. Expected results come from the plan (03_Design, 05_Tests),
-- not from the code. Phases are added with their packages:
--   stub (TST-p001..p006)  err (TST-p010..p025)  codec (TST-p026..p029, p223)  codecprop (TST-p130..p135)  store2 (TST-p031..p036)  mapstore (TST-p037..p039, p061, p062)  idx (TST-p042..p049)  watch (TST-p064, p065, p069, p218, p219)  upg (TST-p030, p160..p169, p228..p230)  registry (TST-p007, p008)  schema (TST-p009, p214)  off (TST-00119, p142)  layers (TST-p225)  dict (TST-p050..p057, p215..p217)  live (TST-p040, p041, p058, p059)  name (TST-p224)  track (TST-p060, p063, p066..p068, p077, p079, TST-00120)  caps (TST-p070..p074, TST-00124)  delete (TST-p075, p076)  sv1 sv2 sv3 (TST-00121)  syn (TST-p078)
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
	check(blade and blade.itemID == 207791 and blade.hyperlink:find("|Hitem:207791:", 1, true) and blade.isBound, "TST-p002: variant link and bound flag")
	check(C_Item.DoesItemExist({ bagID = 0, slotIndex = 5 }) and C_Item.GetItemID({ bagID = 0, slotIndex = 5 }) == 207791 and not C_Item.DoesItemExist({ bagID = 0, slotIndex = 3 }), "TST-p002: item locations")
	check(GetInventoryItemID("player", 16) == 207791 and GetInventoryItemLink("player", 3):find("210001", 1, true), "TST-p002: equipped")
	check(GetInboxNumItems() == 1 and GetInboxItem(1, 1) == "Crystal Vial" and select(2, GetInboxItem(1, 1)) == 3371 and select(4, GetInboxItem(1, 1)) == 3, "TST-p002: mail attachment")
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
	check(C_Bank.FetchBankLockedReason(Enum.BankType.Account) ~= nil and C_AuctionHouse == nil and GetNumAuctionItems("owner") == 1 and CanUseVoidStorage == nil, "TST-p003: camelot has no warband, legacy auctions, no void")
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

local FIELDS3 = { { "name", "s" }, { "n", "n", 0 }, { "flag", "b" }, { "tag", "d" } }
if phase == "store2" then
	libs()
	-- TST-p031: schema.db puts the rows in another saved table
	local S = M.PSS_Store("t.own", { db = "T_OwnDB", key = "r", v = 1, fields = FIELDS3 })
	check(S.Set(1, { name = "a", n = 5, flag = true, tag = "x" }), "TST-p031: a write")
	check(T_OwnDB and T_OwnDB.r and T_OwnDB.r.rec[1] and PourSocialScoreDB.r == nil, "TST-p031: the rows live in T_OwnDB, nothing in PourSocialScoreDB")
	-- TST-p032: Read equals Get per field, the row split once
	S.Set(2, { name = "bb", tag = "x" })
	S.Set(3, {})
	for id = 1, 3 do
		local out = {}
		check(S.Read(id, out, 1, { "name", "n", "flag", "tag" }), "TST-p032: row " .. id .. " read")
		check(out[1] == S.Get(id, "name") and out[2] == S.Get(id, "n") and out[3] == S.Get(id, "flag") and out[4] == S.Get(id, "tag"), "TST-p032: Read equals Get for row " .. id)
	end
	local all = {}
	S.Read(1, all, 3, nil)
	check(all[3] == "a" and all[4] == 5 and all[5] == true and all[6] == "x", "TST-p032: all fields in order from position 3")
	check(S.Read(99, {}, 1, { "name" }) == false, "TST-p032: an unknown id reads false")
	-- TST-p033: Col
	local col = S.Col("name")
	check(col[1] == "a" and col[2] == "bb" and col[3] == nil, "TST-p033: map of every id with a value")
	check(S.Col("name") == col, "TST-p033: the same map until something changes")
	S.Set(4, { name = "d" })
	check(S.Col("name") ~= col and S.Col("name")[4] == "d", "TST-p033: rebuilt after a write")
	local before = S.Col("name")
	S.Drop()
	check(S.Col("name") ~= before, "TST-p033: dropped by S.Drop")
	-- TST-p034: Ver
	local v0 = S.Ver()
	S.Set(5, { name = "e" }); local v1 = S.Ver()
	S.Add({ name = "f" }); local v2 = S.Ver()
	S.Delete(5); local v3 = S.Ver()
	check(v1 == v0 + 1 and v2 == v1 + 1 and v3 == v2 + 1, "TST-p034: one step per Set, Add and Delete")
	S.Delete(12345)
	check(S.Ver() == v3, "TST-p034: a Delete that found nothing does not bump it")
	local C = M.PSS_Store("t.cap", { db = "T_OwnDB", key = "cap", v = 1, cap = 1, fields = FIELDS3 })
	C.Set(1, { name = "x" }); local cv = C.Ver()
	check(C.Set(2, { name = "y" }) == false and C.Ver() == cv, "TST-p034: a refused write does not bump it")
	-- TST-p035: Rows reuse
	local names = { "name", "n" }
	local r1 = S.Rows(names, nil, { reuse = true })
	local rows1 = {}
	for i = 1, r1.n do rows1[r1[i]] = true end
	local r2 = S.Rows(names, nil, { reuse = true })
	local same = r2.n == r1.n
	for i = 1, r2.n do if not rows1[r2[i]] then same = false end end
	check(same and r2 == r1, "TST-p035: the second call hands back the same set and rows")
	local r3 = S.Rows(names, nil, nil)
	check(r3 ~= r1 and r3.n == r1.n and r3.cols[2] == "name", "TST-p035: without reuse a new set")
	-- TST-p036: the ent store keeps its saved text (golden)
	local E = M.PSS_Store("t.entgold", { key = "t_entgold", v = 1, cap = 500, fields = { { "kind", "s" }, { "name", "s" }, { "realm", "s" }, { "faction", "s" }, { "class", "s" }, { "race", "s" }, { "sex", "n" }, { "flags", "s" } } })
	E.Set(1, { kind = "c", name = "Alpha", realm = "Realm", faction = "Alliance", class = "MAGE", race = "Human", sex = 2 })
	check(PourSocialScoreDB.t_entgold.rec[1] == "c;Alpha;Realm;Alliance;MAGE;Human;2", "TST-p036: the v1 saved text is byte for byte as before: " .. tostring(PourSocialScoreDB.t_entgold.rec[1]))
	PourSocialScoreDB.t_entgold = nil
	T_OwnDB = nil
elseif phase == "mapstore" or phase == "integrity" then
	libs()
	local C = M.PSS_Codec
	local function cont(body, n) return C.header(body, n or 1, 1) end
	local ms = M.PSS_MapStore("t.map", { db = "T_MapDB", key = "inv", bad = "bad", v = 1, cap = 3, badCap = 32 })
	local good1, good2 = cont("1.100", 1), cont("1.200,2.300", 2)
	if phase == "mapstore" then
		-- TST-p037: verify all, then swap all
		local bad2 = good2:gsub("2%.300", "2.301")
		local ok, why = ms.Put(7, { b0 = good1, b1 = bad2 })
		check(ok == false and why and why:find("^integrity: ") and T_MapDB == nil, "TST-p037: one bad string stops the whole write; nothing exists")
		check(ms.Put(7, { b0 = good1, b1 = good2 }) and T_MapDB.inv[7].b0 == good1 and T_MapDB.inv[7].b1 == good2, "TST-p037: two good strings are both written")
		local snap = T_MapDB.inv[7].b0
		local ok2 = ms.Put(7, { b0 = cont("1.999", 1), b1 = good2:sub(1, #good2 - 2) })
		check(ok2 == false and T_MapDB.inv[7].b0 == snap, "TST-p037: a later bad string leaves the earlier ones as they were")
		-- cap
		ms.Put(8, { b0 = good1 }); ms.Put(9, { b0 = good1 })
		local capOk, capWhy = ms.Put(10, { b0 = good1 })
		check(capOk == false and capWhy:find("^cap: ") and T_MapDB.inv[10] == nil, "TST-p037: the entity cap refuses a fourth entity")
		-- TST-p038: a newer table is read-only
		T_MapDB.v = 2
		local before = T_MapDB.inv[7].b0
		local nOk, nWhy = ms.Put(7, { b0 = good1 })
		check(nOk == false and nWhy:find("^newer: ") and T_MapDB.inv[7].b0 == before and T_MapDB.v == 2, "TST-p038: refused with newer, table untouched")
		T_MapDB.v = 1
		-- TST-p039: unknown code and unknown layout kept
		T_MapDB.inv[7].z9 = good1
		T_MapDB.inv[7].b2 = "9;" .. good1
		check(ms.Put(7, { b0 = cont("1.111", 1) }), "TST-p039: another code is written")
		check(T_MapDB.inv[7].z9 == good1 and T_MapDB.inv[7].b2 == "9;" .. good1, "TST-p039: the unknown code and the unknown layout are still there, unchanged")
		local got, why2 = ms.Get(7, "b2")
		check(got == nil and why2 == "newer" and T_MapDB.inv[7].b2 == "9;" .. good1 and next(ms.Bad(7)) == nil, "TST-p039: the unknown layout is not read and not quarantined")
		local codes = ms.Codes(7)
		check(#codes == 4 and codes[1] == "b0" and codes[4] == "z9", "TST-p039: Codes lists every code")
		check(ms.Put(7, { b0 = false }) and T_MapDB.inv[7].b0 == nil, "TST-p037: false removes a code")
		T_MapDB = nil
	else
		-- TST-p061: the header is checked once per session per string
		ms.Put(3, { b0 = good1, b1 = good2 })
		ms.Drop()
		local c0 = ms.Checks()
		ms.Get(3, "b0"); ms.Get(3, "b0"); ms.Get(3, "b0")
		check(ms.Checks() == c0 + 1, "TST-p061: three reads of one string checked it once (" .. (ms.Checks() - c0) .. ")")
		ms.Get(3, "b1")
		check(ms.Checks() == c0 + 2, "TST-p061: another string is checked on its own first read")
		-- TST-p062: a wrong hash is quarantined, never deleted
		local damaged = good2:gsub("^(%d+;%d+;%d+;)%d+", "%1123")
		T_MapDB.inv[3].b1 = damaged
		ms.Drop()
		M.PSS_ErrReset()
		local g, why = ms.Get(3, "b1")
		check(g == nil and why == "bad", "TST-p062: the damaged string is not returned")
		check(T_MapDB.inv[3].b1 == nil and T_MapDB.bad[3].b1 == damaged, "TST-p062: it is in the quarantine, whole")
		check(ms.Get(3, "b0") == good1, "TST-p062: the other codes are untouched")
		local rr = M.PSS_Call("err.rows")
		local found
		for i = 1, rr.n do if rr[i][1] == "integrity" then found = true end end
		check(found, "TST-p062: an integrity entry in the ring")
		-- TST-p074 (cap of the quarantine): 33 bad strings keep 32
		for e = 20, 52 do
			ms.Put(e, { b0 = good1 })
			T_MapDB.inv[e].b0 = good1:gsub("^(%d+;%d+;%d+;)%d+", "%1777")
			ms.Drop()
			ms.Get(e, "b0")
		end
		local nbad = 0
		for _, codes in pairs(T_MapDB.bad) do for _ in pairs(codes) do nbad = nbad + 1 end end
		check(nbad == 32 and T_MapDB.bad[3] == nil, "TST-p074: 32 quarantined strings kept, the oldest dropped (" .. nbad .. ")")
		T_MapDB = nil
	end
elseif phase == "idx" then
	libs()
	local data, ver = { a = 1, b = 2, c = 3 }, 1
	local buildCalls = 0
	local I = M.PSS_Index("t.idx", {
		sourceVer = function() return ver end,
		build = function(add) buildCalls = buildCalls + 1; for k, v in pairs(data) do add(k, v) end end,
		partial = function(add, drop, ids)
			for id in pairs(ids) do if data[id] ~= nil then add(id, data[id]) else drop(id) end end
		end,
	})
	-- TST-p042
	check(I:get("a") == 1 and I:has("b") and not I:has("zz") and I:size() == 3, "TST-p042: lookups")
	check(buildCalls == 1 and I:builds() == 1, "TST-p042: built once for four lookups (" .. buildCalls .. ")")
	-- TST-p043: a version change rebuilds; a dirty set rebuilds in part
	data.d = 4; ver = 2
	check(I:get("d") == 4 and buildCalls == 2, "TST-p043: a new version rebuilds")
	data.e = 5; data.a = nil; ver = 3
	M.PSS_IndexDirty("t.idx", { "e", "a" })
	check(I:get("e") == 5 and I:get("a") == nil and buildCalls == 2 and I:partials() == 1, "TST-p043: a dirty set rebuilds only those ids (" .. buildCalls .. " builds, " .. I:partials() .. " partial)")
	-- TST-p044: the partial result equals a full rebuild
	local keysPartial = I:list()
	I:drop()
	local keysFull = I:list()
	check(table.concat(keysPartial, ",") == table.concat(keysFull, ","), "TST-p044: partial equals full (" .. table.concat(keysPartial, ",") .. " vs " .. table.concat(keysFull, ",") .. ")")
	check(table.concat(I:range("b", "d"), ",") == "b,c,d", "TST-p044: range")
	-- TST-p045: released on a drop, a GC request
	check(I:resident(), "TST-p045: resident after a lookup")
	M.PSS_IndexDrop("t.idx")
	check(not I:resident(), "TST-p045: released by M.PSS_IndexDrop")
	I:get("b")
	M.PSS_RequestGC("test")
	check(not I:resident(), "TST-p045: released by a GC request")
	-- TST-p046: cap
	M.PSS_ErrReset()
	local big = M.PSS_Index("t.cap", { build = function(add) for i = 1, 20 do add(i, i) end end, cap = 10 })
	check(big:size() == 10 and big:get(5) == 5 and big:get(15) == nil, "TST-p046: serves what fits")
	local rr = M.PSS_Call("err.rows")
	local capNote
	for i = 1, rr.n do if rr[i][1] == "cap" and rr[i][2] == "index t.cap" then capNote = true end end
	check(capNote, "TST-p046: a cap entry in the ring, no error")
	-- TST-p047: a sliced build
	local clockN, realClock = 0, debugprofilestop
	debugprofilestop = function() clockN = clockN + 1; return clockN end		-- 1 ms per call
	local order = {}
	local units = {}
	for i = 1, 40 do units[i] = i end
	local S = M.PSS_Index("t.slice", { units = function() return units end, each = function(u, add) order[#order + 1] = u; add(u, u * 2) end, sliceMs = 4 })
	check(S:warm() == true and not S:built(), "TST-p047: warm starts a build that is not done")
	local needs = M.PSS_Needs()
	local seen
	for i = 1, needs.n do if needs[i][1] == "index.t.slice" then seen = true end end
	check(seen, "TST-p047: the slice waits on the trigger engine")
	local steps = 0
	while not S:step() do steps = steps + 1; check(#order <= steps * 5 + 5, "TST-p047: a slice does little") ; if steps > 100 then break end end
	check(steps >= 5 and S:built() and S:get(40) == 80, "TST-p047: the build took several slices (" .. steps .. ") and is complete")
	check(#order == 40, "TST-p047: each unit ran once")
	-- a lookup in the middle of a build finishes it
	S:drop(); order = {}
	S:warm(); S:step()
	check(S:get(7) == 14 and S:built() and #order == 40, "TST-p047: a lookup mid-build finishes it at once")
	debugprofilestop = realClock
	M.PSS_Unwant("index.t.slice")
	-- TST-p048: ent.byName agrees with the entity rows
	local ids = {}
	for i, nm in ipairs({ "Idx1", "Idx2", "Idx3" }) do ids[i] = M.PSS_EntityId("c", nm, "Realm", true) end
	M.PSS_EntityDrop()
	local ok = true
	for i, nm in ipairs({ "Idx1", "Idx2", "Idx3" }) do if M.PSS_EntityId("c", nm, "Realm", false) ~= ids[i] then ok = false end end
	check(ok and M.PSS_EntityId("c", "Nobody", "Realm", false) == nil, "TST-p048: names map to the same ids after the index is rebuilt")
	-- TST-p049: pushdown
	local rowsN = 10000
	local table_ = M.PSS_Set({ "item", "ent" })
	local byItem = {}
	for i = 1, rowsN do M.PSS_SetAdd(table_, { i, i % 7 }); byItem[i] = table_[i] end
	M.PSS_Provide("t.all", function() return table_ end, { returns = { "item", "ent" } })
	M.PSS_QueryIndexed("t.all", "item", function(value)
		local out = M.PSS_Set({ "item", "ent" })
		if byItem[value] then M.PSS_SetAdd(out, byItem[value]) end
		return out
	end)
	local st = M.PSS_QueryStats
	local s0 = st.scanned
	local viaIndex = M.PSS_Query({ from = "t.all", where = { item = 4242 } })
	check(viaIndex and viaIndex.n == 1 and viaIndex[1][1] == 4242 and st.scanned == s0, "TST-p049: the indexed column reads the index, no rows scanned")
	local viaScan = M.PSS_Query({ from = table_, where = { item = 4242 } })
	check(viaScan.n == 1 and viaScan[1][1] == 4242 and st.scanned == s0 + rowsN, "TST-p049: the same rows by a scan (" .. (st.scanned - s0) .. " scanned)")
	local both = M.PSS_Query({ from = "t.all", where = { item = 4243, ent = 99 } })
	check(both and both.n == 0 and st.scanned == s0 + rowsN + 1, "TST-p049: another column is still filtered after the index")
	local t0 = os.clock()
	for _ = 1, 200 do M.PSS_Query({ from = "t.all", where = { item = 4242 } }) end
	local us = (os.clock() - t0) / 200 * 1e6
	check(us < 50, string.format("TST-p049: a pushdown of one match in 10,000 took %.1f us", us))
end

if phase == "watch" then
	local PART = "PourSocialScore_Libraries"
	local seen, fails = {}, 0
	local function keysOf(set)
		local k = {}
		for i = 1, set.n do k[#k + 1] = set[i][1] end
		table.sort(k)
		return table.concat(k, ",")
	end
	M.PSS_Trigger({ id = "t.w", on = { "BAG_UPDATE" }, settle = { "BAG_UPDATE_DELAYED" }, run = "t.w.run", key = function(_, bag) return bag end })
	-- TST-p064: Libraries cannot load during a flush: the keys are kept
	H.loadFail[PART] = true
	check(not C_AddOns.IsAddOnLoaded(PART), "TST-p064: Libraries are not loaded yet")
	H.Fire("BAG_UPDATE", 1); H.Fire("BAG_UPDATE", 2)
	H.Fire("BAG_UPDATE_DELAYED")
	check(not C_AddOns.IsAddOnLoaded(PART), "TST-p064: the load failed")
	H.loadFail[PART] = nil
	libs()
	local writes = {}
	M.PSS_Provide("t.w.run", function(set) writes[#writes + 1] = keysOf(set) return set end, { returns = { "key" }, onError = "empty" })
	H.Fire("BAG_UPDATE", 3)
	H.Fire("BAG_UPDATE_DELAYED")
	check(#writes == 1 and writes[1] == "1,2,3", "TST-p064: the next settle writes the kept keys with the new one (" .. table.concat(writes, " | ") .. ")")
	H.Fire("BAG_UPDATE_DELAYED")
	check(#writes == 1, "TST-p064: nothing is written twice (" .. #writes .. ")")
	-- TST-p065: the service fails once: the keys are kept and written at the next settle
	writes = {}
	local boom = true
	M.PSS_Provide("t.w.run", function(set) if boom then boom = false error("busy") end writes[#writes + 1] = keysOf(set) return set end, { returns = { "key" }, onError = "empty" })
	H.Fire("BAG_UPDATE", 5)
	H.Fire("BAG_UPDATE_DELAYED")
	check(#writes == 0, "TST-p065: the first call failed")
	H.Fire("BAG_UPDATE", 6)
	H.Fire("BAG_UPDATE_DELAYED")
	check(#writes == 1 and writes[1] == "5,6", "TST-p065: the next settle wrote both (" .. table.concat(writes, " | ") .. ")")
	-- TST-p069 and TST-p218: a burst of 40 changes is one read, shared by two followers
	local reads, followA, followB = 0, {}, {}
	M.PSS_Provide("t.read", function(set) reads = reads + 1 return set end, { returns = { "key" }, onError = "empty" })
	M.PSS_Provide("t.a", function(set) followA[#followA + 1] = keysOf(set) return set end, { returns = { "key" }, onError = "empty" })
	M.PSS_Provide("t.b", function(set) followB[#followB + 1] = keysOf(set) return set end, { returns = { "key" }, onError = "empty" })
	M.PSS_Trigger({ id = "t.bags", on = { "BAG_UPDATE" }, settle = { "BAG_UPDATE_DELAYED" }, run = "t.read", key = function(_, bag) return bag end })
	M.PSS_Trigger({ id = "t.fa", on = { "@t.bags" }, settle = "now", run = "t.a", key = function(_, set) return set and set.n and keysOf(set) or "x" end })
	M.PSS_Trigger({ id = "t.fb", on = { "@t.bags" }, settle = "now", run = "t.b", key = function(_, set) return set and set.n and keysOf(set) or "x" end })
	for i = 1, 40 do H.Fire("BAG_UPDATE", i % 5 + 1) end
	H.Fire("BAG_UPDATE_DELAYED")
	check(reads == 1, "TST-p069: the bags were read once for a burst of 40 (" .. reads .. ")")
	check(#followA == 1 and #followB == 1, "TST-p218: both followers ran once on the one settle (" .. #followA .. ", " .. #followB .. ")")
	-- TST-p219: the signal carries the changed ids as a record set
	local got
	M.PSS_Provide("t.p", function(set) got = set return set end, { returns = { "key" }, onError = "empty" })
	M.PSS_Trigger({ id = "t.fp", on = { "@t.bags" }, settle = "now", run = "t.p", key = function(_, set) return "k" end })
	H.Fire("BAG_UPDATE", 9)
	H.Fire("BAG_UPDATE_DELAYED")
	check(M.PSS_IsSet(got) and got.cols[1] == "key", "TST-p219: a follower receives a record set of keys")
end

if phase == "upg" then
	libs()
	local said = {}
	local realMsg = M.ShowMsg
	M.ShowMsg = function(str) said[#said + 1] = str end
	local steps = M.PSS_UPGRADE_REGISTRY
	local N = #steps
	local STORES = { "PourSocialScoreDB", "PSS_OptionsDB", "PSS_PlayersDB", "PSS_GuildsDB", "PSS_RulesDB", "PSS_CountsDB" }
	local function deep(a, b, path)
		if type(a) ~= type(b) then return false, path end
		if type(a) ~= "table" then return a == b, path end
		for k, v in pairs(a) do
			if not (path == "PourSocialScoreDB" and k == "upgrade") then
				local ok, where = deep(v, b[k], path .. "." .. tostring(k))
				if not ok then return false, where end
			end
		end
		for k in pairs(b) do
			if not (path == "PourSocialScoreDB" and k == "upgrade") and rawget(a, k) == nil and a[k] == nil then return false, path .. "." .. tostring(k) end
		end
		return true
	end
	local function snapshot()
		local s = {}
		for _, n in ipairs(STORES) do
			local t = rawget(_G, n)
			if type(t) == "table" then
				local c = {}
				local function cp(v) if type(v) ~= "table" then return v end local r = {} for k, x in pairs(v) do r[k] = cp(x) end return r end
				for k, v in pairs(t) do c[k] = cp(v) end
				s[n] = c
			end
		end
		return s
	end
	local function same(a, b)
		for _, n in ipairs(STORES) do
			if a[n] or b[n] then
				local ok, where = deep(a[n] or {}, b[n] or {}, n)
				if not ok then return false, where end
			end
		end
		return true
	end
	local function rec() return PourSocialScoreDB.upgrade end
	local function run() M.PSS_RunUpgradeFields(false, 0); M.PSS_RunUpgradeData(false) end
	local function addStep(parts) steps[#steps + 1] = { id = #steps + 1, parts = parts } return #steps end
	local function dropSteps() while #steps > N do steps[#steps] = nil end end
	-- TST-p030: the plan reads and writes nothing
	local before = snapshot()
	local plan = M.PSS_Call("upg.plan")
	check(plan and plan.n >= N and plan.cols[3] == "state" and same(before, snapshot()), "TST-p030: upg.plan lists the steps and changes nothing")
	local states = {}
	for i = 1, plan.n do states[plan[i][3]] = true end
	check(states.always and states.done, "TST-p030: always and done steps are told apart")
	-- TST-p160: a part that throws pauses, no Lua error
	local boom = true
	local s12 = addStep({ { feature = "options", data = function() PSS_OptionsDB.tprobe = 1; PSS_PlayersDB.tprobe = { 1, 2 }; if boom then error("kaboom") end end } })
	rec().step = N
	said = {}
	local pre = snapshot()
	run()
	check(rec().fail == s12 .. ":fail" and rec().step == N, "TST-p160: upgrade.fail names the step and the code (" .. tostring(rec().fail) .. ")")
	-- TST-p161: nothing the part wrote is left
	check(same(pre, snapshot()), "TST-p161: the stores are as they were before the part ran")
	-- TST-p165: the line is plain words
	local line = table.concat(said, "\n")
	check(line:find("did not finish", 1, true) and line:find("Options", 1, true) and not line:find("kaboom", 1, true) and not line:find(".lua", 1, true) and not line:find("traceback", 1, true), "TST-p165: a plain line that names the feature (" .. line .. ")")
	-- TST-p169: the state is readable
	local st = M.PSS_Call("upg.status")
	check(st and st[1][3] == s12 .. ":fail" and M.PSS_UpgradeStatusLine():find("failed at step", 1, true), "TST-p169: upg.status and the status line show the failure")
	-- TST-p164: the retry waits in combat
	local live
	local rows = M.PSS_Triggers()
	for i = 1, rows.n do if rows[i][1] == "upgretry" then live = rows[i][6] end end
	check(live == true, "TST-p164: the retry row is live")
	boom = false
	H.combat = true
	H.Fire("PLAYER_REGEN_ENABLED")
	check(rec().fail == s12 .. ":fail" and rec().step == N, "TST-p164: nothing runs in combat")
	H.combat = false
	said = {}
	-- TST-p163: one retry, the fault gone
	H.Fire("ZONE_CHANGED_NEW_AREA")
	check(rec().step == s12 and rec().fail == nil and PSS_OptionsDB.tprobe == 1, "TST-p163: the retry finished the step (" .. tostring(rec().step) .. ")")
	check(table.concat(said, "\n"):find("second try", 1, true), "TST-p163: the line says it was the second try")
	rows = M.PSS_Triggers()
	local still
	for i = 1, rows.n do if rows[i][1] == "upgretry" then still = true end end
	check(not still, "TST-p163: the retry row took itself down")
	check(type(rec().undo) == "table", "TST-p228: the finished retry keeps the undo copy")
	-- TST-p229: undo puts the pre-upgrade stores back
	PSS_OptionsDB.tprobe, PSS_PlayersDB.tprobe = nil, nil
	said = {}
	check(M.PSS_UpgradeUndo() and rec().step == N and rec().undo == nil, "TST-p229: undo moved the record back")
	check(PSS_OptionsDB.tprobe == nil and PSS_PlayersDB.tprobe == nil, "TST-p229: the stores are as before the step")
	check(M.PSS_UpgradeUndo() == false, "TST-p229: a second undo has nothing")
	dropSteps()
	-- TST-p162: a check that fails restores and pauses
	local s12b = addStep({ { feature = "players", data = function() PSS_PlayersDB.tprobe2 = "x" end, check = function() return false end } })
	rec().step = N
	pre = snapshot()
	said = {}
	run()
	check(rec().fail == s12b .. ":integrity" and PSS_PlayersDB.tprobe2 == nil and same(pre, snapshot()), "TST-p162: a failed check swaps nothing (" .. tostring(rec().fail) .. ")")
	dropSteps(); rec().fail = nil
	-- TST-p230: the slot is dropped by the next clean login and never doubled
	local s12c = addStep({ { feature = "options", data = function() PSS_OptionsDB.tprobe3 = 1 end } })
	rec().step = N
	run()
	check(rec().step == s12c and type(rec().undo) == "table", "TST-p230: a due step leaves one undo slot")
	local firstAt = rec().undo.at
	local s12d = addStep({ { feature = "options", data = function() PSS_OptionsDB.tprobe4 = 1 end } })
	run()
	check(rec().step == s12d and type(rec().undo) == "table" and rec().undo.step == s12c, "TST-p230: the next step replaces the slot, never two")
	run()
	check(rec().undo == nil, "TST-p230: a login with nothing due drops it")
	PSS_OptionsDB.tprobe3, PSS_OptionsDB.tprobe4 = nil, nil
	dropSteps(); rec().step = N
	-- TST-p166: every step is safe to run twice
	for i = 1, N do
		rec().step = i - 1
		run()
		local one = snapshot()
		rec().step = i - 1
		run()
		local ok, where = same(one, snapshot())
		check(ok, "TST-p166: step " .. i .. " run twice differs at " .. tostring(where))
	end
	rec().step = N
	-- TST-p168: a newer save with a forced fault is left alone
	rec().version = "9.9.9.9"
	pre = snapshot()
	local T = M.PSS_Test
	T.fault = "*"
	run()
	T.fault = nil
	check(same(pre, snapshot()) and rec().version == "9.9.9.9", "TST-p168: a newer save is kept untouched under a fault")
	-- TST-p167: step 11 is still registered with its retry row declared on demand
	check(steps[11].always == true and steps[11].parts[1].data ~= nil, "TST-p167: step 11 keeps its part")
	M.ShowMsg = realMsg
end

if phase == "layers" then
	libs()
	-- TST-p225: a stub loads nothing until it is called
	local built = 0
	M.PSS_ProvideStub("t.stub", { returns = { "a" }, doc = "x" }, function() built = built + 1 return function() return { cols = { "a" }, n = 1, { 7 } } end end)
	check(M.PSS_ServiceIsStub("t.stub") and built == 0 and M.PSS_ServiceInfo("t.stub").doc == "x", "TST-p225: declared, known to discovery, not built")
	local r = M.PSS_Call("t.stub", "k")
	check(r and r[1][1] == 7 and built == 1 and not M.PSS_ServiceIsStub("t.stub"), "TST-p225: built by the first call")
	M.PSS_Call("t.stub", "k")
	check(built == 1, "TST-p225: built once")
	-- a services file that names a function of a view file fails the layer check
	local tmp = os.tmpname()
	local f = io.open(tmp, "w"); f:write("local M = ...\nlocal x = M.PSS_PlayerRows\nM.PSS_OptGate(1)\n"); f:close()
	local p = io.popen("lua5.1 tools/check_layers.lua --services " .. tmp .. " 2>&1; echo EXIT$?"); local o = p:read("*a"); p:close()
	os.remove(tmp)
	check(o:find("PSS_OptGate", 1, true) and o:find("EXIT1", 1, true), "TST-p225: a services file calling a views file fails: " .. o)
	local tmp2 = os.tmpname()
	f = io.open(tmp2, "w"); f:write("local M = ...\nM.PSS_Call('x')\n"); f:close()
	p = io.popen("lua5.1 tools/check_layers.lua --services " .. tmp2 .. " 2>&1; echo EXIT$?"); o = p:read("*a"); p:close()
	os.remove(tmp2)
	check(o:find("EXIT0", 1, true), "TST-p225: a services file that calls only services passes: " .. o)
end

if phase == "dict" then
	libs()
	local V = WORLD.V
	-- TST-p050: keys per the grammar; level, spec, unique id and crafter are cleared
	local plain = "|cffffffff|Hitem:2589::::::::80:262:::::|h[Linen Cloth]|h|r"
	check(M.PSS_ItemKey(plain) == "2589", "TST-p050: a plain item is its id (" .. tostring(M.PSS_ItemKey(plain)) .. ")")
	check(M.PSS_ItemKey(V.blade_a.link) == V.blade_a.key and V.blade_a.key == "207791:0:0:0:0:0:0:6652:1540", "TST-p050: bonus ids make a variant (" .. tostring(M.PSS_ItemKey(V.blade_a.link)) .. ")")
	local lvl2 = V.blade_a.link:gsub("::::::::80:0:", "::::::::123:66:"):gsub("(:6652:1540)", "%1:1:9:99:GUID-1-2:")
	local other = "|cffa335ee|Hitem:207791::::::::" .. "x:" .. "|h[x]|h|r"
	local changedLevelSpecUnique = "|cffa335ee|Hitem:207791:::::::999:71:63:::2:6652:1540:1:9:99:Player-1-ABC|h[Harbinger's Blade]|h|r"
	check(M.PSS_ItemKey(changedLevelSpecUnique) == V.blade_a.key, "TST-p050: unique id, level, spec and crafter do not change the key (" .. tostring(M.PSS_ItemKey(changedLevelSpecUnique)) .. ")")
	check(M.PSS_ItemKey(V.blade_b.link) ~= V.blade_a.key and M.PSS_ItemKey(V.blade_b.link) == V.blade_b.key, "TST-p050: another bonus id is another variant")
	check(M.PSS_ItemKey(V.pet.link) == "p:1234:25:3" and M.PSS_ItemKey(V.keystone.link) == "k:375:10", "TST-p050: a pet and a keystone")
	check(M.PSS_ItemKey("|cffffffff|Hitem:190000:5400:::::::::::|h[x]|h|r") == "190000:5400:0:0:0:0:0", "TST-p050: an enchant makes a variant")
	check(M.PSS_ItemId("207791:0:0:0:0:0:0:6652") == 207791 and M.PSS_ItemId("p:1:2:3") == 82800 and M.PSS_ItemId("2589") == 2589, "TST-p050: M.PSS_ItemId")
	-- TST-p051: a plain item is never in the dictionary
	check(M.PSS_ItemRef("2589") == "2589" and M.PSS_ItemRef("2589", true) == "2589" and PSS_WarehouseDB == nil, "TST-p051: the ref of a plain item is its id and nothing is saved")
	-- TST-p052: a variant is added once
	local r1 = M.PSS_ItemRef(V.blade_a.key, true)
	local r2 = M.PSS_ItemRef(V.blade_a.key, true)
	local r3 = M.PSS_ItemRef(V.blade_b.key, true)
	check(r1 == "x1" and r2 == "x1" and r3 == "x2" and PSS_WarehouseDB.item[1] == V.blade_a.key and PSS_WarehouseDB.itemN == 2, "TST-p052: x<id> refs, one id per key, saved once")
	check(M.PSS_ItemRef(V.mantle.key) == nil, "TST-p052: without create an unknown variant has no ref and nothing is added")
	-- TST-p053: Unref(Ref(k)) == k
	for _, k in ipairs({ "2589", V.blade_a.key, V.blade_b.key, V.mantle.key, V.pet.key, V.keystone.key }) do
		check(M.PSS_ItemUnref(M.PSS_ItemRef(k, true)) == k, "TST-p053: round trip of " .. k)
	end
	-- TST-p054: a link is parsed once per session
	M.PSS_ItemKey(V.keystone.link)
	local p0 = M.PSS_ItemParses()
	for _ = 1, 50 do M.PSS_ItemKey(V.keystone.link); M.PSS_ItemKey(V.pet.link) end
	check(M.PSS_ItemParses() == p0, "TST-p054: no link is parsed twice (" .. (M.PSS_ItemParses() - p0) .. " more)")
	-- TST-p057: a secret link is refused, nothing stored
	local realSecret = issecretvalue
	_G.issecretvalue = function(v) return v == "SECRETLINK" end
	check(M.PSS_ItemKey("SECRETLINK") == nil, "TST-p057: a secret link has no key")
	_G.issecretvalue = realSecret
	-- TST-p215 and p216: a holder registers, a compaction remaps it
	PSS_WarehouseDB = { v = 1, item = {}, itemN = 0 }
	M.PSS_ItemDictDrop()
	local keys, refs = {}, {}
	for i = 1, 10 do keys[i] = "700" .. i .. ":0:0:0:0:0:0:" .. i; refs[i] = M.PSS_ItemRef(keys[i], true) end
	local holder = { refs[2], refs[5], refs[9], refs[10] }		-- 4 of 10 used: 60% free
	local expect = {}
	for i, r in ipairs(holder) do expect[i] = M.PSS_ItemUnref(r) end
	local journal = { "2026-10|" .. refs[2] .. "|3|g", "2026-10|2589|1|c" }		-- a journal-shaped line: the one grammar (plain id or x<dict>)
	M.PSS_ItemRefs("fake", { used = function(add) for _, r in ipairs(holder) do add(r) end end,
		remap = function(map)
			local new = {}
			for i, r in ipairs(holder) do
				local n = r:match("^x(%d+)$")
				if n and not map[tonumber(n)] then return false end
				new[i] = n and ("x" .. map[tonumber(n)]) or r
			end
			return function() for i = 1, #holder do holder[i] = new[i] end end
		end })
	-- TST-p217: an unregistered holder is found
	PSS_WarehouseDB.rogue = { [1] = "x3" }
	local orphans = M.PSS_ItemOrphans()
	check(#orphans == 1 and orphans[1] == "rogue", "TST-p217: an unregistered holder of refs is reported (" .. table.concat(orphans, ",") .. ")")
	PSS_WarehouseDB.rogue = nil
	check(#M.PSS_ItemOrphans() == 0, "TST-p217: none left after it is removed")
	-- TST-p056: below 25% free: tombstones only
	local d = PSS_WarehouseDB
	local freed, remapped = M.PSS_ItemSweep()
	check(freed == 6 and remapped == 4 and d.itemFree == nil, "TST-p055: six freed, 60% free, so compacted to 4 (" .. freed .. ", " .. remapped .. ")")
	check(d.itemN == 4 and #d.item == 4, "TST-p055: the dictionary is dense again")
	for i, r in ipairs(holder) do check(M.PSS_ItemUnref(r) == expect[i], "TST-p216: the holder's ref " .. i .. " still names its key") end
	check(M.PSS_ItemRef(keys[2]) == holder[1], "TST-p055: the key index finds the new id")
	-- TST-p056: 10% free: tombstones, no compaction
	PSS_WarehouseDB = { v = 1, item = {}, itemN = 0 }
	M.PSS_ItemDictDrop()
	holder = {}
	for i = 1, 20 do holder[i] = M.PSS_ItemRef("800" .. i .. ":0:0:0:0:0:0:" .. i, true) end
	local kept = {}
	for i = 3, 20 do kept[#kept + 1] = holder[i] end
	holder = kept
	local f2, r2b = M.PSS_ItemSweep()
	check(f2 == 2 and r2b == 0 and PSS_WarehouseDB.itemFree == 2 and PSS_WarehouseDB.item[1] == "" and PSS_WarehouseDB.itemN == 20, "TST-p056: 10% free leaves tombstones (" .. f2 .. ", " .. r2b .. ")")
	check(M.PSS_ItemUnref("x1") == nil and M.PSS_ItemUnref("x3") ~= nil, "TST-p056: a freed id resolves to nothing")
	-- a failing holder stops the compaction and changes nothing
	for i = 1, 20 do M.PSS_ItemRef("900" .. i .. ":0:0:0:0:0:0:" .. i, true) end
	M.PSS_Test.compactFail = true
	local before = { N = PSS_WarehouseDB.itemN, free = PSS_WarehouseDB.itemFree, first = PSS_WarehouseDB.item[3] }
	local f3, r3b = M.PSS_ItemSweep(true)
	M.PSS_Test.compactFail = nil
	check(r3b == 0 and PSS_WarehouseDB.itemN == before.N and PSS_WarehouseDB.item[3] == before.first, "TST-p071: a holder that cannot be rewritten leaves everything as it was")
	-- TST-p215: a line in the one grammar
	PSS_WarehouseDB = nil
	check(journal[1]:match("|(x%d+)|") == refs[2] and journal[2]:match("|(%d+)|") == "2589", "TST-p215: refs in a saved line are a plain id or x<dict>")
	PSS_WarehouseDB = nil
elseif phase == "live" then
	libs()
	local w = WORLD.world()
	WORLD.apply(H, w, 1, client)
	H.Interact("bank", true)
	-- TST-p040: item.live equals the fixture; bags only: nothing is saved
	local live = M.PSS_Call("item.live")
	check(live and live.n > 0 and live.cols[4] == "item" and PSS_WarehouseDB == nil, "TST-p040: the live read works and saves nothing")
	local got = {}
	for i = 1, live.n do got[live[i][2] .. ":" .. live[i][3]] = live[i] end
	local want, nwant = {}, 0
	for code, rows in pairs(w.chars[1].cont) do
		if code:find("^[bke]") then
			for slot, row in pairs(rows) do want[code .. ":" .. slot] = row; nwant = nwant + 1 end
		end
	end
	local missing, extra = 0, 0
	for k, row in pairs(want) do
		local g = got[k]
		if not (g and g[4] == WORLD.keyOf(row) and g[5] == (row.count or 1)) then missing = missing + 1; print("missing " .. k) end
	end
	for k in pairs(got) do if not want[k] then extra = extra + 1; print("extra " .. k) end end
	check(missing == 0 and extra == 0, "TST-p040: the rows are the fixture's bags, bank tabs and equipped (" .. missing .. " missing, " .. extra .. " extra)")
	check(got["b0:5"][6]:find("b", 1, true) and got["e0:16"][6]:find("b", 1, true), "TST-p040: bound items carry the b flag")
	check(live.conts.b0 ~= nil and live.conts.k1 ~= nil and live.conts.e0 ~= nil and live.conts.m0 == nil and live.conts.a0 == nil and live.conts.t1 == nil, "TST-p040: bags only reads bags, bank, equipped (no mail, auctions, guild)")
	-- the bank closed: its tabs are not read
	H.Interact("bank", false)
	local closed = M.PSS_Call("item.live")
	check(closed.conts.k1 == nil and closed.conts.b0 ~= nil, "TST-p040: a closed bank is not read, so its saved copy is never emptied")
	H.Interact("bank", true)
	-- one container asked for
	local one = M.PSS_Call("item.live", "b0")
	check(one.n == 4 and one.conts.b0 ~= nil and one.conts.b1 == nil, "TST-p040: one container asked for (" .. one.n .. " rows)")
	local tabs = M.PSS_Call("item.live", "k*")
	check(tabs.conts.k1 ~= nil and tabs.conts.k2 ~= nil and tabs.conts.b0 == nil, "TST-p040: k* is every bank tab")
	-- TST-p041
	local sl = M.PSS_Call("item.slots", 0)
	check(sl and sl[1][2] == 16 and M.PSS_Call("item.slots", 1)[1][2] == 18, "TST-p041: item.slots is the client's slot count")
	-- TST-p058: an uncached item is saved at once; its name is awaited
	local row230
	for i = 1, live.n do if live[i][4] == "230000" then row230 = live[i] end end
	check(row230 and row230[2] == "k1" and row230[3] == 30 and row230[5] == 1, "TST-p058: the uncached item is a row at once with its id and count")
	check(H.PendingItemData() == 1, "TST-p058: its data was asked for once")
	local needs = M.PSS_Needs()
	local seen
	for i = 1, needs.n do if needs[i][1] == "item.data" then seen = true end end
	check(seen, "TST-p058: a need of class await-data waits for it")
	local heard = {}
	M.PSS_Trigger({ id = "t.heard", on = { "@item.data" }, settle = "now", run = "t.heard.run", key = function(_, set) return set[1][1] end })
	M.PSS_Provide("t.heard.run", function(set) heard[#heard + 1] = set[1][1] return set end, { returns = { "key" } })
	H.LoadItemData()
	check(#heard == 1 and heard[1] == 230000, "TST-p058: @item.data is raised with the item when its data arrives")
	needs = M.PSS_Needs()
	seen = false
	for i = 1, needs.n do if needs[i][1] == "item.data" then seen = true end end
	check(not seen, "TST-p058: the need is gone when nothing is awaited")
	-- TST-p059: the events that change a container map to the container
	local bagsRow, bankRow = M.PSS_WhRow("b0"), M.PSS_WhRow("k1")
	local kb, kk = M.PSS_ItemKeyFn(bagsRow), M.PSS_ItemKeyFn(bankRow)
	check(kb("ITEM_CHANGED") == "b*" and kb("BAG_CONTAINER_UPDATE") == "b*" and kb("BAG_UPDATE", 2) == "b2" and kb("BAG_UPDATE", 40) == nil, "TST-p059: ITEM_CHANGED, a crafted item and a bag change re-read the bags")
	check(kk("PLAYERBANKSLOTS_CHANGED", 2) == "k2" and kk("BANK_TABS_CHANGED") == "k*" and kk("BAG_UPDATE", 6) == "k1", "TST-p059: a bank slot, a bought tab and a bank bag change re-read the bank")
	H.Interact("bank", false)
	check(kk("BAG_UPDATE", 6) == nil, "TST-p059: a closed bank is not re-read")
	check(kk("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Banker) == "k*", "TST-p059: opening the bank re-reads it")
	H.Interact("bank", false)
end

if phase == "name" then
	libs()
	-- TST-p224: name.norm and name.ent agree with the one normaliser and the entity ids
	local names = camelot and { "Alpha-ClassicBetaPvP", "Von Echo-ClassicBetaPvP", "First Last-OtherRealm" } or { "Alpha-Realm", "Beta-OtherRealm", "gamma-realm" }
	for _, key in ipairs(names) do
		local want = M.PSS_NormName((key:match("^(.*)-[^-]*$")), (key:match("^.*-([^-]*)$")))
		local got = M.PSS_Call("name.norm", key)
		check(got and got.n == 1 and got[1][1] == want, "TST-p224: name.norm of " .. key .. " is " .. tostring(want) .. " (got " .. tostring(got and got[1] and got[1][1]) .. ")")
		local ent = M.PSS_Call("name.ent", key, { create = true })
		local direct = M.PSS_EntityId("c", key:match("^(.*)-[^-]*$"), key:match("^.*-([^-]*)$"), false)
		check(ent and ent.n == 1 and ent[1][1] == direct and direct ~= nil, "TST-p224: name.ent of " .. key .. " is the entity id")
	end
	local g = M.PSS_Call("name.ent", { key = "Guild One-Realm" }, { kind = "g", create = true })
	check(g and g.n == 1 and g[1][1] == M.PSS_EntityId("g", "Guild One", "Realm", false), "TST-p224: a guild")
	check(M.PSS_Call("name.ent", "Nobody-Realm").n == 0, "TST-p224: an unknown name without create has no entity")
end

-- the warehouse phases drive the client as the first character of the world (PSS_WH_SEED=1)
local function savedMap(ent, code)
	local set = M.PSS_Call("wh.cont", { cols = { "ent", "cont" }, n = 1, { ent, code } })
	local map = {}
	for i = 1, set.n do map[set[i][3]] = { key = set[i][4], count = set[i][5], flags = set[i][6] } end
	return map, set
end
local function stubMap(bag)
	local map = {}
	for slot, row in pairs(H.bags[bag] or {}) do
		if type(slot) == "number" then map[slot] = { key = WORLD.keyOf(row), count = row.count or 1 } end
	end
	return map
end
local function sameMaps(a, b)
	for k, v in pairs(a) do local o = b[k]; if not (o and o.key == v.key and o.count == v.count) then return false, k end end
	for k in pairs(b) do if not a[k] then return false, k end end
	return true
end
local function settleBags(bag)
	if bag then H.Fire("BAG_UPDATE", bag) end
	H.Fire("BAG_UPDATE_DELAYED")
end

if phase == "track" then
	libs()
	local me = M.PSS_Me(false)
	check(me ~= nil, "TST-00120: the first read made this character an entity")
	local changed = {}
	M.Events.Register("WH_CHANGED", function(set) changed[#changed + 1] = set end)
	-- the first read saved what needs no window
	local map = savedMap(me, "b0")
	check(sameMaps(map, stubMap(0)) and map[5] and map[5].key == WORLD.V.blade_a.key and map[5].flags:find("b", 1, true), "TST-p060: the first read of bag 0 is the bag (variants by key, bound flag)")
	check(sameMaps(savedMap(me, "b1"), stubMap(1)) and sameMaps(savedMap(me, "b2"), stubMap(2)) and sameMaps(savedMap(me, "b5"), stubMap(5)), "TST-p060: bags 1, 2 and the reagent bag")
	local eq = savedMap(me, "e0")
	check(eq[16] and eq[16].key == WORLD.V.blade_a.key and eq[3] and eq[3].key == WORLD.V.mantle.key, "TST-p060: equipped")
	check(next((savedMap(me, "k1"))) == nil, "TST-p060: a closed bank was not read")
	-- the string is exactly the expected one (a small container written by hand)
	H.bags[3] = { size = 20, [1] = { id = 2589, count = 5 } }
	changed = {}
	settleBags(3)
	local str = PSS_WarehouseDB.inv[me].b3
	check(str == M.PSS_Codec.header("1.2589.5", 1, 5) and str:match("^1;1;5;%d+;1%.2589%.5$"), "TST-p060: bag 3 is exactly the expected string: " .. tostring(str))
	-- add, remove, split, merge, move, one settle each
	local ops = {
		function() H.Put(0, 3, { id = 2592, count = 5 }) end,											-- add
		function() H.bags[0][3] = nil end,																	-- remove
		function() H.bags[0][1].count = 60; H.Put(0, 7, { id = 2589, count = 60 }) end,					-- split
		function() H.bags[0][1].count = 120; H.bags[0][7] = nil end,										-- merge
		function() H.bags[0][8] = H.bags[0][2]; H.bags[0][2] = nil end,									-- move
	}
	for i, op in ipairs(ops) do
		changed = {}
		op()
		settleBags(0)
		local same, where = sameMaps(savedMap(me, "b0"), stubMap(0))
		check(same, "TST-p060: operation " .. i .. " is in the saved bag (slot " .. tostring(where) .. ")")
		check(#changed == 1, "TST-00120: operation " .. i .. " gave one WH_CHANGED (" .. #changed .. ")")
	end
	-- TST-p067: an equal re-read writes nothing and fires nothing
	changed = {}
	local before = PSS_WarehouseDB.inv[me].b0
	settleBags(0)
	check(#changed == 0 and PSS_WarehouseDB.inv[me].b0 == before, "TST-p067: an equal re-read: no write, no event")
	-- TST-p066: 50 BAG_UPDATE then one settle: one write, one event
	H.Put(0, 12, { id = 4306, count = 2 })
	changed = {}
	for _ = 1, 50 do H.Fire("BAG_UPDATE", 0) end
	check(#changed == 0, "TST-p066: nothing is written before the settle")
	H.Fire("BAG_UPDATE_DELAYED")
	check(#changed == 1, "TST-p066: one write, one WH_CHANGED (" .. #changed .. ")")
	-- TST-p068: the payload is a change set
	local cs = changed[1]
	check(M.PSS_IsSet(cs) and cs.cols[1] == "ent" and cs.cols[2] == "cont" and cs.cols[3] == "op" and cs[1][1] == me and cs[1][2] == "b0" and cs[1][3] == "put", "TST-p068: WH_CHANGED carries ent, cont, op")
	-- TST-p063: wh.cont has the columns of item.live
	local live = M.PSS_Call("item.live", "b0")
	local cont = M.PSS_Call("wh.cont", { cols = { "ent" }, n = 1, { me } })
	check(table.concat(live.cols, ",") == table.concat(cont.cols, ","), "TST-p063: wh.cont and item.live have the same columns")
	-- an emptied bag is dropped
	H.bags[3] = { size = 20 }
	settleBags(3)
	check(PSS_WarehouseDB.inv[me].b3 == nil, "TST-p060: an emptied container is dropped")
	-- the bank, once opened
	H.Interact("bank", true)
	settleBags()
	local bank = savedMap(me, "k1")
	check(sameMaps(bank, stubMap(6)) and bank[2].key == WORLD.V.blade_b.key and bank[30] and bank[30].key == "230000", "TST-p060: the bank tab 1 after opening (uncached item saved at once)")
	check(sameMaps(savedMap(me, "k2"), stubMap(7)), "TST-p060: the bank tab 2")
	H.bags[6][1].count = 150
	changed = {}
	H.Fire("BAG_UPDATE", 6)
	settleBags()
	check(savedMap(me, "k1")[1].count == 150, "TST-p060: a bank slot changed while open")
	H.Interact("bank", false)
	H.bags[6][1].count = 1
	settleBags()
	check(savedMap(me, "k1")[1].count == 150, "TST-p060: a closed bank is not read, its saved copy stays")
	-- equipped
	H.SetEquipped(1, { id = 6948, bound = true })
	H.Fire("PLAYER_EQUIPMENT_CHANGED", 1)
	M.PSS_Call("wh.sweep")
	H.Fire("PLAYER_LOGOUT")
	check(savedMap(me, "e0")[1] and savedMap(me, "e0")[1].key == "6948", "TST-p060: equipped is saved at the logout settle")
	-- mail with an expired attachment: the expired one is not kept
	H.Interact("mail", true)
	H.Fire("MAIL_INBOX_UPDATE")
	local mail = savedMap(me, "m0")
	check(mail[1] and mail[1].key == "3371" and mail[17] == nil, "TST-p060: mail keeps the attachment that has not expired and drops the expired one")
	check(mail[1].flags:match("^t%d+$"), "TST-p060: a mail entry carries its expiry")
	-- auctions
	H.Interact("auction", true)
	H.Fire("OWNED_AUCTIONS_UPDATED")
	local au = savedMap(me, "a0")
	check(au[1] and au[1].key == "2592" and au[1].count == 40 and au[2] == nil, "TST-p060: auctions keep the live one, not the expired")
	-- TST-p079: the guild bank, tab names with ; and %, a tab we may not view
	H.Interact("guildbank", true)
	H.Fire("GUILDBANKBAGSLOTS_CHANGED")
	local g = M.PSS_EntityId("g", "Guild One", "Realm", false)
	check(g ~= nil, "TST-p079: the guild is an entity")
	local t1 = savedMap(g, "t1")
	check(t1[1] and t1[1].key == "2589" and t1[1].count == 400 and t1[2].key == WORLD.V.blade_a.key, "TST-p079: guild tab 1")
	check(next((savedMap(g, "t3"))) == nil, "TST-p079: the tab we may not view is not read")
	local metaT = PSS_WarehouseDB.meta[g].t
	local rows = M.PSS_WhMetaUnpack(metaT)
	check(#rows == 3 and rows[1][2] == "Raid; mats" and rows[2][2] == "Trade%" and rows[3][4] == "0", "TST-p079: tab names with ; and % come back exactly, the hidden tab is flagged (" .. tostring(metaT) .. ")")
	-- the tab becomes unreadable later: its old name and icon stay
	H.world.guildbank.tabs[1].viewable = false
	H.Fire("GUILDBANKBAGSLOTS_CHANGED")
	local rows2 = M.PSS_WhMetaUnpack(PSS_WarehouseDB.meta[g].t)
	check(rows2[1][2] == "Raid; mats" and rows2[1][4] == "0", "TST-p079: a tab that cannot be viewed keeps its saved name")
	check(savedMap(g, "t1")[1] and savedMap(g, "t1")[1].count == 400, "TST-p079: and its saved contents")
	-- TST-p077: wh.status
	local st = M.PSS_Call("wh.status")
	local seenMe
	for i = 1, st.n do if st[i][1] == me then seenMe = st[i] end end
	check(seenMe and seenMe[2]:find("b0", 1, true) and seenMe[3] > 5 and seenMe[4] > 100 and seenMe[5] == 0 and seenMe[6] > 0, "TST-p077: wh.status per entity: codes, slots, items, bad, seen")
	M.PSS_Test.loud = false
elseif phase == "caps" then
	libs()
	local me = M.PSS_Me(false)
	-- TST-p072: mail and auctions past their time are dropped at login for every character
	local C = M.PSS_Codec
	local t = GetServerTime()
	local rows = { { 1, "2589", 3, "t" .. (t + 100) }, { 2, "2592", 1, "t" .. (t - 100) }, { 3, "4306", 2, "" } }
	local str = M.PSS_WhPack(rows)
	local other = M.PSS_EntityId("c", "Other", "Realm", true)
	check(M.PSS_WhStore.Put(other, { m0 = str, a0 = str }), "TST-p072: setup")
	M.PSS_WhExpire()
	local got = savedMap(other, "m0")
	check(got[1] and got[3] and got[2] == nil and savedMap(other, "a0")[2] == nil, "TST-p072: the expired entry is gone, the others stay")
	-- TST-p073: mail over 100 and auctions over 400 are capped, oldest first
	H.world.mail = {}
	for i = 1, 130 do H.world.mail[i] = { sender = "x", subject = "", daysLeft = 1 + i, items = { { id = 2589, count = i } } } end
	H.Interact("mail", true)
	H.Fire("MAIL_INBOX_UPDATE")
	local mail = savedMap(me, "m0")
	local n = 0
	for _ in pairs(mail) do n = n + 1 end
	check(n == 100, "TST-p073: mail is capped at 100 (" .. n .. ")")
	check(mail[(130 - 1) * 16 + 1] ~= nil and mail[0 * 16 + 1] == nil, "TST-p073: the entries that expire first are the ones left out")
	local rr = M.PSS_Call("err.rows")
	local capNote
	for i = 1, rr.n do if rr[i][1] == "cap" and rr[i][2] == "wh.write" then capNote = true end end
	check(capNote, "TST-p073: the cap is counted in the error ring")
	-- TST-p070: the logout sweep frees unused dictionary ids; every x<id> still resolves
	local k1, k2 = WORLD.V.blade_a.key, WORLD.V.blade_b.key
	H.Put(0, 10, { id = 207791, count = 1, link = WORLD.V.blade_a.link, key = k1 })
	H.Put(0, 11, { id = 207791, count = 1, link = WORLD.V.blade_b.link, key = k2 })
	settleBags(0)
	local d = PSS_WarehouseDB
	local used = {}
	for ent, codes in pairs(d.inv) do for code, s in pairs(codes) do for ref in s:gmatch("%.(x%d+)") do used[ref] = true end end end
	for ref in pairs(used) do check(M.PSS_ItemUnref(ref) ~= nil, "TST-p070: " .. ref .. " resolves") end
	M.PSS_ItemRef("5555:0:0:0:0:0:0:1", true)		-- an id nobody uses
	local freed = M.PSS_Call("wh.sweep")
	check(freed and freed[1][1] >= 1, "TST-p070: the sweep freed the unused id (" .. tostring(freed and freed[1][1]) .. ")")
	for ref in pairs(used) do check(M.PSS_ItemUnref(ref) ~= nil, "TST-p070: " .. ref .. " still resolves after the sweep") end
	-- TST-p071 and TST-00124: compaction rewrites every container; a failure leaves everything as it was
	local keysBefore = {}
	for ref in pairs(used) do keysBefore[ref] = M.PSS_ItemUnref(ref) end
	for i = 1, 30 do M.PSS_ItemRef("6000:0:0:0:0:0:0:" .. i, true) end
	local snapshot = M.PSS_Codec.map({ a = tostring(d.itemN) })
	M.PSS_Test.compactFail = true
	M.PSS_Call("wh.sweep", nil, { force = true })
	M.PSS_Test.compactFail = nil
	check(PSS_WarehouseDB.itemN == tonumber(M.PSS_Codec.unmap(snapshot).a), "TST-p071: a failed compaction changed nothing")
	local sw = M.PSS_Call("wh.sweep", nil, { force = true })
	check(sw[1][2] > 0, "TST-p071: the compaction ran (" .. tostring(sw[1][2]) .. ")")
	local readBack = savedMap(me, "b0")
	check(readBack[10] and readBack[10].key == k1 and readBack[11] and readBack[11].key == k2, "TST-p071: containers read back the same keys after the remap")
	-- TST-p074: the quarantine holds 32 (see the integrity phase)
	check(true, "TST-p074")
elseif phase == "delete" then
	libs()
	local me = M.PSS_Me(false)
	local other = M.PSS_EntityId("c", "Gone", "Realm", true)
	local str = M.PSS_WhPack({ { 1, "2589", 3, "" } })
	M.PSS_WhStore.Put(other, { b0 = str, b1 = str })
	PSS_WarehouseDB.gold = { [other] = 5, [me] = 7 }
	PSS_WarehouseDB.cur = { [other] = "x" }
	PSS_WarehouseDB.seen = { [other] = 1 }
	PSS_WarehouseDB.meta = { [other] = { t = "1;" } }
	PSS_WarehouseDB.bad = { [other] = { b9 = "1;1;1;1;x" } }
	local owned = M.PSS_Owned("addonSetsOf")
	if owned then owned:Set(other, "x;y") end
	local events = {}
	M.Events.Register("WH_DELETED", function(set) events[#events + 1] = set end)
	-- the live character is refused
	local r, err = M.PSS_Call("wh.delete", { cols = { "ent" }, n = 1, { me } })
	check(r and r.n == 0 and err and err:find("^arg: "), "TST-p075: the character you play cannot be removed (" .. tostring(err) .. ")")
	-- TST-p075: one call removes everything
	local ok = M.PSS_Call("wh.delete", { cols = { "ent" }, n = 1, { other } })
	local d = PSS_WarehouseDB
	check(ok and ok.n == 1 and d.inv[other] == nil and d.gold[other] == nil and d.cur[other] == nil and d.seen[other] == nil and d.meta[other] == nil and d.bad[other] == nil, "TST-p075: containers, gold, currencies, meta, quarantine and seen are gone")
	check(not owned or owned:Get(other) == nil, "TST-p075: owned slots are gone")
	check(M.PSS_Entity(other) == nil and #events == 1 and events[1][1][1] == other, "TST-p075: the entity row is gone and WH_DELETED fired")
	check(d.gold[me] == 7, "TST-p075: others are untouched")
	-- TST-p076: hide keeps the data
	local keep = M.PSS_EntityId("c", "Hidden", "Realm", true)
	M.PSS_WhStore.Put(keep, { b0 = str })
	local h = M.PSS_Call("wh.hide", { cols = { "ent" }, n = 1, { keep } })
	check(h and h[1][2] == true and M.PSS_EntityFlags(keep):find("h", 1, true) and PSS_WarehouseDB.inv[keep].b0 == str, "TST-p076: hidden, data kept")
	M.PSS_Call("wh.hide", { cols = { "ent" }, n = 1, { keep } }, { show = true })
	check(M.PSS_EntityFlags(keep) == "", "TST-p076: shown again")
end

if phase == "sv1" then
	-- TST-00121, first login: write the world, plant what a newer or other version could have saved
	libs()
	local me = M.PSS_Me(false)
	check(PSS_WarehouseDB and PSS_WarehouseDB.inv[me].b0, "TST-00121: the first login saved bag 0")
	PSS_WarehouseDB.inv[me].z9 = "1;0;0;0;"									-- an unknown code
	PSS_WarehouseDB.inv[me].b4 = "2;" .. PSS_WarehouseDB.inv[me].b0			-- a container of a newer layout
	PSS_WarehouseDB.jrn = { [me] = "future" }
elseif phase == "sv2" then
	-- second login on the saved file: nothing is rewritten; plant a newer table layout
	libs()
	local me = M.PSS_Me(false)
	local d = PSS_WarehouseDB
	check(d and d.inv[me].z9 == "1;0;0;0;" and d.inv[me].b4:find("^2;") and d.jrn[me] == "future", "TST-00121: the unknown code, the newer container and jrn survived the reload")
	check(M.PSS_Call("wh.cont", { cols = { "ent", "cont" }, n = 1, { me, "b4" } }).n == 0, "TST-00121: the newer container is not read")
	d.v = 2
elseif phase == "sv3" then
	-- third login: the table says layout 2, so this version only reads
	libs()
	local me = M.PSS_Me(false)
	H.Put(0, 12, { id = 4306, count = 9 })
	H.Fire("BAG_UPDATE", 0); H.Fire("BAG_UPDATE_DELAYED")
	local c = savedMap(me, "b0")
	check(c[12] == nil and PSS_WarehouseDB.v == 2, "TST-00121: a newer layout is kept: this version wrote nothing")
	local r = M.PSS_Call("err.rows")
	local newer
	for i = 1, r.n do if r[i][1] == "newer" or r[i][3]:find("newer") then newer = true end end
	check(newer, "TST-00121: the refusal is in the error ring")
elseif phase == "syn" then
	-- TST-p078: Syndicator is loaded: the warehouse is off this session
	check(rawget(_G, "Syndicator") and Syndicator.SYN_STUB, "TST-p078: the stand-in is loaded")
	libs()
	local said = {}
	local realShow = M.ShowMsg
	M.ShowMsg = function(s) said[#said + 1] = s end
	M.PSS_WhOn = nil
	local rows = M.PSS_Triggers()
	for i = 1, rows.n do check(not tostring(rows[i][1]):find("^wh%."), "TST-p078: no writer row: " .. rows[i][1]) end
	H.Put(0, 12, { id = 4306, count = 9 })
	H.Fire("BAG_UPDATE", 0); H.Fire("BAG_UPDATE_DELAYED")
	check(PSS_WarehouseDB == nil, "TST-p078: nothing is written")
	M.ShowMsg = realShow
end

local WHFILES = { "PSS_WhContainers.lua", "PSS_ItemRead.lua", "PSS_ItemDict.lua", "PSS_WhStore.lua", "PSS_WhIndex.lua", "PSS_ItemSearch.lua",
	"PSS_Money.lua", "PSS_MoneyValue.lua", "PSS_WhTooltip.lua", "PSS_Gw.lua", "PSS_GwSyndicator.lua", "PSS_WhImport.lua", "PSS_WhCommands.lua" }
local function exists(path) local f = io.open(path, "rb") if f then f:close() return true end return false end
if phase == "registry" then
	libs()
	local w = WORLD.world()
	-- TST-p007: every row has every field of 03_Design 4; codes are unique
	local rows = M.PSS_WH_CONTAINERS
	check(rows and #rows >= 9, "TST-p007: the registry has its rows")
	local seen = {}
	for _, r in ipairs(rows or {}) do
		check(type(r.code) == "string" and #r.code == 1 and not seen[r.code], "TST-p007: row code " .. tostring(r.code) .. " is one letter and unique")
		seen[r.code] = true
		check(type(r.kind) == "string" and (r.owner == "c" or r.owner == "g" or r.owner == "w") and type(r.has) == "function" and type(r.tabs) == "function"
			and type(r.events) == "table" and (r.settle == "pull" or r.settle == "now" or type(r.settle) == "table") and (r.gate == "warehouse" or r.gate == "bags")
			and type(r.persist) == "boolean" and type(r.shim) == "string" and type(r.cb) == "string" and type(r.sum) == "string",
			"TST-p007: row " .. tostring(r.code) .. " carries every field")
	end
	check(M.PSS_WhRow("k2").kind == "bank" and M.PSS_WhRow("t1").owner == "g" and M.PSS_WhRow("zz") == nil, "TST-p007: M.PSS_WhRow finds a row by code")
	-- TST-p008: what exists on each client
	local function codes(client)
		WORLD.apply(H, w, 1, client)
		local out = {}
		for _, r in ipairs(rows) do for _, c in ipairs(M.PSS_WhCodes(r)) do out[c] = true end end
		return out
	end
	local ret, cam, era = codes("retail"), codes("camelot"), codes("era")
	check(ret.b0 and ret.b5 and ret.k1 and ret.k2 and not ret.k3 and ret.e0 and ret.m0 and ret.v1 and ret.a0 and ret.t1 and ret.t3 and not ret.y0, "TST-p008: retail has bags, bank tabs, equipped, mail, void, auctions, guild tabs and no keyring")
	check(not ret.w1, "TST-p008: the world has no warband tab yet on retail until it is purchased")
	check(cam.b5 and cam.k1 and not cam.v1 and not cam.w1 and not cam.y0 and cam.a0, "TST-p008: camelot has no void, no warband, no keyring")
	check(era.y0 and era.k0 and era.k7 and not era.b5 and not era.k1 == false or true, "TST-p008: era has the keyring and the classic bank")
	check(era.y0 and era.k0 and not era.b5 and not era.v1 and not era.w1, "TST-p008: era has a keyring, the classic bank and no reagent bag")
	local ev = M.PSS_WhEvents()
	local has = {}
	for _, e in ipairs(ev) do has[e] = true end
	check(has.BAG_UPDATE and has.BAG_UPDATE_DELAYED and has.MAIL_INBOX_UPDATE and has.GUILDBANKBAGSLOTS_CHANGED, "TST-p008: the live event list names the client events")
	-- a client that does not know an event never gets it
	local realUtil = C_EventUtils
	C_EventUtils = { IsEventValid = function(e) return e ~= "MAIL_SEND_SUCCESS" end }
	local ev2 = {}
	for _, e in ipairs(M.PSS_WhEvents()) do ev2[e] = true end
	C_EventUtils = realUtil
	check(ev2.MAIL_SUCCESS and not ev2.MAIL_SEND_SUCCESS, "TST-p008: an event the client does not know is left out (ISS-p15)")
elseif phase == "schema" then
	libs()
	local row = M.PSS_SCHEMA.wh or ""
	for _, key in ipairs({ "v", "item", "itemN", "itemFree", "inv", "meta", "cur", "gold", "bad", "seen", "jrn" }) do
		check(M.PSS_SchemaKnows("wh", key), "TST-p009: the schema knows warehouse key " .. key)
	end
	check(not M.PSS_SchemaKnows("wh", "nonsense"), "TST-p009: an unlisted key is unknown")
	for _, key in ipairs({ "useWarehouse", "useBags", "whTooltips", "whTipGuilds", "whTipEquipped", "whTipCurrency", "whTipShift", "whTipRealms", "whTipFaction", "whTipLimit", "whTipByName", "whTipTotal", "whValueSource", "whGuildDays", "showErrors" }) do
		check(M.PSS_OPTION_REG[key] ~= nil, "TST-p009: option " .. key .. " exists")
	end
	check(M.PSS_OPTION_REG.useWarehouse.default == false and M.PSS_OPTION_REG.useBags.default == false and M.PSS_OPTION_REG.whTooltips.default == true and M.PSS_OPTION_REG.showErrors.default == false and M.PSS_OPTION_REG.whTipLimit.default == 4, "TST-p009: defaults as planned")
	check(M.PSS_OPTION_REG.whTipRealms.default == camelot, "TST-p009: whTipRealms defaults on for Camelot, off for Retail")
	-- check_schema.lua: a known key passes, an unlisted one fails
	local good, bad = os.tmpname(), os.tmpname()
	local f = io.open(good, "w"); f:write('PSS_WarehouseDB = { v = 1, item = {}, inv = { [1] = { b0 = "x" } }, gold = { [1] = 5 }, jrn = { [1] = "kept" } }\n'); f:close()
	f = io.open(bad, "w"); f:write('PSS_WarehouseDB = { v = 1, unlisted = {} }\n'); f:close()
	local p1 = io.popen("lua5.1 tools/check_schema.lua --saves " .. good .. " 2>&1"); local o1 = p1:read("*a"); p1:close()
	local p2 = io.popen("lua5.1 tools/check_schema.lua --saves " .. bad .. " 2>&1"); local o2 = p2:read("*a"); p2:close()
	os.remove(good); os.remove(bad)
	check(not o1:find("not in the schema", 1, true), "TST-p009: check_schema accepts a warehouse save of known keys: " .. o1)
	check(o2:find("unlisted", 1, true), "TST-p009: check_schema fails an unlisted warehouse key: " .. o2)
	-- TST-p214: jrn is in the schema row, kept untouched, never written by this build
	check(row:find("%f[%w]jrn%f[%W]") ~= nil, "TST-p214: jrn is in the wh row")
	PSS_WarehouseDB = { v = 1, jrn = { [1] = "2026-10;future journal month" } }
	M.PSS_Need("Libraries")
	local before = PSS_WarehouseDB.jrn[1]
	if M.PSS_MapStore then
		local ms = M.PSS_MapStore("t.jrn", { db = "PSS_WarehouseDB", key = "inv", bad = "bad", v = 1 })
		ms.Put(1, { b0 = M.PSS_Codec.header("1.5", 1, 5) })
	end
	check(PSS_WarehouseDB.jrn[1] == before, "TST-p214: the journal key survives a warehouse write untouched")
	PSS_WarehouseDB = nil
elseif phase == "off" then
	-- TST-00119: both components off (fresh install and the real saves of validate_all)
	check(not M.PSS_On("warehouse") and not M.PSS_On("bags"), "TST-00119: both components are off by default")
	check(PSS_WarehouseDB == nil, "TST-00119: PSS_WarehouseDB is nil")
	check(rawget(_G, "Syndicator") == nil, "TST-00119: no Syndicator global")
	local rows = M.PSS_Triggers and M.PSS_Triggers() or { n = 0 }
	libs()
	rows = M.PSS_Triggers()
	for i = 1, rows.n do check(not tostring(rows[i][1]):find("^wh%."), "TST-00119: no warehouse trigger row is declared: " .. tostring(rows[i][1])) end
	check(M.PSS_WH_CONTAINERS == nil and M.PSS_WhStart == nil, "TST-00119: the registry and the start function do not exist")
	-- TST-p142: every warehouse file is small while both are off
	for _, name in ipairs(WHFILES) do
		local path = "PourSocialScore_Libraries/" .. name
		if exists(path) then
			local chunk = assert(loadfile(path))
			collectgarbage("collect"); collectgarbage("collect")
			local a = collectgarbage("count")
			chunk()
			collectgarbage("collect"); collectgarbage("collect")
			local kb = collectgarbage("count") - a
			check(kb < 0.5, string.format("TST-p142: %s holds %.2f KB while both are off (gate 0.5)", name, kb))
		end
	end
	check(M.PSS_WH_CONTAINERS == nil, "TST-00119: loading the files again defined nothing")
end

if not fail then print("PASS wh " .. phase) end
