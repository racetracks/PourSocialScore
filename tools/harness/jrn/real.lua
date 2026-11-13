-- Real saves with the Journal off and on (build J1W; jrnrealoff, jrnrealon).
-- Parent (run by check_jrn.lua): for each save of this flavour under PSS_REAL_SAVES it starts run.lua again on the
-- save with PSS_JRN_REAL_CHILD=off|on, reads the written save back and compares it. Child: a login, nothing else.
local mode = os.getenv("PSS_JRN_REAL_CHILD")
local M = PourSocialScore_NS.M
local flv = M.PSS_FLV.flavour
if mode then
	if mode == "on" then
		local realOn = M.PSS_On
		M.PSS_On = function(n) if n == "journal" then return true end return realOn(n) end
	end
	print("CHILD done")
	return
end
local function fail(w) print("FAIL jrn: real: " .. w) end
local dir = os.getenv("PSS_REAL_SAVES")
if flv == "retail" then
	print("SKIP jrn real: Retail has no Journal saves (DEC-00456)")
	print("PASS real retail")
	return
end
if not dir or dir == "" then
	print("SKIP jrn real: PSS_REAL_SAVES not set")
	print("PASS real " .. flv)
	return
end
local harness = (arg[0] or ""):match("^(.*)/[^/]*$") or "."

local function ser(v, seen)
	if type(v) ~= "table" then return type(v) == "string" and ("%q"):format(v) or tostring(v) end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local out = {}
	for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k]) end
	return "{" .. table.concat(out, ",") .. "}"
end
local function counters(env)
	local parts = { ser(env.PSS_CountsDB) }
	local db = env.PourSocialScoreDB or {}
	local keys = {}
	for k, v in pairs(db) do
		if type(k) == "string" and type(v) == "number" and (k:find("otal") or k:find("ext") or k:find("Id")) then keys[#keys + 1] = k end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. db[k] end
	return table.concat(parts, "|")
end
local function read(path)
	local env = {}
	local f, e = loadfile(path)
	if not f then return nil, e end
	setfenv(f, env)
	local ok, err = pcall(f)
	if not ok then return nil, err end
	return env
end
local function empty(T)
	if T == nil then return true end
	if type(T) ~= "table" then return false end
	return (type(T.open) ~= "table" or #T.open == 0) and (type(T.seg) ~= "table" or next(T.seg) == nil)
end

local p = io.popen('find -L "' .. dir .. '/' .. flv .. '" -name PourSocialScore.lua 2>/dev/null | sort')
local saves = {}
if p then for l in p:lines() do saves[#saves + 1] = l end p:close() end
if #saves == 0 then
	print("SKIP jrn real: no " .. flv .. " saves under " .. dir)
	print("PASS real " .. flv)
	return
end
local out = os.tmpname()
local bad = 0
for _, sv in ipairs(saves) do
	local ref		-- the counters after the Journal-off login: an old save migrates, so the source is compared only for a current one
	for _, m in ipairs({ "off", "on" }) do
		local cmd = ('env PSS_JRN_REAL_CHILD=%s PSS_JRN=1 TZ=UTC PSS_FLAVOUR=%s PSS_COMPONENTS=logging,warehouse lua5.1 "%s/run.lua" . "%s" "%s" "%s/check_jrn.lua" 2>&1'):format(m, flv, harness, sv, out, harness)
		local h = io.popen('PSS_JRN_AREA=real ' .. cmd)
		local txt = h:read("*a") or ""
		h:close()
		if txt:find("FAIL", 1, true) or not txt:find("CHILD done", 1, true) then
			bad = bad + 1; fail("jrnreal" .. m .. " " .. sv .. ": the login failed: " .. txt:sub(1, 200))
		else
			local a, b = read(sv), read(out)
			if not a or not b then
				bad = bad + 1; fail("jrnreal" .. m .. " " .. sv .. ": unreadable save")
			else
				local W = b.PSS_WarehouseDB
				local cb = counters(b)
				if m == "off" then ref = cb end
				if (m == "off" and sv:find("/3%.8%.", 1) and counters(a) ~= cb) or (m == "on" and cb ~= ref) then
					bad = bad + 1; fail("jrnreal" .. m .. " " .. sv .. ": a counter changed")
				elseif m == "off" and type(W) == "table" and (W.jrn ~= nil or W.whh ~= nil) then
					bad = bad + 1; fail("jrnrealoff " .. sv .. ": jrn or whh created with the Journal off")
				elseif m == "on" and type(W) == "table" and not (empty(W.jrn) and empty(W.whh)) then
					bad = bad + 1; fail("jrnrealon " .. sv .. ": jrn or whh not empty after a login")
				end
			end
		end
	end
end
os.remove(out)
if bad == 0 then print("PASS real " .. flv) end
