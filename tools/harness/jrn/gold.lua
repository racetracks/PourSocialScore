-- The Journal's gold and history phases on the real start chain (build J2G1; no stub of M.PSS_On, M.PSS_WhStartMore or
-- M.PSS_WatchStart): each phase is a chain of child runs (A prepares the save, B the body, C reads back); run.lua
-- fires PLAYER_LOGOUT at the end of each child, so a save is chained like a session. Q = SlashCmdList["PSS"]("q ...").
local pass = os.getenv("PSS_GOLD_CHILD")
local M = PourSocialScore_NS.M
local DAY = 86400
local function say(w) print("GOLDFAIL " .. w) end

-- helpers (child side)
local function Q(args)
	local said, n, hit = {}, 0, {}
	local realMsg = M.ShowMsg
	M.ShowMsg = function(s) said[#said + 1] = s end
	SlashCmdList["PSS"]("q " .. args)
	M.ShowMsg = realMsg
	for _, l in ipairs(said) do
		if not l:find("Spyglass: ", 1, true) and not l:find("^%d+ rows") then n = n + 1; hit[#hit + 1] = l end
	end
	return n, hit
end
local function money(v) H.SetMoney(v); H.Fire("PLAYER_MONEY"); H.RunTimers() end
local function bagPut(bag, id)
	local sl = 1
	while H.bags[bag] and H.bags[bag][sl] do sl = sl + 1 end
	H.Put(bag, sl, { id = id or 2592, count = 7 })
	H.Fire("BAG_UPDATE", bag)
end
local function settle() H.Fire("BAG_UPDATE_DELAYED"); H.RunTimers() end
local function errs(pat, msg)
	local rows, n = M.PSS_ErrRows(), 0
	for i = 1, rows.n do
		if rows[i][2] == pat and (not msg or tostring(rows[i][3]):find(msg)) then n = n + 1 end
	end
	return n
end
local function held(T)
	if type(T) ~= "table" then return 0 end
	local n = type(T.open) == "table" and #T.open or 0
	for _, s in pairs(type(T.seg) == "table" and T.seg or {}) do n = n + (tonumber(s:match("^[^;]*;[^;]*;(%d+);")) or 0) end
	return n
end
local function inv(me, code) local W = PSS_WarehouseDB; return W and W.inv and W.inv[me] and W.inv[me][code] end
-- A pass only: put lines into the stores of a session whose Journal option is not yet on
local function plant(f)
	local realOn = M.PSS_On
	M.PSS_On = function(n) if n == "journal" then return true end return realOn(n) end
	PSS_WarehouseDB = PSS_WarehouseDB or {}
	M.PSS_SetOpt("jrnMonths", "global", 0)
	f()
	M.PSS_SetOpt("jrnMonths", "global", 13)
	M.PSS_On = realOn
end
local function monthBack(k)
	local d = os.date("*t", GetServerTime())
	return os.time({ year = d.year, month = d.month - k, day = 15, hour = 12 })
end
local function journalOn() M.PSS_OptSetBool({ key = "useJournal" }, true) end

local P = {}
-- name = { passes, A = prep (default: option on), B = body, C = read back }
P.goldchain = { "ABC", B = function(me) money(GetMoney() + 12345) end,
	C = function(me)
		local n = Q("index=whh st=whh.g")
		local sealed = held(PSS_WarehouseDB and PSS_WarehouseDB.whh)
		if sealed ~= 1 or n ~= 2 then say("goldchain: " .. sealed .. " sealed, " .. n .. " visible") end
		if errs("wh.write") + errs("jrn.seal") > 0 then say("goldchain: error rows") end
	end }
P.goldvisible = { "AB", B = function(me)
	local v = GetMoney() + 12345
	money(v)
	local n, hit = Q("index=whh st=whh.g")
	local got
	M.PSS_Ix("whh"):scan({}, function(r) if r.st == "whh.g" then got = r.copper end end, { load = true })
	if n ~= 1 or got ~= v then say("goldvisible: " .. n .. " lines before logout, copper " .. tostring(got) .. " want " .. v) end
end }
P.goldhour = { "ABC", B = function(me)
	local t0 = math.floor(GetServerTime() / 3600) * 3600 + 10
	local v = GetMoney()
	H.SetTime(t0); money(v + 100)
	H.SetTime(t0 + 600); money(v + 200)
	H.SetTime(t0 + 3700); money(v + 300)
	H.Fire("PLAYER_LOGOUT")
	P.goldhour.v = v
end, C = function(me)
	local n, hit = Q("index=whh st=whh.g")
	local sealed = held(PSS_WarehouseDB and PSS_WarehouseDB.whh)
	if sealed ~= 2 or n ~= 3 then say("goldhour: " .. sealed .. " sealed, " .. n .. " visible") end
end }
P.histfault = { "AB", B = function(me)
	M.PSS_WhHistDelta = function() error("fgold") end
	local before = inv(me, "b0")
	bagPut(0); settle()
	if inv(me, "b0") == before then say("histfault: the container was not written") end
	if errs("wh.write", "^whh:") ~= 1 then say("histfault: expected 1 wh.write row starting whh:, got " .. errs("wh.write", "^whh:")) end
end }
P.histuncommitted = { "ABC", B = function(me)
	M.PSS_Test = M.PSS_Test or {}
	M.PSS_Test.buildFail = 2
	local before = inv(me, "b0")
	bagPut(0); bagPut(1); settle()
	M.PSS_Test.buildFail = nil
	if inv(me, "b0") ~= before then say("histuncommitted: the failed write changed b0") end
	if errs("wh.write") < 1 then say("histuncommitted: the write did not fail") end
end, C = function(me)
	local n = Q("index=whh st=whh.d")
	if n ~= 0 then say("histuncommitted: " .. n .. " whh.d lines of a write that failed") end
end }
P.sealout = { "AB", B = function(me)
	for i = 1, 3 do M.PSS_IxPut("jrn", "jrn.loot", { item = 2592, count = 1 }) end
	H.Fire("PLAYER_LOGOUT")
	local n = held(PSS_WarehouseDB and PSS_WarehouseDB.jrn)
	if n ~= 3 or #M.PSS_IxHot("jrn") ~= 0 then say("sealout: " .. n .. " lines held, " .. #M.PSS_IxHot("jrn") .. " hot") end
end }
P.sealin = { "AB", A = function(me)
	journalOn()
	plant(function()
		local old = GetServerTime() - 430 * DAY
		M.PSS_IxPut("jrn", "jrn.loot", { time = old, item = 2592, count = 1 }); M.PSS_IxFlush("jrn"); M.PSS_JrnStore:seal()
		M.PSS_IxPut("whh", "whh.d", { time = old, ent = me, item = 100, delta = 1, where = "a" }); M.PSS_IxFlush("whh"); M.PSS_WhHistStore:seal()
	end)
end, B = function(me)
	local W = PSS_WarehouseDB or {}
	local a, b = held(W.jrn), held(W.whh)
	if a ~= 0 or b ~= 0 then say("sealin: old lines held after login, jrn " .. a .. " whh " .. b) end
end }
P.sealmonths = { "AB", B = function(me)
	M.PSS_SetOpt("jrnMonths", "global", 0)
	for k = 3, 1, -1 do
		local t = monthBack(k)
		M.PSS_IxPut("jrn", "jrn.loot", { time = t, item = 2592, count = 1 }); M.PSS_IxFlush("jrn"); M.PSS_JrnStore:seal()
		M.PSS_IxPut("whh", "whh.d", { time = t, ent = me, item = 100, delta = 1, where = "a" }); M.PSS_IxFlush("whh"); M.PSS_WhHistStore:seal()
	end
	local W = PSS_WarehouseDB
	if held(W.jrn) ~= 3 or held(W.whh) ~= 3 then say("sealmonths: set-up holds " .. held(W.jrn) .. "/" .. held(W.whh)) end
	M.PSS_SetOpt("jrnMonths", "global", 1)
	if held(W.jrn) ~= 1 or held(W.whh) ~= 1 then say("sealmonths: jrn " .. held(W.jrn) .. " whh " .. held(W.whh) .. " held after the option, expected 1 each") end
end }
P.goldsynd = { "AB", env = true, B = function(me)
	if M.PSS_WhOn then say("goldsynd: PSS_WhOn is on") end
	if M.PSS_On("journal") or M.PSS_OnNow("journal") then say("goldsynd: the Journal is on") end
	if PSS_WarehouseDB and PSS_WarehouseDB.jrn ~= nil then say("goldsynd: PSS_WarehouseDB.jrn exists") end
	for _, id in ipairs({ "whh.net", "whh.logout", "jrn.loot" }) do
		if M.PSS_Triggers then local set = M.PSS_Triggers(); for i = 1, set.n do if set[i][1] == id then say("goldsynd: trigger " .. id) end end end
	end
end }
P.whhday = { "AB", B = function(me)
	local base = math.floor(GetServerTime() / DAY) * DAY + 3600
	H.SetTime(base)
	M.PSS_IxPut("whh", "whh.d", { time = base, ent = me, item = 100, delta = 5, where = "a" })
	M.PSS_IxPut("whh", "whh.d", { time = base + 60, ent = me, item = 100, delta = 3, where = "a" })
	M.PSS_IxPut("whh", "whh.d", { time = base + 120, ent = me, item = 200, delta = -2, where = "b" })
	M.PSS_IxPut("whh", "whh.g", { time = base + 130, ent = me, copper = 10 })
	M.PSS_IxPut("whh", "whh.g", { time = base + 7200, ent = me, copper = 20 })
	M.PSS_IxFlush("whh")
	H.SetTime(base + DAY)
	money(GetMoney() + 1)
	H.Fire("PLAYER_LOGOUT")
	local d, _ = Q("index=whh st=whh.d")
	local day = Q("index=whh st=whh.day")
	local old = 0
	M.PSS_Ix("whh"):scan({}, function(r) if r.st == "whh.g" and r.copper == 10 then old = old + 1 end end, { load = true })
	if old ~= 0 then say("whhday: the first g of the day was kept") end
end }
P.whhsettle = { "AB", B = function(me)
	bagPut(0); settle()
	local n = Q("index=whh st=whh.d")
	if n ~= 1 then say("whhsettle: " .. n .. " lines before logout, expected 1") end
end }
local ORDER = { "goldchain", "goldvisible", "goldhour", "histfault", "histuncommitted", "sealout", "sealin", "sealmonths", "goldsynd", "whhday", "whhsettle" }

if pass then
	local name, ps = pass:match("^(%w+):(%a)$")
	local ph = P[name]
	local me = M.PSS_Me(false)
	if ps == "A" then
		if ph.A then ph.A(me) else journalOn() end
	else
		ph[ps](me)
	end
	print("GOLDDONE")
	return
end

-- parent
local flv = M.PSS_FLV.flavour
if flv == "retail" and false then return end
local harness = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local tmp = os.tmpname()
for _, name in ipairs(ORDER) do
	local ph = P[name]
	local inn, why = "-", nil
	for i = 1, #ph[1] do
		local ps = ph[1]:sub(i, i)
		local out = tmp .. "." .. name .. i
		local envx = ph.env and ps == "B" and ('PSS_EXTRA_ADDONS="' .. harness .. '/fixtures/Syndicator" ') or ""
		local cmd = ('env %sPSS_GOLD_CHILD=%s:%s PSS_WH_SEED=1 PSS_JRN=1 TZ=UTC PSS_JRN_AREA=gold lua5.1 "%s/run.lua" . "%s" "%s" "%s/check_jrn.lua" 2>&1'):format(envx, name, ps, harness, inn, out, harness)
		local h = io.popen(cmd)
		local txt = h:read("*a") or ""
		h:close()
		local f = txt:match("GOLDFAIL ([^\n]*)")
		if not f and ph.env and ps == "B" and not txt:find(" The Journal is off with it.", 1, true) then f = "goldsynd: the login line does not end ' The Journal is off with it.'" end
		if f then why = f elseif txt:find("FAIL", 1, true) or not txt:find("GOLDDONE", 1, true) then why = name .. ": pass " .. ps .. ": " .. (txt:match("[^\n]*FAIL[^\n]*") or txt:sub(1, 200)) end
		if inn ~= "-" then os.remove(inn) end
		inn = out
		if why then break end
	end
	os.remove(inn)
	if why then print("FAIL jrn: gold: " .. why) else print("PASS gold " .. name .. " " .. flv) end
end
os.remove(tmp)
