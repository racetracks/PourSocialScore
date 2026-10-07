------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - KIT PREVIEW (temporary)
--
-- While the window is being built (3.4.0), /pss tui shows every control of
-- the kit in the place the tabs will take, so both looks can be checked in
-- game. The window's tabs replace this page (stage B1).
------------------------------------------------------------------------
local ADDON_NAME, ns = ...

function ns.BuildKitPage(win)
	-- the tab row, as the window will have it
	local names = { "Player Ignore List", "Guild Ignore List", "Chat Filters", "Events", "Import/Export", "Options" }
	local tabs, prev = {}, nil
	local function Select(i)
		for j, t in ipairs(tabs) do ns.SetTabSelected(t, j == i) end
	end
	for i, name in ipairs(names) do
		local tab = ns.NewTab(win, name, function() Select(i) end)
		if prev then
			tab:SetPoint("LEFT", prev, "RIGHT", 2, 0)
		else
			tab:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -32)
		end
		tabs[i], prev = tab, tab
	end
	Select(1)

	local page = ns.NewPanel(win)
	page:SetPoint("TOPLEFT", win, "TOPLEFT", 10, -84)
	page:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 10)

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

	y = y - 32
	Label("Tooltip")
	local hover = ns.NewText(page, 12)
	hover:SetPoint("TOPLEFT", page, "TOPLEFT", 120, y - 4)
	hover:SetText("Hover this text")
	local hit = CreateFrame("Frame", nil, page)
	hit:SetAllPoints(hover)
	hit:EnableMouse(true)
	ns.TipOn(hit, hover, "Plain tooltips follow the look: Blizzard's in Blizzard, a dark one in Modern.")

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

	-- Trial: the tab art of Blizzard's new Social window (common-sidetab,
	-- its hover and its selected glow), turned on its side for a top tab
	-- row, to judge in game where it should be used. Clients without the
	-- art (Camelot) show a note instead.
	y = y - 132
	Label("Social tab art")
	local trial = {}
	if ns.HasAtlas("common-sidetab") and ns.HasAtlas("common-sidetab-selected") then
		local tprev
		local function Pick(i)
			for j, t in ipairs(trial) do t.sel:SetShown(j == i); t.label:SetAlpha(j == i and 1 or 0.7) end
		end
		for i, name in ipairs({ "Player Ignore List", "Guild Ignore List", "Chat Filters" }) do
			local t = CreateFrame("Button", nil, page)
			t.label = ns.NewText(t, 11)
			t.label:SetPoint("CENTER", t, "CENTER", 0, -1)
			t.label:SetText(name)
			t:SetSize(t.label:GetStringWidth() + 36, 30)
			local function Art(atlas, layer)
				local tex = t:CreateTexture(nil, layer)
				tex:SetAtlas(atlas)
				-- the art is a tall side tab open on its left: a quarter turn
				-- lays it along the row, open side down, onto the page
				tex:SetRotation(math.pi / 2)
				tex:SetAllPoints(t)
				return tex
			end
			Art("common-sidetab", "BACKGROUND")
			t.sel = Art("common-sidetab-selected", "OVERLAY")
			if ns.HasAtlas("common-sidetab-hover") then Art("common-sidetab-hover", "HIGHLIGHT") end
			t:SetScript("OnClick", function() Pick(i) end)
			if tprev then
				t:SetPoint("LEFT", tprev, "RIGHT", 2, 0)
			else
				t:SetPoint("TOPLEFT", page, "TOPLEFT", 120, y + 4)
			end
			trial[i], tprev = t, t
		end
		Pick(1)
	else
		local note = Label("Not on this client (no common-sidetab art).", 120)
		note:SetTextColor(1, 1, 1, 0.5)
	end

	win.kit = { tabs = tabs, page = page, trial = trial, buttons = { b1, b2 }, checks = { c1, c2 }, boxes = { e1, n1, s1 }, scroll = sf, tipOwner = hit }
end
