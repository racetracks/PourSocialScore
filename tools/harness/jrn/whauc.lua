-- Warehouse auctions without an itemLink (build J2IL): an owned auction the client gives with itemKey.itemID only is read.
local M = PourSocialScore_NS.M
local function fail(w) print("FAIL jrn: whauc: " .. w) end
if not C_AuctionHouse then print("PASS whauc " .. M.PSS_FLV.flavour) return end

local realOwned, realNum = C_AuctionHouse.GetOwnedAuctionInfo, C_AuctionHouse.GetNumOwnedAuctions
local realOn = M.PSS_On
M.PSS_On = function(n) if n == "warehouse" then return true end return realOn(n) end
local realOpen = M.PSS_ItemOpen
M.PSS_ItemOpen = function(k) return k == "auction" or realOpen(k) end
C_AuctionHouse.GetNumOwnedAuctions = function() return 1 end
C_AuctionHouse.GetOwnedAuctionInfo = function(i)
	if i == 1 then return { itemKey = { itemID = 2592 }, quantity = 3, timeLeftSeconds = 3600 } end
end
local live, err = M.PSS_Call("item.live", "a0")
M.PSS_ItemOpen = realOpen
C_AuctionHouse.GetOwnedAuctionInfo, C_AuctionHouse.GetNumOwnedAuctions = realOwned, realNum
M.PSS_On = realOn
if err then return fail("whauc-nolink: item.live error " .. tostring(err)) end
if not live or live.n ~= 1 then return fail("whauc-nolink: expected 1 entry, got " .. tostring(live and live.n)) end
local r = live[1]
if r[2] ~= "a0" or tonumber(tostring(r[4]):match("^%d+")) ~= 2592 or r[5] ~= 3 then
	return fail("whauc-nolink: entry " .. tostring(r[2]) .. " " .. tostring(r[4]) .. " x" .. tostring(r[5]))
end
print("PASS whauc " .. M.PSS_FLV.flavour)
