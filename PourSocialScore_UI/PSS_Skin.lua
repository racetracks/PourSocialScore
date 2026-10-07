------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - SKINS
--
-- The window has one layout and two looks (option uiSkin, Libraries
-- M.PSS_UISkin): "blizzard" (the default: Blizzard frames, templates and
-- fonts) and "modern" (flat dark fills and one-pixel borders, drawn here).
-- Every widget is built once with the parts of both looks and registers a
-- painter with ns.OnPaint; switching the option repaints the window in
-- place. Only the paint differs: sizes, places and behaviour are the same.
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = PourSocialScore_NS.M
ns.M = M

local floor, max = math.floor, math.max
local ipairs = ipairs

-- Fonts: Blizzard keeps its own; Modern uses the client's Arial Narrow
local FONT_MODERN = "Fonts\\ARIALN.TTF"

-- colours: { r, g, b, a }
ns.MODERN = {
	window = { 0.067, 0.067, 0.067, 0.97 },
	titleBar = { 0, 0, 0, 0.5 },
	border = { 0.2, 0.2, 0.2, 1 },
	close = { 1, 1, 1, 0.75 },
	closeHover = { 1, 1, 1, 1 },
	text = { 1, 1, 1, 1 },
}

ns.TITLE_H = 25

local skin
local painters = {}

-- "blizzard" or "modern"
function ns.Skin()
	if not skin then skin = M.PSS_UISkin() end
	return skin
end

function ns.IsModern()
	return ns.Skin() == "modern"
end

-- fn(modern) runs now and again on every skin change
function ns.OnPaint(fn)
	painters[#painters + 1] = fn
	fn(ns.IsModern())
end

function ns.Repaint()
	skin = M.PSS_UISkin()
	local modern = skin == "modern"
	for _, fn in ipairs(painters) do fn(modern) end
end

-- One physical pixel at the frame's scale (768 units span the screen height).
local function OnePixel(frame)
	local h = GetPhysicalScreenSize and select(2, GetPhysicalScreenSize())
	if not h or h <= 0 then return 1 end
	local scale = frame:GetEffectiveScale()
	if not scale or scale <= 0 then scale = 1 end
	return 768 / h / scale
end

-- A border of four flat strips inside the frame's edges, one physical pixel
-- thick, on its own child so it can be shown with one look and hidden with
-- the other. Returns the holder; holder:SetColor(r, g, b, a).
function ns.PixelBorder(frame, color)
	local b = CreateFrame("Frame", nil, frame)
	b:SetAllPoints(frame)
	b:SetFrameLevel(frame:GetFrameLevel() + 1)
	local strips = {}
	for i = 1, 4 do strips[i] = b:CreateTexture(nil, "BORDER", nil, 7) end
	local function Layout()
		local px = max(OnePixel(b), 0.0001)
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
function ns.Fill(frame, color, sub)
	local t = frame:CreateTexture(nil, "BACKGROUND", nil, sub or -6)
	t:SetAllPoints(frame)
	t:SetColorTexture(color[1], color[2], color[3], color[4])
	return t
end

-- Is this atlas on the client? (names differ between clients)
function ns.HasAtlas(name)
	return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

-- A FontString that follows the skin: Blizzard uses the font object
-- (its face, colour and shadow), Modern the Modern face at the same size.
-- size: Modern point size; blizzObject: the Blizzard font object name.
function ns.NewText(parent, size, blizzObject, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", blizzObject or "GameFontHighlight")
	size = size or 12
	ns.OnPaint(function(modern)
		local obj = _G[blizzObject or "GameFontHighlight"]
		if modern then
			fs:SetFont(FONT_MODERN, size, "")
			fs:SetShadowOffset(0, 0)
			local c = ns.MODERN.text
			fs:SetTextColor(c[1], c[2], c[3], c[4])
		elseif obj then
			fs:SetFontObject(obj)
			local face, _, flags = obj:GetFont()
			if face then fs:SetFont(face, size, flags or "") end
			fs:SetShadowOffset(obj:GetShadowOffset())
			fs:SetTextColor(obj:GetTextColor())
		end
	end)
	return fs
end

-- Round to whole units (saved places stay small and stable)
function ns.Round(v)
	return floor((v or 0) + 0.5)
end
