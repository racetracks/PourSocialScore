-- Entity ids and owned keys (service-bus-helper, stage S2; TST-00205; SAV-00034,
-- SAV-00035; expected results from DDS-00010 section 11.5, not from the code).
--   * nothing is saved, registered or built until a feature saves something owned
--   * one Set makes one ent row and one owned slot, in PSS_OptionsDB (routed)
--   * two characters keep separate slots
--   * a default value or nil clears a slot; an empty <key>Of goes back to nil
--   * M.PSS_EntityRemove drops the row and every owned slot
--   * an unknown owned key, an unknown entity kind and a newer layout are kept
--     untouched and not read
--   * a Camelot surname is the M.PSS_NormName form
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_owned.lua
--   PSS_CAMELOT=1 for the surname run
local fails = 0
local realPrint = print
local function eq(what, got, want)
	if got ~= want then realPrint(("  FAIL owned: %s: %s, expected %s"):format(what, tostring(got), tostring(want))); fails = fails + 1 end
end
local function ok(what, v) eq(what, v and true or false, true) end
local camelot = (os.getenv("PSS_FLAVOUR") == "forever" or os.getenv("PSS_CAMELOT") == "1")

-- the character name without its realm, as M.PSS_NormName builds it
local function short(name)
	return (M.PSS_NormName(name, nil, "player"):gsub("%-[^-]*$", ""))
end

local function keys(t)
	local n = {}
	for k in pairs(t) do n[#n + 1] = k end
	table.sort(n)
	return table.concat(n, ",")
end

-- nothing at login: the three files make no frame and register no event
ok("Libraries load", M.PSS_Need("Libraries"))
local frames, regs = 0, 0
local realCreate, realReg = CreateFrame, M.Events.Register
CreateFrame = function(...) frames = frames + 1 return realCreate(...) end
M.Events.Register = function(...) regs = regs + 1 return realReg(...) end
for _, f in ipairs({ "PSS_Store", "PSS_Query", "PSS_Entity" }) do
	ok(f .. " loads", loadfile("PourSocialScore_Libraries/" .. f .. ".lua"))
	loadfile("PourSocialScore_Libraries/" .. f .. ".lua")()
end
CreateFrame, M.Events.Register = realCreate, realReg
eq("frames made by the files", frames, 0)
eq("events registered by the files", regs, 0)

local o = M.PSS_Owned("bagProfileOf")
ok("bagProfileOf is an owned key", o)
local before = keys(PSS_OptionsDB)
eq("Me before anything is saved", M.PSS_Me(), nil)
eq("Get on an empty key", o:Get(1), nil)
eq("EntityId without create", M.PSS_EntityId("c", "Nobody", "Realm"), nil)
eq("Entity of an unknown id", M.PSS_Entity(99), nil)
eq("PSS_OptionsDB unchanged by reads", keys(PSS_OptionsDB), before)
eq("no ent key", PSS_OptionsDB.ent, nil)

-- one Set makes one ent row and one owned slot
local me = M.PSS_Me(true)
ok("Me(true) makes the row", me)
eq("Me is stable", M.PSS_Me(), me)
eq("the row is in PSS_OptionsDB (routed)", PSS_OptionsDB.ent ~= nil and rawget(PourSocialScoreDB, "ent") == nil, true)
ok("the owned Set", o:Set(me, "profile one"))
eq("the slot", o:Get(me), "profile one")
eq("the slot is in PSS_OptionsDB", PSS_OptionsDB.bagProfileOf and PSS_OptionsDB.bagProfileOf[me], "profile one")
local count = 0
for _ in pairs(PSS_OptionsDB.ent.rec) do count = count + 1 end
eq("one ent row", count, 1)
eq("the row packs the character", PSS_OptionsDB.ent.rec[me]:match("^c;[^;]+;[^;]*"), "c;" .. short("Tester") .. ";" .. M.PSS_NormName("Tester", nil, "player"):match("%-([^-]*)$"))
local e = M.PSS_Entity(me)
ok("Entity is a record set", M.PSS_IsSet(e))
eq("Entity kind", e[1][M.PSS_SetCol(e, "kind")], "c")
eq("EntityId finds the same row", M.PSS_EntityId("c", "Tester", GetRealmName()), me)
local svc = M.PSS_Call("ent.get", me)
ok("the ent.get service answers", svc and svc.n == 1)
local q = M.PSS_Query({ from = M.PSS_Set({ "ent", "count" }), })
ok("Query with no steps returns the set", q)
local owners = M.PSS_Set({ "ent", "count" })
M.PSS_SetAdd(owners, { me, 5 })
local joined = M.PSS_Query({ from = owners, join = { "ent" } })
eq("join reads the entity name", joined and joined[1][3], short("Tester"))

-- two characters (a second login in the stub) keep separate slots
local realUnitName = UnitName
UnitName = function(u) if u == "player" then return "Other", nil end return realUnitName(u) end
M.PSS_EntityDrop()
-- a new session: the file's upvalues are fresh
ok("the Entity file loads again", loadfile("PourSocialScore_Libraries/PSS_Entity.lua"))
loadfile("PourSocialScore_Libraries/PSS_Entity.lua")()
local me2 = M.PSS_Me(true)
ok("the second character has its own id", me2 and me2 ~= me)
local o2 = M.PSS_Owned("bagProfileOf")
o2:Set(me2, "profile two")
eq("second slot", o2:Get(me2), "profile two")
eq("first slot kept", o2:Get(me), "profile one")
UnitName = realUnitName

-- a default value or nil clears; an empty key goes back to nil
o2:Set(me2, nil)
eq("nil clears the slot", o2:Get(me2), nil)
eq("the other slot is kept", o2:Get(me), "profile one")
o2:Set(me, nil)
eq("an empty key is nil", PSS_OptionsDB.bagProfileOf, nil)
o2:Set(me, "x")
o2:Set(me2, "y")

-- unknown owned key and unknown entity kind are kept untouched and not read
eq("an unknown owned key is not served", M.PSS_Owned("zzOf"), nil)
PSS_OptionsDB.zzOf = { [me] = "newer" }
local rec = PSS_OptionsDB.ent.rec
rec[50] = "q;Future;Thing"
PSS_OptionsDB.ent.n = 50
M.PSS_EntityDrop()
eq("an unknown kind has no id", M.PSS_EntityId("q", "Future", "Thing"), nil)
eq("an unknown kind is not an entity", M.PSS_Entity(50), nil)
eq("EntityRemove refuses an unknown kind", M.PSS_EntityRemove(50), false)
eq("the unknown row is kept", rec[50], "q;Future;Thing")

-- remove drops the row and every owned slot (not the unknown key)
ok("EntityRemove", M.PSS_EntityRemove(me2))
eq("row gone", rec[me2], nil)
eq("slot gone", o2:Get(me2), nil)
eq("the other slot stays", o2:Get(me), "x")
eq("the unknown owned key is untouched", PSS_OptionsDB.zzOf[me], "newer")
local id3 = M.PSS_EntityId("g", "Some Guild", nil, true)
ok("a guild row", id3 and id3 > 50)
eq("ids are never reused", id3 ~= me2, true)

-- a newer layout is read only
PSS_OptionsDB.ent.v = 2
eq("newer layout: no new row", M.PSS_EntityId("g", "Another", nil, true), nil)
eq("newer layout: Set refused", o2:Set(me, "z"), false)
eq("newer layout: slot kept", o2:Get(me), "x")
PSS_OptionsDB.ent.v = 1

-- names go through M.PSS_NormName (Camelot surnames)
if camelot then
	local realRel = UnitRealmRelationship
	UnitRealmRelationship = function(u) if u == "target" then return 1 end end
	local realName = UnitName
	UnitName = function(u) if u == "target" then return "First Last", GetRealmName() end return realName(u) end
	local display = M.PSS_NormName("First Last", GetRealmName(), "target")
	local sid = M.PSS_EntityId("c", "First Last", GetRealmName(), true, "target")
	ok("a surname character", sid)
	local want = display:gsub("%-[^-]*$", "")
	eq("the surname form", M.PSS_Entity(sid)[1][3], want)
	UnitName, UnitRealmRelationship = realName, realRel
end

print = realPrint
if fails == 0 then print("PASS owned") end
