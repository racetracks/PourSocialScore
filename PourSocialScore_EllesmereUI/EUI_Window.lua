-------------------------------------------------------------------------------
--  EUI_Window.lua -- the Pour Social Score window in EllesmereUI's style.
--  Opens next to the Friends window (option "openWithFriends") and with
--  /pss gui; dragged elsewhere it remembers the place for /pss gui.
--  Back / forward arrows under the tabs (and mouse buttons 4 / 5) step
--  through the views shown; Escape goes up one level (a Block History
--  view back to its tab, the guild members back to the guild list) and
--  closes the window from the top.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI

local WIN_W, WIN_H = 960, 494
local TAB_H = 24
local NAV_H = 20
local NAV_MAX = 50
local TABS = {
    { "Player Ignore List", nil, "BuildPlayersTab" },
    { "Guild Ignore List",  nil, "BuildGuildsTab" },
    { "Chat Filters",       nil, "BuildFiltersTab" },
    { "Import/Export",      nil, "BuildImportExportTab" },
    { "Options",            nil, "BuildOptionsTab" },
}

local win

-- the views shown, oldest first: { tab = id, view = what the page's
-- navState() returned (nil: its main view) }; navPos is the one shown
local nav, navPos, applying = {}, 0, false

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

-- A tab with a builder (TABS[i][3], in EUI_Players.lua, EUI_Guilds.lua,
-- EUI_Filters.lua or EUI_Options.lua) is
-- built on first open; its builder returns the function that redraws it from
-- saved data.
local function SelectTab(id)
    local page = win.pages[id]
    local build = TABS[id][3]
    if build and not page.refresh then
        -- a tab that fails to build still reports its error and becomes the
        -- selected tab; it is built again on the next click
        local ok, refresh = xpcall(function() return ns[build](page) end, geterrorhandler())
        if ok then page.refresh = refresh end
    end
    for i, tab in ipairs(win.tabs) do
        ns.SetTabSelected(tab, i == id)
        -- a tab showing its Block History view shows that in its place
        local hv = win.pages[i].hview
        local hist = hv and hv:IsOpen()
        win.pages[i]:SetShown(i == id and not hist)
        if hv then hv.frame:SetShown(i == id and hist) end
    end
    if page.hview and page.hview:IsOpen() then page.hview:Refresh(false)
    elseif page.refresh then page.refresh() end
    ns.DB().tab = id
end

-- M.EUI_Refresh: redraw the tab on show (the others redraw when selected)
function ns.RefreshTabs()
    if not (win and win:IsShown()) then return end
    local page = win.pages[ns.DB().tab or 1]
    if page and page.hview and page.hview:IsOpen() then page.hview:Refresh(false)
    elseif page and page.refresh then page.refresh() end
end

-------------------------------------------------------------------------------
--  Back / forward. A page with sub-views gives navState() (its view now),
--  navApply(view) (show it again), navUp() (one level up; true if it went)
--  and navTitle(view) (for the line by the arrows). A Block History view
--  (EUI_HistoryView.lua, page.hview) is a step of its own over the page.
-------------------------------------------------------------------------------
local function ShownState()
    local tab = ns.DB().tab or 1
    local page = win.pages[tab]
    local hv = page.hview
    return tab, page.navState and page.navState() or nil, hv and hv.spec or nil
end

local function HistKey(spec)
    return spec and (tostring(spec.kind) .. "\001" .. tostring(spec.id)
        .. "\001" .. tostring(spec.period)) or nil
end

local function UpdateNav()
    win.back:SetEnabled(navPos > 1)
    win.forward:SetEnabled(navPos < #nav)
    local tab, view, hist = ShownState()
    local page = win.pages[tab]
    local where = TABS[tab][1]
    if view ~= nil and page.navTitle then where = where .. "  >  " .. page.navTitle(view) end
    if hist then where = where .. "  >  Block History: " .. tostring(page.hview.name or "?") end
    win.where:SetText(where)
end

-- After the user changed the view: a new step (dropping any forward steps).
function ns.NavRecord()
    if applying or not win then return end
    local tab, view, hist = ShownState()
    local top = nav[navPos]
    if not (top and top.tab == tab and top.view == view and HistKey(top.hist) == HistKey(hist)) then
        for i = #nav, navPos + 1, -1 do nav[i] = nil end
        nav[#nav + 1] = { tab = tab, view = view, hist = hist }
        if #nav > NAV_MAX then table.remove(nav, 1) end
        navPos = #nav
    end
    UpdateNav()
end

local function Go(pos)
    local st = nav[pos]
    if not st then return end
    navPos = pos
    applying = true
    local ok, err = pcall(function()
        local page = win.pages[st.tab]
        if page.navClose then page.navClose() end
        if not st.hist and page.hview then page.hview:Close() end
        SelectTab(st.tab)
        if page.navApply then page.navApply(st.view) end
        if st.hist then ns.OpenHistoryView(page, st.hist, true) end
    end)
    applying = false
    -- a view that is gone (a removed guild) leaves the page as it is
    local tab, view, hist = ShownState()
    if tab ~= st.tab or view ~= st.view or HistKey(hist) ~= HistKey(st.hist) then
        nav[navPos] = { tab = tab, view = view, hist = hist }
    end
    UpdateNav()
    if not ok then geterrorhandler()(err) end
end

-- Back closes an overlay first (Guild Search results), then steps back.
function ns.NavBack()
    local page = win.pages[ns.DB().tab or 1]
    if page.navClose and page.navClose() then UpdateNav() return end
    if navPos > 1 then Go(navPos - 1) end
end

function ns.NavForward()
    if navPos < #nav then Go(navPos + 1) end
end

-- Escape: up one level; false at the top (the window closes).
function ns.NavUp()
    local page = win.pages[ns.DB().tab or 1]
    if page.hview and page.hview:IsOpen() then
        page.hview:Close()
        ns.NavRecord()
        return true
    end
    if page.navUp and page.navUp() then
        ns.NavRecord()
        return true
    end
    return false
end

local function OnEscape(self)
    if not ns.NavUp() then self:Hide() end
end

-- mouse buttons 4 / 5 over the window; listened to only while it shows
local function OnMouseButton(self, _, button)
    if button ~= "Button4" and button ~= "Button5" then return end
    if not self:IsMouseOver() then return end
    if button == "Button4" then ns.NavBack() else ns.NavForward() end
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
    -- the shown tab is redrawn from the saved data each time the window opens
    win:SetScript("OnShow", function(self)
        ns.RefreshTabs()
        -- an unknown event (an older client) is not an error worth showing
        pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_UP")
    end)
    win:SetScript("OnHide", function(self) self:UnregisterEvent("GLOBAL_MOUSE_UP") end)
    win:SetScript("OnEvent", OnMouseButton)
    if EUI.RegisterEscapeClose then
        -- EllesmereUI's Escape handling, with our step back in place of Hide
        EUI.RegisterEscapeClose(win, { onEscape = OnEscape })
    else
        -- the same through UISpecialFrames: a helper shown with the window
        -- whose hiding by Escape steps back (shown again) or closes
        local esc = CreateFrame("Frame", "PSS_EllesmereUIEscape", UIParent)
        esc:Hide()
        tinsert(UISpecialFrames, "PSS_EllesmereUIEscape")
        win:HookScript("OnShow", function() esc:Show() end)
        win:HookScript("OnHide", function() esc:Hide() end)
        esc:SetScript("OnHide", function(self)
            if not win:IsShown() then return end
            OnEscape(win)
            if win:IsShown() then self:Show() end
        end)
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
        tab:SetScript("OnClick", function()
            SelectTab(i)
            ns.NavRecord()
        end)
        ns.Tab(tab)
        win.tabs[i] = tab
        prev = tab

        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -32 - TAB_H - NAV_H - 8)
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

    -- [<] [>]  Guild Ignore List  >  Members of <guild>
    local navY = -32 - TAB_H - 4
    win.back = ns.NewButton(win, "<", 26, ns.NavBack)
    win.back:SetHeight(NAV_H)
    win.back:SetPoint("TOPLEFT", win, "TOPLEFT", 10, navY)
    ns.TipOn(win.back, win.back, "Back (mouse button 4). Escape goes up one level.")
    win.forward = ns.NewButton(win, ">", 26, ns.NavForward)
    win.forward:SetHeight(NAV_H)
    win.forward:SetPoint("LEFT", win.back, "RIGHT", 4, 0)
    ns.TipOn(win.forward, win.forward, "Forward (mouse button 5).")
    win.where = ns.NewText(win, 11)
    win.where:SetPoint("LEFT", win.forward, "RIGHT", 10, 0)
    win.where:SetTextColor(1, 1, 1, 0.7)

    SelectTab(ns.DB().tab or 1)
    ns.NavRecord()

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
