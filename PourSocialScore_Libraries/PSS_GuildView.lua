------------------------------------------------------------------------
-- POUR SOCIAL SCORE - GUILD IGNORE LIST VIEW (for PourSocialScore_UI)
--
-- What the window's Guild Ignore List tab shows and does, worked out here
-- so the tab only draws: the grouped list's sort, search and selection,
-- each row's text and tooltip, Scan All's status, the Add / Exclude entry
-- rows, Guild Search and its results picker, and the Events specs. Read
-- through PSS_GuildQuery.lua and changed through the guild setters.
--   local v = M.PSS_GuildListNew()     the list's state
--   v:Resort()                          n shown (v.rows filled by M.PSS_GuildRows)
--   v:SortBy(key), v:SetFind(text), v:CountText()
--   v:IsSel(item), v:Select(kind, value), v:Click(item, now)
--   M.PSS_GuildRowCells(item, find, nested, into)   guild / members / total / scan text, dim
--   M.PSS_GuildRowTip(item)
--   M.PSS_GuildScanTip(g)               a guild's sweep (g) or Scan All (nil)
--   M.PSS_GuildAddFromText(text), M.PSS_GuildExcludeFromText(text)
--   M.PSS_GuildSearchFromText(text, mode)
--   M.PSS_GuildPickerItems(found, mode, into), M.PSS_GuildPickerTitle(n, query, mode)
--   M.PSS_GuildPickerSave(items, mode), M.PSS_GuildPickerClose(mode)
--   M.PSS_GuildNoneFound(query, mode)   the text for no results, and the
--                                       name to exclude anyway (or nil);
--                                       M.PSS_GuildExcludeAnyway(name)
--   M.PSS_GUILD_SEARCH_OWNER            the window's Guild Search tag
--   M.PSS_AllGuildsSpec(), M.PSS_GuildEventsSpec(key), M.PSS_GroupEventsSpec(k)
--   M.PSS_GuildGroupLabel(k)
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M
local History = M.PSS_History

local tostring, pairs, ipairs, setmetatable, concat = tostring, pairs, ipairs, setmetatable, table.concat

-- the Managed Communities row is selected as "managed"
local MANAGED = "__managed"
local MANAGED_PREFIX = "Managed Communities - "
local DOUBLE_CLICK = 0.35

M.PSS_GUILD_MANAGED = MANAGED
-- Guild Search results go to the window that asked (the old window takes
-- only searches without an owner)
M.PSS_GUILD_SEARCH_OWNER = "window"

------------------------------------------------------------------------
-- The list: sort, search, selection
------------------------------------------------------------------------
local List = {}
List.__index = List

-- selKind: "guild" (sel = key), "group" (key), "managed", "exclHeader",
-- "excl" (name), or nil
function M.PSS_GuildListNew()
	return setmetatable({ key = "guild", asc = true, find = "", rows = { nest = true }, n = 0, dirty = true }, List)
end

function List:Resort()
	local _, n = M.PSS_GuildRows(self.key, self.asc, self.find, self.rows)
	self.n, self.dirty = n, false
	return n
end

function List:SortBy(key)
	if self.key == key then
		self.asc = not self.asc
	else
		self.key, self.asc = key, true
	end
end

function List:SetFind(text)
	text = text or ""
	if text == self.find then return false end
	self.find = text
	return true
end

function List:CountText()
	local all = M.PSS_GuildCount()
	if self.find ~= "" then return ("%d of %d"):format(self.n, all) end
	return ("%d guild rule%s"):format(all, all == 1 and "" or "s")
end

function List:IsSel(item)
	if item.managedHeader then return self.selKind == "managed" end
	if item.header then return self.selKind == "group" and self.sel == item.groupKey end
	if item.exclHeader then return self.selKind == "exclHeader" end
	if item.exclItem then return self.selKind == "excl" and self.sel == item.name end
	return self.selKind == "guild" and self.sel == item.key
end

function List:Select(kind, value)
	self.selKind, self.sel = kind, value
end

-- A click on a row. A heading opens or closes (and is selected); a guild is
-- selected, or deselected when it was; a second click on the same guild
-- within 0.35 s returns "members" (its members view). Returns what to do
-- next: "resort" (the list changed shape), "select", "members" or nil.
function List:Click(item, now)
	if not item then return nil end
	if item.managedHeader then
		M.PSS_SetGuildGroupOpen(M.PSS_GUILD_MANAGED_SHUT, item.open)
		self:Select("managed", MANAGED)
		return "resort"
	elseif item.header then
		M.PSS_SetGuildGroupOpen(item.groupKey, not item.open)
		self:Select("group", item.groupKey)
		return "resort"
	elseif item.exclHeader then
		M.PSS_SetGuildGroupOpen(M.PSS_GUILD_EXCL_OPEN, not item.open)
		self:Select("exclHeader", true)
		return "resort"
	elseif item.exclItem then
		self:Select("excl", item.name)
		return "select"
	end
	now = now or GetTime()
	if self.lastKey == item.key and now - (self.lastAt or 0) < DOUBLE_CLICK then
		self.lastKey = nil
		self:Select("guild", item.key)
		return "members"
	end
	self.lastKey, self.lastAt = item.key, now
	if self.selKind == "guild" and self.sel == item.key then self:Select(nil, nil) else self:Select("guild", item.key) end
	return "select"
end

------------------------------------------------------------------------
-- Row text
------------------------------------------------------------------------
-- how many default guild lists have their rule on
local function ManagedOn()
	local n = 0
	for k in pairs(M.PSS_ManagedGroups()) do
		if M.PSS_ManagedGroupActive(k) then n = n + 1 end
	end
	return n
end

-- into: guild, members, total, scan (texts) and dim (true: a group whose
-- rule is off; nothing in it is blocked). find: the search shown.
function M.PSS_GuildRowCells(item, find, nested, into)
	into.dim = false
	if item.managedHeader then
		into.guild = (item.open and "[-] " or "[+] ") .. "|cffffd100Managed Communities|r"
			.. ("  |cffaaaaaa(%d)|r"):format(item.groups)
		into.members, into.total = item.members, item.bc.total or 0
		into.scan = ("|cffaaaaaa%d of %d on|r"):format(ManagedOn(), item.groups)
	elseif item.header then
		-- under the Managed Communities row: indented, without its prefix
		local name = item.name
		if item.nested and name:sub(1, #MANAGED_PREFIX) == MANAGED_PREFIX then name = name:sub(#MANAGED_PREFIX + 1) end
		into.guild = (item.nested and "   " or "") .. (item.open and "[-] " or "[+] ") .. "|cffffd100" .. name .. "|r"
			.. ("  |cffaaaaaa(%d guilds)|r"):format(item.guilds)
		into.members, into.total = item.members, item.bc.total or 0
		into.scan = M.PSS_ManagedGroupActive(item.groupKey) and "|cff00ff00Rule ON|r" or "|cffff5555Rule OFF|r"
	elseif item.exclHeader then
		into.guild = (item.open and "[-] " or "[+] ") .. "|cff4dccffGuild Exclusion List|r"
			.. ("  |cffaaaaaa(%d guilds)|r"):format(item.count)
		into.members, into.total, into.scan = "", "", "|cff4dccffNever|r"
	elseif item.exclItem then
		into.guild = "      " .. item.name
		into.members, into.total, into.scan = "", "", "|cff4dccffExcluded|r"
	else
		local g = item.g
		local indent = ""
		if item.inGroup and (find or "") == "" then indent = nested and "         " or "      " end
		into.guild = indent .. tostring(g.name)
		into.members, into.total = g.memberCount or 0, item.bc.total or 0
		into.scan = M.PSS_GuildSweepLabel(item.key)
		into.dim = item.inGroup and not item.groupOn or false
	end
	return into
end

function M.PSS_GuildRowTip(item)
	if item.managedHeader then
		return "Managed Communities\n\nThe default guild lists, each with its own rule on the Chat Filters tab."
			.. "\n\nClick to expand or collapse and see them added up."
	elseif item.header then
		local grp = M.PSS_ManagedGroups()[item.groupKey] or {}
		return (item.name or "") .. "\n\nDefault guild list. Rule on the Chat Filters tab: "
			.. tostring(grp.rule) .. " (" .. tostring(grp.filter) .. ").\n\nClick to expand or collapse."
	elseif item.exclHeader then
		return "Guild Exclusion List\n\nGuilds that no guild rule ever blocks, captures or scans in.\n\nClick to expand or collapse."
	elseif item.exclItem then
		return item.name .. "\n\nExcluded: never blocked by a guild rule."
	end
	return tostring(item.g.name) .. "\n\nClick for the details, double-click for the members."
end

-- The status of a guild's sweep (g) or of Scan All (nil), for the tooltip.
function M.PSS_GuildScanTip(g)
	local t = {}
	local function add(s) t[#t + 1] = s end
	if g then
		add("Scan <" .. tostring(g.name) .. ">")
		add("|cffccccccOne /who per click: the whole guild first. An answer of 50 (the /who cap) is split into narrower searches until each is under the cap.|r")
		local sw = M.PSS_GuildSweep(M.PSS_NormalizeGuild(g.name))
		if not sw then
			add("Not swept yet. Next: " .. M.PSS_HarvestFilter(g.name, {}))
		else
			add(("Searches %d sent, %d queued. Players found %d (%d new)."):format(sw.sent, #sw.queue, sw.seen, sw.added))
			if sw.done then
				add("|cff00ff00Sweep complete: click to start it again.|r")
			elseif sw.queue[1] then
				add("Next: " .. M.PSS_HarvestFilter(g.name, sw.queue[1]))
			end
		end
	else
		add("Scan All")
		add("|cffccccccOne /who per click across every guild, A-Z: each guild is swept to the end before the next.|r")
		local nextG, done, n = M.PSS_ScanAllNext()
		add(("Guilds swept %d / %d."):format(done, n))
		if nextG then add("Now: " .. tostring(nextG.name)) end
	end
	if M.PSS_WhoPending() then
		add("|cffffff00Waiting for the /who answer.|r")
	elseif M.PSS_ScanCooldownActive() then
		add("|cffff8000/who is cooling down.|r")
	else
		add("|cff00ff00Ready: click for the next search.|r")
	end
	if g then add("|cff999999Shift-click: start this guild's sweep over.|r") end
	add("|cff999999Key binding for Scan All: Key Bindings > AddOns > Pour Social Score.|r")
	return concat(t, "\n")
end

------------------------------------------------------------------------
-- The entry rows: Add, Exclude, Guild Search
------------------------------------------------------------------------
local function BoxText(text)
	text = M.trim(text or "") or ""
	if text == "" then return nil end
	return text
end

-- Add Guild: the key to select, or nil (nothing typed)
function M.PSS_GuildAddFromText(text)
	text = BoxText(text)
	if not text then
		M.PSS_Say("Type a guild name in the box first.")
		return nil
	end
	if M.PSS_IsGuildListed(text) then
		M.PSS_Say(("<%s> is already on the Guild Ignore List."):format(text))
	else
		M.PSS_AddGuild(text)
		M.PSS_Say(("<%s> added to the Guild Ignore List."):format(text))
	end
	return M.PSS_NormalizeGuild(text)
end

-- Exclude: true when something was typed (the box is then cleared)
function M.PSS_GuildExcludeFromText(text)
	text = BoxText(text)
	if not text then
		M.PSS_Say("Type a guild name in the box first.")
		return false
	end
	if M.PSS_AddGuildExclusion(text) == false then
		M.PSS_Say(("<%s> is already on the Guild Exclusion List."):format(text))
	else
		M.PSS_Say(("<%s> added to the Guild Exclusion List."):format(text))
	end
	return true
end

-- Guild Search (mode "exclude": for the Guild Exclusion List). Runs a /who
-- straight from the click; true when it went out (the box is then cleared).
function M.PSS_GuildSearchFromText(text, mode)
	if M.PSS_ScanBlockedMsg() then return false end
	text = BoxText(text)
	if not text then
		M.PSS_Say("Type part of a guild name in the box first.")
		return false
	end
	if mode == "exclude" then text = text:gsub('"', "") end
	return M.PSS_GuildSearch(text, mode, M.PSS_GUILD_SEARCH_OWNER) and true or false
end

-- The results picker's entries: { name, listed (already on the list), ticked }
function M.PSS_GuildPickerItems(found, mode, into)
	into = into or {}
	for i = #into, 1, -1 do into[i] = nil end
	for _, name in ipairs(found or {}) do
		local listed
		if mode == "exclude" then listed = M.PSS_IsGuildExcluded(name) else listed = M.PSS_IsGuildListed(name) end
		into[#into + 1] = { name = name, listed = listed and true or false }
	end
	return into
end

function M.PSS_GuildPickerTitle(n, query, mode)
	local exclude = mode == "exclude"
	return (exclude and "Guild Exclusion Search: " or "Guild Search: ")
		.. ("%d guild(s) found for \"%s\". Click the guilds to "):format(n, query or "")
		.. (exclude and "exclude." or "add.")
end

-- Save the ticked entries; the count saved
function M.PSS_GuildPickerSave(items, mode)
	local names = {}
	for _, it in ipairs(items) do
		if it.ticked and not it.listed then names[#names + 1] = it.name end
	end
	if #names > 0 then
		if mode == "exclude" then M.PSS_SaveGuildExclusions(names) else M.PSS_SaveGuildSearch(names) end
	end
	return #names
end

-- the picker closed: a guild search's cache of who was seen is dropped
function M.PSS_GuildPickerClose(mode)
	if mode ~= "exclude" then M.PSS_ForgetGuildSearch() end
end

-- No results: the message, and for the exclusion search the name to offer
-- to add anyway (nil: nothing to offer).
function M.PSS_GuildNoneFound(query, mode)
	if mode == "exclude" then
		local name = M.trim(((query or ""):gsub('"', ""))) or ""
		if name == "" then return nil end
		return ("No guild named <%s> was found online.\n\nAdd it to the Guild Exclusion List anyway?"):format(name), name
	end
	M.PSS_Say(("Guild Search found no guilds for \"%s\"."):format(query or ""))
	return nil
end

function M.PSS_GuildExcludeAnyway(name)
	M.PSS_AddGuildExclusion(name)
	M.PSS_Say(("<%s> added to the Guild Exclusion List."):format(name))
end

------------------------------------------------------------------------
-- Events specs (the Events tab reads them; nothing here loads Logging)
------------------------------------------------------------------------
local allGuilds

function M.PSS_AllGuildsSpec()
	if allGuilds then return allGuilds end
	allGuilds = {
		kind = "guild", id = false, allText = "All Guilds", source = "guilds",
		label = function() return "All Guilds" end,
		read = M.PSS_GetGuildBlockHistory,
		reset = M.PSS_ResetAllGuildEvents,
	}
	return allGuilds
end

local function GuildLabel(key)
	local _, g = M.PSS_FindGuildRule(key)
	return g and tostring(g.name or key) or nil
end

function M.PSS_GuildEventsSpec(key)
	return {
		kind = "guild", id = key, allText = "All Guilds", all = M.PSS_AllGuildsSpec,
		label = GuildLabel,
		read = M.PSS_GetGuildBlockHistory,
		reset = M.PSS_ResetGuildBlockHistory,
		owner = History.GuildKey, counts = M.PSS_GetGuildBlockCounts,
	}
end

-- a default guild list (or MANAGED: every one)
function M.PSS_GuildGroupLabel(k)
	if k == MANAGED then return "Managed Communities" end
	local grp = M.PSS_ManagedGroups()[k]
	return grp and tostring(grp.name or k) or nil
end

function M.PSS_GroupEventsSpec(k)
	return {
		kind = "group", id = k, confirm = true, allText = "All Guilds", all = M.PSS_AllGuildsSpec,
		label = M.PSS_GuildGroupLabel,
		read = M.PSS_GroupEvents,
		reset = M.PSS_ResetGroupEvents,
	}
end
