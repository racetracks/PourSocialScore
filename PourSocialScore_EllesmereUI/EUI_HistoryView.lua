-------------------------------------------------------------------------------
--  EUI_HistoryView.lua -- the Events tab: the blocked lines of the lists, in
--  place of the PSS window's Block History panel. Three drop-downs filter
--  them: Time (this session, the last 24 hours, all time or a custom range
--  of dates), Types, and Source (the Player and Guild Ignore Lists and the
--  Chat Filters, or one entry of them); a search box goes over player,
--  channel and message.
--  Time | Source | Player | Type | Channel | Message, sorted by a header
--  click. Links in a message work as in chat; a double-click on a line
--  opens the message in a copy box.
--  The pies of the other tabs open it (ns.OpenEvents) with their entry, a
--  period and the types ticked; so do View Events and a double-click on a
--  pane's Event History. Opening it loads PourSocialScore_Logging.
--
--  spec (an entry, from the tabs) = { kind, id, label(id) -> name (nil:
--           gone), read(id) -> lines, reset(id) (asked first when confirm
--           is set), owner(id) -> the core's owner key, counts(id) -> its
--           counts by type: blocks counted but no longer in the block
--           history show as "Data expired from logs" lines (with their
--           type, and their 10 minutes when in the last day) }
--  A whole list's spec has id false and source = its key (that list as
--  the source).
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI
local L = PourSocialScore_NS.L
local History = M.PSS_History

local TIME_FMT = "%Y/%m/%d %H:%M:%S"
local INPUT_FMT = "%Y-%m-%d %H:%M"
local DOUBLE_CLICK = 0.35
local DAY = 86400

-- the lists whose events show (EUI_Players.lua, EUI_Guilds.lua and
-- EUI_Filters.lua register theirs): { key, text, all() -> its spec }
local SOURCES = {}
function ns.RegisterEventSource(key, text, all)
    SOURCES[#SOURCES + 1] = { key = key, text = text, all = all }
end

local TIMES = {
    { key = "session", text = "This session" },
    { key = "day",     text = "Last 24 hours" },
    { key = "all",     text = "All time" },
    { key = "custom",  text = "Custom range" },
}

local view                  -- the one Events view (built with the tab)

local function SourceText(view, h)
    local src = History.sourceLabel and History.sourceLabel[h]
    return src or view.srcOf[h] or view.name or ""
end

local SORT = {
    time    = function(h) return tonumber(h.ts) or 0 end,
    source  = function(h) return string.lower(SourceText(view, h)) end,
    member  = function(h) return string.lower(h.member or "") end,
    kind    = function(h) return ns.HistoryType(h) end,
    channel = function(h) return string.lower(h.channel or "") end,
    message = function(h) return string.lower(h.message or "") end,
}

local function TimeText(h)
    local ts = tonumber(h.ts)
    return ts and ts > 0 and date(TIME_FMT, ts) or History.UNKNOWN
end

-- "2026-10-05 13:20" -> server seconds (nil: not a date)
local ParseTime = M.PSS_ParseEventTime

-- Blocks counted for one entry but no longer in its lines, added to its
-- lines (PSS_EventsQuery.lua)
local AddExpired = M.PSS_AddExpiredEvents
ns.HistoryAddExpired = AddExpired

local View = {}
View.__index = View

-- The query shown: q = { scope = an entry's spec (nil: the sources),
-- sources = { [key] = true }, period = "session" | "day" | "custom" | nil
-- (all time), from, to (custom), cats = { [cat] = true } (nil: every type) }
local function NewQuery()
    local q = { sources = {} }
    for _, src in ipairs(SOURCES) do q.sources[src.key] = true end
    return q
end

local function CopyQuery(q)
    local c = { scope = q.scope, period = q.period, from = q.from, to = q.to, sources = {} }
    for k, v in pairs(q.sources) do c.sources[k] = v end
    if q.cats then
        c.cats = {}
        for k, v in pairs(q.cats) do c.cats[k] = v end
    end
    return c
end

-- a string for the query (back / forward tell views apart by it); nil for
-- the tab as it opens
local function QueryKey(q)
    local parts = {}
    if q.scope then parts[#parts + 1] = tostring(q.scope.kind) .. "=" .. tostring(q.scope.id) end
    for _, src in ipairs(SOURCES) do if not q.sources[src.key] then parts[#parts + 1] = "-" .. src.key end end
    if q.period then parts[#parts + 1] = q.period .. (q.period == "custom" and (tostring(q.from) .. "-" .. tostring(q.to)) or "") end
    if q.cats then
        for _, cat in ipairs(History.ALL_CATS or {}) do if q.cats[cat] then parts[#parts + 1] = "+" .. cat end end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

-- the first and last second shown (nil: open ended), and whether a line
-- is in the query (PSS_EventsQuery.lua)
local Range, Matches = M.PSS_EventRange, M.PSS_EventMatches

-- the name of what is shown
local function Title(q, name)
    if q.scope then return name or "?" end
    local on, all = {}, true
    for _, src in ipairs(SOURCES) do
        if q.sources[src.key] then on[#on + 1] = src.text else all = false end
    end
    if all then return "All sources" end
    if #on == 0 then return "No source" end
    return table.concat(on, ", ")
end

local function TimeLabel(q)
    if q.period == "custom" then
        return ("%s to %s"):format(q.from and date(INPUT_FMT, q.from) or "...", q.to and date(INPUT_FMT, q.to) or "now")
    end
    return ns.PeriodText(q.period or "all")
end

local function TypesLabel(q)
    if not q.cats then return "All types" end
    local on = {}
    for _, cat in ipairs(History.ALL_CATS or {}) do
        if q.cats[cat] then on[#on + 1] = History.CAT_LABEL[cat] or cat end
    end
    if #on == 0 then return "No type" end
    if #on <= 2 then return table.concat(on, ", ") end
    return ("%d types"):format(#on)
end

local function SetDropText(d, text)
    d.shownText = text
    if d.OverrideText then d:OverrideText(text) elseif d.SetDefaultText then d:SetDefaultText(text) end
end

-- Filter and sort what was read into self.shown.
function View:Apply(top)
    local q = self.q
    local find = string.lower(M.trim(self.search:GetText() or "") or "")
    local since, upto = Range(q)
    local out, n = self.shown, 0
    for i = 1, #self.all do
        local h = self.all[i]
        if Matches(q, h, find, since, upto) then
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
    self.heading:SetText(("Events: %s  |cffaaaaaa(%s)|r"):format(Title(q, self.name),
        n == #self.all and tostring(n) or (n .. " of " .. #self.all)))
    SetDropText(self.timeDrop, TimeLabel(q))
    SetDropText(self.typeDrop, TypesLabel(q))
    SetDropText(self.sourceDrop, q.scope and ("Only " .. (self.name or "?")) or Title(q))
    self.custom:SetShown(q.period == "custom")
    self.listFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, q.period == "custom" and -88 or -62)
    self.resetButton:SetShown(q.scope ~= nil)
    self.list:SetEmptyText(#self.all == 0 and "Nothing blocked here yet."
        or "No line matches the time, the types and the search.")
end

-- Read the lines again (an entry gone: its list instead).
function View:Refresh(top)
    local q = self.q
    local all, srcOf = {}, self.srcOf
    wipe(srcOf)
    local scope = q.scope
    local name = scope and scope.label(scope.id)
    if scope and not name then
        -- the entry is gone: its whole list
        if scope.all then
            local list = scope.all()
            if list and list.source then
                for k in pairs(q.sources) do q.sources[k] = k == list.source end
            end
        end
        q.scope, scope = nil, nil
    end
    self.name = name
    if scope then
        local lines = scope.read(scope.id) or {}
        for i = 1, #lines do all[i] = lines[i] end
        if scope.owner and scope.counts then
            local counts = scope.counts(scope.id)
            if counts then
                AddExpired(all, counts, History.RecentSlots and History.RecentSlots(scope.owner(scope.id)),
                    scope.kind ~= "filter" and History.KEEP_TOTAL ~= nil and not History.LOG_ALL)
            end
        end
    else
        local order = self.order
        wipe(order)
        for _, src in ipairs(SOURCES) do
            if q.sources[src.key] then
                local spec = src.all()
                local lines = spec and spec.read(false) or {}
                for i = 1, #lines do
                    local h = lines[i]
                    all[#all + 1] = h
                    srcOf[h] = src.text
                    order[h] = #all
                end
            end
        end
        -- newest first across the lists
        table.sort(all, function(a, b)
            local x, y = tonumber(a.ts) or 0, tonumber(b.ts) or 0
            if x ~= y then return x > y end
            return order[a] < order[b]
        end)
    end
    self.all = all
    self:Apply(top)
end

-- q changed by a drop-down: show it, as a step of its own
function View:Changed()
    self:Refresh(true)
    ns.NavRecord()
end

function View:IsOpen() return self.frame:IsVisible() end

local function Draw(view, row, i)
    local h = view.shown[i]
    local c = row.cells
    if not h then
        for _, fs in pairs(c) do fs:SetText("") end
        return
    end
    c.time:SetText(TimeText(h))
    c.source:SetText(SourceText(view, h))
    c.member:SetText(M.removeServer and M.removeServer(h.member or "", true) or (h.member or ""))
    c.kind:SetText("|c" .. (History.CAT_COLOR[h.cat or "unknown"] or "ffffffff") .. ns.HistoryType(h) .. "|r")
    c.channel:SetText(h.channel or "")
    local msg = h.message or ""
    c.message:SetText(msg ~= "" and msg or "|cff888888(no message text)|r")
end

local function Tip(view, row, i)
    local h = view.shown[i]
    if not h then return end
    ns.Tip(row, TimeText(h) .. "  " .. (h.channel or "") .. "\n" .. (h.member or "")
        .. "\n|cffaaaaaa" .. SourceText(view, h) .. "|r\n\n" .. (h.message or "")
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
            EUI:ShowCopyPopup("Events", (h.member or "") .. "  " .. TimeText(h), h.message or "")
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

-- a drop-down whose menu is built each time it opens
local function NewMenu(parent, w, build)
    local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    d:SetWidth(w)
    d:SetupMenu(function(_, root) build(root) end)
    ns.Dropdown(d)
    return d
end

-- the tab page: built the first time the tab shows (EUI_Window.lua)
function ns.BuildEventsTab(page)
    view = setmetatable({ page = page, frame = page, q = NewQuery(), all = {}, shown = {}, vals = {},
        order = {}, srcOf = {}, saved = {}, nsaved = 0, sortKey = "time", sortAsc = false }, View)
    local f = page

    -- Events: name (n)                                  [Reset Block History]
    view.heading = ns.NewHeading(f, "")
    view.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    local reset = ns.NewButton(f, L["HISTORY_RESET"] or "Reset Block History", 140, function()
        local spec = view.q.scope
        if not spec then return end
        if not spec.confirm then
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
    reset:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -6)
    ns.TipOn(reset, reset, "Clears this entry's block history and counts.")
    view.resetButton = reset

    -- [Time v] [Types v] [Source v]          [search player, channel or message]
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -34)
    bar:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    bar:SetHeight(22)
    view.timeDrop = NewMenu(bar, 190, function(root)
        for _, t in ipairs(TIMES) do
            root:CreateRadio(t.text, function() return (view.q.period or "all") == t.key end, function()
                local q = view.q
                if t.key == "custom" then
                    q.period = "custom"
                    q.from = q.from or (History.Now() - DAY)
                    view.fromBox:SetText(date(INPUT_FMT, q.from))
                    view.toBox:SetText(q.to and date(INPUT_FMT, q.to) or "")
                else
                    q.period = t.key ~= "all" and t.key or nil
                end
                view:Changed()
            end)
        end
    end)
    view.timeDrop:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    view.typeDrop = NewMenu(bar, 150, function(root)
        root:CreateButton("All types", function()
            view.q.cats = nil
            view:Changed()
        end)
        for _, cat in ipairs(History.ALL_CATS or {}) do
            root:CreateCheckbox(History.CAT_LABEL[cat] or cat, function()
                return not view.q.cats or view.q.cats[cat] == true
            end, function()
                local q = view.q
                if not q.cats then
                    q.cats = {}
                    for _, c in ipairs(History.ALL_CATS) do q.cats[c] = true end
                end
                q.cats[cat] = not q.cats[cat] or nil
                local every = true
                for _, c in ipairs(History.ALL_CATS) do if not q.cats[c] then every = false end end
                if every then q.cats = nil end
                view:Changed()
            end)
        end
    end)
    view.typeDrop:SetPoint("LEFT", view.timeDrop, "RIGHT", 6, 0)
    view.sourceDrop = NewMenu(bar, 230, function(root)
        local q = view.q
        if q.scope then
            root:CreateCheckbox("Only " .. (view.name or "?"), function() return view.q.scope ~= nil end, function()
                view.q.scope = nil
                for _, src in ipairs(SOURCES) do view.q.sources[src.key] = true end
                view:Changed()
            end)
        end
        for _, src in ipairs(SOURCES) do
            root:CreateCheckbox(src.text, function()
                return view.q.scope == nil and view.q.sources[src.key] == true
            end, function()
                local q2 = view.q
                if q2.scope then
                    -- from one entry to this whole list
                    q2.scope = nil
                    for k in pairs(q2.sources) do q2.sources[k] = k == src.key end
                else
                    q2.sources[src.key] = not q2.sources[src.key] or nil
                end
                view:Changed()
            end)
        end
    end)
    view.sourceDrop:SetPoint("LEFT", view.typeDrop, "RIGHT", 6, 0)
    local search = ns.NewSearchBox(bar, 240, "Search player, channel or message", function(text)
        if text ~= view.lastFind then
            view.lastFind = text
            view:Apply(true)
        end
    end)
    search:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    view.search = search

    -- the custom range: From [2026-10-04 13:20]  To [          ]  [Apply]
    local custom = CreateFrame("Frame", nil, f)
    custom:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
    custom:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    custom:SetHeight(22)
    custom:Hide()
    view.custom = custom
    local function Box(label, x)
        local t = ns.NewText(custom, 12)
        t:SetPoint("LEFT", custom, "LEFT", x, 0)
        t:SetText(label)
        local e = CreateFrame("EditBox", nil, custom, "InputBoxTemplate")
        e:SetSize(130, 20)
        e:SetAutoFocus(false)
        e:SetPoint("LEFT", t, "RIGHT", 8, 0)
        ns.EditBox(e)
        return e
    end
    view.fromBox = Box("From", 0)
    view.toBox = Box("To", 190)
    local apply
    apply = ns.NewButton(custom, "Apply", 70, function()
        local q = view.q
        local from = ParseTime(view.fromBox:GetText())
        local toText = M.trim(view.toBox:GetText() or "") or ""
        local to = toText ~= "" and ParseTime(toText) or nil
        view.rangeError:SetText((not from or (toText ~= "" and not to)) and "|cffff6060Dates as 2026-10-05 13:20|r" or "")
        if not from or (toText ~= "" and not to) then return end
        -- a "to" without a time takes the whole day
        if to and not toText:find(":", 1, true) then to = to + DAY - 1 end
        q.from, q.to = from, to
        view:Changed()
    end)
    apply:SetPoint("LEFT", view.toBox, "RIGHT", 8, 0)
    view.applyButton = apply
    view.fromBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); apply:GetScript("OnClick")(apply) end)
    view.toBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); apply:GetScript("OnClick")(apply) end)
    ns.TipOn(view.fromBox, view.fromBox, "The first day and time shown, as 2026-10-05 13:20 (a day alone: from its start).")
    ns.TipOn(view.toBox, view.toBox, "The last day and time shown (empty: up to now; a day alone: to its end).")
    view.rangeError = ns.NewText(custom, 11)
    view.rangeError:SetPoint("LEFT", apply, "RIGHT", 8, 0)

    local lf = CreateFrame("Frame", nil, f)
    lf:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -62)
    lf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 8)
    view.listFrame = lf
    view.list = ns.NewRows(lf, {
        rowH = 18, fontSize = 12, links = true,
        cols = {
            { key = "time", text = "Time", width = 136 },
            { key = "source", text = "Source", width = 140 },
            { key = "member", text = "Player", width = 130 },
            { key = "kind", text = "Type", width = 60 },
            { key = "channel", text = "Channel", width = 120 },
            { key = "message", text = "Message" },
        },
        sort = function(key) SetSort(view, key) end,
        draw = function(row, i) Draw(view, row, i) end,
        enter = function(row, i) Tip(view, row, i) end,
        click = function(row, i, button) Click(view, row, i, button) end,
    })

    -- back / forward (EUI_Window.lua): each query a step; Events in the
    -- line by the arrows is the tab as it opens
    page.navState = function()
        local key = QueryKey(view.q)
        if key and not view.saved[key] then
            if view.nsaved >= 100 then wipe(view.saved); view.nsaved = 0 end
            view.saved[key] = CopyQuery(view.q)
            view.nsaved = view.nsaved + 1
        end
        return key
    end
    page.navTitle = function(key)
        local q = view.saved[key]
        if not q then return "?" end
        local t = Title(q, q.scope and q.scope.label(q.scope.id))
        if q.period then t = t .. ", " .. TimeLabel(q) end
        if q.cats then t = t .. ", " .. TypesLabel(q) end
        return t
    end
    page.navApply = function(key)
        local q = key and view.saved[key]
        view.q = q and CopyQuery(q) or NewQuery()
        view:Refresh(true)
    end
    page.navReset = function()
        view.q = NewQuery()
        view.search:SetText("")
    end
    page.view = view
    return function()
        view:Refresh(view.toTop)
        view.toTop = nil
    end
end

-- Show the Events tab for spec (an entry; a whole list: that list as the
-- source; nil: every list) with opts.period and opts.cats (nil: every type).
function ns.OpenEvents(tabPage, spec, opts)
    if not ns.ShowEventsTab then return end
    opts = opts or {}
    ns.ShowEventsTab(function()
        local q = NewQuery()
        if spec and spec.id == false and spec.source then
            for k in pairs(q.sources) do q.sources[k] = k == spec.source end
        elseif spec then
            q.scope = spec
        end
        q.period = opts.period ~= "all" and opts.period or nil
        if opts.cats then
            q.cats = {}
            for k, v in pairs(opts.cats) do q.cats[k] = v end
        end
        view.q = q
        view.search:SetText("")
        view.sortKey, view.sortAsc = "time", false
        view.toTop = true
    end)
    return view
end

-- the pane histories and older callers: spec's events, its period
function ns.OpenHistoryView(page, spec)
    return ns.OpenEvents(page, spec, { period = spec and spec.period })
end

-- new blocks: read the tab again while it shows, at most 4 times a second
local pending
local function Changed()
    if pending then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = nil
        if view and view.frame:IsVisible() then view:Refresh(false) end
    end)
end
M.Events.Register("PLAYER_BLOCKED", Changed)
M.Events.Register("GUILD_BLOCKS_CHANGED", Changed)
M.Events.Register("PLAYERS_CHANGED", Changed)
M.Events.Register("GUILDS_CHANGED", Changed)
