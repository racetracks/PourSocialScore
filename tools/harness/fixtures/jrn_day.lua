-- journal day fixture: one line per activity; fields after time,ent per the stream table
-- events per activity, in expect order: { t, kind = "event" or "hook", name, args }
local function E(t, name, ...) return { t = t, kind = "event", name = name, args = { ... } } end
local function H(t, name, ...) return { t = t, kind = "hook", name = name, args = { ... } } end
local events = {
	vend = { E(1793487600, "MERCHANT_SHOW"), H(1793487600, "BuyMerchantItem"), E(1793487600, "BAG_UPDATE_DELAYED"), E(1793487600, "PLAYER_MONEY"), E(1793489100, "MERCHANT_CLOSED") },
	repair = { H(1793489400, "RepairAllItems"), E(1793489400, "PLAYER_MONEY") },
	mailin = { E(1793490600, "MAIL_INBOX_UPDATE"), H(1793490600, "TakeInboxMoney"), H(1793490900, "TakeInboxItem") },
	mailout = { H(1793490000, "SendMail"), E(1793490000, "PLAYER_MONEY") },
	trade = { E(1793491200, "TRADE_SHOW"), E(1793491200, "TRADE_ACCEPT_UPDATE", 1, 1), E(1793491200, "UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE or "Trade complete.") },
	taxi = { E(1793491500, "TAXIMAP_OPENED"), H(1793491500, "TakeTaxiNode"), E(1793491500, "PLAYER_MONEY") },
	train = { E(1793491800, "TRAINER_SHOW"), H(1793491800, "BuyTrainerService"), E(1793491800, "PLAYER_MONEY") },
	quest = { E(1793492100, "QUEST_TURNED_IN", 1001, 0, 5000), E(1793492100, "QUEST_LOOT_RECEIVED", 1001, "item:2589", 2) },
	loot = { E(1793492400, "LOOT_OPENED", false, false), E(1793492400, "LOOT_READY", false), E(1793492400, "LOOT_CLOSED") },
}
-- the four auction activities (two posts, one sale invoice, one expiry mail) per adapter: stub calls of J2S
local function ah(owner)
	return {
		{ t = 1793492700, call = "Post", args = { { id = 6948, count = 1, buyout = 5000, time = 86400 } }, money = -250 },
		{ t = 1793493000, call = "Post", args = { { id = 2589, count = 10, buyout = 3000, time = 172800 } }, money = -150 },
		{ t = 1793493300, call = "Mail", args = { { sender = "Auction House", subject = "Auction successful: Item", invoice = { "seller", "Item", "Gus", 0, 5000, 250, 250 } } } },
		{ t = 1793493600, call = "Mail", args = { { sender = "Auction House", subject = "Auction expired: Item", items = { { id = 6948, count = 1 } } } } },
	}
end

return {
	events = events,
	ah = { modern = ah("modern"), legacy = ah("legacy") },
	expect = {
		craftPlaced = {
			"1793494200,1,2592,1,10000,Hal,159:4",
		},
		fail = {
			"1793493600,1,6948,1,expired",
			"1793493900,1,2589,10,cancelled",
		},
		loot = {
			"1793492400,1,6948,0,159:1,",
		},
		mailin = {
			"1793490600,1,Dee,500,0,,Pay",
			"1793490900,1,Eve,-2500,2500,159:2,COD",
		},
		mailout = {
			"1793490000,1,Bob,1000,0,2589:5,Hi",
			"1793490300,1,Cy,0,0,6948:1,Gift",
		},
		post = {
			"1793492700,1,6948,1,5000,250,24",
			"1793493000,1,2589,10,300,150,48",
		},
		quest = {
			"1793492100,1,Quest A,5000,900,10,2589:2,1:5",
		},
		repair = {
			"1793489400,1,4500,0",
			"1793489700,1,3200,1",
		},
		sold = {
			"1793493300,1,6948,1,4750,250,250,Gus",
		},
		taxi = {
			"1793491500,1,350,Orgrimmar,Crossroads",
		},
		trade = {
			"1793491200,1,Fay,1000,0,2589:1,6948:1",
		},
		train = {
			"1793491800,1,1200,Fireball",
		},
		vend = {
			"1793487600,1,6948,1,100,sell,,",
			"1793487900,1,2589,5,25,sell,,",
			"1793488200,1,2592,3,60,sell,,",
			"1793488500,1,159,2,10,buy,,",
			"1793488800,1,2589,5,25,buyback,,",
			"1793489100,1,40000,1,0,refund,1:50,2589:3",
		},
	},
}
