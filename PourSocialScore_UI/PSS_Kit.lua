------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - KIT
--
-- The controls every tab is built from, each in both looks (PSS_Skin.lua).
-- Blizzard: the Blizzard template as it is. Modern: the template's art faded
-- out and flat fills and one-pixel borders drawn over it. Sizes are the
-- same in both looks.
--   ns.NewHeading(parent, text)          13, the accent colour
--   ns.NewButton(parent, text, w, onClick)
--   ns.NewCheck(parent)                  24 x 24
--   ns.NewEditBox(parent, w, maxLetters) and ns.NewNumberBox(parent, w)
--   ns.OnCommit(box, commit, refresh)    Enter or focus loss, once
--   ns.NewSearchBox(parent, w, hint, onChange)
--   ns.NewPanel(parent, inset)           a tab page or a pane
--   ns.NewScrollFrame(parent)            scroll frame with a skinned bar
--   ns.NewTab(parent, text, onClick) and ns.SetTabSelected(tab, on)
-- Each widget keeps its Modern parts in widget.pssParts (shown in Modern).
------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local MOD = ns.MODERN
local ipairs, pcall = ipairs, pcall

function ns.NewHeading(parent, text)
	local fs = ns.NewText(parent, 13)
	ns.OnPaint(function() fs:SetTextColor(ns.Accent()) end)
	fs:SetText(text or "")
	return fs
end

-- Labels: Blizzard's gold / white / grey button fonts; Modern white, grey
-- when disabled (the shared font objects follow the look).
function ns.NewButton(parent, text, w, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetNormalFontObject(ns.Font(12, "GameFontNormal"))
	b:SetHighlightFontObject(ns.Font(12, "GameFontHighlight"))
	b:SetDisabledFontObject(ns.Font(12, "GameFontDisable"))
	b:SetText(text or "")
	if onClick then b:SetScript("OnClick", onClick) end
	local fill = ns.Own(ns.Fill(b, MOD.control, -6))
	local hover = ns.Own(b:CreateTexture(nil, "HIGHLIGHT"))
	hover:SetAllPoints(b)
	hover:SetColorTexture(MOD.hover[1], MOD.hover[2], MOD.hover[3], MOD.hover[4])
	local edge = ns.PixelBorder(b, MOD.border)
	b.pssParts = { fill = fill, edge = edge }
	ns.OnPaint(function(modern)
		ns.ShowArt(b, modern)
		fill:SetShown(modern)
		-- a HIGHLIGHT texture shows on hover by itself: fade it in Blizzard
		hover:SetAlpha(modern and 1 or 0)
		edge:SetShown(modern)
		-- Modern labels are white when enabled (the normal font is gold in Blizzard)
		b:SetNormalFontObject(ns.Font(12, modern and "GameFontHighlight" or "GameFontNormal"))
	end)
	return b
end

-- Modern: a near-black box inset 4 with a grey edge; Blizzard's tick kept
-- and tinted with the accent.
function ns.NewCheck(parent)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	local box = ns.Own(c:CreateTexture(nil, "BACKGROUND", nil, -6))
	box:SetPoint("TOPLEFT", 4, -4)
	box:SetPoint("BOTTOMRIGHT", -4, 4)
	box:SetColorTexture(MOD.box[1], MOD.box[2], MOD.box[3], MOD.box[4])
	local edgeHolder = CreateFrame("Frame", nil, c)
	edgeHolder:SetPoint("TOPLEFT", 4, -4)
	edgeHolder:SetPoint("BOTTOMRIGHT", -4, 4)
	local edge = ns.PixelBorder(edgeHolder, MOD.checkBorder)
	local keep = {}
	local tick, tickOff = c:GetCheckedTexture(), c.GetDisabledCheckedTexture and c:GetDisabledCheckedTexture()
	if tick then keep[tick] = true end
	if tickOff then keep[tickOff] = true end
	c.pssParts = { box = box, edge = edge, tick = tick }
	ns.OnPaint(function(modern)
		ns.ShowArt(c, modern, keep)
		box:SetShown(modern)
		edge:SetShown(modern)
		if tick then
			if modern then tick:SetVertexColor(ns.Accent()) else tick:SetVertexColor(1, 1, 1) end
		end
	end)
	return c
end

-- Modern: a near-black fill with a grey edge over the template's box.
local function SkinBox(e, size)
	local fill = ns.Own(e:CreateTexture(nil, "BACKGROUND", nil, -6))
	fill:SetPoint("TOPLEFT", -5, 0)
	fill:SetPoint("BOTTOMRIGHT", 0, 0)
	fill:SetColorTexture(MOD.box[1], MOD.box[2], MOD.box[3], MOD.box[4])
	local holder = CreateFrame("Frame", nil, e)
	holder:SetAllPoints(fill)
	local edge = ns.PixelBorder(holder, MOD.border)
	e.pssParts = { fill = fill, edge = edge }
	ns.OnPaint(function(modern)
		ns.ShowArt(e, modern)
		fill:SetShown(modern)
		edge:SetShown(modern)
		e:SetFontObject(ns.Font(size or 12, "ChatFontNormal"))
	end)
end

function ns.NewEditBox(parent, w, maxLetters)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w, 20)
	e:SetAutoFocus(false)
	if maxLetters then e:SetMaxLetters(maxLetters) end
	SkinBox(e)
	return e
end

function ns.NewNumberBox(parent, w)
	local e = ns.NewEditBox(parent, w)
	e:SetNumeric(true)
	e:SetJustifyH("CENTER")
	return e
end

-- commit on Enter and focus loss, once (ClearFocus fires focus loss again)
function ns.OnCommit(e, commit, refresh)
	local busy
	local function run(self)
		if busy then return end
		busy = true
		commit(self:GetText())
		self:ClearFocus()
		refresh()
		busy = false
	end
	e:SetScript("OnEnterPressed", run)
	e:SetScript("OnEditFocusLost", run)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refresh() end)
end

-- A search box: a magnifier, a grey hint while empty and a clear button
-- while not. onChange(text) runs as you type; Escape clears it.
function ns.NewSearchBox(parent, w, hint, onChange)
	local eb = ns.NewEditBox(parent, w, 128)
	eb:SetTextInsets(16, 18, 0, 0)
	local icon = ns.Own(eb:CreateTexture(nil, "OVERLAY"))
	icon:SetSize(12, 12)
	icon:SetPoint("LEFT", eb, "LEFT", 2, 0)
	icon:SetAtlas("common-search-magnifyingglass")
	icon:SetAlpha(0.6)
	local text = ns.NewText(eb, 11)
	text:SetPoint("LEFT", eb, "LEFT", 18, 0)
	text:SetTextColor(1, 1, 1, 0.4)
	text:SetText(hint or "")
	local clear = CreateFrame("Button", nil, eb)
	clear:SetSize(14, 14)
	clear:SetPoint("RIGHT", eb, "RIGHT", -2, 0)
	local x = clear:CreateTexture(nil, "ARTWORK")
	x:SetAllPoints()
	x:SetAtlas("common-search-clearbutton")
	x:SetAlpha(0.6)
	clear:SetScript("OnEnter", function() x:SetAlpha(1) end)
	clear:SetScript("OnLeave", function() x:SetAlpha(0.6) end)
	clear:SetScript("OnClick", function() eb:SetText(""); eb:ClearFocus() end)
	clear:Hide()
	eb:SetScript("OnTextChanged", function(self)
		local t = self:GetText() or ""
		text:SetShown(t == "")
		clear:SetShown(t ~= "")
		if onChange then onChange(t) end
	end)
	eb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	eb.hint, eb.clear = text, clear
	return eb
end

-- A tab page or a pane. Blizzard: the inset frame art. Modern: a flat fill
-- (darker when inset) with a grey edge.
function ns.NewPanel(parent, inset)
	local p = CreateFrame("Frame", nil, parent)
	local ok, art = pcall(CreateFrame, "Frame", nil, p, "InsetFrameTemplate")
	if ok and art then
		art:SetAllPoints(p)
		art:SetFrameLevel(p:GetFrameLevel())
		art:EnableMouse(false)
	else
		art = nil
	end
	local fill = ns.Fill(p, inset and MOD.inset or MOD.panel, -6)
	local edge = ns.PixelBorder(p, MOD.border)
	p.pssParts = { fill = fill, edge = edge, art = art }
	ns.OnPaint(function(modern)
		local useModern = modern or not art
		fill:SetShown(useModern)
		edge:SetShown(useModern)
		if art then art:SetShown(not useModern) end
	end)
	return p
end

-- A scroll frame (ScrollFrameTemplate where the client has it, else the
-- older UIPanelScrollFrameTemplate). Modern: the bar's arrows and track
-- faded, the thumb a 4 px light strip.
function ns.NewScrollFrame(parent)
	local ok, sf = pcall(CreateFrame, "ScrollFrame", nil, parent, "ScrollFrameTemplate")
	if not (ok and sf) then sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate") end
	local bar = sf.ScrollBar
	if type(bar) ~= "table" then return sf end
	-- new bars: Back, Forward, Track with a Thumb frame; old: up / down
	-- buttons, track textures on the bar and a thumb texture
	local thumbFrame = bar.Track and bar.Track.Thumb
	local thumbTex = not thumbFrame and bar.GetThumbTexture and bar:GetThumbTexture()
	local strip = ns.Own(bar:CreateTexture(nil, "OVERLAY", nil, 7))
	strip:SetColorTexture(MOD.thumb[1], MOD.thumb[2], MOD.thumb[3], MOD.thumb[4])
	strip:SetWidth(4)
	local anchor = thumbFrame or thumbTex
	if anchor then
		strip:SetPoint("TOP", anchor, "TOP")
		strip:SetPoint("BOTTOM", anchor, "BOTTOM")
	end
	local keep = thumbTex and { [thumbTex] = true } or nil
	ns.OnPaint(function(modern)
		for _, k in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton" }) do
			if bar[k] then bar[k]:SetAlpha(modern and 0 or 1) end
		end
		ns.ShowArt(bar, modern, keep)
		if bar.Track then ns.ShowArt(bar.Track, modern) end
		if thumbFrame then ns.ShowArt(thumbFrame, modern) end
		if thumbTex then thumbTex:SetAlpha(modern and 0 or 1) end
		strip:SetShown(modern and anchor ~= nil)
	end)
	return sf
end

------------------------------------------------------------------------
-- Tabs: the port's tab row. Blizzard: a Blizzard top tab where the client
-- has one, else the Modern plate in Blizzard's font. Modern: a dark plate,
-- the label at half strength unless selected; the selected tab gets a faint
-- wash and a one-pixel underline in the accent. Labels fade with SetAlpha,
-- never text colour alpha (that leaves the shadow as a second label).
------------------------------------------------------------------------
local TAB_TEMPLATES = { "PanelTopTabButtonTemplate", "TabButtonTemplate" }

function ns.NewTab(parent, text, onClick)
	local tab
	for _, t in ipairs(TAB_TEMPLATES) do
		local ok, f = pcall(CreateFrame, "Button", nil, parent, t)
		if ok and f then
			tab = f
			tab.pssTemplate = t
			break
		end
	end
	tab = tab or CreateFrame("Button", nil, parent)
	tab:SetNormalFontObject(ns.Font(11, "GameFontNormalSmall"))
	tab:SetHighlightFontObject(ns.Font(11, "GameFontHighlightSmall"))
	tab:SetDisabledFontObject(ns.Font(11, "GameFontHighlightSmall"))
	tab:SetText(text)
	tab:SetSize(tab:GetFontString():GetStringWidth() + 32, 24)
	tab:SetScript("OnClick", onClick)
	local plate = ns.Own(ns.Fill(tab, MOD.tab, -6))
	local wash = ns.Own(tab:CreateTexture(nil, "ARTWORK", nil, 7))
	wash:SetAllPoints()
	wash:SetColorTexture(MOD.tabWash[1], MOD.tabWash[2], MOD.tabWash[3], MOD.tabWash[4])
	wash:SetBlendMode("ADD")
	local line = ns.Own(tab:CreateTexture(nil, "OVERLAY", nil, 7))
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	tab.pssWash, tab.pssLine, tab.pssPlate = wash, line, plate
	ns.OnPaint(function(modern)
		local plain = modern or not tab.pssTemplate
		ns.ShowArt(tab, plain)
		plate:SetShown(plain)
		tab:SetNormalFontObject(ns.Font(11, plain and "GameFontHighlightSmall" or "GameFontNormalSmall"))
		ns.SetTabSelected(tab, tab.pssSelected)
	end)
	return tab
end

function ns.SetTabSelected(tab, selected)
	selected = selected and true or false
	tab.pssSelected = selected
	local plain = ns.IsModern() or not tab.pssTemplate
	tab.pssWash:SetShown(plain and selected)
	tab.pssLine:SetShown(plain and selected)
	tab.pssLine:SetColorTexture(ns.Accent())
	local fs = tab:GetFontString()
	if plain then
		if fs then fs:SetAlpha(selected and 1 or 0.5) end
	else
		if fs then fs:SetAlpha(1) end
		local fn = selected and PanelTemplates_SelectTab or PanelTemplates_DeselectTab
		if fn then pcall(fn, tab) end
	end
end
