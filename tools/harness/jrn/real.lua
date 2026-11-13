-- Real saves with the Journal off and on (build J1W; jrnrealoff, jrnrealon).
-- Parent (run by check_jrn.lua): for each save of this flavour under PSS_REAL_SAVES it starts run.lua again on the
-- save with PSS_JRN_REAL_CHILD=off|on, reads the written save back and compares it. Child: a login, nothing else.
local mode = os.getenv("PSS_JRN_REAL_CHILD")
local M = PourSocialScore_NS.M
local flv = M.PSS_FLV.flavour
local function gold(m)
	local me = M.PSS_Me(false)
	if m == "goldA" then
		M.PSS_OptSetBool({ key = "useJournal" }, true)
	elseif m == "goldB" then
		local sl = 1
		while H.bags[0] and H.bags[0][sl] do sl = sl + 1 end
		H.Put(0, sl, { id = 2592, count = 7 })
		H.Fire("BAG_UPDATE", 0)
		H.Fire("BAG_UPDATE_DELAYED")
		H.RunTimers()
		H.SetMoney(5012345)
		H.Fire("PLAYER_MONEY")
		H.RunTimers()
	else
		local said, n = {}, 0
		local realMsg = M.ShowMsg
		M.ShowMsg = function(t) said[#said + 1] = t end
		SlashCmdList["PSS"]("q index=whh st=whh.g")
		M.ShowMsg = realMsg
		for _, l in ipairs(said) do if not l:find("Spyglass: ", 1, true) and not l:find("^%d+ rows") then n = n + 1 end end
		print("GOLDQ " .. n)
	end
	print("CHILD done")
end
if mode and mode:find("^gold") then return gold(mode) end
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
-- jrnoffbytes: every real save byte-identical with the Journal off, against the J2 base (3.9.0.154, 48ec087)
local function plain(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
local function slurp(path)
	local f = io.open(path, "rb")
	if not f then return "" end
	local t = f:read("*a")
	f:close()
	return t
end
local function tocVersion(path) return slurp(path):match("## Version:%s*([^\r\n]+)") end
local function replAll(t, from, to)
	if not from or from == "" then return t end
	return (t:gsub(plain(from), (to:gsub("%%", "%%%%"))))
end
local function maskTimes(t)
	local o = {}
	for l in (t .. "\n"):gmatch("([^\n]*)\n") do
		if l:find("pss.upg", 1, true) then
			l = l:gsub("ms=%-?%d+%.?%d*", "ms=N")
			if l:find("\t", 1, true) then
				l = l:gsub("\t%-?%d+%.?%d*([\"]?,?)$", "\tN%1")
			end
		end
		o[#o + 1] = l
	end
	return table.concat(o, "\n")
end
local function firstDiff(x, y)
	local xs, ys = {}, {}
	for l in (x .. "\n"):gmatch("([^\n]*)\n") do xs[#xs + 1] = l end
	for l in (y .. "\n"):gmatch("([^\n]*)\n") do ys[#ys + 1] = l end
	for i = 1, math.max(#xs, #ys) do
		if xs[i] ~= ys[i] then return i end
	end
	return 0
end
local base = os.tmpname() .. ".j2base"
os.execute('mkdir -p "' .. base .. '" && git archive 48ec087 | tar -x -C "' .. base .. '"')
local vNew = tocVersion("PourSocialScore/PourSocialScore.toc")
local vOld = tocVersion(base .. "/PourSocialScore/PourSocialScore.toc")
for _, sv in ipairs(saves) do
	local fa, fb = os.tmpname(), os.tmpname()
	for i, src in ipairs({ ".", base }) do
		local cmd = ('env PSS_JRN_REAL_CHILD=off PSS_JRN=1 TZ=UTC PSS_FLAVOUR=%s PSS_COMPONENTS=logging,warehouse lua5.1 "%s/run.lua" "%s" "%s" "%s" "%s/check_jrn.lua" 2>&1'):format(flv, harness, src, sv, i == 1 and fa or fb, harness)
		local h = io.popen('PSS_JRN_AREA=real ' .. cmd)
		h:read("*a")
		h:close()
	end
	local ta = replAll(slurp(fa), vNew, "VERSION")
	local tb = replAll(slurp(fb), vOld, "VERSION")
	ta, tb = maskTimes(ta), maskTimes(tb)
	if ta == tb then
		print("PASS jrnoffbytes " .. sv)
	else
		bad = bad + 1; fail("jrnoffbytes " .. sv .. ": save bytes differ with the Journal off at line " .. firstDiff(ta, tb))
	end
	os.remove(fa); os.remove(fb)
end
os.execute('rm -rf "' .. base .. '"')
-- TST-01035 (Forever), TST-01036 (TBC): the gold chain on each save, Journal on (a login, a bag change and a money change, a login)
local rowKey = flv == "forever" and "TST-01035" or "TST-01036"
local function child(m, inn, outp)
	local cmd = ('env PSS_JRN_REAL_CHILD=%s PSS_WH_SEED=1 PSS_JRN=1 TZ=UTC PSS_FLAVOUR=%s PSS_COMPONENTS=logging,warehouse lua5.1 "%s/run.lua" . "%s" "%s" "%s/check_jrn.lua" 2>&1'):format(m, flv, harness, inn, outp, harness)
	local h = io.popen('PSS_JRN_AREA=real ' .. cmd)
	local txt = h:read("*a") or ""
	h:close()
	return txt
end
for _, sv in ipairs(saves) do
	if sv:find("/3.8.0.143-forever/", 1, true) or sv:find("/3.8.0.139-forever-launch/", 1, true) or sv:find("/tbc/3.8.0.143/", 1, true) then
	local a, b, c = os.tmpname(), os.tmpname(), os.tmpname()
	local t1, t2, t3 = child("goldA", sv, a), child("goldB", a, b), child("goldC", b, c)
	if t1:find("FAIL", 1, true) or t2:find("FAIL", 1, true) or t3:find("FAIL", 1, true) or not t3:find("CHILD done", 1, true) then
		bad = bad + 1; fail(rowKey .. " " .. sv .. ": the gold chain failed: " .. (t1 .. t2 .. t3):match("[^\n]*FAIL[^\n]*") )
	else
		local sa, sb = read(a), read(b)
		local g = tonumber(t3:match("GOLDQ (%d+)"))
		if not sa or not sb then
			bad = bad + 1; fail(rowKey .. " " .. sv .. ": unreadable save")
		elseif g ~= 2 then
			bad = bad + 1; fail(rowKey .. " " .. sv .. ": " .. tostring(g) .. " whh.g lines, expected 2 (sealed plus the login pending line)")
		elseif counters(sa) ~= counters(sb) then
			bad = bad + 1; fail(rowKey .. " " .. sv .. ": a counter changed")
		else
			local diff = {}
			local ia, ib = (sa.PSS_WarehouseDB or {}).inv or {}, (sb.PSS_WarehouseDB or {}).inv or {}
			for ent, row in pairs(ib) do
				for code, str in pairs(row) do if (ia[ent] or {})[code] ~= str then diff[#diff + 1] = ent .. ":" .. code end end
			end
			for ent, row in pairs(ia) do
				for code in pairs(row) do if (ib[ent] or {})[code] == nil then diff[#diff + 1] = ent .. ":" .. code end end
			end
			if #diff > 1 then bad = bad + 1; fail(rowKey .. " " .. sv .. ": containers changed: " .. table.concat(diff, " ")) end
		end
	end
	os.remove(a); os.remove(b); os.remove(c)
	end
end
os.remove(out)
if bad == 0 then print("PASS real " .. flv) end
