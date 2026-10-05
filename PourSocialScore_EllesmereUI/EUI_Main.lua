-------------------------------------------------------------------------------
--  EUI_Main.lua -- Pour Social Score in EllesmereUI's style, loaded on demand.
--  The core (PSS_EUI.lua) loads this addon for the window at Friends,
--  /pss gui, and the pages of its "Pour Social Score" panel section
--  (EUI_Options.lua).
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = PourSocialScore_NS.M
ns.M = M

-- Saved settings of this front end only; the PSS settings stay in the core.
function ns.DB()
    return PSS_EllesmereUIDB
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if type(PSS_EllesmereUIDB) ~= "table" then PSS_EllesmereUIDB = {} end
end)
