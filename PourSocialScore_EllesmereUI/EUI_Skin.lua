-------------------------------------------------------------------------------
--  EUI_Skin.lua -- our frames painted through EllesmereUI's skinning API
--  (SKINNING_API.md). ns.S stays nil while the user has third-party skinning
--  off for this addon; the frames then get a plain dark look.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local EUI = EllesmereUI

if EUI.RegisterSkin then
    EUI.RegisterSkin(ADDON_NAME, function(S) ns.S = S end)
end

local function PlainBorder(frame)
    if EUI.PanelPP and EUI.PanelPP.CreateBorder then
        EUI.PanelPP.CreateBorder(frame, 0.25, 0.25, 0.25, 1)
    end
end

local function PlainFill(frame, a)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, a)
    return bg
end

function ns.Font(fs, size)
    if ns.S then
        ns.S.Font(fs)
    else
        fs:SetFont(EUI.GetFontPath and EUI.GetFontPath() or STANDARD_TEXT_FONT, size or 12, "")
    end
end

function ns.Shell(frame)
    if ns.S then ns.S.Shell(frame) return end
    PlainFill(frame, 0.92)
    PlainBorder(frame)
end

function ns.Panel(frame)
    if ns.S then ns.S.Panel(frame, { inset = true }) return end
    PlainFill(frame, 0.6)
    PlainBorder(frame)
end

function ns.CloseButton(btn)
    if ns.S then ns.S.CloseButton(btn) end
end

function ns.Tab(tab)
    if ns.S then ns.S.Tab(tab) return end
    PlainFill(tab, 0.9)
    PlainBorder(tab)
end

-- Visual selection of a tab this addon switches itself.
function ns.SetTabSelected(tab, selected)
    if ns.S and ns.S.SetTabSelection then
        ns.S.SetTabSelection(tab, selected)
    else
        local fs = tab:GetFontString()
        if fs then fs:SetTextColor(1, 1, 1, selected and 1 or 0.5) end
    end
end
