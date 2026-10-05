-------------------------------------------------------------------------------
--  EUI_Filters.lua -- the Chat Filters tab of the window: the filters
--  (built-ins first, search, sortable columns) and, for the selected one,
--  an editor pane (On, description, filter text, Save / Copy / Remove /
--  Reset Count, Test, link converter) with its block history under it.
--  Built-ins are read only (On only); a guild rule's blocks are counted on
--  the Guild Ignore List, so it has no count or history here.
--  Everything is read and changed through the core (PSS_FilterQuery.lua
--  and the filter setters); the core says when filters changed
--  (FILTERS_CHANGED, FILTER_HISTORY_CHANGED) and the tab redraws if it shows.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI
local L = PourSocialScore_NS.L
local History = M.PSS_History

local DETAIL_W = 380
local TOP_H = 32
local LINE_H = 16

-- key/asc/find: the sort and search; index: filter numbers in the order
-- shown; sel: the selected filter number; row: the table every drawn row is
-- read into (M.PSS_FilterRow)
local F = { key = "desc", asc = true, find = "", index = {}, count = 0, dirty = true, row = {}, prow = {} }
local page, list, pane

local function Say(msg) M.PSS_Say(msg) end

-------------------------------------------------------------------------------
--  List
-------------------------------------------------------------------------------
local function Resort()
    local _, n = M.PSS_FilterRows(F.key, F.asc, F.find, F.index)
    F.count, F.dirty = n, false
    list:SetSort(F.key, F.asc)
    list:SetCount(n)
    local total, builtin, custom, on = M.PSS_FilterCount()
    page.count:SetText((F.find ~= "" and ("%d of %d   "):format(n, total) or "")
        .. ("|cffaaaaaaBuilt-in|r %d   |cffaaaaaaCustom|r %d   |cffaaaaaaOn|r |cff33ff99%d|r"):format(builtin, custom, on))
    list:SetEmptyText(total == 0 and "No chat filters." or "Nothing matches the search.")
end

local function DrawRow(row, i)
    local r = M.PSS_FilterRow(F.index[i], F.row)
    local c = row.cells
    if not r then
        for _, fs in pairs(c) do fs:SetText("") end
        row.sel:Hide()
        return
    end
    if r.builtin then
        c.desc:SetText("|cff8a8a8a" .. r.desc .. " |cff5f5f5f" .. (r.guildRule and "(guild rule)" or "(built-in)") .. "|r")
        c.filter:SetText("|cff7a7a7a" .. r.filter .. "|r")
    else
        c.desc:SetText(r.desc)
        c.filter:SetText(r.filter)
    end
    c.state:SetText(r.active and ("|cff33ff99" .. L["ON"] .. "|r") or ("|cffe60000" .. L["OFF"] .. "|r"))
    c.blocked:SetText(M.PSS_FilterBlockedText(r.index))
    row.sel:SetShown(r.index == F.sel)
end

local function RowTip(row, i)
    local r = M.PSS_FilterRow(F.index[i], F.row)
    if not r then return end
    ns.Tip(row, r.desc .. "\n\n" .. r.filter .. "\n\n|cffaaaaaaClick to edit. Built-ins are read only.|r")
end

local function SetSort(key)
    if F.key == key then
        F.asc = not F.asc
    else
        F.key, F.asc = key, true
    end
    Resort()
end

-------------------------------------------------------------------------------
--  Block History view (EUI_HistoryView.lua) of a filter, or of every filter
-------------------------------------------------------------------------------
local allFilters = {
    kind = "filter", id = false, allText = "All Filters", source = "filters",
    label = function() return "All Filters" end,
    read = M.PSS_AllFilterHistory,
    reset = M.PSS_ResetAllFilterHistory,
}
local function AllFilters() return allFilters end
ns.RegisterEventSource("filters", "Chat Filters", AllFilters)

function ns.FilterHistorySpec(i)
    return {
        kind = "filter", id = i, allText = "All Filters", all = AllFilters,
        label = function(n)
            local r = M.PSS_FilterRow(n, F.prow)
            return r and not r.guildRule and r.desc or nil
        end,
        read = M.PSS_FilterHistory,
        reset = M.PSS_ResetFilterHistory,
        owner = M.PSS_FilterOwnerKey, counts = M.PSS_FilterCounts,
    }
end

-------------------------------------------------------------------------------
--  Editor pane
-------------------------------------------------------------------------------
local function Line(parent, y)
    local fs = ns.NewText(parent, 12)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    return fs
end

local function Label(parent, text, x, y)
    local fs = ns.NewText(parent, 12)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 0.7)
    return fs
end

local function SetEditable(e, on)
    e:SetEnabled(on)
    e:SetTextColor(1, 1, 1, on and 1 or 0.5)
end

local function ConfirmRemove()
    local i = F.sel
    local r = i and M.PSS_FilterRow(i, F.prow)
    if not r or r.builtin then return end
    EUI:ShowConfirmPopup({
        title       = "Pour Social Score",
        message     = ("Remove the chat filter \"%s\"?\n\nIts count and block history are deleted."):format(r.desc),
        confirmText = "Remove",
        cancelText  = "Cancel",
        onConfirm   = function()
            if M.PSS_FilterRow(i, F.prow) and F.prow.desc == r.desc then
                F.sel = nil
                M.RemoveChatFilter(i)
            end
        end,
    })
end

local function Copy()
    local i = F.sel
    if not i or M.PSS_IsGuildRuleFilter(i) then return end
    local src = M.PSS_FilterRow(i, F.prow) and F.prow.desc
    local n = M.PSS_CopyChatFilter(i)
    if not n then return end
    F.sel = n
    Say(("Copied \"%s\" to a new custom filter (starts Off). Edit it, tick On and save."):format(tostring(src)))
end

local function Save()
    local i = F.sel
    local r = i and M.PSS_FilterRow(i, F.prow)
    if not r or r.builtin then return end
    local desc = M.trim(pane.descBox:GetText() or "") or ""
    local text = pane.filterBox:GetText() or ""
    if desc == "" or text == "" then
        Say("A chat filter needs a description and a filter.")
        return
    end
    pane.descBox:ClearFocus()
    pane.filterBox:ClearFocus()
    M.PSS_SaveChatFilter(i, desc, text)
    Say(("Chat filter \"%s\" saved."):format(desc))
end

local function BuildPane(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -TOP_H - 4)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
    pane:SetWidth(DETAIL_W)
    ns.Panel(pane)

    pane.none = ns.NewText(pane, 12)
    pane.none:SetPoint("CENTER")
    pane.none:SetTextColor(1, 1, 1, 0.5)
    pane.none:SetText("Select a filter to edit it.")
    pane.none:Hide()
    -- nothing selected: every filter's totals (a click on the selected
    -- filter deselects it)
    pane.totals = ns.NewTotals(pane, page, "filters", "Chat Filters", "Select a filter to edit it.", AllFilters)

    local b = CreateFrame("Frame", nil, pane)
    b:SetAllPoints()
    pane.body = b

    pane.heading = ns.NewHeading(b, "")
    pane.heading:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
    pane.heading:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    pane.info = Line(b, -26)
    ns.Font(pane.info, 11)

    -- the pages: Summary (counts), Event History, View/Edit Rule (the editor)
    local dp = ns.NewDetailPages(b, -44, "filters")
    pane.pages = dp
    local rule = dp.rule

    -- [x] On   Description [..............]
    local y = -2
    local on = ns.NewCheck(rule)
    on:SetPoint("TOPLEFT", rule, "TOPLEFT", 8, y + 2)
    local onText = ns.NewText(rule, 12)
    onText:SetPoint("LEFT", on, "RIGHT", 0, 0)
    onText:SetText("On")
    ns.TipOn(on, on, "Turns this filter on or off at once.")
    on:SetScript("OnClick", function(self)
        if F.sel then M.PSS_SetFilterActive(F.sel, self:GetChecked() and true or false) end
    end)
    pane.onBox = on
    Label(rule, "Description", 74, y - 3)
    local desc = CreateFrame("EditBox", nil, rule, "InputBoxTemplate")
    desc:SetPoint("TOPLEFT", rule, "TOPLEFT", 156, y)
    desc:SetPoint("RIGHT", rule, "RIGHT", -12, 0)
    desc:SetHeight(20)
    desc:SetAutoFocus(false)
    desc:SetMaxLetters(100)
    ns.EditBox(desc)
    desc:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    desc:SetScript("OnEscapePressed", function(self) self:ClearFocus(); ns.ShowFilterDetail() end)
    pane.descBox = desc
    y = y - 28

    -- Filter (?) and its text, several lines
    local fl = Label(rule, "Filter", 12, y)
    local help = ns.NewButton(rule, "?", 22, function() end)
    help:SetHeight(18)
    help:SetPoint("LEFT", fl, "RIGHT", 6, 0)
    ns.TipOn(help, help, L["TIP_1"])
    pane.lock = ns.NewText(rule, 11)
    pane.lock:SetPoint("LEFT", help, "RIGHT", 8, 0)
    pane.lock:SetTextColor(1, 1, 1, 0.5)
    pane.lock:SetText("Built-in: read only. Copy it to edit.")
    y = y - 18
    local ff = CreateFrame("Frame", nil, rule)
    ff:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
    ff:SetPoint("RIGHT", rule, "RIGHT", -10, 0)
    ff:SetHeight(58)
    ns.Panel(ff)
    -- a long filter scrolls inside the panel instead of spilling over the
    -- buttons below; the box grows with its text and the view follows the cursor
    local fscroll = CreateFrame("ScrollFrame", nil, ff, "ScrollFrameTemplate")
    fscroll:SetPoint("TOPLEFT", ff, "TOPLEFT", 4, -4)
    fscroll:SetPoint("BOTTOMRIGHT", ff, "BOTTOMRIGHT", -22, 4)
    ns.ScrollBar(fscroll.ScrollBar)
    local fbox = CreateFrame("EditBox", nil, fscroll)
    fbox:SetPoint("TOPLEFT", fscroll, "TOPLEFT", 0, 0)
    fbox:SetWidth(300)
    fscroll:SetScrollChild(fbox)
    fscroll:SetScript("OnSizeChanged", function(_, w) if w and w > 0 then fbox:SetWidth(w) end end)
    fbox:SetScript("OnCursorChanged", function(_, _, y, _, h)
        if fscroll.UpdateScrollChildRect then fscroll:UpdateScrollChildRect() end
        local top, view = fscroll:GetVerticalScroll(), fscroll:GetHeight()
        y = -(y or 0)
        h = h or 0
        if y < top then
            fscroll:SetVerticalScroll(y)
        elseif view > 0 and y + h > top + view then
            fscroll:SetVerticalScroll(math.min(y + h - view, fscroll:GetVerticalScrollRange()))
        end
    end)
    fbox:SetMultiLine(true)
    fbox:SetAutoFocus(false)
    fbox:SetMaxLetters(1000)
    fbox:SetFontObject(ChatFontNormal)
    ns.Font(fbox, 11)
    fbox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); ns.ShowFilterDetail() end)
    ff:EnableMouse(true)
    ff:SetScript("OnMouseDown", function() if fbox:IsEnabled() then fbox:SetFocus() end end)
    pane.filterBox, pane.filterScroll = fbox, fscroll
    y = y - 62

    -- [Save Filter] [Copy] [Remove] [Reset Count]
    local save = ns.NewButton(rule, "Save Filter", 92, Save)
    save:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
    ns.TipOn(save, save, "Saves the description and filter text.")
    pane.saveButton = save
    local copy = ns.NewButton(rule, "Copy", 70, Copy)
    copy:SetPoint("LEFT", save, "RIGHT", 6, 0)
    ns.TipOn(copy, copy, "Makes an editable custom copy (starts Off).")
    pane.copyButton = copy
    local remove = ns.NewButton(rule, "Remove", 76, ConfirmRemove)
    remove:SetPoint("LEFT", copy, "RIGHT", 6, 0)
    pane.removeButton = remove
    local resetCount = ns.NewButton(rule, "Reset Count", 100, function()
        if F.sel then M.PSS_ResetFilterCount(F.sel) end
    end)
    resetCount:SetPoint("LEFT", remove, "RIGHT", 6, 0)
    ns.TipOn(resetCount, resetCount, "The Blocked count starts again from 0 (the block history stays).")
    pane.resetCount = resetCount
    y = y - 28

    -- Test [chat line ............] [Test] BLOCKED / PASSED
    Label(rule, "Test", 12, y - 3)
    local test = CreateFrame("EditBox", nil, rule, "InputBoxTemplate")
    test:SetPoint("TOPLEFT", rule, "TOPLEFT", 56, y)
    test:SetSize(170, 20)
    test:SetAutoFocus(false)
    ns.EditBox(test)
    local result = ns.NewText(rule, 12)
    local function RunTest()
        local res = M.PSS_TestChatFilter(fbox:GetText() or "", test:GetText() or "")
        result:SetText(res == "error" and "|cffffff00FILTER ERROR|r" or (res == "blocked" and "|cffff5c5cBLOCKED|r" or "|cff00ff96PASSED|r"))
    end
    test:SetScript("OnTextChanged", function() result:SetText("") end)
    test:SetScript("OnEnterPressed", RunTest)
    test:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ns.TipOn(test, test, L["TIP_2"])
    local testButton = ns.NewButton(rule, "Test", 50, RunTest)
    testButton:SetPoint("LEFT", test, "RIGHT", 6, 0)
    result:SetPoint("LEFT", testButton, "RIGHT", 8, 0)
    pane.testBox, pane.testButton, pane.result = test, testButton, result
    y = y - 26

    -- Link [shift-click a link] -> its [tag], selected to copy
    Label(rule, "Link", 12, y - 3)
    local link = CreateFrame("EditBox", nil, rule, "InputBoxTemplate")
    link:SetPoint("TOPLEFT", rule, "TOPLEFT", 56, y)
    link:SetPoint("RIGHT", rule, "RIGHT", -12, 0)
    link:SetHeight(20)
    link:SetAutoFocus(false)
    ns.EditBox(link)
    local function Convert(self)
        self:SetText(M.PSS_ConvertChatLink(self:GetText()))
        self:HighlightText()
    end
    link:SetScript("OnEnterPressed", Convert)
    link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ns.TipOn(link, link, "Click here, then shift-click a link in chat (or paste one and press Enter): it turns into the filter [tag], selected to copy. Shift-clicking a link while the filter box is being edited puts the [tag] there directly.")
    pane.linkBox = link

    pane.counts = Line(dp.summary, -6)
    ns.Font(pane.counts, 11)
    pane.summary = ns.NewSummary(dp.summary, page, -30)
    pane.summaryOpts = {}

    -- Event History: the filter's block history, the whole page
    pane.hist = ns.NewHistory(dp.history, -2, {
        names = true, empty = "Nothing blocked by this filter yet.",
        open = function(i) ns.OpenHistoryView(page, ns.FilterHistorySpec(i)) end,
    })
    -- no buttons under it: the list goes to the bottom of the page
    pane.hist.frame:SetPoint("BOTTOMRIGHT", dp.history, "BOTTOMRIGHT", -4, 6)
end

-- A link shift-clicked while one of our boxes is being edited goes there:
-- the filter box gets its [tag], the Test box the link, the Link box the
-- converted tag.
local hooked
local function HookLinks()
    if hooked or not ChatEdit_InsertLink then return end
    hooked = true
    hooksecurefunc("ChatEdit_InsertLink", function(text)
        if not (text and pane and pane:IsVisible()) then return end
        if pane.filterBox:HasFocus() then
            pane.filterBox:Insert(M.PSS_ConvertChatLink(text))
        elseif pane.testBox:HasFocus() then
            pane.testBox:Insert(text)
        elseif pane.linkBox:HasFocus() then
            pane.linkBox:SetText(M.PSS_ConvertChatLink(text))
            pane.linkBox:HighlightText()
        end
    end)
end

-- Redraw the pane for the selected filter (none: a hint). fresh: another
-- filter was selected (its texts are loaded again, the test cleared).
function ns.ShowFilterDetail(fresh)
    if not pane then return end
    local r = F.sel and M.PSS_FilterRow(F.sel, F.prow)
    pane.body:SetShown(r and true or false)
    if r then pane.totals:Hide() else pane.totals:Show() end
    if not r then
        F.sel = nil
        pane.hist:Clear()
        return
    end
    pane.heading:SetText(r.desc .. (r.guildRule and "  |cff808080(guild rule)|r" or (r.builtin and "  |cff808080(built-in)|r" or "")))
    if r.guildRule then
        pane.info:SetText("|cffaaaaaaTurns its guilds on the Guild Ignore List on or off; their blocks are counted there.|r")
    else
        pane.info:SetText(("Blocked |cffffff00%d|r messages"):format(r.blocked or 0))
    end
    pane.onBox:SetChecked(r.active)
    if fresh or not pane.descBox:HasFocus() then pane.descBox:SetText(r.desc) end
    if fresh or not pane.filterBox:HasFocus() then
        pane.filterBox:SetText(r.filter)
        if fresh then pane.filterScroll:SetVerticalScroll(0) end
    end
    if fresh then
        pane.testBox:SetText("")
        pane.result:SetText("")
    end
    SetEditable(pane.descBox, not r.builtin)
    SetEditable(pane.filterBox, not r.builtin)
    pane.lock:SetShown(r.builtin)
    pane.saveButton:SetEnabled(not r.builtin)
    pane.removeButton:SetEnabled(not r.builtin)
    pane.copyButton:SetEnabled(not r.guildRule)
    pane.resetCount:SetEnabled(not r.guildRule)
    -- a guild rule's blocks are counted on its guilds: only its settings here
    pane.pages:Limit(r.guildRule and { rule = true } or nil)
    if r.guildRule then
        pane.hist:Clear()
        return
    end
    local c = M.PSS_FilterCounts(r.index)
    pane.counts:SetText(("History %d lines:  Whispers %d  Party %d  Chat %d"):format(r.lines,
        c and c.whisper or 0, c and c.partyRaid or 0, (c and c.world or 0) + (c and c.guildChat or 0)))
    -- read again only when the filter or its count changed; the block
    -- history (PourSocialScore_Logging) loads only when asked for
    pane.hist:Set(r.index, r.lines, M.PSS_FilterHistory, fresh)
    pane.summaryOpts.counts = c
    pane.summary:Set(M.PSS_FilterOwnerKey(r.index), r.blocked or 0, r.desc, ns.FilterHistorySpec, r.index,
        pane.summaryOpts)
end

-------------------------------------------------------------------------------
--  Tab
-------------------------------------------------------------------------------
local function Refresh()
    if F.dirty then Resort() else list:Redraw() end
    ns.ShowFilterDetail()
end

local function Select(i)
    if pane then
        pane.descBox:ClearFocus()
        pane.filterBox:ClearFocus()
    end
    F.sel = i
    list:Redraw()
    ns.ShowFilterDetail(true)
end

function ns.BuildFiltersTab(pg)
    page = pg
    HookLinks()

    -- top: search and counts on the left, New Filter and Reset Defaults on
    -- the right
    local search = CreateFrame("EditBox", nil, pg, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", pg, "TOPLEFT", 16, -6)
    search:SetSize(200, 20)
    search:SetAutoFocus(false)
    ns.EditBox(search)
    local hint = ns.NewText(search, 12)
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetTextColor(1, 1, 1, 0.4)
    hint:SetText("Search description or filter")
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        if text ~= F.find then
            F.find = text
            Resort()
            list:Top()
        end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    pg.search = search

    pg.count = ns.NewText(pg, 12)
    pg.count:SetPoint("LEFT", search, "RIGHT", 12, 0)
    pg.count:SetTextColor(1, 1, 1, 0.8)

    local new = ns.NewButton(pg, "New Filter", 100, function()
        local i = M.PSS_AddCustomFilter("New Chat Filter", "[word=newchatfilter]", false)
        if i then
            Select(i)
            if pane then pane.descBox:SetFocus(); pane.descBox:HighlightText() end
        end
    end)
    new:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -8, -5)
    ns.TipOn(new, new, "A new custom filter (starts Off): give it a description and filter, Save, then tick On.")
    pg.newButton = new
    local reset = ns.NewButton(pg, L["BUT_7"] or "Reset Defaults", 120, function()
        EUI:ShowConfirmPopup({
            title       = "Pour Social Score",
            message     = L["BOX_2"],
            confirmText = "Reset",
            cancelText  = "Cancel",
            onConfirm   = function()
                F.sel = nil
                M.ResetSpamFilters()
            end,
        })
    end)
    reset:SetPoint("RIGHT", new, "LEFT", -8, 0)
    pg.resetButton = reset

    BuildPane(pg)

    local lf = CreateFrame("Frame", nil, pg)
    lf:SetPoint("TOPLEFT", pg, "TOPLEFT", 8, -TOP_H - 4)
    lf:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", -8, 0)
    list = ns.NewRows(lf, {
        rowH = 20, height = 300,
        cols = {
            { key = "desc", text = "Description", width = 190 },
            { key = "state", text = "On", width = 40 },
            { key = "blocked", text = "Blocked", width = 60, justify = "RIGHT",
              tip = "Lines this filter blocked (n/a: a guild rule, counted on the Guild Ignore List)." },
            { key = "filter", text = "Filter", tip = "Built-in filters always stay at the top." },
        },
        sort = SetSort,
        draw = DrawRow,
        enter = RowTip,
        click = function(row, i)
            local n = F.index[i]
            if n then Select(n ~= F.sel and n or nil) end
        end,
        emptyClick = function() if F.sel then Select(nil) end end,
    })
    -- a tab click (EUI_Window.lua): nothing selected
    pg.navReset = function() if F.sel then Select(nil) end end
    pg.list, pg.pane, pg.state = list, pane, F
    F.dirty = true
    return Refresh
end

-------------------------------------------------------------------------------
--  Core events: redraw now if the tab shows, else when it next shows.
-------------------------------------------------------------------------------
local queued
M.Events.Register("FILTERS_CHANGED", function()
    F.dirty = true
    if queued or not (page and page:IsVisible()) then return end
    -- one redraw however many changes arrive in a frame (an import adds
    -- many filters at once, and every blocked line fires it)
    queued = true
    C_Timer.After(0, function()
        queued = false
        if page and page:IsVisible() then Refresh() end
    end)
end)

-- a blocked line: the counts and the history, at most 4 times a second
local pending
M.Events.Register("FILTER_HISTORY_CHANGED", function()
    if pending or not (page and page:IsVisible()) then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = nil
        if page and page:IsVisible() then
            list:Redraw()
            ns.ShowFilterDetail()
        end
    end)
end)
