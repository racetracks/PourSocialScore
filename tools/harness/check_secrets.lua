-- Secret values (Retail 12.x, PSS 02 section 10): chat, unit and hook values
-- the client hides from addons. Here a few plain strings are made secret
-- through the stub's issecretvalue; the addon must check them before any
-- use, never error, never count them and never store them.
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_secrets.lua
local History = M.PSS_History
local fail = false
local function check(ok, msg) if not ok then print("FAIL secrets: " .. msg) fail = true end end

local SECRET = {}
local function secret(s) SECRET[s] = true return s end
_G.issecretvalue = function(v) return v ~= nil and SECRET[v] == true end

local lineID = 700000
local function line(event, msg, author, chString, chIndex, chName, guid)
	lineID = lineID + 1
	local ok, hit = pcall(M.PSS_CoreFilter, nil, event, msg, author, "", chString or "", "", "",
		0, chIndex or 0, chName or "", 0, lineID, guid)
	check(ok, "the filter raised an error: " .. tostring(hit))
	return hit == true
end

-- every string kept in a table, keys and values, nested
local function holds(t, s, seen)
	seen = seen or {}
	if type(t) ~= "table" or seen[t] then return false end
	seen[t] = true
	for k, v in pairs(t) do
		if k == s or v == s then return true end
		if type(k) == "string" and k:find(s, 1, true) then return true end
		if type(v) == "string" and v:find(s, 1, true) then return true end
		if holds(k, s, seen) or holds(v, s, seen) then return true end
	end
	return false
end

-- 1. a secret author or GUID: not filtered, not counted
local P = "Listed-Realm"
M.PSS_AddIgnore(P, true)
local key = History.PlayerKey(P)
check(line("CHAT_MSG_WHISPER", "hello", P), "a listed author was not blocked")
local s0 = History.RecentCounts(key)
local SA = secret("Listed-Realm ")
check(not line("CHAT_MSG_WHISPER", "hello", SA), "a secret author was blocked")
check(not line("CHAT_MSG_WHISPER", "hello", P, nil, nil, nil, secret("Player-1-SECRETGUID")), "a line with a secret GUID was blocked")
check(History.RecentCounts(key) == s0, "a skipped line was counted")

-- 2. a readable listed author with a secret message (decision 1a): blocked and
-- counted, and the message itself is never kept
local SM = secret("SECRET MESSAGE TEXT")
check(line("CHAT_MSG_WHISPER", SM, P), "a listed author's secret message was not blocked")
check(History.RecentCounts(key) == s0 + 1, "a listed author's secret message was not counted")

-- 3. secret channel args never reach the filter tags ([chname], [channel])
check(M.PSS_AddCustomFilter("Open channel", "[chname=openchan]", true) ~= nil, "test filter not added")
check(M.PSS_AddCustomFilter("Hidden channel", "[chname=hiddenchan]", true) ~= nil, "test filter not added")
check(line("CHAT_MSG_CHANNEL", "buy gold", "Someone-Realm", "5. openchan", 5, "openchan"), "the [chname] filter does not block a readable channel")
check(not line("CHAT_MSG_CHANNEL", "buy gold", "Someone-Realm", secret("6. hiddenchan"), 6, secret("hiddenchan")), "a secret channel name reached [chname]")
check(not line("CHAT_MSG_CHANNEL", "buy gold", "Someone-Realm", "7. Trade", secret(7), "Trade"), "a secret channel number broke the line")

-- 4. a secret target name: nothing added, no error
local before = M.PSS_PlayerCount()
local ST = secret("Target")
local realUnitName = _G.UnitName
_G.UnitName = function(u)
	if u == "target" then return ST, secret("TargetRealm") end
	return realUnitName(u)
end
_G.UnitPlayerControlled = function() return true end
check(M.PSS_UnitFullName("target") == nil, "PSS_UnitFullName returned a secret name")
local ok, err = pcall(M.ignoreFromCmd, "")
check(ok, "ignoreFromCmd: " .. tostring(err))
ok, err = pcall(M.PSS_AddIgnore, "")
check(ok, "PSS_AddIgnore: " .. tostring(err))
ok, err = pcall(M.PSS_AddOrDelIgnore, "")
check(ok, "PSS_AddOrDelIgnore: " .. tostring(err))
check(M.PSS_PlayerCount() == before, "a secret target was added")
_G.UnitName = function(u)
	if u == "target" then return "Readable", "Realm" end
	return realUnitName(u)
end
check(M.PSS_UnitFullName("target") == "Readable-Realm", "PSS_UnitFullName with a readable target")
_G.UnitName = realUnitName

-- 5. no secret is kept anywhere saved or in the outbox
-- (text secrets only: a secret channel number such as 7 is no name or
-- message, and any 7 in a count, a date or the version would match it)
for s in pairs(SECRET) do
	if type(s) == "string" then
		check(not holds(PourSocialScoreDB, s), ("%q kept in PourSocialScoreDB"):format(s))
		check(not holds(_G.PSS_OptionsDB, s), ("%q kept in PSS_OptionsDB"):format(s))
		check(not holds(_G.PSS_LoggingDB, s), ("%q kept in PSS_LoggingDB"):format(s))
	end
end

if not fail then print("PASS secrets") end
