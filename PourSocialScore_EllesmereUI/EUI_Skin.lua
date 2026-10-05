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

-- The selected tab, as EllesmereUI's Friends window shows Contacts / Raid:
-- a faint white wash over the tab and a pixel line across its bottom in
-- the accent colour (EllesmereUI's theme: class colour, faction, a preset
-- or custom). Drawn by us in both looks, so it shows on any EllesmereUI
-- version; S.SetTabSelection (skin API 2+) also brightens S.Tab's label.
local tabs = {}

local function AccentColor()
    if ns.S and ns.S.GetAccentColor then return ns.S.GetAccentColor() end
    local c = EUI.ELLESMERE_GREEN or {}
    return c.r or 0.047, c.g or 0.824, c.b or 0.616
end

local function PaintMark(tab)
    local r, g, b = AccentColor()
    tab.pssUnderline:SetColorTexture(r, g, b, 1)
end

local function Mark(tab)
    local wash = tab:CreateTexture(nil, "ARTWORK", nil, 7)
    wash:SetAllPoints()
    wash:SetColorTexture(1, 1, 1, 0.05)
    wash:SetBlendMode("ADD")
    wash:Hide()
    tab.pssWash = wash
    local line = tab:CreateTexture(nil, "OVERLAY", nil, 7)
    local pp = EUI.PanelPP
    if pp and pp.DisablePixelSnap then pp.DisablePixelSnap(line) end
    line:SetHeight(pp and pp.mult or 1)
    line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
    line:Hide()
    tab.pssUnderline = line
    PaintMark(tab)
    if #tabs == 0 and ns.S and ns.S.OnLooksChanged then
        ns.S.OnLooksChanged(function() for i = 1, #tabs do PaintMark(tabs[i]) end end)
    end
    tabs[#tabs + 1] = tab
end

-- S.Tab draws its own label over ours; our label is faded only by colour,
-- which the button resets on state changes, so it showed through as a ghost.
function ns.Tab(tab)
    if ns.S then
        ns.S.Tab(tab)
        local fs = tab:GetFontString()
        if fs then fs:SetAlpha(0) end
    else
        PlainFill(tab, 0.9)
        PlainBorder(tab)
    end
    Mark(tab)
end

-- Visual selection of a tab this addon switches itself.
function ns.SetTabSelected(tab, selected)
    selected = selected and true or false
    PaintMark(tab)
    tab.pssWash:SetShown(selected)
    tab.pssUnderline:SetShown(selected)
    if ns.S then
        -- S.Tab's label: bright when selected. Skin API 2 takes it directly;
        -- older versions read the button's isSelected on their next tab
        -- update (a tab click, or the PanelTemplates hook nudged here).
        tab.isSelected = selected
        if ns.S.SetTabSelection and (ns.S.apiVersion or 0) >= 2 then
            ns.S.SetTabSelection(tab, selected)
        elseif PanelTemplates_UpdateTabs then
            pcall(PanelTemplates_UpdateTabs, {})
        end
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

function ns.EditBox(eb, opts)
    if ns.S then ns.S.EditBox(eb, opts) end
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

-- A search box: EllesmereUI's skinned edit box (S.EditBox with its padded
-- input) with a magnifier, a grey hint while empty and a clear button
-- while not. onChange(text) runs as you type; Escape clears it.
function ns.NewSearchBox(parent, w, hint, onChange)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w, 20)
    eb:SetAutoFocus(false)
    eb:SetTextInsets(16, 18, 0, 0)
    ns.EditBox(eb, { padInput = true })
    local icon = eb:CreateTexture(nil, "OVERLAY")
    icon:SetSize(12, 12)
    icon:SetPoint("LEFT", eb, "LEFT", 2, 0)
    icon:SetAtlas("common-search-magnifyingglass")
    icon:SetAlpha(0.6)
    local text = ns.NewText(eb, 11)
    text:SetPoint("LEFT", eb, "LEFT", 18, 0)
    text:SetTextColor(1, 1, 1, 0.4)
    text:SetText(hint)
    local clear = CreateFrame("Button", nil, eb)
    clear:SetSize(14, 14)
    clear:SetPoint("RIGHT", eb, "RIGHT", -2, 0)
    local x = clear:CreateTexture(nil, "ARTWORK")
    x:SetAllPoints()
    x:SetAtlas("common-search-clearbutton")
    x:SetAlpha(0.6)
    clear:SetScript("OnEnter", function() x:SetAlpha(1) end)
    clear:SetScript("OnLeave", function() x:SetAlpha(0.6) end)
    clear:SetScript("OnClick", function() eb:SetText(""); eb:ClearFocus() end)
    clear:Hide()
    eb:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        text:SetShown(t == "")
        clear:SetShown(t ~= "")
        onChange(t)
    end)
    eb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb.hint, eb.clear = text, clear
    return eb
end

function ns.TipOn(frame, owner, text)
    frame:SetScript("OnEnter", function() ns.Tip(owner, text) end)
    frame:SetScript("OnLeave", ns.HideTip)
end

