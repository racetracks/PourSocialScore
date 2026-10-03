------------------------------------------------------------------------
-- POUR SOCIAL SCORE - BLOCK HISTORY (one module for every list)
--
-- The Player Ignore List, the Guild Ignore List (per member) and the Chat
-- Filters (per filter) all keep their block history the same way:
--
--   history = { entry, entry, ... }        newest first, capped
--   counts  = { whisper=, partyInvite=, guildInvite=, partyRaid=, world=,
--               guildChat=, unknown=, total= }
--   entry   = { ts      = server time (number, 0 = unknown),
--               time    = "02 Oct 2026 14:31:05" or "Unknown",
--               cat     = whisper | partyInvite | guildInvite | partyRaid |
--                         world | guildChat | unknown,
--               kind    = label of cat ("Whisper", "World Chat", ...),
--               member  = sender ("Name-Realm") or "Unknown",
--               event   = CHAT_MSG_* / PARTY_INVITE / GUILD_INVITE or nil,
--               channel = "2. Trade - City", "Whisper", ... or "Unknown",
--               message = text ("" for invites) }
--
-- and show it the same way: the block history table (sortable Who-style
-- columns, right-click a line for options), the in-place Block History
-- panel used by each tab (All / Reset / Close on the bar) and the Block
-- History popup window.
--
-- Older data is migrated when it is read: entries from earlier builds get
-- their category, timestamp and channel filled in, and anything that was
-- never recorded is set to "Unknown". The chat filters' old 50-slot ring
-- buffer ({ m, s, t, c, n }) is converted to the list above once.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M
local V = addon.V
local L = addon.L

local History = {}
M.PSS_History = History

local UNKNOWN = "Unknown"
History.UNKNOWN = UNKNOWN
-- Categories shown in counts (in this order) and their labels/colours.
History.CAT_ORDER = { "whisper", "partyInvite", "partyRaid", "world", "guildInvite" }
History.CAT_LABEL = {
	whisper = "Whisper", partyInvite = "Party Invite", partyRaid = "Party/Raid",
	world = "World Chat", guildInvite = "Guild Invite", guildChat = "Guild Chat", unknown = UNKNOWN,
}
History.CAT_COLOR = {
	whisper = "ffffff00", partyInvite = "ffff9933", partyRaid = "ff66ccff",
	world = "ff99ff99", guildInvite = "ffcc99ff", guildChat = "ff40ff40", unknown = "ff9d9d9d",
}
local CAT_LABEL, CAT_COLOR, CAT_ORDER = History.CAT_LABEL, History.CAT_COLOR, History.CAT_ORDER
local ALL_CATS = { "whisper", "partyInvite", "guildInvite", "partyRaid", "world", "guildChat", "unknown" }
History.ALL_CATS = ALL_CATS

-- entry -> where it came from ("Guild rule: X", "Filter: Y"); tooltips only,
-- weak keys, never saved
History.sourceLabel = setmetatable({}, { __mode = "k" })
function History.SetSource(h, label) if type(h) == "table" then History.sourceLabel[h] = label end end

------------------------------------------------------------------------
-- Time
------------------------------------------------------------------------
local TIME_FMT = "%d %b %Y %H:%M:%S"
local MONTHS = { Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12 }

function History.Now() return GetServerTime and GetServerTime() or time() end
function History.FormatTime(ts)
	ts = tonumber(ts)
	if not ts or ts <= 0 then return UNKNOWN end
	return date(TIME_FMT, ts)
end

-- "02 Oct 2026 14:31:05" (current) or "2026.10.02 14:31:05" (old chat
-- filter history) -> server time, or nil.
function History.ParseTime(s)
	if type(s) ~= "string" or not time then return nil end
	local d, mon, y, hh, mm, ss = s:match("^(%d+) (%a+) (%d+) (%d+):(%d+):(%d+)")
	if d and MONTHS[mon] then
		return time({ year = tonumber(y), month = MONTHS[mon], day = tonumber(d), hour = tonumber(hh), min = tonumber(mm), sec = tonumber(ss) })
	end
	local Y, Mo, D, H, Mi, S = s:match("^(%d+)%.(%d+)%.(%d+) (%d+):(%d+):(%d+)")
	if Y then
		return time({ year = tonumber(Y), month = tonumber(Mo), day = tonumber(D), hour = tonumber(H), min = tonumber(Mi), sec = tonumber(S) })
	end
	return nil
end
M.PSS_ParseTimeString = History.ParseTime

------------------------------------------------------------------------
-- Entries
------------------------------------------------------------------------
local KIND_TO_CAT = {
	["Whisper"] = "whisper", ["Private Message"] = "whisper",
	["Group Invite"] = "partyInvite", ["Party Invite"] = "partyInvite",
	["Guild Invite"] = "guildInvite",
	["Party/Raid"] = "partyRaid",
	["World Chat"] = "world", ["Other"] = "world",
	["Guild Chat"] = "guildChat",
	[UNKNOWN] = "unknown",
}

-- Counting bucket for a core category (achievements, notices... count as
-- world chat, as before).
function History.Bucket(cat)
	if cat == "other" then return "world" end
	if CAT_LABEL[cat] then return cat end
	return "unknown"
end

-- Fill in everything a history line needs. Idempotent; used to migrate
-- entries written by older builds (which only had kind/event/time).
function History.Normalize(h)
	if type(h) ~= "table" then return nil end
	if not h.cat or not CAT_LABEL[h.cat] then
		local cat = KIND_TO_CAT[h.kind]
		if not cat and h.event and M.PSS_EventCategory then cat = M.PSS_EventCategory(h.event) end
		h.cat = History.Bucket(cat)
	end
	h.ts = tonumber(h.ts) or History.ParseTime(rawget(h, "time")) or 0
	-- "time" and "kind" are worked out from ts / cat when shown (see EntryMT);
	-- not stored, which saves two strings per line
	h.time, h.kind = nil, nil
	setmetatable(h, History.EntryMT)
	if type(h.channel) ~= "string" or h.channel == "" then
		if h.cat == "partyInvite" then h.channel = "Party Invite"
		elseif h.cat == "guildInvite" then h.channel = "Guild Invite"
		elseif type(h.event) == "string" and h.event ~= "" and M.PSS_ChannelLabel then h.channel = M.PSS_ChannelLabel(h.event)
		else h.channel = UNKNOWN end
	end
	if type(h.member) ~= "string" or h.member == "" then h.member = nil end   -- caller may know the owner
	h.message = tostring(h.message or "")
	return h
end
M.PSS_NormalizeBlockEntry = History.Normalize

-- A new line. cat: core category; channel: label (built from the event when nil).
function History.NewEntry(cat, event, message, channel, member)
	if M.PSS_IsSecret and M.PSS_IsSecret(message) then message = "(message hidden by the client)" end
	local ts = History.Now()
	local h = {
		ts = ts,
		cat = History.Bucket(cat), event = event,
		channel = channel, member = member,
		message = tostring(message or ""),
	}
	return History.Normalize(h)
end

function History.EmptyCounts()
	local c = { total = 0 }
	for _, k in ipairs(ALL_CATS) do c[k] = 0 end
	return c
end

function History.EnsureCounts(c)
	if type(c) ~= "table" then c = {} end
	for _, k in ipairs(ALL_CATS) do c[k] = tonumber(c[k]) or 0 end
	-- total is never less than the categories added up (older member
	-- counters were saved with total = 0)
	local sum = 0
	for _, k in ipairs(ALL_CATS) do sum = sum + c[k] end
	c.total = math.max(tonumber(c.total) or 0, sum)
	return c
end

------------------------------------------------------------------------
-- THE SHARED BLOCK LOG
--
-- Every blocked line is ONE entry in one list, PourSocialScoreDB.blockLog
-- (oldest first), capped at the Options setting "Block history lines kept
-- in total" (default 2,000). However many people get blocked, the history
-- never grows past that. Each entry names its owner:
--   o = "p:<key>"   Player Ignore List entry
--   o = "g:<key>"   guild member (by character, so it follows them when they
--                   are moved to another guild rule)
--   o = "f:<id>"    chat filter (built-in id, or "f:t:<filter text>")
--   r = "<id>"      also counted on this guild rule (managed guild groups)
-- Views (a player, a guild, a member, a filter, "all ...") are filtered
-- from the log. The per-type blocked COUNTS stay on each owner and are
-- totals: they are never cut.
------------------------------------------------------------------------
History.DEFAULT_TOTAL, History.MIN_TOTAL, History.MAX_TOTAL = 2000, 100, 20000

function History.Cap()
	local v = tonumber(M.PSS_Opt and M.PSS_Opt("historyTotal"))
	if not v then return History.DEFAULT_TOTAL end
	v = math.floor(v)
	if v < History.MIN_TOTAL then return History.MIN_TOTAL end
	if v > History.MAX_TOTAL then return History.MAX_TOTAL end
	return v
end
History.Max = History.Cap      -- (older name)

-- time / kind are worked out when read
History.EntryMT = { __index = function(h, k)
	if k == "time" then return History.FormatTime(rawget(h, "ts"))
	elseif k == "kind" then return CAT_LABEL[rawget(h, "cat") or "unknown"] or UNKNOWN end
end }

local attached = setmetatable({}, { __mode = "k" })
function History.Log()
	local db = PourSocialScoreDB
	if type(db) ~= "table" then return {} end
	local log = db.blockLog
	if type(log) ~= "table" then log = {}; db.blockLog = log end
	if not attached[log] then
		-- saved entries come back without their metatable
		for i = 1, #log do if type(log[i]) == "table" then setmetatable(log[i], History.EntryMT) end end
		attached[log] = true
	end
	return log
end

-- Keep the newest `cap` lines. Done in batches (when the log is 5 % over)
-- so adding a line never shifts the whole list.
function History.Trim(force)
	local log = History.Log()
	local cap = History.Cap()
	local n = #log
	if n <= cap or (not force and n <= cap + math.max(20, math.floor(cap / 20))) then return 0 end
	local drop = n - cap
	for i = 1, cap do log[i] = log[i + drop] end
	for i = cap + 1, n do log[i] = nil end
	if M.PSS_RequestGC then M.PSS_RequestGC("history trimmed") end
	return drop
end
History.TrimAll = function() return History.Trim(true) end
M.PSS_TrimAllHistory = History.TrimAll

-- Add a line for an owner, count it on `counts`. Returns the entry.
function History.Add(owner, counts, entry, ruleTag)
	entry.o = owner
	if ruleTag then entry.r = ruleTag end
	local log = History.Log()
	log[#log + 1] = entry
	if counts then
		counts[entry.cat] = (tonumber(counts[entry.cat]) or 0) + 1
		counts.total = (tonumber(counts.total) or 0) + 1
	end
	History.Trim(false)
	return entry
end

-- Newest-first list of the lines where pred(entry) is true (a new array:
-- for showing, not for keeping).
function History.Collect(pred)
	local log, out = History.Log(), {}
	for i = #log, 1, -1 do
		local h = log[i]
		if h and pred(h) then out[#out + 1] = h end
	end
	return out
end
function History.For(owner) return History.Collect(function(h) return h.o == owner end) end
function History.CountFor(owner)
	local log, n = History.Log(), 0
	for i = 1, #log do if log[i].o == owner then n = n + 1 end end
	return n
end

-- Remove the lines where pred(entry) is true.
function History.Clear(pred)
	local log = History.Log()
	local j, n = 0, #log
	for i = 1, n do
		local h = log[i]
		if not pred(h) then j = j + 1; log[j] = h end
	end
	for i = j + 1, n do log[i] = nil end
	if n - j > 0 and M.PSS_RequestGC then M.PSS_RequestGC("history cleared") end
	return n - j
end

-- owner keys
function History.PlayerKey(name)
	local c = M.PSS_CanonPlayer and M.PSS_CanonPlayer(name)
	return c and ("p:" .. c) or nil
end
function History.MemberKey(m)
	if type(m) ~= "table" then return nil end
	local c = M.PSS_CanonPlayer and (M.PSS_CanonPlayer(m._playerKey) or M.PSS_CanonPlayer(m.name))
	return c and ("g:" .. c) or nil
end
function History.FilterKey(id, text)
	if type(id) == "string" and id ~= "" then return "f:" .. id end
	return "f:t:" .. tostring(text or "")
end

-- Approximate memory of the log (for /pss mem): bytes.
local EST_KEYS = { "message", "channel", "member", "event", "o", "r" }
function History.EstimateBytes()
	local log, bytes = History.Log(), 0
	for i = 1, #log do
		local h = log[i]
		bytes = bytes + 120   -- table + 6-8 fields
		for j = 1, #EST_KEYS do
			local v = rawget(h, EST_KEYS[j])
			if type(v) == "string" then bytes = bytes + 24 + #v end
		end
	end
	return bytes, #log
end

------------------------------------------------------------------------
-- One-time move of the old per-person / per-filter lists into the log.
-- sources = { { list = {...}, owner = "p:..." , member = name }, ... }
------------------------------------------------------------------------
function History.Absorb(sources)
	local log = History.Log()
	local all = {}
	for i = 1, #log do all[#all + 1] = log[i] end
	for _, src in ipairs(sources) do
		for _, h in ipairs(src.list or {}) do
			if type(h) == "table" and History.Normalize(h) then
				h.o = h.o or src.owner
				h.member = h.member or src.member
				all[#all + 1] = h
			end
		end
	end
	-- oldest first; stable for equal times
	local pos = {}
	for i, h in ipairs(all) do pos[h] = i end
	table.sort(all, function(a, b)
		if (a.ts or 0) ~= (b.ts or 0) then return (a.ts or 0) < (b.ts or 0) end
		return pos[a] < pos[b]
	end)
	PourSocialScoreDB.blockLog = all
	attached[all] = true
	History.Trim(true)
	return #PourSocialScoreDB.blockLog
end

-- Counts rebuilt from a list (migration).
function History.CountList(list)
	local c = History.EmptyCounts()
	for _, h in ipairs(list or {}) do
		if History.Normalize(h) then c[h.cat] = c[h.cat] + 1; c.total = c.total + 1 end
	end
	return c
end

function History.Sig(h)
	return tostring(h.ts or 0) .. "\1" .. tostring(h.time or "") .. "\1" .. tostring(h.event or "") ..
			"\1" .. tostring(h.message or "") .. "\1" .. tostring(h.cat or "")
end

-- Union of two lists, de-duplicated (copies), newest first, capped.
function History.MergeLists(a, b)
	local max = History.Max()
	local seen, merged = {}, {}
	for _, list in ipairs({ a or {}, b or {} }) do
		for _, h in ipairs(list) do
			local sig = History.Sig(h)
			if not seen[sig] then
				seen[sig] = true
				local copy = {}
				for k, v in pairs(h) do copy[k] = v end
				merged[#merged + 1] = copy
			end
		end
	end
	table.sort(merged, function(x, y) return (x.ts or 0) > (y.ts or 0) end)
	while #merged > max do table.remove(merged) end
	return merged
end

-- Several lists -> one newest-first list (for "all players / guilds /
-- filters" views). sourceFn(list) gives the tooltip label, ownerName the
-- sender when a line does not name one.
function History.Combine(parts)
	local out = {}
	for _, p in ipairs(parts) do
		for _, h in ipairs(p.list or {}) do
			if History.Normalize(h) then
				h.member = h.member or p.owner or UNKNOWN
				if p.source then History.SetSource(h, p.source) end
				out[#out + 1] = h
			end
		end
	end
	table.sort(out, function(a, b)
		if (a.ts or 0) ~= (b.ts or 0) then return (a.ts or 0) > (b.ts or 0) end
		return tostring(a.member or "") < tostring(b.member or "")
	end)
	return out
end

-- "Whispers: 3  Party Invites: 0 ..." summary line.
function History.FormatCounts(c)
	c = c or {}
	local function part(cat, label)
		return "|cffaaaaaa" .. label .. ":|r |c" .. CAT_COLOR[cat] .. (c[cat] or 0) .. "|r"
	end
	local s = part("whisper", "Whispers") .. "    " .. part("partyInvite", "Party Invites") .. "    " ..
				part("partyRaid", "Party/Raid") .. "    " .. part("world", "World Chat")
	if (c.guildInvite or 0) > 0 then s = s .. "    " .. part("guildInvite", "Guild Invites") end
	if (c.guildChat or 0) > 0 then s = s .. "    " .. part("guildChat", "Guild Chat") end
	if (c.unknown or 0) > 0 then s = s .. "    " .. part("unknown", UNKNOWN) end
	return s
end
M.PSS_FormatGuildCounts = History.FormatCounts
M.PSS_FormatBlockCounts = History.FormatCounts

------------------------------------------------------------------------
-- Chat filter history migration
------------------------------------------------------------------------
-- old: ring buffer of { m = message, s = sender, t = "YYYY.MM.DD HH:MM:SS",
--                       c = channel number, n = channel/event name }
-- with filterBlockedLast = index of the newest slot.
local OLD_CHANNEL_CAT = {
	WHISPER = "whisper", BN_WHISPER = "whisper",
	PARTY = "partyRaid", PARTY_LEADER = "partyRaid", RAID = "partyRaid", RAID_LEADER = "partyRaid",
	RAID_WARNING = "partyRaid", INSTANCE_CHAT = "partyRaid", INSTANCE_CHAT_LEADER = "partyRaid",
	BATTLEGROUND = "partyRaid", BATTLEGROUND_LEADER = "partyRaid",
	SAY = "world", YELL = "world", EMOTE = "world", TEXT_EMOTE = "world", CHANNEL = "world",
	COMMUNITIES_CHANNEL = "world", AFK = "world", DND = "world",
	GUILD = "guildChat", OFFICER = "guildChat",
}

local function isOldFilterEntry(e)
	return type(e) == "table" and e.cat == nil and (e.m ~= nil or e.s ~= nil or e.t ~= nil)
end

function History.MigrateOldFilterEntry(e)
	local chNum = tonumber(e.c) or 0
	local name = type(e.n) == "string" and e.n ~= "" and e.n or nil
	local cat, channel, event
	if chNum > 0 then
		cat = "world"
		channel = name and (chNum .. ". " .. name) or (chNum .. ". " .. UNKNOWN)
		event = "CHAT_MSG_CHANNEL"
	elseif name then
		local key = name:upper()
		cat = OLD_CHANNEL_CAT[key] or "unknown"
		event = OLD_CHANNEL_CAT[key] and ("CHAT_MSG_" .. key) or nil
		channel = (event and M.PSS_ChannelLabel and M.PSS_ChannelLabel(event)) or name
	else
		cat, channel = "unknown", UNKNOWN
	end
	local ts = History.ParseTime(e.t) or 0
	return History.Normalize({
		ts = ts, time = ts > 0 and History.FormatTime(ts) or UNKNOWN,
		cat = cat, event = event, channel = channel,
		member = (type(e.s) == "string" and e.s ~= "") and e.s or UNKNOWN,
		message = tostring(e.m or ""),
	})
end

-- Returns the filter's history in the current format (a list with a
-- .counts table), converting the old ring buffer when needed.
-- lists already in the current format this session (weak: no leak)
local migratedLists = setmetatable({}, { __mode = "k" })

function History.MigrateFilterList(list, last)
	if type(list) ~= "table" then list = {} end
	-- checked once per session, not on every blocked line
	if migratedLists[list] and type(list.counts) == "table" then return list end
	local old = false
	for _, e in ipairs(list) do if isOldFilterEntry(e) then old = true break end end
	if not old then
		list.counts = History.EnsureCounts(list.counts)
		if list.counts.total == 0 and #list > 0 then list.counts = History.CountList(list) end
		migratedLists[list] = true
		return list
	end
	-- ring order: newest at `last`, going backwards, then wrapping
	local total = #list
	last = tonumber(last) or total
	if last < 1 or last > total then last = total end
	local order = {}
	for i = last, 1, -1 do order[#order + 1] = i end
	for i = total, last + 1, -1 do order[#order + 1] = i end
	local out = {}
	for _, i in ipairs(order) do
		local e = list[i]
		if isOldFilterEntry(e) then out[#out + 1] = History.MigrateOldFilterEntry(e)
		elseif type(e) == "table" and History.Normalize(e) then out[#out + 1] = e end
	end
	-- keep newest first even where old timestamps were readable
	local pos = {}
	for i, h in ipairs(out) do pos[h] = i end
	table.sort(out, function(a, b)
		if a.ts > 0 and b.ts > 0 and a.ts ~= b.ts then return a.ts > b.ts end
		return pos[a] < pos[b]
	end)
	out.counts = History.CountList(out)
	migratedLists[out] = true
	return out
end

------------------------------------------------------------------------
-- Right-click a history line
------------------------------------------------------------------------
-- Default options for the sender: add to / remove from the Player Ignore
-- List. extra(root, entry) can add more (e.g. Edit Filter).
function History.RowMenu(entry, extra)
	if not entry or not MenuUtil then return end
	local name = entry.member
	local valid = type(name) == "string" and name ~= "" and name ~= UNKNOWN
	local full = valid and M.Proper and M.Proper(M.addServer(name)) or name
	MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, root)
		root:CreateTitle(valid and full or "Blocked line")
		if valid then
			root:CreateDivider()
			if M.hasGlobalIgnored and M.hasGlobalIgnored(full) > 0 then
				root:CreateButton(L["RCM_4"] or "Remove from ignore", function() M.PSS_DelIgnore(full) end)
			else
				root:CreateButton(L["RCM_6"] or "Add to ignore", function() M.PSS_AddOrDelIgnore(full) end)
			end
		end
		if extra then extra(root, entry) end
		root:CreateDivider()
		root:CreateButton(L["RCM_5"] or "Cancel", function() end)
	end)
end

------------------------------------------------------------------------
-- History table (the widget every Block History view uses)
-- Columns: Time | Player | Type | Channel | Message (tooltip: full text).
-- opts.onRowClick(entry, mouseButton) replaces the default right-click menu;
-- opts.rowMenu(root, entry) adds items to the default menu.
------------------------------------------------------------------------
local listCount = 0
local SORT = {
	time    = function(h) return tonumber(h.ts) or 0 end,
	member  = function(h) return string.lower(h.member or "") end,
	kind    = function(h) return string.lower(h.kind or "") end,
	channel = function(h) return string.lower(h.channel or "") end,
	message = function(h) return string.lower(h.message or "") end,
}

function History.CreateList(parent, numRows, rowH, width, opts)
	opts = opts or {}
	local UI = M.UI
	listCount = listCount + 1
	rowH = UI.ROW_H
	numRows = numRows or 10
	-- visible: our own on/off flag. Never use scroll:IsShown() for this -
	-- FauxScrollFrame_Update hides the scroll frame whenever every entry
	-- fits on screen, which used to hide all rows of a short history.
	local HL = { entries = {}, source = {}, numRows = numRows, rowH = rowH, rows = {}, sortKey = "time", sortAsc = false, visible = true }
	local cols = { time = 132, member = 150, kind = 100, channel = 140 }
	cols.message = math.max(80, (width or 860) - 26 - cols.time - cols.member - cols.kind - cols.channel)

	local update
	local function applySort()
		local key, asc = HL.sortKey, HL.sortAsc
		local fn = SORT[key] or SORT.time
		local list, vals, order = {}, {}, {}
		for i, h in ipairs(HL.source) do list[i] = h; vals[h] = fn(h); order[h] = i end
		table.sort(list, function(a, b)
			local A, B = vals[a], vals[b]
			if A ~= B then if asc then return A < B else return A > B end end
			return order[a] < order[b]
		end)
		HL.entries = list
		if HL.header then HL.header:SetSort(key, asc) end
	end
	local function onSort(key)
		if HL.sortKey == key then HL.sortAsc = not HL.sortAsc
		else HL.sortKey, HL.sortAsc = key, (key ~= "time") end   -- time starts newest first
		applySort()
		update()
	end

	HL.header = UI.CreateHeaderRow(parent, {
		{ key = "time",    text = "Time",    width = cols.time },
		{ key = "member",  text = "Player",  width = cols.member },
		{ key = "kind",    text = "Type",    width = cols.kind },
		{ key = "channel", text = "Channel", width = cols.channel },
		{ key = "message", text = "Message", width = cols.message, fill = true, minWidth = 80 },
	}, 0, 0, onSort, { id = "history" })
	-- the widths in use (the header row owns them; kept for older callers)
	HL.cols = HL.header.w

	HL.empty = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	HL.empty:SetPoint("TOP", parent, "TOP", 0, -UI.HEADER_H - 30)
	HL.empty:SetText("No blocked messages or invites recorded.")

	local scroll = CreateFrame("ScrollFrame", "PSSHistoryList" .. listCount .. "Scroll", parent, "FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -UI.HEADER_H)
	scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 0)
	HL.scroll = scroll

	update = function()
		local n = #HL.entries
		local rowsShown = HL.numRows
		FauxScrollFrame_Update(scroll, n, rowsShown, rowH)
		local offset = FauxScrollFrame_GetOffset(scroll) or 0
		HL.empty:SetShown(n == 0 and HL.visible)
		for i = rowsShown + 1, #HL.rows do HL.rows[i].entry = nil; HL.rows[i]:Hide() end
		for i = 1, rowsShown do
			local row = HL.rows[i]
			local h = HL.entries[i + offset]
			if h and HL.visible then
				local cat = h.cat or "unknown"
				row.time:SetText(h.time or UNKNOWN)
				row.member:SetText(h.member or UNKNOWN)
				row.kind:SetText("|c" .. (CAT_COLOR[cat] or "ffffffff") .. (h.kind or CAT_LABEL[cat] or UNKNOWN) .. "|r")
				row.channel:SetText(h.channel or UNKNOWN)
				local msg = h.message or ""
				row.msg:SetText(msg ~= "" and msg or "|cff888888(no message text)|r")
				row.entry = h
				row:Show()
			else
				row.entry = nil
				row:Hide()
			end
		end
	end
	HL.update = update
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, rowH, update)
	end)

	local function makeRow(i)
		local row = UI.CreateRow(parent)
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -UI.HEADER_H - (i - 1) * rowH)
		row:SetPoint("RIGHT", parent, "RIGHT", -26, 0)
		local hr = HL.header
		row.time = UI.TCell(row, hr, "time")
		row.member = UI.TCell(row, hr, "member")
		row.kind = UI.TCell(row, hr, "kind")
		row.channel = UI.TCell(row, hr, "channel")
		row.msg = UI.TCell(row, hr, "message")

		-- Links in the message (items, recipes, professions, spells,
		-- achievements...) work like in chat: hover for the tooltip, click
		-- to open it, shift-click to paste it into chat.
		if row.SetHyperlinksEnabled then
			row:SetHyperlinksEnabled(true)
			row:SetScript("OnHyperlinkClick", function(self, link, text, button)
				self.linkClickAt = GetTime()
				if SetItemRef then pcall(SetItemRef, link, text, button, DEFAULT_CHAT_FRAME) end
			end)
			row:SetScript("OnHyperlinkEnter", function(self, link)
				GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
				local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
				if ok and GameTooltip:NumLines() > 0 then
					GameTooltip:Show()
				else
					GameTooltip:Hide()
					local onEnter = self:GetScript("OnEnter")
					if onEnter then onEnter(self) end
				end
			end)
			row:SetScript("OnHyperlinkLeave", function(self)
				GameTooltip:Hide()
				if self:IsMouseOver() then
					local onEnter = self:GetScript("OnEnter")
					if onEnter then onEnter(self) end
				end
			end)
		end

		row:SetScript("OnEnter", function(self)
			local h = self.entry
			if not h then return end
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:AddDoubleLine(h.member or UNKNOWN, h.time or UNKNOWN, 1, 1, 1, 0.85, 0.85, 0.85)
			GameTooltip:AddDoubleLine(h.kind or UNKNOWN, h.channel or UNKNOWN, 1, 0.82, 0, 0.6, 0.6, 0.4)
			local src = History.sourceLabel[h]
			if src then GameTooltip:AddLine(src, 0.7, 0.7, 0.7) end
			if (h.message or "") ~= "" then GameTooltip:AddLine(h.message, 1, 0.75, 0.75, true) end
			GameTooltip:AddLine("Right-click for options. Click a link in the message to open it.", 0.6, 0.6, 0.6, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row:SetScript("OnClick", function(self, button)
			if not self.entry then return end
			-- the click was on a link in the message: that is handled above
			if self.linkClickAt and GetTime() - self.linkClickAt < 0.05 then return end
			if opts.onRowClick then opts.onRowClick(self.entry, button)
			elseif button == "RightButton" then History.RowMenu(self.entry, opts.rowMenu) end
		end)
		row:Hide()
		HL.rows[i] = row
	end
	for i = 1, numRows do makeRow(i) end

	-- Fit the row count and Message column to the parent's size (the windows
	-- holding this list can be resized).
	local function relayout()
		local pw, ph = parent:GetWidth() or 0, parent:GetHeight() or 0
		if pw <= 0 or ph <= 0 then return end
		HL.numRows = math.max(1, math.floor((ph - UI.HEADER_H) / rowH))
		for i = #HL.rows + 1, HL.numRows do makeRow(i) end
		-- the Message column takes the width the other columns leave
		HL.header:SetAvailableWidth(pw - 26)
		update()
	end
	HL.relayout = relayout
	parent:HookScript("OnSizeChanged", relayout)

	function HL:SetEntries(entries, resetScroll)
		self.source = entries or {}
		if resetScroll then
			self.sortKey, self.sortAsc = "time", false
			FauxScrollFrame_SetOffset(scroll, 0)
			local bar = scroll.ScrollBar or _G[scroll:GetName() .. "ScrollBar"]
			if bar and bar.SetValue then bar:SetValue(0) end
		end
		applySort()
		update()
	end
	function HL:SetShown(on)
		self.visible = on and true or false
		self.header:SetShown(on)
		scroll:SetShown(on)
		if not on then for _, r in ipairs(self.rows) do r:Hide() end; self.empty:Hide() else update() end
	end
	applySort()
	return HL
end
M.PSS_CreateHistoryList = History.CreateList

------------------------------------------------------------------------
-- In-place Block History panel for a tab (the Guild Ignore List design)
--
-- Shown instead of the tab's list; its header row sits where the list
-- header was, the tab title shows what is listed, and the bar holds
-- Close (right) / Reset Block History / All <things> [/ extra button].
--
-- opts = {
--   baseTitle  = "Guild Ignore List",       title to restore on Close
--   allText    = "all guilds",              title text for the "all" view
--   allButton  = "All Guilds",              bar button
--   setListShown(on)                         hide/show the tab's own list
--   entries(key)  -> list                    key nil = everything
--   label(key)    -> name or nil             nil = gone (falls back to all)
--   reset(key)                               key nil = everything (asks first)
--   extra = { text=, onClick(key), shown(key) }   optional bar button
--   rowMenu(root, entry)                     optional right-click items
-- }
------------------------------------------------------------------------
StaticPopupDialogs["PSS_HISTORY_RESET_ALL"] = {
	preferredIndex = STATICPOPUPS_NUMDIALOGS or 3,
	text = "%s",
	whileDead = 1,
	hideOnEscape = 1,
	button1 = (L and L["BOX_4"]) or "Reset",
	button2 = (L and L["BOX_5"]) or CANCEL,
	OnAccept = function(self, data) if data and data.run then data.run() end end,
}

function History.CreatePanel(tab, opts)
	local UI = M.UI
	local P = CreateFrame("Frame", nil, tab)
	P:SetPoint("TOPLEFT", 1, opts.headerY or UI.HEADER_Y)
	P:SetPoint("BOTTOMRIGHT", -1, 4)
	P:Hide()
	P.opts = opts

	P.close = UI.BarButton(tab, L["BUT_10"] or "Close"); P.close:SetParent(P)
	P.reset = UI.BarButton(tab, L["HISTORY_RESET"] or "Reset Block History", P.close, 140); P.reset:SetParent(P)
	P.all = UI.BarButton(tab, opts.allButton or "All", P.reset); P.all:SetParent(P)
	if opts.extra then
		P.extra = UI.BarButton(tab, opts.extra.text, P.all); P.extra:SetParent(P)
		P.extra:SetScript("OnClick", function() opts.extra.onClick(P.key) end)
	end
	P.list = History.CreateList(P, 11, UI.ROW_H, 860, { rowMenu = opts.rowMenu })

	function P:Refresh(resetScroll)
		if not self:IsShown() then return end
		local key = self.key
		local name = key ~= nil and opts.label(key) or nil
		if key ~= nil and not name then key = nil; self.key = nil end   -- removed meanwhile
		local entries = opts.entries(key)
		if tab.title then
			tab.title:SetText("Block History: |cffffff00" .. (name or opts.allText or "all") .. "|r (" .. #entries .. ")")
		end
		self.all:SetShown(key ~= nil)
		if self.extra then self.extra:SetShown(not opts.extra.shown or opts.extra.shown(key)) end
		self.list:SetEntries(entries, resetScroll)
	end
	function P:Open(key)
		self.key = key
		opts.setListShown(false)
		self:Show()
		self:Refresh(true)
	end
	function P:Close()
		if not self:IsShown() then return end
		self:Hide()
		if tab.title and opts.baseTitle then tab.title:SetText(opts.baseTitle) end
		opts.setListShown(true)
	end

	P.close:SetScript("OnClick", function() P:Close() end)
	P.all:SetScript("OnClick", function() P.key = nil; P:Refresh(true) end)
	P.reset:SetScript("OnClick", function()
		if P.key ~= nil then
			opts.reset(P.key)
			P:Refresh(true)
		else
			StaticPopup_Show("PSS_HISTORY_RESET_ALL",
				"|cffffff00Reset Block History|cffffffff\n\nClear the block history and counts of " .. (opts.allText or "everything") .. "?",
				nil, { run = function() opts.reset(nil); P:Refresh(true) end })
		end
	end)
	P.reset:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine(L["HISTORY_RESET"] or "Reset Block History", 1, 1, 1)
		GameTooltip:AddLine(P.key ~= nil and "Clears this history and its counts." or "Clears the history and counts of everything listed (asks first).", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	P.reset:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return P
end

------------------------------------------------------------------------
-- Block History popup window (member / player / guild history opened
-- from other windows)
------------------------------------------------------------------------
local popup

local function getPopup()
	if popup then return popup end
	local UI = M.UI
	local f = UI.CreateWindow("PSSRuleBlockHistory", "Block History", 860, 500,
		{ strata = "FULLSCREEN_DIALOG", minW = 640, minH = 300, saveKey = "ruleHistory" })
	popup = f
	local inset = f.inset
	f.heading, f.info = UI.CreateSummary(inset, "", 500)
	-- block metrics of the player / guild shown (same table everywhere)
	f.metrics = UI.CreateMetricsTable(inset)
	f.metrics:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -6)
	f.reset = UI.BarButton(inset, L["HISTORY_RESET"] or "Reset Block History", nil, 140)
	local body = CreateFrame("Frame", nil, inset)
	body:SetPoint("TOPLEFT", 1, UI.HEADER_Y)
	body:SetPoint("BOTTOMRIGHT", -1, 4)
	f.list = History.CreateList(body, 11, UI.ROW_H, 830)
	return f
end

-- source: function returning (title, entries, counts|nil); onReset optional.
function History.ShowPopup(source, onReset)
	local f = getPopup()
	f.source = source
	f.onReset = onReset
	f.reset:SetShown(onReset ~= nil)
	f.reset:SetScript("OnClick", function()
		if f.onReset then f.onReset() end
		History.RefreshPopup(true)
	end)
	f:Show()
	f:Raise()
	History.RefreshPopup(true)
end
M.PSS_ShowHistoryPopup = function(...) return History.ShowPopup(...) end

function History.RefreshPopup(resetScroll)
	local f = popup
	if not f or not f:IsShown() or not f.source then return end
	local title, entries, counts = f.source()
	entries = entries or {}
	f.title:SetText(title or "Block History")
	f.heading:SetText((title or "Block History") .. " (" .. #entries .. ")")
	f.info:SetText("")
	if counts then f.metrics:Set(counts); f.metrics:Show() else f.metrics:Hide() end
	f.list:SetEntries(entries, resetScroll)
end
M.PSS_RefreshHistoryPopup = History.RefreshPopup
