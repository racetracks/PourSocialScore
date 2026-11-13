-- Mutants of the warehouse history (build J1W). { id, file, from, to, phases }
return {
	{ "whh-move-writes", "PourSocialScore_Libraries/PSS_WhHist.lua", "add(n, w, old, -1, cont)", "add(n, w, old, 1, cont)", "whh" },
	{ "whh-gold-each", "PourSocialScore_Libraries/PSS_WhHist.lua", "if p and p.hour ~= h then putGold(ent, p) end", "if p then putGold(ent, p) end", "whh" },
	{ "whh-no-compact", "PourSocialScore_Libraries/PSS_WhHist.lua", "if T.day and T.day ~= day then compact(T.day) end", "if false then compact(T.day) end", "whh" },
}
