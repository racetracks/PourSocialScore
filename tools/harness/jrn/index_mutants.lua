-- Mutants of the Journal index (build J1I). { id, file, from, to, phases }
return {
	{ "jrn-trim-wrong-month", "PourSocialScore_Libraries/PSS_JrnIx.lua", "cap = { months = \"jrnMonths\" }", "cap = { months = \"jrnMonthz\" }", "index" },
	{ "jrn-post-stale", "PourSocialScore_Libraries/PSS_JrnIx.lua", "sourceVer = function() return store:ver() end", "sourceVer = function() return 0 end", "index" },
	{ "jrn-off-writes", "PourSocialScore_Libraries/PSS_JrnIx.lua", "if not M.PSS_On(\"journal\") then return 0 end\n\tlocal hot", "local hot", "index" },
}
