-- The new window's tour (3.4.0.16; run.lua script, any save): in each look
-- (Modern, Classic, Dark) opens /pss gui, clicks every tab, the first rows
-- of the Players, Guilds and Chat Filters lists, a confirm, the copy popup
-- and a drop-down, and after every step writes what is shown to
-- PSS_UI_DUMP: path, type, size, text, colour, the alpha the eye sees (text
-- or vertex colour alpha times the frame's own) and anchor points of each
-- shown frame of the window and of its popups and menu. Two dumps from
-- before and after a change must be identical when the look did not change:
--   sh tools/harness/tui_compare.sh [git ref] [save.lua]
local out = assert(os.getenv("PSS_UI_DUMP"), "set PSS_UI_DUMP=<file>")
local ROWS = tonumber(os.getenv("PSS_TOUR_ROWS") or "") or 25

local MT = getmetatable(UIParent)
local origIndex = MT.__index
local frames, seq = {}, 0
local function track(f)
	if type(f) == "table" and getmetatable(f) == MT and not frames[f] then
		seq = seq + 1
		frames[f] = { order = seq, points = {} }
	end
	return f
end
MT.__index = function(t, k)
	local m = origIndex(t, k)
	if type(m) ~= "function" or type(k) ~= "string" then return m end
	if k:match("^Create") then
		return function(self, ...) track(self); return track(m(self, ...)) end
	end
	if k == "SetTextColor" or k == "SetVertexColor" then
		return function(self, r, g, b, a)
			local rec = track(self) and frames[self]
			rec.rgb = { r or 1, g or 1, b or 1 }
			rec.a = a or 1
			return m(self, r, g, b, a)
		end
	end
	if k == "SetPoint" or k == "ClearAllPoints" or k == "SetAllPoints" then
		return function(self, ...)
			local rec = track(self) and frames[self]
			if k == "SetPoint" then rec.points[#rec.points + 1] = { n = select("#", ...), ... }
			else rec.points = k == "SetAllPoints" and { { n = 1, "all" } } or {} end
			return m(self, ...)
		end
	end
	return m
end
local origCreateFrame = CreateFrame
function CreateFrame(...) return track(origCreateFrame(...)) end

local function childIndex(f)
	local p, n = f._parent, 0
	for g, r in pairs(frames) do
		if g._parent == p and not g._name and r.order <= frames[f].order then n = n + 1 end
	end
	return n
end
local paths = {}
local function pathOf(f)
	if paths[f] then return paths[f] end
	local own = f._name or (f._kind .. "#" .. childIndex(f))
	local p = f._parent
	local path = (p and p ~= UIParent and frames[p]) and (pathOf(p) .. "/" .. own) or own
	paths[f] = path
	return path
end
local function val(v)
	local t = type(v)
	if t == "number" then return ("%.2f"):format(v) end
	if t == "string" then return ("%q"):format(v) end
	if t == "table" then
		if getmetatable(v) == MT then return "@" .. (frames[v] and pathOf(v) or (v._name or "?")) end
		return "{table}"
	end
	return tostring(v)
end
local function visible(f)
	while f do
		if not f:IsShown() then return false end
		f = f._parent
	end
	return true
end

local fh = assert(io.open(out, "w"))
local errors, snaps = {}, 0
local ROOTS = { "PSS_Window", "PSS_Confirm", "PSS_TextPopup", "PSS_Menu", "PSS_GfxPopup" }
local function rootOf(f)
	while f do
		for _, n in ipairs(ROOTS) do if f == _G[n] then return true end end
		f = f._parent
	end
	return false
end
local function snapshot(name)
	if not _G.PSS_Window then return end
	snaps = snaps + 1
	local lines = {}
	for f, rec in pairs(frames) do
		if rootOf(f) and visible(f) then
			local pts = {}
			for _, p in ipairs(rec.points) do
				local a = {}
				for i = 1, p.n do a[#a + 1] = val(p[i]) end
				pts[#pts + 1] = "(" .. table.concat(a, ",") .. ")"
			end
			local checked = f.GetChecked and (f:GetChecked() and " checked" or "") or ""
			local rgb = rec.rgb and ("%.2f,%.2f,%.2f"):format(rec.rgb[1], rec.rgb[2], rec.rgb[3]) or "-"
			local col = f._color and ("%.2f,%.2f,%.2f,%.2f"):format(f._color[1] or 0, f._color[2] or 0, f._color[3] or 0, f._color[4] or 1) or "-"
			lines[#lines + 1] = ("%s | %s | %gx%g | %q | rgb %s | fill %s | seen %.2f | %s%s"):format(pathOf(f), f._kind,
				f._w or 0, f._h or 0, f._text or "", rgb, col, (rec.a or 1) * (f._alpha or 1), table.concat(pts), checked)
		end
	end
	table.sort(lines)
	fh:write("== ", name, "\n")
	for _, l in ipairs(lines) do fh:write(l, "\n") end
end
local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then errors[#errors + 1] = name .. ": " .. tostring(err) end
	H.RunTimers()
	snapshot(name)
end
-- a tab's number by its key (the order changed in 3.6.0.66; main's tour runs too)
local function TAB(key)
	for i, t in ipairs(M.PSS_UI_TABS) do
		if t.key == key then return i end
	end
end

local function click(b, button)
	local fn = b and b:GetScript("OnClick")
	if fn then fn(b, button or "LeftButton") end
	H.Advance(1)	-- never a double-click by accident
end

step("add player", function() M.PSS_AddPlayer("Tourplayer-Realm", "a note", 0) end)
for _, skin in ipairs({ 2, 0, 1 }) do
	local look = ({ [0] = "classic", [1] = "dark", [2] = "modern" })[skin]
	step(look .. " look", function() M.PSS_SetOpt("uiSkin", "global", skin) end)
	step(look .. " open", function() if not (_G.PSS_Window and _G.PSS_Window:IsShown()) then SlashCmdList.PSS("gui") end end)
	local win = _G.PSS_Window
	for i = 1, #(win and win.tabs or {}) do
		step(look .. " tab " .. i, function() click(win.tabs[i]) end)
	end
	local ci = TAB("console")
	if ci then
		local function pgc() return win.pages[ci] end
		step(look .. " console", function() click(win.tabs[ci]) end)
		step(look .. " console typed", function()
			pgc().bar:SetText("index=log | stats count by cat")
			local f = pgc().bar:GetScript("OnEnterPressed")
			if f then f(pgc().bar) end
		end)
		step(look .. " console chart", function() pgc().selectTab("chart") end)
		step(look .. " console help", function() pgc().toggleHelp() end)
		step(look .. " console help closed", function() pgc().navClose() end)
	end
	for i = 1, 3 do
		step(look .. " list tab " .. i, function() click(win.tabs[i]) end)
		local page = win.pages[i]
		local list = page.list
		if list then
			list.scroll:SetHeight(300)
			list:Layout()
			for r = 1, math.min(list.count or 0, ROWS) do
				step(("%s tab %d row %d"):format(look, i, r), function()
					list.scroll:SetVerticalScroll((r - 1) * list.rowH)
					for _, row in ipairs(list.rows) do if row.index == r then click(row) break end end
				end)
			end
		end
	end
	-- the window's folder: PourSocialScore_GUI from 3.4.0.25 (D2),
	-- PourSocialScore_UI before (so a compare reaches back past D2)
	local ui = H.Private("PourSocialScore_GUI")
	if not (ui and ui.Confirm) then ui = H.Private("PourSocialScore_UI") end
	step(look .. " confirm", function() ui.Confirm({ text = "Tour confirm", accept = "Remove" }) end)
	step(look .. " confirm closed", function() _G.PSS_Confirm:Hide() end)
	step(look .. " copy", function() ui.CopyText({ title = "Tour copy", text = "line one\nline two" }) end)
	step(look .. " copy closed", function() _G.PSS_TextPopup:Hide() end)
	-- 3.5.0: the timed confirm (a plain one before) and the graphics popup
	-- (nothing before; the History view only where Libraries has it, run
	-- with PSS_CAMELOT=1)
	step(look .. " timed confirm", function() ui.Confirm({ title = "Keep Settings?", text = "Tour timed confirm", accept = "Keep", cancel = "Revert", timeout = 15 }) end)
	step(look .. " timed confirm closed", function() _G.PSS_Confirm:Hide() end)
	step(look .. " graphics", function() if M.PSS_GfxBox then M.PSS_GfxBox() end end)
	step(look .. " graphics history", function()
		local g = _G.PSS_GfxPopup
		if g and M.PSS_GfxHistory then click(g.history) end
	end)
	step(look .. " graphics closed", function() if _G.PSS_GfxPopup then _G.PSS_GfxPopup:Hide() end end)
	-- 3.6.0: the AddOns tab (nothing before; the tour opens it with the other tabs)
	step(look .. " addons", function()
		click(win.tabs[TAB("addons")])
		local pg = win.pages[TAB("addons")]
		if pg.list then
			pg.list.scroll:SetHeight(300)
			pg.list:Layout()
		end
	end)
	step(look .. " addons hover row", function()
		local pg = win.pages[TAB("addons")]
		for _, row in ipairs(pg.list and pg.list.rows or {}) do
			if row.index and row.index > 1 and row:IsShown() then
				local f = row:GetScript("OnEnter")
				if f then f(row) end
				break
			end
		end
	end)
	step(look .. " addons hover header", function()
		local pg = win.pages[TAB("addons")]
		local row = pg.list and pg.list.rows[1]
		local f = row and row:GetScript("OnEnter")
		if f then f(row) end
	end)
	step(look .. " addons collapse", function()
		local pg = win.pages[TAB("addons")]
		local row = pg.list and pg.list.rows[1]
		if row then click(row) end
	end)
	step(look .. " addons search", function()
		local pg = win.pages[TAB("addons")]
		if pg.search then
			pg.search:SetText("dbm")
			local f = pg.search:GetScript("OnTextChanged")
			if f then f(pg.search) end
		end
	end)
	-- 3.6.0.66: the Sets drop-down at the bottom left; Save asks first, Rename has the name field
	step(look .. " addons sets menu", function()
		local pg = win.pages[TAB("addons")]
		if pg.setsDD and pg.setsDD.dark then click(pg.setsDD.dark) end
	end)
	step(look .. " addons sets menu closed", function() if _G.PSS_Menu then _G.PSS_Menu:Hide() end end)
	step(look .. " addons save set", function()
		ui.Confirm({ title = "Save Set?", text = "Save the addons that are on now as Set 1?", accept = "Save" })
	end)
	step(look .. " addons save set closed", function() _G.PSS_Confirm:Hide() end)
	step(look .. " addons rename set", function()
		ui.Confirm({ title = "Rename Set?", text = "Give Raid a new name.", accept = "Rename", name = { text = "Raid", max = 32 } })
	end)
	step(look .. " addons rename set closed", function() _G.PSS_Confirm:Hide() end)
	step(look .. " addons disable all", function()
		local pg = win.pages[TAB("addons")]
		if pg.search then
			pg.search:SetText("")
			local f = pg.search:GetScript("OnTextChanged")
			if f then f(pg.search) end
		end
		ui.Confirm({ title = "Disable All AddOns?", text = "Tour disable all", accept = "Disable All" })
	end)
	step(look .. " addons disable all closed", function() _G.PSS_Confirm:Hide() end)
	step(look .. " console", function() click(win.tabs[TAB("console")]) end)
	step(look .. " close", function() win:Hide() end)
end

for _, e in ipairs(errors) do fh:write("ERROR ", e, "\n") end
fh:close()
print(("tui tour: %d snapshots, %d errors"):format(snaps, #errors))
for _, e in ipairs(errors) do print("ERROR " .. e) end
