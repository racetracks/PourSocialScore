-------------------------------------------------------------------------------
--  EUI_Detail.lua -- the details pane of the Players, Guilds and Chat Filters
--  tabs as three pages, picked by the buttons along its bottom:
--    Summary         the entry's block counts
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
