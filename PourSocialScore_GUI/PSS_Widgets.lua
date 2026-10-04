------------------------------------------------------------------------
-- POUR SOCIAL SCORE - WIDGETS
--
-- UI only. Nothing here reads PourSocialScoreDB or calls a PSS function:
-- every decision (is it listed? what does Add do? may a /who be sent?)
-- and every message comes in through `opts`. The look comes from
-- PSS_UIKit.lua (windows, top buttons, header rows).
--
--   W.Prompt(opts)                 in-game style question, up to 3 buttons
--   W.PromptAdd(name, opts)        "Add <Name> to the ... without searching?"  Okay / Search / Cancel
--   W.PromptAddAnyway(name, opts)  "No ... was found. Add it anyway?"          Add Anyway / Cancel
--   W.BoxHint(box, text)           grey hint text in an empty edit box
--   W.EntryRow(panel, opts)        [box] [Search] [Add] row, top right of a panel
--   W.Picker(opts)                 results window: tick column, text columns, Save / Cancel
--
-- Messages: every widget that reports something calls opts.say(text).
-- Without opts.say the text goes to the default chat frame.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M
local UI = M.UI

local W = {}
M.Widgets = W

local function say(opts, msg)
	if opts and opts.say then
		opts.say(msg)
	elseif DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(msg)
	end
end

------------------------------------------------------------------------
-- Prompt: a question with up to three buttons, drawn with the game's own
-- dialog art (the StaticPopup box, border, font, buttons and sounds).
--
--   W.Prompt({
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
	bgFile		= "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile		= true, tileSize = 32, edgeSize = 32,
	insets		= { left = 11, right = 12, top = 12, bottom = 11 },
}

local function promptSound(kit)
	if PlaySound and SOUNDKIT and SOUNDKIT[kit] then PlaySound(SOUNDKIT[kit]) end
end

local function buildPrompt()
	if W.promptFrame then return W.promptFrame end

	local f = CreateFrame("Frame", "PSSPromptDialog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:Hide()
	f:SetWidth(PROMPT_WIDTH)
	f:SetPoint("TOP", UIParent, "TOP", 0, -135)		-- where StaticPopup1 sits
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	if f.SetBackdrop then f:SetBackdrop(DIALOG_BACKDROP) end
	tinsert(UISpecialFrames, "PSSPromptDialog")		-- Escape closes it

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

	W.promptFrame = f
	return f
end

function W.Prompt(opts)
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

------------------------------------------------------------------------
-- PromptAdd: ask before adding a name without searching.
--
--   W.PromptAdd(name, {
--   	listName = "Player Ignore List",
--   	add      = function(name) ... end,                -- Okay
--   	search   = function(name) return sentOk end,      -- Search (from the click)
--   	canSend  = function() return true end,            -- optional, e.g. /who cooldown
--   	onDone   = function() ... end,                    -- optional: after Okay / a sent search
--   	say      = function(msg) ... end,                 -- optional
--   	text     = "...", addedText = "...",              -- optional wording, %s = name, list
--   	okText = OKAY, searchText = SEARCH, cancelText = CANCEL,
--   })
------------------------------------------------------------------------
function W.PromptAdd(name, opts)
	local question = opts.text or "Add |cffffd100<%s>|r to the %s without searching?"
	local added = opts.addedText or "<%s> added to the %s."

	return W.Prompt({
		text = question:format(name, opts.listName),
		buttons = {
			{
				text = opts.okText or OKAY or "Okay",
				onClick = function()
					opts.add(name)
					say(opts, added:format(name, opts.listName))
					if opts.onDone then opts.onDone() end
				end,
			},
			{
				text = opts.searchText or SEARCH or "Search",
				onClick = function()
					if opts.canSend and not opts.canSend() then return end
					if opts.search(name) and opts.onDone then opts.onDone() end
				end,
			},
			{ text = opts.cancelText or CANCEL or "Cancel" },
		},
	})
end

------------------------------------------------------------------------
-- PromptAddAnyway: a search found nothing - add the name anyway?
--
--   W.PromptAddAnyway(name, {
--   	what = "guild", listName = "Guild Exclusion List",
--   	add  = function(name) end,
--   	say  = function(msg) end,                         -- optional
--   	text = "...", addedText = "...", addText = "Add Anyway", cancelText = CANCEL,  -- optional
--   })
------------------------------------------------------------------------
function W.PromptAddAnyway(name, opts)
	local question = opts.text or "No %s named |cffffd100<%s>|r was found online.\n\nAdd it to the %s anyway?"
	local added = opts.addedText or "<%s> added to the %s."

	return W.Prompt({
		text = question:format(opts.what or "match", name, opts.listName),
		buttons = {
			{
				text = opts.addText or "Add Anyway",
				onClick = function()
					opts.add(name)
					say(opts, added:format(name, opts.listName))
				end,
			},
			{ text = opts.cancelText or CANCEL or "Cancel" },
		},
	})
end

------------------------------------------------------------------------
-- BoxHint: grey hint text inside an edit box ("Add a Guild..."), shown
-- while the box is empty and not being typed in.
------------------------------------------------------------------------
function W.BoxHint(box, text)
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
-- EntryRow: [box] [Search button] [Add button], top right of a panel, or
-- directly beneath another EntryRow (opts.below).
--
--   W.EntryRow(panel, {
--   	searchText = "Player Search",  addText = "Add Player",
--   	hint       = "Add a Player...", listName = "Player Ignore List",
--   	emptyMsg   = "message when a button is pressed with an empty box",
--   	listedMsg  = "<%s> is already on the %s.",          -- optional
--   	searchTip  = { "first line", "grey lines ..." },
--   	addTip     = "Add button tooltip text",             -- optional
--   	isListed   = function(text) return bool end,
--   	add        = function(text) end,
--   	search     = function(text) return sentOk end,      -- runs from the click
--   	canSend    = function() return true end,            -- optional
--   	onEmptyAdd = function() return handled end,         -- optional: Add with an empty box
--   	clearOnSearch = true,                               -- optional
--   	below      = otherRow,                              -- optional
--   	names      = { box =, search =, add = },            -- optional global frame names
--   	say        = function(msg) end,                     -- optional
--   })
-- Returns { box =, search =, add = }.
------------------------------------------------------------------------
function W.EntryRow(panel, opts)
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
	W.BoxHint(row.box, opts.hint)

	local function boxText()
		local text = (row.box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then return nil end
		return text
	end

	local function doSearch()
		if opts.canSend and not opts.canSend() then return end
		local text = boxText()
		if not text then
			say(opts, opts.emptyMsg)
			return
		end
		if opts.search(text) and opts.clearOnSearch then row.box:SetText("") end
	end

	local function doAdd()
		local text = boxText()
		if not text then
			if not (opts.onEmptyAdd and opts.onEmptyAdd()) then say(opts, opts.emptyMsg) end
			return
		end
		if opts.isListed(text) then
			say(opts, (opts.listedMsg or "<%s> is already on the %s."):format(text, opts.listName))
			return
		end
		W.PromptAdd(text, {
			listName = opts.listName,
			add			= opts.add,
			search		= opts.search,
			canSend		= opts.canSend,
			say			= opts.say,
			onDone		= function() row.box:SetText("") end,
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
-- The ticked rows' values are handed to onSave when Save is pressed. One
-- window per `name`; its columns are fixed the first time it is built.
--
--   W.Picker({
--   	name     = "PSSPlayerSearchFrame",       -- global frame name
--   	saveKey  = "playerSearch",                -- optional: remembers size / columns
--   	title    = "Player Search Results",
--   	subtitle = "3 player(s) found for \"Bob\".",
--   	columns  = { { key = "name", text = "Name", width = 160 }, ... },  -- the last one fills
--   	items    = { { cells = { name = "Bob-Realm", ... }, value = "Bob-Realm", listed = false }, ... },
--   	onSave   = function(values) end,          -- values of the ticked rows, in order
--   	onHide   = function() end,                -- optional
--   	listedText = " (already in list)",        -- optional
--   })
-- Listed items are shown unticked and greyed.
------------------------------------------------------------------------
W.pickers = {}

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

	W.pickers[opts.name] = f
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

function W.Picker(opts)
	local f = W.pickers[opts.name] or buildPicker(opts)
	if f.title then f.title:SetText(opts.title or "") end
	f.subtitle:SetText(opts.subtitle or "")
	f.onSave, f.onHide = opts.onSave, opts.onHide
	local listedText = opts.listedText or " |cff999999(already in list)|r"

	for _, r in ipairs(f.rows) do r:Hide() end
	local items = opts.items or {}
	for i, item in ipairs(items) do
		local r = pickerRow(f, i)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -(i - 1) * UI.ROW_H)
		r.value = item.value

		for n, c in ipairs(f.columns) do
			local text = tostring((item.cells or {})[c.key] or "")
			if n == 1 and item.listed then text = text .. listedText end
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
