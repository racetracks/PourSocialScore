------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - SKINS
--
-- The window has one layout and three looks (option uiSkin, Libraries
-- M.PSS_UISkin): "blizzard" (the default: Blizzard frames, templates and
-- fonts), "modern" (Blizzard's new Social window art; until it is built it
-- paints as Blizzard) and "dark" (flat dark fills and one-pixel borders,
-- drawn here).
-- Every widget is built once with the parts of both looks and registers a
-- painter with ns.OnPaint; switching the look or the font (option uiFont)
-- repaints the window in place. Only the paint differs: sizes, places and
-- behaviour are the same in both looks.
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = PourSocialScore_NS.M
ns.M = M

local floor, max = math.floor, math.max
local ipairs, select = ipairs, select

-- Dark's face when no font is picked: the client's Arial Narrow
local FONT_DARK = "Fonts\\ARIALN.TTF"

-- Dark colours: { r, g, b, a }
ns.DARK = {
	window = { 0.067, 0.067, 0.067, 0.97 },
	titleBar = { 0, 0, 0, 0.5 },
	border = { 0.2, 0.2, 0.2, 1 },
	close = { 1, 1, 1, 0.75 },
	closeHover = { 1, 1, 1, 1 },
	text = { 1, 1, 1, 1 },
	disabledText = { 0.5, 0.5, 0.5, 1 },
	panel = { 0.08, 0.08, 0.08, 0.92 },
	inset = { 0.04, 0.04, 0.04, 0.85 },
	control = { 0.08, 0.08, 0.08, 0.92 },
	box = { 0.02, 0.02, 0.02, 1 },
	checkBorder = { 0.25, 0.25, 0.25, 1 },
	hover = { 1, 1, 1, 0.10 },
	tab = { 0.068, 0.056, 0.052, 1 },
	tabWash = { 1, 1, 1, 0.02 },
	thumb = { 1, 1, 1, 0.30 },
	tip = { 0.067, 0.067, 0.067, 0.92 },
	tipBorder = { 1, 1, 1, 0.15 },
	tipText = { 1, 1, 1, 0.80 },
}

-- the look's own accent, used only without a class colour
local ACCENT = { dark = { 0.047, 0.824, 0.616 }, blizzard = { 1, 0.82, 0 } }

ns.TITLE_H = 25

local skin, modernArt
local painters = {}

-- "blizzard" or "dark"
function ns.Skin()
	if not skin then skin = M.PSS_UISkin() end
	return skin
end

function ns.IsDark()
	return ns.Skin() == "dark"
end

-- The art of Blizzard's new Social window (12.x); a client without it
-- (Camelot) shows the Blizzard look when Modern is picked.
local MODERN_ART = { "128-RedButton-Left", "common-sidetab", "common-sidetab-hover", "common-sidetab-selected", "friends-card-default", "perks-divider-short", "checkbox-minimal", "checkmark-minimal", "common-searchbar-a" }

function ns.HasModernArt()
	if modernArt == nil then
		modernArt = true
		for _, a in ipairs(MODERN_ART) do
			if not ns.HasAtlas(a) then modernArt = false break end
		end
	end
	return modernArt
end

function ns.IsModern()
	return ns.Skin() == "modern" and ns.HasModernArt()
end

-- The gold-framed plate of Blizzard's new Social window (its side tabs:
-- common-sidetab, -hover, -selected), stretched only in the middle so the
-- frame keeps its corners at any size (texture slice margins; a client
-- without them shows the plain stretched art).
local SIDE_MARGIN = 8

function ns.SideFrame(tex, atlas)
	tex:SetAtlas(atlas)
	if tex.SetTextureSliceMargins then
		tex:SetTextureSliceMargins(SIDE_MARGIN, SIDE_MARGIN, SIDE_MARGIN, SIDE_MARGIN)
		if tex.SetTextureSliceMode and Enum and Enum.UITextureSliceMode then
			tex:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
		end
	end
end

-- Size an atlas texture to a height, keeping its proportions (three-slice
-- ends); returns the width used.
function ns.AtlasWidth(atlas, h)
	local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
	if not info or not info.height or info.height == 0 then return h end
	return info.width * h / info.height
end

-- r, g, b of the accent: your class colour in every look; the look's own
-- only if the client gives no class colour
function ns.Accent()
	local r, g, b = M.PSS_UIAccent()
	if r then return r, g, b end
	local c = ACCENT[ns.Skin()] or ACCENT.blizzard
	return c[1], c[2], c[3]
end

-- fn(dark) runs now and again on every look or font change
function ns.OnPaint(fn)
	painters[#painters + 1] = fn
	fn(ns.IsDark())
end

------------------------------------------------------------------------
-- Fonts: shared font objects, one per (size, Blizzard font object), painted
-- in place, so every text, button and box using one follows a change.
-- Blizzard: the Blizzard object's face, colour and shadow at our size.
-- Dark: Arial Narrow, white (grey for a disabled object), no shadow.
-- A picked font (uiFont) replaces the face in both looks.
------------------------------------------------------------------------
local fonts, fontList = {}, {}

local function PaintFont(f, dark)
	-- "Accent": GameFontNormal's face, coloured with the accent in every look
	local src = _G[f.blizz == "Accent" and "GameFontNormal" or f.blizz] or GameFontHighlight
	local face, _, flags = src:GetFont()
	local picked = M.PSS_UIFontPath()
	if dark then
		face, flags = FONT_DARK, ""
		local c = f.blizz:find("Disable") and ns.DARK.disabledText or ns.DARK.text
		f.obj:SetTextColor(c[1], c[2], c[3], c[4])
		f.obj:SetShadowOffset(0, 0)
	else
		f.obj:SetTextColor(src:GetTextColor())
		f.obj:SetShadowColor(src:GetShadowColor())
		f.obj:SetShadowOffset(src:GetShadowOffset())
	end
	if f.blizz == "Accent" then f.obj:SetTextColor(ns.Accent()) end
	-- a picked face the client cannot load keeps the look's own
	if not (picked and f.obj:SetFont(picked, f.size, flags or "")) then
		f.obj:SetFont(face or FONT_DARK, f.size, flags or "")
	end
end

function ns.Font(size, blizz)
	size, blizz = size or 12, blizz or "GameFontHighlight"
	local key = blizz .. size
	local f = fonts[key]
	if not f then
		fontList[#fontList + 1] = key
		f = { obj = CreateFont("PSS_Font" .. #fontList), size = size, blizz = blizz }
		fonts[key] = f
		PaintFont(f, ns.IsDark())
	end
	return f.obj
end

function ns.Repaint()
	skin = M.PSS_UISkin()
	modernArt = nil	-- looked up again on the next paint
	local dark = skin == "dark"
	for _, key in ipairs(fontList) do PaintFont(fonts[key], dark) end
	for _, fn in ipairs(painters) do fn(dark) end
end

-- A FontString on a shared font object; colour set on it stays its own.
function ns.NewText(parent, size, blizz, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFontObject(ns.Font(size, blizz))
	return fs
end

------------------------------------------------------------------------
-- Primitives
------------------------------------------------------------------------
-- One physical pixel at the frame's scale (768 units span the screen height).
function ns.OnePixel(frame)
	local h = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
	if not h or h <= 0 then return 1 end
	local scale = frame:GetEffectiveScale()
	if not scale or scale <= 0 then scale = 1 end
	return 768 / h / scale
end

-- A line or strip exactly as thick as asked in physical pixels: no snapping
-- to the UI grid, which blurs a thin line at UI scales under 1.
function ns.NoSnap(t)
	if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
	if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
end

-- A border of four flat strips inside the frame's edges, one physical pixel
-- thick, on its own child so it can be shown with one look and hidden with
-- the other. Returns the holder; holder:SetColor(r, g, b, a).
function ns.PixelBorder(frame, color)
	local b = CreateFrame("Frame", nil, frame)
	b:SetAllPoints(frame)
	b:SetFrameLevel(frame:GetFrameLevel() + 1)
	local strips = {}
	for i = 1, 4 do
		strips[i] = b:CreateTexture(nil, "BORDER", nil, 7)
		ns.NoSnap(strips[i])
	end
	local function Layout()
		local px = max(ns.OnePixel(b), 0.0001)
		local t, btm, l, r = strips[1], strips[2], strips[3], strips[4]
		t:ClearAllPoints(); t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(px)
		btm:ClearAllPoints(); btm:SetPoint("BOTTOMLEFT"); btm:SetPoint("BOTTOMRIGHT"); btm:SetHeight(px)
		l:ClearAllPoints(); l:SetPoint("TOPLEFT", t, "BOTTOMLEFT"); l:SetPoint("BOTTOMLEFT", btm, "TOPLEFT"); l:SetWidth(px)
		r:ClearAllPoints(); r:SetPoint("TOPRIGHT", t, "BOTTOMRIGHT"); r:SetPoint("BOTTOMRIGHT", btm, "TOPRIGHT"); r:SetWidth(px)
	end
	function b:SetColor(r, g, bl, a)
		for i = 1, 4 do strips[i]:SetColorTexture(r, g, bl, a) end
	end
	b:SetColor(color[1], color[2], color[3], color[4])
	Layout()
	-- the scale can change after the first layout (UI scale, a parent's scale)
	b:SetScript("OnSizeChanged", Layout)
	return b
end

-- A flat fill behind everything else on the frame
function ns.Fill(frame, color, sub, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -6)
	t:SetAllPoints(frame)
	t:SetColorTexture(color[1], color[2], color[3], color[4])
	return t
end

-- Is this atlas on the client? (names differ between clients)
function ns.HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- The look's own parts of a widget: Dark parts are ours (kept in a table
-- per widget); Blizzard parts are the template's textures. ns.ShowArt shows
-- one set and fades the other (alpha, so a template's state changes cannot
-- bring a hidden texture back; Blizzard gets each texture's own alpha back).
-- keep: template textures Dark keeps.
local own = setmetatable({}, { __mode = "k" })
local alphaOf = setmetatable({}, { __mode = "k" })	-- a template texture's own alpha

function ns.Own(region)
	own[region] = true
	return region
end

function ns.ShowArt(frame, dark, keep)
	for i = 1, select("#", frame:GetRegions()) do
		local r = select(i, frame:GetRegions())
		if r and r:GetObjectType() == "Texture" and not own[r] and not (keep and keep[r]) then
			if alphaOf[r] == nil then alphaOf[r] = r:GetAlpha() end
			r:SetAlpha(dark and 0 or alphaOf[r])
		end
	end
end

-- Round to whole units (saved places stay small and stable)
function ns.Round(v)
	return floor((v or 0) + 0.5)
end
