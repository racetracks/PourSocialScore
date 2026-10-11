------------------------------------------------------------------------
-- POUR SOCIAL SCORE - ENTITIES AND OWNED KEYS (service-bus-helper,
-- DDS-00010 section 11.5, SAV-00034, SAV-00035). Every saved variable is
-- account wide. Data a character owns is an account-wide record keyed by
-- that character's entity id, so nothing reads another character's slot
-- until an interface passes another id.
--   M.PSS_Me(create)                this character's id, or nil until something
--                                   is saved; create = true makes the row
--   M.PSS_EntityId(kind, name, realm, create)
--                                   the id of a character ("c"), guild ("g") or
--                                   the warband ("w"), or nil
--   M.PSS_Entity(id)                the row's fields as a record set
--   M.PSS_Owned(key)                o:Get(id), o:Set(id, value), o:Each(fn) for a
--                                   key in M.PSS_SCHEMA.owned (nil for another)
--   M.PSS_EntityRemove(id)          drops the row and every owned slot
--   M.PSS_EntityDrop()              releases the name index
-- The rows are PourSocialScoreDB.ent (a PSS_Store, routed to the Options
-- folder); an owned key is PourSocialScoreDB.<key>Of = { [id] = value }. A
-- default value and nil clear a slot, an empty key goes back to nil, an
-- unknown owned key or entity kind is kept untouched and never read. Nothing
-- runs at login and nothing is saved until a feature saves something owned.
-- Loaded with Libraries.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, pairs, next = type, pairs, next

local FIELDS = { "kind", "name", "realm", "faction", "class", "race", "sex" }
local ent = M.PSS_Store("ent", {
	key = "ent", v = 1, cap = 500,
	fields = { { "kind", "s" }, { "name", "s" }, { "realm", "s" }, { "faction", "s" }, { "class", "s" }, { "race", "s" }, { "sex", "n" }, { "flags", "s" } },
})
local KINDS = { c = true, g = true, w = true }

local me				-- this character's id, once per session
local byName			-- [kind .. ":" .. lower name] = id, built on first need

local function indexKey(kind, name, realm)
	local full = realm and realm ~= "" and (name .. "-" .. realm) or name
	return kind .. ":" .. full:lower()
end

local function index()
	if not byName then
		byName = {}
		ent.Each(function(id)
			local kind = ent.Get(id, "kind")
			if KINDS[kind] then byName[indexKey(kind, ent.Get(id, "name") or "", ent.Get(id, "realm"))] = id end
		end)
	end
	return byName
end

function M.PSS_EntityDrop() byName = nil; ent.Drop() end

-- a character is "Name" and "Realm" (the one name builder, with Camelot surnames)
local function split(name, realm, unit)
	local display = M.PSS_NormName(name, realm, unit)
	if not display then return nil end
	return display:match("^(.*)-([^-]*)$")
end

local function api(fn, ...)
	if type(fn) ~= "function" then return nil end
	local v = fn(...)
	if M.PSS_IsSecret and M.PSS_IsSecret(v) then return nil end
	return v
end

function M.PSS_EntityId(kind, name, realm, create, unit)
	if not KINDS[kind] or type(name) ~= "string" or name == "" then return nil end
	if M.PSS_IsSecret and (M.PSS_IsSecret(name) or M.PSS_IsSecret(realm)) then return nil end
	if kind == "c" then
		name, realm = split(name, realm, unit)
		if not name then return nil end
	elseif kind == "w" then
		realm = ""
	end
	local k = indexKey(kind, name, realm)
	local id = index()[k]
	if id or not create then return id end
	local rec = { kind = kind, name = name, realm = realm }
	if unit then
		rec.faction = api(UnitFactionGroup, unit)
		rec.class = select(2, UnitClass(unit))
		rec.race = select(2, UnitRace(unit))
		rec.sex = api(UnitSex, unit)
	end
	local new, why = ent.Add(rec)
	if not new then return nil, why end
	byName[k] = new
	return new
end

function M.PSS_Me(create)
	if me then return me end
	if not UnitName then return nil end
	local name, realm = UnitName("player")
	if type(name) ~= "string" or (M.PSS_IsSecret and M.PSS_IsSecret(name)) then return nil end
	local id = M.PSS_EntityId("c", name, realm, create, "player")
	me = id
	return id
end

local COLS = { "id", "kind", "name", "realm", "faction", "class", "race", "sex" }

function M.PSS_Entity(id)
	if not KINDS[ent.Get(id, "kind")] then return nil end
	return ent.Rows(FIELDS, { n = 1, { id } })
end

M.PSS_QueryDict("ent", { "name", "realm", "kind" }, function(id, dest, at)
	if KINDS[ent.Get(id, "kind")] then
		dest[at], dest[at + 1], dest[at + 2] = ent.Get(id, "name"), ent.Get(id, "realm"), ent.Get(id, "kind")
	end
end)

M.PSS_Provide("ent.get", function(input)
	local out = M.PSS_Set(COLS)
	for i = 1, input.n do
		local set = M.PSS_Entity(input[i][1])
		if set then M.PSS_SetAdd(out, set[1]) end
	end
	return out
end, { accepts = { "key" }, returns = COLS, doc = "an entity's fields by id" })

------------------------------------------------------------------------
-- Owned keys
------------------------------------------------------------------------
local ownedDefault			-- [key] = default (false when none), parsed from the schema on first need
local objects = {}

local function owned()
	if not ownedDefault then
		ownedDefault = {}
		for word in (M.PSS_SCHEMA and M.PSS_SCHEMA.owned or ""):gmatch("%S+") do
			local key, def = word:match("^([%a_][%w_]*)=?(.*)$")
			ownedDefault[key] = def ~= "" and def or false
		end
	end
	return ownedDefault
end

function M.PSS_Owned(key)
	local def = owned()[key]
	if def == nil then return nil end
	local o = objects[key]
	if o then return o end
	o = {}
	objects[key] = o
	function o:Get(id)
		local t = PourSocialScoreDB[key]
		return type(t) == "table" and t[id] or nil
	end
	function o:Set(id, value)
		if ent.ReadOnly() or not KINDS[ent.Get(id, "kind")] then return false end
		local t = PourSocialScoreDB[key]
		if value == nil or value == "" or value == def then
			if type(t) == "table" then
				t[id] = nil
				if next(t) == nil then PourSocialScoreDB[key] = nil end
			end
			return true
		end
		if type(t) ~= "table" then
			t = {}
			PourSocialScoreDB[key] = t
		end
		t[id] = value
		return true
	end
	function o:Each(fn)
		local t = PourSocialScoreDB[key]
		if type(t) == "table" then
			for id, v in pairs(t) do fn(id, v) end
		end
	end
	return o
end

function M.PSS_EntityRemove(id)
	if ent.ReadOnly() or not KINDS[ent.Get(id, "kind")] then return false end
	for key in pairs(owned()) do
		local t = PourSocialScoreDB[key]
		if type(t) == "table" then
			t[id] = nil
			if next(t) == nil then PourSocialScoreDB[key] = nil end
		end
	end
	ent.Delete(id)
	if byName then
		for k, v in pairs(byName) do if v == id then byName[k] = nil end end
	end
	if me == id then me = nil end
	return true
end
