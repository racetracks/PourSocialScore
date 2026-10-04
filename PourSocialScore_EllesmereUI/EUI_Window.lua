-------------------------------------------------------------------------------
--  EUI_Window.lua -- the Pour Social Score window in EllesmereUI's style.
--  Opens next to the Friends window (option "openWithFriends") and with
--  /pss gui; dragged elsewhere it remembers the place for /pss gui.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI

local WIN_W, WIN_H = 960, 470
local TAB_H = 24
local TABS = {
    { "Player Ignore List", "The Player Ignore List comes in the next test build (E.4)." },
    { "Guild Ignore List",  "The Guild Ignore List comes in test build E.5." },
    { "Chat Filters",       "Chat Filters and the block history come in test build E.6." },
    { "Import/Export",      nil, "BuildImportExportTab" },
    { "Options",            nil, "BuildOptionsTab" },
}

local win

local function SavePlace()
    local point, _, relPoint, x, y = win:GetPoint(1)
    if point then ns.DB().point = { point, relPoint, x, y } end
end

local function RestorePlace()
    win:ClearAllPoints()
    local p = ns.DB().point
    if p then
        win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- A tab with a builder (TABS[i][3], in EUI_Options.lua) is built on first
-- open; its builder returns the function that redraws it from saved data.
local function SelectTab(id)
    local page = win.pages[id]
    local build = TABS[id][3]
    if build and not page.refresh then page.refresh = ns[build](page) end
    for i, tab in ipairs(win.tabs) do
        ns.SetTabSelected(tab, i == id)
        win.pages[i]:SetShown(i == id)
    end
    if page.refresh then page.refresh() end
    ns.DB().tab = id
end

-- M.EUI_Refresh: redraw the tab on show (the others redraw when selected)
function ns.RefreshTabs()
    if not (win and win:IsShown()) then return end
    local page = win.pages[ns.DB().tab or 1]
    if page and page.refresh then page.refresh() end
end

local function Build()
    win = CreateFrame("Frame", "PSS_EllesmereUIWindow", UIParent)
    win:Hide()
    win:SetSize(WIN_W, WIN_H)
    win:SetFrameStrata(M.PSS_FrameStrataName())
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePlace()
    end)
    ns.Shell(win)
    if EUI.RegisterEscapeClose then
        EUI.RegisterEscapeClose(win)
    else
        tinsert(UISpecialFrames, "PSS_EllesmereUIWindow")
    end

    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", win, "TOP", 0, -6)
    title:SetText("Pour Social Score")
    ns.Font(title, 13)
    title:SetTextColor(1, 1, 1)

    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
    ns.CloseButton(close)

    win.tabs, win.pages = {}, {}
    local prev
    for i, t in ipairs(TABS) do
        local tab = CreateFrame("Button", nil, win)
        tab:SetNormalFontObject(GameFontHighlightSmall)
        tab:SetText(t[1])
        tab:SetSize(tab:GetFontString():GetStringWidth() + 32, TAB_H)
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        else
            tab:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -32)
        end
        tab:SetScript("OnClick", function() SelectTab(i) end)
        ns.Tab(tab)
        win.tabs[i] = tab
        prev = tab

        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -32 - TAB_H - 6)
        page:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10)
        page:Hide()
        ns.Panel(page)
        if t[2] then
            local note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            note:SetPoint("CENTER")
            note:SetWidth(WIN_W - 120)
            note:SetText(t[2])
            ns.Font(note, 12)
            note:SetTextColor(1, 1, 1, 0.7)
        end
        win.pages[i] = page
    end
    SelectTab(ns.DB().tab or 1)

    M.Events.Register("OPTION_CHANGED", function(key)
        if key == "frameStrata" then win:SetFrameStrata(M.PSS_FrameStrataName()) end
    end)
end

-- /pss gui; show true opens without toggling.
function M.EUI_Toggle(show)
    if not win then Build() end
    if win:IsShown() and not show then
        win:Hide()
        return
    end
    win.byFriends = nil
    RestorePlace()
    win:Show()
    win:Raise()
end

function M.EUI_FriendsShow(anchor)
    if not win then Build() end
    win:ClearAllPoints()
    win:SetPoint("TOPLEFT", anchor or FriendsFrame, "TOPRIGHT", 12, -10)
    win.byFriends = true
    win:Show()
end

function M.EUI_FriendsHide()
    if win and win.byFriends then win:Hide() end
end
