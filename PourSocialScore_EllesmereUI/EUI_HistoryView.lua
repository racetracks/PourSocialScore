-------------------------------------------------------------------------------
--  EUI_HistoryView.lua -- the Block History view: a tab's block history in
--  place of the tab (the PSS window's Block History panel in EllesmereUI's
--  style). Opened by a double-click on a line of a pane's history.
--  Time | Player | Type | Channel | Message, sorted by a header click; the
--  type tick boxes (shared with the panes) and a search box over player,
--  channel and message above it. Links in a message work as in chat; a
--  double-click on a line opens the message in a copy box.
--
--  spec = { kind, id, label(id) -> name (nil: gone), read(id) -> lines,
--           reset(id), all = function() -> the spec of everything (or nil),
--           allText = "All Guilds",
--           period = "session" | "day" | nil (all time): what the time
--           picker starts on (a Summary slice opens with its period),
--           pick = function() -> { { key, name }, ... } and pickSpec(key):
--           a drop-down to jump to another entry (the guilds) }
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI
local L = PourSocialScore_NS.L
local History = M.PSS_History

local TIME_FMT = "%Y/%m/%d %H:%M:%S"
local DOUBLE_CLICK = 0.35
local hidden = ns.histHidden
local views = {}

local SORT = {
    time    = function(h) return tonumber(h.ts) or 0 end,
    member  = function(h) return string.lower(h.member or "") end,
    kind    = function(h) return ns.HistoryType(h) end,
    channel = function(h) return string.lower(h.channel or "") end,
    message = function(h) return string.lower(h.message or "") end,
}

local function TimeText(h)
    local ts = tonumber(h.ts)
    return ts and ts > 0 and date(TIME_FMT, ts) or History.UNKNOWN
end

-- since: only the events from then on (a Summary slice)
local function Matches(h, find, since)
    if hidden[ns.HistoryType(h)] then return false end
    if since and (tonumber(h.ts) or 0) < since then return false end
    if find == "" then return true end
    return string.find(string.lower(h.member or ""), find, 1, true)
        or string.find(string.lower(h.channel or ""), find, 1, true)
        or string.find(string.lower(h.message or ""), find, 1, true)
end

local View = {}
View.__index = View

-- Filter and sort what was read into self.shown.
function View:Apply(top)
    local find = string.lower(M.trim(self.search:GetText() or "") or "")
    local period = self.period
    local since = period and ns.SummarySince(period)
    local out, n = self.shown, 0
    for i = 1, #self.all do
        local h = self.all[i]
        if Matches(h, find, since) then
            n = n + 1
            out[n] = h
        end
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    if self.sortKey ~= "time" or self.sortAsc then
        local fn, asc, vals = SORT[self.sortKey] or SORT.time, self.sortAsc, self.vals
        wipe(vals)
        for i = 1, n do vals[out[i]] = fn(out[i]) end
        -- read order (newest first) breaks ties
        local order = self.order
        wipe(order)
        for i = 1, n do order[out[i]] = i end
        table.sort(out, function(a, b)
            local A, B = vals[a], vals[b]
            if A ~= B then if asc then return A < B end return A > B end
            return order[a] < order[b]
        end)
    end
    self.list:SetSort(self.sortKey, self.sortAsc)
    self.list:SetCount(n)
    if top then self.list:Top() end
    local name = self.name or "?"
    if since then name = name .. ", " .. string.lower(ns.PeriodText(period)) end
    for key, b in pairs(self.periodButtons) do ns.SetTabSelected(b, key == (period or "all")) end
    self.heading:SetText(("Block History: %s  |cffaaaaaa(%s)|r"):format(name,
        n == #self.all and tostring(n) or (n .. " of " .. #self.all)))
    self.list:SetEmptyText(#self.all == 0 and "Nothing blocked here yet." or "No line matches the search and the ticked types.")
end

-- Read the lines again (the spec's owner gone: everything instead).
function View:Refresh(top)
    local spec = self.spec
    if not spec then return end
    local name = spec.label(spec.id)
    if not name and spec.all then
        local all = spec.all()
        if all and all ~= spec then self.spec = all; return self:Refresh(true) end
    end
    self.name = name or "?"
    self.all = spec.read(spec.id) or {}
    self.allButton:SetShown(spec.id and spec.all ~= nil or false)
    if spec.allText then self.allButton:SetText(spec.allText) end
    self.pick:SetShown(spec.pick ~= nil)
    self:Apply(top)
end

function View:Open(spec)
    self.spec = spec
    self.period = spec.period
    self.sortKey, self.sortAsc = "time", false
    self.search:SetText("")
    self.page:Hide()
    self.frame:Show()
    self:Refresh(true)
end

function View:Close()
    if not self.spec then return end
    self.spec = nil
    self.all = {}
    wipe(self.shown)
    self.frame:Hide()
    self.page:Show()
    if self.page.refresh then self.page.refresh() end
end

function View:IsOpen() return self.spec ~= nil end

local function Draw(view, row, i)
    local h = view.shown[i]
    local c = row.cells
    if not h then
        for _, fs in pairs(c) do fs:SetText("") end
        return
    end
    c.time:SetText(TimeText(h))
    c.member:SetText(M.removeServer and M.removeServer(h.member or "", true) or (h.member or ""))
    c.kind:SetText("|c" .. (History.CAT_COLOR[h.cat or "unknown"] or "ffffffff") .. ns.HistoryType(h) .. "|r")
    c.channel:SetText(h.channel or "")
    local msg = h.message or ""
    c.message:SetText(msg ~= "" and msg or "|cff888888(no message text)|r")
end

local function Tip(view, row, i)
    local h = view.shown[i]
    if not h then return end
    local src = History.sourceLabel and History.sourceLabel[h]
    ns.Tip(row, TimeText(h) .. "  " .. (h.channel or "") .. "\n" .. (h.member or "")
        .. (src and ("\n|cffaaaaaa" .. src .. "|r") or "") .. "\n\n" .. (h.message or "")
        .. "\n\n|cffaaaaaaClick a link to open it, shift-click to paste it. Double-click: copy the message.|r")
end

-- double-click a line: the message in EllesmereUI's copy box
local function Click(view, row, i, button)
    if button ~= "LeftButton" then return end
    local now = GetTime()
    if view.lastClick == i and now - (view.lastClickAt or 0) <= DOUBLE_CLICK then
        view.lastClick = nil
        local h = view.shown[i]
        if h and EUI.ShowCopyPopup then
            EUI:ShowCopyPopup("Block History", (h.member or "") .. "  " .. TimeText(h), h.message or "")
        end
    else
        view.lastClick, view.lastClickAt = i, now
    end
end

local function SetSort(view, key)
    if view.sortKey == key then
        view.sortAsc = not view.sortAsc
    else
        view.sortKey, view.sortAsc = key, key ~= "time"     -- time starts newest first
    end
    view:Apply(true)
end

local function Build(page)
    local win = page:GetParent()
    local view = setmetatable({ page = page, all = {}, shown = {}, vals = {}, order = {},
        sortKey = "time", sortAsc = false }, View)
    local f = CreateFrame("Frame", nil, win)
    f:SetAllPoints(page)
    f:Hide()
    ns.Panel(f)
    view.frame = f

    -- Block History: name (n)                  [All Guilds] [Reset] [Close]
    view.heading = ns.NewHeading(f, "")
    view.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    local close = ns.NewButton(f, "Close", 80, function()
        view:Close()
        ns.NavRecord()
    end)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -6)
    ns.TipOn(close, close, "Back to the tab (Escape too).")
    local reset = ns.NewButton(f, L["HISTORY_RESET"] or "Reset Block History", 130, function()
        local spec = view.spec
        if not spec then return end
        if spec.id then
            spec.reset(spec.id)
            view:Refresh(true)
            return
        end
        EUI:ShowConfirmPopup({
            title       = "Pour Social Score",
            message     = ("Clear the block history and counts of %s?"):format(string.lower(view.name or "everything")),
            confirmText = "Reset",
            cancelText  = "Cancel",
            onConfirm   = function()
                spec.reset(spec.id)
                view:Refresh(true)
            end,
        })
    end)
    reset:SetPoint("RIGHT", close, "LEFT", -6, 0)
    view.resetButton = reset
    view.allButton = ns.NewButton(f, "All", 100, function()
        local spec = view.spec
        local all = spec and spec.all and spec.all()
        if not all then return end
        view.spec = all
        view:Refresh(true)
        ns.NavRecord()
    end)
    view.allButton:SetPoint("RIGHT", reset, "LEFT", -6, 0)

    -- [x] whisper ... [x] guild          [search player, channel or message]
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    bar:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    bar:SetHeight(20)
    view.boxes = ns.TypeBoxes(bar)
    local search = CreateFrame("EditBox", nil, bar, "InputBoxTemplate")
    search:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    search:SetSize(260, 20)
    search:SetAutoFocus(false)
    ns.EditBox(search)
    local hint = ns.NewText(search, 12)
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetTextColor(1, 1, 1, 0.4)
    hint:SetText("Search player, channel or message")
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        if text ~= view.lastFind then
            view.lastFind = text
            if view.spec then view:Apply(true) end
        end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    view.search = search

    local lf = CreateFrame("Frame", nil, f)
    -- [This session] [Last 24 hours] [All time]               [Guilds v]
    local bar2 = CreateFrame("Frame", nil, f)
    bar2:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    bar2:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    bar2:SetHeight(22)
    view.periodButtons = {}
    local prevB
    for _, per in ipairs(ns.SUMMARY_PERIODS) do
        local b = CreateFrame("Button", nil, bar2)
        b:SetNormalFontObject(GameFontHighlightSmall)
        b:SetText(per.text)
        b:SetSize(110, 22)
        if prevB then b:SetPoint("LEFT", prevB, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", bar2, "TOPLEFT", 0, 0) end
        b:SetScript("OnClick", function()
            if not view.spec then return end
            view.period = per.key ~= "all" and per.key or nil
            view:Apply(true)
        end)
        ns.Tab(b)
        ns.TipOn(b, b, per.key == "all" and "Every logged event." or ("Only the events of " .. string.lower(per.text) .. "."))
        view.periodButtons[per.key] = b
        prevB = b
    end
    view.pick = ns.NewDropdown(bar2, 200, function()
        local spec = view.spec
        local out = {}
        for i, c in ipairs(spec and spec.pick and spec.pick() or {}) do out[i] = { c.key, c.name } end
        return out
    end, function(key)
        local spec = view.spec
        if not (spec and spec.pickSpec) then return end
        view.spec = spec.pickSpec(key)
        view:Refresh(true)
        ns.NavRecord()
    end)
    view.pick:SetPoint("RIGHT", bar2, "RIGHT", 0, 0)
    if view.pick.SetDefaultText then view.pick:SetDefaultText("Guilds") end
    view.pick:Hide()

    lf:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -88)
    lf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    view.list = ns.NewRows(lf, {
        rowH = 18, fontSize = 12, links = true,
        cols = {
            { key = "time", text = "Time", width = 136 },
            { key = "member", text = "Player", width = 150 },
            { key = "kind", text = "Type", width = 64 },
            { key = "channel", text = "Channel", width = 130 },
            { key = "message", text = "Message" },
        },
        sort = function(key) SetSort(view, key) end,
        draw = function(row, i) Draw(view, row, i) end,
        enter = function(row, i) Tip(view, row, i) end,
        click = function(row, i, button) Click(view, row, i, button) end,
    })
    views[#views + 1] = view
    page.hview = view
    return view
end

-- Open spec's Block History in place of page's tab.
function ns.OpenHistoryView(page, spec, quiet)
    local view = page.hview or Build(page)
    view:Open(spec)
    if not quiet then ns.NavRecord() end
    return view
end

-- the type boxes changed: redraw every open view
ns.HistoryWatch(function()
    for _, v in ipairs(views) do
        for t, c in pairs(v.boxes) do c:SetChecked(not hidden[t]) end
        if v.spec then v:Apply(false) end
    end
end)

-- new blocks: read an open view again, at most 4 times a second
local pending
local function Changed()
    if pending then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = nil
        for _, v in ipairs(views) do
            if v.spec and v.frame:IsVisible() then v:Refresh(false) end
        end
    end)
end
M.Events.Register("PLAYER_BLOCKED", Changed)
M.Events.Register("GUILD_BLOCKS_CHANGED", Changed)
M.Events.Register("PLAYERS_CHANGED", Changed)
M.Events.Register("GUILDS_CHANGED", Changed)
