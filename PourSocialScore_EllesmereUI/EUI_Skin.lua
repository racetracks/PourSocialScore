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

-------------------------------------------------------------------------------
--  Controls shared by the window tabs (each painted by the helpers above)
-------------------------------------------------------------------------------
function ns.NewText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ns.Font(fs, size or 12)
    fs:SetTextColor(1, 1, 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

function ns.NewHeading(parent, text)
    local fs = ns.NewText(parent, 13)
    if ns.S then fs:SetTextColor(ns.S.GetAccentColor()) else fs:SetTextColor(1, 0.82, 0) end
    fs:SetText(text)
    return fs
end

function ns.NewCheck(parent)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    ns.Checkbox(c)
    return c
end

function ns.NewNumberBox(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    e:SetNumeric(true)
    e:SetJustifyH("CENTER")
    ns.EditBox(e)
    return e
end

-- commit on Enter and focus loss, once (ClearFocus fires focus loss again)
function ns.OnCommit(e, commit, refresh)
    local busy
    local function run(self)
        if busy then return end
        busy = true
        commit(self:GetText())
        self:ClearFocus()
        refresh()
        busy = false
    end
    e:SetScript("OnEnterPressed", run)
    e:SetScript("OnEditFocusLost", run)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refresh() end)
end

function ns.NewDropdown(parent, w, choices, onPick)
    local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    d:SetWidth(w)
    d:SetupMenu(function(dd, root)
        for _, ch in ipairs(choices) do
            root:CreateButton(ch[2], function() onPick(ch[1]) end)
        end
    end)
    ns.Dropdown(d)
    return d
end

function ns.NewButton(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    ns.Button(b)
    return b
end

function ns.TipOn(frame, owner, text)
    frame:SetScript("OnEnter", function() ns.Tip(owner, text) end)
    frame:SetScript("OnLeave", ns.HideTip)
end

