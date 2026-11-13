-- Mutants of the vendor and repair monitors (build J2A). { id, file, from, to, phases }
return {
	{ "vend-money-only", "PourSocialScore_Libraries/PSS_JrnMon1.lua", "if now[p.key] ~= p.sig and gained >= total then", "if gained >= total then", "mon1" },
	{ "vend-double-match", "PourSocialScore_Libraries/PSS_JrnMon1.lua", "gained = gained - total; done = true", "gained = gained - total", "mon1" },
	{ "secret-compared", "PourSocialScore_Libraries/PSS_JrnMon1.lua", "local function readable(v) if M.PSS_IsSecret(v) then return false end return v ~= nil end", "local function readable(v) return v ~= nil end", "mon1" },
}
