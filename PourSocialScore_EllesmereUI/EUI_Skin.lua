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

-- S.Tab draws its own label over ours; our label is faded only by colour,
-- which the button resets on state changes, so it showed through as a ghost.
function ns.Tab(tab)
    if ns.S then
        ns.S.Tab(tab)
        local fs = tab:GetFontString()
        if fs then fs:SetAlpha(0) end
        return
    end
    PlainFill(tab, 0.9)
    PlainBorder(tab)
end

-- Visual selection of a tab this addon switches itself.
function ns.SetTabSelected(tab, selected)
    if ns.S and ns.S.SetTabSelection then
        ns.S.SetTabSelection(tab, selected)
    else
        -- Alpha, not text colour: colour alpha leaves the shadow at full
        -- strength, which read as a second, offset label.
        local fs = tab:GetFontString()
        if fs then fs:SetAlpha(selected and 1 or 0.5) end
    end
end

-- Controls of the Options and Import/Export tabs. Without skinning they keep
-- their Blizzard template art.
function ns.Checkbox(cb)
    if ns.S then ns.S.Checkbox(cb) end
end

function ns.EditBox(eb)
    if ns.S then ns.S.EditBox(eb) end
end

function ns.Dropdown(dd)
    if ns.S then ns.S.Dropdown(dd) end
end

function ns.Button(btn)
    if ns.S then
        ns.S.Button(btn)
        ns.S.WhiteButtonLabel(btn)
    end
end

function ns.ScrollBar(sb)
    if ns.S and sb then ns.S.ScrollBar(sb) end
end

-- Plain-text tooltips through EllesmereUI's own (house rule).
function ns.Tip(owner, text)
    if EUI.ShowWidgetTooltip then EUI.ShowWidgetTooltip(owner, text) end
end

function ns.HideTip()
    if EUI.HideWidgetTooltip then EUI.HideWidgetTooltip() end
end
