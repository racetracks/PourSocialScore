-- Mutants of the Journal options and gates (build J1D). { id, file, from, to, phases }
return {
	{ "jrn-no-gate", "PourSocialScore_Libraries/PSS_OptionsView.lua", "if o.key == \"useJournal\" and on and not M.PSS_Opt(\"useWarehouse\") then", "if false then", "opts" },
	{ "jrn-opts-dense", "PourSocialScore/PSS_Options.lua", "if def and value == def.default then value = nil end\n\t\tdb[key] = value", "db[key] = value", "opts" },
	{ "jrn-early-error", "PourSocialScore/PSS_Options.lua", "function M.PSS_Opt(key, ctx)\n\tlocal def = REG[key]", "function M.PSS_Opt(key, ctx)\n\tlocal def = REG[key]\n\tif PourSocialScoreDB == nil then error(\"early\") end", "opts" },
}
