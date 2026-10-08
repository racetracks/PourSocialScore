------------------------------------------------------------------------
-- POUR SOCIAL SCORE - PLAYER IGNORE LIST VIEW (for PourSocialScore_UI)
--
-- What the window's Player Ignore List tab shows and does, worked out here
-- so the tab only draws: the list's sort and search, each column's text,
-- the detail pane's lines, the edits from its boxes and buttons, and the
-- Events specs of one player or of every listed player. Everything is read
-- and changed through the core (PSS_PlayerQuery.lua, the player setters).
--   local v = M.PSS_PlayerListNew()       the list's state
--   v:Resort()                            n shown, every entry, count text, empty text
--   v:SortBy(key)                         a header click: that column, or flip it
--   M.PSS_PlayerTypeText(r), M.PSS_PlayerExpireText(r), M.PSS_PlayerTotal(p)
--   M.PSS_PlayerHeading(r), M.PSS_PlayerTypeLine(r), M.PSS_PlayerAddedLine(r)
--   M.PSS_PlayerExpireNote(r), M.PSS_PlayerGuildLine(p), M.PSS_PlayerInviteLine(p)
--   M.PSS_PlayerTip(r), M.PSS_PlayerRemoveText(entry)
--   M.PSS_PlayerAddFromText(text)         adds a typed name; its entry or nil
--   M.PSS_PlayerCommitExpiry(entry, text) / M.PSS_PlayerCommitNote(entry, text)
--   M.PSS_PlayerToggleAllowed(entry, field, allowed)
--   M.PSS_PlayerCycleOverride(p, key)
--   M.PSS_PlayerAddGuild(guild)           the player's guild onto the guild list
--   M.PSS_PlayerGuildState(p)             guild, listed (Add Guild button)
--   M.PSS_PlayerEventsSpec(entry), M.PSS_AllPlayersSpec()
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M
local L = addon.L

local type, tonumber, setmetatable = type, tonumber, setmetatable

------------------------------------------------------------------------
-- The list: sort, search and the order shown (positions in the list)
------------------------------------------------------------------------
local List = {}
List.__index = List

function M.PSS_PlayerListNew()
	return setmetatable({ key = "name", asc = true, find = "", index = {}, count = 0, dirty = true }, List)
end

-- n shown; every entry on the list; the count line; the text for no rows
function List:Resort()
	local _, n = M.PSS_SortPlayers(self.key, self.asc, self.find, self.index)
	self.count, self.dirty = n, false
	local all = M.PSS_PlayerCount()
	local countText = self.find ~= "" and ("%d of %d"):format(n, all) or ("%d on the list"):format(all)
	local empty = all == 0 and "The list is empty. Add a player above." or "Nothing matches the search."
	return n, all, countText, empty
end

function List:SortBy(key)
	if self.key == key then
		self.asc = not self.asc
	else
		self.key, self.asc = key, true
	end
end

-- the search text changed; true when the list must be sorted again
function List:SetFind(text)
	text = text or ""
	if text == self.find then return false end
	self.find = text
	return true
end

------------------------------------------------------------------------
-- Column and pane text (r: a row from M.PSS_PlayerRow; p: its record)
------------------------------------------------------------------------
function M.PSS_PlayerTypeText(r)
	if r.kind == "npc" then return "|cffffff99NPC|r" end
	if r.kind == "server" then return "|cffff66ccServer|r" end
	if r.faction == "Alliance" then return "|cff335effAlliance|r" end
	if r.faction == "Horde" then return "|cffe60000Horde|r" end
	return "Unknown"
end

function M.PSS_PlayerExpireText(r)
	if r.expire == 0 then return "|cff808080" .. L["EXP_NVR"] .. "|r" end
	if r.left <= 0 then return "|cffff6666" .. L["EXP_TDY"] .. "|r" end
	return r.left .. "d"
end

function M.PSS_PlayerTotal(p)
	return p and M.PSS_GetPlayerBlockCounts(p).total or 0
end

function M.PSS_PlayerTip(r)
	local text = r.entry
	if r.note and r.note ~= "" then text = text .. "\n\n" .. r.note end
	return text .. "\n\nClick for the details."
end

-- the pane's heading: the name in its class colour, NPC: / Server: first
function M.PSS_PlayerHeading(r)
	local p = r.record
	local cr, cg, cb = M.PSS_ClassColor(p and p.class)
	local title = (r.kind == "npc" and "NPC: ") or (r.kind == "server" and "Server: ") or ""
	local name = r.kind == "server" and r.server or r.name .. (r.server ~= "All" and ("-" .. r.server) or "")
	return title .. ("|cff%02x%02x%02x"):format(cr * 255, cg * 255, cb * 255) .. name .. "|r"
end

function M.PSS_PlayerTypeLine(r)
	local p = r.record
	local text = M.PSS_PlayerTypeText(r)
	if p and (p.className or p.class) then text = text .. "  " .. (p.className or p.class) end
	return text
end

function M.PSS_PlayerAddedLine(r)
	local ago = r.listed or 0
	if not r.added then return "Added |cff808080Unknown|r" end
	return ("Added %s  |cffaaaaaa(%d %s ago)|r"):format(r.added, ago, M.dayString(ago))
end

function M.PSS_PlayerExpireNote(r)
	if r.expire == 0 then return "days  |cff808080(never)|r" end
	if r.left <= 0 then return "days  |cffff6666(today)|r" end
	return ("days  |cffaaaaaa(%d left)|r"):format(r.left)
end

function M.PSS_PlayerGuildLine(p)
	local now, was = p.currentGuild or "", p.guildWhenBlocked or ""
	return "Guild " .. (now ~= "" and ("<" .. now .. ">") or "|cff808080none seen|r")
		.. ((was ~= "" and was ~= now) and ("  |cffaaaaaa(when added <" .. was .. ">)|r") or "")
end

function M.PSS_PlayerInviteLine(p)
	local last = p.lastBlockedInvite or ""
	return "Last blocked invite " .. (last ~= "" and last or "|cff808080never|r")
end

-- the player's current guild and whether the guild list has it (nil: none seen)
function M.PSS_PlayerGuildState(p)
	local now = p and p.currentGuild or ""
	if now == "" then return nil end
	return now, M.PSS_IsGuildListed(now)
end

function M.PSS_PlayerRemoveText(entry)
	local _, kind = M.PSS_PlayerEntry(M.PSS_PlayerPosition(entry))
	return ("Remove %s from the Player Ignore List?"):format(entry)
		.. (kind == "player" and "\n\nTheir note, settings and block history are deleted." or "")
end

------------------------------------------------------------------------
-- Edits (each through the core's setters; the core fires PLAYERS_CHANGED)
------------------------------------------------------------------------
-- A typed Name or Name-Realm: added; its entry as stored, or nil.
function M.PSS_PlayerAddFromText(text)
	text = M.trim(text or "") or ""
	if text == "" then return nil end
	M.PSS_AddPlayer(text)
	local pos = M.PSS_PlayerPosition(M.Proper(M.addServer(text)))
	if pos > 0 then return (M.PSS_PlayerEntry(pos)) end
end

-- the expiry box of entry (days, 0 = never); true if it changed
function M.PSS_PlayerCommitExpiry(entry, text)
	local pos, days = M.PSS_PlayerPosition(entry), tonumber(text)
	if pos <= 0 or not days then return false end
	local r = M.PSS_PlayerRow(pos, {})
	if r and days == r.expire then return false end
	M.PSS_SetExpiry(pos, days)
	M.PSS_PlayersChanged()
	return true
end

function M.PSS_PlayerCommitNote(entry, text)
	local pos = M.PSS_PlayerPosition(entry)
	text = M.trim(text or "") or ""
	if pos <= 0 then return false end
	local r = M.PSS_PlayerRow(pos, {})
	if r and text == (r.note or "") then return false end
	M.PSS_SetNote(pos, text)
	M.PSS_PlayersChanged()
	return true
end

-- W I G P C: ticked = allowed; the record stores "blocked"
function M.PSS_PlayerToggleAllowed(entry, field, allowed)
	if not entry then return end
	M.PSS_SetPlayerSetting(entry, field, not allowed)
	M.PSS_PlayersChanged()
end

-- an Options override for this player: Default > On > Off
function M.PSS_PlayerCycleOverride(p, key)
	if type(p) ~= "table" then return end
	M.PSS_SetOpt(key, "person", M.PSS_NextOverride(p.opts and p.opts[key]), p)
end

function M.PSS_PlayerAddGuild(guild)
	if type(guild) ~= "string" or guild == "" then return end
	M.PSS_AddGuild(guild)
	M.ShowMsg(("Added <%s> to the Guild Ignore List."):format(guild))
end

------------------------------------------------------------------------
-- Events specs: one player, or every listed player (the Events tab reads
-- them; nothing here loads PourSocialScore_Logging)
------------------------------------------------------------------------
local allPlayers

function M.PSS_AllPlayersSpec()
	if allPlayers then return allPlayers end
	allPlayers = {
		kind = "player", id = false, allText = "All Players", source = "players",
		label = function() return "All Players" end,
		read = M.PSS_ListedPlayerEvents,
		reset = M.PSS_ResetListedPlayerEvents,
	}
	return allPlayers
end

function M.PSS_PlayerEventsSpec(entry)
	return {
		kind = "player", id = entry, allText = "All Players", all = M.PSS_AllPlayersSpec,
		label = function(e) return M.PSS_PlayerPosition(e) > 0 and e or nil end,
		read = M.PSS_GetPlayerBlockHistory,
		reset = M.PSS_ResetPlayerBlockHistory,
		owner = M.PSS_PlayerHistoryKey, counts = M.PSS_GetPlayerBlockCounts,
	}
end
