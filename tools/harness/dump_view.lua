-- Everything the addon shows about a save, read the way the window reads it
-- (through the accessors), one sorted line each, as a run.lua script. S3
-- (3.4.1.52) saves records sparse; sparse_saves.sh runs this with the previous
-- build and with the working tree on the same save and the two dumps must be
-- identical: the same fields, counters, history lines and recent counts.
--   lua5.1 tools/harness/run.lua <tree> <save> - tools/harness/dump_view.lua
-- Left out on purpose: a custom chat filter's id (it gets one in S3; the
-- filter is named by its position), and the date of a shipped member (read as
-- "Managed list": the one member that carried a real date and the shipped mark
-- now reads as shipped, as it always counted).
local H = _G.H
local History = M.PSS_History
local db = PourSocialScoreDB
local out = {}
local function put(...)
	local t = { ... }
	for i = 1, #t do t[i] = tostring(t[i]) end
	out[#out + 1] = table.concat(t, "|")
end
local function cs(c)
	local t = {}
	for _, k in ipairs(History.ALL_CATS) do t[#t + 1] = tostring(c[k] or 0) end
	t[#t + 1] = tostring(History.CountTotal and History.CountTotal(c) or c.total or 0)
	return table.concat(t, ",")
end
local function recent(owner)
	local s, d = History.RecentCounts(owner)
	return s .. "/" .. d
end
local function lines(owner)
	return #History.For(owner)
end
local function flat(v)
	if type(v) == "table" then return H.serialize(v):gsub("%s+", " ") end
	return tostring(v)
end

M.PSS_LoadLogging()
if M.PSS_Need then M.PSS_Need("Libraries") end

-- (the member index is built, as the first chat line builds it)
M.PSS_LookupGuildMember("Nobody-Nowhere")

-- guild rules and their members
local exclCats = M.PSS_EXCL_CATS
for gkey, g in pairs(db.guildData or {}) do
	if type(g) == "table" then
		put("G", gkey, g.name, g.enabled, g.managed, g.customScan, flat(M.PSS_GuildBlock(g)), M.PSS_GuildMemberCount(g, gkey))
		for k, m in pairs(g.members or {}) do
			local eff = {}
			for _, c in ipairs(exclCats) do eff[#eff + 1] = M.PSS_MemberBlocks(g, m, c) and "1" or "0" end
			local shipped = M.PSS_MemberShipped(m, g)
			local when = shipped and "Managed list" or M.PSS_MemberWhenBlocked(m)
			local owner = "g:" .. tostring(M.PSS_MemberCanon(m, k))
			put("M", gkey, k, M.PSS_MemberName(m), M.PSS_MemberName(m, k), M.PSS_MemberGuildName(m), M.PSS_MemberGuildName(m, g),
				when, shipped, M.PSS_MemberCanon(m) ~= nil, M.PSS_MemberCanon(m, k), m.class, m.level, m.faction, m.note,
				cs(M.PSS_GetMemberBlockCounts(m)), table.concat(eff), flat(m.opts or ""),
				owner, recent(owner), lines(owner), tostring(m.lastBlockedInvite))
		end
	end
end

-- players
for key, p in pairs(db.playerData or {}) do
	if type(p) == "table" then
		local f = {}
		for _, name in ipairs({ "whispersBlocked", "partyInvitesBlocked", "guildInvitesBlocked", "partyRaidBlocked", "channelsBlocked" }) do
			f[#f + 1] = p[name] ~= false and "1" or "0"
		end
		local owner = History.PlayerKey(p.name or key)
		put("P", key, p.name, table.concat(f), cs(M.PSS_GetPlayerBlockCounts(p)), flat(p.opts or ""), p.faction, p.class,
			p.currentGuild, p.blizzardIgnore, owner, recent(owner), lines(owner))
	end
end
for i, e in ipairs(db.list or {}) do
	put("E", i, e.name, e.kind or "player", e.note or "", e.exp or 0, e.faction or "", e.date or "")
end
for i, n in ipairs(db.delList or {}) do put("D", i, n) end

-- chat filters (a custom filter is named by its text, its id left out)
for i = 1, #db.filterList do
	local builtin = M.PSS_IsBuiltinFilter(i)
	local owner = M.PSS_FilterOwnerKey(i)
	if builtin then
		put("F", i, db.filterID[i], db.filterDesc[i], db.filterList[i], db.filterActive[i], db.filterCount[i],
			cs(M.PSS_FilterCounts(i) or {}), recent(owner), lines(owner))
	else
		put("F", i, "custom", db.filterDesc[i], db.filterList[i], db.filterActive[i], db.filterCount[i],
			cs(M.PSS_FilterCounts(i) or {}), recent(owner), lines(owner))
	end
end

-- the numbers and the log
local n = M.PSS_Validate().n
for k, v in pairs(n) do put("N", k, v) end
put("L", #History.Log(), History.KeepSize and History.KeepSize() or "")
local totals = M.PSS_ListTotals
if totals then
	for _, kind in ipairs({ "players", "guilds", "filters" }) do
		put("T", kind, cs(totals(kind, {})))
	end
end

table.sort(out)
for i = 1, #out do print("V " .. out[i]) end
