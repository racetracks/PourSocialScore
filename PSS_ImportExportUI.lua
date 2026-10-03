------------------------------------------------------------------------
-- POUR SOCIAL SCORE - IMPORT / EXPORT TAB
--
-- The client side of PSS_ImportExport.lua: the Import / Export tab and its
-- Replace confirmation. Building, describing and applying an import string
-- stay in PSS_ImportExport.lua.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
StaticPopupDialogs["PSS_IMPORT_REPLACE"] = {
	preferredIndex = 3,
	text = "Replace the selected sections with the imported data?\n\n%s\n\nWhat you have now in those sections will be removed.",
	button1 = "Replace", button2 = CANCEL,
	OnAccept = function(self, data) if data and data.run then data.run() end end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

function M.PSS_BuildImportExportTab(MainFrame, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_OFFSET)
	local f = CreateFrame("Frame", "PSSFrameImportExport", MainFrame, "InsetFrameTemplate")
	f:Hide()
	f:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -84)
	f:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -11, 29)

	local UI = M.UI
	local title, help = UI.CreateSummary(f, "Import / Export", 840)
	help:SetText("Tick what to include, then Export and copy the text (Ctrl+C). To import, paste a string into the box (Ctrl+V) and choose Merge or Replace.")

	local INCLUDE_W = 250
	local hr = UI.CreateHeaderRow(f, {
		{ key = "include", text = "Include", width = INCLUDE_W, sort = false, minWidth = 200 },
		{ key = "text",		text = "Export / import text", width = 600, sort = false, fill = true, minWidth = 200 },
	}, 1, UI.HEADER_Y, nil, { id = "importExport" })
	f:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then hr:SetAvailableWidth(w - 2) end end)

	local checks = {}
	local y = -UI.LIST_TOP - 2
	local function check(key, label, default, indent)
		local c = UI.LabeledCheck(f, label)
		c:SetPoint("TOPLEFT", 12 + (indent or 0), y)
		c:SetChecked(default)
		checks[key] = c
		y = y - 24
		return c
	end
	check("players", "Player Ignore List", true)
	check("guilds", "Guild Ignore List", true)
	check("members", "Include captured guild members", false, 20)
	check("filters", "Custom chat filters", true)
	check("builtins", "Built-in filter on/off", true)
	check("options", "Options (all characters)", false)
	f.checks = checks

	local function sections()
		local s = {}
		for k, c in pairs(checks) do s[k] = c:GetChecked() == true end
		if not s.guilds then s.members = false end
		return s
	end

	local box = UI.TextArea(f, "PSSImportExportText", 0, "ChatFontSmall", 24)
	hr:Track("text", function(x)
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", f, "TOPLEFT", x + 14, -UI.LIST_TOP - 6)
		box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 30)
	end)
	box.EditBox:SetWidth(WINDOW_WIDTH - 19 - 262 - 40)
	f.box = box

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hr:Track("text", function(x)
		status:ClearAllPoints()
		status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x + 8, 10)
		status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 10)
	end)
	status:SetJustifyH("LEFT")
	f.status = status
	local function say(text, r, g, b) status:SetText(text); status:SetTextColor(r or 1, g or 1, b or 1) end

	local function button(label, w, anchorTo, onClick)
		-- the bottom bar under the panel, like every other tab
		local b = UI.BarButton(f, label, anchorTo, math.max(w, UI.BAR_W))
		b:SetScript("OnClick", onClick)
		return b
	end

	local function readImport()
		local data, err = M.PSS_DecodeExport(box.EditBox:GetText())
		if not data then say("Import failed: " .. tostring(err), 1, 0.4, 0.4) end
		return data
	end

	f.replaceButton = button("Import: Replace", 120, nil, function()
		local data = readImport()
		if not data then return end
		local s = sections()
		StaticPopup_Show("PSS_IMPORT_REPLACE", M.PSS_DescribeImport(data), nil, { run = function()
			say("Replaced: " .. M.PSS_ApplyImport(data, "replace", s), 0.4, 1, 0.4)
		end })
	end)
	f.mergeButton = button("Import: Merge", 120, f.replaceButton, function()
		local data = readImport()
		if not data then return end
		say("Merged: " .. M.PSS_ApplyImport(data, "merge", sections()), 0.4, 1, 0.4)
	end)
	f.clearButton = button("Clear", 70, f.mergeButton, function()
		box.EditBox:SetText(""); say("")
	end)
	f.exportButton = button("Export", 90, f.clearButton, function()
		local text = M.PSS_EncodeExport(M.PSS_BuildExport(sections()))
		box.EditBox:SetText(text)
		box.EditBox:SetFocus()
		box.EditBox:HighlightText()
		say(("Export ready (%d characters) - press Ctrl+C to copy."):format(#text), 0.4, 1, 0.4)
	end)

	box.EditBox:SetScript("OnTextChanged", function(self, userInput)
		if not userInput then return end
		local data = M.PSS_DecodeExport(self:GetText())
		if data then say("Pasted: " .. M.PSS_DescribeImport(data) .. ". Tick the sections to apply, then Merge or Replace.", 1, 0.82, 0) end
	end)
	return f
end
