local _, TK = ...

-- TestKit api allowlist (api-ops.md#tk-a-50-api-allowlist): read-only client APIs the `api` op may call.
-- A new name is a kit build; TK.CMD_ALLOW lists the /pss words the `cmd` op may run (inside an action only).
TK.ALLOW = {
	["GetBuildInfo"] = true,
	["GetLocale"] = true,
	["GetRealmName"] = true,
	["UnitName"] = true,
	["time"] = true,
	["GetTime"] = true,
	["IsInGuild"] = true,
	["GetNumGuildBankTabs"] = true,
	["GetNumMacros"] = true,
	["GetMacroInfo"] = true,
	["GetCVar"] = true,
	["C_CVar.GetCVar"] = true,
	["IsAddOnLoaded"] = true,
	["C_AddOns.IsAddOnLoaded"] = true,
	["GetAddOnMetadata"] = true,
	["C_AddOns.GetAddOnMetadata"] = true,
}

TK.CMD_ALLOW = { version = true, status = true, check = true, mem = true, memory = true }
