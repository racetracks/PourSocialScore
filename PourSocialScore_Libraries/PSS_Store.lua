------------------------------------------------------------------------
-- POUR SOCIAL SCORE - KEY/VALUE STORES (service-bus-helper, DDS-00010
-- section 11.3, DEC-00193). A saved table as a data-driven store:
--   local S = M.PSS_Store(name, schema)
--   schema = { key = "ent", v = 1, cap = 500, fields = { { name, kind, default }, ... } }
-- kinds are rows: n number, s string, b boolean, d dictionary id (a string
-- that repeats is saved once). The saved table is PourSocialScoreDB[schema.key]
-- (routed to the Options folder): { v, n = last id, dn = last dictionary id,
-- rec = { [id] = "packed;fields" }, dict = { [id] = string } }.
--   S.Get(id, field)  S.Set(id, rec)  S.Add(rec) -> id  S.Delete(id)
--   S.Each(fn)  S.Count()  S.Rows(fields, ids) -> record set  S.Drop()
-- A default is never stored; trailing empty fields are dropped; ids are
-- never reused; a table of a newer layout (v above the schema's) and every
-- key the store does not know are kept untouched (PSS 02 section 3). Nothing
-- is written until the first Set or Add, nothing registers an event, and the
-- reverse dictionary index is built on the first dictionary write and
-- dropped by S.Drop(). Loaded with Libraries.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, tostring, tonumber, pairs = type, tostring, tonumber, pairs
local concat = table.concat

local SEP = ";"
local KINDS = {
	n = { pack = function(v) return v ~= nil and tostring(v) or "" end, unpack = function(s) return s ~= "" and tonumber(s) or nil end },
	s = { pack = function(v) return v ~= nil and (tostring(v):gsub("[;\n]", ",")) or "" end, unpack = function(s) return s ~= "" and s or nil end },
	b = { pack = function(v) return v and "1" or "" end, unpack = function(s) return s == "1" or nil end },
	d = { dict = true },
}

local stores = {}

function M.PSS_Store(name, schema)
	local S = stores[name]
	if S then return S end
	S = {}
	stores[name] = S
	local fields, idx = schema.fields, {}
	for i = 1, #fields do idx[fields[i][1]] = i end
	local rev, count		-- reverse dictionary index and record count, built on first need

	local function root(create)
		local db = PourSocialScoreDB
		if type(db) ~= "table" then return nil end
		local t = db[schema.key]
		if type(t) ~= "table" and create then
			t = { v = schema.v }
			db[schema.key] = t
		end
		return type(t) == "table" and t or nil
	end

	-- a table written by a newer layout is read as far as it goes, never changed
	function S.ReadOnly()
		local t = root()
		return t ~= nil and type(t.v) == "number" and t.v > schema.v
	end

	local function dictId(t, str)
		if str == nil then return "" end
		t.dict = t.dict or {}
		if not rev then
			rev = {}
			for id, s in pairs(t.dict) do rev[s] = id end
		end
		local id = rev[str]
		if not id then
			id = (t.dn or 0) + 1
			t.dn = id
			t.dict[id] = str
			rev[str] = id
		end
		return tostring(id)
	end

	local function pack(t, rec)
		local parts, last = {}, 0
		for i = 1, #fields do
			local f = fields[i]
			local v = rec[f[1]]
			if v == f[3] then v = nil end
			local k = KINDS[f[2]]
			local p = k.dict and dictId(t, v) or k.pack(v)
			parts[i] = p
			if p ~= "" then last = i end
		end
		return concat(parts, SEP, 1, last)
	end

	-- the pos-th field of a packed record
	local function cut(str, pos)
		local from = 1
		for _ = 2, pos do
			local at = str:find(SEP, from, true)
			if not at then return "" end
			from = at + 1
		end
		local to = str:find(SEP, from, true)
		return to and str:sub(from, to - 1) or str:sub(from)
	end

	local function value(t, str, pos)
		local f = fields[pos]
		local raw = cut(str, pos)
		local k = KINDS[f[2]]
		local v
		if k.dict then
			v = raw ~= "" and t.dict and t.dict[tonumber(raw)] or nil
		else
			v = k.unpack(raw)
		end
		if v == nil then v = f[3] end
		return v
	end

	-- O(1) by id: one table read, then only the asked field is cut out
	function S.Get(id, field)
		local t = root()
		local str = t and t.rec and t.rec[id]
		local pos = idx[field]
		if not str or not pos then return nil end
		return value(t, str, pos)
	end

	function S.Count()
		if not count then
			local t = root()
			count = 0
			if t and t.rec then for _ in pairs(t.rec) do count = count + 1 end end
		end
		return count
	end

	-- replaces (or adds, with an id above the last) the record; false, why when it did not
	function S.Set(id, rec)
		local t = root()
		if t and t.v and t.v > schema.v then return false, "newer layout kept" end
		local had = t and t.rec and t.rec[id]
		if not had and schema.cap and S.Count() >= schema.cap then return false, "cap" end
		t = root(true)
		t.rec = t.rec or {}
		t.rec[id] = pack(t, rec)
		if not had then
			count = S.Count() + 1
			if id > (t.n or 0) then t.n = id end
		end
		return true
	end

	-- a new record under the next id (ids are never reused)
	function S.Add(rec)
		local t = root()
		if t and t.v and t.v > schema.v then return nil, "newer layout kept" end
		local id = ((t and t.n) or 0) + 1
		local ok, why = S.Set(id, rec)
		if not ok then return nil, why end
		return id
	end

	function S.Delete(id)
		local t = root()
		if t and t.rec and t.rec[id] and not (t.v and t.v > schema.v) then
			t.rec[id] = nil
			if count then count = count - 1 end
			return true
		end
	end

	function S.Each(fn)
		local t = root()
		if t and t.rec then
			for id in pairs(t.rec) do fn(id) end
		end
	end

	-- a record set { "id", fields... } of the asked ids (a record set with the
	-- id in its first column) or of every record; it joins on "id"
	function S.Rows(names, ids)
		local out = { cols = { "id" }, n = 0 }
		for i = 1, #names do out.cols[i + 1] = names[i] end
		local t = root()
		if not (t and t.rec) then return out end
		local function add(id, str)
			local r = { id }
			for i = 1, #names do r[i + 1] = value(t, str, idx[names[i]]) end
			out.n = out.n + 1
			out[out.n] = r
		end
		if ids then
			for i = 1, ids.n do
				local id = ids[i][1]
				local s = t.rec[id]
				if s then add(id, s) end
			end
		else
			for id, s in pairs(t.rec) do add(id, s) end
		end
		return out
	end

	-- the runtime indexes are released (window closed, GC requested)
	function S.Drop() rev = nil; count = nil end
	return S
end
