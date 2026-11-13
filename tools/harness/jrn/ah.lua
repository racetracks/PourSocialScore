-- Journal auction-house adapters (build J2C): the pick, each adapter on its fixture, posts, invoices, fails, ahsame.
local M = PourSocialScore_NS.M
local gold = 0
function GetMoney() return gold end
local realSet = H.SetMoney
H.SetMoney = function(c) gold = c end
Enum = Enum or {}; Enum.PlayerInteractionType = Enum.PlayerInteractionType or { Auctioneer = 21 }
local function keep(t, names) local s = {}; for _, n in ipairs(names) do s[n] = t[n] end; return function() for _, n in ipairs(names) do t[n] = s[n] end end end
local undo = { keep(_G, { "GetMoney", "GetInboxNumItems", "GetInboxHeaderInfo", "GetInboxInvoiceInfo", "GetInboxItem", "GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink", "GetAuctionItemTimeLeft", "Auctionator" }), keep(C_Item, { "GetItemInfoInstant" }), keep(C_AuctionHouse or {}, { "GetNumOwnedAuctions", "GetOwnedAuctionInfo" }) }
local realG, realD = M.PSS_WhHistGold, M.PSS_WhHistDelta
M.PSS_WhHistGold, M.PSS_WhHistDelta = function() end, function() end
undo[#undo + 1] = function() H.SetMoney = realSet end
undo[#undo + 1] = function() M.PSS_WhHistGold, M.PSS_WhHistDelta = realG, realD end
local function fail(w) print("FAIL jrn: ah: " .. w) end
local fx = dofile(((arg and arg[0] or ""):match("^(.*)/[^/]*$") or ".") .. "/fixtures/jrn_day.lua")
local modern = C_AuctionHouse ~= nil
local want = modern and "Modern" or "Legacy"
if M.PSS_JrnAhPick and M.PSS_JrnAhPick() ~= want then return fail("pick: " .. tostring(M.PSS_JrnAhPick()) .. " on " .. M.PSS_FLV.flavour .. ", want " .. want) end
local function link(id) return "|cffffffff|Hitem:" .. id .. "::::::::|h[I" .. id .. "]|h|r" end
local O, inbox, late = {}, {}, false
if modern then
	C_AuctionHouse.GetNumOwnedAuctions = function() return late and 0 or #O end
	C_AuctionHouse.GetOwnedAuctionInfo = function(i)
		local a = O[i]
		return a and { auctionID = i, itemKey = { itemID = a.id }, itemLink = not a.nolink and link(a.id) or nil, quantity = a.count, buyoutAmount = a.buyout, timeLeftSeconds = a.time, status = a.status }
	end
else
	GetNumAuctionItems = function(l) return l == "owner" and not late and #O or 0 end
	GetAuctionItemInfo = function(l, i) local a = O[i]; return "I", 1, a.count, 1, true, 1, "", 0, 0, a.buyout end
	GetAuctionItemLink = function(l, i) return link(O[i].id) end
	GetAuctionItemTimeLeft = function(l, i) local t = O[i].time; return t <= 1800 and 1 or t <= 7200 and 2 or t <= 43200 and 3 or 4 end
end
GetInboxNumItems = function() return #inbox, #inbox end
GetInboxHeaderInfo = function(i) local m = inbox[i]; return 1, 1, m.sender, m.subject, 0, 0, m.days or 30, m.item ~= nil end
GetInboxInvoiceInfo = function(i) local v = inbox[i].invoice; if v then return unpack(v) end end
GetInboxItem = function(i, a) local m = inbox[i]; if m.item and a == 1 then return "I", m.item, 1, m.count or 1 end end
C_Item.GetItemInfoInstant = function() return 6948 end
local on = true
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "journal" then return on end return realOn(n) end
PSS_WarehouseDB = PSS_WarehouseDB or {}
M.PSS_WhStartMore(true); M.PSS_WatchStart()
local function reset()
	PSS_WarehouseDB.jrn = nil
	if M.PSS_JrnStore then M.PSS_JrnStore:drop() end
	M.PSS_IxHot("jrn", true); M.PSS_JrnUnmatched = 0; O = {}; inbox = {}
	M.PSS_SetOpt("jrnMonitorAH", "global", true)
	H.SetMoney(1000000); H.Fire("PLAYER_MONEY")
end
local function rows(st)
	local out = {}
	M.PSS_Ix("jrn"):scan({}, function(r) if not st or r.st == st then local c = {}; for k, v in pairs(r) do c[k] = v end; out[#out + 1] = c end end, { load = true })
	table.sort(out, function(x, y) return (x.time or 0) < (y.time or 0) or ((x.time or 0) == (y.time or 0) and (x.item or 0) < (y.item or 0)) end)
	return out
end
local EV = modern and "OWNED_AUCTIONS_UPDATED" or "AUCTION_OWNED_LIST_UPDATE"
local function post(id, count, buyout, time, deposit)
	O[#O + 1] = { id = id, count = count, buyout = buyout, time = time }
	H.SetMoney(GetMoney() - deposit); H.Fire("PLAYER_MONEY"); H.Fire(EV)
end
local function open() H.Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Auctioneer) end
-- the adapter on its fixture: two posts, deposit, unit, hours
reset(); open(); H.Fire(EV)
for _, p in ipairs({ fx.ah.modern[1], fx.ah.modern[2] }) do post(p.args[1].id, p.args[1].count, p.args[1].buyout, p.args[1].time, -p.money) end
local got = rows("jrn.post")
if #got ~= 2 then return fail("post: " .. #got .. " lines, want 2") end
local A, B = nil, nil
for _, x in ipairs(got) do if x.item == 6948 then A = x else B = x end end
local hours = modern and { 24, 48 } or { 48, 48 }
if A.item ~= 6948 or A.count ~= 1 or A.unit ~= 5000 or A.deposit ~= 250 or A.duration ~= hours[1] then return fail("post1: " .. tostring(A.unit) .. " " .. tostring(A.deposit) .. " " .. tostring(A.duration)) end
if B.item ~= 2589 or B.count ~= 10 or B.unit ~= 300 or B.deposit ~= 150 or B.duration ~= hours[2] then return fail("post2: " .. tostring(B.unit)) end
-- a post that leaves the list writes nothing; a second event writes nothing again
local n0 = #rows(); table.remove(O, 1); H.Fire(EV); H.Fire(EV)
if #rows() ~= n0 then return fail("unpost: a line when a key left the list") end
-- two equal posts in one list are two keys (a multiset on the legacy key)
reset(); open(); H.Fire(EV); O = { { id = 6948, count = 1, buyout = 5000, time = 86400 } }; H.SetMoney(GetMoney() - 100); H.Fire("PLAYER_MONEY"); H.Fire(EV)
O[2] = { id = 6948, count = 1, buyout = 5000, time = 86400 }; H.SetMoney(GetMoney() - 100); H.Fire("PLAYER_MONEY"); H.Fire(EV)
if #rows("jrn.post") ~= 2 then return fail("multiset: " .. #rows("jrn.post") .. " posts, want 2") end
-- invoice once, fail kinds
reset(); inbox = { { sender = "Auction House", subject = "Auction successful: Item", invoice = { "seller", "Item", "Gus", 0, 5000, 250, 250 } } }
H.Fire("MAIL_INBOX_UPDATE"); H.Fire("MAIL_INBOX_UPDATE")
local s = rows("jrn.sold")
if #s ~= 1 or s[1].item ~= 6948 or s[1].value ~= 4750 or s[1].deposit ~= 250 or s[1].consignment ~= 250 or s[1].buyer ~= "Gus" then return fail("invoice: " .. #s .. " lines, value " .. tostring(s[1] and s[1].value)) end
reset(); inbox = { { sender = "Auction House", subject = "Auction expired: Item", item = 6948, count = 1 }, { sender = "Auction House", subject = "Auction cancelled: Item", item = 2589, count = 10 } }
H.Fire("MAIL_INBOX_UPDATE")
local f = rows("jrn.fail")
local fk = {}; for _, x in ipairs(f) do fk[x.item] = x end
if #f ~= 2 or not fk[6948] or fk[6948].kind ~= "expired" or not fk[2589] or fk[2589].kind ~= "cancelled" or fk[2589].count ~= 10 then return fail("fail kinds: " .. #f .. " lines") end
-- monoff: option off writes nothing
reset(); M.PSS_SetOpt("jrnMonitorAH", "global", false); open(); post(6948, 1, 5000, 86400, 250)
inbox = { { sender = "Auction House", subject = "Auction expired: Item", item = 6948, count = 1 } }; H.Fire("MAIL_INBOX_UPDATE")
if #rows() ~= 0 then return fail("monoff: " .. #rows() .. " lines with the option off") end
-- Auctionator: told only when present
local told = 0
reset(); Auctionator = nil; inbox = { { sender = "Auction House", subject = "Auction expired: Other", item = 6948, count = 1 } }; H.Fire("MAIL_INBOX_UPDATE")
Auctionator = { EventBus = { Fire = function() told = told + 1 end } }
inbox = { { sender = "Auction House", subject = "Auction cancelled: Other", item = 2589, count = 1 } }; H.Fire("MAIL_INBOX_UPDATE")
H.Fire("MAIL_INBOX_UPDATE"); Auctionator = nil
if told ~= 1 then local e = M.PSS_ErrRows(); return fail("bus: told " .. told .. " times, want 1; errors " .. e.n .. " " .. tostring(e[1] and e[1][3]) .. " lines " .. #rows()) end
-- phases of build J2 4 (DEC-00480): the baseline is the first list event of an open
local function lines() return rows("jrn.post") end
local function drop(c) H.SetMoney(GetMoney() - c); H.Fire("PLAYER_MONEY") end
local function listev() late = false; H.Fire(EV) end
local function seed(n) for i = 1, n do O[#O + 1] = { id = 100 + i, count = 1, buyout = 900, time = 86400 } end end
-- ah-baseline-late (both adapters): two auctions exist, the list reads 0 until its first event
reset(); late = true; seed(2); open(); drop(0); listev()
if #lines() ~= 0 then return fail("baseline-late: " .. #lines() .. " lines at the baseline, want 0") end
O[3] = { id = 6948, count = 1, buyout = 400, time = 86400 }; drop(30); H.Fire(EV)
local L = lines()
if #L ~= 1 or L[1].unit ~= 400 or L[1].deposit ~= 30 then return fail("baseline-late: " .. #L .. " lines, unit " .. tostring(L[1] and L[1].unit) .. " deposit " .. tostring(L[1] and L[1].deposit)) end
-- ah-created-first (modern): a created event before any list event is not a baseline
if modern then
	reset(); late = true; seed(2); open(); H.Fire("AUCTION_HOUSE_AUCTION_CREATED"); drop(30); listev()
	if #lines() ~= 0 then return fail("created-first: " .. #lines() .. " lines, want 0") end
end
-- ah-reopen: a close drops the baseline, a re-open starts again
reset(); seed(2); open(); H.Fire(EV); H.Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Auctioneer)
seed(1); open(); drop(20); H.Fire(EV)
if #lines() ~= 0 then return fail("reopen: " .. #lines() .. " lines on re-open, want 0") end
if modern then
	-- ah-modern-nolink: a row without itemLink is a post
	reset(); open(); H.Fire(EV); O[1] = { id = 6948, count = 1, buyout = 500, time = 86400, nolink = true }; drop(10); H.Fire(EV)
	L = lines()
	if #L ~= 1 or L[1].item ~= 6948 then return fail("modern-nolink: " .. #L .. " lines") end
	-- ah-modern-unit: buyout over quantity, bid-only, a unit below the quantity
	local want = { { 400, 4, 100 }, { false, 1, false }, { 10, 3, 3 } }
	for i, w in ipairs(want) do
		reset(); open(); H.Fire(EV); O[1] = { id = 6948, count = w[2], buyout = w[1] or nil, time = 86400 }; drop(10); H.Fire(EV)
		L = lines()
		if #L ~= 1 or L[1].unit ~= (w[3] or nil) then return fail("modern-unit " .. i .. ": " .. tostring(L[1] and L[1].unit)) end
	end
	-- ah-modern-sold: a sold row (status 1) is never a post
	reset(); open(); H.Fire(EV); O[1] = { id = 6948, count = 1, buyout = 500, time = 86400, status = 1 }; drop(10); H.Fire(EV)
	if #lines() ~= 0 then return fail("modern-sold: " .. #lines() .. " lines, want 0") end
	-- ah-deposit-split: two posts in one settle share the money drop, the remainder on the first
	reset(); open(); H.Fire(EV); O[1] = { id = 6948, count = 1, buyout = 500, time = 86400 }; O[2] = { id = 2589, count = 1, buyout = 500, time = 86400 }
	drop(31); H.Fire(EV)
	L = lines()
	if #L ~= 2 or L[1].deposit + L[2].deposit ~= 31 or math.max(L[1].deposit, L[2].deposit) ~= 16 or math.min(L[1].deposit, L[2].deposit) ~= 15 then return fail("deposit-split: " .. #L .. " lines " .. tostring(L[1] and L[1].deposit) .. " " .. tostring(L[2] and L[2].deposit)) end
else
	-- ah-legacy-unit: the 10th return over the count; 0 is no unit
	for i, w in ipairs({ { 500, 5, 100 }, { 0, 1, false } }) do
		reset(); open(); H.Fire(EV); O[1] = { id = 6948, count = w[2], buyout = w[1], time = 86400 }; drop(10); H.Fire(EV)
		L = lines()
		if #L ~= 1 or L[1].unit ~= (w[3] or nil) then return fail("legacy-unit " .. i .. ": " .. tostring(L[1] and L[1].unit)) end
	end
end
M.PSS_On = realOn
H.Fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Auctioneer)
reset()
for _, u in ipairs(undo) do u() end
print("PASS ah " .. M.PSS_FLV.flavour)
