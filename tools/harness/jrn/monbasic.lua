-- Journal basic monitors (build J2B): mail, trade, taxi, training, quest, loot; secret partner; rows on every client.
local M = PourSocialScore_NS.M
local gold = 0
function GetMoney() return gold end
H.SetMoney = function(c) gold = c end
Enum = Enum or {}; Enum.PlayerInteractionType = Enum.PlayerInteractionType or { Auctioneer = 21 }
local function keep(t, names) local s = {}; for _, n in ipairs(names) do s[n] = t[n] end; return function() for _, n in ipairs(names) do t[n] = s[n] end end end
local undo = { keep(_G, { "GetMoney", "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxItem", "GetInboxItemLink", "SendMail", "TakeInboxMoney", "TakeInboxItem", "AutoLootMailItem", "GetSendMailMoney", "GetSendMailCOD", "GetSendMailItem", "GetSendMailItemLink", "ATTACHMENTS_MAX_SEND", "GetPlayerTradeMoney", "GetTargetTradeMoney", "GetTradePlayerItemLink", "GetTradeTargetItemLink", "GetTradePlayerItemInfo", "GetTradeTargetItemInfo", "ERR_TRADE_COMPLETE", "ERR_TRADE_CANCELLED", "UnitName", "TakeTaxiNode", "TaxiNodeCost", "TaxiNodeName", "NumTaxiNodes", "TaxiNodeGetType", "BuyTrainerService", "GetTrainerServiceCost", "GetTrainerServiceInfo", "GetNumLootItems", "GetLootSlotInfo", "GetLootSlotLink", "GetLootSlotType" }), keep(C_Item, {}) }
local realG, realD = M.PSS_WhHistGold, M.PSS_WhHistDelta
M.PSS_WhHistGold, M.PSS_WhHistDelta = function() end, function() end
undo[#undo + 1] = function() M.PSS_WhHistGold, M.PSS_WhHistDelta = realG, realD end
local function fail(w) print("FAIL jrn: monbasic: " .. w) end
local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[I" .. id .. "]|h|r" end
local inbox, sent, trade, loot = {}, { money = 1000, cod = 0, items = { 2589 } }, { out = 1000, ["in"] = 0 }, { { id = 159, n = 1 } }
GetInboxNumItems = function() return #inbox, #inbox end
GetInboxHeaderInfo = function(i) local m = inbox[i]; return 1, 1, m.sender, m.subject, m.money or 0, m.cod or 0, 30, m.item ~= nil end
GetInboxItem = function(i, a) local m = inbox[i]; if m and m.item and a == 1 then return "I", m.item, 1, m.count or 1 end end
GetInboxItemLink = function(i, a) local m = inbox[i]; return m and m.item and a == 1 and link(m.item) or nil end
SendMail = function() end; TakeInboxMoney = function() end; TakeInboxItem = function() end; AutoLootMailItem = function() end
GetSendMailMoney = function() return sent.money end
GetSendMailCOD = function() return sent.cod end
GetSendMailItem = function(a) if sent.items[a] then return "I", sent.items[a], 1, 5 end end
GetSendMailItemLink = function(a) return sent.items[a] and link(sent.items[a]) or nil end
ATTACHMENTS_MAX_SEND = 12
GetPlayerTradeMoney = function() return trade.out end
GetTargetTradeMoney = function() return trade["in"] end
GetTradePlayerItemLink = function(a) return a == 1 and link(2589) or nil end
GetTradeTargetItemLink = function(a) return a == 1 and link(6948) or nil end
GetTradePlayerItemInfo = function(a) return "I", 1, 1 end
GetTradeTargetItemInfo = function(a) return "I", 1, 1 end
ERR_TRADE_COMPLETE = ERR_TRADE_COMPLETE or "Trade complete."; ERR_TRADE_CANCELLED = ERR_TRADE_CANCELLED or "Trade cancelled."
local partner = "Fay"
local realUnitName = UnitName
UnitName = function(u) if u == "NPC" then return partner end return realUnitName(u) end
TakeTaxiNode = function() end; TaxiNodeCost = function() return 350 end; TaxiNodeName = function(i) return i == 1 and "Orgrimmar" or "Crossroads" end
NumTaxiNodes = function() return 2 end; TaxiNodeGetType = function(i) return i == 1 and "CURRENT" or "REACHABLE" end
BuyTrainerService = function() end; GetTrainerServiceCost = function() return 1200 end; GetTrainerServiceInfo = function() return "Fireball" end
GetNumLootItems = function() return #loot end
GetLootSlotInfo = function(i) return 1, "I", loot[i].n, 0, 1 end
GetLootSlotLink = function(i) return link(loot[i].id) end
GetLootSlotType = function() return 1 end
C_QuestLog = C_QuestLog or {}
C_QuestLog.GetTitleForQuestID = function() return "Quest A" end
local on = true
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "journal" then return on end return realOn(n) end
PSS_WarehouseDB = PSS_WarehouseDB or {}
M.PSS_WhStartMore(true); M.PSS_WatchStart()
local function reset()
	H.Fire("QUEST_TURNED_IN", 1001, 0, 0)
	PSS_WarehouseDB.jrn = nil
	if M.PSS_JrnStore then M.PSS_JrnStore:drop() end
	M.PSS_IxHot("jrn", true); M.PSS_JrnUnmatched = 0; inbox = {}
	for _, o in ipairs({ "Mail", "Trades", "Quests", "Loot" }) do M.PSS_SetOpt("jrnMonitor" .. o, "global", true) end
end
local function rows(st)
	local out = {}
	M.PSS_Ix("jrn"):scan({}, function(r) if not st or r.st == st then local c = {}; for k, v in pairs(r) do c[k] = v end; out[#out + 1] = c end end, { load = true })
	return out
end
-- mailout and mailcod
reset(); SendMail("Bob", "Hi", "x")
local r = rows("jrn.mailout")[1]
if not r or not tostring(r.party):find("^Bob") or r.copper ~= 1000 or r.items ~= "2589:5" or r.subject ~= "Hi" then return fail("mailout: " .. tostring(r and r.party) .. " " .. tostring(r and r.items)) end
reset(); inbox = { { sender = "Dee", subject = "Pay", money = 500 }, { sender = "Eve", subject = "COD", cod = 2500, item = 159, count = 2 } }
H.Fire("MAIL_INBOX_UPDATE"); TakeInboxMoney(1); TakeInboxItem(2, 1)
local a = rows("jrn.mailin"); table.sort(a, function(x, y) return (x.party or "") < (y.party or "") end)
if #a ~= 2 or not tostring(a[1].party):find("^Dee") or a[1].copper ~= 500 or not tostring(a[2].party):find("^Eve") or a[2].cod ~= 2500 or a[2].copper ~= -2500 or a[2].items ~= "159:2" then return fail("mailcod: " .. #a .. " lines") end
reset(); TakeInboxMoney(9)
if #rows() ~= 0 or M.PSS_JrnUnmatched ~= 1 then return fail("mailunmatched: " .. #rows() .. " lines, unmatched " .. tostring(M.PSS_JrnUnmatched)) end
-- trade: complete writes both sides, cancelled writes nothing, a secret partner is "?"
reset(); H.Fire("TRADE_SHOW"); H.Fire("TRADE_ACCEPT_UPDATE", 1, 1); H.Fire("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
r = rows("jrn.trade")[1]
if not r or not tostring(r.party):find("^Fay") or r.copperOut ~= 1000 or r.itemsOut ~= "2589:1" or r.itemsIn ~= "6948:1" then return fail("trade: " .. tostring(r and r.party) .. " " .. tostring(r and r.itemsIn)) end
reset(); H.Fire("TRADE_SHOW"); H.Fire("TRADE_ACCEPT_UPDATE", 1, 1); H.Fire("UI_INFO_MESSAGE", 0, ERR_TRADE_CANCELLED)
if #rows() ~= 0 then return fail("tradecancel: a cancelled trade wrote " .. #rows()) end
reset(); local realSec = M.PSS_IsSecret; M.PSS_IsSecret = function(v) return v == "Fay" or realSec(v) end
H.Fire("TRADE_SHOW"); H.Fire("TRADE_ACCEPT_UPDATE", 1, 1); H.Fire("UI_INFO_MESSAGE", 0, ERR_TRADE_COMPLETE)
M.PSS_IsSecret = realSec; r = rows("jrn.trade")[1]
if not r or r.party ~= "?" or r.copperOut ~= 1000 then return fail("monsecret: party " .. tostring(r and r.party)) end
-- taxi, training
reset(); H.Fire("TAXIMAP_OPENED"); TakeTaxiNode(2)
r = rows("jrn.taxi")[1]
if not r or r.copper ~= 350 or r.from ~= "Orgrimmar" or r.to ~= "Crossroads" then return fail("taxi: " .. tostring(r and r.copper)) end
reset(); H.Fire("TRAINER_SHOW"); BuyTrainerService(1)
r = rows("jrn.train")[1]
if not r or r.copper ~= 1200 or r.spell ~= "Fireball" then return fail("train: " .. tostring(r and r.copper)) end
-- questitems: the reward item and the money in one line; option off writes nothing
reset(); H.Fire("QUEST_LOOT_RECEIVED", 1001, link(2589), 2); H.Fire("QUEST_TURNED_IN", 1001, 900, 5000)
a = rows("jrn.quest"); r = a[1]
if #a ~= 1 or r.quest ~= "Quest A" or r.copper ~= 5000 or r.xp ~= 900 or r.items ~= "2589:2" then return fail("questitems: " .. #a .. " lines") end
reset(); M.PSS_SetOpt("jrnMonitorQuests", "global", false); H.Fire("QUEST_TURNED_IN", 1001, 900, 5000)
if #rows() ~= 0 then return fail("monoff: quest wrote with the option off") end
-- loot: the slots read at open are written at close; nothing to read counts unmatched
reset(); H.Fire("LOOT_OPENED", false, false); H.Fire("LOOT_READY", false); H.Fire("LOOT_CLOSED")
r = rows("jrn.loot")[1]
if not r or r.items ~= "159:1" then return fail("loot: " .. tostring(r and r.items)) end
reset(); loot = {}; H.Fire("LOOT_OPENED", false, false); H.Fire("LOOT_CLOSED"); loot = { { id = 159, n = 1 } }
if #rows() ~= 0 or M.PSS_JrnUnmatched ~= 1 then return fail("lootunmatched: unmatched " .. tostring(M.PSS_JrnUnmatched)) end
-- moncamelot: a row for each client API present, on every stub
local have = {}
for _, row in ipairs((M.PSS_WatchRows())) do have[row.id] = true end
for _, id in ipairs({ "jrn.mail", "jrn.trade", "jrn.taxi", "jrn.train", "jrn.quest", "jrn.loot" }) do
	if not have[id] then return fail("moncamelot: no row " .. id .. " on " .. M.PSS_FLV.flavour) end
end
UnitName = realUnitName; M.PSS_On = realOn
for _, u in ipairs(undo) do u() end
print("PASS monbasic " .. M.PSS_FLV.flavour)
