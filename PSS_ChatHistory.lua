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
	if type(h.member) ~= "string" or h.member == "" then h.member = nil end		-- caller may know the owner
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
-- from the log and the per-player keep (below). The per-type blocked COUNTS
-- stay on each owner and are totals: they are never cut, and no history
-- line (log or keep) is ever counted again.
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
History.Max = History.Cap		-- (older name)

-- time / kind are worked out when read
History.EntryMT = { __index = function(h, k)
	if k == "time" then return History.FormatTime(rawget(h, "ts"))
	elseif k == "kind" then return CAT_LABEL[rawget(h, "cat") or "unknown"] or UNKNOWN end
end }

local attached = setmetatable({}, { __mode = "k" })
local keepsOwner
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

------------------------------------------------------------------------
-- PER-PLAYER KEEP
--
-- When lines leave the shared log (Trim), a player's or guild member's line
-- is MOVED (never copied) to PourSocialScoreDB.blockKeep if it is still one
-- of that person's newest
--   10 chat lines, 5 emotes, 5 party invites, 5 guild invites
-- counting the lines they still have in the log. So everyone who was ever
-- blocked keeps at least that much history, however busy the log is.
-- A line is in exactly ONE place (log or keep); the block counters live on
-- the owners and are never worked out from lines, so nothing is counted
-- twice. Chat filter lines (o = "f:...") are not kept: a filter's senders
-- are strangers and there can be thousands of them.
--   blockKeep = { ["p:<key>" | "g:<key>"] = { entry, ... } (oldest first) }
-- Keep lines are always older than every log line of the same owner.
------------------------------------------------------------------------
History.KEEP = { text = 10, emote = 5, party = 5, guild = 5 }
local KEEP = History.KEEP
local EMOTE_EVENT = { CHAT_MSG_EMOTE = true, CHAT_MSG_TEXT_EMOTE = true }

-- text | emote | party | guild
function History.KeepKind(h)
	local cat = h.cat
	if cat == "partyInvite" then return "party" end
	if cat == "guildInvite" then return "guild" end
	if EMOTE_EVENT[h.event] or h.channel == "Emote" then return "emote" end
	return "text"
end
local keepKind = History.KeepKind

-- "p:..." or "g:..." (a person); byte compare, no new strings
function keepsOwner(o)
	if type(o) ~= "string" then return false end
	local a, b = o:byte(1, 2)
	return b == 58 and (a == 112 or a == 103)
end
History.KeepsOwner = keepsOwner

function History.Keep()
	local db = PourSocialScoreDB
	if type(db) ~= "table" then return {} end
	local keep = db.blockKeep
	if type(keep) ~= "table" then keep = {}; db.blockKeep = keep end
	if not attached[keep] then
		for o, list in pairs(keep) do
			if type(list) ~= "table" or not keepsOwner(o) then
				keep[o] = nil
			else
				local j = 0
				for i = 1, #list do
					local h = list[i]
					list[i] = nil
					if type(h) == "table" then j = j + 1; list[j] = setmetatable(h, History.EntryMT) end
				end
				if j == 0 then keep[o] = nil end
			end
		end
		attached[keep] = true
	end
	return keep
end

-- Work out the keep of `owners` (set of owner keys) again: their kept lines
-- plus `dropped` (lines just taken off the front of the log, oldest first),
-- newest first, as long as the person has room for that kind once their
-- log lines are counted. Everything else is let go.
function History.SettleKeep(owners, dropped, n)
	local keep, log = History.Keep(), History.Log()
	local used, cand = {}, {}
	for o in pairs(owners) do
		used[o] = {}
		local c, old = {}, keep[o]
		if old then for i = 1, #old do c[i] = old[i] end end
		cand[o] = c
	end
	for i = 1, #log do
		local h = log[i]
		local u = used[h.o]
		if u then
			local k = keepKind(h)
			u[k] = (u[k] or 0) + 1
		end
	end
	for i = 1, (n or 0) do
		local h = dropped[i]
		local c = cand[h.o]
		if c then c[#c + 1] = h end
	end
	for o, c in pairs(cand) do
		local u, out = used[o], {}
		for i = #c, 1, -1 do
			local h = c[i]
			local k = keepKind(h)
			local have = u[k] or 0
			if have < KEEP[k] then u[k] = have + 1; out[#out + 1] = h end
		end
		local m = #out
		if m == 0 then
			keep[o] = nil
		else
			for i = 1, math.floor(m / 2) do out[i], out[m - i + 1] = out[m - i + 1], out[i] end
			keep[o] = out
		end
	end
end

-- Settle every kept person (after a tidy-up or a cleared history).
function History.SettleAllKeep()
	local owners
	for o in pairs(History.Keep()) do owners = owners or {}; owners[o] = true end
	if owners then History.SettleKeep(owners) end
end

-- Number of kept lines and people.
function History.KeepSize()
	local lines, people = 0, 0
	for _, list in pairs(History.Keep()) do lines = lines + #list; people = people + 1 end
	return lines, people
end

-- fn(entry) for every line, log first (oldest first), then the keep.
function History.Each(fn)
	local log = History.Log()
	for i = 1, #log do fn(log[i]) end
	for _, list in pairs(History.Keep()) do
		for i = 1, #list do fn(list[i]) end
	end
end

-- Keep the newest `cap` lines. Done in batches (when the log is 5 % over)
-- so adding a line never shifts the whole list.
function History.Trim(force)
	local log = History.Log()
	local cap = History.Cap()
	local n = #log
	if n <= cap or (not force and n <= cap + math.max(20, math.floor(cap / 20))) then return 0 end
	local drop = n - cap
	local dropped, owners = {}, nil
	for i = 1, drop do
		local h = log[i]
		dropped[i] = h
		if keepsOwner(h.o) then owners = owners or {}; owners[h.o] = true end
	end
	for i = 1, cap do log[i] = log[i + drop] end
	for i = cap + 1, n do log[i] = nil end
	-- a player's newest lines move to the keep (not copied)
	if owners then History.SettleKeep(owners, dropped, drop) end
	-- no cleanup request here: about 100 lines (~30 KB) leave at a time, and
	-- a busy channel trims often; a cycle walks the whole game heap
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
-- Kept lines come after the log lines (they are older).
local function byTimeDesc(a, b)
	if (a.ts or 0) ~= (b.ts or 0) then return (a.ts or 0) > (b.ts or 0) end
	return tostring(a.o or "") < tostring(b.o or "")
end
function History.Collect(pred)
	local log, out = History.Log(), {}
	for i = #log, 1, -1 do
		local h = log[i]
		if h and pred(h) then out[#out + 1] = h end
	end
	local older, owners = nil, 0
	for _, list in pairs(History.Keep()) do
		local hit = false
		for i = #list, 1, -1 do
			local h = list[i]
			if pred(h) then older = older or {}; older[#older + 1] = h; hit = true end
		end
		if hit then owners = owners + 1 end
	end
	if older then
		if owners > 1 then table.sort(older, byTimeDesc) end
		for i = 1, #older do out[#out + 1] = older[i] end
	end
	return out
end
function History.For(owner)
	local log, out = History.Log(), {}
	for i = #log, 1, -1 do
		local h = log[i]
		if h.o == owner then out[#out + 1] = h end
	end
	local kept = owner and History.Keep()[owner]
	if kept then for i = #kept, 1, -1 do out[#out + 1] = kept[i] end end
	return out
end
function History.CountFor(owner)
	local log, n = History.Log(), 0
	for i = 1, #log do if log[i].o == owner then n = n + 1 end end
	local kept = owner and History.Keep()[owner]
	return n + (kept and #kept or 0)
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
	local removed = n - j
	local keep = History.Keep()
	for o, list in pairs(keep) do
		local k, m = 0, #list
		for i = 1, m do
			local h = list[i]
			if not pred(h) then k = k + 1; list[k] = h end
		end
		for i = k + 1, m do list[i] = nil end
		if k == 0 then keep[o] = nil end
		removed = removed + m - k
	end
	if removed > 0 and M.PSS_RequestGC then M.PSS_RequestGC("history cleared") end
	return removed
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
	local bytes, lines = 0, 0
	History.Each(function(h)
		lines = lines + 1
		bytes = bytes + 120		-- table + 6-8 fields
		for j = 1, #EST_KEYS do
			local v = rawget(h, EST_KEYS[j])
			if type(v) == "string" then bytes = bytes + 24 + #v end
		end
	end)
	return bytes, #History.Log(), lines
end

------------------------------------------------------------------------
-- Tidy-up (every login, after the upgrades): drop lines whose owner is no
-- longer part of the addon, and tags that point at something gone.
--   alive.p / alive.g / alive.f (o, h) -> true while that listed player /
--                       guild member / chat filter still exists
--   alive.rule(id)    -> true while that Chat Filters rule exists (h.r)
--   alive.guild(gkey) -> true while that guild rule exists (h.gk)
-- A kind of owner with no check is left alone. Counters are not touched.
------------------------------------------------------------------------
function History.Tidy(alive)
	local removed = History.Clear(function(h)
		if type(h) ~= "table" or type(h.o) ~= "string" then return true end
		local t = h.o:sub(1, 1)
		local check = alive[t]
		return check ~= nil and not check(h.o, h)
	end)
	History.Each(function(h)
		if h.r ~= nil and alive.rule and not alive.rule(h.r) then h.r = nil end
		if h.gk ~= nil and alive.guild and not alive.guild(h.gk) then h.gk = nil end
		-- fields of older builds (worked out when shown)
		if rawget(h, "time") ~= nil or rawget(h, "kind") ~= nil then h.time, h.kind = nil, nil end
	end)
	History.SettleAllKeep()
	return removed
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
