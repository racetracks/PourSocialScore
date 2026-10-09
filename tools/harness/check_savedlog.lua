-- The saved log (3.2.0-dev007), as a run.lua script: lines of players,
-- guild members, chat filters (several senders), world and guild chat are
-- saved one group per owner (a name once) and come back exactly, the keep
-- included; the saved text is smaller than the old one-table-a-line log.
--   PSS_PHASE=1 : add the lines, note them (PSS_NOTE), log out
--   PSS_PHASE=2 : the log and keep after the login match the note
local phase = tonumber(os.getenv("PSS_PHASE") or "1")
local note = os.getenv("PSS_NOTE")
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL saved log: " .. msg) fail = true end end
local F = { "ts", "cat", "event", "channel", "member", "message", "o", "r", "gk" }

local function dump()
	local out = {}
	for _, h in ipairs(History.Log()) do
		local t = {}
		for i, k in ipairs(F) do t[i] = tostring(rawget(h, k) or (k == "channel" and h.channel) or "") end
		out[#out + 1] = table.concat(t, "|")
	end
	local keep, owners = History.Keep(), {}
	for o in pairs(keep) do owners[#owners + 1] = o end
	table.sort(owners)
	for _, o in ipairs(owners) do
		local l = keep[o]
		out[#out + 1] = "K " .. o .. " " .. tostring(l.m) .. " " .. tostring(l.gk) .. " " .. tostring(l.r)
		for i = 1, #l do out[#out + 1] = l[i] end
	end
	return table.concat(out, "\n")
end

check(M.PSS_LoadLogging(), "Logging not loaded")
if phase == 1 then
	local add = function(o, cat, ev, msg, ch, member, gk, r)
		H.Advance(7)
		local h = History.NewEntry(cat, ev, msg, ch, member)
		h.ts = GetServerTime()
		h.gk = gk
		History.Add(o, nil, h, r)
	end
	local fk = M.PSS_FilterOwnerKey(1)
	local fid = PourSocialScoreDB.filterID[1]
	fid = fid ~= "" and fid or nil
	for k = 0, 49 do M.PSS_AddIgnore(("Spammer%02d-Realm"):format(k), true) end
	M.PSS_AddIgnore("Grunt-Realm", true)
	M.PSS_AddIgnore("Odd-Realm", true)
	M.PSS_AddIgnore("Early-Realm", true)		-- trimmed off the log: kept
	M.PSS_AddGuild("Bad Guild")
	local gk = M.PSS_NormalizeGuild("Bad Guild")
	for i = 1, 3000 do
		local k = i % 50
		add(History.PlayerKey(("Spammer%02d-Realm"):format(k)), "whisper", "CHAT_MSG_WHISPER", "buy gold " .. (i % 3))
		if i % 3 == 0 then add(("g:gm%02d-realm"):format(k), "world", "CHAT_MSG_CHANNEL", "WTS boost\tnow", "2. Trade - City", ("Gm%02d-Realm"):format(k), gk) end
		if i % 4 == 0 then add(fk, "world", "CHAT_MSG_CHANNEL", "filtered " .. i, i % 8 == 0 and "4. LookingForGroup" or "2. Trade - City", ("Sender%d-Realm"):format(i % 9), nil, fid) end
		if i % 11 == 0 then add(History.PlayerKey("Grunt-Realm"), "guildChat", "CHAT_MSG_GUILD", "guild line", nil, "Grunt-Realm") end
		if i % 13 == 0 then add(History.PlayerKey("Grunt-Realm"), "partyInvite", "PARTY_INVITE", "") end
		if i <= 300 and i % 10 == 0 then add(History.PlayerKey("Early-Realm"), i % 20 == 0 and "whisper" or "guildInvite", i % 20 == 0 and "CHAT_MSG_WHISPER" or "GUILD_INVITE", "early " .. i, i == 40 and "Whisper (alt)" or nil) end
		if i % 17 == 0 then add(History.PlayerKey("Odd-Realm"), "unknown", "SOME_NEW_EVENT", "\2odd \1 line \2", "Custom", nil) end
	end
	local db = PourSocialScoreDB
	local old = #H.serialize(db.blockLog) + #H.serialize(db.blockKeep or {})
	-- (a login trims the log to the setting, as LoadLogging does)
	History.CapKeep(true)
	History.Trim(true)
	M.PSS_TidyBlockHistory()
	local before = dump()
	History.PackForSave()
	local saved = H.serialize(db.blockLog)
	check(db.blockLog.v == 2 and db.blockKeep == nil, "not packed")
	local _, names = saved:gsub("p:spammer07%-realm", "")
	check(names == 1, "a player's name saved " .. names .. " times")
	check(db.blockLog[History.PlayerKey("Early-Realm")].k == 15, "kept lines not saved first")
	print(("saved log: %d bytes, %d as one table a line"):format(#saved, old))
	check(#saved < old / 2, "saved log not smaller")
	History.UnpackSaved()
	local now = dump()
	if now ~= before then
		local a, b = {}, {}
		for l in (before .. "\n"):gmatch("(.-)\n") do a[#a + 1] = l end
		for l in (now .. "\n"):gmatch("(.-)\n") do b[#b + 1] = l end
		for i = 1, math.max(#a, #b) do
			if a[i] ~= b[i] then print("was: " .. tostring(a[i])); print("now: " .. tostring(b[i])); break end
		end
	end
	check(now == before, "lines changed by a save and load in place")
	local fh = assert(io.open(note, "w")); fh:write(before); fh:close()
else
	local fh = assert(io.open(note)); local before = fh:read("*a"); fh:close()
	local now = dump()
	if now ~= before then
		local a, b = {}, {}
		for l in (before .. "\n"):gmatch("(.-)\n") do a[#a + 1] = l end
		for l in (now .. "\n"):gmatch("(.-)\n") do b[#b + 1] = l end
		for i = 1, math.max(#a, #b) do
			if a[i] ~= b[i] then print("was: " .. tostring(a[i])); print("now: " .. tostring(b[i])); break end
		end
	end
	check(now == before, "lines changed over a logout")
end
if not fail then print("PASS saved log " .. phase) end
