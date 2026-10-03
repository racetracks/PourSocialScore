---------------------------------------
-- Pour Social Score USER INTERFACE --
---------------------------------------

-- first : X... - is move left
-- second: Y... - is move down

local addonName, addon 	= ...
local L = addon.L -- localization entries
local V = addon.V -- shared variables
local M = addon.M -- shared methods

V.needSorted					= true
V.nameUI							= ""

local MainFrame				= nil
local Tab1Frame				= nil
local Tab2Frame				= nil
local Tab2FrameState		= 0
local Tab2FrameEdit			= nil
local Tab2EditDesc			= ""
local Tab2EditFilter		= ""
local Tab2EditActive		= false
local Tab2BlockFilter		= 0
local Tab3Frame				= nil
local TabIOFrame			= nil
local TabGuildFrame			= nil
local columnCount			= 0
local IgnoreScrollFrame		= nil
local IgnoreScrollButtons	= {}
local IgnoreScrollIndex		= {}
local IgnoreScrollType		= 0
local IgnoreScrollSelect	= 0
local FilterScrollFrame		= nil
local FilterScrollButtons	= {}
local FilterScrollSelect	= 0
-- Sort state and helpers for the list tabs, kept in one table (Lua 5.1 allows
-- a function at most 60 upvalues, and BuildUIFrames is close to that).
local SortUI				= {}
local UI					= M.UI    -- shared look (PSS_UIKit.lua)
local WINDOW_WIDTH			= 960   -- default and minimum (the guild and player tables need it)
local WINDOW_HEIGHT			= 470
local WINDOW_OFFSET			= 113
local BUTTON_HEIGHT			= 20
-- Row counts are recalculated whenever the window is resized (see
-- RelayoutMainFrame); these are the values for the default window size.
local BUTTON_TOTAL			= math.floor((WINDOW_HEIGHT - WINDOW_OFFSET - 86 - 4) / BUTTON_HEIGHT)
-- Player Ignore List: summary block + column header take the top 86 px
local IGNORE_LIST_TOP		= 86
local IGNORE_ROWS			= math.floor((WINDOW_HEIGHT - WINDOW_OFFSET - IGNORE_LIST_TOP - 4) / BUTTON_HEIGHT)

-------------------------
-- DIALOGS AND BUTTONS --
-------------------------

StaticPopupDialogs["PSS_REASON"] = {

	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	text           = "Edit ignore note for |cffffff00%s:",
	maxLetters     = 128,
	hasEditBox	   = 1,
	whileDead      = 1,
	button1        = L["BOX_3"],
	button2        = L["BOX_5"],

	OnShow = function(self)
		local idx = M.hasAnyIgnored(V.nameUI)
		self.EditBox:SetText(idx > 0 and (PourSocialScoreDB.notes[idx] or "") or "")
		self.EditBox:SetFocus()
	end,
	OnAccept = function(self)
		local idx = M.hasAnyIgnored(V.nameUI)
		if idx > 0 then PourSocialScoreDB.notes[idx] = self.EditBox:GetText() end
		M.PSSUpdateUI()
	end,
	EditBoxOnEnterPressed = function(self)
		local idx = M.hasAnyIgnored(V.nameUI)
		if idx > 0 then PourSocialScoreDB.notes[idx] = self:GetParent().EditBox:GetText() end
		self:GetParent():Hide()
		M.PSSUpdateUI()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

local function setExpire (text)
	local idx = M.hasAnyIgnored(V.nameUI)
	if tonumber(text) and idx > 0 then
		PourSocialScoreDB.expList[idx] = tonumber(text)
		M.PSSUpdateUI()
	end	
end

StaticPopupDialogs["PSS_PRUNE"] = {
	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	text           = "|cffffff00%s|cffffffff\n\n"..L["BOX_11"],
	maxLetters     = 4,
	hasEditBox	   = 1,
	whileDead      = 1,
	button1        = L["BOX_6"],
	button2        = L["BOX_5"],

	OnShow = function(self)
		self.EditBox:SetText("365")
		self.EditBox:SetFocus()
	end,
	OnAccept = function(self)
		-- removes straight away (no second confirmation)
		local d = tonumber(self.EditBox:GetText())
		if d and d > 0 then M.PruneIgnoreList(d, true) end
	end,
	EditBoxOnEnterPressed = function(self)
		local d = tonumber(self:GetText())
		if d and d > 0 then M.PruneIgnoreList(d, true) end
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

StaticPopupDialogs["PSS_EXPIRE"] = {

	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	text           = "|cffffff00%s|cffffffff\n\n"..L["BOX_1"],
	maxLetters     = 4,
	hasEditBox	   = 1,
	whileDead      = 1,
	button1        = L["BOX_3"],
	button2        = L["BOX_5"],

	OnShow         = function(self)
		local idx = M.hasAnyIgnored(V.nameUI)
		self.EditBox:SetText(idx > 0 and tostring(PourSocialScoreDB.expList[idx] or 0) or "0")
		self.EditBox:SetFocus()
	end,
	OnAccept       = function(self)
		setExpire(self.EditBox:GetText())
	end,
	EditBoxOnEnterPressed = function(self)
		setExpire(self:GetParent().EditBox:GetText())
		self:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

StaticPopupDialogs["PSS_FILTERRESET"] = {

	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	text           = "|cffffff00%s|cffffffff\n\n"..L["BOX_2"],
	whileDead      = 1,
	button1        = L["BOX_4"],
	button2        = L["BOX_5"],
	OnAccept       = function(self)
		M.ResetSpamFilters()
		M.FilterListDrawUpdate(FilterScrollFrame)
	end,	
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

StaticPopupDialogs["PSS_FILTERREMOVE"] = {

	preferredIndex = STATICPOPUPS_NUMDIALOGS,
	text           = "|cffffff00%s|cffffffff\n\n"..L["BOX_9"],
	whileDead      = 1,
	button1        = L["BOX_10"],
	button2        = L["BOX_5"],
	OnAccept       = function(self)
		if FilterScrollSelect <= 0 then
			return
		end

		M.RemoveChatFilter(FilterScrollSelect)
		M.FilterListDrawUpdate(FilterScrollFrame)
	end,	
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

local function ButtonFilterRemove()

	if FilterScrollSelect <= 0 then
		return
	end

	if M.PSS_IsBuiltinFilter(FilterScrollSelect) then
		M.ShowMsg("Built-in chat filters can't be removed. Turn it off instead, or use Copy Filter to make an editable version.")
		return
	end

	StaticPopup_Show("PSS_FILTERREMOVE", L["BOX_10"])
end

local function ButtonIgnoreRemove()

	if IgnoreScrollSelect <= 0 then
		return
	end

	local idx     = IgnoreScrollIndex[IgnoreScrollSelect]
	local typeStr = PourSocialScoreDB.typeList[idx]

	V.needSorted = true

	if typeStr == "player" then
		M.PSS_DelIgnore(idx, true)
	elseif typeStr == "npc" then
		M.AddOrDelNPC(idx)
		M.PSSUpdateUI()
	elseif typeStr == "server" then
		M.AddOrDelServer(idx)
		M.PSSUpdateUI()
	end
end

--------------------------
-- CHAT FILTER SCROLLER --
--------------------------

function M.FilterScrollChangeState (state)
	-- -1 = refresh current  0 = list  1 = editor  2 = list with its Block History panel
	if (state ~= -1) then
		Tab2FrameState = state
	end

	if Tab2FrameState == 1 then
		Tab2Frame:Hide()
		Tab2FrameEdit:Show()
	else
		-- coming back from the editor: keep the current sort
		if Tab2FrameEdit and Tab2FrameEdit:IsShown() then Tab2Frame.keepSort = true end
		Tab2FrameEdit:Hide()
		Tab2Frame:Show()
		if Tab2Frame.histPanel then
			if Tab2FrameState == 2 then
				Tab2Frame.histPanel:Open(Tab2BlockFilter)
			else
				Tab2Frame.histPanel:Close()
			end
		end
	end
end

-- Chat filter sorting. Built-in rules always stay above custom rules; within
-- each group the list is sorted by the chosen column (default Description
-- A-Z). Ties fall back to the description A-Z.
SortUI.filterKey, SortUI.filterAsc = "desc", true
-- Chat Filters columns (the Filter column stretches with the window)
SortUI.FILTER_COLUMNS = {
	{ key = "desc",    text = L["COL_9"],  width = 230, tipName = "Description" },
	{ key = "state",   text = "On",        width = 44,  tipName = "On/Off" },
	{ key = "blocked", text = L["COL_11"], width = 70,  tipName = "Blocked count", justify = "RIGHT" },
	{ key = "filter",  text = L["COL_10"], width = 509, tipName = "Filter text", tip = "Built-in filters always stay at the top.", fill = true, minWidth = 120 },
}
-- Player Ignore List columns (the reference design)
SortUI.PLAYER_COLUMNS = {
	{ key = "name",   text = L["COL_1"], width = 130 },
	{ key = "server", text = L["COL_2"], width = 120 },
	{ key = "type",   text = L["COL_3"], width = 60 },
	{ key = "listed", text = L["COL_4"], width = 50, justify = "RIGHT" },
	{ key = "expire", text = L["COL_5"], width = 54, justify = "RIGHT" },
	{ key = "note",   text = L["COL_6"], width = 110 },
}
-- block metrics (same columns as the Guild Ignore List), then W I G P C
for _, c in ipairs(UI.MetricColumns()) do SortUI.PLAYER_COLUMNS[#SortUI.PLAYER_COLUMNS + 1] = c end
SortUI.PLAYER_COLUMNS[#SortUI.PLAYER_COLUMNS + 1] =
	{ key = "excl",   letters = "excl",  width = 154, lettersTitle = "Per-player exclusions",
		lettersNote = "Ticked = allowed from that player, unticked = blocked." }
local FilterSortIndex = {}   -- display position -> filter number

local function buildFilterSortIndex()
	local db = PourSocialScoreDB
	local key, asc = SortUI.filterKey, SortUI.filterAsc
	local items = {}
	for i = 1, #db.filterList do
		local v
		if key == "state" then v = db.filterActive[i] == true and 1 or 0
		elseif key == "blocked" then v = tonumber(db.filterCount[i]) or 0
		elseif key == "filter" then v = string.lower(db.filterList[i] or "")
		else v = string.lower(db.filterDesc[i] or "") end
		items[#items + 1] = { i = i, b = M.PSS_IsBuiltinFilter(i) and 0 or 1, v = v, d = string.lower(db.filterDesc[i] or "") }
	end
	table.sort(items, function(a, b)
		if a.b ~= b.b then return a.b < b.b end          -- built-ins first, always
		if a.v ~= b.v then if asc then return a.v < b.v else return a.v > b.v end end
		if a.d ~= b.d then return a.d < b.d end
		return a.i < b.i
	end)
	FilterSortIndex = {}
	for pos, it in ipairs(items) do FilterSortIndex[pos] = it.i end
	if SortUI.filterHR then SortUI.filterHR:SetSort(key, asc) end
end

function SortUI.setFilterSort(key)
	if SortUI.filterKey == key then SortUI.filterAsc = not SortUI.filterAsc else SortUI.filterKey, SortUI.filterAsc = key, true end
	M.FilterListDrawUpdate(FilterScrollFrame)
end

function M.FilterListDrawUpdate (self)

	-- While the Block History panel is open in place of the list, keep the
	-- list rows hidden. (2.0.8 redrew them on every blocked line, on top of
	-- the history table, which is what jumbled the page.)
	if Tab2Frame and Tab2Frame.histPanel and Tab2Frame.histPanel:IsShown() then
		for _, b in ipairs(FilterScrollButtons) do b:Hide() end
		return
	end

	buildFilterSortIndex()
	FauxScrollFrame_Update(self, #PourSocialScoreDB.filterList, BUTTON_TOTAL, BUTTON_HEIGHT)

	if FilterScrollSelect > #PourSocialScoreDB.filterList then
		FilterScrollSelect = #PourSocialScoreDB.filterList
	end

	Tab2Frame.infotext:SetText(format(L["INFO_4"], PourSocialScoreDB.filterTotal or 0, PourSocialScoreDB.filterWhisperTotal or 0, PourSocialScoreDB.filterPrivateTotal or 0))
	do
		local nb, nc, non = 0, 0, 0
		for i = 1, #PourSocialScoreDB.filterList do
			if M.PSS_IsBuiltinFilter(i) then nb = nb + 1 else nc = nc + 1 end
			if PourSocialScoreDB.filterActive[i] == true then non = non + 1 end
		end
		Tab2Frame.infobreakdown:SetText(("|cffaaaaaaFilters:|r %d    |cffaaaaaaBuilt-in:|r %d    |cffaaaaaaCustom:|r %d    |cffaaaaaaOn:|r |cff33ff99%d|r"):format(nb + nc, nb, nc, non))
	end

	local offset = FauxScrollFrame_GetOffset(self)
	local index  = 0
	local pName = ""
	for count = 1, BUTTON_TOTAL do
		index = FilterSortIndex[count + offset]

		if index and PourSocialScoreDB.filterList[index] then
			pName = PourSocialScoreDB.filterDesc[index]

			if M.PSS_IsBuiltinFilter(index) then
				-- built-in: greyed out, read-only
				local tag = M.PSS_IsGuildRuleFilter(index) and "(guild rule)" or "(built-in)"
				FilterScrollButtons[count].name:SetText("|cff8a8a8a" .. (PourSocialScoreDB.filterDesc[index] or "") .. " |cff5f5f5f" .. tag .. "|r")
				FilterScrollButtons[count].filter:SetText("|cff7a7a7a" .. (PourSocialScoreDB.filterList[index] or "") .. "|r")
			else
				FilterScrollButtons[count].name:SetText(PourSocialScoreDB.filterDesc[index])
				FilterScrollButtons[count].filter:SetText(PourSocialScoreDB.filterList[index])
			end

			if PourSocialScoreDB.filterActive[index] == true then
				FilterScrollButtons[count].state:SetText("|cff33ff99" .. L["ON"]);			
			else
				FilterScrollButtons[count].state:SetText("|cffe60000" .. L["OFF"]);
			end

			FilterScrollButtons[count].blocked:SetText(PourSocialScoreDB.filterCount[index])

			FilterScrollButtons[count]:SetID(index)

			if FilterScrollSelect == index then
				FilterScrollButtons[count]:LockHighlight()
			else
				FilterScrollButtons[count]:UnlockHighlight()
			end

			FilterScrollButtons[count]:Show()
		else
			FilterScrollButtons[count]:Hide()
		end
	end
	for count = BUTTON_TOTAL + 1, #FilterScrollButtons do
		FilterScrollButtons[count]:Hide()
	end
end

----------------------------
-- TEMPLATE FALLBACK HELPERS --
----------------------------

-- Not every client build ships the same Blizzard templates (WoW Forever/Camelot
-- in particular).  These helpers try the known templates and fall back to a
-- minimal hand-built widget so the UI still opens.

local function PSS_TemplateExists(name)
	if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
		local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
		if ok then return info ~= nil end
	end
	return nil -- unknown; caller probes with pcall
end

local function PSS_TryTemplates(frameType, name, parent, templates)
	for _, template in ipairs(templates) do
		if PSS_TemplateExists(template) ~= false then
			local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
			if ok and frame then
				return frame
			end
		end
	end
	return nil
end

-- Row button for the ignore/filter lists.  Callers need: .name (FontString),
-- LockHighlight/UnlockHighlight, SetID, OnClick.
local function PSS_CreateListButton(parent)
	local templates = { "IgnoreListButtonTemplate", "FriendsFrameIgnoreButtonTemplate" }
	if V.wowIsClassic == true then
		templates = { "FriendsFrameIgnoreButtonTemplate", "IgnoreListButtonTemplate" }
	end

	local button = PSS_TryTemplates("Button", nil, parent, templates)

	if button and button.name then
		return button
	end
	if button then button:Hide() end -- template gave us something unusable

	button = CreateFrame("Button", nil, parent)
	button:SetSize(300, 16)

	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	button.name:SetPoint("LEFT", button, "LEFT", 6, 0)
	button.name:SetJustifyH("LEFT")
	button.name:SetWordWrap(false)

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints(button)
	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	highlight:SetBlendMode("ADD")
	button:SetHighlightTexture(highlight)

	return button
end

-- Put a list button's built-in name text into a header column.
function SortUI.placeName(button, hr, key)
	button.name:SetJustifyH("LEFT")
	button.name:SetWordWrap(false)
	if button.name.SetFontObject then button.name:SetFontObject("GameFontHighlight") end
	UI.TPlace(button.name, button, hr, key)   -- follows the column when resized
	if button.SetClipsChildren then button:SetClipsChildren(true) end
end

local function CreateFilterButtons()

	local hr = SortUI.filterHR
	for count = #FilterScrollButtons + 1, BUTTON_TOTAL do
		local b = PSS_CreateListButton(FilterScrollFrame:GetParent())
		FilterScrollButtons[count] = b
		if count == 1 then
			b:SetPoint("TOPLEFT", FilterScrollFrame, "TOPLEFT", 0, 0)
		else
			b:SetPoint("TOPLEFT", FilterScrollButtons[count - 1], "BOTTOMLEFT")
		end
		b:SetHeight(BUTTON_HEIGHT)
		b:SetPoint("RIGHT", FilterScrollFrame, "RIGHT", 0, 0)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", M.FilterScrollClick)
		SortUI.placeName(b, hr, "desc")
		b.state = UI.TCell(b, hr, "state")
		b.blocked = UI.TCell(b, hr, "blocked", "RIGHT")
		b.filter = UI.TCell(b, hr, "filter")
	end

	M.FilterListDrawUpdate(FilterScrollFrame)
end

-- Block History for the selected filter (every filter when none is selected).
function M.FilterScrollBlockHistory()
	if FilterScrollSelect and FilterScrollSelect > 0 and PourSocialScoreDB.filterDesc[FilterScrollSelect] ~= nil then
		Tab2BlockFilter = FilterScrollSelect
	else
		Tab2BlockFilter = nil
	end
	M.FilterScrollChangeState(2)
end

local function setEditable(box, editable)
	if not box then return end
	if box.SetEnabled then box:SetEnabled(editable)
	elseif editable then box:Enable() else box:Disable() end
	if not editable and box.ClearFocus then box:ClearFocus() end
	local c = editable and 1 or 0.5
	if box.SetTextColor then box:SetTextColor(c, c, c) end
end

-- Push the current Tab2Edit* values into the editor and lock it for built-in
-- rules (only the Active box stays usable). Called every time the editor is
-- (re)opened, including when it is already visible.
function M.PSS_RefreshFilterEditor()
	if not Tab2FrameEdit then return end
	local builtin = M.PSS_IsBuiltinFilter(FilterScrollSelect)
	if PSSFrame2EditDescField then PSSFrame2EditDescField:SetText(Tab2EditDesc or "") end
	if PSSFrame2EditFilterField then PSSFrame2EditFilterField.EditBox:SetText(Tab2EditFilter or "") end
	if PSSFrame2Active then PSSFrame2Active:SetChecked(Tab2EditActive == true) end
	setEditable(PSSFrame2EditDescField, not builtin)
	setEditable(PSSFrame2EditFilterField and PSSFrame2EditFilterField.EditBox, not builtin)
	if Tab2FrameEdit.TitleLabel then
		Tab2FrameEdit.TitleLabel:SetText(builtin and "Built-in Chat Filter (read only):" or "Chat Filter Editor:")
	end
	if Tab2FrameEdit.LockNote then Tab2FrameEdit.LockNote:SetShown(builtin) end
	if PSSFrame2EditSaveButton then PSSFrame2EditSaveButton:SetText(builtin and "Save On/Off" or "Save Filter") end
	if Tab2FrameEdit.InfoText then
		Tab2FrameEdit.InfoText:SetText(format(L["INFO_3"], (PourSocialScoreDB.filterCount[FilterScrollSelect] or 0)))
	end
end

function M.FilterScrollEditMenu()
	if PourSocialScoreDB.filterDesc[FilterScrollSelect] ~= nil then

		Tab2EditDesc   = PourSocialScoreDB.filterDesc[FilterScrollSelect]
		Tab2EditFilter = PourSocialScoreDB.filterList[FilterScrollSelect]
		Tab2EditActive = PourSocialScoreDB.filterActive[FilterScrollSelect]

		M.FilterScrollChangeState(1)
		M.PSS_RefreshFilterEditor()
	end
end

-- Copy any rule into a new custom (editable) rule and open it in the editor.
function M.PSS_CopySelectedFilter(index)
	index = index or FilterScrollSelect
	if not index or index <= 0 then return end
	local src = PourSocialScoreDB.filterDesc[index]
	if M.PSS_IsGuildRuleFilter(index) then
		M.ShowMsg("Guild rules can't be copied. Turn it on or off here; its guilds are on the Guild Ignore List.")
		return
	end
	local newIndex = M.PSS_CopyChatFilter(index)
	if not newIndex then return end
	FilterScrollSelect = newIndex
	M.FilterListDrawUpdate(FilterScrollFrame)
	M.ShowMsg(format("Copied \"%s\" to a new custom filter (starts Off). Edit it, tick Active and save.", tostring(src)))
	M.FilterScrollEditMenu()
end

function M.FilterScrollClick(self, button, down)

	if down == true then return end

	if FilterScrollSelect == self:GetID() and button == "LeftButton" then
		M.FilterScrollEditMenu()
		return
	elseif FilterScrollSelect ~= self:GetID() then
		FilterScrollSelect = self:GetID()
		M.FilterListDrawUpdate(FilterScrollFrame)
	end

	if button == "RightButton" then	
		MenuUtil.CreateContextMenu(UIParent,
			function(ownerRegion, root)
				local builtin = M.PSS_IsBuiltinFilter(FilterScrollSelect)
				local sel = FilterScrollSelect
				root:CreateTitle(L["RCM_10"] .. (builtin and " (built-in)" or ""))
				root:CreateDivider()
				root:CreateButton(builtin and "View filter" or L["RCM_11"],
					function()
						M.FilterScrollEditMenu()
					end
				)
				root:CreateButton(PourSocialScoreDB.filterActive[sel] and "Turn filter Off" or "Turn filter On",
					function()
						M.PSS_SetFilterActive(sel, not PourSocialScoreDB.filterActive[sel])
						M.FilterListDrawUpdate(FilterScrollFrame)
					end
				)
				if not M.PSS_IsGuildRuleFilter(sel) then
					root:CreateButton("Copy filter",
						function()
							M.PSS_CopySelectedFilter(sel)
						end
					)
				end
				if not builtin then
					root:CreateButton(L["RCM_12"],
						function()
							ButtonFilterRemove()
						end
					)
				end
				root:CreateDivider()				
				root:CreateButton(L["RCM_13"] .. " (" .. #(M.PSS_FilterHistory(FilterScrollSelect) or {}) .. ")",
					function()
						M.FilterScrollBlockHistory()
					end
				)
				root:CreateDivider()	
				root:CreateButton(L["RCM_14"],
					function()
						PourSocialScoreDB.filterCount[FilterScrollSelect] = 0
						M.PSSUpdateChatCount()
					end
				)
				root:CreateButton(L["RCM_15"],
					function()
						M.PSS_ResetFilterHistory(FilterScrollSelect)
					end
				)				
				root:CreateDivider()			
				root:CreateButton(L["RCM_5"],
					function()
					end)
			end
		)
	end
end

--------------------------
-- IGNORE LIST SCROLLER --
--------------------------

local function UpdateRuleSummaryTexts()
	-- nothing to show while the window is closed (this used to add up the
	-- whole list for every blocked line)
	if not (MainFrame and MainFrame:IsVisible()) then return end
	if Tab1Frame and M.PSS_GetPlayerBlockTotals then
		local sum = { total = 0, whisper = 0, partyInvite = 0, guildInvite = 0, partyRaid = 0, world = 0 }
		for i, name in ipairs(PourSocialScoreDB.ignoreList or {}) do
			if PourSocialScoreDB.typeList[i] == "player" and M.PSS_GetPlayerRecord(name) then
				local c = M.PSS_GetPlayerBlockCounts(name)
				for k in pairs(sum) do sum[k] = sum[k] + (c[k] or 0) end
			end
		end
		Tab1Frame.infotext:SetText(format(L["INFO_5"], sum.total))
		if Tab1Frame.infobreakdown and M.PSS_FormatGuildCounts then
			Tab1Frame.infobreakdown:SetText(M.PSS_FormatGuildCounts(sum))
		end
	end
	if Tab2Frame then
		local total = tonumber(PourSocialScoreDB.filterTotal) or 0
		local whispers = tonumber(PourSocialScoreDB.filterWhisperTotal) or 0
		local privateMessages = tonumber(PourSocialScoreDB.filterPrivateTotal) or 0
		Tab2Frame.infotext:SetText(format(L["INFO_4"], total, whispers, privateMessages))
	end
end

local function IgnoreListDrawUpdate (self)

	if Tab1Frame and Tab1Frame.histPanel and Tab1Frame.histPanel:IsShown() then
		for _, b in ipairs(IgnoreScrollButtons) do b:Hide() end
		UpdateRuleSummaryTexts()
		return
	end

	FauxScrollFrame_Update(self, #PourSocialScoreDB.ignoreList, IGNORE_ROWS, BUTTON_HEIGHT)

	if IgnoreScrollSelect > #PourSocialScoreDB.ignoreList then
		IgnoreScrollSelect = #PourSocialScoreDB.ignoreList
	end

	UpdateRuleSummaryTexts()

	local offset  = FauxScrollFrame_GetOffset(self)
	local index   = 0
	local id      = 0
	local pName   = ""
	local pServer = ""
	local pType   = ""
	local pExpire = ""
	local temp    = 0

	for count = 1, IGNORE_ROWS do
		id = count + offset

		if PourSocialScoreDB.ignoreList[id] then
			index = IgnoreScrollIndex[id] or id
			pName = PourSocialScoreDB.ignoreList[index]
			temp  = string.find(pName, "-", 1, true)

			if temp then
				pServer = M.prettyServer(string.sub(pName, temp + 1, string.len(pName)))
				pName   = string.sub(pName, 1, temp - 1)
			else
				pServer = "All"
			end

			if PourSocialScoreDB.typeList[index] == "player" then
				if PourSocialScoreDB.factionList[index] == "Alliance" then
					pType = "|cff335effAlliance"
				elseif PourSocialScoreDB.factionList[index] == "Horde" then
					pType = "|cffe60000Horde"
				else
					pType = "Unknown"
				end				  
			elseif PourSocialScoreDB.typeList[index] == "npc" then
				pType = "|cffffff99NPC"
			else
				pType = "|cffff66ccServer"
				pServer = M.prettyServer(pName)
				pName = "All"				
			end	

			local playerExp = (PourSocialScoreDB.expList[index] or 0)
			local daysExp   = playerExp - M.daysFromToday(PourSocialScoreDB.dateList[index])

			if playerExp == 0 then
				pExpire = "|cff808080"..L["EXP_NVR"]
			elseif daysExp <= 0 then
				pExpire = "|cffff6666"..L["EXP_TDY"]
			else
				pExpire = daysExp.."d"
			end

			IgnoreScrollButtons[count].name:SetText(pName)
			local rowPrefs = PourSocialScoreDB.typeList[index] == "player" and M.PSS_GetPlayerPrefs and M.PSS_GetPlayerPrefs(PourSocialScoreDB.ignoreList[index])
			if rowPrefs and rowPrefs.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[rowPrefs.class] then
				local c = RAID_CLASS_COLORS[rowPrefs.class]
				IgnoreScrollButtons[count].name:SetTextColor(c.r, c.g, c.b)
			else
				IgnoreScrollButtons[count].name:SetTextColor(1, 1, 1)
			end
			IgnoreScrollButtons[count].server:SetText(pServer)
			IgnoreScrollButtons[count].type:SetText(pType)
			IgnoreScrollButtons[count].listed:SetText(M.daysFromToday(PourSocialScoreDB.dateList[index]) .. "d")
			IgnoreScrollButtons[count].expire:SetText(pExpire)
			IgnoreScrollButtons[count].note:SetText("|cff69CCF0"..PourSocialScoreDB.notes[index])

			-- exclusions apply to players only (NPC / server rows have no switches)
			local isPlayer = PourSocialScoreDB.typeList[index] == "player"
			local prefs = isPlayer and M.PSS_GetPlayerPrefs and M.PSS_GetPlayerPrefs(PourSocialScoreDB.ignoreList[index])
			if prefs then
				UI.SetMetricCells(IgnoreScrollButtons[count].metrics, M.PSS_GetPlayerBlockCounts(prefs))
			else
				for _, fs in pairs(IgnoreScrollButtons[count].metrics) do fs:SetText("") end
			end
			for _, ex in ipairs(UI.EXCL) do
				local box = IgnoreScrollButtons[count].excl[ex.cat]
				box:SetShown(prefs and true or false)
				if prefs then box:SetChecked(UI.ExclChecked(prefs[ex.field] ~= false)) end
			end

			IgnoreScrollButtons[count]:SetID(id)

			if IgnoreScrollSelect == id then
				IgnoreScrollButtons[count]:LockHighlight()
			else
				IgnoreScrollButtons[count]:UnlockHighlight()
			end

			IgnoreScrollButtons[count]:Show()
		else
			IgnoreScrollButtons[count]:Hide()
		end
	end
	for count = IGNORE_ROWS + 1, #IgnoreScrollButtons do
		IgnoreScrollButtons[count]:Hide()
	end
end

local function CreateIgnoreButtons()

	local hr = SortUI.playerHR
	for count = #IgnoreScrollButtons + 1, IGNORE_ROWS do
		local b = PSS_CreateListButton(IgnoreScrollFrame:GetParent())
		IgnoreScrollButtons[count] = b
		if count == 1 then
			b:SetPoint("TOPLEFT", IgnoreScrollFrame, "TOPLEFT", 0, 0)
		else
			b:SetPoint("TOPLEFT", IgnoreScrollButtons[count - 1], "BOTTOMLEFT")
		end
		b:SetHeight(BUTTON_HEIGHT)
		b:SetPoint("RIGHT", IgnoreScrollFrame, "RIGHT", 0, 0)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", M.IgnoreScrollClick)

		SortUI.placeName(b, hr, "name")
		b.server = UI.TCell(b, hr, "server")
		b.type   = UI.TCell(b, hr, "type")
		b.listed = UI.TCell(b, hr, "listed", "RIGHT")
		b.expire = UI.TCell(b, hr, "expire", "RIGHT")
		b.note   = UI.TCell(b, hr, "note")
		b.metrics = UI.CreateMetricCells(b, hr)

		-- W I G P C (ticked = allowed; the record stores *Blocked)
		b.excl = UI.CreateExclusionBoxes(b, hr, "excl", function(box, cat)
			local rowIndex = b:GetID()
			local idx = IgnoreScrollIndex[rowIndex] or rowIndex
			local name = PourSocialScoreDB.ignoreList[idx]
			if name and M.PSS_SetPlayerSetting then M.PSS_SetPlayerSetting(name, UI.EXCL_BY_CAT[cat].field, UI.ExclBlocked(box)) end
			if M.PSS_RefreshPlayerDetail then M.PSS_RefreshPlayerDetail() end
		end)
	end

	IgnoreListDrawUpdate(IgnoreScrollFrame)
end

function M.IgnoreScrollDoubleClick()
	local idx = IgnoreScrollIndex[IgnoreScrollSelect]
	local name = idx and PourSocialScoreDB.ignoreList[idx]
	if name and M.PSS_ShowPlayerDetail then
		M.PSS_ShowPlayerDetail(name)
	end
end

function M.IgnoreScrollClick(self, button, down)

	if down == true then return end

	if IgnoreScrollSelect == self:GetID() and button == "LeftButton" then
		M.IgnoreScrollDoubleClick()
		return
	elseif IgnoreScrollSelect ~= self:GetID() then
		IgnoreScrollSelect = self:GetID()
		IgnoreListDrawUpdate(IgnoreScrollFrame)
	end

	if button == "RightButton" then	
		V.nameUI = PourSocialScoreDB.ignoreList[IgnoreScrollIndex[IgnoreScrollSelect]]

		MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
			root:CreateTitle(V.nameUI)
			root:CreateDivider()
			root:CreateButton(L["RCM_1"],
				function()
					M.IgnoreScrollDoubleClick()
				end)
			root:CreateDivider()
			root:CreateButton(L["RCM_2"],
				function()
					StaticPopup_Show("PSS_EXPIRE", V.nameUI)
				end)
			root:CreateButton(L["RCM_3"],
				function()
					PourSocialScoreDB.expList[IgnoreScrollIndex[IgnoreScrollSelect]] = 0
					M.PSSUpdateUI()
				end)
			root:CreateDivider()
			local playerHistoryCount = 0
			if M.PSS_GetPlayerPrefs then
				local prefs = M.PSS_GetPlayerPrefs(V.nameUI)
				local key = prefs and M.PSS_PlayerHistoryKey and M.PSS_PlayerHistoryKey(prefs)
				playerHistoryCount = key and M.PSS_History.CountFor(key) or 0
			end
			root:CreateButton(L["HISTORY_PLAYER"] .. " (" .. playerHistoryCount .. ")",
				function()
					if M.PSS_ShowPlayerBlockHistory then M.PSS_ShowPlayerBlockHistory(V.nameUI) end
				end)
			root:CreateButton(L["HISTORY_RESET"],
				function()
					if M.PSS_ResetPlayerBlockHistory then M.PSS_ResetPlayerBlockHistory(V.nameUI) end
				end)
			do
				local ri = IgnoreScrollIndex[IgnoreScrollSelect]
				local p = (PourSocialScoreDB.typeList[ri] == "player") and M.PSS_GetPlayerPrefs and M.PSS_GetPlayerPrefs(V.nameUI)
				if p and M.PSS_AddOverrideMenu then
					M.PSS_AddOverrideMenu(root, p, "person", function() IgnoreListDrawUpdate(IgnoreScrollFrame) end)
				end
			end
			root:CreateDivider()
			root:CreateButton(L["RCM_4"],
				function()
					ButtonIgnoreRemove()
				end)
			root:CreateDivider()
			root:CreateButton(L["RCM_5"],
				function()					
				end)			
		end)
	end
end

------------------------------
-- COLUMN SORTING FUNCTIONS --
------------------------------

local function elementName (num)

	local type = PourSocialScoreDB.typeList[num]

	if type == "player" or type == "npc" then
		return M.removeServer(PourSocialScoreDB.ignoreList[num], true)
	elseif type == "server" then
		return "All"
	else
		return ""
	end
end

local function elementServer (num)

	local type = PourSocialScoreDB.typeList[num]

	if type == "player" then
		return M.getServer(PourSocialScoreDB.ignoreList[num])
	elseif type == "server" then
		return PourSocialScoreDB.ignoreList[num]
	elseif type == "npc" then
		return "All"
	else
		return ""
	end
end

local function elementType(num)

	local type = PourSocialScoreDB.typeList[num]

	if type == "player" then
		return PourSocialScoreDB.factionList[num]
	else
		return type
	end
end

-- Player Ignore List sorting: one key + direction. Every column is sortable
-- (Name, Server, Type, Listed, Expire, Notes and each W I G P C box). The
-- list opens sorted by name A-Z; ties always fall back to name A-Z.
SortUI.ignoreKey, SortUI.ignoreAsc = "name", true

local function playerSortValue(i, key)
	local db = PourSocialScoreDB
	if key == "name" then return string.lower(elementName(i) or "")
	elseif key == "server" then return string.lower(elementServer(i) or "")
	elseif key == "type" then return string.lower(elementType(i) or "")
	elseif key == "listed" then return M.daysFromToday(db.dateList[i]) or 0
	elseif key == "expire" then
		local e = tonumber(db.expList[i]) or 0
		if e == 0 then return math.huge end            -- never expires: after everything
		return e - (M.daysFromToday(db.dateList[i]) or 0)
	elseif key == "note" then
		local n = string.lower(db.notes[i] or "")
		return n == "" and nil or n                     -- empty notes go last
	end
	-- block metrics ("metric:<cat>"; players only - NPC / server rows go last)
	local mcat = key:match("^metric:(.+)$")
	if mcat then
		if db.typeList[i] ~= "player" then return nil end
		local p = M.PSS_GetPlayerRecord and M.PSS_GetPlayerRecord(db.ignoreList[i])
		return p and (tonumber(M.PSS_GetPlayerBlockCounts(p)[mcat]) or 0) or 0
	end
	-- W I G P C ("excl:<cat>"; players only - NPC / server rows go last)
	local cat = key:match("^excl:(.+)$")
	local ex = cat and UI.EXCL_BY_CAT[cat]
	if ex then
		if db.typeList[i] ~= "player" then return nil end
		local p = M.PSS_GetPlayerRecord and M.PSS_GetPlayerRecord(db.ignoreList[i])
		return UI.ExclChecked(not p or p[ex.field] ~= false) and 1 or 0   -- by tick (allowed)
	end
	return 0
end

local function updatePlayerSortArrows()
	if SortUI.playerHR then SortUI.playerHR:SetSort(SortUI.ignoreKey, SortUI.ignoreAsc) end
end

-- (sortType is ignored; kept so existing callers still work)
local function createSortedIndex (sortType)
	local db = PourSocialScoreDB
	-- keep the selected entry selected after re-sorting
	local selectedEntry = IgnoreScrollSelect > 0 and IgnoreScrollIndex[IgnoreScrollSelect] or nil

	V.needSorted		= false
	IgnoreScrollIndex	= {}
	IgnoreScrollType	= 1

	local key, asc = SortUI.ignoreKey, SortUI.ignoreAsc
	local sv, nv, srv = {}, {}, {}
	for i = 1, #db.ignoreList do
		IgnoreScrollIndex[i] = i
		sv[i] = playerSortValue(i, key)
		nv[i] = string.lower(elementName(i) or "")
		srv[i] = string.lower(elementServer(i) or "")
	end

	table.sort(IgnoreScrollIndex, function(a, b)
		local A, B = sv[a], sv[b]
		if A ~= B then
			if A == nil then return false end        -- blanks always last
			if B == nil then return true end
			if asc then return A < B else return A > B end
		end
		if nv[a] ~= nv[b] then return nv[a] < nv[b] end
		if srv[a] ~= srv[b] then return srv[a] < srv[b] end
		return a < b
	end)

	if selectedEntry then
		for pos, i in ipairs(IgnoreScrollIndex) do
			if i == selectedEntry then IgnoreScrollSelect = pos break end
		end
	end

	updatePlayerSortArrows()
	if (IgnoreScrollFrame ~= nil) then
		IgnoreListDrawUpdate(IgnoreScrollFrame)
	end
end

function SortUI.setPlayerSort(key)
	if SortUI.ignoreKey == key then
		SortUI.ignoreAsc = not SortUI.ignoreAsc
	else
		SortUI.ignoreKey, SortUI.ignoreAsc = key, true
	end
	createSortedIndex()
end

--------------------
-- LINK CONVERTER --
----------------------------------------
-- LINK CONVERTER --
--------------------

local function convertLink (text)

	if text == nil or text == "" then
		return "UNKNOWN"
	end

	local temp = string.match(text, "|Hitem:(%d+)")
	if temp then
		return "[item=".. temp .. "]"
	end

	temp = string.match(text, "|Hspell:(%d+)")
	if temp then
		return "[spell=".. temp.."]"
	end

	temp = string.match(text, "|Htalent:(%d+)")
	if temp then
		return "[talent=" .. temp .. "]"
	end

	temp = string.match(text, "|Hachievement:(%d+)")
	if temp then
		return "[achievement=".. temp .. "]"
	end

	temp = string.match(text, "|Hbattlepet:(%d+)")
	if temp then
		return "[pet=" .. temp .. "]"
	end

	temp = string.match(text, "|Hjournal:(%d+)")
	if temp then
		return "[journal]"
	end

	if string.match(text, "|Htrade:") then
		return "[trade]"
	end

	if string.match(text, "|Hclubfinder:") then
		return "[guild]"
	end

	if string.match(text, "|Hclubticket:") then
		return "[community]"
	end

	return "UNKNOWN"
end

---------------------
-- TAB BUTTON HELPERS --
---------------------

-- Tab button templates differ between client builds (Mainline, Classic-family,
-- WoW Forever/Camelot).  Use the first one that actually exists instead of
-- hard-coding CharacterFrameTabButtonTemplate, which is missing on some builds.
local TAB_TEMPLATES = {
	"PanelTabButtonTemplate",
	"CharacterFrameTabButtonTemplate",
	"CharacterFrameTabTemplate",
	"TabButtonTemplate",
}

local function templateExists(name)
	if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
		local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
		if ok then return info ~= nil end
	end
	return nil -- unknown, caller must probe with pcall
end

local function createTabButton(name, parent)
	for _, template in ipairs(TAB_TEMPLATES) do
		if templateExists(template) ~= false then
			local ok, frame = pcall(CreateFrame, "Button", name, parent, template)
			if ok and frame then
				frame.PSS_UsesPanelTab = (frame.Left ~= nil or _G[name .. "Left"] ~= nil)
				return frame
			end
		end
	end

	-- Last resort: a plain button, so the UI still works with no tab template.
	local frame = UI.Button(parent, nil, 110, 24, name)
	frame.PSS_UsesPanelTab = false
	return frame
end

local function setActiveTab(mainFrame, id)
	local ok = false
	if PanelTemplates_SetTab then
		ok = pcall(PanelTemplates_SetTab, mainFrame, id)
	end
	if not ok then
		-- Manual fallback: disable the active tab button, enable the others.
		local tabs = {
			[1] = _G["PSSTab1"],
			[2] = _G["PSSTabGuild"],
			[3] = _G["PSSTab2"],
			[4] = _G["PSSTabIO"],
			[5] = _G["PSSTab3"],
		}
		for i = 1, 5 do
			local tab = tabs[i]
			if tab then
				if i == id then tab:Disable() else tab:Enable() end
			end
		end
	end
end

------------------------
-- WINDOW RESIZE LAYOUT --
------------------------

-- Resize a createColumn() header, including its stretchy middle texture.
-- Called whenever the main window changes size. The tab panels are anchored
-- to the window's edges, so they stretch on their own; this recalculates the
-- things that depend on the panel size: how many list rows fit, the scroll
-- frame heights and the width of the last (stretchy) column in each list.
local function RelayoutMainFrame()
	if not MainFrame or not Tab1Frame or not Tab2Frame then return end

	local tabW = Tab1Frame:GetWidth() or 0
	local tabH = Tab1Frame:GetHeight() or 0
	if tabW <= 0 or tabH <= 0 then return end

	-- Player Ignore List rows
	IGNORE_ROWS = math.max(1, math.floor((tabH - UI.LIST_TOP - 4) / BUTTON_HEIGHT))
	IgnoreScrollFrame:SetHeight(IGNORE_ROWS * BUTTON_HEIGHT)
	CreateIgnoreButtons()

	-- Chat Filter rows; the Filter column takes up any extra width
	BUTTON_TOTAL = math.max(1, math.floor((tabH - UI.LIST_TOP - 4) / BUTTON_HEIGHT))
	FilterScrollFrame:SetHeight(BUTTON_TOTAL * BUTTON_HEIGHT)
	CreateFilterButtons()
	-- the Filter column takes up any extra width; drags stay inside the panel
	if SortUI.filterHR then SortUI.filterHR:SetAvailableWidth(tabW - 28) end
	if SortUI.playerHR then SortUI.playerHR:SetAvailableWidth(tabW - 28) end
end

---------------------
-- BUILD UI FRAMES --
---------------------
-- Every page uses the shared look from PSS_UIKit.lua (the Player Ignore
-- List design): a summary block at the top of the panel, Who-style column
-- headers at UI.HEADER_Y, 20 px rows from UI.LIST_TOP, buttons on the bar
-- under the panel.

local function newPanel(name, parent)
	local f = CreateFrame("Frame", name, parent, "InsetFrameTemplate")
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -84)
	f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -11, 29)
	return f
end

local function tip(owner, title, text)
	owner:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(title, 1, 1, 1)
		if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
		GameTooltip:Show()
	end)
	owner:SetScript("OnLeave", UI.HideTip)
end

------------------------------------------------------------ player list
local function BuildPlayerTab()
	Tab1Frame = newPanel("PSSFrame1", MainFrame)

	Tab1Frame:SetScript("OnShow",
		function(self)
			UpdateRuleSummaryTexts()
			-- always open on the list, sorted by name A-Z
			if self.closeHistoryPanel then self.closeHistoryPanel() end
			SortUI.ignoreKey, SortUI.ignoreAsc = "name", true
			createSortedIndex()
		end)

	Tab1Frame.title, Tab1Frame.infotext, Tab1Frame.infobreakdown = UI.CreateSummary(Tab1Frame, "Player Ignore List")

	-- Top right: [ Add a Player... ] [Player Search] [Add Player]
	-- (the EntryRow widget, PSS_Widgets.lua; the same as the guild tab)
	local W = M.Widgets
	local LIST_NAME = "Player Ignore List"

	local function say(msg)
		if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("PSS: " .. msg) end
	end

	-- your target, when it is another player of your faction
	local function targetName()
		local target = "target"
		if UnitExists(target) and UnitIsPlayer(target) and not UnitIsUnit(target, "player") and
			UnitFactionGroup(target) == UnitFactionGroup("player") then
			local name, realm = UnitFullName(target)
			if name then return name .. ((realm and realm ~= "") and ("-" .. realm) or "") end
		end
		return nil
	end

	local function addPlayer(name)
		M.PSS_AddPlayer(name, "", 0)
	end

	-- Player Search results: tick the players to add
	local function showResults(players, query)
		if #players == 0 then
			W.PromptAddAnyway(query, { what = "player", listName = LIST_NAME, add = addPlayer, say = say })
			return
		end
		local items = {}
		for _, p in ipairs(players) do
			items[#items + 1] = {
				cells  = { name = p.name, level = p.level or "", class = p.class or "", guild = p.guild or "" },
				value  = p.name,
				listed = M.PSS_IsPlayerListed(p.name),
			}
		end
		W.Picker({
			name     = "PSSPlayerSearchFrame",
			saveKey  = "playerSearch",
			title    = "Player Search Results",
			subtitle = ("%d player(s) found for \"%s\"."):format(#players, query),
			columns  = {
				{ key = "name",  text = "Name",  width = 150 },
				{ key = "level", text = "Level", width = 50 },
				{ key = "class", text = "Class", width = 90 },
				{ key = "guild", text = "Guild", width = 120 },
			},
			items    = items,
			onSave   = function(names)
				for _, name in ipairs(names) do addPlayer(name) end
				say(("%d player(s) added to the %s."):format(#names, LIST_NAME))
			end,
		})
	end

	local function search(text)
		return M.PSS_PlayerSearch(text, showResults)
	end

	local entry = W.EntryRow(Tab1Frame, {
		searchText = "Player Search",
		addText    = "Add Player",
		hint       = "Add a Player...",
		listName   = LIST_NAME,
		emptyMsg   = "Type a player name in the box next to Player Search first (or target a player for Add Player).",
		searchTip  = {
			"Runs a /who for the name in the box and lists the players found, so you can tick which to add. If nobody is found you can add the name anyway.",
			"Name, Name-Realm, or First Last-Realm. /who can't search by realm, so only the name is searched for.",
		},
		addTip     = "Adds the name typed in the box (you are asked first: Okay adds it without searching, Search runs Player Search instead). With the box empty, adds your target if it is a player of your faction.",
		isListed   = function(name) return M.PSS_IsPlayerListed(name) end,
		add        = addPlayer,
		search     = search,
		canSend    = function() return not M.Whois.BlockedMsg() end,
		onEmptyAdd = function()
			local name = targetName()
			if not name then return false end
			M.PSS_AddPlayer(name, "", 0, "target")
			return true
		end,
		say        = say,
		names      = { box = "PSSFrame1SearchBox", search = "PSSFrame1SearchButton", add = "PSSFrame1AddPlayerButton" },
	})
	UI.RegisterWhoisButton(entry.search)
	Tab1Frame.searchBox = entry.box

	-- older name: add a name (asks first) or, with none, your target
	M.PSS_AddPlayerPrompt = function(name)
		name = name and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
		if name == "" then
			local target = targetName()
			if target then M.PSS_AddPlayer(target, "", 0, "target") end
			return
		end
		W.PromptAdd(name, {
			listName = LIST_NAME, add = addPlayer, search = search, say = say,
			canSend = function() return not M.Whois.BlockedMsg() end,
		})
	end

	SortUI.playerHR = UI.CreateHeaderRow(Tab1Frame, SortUI.PLAYER_COLUMNS, 1, UI.HEADER_Y, SortUI.setPlayerSort, { id = "players" })
	Tab1Frame.headers = SortUI.playerHR.headers

	IgnoreScrollFrame = CreateFrame("ScrollFrame", "PSSIgnoreScrollFrame", Tab1Frame, "FauxScrollFrameTemplate")
	IgnoreScrollFrame:SetHeight(IGNORE_ROWS * BUTTON_HEIGHT)
	IgnoreScrollFrame:SetPoint("TOPLEFT", 1, -UI.LIST_TOP)
	IgnoreScrollFrame:SetPoint("RIGHT", Tab1Frame, "RIGHT", -27, 0)
	IgnoreScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, BUTTON_HEIGHT, IgnoreListDrawUpdate)
	end)

	CreateIgnoreButtons()

	-- bottom bar: Remove (right), Prune, Block History
	local Button1 = UI.BarButton(Tab1Frame, L["BUT_1"], nil, nil, "PSSFrame1IgnoreButton")
	Button1:SetScript("OnClick", function() ButtonIgnoreRemove() end)
	local Button2 = UI.BarButton(Tab1Frame, L["BUT_8"], Button1, nil, "PSSFrame1PruneButton")
	Button2:SetScript("OnClick", function() StaticPopup_Show("PSS_PRUNE", L["BOX_12"]) end)
	local Button3 = UI.BarButton(Tab1Frame, L["BUT_9"] or "Block History", Button2, nil, "PSSFrame1BlockHistoryButton")
	tip(Button3, "Block History", "Click a player first to see only that player. With no player selected, every player's history is shown.")
	Tab1Frame.listButtons = { Button1, Button2, Button3 }

	-- Block History in place of the list: the shared panel (PSS_ChatHistory.lua)
	local History = M.PSS_History
	local function setListShown(shown)
		SortUI.playerHR:SetShown(shown)
		IgnoreScrollFrame:SetShown(shown)
		for _, b in ipairs(Tab1Frame.listButtons) do b:SetShown(shown) end
		if not shown then
			for _, b in ipairs(IgnoreScrollButtons) do b:Hide() end
		else
			IgnoreListDrawUpdate(IgnoreScrollFrame)
		end
	end
	local function listedPlayers()
		local out = {}
		for i, n in ipairs(PourSocialScoreDB.ignoreList or {}) do
			if PourSocialScoreDB.typeList[i] == "player" then out[#out + 1] = n end
		end
		return out
	end
	local hist = History.CreatePanel(Tab1Frame, {
		baseTitle = "Player Ignore List",
		allText = "all players", allButton = "All Players",
		setListShown = setListShown,
		entries = function(name)
			if name then return M.PSS_GetPlayerBlockHistory(name) end
			-- every listed player's lines, from the shared log
			local keys = {}
			for _, n in ipairs(listedPlayers()) do
				local k = M.PSS_PlayerHistoryKey(n)
				if k then keys[k] = true end
			end
			return History.Collect(function(h) return keys[h.o] == true end)
		end,
		label = function(name) return (M.hasGlobalIgnored(name) > 0) and name or nil end,
		reset = function(name)
			if name then
				M.PSS_ResetPlayerBlockHistory(name)
			else
				for _, n in ipairs(listedPlayers()) do
					if M.PSS_GetPlayerRecord(n) then M.PSS_ResetPlayerBlockHistory(n) end
				end
			end
		end,
		extra = { text = "Player Details", onClick = function(name) if name and M.PSS_ShowPlayerDetail then M.PSS_ShowPlayerDetail(name) end end,
					shown = function(name) return name ~= nil end },
	})
	Tab1Frame.histPanel = hist
	Tab1Frame.updateHistoryPanel = function(resetScroll) hist:Refresh(resetScroll) end
	Tab1Frame.showHistoryPanel = function(name) hist:Open(name) end
	Tab1Frame.closeHistoryPanel = function() hist:Close() end

	Button3:SetScript("OnClick", function()
		local idx = IgnoreScrollSelect > 0 and IgnoreScrollIndex[IgnoreScrollSelect]
		local name = idx and PourSocialScoreDB.typeList[idx] == "player" and PourSocialScoreDB.ignoreList[idx] or nil
		hist:Open(name)
	end)

	createSortedIndex()
end

------------------------------------------------------------ chat filters
local function BuildFilterTab()
	Tab2Frame = newPanel("PSSFrame2", MainFrame)
	Tab2Frame:Hide()
	Tab2Frame:SetScript("OnShow",
		function(self)
			if not self.keepSort then SortUI.filterKey, SortUI.filterAsc = "desc", true end
			self.keepSort = nil
			UpdateRuleSummaryTexts()
			M.FilterListDrawUpdate(FilterScrollFrame) -- update filter count display
		end)

	Tab2Frame.title, Tab2Frame.infotext, Tab2Frame.infobreakdown = UI.CreateSummary(Tab2Frame, "Chat Filters", 700)

	SortUI.filterHR = UI.CreateHeaderRow(Tab2Frame, SortUI.FILTER_COLUMNS, 1, UI.HEADER_Y, SortUI.setFilterSort, { id = "filters" })

	FilterScrollFrame = CreateFrame("ScrollFrame", "PSSFilterScrollFrame", Tab2Frame, "FauxScrollFrameTemplate")
	FilterScrollFrame:SetHeight(BUTTON_TOTAL * BUTTON_HEIGHT)
	FilterScrollFrame:SetPoint("TOPLEFT", 1, -UI.LIST_TOP)
	FilterScrollFrame:SetPoint("RIGHT", Tab2Frame, "RIGHT", -27, 0)
	FilterScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, BUTTON_HEIGHT, M.FilterListDrawUpdate)
	end)

	CreateFilterButtons()

	-- bottom bar: Create (right), Remove, Block History, Copy ... Reset (left)
	local create = UI.BarButton(Tab2Frame, L["BUT_5"], nil, nil, "PSSFrame2CreateButton")
	create:SetScript("OnClick", function()
		local idx = #PourSocialScoreDB.filterList + 1
		PourSocialScoreDB.filterList[idx]			= "[word=NewChatFilter]"
		PourSocialScoreDB.filterDesc[idx]			= "New Chat Filter"
		PourSocialScoreDB.filterCount[idx]			= 0
		PourSocialScoreDB.filterActive[idx]			= false
		PourSocialScoreDB.filterID[idx]				= ""
		PourSocialScoreDB.filterBlocked[idx]		= {}
		PourSocialScoreDB.filterBlockedLast[idx]	= 0
		FilterScrollSelect = idx
		M.FilterListDrawUpdate(FilterScrollFrame)
	end)
	local remove = UI.BarButton(Tab2Frame, L["BUT_6"], create, nil, "PSSFrame2RemoveButton")
	remove:SetScript("OnClick", function() ButtonFilterRemove() end)
	local block = UI.BarButton(Tab2Frame, L["BUT_9"], remove, nil, "PSSFrame2BlockButton")
	block:SetScript("OnClick", function() M.FilterScrollBlockHistory() end)
	local copy = UI.BarButton(Tab2Frame, "Copy Filter", block, nil, "PSSFrame2CopyButton")
	copy:SetScript("OnClick", function() M.PSS_CopySelectedFilter() end)
	local reset = UI.BarButtonLeft(Tab2Frame, L["BUT_7"], nil, nil, "PSSFrame2ResetButton")
	reset:SetScript("OnClick", function() StaticPopup_Show("PSS_FILTERRESET", L["BOX_4"]) end)
	local listButtons = { create, remove, block, copy, reset }

	-- Block History in place of the list: the shared panel (PSS_ChatHistory.lua)
	local History = M.PSS_History
	local function setListShown(shown)
		SortUI.filterHR:SetShown(shown)
		FilterScrollFrame:SetShown(shown)
		for _, b in ipairs(listButtons) do b:SetShown(shown) end
		if not shown then
			for _, b in ipairs(FilterScrollButtons) do b:Hide() end
		else
			M.FilterListDrawUpdate(FilterScrollFrame)
		end
	end
	local hist = History.CreatePanel(Tab2Frame, {
		baseTitle = "Chat Filters",
		allText = "all filters", allButton = "All Filters",
		setListShown = setListShown,
		entries = function(i)
			local db = PourSocialScoreDB
			if i then return M.PSS_FilterHistory(i) or {} end
			-- every filter's lines (and the guild rules' group lines), labelled
			local byKey, byRule = {}, {}
			for n = 1, #db.filterList do
				local label = "Filter: " .. tostring(db.filterDesc[n] or n)
				byKey[M.PSS_FilterOwnerKey(n)] = label
				local id = db.filterID[n]
				if id and id ~= "" and M.PSS_IsGuildRuleText(db.filterList[n]) then byRule[id] = label end
			end
			return History.Collect(function(h)
				local l = byKey[h.o] or (h.r and byRule[h.r])
				if l then History.SetSource(h, l) return true end
				return false
			end)
		end,
		label = function(i) return PourSocialScoreDB.filterDesc[i] end,
		reset = function(i)
			if i then
				M.PSS_ResetFilterHistory(i)
			else
				for n = 1, #PourSocialScoreDB.filterList do M.PSS_ResetFilterHistory(n) end
			end
		end,
		extra = { text = L["BUT_11"] or "Edit Filter",
					onClick = function(i) if i then FilterScrollSelect = i; M.FilterScrollEditMenu() end end,
					shown = function(i) return i ~= nil end },
	})
	Tab2Frame.histPanel = hist
	hist:HookScript("OnHide", function() if Tab2FrameState == 2 then Tab2FrameState = 0 end end)
end

------------------------------------------------------------ filter editor
local function BuildFilterEditor()
	Tab2FrameEdit = newPanel("PSSFrame2Edit", MainFrame)
	Tab2FrameEdit:Hide()
	Tab2FrameEdit:SetScript("OnShow", function(self)
		self.InfoText:SetText(format(L["INFO_3"], (PourSocialScoreDB.filterCount[FilterScrollSelect] or 0)))
	end)

	local title, info = UI.CreateSummary(Tab2FrameEdit, "Chat Filter Editor")
	Tab2FrameEdit.TitleLabel = title
	Tab2FrameEdit.InfoText = info

	local histBtn = UI.TopButton(Tab2FrameEdit, L["BUT_9"] or "Block History", nil, 110)
	histBtn:SetScript("OnClick", function() M.FilterScrollBlockHistory() end)

	-- bottom bar: Cancel (right), Save, Copy
	local cancel = UI.BarButton(Tab2FrameEdit, "Cancel", nil, nil, "PSSFrame2EditCancelButton")
	cancel:SetScript("OnClick", function() M.FilterScrollChangeState(0) end)
	local save = UI.BarButton(Tab2FrameEdit, "Save Filter", cancel, nil, "PSSFrame2EditSaveButton")
	save:SetScript("OnClick", function()
		if M.PSS_IsBuiltinFilter(FilterScrollSelect) then
			-- built-in rules: only the on/off state can change
			PourSocialScoreDB.filterActive[FilterScrollSelect] = Tab2EditActive
			M.FilterScrollChangeState(0)
			return
		end
		Tab2EditDesc   = PSSFrame2EditDescField:GetText()
		Tab2EditFilter = PSSFrame2EditFilterField.EditBox:GetText()
		PourSocialScoreDB.filterDesc[FilterScrollSelect] = Tab2EditDesc
		PourSocialScoreDB.filterList[FilterScrollSelect] = Tab2EditFilter
		PourSocialScoreDB.filterActive[FilterScrollSelect] = Tab2EditActive
		M.FilterScrollChangeState(0)
	end)
	local copy = UI.BarButton(Tab2FrameEdit, "Copy Filter", save, nil, "PSSFrame2EditCopyButton")
	copy:SetScript("OnClick", function() M.PSS_CopySelectedFilter() end)

	Tab2FrameEdit.LockNote = Tab2FrameEdit:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	Tab2FrameEdit.LockNote:SetPoint("BOTTOMLEFT", Tab2FrameEdit, "BOTTOMLEFT", 4, -18)
	Tab2FrameEdit.LockNote:SetText("Built-in filters are read only. Use Copy Filter to make an editable custom version.")
	Tab2FrameEdit.LockNote:Hide()

	local function label(text, x, y, name)
		local fs = Tab2FrameEdit:CreateFontString(name, "OVERLAY", "GameFontNormal")
		fs:SetPoint("TOPLEFT", x, y)
		fs:SetText(text)
		return fs
	end
	local function helpButton(anchor, text, tipText, name)
		local b = UI.Button(Tab2FrameEdit, text or "Help", 44, UI.ROW_BUTTON_H, name)
		b:SetNormalFontObject("GameFontNormalSmall")
		b:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
		if tipText then
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self)
				GameTooltip:ClearLines()
				GameTooltip:AddLine(tipText)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", UI.HideTip)
		end
		return b
	end

	-- Active + Description
	local activeText = label("Active:", 10, -58, "PSSFrame2ActiveText")
	local active = UI.Check(Tab2FrameEdit)
	_G["PSSFrame2Active"] = active
	active:SetPoint("LEFT", activeText, "RIGHT", 4, 0)
	active:SetScript("OnShow",  function(self) self:SetChecked(Tab2EditActive == true) end)
	active:SetScript("OnClick", function(self) Tab2EditActive = (self:GetChecked() or false) end)

	local descText = label("Description:", 110, -58, "PSSFrame2EditDescText")
	local desc = UI.InputBox(Tab2FrameEdit, nil, 20, "PSSFrame2EditDescField")
	desc:SetPoint("LEFT", descText, "RIGHT", 12, 0)
	desc:SetPoint("RIGHT", Tab2FrameEdit, "RIGHT", -20, 0)
	desc:SetScript("OnShow",	      function(self) self:SetText(Tab2EditDesc) end)
	desc:SetScript("OnEnterPressed",  function(self) Tab2EditDesc = self:GetText() self:ClearFocus() end)
	desc:SetScript("OnEscapePressed", function(self) self:SetText(Tab2EditDesc) self:ClearFocus() end)

	-- Filter text
	local filterText = label("Filter:", 10, -92, "PSSFrame2EditFilterText")
	helpButton(filterText, "Help", L["TIP_1"], "PSSFrame2EditFilterHelp")
	local field = UI.TextArea(Tab2FrameEdit, "PSSFrame2EditFilterField", 1000)
	field:SetPoint("TOPLEFT", 16, -112)
	field:SetPoint("RIGHT", Tab2FrameEdit, "RIGHT", -24, 0)
	field:SetHeight(60)
	field.EditBox:SetWidth(800)
	field.EditBox:SetScript("OnShow",		   function(self) self:SetText(Tab2EditFilter) end)
	field.EditBox:SetScript("OnEnterPressed",  function(self) Tab2EditFilter = self:GetText() self:ClearFocus() end)
	field.EditBox:SetScript("OnEscapePressed", function(self) self:SetText(Tab2EditFilter) self:ClearFocus() end)

	-- Filter testing (bottom left)
	local testText = Tab2FrameEdit:CreateFontString("PSSFrame2EditTestText", "OVERLAY", "GameFontNormal")
	testText:SetPoint("BOTTOMLEFT", Tab2FrameEdit, "BOTTOMLEFT", 10, 94)
	testText:SetText("Filter Testing:")
	local testHelp = helpButton(testText, "Help", L["TIP_2"], "PSSFrame2EditTestHelp")
	local testBtn = helpButton(testHelp, "Test", nil, "PSSFrame2EditTestTest")
	testBtn:SetPoint("LEFT", testHelp, "RIGHT", 4, 0)
	local result = Tab2FrameEdit:CreateFontString("PSSFrame2EditTestResult", "OVERLAY", "GameFontHighlight")
	result:SetPoint("LEFT", testBtn, "RIGHT", 10, 0)
	result:SetWidth(120)
	result:SetJustifyH("LEFT")
	result:SetText("")

	local test = UI.TextArea(Tab2FrameEdit, "PSSFrame2EditTestField", 500, nil, 20)
	test:SetPoint("TOPLEFT", testText, "BOTTOMLEFT", 6, -8)
	test:SetSize(400, 60)
	test.EditBox:SetWidth(380)
	test.EditBox:SetScript("OnTextChanged", function(self) result:SetText("") end)

	testBtn:SetScript("OnClick", function()
		local chatStr   = string.lower(test.EditBox:GetText())
		local filterStr = field.EditBox:GetText()
		local res = M.filterComplex(filterStr, chatStr, 1)
		if V.lastFilterError == true then
			result:SetText("|cffffff00FILTER ERROR")
		elseif res == true then
			result:SetText("|cffff5c5cBLOCKED")
		else
			result:SetText("|cff00ff96PASSED")
		end
	end)

	-- Chat link converter (bottom right)
	local linkText = Tab2FrameEdit:CreateFontString("PSSFrame2EditLinkText", "OVERLAY", "GameFontNormal")
	linkText:SetPoint("BOTTOMRIGHT", Tab2FrameEdit, "BOTTOMRIGHT", -140, 94)
	linkText:SetText("Chat Link Converter:")
	helpButton(linkText, "Help", "|cffffffffChat Link Converter Help\n\n|cffffff00Enter a chat link into the input box, then press the Enter key.  If the link is valid\nit will be converted into a [tag] used by the chat filter system.\n\nConverted text will automatically be selected so it can be copied and pasted\nusing the copy and paste hotkeys.\n\nLinking items directly into the filter editor box will also automatically convert\nthe link to a PSS format [tag] without using this conversion tool.", "PSSFrame2EditLinkHelp")
	local link = UI.InputBox(Tab2FrameEdit, 220, 20, "PSSFrame2EditLinkField")
	link:SetPoint("TOPLEFT", linkText, "BOTTOMLEFT", 5, -6)
	link:SetScript("OnEnterPressed", function(self)
		self:SetText(convertLink(self:GetText()))
		self:HighlightText()
	end)
	link:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
end

local function BuildUIFrames()

	if MainFrame ~= nil then
		createSortedIndex(IgnoreScrollType)
		MainFrame:Show()
		return
	end

	----------------
	-- MAIN FRAME --
	----------------

	MainFrame = CreateFrame("Frame", "PSS", UIParent, "PortraitFrameTemplate")
	tinsert(UISpecialFrames, "PSS")   -- Escape closes it
	MainFrame:Hide()
	MainFrame:SetFrameStrata(M.PSS_FrameStrataName())
	MainFrame:SetWidth(WINDOW_WIDTH)
	MainFrame:SetHeight(WINDOW_HEIGHT)
	MainFrame:SetPoint("CENTER", UIParent)
	UI.DecorateWindow(MainFrame, "Pour Social Score")

	MainFrame:SetScript("OnShow",
		function (self)
			if V.PSS_SyncOK == false then
				M.SyncIgnoreList(M.PSS_Opt("chatmsg") == false)
			end
		end)

	-- One place decides which page is visible (tabs 1-5).
	local function showTab(id)
		Tab1Frame:Hide()
		if M.PSSGuildTabFrame then M.PSSGuildTabFrame:Hide() end
		Tab2Frame:Hide()
		Tab2FrameEdit:Hide()
		Tab3Frame:Hide()
		if TabIOFrame then TabIOFrame:Hide() end
		if id == 1 then
			Tab1Frame:Show()
		elseif id == 2 then
			if M.PSSGuildTabFrame then M.PSSGuildTabFrame:Show() end
		elseif id == 3 then
			M.FilterScrollChangeState(-1)
		elseif id == 4 then
			if TabIOFrame then TabIOFrame:Show() end
		else
			Tab3Frame:Show()
		end
		setActiveTab(MainFrame, id)
	end

	local tabs = { { "PSSTab1", "Player Ignore List" }, { "PSSTabGuild", "Guild Ignore List" }, { "PSSTab2", "Chat Filters" },
					{ "PSSTabIO", "Import/Export" }, { "PSSTab3", "Options" } }
	local prev
	for id, t in ipairs(tabs) do
		local b = createTabButton(t[1], MainFrame)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", -16, 0) else b:SetPoint("TOPLEFT", MainFrame, "BOTTOMLEFT", 20, 1) end
		b:SetText(t[2])
		b:SetID(id)
		b:SetScript("OnClick", function() showTab(id) end)
		prev = b
	end

	if M.PSS_BuildGuildUI then
		TabGuildFrame = M.PSS_BuildGuildUI(MainFrame)
		if TabGuildFrame then TabGuildFrame:Hide() end
	end

	BuildPlayerTab()
	BuildFilterTab()
	BuildFilterEditor()

	------------------------------------
	-- TAB 4/5: IMPORT/EXPORT, OPTIONS --
	------------------------------------

	Tab3Frame = M.PSS_BuildOptionsTab(MainFrame, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_OFFSET)
	TabIOFrame = M.PSS_BuildImportExportTab(MainFrame, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_OFFSET)

	----------
	-- SHOW --
	----------

	if PanelTemplates_SetNumTabs then
		pcall(PanelTemplates_SetNumTabs, MainFrame, 5)
	end
	setActiveTab(MainFrame, 1)

	-- Drag grip in the bottom-right corner. The default size is the minimum:
	-- the tab layouts (guild table, filter editor) need at least that much.
	M.PSS_MakeResizable(MainFrame, {
		minW = WINDOW_WIDTH, minH = WINDOW_HEIGHT,
		saveKey = "main",
		onResize = RelayoutMainFrame,
	})
	MainFrame:HookScript("OnShow", RelayoutMainFrame)
	-- closing the window frees what its lists used (cleaned up out of combat)
	MainFrame:HookScript("OnHide", function() if M.PSS_RequestGC then M.PSS_RequestGC("window closed") end end)
	RelayoutMainFrame()

	MainFrame:Show()
end

-- Wrapper: if building the window fails part-way, discard the half-built frame
-- so the next /pss gui retries cleanly instead of showing a broken window.
local function CreateUIFrames()

	if MainFrame ~= nil then
		createSortedIndex(IgnoreScrollType)
		MainFrame:Show()
		return
	end

	local ok, err = pcall(BuildUIFrames)

	if not ok then
		if MainFrame then
			MainFrame:Hide()
			MainFrame = nil
		end
		Tab1Frame, Tab2Frame, Tab2FrameEdit, Tab3Frame, TabIOFrame = nil, nil, nil, nil, nil
		M.PSSGuildTabFrame = nil
		print("|cffff5555PourSocialScore:|r failed to build the UI: " .. tostring(err))
		geterrorhandler()(err)
	end
end

------------------------------
-- HOOK INTO FRIENDS WINDOW --
------------------------------

local function friendsShow()

	if not M.PSS_Opt("openWithFriends") then
		return
	end

	if MainFrame == nil then
		CreateUIFrames()
	end

	if MainFrame ~= nil then
		MainFrame:ClearAllPoints()
		MainFrame:SetPoint("TOPLEFT", FriendsFrame, "TOPRIGHT", 12, -10)		
		MainFrame:Show()
	end
end

local function friendsHide()
	if not M.PSS_Opt("openWithFriends") then
		return
	end

	if MainFrame ~= nil then
		MainFrame:Hide()
	end
end

FriendsFrame:HookScript("OnShow", friendsShow)
FriendsFrame:HookScript("OnHide", friendsHide)

--------------------------
-- HOOK INTO CHAT LINKS --
--------------------------

Blizzard_ChatEdit_InsertLink = ChatEdit_InsertLink

function ChatEdit_InsertLink (text)

	if text and PSSFrame2EditLinkField and PSSFrame2EditLinkField:HasFocus() then
		PSSFrame2EditLinkField:SetText(text)
		PSSFrame2EditLinkField:Show()

		return true	
	elseif text and PSSFrame2EditFilterField and PSSFrame2EditFilterField.EditBox:HasFocus() then
		PSSFrame2EditFilterField.EditBox:Insert(convertLink(text))
		PSSFrame2EditFilterField.EditBox:Show()

		return true
	elseif text and PSSFrame2EditTestField and PSSFrame2EditTestField.EditBox:HasFocus() then
		PSSFrame2EditTestField.EditBox:Insert(text)
		PSSFrame2EditTestField.EditBox:Show()

		return true
	else	
		return Blizzard_ChatEdit_InsertLink(text)
	end
end

---------------------
-- CORE UI GLOBALS --
---------------------

-- Redraws triggered by blocked chat are batched: a busy Trade channel can
-- block several lines a second, and each used to redraw the window.
local pendingRefresh = {}
local function throttled(key, fn)
	if pendingRefresh[key] then return end
	pendingRefresh[key] = true
	local function run()
		pendingRefresh[key] = nil
		if MainFrame and MainFrame:IsVisible() then fn() end
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end

function M.PSSUpdateBlockHistory (filterNumber)
	throttled("history", function()
		local hp = Tab2Frame and Tab2Frame.histPanel
		if hp and hp:IsVisible() then hp:Refresh() end
	end)
end

function M.PSSUpdateChatCount (filterNumber)
	throttled("chatCount", function()
		UpdateRuleSummaryTexts()
		if Tab2Frame and Tab2Frame:IsVisible() then
			M.FilterListDrawUpdate(FilterScrollFrame)
		end
	end)
end

function M.PSSUpdateUI (forced)
	if M.PSS_RefreshPlayerDetail then M.PSS_RefreshPlayerDetail() end
	if Tab1Frame and Tab1Frame.updateHistoryPanel then Tab1Frame.updateHistoryPanel() end
	if MainFrame ~= nil and Tab1Frame:IsVisible() then	
		if V.needSorted or (forced and forced == true) then
			createSortedIndex(IgnoreScrollType)
		else
			IgnoreListDrawUpdate(IgnoreScrollFrame)
		end
	else
		if V.needSorted or (forced and forced == true) then
			createSortedIndex(IgnoreScrollType)
		end
	end
end

-- Batched PSSUpdateUI for block recording (see throttled above). The
-- player detail window is refreshed too when it is open on its own.
function M.PSS_RequestUIRefresh()
	if pendingRefresh.ui then return end
	pendingRefresh.ui = true
	local function run()
		pendingRefresh.ui = nil
		M.PSSUpdateUI()
	end
	if C_Timer and C_Timer.After then C_Timer.After(0.25, run) else run() end
end

function M.PSS_GUI()
	CreateUIFrames()
end
