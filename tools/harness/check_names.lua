-- Names (core uplift N1): M.PSS_NormName joins every name and realm.
--   lua5.1 tools/harness/run.lua . <save|-> - tools/harness/check_names.lua
-- 1. Every string in the loaded save (keys and values) gives the same storage
--    key, match key and display as the 3.4.1.31 helpers (copied below): no
--    key changes on any save.
-- 2. The Camelot surname rule: a unit on your own realm whose UnitName gives
--    a second value is "First Last-<own realm>" (in game, 2026-10-08:
--    UnitName("target") -> "Bynathalador", "Darkwind";
--    UnitRealmRelationship("target") -> 1).
-- 3. Secret values give nil, never an error.
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

_G.issecretvalue, _G.UnitName, _G.UnitRealmRelationship = realSecret, realUnitName, realRel
print(fail and "FAIL names" or "PASS names")
