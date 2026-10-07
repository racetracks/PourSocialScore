------------------------------------------------------------------------
-- POUR SOCIAL SCORE - WINDOW STATE (for PourSocialScore_UI)
--
-- What the new window remembers and which look it draws. The window only
-- draws; it reads and saves through these.
--   M.PSS_UISkin()                       "blizzard" (default), "modern" or "dark"
--   M.PSS_UIPlace(key)                   point, relPoint, x, y or nil
--   M.PSS_SetUIPlace(key, point, relPoint, x, y)
--   M.PSS_UIFontPath(), M.PSS_UIFontChoices()   (below)
--   M.PSS_UIAccent()                     r, g, b of your class colour, or nil
-- Places are saved with the other window places (PourSocialScoreDB
-- windowPoints, held in PSS_OptionsDB).
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, tonumber, ipairs, pcall = type, tonumber, ipairs, pcall

-- saved values: 1 stays "dark" (it was the only other look first, named Modern)
local SKINS = { [0] = "blizzard", [1] = "dark", [2] = "modern" }

function M.PSS_UISkin()
	return SKINS[tonumber(M.PSS_Opt("uiSkin")) or 0] or "blizzard"
end

function M.PSS_UIPlace(key)
	local db = PourSocialScoreDB
	local p = type(db) == "table" and type(db.windowPoints) == "table" and db.windowPoints[key]
	if type(p) ~= "table" or type(p[1]) ~= "string" then return nil end
	return p[1], p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0
end

function M.PSS_SetUIPlace(key, point, relPoint, x, y)
	local db = PourSocialScoreDB
	if type(db) ~= "table" or type(point) ~= "string" then return end
	if type(db.windowPoints) ~= "table" then db.windowPoints = {} end
	db.windowPoints[key] = { point, relPoint or point, tonumber(x) or 0, tonumber(y) or 0 }
end

-- The window's accent is always your class colour (Dan, 2026-10-07): your
-- own class, never secret. nil only if the client gives none.
function M.PSS_UIAccent()
	local _, class = UnitClass("player")
	if type(class) ~= "string" then return nil end
	local c = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
	c = c or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
	if type(c) == "table" and c.r then return c.r, c.g, c.b end
end

------------------------------------------------------------------------
-- The window's font (option uiFont): a Blizzard font, or one another addon
-- shared through LibSharedMedia. That library is only read, and only when
-- some other addon has loaded it; PSS ships no library.
--   M.PSS_UIFontPath()      the picked font's file, or nil (the look's own)
--   M.PSS_UIFontChoices()   adds the shared fonts to the option's choices
------------------------------------------------------------------------
local LSM_PREFIX = "lsm:"

local function BlizzardFont(key)
	if key == "game" then return STANDARD_TEXT_FONT end
	if key == "names" then return UNIT_NAME_FONT end
	if key == "damage" then return DAMAGE_TEXT_FONT end
	if key == "friz" then return "Fonts\\FRIZQT__.TTF" end
	if key == "arialn" then return "Fonts\\ARIALN.TTF" end
	if key == "morpheus" then return "Fonts\\MORPHEUS.TTF" end
	if key == "skurri" then return "Fonts\\skurri.ttf" end
end

local function SharedMedia()
	local stub = _G.LibStub
	if type(stub) ~= "table" and type(stub) ~= "function" then return nil end
	local ok, lsm = pcall(stub, "LibSharedMedia-3.0", true)
	if ok and type(lsm) == "table" and type(lsm.List) == "function" and type(lsm.Fetch) == "function" then return lsm end
end

function M.PSS_UIFontPath()
	local key = M.PSS_Opt("uiFont")
	if type(key) ~= "string" or key == "" then return nil end
	if key:sub(1, #LSM_PREFIX) == LSM_PREFIX then
		local lsm = SharedMedia()
		if not lsm then return nil end
		local ok, path = pcall(lsm.Fetch, lsm, "font", key:sub(#LSM_PREFIX + 1), true)
		return ok and type(path) == "string" and path or nil
	end
	return BlizzardFont(key)
end

function M.PSS_UIFontChoices()
	local o = M.PSS_OPTION_REG and M.PSS_OPTION_REG.uiFont
	if not o then return {} end
	local lsm = SharedMedia()
	if not lsm then return o.choices end
	local have = {}
	for _, ch in ipairs(o.choices) do have[ch[1]] = true end
	local ok, names = pcall(lsm.List, lsm, "font")
	if ok and type(names) == "table" then
		for _, name in ipairs(names) do
			if type(name) == "string" and not have[LSM_PREFIX .. name] then
				have[LSM_PREFIX .. name] = true
				o.choices[#o.choices + 1] = { LSM_PREFIX .. name, name }
			end
		end
	end
	return o.choices
end
