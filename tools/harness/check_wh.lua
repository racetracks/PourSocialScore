-- The warehouse checks (warehouse-helper, one-build plan), as a run.lua
-- script. The phase is PSS_PHASE; each prints "PASS wh <phase>" or "FAIL
-- wh: <phase>: <what>". Run on Retail and on Camelot (PSS_CAMELOT=1) by
-- wh_phases.sh. Expected results come from the plan (03_Design, 05_Tests),
-- not from the code. Phases are added with their packages:
--   stub (TST-p001..p006)
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

if not fail then print("PASS wh " .. phase) end
