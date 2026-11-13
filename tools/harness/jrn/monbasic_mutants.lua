-- Mutants of the basic monitors (build J2B). { id, file, from, to, phases }
return {
	{ "trade-cancel-writes", "PourSocialScore_Libraries/PSS_JrnMonBasic.lua", "p[3] == ERR_TRADE_COMPLETE then", "(p[3] == ERR_TRADE_COMPLETE or p[3] == ERR_TRADE_CANCELLED) then", "monbasic" },
}
