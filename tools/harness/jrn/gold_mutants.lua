-- Mutants of the gold and history phases (build J2G1). { id, file, from, to, phases }; the ones that name the fixed
-- text of J2G2 and J2G3 (rows S1 to S3, S6 of gold.md) apply once those rows have landed
return {
	{ "gold-no-logout-put", "PourSocialScore_Libraries/PSS_WhHist.lua", "for ent, p in pairs(pend) do putGold(ent, p) end", "for ent, p in pairs(pend) do end", "gold" },
	{ "gold-put-every-change", "PourSocialScore_Libraries/PSS_WhHist.lua", "if p and p.hour ~= h then putGold(ent, p) end", "if p then putGold(ent, p) end", "gold" },
	{ "compact-keeps-all-g", "PourSocialScore_Libraries/PSS_WhHist.lua", "if r.st == \"whh.g\" then lastG[r.ent] = r", "if r.st == \"whh.g\" then lastG[r.time] = r", "gold" },
	{ "whh-flush-before-write", "PourSocialScore_Libraries/PSS_WhHist.lua", "if d ~= 0 then M.PSS_IxPut(\"whh\", \"whh.d\"", "if d == 0 then M.PSS_IxPut(\"whh\", \"whh.d\"", "gold" },
	{ "gold-pend-hidden", "PourSocialScore_Libraries/PSS_WhHist.lua", "{ st = \"whh.g\", time = p.t, ent = ent, copper = p.copper }", "{ st = \"whh.x\", time = p.t, ent = ent, copper = p.copper }", "gold" },
	{ "hist-before-commit", "PourSocialScore_Libraries/PSS_WhStore.lua", "if not ok then M.PSS_ErrNote(\"fail\", \"wh.write\", \"whh: \" .. tostring(why)) end", "if not ok then error(why, 0) end", "gold" },
	{ "seal-no-jrn", "PourSocialScore_Libraries/PSS_WhHist.lua", "M.PSS_IxFlush(\"jrn\")", "", "gold" },
	{ "seal-no-login-trim", "PourSocialScore_Libraries/PSS_WhHist.lua", "M.PSS_JrnSeal(\"login\")", "", "gold" },
	{ "seal-no-months-hook", "PourSocialScore/PSS_Options.lua", "if key == \"jrnMonths\" and M.PSS_JrnSeal then M.PSS_JrnSeal(\"months\") end", "", "gold" },
	{ "journal-ignores-whon", "PourSocialScore/PSS_Options.lua", "(not liveOn(\"warehouse\") or M.PSS_WhOn == false)", "(not liveOn(\"warehouse\"))", "gold" },
}
