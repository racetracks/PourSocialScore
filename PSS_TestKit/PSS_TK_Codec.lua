local _, TK = ...

-- TestKit import string reader (string-format.md sections 3 to 9). Pure Lua 5.1.
local byte, char, find, format, sub, gsub = string.byte, string.char, string.find, string.format, string.sub, string.gsub
local floor, concat = math.floor, table.concat
local type, tonumber, tostring, pairs, pcall, error, next = type, tonumber, tostring, pairs, pcall, error, next

local PREFIX = "!PSSTK1!"
local MAXLEN = 64000
local ISARR = setmetatable({}, { __mode = "k" })

-- base64 (standard alphabet, = padding)
local B64 = {}
do
	local a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, 64 do B64[byte(a, i)] = i - 1 end
end

local function b64decode(s)
	local n = #s
	if n % 4 ~= 0 then return nil end
	local out, o = {}, 0
	for i = 1, n, 4 do
		local c1, c2, c3, c4 = byte(s, i, i + 3)
		local v1, v2, v3, v4 = B64[c1], B64[c2], B64[c3], B64[c4]
		local last = (i + 3 == n)
		if not v1 or not v2 then return nil end
		if c3 == 61 then
			if not last or c4 ~= 61 then return nil end
			local v = v1 * 4 + floor(v2 / 16)
			o = o + 1
			out[o] = char(v)
		elseif c4 == 61 then
			if not last or not v3 then return nil end
			local v = v1 * 1024 + v2 * 16 + floor(v3 / 4)
			o = o + 1
			out[o] = char(floor(v / 256), v % 256)
		else
			if not v3 or not v4 then return nil end
			local v = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
			o = o + 1
			out[o] = char(floor(v / 65536), floor(v / 256) % 256, v % 256)
		end
	end
	return concat(out)
end

local function adler(s)
	local a, b = 1, 0
	for i = 1, #s do
		a = (a + byte(s, i)) % 65521
		b = (b + a) % 65521
	end
	return format("%04x%04x", b, a)
end

-- JSON subset reader. Errors are thrown as { pos = n }.
local function utf8char(cp)
	if cp < 128 then return char(cp) end
	if cp < 2048 then return char(192 + floor(cp / 64), 128 + cp % 64) end
	return char(224 + floor(cp / 4096), 128 + floor(cp / 64) % 64, 128 + cp % 64)
end

local ESC = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function parseJSON(s)
	local pos = 1
	local function fail(p) error({ pos = p or pos }, 0) end
	local function ws()
		pos = find(s, "[^ \t\r\n]", pos) or (#s + 1)
	end
	local value
	local function str()
		local out, o = {}, 0
		pos = pos + 1
		while true do
			local e = find(s, '["\\%c]', pos)
			if not e then fail(#s + 1) end
			if e > pos then o = o + 1; out[o] = sub(s, pos, e - 1) end
			local c = sub(s, e, e)
			if c == '"' then
				pos = e + 1
				return concat(out)
			elseif c == "\\" then
				local k = sub(s, e + 1, e + 1)
				if k == "u" then
					local h = sub(s, e + 2, e + 5)
					if not find(h, "^%x%x%x%x$") then fail(e) end
					local cp = tonumber(h, 16)
					if cp >= 55296 and cp <= 57343 then fail(e) end
					o = o + 1; out[o] = utf8char(cp)
					pos = e + 6
				elseif ESC[k] then
					o = o + 1; out[o] = ESC[k]
					pos = e + 2
				else
					fail(e)
				end
			else
				fail(e)
			end
		end
	end
	function value(depth)
		if depth > 32 then fail() end
		ws()
		local c = sub(s, pos, pos)
		if c == "{" then
			local t = {}
			pos = pos + 1
			ws()
			if sub(s, pos, pos) == "}" then pos = pos + 1; return t end
			while true do
				ws()
				if sub(s, pos, pos) ~= '"' then fail() end
				local k = str()
				ws()
				if sub(s, pos, pos) ~= ":" then fail() end
				pos = pos + 1
				t[k] = value(depth + 1)
				ws()
				local d = sub(s, pos, pos)
				pos = pos + 1
				if d == "}" then return t end
				if d ~= "," then fail(pos - 1) end
			end
		elseif c == "[" then
			local t, n = {}, 0
			ISARR[t] = true
			pos = pos + 1
			ws()
			if sub(s, pos, pos) == "]" then pos = pos + 1; return t end
			while true do
				n = n + 1
				t[n] = value(depth + 1)
				ws()
				local d = sub(s, pos, pos)
				pos = pos + 1
				if d == "]" then return t end
				if d ~= "," then fail(pos - 1) end
			end
		elseif c == '"' then
			return str()
		elseif sub(s, pos, pos + 3) == "true" then
			pos = pos + 4
			return true
		elseif sub(s, pos, pos + 4) == "false" then
			pos = pos + 5
			return false
		else
			local _, e = find(s, "^%-?%d+%.?%d*", pos)
			if not e then fail() end
			local txt = sub(s, pos, e)
			if find(txt, "%.$") or find(txt, "^%-?0%d") then fail() end
			pos = e + 1
			return tonumber(txt)
		end
	end
	local v = value(0)
	ws()
	if pos <= #s then fail() end
	return v
end

-- validation: v is a failure text or nil
local function isInt(v) return type(v) == "number" and v == floor(v) end
local function isArr(v) return type(v) == "table" and ISARR[v] == true end
local function isObj(v) return type(v) == "table" and not ISARR[v] end
local function isStr(v, lo, hi) return type(v) == "string" and #v >= lo and #v <= hi end

local function bad(path, rule) error({ bad = "field " .. path .. ": " .. rule }, 0) end
local function needStr(o, k, path, lo, hi)
	if not isStr(o[k], lo, hi) then bad(path .. "." .. k, "string of " .. lo .. " to " .. hi .. " characters") end
end
local function needInt(o, k, path, lo, hi, optional)
	local v = o[k]
	if v == nil and optional then return end
	if not isInt(v) or v < lo or v > hi then bad(path .. "." .. k, "integer " .. lo .. " to " .. hi) end
end
local function needArr(o, k, path, lo, hi, optional)
	local v = o[k]
	if v == nil and optional then return end
	if not isArr(v) or #v < lo or #v > hi then bad(path .. "." .. k, "array of " .. lo .. " to " .. hi) end
end
local function ident(o, k, path, lo, hi)
	local v = o[k]
	if not isStr(v, lo, hi) or not find(v, "^[a-z0-9_]+$") then bad(path .. "." .. k, "lowercase id of " .. lo .. " to " .. hi) end
end
local function scalar(v) local t = type(v); return t == "string" or t == "number" or t == "boolean" end

local function checkCmp(o, path, wantRequired)
	if o.cmp ~= nil and not isStr(o.cmp, 1, 20) then bad(path .. ".cmp", "string") end
	if o.cmp == "match" and not isStr(o.want, 1, 100) then bad(path .. ".want", "string of 1 to 100 characters") end
	if wantRequired and o.cmp ~= nil and o.want == nil then bad(path .. ".want", "required with cmp") end
end

local OPS = {}
OPS.call = function(o, p)
	needStr(o, "service", p, 1, 60)
	needArr(o, "cols", p, 0, 20, true)
	needArr(o, "rows", p, 0, 100, true)
	if o.col ~= nil and not isStr(o.col, 1, 40) then bad(p .. ".col", "string") end
	needInt(o, "row", p, 1, 1000, true)
	checkCmp(o, p, true)
end
OPS.api = function(o, p)
	needStr(o, "fn", p, 1, 60)
	needArr(o, "args", p, 0, 10, true)
	if o.args then
		for i = 1, #o.args do
			if not scalar(o.args[i]) then bad(p .. ".args[" .. i .. "]", "scalar") end
		end
	end
	needInt(o, "ret", p, 1, 20, true)
	checkCmp(o, p, true)
end
OPS.field = function(o, p)
	if not isStr(o.path, 1, 200) then bad(p .. ".path", "dotted path") end
	local n = 0
	for _ in o.path:gmatch("[^%.]+") do n = n + 1 end
	if n < 1 or n > 6 or find(o.path, "^%.") or find(o.path, "%.%.") or find(o.path, "%.$") then bad(p .. ".path", "1 to 6 parts") end
	checkCmp(o, p, true)
end
OPS.event = function(o, p)
	needStr(o, "name", p, 1, 60)
	needInt(o, "within", p, 1, 600, true)
end
OPS.cmd = function(o, p)
	if not isStr(o.line, 6, 200) or sub(o.line, 1, 5) ~= "/pss " then bad(p .. ".line", "starts with /pss ") end
	checkCmp(o, p, false)
end
OPS.frame = function(o, p)
	if not isStr(o.path, 1, 200) then bad(p .. ".path", "dotted path") end
	local ok = { shown = 1, point = 1, relativeTo = 1, width = 1, height = 1, text = 1, enabled = 1 }
	if not ok[o.prop] then bad(p .. ".prop", "shown, point, relativeTo, width, height, text or enabled") end
	checkCmp(o, p, true)
end
OPS.measure = function(o, p)
	needStr(o, "service", p, 1, 60)
	needArr(o, "cols", p, 0, 20, true)
	needArr(o, "rows", p, 0, 100, true)
	needInt(o, "runs", p, 1, 50, true)
	checkCmp(o, p, true)
end
OPS.load = function(o, p) needStr(o, "addon", p, 1, 60) end
OPS.unit = function(o, p)
	needStr(o, "service", p, 1, 60)
	needArr(o, "cols", p, 0, 20, true)
	needArr(o, "rows", p, 0, 100, true)
	if not isObj(o.want) then bad(p .. ".want", "object with cols and rows") end
end
OPS.manual = function(o, p) needStr(o, "prompt", p, 1, 200) end
OPS.print = function(o, p) needStr(o, "text", p, 1, 200) end
local CHOICE = { bool = 1, number = 1, text = 1, choice = 1 }
OPS.input = function(o, p)
	ident(o, "id", p, 1, 20)
	if not CHOICE[o.kind] then bad(p .. ".kind", "bool, number, text or choice") end
	needStr(o, "label", p, 1, 60)
	if o.kind == "choice" then
		needArr(o, "choices", p, 2, 6)
		for i = 1, #o.choices do
			if type(o.choices[i]) ~= "string" then bad(p .. ".choices[" .. i .. "]", "string") end
		end
	end
	if o.kind == "number" then
		if o.min ~= nil and type(o.min) ~= "number" then bad(p .. ".min", "number") end
		if o.max ~= nil and type(o.max) ~= "number" then bad(p .. ".max", "number") end
	end
	if o.required ~= nil and type(o.required) ~= "boolean" then bad(p .. ".required", "boolean") end
	checkCmp(o, p, false)
end
OPS.action = function(o, p)
	needStr(o, "label", p, 1, 30)
	local t = o["then"]
	if not isObj(t) then bad(p .. ".then", "one call, cmd or print op") end
	local n = t.op
	if n ~= "call" and n ~= "cmd" and n ~= "print" then bad(p .. ".then.op", "call, cmd or print") end
	OPS[n](t, p .. ".then")
end

local function checkOp(o, p)
	if not isObj(o) then bad(p, "object") end
	if not isStr(o.op, 1, 20) then bad(p .. ".op", "op name") end
	if o.op == "print" then bad(p .. ".op", "print only inside action") end
	local f = OPS[o.op]
	if f then f(o, p) end -- an unknown op decodes; the run marks it blocked
end

local function checkObjective(o, p)
	if not isObj(o) then bad(p, "object") end
	ident(o, "id", p, 1, 20)
	needStr(o, "text", p, 1, 80)
	local src = o.source
	if src ~= "event" and src ~= "bus" and src ~= "poll" then bad(p .. ".source", "event, bus or poll") end
	if src == "poll" then
		if not isStr(o.path, 1, 200) then bad(p .. ".path", "dotted path") end
		if not isStr(o.prop, 1, 20) then bad(p .. ".prop", "string") end
		checkCmp(o, p, true)
	else
		needStr(o, "name", p, 1, 60)
	end
	needArr(o, "arg", p, 0, 10, true)
	if o.arg then
		for i = 1, #o.arg do
			if not scalar(o.arg[i]) then bad(p .. ".arg[" .. i .. "]", "scalar") end
		end
	end
	needInt(o, "need", p, 1, 100, true)
end

local LOOKS = { modern = 1, classic = 1, dark = 1, any = 1 }
local FLAV = { retail = 1, forever = 1, tbc = 1 }

local function validate(env, N)
	if not isObj(env) then bad("envelope", "object") end
	if env.fmt ~= 1 then error({ bad = "unknown format " .. tostring(env.fmt) }, 0) end
	if not isInt(env.kitMin) or env.kitMin < 1 then bad("kitMin", "integer 1 or more") end
	if env.kitMin > N then
		error({ bad = "string needs kit TK." .. env.kitMin .. " (this is TK." .. N .. ")" }, 0)
	end
	if not isStr(env.build, 1, 30) or not find(env.build, "^%d+%.%d+%.%d+%.%d+$") then bad("build", "X.Y.Z.B") end
	local b, n = tostring(env.id):match("^(.*)%-(%d+)$")
	if not isStr(env.id, 1, 40) or b ~= env.build or tonumber(n) < 1 then bad("id", "<build>-<n>, n 1 or more") end
	needStr(env, "title", "", 1, 80)
	needArr(env, "flavours", "", 1, 3)
	local fl = {}
	for i = 1, #env.flavours do
		local f = env.flavours[i]
		if not FLAV[f] then bad("flavours[" .. i .. "]", "retail, forever or tbc") end
		fl[f] = true
	end
	needArr(env, "checks", "", 1, 100)
	local seen = {}
	for i = 1, #env.checks do
		local c, p = env.checks[i], "checks[" .. i .. "]"
		if not isObj(c) then bad(p, "object") end
		if not isStr(c.key, 1, 20) or not find(c.key, "^CHK%-%d%d%d%d%d$") then bad(p .. ".key", "CHK-NNNNN") end
		if not isStr(c.link, 9, 400) or sub(c.link, 1, 8) ~= "https://" then bad(p .. ".link", "starts with https://") end
		needStr(c, "title", p, 1, 80)
		if c.client ~= "any" and not (isStr(c.client, 1, 10) and fl[c.client]) then bad(p .. ".client", "a flavours value or any") end
		if not LOOKS[c.look] then bad(p .. ".look", "modern, classic, dark or any") end
		needStr(c, "do", p, 1, 400)
		needStr(c, "expect", p, 1, 400)
		local s = seen[c.key]
		if s and (s[c.client] or s.any or c.client == "any") then bad(p .. ".key", "duplicate") end
		s = s or {}
		s[c.client] = true
		seen[c.key] = s
		needArr(c, "steps", p, 1, 20)
		for j = 1, #c.steps do
			local st, sp = c.steps[j], p .. ".steps[" .. j .. "]"
			if not isObj(st) then bad(sp, "object") end
			if st.n ~= j then bad(sp .. ".n", "integer " .. j .. " (no gaps)") end
			needStr(st, "text", sp, 1, 300)
			checkOp(st.op, sp .. ".op")
		end
		needArr(c, "objectives", p, 0, 8, true)
		if c.objectives then
			local ids = {}
			for j = 1, #c.objectives do
				local op = p .. ".objectives[" .. j .. "]"
				checkObjective(c.objectives[j], op)
				local id = c.objectives[j].id
				if ids[id] then bad(op .. ".id", "duplicate") end
				ids[id] = true
			end
		end
		needArr(c, "inputs", p, 0, 6, true)
		if c.inputs then
			for j = 1, #c.inputs do
				local ip = p .. ".inputs[" .. j .. "]"
				if not isObj(c.inputs[j]) then bad(ip, "object") end
				OPS.input(c.inputs[j], ip)
			end
		end
	end
end

-- TK.Decode(text): env, or nil and the exact error text (string-format.md section 9).
function TK.Decode(text)
	if type(text) ~= "string" then return nil, "not a TestKit string" end
	text = gsub(text, "[ \t\r\n]", "")
	if sub(text, 1, #PREFIX) ~= PREFIX then return nil, "not a TestKit string" end
	if #text > MAXLEN then return nil, "string too long" end
	local body = sub(text, #PREFIX + 1)
	local b64, sum = body:match("^([^!]*)!(%x%x%x%x%x%x%x%x)$")
	if not b64 then return nil, "damaged string: base64" end
	local payload = b64decode(b64)
	if not payload then return nil, "damaged string: base64" end
	if adler(payload) ~= sum:lower() then return nil, "damaged string: checksum" end
	local ok, env = pcall(parseJSON, payload)
	if not ok then
		return nil, "damaged string: JSON at byte " .. ((type(env) == "table" and env.pos) or 1)
	end
	local ok2, err = pcall(validate, env, TK.N or 1)
	if not ok2 then
		if type(err) == "table" and err.bad then return nil, err.bad end
		return nil, "field envelope: unreadable"
	end
	return env
end
