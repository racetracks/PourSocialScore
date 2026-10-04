------------------------------------------------------------------------
-- POUR SOCIAL SCORE - OPTIONS TAB AND OVERRIDE MENUS
--
-- The client side of PSS_Options.lua: the Options tab and the per guild /
-- per person override entries in the right-click menus. Option values,
-- defaults and M.PSS_Opt / M.PSS_SetOpt stay in PSS_Options.lua.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local OPTIONS = M.PSS_OPTIONS
local REG = M.PSS_OPTION_REG
local SECTIONS = M.PSS_OPTION_SECTIONS

-- Options whose effect must be applied immediately when changed.
M.Events.Register("OPTION_CHANGED", function(key)
	if key ~= "frameStrata" then return end
	local main = _G["PSS"]
	if main and main.SetFrameStrata then main:SetFrameStrata(M.PSS_FrameStrataName()) end
end)

------------------------------------------------------------------------
-- Override menus (guild row, member row, player row right-click)
------------------------------------------------------------------------
local function stateText(v)
	if v == nil then return "|cffaaaaaaDefault|r" end
	if v == true then return "|cff00ff00On|r" end
	if v == false then return "|cffff5555Off|r" end
	return tostring(v)
end

-- root: a Menu element description; target: record (guild / member / player)
-- scopeLabel: "guild" or "person" (shown in the title)
function M.PSS_AddOverrideMenu(root, target, scopeLabel, onChange)
	if not root or type(target) ~= "table" then return end
	local scope = (scopeLabel == "guild") and "guild" or "person"
	root:CreateDivider()
	root:CreateTitle(scope == "guild" and "Overrides for this guild" or "Overrides for this player")
	for _, o in ipairs(OPTIONS) do
		if o.target and o.kind == "bool" then
			local cur = target.opts and target.opts[o.key]
			local sub = root:CreateButton(o.label .. ": " .. stateText(cur))
			for _, choice in ipairs({ { nil, "Default (use the Options tab)" }, { true, "On" }, { false, "Off" } }) do
				local v = choice[1]
				sub:CreateButton((cur == v and "|cffffd100> |r" or "   ") .. choice[2], function()
					M.PSS_SetOpt(o.key, scope, v, target)
					if onChange then onChange() end
				end)
			end
		end
	end
end

------------------------------------------------------------------------
-- Options tab
------------------------------------------------------------------------
-- Columns (shared header look, see PSS_UIKit.lua)
local COL_OPTION_W, COL_ALL_W = 620, 160
local COL_GLOBAL = COL_OPTION_W + COL_ALL_W / 2				-- centre of "Setting"

function M.PSS_BuildOptionsTab(MainFrame, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_OFFSET)
	local UI = M.UI
	local frame = CreateFrame("Frame", "PSSFrame3", MainFrame, "InsetFrameTemplate")
	frame:Hide()
	frame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -84)
	frame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -11, 29)

	local title, head = UI.CreateSummary(frame, "Options", 840)
	head:SetFontObject("GameFontHighlightSmall")
	head:SetWordWrap(true)
	head:SetHeight(30)
	head:SetJustifyV("TOP")
	frame.head = head

	local rows = {}
	local hr = UI.CreateHeaderRow(frame, {
		{ key = "option", text = "Option",			width = COL_OPTION_W, sort = false, minWidth = 200 },
		{ key = "all",		text = "Setting",			width = COL_ALL_W,		sort = false, minWidth = 60, tip = "The setting for every character on this account." },
	}, 1, UI.HEADER_Y, nil, { id = "options", onLayout = function(h)
		if frame.Slate then frame.Slate:SetWidth(h.total) end
		for _, r in ipairs(rows) do r:SetWidth(h.total) end
	end })
	frame:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then hr:SetAvailableWidth(w - 28) end end)

	local scroll, slate = UI.ScrollList(frame, "PSSSlate3", COL_OPTION_W + COL_ALL_W, 10)
	frame.ScrollFrame, frame.Slate = scroll, slate

	frame.rows = rows
	local y = -4

	local function refreshAll()
		frame.head:SetText("These settings apply to every character on this account. "
			.. "Options marked |cff66ccff*|r can also be set per guild or per player: right-click a guild row, a guild member, or a player on the ignore list.")
		for _, r in ipairs(rows) do r.refresh() end
	end
	frame.refreshAll = refreshAll

	-- the number option drawn next to a tickbox (o.field): a valid value is
	-- required while the box is ticked
	local function fieldValue(f, text)
		local n = tonumber(text)
		if not n then return nil end
		n = math.floor(n)
		if f.min and n < f.min then n = f.min end
		if f.max and n > f.max then n = f.max end
		return n
	end

	local section = 0
	for _, o in ipairs(OPTIONS) do
		if not o.inline then
		if o.section ~= section then
			section = o.section
			y = y - 6
			local h = M.UI.Heading(slate, SECTIONS[section] or "")
			h:SetPoint("TOPLEFT", 6, y)
			y = y - 22
		end

		local row = CreateFrame("Frame", nil, slate)
		row:SetPoint("TOPLEFT", 0, y)
		row:SetSize(COL_OPTION_W + COL_ALL_W, 24)
		local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		hr:Track("option", function(x, w) label:ClearAllPoints(); label:SetPoint("LEFT", row, "LEFT", x + 18, 0); label:SetWidth(math.max(20, w - 24)) end)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		label:SetText((o.label or o.key) .. (o.target and " |cff66ccff*|r" or ""))
		row.option = o

		if o.tip then
			row:EnableMouse(true)
			row:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(o.label, 1, 1, 1)
				GameTooltip:AddLine(o.tip, nil, nil, nil, true)
				GameTooltip:Show()
			end)
			row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end

		if o.kind == "bool" and o.field then
			local f = REG[o.field]
			local g = M.UI.Check(row)
			local e = UI.NumberBox(row, 50, 18)
			hr:Track("all", function(x, w)
				g:ClearAllPoints(); g:SetPoint("CENTER", row, "LEFT", x + w / 2 - 34, 0)
				e:ClearAllPoints(); e:SetPoint("LEFT", g, "RIGHT", 10, 0)
			end)
			local function saved() return fieldValue(f, M.PSS_Opt(f.key)) end
			local function warn(msg)
				M.ShowMsg("|cffff5555" .. msg .. "|r")
				e:SetFocus()
			end
			g:SetScript("OnClick", function(self)
				if self:GetChecked() then
					-- ticking needs a cap: the one being typed, else the saved one
					local n = fieldValue(f, e:GetText()) or saved()
					if not n then
						self:SetChecked(false)
						warn(("%s: enter the %s first (%d-%d)."):format(o.label, f.label:lower(), f.min, f.max))
						return
					end
					M.PSS_SetOpt(f.key, "global", n)
				end
				M.PSS_SetOpt(o.key, "global", self:GetChecked() == true)
				refreshAll()
			end)
			local busy		-- ClearFocus below fires OnEditFocusLost: commit once
			local function commit(self)
				if busy then return end
				busy = true
				local n = fieldValue(f, self:GetText())
				if n then
					M.PSS_SetOpt(f.key, "global", n)
				elseif M.PSS_Opt(o.key) then
					-- ticked: the cap is mandatory, keep the saved one
					M.ShowMsg(("|cffff5555%s is required while %s is ticked.|r"):format(f.label, o.label))
				else
					M.PSS_SetOpt(f.key, "global", nil)
				end
				self:ClearFocus(); refreshAll()
				busy = false
			end
			e:SetScript("OnEnterPressed", commit)
			e:SetScript("OnEditFocusLost", commit)
			e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshAll() end)
			e:SetScript("OnEnter", row:GetScript("OnEnter"))
			e:SetScript("OnLeave", function() GameTooltip:Hide() end)
			row.global, row.field = g, e
			row.refresh = function()
				local on = M.PSS_Opt(o.key) == true and saved() ~= nil
				g:SetChecked(on)
				if not e:HasFocus() then
					local n = saved()
					e:SetText(n and tostring(n) or "")
				end
				e:SetTextColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
			end
		elseif o.kind == "bool" then
			local g = M.UI.Check(row)
			UI.TCenter(g, row, hr, "all")
			g:SetScript("OnClick", function(self) M.PSS_SetOpt(o.key, "global", self:GetChecked() == true); refreshAll() end)
			row.global = g
			row.refresh = function()
				g:SetChecked(M.PSS_Opt(o.key) == true)
			end
		elseif o.kind == "number" then
			local g = UI.NumberBox(row, 50, 18)
			UI.TCenter(g, row, hr, "all")
			g:SetScript("OnEnterPressed", function(self)
				local n = tonumber(self:GetText())
				if n then
					if o.min and n < o.min then n = o.min end
					if o.max and n > o.max then n = o.max end
					M.PSS_SetOpt(o.key, "global", n)
				end
				self:ClearFocus(); refreshAll()
			end)
			g:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshAll() end)
			row.global = g
			row.refresh = function()
				if not g:HasFocus() then g:SetText(tostring(M.PSS_Opt(o.key))) end
			end
		else -- choice
			local function labelFor(v)
				for _, ch in ipairs(o.choices) do if ch[1] == v then return ch[2] end end
				return tostring(v)
			end
			local g = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
			g:SetWidth(120); UI.TCenter(g, row, hr, "all")
			g:SetupMenu(function(dd, root)
				for _, ch in ipairs(o.choices) do
					root:CreateButton(ch[2], function() M.PSS_SetOpt(o.key, "global", ch[1]); refreshAll() end)
				end
			end)
			row.global = g
			row.refresh = function()
				if g.SetDefaultText then g:SetDefaultText(labelFor(M.PSS_Opt(o.key))) end
			end
		end
		rows[#rows + 1] = row
		y = y - 26
		end
	end

	slate:SetHeight(-y + 20)
	frame:SetScript("OnShow", refreshAll)
	return frame
end
