------------------------------------------------------------------------
-- POUR SOCIAL SCORE - UI KIT
--
-- One set of building blocks for every page and window, taken from the
-- Player Ignore List (the reference design):
--   * windows      : PortraitFrameTemplate + the Battle.net portrait, an
--                    inset panel, a bottom button bar and a resize grip
--   * summary      : title / total / per-type breakdown at the top of a panel
--   * header row   : Blizzard Who-list column tabs, click to sort (arrow
--                    shows the column and direction)
--   * letter header: the W I G P C header - one blank tab with a gold letter
--                    button over each tickbox
--   * block metrics: Whispers / Party Invites / Party/Raid / World Chat /
--                    Guild Invites count columns (two-line gold labels)
--   * rows         : 20 px, quest-title highlight on hover, the same
--                    highlight locked on the selected row, white text
--   * checkboxes   : 20 x 20 UICheckButtonTemplate
--   * buttons      : 110 x 22 on the bottom bar, 100 x 22 top right, 18 px
--                    small-font buttons inside rows
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M
local V = addon.V
local L = addon.L

local UI = {}
M.UI = UI

UI.HEADER_H    = 24
UI.ROW_H       = 20
UI.CHECK       = 20
UI.ROW_BUTTON_H = 18
UI.BAR_W, UI.BAR_H = 110, 22
UI.TOP_W       = 100
UI.LIST_TOP    = 86           -- panel top -> first row (summary + header)
UI.HEADER_Y    = -(86 - 24)   -- panel top -> header row
UI.EXCL_W      = 154          -- W I G P C column
UI.EXCL_STEP   = 28
UI.HIGHLIGHT   = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
UI.SORT_ARROW  = "Interface\\Buttons\\UI-SortArrow"
UI.PORTRAIT    = "Interface\\FriendsFrame\\Battlenet-Portrait"

-- W I G P C: the order, letters and wording used everywhere. "field" is the
-- matching switch on a Player Ignore List record.
--
-- TICKED = ALLOWED. The core (records, guild rules, the chat block sources)
-- stores and decides in "blocked" terms (whispersBlocked, g.block[cat],
-- m.block[cat]); every W I G P C tickbox shows the inverse: ticked = that
-- feature is allowed through, unticked = blocked. Always go through
-- UI.ExclChecked / UI.ExclBlocked so no frame gets this backwards.
UI.EXCL = {
    { cat = "whisper",     letter = "W", field = "whispersBlocked",     label = "Whispers" },
    { cat = "partyInvite", letter = "I", field = "partyInvitesBlocked", label = "Party invites" },
    { cat = "guildInvite", letter = "G", field = "guildInvitesBlocked", label = "Guild invites" },
    { cat = "partyRaid",   letter = "P", field = "partyRaidBlocked",    label = "Party/Raid chat (incl. raid warnings)" },
    { cat = "world",       letter = "C", field = "channelsBlocked",     label = "Chat channels (Trade, General, LFG, communities) and public chat (say, yell, emotes)" },
}
UI.EXCL_BY_CAT = {}
for _, e in ipairs(UI.EXCL) do UI.EXCL_BY_CAT[e.cat] = e end

-- core "blocked" value -> tickbox state (ticked = allowed)
function UI.ExclChecked(blocked) return not blocked end
-- tickbox -> core "blocked" value
function UI.ExclBlocked(box) return not box:GetChecked() end
UI.EXCL_NOTE = "Ticked = allowed, unticked = blocked." 

local function hideTip() GameTooltip:Hide() end
UI.HideTip = hideTip

------------------------------------------------------------------------
-- Fonts / text
------------------------------------------------------------------------
-- A text cell inside a row (white, one line).
function UI.Cell(row, x, w, justify, font)
    local fs = row:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("LEFT", row, "LEFT", x + 6, 0)
    fs:SetWidth(math.max(4, w - 10))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Title / total / breakdown at the top of a panel (Player Ignore List layout).
function UI.CreateSummary(panel, titleText, width)
    width = width or 520
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 10, -8)
    t:SetWidth(width)
    t:SetJustifyH("LEFT")
    t:SetText(titleText or "")
    local i = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    i:SetPoint("TOPLEFT", 10, -25)
    i:SetWidth(width)
    i:SetJustifyH("LEFT")
    local b = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b:SetPoint("TOPLEFT", 10, -42)
    b:SetWidth(math.max(width, 700))
    b:SetJustifyH("LEFT")
    return t, i, b
end

-- Section heading inside a panel (Options sections, detail window blocks).
function UI.Heading(parent, text)
    local h = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetJustifyH("LEFT")
    h:SetText(text or "")
    return h
end

------------------------------------------------------------------------
-- Buttons, boxes
------------------------------------------------------------------------
function UI.Button(parent, text, w, h, name)
    local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    b:SetSize(w or UI.BAR_W, h or UI.BAR_H)
    b:SetText(text or "")
    return b
end

-- Small button that sits inside a 20 px row.
function UI.RowButton(row, text, w)
    local b = UI.Button(row, text, w, UI.ROW_BUTTON_H)
    if GameFontNormalSmall then b:SetNormalFontObject(GameFontNormalSmall) end
    if GameFontDisableSmall then b:SetDisabledFontObject(GameFontDisableSmall) end
    if GameFontHighlightSmall then b:SetHighlightFontObject(GameFontHighlightSmall) end
    return b
end

-- Bottom bar (below a panel). First call with anchorTo = nil puts the button
-- at the right edge; pass the previous button to continue leftwards.
function UI.BarButton(panel, text, anchorTo, w, name)
    local b = UI.Button(panel, text, w or UI.BAR_W, UI.BAR_H, name)
    if anchorTo then
        b:SetPoint("RIGHT", anchorTo, "LEFT", 0, 0)
    else
        b:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, -24)
    end
    return b
end

-- Left end of the bottom bar.
function UI.BarButtonLeft(panel, text, anchorTo, w, name)
    local b = UI.Button(panel, text, w or UI.BAR_W, UI.BAR_H, name)
    if anchorTo then
        b:SetPoint("LEFT", anchorTo, "RIGHT", 0, 0)
    else
        b:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", -1, -24)
    end
    return b
end

-- Top-right of a panel (Add Player / Player Search layout).
function UI.TopButton(panel, text, anchorTo, w, name)
    local b = UI.Button(panel, text, w or UI.TOP_W, UI.BAR_H, name)
    if anchorTo then
        b:SetPoint("RIGHT", anchorTo, "LEFT", -6, 0)
    else
        b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -4)
    end
    return b
end

function UI.SearchBox(panel, anchorTo, w, name)
    local e = CreateFrame("EditBox", name, panel, "InputBoxTemplate")
    e:SetSize(w or 190, 20)
    if anchorTo then
        e:SetPoint("RIGHT", anchorTo, "LEFT", -10, 0)
    else
        e:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -5)
    end
    e:SetAutoFocus(false)
    e:SetMaxLetters(128)
    e:SetTextInsets(4, 4, 0, 0)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

-- Edit box inside a 20 px row.
function UI.RowEditBox(row, x, w, maxLetters)
    local e = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    e:SetSize(math.max(20, w - 14), UI.ROW_BUTTON_H)
    e:SetPoint("LEFT", row, "LEFT", x + 9, 0)
    e:SetAutoFocus(false)
    e:SetMaxLetters(maxLetters or 128)
    e:SetTextInsets(2, 2, 0, 0)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

function UI.Check(parent, size)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(size or UI.CHECK, size or UI.CHECK)
    return c
end

-- Labelled checkbox (Options / Import-Export style).
function UI.LabeledCheck(parent, text)
    local c = UI.Check(parent)
    local t = c.Text or c.text or c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    t:SetFontObject("GameFontHighlight")
    t:ClearAllPoints()
    t:SetPoint("LEFT", c, "RIGHT", 2, 0)
    t:SetText(text or "")
    c.label = t
    return c
end

------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------
-- A table row: 20 px button with the list highlight. row:SetSelected(bool)
-- locks the highlight like the Player Ignore List selection.
function UI.CreateRow(parent, width, height)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(height or UI.ROW_H)
    -- text in a column made wider than the row is cut at the row's edge
    if r.SetClipsChildren then r:SetClipsChildren(true) end
    if width then r:SetWidth(width) end
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(r)
    hl:SetTexture(UI.HIGHLIGHT)
    hl:SetBlendMode("ADD")
    r:SetHighlightTexture(hl)
    function r:SetSelected(on)
        if on then self:LockHighlight() else self:UnlockHighlight() end
    end
    return r
end

------------------------------------------------------------------------
-- Column header tabs (Who-list look)
------------------------------------------------------------------------
local headerCount = 0
local function templateExists(name)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
        if ok then return info ~= nil end
    end
    return nil
end

function UI.CreateHeader(parent, text, width)
    headerCount = headerCount + 1
    local name = "PSSColumnHeader" .. headerCount
    local h
    for _, tmpl in ipairs({ "WhoFrameColumnHeaderTemplate", "FriendsFrameColumnHeaderTemplate" }) do
        if templateExists(tmpl) ~= false then
            local ok, f = pcall(CreateFrame, "Button", name, parent, tmpl)
            if ok and f then h = f break end
        end
    end
    if not h then
        -- hand-built, same textures as the Who frame column tabs
        h = CreateFrame("Button", name, parent)
        h:SetHeight(UI.HEADER_H)
        local tex = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"
        local left = h:CreateTexture(name .. "Left", "BACKGROUND")
        left:SetTexture(tex); left:SetSize(5, 24); left:SetPoint("TOPLEFT"); left:SetTexCoord(0, 0.078125, 0, 0.75)
        local right = h:CreateTexture(name .. "Right", "BACKGROUND")
        right:SetTexture(tex); right:SetSize(4, 24); right:SetPoint("TOPRIGHT"); right:SetTexCoord(0.90625, 0.96875, 0, 0.75)
        local middle = h:CreateTexture(name .. "Middle", "BACKGROUND")
        middle:SetTexture(tex); middle:SetSize(10, 24)
        middle:SetPoint("LEFT", left, "RIGHT"); middle:SetPoint("RIGHT", right, "LEFT")
        middle:SetTexCoord(0.078125, 0.90625, 0, 0.75)
        local hl = h:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
        hl:SetBlendMode("ADD"); hl:SetPoint("TOPLEFT", 2, -2); hl:SetPoint("BOTTOMRIGHT", -2, 2)
        h:SetHighlightTexture(hl)
        h:SetText(" ")
    end
    h:SetNormalFontObject("GameFontHighlight")
    UI.SetHeaderWidth(h, width)
    h:SetText(text or "")
    h:SetScript("OnClick", nil)
    return h
end

function UI.SetHeaderWidth(h, width)
    h:SetWidth(width)
    local mid = _G[(h:GetName() or "") .. "Middle"] or h.Middle
    if mid and mid.SetWidth then mid:SetWidth(width - 9) end
end

function UI.AddSortArrow(h, small)
    local a = h:CreateTexture(nil, "OVERLAY")
    a:SetTexture(UI.SORT_ARROW)
    if small then a:SetSize(7, 6) else a:SetSize(9, 8); a:SetPoint("RIGHT", -4, 0) end
    a:Hide()
    h.sortArrow = a
    return a
end

local function setArrow(a, shown, asc)
    if not a then return end
    a:SetShown(shown)
    if asc then a:SetTexCoord(0, 0.5625, 1, 0) else a:SetTexCoord(0, 0.5625, 0, 1) end
end

-- X of slot i (1-based) inside a letter column of width w.
function UI.SlotX(colX, w, step, i, n)
    n = n or #UI.EXCL
    return colX + (w - (n - 1) * step) / 2 + (i - 1) * step
end

-- Header row.
--   cols = { { key=, text=, width=, sort=false (not sortable), tip="...",
--              justify="RIGHT", minWidth=,
--              letters = "excl"  (W I G P C letter column), small = true (metrics),
--              lettersTitle=, lettersNote=, fill = true }, ... }
--   onSort(key) is called with the column key, or "<key>:<cat>" for a
--   letter of a letter column.
--   opts = { id = "players" (widths are saved under this name),
--            onLayout = function(hr) (after any column changed width) }
--
-- RESIZABLE COLUMNS: drag the right edge of a column header to resize it;
-- right-click the edge to put that column back to its default width. Widths
-- are remembered per table (PourSocialScoreDB.columnWidths[id]). A column
-- marked fill = true takes whatever width is left (hr:SetAvailableWidth),
-- so it has no drag edge of its own.
--
-- Everything placed in a column is registered with hr:Track(key, placer) and
-- moves/resizes with it. Use UI.TCell / UI.TRowButton / UI.TRowEditBox /
-- UI.TCenter for that; UI.CreateMetricCells and UI.CreateExclusionBoxes do it
-- themselves when given the header row.
--
-- Returns hr with hr.x[key] (offset of the column from the row start),
-- hr.w[key], hr.total, hr:SetSort(key, asc), hr:SetShown(bool), hr.headers.
local MIN_COL_W = 28

local function savedWidths(id)
    local db = PourSocialScoreDB
    if not id or type(db) ~= "table" then return nil end
    db.columnWidths = type(db.columnWidths) == "table" and db.columnWidths or {}
    db.columnWidths[id] = type(db.columnWidths[id]) == "table" and db.columnWidths[id] or {}
    return db.columnWidths[id]
end

local function cursorX(frame)
    local x = GetCursorPosition()
    local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    return x / scale
end

function UI.CreateHeaderRow(parent, cols, x, y, onSort, opts)
    opts = opts or {}
    local hr = { x = {}, w = {}, byKey = {}, headers = {}, sortables = {}, cols = cols,
                 parent = parent, x0 = x or 0, y0 = y or 0, id = opts.id, onLayout = opts.onLayout,
                 trackers = {}, def = {}, minW = {}, colByKey = {}, avail = nil }

    -- widths: saved > default
    local saved = savedWidths(opts.id)
    for _, c in ipairs(cols) do
        hr.def[c.key] = c.width
        hr.minW[c.key] = c.minWidth or (c.letters and (#UI.EXCL * 22) or (c.small and 30 or MIN_COL_W))
        hr.colByKey[c.key] = c
        local sw = saved and tonumber(saved[c.key])
        hr.w[c.key] = (sw and not c.fill) and math.max(hr.minW[c.key], sw) or c.width
        if c.fill then hr.fillKey = c.key end
    end

    for _, c in ipairs(cols) do
        local h = UI.CreateHeader(parent, c.letters and "" or c.text, hr.w[c.key])
        if c.small then
            -- two-line gold label (the block metrics columns)
            h:SetNormalFontObject("GameFontNormalSmall")
            local fs = h:GetFontString()
            if fs then
                fs:ClearAllPoints(); fs:SetPoint("LEFT", 1, 0); fs:SetPoint("RIGHT", -7, 0)
                fs:SetJustifyH("CENTER"); fs:SetWordWrap(true)
            end
        end
        hr.byKey[c.key] = h
        hr.headers[#hr.headers + 1] = h
        if c.letters then
            UI.AddLetters(hr, h, c, onSort)
        elseif c.sort ~= false and onSort then
            UI.AddSortArrow(h, c.small)
            if c.small then h.sortArrow:SetPoint("RIGHT", -1, 0) end
            hr.sortables[c.key] = h
            h:SetScript("OnClick", function() onSort(c.key) end)
            h:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine("Sort by " .. (c.tipName or c.text or c.key), 1, 1, 1)
                if c.tip then GameTooltip:AddLine(c.tip, 0.8, 0.8, 0.8, true) end
                GameTooltip:AddLine("Click again to reverse the order. Drag the column's right edge to resize it.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            h:SetScript("OnLeave", hideTip)
        elseif c.tip then
            h:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(c.tipName or c.text or "", 1, 1, 1)
                GameTooltip:AddLine(c.tip, 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            h:SetScript("OnLeave", hideTip)
        end
        if not c.fill then UI.AddResizeHandle(hr, h, c) end
    end

    -- recompute offsets, move the headers and everything tracked
    function hr:Layout()
        if self.fillKey and self.avail then
            local fixed = 0
            for _, c in ipairs(self.cols) do if c.key ~= self.fillKey then fixed = fixed + self.w[c.key] end end
            self.w[self.fillKey] = math.max(self.minW[self.fillKey], self.avail - fixed)
        end
        local cx = 0
        for _, c in ipairs(self.cols) do
            local h = self.byKey[c.key]
            self.x[c.key] = cx
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x0 + cx, self.y0)
            UI.SetHeaderWidth(h, self.w[c.key])
            if h.letterButtons then
                for i, lb in ipairs(h.letterButtons) do
                    lb:ClearAllPoints()
                    lb:SetPoint("CENTER", h, "LEFT", UI.SlotX(0, self.w[c.key], UI.EXCL_STEP, i), 0)
                end
            end
            cx = cx + self.w[c.key]
        end
        self.total = cx
        for _, t in ipairs(self.trackers) do
            local ok = pcall(t.fn, self.x[t.key] or 0, self.w[t.key] or 0)
            if not ok then t.dead = true end
        end
        if self.onLayout then pcall(self.onLayout, self) end
    end

    -- placer(x, w) is called now and after every width change
    function hr:Track(key, placer)
        self.trackers[#self.trackers + 1] = { key = key, fn = placer }
        placer(self.x[key] or 0, self.w[key] or 0)
    end

    function hr:SetColumnWidth(key, width, noSave)
        if not self.w[key] then return end
        -- dragging never pushes the table past the width it has to show in
        if self.avail and key ~= self.fillKey then
            local others = 0
            for _, c in ipairs(self.cols) do
                if c.key ~= key then
                    others = others + ((c.key == self.fillKey) and self.minW[c.key] or self.w[c.key])
                end
            end
            width = math.min(width, math.max(self.minW[key] or MIN_COL_W, self.avail - others))
        end
        self.w[key] = math.max(self.minW[key] or MIN_COL_W, math.floor(width + 0.5))
        if not noSave then
            local sv = savedWidths(self.id)
            if sv then sv[key] = (self.w[key] ~= self.def[key]) and self.w[key] or nil end
        end
        self:Layout()
    end

    function hr:ResetColumn(key)
        local sv = savedWidths(self.id)
        if sv then sv[key] = nil end
        self.w[key] = self.def[key]
        self:Layout()
    end

    -- the width the table has to show in (e.g. the panel width): the fill
    -- column takes what is left, and dragging is limited to it
    function hr:SetAvailableWidth(w)
        if not w or w <= 0 then return end
        self.avail = w
        self:Layout()
    end

    function hr:SetSort(key, asc)
        for k, h in pairs(self.sortables) do setArrow(h.sortArrow, k == key, asc) end
    end
    function hr:SetShown(on)
        for _, h in ipairs(self.headers) do h:SetShown(on) end
    end
    -- kept for older callers: sets a width without saving it
    function hr:SetWidth(key, width)
        if self.w[key] then self:SetColumnWidth(key, width, true) end
    end

    hr:Layout()
    return hr
end

-- Drag grip on the right edge of a column header.
function UI.AddResizeHandle(hr, h, c)
    local grip = CreateFrame("Button", nil, h)
    grip:SetWidth(8)
    grip:SetPoint("TOP", h, "TOPRIGHT", -1, 0)
    grip:SetPoint("BOTTOM", h, "BOTTOMRIGHT", -1, 0)
    grip:SetFrameLevel(h:GetFrameLevel() + 5)
    grip:RegisterForClicks("RightButtonUp")
    local tex = grip:CreateTexture(nil, "HIGHLIGHT")
    tex:SetColorTexture(1, 0.82, 0, 0.45)
    tex:SetPoint("TOP", 0, -3); tex:SetPoint("BOTTOM", 0, 3); tex:SetWidth(2)
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.startX = cursorX(self)
        self.startW = hr.w[c.key]
        self:SetScript("OnUpdate", function(s)
            local dx = cursorX(s) - s.startX
            hr:SetColumnWidth(c.key, s.startW + dx, true)
        end)
    end)
    grip:SetScript("OnMouseUp", function(self, button)
        if self:GetScript("OnUpdate") then
            self:SetScript("OnUpdate", nil)
            hr:SetColumnWidth(c.key, hr.w[c.key])     -- save
        end
    end)
    grip:SetScript("OnHide", function(self)
        if self:GetScript("OnUpdate") then
            self:SetScript("OnUpdate", nil)
            hr:SetColumnWidth(c.key, hr.w[c.key])
        end
    end)
    grip:SetScript("OnClick", function(self, button)
        if button == "RightButton" then hr:ResetColumn(c.key) end
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Resize " .. tostring(c.tipName or (c.letters and (c.lettersTitle or "column")) or c.text or c.key), 1, 1, 1)
        GameTooltip:AddLine("Drag to change the width. Right-click to reset.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", hideTip)
    h.resizeGrip = grip
    return grip
end

-- The W I G P C header: a blank tab with one gold letter button per slot.
function UI.AddLetters(hr, h, c, onSort)
    local step = UI.EXCL_STEP
    local function tip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(c.lettersTitle or "Exclusions", 1, 1, 1)
        if c.lettersNote then GameTooltip:AddLine(c.lettersNote, 0.8, 0.8, 0.8, true) end
        for _, e in ipairs(UI.EXCL) do
            local hl = (self.cat == e.cat) and "|cffffd100" or "|cffffffff"
            GameTooltip:AddLine(hl .. e.letter .. "|r = " .. e.label, 1, 1, 1, true)
        end
        if self.cat and onSort then GameTooltip:AddLine("Click to sort by this column; click again to reverse.", 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end
    h:SetScript("OnEnter", tip)
    h:SetScript("OnLeave", hideTip)
    h.letterButtons = {}
    for i, e in ipairs(UI.EXCL) do
        local b = CreateFrame("Button", nil, h)
        b:SetSize(26, 20)
        b:SetPoint("CENTER", h, "LEFT", UI.SlotX(0, hr.w[c.key] or c.width, step, i), 0)
        b:SetHighlightTexture(UI.HIGHLIGHT, "ADD")
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("CENTER", -3, 0)
        t:SetText(e.letter)
        local a = UI.AddSortArrow(b, true)
        a:SetPoint("LEFT", t, "RIGHT", 2, 0)
        b.cat = e.cat
        local key = c.key .. ":" .. e.cat
        hr.sortables[key] = b
        if onSort then b:SetScript("OnClick", function() onSort(key) end) end
        b:SetScript("OnEnter", tip)
        b:SetScript("OnLeave", hideTip)
        h.letterButtons[i] = b
    end
end

------------------------------------------------------------------------
-- Column-tracked row parts (follow the column when it is resized)
------------------------------------------------------------------------
-- Text cell. xOffset: where the row starts relative to the header row.
function UI.TCell(row, hr, key, justify, font, xOffset)
    local fs = row:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    hr:Track(key, function(x, w)
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row, "LEFT", (xOffset or 0) + x + 6, 0)
        fs:SetWidth(math.max(4, w - 10))
    end)
    return fs
end

-- An existing font string (e.g. a list button's built-in name).
function UI.TPlace(fs, row, hr, key, xOffset)
    hr:Track(key, function(x, w)
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row, "LEFT", (xOffset or 0) + x + 6, 0)
        fs:SetWidth(math.max(4, w - 10))
    end)
end

function UI.TRowButton(row, hr, key, text)
    local b = UI.RowButton(row, text, 40)
    hr:Track(key, function(x, w)
        b:ClearAllPoints()
        b:SetPoint("LEFT", row, "LEFT", x + 4, 0)
        b:SetWidth(math.max(16, w - 8))
    end)
    return b
end

function UI.TRowEditBox(row, hr, key, maxLetters)
    local e = UI.RowEditBox(row, 0, 40, maxLetters)
    hr:Track(key, function(x, w)
        e:ClearAllPoints()
        e:SetPoint("LEFT", row, "LEFT", x + 9, 0)
        e:SetWidth(math.max(20, w - 14))
    end)
    return e
end

-- Keep a widget centred in a column.
function UI.TCenter(widget, row, hr, key)
    hr:Track(key, function(x, w)
        widget:ClearAllPoints()
        widget:SetPoint("CENTER", row, "LEFT", x + w / 2, 0)
    end)
end

------------------------------------------------------------------------
-- W I G P C tickboxes in a row
------------------------------------------------------------------------
-- colX: the column's offset in the row (hr.x[key]); width: column width.
-- Pass a header row instead of colX (and the column key as width) to have the
-- boxes follow the column when it is resized: CreateExclusionBoxes(row, hr, "excl", ...)
-- onClick(box, cat, mouseButton); tooltip(box, entry) optional.
function UI.CreateExclusionBoxes(row, colX, width, onClick, tooltip)
    local boxes = {}
    local hr, key = nil, nil
    if type(colX) == "table" then hr, key = colX, width end
    for i, e in ipairs(UI.EXCL) do
        local c = UI.Check(row)
        if hr then
            hr:Track(key, function(x, w)
                c:ClearAllPoints()
                c:SetPoint("CENTER", row, "LEFT", UI.SlotX(x, w, UI.EXCL_STEP, i), 0)
            end)
        else
            c:SetPoint("CENTER", row, "LEFT", UI.SlotX(colX, width or UI.EXCL_W, UI.EXCL_STEP, i), 0)
        end
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        c.cat, c.entry = e.cat, e
        c:SetScript("OnClick", function(self, button) if onClick then onClick(self, e.cat, button) end end)
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if tooltip then
                tooltip(self, e)
            else
                GameTooltip:AddLine(e.letter .. " - " .. e.label, 1, 1, 1, true)
                GameTooltip:AddLine(self:GetChecked() and "|cff00ff00Allowed|r" or "|cffff5555Blocked|r", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", hideTip)
        boxes[e.cat] = c
    end
    return boxes
end

------------------------------------------------------------------------
-- Block metrics: the per-type blocked counts, shown the same way wherever a
-- player or guild is reported on - one column per type with a two-line
-- gold label, counts in the type's colour, zero in grey.
------------------------------------------------------------------------
UI.METRIC_W = 46
UI.METRICS = {
    { cat = "whisper",     text = "Whispers",       name = "Whispers" },
    { cat = "partyInvite", text = "Party\nInvites", name = "Party Invites" },
    { cat = "partyRaid",   text = "Party/\nRaid",   name = "Party/Raid" },
    { cat = "world",       text = "World\nChat",    name = "World Chat" },
    { cat = "guildInvite", text = "Guild\nInvites", name = "Guild Invites" },
}

-- Column definitions for a header row (keys "metric:<cat>").
function UI.MetricColumns(sortable)
    local cols = {}
    for _, m in ipairs(UI.METRICS) do
        cols[#cols + 1] = { key = "metric:" .. m.cat, text = m.text, width = UI.METRIC_W, small = true,
            sort = sortable ~= false, tipName = m.name .. " blocked",
            tip = "How many " .. m.name:lower() .. " have been blocked." }
    end
    return cols
end

-- Count cells in a row, under the metric columns of header row hr.
function UI.CreateMetricCells(row, hr, xOffset)
    local cells = {}
    for _, m in ipairs(UI.METRICS) do
        local key = "metric:" .. m.cat
        cells[m.cat] = UI.TCell(row, hr, key, "CENTER", nil, xOffset)
    end
    return cells
end

function UI.SetMetricCells(cells, counts)
    local color = M.PSS_History and M.PSS_History.CAT_COLOR or {}
    counts = counts or {}
    for _, m in ipairs(UI.METRICS) do
        local n = tonumber(counts[m.cat]) or 0
        cells[m.cat]:SetText(n > 0 and ("|c" .. (color[m.cat] or "ffffffff") .. n .. "|r") or "|cff6060600|r")
    end
end

-- A one-row metrics table (header + values), for windows that report on
-- one player or guild. :Set(counts) fills it. Anchor it with :SetPoint.
function UI.CreateMetricsTable(parent)
    local t = CreateFrame("Frame", nil, parent)
    local cols = UI.MetricColumns(false)
    cols[#cols + 1] = { key = "total", text = "Total", width = 50, small = true, sort = false,
        tipName = "Total blocked", tip = "Every blocked message and invite." }
    t.hr = UI.CreateHeaderRow(t, cols, 0, 0, nil, { id = "metricsTable", onLayout = function(hr)
        t:SetWidth(hr.total)
        if t.valueRow then t.valueRow:SetWidth(hr.total) end
    end })
    t:SetSize(t.hr.total, UI.HEADER_H + UI.ROW_H)
    local row = CreateFrame("Frame", nil, t)
    row:SetPoint("TOPLEFT", 0, -UI.HEADER_H)
    row:SetSize(t.hr.total, UI.ROW_H)
    t.valueRow = row
    t.cells = UI.CreateMetricCells(row, t.hr)
    t.totalCell = UI.TCell(row, t.hr, "total", "CENTER")
    function t:Set(counts)
        UI.SetMetricCells(self.cells, counts)
        local n = tonumber(counts and counts.total) or 0
        self.totalCell:SetText(n > 0 and ("|cffffffff" .. n .. "|r") or "|cff6060600|r")
    end
    return t
end

------------------------------------------------------------------------
-- Windows
------------------------------------------------------------------------
-- Title text + portrait on a PortraitFrameTemplate frame (main window too).
function UI.DecorateWindow(f, titleText)
    local name = f:GetName() or ""
    f.title = _G[name .. "TitleText"]
        or (f.TitleContainer and f.TitleContainer.TitleText)
        or f.TitleText
    if not f.title then
        f.title = f:CreateFontString(name ~= "" and (name .. "TitleText") or nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", f, "TOP", 0, -8)
    end
    f.title:SetText(titleText or "")
    local icon = f:CreateTexture(nil, "OVERLAY", nil, -8)
    icon:SetSize(60, 60)
    icon:SetPoint("TOPLEFT", -5, 7)
    icon:SetTexture(UI.PORTRAIT)
    f.portraitIcon = icon
    -- drag anywhere on the frame (same as the main window)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetScript("OnMouseDown", function(self) self:StartMoving(); self.isMoving = true end)
    f:SetScript("OnMouseUp", function(self)
        if self.isMoving then self:StopMovingOrSizing(); self.isMoving = false end
    end)
end

-- A popup window that looks like the main window.
-- opts: strata, minW, minH, saveKey, onResize, insetTop (default 60)
-- Returns the frame; frame.inset is the panel to build in (the bottom
-- button bar sits under it, exactly like the main window's tabs).
function UI.CreateWindow(name, titleText, w, h, opts)
    opts = opts or {}
    local f
    local ok, fr = pcall(CreateFrame, "Frame", name, UIParent, "PortraitFrameTemplate")
    if ok and fr then
        f = fr
    else
        f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    end
    f:Hide()
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f:SetFrameStrata(opts.strata or "DIALOG")
    f:SetToplevel(true)
    UI.DecorateWindow(f, titleText)
    if name then tinsert(UISpecialFrames, name) end
    -- make sure there is a close button whatever the template provided
    if not (f.CloseButton or (name and _G[name .. "CloseButton"])) then
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end

    local inset = CreateFrame("Frame", name and (name .. "Inset") or nil, f, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(opts.insetTop or 60))
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 29)
    f.inset = inset

    if M.PSS_MakeResizable then
        M.PSS_MakeResizable(f, { minW = opts.minW or w, minH = opts.minH or 300, saveKey = opts.saveKey, onResize = opts.onResize })
    end
    return f
end

-- Tooltip for a W I G P C legend (used where letters appear without boxes).
function UI.ExclusionLegend(title, note)
    GameTooltip:AddLine(title or "Exclusions", 1, 1, 1)
    if note then GameTooltip:AddLine(note, 0.8, 0.8, 0.8, true) end
    for _, e in ipairs(UI.EXCL) do GameTooltip:AddLine(e.letter .. " = " .. e.label, 1, 1, 1, true) end
end

------------------------------------------------------------------------
-- Grey hint text inside an edit box ("Add a Guild..."), shown while the
-- box is empty and not being typed in.
------------------------------------------------------------------------
function UI.BoxHint(box, text)
	local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", box, "LEFT", 6, 0)
	hint:SetText(text or "")

	local function update()
		hint:SetShown(box:GetText() == "" and not box:HasFocus())
	end
	box:HookScript("OnTextChanged", update)
	box:HookScript("OnEditFocusGained", update)
	box:HookScript("OnEditFocusLost", update)
	box.hint = hint
	return hint
end

------------------------------------------------------------------------
-- Prompt: a question with up to three buttons, drawn with the game's own
-- dialog art (the StaticPopup box, border, font, buttons and sounds).
--
--   UI.Prompt({
--   	text    = "Add <Name> without searching?",
--   	buttons = {                                   -- left to right
--   		{ text = OKAY,   onClick = function() ... end },
--   		{ text = SEARCH, onClick = function() ... end },
--   		{ text = CANCEL },                        -- no onClick: just closes
--   	},
--   })
--
-- One prompt is shown at a time; a new one replaces the last. Escape and
-- the close button act like a button with no onClick. Each onClick runs
-- straight from the click, so it may send a /who.
------------------------------------------------------------------------
local PROMPT_BUTTON_W, PROMPT_BUTTON_H, PROMPT_BUTTON_GAP = 128, 21, 8
local PROMPT_WIDTH = 420

local DIALOG_BACKDROP = BACKDROP_DIALOG_32_32 or {
	bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile     = true, tileSize = 32, edgeSize = 32,
	insets   = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function promptSound(kit)
	if PlaySound and SOUNDKIT and SOUNDKIT[kit] then PlaySound(SOUNDKIT[kit]) end
end

local function buildPrompt()
	if UI.promptFrame then return UI.promptFrame end

	local f = CreateFrame("Frame", "PSSPromptDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:Hide()
	f:SetWidth(PROMPT_WIDTH)
	f:SetPoint("TOP", UIParent, "TOP", 0, -135)   -- where StaticPopup1 sits
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	if f.SetBackdrop then f:SetBackdrop(DIALOG_BACKDROP) end
	tinsert(UISpecialFrames, "PSSPromptDialog")   -- Escape closes it

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -3, -3)
	close:SetScript("OnClick", function() f:Hide() end)

	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	f.text:SetPoint("TOP", f, "TOP", 0, -16)
	f.text:SetWidth(PROMPT_WIDTH - 60)
	f.text:SetJustifyH("CENTER")

	f.buttons = {}
	for i = 1, 3 do
		local b = CreateFrame("Button", "PSSPromptDialogButton" .. i, f, "UIPanelButtonTemplate")
		b:SetSize(PROMPT_BUTTON_W, PROMPT_BUTTON_H)
		b:SetScript("OnClick", function(self)
			local onClick = self.onClick
			f:Hide()
			if onClick then onClick() end
		end)
		f.buttons[i] = b
	end

	f:SetScript("OnShow", function() promptSound("IG_MAINMENU_OPEN") end)
	f:SetScript("OnHide", function() promptSound("IG_MAINMENU_CLOSE") end)

	UI.promptFrame = f
	return f
end

function UI.Prompt(opts)
	local f = buildPrompt()
	local list = opts.buttons or { { text = OKAY or "Okay" } }
	local count = math.min(#list, #f.buttons)

	f.text:SetText(opts.text or "")

	-- buttons centred in one row, in the order given
	local rowWidth = count * PROMPT_BUTTON_W + (count - 1) * PROMPT_BUTTON_GAP
	f:SetWidth(math.max(PROMPT_WIDTH, rowWidth + 40))
	for i, b in ipairs(f.buttons) do
		local spec = list[i]
		if i <= count and spec then
			b:SetText(spec.text or "")
			b.onClick = spec.onClick
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", f, "BOTTOM",
				-rowWidth / 2 + (i - 1) * (PROMPT_BUTTON_W + PROMPT_BUTTON_GAP), 16)
			b:Show()
		else
			b.onClick = nil
			b:Hide()
		end
	end

	-- text + gap + buttons + padding
	f:SetHeight(16 + (f.text:GetStringHeight() or 14) + 20 + PROMPT_BUTTON_H + 16)
	if f:IsShown() then f:Hide() end
	f:Show()
	f:Raise()
	return f
end

local function chatNote(msg)
	if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("PSS: " .. msg) end
end

------------------------------------------------------------------------
-- PromptAdd: "Add <Name> to the <list> without searching?"
--   [Okay] adds it, [Search] searches for it instead, [Cancel] closes.
--
--   UI.PromptAdd(name, {
--   	listName = "Player Ignore List",
--   	add      = function(name) ... end,
--   	search   = function(name) return sentOk end,  -- runs from the click
--   	canSend  = function() return true end,        -- optional, e.g. /who cooldown
--   	onDone   = function() ... end,                -- optional: after Okay / a sent search
--   })
------------------------------------------------------------------------
function UI.PromptAdd(name, opts)
	return UI.Prompt({
		text = ("Add |cffffd100<%s>|r to the %s without searching?"):format(name, opts.listName),
		buttons = {
			{
				text = OKAY or "Okay",
				onClick = function()
					opts.add(name)
					chatNote(("<%s> added to the %s."):format(name, opts.listName))
					if opts.onDone then opts.onDone() end
				end,
			},
			{
				text = SEARCH or "Search",
				onClick = function()
					if opts.canSend and not opts.canSend() then return end
					if opts.search(name) and opts.onDone then opts.onDone() end
				end,
			},
			{ text = CANCEL or "Cancel" },
		},
	})
end

-- "Nothing was found: add it anyway?"  [Add Anyway] [Cancel]
--   UI.PromptAddAnyway(name, { what = "guild", listName =, add = function(name) end })
function UI.PromptAddAnyway(name, opts)
	return UI.Prompt({
		text = ("No %s named |cffffd100<%s>|r was found online.\n\nAdd it to the %s anyway?"):format(
			opts.what or "match", name, opts.listName),
		buttons = {
			{
				text = "Add Anyway",
				onClick = function()
					opts.add(name)
					chatNote(("<%s> added to the %s."):format(name, opts.listName))
				end,
			},
			{ text = CANCEL or "Cancel" },
		},
	})
end

------------------------------------------------------------------------
-- EntryRow: [box] [Search button] [Add button], top right of a panel, or
-- directly beneath another EntryRow (opts.below).
--
--   UI.EntryRow(panel, {
--   	searchText = "Guild Search",   addText = "Add Guild",
--   	hint       = "Add a Guild...", listName = "Guild Ignore List",
--   	emptyMsg   = "chat line when a button is pressed with an empty box",
--   	searchTip  = { "first line", "grey lines ..." },
--   	addTip     = "Add button tooltip text",          -- optional
--   	isListed   = function(text) return bool end,
--   	add        = function(text) end,
--   	search     = function(text) return sentOk end,   -- runs from the click
--   	canSend    = function() return true end,         -- optional
--   	onEmptyAdd = function() return handled end,      -- optional: Add with an empty box
--   	clearOnSearch = true,                            -- optional
--   	below      = otherRow,                           -- optional
--   	names      = { box =, search =, add = },         -- optional global frame names
--   })
-- Returns { box =, search =, add = }.
------------------------------------------------------------------------
function UI.EntryRow(panel, opts)
	local row = {}
	local names = opts.names or {}

	-- buttons right to left: Add, then Search, then the box
	row.add = UI.TopButton(panel, opts.addText, nil, nil, names.add)
	row.search = UI.TopButton(panel, opts.searchText, row.add, nil, names.search)
	if opts.below then
		row.add:ClearAllPoints()
		row.add:SetPoint("TOPLEFT", opts.below.add, "BOTTOMLEFT", 0, -4)
	end

	row.box = UI.SearchBox(panel, row.search, 150, names.box)
	UI.BoxHint(row.box, opts.hint)

	local function boxText()
		local text = (row.box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then return nil end
		return text
	end

	local function doSearch()
		if opts.canSend and not opts.canSend() then return end
		local text = boxText()
		if not text then
			chatNote(opts.emptyMsg)
			return
		end
		if opts.search(text) and opts.clearOnSearch then row.box:SetText("") end
	end

	local function doAdd()
		local text = boxText()
		if not text then
			if not (opts.onEmptyAdd and opts.onEmptyAdd()) then chatNote(opts.emptyMsg) end
			return
		end
		if opts.isListed(text) then
			chatNote(("<%s> is already on the %s."):format(text, opts.listName))
			return
		end
		UI.PromptAdd(text, {
			listName = opts.listName,
			add      = opts.add,
			search   = opts.search,
			canSend  = opts.canSend,
			onDone   = function() row.box:SetText("") end,
		})
	end

	row.search:SetScript("OnClick", doSearch)
	row.box:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
		doSearch()
	end)
	row.add:SetScript("OnClick", doAdd)

	row.search:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(opts.searchText .. " - " .. opts.listName, 1, 1, 1)
		for i, line in ipairs(opts.searchTip or {}) do
			if i == 1 then
				GameTooltip:AddLine(line, nil, nil, nil, true)
			else
				GameTooltip:AddLine(line, 0.7, 0.7, 0.7, true)
			end
		end
		GameTooltip:Show()
	end)
	row.add:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(opts.addText .. " - " .. opts.listName, 1, 1, 1)
		GameTooltip:AddLine(opts.addTip or ("Adds the name typed in the box. You are asked first: Okay adds it without searching, Search runs "
			.. opts.searchText .. " for it instead."), nil, nil, nil, true)
		GameTooltip:Show()
	end)
	row.search:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.add:SetScript("OnLeave", function() GameTooltip:Hide() end)

	return row
end

------------------------------------------------------------------------
-- Picker: a results window with a tick column, then text columns.
-- Ticked rows are handed to onSave when Save is pressed. One window per
-- `name`; its columns are fixed the first time it is built.
--
--   UI.Picker({
--   	name     = "PSSPlayerSearchFrame",       -- global frame name
--   	title    = "Player Search Results",
--   	subtitle = "3 player(s) found for \"Bob\".",
--   	columns  = { { key = "name", text = "Name", width = 160 }, ... },  -- last one fills
--   	items    = { { cells = { name = "Bob-Realm", ... }, value = "Bob-Realm", listed = false }, ... },
--   	onSave   = function(values) end,          -- values of the ticked rows, in order
--   	onHide   = function() end,                -- optional
--   })
-- Listed items are shown unticked and greyed "(already in list)".
------------------------------------------------------------------------
UI.pickers = {}

local function buildPicker(opts)
	local f = UI.CreateWindow(opts.name, opts.title or "", 420, 440,
		{ strata = "DIALOG", minW = 380, minH = 300, saveKey = opts.saveKey or opts.name })
	local inset = f.inset
	f.heading, f.subtitle = UI.CreateSummary(inset, "Tick the entries to add.", 380)

	local cols = { { key = "add", text = "Add", width = 44, sort = false, tip = "Ticked entries are added when you press Save." } }
	for i, c in ipairs(opts.columns) do
		cols[#cols + 1] = {
			key = c.key, text = c.text, width = c.width or 120, sort = false,
			fill = (i == #opts.columns), minWidth = c.minWidth or 80,
		}
	end
	f.columns = opts.columns
	f.hr = UI.CreateHeaderRow(inset, cols, 1, UI.HEADER_Y, nil, {
		id = opts.saveKey or opts.name,
		onLayout = function(h)
			if f.content then f.content:SetWidth(math.max(f.scroll and f.scroll:GetWidth() or 0, h.total)) end
			for _, r in ipairs(f.rows or {}) do r:SetWidth(h.total) end
		end,
	})

	local scroll = CreateFrame("ScrollFrame", opts.name .. "Scroll", inset, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 1, -UI.LIST_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -27, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(f.hr.total, 1)
	scroll:SetScrollChild(content)
	f.content, f.scroll, f.rows = content, scroll, {}

	-- bottom bar: Cancel (right), Save
	local cancel = UI.BarButton(inset, CANCEL or "Cancel")
	cancel:SetScript("OnClick", function() f:Hide() end)
	local save = UI.BarButton(inset, "Save", cancel)
	save:SetScript("OnClick", function()
		local values = {}
		for _, r in ipairs(f.rows) do
			if r:IsShown() and r.check:IsEnabled() and r.check:GetChecked() then
				values[#values + 1] = r.value
			end
		end
		local onSave = f.onSave
		f:Hide()
		if onSave then onSave(values) end
	end)
	f.cancel, f.save = cancel, save
	f:HookScript("OnHide", function()
		if f.onHide then f.onHide() end
	end)

	-- the last column follows the window width
	local function fit()
		local w = scroll:GetWidth() or 0
		if w <= 0 then return end
		f.hr:SetAvailableWidth(w)
		content:SetWidth(math.max(w, f.hr.total))
	end
	f.fitList = fit
	scroll:HookScript("OnSizeChanged", fit)

	UI.pickers[opts.name] = f
	return f
end

local function pickerRow(f, i)
	local r = f.rows[i]
	if r then return r end
	r = UI.CreateRow(f.content, f.hr.total)
	r.check = UI.Check(r)
	UI.TCenter(r.check, r, f.hr, "add")
	r.cells = {}
	for _, c in ipairs(f.columns) do r.cells[c.key] = UI.TCell(r, f.hr, c.key) end
	r:SetScript("OnClick", function(self)
		if self.check:IsEnabled() then self.check:SetChecked(not self.check:GetChecked()) end
	end)
	f.rows[i] = r
	return r
end

function UI.Picker(opts)
	local f = UI.pickers[opts.name] or buildPicker(opts)
	if f.title then f.title:SetText(opts.title or "") end
	f.subtitle:SetText(opts.subtitle or "")
	f.onSave, f.onHide = opts.onSave, opts.onHide

	for _, r in ipairs(f.rows) do r:Hide() end
	local items = opts.items or {}
	for i, item in ipairs(items) do
		local r = pickerRow(f, i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * UI.ROW_H)
		r.value = item.value

		for n, c in ipairs(f.columns) do
			local text = tostring((item.cells or {})[c.key] or "")
			if n == 1 and item.listed then text = text .. " |cff999999(already in list)|r" end
			r.cells[c.key]:SetText(text)
		end
		if item.listed then
			r.check:SetChecked(false)
			r.check:Disable()
		else
			r.check:Enable()
			r.check:SetChecked(true)
		end
		r:Show()
	end

	if f.fitList then f.fitList() end
	f.content:SetHeight(math.max(1, #items * UI.ROW_H + 4))
	f:Show()
	f:Raise()
	return f
end
