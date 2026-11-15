-- Journal vendor and repair monitors (build J2A): sells by slot and money, buys, buybacks, refunds, repairs, unmatched, off, secret.
local M = PourSocialScore_NS.M
local gold = 0
function GetMoney() return gold end
H.SetMoney = function(c) gold = c end
Enum = Enum or {}; Enum.PlayerInteractionType = Enum.PlayerInteractionType or { Auctioneer = 21 }
local function keep(t, names) local s = {}; for _, n in ipairs(names) do s[n] = t[n] end; return function() for _, n in ipairs(names) do t[n] = s[n] end end end
local undo = { keep(_G, { "GetMoney", "RepairAllItems", "GetRepairAllCost", "BuyMerchantItem", "BuybackItem", "GetMerchantItemInfo", "GetMerchantItemLink", "GetBuybackItemInfo", "GetBuybackItemLink" }), keep(C_Container, { "ContainerRefundItemPurchase", "GetContainerItemPurchaseInfo", "GetContainerItemPurchaseItem", "GetContainerItemPurchaseCurrency" }) }
local realG, realD = M.PSS_WhHistGold, M.PSS_WhHistDelta
M.PSS_WhHistGold, M.PSS_WhHistDelta = function() end, function() end
undo[#undo + 1] = function() M.PSS_WhHistGold, M.PSS_WhHistDelta = realG, realD end
local function fail(w) print("FAIL jrn: mon1: " .. w) end
local items = H.items
for _, r in ipairs({ { 6948, 100 }, { 2589, 25 }, { 2592, 60 }, { 159, 10 }, { 40000, 0 } }) do items[r[1]] = items[r[1]] or { name = "I" .. r[1] }; items[r[1]].price = r[2] end
local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[I" .. id .. "]|h|r" end
-- the client calls the monitors hook exist before the rows start
local cost, mer = 4500, { id = 159, price = 20, q = 1 }
RepairAllItems = function() end
GetRepairAllCost = function() return cost, true end
BuyMerchantItem = function() end
BuybackItem = function() end
GetMerchantItemInfo = function() return "I", 1, mer.price, mer.q end
GetMerchantItemLink = function() return link(mer.id) end
GetBuybackItemInfo = function() return "I", 1, 125, 5 end
GetBuybackItemLink = function() return link(2589) end
C_Container.ContainerRefundItemPurchase = function() end
C_Container.GetContainerItemPurchaseInfo = function() return 0, 1, 100, 1 end
C_Container.GetContainerItemPurchaseItem = function() return 1, 3, link(2589) end
C_Container.GetContainerItemPurchaseCurrency = function() return 1, 50, "|Hcurrency:1|h[C]|h" end
local on = true
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "journal" then return on end return realOn(n) end
PSS_WarehouseDB = PSS_WarehouseDB or {}
M.PSS_WhStartMore(true); M.PSS_WatchStart()
local function reset()
	PSS_WarehouseDB.jrn = nil
	if M.PSS_JrnStore then M.PSS_JrnStore:drop() end
	M.PSS_IxHot("jrn", true); M.PSS_JrnUnmatched = 0
	for b = 0, 5 do H.bags[b] = nil end
	M.PSS_SetOpt("jrnMonitorVendor", "global", true)
	H.SetMoney(1000000); H.Fire("PLAYER_MONEY")
end
local function rows()
	local out = {}
	M.PSS_Ix("jrn"):scan({}, function(r) local c = {}; for k, v in pairs(r) do c[k] = v end; out[#out + 1] = c end, { load = true })
	return out
end
local function sell(n)
	local m = GetMoney()
	for i = 1, n do H.Put(0, i, { id = 2592, count = 3 }) end
	H.OpenMerchant()
	for i = 1, n do C_Container.UseContainerItem(0, i) end
	H.SetMoney(m + 180 * n); H.Fire("BAG_UPDATE_DELAYED"); H.Fire("PLAYER_MONEY")
end
-- mon1day: one sale, one buy, one buyback, one refund, one repair (copper to the copper)
reset(); H.Put(0, 1, { id = 6948, count = 1 }); H.OpenMerchant(); local m = GetMoney()
C_Container.UseContainerItem(0, 1); H.SetMoney(m + 100); H.Fire("BAG_UPDATE_DELAYED"); H.Fire("PLAYER_MONEY")
BuyMerchantItem(1, 2); H.SetMoney(m + 60); H.Fire("PLAYER_MONEY")
mer.q = 1; BuybackItem(1); H.SetMoney(m - 65); H.Fire("PLAYER_MONEY")
C_Container.ContainerRefundItemPurchase(0, 1); H.Fire("BAG_UPDATE_DELAYED")
RepairAllItems(false); H.SetMoney(GetMoney() - 4500); H.Fire("PLAYER_MONEY")
local got = rows(); local by = {}
for _, r in ipairs(got) do by[r.st] = (by[r.st] or 0) + 1 end
if #got ~= 5 or by["jrn.vend"] ~= 4 or by["jrn.repair"] ~= 1 then return fail("mon1day: " .. #got .. " lines") end
for _, r in ipairs(got) do
	if r.st == "jrn.vend" and r.kind == "sell" and not (r.item == 6948 and r.count == 1 and r.unit == 100) then return fail("mon1day: sell line") end
	if r.st == "jrn.vend" and r.kind == "buy" and not (r.item == 159 and r.count == 2 and r.unit == 20) then return fail("mon1day: buy line") end
	if r.st == "jrn.vend" and r.kind == "buyback" and not (r.item == 2589 and r.count == 5 and r.unit == 25) then return fail("mon1day: buyback line") end
	if r.st == "jrn.vend" and r.kind == "refund" and not (r.item == 40000 or r.items == "2589:3") then return fail("mon1day: refund line") end
	if r.st == "jrn.repair" and r.copper ~= 4500 then return fail("mon1day: repair copper " .. tostring(r.copper)) end
end
-- vendburst: 12 sales in one settle, each once
reset(); sell(12)
local n = 0; for _, r in ipairs(rows()) do if r.kind == "sell" then n = n + 1 end end
if n ~= 12 then return fail("vendburst: " .. n .. " lines, want 12") end
-- vendunmatched: money up with no slot change; the merchant closes
reset(); H.OpenMerchant(); H.SetMoney(GetMoney() + 500); H.Fire("PLAYER_MONEY"); H.CloseMerchant()
if #rows() ~= 0 or M.PSS_JrnUnmatched ~= 1 then return fail("vendunmatched: " .. #rows() .. " lines, unmatched " .. tostring(M.PSS_JrnUnmatched)) end
-- vendrefund: currencies and items filled
reset(); H.OpenMerchant(); C_Container.ContainerRefundItemPurchase(0, 1); H.Fire("BAG_UPDATE_DELAYED")
local r = rows()[1]
if not r or r.kind ~= "refund" or r.currencies ~= "1:50" or r.items ~= "2589:3" then return fail("vendrefund: " .. tostring(r and r.kind) .. " " .. tostring(r and r.currencies) .. " " .. tostring(r and r.items)) end
-- repairguild: guild repair, copper from the cost, money unchanged
reset(); cost = 3200; H.OpenMerchant(); RepairAllItems(true); H.Fire("PLAYER_MONEY"); cost = 4500
r = rows()[1]
if not r or r.st ~= "jrn.repair" or r.copper ~= 3200 or not r.guild then return fail("repairguild: " .. tostring(r and r.copper) .. " guild " .. tostring(r and r.guild)) end
-- vend-double: a second settle never writes the sale again
reset(); sell(1); H.SetMoney(GetMoney() + 180); H.Fire("PLAYER_MONEY")
n = 0; for _, x in ipairs(rows()) do if x.kind == "sell" then n = n + 1 end end
if n ~= 1 then return fail("vend-double: " .. n .. " lines, want 1") end
-- vend-slot: money up and a pending sale, but the slot still holds the item: no line
reset(); H.Put(0, 1, { id = 6948, count = 1 }); H.OpenMerchant()
local realUse = C_Container.UseContainerItem
C_Container.UseContainerItem(0, 1); H.Put(0, 1, { id = 6948, count = 1 }); H.SetMoney(GetMoney() + 100); H.Fire("PLAYER_MONEY")
if #rows() ~= 0 then return fail("vend-slot: a line with the item still in its slot") end
-- monoff: the option off writes nothing
reset(); M.PSS_SetOpt("jrnMonitorVendor", "global", false); sell(2)
RepairAllItems(false); H.Fire("PLAYER_MONEY")
if #rows() ~= 0 then return fail("monoff: " .. #rows() .. " lines with the option off") end
-- monsecret: a secret link writes nothing and raises no error
reset(); M.PSS_SetOpt("jrnMonitorVendor", "global", true)
local realSec = M.PSS_IsSecret
M.PSS_IsSecret = function(v) return v == link(159) or realSec(v) end
H.OpenMerchant(); BuyMerchantItem(1, 1); H.SetMoney(GetMoney() - 20); H.Fire("PLAYER_MONEY")
M.PSS_IsSecret = realSec
if #rows() ~= 0 then return fail("monsecret: a secret link wrote a line") end
H.CloseMerchant(); for b = 0, 5 do H.bags[b] = nil end; M.PSS_On = realOn
for _, u in ipairs(undo) do u() end
print("PASS mon1 " .. M.PSS_FLV.flavour)
