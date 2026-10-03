------------------------------------------------------------------------
-- POUR SOCIAL SCORE - IGNORE LIST LOOKUP
--
-- The core side of the Dashboard tab (PSS_DashboardUI.lua): finds the
-- people on the Player Ignore List and on the guild lists (the shipped
-- built-in lists and the members found by scans), one entry per person
-- however many lists they are on, and takes a person off the lists picked.
-- Nothing is saved or built at load: the lists are read when asked.
--
--   M.PSS_ListLookup(text, max)   people whose name contains text
--   M.PSS_ListDuplicates(max)     people on more than one list
--   M.PSS_RemoveFromLists(ck, what)
--
-- An entry: { ck =, name =, lists =, player = { name =, index = } or nil,
--   guilds = { { key =, name =, member =, storedKey =, builtIn =, ruleOn = }, ... } }
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

local canonPlayer		= M.PSS_CanonPlayer
local displayPlayer		= M.PSS_DisplayPlayer
local trim				= M.PSS_Trim

M.PSS_LOOKUP_MAX = 500		-- most people one lookup returns

-- "Bob", "bob-Aman'Thul", "First Last-Area 52" -> what canon keys contain
local function lookupText(text)
	text = trim(tostring(text or "")):gsub("%s+", " "):lower()
	local base, realm = text:match("^([^%-]*)%-(.*)$")
	if base then text = base .. "-" .. realm:gsub("[%s%-']", "") end
	return text
end

-- One pass over every list. keep(ck) says whether a person is wanted;
-- only they get an entry. With limit, people past the first limit get
-- none (the work stays the same for "a" as for a full name). Returns the
-- entries in any order, and true when some were left out.
local function collect(keep, limit)
	local byCk, out, more = {}, {}, false
	local function entry(ck)
		local e = byCk[ck]
		if not e then
			if limit and #out >= limit then more = true return nil end
			e = { ck = ck, guilds = {} }
			byCk[ck] = e
			out[#out + 1] = e
		end
		return e
	end
	local function addGuild(e, gkey, g, m, storedKey, builtIn)
		if not e then return end
		for _, gl in ipairs(e.guilds) do
			if gl.key == gkey then
				-- shipped and also stored under the same rule: one list
				if m and not gl.member then gl.member, gl.storedKey = m, storedKey end
				gl.builtIn = gl.builtIn or builtIn
				return
			end
		end
		e.guilds[#e.guilds + 1] = { key = gkey, name = g.name or gkey, member = m, storedKey = storedKey,
			builtIn = builtIn, ruleOn = M.PSS_GuildRuleActive(g) }
	end

	if M.PSS_ForEachListedPlayer then
		M.PSS_ForEachListedPlayer(function(ck, name, index)
			local e = keep(ck) and entry(ck)
			if e then e.player = { name = name, index = index } end
		end)
	end

	local data = PourSocialScoreDB and PourSocialScoreDB.guildData or {}
	for gkey, g in pairs(data) do
		if type(g) == "table" and type(g.members) == "table" then
			for k, m in pairs(g.members) do
				if type(m) == "table" then
					local ck = canonPlayer(type(k) == "string" and k or nil) or canonPlayer(m.name)
					if ck and keep(ck) then
						addGuild(entry(ck), gkey, g, m, k, M.PSS_IsManagedStaticMember(gkey, ck))
					end
				end
			end
		end
	end
	if M.PSS_ForEachShippedMember then
		M.PSS_ForEachShippedMember(function(ck, gkey)
			if keep(ck) then addGuild(entry(ck), gkey, data[gkey], nil, nil, true) end
		end)
	end

	return out, more
end

-- Names, lists count and the shipped record (built only for the people shown).
local function finish(out, max)
	table.sort(out, function(a, b) return a.ck < b.ck end)
	for i = #out, (max or M.PSS_LOOKUP_MAX) + 1, -1 do out[i] = nil end
	for _, e in ipairs(out) do
		for _, gl in ipairs(e.guilds) do
			if not gl.member then gl.member = M.PSS_ManagedRecord(e.ck, gl.key) end
		end
		local gm = e.guilds[1] and e.guilds[1].member
		e.name = (e.player and displayPlayer(e.player.name)) or (gm and gm.name) or e.ck
		e.lists = #e.guilds + (e.player and 1 or 0)
	end
	return out
end

-- People on any list whose name contains text (name, or name-realm).
-- Returns the entries sorted by name (at most max), and true when more
-- matched than that.
function M.PSS_ListLookup(text, max)
	local q = lookupText(text)
	if q == "" then return {}, false end
	max = max or M.PSS_LOOKUP_MAX
	local out, more = collect(function(ck) return ck:find(q, 1, true) ~= nil end, max)
	return finish(out, max), more
end

-- People on more than one list: the Player Ignore List and a guild list,
-- or two guild lists. Returns the entries sorted by name, and the count.
function M.PSS_ListDuplicates(max)
	local out = collect(function() return true end)
	local dup = {}
	for _, e in ipairs(out) do
		if #e.guilds + (e.player and 1 or 0) > 1 then dup[#dup + 1] = e end
	end
	local found = #dup
	return finish(dup, max), found
end

-- One person's entry, as the lists are now (nil if on none).
local function current(ck)
	local out = collect(function(c) return c == ck end)
	return finish(out)[1]
end
M.PSS_ListEntry = current

-- Take a person off lists. what = "player" (Player Ignore List), a guild
-- rule key, "guilds" (every guild list) or "all". Guild lists go first, so
-- someone taken off both is not kept blocked on a built-in list (see
-- M.PSS_KeepBlockedOnBuiltIn); off the Player Ignore List only, a built-in
-- list member stays there with W I G P C blocked and a note, as everywhere.
-- Returns the number of lists they were taken off.
function M.PSS_RemoveFromLists(ck, what)
	local e = ck and current(ck)
	if not e then return 0 end
	local n = 0
	if what ~= "player" then
		for _, gl in ipairs(e.guilds) do
			if what == "all" or what == "guilds" or what == gl.key then
				local name = gl.member and gl.member.name or e.name
				if M.PSS_RemoveGuildMember(gl.key, name, gl.key, gl.storedKey) then n = n + 1 end
			end
		end
		if n > 0 then M.Events.Fire("GUILDS_CHANGED") end
	end
	if e.player and (what == "player" or what == "all") then
		local index = M.PSS_ListedPosition(ck)
		if index then
			M.PSS_DelIgnore(index, true)
			n = n + 1
		end
	end
	return n
end
