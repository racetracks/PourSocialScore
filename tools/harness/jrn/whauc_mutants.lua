-- Mutants of the warehouse auctions read (build J2IL). { id, file, from, to, phases }
return {
	{ "whauc-needs-link", "PourSocialScore_Libraries/PSS_ItemRead.lua", "if a and a.quantity ~= 0 then add(out, ent, code, i, a.itemLink,", "if a and a.itemLink and a.quantity ~= 0 then add(out, ent, code, i, a.itemLink,", "whauc" },
}
