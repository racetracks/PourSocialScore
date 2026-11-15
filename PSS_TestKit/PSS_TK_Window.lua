local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M
local T = TK.T

local CreateFrame = CreateFrame
local UISpecialFrames = UISpecialFrames
local ReloadUI = ReloadUI

local FRAME = "PSS_TestKitFrame"

-- Import dialog: one multi-line edit box, Import / Cancel, error line below.
local function buildDialog(win)
	local dlg = CreateFrame("Frame", FRAME .. "Import", win, "BackdropTemplate")
	dlg:SetSize(560, 320)
	dlg:SetPoint("CENTER", win, "CENTER", 0, 0)
	dlg:SetFrameStrata("DIALOG")
	if dlg.SetBackdrop then
		dlg:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
	end
	local title = dlg:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", dlg, "TOP", 0, -14)
	title:SetText(T.IMPORT_TITLE)

	local scroll = CreateFrame("ScrollFrame", FRAME .. "ImportScroll", dlg, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -40)
	scroll:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -36, 76)
	local box = CreateFrame("EditBox", nil, scroll)
	box:SetMultiLine(true)
	box:SetMaxLetters(0)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal or GameFontHighlight)
	box:SetWidth(500)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(box)

	local err = dlg:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	err:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 16, 50)
	err:SetPoint("RIGHT", dlg, "RIGHT", -16, 0)
	err:SetJustifyH("LEFT")
	err:SetTextColor(1, 0.3, 0.3)
	err:SetText("")

	local ok = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	ok:SetSize(100, 24)
	ok:SetPoint("BOTTOMRIGHT", dlg, "BOTTOM", -6, 16)
	ok:SetText(T.IMPORT)
	ok:SetScript("OnClick", function()
		local text = box:GetText() or ""
		local set, e = M.PSS_Call("testkit.import", { text = text })
		local msg = ""
		if set and set[1] then
			msg = set[1][4] or ""
			if msg == "" and set[1][1] ~= "" then dlg:Hide(); box:SetText(""); err:SetText(""); return end
		end
		if msg == "" then msg = (type(e) == "string" and e) or (type(e) == "table" and e[1] and e[1][1]) or T.ERR_FAILED end
		err:SetText(msg)
	end)
	local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	cancel:SetSize(100, 24)
	cancel:SetPoint("BOTTOMLEFT", dlg, "BOTTOM", 6, 16)
	cancel:SetText(T.CANCEL)
	cancel:SetScript("OnClick", function() dlg:Hide() end)
	dlg:Hide()
	return dlg
end

-- Built once, on the first open; kept hidden after close.
function TK.GetWindow()
	if TK.window then return TK.window end
	local win = CreateFrame("Frame", FRAME, UIParent, "ButtonFrameTemplate")
	win:SetSize(760, 520)
	win:SetPoint("CENTER")
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(win) end
	if win.SetTitle then win:SetTitle(T.TITLE) elseif win.TitleText then win.TitleText:SetText(T.TITLE) end
	UISpecialFrames[#UISpecialFrames + 1] = FRAME

	local dlg
	local imp = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	imp:SetSize(90, 22)
	imp:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -32)
	imp:SetText(T.IMPORT)
	imp:SetScript("OnClick", function()
		if not dlg then dlg = buildDialog(win) end
		dlg:Show()
	end)

	local foot = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	foot:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 12)
	foot:SetText(T.FOOTER:format(0))
	win.footer = foot

	local rl = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	rl:SetSize(90, 22)
	rl:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 8)
	rl:SetText(T.RELOAD)
	rl:SetScript("OnClick", function() ReloadUI() end)

	win:Hide()
	TK.window = win
	return win
end
