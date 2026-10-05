-------------------------------------------------------------------------------
--  EUI_Detail.lua -- the details pane of the Players, Guilds and Chat Filters
--  tabs as three pages, picked by the buttons along its bottom:
--    Summary         the counts and a pie of this session / last 24 hours /
--                    all time (ns.NewSummary below, EUI_Pie.lua)
--    Event History   the block history list, the whole page
--    View/Edit Rule  the entry's settings and actions
--  One frame per page, built with the pane; the page picked is kept per tab.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BAR_H = 24

-------------------------------------------------------------------------------
--  The three pages and the buttons along the bottom
-------------------------------------------------------------------------------
local PAGES = {
    { key = "summary", text = "Summary" },
    { key = "history", text = "Event History" },
    { key = "rule",    text = "View/Edit Rule" },
}
ns.DETAIL_PAGES = PAGES

-- the page last picked, per tab ("players", "guilds", "filters")
local picked = {}

local DP = {}
DP.__index = DP

function DP:Select(key)
    if not self[key] then key = "rule" end
    if self.only and not self.only[key] then key = "rule" end
    self.shown = key
    picked[self.kind] = key
    for i, p in ipairs(PAGES) do
        local on = p.key == key
        self[p.key]:SetShown(on)
        ns.SetTabSelected(self.buttons[i], on)
    end
end

-- only: { rule = true } to offer just that page (nil: all three)
function DP:Limit(only)
    self.only = only
    for i, p in ipairs(PAGES) do
        self.buttons[i]:SetEnabled(not only or only[p.key] == true)
        self.buttons[i]:SetAlpha((not only or only[p.key]) and 1 or 0.4)
    end
    if only and not only[self.shown] then self:Select("rule") end
end

-- body: the pane body; top: where the pages start (below the heading);
-- kind: remembers the page picked on this tab
function ns.NewDetailPages(body, top, kind)
    local dp = setmetatable({ kind = kind, buttons = {} }, DP)
    for _, p in ipairs(PAGES) do
        local f = CreateFrame("Frame", nil, body)
        f:SetPoint("TOPLEFT", body, "TOPLEFT", 0, top)
        f:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, BAR_H + 10)
        f:Hide()
        dp[p.key] = f
    end
    local bar = CreateFrame("Frame", nil, body)
    bar:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 8, 6)
    bar:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -8, 6)
    bar:SetHeight(BAR_H)
    dp.bar = bar
    local n = #PAGES
    for i, p in ipairs(PAGES) do
        local b = CreateFrame("Button", nil, bar)
        b:SetNormalFontObject(GameFontHighlightSmall)
        b:SetText(p.text)
        b:SetHeight(BAR_H)
        -- equal widths across the bar
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        b:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        b:SetScript("OnClick", function() dp:Select(p.key) end)
        ns.Tab(b)
        dp.buttons[i] = b
    end
    local function Lay()
        local w = bar:GetWidth()
        if not w or w <= 0 then return end
        local bw = (w - (n - 1) * 4) / n
        for i, b in ipairs(dp.buttons) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * (bw + 4), 0)
            b:SetSize(bw, BAR_H)
        end
    end
    bar:SetScript("OnSizeChanged", Lay)
    Lay()
    dp:Select(picked[kind] or "summary")
    return dp
end

-------------------------------------------------------------------------------
--  Summary: a pie of this session / last 24 hours / all time (EUI_Pie.lua),
--  a tick box per period (all time starts off; off takes its slice out),
--  View Events.
--  A click on a slice opens the Block History view of that period. The
--  session and day counts come from the core (History.RecentCounts, 3.2),
--  all time from the entry's counts: nothing here loads
--  PourSocialScore_Logging; View Events and a slice do, as asked.
-------------------------------------------------------------------------------
local M = ns.M
local History = M.PSS_History
local DAY = 86400

local PERIODS = {
    { key = "session", text = "This session",  r = 0.31, g = 0.76, b = 0.97 },
    { key = "day",     text = "Last 24 hours", r = 1.00, g = 0.72, b = 0.30 },
    { key = "all",     text = "All time",      r = 0.58, g = 0.46, b = 0.80 },
}
ns.SUMMARY_PERIODS = PERIODS

-- the periods ticked (shared by every tab, kept while the window is
-- loaded). All time starts unticked: it holds the other two and dwarfs them.
local periodOn = { session = true, day = true, all = false }

function ns.PeriodText(key)
    for _, per in ipairs(PERIODS) do if per.key == key then return per.text end end
    return ""
end

-- the first server second of a period (nil: all time)
function ns.SummarySince(key)
    if key == "session" then return History.SessionStart and History.SessionStart() or nil end
    if key == "day" then return History.Now() - DAY end
    return nil
end

local function Recent(owner)
    if not (owner and History.RecentCounts) then return 0, 0 end
    return History.RecentCounts(owner)
end

-- "Stored: 8 kept for this player, 1 waiting, 3 not stored or expired":
-- where owner's counted blocks are (History.Where, 3.2). A filter's lines
-- are in the 2000-line log, a person's in their kept lines (3.2-dev3);
-- world chat of a person is counted, never stored. From core
-- 3.2.0-dev007 (History.LOG_ALL) every line is in the log again and a
-- person's newest are kept once trimmed off it. Before the block
-- history is loaded only the waiting lines are known.
function ns.WhereText(owner, total, who)
    if not (owner and History.Where) or (total or 0) == 0 then return "" end
    local inLog, kept, waiting = History.Where(owner)
    if not inLog then
        return ("Stored: %d waiting, the rest in the block history (not loaded)."):format(waiting)
    end
    local parts = {}
    if inLog > 0 then parts[#parts + 1] = ("%d in the log"):format(inLog) end
    if kept > 0 then parts[#parts + 1] = ("%d kept for %s"):format(kept, who or "this player") end
    if waiting > 0 then parts[#parts + 1] = ("%d waiting"):format(waiting) end
    local gone = total - inLog - kept - waiting
    if gone > 0 then
        local person = History.KeepsOwner and History.KeepsOwner(owner) and History.KEEP_TOTAL and not History.LOG_ALL
        parts[#parts + 1] = ("|cffaaaaaa%d %s|r"):format(gone, person and "not stored or expired" or "expired from logs")
    end
    if #parts == 0 then return "Stored: nothing." end
    return "Stored: " .. table.concat(parts, ", ") .. "."
end

local SM = {}
SM.__index = SM
local summaries = {}

local Build

-- The periods ticked as slices. They are nested (the last 24 hours hold
-- this session, all time holds both), so each slice is drawn as only what
-- the smaller ticked ones before it do not hold: the overlap is drawn once,
-- in the smaller slice, and lit with the bigger one on hover (within).
-- v: { session, day, all }; pool: the slice tables, reused.
function ns.PeriodSlices(v, slices, map, pool)
    for i = #slices, 1, -1 do slices[i] = nil end
    local n, inner = 0, 0
    for _, per in ipairs(PERIODS) do
        if periodOn[per.key] then
            n = n + 1
            local sl = pool[n] or { within = {} }
            pool[n] = sl
            local value = v[per.key] or 0
            sl.value, sl.r, sl.g, sl.b, sl.text = value, per.r, per.g, per.b, per.text
            sl.draw = math.max(0, value - inner)
            sl.inner = math.min(inner, value)
            for i in pairs(sl.within) do sl.within[i] = nil end
            for i = 1, n - 1 do sl.within[i] = true end
            sl.innerText = n > 1 and slices[n - 1].text or nil
            slices[n] = sl
            map[n] = per.key
            inner = math.max(inner, value)
        end
    end
    return n
end

-- A slice's tooltip: its count, and how much of it the smaller slice holds.
function ns.PeriodTip(title, sl, click)
    local t = ("%s\n%s: %d blocked"):format(title or "", sl.text, sl.value or 0)
    if sl.innerText and (sl.inner or 0) > 0 then
        t = t .. ("\n|cffaaaaaa%d of them also in %s (lit with it)|r"):format(sl.inner, string.lower(sl.innerText))
    end
    if click then t = t .. "\n\n|cffaaaaaaClick: these events in the Block History view.|r" end
    return t
end

function SM:Refresh()
    if not self.page:IsVisible() then return end
    if not self.pie then Build(self) end
    local s, d
    if self.recent then s, d = self.recent.session or 0, self.recent.day or 0 else s, d = Recent(self.owner) end
    local v = self.values
    v.session, v.day, v.all = s, d, self.allTime or 0
    for _, per in ipairs(PERIODS) do self.boxes[per.key].count:SetText(tostring(v[per.key])) end
    ns.PeriodSlices(v, self.slices, self.map, self.pool)
    self.pie:Set(self.slices)
    self.where:SetText(self.noWhere and "" or ns.WhereText(self.owner, v.all, self.whoText))
    self.empty:SetShown(v.all == 0 and v.session == 0 and v.day == 0)
    self.viewButton:SetEnabled(self.specFn ~= nil)
    self.viewButton:SetShown(self.specFn ~= nil)
end

-- owner: the core's owner key (History.PlayerKey ...); allTime: the
-- entry's all-time count; title: its name; specFn(id): its Block History
-- spec (made only when opened); opts.noWhere: no "Stored:" line (a guild:
-- its lines are its members'), opts.who: "this player" for the keep,
-- opts.recent: { session =, day = } counted elsewhere (a default guild
-- list, a whole list) instead of the owner's
function SM:Set(owner, allTime, title, specFn, id, opts)
    self.owner, self.allTime, self.title, self.specFn, self.id = owner, allTime, title, specFn, id
    self.noWhere, self.whoText = opts and opts.noWhere, opts and opts.who
    self.recent = opts and opts.recent
    self:Refresh()
end

function SM:Open(key)
    local spec = self.specFn and self.specFn(self.id)
    if not spec then return end
    if key ~= "all" then spec.period = key end
    ns.OpenHistoryView(self.tabPage, spec)
end

-- the pie, the tick boxes and View Events: made the first time the page shows
function Build(sm)
    local page, top = sm.page, sm.top
    local SIZE = sm.size or 116
    sm.pie = ns.NewPie(page, SIZE, function(i) sm:Open(sm.map[i]) end)
    sm.pie.frame:SetPoint("TOPLEFT", page, "TOPLEFT", 18, top)
    sm.pie.tip = function(i) return ns.PeriodTip(sm.title, sm.slices[i], sm.specFn ~= nil) end
    sm.empty = ns.NewText(page, 11)
    sm.empty:SetPoint("CENTER", sm.pie.frame, "CENTER", 0, 0)
    sm.empty:SetTextColor(1, 1, 1, 0.5)
    sm.empty:SetText("Nothing yet")

    -- a tick box per period: its colour, name and count
    local x, y = SIZE + 40, top - (sm.size and 2 or 8)
    for _, per in ipairs(PERIODS) do
        local c = ns.NewCheck(page)
        c:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
        c:SetChecked(periodOn[per.key])
        local sq = page:CreateTexture(nil, "ARTWORK")
        sq:SetSize(10, 10)
        sq:SetColorTexture(per.r, per.g, per.b, 0.9)
        sq:SetPoint("LEFT", c, "RIGHT", 2, 0)
        local t = ns.NewText(page, 12)
        t:SetPoint("LEFT", sq, "RIGHT", 6, 0)
        t:SetText(per.text)
        c.count = ns.NewText(page, 12)
        c.count:SetPoint("LEFT", c, "RIGHT", sm.size and 104 or 128, 0)
        c.count:SetTextColor(per.r, per.g, per.b)
        c:SetScript("OnClick", function(self)
            periodOn[per.key] = self:GetChecked() and true or false
            for _, other in ipairs(summaries) do
                other.boxes[per.key]:SetChecked(periodOn[per.key])
                other:Refresh()
            end
        end)
        ns.TipOn(c, c, "Shows " .. string.lower(per.text) .. " in the pie.")
        sm.boxes[per.key] = c
        y = y - 26
    end
    if not History.RecentCounts then
        -- an older core: all time only
        for _, key in ipairs({ "session", "day" }) do
            sm.boxes[key]:Disable()
            ns.TipOn(sm.boxes[key], sm.boxes[key], "Needs PourSocialScore 3.2 or later.")
        end
    end

    -- where the blocks are: log / kept / waiting / expired
    sm.where = ns.NewText(page, 11)
    sm.where:SetPoint("TOPLEFT", page, "TOPLEFT", 12, top - SIZE - 12)
    sm.where:SetPoint("RIGHT", page, "RIGHT", -10, 0)
    sm.where:SetJustifyH("LEFT")
    sm.where:SetWordWrap(true)
    sm.where:SetTextColor(1, 1, 1, 0.7)

    local view
    if sm.size then
        -- a small pie (a list's pane): beside the All time count, so it
        -- stays clear of what is drawn under the pie
        view = ns.NewButton(page, "View Events", 80, function() sm:Open("all") end)
        view:SetPoint("RIGHT", page, "RIGHT", -10, 0)
        view:SetPoint("TOP", sm.boxes.all, "TOP", 0, 0)
    else
        view = ns.NewButton(page, "View Events", 110, function() sm:Open("all") end)
        view:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y - 8)
    end
    ns.TipOn(view, view, "Every logged event of this entry in the Block History view (loads the block history).")
    sm.viewButton = view

    summaries[#summaries + 1] = sm
end

-- page: the Summary page; tabPage: the tab (for the Block History view);
-- top: where the pie starts; size: the pie (116 when nil)
function ns.NewSummary(page, tabPage, top, size)
    local sm = setmetatable({ page = page, tabPage = tabPage, top = top, size = size, slices = {}, map = {},
        pool = {}, values = {}, boxes = {} }, SM)
    page:HookScript("OnShow", function() sm:Refresh() end)
    return sm
end

-------------------------------------------------------------------------------
--  A pie of all-time blocks by type, with a tick box per type blocked (a
--  default guild list, a whole list): unticked, its slice leaves the pie
--  (its count stays in the legend). The ticks are shared by every type pie
--  while the window is loaded. Only all time: the session and 24 hour
--  counts are not added up by type. No click-through.
--    local tp = ns.NewTypePie(parent, top, size)
--    tp:Set(counts, title)    -- counts: total and one count per type
--  Made the first time Set is called.
-------------------------------------------------------------------------------
local TYPE_SLOTS = 7

-- types unticked (shared by every type pie)
local typeOff = {}
local typePies = {}

local function HexColor(hex)
    hex = tostring(hex or "ffffffff")
    return (tonumber(hex:sub(3, 4), 16) or 255) / 255, (tonumber(hex:sub(5, 6), 16) or 255) / 255,
        (tonumber(hex:sub(7, 8), 16) or 255) / 255
end

local TP = {}
TP.__index = TP

function TP:Build()
    local f, size, top = self.frame, self.size, self.top
    self.pie = ns.NewPie(f, size)
    self.pie.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 18, top)
    self.pie.tip = function(i)
        local sl = self.slices[i]
        return ("%s\n%s: %d blocked (all time)"):format(self.title or "", sl.text, sl.value or 0)
    end
    self.keys = {}
    for i = 1, TYPE_SLOTS do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local c = ns.NewCheck(f)
        c:SetSize(18, 18)
        c:SetPoint("TOPLEFT", f, "TOPLEFT", size + 20 + col * 132, top - 2 - row * 20)
        local sq = f:CreateTexture(nil, "ARTWORK")
        sq:SetSize(10, 10)
        sq:SetPoint("LEFT", c, "RIGHT", 2, 0)
        local t = ns.NewText(f, 11)
        t:SetPoint("LEFT", sq, "RIGHT", 5, 0)
        t:SetWidth(98)
        t:SetJustifyH("LEFT")
        local k = { check = c, sq = sq, text = t }
        c:SetScript("OnClick", function(btn)
            if not k.cat then return end
            typeOff[k.cat] = not btn:GetChecked() or nil
            for _, other in ipairs(typePies) do
                if other.counts then other:Set(other.counts, other.title) end
            end
        end)
        ns.TipOn(c, c, "Shows this type in the pie.")
        self.keys[i] = k
        self.slices[i] = {}
    end
    typePies[#typePies + 1] = self
    self.empty = ns.NewText(f, 11)
    self.empty:SetPoint("CENTER", self.pie.frame, "CENTER", 0, 0)
    self.empty:SetTextColor(1, 1, 1, 0.5)
    self.empty:SetText("Nothing yet")
end

function TP:Set(counts, title)
    if not self.pie then self:Build() end
    self.title, self.counts = title, counts
    local slices, n = self.slices, 0
    for _, cat in ipairs(History.ALL_CATS or {}) do
        local v = tonumber(counts and counts[cat]) or 0
        if v > 0 and n < TYPE_SLOTS then
            n = n + 1
            local sl = slices[n]
            sl.r, sl.g, sl.b = HexColor(History.CAT_COLOR[cat])
            sl.value, sl.text, sl.cat = v, History.CAT_LABEL[cat] or cat, cat
            sl.draw = typeOff[cat] and 0 or nil
            local k = self.keys[n]
            k.cat = cat
            k.check:SetChecked(not typeOff[cat])
            k.sq:SetColorTexture(sl.r, sl.g, sl.b, typeOff[cat] and 0.3 or 0.9)
            k.text:SetText(sl.text .. "  |cffffffff" .. v .. "|r")
            k.check:Show()
            k.sq:Show()
            k.text:Show()
        end
    end
    for i = n + 1, TYPE_SLOTS do
        slices[i].value, slices[i].draw = 0, nil
        local k = self.keys[i]
        k.cat = nil
        k.check:Hide()
        k.sq:Hide()
        k.text:Hide()
    end
    self.count = n
    self.pie:Set(slices)
    self.empty:SetShown(n == 0)
end

-- parent: the frame it draws on; top: where the pie starts; size: the pie
function ns.NewTypePie(parent, top, size)
    return setmetatable({ frame = parent, top = top, size = size or 84, slices = {} }, TP)
end

-------------------------------------------------------------------------------
--  A whole list's totals, shown in a tab's pane when nothing on it is
--  selected: its blocks this session / last 24 hours / all time (the
--  Summary pie) and by type. The counts come from the core
--  (M.PSS_ListTotals, PourSocialScore 3.2.0-dev004); nothing loads
--  PourSocialScore_Logging until a slice or View Events opens the whole
--  list's events (allSpec(): its Block History spec). An older core: the
--  hint only.
--    local tot = ns.NewTotals(pane, tabPage, kind, title, hint, allSpec)
--    tot:Show(guildRows)      -- kind "players", "guilds" or "filters"
-------------------------------------------------------------------------------
local TT = {}
TT.__index = TT

function TT:Show(guildRows)
    self.frame:Show()
    local ok = M.PSS_ListTotals ~= nil
    self.charts:SetShown(ok)
    if not ok then return end
    local c = M.PSS_ListTotals(self.kind, self.counts, guildRows)
    self.recent.session, self.recent.day = c.session, c.day
    self.info:SetText(("Blocked |cffffff00%d|r in all.  |cffaaaaaaSelect an entry to see its own.|r"):format(c.total or 0))
    self.summary:Set(nil, c.total or 0, self.title, self.specFn, nil, { noWhere = true, recent = self.recent })
    self.typePie:Set(c, self.title)
end

function TT:Hide() self.frame:Hide() end

function ns.NewTotals(pane, tabPage, kind, title, hint, allSpec)
    local tt = setmetatable({ kind = kind, title = title, counts = {}, recent = {} }, TT)
    if allSpec then
        -- a copy each time: a slice sets the period it opens on
        tt.specFn = function()
            local spec = {}
            for k, v in pairs(allSpec()) do spec[k] = v end
            return spec
        end
    end
    local f = CreateFrame("Frame", nil, pane)
    f:SetAllPoints()
    f:Hide()
    tt.frame = f
    local heading = ns.NewHeading(f, title)
    heading:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    tt.heading = heading
    local info = ns.NewText(f, 12)
    info:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
    info:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    info:SetText(hint)
    tt.info = info
    tt.charts = CreateFrame("Frame", nil, f)
    tt.charts:SetAllPoints()
    tt.summary = ns.NewSummary(tt.charts, tabPage, -52, 84)
    tt.typePie = ns.NewTypePie(tt.charts, -52 - 84 - 10, 84)
    return tt
end
