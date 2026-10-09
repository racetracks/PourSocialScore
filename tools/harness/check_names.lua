-- Names (core uplift N1, N2): M.PSS_NormName joins every name and realm.
--   lua5.1 tools/harness/run.lua . <save|-> - tools/harness/check_names.lua
-- 1. Every string in the loaded save (keys and values) gives the same storage
--    key, match key and display as the 3.4.1.31 helpers (copied below): no
--    key changes on any save.
-- 2. The Camelot surname rule: a unit on your own realm whose UnitName gives
--    a second value is "First Last-<own realm>" (in game, 2026-10-08:
--    UnitName("target") -> "Bynathalador", "Darkwind";
--    UnitRealmRelationship("target") -> 1).
-- 3. Secret values give nil, never an error.
-- 4. Every caller (N2): the unit menu, Blizzard's Ignore hook, your own
--    character, typed multi-word names, the managed flush and the import.
local fail = false
local function check(ok, msg) if not ok then print("FAIL names: " .. msg) fail = true end end

------------------------------------------------------------------------
-- The helpers as they were at 3.4.1.31 (PSS_ChatBlock.lua)
------------------------------------------------------------------------
local own = M.PSS_OwnRealm()
local function oldNormalize(name)
	if type(name) ~= "string" then return nil end
	name = M.trim(name)
	if name == "" then return nil end
	local dash = name:find("-", 1, true)
	if not dash then
		name = name .. "-" .. own
	elseif name:find("[%s%-]", dash + 1) then
		name = name:sub(1, dash) .. name:sub(dash + 1):gsub("[%s%-]", "")
	end
	return name:lower()
end
local function oldCanon(name)
	if type(name) ~= "string" then return nil end
	name = M.trim(name)
	if name == "" then return nil end
	local base, realm = name:match("^([^%-]+)%-(.+)$")
	if not base then base, realm = name, own end
	base = M.trim(base):gsub("%s+", " ")
	realm = (realm or ""):gsub("[%s%-']", "")
	return (base .. "-" .. realm):lower()
end
local function oldDisplay(name)
	if not name then return "" end
	return M.Proper(M.addServer(name))
end

------------------------------------------------------------------------
-- 1. Unchanged on every string of the save
------------------------------------------------------------------------
local strings, seen = {}, {}
local function collect(t)
	if type(t) ~= "table" or seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		if type(k) == "string" then strings[k] = true elseif type(k) == "table" then collect(k) end
		if type(v) == "string" then strings[v] = true elseif type(v) == "table" then collect(v) end
	end
end
for _, g in ipairs({ "PourSocialScoreDB", "PSS_OptionsDB", "PSS_PlayersDB", "PSS_GuildsDB", "PSS_RulesDB", "PSS_CountsDB", "PSS_LoggingDB" }) do
	collect(_G[g])
end
local CASES = { "Bob", "bob-realm", "  Bob-Realm ", "First Last", "first  last", "First Last-ClassicBetaPvP",
	"First-Last", "Name-Aman'Thul", "Name-Area 52", "Name-Area-52", "-Realm", "Bob-", "a-b-c", "Bob ", " " }
for _, s in ipairs(CASES) do strings[s] = true end
local n, bad = 0, 0
for s in pairs(strings) do
	n = n + 1
	-- strings Proper would read as a name (the old display errors on none)
	local okOld, dOld = pcall(oldDisplay, s)
	local d, k, c = M.PSS_NormName(s)
	local same = M.PSS_NormalizePlayer(s) == oldNormalize(s) and M.PSS_CanonPlayer(s) == oldCanon(s)
		and k == oldNormalize(s) and c == oldCanon(s)
	if okOld and M.trim(s) ~= "" then
		same = same and M.PSS_DisplayPlayer(s) == dOld and d == dOld
	end
	if not same then
		bad = bad + 1
		if bad <= 5 then check(false, ("%q: %s %s %s against %s %s %s"):format(s, tostring(k), tostring(c), tostring(d),
			tostring(oldNormalize(s)), tostring(oldCanon(s)), tostring(dOld))) end
	end
end
check(bad == 0, bad .. " of " .. n .. " strings changed")
print(("names: %d strings of the save unchanged"):format(n - bad))

------------------------------------------------------------------------
-- 2. Names from a unit
------------------------------------------------------------------------
local realUnitName, realRel = _G.UnitName, _G.UnitRealmRelationship
local unitName, unitRealm, rel
_G.UnitName = function(u) if u == "target" then return unitName, unitRealm end return realUnitName(u) end
_G.UnitRealmRelationship = function(u) if u == "target" then return rel end end
local function unit(name, realm, relation, want, wantKey, wantCanon, wantDisplay, what)
	unitName, unitRealm, rel = name, realm, relation
	check(M.PSS_UnitFullName("target") == want, ("%s: %q, not %q"):format(what, tostring(want), tostring(M.PSS_UnitFullName("target"))))
	local d, k, c = M.PSS_NormName(name, realm, "target")
	check(k == wantKey and c == wantCanon and d == wantDisplay,
		("%s: %s %s %s"):format(what, tostring(k), tostring(c), tostring(d)))
end
local R = own
-- Camelot: the surname on your own realm
unit("Bynathalador", "Darkwind", 1, "Bynathalador Darkwind-" .. R, "bynathalador darkwind-" .. R:lower(),
	"bynathalador darkwind-" .. R:lower(), "Bynathalador Darkwind-" .. R, "Camelot surname")
-- the same person as chat and /who write them: one key
check(M.PSS_CanonPlayer("Bynathalador Darkwind") == "bynathalador darkwind-" .. R:lower(), "the chat form gives another key")
-- Retail: your realm (no second value), another realm, a connected realm
unit("Name", nil, 1, "Name", "name-" .. R:lower(), "name-" .. R:lower(), "Name-" .. R, "own realm")
unit("Name", "", 1, "Name", "name-" .. R:lower(), "name-" .. R:lower(), "Name-" .. R, "own realm, empty")
unit("Name", "Area52", 2, "Name-Area52", "name-area52", "name-area52", "Name-Area52", "another realm")
unit("Name", "Aman'Thul", 3, "Name-Aman'Thul", "name-aman'thul", "name-amanthul", "Name-Aman'thul", "connected realm")
-- /pss add with no name, on that Camelot target: the whole name is listed,
-- and a chat line from "First Last" (as chat writes it) is blocked
unitName, unitRealm, rel = "Bynathalador", "Darkwind", 1
local realControlled = _G.UnitPlayerControlled
_G.UnitPlayerControlled = function() return true end
M.ignoreFromCmd("")
_G.UnitPlayerControlled = realControlled
check((M.PSS_ListedPosition(M.PSS_CanonPlayer("Bynathalador Darkwind")) or 0) > 0, "/pss add on a surname target did not list First Last")
check((M.PSS_ListedPosition(M.PSS_CanonPlayer("Bynathalador")) or 0) == 0, "/pss add on a surname target listed the first name only")
local ok, hit = pcall(M.PSS_CoreFilter, nil, "CHAT_MSG_WHISPER", "hi", "Bynathalador Darkwind", "", "", "", "", 0, 0, "", 0, 812345)
check(ok and hit == true, "a whisper from the listed First Last was not blocked")
-- without UnitRealmRelationship (or no unit): the second value is a realm
_G.UnitRealmRelationship = nil
unit("First", "Last", nil, "First-Last", "first-last", "first-last", "First-Last", "no relationship API")
check(M.PSS_NormName("First", "Last") == "First-Last", "a realm without a unit")

------------------------------------------------------------------------
-- 3. Secret values
------------------------------------------------------------------------
local SECRET = {}
local realSecret = _G.issecretvalue
_G.issecretvalue = function(v) return v ~= nil and SECRET[v] == true end
_G.UnitRealmRelationship = function(u) if u == "target" then return rel end end
SECRET["Hidden"], SECRET["HiddenRealm"] = true, true
unitName, unitRealm, rel = "Hidden", "Realm", 1
check(M.PSS_UnitFullName("target") == nil, "a secret name")
check(M.PSS_NormName("Hidden") == nil and M.PSS_NormalizePlayer("Hidden") == nil and M.PSS_CanonPlayer("Hidden") == nil, "a secret name string")
check(M.PSS_DisplayPlayer("Hidden") == "", "a secret display")
unitName, unitRealm = "Shown", "HiddenRealm"
check(M.PSS_UnitFullName("target") == "Shown", "a secret realm is dropped")
local secretRel = {}
SECRET[secretRel] = true
unitName, unitRealm, rel = "First", "Last", secretRel
check(M.PSS_UnitFullName("target") == "First-Last", "a secret relationship is not read")
check(M.PSS_NormName(nil) == nil and M.PSS_NormName("") == nil and M.PSS_NormName("  ") == nil and M.PSS_NormName(5) == nil, "empty names")

_G.issecretvalue = realSecret

------------------------------------------------------------------------
-- 4. Every name caller (core uplift N2)
------------------------------------------------------------------------
local V = PourSocialScore_NS.V
_G.UnitRealmRelationship = function(u) if u == "target" then return rel end end
local realExists, realIsPlayer = _G.UnitExists, _G.UnitIsPlayer
_G.UnitExists = function(u) return u == "target" end
local function listed(n) return (M.PSS_ListedPosition(M.PSS_CanonPlayer(n)) or 0) > 0 end
local function unlist(n)
	local i = M.hasGlobalIgnored(M.Proper(M.addServer(n)))
	if i > 0 then M.PSS_DelIgnore(i, true) end
end
unlist("Bynathalador Darkwind")
-- your own character: a surname is never a realm (the per-character key)
_G.UnitName = function(u)
	if u == "player" then return "Dan", "Surname" end
	if u == "target" then return unitName, unitRealm end
	return realUnitName(u)
end
check(M.PSS_PlayerDisplayName() == "Dan Surname-" .. R, "own name: " .. tostring(M.PSS_PlayerDisplayName()))
check(select(2, M.PSS_NormName("Dan", "Surname", "player")) == "dan surname-" .. R:lower(), "own key")
-- the unit menu (PSS entry) on a Camelot surname target
unitName, unitRealm, rel = "Erlirrin", "Softgale", 1
local btn
local root = { CreateDivider = function() end, CreateTitle = function() end, CreateButton = function(_, text, fn) if text == "Block Player" or text == "Unblock Player" then btn = fn end end }
M.PSS_UnitMenuPlayer(nil, root, { unit = "target" })
check(btn ~= nil, "the unit menu made no entry")
if btn then btn() end
check(listed("Erlirrin Softgale"), "the unit menu did not list First Last")
check(not listed("Erlirrin-Softgale"), "the unit menu listed First-Last")
unlist("Erlirrin Softgale")
-- the menu from a name in chat (no unit): name and realm as chat gives them
btn = nil
M.PSS_UnitMenuPlayer(nil, root, { name = "Hatti Fnatt", server = "" })
if btn then btn() end
check(listed("Hatti Fnatt"), "the chat-name menu did not list First Last")
unlist("Hatti Fnatt")
-- Blizzard's Ignore on that target hands "First-Last" to the hook
V.PSS_Loaded = true
C_FriendList.AddIgnore("Erlirrin-Softgale")
check(listed("Erlirrin Softgale"), "Blizzard's Ignore on a surname target did not list First Last")
check(not listed("Erlirrin-Softgale"), "Blizzard's Ignore on a surname target listed First-Last")
unlist("Erlirrin Softgale")
-- a cross-realm "Name-Realm" is left as it is (relationship 2)
unitName, unitRealm, rel = "Name", "Area52", 2
check(M.PSS_FixUnitName("Name-Area52") == "Name-Area52", "a realm was taken for a surname")
_G.UnitExists = realExists
check(M.PSS_FixUnitName("Erlirrin-Softgale") == "Erlirrin-Softgale", "no unit, yet the name was changed")
-- typed names: two words are the name off Retail, or when listed
local retail = V.wowIsRetail
V.wowIsRetail = false
local n, rest = M.PSS_SplitNameArg("First Last 30 spams")
check(n == "First Last" and rest == "30 spams", "Camelot: " .. n .. " / " .. rest)
n, rest = M.PSS_SplitNameArg("Bob 30 spams")
check(n == "Bob" and rest == "30 spams", "Camelot, one word: " .. n .. " / " .. rest)
n, rest = M.PSS_SplitNameArg('"Bob" spams')
check(n == "Bob" and rest == "spams", "Camelot, quoted: " .. n .. " / " .. rest)
M.PSS_AddIgnore("Typed Name 30 a note")
check(listed("Typed Name"), "Camelot: /pss add First Last 30 note")
V.wowIsRetail = true
n, rest = M.PSS_SplitNameArg("Bob spams trade")
check(n == "Bob" and rest == "spams trade", "Retail: " .. n .. " / " .. rest)
n, rest = M.PSS_SplitNameArg("Typed Name")
check(n == "Typed Name", "Retail, a listed First Last: " .. n)
unlist("Typed Name")
V.wowIsRetail = retail
-- runtime fields are not saved with a changed shipped member
local gk
if M.PSS_LoadManagedData and M.PSS_LoadManagedData() then
	for k, g in pairs(PourSocialScoreDB.guildData or {}) do
		if not gk and type(g) == "table" and g.managed and #(M.PSS_ShippedNames(k) or {}) >= 2 then gk = k end
	end
end
if gk then
	local first = (M.PSS_ShippedNames(gk) or {})[1]
	local ck = first and M.PSS_CanonPlayer(first)
	local r = ck and M.PSS_ManagedRecord(ck, gk)
	check(r ~= nil, "no shipped record to test the flush with")
	if r then
		r.note = "n2 flush"
		M.PSS_KeepManaged(r)
		M.PSS_FlushManaged()
		local g, saved = PourSocialScoreDB.guildData[gk], nil
		for _, mm in pairs(g.members or {}) do if mm == r or (type(mm) == "table" and mm.note == "n2 flush") then saved = mm end end
		check(saved ~= nil, "the changed shipped member was not saved")
		check(saved and saved._canon == nil and saved._gkey == nil and saved._virtual == nil, "runtime fields saved")
		-- (S3) saved sparse: the shipped mark, the name, the guild and the date are given back
		check(saved and saved._managed == nil and saved.whenBlocked == nil and saved.guild == nil, "the shipped member was saved with fields the rule gives")
		check(saved and M.PSS_MemberShipped(saved) == true, "the shipped member is not read as shipped")
		check(saved and M.PSS_MemberWhenBlocked(saved) == "Managed list", "the shipped member's date")
		check(saved and M.PSS_MemberGuildName(saved) == g.name, "the shipped member's guild")
	end
	-- import: a shipped member is merged into the shipped record, not stored twice
	local second = (M.PSS_ShippedNames(gk) or {})[2]
	if second and M.PSS_Need and M.PSS_Need("Libraries") and M.PSS_ApplyImport then
		local g = PourSocialScoreDB.guildData[gk]
		local before = 0
		for _ in pairs(g.members or {}) do before = before + 1 end
		M.PSS_ApplyImport({ guilds = { { name = g.name or gk, members = { { name = second, note = "n2 import" } } } } }, "merge", { guilds = true, members = true })
		local after = 0
		for _ in pairs(g.members or {}) do after = after + 1 end
		check(after == before, "an imported shipped member was stored again")
		local r2 = M.PSS_ManagedRecord(M.PSS_CanonPlayer(second), gk)
		check(r2 and r2.note == "n2 import", "an imported shipped member's note was lost")
		print("names: the managed flush and the import checked on " .. tostring(gk))
	end
end

_G.issecretvalue, _G.UnitName, _G.UnitRealmRelationship, _G.UnitIsPlayer = realSecret, realUnitName, realRel, realIsPlayer
print(fail and "FAIL names" or "PASS names")
