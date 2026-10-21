------------------------------------------------------------------------
-- POUR SOCIAL SCORE - THE SPYGLASS CONSOLE TAB (search-helper, phase B, STP-00255)
-- Drawing only: every value comes from M.PSS_ConsoleModel (Libraries) and the
-- query view. Built on first open (ns.TabBuilders.console).
--   pg.navClose()                  closes help, dictionary or the picker panel; true when it did
--   pg.deepDive(text, params, range, from)   sets the text and range, runs with load
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M

local ERR = { 1, 0.36, 0.36, 1 }

ns.TabBuilders = ns.TabBuilders or {}
ns.TabBuilders.console = function(pg)
	local CV = M.PSS_ConsoleView
	local cm = M.PSS_ConsoleModel()
	local PW, PH = pg:GetWidth(), pg:GetHeight()
	if not PW or PW < 400 then PW = ns.PAGE_W or 780 end
	if not PH or PH < 200 then PH = ns.PAGE_H or 460 end
	local LEFT_W, SIDE_W, PAD = 180, 170, 10
	local RX = LEFT_W + 2 * PAD
	local resW, resH = PW - RX - SIDE_W - 2 * PAD, PH - 84 - PAD
	local qvo = { w = resW, h = resH, rows = M.PSS_Opt("conRows"), deepDive = false, shape = "events" }
	local leftByKey, tabs, tabKey = {}, {}, "results"
	local qv, bar, picker, nav, chip, help, dict, side, sideList, flat

	------------------------------------------------------------------ top bar
	bar = ns.NewEditBox(pg, 300, 512)
	local function BarText() return CV.unpipe(bar:GetText() or "") end
	local function SetBar(t) bar:SetText(CV.pipe(t or "")) end
	local help_b = ns.NewButton(pg, "?", 24, function() pg.toggleHelp() end)
	local save_b = ns.NewButton(pg, "Save", 60, function()
		if ns.SaveQueryDialog then ns.SaveQueryDialog(BarText(), picker:Choice()) end
	end)
	local run_b = ns.NewButton(pg, "Run", 60, function() pg.run(true) end, true)
	local edit_b = ns.NewButton(pg, "Edit search", 100, function() pg.endReport(true) end)
	picker = ns.NewTimePicker(pg, function() if chip then pg.updateChip() end end)
	picker:SetWidth(150)
	help_b:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -PAD, -PAD)
	save_b:SetPoint("RIGHT", help_b, "LEFT", -4, 0)
	run_b:SetPoint("RIGHT", save_b, "LEFT", -4, 0)
	picker:SetPoint("RIGHT", run_b, "LEFT", -4, 0)
	bar:SetPoint("TOPLEFT", pg, "TOPLEFT", RX + 6, -PAD)
	edit_b:SetPoint("TOPLEFT", pg, "TOPLEFT", RX + 6, -PAD)
	edit_b:Hide()
	bar:SetPoint("RIGHT", picker, "LEFT", -6, 0)
	bar:SetTextColor(1, 1, 1, 1)
	if bar.SetShadowColor then bar:SetShadowColor(0, 0, 0, 1) end

	-- plain text (D74): the box shows its own text at alpha 1; overlay stays hidden
	local overlay = ns.NewText(bar, 12)
	local meas = ns.NewText(bar, 12)
	local fo = bar.GetFontObject and bar:GetFontObject()
	if fo then overlay:SetFontObject(fo); meas:SetFontObject(fo) end
	overlay:SetPoint("LEFT", bar, "LEFT", 0, 0)
	overlay:SetJustifyH("LEFT")
	overlay:Hide()
	meas:Hide()
	local ul = bar:CreateTexture(nil, "OVERLAY")
	ul:SetColorTexture(ERR[1], ERR[2], ERR[3], 1)
	ul:Hide()
	local barErr
	local function Highlight()
		local text = BarText()
		pg.lastRaw = bar:GetText()
		local toks, err = cm:Tokens(text)
		barErr = err
		cm:SetText(text)
		meas:SetText(CV.pipe(text))
		local w = meas:GetStringWidth() or 0
		local room = (bar:GetWidth() or 300) - 12
		if w > room then
			ul:Hide()
			return
		end
		if err and err.pos and err.pos <= #text then
			meas:SetText(CV.pipe(text:sub(1, err.pos - 1)))
			local x0 = meas:GetStringWidth() or 0
			meas:SetText(CV.pipe(text))
			ul:ClearAllPoints()
			ul:SetHeight(ns.OnePixel(bar))
			ul:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x0 + 1, 2)
			ul:SetWidth(math.max(2, w - x0))
			ul:Show()
		else
			ul:Hide()
		end
	end
	bar:HookScript("OnTextChanged", Highlight)
	bar:SetScript("OnEnter", function(self) if barErr then ns.Tip(self, barErr.msg) end end)
	bar:SetScript("OnLeave", function() ns.HideTip() end)
	bar:SetScript("OnEnterPressed", function(self) self:ClearFocus(); pg.run(true) end)
	bar:SetScript("OnEscapePressed", function(self)
		if pg.navClose() then return end
		self:ClearFocus()
	end)

	-- the header line: title and summary of the search (ux-review 6.3); the range chip sits at its right
	local header = ns.NewText(pg, 12)
	header:SetPoint("TOPLEFT", pg, "TOPLEFT", RX + 6, -PAD - 26)
	header:SetWidth(resW - 150)
	header:SetJustifyH("LEFT")
	header:SetWordWrap(false)
	chip = ns.NewText(pg, 11)
	chip:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -PAD - SIDE_W + 10, -PAD - 27)
	chip:SetAlpha(0.8)
	local hitf = CreateFrame("Frame", nil, pg)
	hitf:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
	hitf:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	hitf:EnableMouse(true)
	hitf:SetScript("OnEnter", function(self) if qv and qv.vm.query and qv.vm.query ~= "" then ns.Tip(self, qv.vm.query) end end)
	hitf:SetScript("OnLeave", function() ns.HideTip() end)

	------------------------------------------------------------------ result area
	local holder = CreateFrame("Frame", nil, pg)
	holder:SetPoint("TOPLEFT", pg, "TOPLEFT", RX, -84)
	holder:SetSize(resW, resH)
	for i, t in ipairs({ { "results", "Results" }, { "stats", "Statistics" }, { "chart", "Chart" } }) do
		local key = t[1]
		local b = ns.NewTab(pg, t[2], function() pg.selectTab(key) end)
		b.key = key
		if i == 1 then b:SetPoint("TOPLEFT", pg, "TOPLEFT", RX, -PAD - 44)
		else b:SetPoint("LEFT", tabs[i - 1], "RIGHT", 2, 0) end
		tabs[i] = b
	end
	qv = ns.NewQueryView(holder, qvo)
	qv:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)

	------------------------------------------------------------------ sidebar
	side = ns.NewPanel(pg, true)
	side:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -PAD, -84)
	side:SetSize(SIDE_W, resH)
	flat = {}
	sideList = ns.NewRows(side, { rowH = 18,
		cols = { { key = "v", text = "Top values" }, { key = "n", text = "#", width = 40, justify = "RIGHT" } },
		draw = function(row, i)
			local d = flat[i]
			if not d then return end
			row.cells.v:SetText(d.head or d.empty or ("  " .. (d.text or tostring(d.value))))
			if d.head then row.cells.v:SetTextColor(1, 0.82, 0, 1)
			elseif d.empty then row.cells.v:SetTextColor(0.6, 0.6, 0.6, 1)
			else row.cells.v:SetTextColor(1, 1, 1, 1) end
			row.cells.n:SetText((d.head or d.empty) and "" or tostring(d.count))
		end,
		click = function(row, i)
			local d = flat[i]
			if d and d.field then
				SetBar(CV.addTerm(BarText(), CV.term(d.field, d.value)))
				pg.run(true)
			end
		end })

	------------------------------------------------------------------ result row menu
	local HookRows
	function HookRows()
		local list = qv.chart and qv.chart.tableList
		if not list then return end
		if not list.pssConLayout then
			-- a taller list makes more rows later: hook those as they appear
			list.pssConLayout = true
			local layout = list.Layout
			list.Layout = function(self, ...) local r = layout(self, ...); HookRows(); return r end
		end
		for _, row in pairs(list.rows or {}) do
			if not row.pssConHooked then
				row.pssConHooked = true
				row:HookScript("OnClick", function(self, button)
					if button ~= "RightButton" or not self.index then return end
					local set = qv.vm.set
					if not set then return end
					cm:SetText(BarText())
					local actions, idx = cm:RowActions(set, self.index), self.index
					ns.ContextMenu(self, function(m)
						for _, a in ipairs(actions) do
							m:Button(a.text, function()
								if a.key == "copy" then
									ns.CopyText({ title = "Copy line", text = cm:CopyLine(set, idx) })
								else
									SetBar(a.query); pg.run(true)
								end
							end)
						end
					end)
				end)
			end
		end
	end

	------------------------------------------------------------------ tabs and chips
	local backChip = ns.NewButton(pg, "", 150, function() ns.NavBack() end)
	backChip:SetPoint("LEFT", tabs[#tabs], "RIGHT", 10, 0)
	backChip:Hide()
	function pg.updateChip()
		local _, _, label = picker:Range()
		local c = picker:Choice()
		chip:SetText((c and c.preset ~= "all" and label) or "")
		backChip:SetText("Back: " .. tostring(pg.from or ""))
		backChip:SetShown(pg.from ~= nil)
		local text = BarText():match("^%s*(.-)%s*$")
		local rl = (c and c.preset ~= "all" and label) or nil
		header:SetText(text == "" and "" or CV.header(qv and qv.vm.report, text, rl))
	end

	-- report mode: the bar, Run and Save give way to Edit search (ux-review 6.3 step 2)
	local function ApplyMode()
		local on = qv.vm.report ~= nil
		bar:SetShown(not on); run_b:SetShown(not on); save_b:SetShown(not on); edit_b:SetShown(on)
	end
	function pg.endReport(focus)
		qv.vm.report = nil
		ApplyMode()
		pg.updateChip()
		if focus then bar:SetFocus() end
	end

	-- the tab is reset as it opens from a tab click: no way back to a tab it was not sent from
	function pg.navReset() pg.from = nil; pg.updateChip() end

	local function Sync()
		local vm = qv.vm
		local shape = vm.info and vm.info.shape
		local statsOn = shape ~= nil and shape ~= "events"
		local chartOn = vm.chart ~= nil and vm.chart.kind ~= "table"
		tabs[2]:SetEnabled(statsOn)
		tabs[3]:SetEnabled(chartOn)
		if vm.plan and vm.plan.chart and chartOn then tabKey = "chart"
		elseif (tabKey == "stats" and not statsOn) or (tabKey == "chart" and not chartOn) then tabKey = "results" end
		for _, b in ipairs(tabs) do ns.SetTabSelected(b, b.key == tabKey) end
		qvo.shape = (tabKey == "chart") and "chart" or ((tabKey == "results" and shape == "events") and "events" or "table")
		qv:Refresh()
		-- the sidebar: top values of each column
		wipe(flat)
		for _, g in ipairs(cm:Sidebar(vm.set)) do
			flat[#flat + 1] = { head = g.label }
			for _, r in ipairs(g.rows) do flat[#flat + 1] = { field = g.field, value = r[1], count = r[2], text = r[3] } end
		end
		if #flat == 0 and vm.set and (vm.set.n or 0) > 0 then flat[1] = { empty = "No common values" } end
		sideList:SetCount(#flat)
		sideList:Redraw()
		HookRows()
	end

	function pg.selectTab(key)
		tabKey = key
		for _, b in ipairs(tabs) do ns.SetTabSelected(b, b.key == key) end
		local shape = qv.vm.info and qv.vm.info.shape
		qvo.shape = (key == "chart") and "chart" or ((key == "results" and shape == "events") and "events" or "table")
		qv:Refresh()
		HookRows()
	end

	local function Ctx()
		local s = ns.SelectedPlayer and ns.SelectedPlayer()
		return { owner = s and M.PSS_PlayerHistoryKey(s) or nil }
	end
	local function Unbound(missing)
		qv.status:SetTextColor(1, 1, 1)
		qv.status:SetText(M.PSS_UNBOUND_TEXT[missing] or M.PSS_UNBOUND_TEXT.other)
	end

	function pg.run(load, report)
		if dict then dict:Hide() end
		local text = BarText() or ""
		text = text:match("^%s*(.-)%s*$")
		if text == "" then qv.status:SetText(M.PSS_CON_BLANK); return end
		if text:find("$", 1, true) then
			local r, missing = M.PSS_ResolveQuery(text, Ctx())
			if not r then Unbound(missing); return end
			text = r
			SetBar(text)
		end
		local _, err = cm:Tokens(text)
		if err then return end
		cm:SetText(text)
		if report then report.bound = CV.boundName(text); report.text = text end
		qv.vm.report = report
		ApplyMode()
		qv:SetQuery(text)
		qv:SetRange((function() local e, l = picker:Range(); if e or l then return { earliest = e, latest = l } end end)())
		qv:Run(load)
		pg.updateChip()
		Sync()
	end

	------------------------------------------------------------------ help
	help = ns.NewPanel(pg, true)
	help:SetAllPoints(holder)
	help:SetFrameLevel((holder:GetFrameLevel() or 1) + 20)
	help:Hide()
	local helpList = ns.NewRows(help, { rowH = 20,
		cols = { { key = "e", text = "Example", width = 300 }, { key = "t", text = "What it does" } },
		draw = function(row, i) row.cells.e:SetText(CV.HELP[i][1]); row.cells.t:SetText(CV.HELP[i][2]) end,
		click = function(row, i)
			help:Hide()
			SetBar(CV.HELP[i][1])
			pg.run(true)
		end })
	helpList:SetCount(#CV.HELP)
	function pg.toggleHelp() help:SetShown(not help:IsShown()); if help:IsShown() then helpList:Redraw() end end

	------------------------------------------------------------------ data dictionary
	local dIndex, dField, dFields, dValues
	local function DictFill()
		local f = M.PSS_DictPageModel(dIndex)
		dFields = f
		local fc = f and (M.PSS_SetCol(f, "field") or 1)
		dict.fields.fc = fc
		dict.fieldList:SetCount(f and f.n or 0)
		dict.fieldList:Redraw()
		dValues = dField and M.PSS_DictPageModel(dIndex, dField) or nil
		dict.valueList:SetCount(dValues and dValues.n or 0)
		dict.valueList:Redraw()
	end
	local function BuildDict()
		dict = ns.NewPanel(pg, true)
		dict:SetAllPoints(holder)
		dict:SetFrameLevel((holder:GetFrameLevel() or 1) + 20)
		local names = M.PSS_DictPageModel()
		dIndex = names and names.n > 0 and names[1][1] or nil
		dict.fields = {}
		dict.drop = ns.NewDropdown(dict, 180, function(m)
			for i = 1, names and names.n or 0 do
				local n = names[i][1]
				m:Radio(n, function() return dIndex == n end, function()
					dIndex, dField = n, nil; dict.drop:SetLabel(n); DictFill()
				end)
			end
		end)
		dict.drop:SetPoint("TOPLEFT", dict, "TOPLEFT", 6, -6)
		dict.drop:SetLabel(dIndex or "")
		local half = math.floor((resW - 20) / 2)
		local lf, rf = CreateFrame("Frame", nil, dict), CreateFrame("Frame", nil, dict)
		lf:SetPoint("TOPLEFT", dict, "TOPLEFT", 6, -34)
		lf:SetSize(half, resH - 74)
		rf:SetPoint("TOPLEFT", lf, "TOPRIGHT", 8, 0)
		rf:SetSize(half, resH - 74)
		dict.fieldList = ns.NewRows(lf, { rowH = 18,
			cols = { { key = "f", text = "Field" }, { key = "k", text = "Kind", width = 70 } },
			draw = function(row, i)
				local r = dFields and dFields[i]
				if not r then return end
				row.cells.f:SetText(tostring(r[dict.fields.fc or 1]))
				row.cells.k:SetText(tostring(r[M.PSS_SetCol(dFields, "kind") or 2] or ""))
			end,
			click = function(row, i)
				local r = dFields and dFields[i]
				if not r then return end
				dField = r[dict.fields.fc or 1]
				dValues = M.PSS_DictPageModel(dIndex, dField)
				dict.valueList:SetCount(dValues and dValues.n or 0)
				dict.valueList:Redraw()
			end })
		dict.valueList = ns.NewRows(rf, { rowH = 18,
			cols = { { key = "v", text = "Value" }, { key = "n", text = "#", width = 50, justify = "RIGHT" } },
			draw = function(row, i)
				local r = dValues and dValues[i]
				if not r then return end
				row.cells.v:SetText(tostring(r[1])); row.cells.n:SetText(tostring(r[2] or ""))
			end })
		dict.search = ns.NewButton(dict, "Search this field", 140, function()
			if dField then
				dict:Hide()
				SetBar(CV.addTerm(BarText(), tostring(dField) .. "="))
				bar:SetFocus()
			end
		end)
		dict.search:SetPoint("BOTTOMLEFT", dict, "BOTTOMLEFT", 6, 6)
		DictFill()
	end

	------------------------------------------------------------------ left list
	local function Pick(key)
		local d = leftByKey[key]
		if key == "dict" then
			if not dict then BuildDict() end
			help:Hide(); dict:Show(); DictFill()
		elseif d and d.query then
			local text, missing = M.PSS_ResolveQuery(d.query, Ctx())
			if not text then Unbound(missing); return end
			SetBar(text)
			pg.run(true, { title = d.text })
		elseif d and d.insert then
			SetBar(d.insert)
			pg.run(true, { title = d.text })
		end
	end
	local rows = cm:LeftRows()
	for _, d in ipairs(rows) do if d.key then leftByKey[d.key] = d end end
	nav = ns.NewNav(pg, { width = LEFT_W, rows = rows, onSelect = Pick })
	nav:SetPoint("TOPLEFT", pg, "TOPLEFT", PAD, -PAD)
	nav:SetPoint("BOTTOM", pg, "BOTTOM", 0, PAD)

	------------------------------------------------------------------ closing and deep dive
	function pg.navClose()
		local closed = false
		if help:IsShown() then help:Hide(); closed = true end
		if dict and dict:IsShown() then dict:Hide(); closed = true end
		local panel = picker.Panel and picker:Panel()
		if panel and panel:IsShown() then panel:Hide(); closed = true end
		return closed
	end

	function pg.deepDive(text, params, range, from)
		pg.from = from
		SetBar(text or "")
		picker:SetChoice(range or { preset = M.PSS_Opt("conTime") })
		cm:SetText(text or "")
		qv:SetQuery(text or "", params)
		local shown = qv.vm:Text() or text or ""
		SetBar(shown)
		cm:SetText(shown)
		qv:SetQuery(shown)
		local bound = CV.boundName(shown)
		qv.vm.report = { title = bound and ("Events of " .. bound) or "Events", bound = bound, text = shown }
		ApplyMode()
		qv:SetRange((function() local e, l = picker:Range(); if e or l then return { earliest = e, latest = l } end end)())
		qv:Run(true)
		pg.updateChip()
		Sync()
	end

	------------------------------------------------------------------ first show: nothing loads (C3)
	picker:SetChoice({ preset = M.PSS_Opt("conTime") })
	SetBar("")
	cm:SetText("")
	qv.status:SetText(M.PSS_CON_BLANK)
	qv.status:SetTextColor(1, 1, 1)
	tabKey = "results"
	for _, b in ipairs(tabs) do ns.SetTabSelected(b, b.key == tabKey) end
	tabs[2]:SetEnabled(false)
	tabs[3]:SetEnabled(false)
	wipe(flat)
	sideList:SetCount(0)
	pg.updateChip()
	Highlight()

	pg.bar, pg.qv, pg.cm, pg.picker, pg.help, pg.overlay, pg.underline, pg.sideList, pg.tabs = bar, qv, cm, picker, help, overlay, ul, sideList, tabs
	pg.highlight, pg.sync, pg.hookRows = Highlight, Sync, HookRows
	pg.nav, pg.chip, pg.backChip = nav, chip, backChip
	pg.header, pg.runBtn, pg.saveBtn, pg.editBtn, pg.helpBtn = header, run_b, save_b, edit_b, help_b
	pg.pick = Pick
	pg.layout = { PW = PW, PH = PH, resW = resW, resH = resH }
	if ns.AttachQueryList then ns.AttachQueryList(pg) end
	function pg.barError() return barErr end
	ns.ConsoleBarRaw = function() return pg.lastRaw end
	M.PSS_ConsoleBarRaw = ns.ConsoleBarRaw
	function pg.dictPanel() return dict end
	function pg.sideFlat() return flat end
	return function() end
end
