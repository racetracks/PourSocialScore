------------------------------------------------------------------------
-- POUR SOCIAL SCORE - THE LOGIC OF SEARCH EVERYWHERE (warehouse-helper,
-- one-build plan STP-p15). The window (PourSocialScore_GUI/PSS_SearchEverywhere.lua)
-- only draws; what it shows is made here from the services, and every
-- service answer is checked: a failed call is an empty set, never nil.
--   M.PSS_CallSet(name, input, opts)   a record set always
--   M.PSS_WhSearchRows(text)           rows { key, name, icon, total, where } for a search text
--   M.PSS_WhShowLocation(key)          says where an item is (or hands it to the addon that asked)
--   M.PSS_WhGold()                     total copper and a breakdown text
--   M.PSS_WhOpenEverywhere(text)       opens the window (a user entry: /pss wh)
-- Loaded with Libraries; returns at the top while the Warehouse is off.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

if not M.PSS_On("warehouse") then return end

local type, ipairs, tonumber, tostring, pcall = type, ipairs, tonumber, tostring, pcall
local sort, concat = table.sort, table.concat

local EMPTY = { cols = {}, n = 0 }

function M.PSS_CallSet(name, input, opts)
	local r, err = M.PSS_Call(name, input, opts)
	if err or type(r) ~= "table" or type(r.n) ~= "number" then return { cols = {}, n = 0 } end
	return r
end

local MAXROWS = 200

function M.PSS_WhSearchRows(text)
	local rows = {}
	if type(text) ~= "string" or not text:find("%S") then return rows end
	local found = M.PSS_CallSet("item.search", nil, { text = text, pageSize = MAXROWS })
	if found.n == 0 then return rows end
	local keys = { cols = { "item" }, n = found.n }
	for i = 1, found.n do keys[i] = { found[i][1] } end
	local sum = M.PSS_CallSet("wh.sum", keys, { hidden = false, realms = M.PSS_WhRealmScope() })
	local total = {}
	for i = 1, sum.n do total[sum[i][1]] = (total[sum[i][1]] or 0) + (sum[i][12] or 0) end
	for i = 1, found.n do
		local key, name = found[i][1], found[i][2]
		local id = M.PSS_ItemId and M.PSS_ItemId(key)
		local icon
		if id and M.PSS_ItemText then
			local n, ic = M.PSS_ItemText(id)
			if (not name or name == "") and n then name = n end
			icon = ic
		end
		local list = M.PSS_WhHolderList and M.PSS_WhHolderList(key)
		local where = ""
		if list and #list > 0 then
			where = list[1][2]
			if #list > 1 then where = where .. " and " .. (#list - 1) .. " more" end
		end
		if (total[key] or 0) > 0 then rows[#rows + 1] = { key = key, name = name ~= "" and name or key, icon = icon, total = total[key] or 0, where = where } end
	end
	sort(rows, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.key < b.key end)
	return rows
end

function M.PSS_WhShowLocation(key)
	if type(key) ~= "string" then return end
	if type(M.PSS_GwShow) == "function" then
		-- an addon that registered for locations (the shim) is told; it opens its own view
		local ok = pcall(M.PSS_GwShow, key)
		if ok then return end
	end
	local list = M.PSS_WhHolderList and M.PSS_WhHolderList(key)
	if not list or #list == 0 then M.ShowMsg("Nobody holds that item.") return end
	local id = M.PSS_ItemId and M.PSS_ItemId(key)
	local name = id and M.PSS_ItemText and M.PSS_ItemText(id) or key
	M.ShowMsg(tostring(name) .. ":")
	for _, h in ipairs(list) do M.ShowMsg("  " .. h[2] .. ": " .. h[3]) end
end

-- F2, F4: the saved gold as { name, copper, realm } rows inside the realm scope. A gold value whose entity is not
-- saved any more has no name to show: it is left out and counted in `orphans` (/pss wh status reports it), never
-- printed as "?". Hidden entities are named too, so a name always resolves.
function M.PSS_WhGoldRows()
	local gold = M.PSS_CallSet("money.gold")
	local ids = { cols = { "ent" }, n = gold.n }
	for i = 1, gold.n do ids[i] = { gold[i][1] } end
	local ents = M.PSS_CallSet("wh.ent", ids)
	local at = {}
	for i = 1, ents.n do at[ents[i][1]] = ents[i] end
	local scope = M.PSS_WhRealmScope()
	local list, orphans, copper = {}, 0, 0
	local kept = { cols = { "ent", "copper" }, n = 0 }
	for i = 1, gold.n do
		local e = at[gold[i][1]]
		if not e then
			orphans = orphans + 1
		elseif not (scope and e[2] == "c" and not scope[e[4]]) then
			local name = (e[2] == "w" and "Warband bank") or (e[2] == "g" and e[3] .. " (guild bank)") or e[3]
			list[#list + 1] = { name, gold[i][2], e[4] or "" }
			copper = copper + gold[i][2]
			kept.n = kept.n + 1
			kept[kept.n] = gold[i]
		end
	end
	sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
	return list, copper, orphans, kept
end

function M.PSS_WhGold()
	local list, total = M.PSS_WhGoldRows()
	local lines = {}
	for i, r in ipairs(list) do lines[i] = r[1] .. "  " .. (M.PSS_MoneyText and M.PSS_MoneyText(r[2], false) or tostring(r[2])) end
	return total, concat(lines, "\n")
end

-- the window loads only as the player asks (/pss wh): PSS 02 11A
function M.PSS_WhOpenEverywhere(text)
	if M.PSS_Need("GUI") and M.PSS_EverywhereShow then return M.PSS_EverywhereShow(text) end
end
