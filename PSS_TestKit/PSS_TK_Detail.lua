local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M
local T = TK.T

local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local type = type

local MAXSTEPS = 20
local MAXIN = 6
local MAXACT = 6
local RETRY = "[Retry]"
local WAIT_COMBAT = "Waiting: leave combat."

-- The selected run (win.run) resolves this row.
local function findRun(win, rowId)
	local id = win.run
	if not id then return nil end
	local run = TK.DB().runs[id]
	if run then
		local ok, c, row = pcall(TK.Resolve, run, rowId)
		if ok and c then return id, run, c, row end
	end
end

local function build(win)
	local p = CreateFrame("Frame", nil, win)
	p:SetPoint("TOPLEFT", win, "TOPLEFT", 330, -100)
	p:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -14, 40)
	p.title = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	p.title:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
	p.title:SetWidth(400)
	p.title:SetJustifyH("LEFT")
	p.info = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	p.info:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)
	p.info:SetWidth(400)
	p.info:SetJustifyH("LEFT")
	p.stepsLbl = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	p.stepsLbl:SetText(T.STEPS)
	p.steps = {}
	for i = 1, MAXSTEPS do
		local b = CreateFrame("Button", nil, p)
		b:SetSize(400, 14)
		b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
		b.text:SetWidth(360)
		b.text:SetJustifyH("LEFT")
		b.nb = CreateFrame("Button", nil, b)
		b.nb:SetSize(30, 14)
		b.nb:SetPoint("RIGHT", b, "RIGHT", 0, 0)
		b.nb.text = b.nb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		b.nb.text:SetAllPoints()
		b.nb.text:SetText(T.NOTE_BTN)
		b.nb:SetScript("OnClick", function() if p.target then p.target(i) end end)
		b:Hide()
		p.steps[i] = b
	end
	p.act = {}
	for i = 1, MAXSTEPS do
		local a = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
		a:SetSize(120, 18)
		a:Hide()
		p.act[i] = a
	end
	p.inputs = {}
	for i = 1, MAXIN do
		local row = CreateFrame("Frame", nil, p)
		row:SetSize(400, 22)
		row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
		row.label:SetWidth(150)
		row.label:SetJustifyH("LEFT")
		row.edit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
		row.edit:SetSize(150, 20)
		row.edit:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
		row.edit:SetAutoFocus(false)
		row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		row.check:SetSize(22, 22)
		row.check:SetPoint("LEFT", row.label, "RIGHT", 4, 0)
		row.err = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		row.err:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, 0)
		row.err:SetTextColor(1, 0.2, 0.2)
		row:Hide()
		p.inputs[i] = row
	end
	p.noteLbl = p:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	p.noteLbl:SetText(T.NOTE_LBL)
	p.note = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
	p.note:SetSize(300, 20)
	p.note:SetAutoFocus(false)
	p.note:SetMaxLetters(TK.CAP.note)
	p.count = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	p.btn = {}
	local names = { "PASS", "FAIL", "SKIP", "NA", "CLEAR" }
	for i, k in ipairs(names) do
		local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
		b:SetSize(70, 22)
		b:SetText(T[k])
		b.k = k
		p.btn[k] = b
		p.btn[i] = b
	end
	return p
end

function TK.ShowDetail(win, rowId)
	local p = win.detail
	if not p then
		p = build(win)
		win.detail = p
		p.sub = {}
	end
	p.rowId = rowId
	if not rowId or not win.run then p:Hide(); return end
	local runId, run, c, row = findRun(win, rowId)
	if not c then p:Hide(); return end
	p:Show()
	TK.Seen(runId, row)
	local ck = run.checks and run.checks[row] or {}
	p.title:SetText(row .. " " .. (c.title or ""))
	local here = TK.Here()
	local notHere = c.client ~= "any" and c.client ~= here
	local info = (c["do"] and T.DO_LBL:format(c["do"]) or "")
	if c.expect and c.expect ~= "" then info = info .. (info ~= "" and "\n" or "") .. T.EXPECT:format(c.expect) end
	if notHere then info = T.RUN_ON:format(c.client) end
	p.info:SetText(info)
	for i = 1, MAXSTEPS do p.steps[i]:Hide(); p.act[i]:Hide() end
	if not notHere and TK.Select and p.selRow ~= row then
		p.selRow = row
		TK.Select(runId, row, c)
	end
	for i = 1, MAXIN do p.inputs[i]:Hide() end
	local y = -(p.info:GetStringHeight() + 30)
	local set = (not notHere) and M.PSS_Call("testkit.detail", { id = runId, key = row }) or nil
	local nsteps = set and (set.n or #set) or 0
	p.stepsLbl:SetShown(nsteps > 0)
	p.stepsLbl:ClearAllPoints()
	p.stepsLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
	y = y - 16
	local openManual
	for i = 1, nsteps do
		local r = set[i]
		local b = p.steps[i]
		if not b then break end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y)
		b.text:SetText((r[5] and "[ok] " or "[..] ") .. r[2])
		b:Show()
		local op = c.steps[i] and c.steps[i].op
		if op and op.op == "action" then
			local a = p.act[i]
			a:ClearAllPoints()
			a:SetPoint("TOPLEFT", p, "TOPLEFT", 404, y + 2)
			a:SetText(op.label or "")
			a:SetScript("OnClick", function() M.PSS_Call("testkit.act", { id = runId, key = row, step = i }) end)
			a:Show()
		elseif op and op.op == "event" and not r[5] and not TK.Waiting(runId, row, i) then
			local a = p.act[i]
			a:ClearAllPoints()
			a:SetPoint("TOPLEFT", p, "TOPLEFT", 404, y + 2)
			a:SetText(RETRY)
			a:SetScript("OnClick", function()
				TK.Select(runId, row, c)
				M.PSS_Call("testkit.rerun", { id = runId, key = row })
			end)
			a:Show()
		elseif op and op.op == "measure" and not r[5] and TK.CombatWaiting() then
			b.text:SetText(b.text:GetText() .. " " .. WAIT_COMBAT)
		end
		y = y - 15
		if not openManual and r[4] == "manual" and not r[5] then openManual = r[1] end
	end
	p.target = function(i)
		p.noteKey = row .. ".s" .. i
		p.note:SetText((ck.notes and ck.notes["s" .. i]) or "")
		p.note:SetFocus()
	end
	local defs = (not notHere) and c.inputs or nil
	if defs then
		for i, def in ipairs(defs) do
			local r = p.inputs[i]
			if not r then break end
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y - 4)
			r.label:SetText(def.label or def.id)
			r.err:SetText("")
			local cur = ck.inputs and ck.inputs[def.id]
			local function save(v)
				local ok, e = pcall(M.PSS_Call, "testkit.input", { id = runId, key = row, field = def.id, value = v })
				if not ok or not e or (e.n or #e) == 0 then
					r.err:SetText(T.BAD_VALUE:format(def.label or def.id))
				else
					r.err:SetText("")
				end
			end
			if def.kind == "bool" then
				r.edit:Hide()
				r.check:Show()
				r.check:SetChecked(cur == true)
				r.check:SetScript("OnClick", function(self) save(self:GetChecked() and true or false) end)
			else
				r.check:Hide()
				r.edit:Show()
				r.edit:SetText(cur ~= nil and tostring(cur) or "")
				local function commit(self)
					local v = self:GetText()
					if def.kind == "number" then v = tonumber(v) end
					if v ~= nil and v ~= "" then save(v) end
				end
				r.edit:SetScript("OnEnterPressed", function(self) commit(self); self:ClearFocus() end)
				r.edit:SetScript("OnEditFocusLost", commit)
				r.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
			end
			r:Show()
			y = y - 26
		end
	end
	p.noteKey = row
	p.noteLbl:ClearAllPoints()
	p.noteLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 0, y - 8)
	p.note:ClearAllPoints()
	p.note:SetPoint("LEFT", p.noteLbl, "RIGHT", 10, 0)
	p.count:ClearAllPoints()
	p.count:SetPoint("LEFT", p.note, "RIGHT", 6, 0)
	local text = (ck.notes and ck.notes[""]) or ""
	p.note:SetText(text)
	p.count:SetText(T.NOTE_COUNT:format(#text, TK.CAP.note))
	local pendingFail
	local function saveNote()
		local t = p.note:GetText()
		M.PSS_Call("testkit.note", { id = runId, key = p.noteKey, text = t })
	end
	p.note:SetScript("OnTextChanged", function(self) p.count:SetText(T.NOTE_COUNT:format(#self:GetText(), TK.CAP.note)) end)
	p.note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	p.note:SetScript("OnEditFocusLost", function(self)
		local t = self:GetText()
		if pendingFail then
			local st = pendingFail
			pendingFail = nil
			M.PSS_Call("testkit.mark", { id = runId, key = row, status = st[1], step = st[2], reason = (t ~= "" and t) or T.NO_NOTE })
		end
		if p.noteKey then saveNote() end
	end)
	local by = y - 36
	local x = 0
	for i = 1, #p.btn do
		local b = p.btn[i]
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", p, "TOPLEFT", x, by)
		b:SetShown(not notHere)
		x = x + 76
	end
	local function mark(status, reason, step)
		M.PSS_Call("testkit.mark", { id = runId, key = row, status = status, reason = reason, step = step })
	end
	p.btn.PASS:SetScript("OnClick", function()
		if openManual then mark("complete", nil, openManual) else mark("complete") end
	end)
	p.btn.FAIL:SetScript("OnClick", function()
		pendingFail = { "failed", openManual }
		p.noteKey = row
		p.note:SetFocus()
	end)
	p.btn.SKIP:SetScript("OnClick", function() mark("skipped", T.SKIPPED, openManual) end)
	p.btn.NA:SetScript("OnClick", function()
		pendingFail = { "n_a" }
		p.noteKey = row
		p.note:SetFocus()
	end)
	p.btn.CLEAR:SetScript("OnClick", function() mark("clear") end)
	-- redraw on a change of the shown row, only while the window shows
	if not p.listen and M.Events and M.Events.Register then
		p.listen = M.Events.Register("TESTKIT_CHANGED", function(_, key)
			if win:IsShown() and p.rowId and p:IsShown() and (key == "" or key == nil or key == p.rowId or type(key) ~= "string") then
				TK.ShowDetail(win, p.rowId)
			end
		end)
		win:HookScript("OnHide", function()
			if p.listen and M.Events.Unregister then M.Events.Unregister("TESTKIT_CHANGED", p.listen) end
			p.listen = nil
		end)
		win:HookScript("OnShow", function()
			if not p.listen and M.Events.Register and p.rowId then TK.ShowDetail(win, p.rowId) end
		end)
	end
end
