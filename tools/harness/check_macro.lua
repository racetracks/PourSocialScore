-- Macro helper (/pss macro, 3.5.0, Camelot only), as a run.lua script.
-- The phase is PSS_PHASE; each prints "PASS macro <phase>" or "FAIL macro: ...".
--   data       (PSS_CAMELOT=1) the shipped sets: keys, stores, names, bodies
--   global     (PSS_CAMELOT=1) global create: account macros, then current
--   class      (PSS_CAMELOT=1 PSS_CLASS=WARRIOR) warrior create: character macro
--   wrongclass (PSS_CAMELOT=1) a class set on another class; unknown sets
--   stores     (PSS_CAMELOT=1 PSS_CLASS=WARRIOR) account or character per
--              macro: macro over set over default; the command word; store
--              scoped names; room counted per store
--   existing   (PSS_CAMELOT=1 PSS_MACRO_SEED=...) same name, same store: updated
--   dynicon    (PSS_CAMELOT=1 PSS_MACRO_DYNICON=1) the body alone decides "current"
--   full       (PSS_CAMELOT=1 PSS_MACRO_MAX=... PSS_MACRO_SEED=...) no room
--   combat     (PSS_CAMELOT=1) create refused in combat, preview works
--   list       (PSS_CAMELOT=1) /pss macro and the preview write nothing
--   noapi      (PSS_CAMELOT=1 PSS_MACRO_NOAPI=1) one line, no error
--   retail     (no PSS_CAMELOT) one line, nothing defined
--   login      (PSS_CAMELOT=1) nothing loads or is saved at login
--   memory     (PSS_CAMELOT=1) resident cost, garbage per command, nothing
--              kept after a command, no new keys on M or globals
-- The stub's macro stores are in wow_stub.lua (7.1 of the design on
-- scratch docs/latest/macro-helper/01_DESIGN.md).
local phase = os.getenv("PSS_PHASE") or "global"
local fail = false
local function check(ok, msg) if not ok then print("FAIL macro: " .. phase .. ": " .. msg) fail = true end return ok end
local loaded = function(name) return C_AddOns.IsAddOnLoaded(name) end

local realPrint = print
local said
local function capture(fn, ...)
	said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local ok, a, b, c = pcall(fn, ...)
	print = realPrint
	check(ok, "error: " .. tostring(a))
	return said, a, b, c
end
local function has(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return s end end
end
-- run a /pss command and return its chat lines
local function pss(cmd) return (capture(M.PSS_SlashPSS, cmd)) end
local function needLibraries()
	check(M.PSS_Need("Libraries"), "Libraries did not load")
	return loaded("PourSocialScore_Libraries")
end
-- the macro called name in one store ("account" or "char"), or nil
local function macro(where, name)
	for _, m in ipairs(H.macros[where]) do if m.name == name then return m end end
end
local function count(where) return #H.macros[where] end
local function reset(spec)
	H.SeedMacros(spec)
	H.macroWrites, H.combat = {}, false
end
local function expectLine(lines, text, what)
	check(has(lines, text), what .. ": no line with \"" .. text .. "\" (got: " .. table.concat(lines, " | ") .. ")")
end

local phases = {}

function phases.data()
	needLibraries()
	local data = M.PSS_MacroData and M.PSS_MacroData()
	if not check(type(data) == "table", "M.PSS_MacroData() returned no table") then return end
	local CLASSES = { global = true, druid = true, hunter = true, mage = true, paladin = true, priest = true,
		rogue = true, shaman = true, warlock = true, warrior = true }
	local STORE = { account = true, character = true }
	local seen = {}
	for key, set in pairs(data) do
		check(CLASSES[key], "unknown set " .. tostring(key))
		check(type(set) == "table", "set " .. tostring(key) .. " is not a table")
		check(set.store == nil or STORE[set.store], "set " .. tostring(key) .. " store " .. tostring(set.store))
		for k in pairs(set) do check(k == "store" or type(k) == "number", "set " .. tostring(key) .. " has key " .. tostring(k)) end
		for i, m in ipairs(set) do
			local where = tostring(key) .. "[" .. i .. "]"
			check(type(m.name) == "string" and #m.name >= 1 and #m.name <= 16, where .. " name length")
			check(type(m.body) == "string" and #m.body >= 1 and #m.body <= 255, where .. " body length")
			check(not (m.name or ""):find("[^\32-\126]"), where .. " name is not printable ASCII")
			check(not (m.body or ""):find("[^\10\32-\126]"), where .. " body is not printable ASCII")
			check(m.icon == nil or type(m.icon) == "number" or type(m.icon) == "string", where .. " icon")
			check(m.store == nil or STORE[m.store], where .. " store " .. tostring(m.store))
			for k in pairs(m) do check(k == "name" or k == "body" or k == "icon" or k == "store", where .. " has field " .. tostring(k)) end
			check(not seen[m.name], where .. " repeats the name " .. tostring(m.name))
			seen[m.name or ""] = true
		end
	end
	-- the three macros of stage 1, exactly
	check(data.global and data.global.store == "account" and #data.global == 2, "global is not 2 account macros")
	check(data.warrior and data.warrior.store == "character" and #data.warrior == 1, "warrior is not 1 character macro")
	local g1, g2, w1 = data.global and data.global[1], data.global and data.global[2], data.warrior and data.warrior[1]
	check(g1 and g1.name == "Trinket 1" and g1.body == "#showtooltip\n/use 13", "Trinket 1 differs")
	check(g2 and g2.name == "Trinket 2" and g2.body == "#showtooltip\n/use 14", "Trinket 2 differs")
	check(w1 and w1.name == "Attack" and w1.body == "#showtooltip\n/startattack", "Attack differs")
	-- a fresh table on every call (nothing kept)
	check(M.PSS_MacroData() ~= data, "M.PSS_MacroData returned the same table twice")
end

function phases.global()
	needLibraries()
	reset()
	local out = pss("macro global create")
	expectLine(out, "Global macros: created 2 (Trinket 1 (account), Trinket 2 (account)).", "first create")
	local t1, t2 = macro("account", "Trinket 1"), macro("account", "Trinket 2")
	check(t1 and t1.body == "#showtooltip\n/use 13" and t1.icon == 134400, "Trinket 1 not as shipped")
	check(t2 and t2.body == "#showtooltip\n/use 14" and t2.icon == 134400, "Trinket 2 not as shipped")
	check(count("char") == 0, "a character macro was made")
	local n = #H.macroWrites
	out = pss("macro global create")
	expectLine(out, "already current 2", "second create")
	check(#H.macroWrites == n, "the second create wrote")
	check(count("account") == 2, "macros doubled")
	-- the alias
	out = pss("macros global")
	expectLine(out, "Trinket 1 (account): current", "/pss macros")
end

function phases.class()
	needLibraries()
	reset()
	local out = pss("macro warrior create")
	expectLine(out, "Warrior macros: created 1 (Attack (character)).", "warrior create")
	local a = macro("char", "Attack")
	check(a and a.body == "#showtooltip\n/startattack" and a.icon == 134400, "Attack not as shipped")
	check(count("account") == 0, "an account macro was made")
end

function phases.wrongclass()
	needLibraries()
	reset()
	local out = pss("macro warrior create")
	expectLine(out, "Warrior macros are for a Warrior: log in a Warrior to create them.", "create on a mage")
	out = pss("macro warrior")
	expectLine(out, "Warrior macros are for a Warrior", "preview on a mage")
	out = pss("macro rogue")
	expectLine(out, "There are no Rogue macros yet.", "class without a set")
	out = pss("macro foo create")
	expectLine(out, "No macro set \"foo\". Sets: global (2), warrior (1).", "unknown set")
	check(#H.macroWrites == 0, "something was written")
end

function phases.stores()
	needLibraries()
	-- macro over set over default, with a test set in place of the shipped one
	local real = M.PSS_MacroData
	M.PSS_MacroData = function()
		return {
			global = { store = "account",
				{ name = "G set", body = "/g1" },
				{ name = "G own", store = "character", body = "/g2" } },
			warrior = {
				{ name = "W default", body = "/w1" },
				{ name = "W own", store = "account", body = "/w2" } },
		}
	end
	reset()
	local out = pss("macro global")
	expectLine(out, "G set (account): new", "preview store, set")
	expectLine(out, "G own (character): new", "preview store, macro")
	pss("macro global create")
	pss("macro warrior create")
	check(macro("account", "G set") and not macro("char", "G set"), "G set not account (set store)")
	check(macro("char", "G own") and not macro("account", "G own"), "G own not character (macro store)")
	check(macro("char", "W default") and not macro("account", "W default"), "W default not character (default)")
	check(macro("account", "W own") and not macro("char", "W own"), "W own not account (macro store)")
	-- the command word puts the whole run in one store
	reset()
	out = pss("macro global create character")
	check(macro("char", "G set") and macro("char", "G own") and count("account") == 0, "create character")
	out = pss("macro warrior account")
	expectLine(out, "Warrior macros: all as account macros", "preview with a store word")
	pss("macro warrior create account")
	check(macro("account", "W default") and macro("account", "W own"), "create account")
	-- unknown words
	local n = #H.macroWrites
	out = pss("macro global create foo")
	expectLine(out, "\"foo\" is not a macro store: use account or character.", "bad store word")
	out = pss("macro global foo")
	expectLine(out, "\"foo\" is not a macro store", "bad word after the set")
	check(#H.macroWrites == n, "a bad word wrote")
	-- names are owned per store: an account G own is left as it was
	reset("a:G own=/mine")
	pss("macro global create")
	check(macro("account", "G own").body == "/mine", "the account macro of the same name was changed")
	check(macro("char", "G own") and macro("char", "G own").body == "/g2", "the character macro was not made")
	-- room per store: account full, character still written
	MAX_ACCOUNT_MACROS = 0
	reset()
	out = pss("macro global create")
	expectLine(out, "No room for 1 (G set (account))", "account full")
	expectLine(out, "created 1 (G own (character))", "character still created")
	MAX_ACCOUNT_MACROS = 120
	M.PSS_MacroData = real
end

function phases.existing()
	needLibraries()
	-- PSS_MACRO_SEED="a:Trinket 1=/say hi;a:Other=/dance;c:Trinket 2=/say char"
	local out = pss("macro global")
	expectLine(out, "Trinket 1 (account): update", "preview update")
	expectLine(out, "Trinket 2 (account): new", "preview new")
	out = pss("macro global create")
	expectLine(out, "created 1 (Trinket 2 (account))", "create")
	expectLine(out, "updated 1 (Trinket 1 (account))", "update")
	local t1 = macro("account", "Trinket 1")
	check(t1 and t1.body == "#showtooltip\n/use 13" and t1.icon == 134400, "Trinket 1 not set to PSS's")
	check(macro("account", "Other").body == "/dance", "Other was touched")
	check(macro("char", "Trinket 2").body == "/say char", "the character Trinket 2 was touched")
	check(count("account") == 3, "account has " .. count("account") .. " macros, wanted 3")
end

function phases.dynicon()
	needLibraries()
	reset()
	pss("macro global create")
	local n = #H.macroWrites
	local out = pss("macro global create")
	expectLine(out, "already current 2", "dynamic icon")
	check(#H.macroWrites == n, "the dynamic icon caused a write")
end

function phases.full()
	needLibraries()
	-- PSS_MACRO_MAX=1,18 or 2,18; PSS_MACRO_SEED="a:Keep=/x"
	local out = pss("macro global create")
	if MAX_ACCOUNT_MACROS == 1 then
		expectLine(out, "No room for 2 (Trinket 1 (account), Trinket 2 (account))", "no room")
		check(count("account") == 1, "a macro was made in a full store")
	else
		expectLine(out, "created 1 (Trinket 1 (account))", "room for one")
		expectLine(out, "No room for 1 (Trinket 2 (account))", "room for one")
	end
	check(macro("account", "Keep").body == "/x", "Keep was touched")
end

function phases.combat()
	needLibraries()
	reset()
	H.combat = true
	local out = pss("macro global create")
	expectLine(out, "Macros cannot be changed in combat.", "combat")
	check(#H.macroWrites == 0, "written in combat")
	out = pss("macro global")
	expectLine(out, "Trinket 1 (account): new", "preview in combat")
	H.combat = false
end

function phases.list()
	needLibraries()
	reset()
	local out = pss("macro")
	expectLine(out, "Macro sets: global (2), warrior (1). Free slots: account 120 of 120, character 18 of 18.", "sets")
	expectLine(out, "/pss macro <set> create", "usage")
	out = pss("macro global")
	expectLine(out, "Global macros:", "preview head")
	expectLine(out, "Trinket 2 (account): new", "preview row")
	check(#H.macroWrites == 0, "listing wrote")
	out = pss("help")
	expectLine(out, "macro: Create the preloaded macros", "help line")
end

function phases.noapi()
	needLibraries()
	local out = pss("macro global create")
	expectLine(out, "Macros are not available on this client.", "no API")
	out = pss("macro")
	expectLine(out, "Macros are not available on this client.", "no API, list")
end

function phases.retail()
	local out = pss("macro global create")
	expectLine(out, "The macro helper is for Camelot only.", "retail")
	check(M.PSS_MacroData == nil and M.PSS_MacroCommand == nil and M.PSS_MacroPlan == nil, "defined on Retail")
	check(#H.macroWrites == 0, "written on Retail")
end

function phases.login()
	check(not loaded("PourSocialScore_Libraries"), "Libraries loaded at login")
	check(M.PSS_MacroCommand == nil, "the macro helper is defined at login")
	for k in pairs(PourSocialScoreDB) do check(not tostring(k):lower():find("macro"), "saved key " .. tostring(k)) end
	check(#H.macroWrites == 0, "a macro was written at login")
end

function phases.memory()
	needLibraries()
	reset()
	-- only these five names are new on M; no new globals
	local NEW = { PSS_MacroData = true, PSS_MacroSets = true, PSS_MacroPlan = true, PSS_MacroCreate = true, PSS_MacroCommand = true }
	for k in pairs(M) do
		if tostring(k):find("Macro") then check(NEW[k], "unexpected M." .. tostring(k)) end
	end
	for k in pairs(NEW) do check(type(M[k]) == "function", "M." .. k .. " missing") end
	for k in pairs(_G) do
		if type(k) == "string" and k:find("PSS") and k:find("[Mm]acro") then check(false, "global " .. k) end
	end
	-- resident cost of the two files on this client (loaded again into a
	-- throwaway M, so the addon's own copy is not disturbed)
	local function cost(file)
		local saveNS = PourSocialScore_NS
		PourSocialScore_NS = { M = setmetatable({}, { __index = M }) }
		collectgarbage("collect")
		local before = collectgarbage("count")
		local keep = { assert(loadfile("PourSocialScore_Libraries/" .. file))() , PourSocialScore_NS }
		collectgarbage("collect")
		local kb = collectgarbage("count") - before
		PourSocialScore_NS = saveNS
		keep = nil
		return kb
	end
	cost("PSS_MacroData.lua")	-- the first measure grows Lua's string table; not counted
	local kd, kl = cost("PSS_MacroData.lua"), cost("PSS_Macros.lua")
	print(("MEASURE macro resident: PSS_MacroData.lua %.2f KB, PSS_Macros.lua %.2f KB"):format(kd, kl))
	check(kd + kl < 40, "resident cost over the 40 KB budget")
	-- garbage per command (GC stopped) and what is left after a full
	-- collect: nothing of ours (the stub's store and the chat lines aside)
	local cmds = { "macro", "macro global", "macro global create", "macro warrior create" }
	for _, cmd in ipairs(cmds) do -- each from an empty store
		pss(cmd)	-- warm: first-call string interning
		reset()
		collectgarbage("collect")
		local a = collectgarbage("count")
		collectgarbage("stop")
		pss(cmd)
		local b = collectgarbage("count")
		collectgarbage("restart")
		reset()
		said = nil
		collectgarbage("collect")
		local c = collectgarbage("count")
		print(("MEASURE macro %-24s garbage %.2f KB, kept %.2f KB"):format("/pss " .. cmd, b - a, c - a))
		check(b - a < 16, "/pss " .. cmd .. " made over 16 KB of garbage")
		check(c - a < 0.5, "/pss " .. cmd .. " kept " .. ("%.2f"):format(c - a) .. " KB after a full collect")
	end
end

local fn = phases[phase]
if not fn then
	print("FAIL macro: unknown phase " .. phase)
else
	local ok, err = pcall(fn)
	if not ok then print("FAIL macro: " .. phase .. ": error: " .. tostring(err)) fail = true end
	if not fail then print("PASS macro " .. phase) end
end
