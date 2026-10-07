------------------------------------------------------------------------
-- POUR SOCIAL SCORE - WINDOW STATE (for PourSocialScore_UI)
--
-- What the new window remembers and which look it draws. The window only
-- draws; it reads and saves through these.
--   M.PSS_UISkin()                       "blizzard" (default) or "modern"
--   M.PSS_UIPlace(key)                   point, relPoint, x, y or nil
--   M.PSS_SetUIPlace(key, point, relPoint, x, y)
-- Places are saved with the other window places (PourSocialScoreDB
-- windowPoints, held in PSS_OptionsDB).
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, tonumber = type, tonumber

local SKINS = { [0] = "blizzard", [1] = "modern" }

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
