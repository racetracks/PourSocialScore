-- The warehouse client for the harness (warehouse-helper, one-build plan,
-- STP-p00): every client API the warehouse reads, behind stub.SeedWorld(spec).
-- Nothing here exists until SeedWorld runs, so every older phase sees the
-- stub it always saw. The shapes follow the client calls Syndicator 286
-- documents in its tracking files (behaviour learned, nothing copied).
--
-- spec = {
--   client = "retail" | "camelot" | "era"   (default: PSS_CAMELOT=1 gives camelot)
--   player = { name, realm, faction, class, race, sex, guid, guild, guildRealm },
--   money, accountMoney,
--   items = { [id] = { name, quality, price, class, sub, icon, ... , unknown } },
--   bags  = { [bagID] = { size = n, [slot] = { id, count, link, bound, hasLoot, quality } } },
--   bankTabs = { { name, icon, depositFlags } }, accountTabs = { ... },
--   equipped = { [slot] = { id, link, quality, count, bound } },
--   mail = { { sender, subject, money, daysLeft, items = { { id, count, link, quality } } } },
--   void = { [page] = { [slot] = { id, link, quality } } },
--   auctions = { { id, link, count, quality, time } },
--   guildbank = { money, tabs = { { name, icon, viewable, items = { [slot] = { id, count, link, quality } } } } },
--   currencies = { { id, name, quantity, icon, shared, header } },
-- }
-- Mutate with stub.Put(bagID, slot, row), stub.SetEquipped(slot, row), the
-- fields of stub.world, then stub.Fire the event the client would fire.
-- stub.Interact(kind, on) opens or closes bank | mail | guildbank | void |
-- auction | account. stub.LoadItemData() answers every pending request.
return function(stub)
	local camelotEnv = os.getenv("PSS_CAMELOT") == "1"
	local W = {}
	stub.world = W

	local BI = {
		Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
		Keyring = -2, Bank = -1, Reagentbank = -3,
		BankBag_1 = 5, BankBag_2 = 6, BankBag_3 = 7, BankBag_4 = 8, BankBag_5 = 9, BankBag_6 = 10, BankBag_7 = 11,
	}
	for i = 1, 9 do BI["CharacterBankTab_" .. i] = 5 + i; BI["AccountBankTab_" .. i] = 14 + i end

	local function flags(client)
		local f = { client = client }
		f.tabs = client ~= "era"			-- character bank tabs (C_Bank)
		f.warband = client == "retail"
		f.reagentBag = client ~= "era"
		f.keyring = client == "era"
		f.modernAH = client == "retail"
		f.reagentBank = false
		f.void = client == "retail"
		return f
	end

	local loadQueue, requested = {}, {}

	local function itemLink(id)
		local it = stub.items[id]
		return ("|cffffffff|Hitem:%d::::::::|h[%s]|h|r"):format(id, it and it.name or "Item" .. id)
	end

	local function linkId(link)
		return tonumber(tostring(link):match("item:(%d+)")) or tonumber(tostring(link):match("battlepet:(%d+)")) and 82800
	end

	local function cached(id)
		local it = stub.items[id]
		return it ~= nil and not it.unknown
	end

	local function rowInfo(row)
		if not row then return nil end
		local it = stub.items[row.id] or {}
		return { iconFileID = it.icon or 134400, stackCount = row.count or 1, quality = row.quality or it.quality or 0,
			hyperlink = row.link or itemLink(row.id), itemID = row.id, hasNoValue = row.noValue or (it.price or 0) == 0,
			isBound = row.bound == true, hasLoot = row.hasLoot }
	end

	function stub.SetMoney(c, account, guild)
		if c ~= nil then W.money = c end
		if account ~= nil then W.accountMoney = account end
		if guild ~= nil and W.guildbank then W.guildbank.money = guild end
	end

	function stub.SeedWorld(spec)
		spec = spec or {}
		local f = flags(spec.client or (camelotEnv and "camelot" or "retail"))
		W.flags = f
		W.player = spec.player or { name = "Tester", realm = camelotEnv and "ClassicBetaPvP" or "Realm", faction = "Alliance", class = "MAGE", race = "Human", sex = 2 }
		W.money, W.accountMoney = spec.money or 0, spec.accountMoney or 0
		W.equipped, W.mail, W.void = spec.equipped or {}, spec.mail or {}, spec.void or {}
		W.auctions, W.guildbank, W.currencies = spec.auctions or {}, spec.guildbank, spec.currencies or {}
		-- the client's lists do not hold what has run out: an auction past its time, a mail with no days left
		local function live(list, gone)
			local out = {}
			for _, x in pairs(list) do if not gone(x) then out[#out + 1] = x end end
			return out
		end
		W.mail = live(W.mail, function(m) return (m.daysLeft or 30) <= 0 end)
		W.auctions = live(W.auctions, function(a) return (a.time or 3600) <= 0 end)
		W.bankTabs, W.accountTabs = spec.bankTabs or {}, spec.accountTabs or {}
		W.open = {}
		for id, it in pairs(spec.items or {}) do stub.items[id] = it end
		stub.bags = spec.bags or {}
		loadQueue, requested = {}, {}

		-- identity
		local p = W.player
		function UnitName(u) if u == "player" then return p.name, nil end return nil end
		function UnitFullName(u) if u == "player" then return p.name, p.realm end return nil end
		function GetUnitName(u) if u == "player" then return p.name end return nil end
		function UnitGUID(u) if u == "player" then return p.guid or "Player-1-0001" end return nil end
		function UnitFactionGroup(u) return p.faction or "Alliance", p.faction or "Alliance" end
		function UnitClass() local t = p.class or "MAGE"; return t:sub(1, 1) .. t:sub(2):lower(), t, 8 end
		function UnitRace() return p.race or "Human", p.race or "Human" end
		function UnitSex() return p.sex or 2 end
		function GetRealmName() return p.realm end
		function GetNormalizedRealmName() return (p.realm:gsub("%s", "")) end
		function IsInGuild() return p.guild ~= nil end
		function GetGuildInfo(u) if u == "player" and p.guild then return p.guild, "Member", 1, p.guildRealm end return nil end
		function GetMoney() return W.money end

		-- enums
		rawset(Enum, "BagIndex", setmetatable({}, { __index = function(_, k)
			if (not f.tabs and (k:find("^CharacterBankTab") or k:find("^AccountBankTab"))) or (not f.reagentBag and k == "ReagentBag") then return nil end
			if f.tabs and (k == "Bank" or k:find("^BankBag")) then return nil end
			if not f.keyring and k == "Keyring" then return nil end
			return BI[k]
		end }))
		rawset(Enum, "BankType", { Character = 0, Guild = 1, Account = 2 })
		rawset(Enum, "PlayerInteractionType", { Banker = 8, MailInfo = 17, GuildBanker = 10, VoidStorageBanker = 26, Auctioneer = 21, AccountBanker = 68 })
		rawset(Enum, "TooltipDataType", { Item = 0, Currency = 5, Unit = 2, Spell = 1 })
		rawset(Enum, "ItemQuality", { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 })
		NUM_BAG_SLOTS = 4
		ATTACHMENTS_MAX_RECEIVE = 16
		WOW_PROJECT_CLASSIC = 2

		-- containers (bags, bank, bank tabs, warband tabs, keyring share one table)
		C_Container.GetContainerNumSlots = function(bag)
			local b = stub.bags[bag]
			return b and (b.size or 20) or 0
		end
		C_Container.GetContainerItemInfo = function(bag, slot) return rowInfo(stub.bags[bag] and stub.bags[bag][slot]) end
		C_Container.ContainerIDToInventoryID = function(i) return 19 + i end
		function BankButtonIDToInvSlotID(i) return 67 + i end

		-- item data
		C_Item.DoesItemExist = function(loc)
			if loc.bagID then return stub.bags[loc.bagID] ~= nil and stub.bags[loc.bagID][loc.slotIndex] ~= nil end
			return W.equipped[loc.equipmentSlotIndex] ~= nil
		end
		C_Item.GetItemID = function(loc)
			local r = loc.bagID and stub.bags[loc.bagID] and stub.bags[loc.bagID][loc.slotIndex] or W.equipped[loc.equipmentSlotIndex]
			return r and r.id
		end
		C_Item.IsItemDataCachedByID = cached
		C_Item.IsBound = function(loc)
			local r = loc.bagID and stub.bags[loc.bagID] and stub.bags[loc.bagID][loc.slotIndex] or W.equipped[loc.equipmentSlotIndex]
			return r and r.bound == true or false
		end
		C_Item.GetItemInfoInstant = function(x)
			local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
			local it = id and stub.items[id]
			if not it then return nil end
			return id, "Weapon", "Misc", it.equip or "", it.icon or 134400, it.class or 15, it.sub or 0
		end
		C_Item.RequestLoadItemDataByID = function(id)
			if not requested[id] then requested[id] = true; loadQueue[#loadQueue + 1] = id end
		end
		C_Item.GetItemCount = function(id)
			local n = 0
			for _, b in pairs(stub.bags) do for s, r in pairs(b) do if type(s) == "number" and r.id == id then n = n + (r.count or 1) end end end
			return n
		end

		-- equipped
		function GetInventoryItemID(u, slot) local r = u == "player" and W.equipped[slot]; return r and r.id or nil end
		function GetInventoryItemLink(u, slot) local r = u == "player" and W.equipped[slot]; return r and (r.link or itemLink(r.id)) or nil end
		function GetInventoryItemTexture(u, slot) local r = u == "player" and W.equipped[slot]; return r and ((stub.items[r.id] or {}).icon or 134400) or nil end
		function GetInventoryItemQuality(u, slot) local r = u == "player" and W.equipped[slot]; return r and (r.quality or (stub.items[r.id] or {}).quality or 0) or nil end
		function GetInventoryItemCount(u, slot) local r = u == "player" and W.equipped[slot]; return r and (r.count or 1) or 0 end

		-- bank tabs and account money
		if f.tabs then
			C_Bank = {
				FetchPurchasedBankTabData = function(t)
					local src = t == Enum.BankType.Account and W.accountTabs or W.bankTabs
					local out = {}
					for i, tab in ipairs(src) do out[i] = { name = tab.name or "", icon = tab.icon or 134400, depositFlags = tab.depositFlags or 0, ID = i } end
					return out
				end,
				FetchBankLockedReason = function(t)
					if t == Enum.BankType.Account and not f.warband then return 1 end
					return nil
				end,
				FetchDepositedMoney = function(t) return W.accountMoney end,
				CanViewBank = function() return true end,
				ShouldUsePlayerBagsInBank = function() return false end,
			}
		else
			C_Bank = nil
			function IsReagentBankUnlocked() return false end
		end

		-- interaction
		C_PlayerInteractionManager = {
			IsInteractingWithNpcOfType = function(kind) return W.open[kind] == true end,
		}

		-- mail
		function GetInboxNumItems() return #W.mail, #W.mail end
		function GetInboxHeaderInfo(i)
			local m = W.mail[i]
			if not m then return end
			return 1, 1, m.sender or "Someone", m.subject or "", m.money or 0, 0, m.daysLeft or 30, #(m.items or {}) > 0
		end
		function GetInboxItem(i, a)
			local it = W.mail[i] and W.mail[i].items and W.mail[i].items[a]
			if not it then return end
			local d = stub.items[it.id] or {}
			return d.name or "Item", it.id, d.icon or 134400, it.count or 1, it.quality or d.quality or 0, true
		end
		function GetInboxItemLink(i, a)
			local it = W.mail[i] and W.mail[i].items and W.mail[i].items[a]
			return it and (it.link or itemLink(it.id)) or nil
		end

		-- auctions
		if f.modernAH then
			C_AuctionHouse = {
				GetNumOwnedAuctions = function() return #W.auctions end,
				GetOwnedAuctionInfo = function(i)
					local a = W.auctions[i]
					if not a then return nil end
					return { auctionID = a.auctionID or i, itemKey = { itemID = a.id }, itemLink = a.link or itemLink(a.id), quantity = a.count or 1,
						timeLeftSeconds = a.time or 3600, status = 0 }
				end,
				QueryOwnedAuctions = function() end,
				GetItemKeyFromItem = function() return {} end,
				GetAuctionInfoByID = function() return nil end,
			}
			GetNumAuctionItems, GetAuctionItemInfo, GetAuctionItemLink = nil, nil, nil
		else
			C_AuctionHouse = nil
			function GetNumAuctionItems(l) return l == "owner" and #W.auctions or 0 end
			function GetAuctionItemInfo(l, i)
				local a = W.auctions[i]
				if not a then return end
				local d = stub.items[a.id] or {}
				return d.name or "Item", d.icon or 134400, a.count or 1, a.quality or d.quality or 0
			end
			function GetAuctionItemLink(l, i) local a = W.auctions[i]; return a and (a.link or itemLink(a.id)) or nil end
			function GetAuctionItemTimeLeft(l, i)
				local t = W.auctions[i] and W.auctions[i].time or 3600
				return t <= 1800 and 1 or t <= 7200 and 2 or t <= 43200 and 3 or 4
			end
		end

		-- void
		if f.void then
			function CanUseVoidStorage() return true end
			function GetVoidItemInfo(page, slot)
				local r = W.void[page] and W.void[page][slot]
				if not r then return nil end
				local d = stub.items[r.id] or {}
				return r.id, d.icon or 134400, false, false, false, r.quality or d.quality or 0
			end
			function GetVoidItemHyperlinkString(n)
				local page, slot = math.floor((n - 1) / 80) + 1, (n - 1) % 80 + 1
				local r = W.void[page] and W.void[page][slot]
				return r and (r.link or itemLink(r.id)) or nil
			end
		else
			CanUseVoidStorage, GetVoidItemInfo, GetVoidItemHyperlinkString = nil, nil, nil
		end

		-- guild bank
		function GetNumGuildBankTabs() return W.guildbank and #(W.guildbank.tabs or {}) or 0 end
		function GetGuildBankTabInfo(t)
			local tab = W.guildbank and W.guildbank.tabs[t]
			if not tab then return end
			return tab.name or "", tab.icon or 134400, tab.viewable ~= false, true, 0, 0
		end
		function GetGuildBankItemInfo(t, s)
			local tab = W.guildbank and W.guildbank.tabs[t]
			local r = tab and tab.items and tab.items[s]
			if not r then return nil end
			local d = stub.items[r.id] or {}
			return d.icon or 134400, r.count or 1, false, false, r.quality or d.quality or 0
		end
		function GetGuildBankItemLink(t, s)
			local tab = W.guildbank and W.guildbank.tabs[t]
			local r = tab and tab.items and tab.items[s]
			return r and (r.link or itemLink(r.id)) or nil
		end
		function GetGuildBankMoney() return W.guildbank and W.guildbank.money or 0 end
		function GetCurrentGuildBankTab() return 1 end
		function QueryGuildBankTab() end

		-- currencies
		local expanded = {}
		C_CurrencyInfo = {
			GetCurrencyListSize = function() return #W.currencies end,
			GetCurrencyListInfo = function(i)
				local c = W.currencies[i]
				if not c then return nil end
				return { name = c.name or "Currency", isHeader = c.header == true, isHeaderExpanded = expanded[i] ~= false, quantity = c.quantity or 0,
					iconFileID = c.icon or 134400, isAccountWide = c.shared == true, isAccountTransferable = c.shared == true }
			end,
			GetCurrencyListLink = function(i) local c = W.currencies[i]; return c and ("|cffffffff|Hcurrency:%d|h[%s]|h|r"):format(c.id, c.name or "Currency") or nil end,
			GetCurrencyIDFromLink = function(l) return tonumber(tostring(l):match("currency:(%d+)")) end,
			ExpandCurrencyList = function(i, e) expanded[i] = e end,
			GetCurrencyInfo = function(id)
				for _, c in ipairs(W.currencies) do
					if c.id == id then return { name = c.name or "Currency", quantity = c.quantity or 0, iconFileID = c.icon or 134400, isAccountTransferable = c.shared == true } end
				end
			end,
			RequestCurrencyFromAccountCharacter = function() end,
			FetchCurrencyDataFromAccountCharacters = function() return {} end,
		}
		GetCurrencyListSize, GetCurrencyListInfo, ExpandCurrencyList = nil, nil, nil

		-- tooltip data
		stub.tooltipPost = {}
		TooltipDataProcessor = {
			AddTooltipPostCall = function(kind, fn)
				stub.tooltipPost[kind] = stub.tooltipPost[kind] or {}
				local l = stub.tooltipPost[kind]
				l[#l + 1] = fn
			end,
		}
	end

	-- run the post calls for one tooltip, as the client does when it fills it
	function stub.RunTooltip(kind, tooltip, data)
		for _, fn in ipairs(stub.tooltipPost and stub.tooltipPost[kind] or {}) do fn(tooltip, data) end
	end

	function stub.Put(bag, slot, row)
		stub.bags[bag] = stub.bags[bag] or { size = 36 }
		stub.bags[bag][slot] = row
	end
	function stub.SetEquipped(slot, row) W.equipped[slot] = row end

	-- every pending RequestLoadItemDataByID is answered: the item becomes
	-- cached and ITEM_DATA_LOAD_RESULT(id, true) fires once
	function stub.LoadItemData()
		local q = loadQueue
		loadQueue, requested = {}, {}
		for _, id in ipairs(q) do
			if stub.items[id] then stub.items[id].unknown = nil end
			stub.Fire("ITEM_DATA_LOAD_RESULT", id, true)
		end
		return #q
	end
	function stub.PendingItemData() return #loadQueue end

	local KIND = {
		bank = { open = "Banker", ev = "BANKFRAME_OPENED", close = "BANKFRAME_CLOSED" },
		account = { open = "AccountBanker" },
		mail = { open = "MailInfo", ev = "MAIL_SHOW", close = "MAIL_CLOSED" },
		guildbank = { open = "GuildBanker" },
		void = { open = "VoidStorageBanker" },
		auction = { open = "Auctioneer" },
	}
	function stub.Interact(kind, on)
		local k = KIND[kind]
		local t = Enum.PlayerInteractionType[k.open]
		W.open[t] = on or nil
		if on then
			if k.ev then stub.Fire(k.ev) end
			stub.Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", t)
		else
			stub.Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", t)
			if k.close then stub.Fire(k.close) end
		end
	end
end
