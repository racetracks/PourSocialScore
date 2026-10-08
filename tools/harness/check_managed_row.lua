-- The PSS window's Guild Ignore List (3.3.0-dev003): the default guild
-- lists sit under one Managed Communities row, as in the EllesmereUI window.
--   * the row is first, its numbers are its groups' added up and equal the
--     EllesmereUI window's Managed Communities row (M.PSS_GuildRows nest)
--   * a click collapses it (no group rows under it) and opens it again
--   * its right-click menu turns every rule off and on, and collapses
local fails = 0
local function check(ok, msg) if not ok then print("  FAIL managed row: " .. msg); fails = fails + 1 end end
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- right-click menus: record the buttons
local menu
MenuUtil.CreateContextMenu = function(_, build)
	menu = {}
	local root = {
		CreateTitle = function(_, t) menu.title = t end,
		CreateButton = function(_, t, fn) menu[#menu + 1] = { text = t, fn = fn } end,
	}
	build(nil, root)
end
local function pick(text)
	for _, b in ipairs(menu or {}) do if b.text == text then b.fn(); H.RunTimers(); return true end end
	return false
end

M.PSS_GUI()
H.RunTimers()
_G.PSSTabGuild:GetScript("OnClick")(_G.PSSTabGuild)
H.RunTimers()
local f = _G.PSSGuildTabFrame
local groups = 0
for _ in pairs(M.PSS_ManagedGroups()) do groups = groups + 1 end
local eui = M.PSS_GuildRows("guild", true, nil, { nest = true })
local mh = eui.managedHead
check(groups > 0 and mh ~= nil, "no managed groups to show (" .. groups .. ")")
local row = f.managedRow
check(row and row:IsShown(), "no Managed Communities row")
if row and mh then
	check(plain(row.label:GetText()):find("^%[%-%] Managed Communities") ~= nil, "label " .. plain(row.label:GetText()))
	check(tonumber(row.count:GetText()) == mh.members, ("members %s, EllesmereUI %d"):format(tostring(row.count:GetText()), mh.members))
	local shown = 0
	for _, r in ipairs(f.groupRows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == groups, ("%d group rows under it, %d groups"):format(shown, groups))
	-- every group row name lost its "Managed Communities - " prefix
	for _, r in ipairs(f.groupRows) do
		if r:IsShown() then check(not plain(r.label:GetText()):find("Managed Communities %- "), "prefix kept: " .. plain(r.label:GetText())) end
	end
	-- the row's block total equals the groups' added up
	local sum = 0
	for _, it in ipairs(M.PSS_GuildRows("guild", true, nil, { nest = true })) do
		if it.header then sum = sum + (it.bc.total or 0) end
	end
	check((mh.bc.total or 0) == sum, ("total %d, groups %d"):format(mh.bc.total or 0, sum))

	-- click: collapsed, then open again
	row:GetScript("OnClick")(row, "LeftButton")
	H.RunTimers()
	shown = 0
	for _, r in ipairs(f.groupRows) do if r:IsShown() then shown = shown + 1 end end
	check(shown == 0 and plain(f.managedRow.label:GetText()):find("^%[%+%]"), "click did not collapse (" .. shown .. " group rows)")
	check(M.PSS_GuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT), "closed state not saved")
	row:GetScript("OnClick")(row, "LeftButton")
	H.RunTimers()
	check(not M.PSS_GuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT), "open again still saved as closed")

	-- right-click: every rule off, then on
	local was = {}
	for k in pairs(M.PSS_ManagedGroups()) do was[k] = M.PSS_ManagedGroupActive(k) end
	row:GetScript("OnClick")(row, "RightButton")
	check(menu and menu.title == "Managed Communities", "no right-click menu")
	if pick("Turn every rule Off") then
		for k in pairs(M.PSS_ManagedGroups()) do check(not M.PSS_ManagedGroupActive(k), k .. " still on") end
		check(plain(f.managedRow.state:GetText()) == ("0 of %d on"):format(groups), "state " .. plain(f.managedRow.state:GetText()))
	end
	row:GetScript("OnClick")(row, "RightButton")
	check(pick("Turn every rule On"), "no Turn every rule On")
	for k in pairs(M.PSS_ManagedGroups()) do check(M.PSS_ManagedGroupActive(k), k .. " still off") end
	for k, on in pairs(was) do M.PSS_SetManagedGroupActive(k, on) end
	row:GetScript("OnClick")(row, "RightButton")
	check(pick("Collapse") and M.PSS_GuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT), "menu Collapse")
	row:GetScript("OnClick")(row, "RightButton")
	check(pick("Expand") and not M.PSS_GuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT), "menu Expand")
end
print(fails == 0 and ("PASS managed row (%d groups)"):format(groups) or ("FAIL managed row: " .. fails))
