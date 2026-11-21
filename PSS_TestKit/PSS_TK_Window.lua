local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M
local T = TK.T

local CreateFrame = CreateFrame
local UISpecialFrames = UISpecialFrames
local ReloadUI = ReloadUI
local math = math
local string = string

local FRAME = "PSS_TestKitFrame"
local lower = string.lower

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
			if msg == "" and set[1][1] ~= "" then
				dlg:Hide(); box:SetText(""); err:SetText("")
				if win.SelectRun then win.SelectRun(set[1][1]) end
				return
			end
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

	local run -- selected run id
	local rows, pool = {}, {}
	local doneOnly = false

	local function runs()
		local set = M.PSS_Call("testkit.runs")
		return set or { n = 0 }
	end

	local summary = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -60)
	local nextText = win:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nextText:SetPoint("TOPLEFT", win, "TOPLEFT", 16, -76)
	nextText:SetWidth(600)
	nextText:SetJustifyH("LEFT")
	local go = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	go:SetSize(50, 20)
	go:SetPoint("TOPRIGHT", win, "TOPRIGHT", -14, -74)
	go:SetText(T.GO)
	go:Hide()

	local runText = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	local prev = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	local nxt = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	local runLbl = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	runLbl:SetPoint("LEFT", imp, "RIGHT", 14, 0)
	runLbl:SetText(T.RUN)
	prev:SetSize(24, 22)
	prev:SetPoint("LEFT", runLbl, "RIGHT", 6, 0)
	prev:SetText(T.PREV)
	runText:SetPoint("LEFT", prev, "RIGHT", 6, 0)
	runText:SetWidth(120)
	nxt:SetSize(24, 22)
	nxt:SetPoint("LEFT", runText, "RIGHT", 6, 0)
	nxt:SetText(T.NEXT)

	local done = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
	done:SetSize(24, 24)
	done:SetPoint("LEFT", nxt, "RIGHT", 10, 0)
	done:SetChecked(true)
	local doneLbl = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	doneLbl:SetPoint("LEFT", done, "RIGHT", 2, 0)
	doneLbl:SetText(T.SHOW_DONE)

	local rerun = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	rerun:SetSize(130, 22)
	rerun:SetPoint("LEFT", doneLbl, "RIGHT", 14, 0)
	rerun:SetText(T.RERUN)

	local scroll = CreateFrame("ScrollFrame", FRAME .. "List", win, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -100)
	scroll:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 40)
	scroll:SetWidth(300)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(290, 1)
	scroll:SetScrollChild(content)
	local empty = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	empty:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
	empty:SetWidth(280)
	empty:SetJustifyH("LEFT")

	local selected, selStat, wantNext, nextKey
	local function here()
		return lower((M.PSS_FLV and M.PSS_FLV.flavour) or "any")
	end
	local function pick(key)
		selected = key
		win.selected = key
		selStat = "not_complete"
		if TK.ShowDetail then TK.ShowDetail(win, key) end
	end
	function win.SelectRun(id)
		run = id
		win.run = id
		selected = nil
		if win.detail then win.detail:Hide() end
		wantNext = true
		win.Redraw()
	end
	go:SetScript("OnClick", function()
		if nextKey then pick(nextKey); win.Redraw() end
	end)
	local function getRow(i)
		local r = pool[i]
		if r then return r end
		r = CreateFrame("Button", nil, content)
		r:SetSize(290, 18)
		r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * 18)
		r.text = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		r.text:SetPoint("LEFT", r, "LEFT", 4, 0)
		r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
		r.text:SetJustifyH("LEFT")
		r.hl = r:CreateTexture(nil, "BACKGROUND")
		r.hl:SetAllPoints()
		r.hl:SetColorTexture(1, 1, 1, 0.15)
		r.hl:Hide()
		r:SetScript("OnClick", function(self)
			if not self.key then return end
			pick(self.key)
			selStat = self.stat
			win.Redraw()
		end)
		pool[i] = r
		return r
	end

	function win.Redraw()
		local rs = runs()
		local n = rs.n or #rs
		local found
		for i = 1, n do if rs[i][1] == run then found = true end end
		if not found then run = (n > 0 and rs[1][1]) or nil end
		win.run = run
		for i = 1, #pool do pool[i]:Hide() end
		rerun:SetShown(M.PSS_ServiceInfo and M.PSS_ServiceInfo("testkit.rerun") ~= nil)
		if not run then
			runText:SetText("")
			summary:SetText("")
			nextText:SetText("")
			go:Hide()
			empty:SetText(T.NO_RUN)
			empty:Show()
			content:SetHeight(40)
			return
		end
		empty:Hide()
		local build, c, tot = "", 0, 0
		for i = 1, n do
			if rs[i][1] == run then build, c, tot = rs[i][2], rs[i][4], rs[i][5] end
		end
		runText:SetText(run)
		local set = M.PSS_Call("testkit.checks", { id = run })
		local m = (set and (set.n or #set)) or 0
		local hc, hl = here(), T.HERE_LOOK
		local other, todo, nk, nt, nextClient = 0, 0, nil, nil, nil
		local stat = {}
		for i = 1, m do
			local row = set[i]
			stat[row[1]] = row[4]
			if row[4] ~= "complete" and row[4] ~= "not_complete" then other = other + 1 end
			if row[4] == "not_complete" then
				todo = todo + 1
				local cl = row[3]:match("^(.-) / ")
				if cl == "any" or lower(cl or "") == hc then
					if not nk then nk, nt = row[1], row[2] end
				elseif not nextClient then
					nextClient = cl
				end
			end
		end
		summary:SetText(T.HEAD:format(c or 0, tot or 0, other, hc, hl))
		if selected and not stat[selected] then selected = nil end
		if selected and selStat == "not_complete" and stat[selected] ~= "not_complete" then wantNext = true end
		if selected then selStat = stat[selected] end
		if (wantNext or not selected) and nk then pick(nk); wantNext = false end
		nextKey = nk
		local allDone = m > 0 and todo == 0
		if allDone then
			nextText:SetText("")
			go:Hide()
			empty:SetText(T.ALL_DONE)
			empty:Show()
		elseif nk then
			nextText:SetText(T.NEXTLINE:format(nk, nt))
			go:Show()
		else
			nextText:SetText(T.DONE_ON:format(hc, nextClient or hc))
			go:Hide()
		end
		-- group totals, rows keep the service order (client, look, auto first)
		local order, tally = {}, {}
		for i = 1, m do
			local g = set[i][3]
			if not tally[g] then tally[g] = { 0, 0 }; order[#order + 1] = g end
			tally[g][2] = tally[g][2] + 1
			if set[i][4] == "complete" then tally[g][1] = tally[g][1] + 1 end
		end
		local showDone = done:GetChecked()
		local k, last = allDone and 3 or 0, nil
		for i = 1, m do
			local row = set[i]
			local isDone = row[4] == "complete"
			if showDone or not isDone then
				if row[3] ~= last then
					last = row[3]
					k = k + 1
					local h = getRow(k)
					h.key = nil
					h.hl:Hide()
					local gc, gl = last:match("^(.-) / (.+)$")
					gc, gl = gc or last, gl or hl
					local tag = T.G_LOGIN
					if gc == "any" or lower(gc) == hc then
						tag = (gl == hl or hl == "any" or gl == "any") and T.G_HERE or T.G_SWITCH
					end
					h.text:SetText(T.GROUP:format(gc, gl, tag, tally[last][1], tally[last][2]))
					h:Show()
				end
				k = k + 1
				local r = getRow(k)
				r.key = row[1]
				r.stat = row[4]
				local icon = isDone and T.ICON_OK or (row[4] == "not_complete" and T.ICON_TODO or T.ICON_OTHER)
				local sub = (row[5] and row[5] ~= "") and (" - " .. row[5]) or ""
				r.text:SetText(icon .. " " .. row[1] .. " " .. row[2] .. sub)
				if selected == row[1] then r.hl:Show() else r.hl:Hide() end
				r:Show()
			end
		end
		content:SetHeight(math.max(k * 18, 1))
	end

	local function step(d)
		local rs = runs()
		local n = rs.n or #rs
		for i = 1, n do
			if rs[i][1] == run then
				local j = i + d
				if j >= 1 and j <= n then
						run = rs[j][1]
						win.run = run
						selected = nil
						if win.detail then win.detail:Hide() end
						wantNext = true
						win.Redraw()
					end
				return
			end
		end
	end
	prev:SetScript("OnClick", function() step(1) end)
	nxt:SetScript("OnClick", function() step(-1) end)
	done:SetScript("OnClick", function() win.Redraw() end)
	rerun:SetScript("OnClick", function()
		if run then M.PSS_Call("testkit.rerun", { id = run }) end
		win.Redraw()
	end)

	-- Listen only while shown.
	local listenId
	win:SetScript("OnShow", function()
		if M.Events and M.Events.Register and not listenId then
			listenId = M.Events.Register("TESTKIT_CHANGED", function() if win:IsShown() then win.Redraw() end end)
		end
		wantNext = true
		win.Redraw()
	end)
	-- Pop-out: unticked poll objectives of the active run, built on first use (TK-UX-09).
	local pop, popListen
	local function popLines()
		local out = {}
		local ok, r = pcall(TK.GetRun, win.run)
		local env = ok and TK.Env(r)
		if not env then return out end
		local here = TK.Here()
		for _, c in ipairs(env.checks) do
			if (c.client == "any" or c.client == here) and c.objectives then
				local ck = r.checks and r.checks[TK.RowId(c)]
				for _, o in ipairs(c.objectives) do
					local h = ck and ck.obj and ck.obj[o.id] or 0
					local need = o.need or 1
					if o.source == "poll" and h < need then out[#out + 1] = T.OBJ_ROW:format(o.text, h, need) end
				end
			end
		end
		return out
	end
	local function popDraw()
		local lines = popLines()
		if #lines == 0 then pop:Hide(); return end
		for i = 1, #lines do
			local f = pop.rows[i]
			if not f then
				f = pop:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
				f:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -26 - (i - 1) * 14)
				f:SetJustifyH("LEFT")
				pop.rows[i] = f
			end
			f:SetText(lines[i])
			f:Show()
		end
		for i = #lines + 1, #pop.rows do pop.rows[i]:Hide() end
		pop:SetHeight(34 + #lines * 14)
	end
	local function popShow()
		if not pop then
			pop = CreateFrame("Frame", FRAME .. "Pop", UIParent, "BackdropTemplate")
			pop:SetSize(260, 48)
			pop:SetFrameStrata("MEDIUM")
			pop:SetMovable(true)
			pop:EnableMouse(true)
			pop:RegisterForDrag("LeftButton")
			if pop.SetBackdrop then
				pop:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
			end
			pop.rows = {}
			local t = pop:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			t:SetPoint("TOPLEFT", pop, "TOPLEFT", 10, -8)
			t:SetText(T.POP_TITLE)
			local x = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
			x:SetSize(20, 18)
			x:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -6)
			x:SetText(T.POP_CLOSE)
			x:SetScript("OnClick", function() pop:Hide() end)
			pop:SetScript("OnDragStart", function(self) self:StartMoving() end)
			pop:SetScript("OnDragStop", function(self)
				self:StopMovingOrSizing()
				local d = TK.DB()
				if d.v > 1 then return end
				local l, tp = self:GetLeft(), self:GetTop()
				if l and tp then d.ui = { x = l, y = tp } end
			end)
			pop:SetScript("OnShow", function()
				if M.Events and M.Events.Register and not popListen then
					popListen = M.Events.Register("TESTKIT_CHANGED", function() if pop:IsShown() then popDraw() end end)
				end
			end)
			pop:SetScript("OnHide", function()
				if popListen and M.Events.Unregister then M.Events.Unregister("TESTKIT_CHANGED", popListen) end
				popListen = nil
				if not win:IsShown() then TK.Unpoll() end
			end)
			pop:Hide()
		end
		local ui = TK.DB().ui
		pop:ClearAllPoints()
		if type(ui) == "table" and type(ui.x) == "number" and type(ui.y) == "number" then
			pop:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ui.x, ui.y)
		else
			pop:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -200)
		end
		pop:Show()
		popDraw()
	end
	win:SetScript("OnHide", function()
		if listenId and M.Events.Unregister then M.Events.Unregister("TESTKIT_CHANGED", listenId) end
		listenId = nil
		if #popLines() > 0 then popShow() else TK.Unpoll() end
	end)
	win:HookScript("OnShow", function() if pop then pop:Hide() end end)

	local foot = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	foot:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 14, 12)
	foot:SetText(T.FOOTER:format(0))
	win.footer = foot

	local rl = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
	rl:SetSize(90, 22)
	rl:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 8)
	rl:SetText(T.RELOAD)
	rl:SetScript("OnClick", function() ReloadUI() end)

	local dev = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
	dev:SetPoint("RIGHT", rl, "LEFT", -100, 0)
	dev.text = dev.text or dev.Text
	if dev.text then dev.text:SetText(T.DEV) end
	dev:SetScript("OnShow", function(self) self:SetChecked(TK.DB().devMode == true) end)
	dev:SetScript("OnClick", function(self)
		local on = self:GetChecked() and true or false
		TK.DB().devMode = on or nil
		M.PSS_TK_DEV = on
		if M.Events and M.Events.Fire then M.Events.Fire("ADDONS_CHANGED") end
	end)

	win:Hide()
	TK.window = win
	return win
end
