-- check_testkit.lua: offline checks of the PSS TestKit: TK-UT-01 to 06, 12 to 15, 16, 18.
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
			PSS_TestKitDB = nil
			if phase == "ut01" then
				local r = row(imp(exTxt))
				local run = PSS_TestKitDB.runs["3.9.0.156-1"]
				ok = r and r[1] == "3.9.0.156-1" and r[2] == "3.9.0.156" and r[3] == 3 and r[4] == "" and run ~= nil
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
				ok = r and r[1] == "3.9.0.156-1" and r[2] == "3.9.0.156" and r[3] == 3 and r[4] == ""
					and PSS_TestKitDB.runs["3.9.0.156-1"].src == exTxt
				why = "row=" .. tostring(r and r[1]) .. " err=" .. tostring(r and r[4])
			elseif phase == "ut12" then
				imp(exTxt)
				local run = PSS_TestKitDB.runs["3.9.0.156-1"]
				run.checks["CHK-00226@tbc"] = run.checks["CHK-00226@tbc"] or {}
				run.checks["CHK-00226@tbc"].auto = { s = "complete", at = 1 }
				M.PSS_Call("testkit.mark", { id = "3.9.0.156-1", key = "CHK-00226@tbc", status = "failed", reason = "x" })
				local ck = run.checks["CHK-00226@tbc"]
				ok = ck.s == "other" and ck.sub == "failed" and ck.why == "x" and ck.man and ck.man.s == "other" and ck.auto and ck.auto.s == "complete"
				why = "s=" .. tostring(ck.s) .. " sub=" .. tostring(ck.sub) .. " auto=" .. tostring(ck.auto and ck.auto.s)
			elseif phase == "ut13" then
				local n = 0
				for i = 1, 6 do
					local r = row(imp(enc(plain('"id":"3.9.0.156-1"', '"id":"3.9.0.156-' .. i .. '"'))))
					if r and r[4] == "" then n = n + 1 end
				end
				M.PSS_Call("testkit.note", { id = "3.9.0.156-6", key = "CHK-00226", text = string.rep("n", 600) })
				local ck = PSS_TestKitDB.runs["3.9.0.156-6"] and PSS_TestKitDB.runs["3.9.0.156-6"].checks["CHK-00226@tbc"]
				local note = ck and ck.notes and ck.notes[""] or ""
				ok = n == 6 and runCount() == 5 and PSS_TestKitDB.runs["3.9.0.156-1"] == nil and #PSS_TestKitDB.order == 5 and #note == 500
				why = "imported=" .. n .. " runs=" .. runCount() .. " note=" .. #note
			elseif phase == "ut14a" then
				PSS_TestKitDB = { v = 1, order = {}, runs = {}, zz = "keep" }
				imp(exTxt)
				ok = PSS_TestKitDB.zz == "keep" and PSS_TestKitDB.runs["3.9.0.156-1"] ~= nil
				why = "zz=" .. tostring(PSS_TestKitDB.zz)
			elseif phase == "ut14b" then
				PSS_TestKitDB = { v = 2, order = {}, runs = {} }
				local r = row(imp(exTxt))
				local told = false
				for _, m in ipairs(msgs) do if m == "PSS_TestKitDB is from a newer kit; results are read-only." then told = true end end
				ok = told and runCount() == 0 and PSS_TestKitDB.v == 2 and not (r and r[1] == "3.9.0.156-1")
				why = "told=" .. tostring(told) .. " runs=" .. runCount()
			elseif phase == "ut15" then
				imp(exTxt)
				local before = #msgs
				local r = row(imp(exTxt))
				ok = runCount() == 1 and #PSS_TestKitDB.order == 1 and r and r[1] == "3.9.0.156-1" and msgs[before + 1] == "already imported: 3.9.0.156-1"
				why = "runs=" .. runCount() .. " msg=" .. tostring(msgs[before + 1])
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
	{ "TK-UT-14", { "ut14a", "ut14b" } }, { "TK-UT-15", { "ut15" } } }
for _, t in ipairs(UT) do
	local good, detail = true, nil
	for _, ph in ipairs(t[2]) do
		local out = run("PSS_PHASE=" .. ph .. " lua5.1 " .. here .. "/run.lua . - - " .. self)
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
