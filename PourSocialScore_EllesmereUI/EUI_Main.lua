-------------------------------------------------------------------------------
--  EUI_Main.lua -- Pour Social Score in EllesmereUI's style, loaded on demand.
--  The core (PSS_EUI.lua) loads this addon for the window at Friends,
--  /pss gui, and the pages of its "Pour Social Score" panel section.
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

-------------------------------------------------------------------------------
--  Panel pages (EllesmereUI plugin API; registered by the core)
-------------------------------------------------------------------------------
local function BuildOptionsGeneral(parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h
    _, h = W:SectionHeader(parent, "POUR SOCIAL SCORE", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "labeledButton", text = "Pour Social Score window", buttonText = "Open",
          tooltip = "The window that opens next to your Friends list. /pss gui opens it too.",
          onClick = function() M.EUI_Toggle(true) end },
        { type = "toggle", text = "Enable EllesmereUI integration",
          tooltip = "Turn off to go back to the Pour Social Score windows. Asks to reload.",
          getValue = function() return M.PSS_Opt("euiIntegration") end,
          setValue = function(v) M.PSS_SetOpt("euiIntegration", "global", v) end }); y = y - h
    return math.abs(y)
end

function M.EUI_BuildPage(module, page, parent, yOffset)
    if module == "Options" and page == "General" then
        return BuildOptionsGeneral(parent, yOffset)
    end
    return 0
end
