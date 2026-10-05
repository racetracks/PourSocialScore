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
local addon = PourSocialScore_NS
local M = addon.M
local V = addon.V
local L = addon.L

local UI = {}
M.UI = UI

UI.HEADER_H		= 24
UI.ROW_H		= 20
UI.CHECK		= 20
UI.ROW_BUTTON_H = 18
UI.BAR_W, UI.BAR_H = 110, 22
UI.TOP_W		= 100
UI.LIST_TOP		= 86			-- panel top -> first row (summary + header)
UI.HEADER_Y		= -(86 - 24)	-- panel top -> header row
-- Player Ignore List and Chat Filters: the block counts sit above the panel
-- (UI.CreateBlockStats), so their headers go straight under the top buttons
UI.COMPACT_LIST_TOP = 54
UI.COMPACT_HEADER_Y = -(54 - 24)
UI.EXCL_W		= 154			-- W I G P C column
UI.EXCL_STEP	= 28
UI.HIGHLIGHT	= "Interface\\QuestFrame\\UI-QuestTitleHighlight"
UI.SORT_ARROW	= "Interface\\Buttons\\UI-SortArrow"
UI.PORTRAIT		= "Interface\\FriendsFrame\\Battlenet-Portrait"	-- also the addon-list icon (## IconTexture in the 3 TOCs)

-- W I G P C: the order, letters and wording used everywhere. "field" is the
-- matching switch on a Player Ignore List record.
--
-- TICKED = ALLOWED. The core (records, guild rules, the chat block sources)
-- stores and decides in "blocked" terms (whispersBlocked, g.block[cat],
-- m.block[cat]); every W I G P C tickbox shows the inverse: ticked = that
-- feature is allowed through, unticked = blocked. Always go through
-- UI.ExclChecked / UI.ExclBlocked so no frame gets this backwards.
UI.EXCL = M.EXCL			-- the five categories (PSS_Globals.lua)
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

-- Block counts in the strip at the top of the main window, right of the
-- portrait: one line each for this session, the last 24 hours and the total,
-- with the per-type counts in fixed columns so the three lines line up.
-- Parented to the tab panel (shown with it), anchored to the window.
--   cats = { { key =, label =, color = "ffrrggbb", width = }, ... }
--   unit = "messages and invites"
-- :Set(row, counts) fills one line (row 1-3); counts = { total =, [key] = }.
UI.STATS_ROWS = { "This session:", "Last 24 hours:", "Total:" }
UI.STATS_X, UI.STATS_Y, UI.STATS_ROW_H = 62, -28, 16
-- Player and Guild Ignore Lists (same order and colours as the summary line
-- they replace), and the Chat Filters' own two.
UI.STATS_BLOCK_CATS = {
	{ key = "whisper",		label = "Whispers",			color = "ffffff00", width = 86 },
	{ key = "partyInvite", label = "Party Invites", color = "ffff9933", width = 108 },
	{ key = "partyRaid",	label = "Party/Raid",		color = "ff66ccff", width = 92 },
	{ key = "world",		label = "World Chat",		color = "ff99ff99", width = 112 },
	{ key = "guildInvite", label = "Guild Invites", color = "ffcc99ff", width = 110 },
}
UI.STATS_FILTER_CATS = {
	{ key = "whisper", label = "Whispers",			color = "ffffff00", width = 86 },
	{ key = "private", label = "Private messages", color = "ff00ccff", width = 140 },
}

function UI.CreateBlockStats(panel, window, cats, unit)
	local s = { rows = {} }
	for i, label in ipairs(UI.STATS_ROWS) do
		local y = UI.STATS_Y - (i - 1) * UI.STATS_ROW_H
		local r = { cats = {} }
		r.label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		r.label:SetPoint("TOPLEFT", window, "TOPLEFT", UI.STATS_X, y)
		r.label:SetWidth(105)
		r.label:SetJustifyH("LEFT")
		r.label:SetText(label)
		r.total = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		r.total:SetPoint("LEFT", r.label, "RIGHT", 0, 0)
		r.total:SetWidth(50)
		r.total:SetJustifyH("RIGHT")
		r.unit = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		r.unit:SetPoint("LEFT", r.total, "RIGHT", 5, 0)
		r.unit:SetWidth(175)
		r.unit:SetJustifyH("LEFT")
		r.unit:SetText(unit or "")
		local prev = r.unit
		for j, c in ipairs(cats) do
			local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			fs:SetPoint("LEFT", prev, "RIGHT", 0, 0)
			fs:SetWidth(c.width or 100)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(false)
			r.cats[j] = fs
			prev = fs
		end
		s.rows[i] = r
	end
	function s:Set(row, counts)
		local r = self.rows[row]
		if not r then return end
		counts = counts or {}
		r.total:SetText("|cffffff00" .. (tonumber(counts.total) or 0) .. "|r")
		for j, c in ipairs(cats) do
			local n = counts[c.key]
			r.cats[j]:SetText("|cffaaaaaa" .. c.label .. ":|r |c" .. c.color .. (n == false and "-" or (tonumber(n) or 0)) .. "|r")
		end
	end
	return s
end

-- The three lines of a tab: this session and the last 24 hours as the
-- EllesmereUI window counts them (M.PSS_RecentListStats, in
-- PourSocialScore_Libraries), then the tab's own totals. kind: "players",
-- "guilds" or "filters". A Battle.net whisper counts as a whisper in the
-- first two lines, so their Private messages read "-".
local recentSession, recentDay = {}, {}
function UI.SetBlockStats(stats, kind, total)
	if not stats then return end
	M.PSS_RecentListStats(kind, recentSession, recentDay)
	if kind == "filters" then recentSession.private, recentDay.private = false, false end
	stats:Set(1, recentSession)
	stats:Set(2, recentDay)
	stats:Set(3, total)
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

-- Free-standing edit box. w = nil sets only the height (for boxes anchored
-- left and right); maxLetters = nil keeps the template's limit.
function UI.InputBox(parent, w, h, name, maxLetters)
	local e = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
	if w then e:SetSize(w, h or 20) else e:SetHeight(h or 20) end
	e:SetAutoFocus(false)
	if maxLetters then e:SetMaxLetters(maxLetters) end
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return e
end

-- Small centred box for a number (Options values, expiry days).
function UI.NumberBox(parent, w, h, maxLetters)
	local e = UI.InputBox(parent, w, h, nil, maxLetters)
	e:SetNumeric(true)
	e:SetJustifyH("CENTER")
	return e
end

-- Multi-line text box (InputScrollFrameTemplate): the text keeps wrapping to
-- the box when it is resized (inner box = width - pad), no character count.
function UI.TextArea(parent, name, maxLetters, font, pad)
	local box = CreateFrame("ScrollFrame", name, parent, "InputScrollFrameTemplate")
	box.EditBox:SetAutoFocus(false)
	box.EditBox:SetMaxLetters(maxLetters or 0)
	box.EditBox:SetFontObject(font or "ChatFontNormal")
	box:HookScript("OnSizeChanged", function(self, w)
		if w and w > 40 then self.EditBox:SetWidth(w - (pad or 18)) end
	end)
	if type(box.CharCount) == "table" and box.CharCount.Hide then box.CharCount:Hide() end
	return box
end

-- Scrolling list inside a panel (below the summary and header row). Returns
-- the scroll frame and its content frame (contentW wide).
function UI.ScrollList(parent, name, contentW, contentH)
	local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 1, -UI.LIST_TOP)
	scroll:SetPoint("BOTTOMRIGHT", -27, 4)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(contentW, contentH or 1)
	scroll:SetScrollChild(content)
	return scroll, content
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
			hr:SetColumnWidth(c.key, hr.w[c.key])		-- save
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
	{ cat = "whisper",		text = "Whispers",			name = "Whispers" },
	{ cat = "partyInvite", text = "Party\nInvites", name = "Party Invites" },
	{ cat = "partyRaid",	text = "Party/\nRaid",		name = "Party/Raid" },
	{ cat = "world",		text = "World\nChat",		name = "World Chat" },
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
	UI.RestorePlace(f)
	f:SetScript("OnMouseDown", function(self) self:StartMoving(); self.isMoving = true end)
	f:SetScript("OnMouseUp", function(self)
		if self.isMoving then self:StopMovingOrSizing(); self.isMoving = false; UI.SavePlace(self) end
	end)
end

-- Where a dragged window was left, per window name, in
-- PourSocialScoreDB.windowPoints (PSS_OptionsDB): { point, relativePoint,
-- x, y } against UIParent. Not the game's layout cache: this addon loads on
-- demand, after the game has placed the windows it knows.
local function places()
	local db = PourSocialScoreDB
	if type(db) ~= "table" then return nil end
	db.windowPoints = type(db.windowPoints) == "table" and db.windowPoints or {}
	return db.windowPoints
end

function UI.SavePlace(f)
	local name, store = f:GetName(), places()
	if not name or not store or not f.GetPoint then return end
	local point, _, relPoint, x, y = f:GetPoint(1)
	if not point then return end
	store[name] = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) }
	if f.SetUserPlaced then f:SetUserPlaced(false) end
end

function UI.RestorePlace(f)
	local name = f:GetName()
	local db = PourSocialScoreDB
	local p = name and type(db) == "table" and type(db.windowPoints) == "table" and db.windowPoints[name]
	if type(p) ~= "table" or type(p[1]) ~= "string" then return end
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[2] or p[1], tonumber(p[3]) or 0, tonumber(p[4]) or 0)
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
-- Buttons that send a /who (Scan, Scan All, Guild Search, Player Search)
-- are disabled while the shared /who cooldown runs (PSS_Whois.lua).
------------------------------------------------------------------------
local whoisButtons = setmetatable({}, { __mode = "k" })

function UI.RegisterWhoisButton(button)
	whoisButtons[button] = true
	button:SetEnabled(not M.Whois.CooldownActive())
	return button
end

M.Events.Register("WHOIS_COOLDOWN", function(active)
	for button in pairs(whoisButtons) do
		if button.SetEnabled then button:SetEnabled(not active) end
	end
end)

------------------------------------------------------------------------
-- Resize grip (every resizable window)
------------------------------------------------------------------------
-- Adds a drag grip to the bottom-right corner of a top-level window.
--   Left-drag the grip  : resize the window
--   Right-click the grip: reset the window to its default size
-- The size is remembered per window in PourSocialScoreDB.windowSizes[saveKey].
-- opts = { minW, minH, maxW, maxH, saveKey, onResize = function(frame, w, h) }
function M.PSS_MakeResizable(frame, opts)
	if not frame or frame.PSS_ResizeGrip then return frame and frame.PSS_ResizeGrip end
	opts = opts or {}

	local defW, defH = frame:GetWidth(), frame:GetHeight()
	local screenW = (UIParent and UIParent:GetWidth()) or 1920
	local screenH = (UIParent and UIParent:GetHeight()) or 1080
	local minW = opts.minW or math.min(defW, 300)
	local minH = opts.minH or math.min(defH, 200)
	local maxW = math.max(minW, opts.maxW or screenW)
	local maxH = math.max(minH, opts.maxH or screenH)

	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(minW, minH, maxW, maxH)
	else
		-- older client builds
		if frame.SetMinResize then frame:SetMinResize(minW, minH) end
		if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
	end

	local function clamp(w, h)
		return math.max(minW, math.min(maxW, w)), math.max(minH, math.min(maxH, h))
	end

	local function saved()
		local db = PourSocialScoreDB
		if type(db) ~= "table" or not opts.saveKey then return nil end
		db.windowSizes = type(db.windowSizes) == "table" and db.windowSizes or {}
		return db.windowSizes
	end

	-- Restore a previously saved size.
	local store = saved()
	local s = store and store[opts.saveKey]
	if type(s) == "table" and tonumber(s.w) and tonumber(s.h) then
		frame:SetSize(clamp(tonumber(s.w), tonumber(s.h)))
	end

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", opts.gripX or -4, opts.gripY or 4)
	grip:SetFrameLevel(frame:GetFrameLevel() + 20)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.PSS_ResizeGrip = grip

	local function save()
		local st = saved()
		if st then st[opts.saveKey] = { w = math.floor(frame:GetWidth() + 0.5), h = math.floor(frame:GetHeight() + 0.5) } end
	end

	grip:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		frame.PSS_Sizing = true
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function(self, button)
		if frame.PSS_Sizing then
			frame.PSS_Sizing = nil
			frame:StopMovingOrSizing()
			save()
		elseif button == "RightButton" then
			frame:SetSize(clamp(defW, defH))
			local st = saved()
			if st then st[opts.saveKey] = nil end
		end
	end)
	-- Safety net if the window is hidden mid-drag.
	frame:HookScript("OnHide", function(self)
		if self.PSS_Sizing then
			self.PSS_Sizing = nil
			self:StopMovingOrSizing()
			save()
		end
	end)
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Resize", 1, 1, 1)
		GameTooltip:AddLine("Drag to resize this window.", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-click to reset to the default size.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

	if opts.onResize then
		frame:HookScript("OnSizeChanged", function(self, w, h) opts.onResize(self, w, h) end)
	end
	return grip
end
