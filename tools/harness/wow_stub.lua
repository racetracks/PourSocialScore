-- Minimal World of Warcraft API stub for loading PourSocialScore in plain
-- Lua 5.1 (tests only, not shipped). Frames are inert objects that remember
-- scripts, events, text, shown state and size.
local stub = {}

local clock = 1790000000			-- server time (seconds), settable
local uptime = 1000
function stub.SetTime(t) clock = t end
function stub.Advance(s) clock = clock + s; uptime = uptime + s end

local frames, eventFrames = {}, {}
local timers = {}

local W = {}
local WMT = { __index = function(t, k)
	local m = W[k]
	if m then return m end
	-- setters and other actions do nothing; anything else is missing
	if type(k) == "string" and (k:match("^Set") or k:match("^Enable") or k:match("^Disable") or
		k:match("^Clear") or k:match("^Lock") or k:match("^Unlock") or k:match("^Start") or
		k:match("^Stop") or k:match("^Play") or k:match("^Raise") or k:match("^Lower") or
		k:match("^Add") or k:match("^Hook") or k:match("^Register") or k:match("^Unregister") or
		k:match("^Insert") or k:match("^Highlight") or k:match("^Lock") or k:match("^Refresh") or
		k:match("^Scroll") or k:match("^Adjust") or k:match("^Toggle")) then
		return W._noop
	end
	return nil
end }
W._noop = function() end

local function new(kind, name, parent)
	local f = setmetatable({ _kind = kind, _name = name, _parent = parent, _shown = true,
		_scripts = {}, _events = {}, _w = 100, _h = 20, _text = "" }, WMT)
	frames[#frames + 1] = f
	if name then _G[name] = f end
	return f
end
stub.new = new

function W:GetName() return self._name end
function W:GetObjectType() return self._kind end
function W:IsObjectType(k) return self._kind == k end
function W:GetParent() return self._parent end
function W:SetParent(p) self._parent = p end
-- as the client: a script is a function or nil (anything else is an error)
function W:SetScript(k, fn)
	if fn ~= nil and type(fn) ~= "function" then
		error(("Usage: %s:SetScript(\"%s\", function): got a %s"):format(tostring(self._name or self._kind), tostring(k), type(fn)), 2)
	end
	self._scripts[k] = fn
end
function W:GetScript(k) return self._scripts[k] end
function W:HasScript() return true end
function W:HookScript(k, fn)
	local old = self._scripts[k]
	self._scripts[k] = old and function(...) old(...); fn(...) end or fn
end
function W:RegisterEvent(e) self._events[e] = true; eventFrames[self] = true end
function W:UnregisterEvent(e) self._events[e] = nil end
function W:UnregisterAllEvents() self._events = {} end
function W:IsEventRegistered(e) return self._events[e] == true end
function W:RegisterUnitEvent(e) self:RegisterEvent(e) end
function W:IsShown() return self._shown end
function W:IsVisible()
	local f = self
	while f do
		if not f._shown then return false end
		f = f._parent
	end
	return true
end
function W:Show()
	local was = self._shown
	self._shown = true
	if not was and self._scripts.OnShow and self:IsVisible() then self._scripts.OnShow(self) end
end
function W:Hide()
	local was = self._shown
	self._shown = false
	if was and self._scripts.OnHide then self._scripts.OnHide(self) end
end
function W:SetShown(s) if s then self:Show() else self:Hide() end end
function W:GetWidth() return self._w end
function W:GetHeight() return self._h end
function W:GetSize() return self._w, self._h end
function W:SetWidth(w) self._w = w end
function W:SetHeight(h) self._h = h end
function W:SetSize(w, h) self._w = w; self._h = h or w end
function W:GetRect() return 0, 0, self._w, self._h end
function W:GetLeft() return 0 end
function W:GetRight() return self._w end
function W:GetTop() return self._h end
function W:GetBottom() return 0 end
function W:GetCenter() return 0, 0 end
function W:GetScale() return 1 end
function W:GetEffectiveScale() return 1 end
function W:GetNumPoints() return 0 end
function W:SetPoint(...)
	self._point = { ... }
	-- every anchor in order (a frame can have more than one)
	self._points = self._points or {}
	self._points[#self._points + 1] = self._point
end
-- the last SetPoint as the game returns it: point, relativeTo, relativePoint, x, y
function W:GetPoint()
	local p = self._point
	if not p then return nil end
	if type(p[2]) == "string" then return p[1], nil, p[2], p[3] or 0, p[4] or 0 end
	return p[1], p[2], p[3] or p[1], p[4] or 0, p[5] or 0
end
function W:GetShadowOffset() return 1, -1 end
function W:GetShadowColor() return 0, 0, 0, 1 end
function W:IsPlaying() return false end
function W:SetText(t) self._text = t == nil and "" or tostring(t) end
function W:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
function W:GetText() return self._text end
function W:SetFormattedText(fmt, ...) self._text = string.format(fmt, ...) end
function W:GetStringWidth() return #(self._text or "") * 6 end
function W:GetStringHeight() return 12 end
function W:GetNumLines() return 1 end
function W:GetNumber() return tonumber(self._text) or 0 end
function W:SetNumber(n) self._text = tostring(n) end
function W:GetChecked() return self._checked == true end
function W:SetChecked(c) self._checked = c and true or false end
function W:SetupMenu(gen) self._menu = gen end
-- the entries of a SetupMenu drop-down: { { text, fn, kind, on }, ... }
-- (kind "button", "radio" or "checkbox"; on: its isSelected() as built)
function W:MenuButtons()
	local out = {}
	local function sel(kind)
		return function(_, text, isSelected, setSelected, data)
			out[#out + 1] = { text = text, kind = kind, on = isSelected(data) and true or false,
				fn = function() return setSelected(data) end }
		end
	end
	local root = {
		CreateButton = function(_, text, fn, data) out[#out + 1] = { text = text, kind = "button", fn = function() return fn(data) end } end,
		CreateRadio = sel("radio"),
		CreateCheckbox = sel("checkbox"),
	}
	if self._menu then self._menu(self, root) end
	return out
end
-- the whole tree of a SetupMenu drop-down: items { kind, text, fn, sub = { items } },
-- titles and dividers included, a CreateButton's returned root holds its submenu
function W:MenuTree()
	local function node()
		local n = { items = {} }
		local r = {}
		function r:CreateButton(text, fn, data)
			local it = { kind = "button", text = text, fn = fn and function() return fn(data) end or nil }
			n.items[#n.items + 1] = it
			local child, cr = node()
			it.sub = child
			return cr
		end
		function r:CreateTitle(text) n.items[#n.items + 1] = { kind = "title", text = text } end
		function r:CreateDivider() n.items[#n.items + 1] = { kind = "divider" } end
		function r:SetScrollMode() n.scroll = true end
		return n, r
	end
	local n, r = node()
	if self._menu then self._menu(self, r) end
	return n
end
-- the text a drop-down shows (OverrideText)
function W:OverrideText(t) self._ddText = t end
function W:IsEnabled() return self._enabled ~= false end
function W:Enable() self._enabled = true end
function W:Disable() self._enabled = false end
function W:SetEnabled(e) self._enabled = e and true or false end
function W:GetFrameLevel() return 1 end
function W:GetFrameStrata() return "MEDIUM" end
function W:GetID() return self._id or 0 end
function W:SetID(i) self._id = i end
-- a check sets f._focus to give a box the keyboard
function W:HasFocus() return self._focus or false end
function W:Insert(t) self._text = (self._text or "") .. tostring(t or "") end
function W:GetCursorPosition() return 0 end
function W:GetVerticalScroll() return self._vscroll or 0 end
function W:SetVerticalScroll(v)
	self._vscroll = v
	local fn = self._scripts.OnVerticalScroll
	if fn then fn(self, v) end
end
function W:GetVerticalScrollRange() return 0 end
function W:GetMinMaxValues() return 0, 100 end
function W:GetValue() return self._value or 0 end
function W:SetValue(v) self._value = v end
function W:GetMaxLetters() return 255 end
function W:SetAlpha(a) self._alpha = a end
function W:GetAlpha() return self._alpha or 1 end
function W:GetTextColor() return 1, 1, 1, 1 end
function W:GetFont()
	if self._font then return self._font[1], self._font[2], self._font[3] end
	return "Fonts\\FRIZQT__.TTF", 12, ""
end
function W:SetFont(path, size, flags) self._font = { path, size, flags }; return true end
function W:GetJustifyH() return "LEFT" end
-- only text regions justify: on a Button or Frame the game has no such method
local JUSTIFIES = { FontString = true, EditBox = true, SimpleHTML = true, MessageFrame = true, ScrollingMessageFrame = true }
local function justify(self, name)
	if not JUSTIFIES[self._kind] then error(("attempt to call method '%s' (a nil value) on a %s"):format(name, tostring(self._kind)), 3) end
end
function W:SetJustifyH() justify(self, "SetJustifyH") end
function W:SetJustifyV() justify(self, "SetJustifyV") end
function W:GetChildren() return end
function W:GetRegions() return end
function W:GetNumChildren() return 0 end
function W:SetHyperlinksEnabled(on) self._links = on and true or false end
function W:GetHyperlinksEnabled() return self._links or false end
-- a check sets f._mouseOver to put the mouse over a frame
function W:IsMouseOver() return self._mouseOver or false end
function W:IsDragging() return false end
function W:GetTexture() return nil end
function W:GetAtlas() return self._atlas end
function W:SetAtlas(a) self._atlas = a end
-- PSS_TEX_MISSING="path;path": the client has no such file (SetTexture says false)
local missingTex = {}
for p in (os.getenv("PSS_TEX_MISSING") or ""):gmatch("[^;]+") do missingTex[p] = true end
function W:SetTexture(t)
	if missingTex[t] then return false end
	self._texture = t
end
function W:SetWordWrap(w) self._wrap = w end
function W:SetMaxLines(n) self._maxLines = n end
function W:SetTextureSliceMargins(l, t, r, b) self._slice = { l, t, r, b } end
function W:IsProtected() return false end
function W:IsForbidden() return false end
function W:GetDebugName() return self._name or "?" end
function W:GetHighlightTexture() return self._hl or new("Texture", nil, self) end
function W:GetNormalTexture() return new("Texture", nil, self) end
function W:GetPushedTexture() return new("Texture", nil, self) end
function W:GetDisabledTexture() return new("Texture", nil, self) end
function W:GetCheckedTexture() return new("Texture", nil, self) end
function W:GetFontString()
	if not self._fs then self._fs = new("FontString", nil, self) end
	return self._fs
end
function W:GetScrollChild() return self._child end
function W:SetScrollChild(c) self._child = c end
function W:CreateFontString(name) return new("FontString", name, self) end
function W:CreateTexture(name) return new("Texture", name, self) end
function W:CreateMaskTexture(name) return new("Texture", name, self) end
function W:CreateLine(name) return new("Line", name, self) end
function W:CreateAnimationGroup() return new("AnimationGroup", nil, self) end
function W:CreateAnimation() return new("Animation", nil, self) end
function W:CreateFrame(kind, name) return new(kind, name, self) end

local TEMPLATE_PARTS = {
	PortraitFrameTemplate = { "TitleText", "CloseButton", "Portrait", "PortraitContainer" },
	ButtonFrameTemplate = { "TitleText", "CloseButton", "Portrait", "Inset" },
	InputBoxTemplate = { "Left", "Right", "Middle" },
	UIPanelScrollFrameTemplate = { "ScrollBar" },
	ScrollFrameTemplate = { "ScrollBar" },
	InsetFrameTemplate = {},
	PanelTopTabButtonTemplate = { "Left", "Right", "Middle", "LeftActive", "RightActive", "MiddleActive", "Text" },
	FauxScrollFrameTemplate = { "ScrollBar", "ScrollChildFrame" },
	InputScrollFrameTemplate = { "EditBox", "CharCount", "ScrollBar" },
	PanelTabButtonTemplate = { "Left", "Right", "Middle", "LeftActive", "RightActive", "MiddleActive", "Text" },
	CharacterFrameTabTemplate = { "Left", "Right", "Middle", "LeftActive", "RightActive", "MiddleActive", "Text" },
	CharacterFrameTabButtonTemplate = { "Left", "Right", "Middle", "LeftDisabled", "RightDisabled", "MiddleDisabled", "Text" },
	TabButtonTemplate = { "Left", "Right", "Middle", "Text" },
	UICheckButtonTemplate = { "Text" },
	WhoFrameColumnHeaderTemplate = { "Left", "Right", "Middle" },
	FriendsFrameColumnHeaderTemplate = { "Left", "Right", "Middle" },
}

function CreateFrame(kind, name, parent, template)
	local f = new(kind, name, parent)
	f._template = template
	if template then
		for t in tostring(template):gmatch("[^,%s]+") do
			for _, part in ipairs(TEMPLATE_PARTS[t] or {}) do
				local child = new("Frame", name and (name .. part) or nil, f)
				f[part] = child
				if part == "ScrollBar" then
					child.ScrollUpButton = new("Button", name and (name .. "ScrollBarScrollUpButton") or nil, child)
					child.ScrollDownButton = new("Button", name and (name .. "ScrollBarScrollDownButton") or nil, child)
				end
			end
		end
	end
	if kind == "Button" or kind == "CheckButton" then
		f.Text = f:GetFontString()
		if name then _G[name .. "Text"] = f.Text end
	end
	if f.PortraitContainer then f.PortraitContainer.portrait = new("Texture", nil, f) end
	return f
end

-- events
-- Blizzard's ignore list (C_FriendList below). PSS_BLIZZ_IGNORES="A;B" starts
-- with those names on it; PSS_BLIZZ_LATE=1 hides the list until the first
-- IGNORELIST_UPDATE, as at a real login.
local blizzList = { names = {}, visible = os.getenv("PSS_BLIZZ_LATE") == nil }
for n in (os.getenv("PSS_BLIZZ_IGNORES") or ""):gmatch("[^;]+") do blizzList.names[#blizzList.names + 1] = n end
stub.blizzList = blizzList

function stub.Fire(event, ...)
	if event == "IGNORELIST_UPDATE" then blizzList.visible = true end
	local list = {}
	for f in pairs(eventFrames) do
		if f._events[event] then list[#list + 1] = f end
	end
	for _, f in ipairs(list) do
		local h = f._scripts.OnEvent
		if h and f._events[event] then h(f, event, ...) end
	end
	return #list
end

-- how many frames are registered for an event (nothing is fired)
function stub.Listeners(event)
	local n = 0
	for f in pairs(eventFrames) do
		if f._events[event] then n = n + 1 end
	end
	return n
end

-- run every queued C_Timer callback (and the ones they queue), and OnUpdate once
function stub.RunTimers(maxRounds)
	for _ = 1, maxRounds or 20 do
		if #timers == 0 then break end
		local q = timers
		timers = {}
		for _, fn in ipairs(q) do fn() end
	end
end
function stub.RunOnUpdate(n)
	for _ = 1, n or 1 do
		for _, f in ipairs(frames) do
			local h = f._scripts.OnUpdate
			if h and f:IsVisible() then h(f, 0.02) end
		end
	end
end

-- globals ---------------------------------------------------------------
UIParent = new("Frame", "UIParent")
WorldFrame = new("Frame", "WorldFrame")
FriendsFrame = new("Frame", "FriendsFrame")
FriendsFrame._shown = false
SocialUIFrame = new("Frame", "SocialUIFrame")	-- Retail 12.1 Social window
SocialUIFrame._shown = false
-- the Addon Compartment (Retail): the entries addons register
AddonCompartmentFrame = { registered = {} }
function AddonCompartmentFrame:RegisterAddon(info) self.registered[#self.registered + 1] = info end
GameTooltip = new("GameTooltip", "GameTooltip")
ItemRefTooltip = new("GameTooltip", "ItemRefTooltip")
DEFAULT_CHAT_FRAME = new("ScrollingMessageFrame", "DEFAULT_CHAT_FRAME")
stub.chat = {}
function DEFAULT_CHAT_FRAME:AddMessage(m) stub.chat[#stub.chat + 1] = tostring(m) end
ChatFrame1 = DEFAULT_CHAT_FRAME
NUM_CHAT_WINDOWS = 1
UISpecialFrames = {}
StaticPopupDialogs = {}
SlashCmdList = {}
hash_SlashCmdList = {}
-- font objects answer GetFont, GetShadowOffset and GetTextColor like regions
local function fontObject() return setmetatable({ _kind = "Font", _scripts = {}, _events = {} }, WMT) end
GameFontNormal, GameFontHighlight, GameFontHighlightSmall, GameFontNormalSmall = fontObject(), fontObject(), fontObject(), fontObject()
GameFontDisable, ChatFontNormal = fontObject(), fontObject()
-- CreateFont: a named font object (the kit's shared fonts)
function CreateFont(name)
	local f = fontObject()
	if name then _G[name] = f end
	return f
end
CANCEL, OKAY, ACCEPT, YES, NO, UNKNOWN, CLOSE = "Cancel", "Okay", "Accept", "Yes", "No", "Unknown", "Close"
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
LE_PARTY_CATEGORY_HOME = 1
Enum = setmetatable({}, { __index = function(t, k) local v = setmetatable({}, { __index = function() return 0 end }); rawset(t, k, v); return v end })
-- the console's categories and command types (the auto Enum answers 0 for any other name)
rawset(Enum, "ConsoleCategory", { Debug = 0, Graphics = 1, Console = 2, Combat = 3, Game = 4, Default = 5, Net = 6, Sound = 7 })
rawset(Enum, "ConsoleCommandType", { Cvar = 0, Command = 1, Macro = 2, Script = 3 })

function GetTime() return uptime end
function GetServerTime() return clock end
local osdate = os.date
function date(fmt, t) return osdate(fmt, t or clock) end
function time(t) if t then return os.time(t) end return clock end
function debugprofilestop() return uptime * 1000 end
function GetFramerate() return 60 end
function InCombatLockdown() return stub.combat == true end
function IsEncounterInProgress() return false end
function UnitIsDeadOrGhost() return false end
function UnitAffectingCombat() return false end
function UnitName(u) if u == "player" then return "Tester", nil end return nil end
function UnitFullName(u) if u == "player" then return "Tester", "Realm" end return nil end
function GetUnitName(u) if u == "player" then return "Tester" end return nil end
function UnitGUID(u) if u == "player" then return "Player-1-0001" end return nil end
function UnitExists() return false end
function UnitIsPlayer() return false end
function UnitIsUnit() return false end
function UnitFactionGroup() return "Alliance", "Alliance" end
function UnitLevel() return 80 end
-- PSS_CLASS=<TOKEN> plays another class (macro helper); Mage by default
local CLASS_NAMES = { DRUID = 11, HUNTER = 3, MAGE = 8, PALADIN = 2, PRIEST = 5, ROGUE = 4, SHAMAN = 7, WARLOCK = 9, WARRIOR = 1 }
function UnitClass()
	local token = os.getenv("PSS_CLASS") or "MAGE"
	return token:sub(1, 1) .. token:sub(2):lower(), token, CLASS_NAMES[token] or 0
end
function UnitRace() return "Human", "Human" end
-- PSS_CAMELOT=1: the Camelot client (interface 16001, realm ClassicBetaPvP)
local camelot = os.getenv("PSS_CAMELOT") == "1"
function GetRealmName() return camelot and "ClassicBetaPvP" or "Realm" end
function GetNormalizedRealmName() return camelot and "ClassicBetaPvP" or "Realm" end
function GetLocale() return "enUS" end
function GetBuildInfo() return camelot and "1.0.0" or "12.0.7", "1", "Oct 1 2026", camelot and 16001 or 120007 end
function GetCVar(name)
	if name == "addonPerformanceMsgWarning" then return os.getenv("PSS_ADDON_WARN") or "1" end
	local c = stub.cvars[name]
	return c and c.value or "0"
end
function GetCVarBool() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function IsInGuild() return false end
function GetNumGroupMembers() return 0 end
function GetChannelList() return end
function GetChannelName() return 0 end
function GetNumDisplayChannels() return 0 end
function IsAddOnLoaded() return false end
function GetAddOnMemoryUsage() return 0 end
function UpdateAddOnMemoryUsage() end
function collectgarbage_stub() end
function GetCursorPosition() return 0, 0 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function PlaySound() end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function IsModifiedClick() return false end
function geterrorhandler() return function(e) print("ERROR: " .. tostring(e)); error(e, 0) end end
function seterrorhandler() end
function securecall(f, ...) return f(...) end
function hooksecurefunc(a, b, c)
	if type(a) == "table" then
		local old = a[b]
		a[b] = function(...) local r = { old(...) }; c(...); return unpack(r) end
	else
		local old = _G[a]
		_G[a] = function(...) local r = { (old or function() end)(...) }; b(...); return unpack(r) end
	end
end
function issecretvalue() return false end
function canaccessvalue() return true end
function tinsert(t, a, b) if b == nil then table.insert(t, a) else table.insert(t, a, b) end end
tremove = table.remove
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
strsplit = function(sep, s, n)
	local out, pos = {}, 1
	while true do
		if n and #out == n - 1 then out[#out + 1] = s:sub(pos); break end
		local a, b = s:find(sep, pos, true)
		if not a then out[#out + 1] = s:sub(pos); break end
		out[#out + 1] = s:sub(pos, a - 1)
		pos = b + 1
	end
	return unpack(out)
end
strtrim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
strlower, strupper, strsub, strlen, strfind, format, gsub, strrep, strbyte, strchar, strmatch, gmatch =
	string.lower, string.upper, string.sub, string.len, string.find, string.format, string.gsub, string.rep, string.byte, string.char, string.match, string.gmatch
string.trim = strtrim
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
floor, ceil, abs, max, min, mod = math.floor, math.ceil, math.abs, math.max, math.min, math.fmod
getn = table.getn
sort = table.sort
bit = { band = function(a, b) return a % (b + 1) end }

C_Timer = {}
function C_Timer.After(_, fn) timers[#timers + 1] = fn end
function C_Timer.NewTimer(_, fn) timers[#timers + 1] = fn; return { Cancel = function() end, IsCancelled = function() return false end } end
function C_Timer.NewTicker(_, fn) return { Cancel = function() end, IsCancelled = function() return true end } end

C_FriendList = {}
local ignores = blizzList.names
local function ignoreIndex(n)
	for i, v in ipairs(ignores) do if v:lower() == tostring(n):lower() then return i end end
end
function C_FriendList.GetNumIgnores() return blizzList.visible and #ignores or 0 end
function C_FriendList.GetIgnoreName(i) return blizzList.visible and ignores[i] or nil end
function C_FriendList.AddIgnore(n) if not ignoreIndex(n) then ignores[#ignores + 1] = n end return true end
function C_FriendList.DelIgnore(n) local i = ignoreIndex(n); if i then table.remove(ignores, i) end end
function C_FriendList.DelIgnoreByIndex(i) if ignores[i] then table.remove(ignores, i) end end
function C_FriendList.IsIgnored() return false end
function C_FriendList.SendWho() end
function C_FriendList.SetWhoToUi() end
function C_FriendList.GetNumWhoResults() return 0, 0 end
function C_FriendList.GetWhoInfo() return nil end
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() end }
C_AddOns = { IsAddOnLoaded = function() return false end, GetAddOnMetadata = function() return "test" end, LoadAddOn = function() end }
C_GuildInfo = {}
C_BattleNet = {}
C_Club = {}
C_ChatBubbles = {}
C_PartyInfo = {}
C_Map = {}
C_Spell = {}
C_Item = {}
C_CVar = { GetCVar = GetCVar, GetCVarBool = function() return false end }
-- CVars and the console (3.5.0, graphics settings): stub.cvars[name] =
-- {value, default, category, secure, readOnly, locked, noStick}; noStick
-- accepts a write and keeps the old value (a client that clamps or ignores
-- it). stub.SeedGfx() fills it on Camelot (about 20 entries). stub.cvarWrites
-- lists every SetCVar call, accepted or not. PSS_GFX_SET sets values at
-- login. PSS_GFX_OLDAPI=1 offers the
-- console list as C_Console.GetAllCommands, PSS_GFX_NOAPI=1 offers neither.
stub.cvars, stub.cvarWrites, stub.combat, stub.reloads = {}, {}, false, 0
local function cvarRow(name, value, default, category, flags)
	flags = flags or {}
	stub.cvars[name] = { value = value, default = default, category = category,
		secure = flags.secure, readOnly = flags.readOnly, locked = flags.locked, noStick = flags.noStick }
end
function stub.SeedGfx()
	stub.cvars = {}
	local G = 1
	cvarRow("graphicsQuality", "7", "5", G)
	cvarRow("graphicsViewDistance", "7", "5", G)
	cvarRow("graphicsShadowQuality", "3", "3", G)
	cvarRow("graphicsTextureResolution", "2", "2", G)
	cvarRow("graphicsLiquidDetail", "2", "2", G)
	cvarRow("ffxAntiAliasingMode", "2", "0", G)
	cvarRow("renderScale", "1", "1", G)
	cvarRow("farclip", "1300", "1300", G)
	cvarRow("vsync", "1", "1", G)
	cvarRow("particleDensity", "100", "100", G)
	cvarRow("gxWindow", "1", "1", G)
	cvarRow("gxMaximize", "1", "0", G)
	cvarRow("gxFullscreenResolution", "1920x1080", "1280x720", G)
	cvarRow("gxMonitor", "0", "0", G)
	cvarRow("gxAdapter", "", "", G)
	cvarRow("secureGfx", "1", "0", G, { secure = true })
	cvarRow("readOnlyGfx", "1", "0", G, { readOnly = true })
	cvarRow("lockedGfx", "1", "0", G, { locked = true })
	cvarRow("stuckGfx", "1", "0", G, { noStick = true })
	cvarRow("addonCombatRestrictionsForced", "0", "0", G)
	cvarRow("Sound_MasterVolume", "1", "1", 7)
	cvarRow("autoLootDefault", "0", "0", 4)
	-- PSS_GFX_SET="name=value;name=value": values the client already holds at
	-- login (a /reload keeps the CVars; a new harness run starts from the seed)
	for pair in (os.getenv("PSS_GFX_SET") or ""):gmatch("[^;]+") do
		local name, value = pair:match("^([^=]+)=(.*)$")
		if name and stub.cvars[name] then stub.cvars[name].value = value end
	end
end
function C_CVar.GetCVarInfo(name)
	local c = stub.cvars[name]
	if not c then return nil end
	return c.value, c.default, false, false, c.locked == true, c.secure == true, c.readOnly == true
end
function C_CVar.GetCVarDefault(name) local c = stub.cvars[name]; return c and c.default end
function C_CVar.SetCVar(name, value)
	stub.cvarWrites[#stub.cvarWrites + 1] = { name, tostring(value) }
	local c = stub.cvars[name]
	if not c or c.secure or c.readOnly then return false end
	if not c.noStick then c.value = tostring(value) end
	return true
end
local function consoleList()
	local names = {}
	for n in pairs(stub.cvars) do names[#names + 1] = n end
	table.sort(names, function(a, b) return a > b end)	-- not sorted, as the client
	local out = {}
	for _, n in ipairs(names) do
		local c = stub.cvars[n]
		out[#out + 1] = { command = n, help = "", category = c.category, commandType = 0 }
	end
	-- a console command (not a CVar) in the Graphics category
	out[#out + 1] = { command = "gxRestart", help = "", category = 1, commandType = 1 }
	return out
end
if os.getenv("PSS_GFX_NOAPI") ~= "1" then
	if os.getenv("PSS_GFX_OLDAPI") == "1" then
		C_Console = { GetAllCommands = consoleList }
	else
		function ConsoleGetAllCommands() return consoleList() end
	end
end
function ReloadUI() stub.reloads = stub.reloads + 1 end
if camelot then stub.SeedGfx() end

C_DateAndTime = {}
C_Texture = {}
-- PSS_ATLAS=all | "name,name": the client has these atlases (none otherwise)
if os.getenv("PSS_ATLAS") then
	local have = {}
	for n in os.getenv("PSS_ATLAS"):gmatch("[^,]+") do have[n] = true end
	local all = have.all
	-- PSS_ATLAS_MISSING=name,name: atlases the client lacks even with "all"
	local lack = {}
	for n in (os.getenv("PSS_ATLAS_MISSING") or ""):gmatch("[^,]+") do lack[n] = true end
	C_Texture.GetAtlasInfo = function(name) if (all or have[name]) and not lack[name] then return { width = 16, height = 16 } end end
end
C_ClassColor = { GetClassColor = function() return { r = 1, g = 1, b = 1, GenerateHexColor = function() return "ffffffff" end } end }
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1, colorStr = "ffffffff" } end })
LOCALIZED_CLASS_NAMES_MALE = {}
LOCALIZED_CLASS_NAMES_FEMALE = {}
CLASS_ICON_TCOORDS = {}
Menu = { ModifyMenu = function() end }
MenuUtil = { CreateContextMenu = function() end }
ChatFrame_AddMessageEventFilter = function() end
ChatFrame_RemoveMessageEventFilter = function() end
ChatFrameUtil = { AddMessageEventFilter = function() end }
ChatEdit_InsertLink = function() end
ChatFrame_OpenChat = function() end
StaticPopup_Show = function() end
StaticPopup_Hide = function() end
FauxScrollFrame_Update = function() return true end
FauxScrollFrame_GetOffset = function() return 0 end
FauxScrollFrame_OnVerticalScroll = function() end
FauxScrollFrame_SetOffset = function() end
PanelTemplates_SetNumTabs = function() end
PanelTemplates_SetTab = function() end
PanelTemplates_TabResize = function() end
PanelTemplates_SelectTab = function() end
PanelTemplates_DeselectTab = function() end
SetPortraitToTexture = function() end
ButtonFrameTemplate_HidePortrait = function() end
UIDropDownMenu_Initialize = function() end
ToggleDropDownMenu = function() end
UIErrorsFrame = new("Frame", "UIErrorsFrame")
SendChatMessage = function() end
GetAutoCompleteRealms = function() return {} end
RegisterAddonMessagePrefix = function() end
EasyMenu = function() end
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GenerateHexColor = function() return "ffffffff" end } end
Settings = { RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end, RegisterAddOnCategory = function() end }
InterfaceOptions_AddCategory = function() end

-- SavedVariables writer (sorted keys, tabs)
local function serialize(v, indent, out, seen)
	local t = type(v)
	if t == "string" then out[#out + 1] = string.format("%q", v)
	elseif t == "number" or t == "boolean" or t == "nil" then out[#out + 1] = tostring(v)
	elseif t == "table" then
		if seen[v] then error("cycle in saved variables") end
		seen[v] = true
		out[#out + 1] = "{\n"
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b)
			if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
			return type(a) < type(b)
		end)
		for _, k in ipairs(keys) do
			local val = v[k]
			if type(val) ~= "function" and type(val) ~= "userdata" then
				out[#out + 1] = indent .. "\t["
				serialize(k, "", out, seen)
				out[#out + 1] = "] = "
				serialize(val, indent .. "\t", out, seen)
				out[#out + 1] = ",\n"
			end
		end
		out[#out + 1] = indent .. "}"
		seen[v] = nil
	end
end
stub.serialize = function(v) local out = {}; serialize(v, "", out, {}); return table.concat(out) end

stub.frames = frames
-- Macros (macro helper, 3.5.0): stub.macros.account and .char, each a
-- name-sorted array of {name, icon, body}, as the client's two stores.
-- Account macros are indexes 1 to MAX_ACCOUNT_MACROS, character macros
-- follow. CreateMacro and EditMacro raise errors as the client does (in
-- combat, store full, name or body too long); stub.macroWrites lists every
-- call, accepted or not. PSS_MACRO_MAX="<account>,<character>" sets the
-- limits; PSS_MACRO_SEED="a:Name=body;c:Name=body" ("|" for a new line)
-- seeds the stores; PSS_MACRO_DYNICON=1 answers icon 999 for a body that
-- starts "#showtooltip" (the client's dynamic icon); PSS_MACRO_NOAPI=1
-- leaves the four functions out.
do
	local maxA, maxC = (os.getenv("PSS_MACRO_MAX") or ""):match("^(%d+),(%d+)$")
	MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = tonumber(maxA) or 120, tonumber(maxC) or 18
	stub.macros, stub.macroWrites = { account = {}, char = {} }, {}
	local function byName(a, b) return a.name < b.name end
	local function store(i)
		if i <= MAX_ACCOUNT_MACROS then return stub.macros.account, i end
		return stub.macros.char, i - MAX_ACCOUNT_MACROS
	end
	local function check(name, body)
		if stub.combat then error("Cannot change macros in combat") end
		if type(name) ~= "string" or #name < 1 or #name > 16 then error("bad macro name") end
		if type(body) ~= "string" or #body > 255 then error("bad macro body") end
	end
	local function indexOf(t, m, perChar)
		for i, x in ipairs(t) do if x == m then return perChar and i + MAX_ACCOUNT_MACROS or i end end
	end
	function stub.SeedMacros(spec)
		stub.macros = { account = {}, char = {} }
		for item in (spec or ""):gmatch("[^;]+") do
			local where, name, body = item:match("^([ac]):([^=]+)=(.*)$")
			if where then
				local t = where == "a" and stub.macros.account or stub.macros.char
				t[#t + 1] = { name = name, icon = 134400, body = (body:gsub("|", "\n")) }
				table.sort(t, byName)
			end
		end
	end
	stub.SeedMacros(os.getenv("PSS_MACRO_SEED"))
	if os.getenv("PSS_MACRO_NOAPI") ~= "1" then
		function GetNumMacros() return #stub.macros.account, #stub.macros.char end
		function GetMacroInfo(i)
			local t, j = store(i)
			local m = t[j]
			if not m then return nil end
			local icon = m.icon
			if os.getenv("PSS_MACRO_DYNICON") == "1" and m.body:find("^#showtooltip") then icon = 999 end
			return m.name, icon, m.body
		end
		function CreateMacro(name, icon, body, perChar)
			stub.macroWrites[#stub.macroWrites + 1] = { "create", name, perChar and true or false }
			check(name, body)
			local t = perChar and stub.macros.char or stub.macros.account
			if #t >= (perChar and MAX_CHARACTER_MACROS or MAX_ACCOUNT_MACROS) then error("Cannot create any more macros") end
			local m = { name = name, icon = icon, body = body }
			t[#t + 1] = m
			table.sort(t, byName)
			return indexOf(t, m, perChar)
		end
		function EditMacro(i, name, icon, body)
			stub.macroWrites[#stub.macroWrites + 1] = { "edit", name, i > MAX_ACCOUNT_MACROS }
			check(name, body)
			local t, j = store(i)
			local m = t[j]
			if not m then error("no such macro") end
			m.name, m.icon, m.body = name, icon, body
			table.sort(t, byName)
			return indexOf(t, m, i > MAX_ACCOUNT_MACROS)
		end
	end
end

------------------------------------------------------------------------
-- The addon list (3.6.0, the addon manager). The real folders come first
-- (run.lua hands them over: H.AddonsReal), then the fake ones from
-- PSS_ADDONS: a count (Fake001 ...) or "name:flags;name:flags" with flags
-- joined by commas: e enabled for this character, E enabled for both
-- characters (me and alt), L loaded, l load on demand, d=<dep>, o=<optional
-- dep>, g=<TOC Group>, c=<X-Category>, m=<memory KB>, r=<reason>, t=<title>,
-- p=<avg/cur/peak/enc CPU ms>. Every call is counted in stub.calls; every
-- write is listed in stub.addonWrites. PSS_ADDON_NOAPI=<names> removes
-- APIs, PSS_ADDON_OLDAPI=1 gives GetAddOnEnableState as the old global
-- (character, name), PSS_ADDON_NOENUM=1 leaves Enum.AddOnEnableState out,
-- PSS_ADDON_NOPROFILER=1 / PSS_ADDON_PROFILEROFF=1 the profiler.
------------------------------------------------------------------------
stub.calls, stub.addonWrites, stub.versionCheck = {}, {}, true
local DEFAULT_ADDONS = "Atlas:e,L,m=900;Atlas_Options:e,l,d=Atlas;LibStub:e,L,c=Library,m=10;LibFoo:e,L,m=20;"
	.. "DBM-Core:e,L,m=4000,p=2/1/9/3;DBM-GUI:e,L,d=DBM-Core,m=600;DBM-Raids:e,l,d=DBM-Core;Details:e,L,m=2500,p=1/2/3/4;"
	.. "Details_Streamer:E,d=Details;WeakAuras:e;ZedOne:g=Zeds;ZedTwo:g=Zeds,e;OldThing:e,r=INTERFACE_VERSION;"
	.. "Needy:e,d=Gone;Loner:o=Atlas;CycA:d=CycB;CycB:d=CycA;CycC:d=CycA;Blizzard_Test:l"
if os.getenv("PSS_ACP_TAKEN") == "1" then
	SlashCmdList = SlashCmdList or {}
	SlashCmdList["ACP"] = function() end
	SLASH_ACP1 = "/acp"
end
local list, real
local function call(n) stub.calls[n] = (stub.calls[n] or 0) + 1 end
local function parseFlags(rec, flags)
	for f in (flags or ""):gmatch("[^,]+") do
		local k, v = f:match("^(%a)=(.*)$")
		if not k then k = f end
		if k == "e" then rec.me = true
		elseif k == "E" then rec.me, rec.alt = true, true
		elseif k == "L" then rec.loaded = true
		elseif k == "l" then rec.lod = true
		elseif k == "d" then rec.deps[#rec.deps + 1] = v
		elseif k == "o" then rec.opt[#rec.opt + 1] = v
		elseif k == "g" then rec.group = v
		elseif k == "c" then rec.cat = v
		elseif k == "m" then rec.mem = tonumber(v)
		elseif k == "r" then rec.reason = v
		elseif k == "t" then rec.title = v
		elseif k == "i" then rec.iconTex = v
		elseif k == "a" then rec.iconAtlas = v
		elseif k == "p" then
			rec.cpu = {}
			for n in v:gmatch("[^/]+") do rec.cpu[#rec.cpu + 1] = tonumber(n) end
		end
	end
end
local function build()
	if list then return list end
	list = {}
	for _, r in ipairs(real and real.order or {}) do
		local a = real.addons[r]
		list[#list + 1] = { name = r, real = true, me = true, deps = a.deps, opt = {}, lod = a.lod, mem = 100 }
	end
	local spec = os.getenv("PSS_ADDONS") or DEFAULT_ADDONS
	if spec == "big" then
		-- 280 plain addons, a chain of 20 (C20 needs C19 ... C01) and a loop
		local parts = {}
		for i = 1, 280 do parts[#parts + 1] = ("Big%03d:%s"):format(i, i % 2 == 0 and "e,L,m=50" or "l") end
		for i = 1, 20 do parts[#parts + 1] = ("C%02d:%s"):format(i, i > 1 and ("d=C%02d"):format(i - 1) or "") end
		parts[#parts + 1] = "LoopA:d=LoopB"
		parts[#parts + 1] = "LoopB:d=LoopA"
		spec = table.concat(parts, ";")
	end
	if tonumber(spec) then
		for i = 1, tonumber(spec) do
			list[#list + 1] = { name = ("Fake%03d"):format(i), deps = {}, opt = {}, me = i % 3 ~= 0, mem = 10 + i,
				loaded = i % 3 ~= 0, group = i % 10 == 0 and "Grp" or nil }
		end
	else
		for item in spec:gmatch("[^;]+") do
			local name, flags = item:match("^([^:]+):?(.*)$")
			local rec = { name = name, deps = {}, opt = {}, mem = 0 }
			parseFlags(rec, flags)
			list[#list + 1] = rec
		end
	end
	for _, r in ipairs(list) do
		if not r.real then r.title = r.title or ("|cff69ccf0" .. r.name .. "|r") end
	end
	stub.snapshot = {}
	for i, r in ipairs(list) do stub.snapshot[i] = { r.me, r.alt } end
	return list
end
function stub.AddonList() return build() end
-- ids: an index or a name
local function find(x)
	local l = build()
	if type(x) == "number" then return l[x], x end
	for i, r in ipairs(l) do if r.name == x then return r, i end end
end
local function target(char, r)
	-- nil: every character; the GUID or a name: this one
	if char == nil then return "all" end
	return "me"
end
local function setEnabled(i, char, on)
	local r = find(i)
	if not r then return end
	stub.addonWrites[#stub.addonWrites + 1] = { i = i, name = r.name, char = char, on = on }
	local t = target(char, r)
	if t == "all" then r.me, r.alt = on or nil, on or nil else r.me = on or nil end
end
local function stateOf(r, char)
	if char == nil then
		if r.me and r.alt then return 2 end
		if r.me or r.alt then return 1 end
		return 0
	end
	return r.me and 2 or 0
end
local function reasonOf(r)
	if r.reason then return r.reason end
	if not r.me then return "DISABLED" end
	for _, d in ipairs(r.deps) do
		local dr = find(d)
		if not dr then return "DEP_MISSING" end
		if not dr.me then return "DEP_DISABLED" end
	end
	if r.lod then return "DEMAND_LOADED" end
end

local api = {}
function api.GetNumAddOns() call("GetNumAddOns") return #build() end
function api.GetAddOnInfo(x)
	call("GetAddOnInfo")
	local r = find(x)
	if not r then return nil end
	local reason = reasonOf(r)
	return r.name, r.title or r.name, "Notes of " .. r.name, reason == nil, reason, "INSECURE"
end
function api.GetAddOnEnableState(x, char)
	call("GetAddOnEnableState")
	local r = find(x)
	return r and stateOf(r, char) or 0
end
function api.EnableAddOn(x, char) call("EnableAddOn") setEnabled(x, char, true) end
function api.DisableAddOn(x, char) call("DisableAddOn") setEnabled(x, char, false) end
function api.EnableAllAddOns(char)
	call("EnableAllAddOns")
	stub.addonWrites[#stub.addonWrites + 1] = { fn = "EnableAll", char = char }
	for _, r in ipairs(build()) do if char == nil then r.me, r.alt = true, true else r.me = true end end
end
function api.DisableAllAddOns(char)
	call("DisableAllAddOns")
	stub.addonWrites[#stub.addonWrites + 1] = { fn = "DisableAll", char = char }
	for _, r in ipairs(build()) do if char == nil then r.me, r.alt = nil, nil else r.me = nil end end
end
function api.GetAddOnDependencies(x) call("GetAddOnDependencies") local r = find(x) return unpack(r and r.deps or {}) end
function api.GetAddOnOptionalDependencies(x) call("GetAddOnOptionalDependencies") local r = find(x) return unpack(r and r.opt or {}) end
function api.IsAddOnLoadOnDemand(x) call("IsAddOnLoadOnDemand") local r = find(x) return r and r.lod and true or false end
function api.IsAddOnLoaded(x)
	local r = find(x)
	if not r then return false end
	if r.real then return real.isLoaded(r.name) end
	return r.loaded and true or false
end
function api.LoadAddOn(x)
	call("LoadAddOn")
	local r = find(x)
	if not r then return false, "MISSING" end
	if r.real then return real.load(r.name) end
	if not r.me then return false, "DISABLED" end
	if not r.lod then return false, "NOT_DEMAND_LOADED" end
	r.loaded = true
	return true
end
function api.GetAddOnMetadata(x, field)
	call("GetAddOnMetadata")
	local r = find(x)
	if not r then return nil end
	if r.real then return real.meta(r.name, field) end
	if field == "Title" then return r.title or r.name end
	if field == "Group" then return r.group end
	if field == "X-Category" or field == "Category" then return r.cat end
	if field == "IconTexture" then return r.iconTex end
	if field == "IconAtlas" then return r.iconAtlas end
	if field == "Author" then return "Tester" end
	if field == "Version" then return "1.0" end
	return nil
end
function api.UpdateAddOnMemoryUsage() call("UpdateAddOnMemoryUsage") stub.memUpdates = (stub.memUpdates or 0) + 1 end
function api.GetAddOnMemoryUsage(x) call("GetAddOnMemoryUsage") local r = find(x) return r and r.mem or 0 end
function api.SaveAddOns() call("SaveAddOns") stub.saveAddOns = (stub.saveAddOns or 0) + 1 end
function api.ResetAddOns()
	call("ResetAddOns")
	for i, r in ipairs(build()) do
		local s = stub.snapshot[i]
		if s then r.me, r.alt = s[1], s[2] end
	end
end
function api.IsAddonVersionCheckEnabled() call("IsAddonVersionCheckEnabled") return stub.versionCheck end
function api.SetAddonVersionCheck(on) call("SetAddonVersionCheck") stub.versionCheck = on and true or false end

-- the real folders: run.lua hands over what it loaded (order, addons,
-- isLoaded, load, meta); this installs the whole list API over its own
function stub.AddonsReal(r)
	real, list = r, nil
	local noapi = {}
	for n in (os.getenv("PSS_ADDON_NOAPI") or ""):gmatch("[^,%s]+") do noapi[n] = true end
	local old = os.getenv("PSS_ADDON_OLDAPI") == "1"
	for n, f in pairs(api) do
		if n == "GetAddOnEnableState" and old then
			-- the old global: (character, name)
			_G.GetAddOnEnableState = function(char, x) return f(x, char) end
			C_AddOns.GetAddOnEnableState = nil
		else
			C_AddOns[n] = f
			_G[n] = f
		end
	end
	local doesExist = C_AddOns.DoesAddOnExist
	C_AddOns.DoesAddOnExist = function(x) return doesExist(x) or find(x) ~= nil end
	for n in pairs(noapi) do
		C_AddOns[n] = nil
		_G[n] = nil
	end
	if os.getenv("PSS_ADDON_NOENUM") == "1" then
		rawset(Enum, "AddOnEnableState", nil)
		getmetatable(Enum).__index = function(t, k)
			if k == "AddOnEnableState" then return nil end
			local v = setmetatable({}, { __index = function() return 0 end })
			rawset(t, k, v)
			return v
		end
	else
		rawset(Enum, "AddOnEnableState", { None = 0, Some = 1, All = 2 })
	end
	-- the profiler
	rawset(Enum, "AddOnProfilerMetric", nil)
	Enum.AddOnProfilerMetric = { SessionAverageTime = 0, RecentAverageTime = 1, EncounterAverageTime = 2, PeakTime = 3 }
	local slot = { [0] = 1, [1] = 2, [3] = 3, [2] = 4 }	-- metric -> the p= position (avg/cur/peak/enc)
	if os.getenv("PSS_ADDON_NOPROFILER") ~= "1" then
		local function metric(rec, m) return rec.cpu and rec.cpu[slot[m]] or 0 end
		C_AddOnProfiler = {
			IsEnabled = function() return os.getenv("PSS_ADDON_PROFILEROFF") ~= "1" end,
			GetAddOnMetric = function(name, m) call("GetAddOnMetric") local rec = find(name) return rec and metric(rec, m) or 0 end,
			GetOverallMetric = function(m)
				call("GetOverallMetric")
				local sum = 0
				for _, rec in ipairs(build()) do sum = sum + metric(rec, m) end
				return sum
			end,
			GetApplicationMetric = function(m)
				call("GetApplicationMetric")
				local sum = tonumber(os.getenv("PSS_ADDON_APP") or "100")
				for _, rec in ipairs(build()) do sum = sum + metric(rec, m) end
				return sum
			end,
		}
	end
end

return stub
