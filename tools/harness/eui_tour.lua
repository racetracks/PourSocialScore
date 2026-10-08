-- EllesmereUI tour (run.lua script, with the EllesmereUI stand-in and
-- PourSocialScore_EllesmereUI through PSS_EXTRA_ADDONS, on a save with the
-- integration switched on): opens the PourSocialScore window, clicks every
-- tab, the first rows of each list, their View Events and period slices, a
-- type tick, the list totals and the Events tab's searches, and after every
-- step writes what is shown to PSS_UI_DUMP: path, type, size, text and
-- anchor points of each shown frame of the window. Two dumps from before
-- and after a change must be identical when the look did not change:
--   sh tools/harness/eui_compare.sh [git ref] [save.lua]
local out = assert(os.getenv("PSS_UI_DUMP"), "set PSS_UI_DUMP=<file>")
local ROWS = tonumber(os.getenv("PSS_TOUR_ROWS") or "") or 25
local E = EllesmereUI

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
local function snapshot(name)
	local win = _G.PSS_EllesmereUIWindow
	if not win then return end
	snaps = snaps + 1
	local lines = {}
	for f, rec in pairs(frames) do
		local root = f
		while root._parent and root ~= win do root = root._parent end
		if root == win and visible(f) then
			local pts = {}
			for _, p in ipairs(rec.points) do
				local a = {}
				for i = 1, p.n do a[#a + 1] = val(p[i]) end
				pts[#pts + 1] = "(" .. table.concat(a, ",") .. ")"
			end
			local checked = f.GetChecked and (f:GetChecked() and " checked" or "") or ""
			lines[#lines + 1] = ("%s | %s | %gx%g | %q | %s%s"):format(pathOf(f), f._kind, f._w or 0, f._h or 0,
				f._text or "", table.concat(pts), checked)
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
local function click(b, button)
	local fn = b and b:GetScript("OnClick")
	if fn then fn(b, button or "LeftButton") end
	H.Advance(1)	-- never a double-click by accident
end

-- a shown summary (pies with View Events) and type pie under a frame
local function findShown(root, field, depth, seen)
	seen = seen or {}
	if depth < 0 or type(root) ~= "table" or seen[root] then return end
	seen[root] = true
	if root[field] and (not root.IsShown or visible(root)) then return root end
	for k, v in pairs(root) do
		if type(v) == "table" and k ~= "_parent" then
			local r = findShown(v, field, depth - 1, seen)
			if r then return r end
		end
	end
end

local win
local function viewEvents(page, label)
	local sm = findShown(page.pane, "viewButton", 3)
	if not sm then return end
	step(label .. " view events", function() click(sm.viewButton) end)
	-- the oldest lines: the counted rows no longer stored
	step(label .. " view end", function()
		local l = win.pages[4].view.list
		l.scroll:SetVerticalScroll(l.count * l.rowH)
	end)
	step(label .. " back", function() E.PressEscape() end)
	for _, per in ipairs({ "session", "day" }) do
		if sm.Open then
			step(label .. " slice " .. per, function() sm:Open(per) end)
			step(label .. " slice back", function() E.PressEscape() end)
		end
	end
end

step("add player", function() M.PSS_AddPlayer("Tourplayer-Realm", "a note", 0) end)
step("open", function() M.PSS_Need("EllesmereUI"); M.EUI_Toggle() end)
win = _G.PSS_EllesmereUIWindow
for i = 1, #(win and win.tabs or {}) do
	step("tab " .. i, function() click(win.tabs[i]) end)
end

for i = 1, 3 do
	step("list tab " .. i, function() click(win.tabs[i]) end)
	local page = win.pages[i]
	local list, st = page.list, page.state
	if list then
		list.scroll:SetHeight(300)
		list:Layout()
		if page.pane and page.pane.totals then
			step("tab " .. i .. " totals", function() page.pane.totals:Show(st and st.rows) end)
			viewEvents({ pane = page.pane.totals }, "tab " .. i .. " totals")
			step("tab " .. i .. " totals hide", function() page.pane.totals:Hide() end)
		end
		for r = 1, math.min(st and st.n or list.count or 0, ROWS) do
			local label = ("tab %d row %d"):format(i, r)
			step(label, function()
				list.scroll:SetVerticalScroll((r - 1) * list.rowH)
				for _, row in ipairs(list.rows) do if row.index == r then click(row) break end end
			end)
			viewEvents(page, label)
			-- a type unticked and back (shared by every type pie)
			local tp = findShown(page.pane, "keys", 3)
			local k1 = tp and tp.keys and tp.keys[1]
			if k1 and k1.check then
				step(label .. " untick type", function() k1.check:SetChecked(false); k1.check:GetScript("OnClick")(k1.check) end)
				step(label .. " tick type", function() k1.check:SetChecked(true); k1.check:GetScript("OnClick")(k1.check) end)
			end
		end
	end
end

-- the Events tab on its own: everything, then searches
step("events tab", function() click(win.tabs[4]) end)
local view = win.pages[4] and win.pages[4].view
if view and view.search then
	for _, text in ipairs({ "olympus", "PSS0010", "zzz-none", "" }) do
		step("events search " .. text, function()
			view.search:SetText(text)
			local fn = view.search:GetScript("OnTextChanged")
			if fn then fn(view.search, true) end
		end)
	end
end

for _, e in ipairs(errors) do fh:write("ERROR ", e, "\n") end
fh:close()
print(("eui tour: %d snapshots, %d errors"):format(snaps, #errors))
for _, e in ipairs(errors) do print("ERROR " .. e) end
