-- The flavour misdetection mutants (multi-version suite, TST-00977): each one is a small wrong change to a
-- copy of PSS_Flavour.lua; at least one of its phases must fail for it. Data only; flv_mutants.sh applies them.
--   { id, file, from, to, phases }   `from` must occur exactly once in the file
local F = "PourSocialScore/PSS_Flavour.lua"
return {
	{ "ifacefirst", F, "if not flavour then\n\tif iface then", "if iface then\n\tflavour = nil\n\tif iface then", "detect" },
	{ "erabound", F, 'elseif iface >= 10000 and iface <= 15999 then flavour = "era"', 'elseif iface >= 10000 and iface <= 49999 then flavour = "era"', "detect" },
	{ "noconstguard", F, "if const ~= nil and const == pid then flavour = name end", "if not flavour and const == pid then flavour = name end", "detect" },
	{ "nildefault", F, '\t\tflavour = "retail"\n\tend\nend', '\t\tflavour = "unknown"\n\tend\nend', "detect" },
	{ "tbcdigit", F, '(flavour == "tbc" and "3")', '(flavour == "tbc" and "1")', "detect" },
	{ "tbcfamily", F, 'if flavour == "retail" or flavour == "forever" then family = "mainline"', 'if flavour == "retail" or flavour == "forever" or flavour == "tbc" then family = "mainline"', "detect" },
	{ "noprobe", F, "if lvl ~= O and probe and not probe() then lvl = O end", "", "probe" },
	{ "degradedoff", F, "return lvl ~= O\nend", 'return lvl ~= O and lvl ~= "degraded"\nend', "can" },
	{ "unknowntrue", F, "\t\treturn false\n\tend\n\treturn lvl ~= O", "\t\treturn true\n\tend\n\treturn lvl ~= O", "can" },
	{ "aliascopy", F, "M.PSS_IsCamelot = M.PSS_IsForever", "function M.PSS_IsCamelot() return false end", "alias" },
}
