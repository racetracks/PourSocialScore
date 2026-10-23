local addonName, addon = ...
local M = addon.M
local V = addon.V

-- Client flavour record, capability levels and the capability API
-- (multi-version suite). Detection runs once, at load; project id first,
-- interface second. Features read M.PSS_Can, never a client test.

local select = select
local type = type
local error = error
local pairs = pairs
local tostring = tostring

local pid = WOW_PROJECT_ID
local iface = GetBuildInfo and select(4, GetBuildInfo())
if type(iface) ~= "number" then iface = nil end

local flavour
local rows = {
	{ WOW_PROJECT_MAINLINE, "retail" },
	{ WOW_PROJECT_CAMELOT, "forever" },
	{ WOW_PROJECT_BURNING_CRUSADE_CLASSIC, "tbc" },
	{ WOW_PROJECT_CLASSIC, "era" },
	{ WOW_PROJECT_MISTS_CLASSIC, "mists" },
}
for i = 1, #rows do
	local r = rows[i]
	if r[1] ~= nil and r[1] == pid then flavour = r[2]; break end
end
if not flavour then
	if iface then
		if iface >= 100000 then flavour = "retail"
		elseif iface >= 50000 and iface <= 59999 then flavour = "mists"
		elseif iface >= 20000 and iface <= 29999 then flavour = "tbc"
		elseif iface >= 16000 and iface <= 16999 then flavour = "forever"
		elseif iface >= 10000 and iface <= 15999 then flavour = "era"
		else flavour = "unknown" end
	else
		flavour = "retail"
	end
end

local family
if flavour == "retail" or flavour == "forever" then family = "mainline"
elseif flavour == "unknown" and (iface or 0) >= 100000 then family = "mainline"
elseif flavour == "unknown" then family = "classic"
else family = "classic" end

local DIGITS = { retail = "1", forever = "2", tbc = "3", era = "4", mists = "5" }

-- levels per flavour: { retail, forever, tbc, era, mists } (design.md#capability-table)
local S, O = "supported", "off"
local LEVELS = {
	reloadButton = { O, S, O, O, O },
	gfxCommand = { O, S, O, O, O },
	macroCommand = { O, S, O, O, O },
	surnames = { O, S, O, O, O },
	compartment = { S, O, S, S, S },
	modernMenu = { S, S, S, S, S },
	cContainer = { S, S, S, S, S },
	secretValues = { S, S, O, O, O },
	guildBank = { S, S, S, O, S },
	friendsAnchor = { O, O, S, O, O },
}
local COL = { retail = 1, forever = 2, tbc = 3, era = 4, mists = 5 }
local col = COL[flavour]
if not col then col = (family == "mainline") and 1 or 4 end

-- probes: a false probe forces the level to off
local PROBES = {
	compartment = function() return AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon end,
	modernMenu = function() return Menu and Menu.ModifyMenu end,
	secretValues = function() return issecretvalue end,
	cContainer = function() return C_Container end,
	guildBank = function() return GetGuildBankItemInfo end,
	friendsAnchor = function() return FriendsFrame and FriendsFrame.NineSlice end,
}

local caps = {}
for cap, row in pairs(LEVELS) do
	local lvl = row[col]
	local probe = PROBES[cap]
	if lvl ~= O and probe and not probe() then lvl = O end
	caps[cap] = lvl
end

M.PSS_FLV = {
	flavour = flavour, family = family, interface = iface, projectId = pid,
	digit = DIGITS[flavour] or "0", caps = caps,
}
local FLV = M.PSS_FLV

V.wowIsRetail = (flavour == "retail")

function M.PSS_IsForever()
	return FLV.flavour == "forever"
end
M.PSS_IsCamelot = M.PSS_IsForever

function M.PSS_CapLevel(cap)
	return caps[cap] or O
end

function M.PSS_Can(cap)
	local lvl = caps[cap]
	if lvl == nil then
		local t = M.PSS_Test
		if t and t.strict then error("unknown capability: " .. tostring(cap), 2) end
		return false
	end
	return lvl ~= O
end
