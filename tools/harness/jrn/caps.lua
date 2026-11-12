-- Journal capabilities (build J1C): each of the eight caps against its letter for this flavour.
local M = PourSocialScore_NS.M
local LET = {
	modernAH = "ssoos", legacyAH = "oosso", mailInvoice = "sssss", ahMailSubjects = "sssss",
	craftingOrders = "soooo", tradingPost = "soooo", wowToken = "sooos", missions = "soooo",
}
local flv = M.PSS_FLV.flavour
local col = ({ retail = 1, forever = 2, tbc = 3, era = 4, mists = 5 })[flv]
for cap, row in pairs(LET) do
	local want = row:sub(col, col) == "s" and "supported" or "off"
	if M.PSS_FLV.caps[cap] ~= want then
		print("FAIL jrn: caps: " .. cap .. " on " .. flv .. " is " .. tostring(M.PSS_FLV.caps[cap]) .. ", want " .. want)
		return
	end
end
print("PASS caps " .. flv)
