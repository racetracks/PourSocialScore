------------------------------------------------------------------------
-- POUR SOCIAL SCORE - RIGHT-CLICK MENUS (for PourSocialScore_UI)
--
-- What each list's right-click menu offers, worked out here so the window
-- only draws it (3.4.0.21, C2). A menu is a list of entries:
--   { kind = "title", text = ... }   { kind = "divider" }
--   { text = ..., act = "...", arg = ... }   a button: the tab runs act
-- The tab maps each act to what its own buttons already do (a confirm for
-- Remove, the Events tab for Block History). Counts come from the counters:
-- opening a menu never loads the block history (PourSocialScore_Logging).
--   M.PSS_PlayerMenu(entry)        a Player Ignore List row
--   M.PSS_GuildRowMenu(item)       a Guild Ignore List row (any kind)
--   M.PSS_MemberMenu(m)            a guild member row
--   M.PSS_FilterMenu(i)            a Chat Filters row
--   M.PSS_SenderMenu(name)         a blocked line (Events, a pane's history)
--   M.PSS_SenderAdd(name), M.PSS_SenderRemoveText(name) / M.PSS_SenderRemove(name)
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M
local L = addon.L

local type, ipairs, pairs, tonumber = type, ipairs, pairs, tonumber

local MANAGED = M.PSS_GUILD_MANAGED		-- the Managed Communities row (PSS_GuildView.lua)

local function Title(t, text) t[#t + 1] = { kind = "title", text = text } end
local function Divider(t) t[#t + 1] = { kind = "divider" } end
local function Button(t, text, act, arg) t[#t + 1] = { text = text, act = act, arg = arg } end

-- the Options a player or a guild can override: one entry each, a click
-- moves it on (Default > On > Off), as the pane's buttons do
local function Overrides(t, target)
	if type(target) ~= "table" then return end
	Divider(t)
	for _, o in ipairs(M.PSS_OverrideOptions()) do
		Button(t, M.PSS_OverrideText(o, M.PSS_OverrideValue(target, o.key)), "override", o.key)
	end
end

local function HistoryText(n)
	return ("%s (%d)"):format(L["HISTORY_PLAYER"] or "Block History", n or 0)
end

------------------------------------------------------------------------
-- Player Ignore List
------------------------------------------------------------------------
local prow = {}

function M.PSS_PlayerMenu(entry)
	local pos = M.PSS_PlayerPosition(entry)
	local r = pos > 0 and M.PSS_PlayerRow(pos, prow)
	if not r then return nil end
	local t = {}
	Title(t, r.name or entry)
	local p = r.record
	if p then
		Divider(t)
		Button(t, HistoryText(M.PSS_PlayerTotal(p)), "history")
		local guild, listed = M.PSS_PlayerGuildState(p)
		if guild and not listed then Button(t, "Add Guild <" .. guild .. ">", "addGuild", guild) end
	end
	if (tonumber(r.expire) or 0) > 0 then Button(t, L["RCM_3"] or "Reset Expiration", "noExpiry") end
	if p then
		Button(t, L["HISTORY_RESET"] or "Reset Block History", "resetHistory")
		Overrides(t, p)
	end
	Divider(t)
	Button(t, "Remove Player", "remove")
	return t
end

------------------------------------------------------------------------
-- Guild Ignore List: the Managed Communities row, a default list, the
-- Guild Exclusion List and its guilds, a guild
------------------------------------------------------------------------
local function OpenText(open) return open and "Collapse" or "Expand" end

function M.PSS_GuildRowMenu(item)
	if not item then return nil end
	local t = {}
	if item.managedHeader then
		local on, all = 0, 0
		for k in pairs(M.PSS_ManagedGroups()) do
			all = all + 1
			if M.PSS_ManagedGroupActive(k) then on = on + 1 end
		end
		Title(t, "Managed Communities")
		Divider(t)
		if on < all then Button(t, "Turn every rule On", "allRules", true) end
		if on > 0 then Button(t, "Turn every rule Off", "allRules", false) end
		Button(t, OpenText(item.open), "open", MANAGED)
	elseif item.header then
		Title(t, item.name or item.groupKey)
		Divider(t)
		Button(t, M.PSS_ManagedGroupActive(item.groupKey) and "Turn rule Off" or "Turn rule On", "rule", item.groupKey)
		Button(t, OpenText(item.open), "open", item.groupKey)
	elseif item.exclHeader then
		Title(t, "Guild Exclusion List")
		Divider(t)
		Button(t, OpenText(item.open), "open", M.PSS_GUILD_EXCL_OPEN)
	elseif item.exclItem then
		Title(t, item.name)
		Divider(t)
		Button(t, "Remove from Exclusion List", "exclRemove", item.name)
	else
		local g = item.g
		Title(t, tostring(g and g.name or item.key))
		Divider(t)
		Button(t, "Show Members", "members", item.key)
		Button(t, HistoryText(item.bc and item.bc.total), "history", item.key)
		Button(t, L["HISTORY_RESET"] or "Reset Block History", "resetHistory", item.key)
		Overrides(t, g)
		if not M.PSS_IsStaticManagedGuild(item.key) then
			Divider(t)
			Button(t, "Remove Guild", "remove", item.key)
		end
	end
	return t
end

function M.PSS_GuildSetAllRules(on)
	for k in pairs(M.PSS_ManagedGroups()) do M.PSS_SetManagedGroupActive(k, on and true or false) end
end

function M.PSS_MemberMenu(m)
	if type(m) ~= "table" then return nil end
	local t = {}
	Title(t, tostring(m.name))
	Divider(t)
	Button(t, HistoryText(M.PSS_MemberBlockTotal(m)), "history")
	Button(t, L["HISTORY_RESET"] or "Reset Block History", "resetHistory")
	Overrides(t, m)
	Divider(t)
	Button(t, "Remove Member", "remove")
	return t
end

------------------------------------------------------------------------
-- Chat Filters
------------------------------------------------------------------------
local frow = {}

function M.PSS_FilterMenu(i)
	local r = i and M.PSS_FilterRow(i, frow)
	if not r then return nil end
	local t = {}
	Title(t, r.desc ~= "" and r.desc or (L["RCM_10"] or "Chat filter options"))
	Divider(t)
	Button(t, r.active and "Turn filter Off" or "Turn filter On", "toggle", not r.active)
	if not r.guildRule then
		Button(t, "Copy filter", "copy")
		Button(t, HistoryText(r.lines), "history")
		Divider(t)
		Button(t, L["RCM_14"] or "Reset block count", "resetCount")
		Button(t, L["RCM_15"] or "Reset block history", "resetHistory")
	end
	if not r.builtin then
		Divider(t)
		Button(t, L["RCM_12"] or "Remove filter", "remove")
	end
	return t
end

------------------------------------------------------------------------
-- A blocked line's sender (Events tab, a pane's Event History): on or off
-- the Player Ignore List. name: as stored on the line (a readable name;
-- the core never stores a secret).
------------------------------------------------------------------------
local function SenderEntry(name)
	if type(name) ~= "string" or name == "" or name == UNKNOWN then return nil end
	return M.Proper(M.addServer(name))
end

function M.PSS_SenderMenu(name)
	local full = SenderEntry(name)
	if not full then return nil end
	local t = {}
	Title(t, full)
	Divider(t)
	if M.PSS_PlayerPosition(full) > 0 then
		Button(t, L["RCM_4"] or "Remove from Ignore", "senderRemove", full)
	else
		Button(t, L["RCM_6"] or "Add to Ignore", "senderAdd", full)
	end
	return t
end

function M.PSS_SenderAdd(full)
	if full then M.PSS_AddPlayer(full) end
end

function M.PSS_SenderRemoveText(full)
	local pos = full and M.PSS_PlayerPosition(full) or 0
	if pos <= 0 then return nil end
	return M.PSS_PlayerRemoveText(M.PSS_PlayerEntry(pos))
end

function M.PSS_SenderRemove(full)
	local pos = full and M.PSS_PlayerPosition(full) or 0
	if pos > 0 then M.PSS_RemovePlayerAt(pos) end
end
