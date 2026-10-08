-- The new window's right-click menus (3.4.0.21, C2), as a run.lua script on
-- any save, real ones included. In Modern (and Classic) a right-click on a
-- row opens Blizzard's menu (MenuUtil, recorded here) with the entries
-- Libraries describes (PSS_RowMenus.lua); in Dark our own menu list opens
-- instead. A right-click selects the row; the entries do what the pane's
-- buttons do (Remove and the sender's removal ask first); opening a menu
-- never loads the block history. Rows: a player, a guild, a filter, a
-- blocked line's sender.
local fail = false
local function check(ok, msg) if not ok then print("FAIL menus: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded
local loggingBefore = loaded("PourSocialScore_Logging")

-- record Blizzard's menu: the generator is run on a root that keeps its entries
local got, calls = nil, 0
MenuUtil.CreateContextMenu = function(owner, gen)
	calls = calls + 1
	got = {}
	local root = {}
	function root:CreateButton(text, fn) got[#got + 1] = { text = text, fn = fn } return {} end
	function root:CreateTitle(text) got[#got + 1] = { title = text } end
	function root:CreateDivider() got[#got + 1] = { divider = true } end
	function root:CreateCheckbox(text, isOn, fn) got[#got + 1] = { text = text, isOn = isOn, fn = fn, check = true } return {} end
	gen(owner, root)
end
local function find(text)
	for _, e in ipairs(got or {}) do
		if e.text and e.text:find(text, 1, true) then return e end
	end
end
local function titled(text)
	return got and got[1] and got[1].title and got[1].title:find(text, 1, true) ~= nil
end
local function rclick(list, i)
	got = nil
	list.spec.click(list.rows[1], i, "RightButton")
end

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window
check(win and win:IsShown(), "/pss gui did not open the window")
local ui = H.Private("PourSocialScore_GUI")

------------------------------------------------------------------------
-- Player Ignore List
------------------------------------------------------------------------
win.tabs[1]._scripts.OnClick(win.tabs[1])
local page = win.pages[1]
local list, pane = page.list, page.pane
M.PSS_ImportListEntry("Menuplayer-Realm1", "Horde", "", "player")
M.PSS_PlayersChanged()
local entry = M.Proper(M.addServer("Menuplayer-Realm1"))
check(M.PSS_PlayerPosition(entry) > 0, "player not added")
local at
for i = 1, list.count do
	list.spec.draw(list.rows[1], i)
	if list.rows[1].cells.name:GetText() == "Menuplayer" then at = i break end
end
check(at ~= nil, "player row not found")
if at then
	rclick(list, at)
	check(got and titled("Menuplayer"), "player menu not opened or no title")
	check(pane.body:IsShown() and pane.heading:GetText():find("Menuplayer", 1, true), "right-click did not select the row")
	check(find("Block History (0)") and find("Remove Player") and find("Reset Block History"), "player menu entries")
	check(not find("Reset Expiration"), "Reset Expiration offered without an expiry")
	-- an exception is a tick (ticked = it happens); a click turns it the
	-- other way, a second click takes the exception off
	local heading
	for _, e in ipairs(got or {}) do
		if e.title and e.title:find("For this player", 1, true) then heading = true end
	end
	check(heading, "no exceptions heading")
	for n, o in ipairs(M.PSS_OverrideOptions()) do
		local base = M.PSS_Opt(o.key) == true
		local ov = find(M.PSS_OVERRIDE_SHORT[o.key])
		check(ov and ov.check and ov.isOn() == base, o.key .. ": exception tick missing or not on the default")
		if ov then
			ov.fn()
			local p = M.PSS_GetPlayerRecord(entry)
			check(M.PSS_OverrideValue(p, o.key) == (not base) and ov.isOn() == (not base)
				and pane.exceptions.boxes[n]:GetChecked() == (not base), o.key .. ": the tick did not make an exception")
			ov.fn()
			check(M.PSS_OverrideValue(p, o.key) == nil, o.key .. ": the second tick did not take the exception off")
		end
	end
	-- an expiry: Reset Expiration takes it off
	M.PSS_PlayerCommitExpiry(entry, "30")
	rclick(list, at)
	local re = find("Reset Expiration")
	check(re ~= nil, "Reset Expiration missing with an expiry")
	if re then
		re.fn()
		check(M.PSS_PlayerRow(M.PSS_PlayerPosition(entry), {}).expire == 0, "Reset Expiration did not clear it")
	end
	-- Remove asks first
	rclick(list, at)
	find("Remove Player").fn()
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown() and cf.text:GetText():find(entry, 1, true), "no confirm before removing")
	if cf then cf.accept._scripts.OnClick(cf.accept) end
	check(M.PSS_PlayerPosition(entry) == 0, "menu Remove did not remove the player")
end

-- Dark: our own menu list, not Blizzard's
M.PSS_SetOpt("uiSkin", "global", 1)
M.PSS_ImportListEntry("Darkmenu-Realm1", "Horde", "", "player")
M.PSS_PlayersChanged()
local before = calls
list.spec.click(list.rows[1], 1, "RightButton")
check(calls == before and _G.PSS_Menu and _G.PSS_Menu:IsShown(), "Dark did not open our menu list")
if _G.PSS_Menu then _G.PSS_Menu:Hide() end
M.PSS_SetOpt("uiSkin", "global", 2)

------------------------------------------------------------------------
-- A blocked line's sender (Events tab, a pane's Event History)
------------------------------------------------------------------------
local sender = M.Proper(M.addServer("Sendertest-Realm2"))
ui.SenderMenu(list.rows[1], "Sendertest-Realm2")
check(got and titled(sender) and find("Add to Ignore"), "sender menu (not listed)")
if find("Add to Ignore") then find("Add to Ignore").fn() end
check(M.PSS_PlayerPosition(sender) > 0, "sender not added")
ui.SenderMenu(list.rows[1], "Sendertest-Realm2")
check(find("Remove from Ignore") ~= nil, "sender menu (listed)")
if find("Remove from Ignore") then
	find("Remove from Ignore").fn()
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown(), "no confirm before removing the sender")
	if cf then cf.accept._scripts.OnClick(cf.accept) end
end
check(M.PSS_PlayerPosition(sender) == 0, "sender not removed")
got = nil
ui.SenderMenu(list.rows[1], "")
check(got == nil, "a menu for a line without a sender")

------------------------------------------------------------------------
-- Guild Ignore List
------------------------------------------------------------------------
win.tabs[2]._scripts.OnClick(win.tabs[2])
local gpage = win.pages[2]
local glist, V = gpage.list, gpage.state
M.PSS_AddGuild("Menu Check Guild")
gpage.refresh()
local gkey = M.PSS_NormalizeGuild("Menu Check Guild")
local gi
for i, item in ipairs(V.rows) do
	if item.key == gkey and not item.header then gi = i end
end
check(gi ~= nil, "guild row not found")
if gi then
	rclick(glist, gi)
	check(got and titled("Menu Check Guild"), "guild menu title")
	check(V.selKind == "guild" and V.sel == gkey, "right-click did not select the guild")
	check(find("Show Members") and find("Block History (0)") and find("Remove Guild"), "guild menu entries")
	find("Show Members").fn()
	check(V.view == "members" and V.mguild == gkey, "Show Members did not open the members view")
	gpage.navUp()
	check(V.view == "guilds", "members view not closed")
	for i, item in ipairs(V.rows) do
		if item.key == gkey and not item.header then gi = i end
	end
	rclick(glist, gi)
	find("Remove Guild").fn()
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown() and cf.text:GetText():find("Menu Check Guild", 1, true), "no confirm before removing the guild")
	if cf then cf.accept._scripts.OnClick(cf.accept) end
	check(not select(2, M.PSS_FindGuildRule(gkey)), "menu Remove did not remove the guild")
end
-- a heading: the right-click selects it but does not open or close it
gpage.refresh()
for i, item in ipairs(V.rows) do
	if item.managedHeader or item.header or item.exclHeader then
		local open = item.open
		rclick(glist, i)
		check(got and got[1] and got[1].title and (find("Expand") or find("Collapse")), "heading menu")
		check(V.rows[i] and V.rows[i].open == open, "a right-click opened or closed a heading")
		break
	end
end

------------------------------------------------------------------------
-- Chat Filters
------------------------------------------------------------------------
win.tabs[3]._scripts.OnClick(win.tabs[3])
local fpage = win.pages[3]
local flist, FV = fpage.list, fpage.state
local n = M.PSS_FilterNew()
fpage.refresh()
local fi
for i = 1, flist.count do if FV.index[i] == n then fi = i end end
check(fi ~= nil, "filter row not found")
if fi then
	rclick(flist, fi)
	check(got and titled("New Chat Filter"), "filter menu title")
	check(fpage.selected() == n, "right-click did not select the filter")
	check(find("Turn filter On") and find("Copy filter") and find("Remove filter"), "filter menu entries")
	find("Turn filter On").fn()
	check(M.PSS_FilterRow(n, {}).active, "Turn filter On did not")
	local count = M.PSS_FilterCount and M.PSS_FilterCount() or nil
	rclick(flist, fi)
	find("Remove filter").fn()
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown(), "no confirm before removing the filter")
	if cf then cf.accept._scripts.OnClick(cf.accept) end
	check(not M.PSS_FilterRow(n, {}) or M.PSS_FilterRow(n, {}).desc ~= "New Chat Filter", "menu Remove did not remove the filter")
end
-- a built-in: no Remove
for i = 1, flist.count do
	local idx = FV.index[i]
	if idx and M.PSS_IsBuiltinFilter(idx) and not M.PSS_IsGuildRuleFilter(idx) then
		rclick(flist, i)
		check(not find("Remove filter"), "Remove offered on a built-in filter")
		break
	end
end

check(loaded("PourSocialScore_Logging") == loggingBefore, "opening a menu loaded the block history")

if not fail then print("PASS menus") end
