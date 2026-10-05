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
--  a tick box per period (all on; off takes its slice out), View Events.
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

-- the periods ticked (shared by every tab, kept while the window is loaded)
local periodOn = { session = true, day = true, all = true }

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

-- "Stored: 8 in the log, 2 kept for this player, 1 waiting, 1 expired":
-- where owner's counted blocks are (History.Where, 3.2). Before the block
-- history is loaded only the waiting lines are known.
function ns.WhereText(owner, total, who)
    if not (owner and History.Where) or (total or 0) == 0 then return "" end
    local inLog, kept, waiting = History.Where(owner)
    if not inLog then
        return ("Stored: %d waiting, the rest in the block history (not loaded)."):format(waiting)
    end
    local parts = { ("%d in the log"):format(inLog) }
    if kept > 0 then parts[#parts + 1] = ("%d kept for %s"):format(kept, who or "this player") end
    if waiting > 0 then parts[#parts + 1] = ("%d waiting"):format(waiting) end
    local gone = total - inLog - kept - waiting
    if gone > 0 then parts[#parts + 1] = ("|cffaaaaaa%d expired from logs|r"):format(gone) end
    return "Stored: " .. table.concat(parts, ", ") .. "."
end

local SM = {}
SM.__index = SM
local summaries = {}

local Build

function SM:Refresh()
    if not self.page:IsVisible() then return end
    if not self.pie then Build(self) end
    local s, d = Recent(self.owner)
    local v = self.values
    v.session, v.day, v.all = s, d, self.allTime or 0
    local slices, map, n = self.slices, self.map, 0
    for i = #slices, 1, -1 do slices[i] = nil end
    for _, per in ipairs(PERIODS) do
        local box = self.boxes[per.key]
        box.count:SetText(tostring(v[per.key]))
        if periodOn[per.key] then
            n = n + 1
            local sl = self.pool[n] or {}
            self.pool[n] = sl
            sl.value, sl.r, sl.g, sl.b, sl.text = v[per.key], per.r, per.g, per.b, per.text
            slices[n] = sl
            map[n] = per.key
        end
    end
    self.pie:Set(slices)
    self.where:SetText(self.noWhere and "" or ns.WhereText(self.owner, v.all, self.whoText))
    self.empty:SetShown(v.all == 0 and v.session == 0 and v.day == 0)
    self.viewButton:SetEnabled(self.specFn ~= nil)
end

-- owner: the core's owner key (History.PlayerKey ...); allTime: the
-- entry's all-time count; title: its name; specFn(id): its Block History
-- spec (made only when opened); opts.noWhere: no "Stored:" line (a guild:
-- its lines are its members'), opts.who: "this player" for the keep
function SM:Set(owner, allTime, title, specFn, id, opts)
    self.owner, self.allTime, self.title, self.specFn, self.id = owner, allTime, title, specFn, id
    self.noWhere, self.whoText = opts and opts.noWhere, opts and opts.who
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
    local SIZE = 116
    sm.pie = ns.NewPie(page, SIZE, function(i) sm:Open(sm.map[i]) end)
    sm.pie.frame:SetPoint("TOPLEFT", page, "TOPLEFT", 18, top)
    sm.pie.tip = function(i)
        local sl = sm.slices[i]
        return ("%s\n%s: %d blocked\n\n|cffaaaaaaClick: these events in the Block History view.|r")
            :format(sm.title or "", sl.text, sl.value or 0)
    end
    sm.empty = ns.NewText(page, 11)
    sm.empty:SetPoint("CENTER", sm.pie.frame, "CENTER", 0, 0)
    sm.empty:SetTextColor(1, 1, 1, 0.5)
    sm.empty:SetText("Nothing yet")

    -- a tick box per period: its colour, name and count
    local x, y = SIZE + 40, top - 8
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
        c.count:SetPoint("LEFT", c, "RIGHT", 128, 0)
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

    local view = ns.NewButton(page, "View Events", 110, function() sm:Open("all") end)
    view:SetPoint("TOPLEFT", page, "TOPLEFT", x + 4, y - 8)
    ns.TipOn(view, view, "Every logged event of this entry in the Block History view (loads the block history).")
    sm.viewButton = view

    summaries[#summaries + 1] = sm
end

-- page: the Summary page; tabPage: the tab (for the Block History view);
-- top: where the pie starts
function ns.NewSummary(page, tabPage, top)
    local sm = setmetatable({ page = page, tabPage = tabPage, top = top, slices = {}, map = {}, pool = {},
        values = {}, boxes = {} }, SM)
    page:HookScript("OnShow", function() sm:Refresh() end)
    return sm
end
