------------------------------------------------------------------------
-- POUR SOCIAL SCORE - MACRO HELPER DATA (/pss macro, 3.5.0, Camelot only)
--
-- The macros /pss macro <set> create writes. A set is "global" or a
-- class (key: the class in lower case, one of druid, hunter, mage,
-- paladin, priest, rogue, shaman, warlock, warrior; a class set runs on
-- that class only). Each macro goes to one store: store = "account"
-- (every character) or "character" (this character only). A macro's own
-- store wins, then its set's store, then the default: account for
-- "global", character for a class. /pss macro <set> create account (or
-- character) puts the whole run in one store. PSS owns these names: a
-- macro with the same name in the same store is set to this icon and
-- body. name: 1 to 16 letters, unique across every set; body: up to 255,
-- "\n" between lines; icon: a file ID (134400 is the question mark,
-- which #showtooltip turns into the used item's or spell's icon), or
-- leave it out for the question mark. ASCII only. Macros run in the
-- order written.
--
-- Built on each call and dropped by the caller, so no table stays in
-- memory between commands. Nothing is defined on other clients.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

if not M.PSS_Can("macroCommand") then return end
if not M.PSS_Can("macroCommand") then return end

function M.PSS_MacroData()
	return {
		global = {
			store = "account",
			{ name = "Trinket 1", body = "#showtooltip\n/use 13" },
			{ name = "Trinket 2", body = "#showtooltip\n/use 14" },
			{ name = "Mark-Skull", icon = 132095, body = "/tm 8" },
			{ name = "Mark-X", icon = 132094, body = "/tm 7" },
			{ name = "Mark-Moon", icon = 133938, body = "/tm 5" },
		},
		shaman = {
			store = "character",
			{ name = "HW", body = "#showtooltip Healing Wave\n/cast [help, target=mouseover,exists,help,nodead][]Healing Wave" },
			{ name = "LHW", body = "#showtooltip Lesser Healing Wave\n/cast [help, target=mouseover,exists,help,nodead][]Lesser Healing Wave" },
			{ name = "CH", body = "#showtooltip Chain Heal\n/cast [help, target=mouseover,exists,help,nodead][]Chain Heal" },
			{ name = "RT", body = "#showtooltip Riptide\n/cast [help, target=mouseover,exists,help,nodead][]Riptide" },
		},
		warrior = {
			store = "character",
			{ name = "Attack", body = "#showtooltip\n/startattack" },
			{ name = "BT", body = "#showtooltip\n/cast bloodthirst\n/startattack" },
			{ name = "SS", body = "#showtooltip\n/cast shield slam\n/startattack" },
			{ name = "TC", body = "#showtooltip\n/cast thunder clap\n/startattack" },
			{ name = "Sunder", body = "#showtooltip\n/cast sunder armor\n/startattack" },
			{ name = "Revenge", body = "#showtooltip\n/cast revenge\n/startattack" },
			{ name = "HS", body = "#showtooltip\n/cast heroic strike\n/startattack" },
			{ name = "Cleave", body = "#showtooltip\n/cast cleave\n/startattack" },
		},
	}
end
