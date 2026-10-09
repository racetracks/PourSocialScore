-- The kit preview (3.4.0-dev002 to dev005), kept for the harness: it
-- builds every control of the window's kit (PourSocialScore_GUI) on a frame of its own,
-- in three preview tabs (controls; lists and the pie; menus and popups),
-- so check_tui.lua can check each look. It left the window in dev006
-- (the window's six tabs took its place). Load it with the UI's namespace:
--   loadfile("tools/harness/kit_page.lua")("PourSocialScore_GUI", H.Private("PourSocialScore_GUI"))
local ADDON_NAME, ns = ...

local NAMES = { "Controls", "Lists and pie", "Menus and popups" }

function ns.BuildKitPage(win)
	local tabs, pages, prev = {}, {}, nil
	local function Select(i)
		for j, t in ipairs(tabs) do
			ns.SetTabSelected(t, j == i)
			pages[j]:SetShown(j == i)
		end
	end
	for i, name in ipairs(NAMES) do
		local tab = ns.NewTab(win, name, function() Select(i) end)
		if prev then
			tab:SetPoint("LEFT", prev, "RIGHT", 2, 0)
		else
			tab:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -32)
		end
		tabs[i], prev = tab, tab
		local pg = ns.NewPanel(win)
		pg:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -84)
		pg:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10)
		pages[i] = pg
	end
	local page = pages[1]

	local h = ns.NewHeading(page, "Kit preview (temporary): every control in the look chosen in Options")
	h:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -10)

	local y = -40
	local function Label(text, x)
		local fs = ns.NewText(page, 12)
		fs:SetPoint("TOPLEFT", page, "TOPLEFT", x or 12, y - 4)
		fs:SetTextColor(1, 1, 1, 0.7)
		fs:SetText(text)
		return fs
	end

	Label("Buttons")
	local b1 = ns.NewButton(page, "Add Player", 100, function() end)
	b1:SetPoint("TOPLEFT", page, "TOPLEFT", 120, y)
	ns.TipOn(b1, b1, "A button with a tooltip.")
	local b2 = ns.NewButton(page, "Disabled", 100)
	b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
	b2:Disable()
	local b3 = ns.NewButton(page, "Primary", 100, function() end, true)
	b3:SetPoint("LEFT", b2, "RIGHT", 6, 0)

	y = y - 32
	Label("Tick boxes")
	local c1 = ns.NewCheck(page)
	c1:SetPoint("TOPLEFT", page, "TOPLEFT", 116, y + 2)
	c1:SetChecked(true)
	local c2 = ns.NewCheck(page)
	c2:SetPoint("LEFT", c1, "RIGHT", 22, 0)

	y = y - 32
	Label("Boxes")
	local e1 = ns.NewEditBox(page, 170, 128)
	e1:SetPoint("TOPLEFT", page, "TOPLEFT", 124, y)
	e1:SetText("Name-Realm")
	local n1 = ns.NewNumberBox(page, 44)
	n1:SetPoint("LEFT", e1, "RIGHT", 12, 0)
	n1:SetText("30")
	local s1 = ns.NewSearchBox(page, 200, "Search name, server or note")
	s1:SetPoint("LEFT", n1, "RIGHT", 16, 0)
	local h1 = ns.NewEditBox(page, 150, 64, "Name-Realm")
	h1:SetPoint("LEFT", s1, "RIGHT", 12, 0)

	y = y - 32
	Label("Tooltip")
	local hover = ns.NewText(page, 12)
	hover:SetPoint("TOPLEFT", page, "TOPLEFT", 120, y - 4)
	hover:SetText("Hover this text")
	local hit = CreateFrame("Frame", nil, page)
	hit:SetAllPoints(hover)
	hit:EnableMouse(true)
	ns.TipOn(hit, hover, "Plain tooltips follow the look: Blizzard's in Blizzard, a dark one in Dark.")

	y = y - 32
	Label("Scroll frame")
	local inset = ns.NewPanel(page, true)
	inset:SetPoint("TOPLEFT", page, "TOPLEFT", 120, y)
	inset:SetSize(360, 120)
	local sf = ns.NewScrollFrame(inset)
	sf:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	sf:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -22, 4)
	local child = CreateFrame("Frame", nil, sf)
	child:SetSize(330, 20 * 16)
	sf:SetScrollChild(child)
	for i = 1, 20 do
		local fs = ns.NewText(child, 12)
		fs:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -(i - 1) * 16)
		fs:SetText("Line " .. i .. " of the scroll frame")
	end

	-- a scrolling multi-line box (the filter text, the copy and import popups)
	local ta = ns.NewTextArea(page, 11, 1000)
	ta:SetPoint("TOPLEFT", page, "TOPLEFT", 500, y)
	ta:SetSize(400, 120)
	ta.edit:SetText("A text area: several lines,\nthat scroll inside the box.")

	-- the pane parts: a line, a label and the W I G P C row
	y = y - 130
	Label("Pane parts")
	local allowed, allowedRow = ns.NewAllowedBoxes(page, y, 360, "Ticked = allowed.", function() end, true)
	allowedRow:ClearAllPoints()
	allowedRow:SetPoint("TOPLEFT", page, "TOPLEFT", 120, y)
	local line = ns.NewLine(page, y - 4)
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", page, "TOPLEFT", 500, y - 4)
	line:SetText("A pane line")
	local lbl = ns.NewLabel(page, "A dim label", 640, y - 4)

	local lists = ns.BuildKitLists(pages[2])
	local menus = ns.BuildKitMenus(pages[3])
	Select(1)

	win.kit = { tabs = tabs, pages = pages, page = page, lists = lists, menus = menus, buttons = { b1, b2, b3 }, checks = { c1, c2 }, boxes = { e1, n1, s1, h1 }, textArea = ta, allowed = allowed, line = line, label = lbl, scroll = sf, tipOwner = hit }
end

-- Page 2: a sortable list of 200 sample entries and a pie
function ns.BuildKitLists(page)
	local h = ns.NewHeading(page, "A list of 200 sample entries (click a header to sort) and a pie")
	h:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -10)
	local data = {}
	for i = 1, 200 do data[i] = { name = "Sample-" .. string.format("%03d", i), n = (i * 37) % 101 } end
	local frame = CreateFrame("Frame", nil, page)
	frame:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -36)
	frame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -330, 8)
	local picked
	local list
	list = ns.NewRows(frame, {
		rowH = 20,
		cols = { { key = "name", text = "Name" }, { key = "n", text = "Blocked", width = 70, justify = "RIGHT" } },
		sort = function(key)
			local asc = not (list.sortKey == key and list.sortAsc)
			table.sort(data, function(a, b)
				if a[key] == b[key] then return a.name < b.name end
				if asc then return a[key] < b[key] end
				return a[key] > b[key]
			end)
			list:SetSort(key, asc)
			list:Redraw()
		end,
		draw = function(row, i)
			row.cells.name:SetText(data[i].name)
			row.cells.n:SetText(tostring(data[i].n))
			row.sel:SetShown(picked == data[i])
		end,
		click = function(row, i)
			picked = (picked ~= data[i]) and data[i] or nil
			list:Redraw()
		end,
		emptyClick = function() picked = nil; list:Redraw() end,
	})
	list:SetCount(#data)

	local pie = ns.NewPie(page, 116, function() end)
	pie.frame:SetPoint("TOPLEFT", page, "TOPRIGHT", -290, -60)
	pie:Set({
		{ value = 12, r = 0.31, g = 0.76, b = 0.97, text = "This session" },
		{ value = 40, draw = 28, r = 1.00, g = 0.72, b = 0.30, text = "Last 24 hours", within = { [1] = true } },
		{ value = 25, r = 0.58, g = 0.46, b = 0.80, text = "Earlier" },
	})
	pie.tip = function(i) return ({ "This session", "Last 24 hours", "Earlier" })[i] end
	local note = ns.NewText(page, 11)
	note:SetPoint("TOPLEFT", pie.frame, "BOTTOMLEFT", -20, -12)
	note:SetWidth(240)
	note:SetWordWrap(true)
	note:SetTextColor(1, 1, 1, 0.7)
	note:SetText("Hover a slice: the others dim and its count shows. The last 24 hours lights this session too.")
	return { list = list, data = data, pie = pie }
end

-- Page 3: drop-downs, a right-click menu and the three popups
function ns.BuildKitMenus(page)
	local h = ns.NewHeading(page, "Drop-downs, a right-click menu and popups")
	h:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -10)
	local result = ns.NewText(page, 12)
	result:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 12, 12)
	result:SetTextColor(1, 1, 1, 0.7)
	local function Say(text) result:SetText("Last: " .. text) end

	local function Label(text, y)
		local fs = ns.NewText(page, 12)
		fs:SetPoint("TOPLEFT", page, "TOPLEFT", 12, y - 4)
		fs:SetTextColor(1, 1, 1, 0.7)
		fs:SetText(text)
	end

	-- one of a set
	local times = { "This session", "Last 24 hours", "All time", "Custom range" }
	local time = 1
	Label("Pick one", -40)
	local dd1 = ns.NewDropdown(page, 190, function(m)
		for i, t in ipairs(times) do
			m:Radio(t, function() return time == i end, function() time = i; Say(t); page.dd1:SetLabel(t) end)
		end
	end)
	dd1:SetPoint("TOPLEFT", page, "TOPLEFT", 140, -38)
	dd1:SetLabel(times[time])
	page.dd1 = dd1

	-- ticks (stays open)
	local types = { "Whisper", "Say", "Yell", "Channel", "Guild", "Party", "Instance" }
	local on = {}
	for i = 1, #types do on[i] = true end
	local function TypesLabel()
		local n = 0
		for i = 1, #types do if on[i] then n = n + 1 end end
		return n == #types and "All types" or (n .. " of " .. #types .. " types")
	end
	Label("Tick several", -72)
	local dd2
	dd2 = ns.NewDropdown(page, 150, function(m)
		m:Title("Types")
		for i, t in ipairs(types) do
			m:Check(t, function() return on[i] end, function() on[i] = not on[i]; dd2:SetLabel(TypesLabel()); Say(TypesLabel()) end)
		end
		m:Divider()
		m:Button("All types", function() for i = 1, #types do on[i] = true end; dd2:SetLabel(TypesLabel()); Say("All types") end)
	end)
	dd2:SetPoint("TOPLEFT", page, "TOPLEFT", 140, -70)
	dd2:SetLabel(TypesLabel())

	-- a long list scrolls
	Label("Long list", -104)
	local dd3 = ns.NewDropdown(page, 190, function(m)
		for i = 1, 30 do m:Button("Entry " .. i, function() Say("Entry " .. i) end) end
	end)
	dd3:SetPoint("TOPLEFT", page, "TOPLEFT", 140, -102)
	dd3:SetLabel("Choose an entry")

	-- right-click menu
	Label("Right-click", -140)
	local area = CreateFrame("Button", nil, page)
	area:SetPoint("TOPLEFT", page, "TOPLEFT", 140, -136)
	area:SetSize(190, 24)
	area:RegisterForClicks("RightButtonUp", "LeftButtonUp")
	ns.Fill(area, { 1, 1, 1, 0.06 }, -6)
	local at = ns.NewText(area, 12)
	at:SetPoint("CENTER")
	at:SetText("Right-click here")
	area:SetScript("OnClick", function(self, button)
		if button ~= "RightButton" then return end
		ns.ContextMenu(self, function(m)
			m:Title("Badguy-Area52")
			m:Button("Show details", function() Say("Show details") end)
			m:Button("Block history (12)", function() Say("Block history") end)
			m:Divider()
			m:Button("Remove", function() Say("Remove") end)
		end)
	end)

	-- popups
	Label("Popups", -176)
	local b1 = ns.NewButton(page, "Confirm...", 110, function()
		ns.Confirm({ title = "Pour Social Score", text = "Remove Badguy-Area52 from the ignore list?\n\nTheir block history is removed too.",
			accept = "Remove", onAccept = function() Say("Confirmed") end, onCancel = function() Say("Cancelled") end })
	end)
	b1:SetPoint("TOPLEFT", page, "TOPLEFT", 140, -174)
	local b2 = ns.NewButton(page, "Copy...", 110, function()
		ns.CopyText({ title = "Pour Social Score Export", subtitle = "Copy the string below (40 characters)",
			text = "PSS1:abcdefghijklmnopqrstuvwxyz0123456789" })
		Say("Copy shown")
	end)
	b2:SetPoint("LEFT", b1, "RIGHT", 8, 0)
	local b3 = ns.NewButton(page, "Import...", 110, function()
		ns.ImportText({ title = "Pour Social Score Import", subtitle = "Paste a Pour Social Score export string below",
			accept = "Import", onAccept = function(text) Say("Imported " .. #text .. " characters") end })
	end)
	b3:SetPoint("LEFT", b2, "RIGHT", 8, 0)
	-- a timed confirm (3.5.0): the cancel button counts down
	local b4 = ns.NewButton(page, "Timed confirm...", 110, function()
		ns.Confirm({ title = "Keep Settings?", text = "Keep the new settings?\n\nThey are put back when the count reaches 0.",
			accept = "Keep", cancel = "Revert", timeout = 15,
			onAccept = function() Say("Kept") end, onCancel = function() Say("Reverted") end,
			onTimeout = function() Say("Timed out") end })
	end)
	b4:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -6)
	-- a confirm with a name field (3.6.0: the AddOns tab's Save Set and Rename Set)
	local b5 = ns.NewButton(page, "Name...", 110, function()
		ns.Confirm({ title = "Save Set?", text = "Name the new set.", accept = "Save", name = { text = "Raid", max = 32 },
			onAccept = function(_, typed) Say("Saved as " .. tostring(typed)) end })
	end)
	b5:SetPoint("LEFT", b4, "RIGHT", 8, 0)
	-- a Blizzard client file by path with its fallback (3.6.0: ns.FileTexture)
	local fileBox = CreateFrame("Frame", nil, page)
	fileBox:SetSize(18, 18)
	fileBox:SetPoint("LEFT", b5, "RIGHT", 12, 0)
	local fileTex = fileBox:CreateTexture(nil, "ARTWORK")
	fileTex:SetAllPoints()
	local fileGlyph = ns.NewText(fileBox, 16)
	fileGlyph:SetPoint("CENTER", fileBox, "CENTER", 0, -3)
	fileGlyph:SetText("*")
	local hasFile = ns.FileTexture(fileTex, "Interface\\Glues\\CharacterSelect\\Glues-AddOn-Icons", { 0.75, 1, 0, 1 })
	fileTex:SetShown(hasFile)
	fileGlyph:SetShown(not hasFile)

	-- the results picker (Player Search, Guild Search) over a frame of its own
	Label("Results picker", -212)
	local over = CreateFrame("Frame", nil, page)
	over:SetPoint("TOPLEFT", page, "TOPLEFT", 520, -40)
	over:SetSize(400, 200)
	local picker = ns.NewPicker(page, over, {
		cols = { { key = "name", text = "Name" } },
		fill = function(c, it) c.name:SetText(it.name) end,
		toggle = function(it) if it.listed then return false end it.ticked = not it.ticked return true end,
		tickAll = function(items) for _, it in ipairs(items) do if not it.listed then it.ticked = true end end end,
		save = function() Say("Picker saved") end,
		close = function() page.picker:Hide() end,
	})
	picker.items[1] = { name = "Badguy-Area52", ticked = true }
	picker.items[2] = { name = "Spammer-Area52" }
	picker.items[3] = { name = "Known-Area52", listed = true }
	picker:ShowItems("3 players found")
	page.picker = picker

	return { picker = picker, pick = dd1, ticks = dd2, long = dd3, area = area, confirm = b1, timed = b4, name = b5, file = fileBox, copy = b2, import = b3, result = result, types = on }
end
