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
}
