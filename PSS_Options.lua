------------------------------------------------------------------------
-- POUR SOCIAL SCORE - OPTIONS
--
-- Every option has one account-wide value (the Options tab, stored at the
-- top level of PourSocialScoreDB). Options that make sense per target (e.g.
-- "Send ignore response to ignored players") can additionally be overridden
-- per GUILD rule and per PERSON (guild member or ignored player) from their
-- right-click menus / the player detail window.
--
-- Resolution (most specific wins):  person > guild > Options tab > default
-- (2.0.12 removed the per-character layer: it had no visible effect for most
-- people and an override set there could not be seen anywhere else.)
--
--   M.PSS_Opt(key [, ctx])     ctx = { person = <opts table>, guild = <opts table> }
--   M.PSS_SetOpt(key, scope, value [, target])  scope: "global" | "guild" | "person"
--                                               value nil clears an override
------------------------------------------------------------------------
local addonName, addon = ...
local L = addon.L
local V = addon.V
local M = addon.M

local OPTIONS = {
	-- Ignore list
	{ key = "asknote",			kind = "bool",		default = true, section = 1, label = L["OPT_1"] },
	{ key = "sameserver",		kind = "bool",		default = true,		section = 1, label = L["OPT_4"] },
	{ key = "samefaction",		kind = "bool",		default = true,		section = 1, label = L["OPT_27"] },
	{ key = "trackChanges",		kind = "bool",		default = true,		section = 1, label = L["OPT_6"] },
	{ key = "chatmsg",			kind = "bool",		default = true,		section = 1, label = L["OPT_26"] },
	{ key = "showWarning",		kind = "bool",		default = true, section = 1, label = L["OPT_18"] },
	{ key = "defexpire",		kind = "number", default = 0,		section = 1, label = L["OPT_5"] },
	-- Blocking (people)
	{ key = "blizzardSync",		kind = "bool",		default = false, section = 1, label = "Also put listed players on Blizzard's ignore list (it ignores exclusions)" },
	{ key = "ignoreResponse", kind = "bool",	default = false,	section = 2, label = L["OPT_24"], target = true },
	{ key = "showDeclines",		kind = "bool",		default = true,		section = 2, label = L["OPT_28"], target = true },
	{ key = "declineDuel",		kind = "bool",		default = true,		section = 2, label = "Decline duels from blocked players", target = true },
	{ key = "declineTrade",		kind = "bool",		default = true,		section = 2, label = "Decline trades from blocked players", target = true },
	{ key = "historyTotal",		kind = "number", default = 2000,	section = 2, min = 100, max = 20000,
		label = "Block history lines kept in total, shared by every player, guild and filter (100-20000; a larger buffer increases memory usage)" },
	{ key = "purgeHistory",		kind = "bool",		default = true,		section = 2, label = "Remove a player's earlier chat lines when they become blocked" },
	-- Chat filters
	{ key = "spamFilter",		kind = "bool",		default = true,		section = 3, label = L["OPT_7"] },
	{ key = "invertSpam",		kind = "bool",		default = false, section = 3, label = L["OPT_10"] },
	{ key = "floodFilter",		kind = "choice", default = 0,		section = 3, label = L["OPT_20"],
		choices = { { 0, L["OPT_21"] }, { 1, L["OPT_22"] }, { 2, L["OPT_23"] } } },
	{ key = "skipGuild",		kind = "bool",		default = true,		section = 3, label = L["OPT_12"] },
	{ key = "skipParty",		kind = "bool",		default = false, section = 3, label = L["OPT_13"] },
	{ key = "skipPrivate",		kind = "bool",		default = true,		section = 3, label = L["OPT_14"] },
	{ key = "skipYourself",		kind = "bool",		default = false, section = 3, label = L["OPT_19"] },
	-- User interface
	{ key = "openWithFriends", kind = "bool",	default = true,		section = 4, label = L["OPT_2"] },
	{ key = "useUnitHacks",		kind = "bool",		default = true,		section = 4, label = L["OPT_16"] },
	{ key = "useLFGHacks",		kind = "bool",		default = true,		section = 4, label = L["OPT_17"] },
	{ key = "gcEnabled",		kind = "bool",		default = true,		section = 4, label = "Background memory cleanup (out of combat, never causes a hitch)" },
	{ key = "frameStrata",		kind = "choice", default = 3,		section = 4, label = L["OPT_25"],
		choices = { { 0, "LOW" }, { 1, "MEDIUM" }, { 2, "HIGH" }, { 3, "DIALOG" } } },
	-- Whois scans (Scan, Scan All, Custom, Guild Search): see PSS_WhoisHarvest.lua.
	-- The cap is drawn in the tickbox's row (field) and must be set to tick it.
	{ key = "whoLevelCapOn",	kind = "bool",		default = false, section = 5, label = "Enable scan level cap", field = "whoLevelCap",
		tip = "When ticked, no /who scan searches above this level: Scan and Scan All stop their level brackets at the cap, Custom and Guild Search are limited to it." },
	{ key = "whoLevelCap",		kind = "number", default = nil,		section = 5, min = 1, max = 999, inline = true, label = "Scan level cap" },
}
local SECTIONS = { L["OPT_8"], "Blocking Options:", L["OPT_9"], L["OPT_15"], "Whois Scan Options:" }

local REG = {}
for _, o in ipairs(OPTIONS) do REG[o.key] = o end
M.PSS_OPTIONS = OPTIONS
M.PSS_OPTION_REG = REG
M.PSS_OPTION_SECTIONS = SECTIONS

------------------------------------------------------------------------
-- Resolution
------------------------------------------------------------------------
local charKeyCache
local function charKey()
	if not charKeyCache and UnitName then
		local n, r = UnitName("player")
		if n then charKeyCache = M.PSS_NormalizePlayer((r and r ~= "") and (n .. "-" .. r) or n) end
	end
	return charKeyCache
end
M.PSS_CharKey = charKey

function M.PSS_Opt(key, ctx)
	local def = REG[key]
	if ctx and def and def.target then
		local person, guild = ctx.person, ctx.guild
		if type(person) == "table" and person[key] ~= nil then return person[key] end
		if type(guild) == "table" and guild[key] ~= nil then return guild[key] end
	end
	local db = PourSocialScoreDB
	if db and db[key] ~= nil then return db[key] end
	if def then return def.default end
	return nil
end

local STRATA = { [0] = "LOW", [1] = "MEDIUM", [2] = "HIGH", [3] = "DIALOG" }
function M.PSS_FrameStrataName()
	return STRATA[tonumber(M.PSS_Opt("frameStrata")) or 3] or "DIALOG"
end

-- Options whose effect must be applied immediately when changed.
local function applyLive()
	local main = _G["PSS"]
	if main and main.SetFrameStrata then main:SetFrameStrata(M.PSS_FrameStrataName()) end
end

-- target: the record whose .opts holds the override (guild rule, member,
-- or player record) for scope "guild"/"person".
function M.PSS_SetOpt(key, scope, value, target)
	local db = PourSocialScoreDB
	if not db then return end
	if scope == "global" then
		db[key] = value
	elseif (scope == "guild" or scope == "person") and type(target) == "table" then
		if M.PSS_KeepManaged then M.PSS_KeepManaged(target) end		-- shipped member: save it
		target.opts = target.opts or {}
		target.opts[key] = value
		if next(target.opts) == nil then target.opts = nil end
	end
	if key == "frameStrata" then applyLive() end
	-- a smaller history buffer frees the memory now, not only as lines arrive
	if key == "historyTotal" and M.PSS_TrimAllHistory then M.PSS_TrimAllHistory() end
end

-- New options get their global default once (old ones keep saved values).
function M.PSS_ApplyOptionDefaults()
	local db = PourSocialScoreDB
	if not db then return end
	-- 2.0.12: these two are off by default. Saved values were almost always
	-- just the old default (on), so they are switched off once; turn them
	-- back on in the Options tab if you want them.
	if not db.optionsV2012 then
		db.ignoreResponse = false
		db.blizzardSync = false
		db.charOptions = nil		-- per-character overrides are gone (see top)
		db.optionsV2012 = true
	end
	for _, o in ipairs(OPTIONS) do
		if db[o.key] == nil then db[o.key] = o.default end
	end
end
