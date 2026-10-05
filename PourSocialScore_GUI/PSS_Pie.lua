------------------------------------------------------------------------
-- POUR SOCIAL SCORE - PIE AND LIST TOTALS (3.3)
--
-- The pie chart and the whole-list totals of the EllesmereUI window, drawn
-- with Blizzard parts (copied from our PourSocialScore_EllesmereUI, rule G9;
-- nothing here reads that folder):
--   UI.NewPie(parent, size, onClick)   a ring; pie:Set(slices)
--   UI.NewTotals(parent, kind, title)  a list's blocks this session / last
--                                      24 hours / all time as a pie with a
--                                      tick box and count per period;
--                                      tot:Refresh()
-- The counts come from M.PSS_ListTotals (PourSocialScore_Libraries), the
-- same call the EllesmereUI window makes, so both show the same numbers.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local UI = M.UI

------------------------------------------------------------------------
-- The pie: SEGS short thick lines round a ring, each the colour of the
-- slice its middle falls in. slices: { { value =, r =, g =, b =, text =,
-- draw =, within = }, ... }. Each slice takes its share of the ring (draw,
-- else value, over the sum); draw lets a slice that holds another take
-- only the part the other does not. within = { [index] = true }: the
-- slices it holds, lit with it on hover. Hover dims the others and shows
-- the count in the middle. Nothing to draw: a faint ring.
------------------------------------------------------------------------
local SEGS = 60
local TWO_PI = 2 * math.pi
local atan2 = math.atan2 or atan2

local Pie = {}
Pie.__index = Pie

function Pie:Set(slices)
	self.slices = slices
	local total = 0
	for i = 1, #slices do total = total + (slices[i].draw or slices[i].value or 0) end
	self.total = total
	local seg, acc, at = self.segSlice, 0, 1
	for s = 1, SEGS do seg[s] = 0 end
	if total > 0 then
		-- where each slice ends, 0..1 from the top, clockwise
		for i = 1, #slices do
			local v = slices[i].draw or slices[i].value or 0
			if v > 0 then
				acc = acc + v / total
				while at <= SEGS and (at - 0.5) / SEGS <= acc + 1e-9 do
					seg[at] = i
					at = at + 1
				end
			end
		end
	end
	self.hot = nil
	self:Paint()
end

-- the hovered slice (and the slices it holds) full, the others dimmed
function Pie:Paint()
	local hot, slices = self.hot, self.slices
	local within = hot and slices[hot] and slices[hot].within
	for s = 1, SEGS do
		local i = self.segSlice[s]
		local line = self.segs[s]
		if i == 0 then
			line:SetColorTexture(1, 1, 1, 0.08)
			line:SetDrawLayer("ARTWORK", 0)
		else
			local sl = slices[i]
			local lit = hot == nil or hot == i or (within and within[i])
			line:SetColorTexture(sl.r, sl.g, sl.b, lit and 0.9 or 0.3)
			-- segments overlap a little (no seams): a lit one over a dimmed one
			line:SetDrawLayer("ARTWORK", lit and 2 or 1)
		end
	end
	if hot then
		local sl = slices[hot]
		self.center:SetText(tostring(sl.value or 0))
		self.center:SetTextColor(sl.r, sl.g, sl.b)
	else
		self.center:SetText("")
	end
end

-- the slice under the cursor (nil: not on the ring)
function Pie:SliceAt()
	if not self.total or self.total == 0 then return nil end
	local x, y = GetCursorPosition()
	local sc = self.frame:GetEffectiveScale()
	local cx, cy = self.frame:GetCenter()
	if not (x and cx and sc and sc > 0) then return nil end
	local dx, dy = x / sc - cx, y / sc - cy
	local d = math.sqrt(dx * dx + dy * dy)
	if d < self.inner - 3 or d > self.outer + 3 then return nil end
	local a = atan2(dx, dy)
	if a < 0 then a = a + TWO_PI end
	local i = self.segSlice[math.min(math.floor(a / TWO_PI * SEGS) + 1, SEGS)]
	return i ~= 0 and i or nil
end

local function hover(pie)
	local i = pie:SliceAt()
	if i == pie.hot then return end
	pie.hot = i
	pie:Paint()
	if i and pie.tip then
		GameTooltip:SetOwner(pie.frame, "ANCHOR_RIGHT")
		GameTooltip:SetText(pie.tip(i), 1, 1, 1, 1, true)
		GameTooltip:Show()
	else
		GameTooltip:Hide()
	end
end

-- parent, size (px), onClick(slice index) or nil; pie.tip = function(i) -> text
function UI.NewPie(parent, size, onClick)
	local pie = setmetatable({ segs = {}, segSlice = {}, slices = {}, total = 0 }, Pie)
	local f = CreateFrame("Button", nil, parent)
	f:SetSize(size, size)
	pie.frame = f
	local ring = math.floor(size * 0.24)
	local r = (size - ring) / 2
	pie.inner, pie.outer = r - ring / 2, r + ring / 2
	local over = 0.6 / SEGS * TWO_PI	-- a little overlap: no seams
	for s = 1, SEGS do
		local a0 = (s - 1) / SEGS * TWO_PI - over
		local a1 = s / SEGS * TWO_PI + over
		local line = f:CreateLine(nil, "ARTWORK")
		line:SetThickness(ring)
		line:SetStartPoint("CENTER", f, r * math.sin(a0), r * math.cos(a0))
		line:SetEndPoint("CENTER", f, r * math.sin(a1), r * math.cos(a1))
		pie.segs[s] = line
		pie.segSlice[s] = 0
	end
	pie.center = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	pie.center:SetPoint("CENTER", f, "CENTER", 0, 0)
	f:SetScript("OnEnter", function() f:SetScript("OnUpdate", function() hover(pie) end) end)
	f:SetScript("OnLeave", function()
		f:SetScript("OnUpdate", nil)
		pie.hot = nil
		pie:Paint()
		GameTooltip:Hide()
	end)
	f:SetScript("OnClick", function()
		local i = pie:SliceAt()
		if i and onClick then onClick(i) end
	end)
	pie:Paint()
	return pie
end

------------------------------------------------------------------------
-- The periods. They are nested (the last 24 hours hold this session, all
-- time holds both), so each ticked slice is drawn as only what the smaller
-- ticked ones before it do not hold, and lit with them on hover. The
-- ticks are shared by every tab while the window is loaded; all time
-- starts unticked (it holds the other two and dwarfs them), as in the
-- EllesmereUI window.
------------------------------------------------------------------------
local PERIODS = {
	{ key = "session", text = "This session", r = 0.31, g = 0.76, b = 0.97 },
	{ key = "day", text = "Last 24 hours", r = 1.00, g = 0.72, b = 0.30 },
	{ key = "all", text = "All time", r = 0.58, g = 0.46, b = 0.80 },
}
UI.PERIODS = PERIODS
local periodOn = { session = true, day = true, all = false }

-- v: { session =, day =, all = }; slices: filled; pool: slice tables reused
local function periodSlices(v, slices, pool)
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
			inner = math.max(inner, value)
		end
	end
	return n
end

local function periodTip(title, sl)
	local t = ("%s\n%s: %d blocked"):format(title or "", sl.text, sl.value or 0)
	if sl.innerText and (sl.inner or 0) > 0 then
		t = t .. ("\n|cffaaaaaa%d of them also in %s (lit with it)|r"):format(sl.inner, string.lower(sl.innerText))
	end
	return t
end

------------------------------------------------------------------------
-- A list's totals: the heading, "Blocked N in all." and the period pie
-- with a tick box, colour, name and count per period. Built on the first
-- Refresh while shown; Refresh does nothing while hidden.
------------------------------------------------------------------------
local PIE_SIZE = 84
local totalsShown = {}		-- every totals view, for the shared ticks

local TT = {}
TT.__index = TT

local function tipOn(owner, text)
	owner:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	owner:SetScript("OnLeave", UI.HideTip)
end

local function redrawAll()
	for _, tt in ipairs(totalsShown) do
		for key, c in pairs(tt.boxes) do c:SetChecked(periodOn[key]) end
		tt:Refresh()
	end
end

-- a tick box with its colour, name and count; a click on the name ticks it too
local function newKey(parent, per)
	local c = UI.Check(parent, 18)
	local sq = parent:CreateTexture(nil, "ARTWORK")
	sq:SetSize(10, 10)
	sq:SetPoint("LEFT", c, "RIGHT", 2, 0)
	sq:SetColorTexture(per.r, per.g, per.b, 0.9)
	local t = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	t:SetPoint("LEFT", sq, "RIGHT", 6, 0)
	t:SetText(per.text)
	local n = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	n:SetPoint("LEFT", c, "RIGHT", 116, 0)
	n:SetJustifyH("LEFT")
	n:SetTextColor(per.r, per.g, per.b)
	local function changed()
		periodOn[per.key] = c:GetChecked() and true or false
		redrawAll()
	end
	local hit = CreateFrame("Button", nil, parent)
	hit:SetPoint("TOPLEFT", c, "TOPRIGHT", 0, 0)
	hit:SetPoint("BOTTOMLEFT", c, "BOTTOMRIGHT", 0, 0)
	hit:SetWidth(166)
	hit:SetScript("OnClick", function()
		c:SetChecked(not c:GetChecked())
		changed()
	end)
	c:SetScript("OnClick", changed)
	c:SetChecked(periodOn[per.key])
	local tip = "Shows " .. string.lower(per.text) .. " in the pie."
	tipOn(c, tip)
	tipOn(hit, tip)
	c.count = n
	return c
end

function TT:Build()
	local f = self.frame
	self.pie = UI.NewPie(f, PIE_SIZE, nil)
	self.pie.frame:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -52)
	self.pie.tip = function(i) return periodTip(self.title, self.slices[i]) end
	self.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	self.empty:SetPoint("CENTER", self.pie.frame, "CENTER", 0, 0)
	self.empty:SetText("Nothing yet")
	local y = -60
	for _, per in ipairs(PERIODS) do
		local c = newKey(f, per)
		c:SetPoint("TOPLEFT", f, "TOPLEFT", PIE_SIZE + 34, y)
		self.boxes[per.key] = c
		y = y - 26
	end
	totalsShown[#totalsShown + 1] = self
end

function TT:Refresh()
	if not self.frame:IsVisible() then return end
	if not M.PSS_ListTotals then
		self.info:SetText("")
		return
	end
	if not self.pie then self:Build() end
	local c = M.PSS_ListTotals(self.kind, self.counts)
	local v = self.values
	v.session, v.day, v.all = c.session or 0, c.day or 0, c.total or 0
	self.info:SetText(("Blocked |cffffff00%d|r in all."):format(v.all))
	for _, per in ipairs(PERIODS) do self.boxes[per.key].count:SetText(tostring(v[per.key])) end
	periodSlices(v, self.slices, self.pool)
	self.pie:Set(self.slices)
	self.empty:SetShown(v.all == 0 and v.session == 0 and v.day == 0)
end

-- parent: the frame it fills; kind: "players", "guilds" or "filters";
-- title: the list's name
function UI.NewTotals(parent, kind, title)
	local tt = setmetatable({ kind = kind, title = title, counts = {}, values = {}, slices = {}, pool = {}, boxes = {} }, TT)
	local f = CreateFrame("Frame", nil, parent)
	f:SetAllPoints()
	tt.frame = f
	local heading = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	heading:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	heading:SetText(title)
	local info = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	info:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
	info:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	info:SetJustifyH("LEFT")
	tt.info = info
	f:SetScript("OnShow", function() tt:Refresh() end)
	return tt
end

------------------------------------------------------------------------
-- The pane on the right of the main window: the totals of the Player,
-- Guild or Chat Filters tab beside its list (hidden on the other tabs).
-- The lists keep the 960 px they had; the window is wider by the pane.
--   UI.CreateTotalsPane(window)   once, when the window is built
--   UI.ShowTotals(kind)           the tab's totals (nil: no pane)
--   UI.RefreshTotals(kind)        that tab's numbers changed
------------------------------------------------------------------------
UI.PANE_W = 326
UI.LIST_RIGHT = -(11 + UI.PANE_W + 4)		-- a list panel's right edge

local TITLES = { players = "Player Ignore List", guilds = "Guild Ignore List", filters = "Chat Filters" }
local pane, totals = nil, {}
UI.TOTALS = totals		-- by kind (read by the harness)

function UI.CreateTotalsPane(window)
	pane = CreateFrame("Frame", nil, window, "InsetFrameTemplate")
	pane:SetPoint("TOPLEFT", window, "TOPRIGHT", -(11 + UI.PANE_W), -84)
	pane:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -11, 29)
	for kind, title in pairs(TITLES) do
		totals[kind] = UI.NewTotals(pane, kind, title)
		totals[kind].frame:Hide()
	end
	return pane
end

function UI.ShowTotals(kind)
	if not pane then return end
	pane:SetShown(kind ~= nil)
	for k, tt in pairs(totals) do tt.frame:SetShown(k == kind) end
end

-- many blocks in a row redraw once, a quarter second after the first
local due = {}
local function refreshDue()
	for kind in pairs(due) do
		due[kind] = nil
		if totals[kind] then totals[kind]:Refresh() end
	end
end
function UI.RefreshTotals(kind)
	local tt = totals[kind]
	if not (tt and tt.frame:IsVisible()) or due[kind] then return end
	due[kind] = true
	C_Timer.After(0.25, refreshDue)
end
