------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - WINDOW
--
-- The Pour Social Score window, 960 x 494. While it is being built it opens
-- with /pss tui only (M.PSS_TUI); the tabs, navigation and pages come in the
-- next stages. Dragged elsewhere it remembers the place (Libraries
-- M.PSS_UIPlace); Escape closes it.
--
-- Blizzard look: a Blizzard window frame (ButtonFrameTemplate) behind our
-- frame, with its own art only. Modern look: a flat fill, a dark title
-- strip, a thin frame and a plain close glyph.
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M

local WIN_W, WIN_H = 960, 494
local PLACE = "PSS_Window"

-- tried in order; the first the client has is the Blizzard look
local FRAME_TEMPLATES = { "ButtonFrameTemplate", "PortraitFrameTemplate", "BasicFrameTemplateWithInset" }

local win

local function SavePlace()
	local point, _, relPoint, x, y = win:GetPoint(1)
	if point then M.PSS_SetUIPlace(PLACE, point, relPoint, ns.Round(x), ns.Round(y)) end
end

local function RestorePlace()
	win:ClearAllPoints()
	local point, relPoint, x, y = M.PSS_UIPlace(PLACE)
	if point then
		win:SetPoint(point, UIParent, relPoint, x, y)
	else
		win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-- The Blizzard window art: a template frame of our own, under our frame's
-- content, with its portrait, title and close button hidden (ours are used
-- in both looks so they sit in the same place).
local function BlizzardFrame()
	for _, t in ipairs(FRAME_TEMPLATES) do
		local ok, f = pcall(CreateFrame, "Frame", nil, win, t)
		if ok and f then
			f:SetAllPoints(win)
			f:SetFrameLevel(win:GetFrameLevel())
			f:EnableMouse(false)
			if ButtonFrameTemplate_HidePortrait and t == "ButtonFrameTemplate" then
				pcall(ButtonFrameTemplate_HidePortrait, f)
			end
			if f.CloseButton then f.CloseButton:Hide() end
			if f.TitleText then f.TitleText:Hide() end
			if f.TitleContainer and f.TitleContainer.TitleText then f.TitleContainer.TitleText:Hide() end
			if f.Inset then f.Inset:Hide() end
			return f
		end
	end
end

-- The Modern art: fill, title strip and frame. The frame is Blizzard's
-- AdventureMap_TopBorder atlas where the client has it, else a thin border.
local function ModernFrame()
	local f = CreateFrame("Frame", nil, win)
	f:SetAllPoints(win)
	f:SetFrameLevel(win:GetFrameLevel())
	ns.Fill(f, ns.MODERN.window, -6)
	local bar = f:CreateTexture(nil, "BACKGROUND", nil, -5)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(ns.TITLE_H)
	local c = ns.MODERN.titleBar
	bar:SetColorTexture(c[1], c[2], c[3], c[4])
	if ns.HasAtlas("AdventureMap_TopBorder") then
		local edge = CreateFrame("Frame", nil, f)
		edge:SetAllPoints(f)
		edge:SetFrameLevel(win:GetFrameLevel() + 6)
		local t = edge:CreateTexture(nil, "OVERLAY", nil, 7)
		t:SetAllPoints(edge)
		t:SetAtlas("AdventureMap_TopBorder")
	else
		ns.PixelBorder(f, ns.MODERN.border)
	end
	return f
end

-- Modern close: Blizzard's close glyph, no plate, brighter on hover
local function ModernClose()
	local b = CreateFrame("Button", nil, win)
	b:SetSize(24, 24)
	b:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
	b:SetFrameLevel(win:GetFrameLevel() + 8)
	local t = b:CreateTexture(nil, "ARTWORK")
	t:SetSize(14, 14)
	t:SetPoint("CENTER", b, "CENTER", -2, 0)
	if ns.HasAtlas("uitools-icon-close") then
		t:SetAtlas("uitools-icon-close")
	else
		t:SetTexture("Interface\\Buttons\\UI-StopButton")
	end
	local c, h = ns.MODERN.close, ns.MODERN.closeHover
	t:SetVertexColor(c[1], c[2], c[3], c[4])
	b:SetScript("OnEnter", function() t:SetVertexColor(h[1], h[2], h[3], h[4]) end)
	b:SetScript("OnLeave", function() t:SetVertexColor(c[1], c[2], c[3], c[4]) end)
	b:SetScript("OnClick", function() win:Hide() end)
	return b
end

-- Escape: a helper frame in UISpecialFrames shown with the window; Escape
-- hides it, and that closes the window (the next stages step back first).
local function EscapeFrame()
	local esc = CreateFrame("Frame", "PSS_WindowEscape", UIParent)
	esc:Hide()
	tinsert(UISpecialFrames, "PSS_WindowEscape")
	win:HookScript("OnShow", function() esc:Show() end)
	win:HookScript("OnHide", function() esc:Hide() end)
	esc:SetScript("OnHide", function()
		if win:IsShown() then win:Hide() end
	end)
end

local function Build()
	win = CreateFrame("Frame", "PSS_Window", UIParent)
	win:Hide()
	win:SetSize(WIN_W, WIN_H)
	win:SetFrameStrata(M.PSS_FrameStrataName())
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	win:EnableMouse(true)
	win:SetMovable(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePlace()
	end)

	local blizz = BlizzardFrame()
	local modern = ModernFrame()
	local blizzClose = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	blizzClose:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
	blizzClose:SetFrameLevel(win:GetFrameLevel() + 8)
	local modernClose = ModernClose()

	local title = ns.NewText(win, 13, "GameFontNormal")
	title:SetPoint("TOP", win, "TOP", 0, -6)
	title:SetText("Pour Social Score")
	win.title = title
	-- each look's parts, so the look shown can be checked
	win.art = { blizzard = blizz, modern = modern, blizzardClose = blizzClose, modernClose = modernClose }

	ns.OnPaint(function(isModern)
		-- a client without any Blizzard frame template falls back to Modern art
		local useModern = isModern or not blizz
		modern:SetShown(useModern)
		if blizz then blizz:SetShown(not useModern) end
		modernClose:SetShown(useModern)
		blizzClose:SetShown(not useModern)
	end)

	EscapeFrame()

	M.Events.Register("OPTION_CHANGED", function(key)
		if key == "frameStrata" then
			win:SetFrameStrata(M.PSS_FrameStrataName())
		elseif key == "uiSkin" then
			ns.Repaint()
		end
	end)
end

-- /pss tui; show true opens without toggling.
function M.PSS_TUI(show)
	if not win then Build() end
	if win:IsShown() and not show then
		win:Hide()
		return
	end
	RestorePlace()
	win:Show()
	win:Raise()
end
