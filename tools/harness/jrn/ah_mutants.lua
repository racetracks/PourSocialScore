-- Mutants of the auction-house adapters and mail readers (build J2C). { id, file, from, to, phases }
local F = "PourSocialScore_Libraries/PSS_JrnAh.lua"
return {
	{ "ah-modern-count-lost", F, "count = a.quantity, unit = unitOf(a.buyoutAmount, a.quantity)", "count = 1, unit = unitOf(a.buyoutAmount, a.quantity)", "ah" },
	{ "ah-legacy-timeleft-raw", F, "duration = LEFT[GetAuctionItemTimeLeft(\"owner\", i)] or 3600 }", "duration = GetAuctionItemTimeLeft(\"owner\", i) }", "ah" },
	{ "ah-pick-modern-always", F, "local AH = M.PSS_Can(\"modernAH\") and Modern or M.PSS_Can(\"legacyAH\") and Legacy or nil", "local AH = Modern", "ah" },
	{ "ah-pick-legacy-always", F, "local AH = M.PSS_Can(\"modernAH\") and Modern or M.PSS_Can(\"legacyAH\") and Legacy or nil", "local AH = Legacy", "ah" },
	{ "invoice-every-read", F, "if not seen[key] then", "if true then", "ah" },
	{ "fail-kind-swapped", F, "and \"expired\" or removed and subject:match(removed) and \"cancelled\" or nil", "and \"cancelled\" or removed and subject:match(removed) and \"expired\" or nil", "ah" },
	{ "bus-always", F, "if wrote then told() end", "told()", "ah" },
	{ "ah-snapshot-at-open", F, "GetMoney(); snap = nil", "GetMoney(); snap = counts(AH.owned())", "ah" },
	{ "ah-baseline-any-event", F, "if e == AH.list then", "if true then", "ah" },
	{ "ah-snap-kept-on-close", F, "GetMoney(); snap = nil end\n\t\telseif e == HIDE then\n\t\t\tif auc and tostring(auc) == arg then open, pend, snap = false, {}, nil end", "GetMoney() end\n\t\telseif e == HIDE then\n\t\t\tif auc and tostring(auc) == arg then open, pend = false, {} end", "ah" },
	{ "ah-modern-itemlink-required", F, "and (a.status == nil or a.status == 0) then", "and (a.status == nil or a.status == 0) and a.itemLink then", "ah" },
	{ "ah-unit-not-divided", F, "return floor(buyout / count) end", "return buyout end", "ah" },
	{ "ah-modern-sold-kept", F, "readable(a.quantity) and (a.status == nil or a.status == 0) then", "readable(a.quantity) then", "ah" },
	{ "ah-legacy-unit-zero-kept", F, "readable(buyout) and buyout > 0 and", "readable(buyout) and buyout >= 0 and", "ah" },
	{ "ah-deposit-not-split", F, "deposit = each + (i == 1 and extra or 0)", "deposit = d", "ah" },
}
