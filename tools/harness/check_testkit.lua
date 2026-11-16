-- check_testkit.lua: offline checks of the PSS TestKit: TK-UT-01 to 15, 16, 18, 30.
-- Standalone: lua5.1 tools/harness/check_testkit.lua (from the repo root).
-- Each case runs this file again through run.lua on the shared stub, with
-- PSS_PHASE=<case>; the case code below runs after login (H and M exist).
local phase = os.getenv("PSS_PHASE")

if rawget(_G, "H") and phase then
	local calls, msgs = {}, {}
	C_AddOns.LoadAddOn("PourSocialScore_Libraries")
	local real = M.PSS_Call
	M.PSS_Call = function(name, ...)
		calls[#calls + 1] = name
		return real(name, ...)
	end
	local showMsg = M.ShowMsg
	M.ShowMsg = function(msg) msgs[#msgs + 1] = msg end
	local function stubLoad(why)
		local real = C_AddOns.LoadAddOn
		local f = function(name) if name == "PSS_TestKit" then return false, why end return real(name) end
		C_AddOns.LoadAddOn = f
		LoadAddOn = f
	end
	local L = PourSocialScore_NS.L
	local function kitCalls()
		local n = 0
		for _, c in ipairs(calls) do if c:match("^testkit%.") then n = n + 1 end end
		return n
	end
	local ok, why = true, nil
	if phase == "missing" then
		stubLoad("MISSING")
		SlashCmdList["PSS"]("test")
		ok = #msgs == 1 and msgs[1] == L["TEST_1"] and kitCalls() == 0
		why = "msgs=" .. #msgs .. " first=" .. tostring(msgs[1])
	elseif phase == "disabled" then
		stubLoad("DISABLED")
		SlashCmdList["PSS"]("test")
		ok = #msgs == 1 and msgs[1] == L["TEST_2"] and kitCalls() == 0
		why = "msgs=" .. #msgs .. " first=" .. tostring(msgs[1])
	elseif phase == "loadable" then
		SlashCmdList["PSS"]("test")
		local opens, first, other = 0, nil, true
		for _, c in ipairs(calls) do
			if c:match("^testkit%.") then
				first = first or c
				if c == "testkit.open" then opens = opens + 1 elseif c ~= "testkit.runs" and c ~= "testkit.checks" then other = false end
			end
		end
		ok = opens == 1 and first == "testkit.open" and other and #msgs == 0 and C_AddOns.IsAddOnLoaded("PSS_TestKit")
		why = "kitCalls=" .. kitCalls() .. " msgs=" .. #msgs .. " first=" .. tostring(msgs[1])
	elseif phase:match("^ut") then
			C_AddOns.LoadAddOn("PSS_TestKit")
			local function slurp(p) local h = assert(io.open(p, "rb")) local t = h:read("*a") h:close() return t end
			local exTxt = slurp("tools/testkit/fixtures/example.txt"):gsub("%s", "")
			local exJson = slurp("tools/testkit/fixtures/example.json"):gsub("%s+$", "")
			local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
			local function b64(s)
				local o = {}
				for i = 1, #s, 3 do
					local a, b, c = s:byte(i, i + 2)
					local n = a * 65536 + (b or 0) * 256 + (c or 0)
					local d1, d2, d3, d4 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
					o[#o + 1] = B64:sub(d1 + 1, d1 + 1) .. B64:sub(d2 + 1, d2 + 1) .. (b and B64:sub(d3 + 1, d3 + 1) or "=") .. (c and B64:sub(d4 + 1, d4 + 1) or "=")
				end
				return table.concat(o)
			end
			local function unb64(s)
				local o, bits, nb = {}, 0, 0
				for ch in s:gsub("=", ""):gmatch(".") do
					bits = bits * 64 + (B64:find(ch, 1, true) - 1)
					nb = nb + 6
					if nb >= 8 then
						nb = nb - 8
						local d = 2 ^ nb
						o[#o + 1] = string.char(math.floor(bits / d))
						bits = bits % d
					end
				end
				return table.concat(o)
			end
			local function adler(s)
				local a, b = 1, 0
				for i = 1, #s do a = (a + s:byte(i)) % 65521; b = (b + a) % 65521 end
				return string.format("%04x%04x", b, a)
			end
			local function enc(payload) return "!PSSTK1!" .. b64(payload) .. "!" .. adler(payload) end
			local function plain(from, to)
				local i, j = exJson:find(from, 1, true)
				assert(i, "fixture lacks " .. from)
				return exJson:sub(1, i - 1) .. to .. exJson:sub(j + 1)
			end
			local function imp(text) return M.PSS_Call("testkit.import", { text = text }) end
			local function row(set) return set and set[1] end
			local function runCount() local n = 0 for _ in pairs(PSS_TestKitDB and PSS_TestKitDB.runs or {}) do n = n + 1 end return n end
			local function privTK()
				local TK = { N = 1, CAP = { m = 20, got = 200 } }
				for _, f in ipairs({ "PSS_TK_Allow", "PSS_TK_Run" }) do assert(loadfile("PSS_TestKit/" .. f .. ".lua"))("PSS_TestKit", TK) end
				return TK
			end
			local function stubSvc()
				local w = 0
				M.PSS_Provide("tkt.rows", function() return { cols = { "a", "b" }, n = 2, { 1, "x" }, { 2, "y" } } end,
					{ returns = { "a", "b" }, doc = "t", cost = "O(1)", writes = false, onError = "empty" })
				M.PSS_Provide("tkt.w", function() w = w + 1 return { cols = { "a" }, n = 1, { 1 } } end,
					{ returns = { "a" }, doc = "t", cost = "O(1)", writes = true, onError = "empty" })
				return function() return w end
			end
			local function json(v)
				local t = type(v)
				if t == "table" then
					local o = {}
					if next(v) == nil or v[1] ~= nil then
						for i = 1, #v do o[i] = json(v[i]) end
						return "[" .. table.concat(o, ",") .. "]"
					end
					for k, x in pairs(v) do o[#o + 1] = json(k) .. ":" .. json(x) end
					return "{" .. table.concat(o, ",") .. "}"
				elseif t == "string" then return '"' .. v:gsub('[\\"]', "\\%0") .. '"'
				end
				return tostring(v)
			end
			local function snap(v, seen)
				if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
				seen = seen or {}
				if seen[v] then return "cycle" end
				seen[v] = true
				local ks = {}
				for k in pairs(v) do ks[#ks + 1] = k end
				table.sort(ks, function(a, b) return type(a) .. tostring(a) < type(b) .. tostring(b) end)
				local o = {}
				for _, k in ipairs(ks) do o[#o + 1] = type(k) .. tostring(k) .. "=" .. snap(v[k], seen) end
				seen[v] = nil
				return "{" .. table.concat(o, ";") .. "}"
			end
			local DBS = { "PourSocialScoreDB", "PSS_LoggingDB", "PSS_OptionsDB", "PSS_PlayersDB", "PSS_GuildsDB", "PSS_RulesDB", "PSS_CountsDB", "PSS_WarehouseDB", "PSS_CharDB" }
			local function snapAll()
				local o = {}
				for i, n in ipairs(DBS) do o[i] = snap(rawget(_G, n)) end
				return o
			end
			-- TK-UT-08: every op of string-format.md section 6; returns the names that failed
			local function runOps(TK)
				local bad = {}
				local function chk(name, c) if not c then bad[#bad + 1] = name end end
				local function ex(op, ctx) return TK.Exec(op, ctx or {}) end
				local r = ex({ op = "call", service = "tkt.rows", col = "b", row = 2, cmp = "eq", want = "y" })
				chk("call cell", r.ok and r.got == "y")
				r = ex({ op = "call", service = "tkt.rows", col = "#", cmp = "eq", want = 2 })
				chk("call count", r.ok)
				r = ex({ op = "call", service = "tkt.w", col = "a" })
				chk("call writer auto", r.status == "not_complete")
				r = ex({ op = "call", service = "tkt.w", col = "a" }, { action = true })
				chk("call writer action", r.status == "other" and r.sub == "blocked" and r.why == "writing service not allowed: tkt.w")
				r = ex({ op = "api", fn = "GetBuildInfo", ret = 4, cmp = "eq", want = select(4, GetBuildInfo()) })
				chk("api", r.ok)
				r = ex({ op = "api", fn = "RunScript", args = { "x=1" } })
				chk("api RunScript", r.status == "other" and r.sub == "blocked" and r.why == "api not allowed: RunScript")
				_G.PSS_TKF = { a = { b = 7 } }
				r = ex({ op = "field", path = "PSS_TKF.a.b", cmp = "eq", want = 7 })
				chk("field", r.ok)
				r = ex({ op = "field", path = "PSS_TKF.a.zz", cmp = "ne", want = 7 })
				chk("field missing", r.ok)
				local ev = { op = "event", name = "PSS_TK_EVT", within = 5 }
				r = ex(ev, { id = "r", key = "k", n = 2 })
				chk("event no wait", r.status == "not_complete")
				TK.Select("r", "k", { steps = { { op = ev } } })
				r = ex(ev, { id = "r", key = "k", n = 1 })
				chk("event waiting", r.status == "not_complete")
				H.Advance(10)
				r = ex(ev, { id = "r", key = "k", n = 1 })
				chk("event expired", r.ok == false and r.why == "not seen in 5 s")
				r = ex({ op = "cmd", line = "/pss version" })
				chk("cmd outside action", r.status == "not_complete")
				r = ex({ op = "cmd", line = "/pss version" }, { action = true })
				chk("cmd action", r.ok and #r.got > 0)
				r = ex({ op = "cmd", line = "/pss prune 1" }, { action = true })
				chk("cmd prune", r.status == "other" and r.sub == "blocked" and r.why == "command not allowed: prune")
				_G.PSS_TKFR = { IsShown = function() return true end }
				r = ex({ op = "frame", path = "PSS_TKFR", prop = "shown", cmp = "eq", want = true })
				chk("frame", r.ok)
				local m = {}
				r = ex({ op = "measure", service = "tkt.rows", cols = { "a" }, runs = 3, cmp = "ge", want = 0 }, { m = m })
				chk("measure", r.ok and #m == 1)
				r = ex({ op = "load", addon = "PSS_TestKit" })
				chk("load", r.ok)
				r = ex({ op = "load", addon = "PSS_NoSuchAddon" })
				chk("load missing", r.ok == false and r.why == "not loaded")
				r = ex({ op = "unit", service = "tkt.rows", cols = { "a" }, want = { cols = { "a", "b" }, rows = { { 1, "x" }, { 2, "y" } } } })
				chk("unit", r.ok)
				r = ex({ op = "unit", service = "tkt.rows", cols = { "a" }, want = { cols = { "a" } } })
				chk("unit differs", r.ok == false and r.why == "cols differ")
				r = ex({ op = "manual", prompt = "p" })
				chk("manual", r.status == "not_complete")
				r = ex({ op = "input", id = "i", kind = "text", label = "l" })
				chk("input none", r.status == "not_complete")
				r = ex({ op = "input", id = "i", kind = "text", label = "l" }, { value = "v" })
				chk("input value", r.ok and r.got == "v")
				r = ex({ op = "input", id = "i", kind = "text", label = "l", required = false })
				chk("input optional", r.ok)
				r = ex({ op = "action", label = "a", ["then"] = { op = "cmd", line = "/pss version" } })
				chk("action outside", r.status == "not_complete")
				r = ex({ op = "action", label = "a", ["then"] = { op = "cmd", line = "/pss version" } }, { action = true })
				chk("action cmd", r.ok)
				r = ex({ op = "action", label = "a", ["then"] = { op = "print", text = "hello" } }, { action = true })
				chk("action print", r.ok)
				r = ex({ op = "action", label = "a", ["then"] = { op = "unit" } }, { action = true })
				chk("action bad inner", r.status == "other" and r.why == "unknown op unit")
				r = ex({ op = "print", text = "x" })
				chk("print outside", r.status == "other" and r.why == "unknown op print")
				r = ex({ op = "zzz" })
				chk("unknown op", r.status == "other" and r.sub == "blocked" and r.why == "unknown op zzz")
				return bad
			end
			if phase ~= "ut14d" then PSS_TestKitDB = nil end
			if phase == "ut01" then
				local r = row(imp(exTxt))
				local run = PSS_TestKitDB.runs["3.9.0.162-1"]
				ok = r and r[1] == "3.9.0.162-1" and r[2] == "3.9.0.162" and r[3] == 3 and r[4] == "" and run ~= nil
					and run.src == exTxt and unb64(run.src:match("^!PSSTK1!(.-)!")) == exJson
				why = "row=" .. tostring(r and r[1]) .. "," .. tostring(r and r[3]) .. " err=" .. tostring(r and r[4])
			elseif phase == "ut02" then
				local r = row(imp(exTxt:sub(1, -2) .. (exTxt:sub(-1) == "0" and "1" or "0")))
				ok = r and r[1] == "" and r[4] == "damaged string: checksum" and runCount() == 0
				why = "err=" .. tostring(r and r[4])
			elseif phase == "ut03" then
				local r = row(imp("PSSTK1!abc"))
				ok = r and r[4] == "not a TestKit string" and runCount() == 0
				why = "err=" .. tostring(r and r[4])
			elseif phase == "ut04" then
				local r = row(imp(enc(plain('"kitMin":1', '"kitMin":99'))))
				ok = r and r[4] == "string needs kit TK.99 (this is TK.1)" and runCount() == 0
				why = "err=" .. tostring(r and r[4])
			elseif phase == "ut05" then
				local r = row(imp(enc(plain('"key":"CHK-00226"', '"key":"CHK-1"'))))
				ok = r and r[4] == "field checks[1].key: bad key" and runCount() == 0
				why = "err=" .. tostring(r and r[4])
			elseif phase == "ut06" then
				local parts = {}
				for i = 1, #exTxt, 60 do parts[#parts + 1] = exTxt:sub(i, i + 59) end
				local r = row(imp(" " .. table.concat(parts, "\n ")))
				ok = r and r[1] == "3.9.0.162-1" and r[2] == "3.9.0.162" and r[3] == 3 and r[4] == ""
					and PSS_TestKitDB.runs["3.9.0.162-1"].src == exTxt
				why = "row=" .. tostring(r and r[1]) .. " err=" .. tostring(r and r[4])
			elseif phase == "ut12" then
				imp(exTxt)
				local run = PSS_TestKitDB.runs["3.9.0.162-1"]
				run.checks["CHK-00226@tbc"] = run.checks["CHK-00226@tbc"] or {}
				run.checks["CHK-00226@tbc"].auto = { s = "complete", at = 1 }
				M.PSS_Call("testkit.mark", { id = "3.9.0.162-1", key = "CHK-00226@tbc", status = "failed", reason = "x" })
				local ck = run.checks["CHK-00226@tbc"]
				ok = ck.s == "other" and ck.sub == "failed" and ck.why == "x" and ck.man and ck.man.s == "other" and ck.auto and ck.auto.s == "complete"
				why = "s=" .. tostring(ck.s) .. " sub=" .. tostring(ck.sub) .. " auto=" .. tostring(ck.auto and ck.auto.s)
			elseif phase == "ut13" then
				local n = 0
				for i = 1, 6 do
					local r = row(imp(enc(plain('"id":"3.9.0.162-1"', '"id":"3.9.0.162-' .. i .. '"'))))
					if r and r[4] == "" then n = n + 1 end
				end
				M.PSS_Call("testkit.note", { id = "3.9.0.162-6", key = "CHK-00226", text = string.rep("n", 600) })
				local ck = PSS_TestKitDB.runs["3.9.0.162-6"] and PSS_TestKitDB.runs["3.9.0.162-6"].checks["CHK-00226@tbc"]
				local note = ck and ck.notes and ck.notes[""] or ""
				ok = n == 6 and runCount() == 5 and PSS_TestKitDB.runs["3.9.0.162-1"] == nil and #PSS_TestKitDB.order == 5 and #note == 500
				why = "imported=" .. n .. " runs=" .. runCount() .. " note=" .. #note
			elseif phase == "ut14a" then
				PSS_TestKitDB = { v = 1, order = {}, runs = {}, zz = "keep" }
				imp(exTxt)
				ok = PSS_TestKitDB.zz == "keep" and PSS_TestKitDB.runs["3.9.0.162-1"] ~= nil
				why = "zz=" .. tostring(PSS_TestKitDB.zz)
			elseif phase == "ut14c" then
				local r = row(imp(exTxt))
				local a = M.PSS_Call("testkit.input", { id = "3.9.0.162-1", key = "CHK-00265", field = "rows", value = 7 })
				local b = M.PSS_Call("testkit.note", { id = "3.9.0.162-1", key = "CHK-00265.s2", text = "reload note" })
				ok = r and r[4] == "" and a ~= nil and b ~= nil
				why = "imp=" .. tostring(r and r[4]) .. " in=" .. tostring(a) .. " note=" .. tostring(b)
			elseif phase == "ut14d" then
				local ck = PSS_TestKitDB and PSS_TestKitDB.runs and PSS_TestKitDB.runs["3.9.0.162-1"] and PSS_TestKitDB.runs["3.9.0.162-1"].checks["CHK-00265@forever"]
				ok = ck ~= nil and ck.inputs and ck.inputs.rows == 7 and ck.notes and ck.notes.s2 == "reload note"
				why = "ck=" .. tostring(ck) .. " rows=" .. tostring(ck and ck.inputs and ck.inputs.rows) .. " note=" .. tostring(ck and ck.notes and ck.notes.s2)
			elseif phase == "ut14b" then
				PSS_TestKitDB = { v = 2, order = {}, runs = {} }
				local r = row(imp(exTxt))
				local told = false
				for _, m in ipairs(msgs) do if m == "PSS_TestKitDB is from a newer kit; results are read-only." then told = true end end
				ok = told and runCount() == 0 and PSS_TestKitDB.v == 2 and not (r and r[1] == "3.9.0.162-1")
				why = "told=" .. tostring(told) .. " runs=" .. runCount()
			elseif phase == "ut15" then
				imp(exTxt)
				local before = #msgs
				local r = row(imp(exTxt))
				ok = runCount() == 1 and #PSS_TestKitDB.order == 1 and r and r[1] == "3.9.0.162-1" and msgs[before + 1] == "already imported: 3.9.0.162-1"
				why = "runs=" .. runCount() .. " msg=" .. tostring(msgs[before + 1])
			elseif phase == "ut30" then
				local sTxt = slurp("tools/testkit/fixtures/selftest.txt"):gsub("%s", "")
				local other = enc((exJson:gsub('"build":"3.9.0.162"', '"build":"3.9.0.156"'):gsub('"id":"3.9.0.162%-1"', '"id":"3.9.0.156-1"')))
				local r0 = row(imp(other))
				local r = row(imp(exTxt))
				local n1 = runCount()
				M.PSS_FLV = M.PSS_FLV or {}
				M.PSS_FLV.flavour = "forever"
				local r2 = row(imp(sTxt))
				local run = PSS_TestKitDB.runs["3.9.0.162-99"]
				local ck = run and run.checks["CHK-00263@forever"]
				ok = r and r[1] == "3.9.0.162-1" and r[4] == "" and n1 == 2 and run ~= nil and ck ~= nil and ck.s == "complete"
				why = "seed=" .. tostring(r0 and r0[4]) .. " row=" .. tostring(r and r[1]) .. " runs=" .. n1 .. " self=" .. tostring(r2 and r2[4]) .. " s=" .. tostring(ck and ck.s) .. " keys=" .. (function() local t = {} for k, v in pairs(run and run.checks or {}) do t[#t + 1] = k .. ":" .. tostring(v.s) end return table.concat(t, ",") end)()
			elseif phase == "ut07" then
				local TK = privTK()
				local C = {
					{ "eq", 5, 5, true }, { "eq", 5, 6, false, "got 5" }, { "eq", { 1, { 2 } }, { 1, { 2 } }, true },
					{ "ne", 5, 6, true }, { "ne", 5, 5, false, "got 5" },
					{ "lt", 1, 2, true }, { "lt", 3, 2, false, "got 3" }, { "lt", "abc", 2, false, "not a number" },
					{ "le", 2, 2, true }, { "le", 3, 2, false, "got 3" },
					{ "gt", 3, 2, true }, { "gt", 1, 2, false, "got 1" },
					{ "ge", 2, 2, true }, { "ge", 1, 2, false, "got 1" },
					{ "match", "hello", "ell", true }, { "match", "hello", "zzz", false, "got hello" },
					{ "type", "x", "string", true }, { "type", 5, "string", false, "got number" },
					{ "len", "abc", 3, true }, { "len", { 1, 2 }, 2, true }, { "len", "abc", 4, false, "got 3" }, { "len", 5, 1, false, "no length" },
					{ "has", { "a", "b" }, "b", true }, { "has", { "a" }, "b", false, "not found" },
					{ "has", "hello", "ell", true }, { "has", "hello", "zz", false, "not found" }, { "has", 5, "x", false, "not a table or string" },
				}
				local bad = {}
				for i, c in ipairs(C) do
					_G.PSS_TKV = c[2]
					local r = TK.Exec({ op = "field", path = "PSS_TKV", cmp = c[1], want = c[3] }, {})
					if (r.ok == true) ~= c[4] or (not c[4] and r.why ~= c[5]) then bad[#bad + 1] = c[1] .. "#" .. i .. " " .. tostring(r.ok) .. " " .. tostring(r.why) end
				end
				local u = TK.Exec({ op = "field", path = "PSS_TKV", cmp = "zzz", want = 1 }, {})
				if not (u.status == "other" and u.sub == "blocked" and u.why == "unknown cmp zzz") then bad[#bad + 1] = "unknown cmp" end
				ok = #bad == 0
				why = table.concat(bad, "; ")
			elseif phase == "ut08" then
				M.ShowMsg = showMsg
				stubSvc()
				local bad = runOps(privTK())
				ok = #bad == 0
				why = table.concat(bad, "; ")
			elseif phase == "ut09" then
				M.ShowMsg = showMsg
				local wcalls = stubSvc()
				local function chk(key, steps) return { client = "any", ["do"] = "d", expect = "e", key = key, link = "https://x", look = "any", steps = steps, title = "t" } end
				local env = { build = "3.9.0.156", checks = {
					chk("CHK-00001", { { n = 1, text = "c", op = { op = "cmd", line = "/pss version" } }, { n = 2, text = "w", op = { op = "call", service = "tkt.w" } } }),
					chk("CHK-00002", { { n = 1, text = "a", op = { op = "action", label = "Version", ["then"] = { op = "cmd", line = "/pss version" } } } }),
					chk("CHK-00003", { { n = 1, text = "a", op = { op = "action", label = "Call", ["then"] = { op = "call", service = "core.version" } } } }),
					chk("CHK-00004", { { n = 1, text = "a", op = { op = "action", label = "Prune", ["then"] = { op = "cmd", line = "/pss prune 1" } } } }),
				}, flavours = { "forever" }, fmt = 1, id = "3.9.0.156-9", kitMin = 1, title = "t" }
				local r = row(imp(enc(json(env))))
				local run = r and PSS_TestKitDB and PSS_TestKitDB.runs["3.9.0.156-9"]
				local bad = {}
				if not (run and r[4] == "") then
					bad[1] = "import " .. tostring(r and r[4])
				else
					local c1 = run.checks["CHK-00001@any"] or {}
					local st = c1.steps or {}
					if st[1] ~= nil or st[2] ~= nil or c1.s ~= "not_complete" or wcalls() ~= 0 then bad[#bad + 1] = "outside action ran" end
					local before = snapAll()
					for _, b in ipairs(runOps(privTK())) do bad[#bad + 1] = "op " .. b end
					M.PSS_Call("testkit.rerun", { id = "3.9.0.156-9" })
					M.PSS_Call("testkit.act", { id = "3.9.0.156-9", key = "CHK-00002@any", step = 1 })
					M.PSS_Call("testkit.act", { id = "3.9.0.156-9", key = "CHK-00003@any", step = 1 })
					M.PSS_Call("testkit.act", { id = "3.9.0.156-9", key = "CHK-00004@any", step = 1 })
					local after = snapAll()
					for i, n in ipairs(DBS) do if before[i] ~= after[i] then bad[#bad + 1] = "changed " .. n end end
					local a2 = run.checks["CHK-00002@any"].steps[1]
					local a3 = run.checks["CHK-00003@any"].steps[1]
					local a4 = run.checks["CHK-00004@any"]
					if not (a2 and a2.ok and a3 and a3.ok) then bad[#bad + 1] = "act version/call" end
					if not (a4.auto and a4.auto.s == "other" and a4.auto.sub == "blocked" and a4.auto.why == "command not allowed: prune") then bad[#bad + 1] = "act prune" end
				end
				ok = #bad == 0
				why = table.concat(bad, "; ")
			elseif phase == "ut10" or phase == "ut11" then
				local ev = phase == "ut10"
				local obj = ev and { id = "o1", need = 2, name = "PSS_TK_EVT", source = "event", text = "Event twice" }
					or { cmp = "eq", id = "o1", path = "PSS_TKFR", prop = "shown", source = "poll", text = "Frame shown", want = true }
				local env = { build = "3.9.0.162", checks = { { client = "any", ["do"] = "d", expect = "e", key = "CHK-00001", link = "https://x", look = "any",
					objectives = { obj }, steps = { { n = 1, op = { cmp = "type", fn = "GetLocale", op = "api", want = "string" }, text = "locale" } }, title = "t" } }, flavours = { "forever" }, fmt = 1, id = "3.9.0.162-9", kitMin = 1, title = "t" }
				local r = row(imp(enc(json(env))))
				local wants = 0
				M.PSS_Want = function() wants = wants + 1 return true end
				local ck = function() local run = PSS_TestKitDB and PSS_TestKitDB.runs["3.9.0.162-9"] return run and run.checks["CHK-00001@any"] end
				if not (r and r[4] == "") then
					ok, why = false, "import " .. tostring(r and r[4])
				elseif ev then
					M.PSS_Call("testkit.open")
					H.Fire("PSS_TK_EVT")
					local c1 = ck()
					local h1, s1 = c1 and c1.obj and c1.obj.o1, c1 and c1.auto and c1.auto.s
					H.Fire("PSS_TK_EVT")
					local c2 = ck()
					local h2, s2 = c2 and c2.obj and c2.obj.o1, c2 and c2.s
					ok = h1 == 1 and s1 ~= "complete" and h2 == 2 and s2 == "complete"
					why = "have1=" .. tostring(h1) .. " auto1=" .. tostring(s1) .. " have2=" .. tostring(h2) .. " s2=" .. tostring(s2)
				else
					_G.PSS_TKFR = { IsShown = function() return false end }
					local hidden = wants
					M.PSS_Call("testkit.open")
					ok = hidden == 0 and wants == 1
					why = "hidden=" .. hidden .. " shown=" .. wants
				end
			else
				ok, why = false, "unknown case"
			end
	end
	M.ShowMsg = showMsg
	print((ok and "PASS testkit " or "FAIL testkit ") .. phase .. (ok and "" or (": " .. tostring(why))))
	return
end

-- driver
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local self = arg[0]
local pass, fail = 0, 0
local UT14SV

local function run(cmd)
	local p = io.popen("(" .. cmd .. ") 2>&1; echo EXIT=$?")
	local out = p:read("*a")
	p:close()
	local code = tonumber(out:match("EXIT=(%d+)%s*$"))
	return out, code
end
local function report(name, good, detail)
	if good then pass = pass + 1 print("PASS testkit " .. name)
	else fail = fail + 1 print("FAIL testkit " .. name .. (detail and (": " .. detail) or "")) end
end

for _, ph in ipairs({ "missing", "disabled", "loadable" }) do
	local out = run("PSS_PHASE=" .. ph .. " lua5.1 " .. here .. "/run.lua . - - " .. self)
	local line = out:match("(PASS testkit " .. ph .. ")") or out:match("(FAIL testkit [^\n]*)")
	report(ph, line and line:sub(1, 4) == "PASS", line or out:sub(1, 200))
end

-- TK-UT-01 to 06, 12 to 15: one report each, each phase a fresh stub client
local UT = { { "TK-UT-01", { "ut01" } }, { "TK-UT-02", { "ut02" } }, { "TK-UT-03", { "ut03" } }, { "TK-UT-04", { "ut04" } },
	{ "TK-UT-05", { "ut05" } }, { "TK-UT-06", { "ut06" } }, { "TK-UT-12", { "ut12" } }, { "TK-UT-13", { "ut13" } },
	{ "TK-UT-14", { "ut14a", "ut14b", "ut14c", "ut14d" } }, { "TK-UT-15", { "ut15" } }, { "TK-UT-30", { "ut30" } },
	{ "TK-UT-07", { "ut07" } }, { "TK-UT-10", { "ut10" } }, { "TK-UT-11", { "ut11" } }, { "TK-UT-08", { "ut08" } }, { "TK-UT-09", { "ut09" } } }
for _, t in ipairs(UT) do
	local good, detail = true, nil
	for _, ph in ipairs(t[2]) do
		local sv = os.tmpname()
		local out = run("PSS_PHASE=" .. ph .. " lua5.1 " .. here .. "/run.lua . " .. (ph == "ut14d" and UT14SV or "-") .. " " .. (ph == "ut14c" and (function() UT14SV = sv return sv end)() or "-") .. " " .. self)
		local line = out:match("(PASS testkit " .. ph .. ")") or out:match("(FAIL testkit [^\n]*)")
		if not (line and line:sub(1, 4) == "PASS") then good = false detail = line or out:sub(1, 200) end
	end
	report(t[1], good, detail)
end

-- TK-UT-18: the rules tools pass with PSS_TestKit/ present
local f = io.open("PSS_TestKit/PSS_TestKit.toc", "rb")
local tools = { "lua5.1 tools/check_layers.lua", "lua5.1 tools/harness/bus_budgets.lua", "lua5.1 tools/check_timers.lua",
	"PSS_PHASE=budget PSS_COMPONENTS=logging lua5.1 " .. here .. "/run.lua . - - " .. here .. "/check_bus.lua | grep -v '^|cff' | grep -q 'PASS bus budget'" }
local bad
if not f then bad = "PSS_TestKit/PSS_TestKit.toc missing" else
	f:close()
	for _, cmd in ipairs(tools) do
		local out, code = run(cmd)
		if code ~= 0 then bad = cmd .. " exit " .. tostring(code) .. " " .. out:sub(1, 200) break end
	end
end
report("tools", not bad, bad)

print("check_testkit: " .. pass .. " passed, " .. fail .. " failed")
os.exit(fail > 0 and 1 or 0)
