-- check_testkit.lua: offline checks of the PSS TestKit hand-off (TK-UT-16, TK-UT-18).
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
		ok = kitCalls() == 1 and calls[#calls] == "testkit.open" and #msgs == 0 and C_AddOns.IsAddOnLoaded("PSS_TestKit")
		why = "kitCalls=" .. kitCalls() .. " msgs=" .. #msgs .. " first=" .. tostring(msgs[1])
	else
		ok, why = false, "unknown case"
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
