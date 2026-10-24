-- Flavour checks (multi-version suite, tests#stub-per-flavour); run by flv_phases.sh.
--   lua5.1 tools/harness/check_flavour.lua <phase>          (stub, conflict: the stub alone)
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_flavour.lua  with PSS_PHASE=<phase> (the rest)
local phase = os.getenv("PSS_PHASE") or (arg and arg[1])
local here = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "tools/harness"
local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1; print("FAIL flv " .. phase .. ": " .. msg) end end
local function done() if fails == 0 then print("PASS flv " .. phase) end os.exit(fails == 0 and 0 or 1) end

if phase == "stub" then
	-- PSS_EXPECT is the flavour the environment must resolve to; PSS_EXPECT_PID its WOW_PROJECT_ID
	local H = dofile(here .. "/wow_stub.lua")
	local want, pid = os.getenv("PSS_EXPECT"), tonumber(os.getenv("PSS_EXPECT_PID") or "")
	ok(H.flavour == want, "stub.flavour " .. tostring(H.flavour) .. " expected " .. tostring(want))
	ok(WOW_PROJECT_ID == pid, "WOW_PROJECT_ID " .. tostring(WOW_PROJECT_ID) .. " expected " .. tostring(pid))
	ok(WOW_PROJECT_CAMELOT == 18 and WOW_PROJECT_MISTS_CLASSIC == 19 and WOW_PROJECT_CLASSIC == 2 and WOW_PROJECT_BURNING_CRUSADE_CLASSIC == 5 and WOW_PROJECT_MAINLINE == 1, "constants")
	done()
elseif phase == "conflict" then
	local good, err = pcall(dofile, here .. "/wow_stub.lua")
	ok(not good, "stub loaded without error")
	ok(tostring(err) == "PSS_FLAVOUR=tbc conflicts with PSS_CAMELOT=1", "error was: " .. tostring(err))
	done()
else
	-- detect can probe alias levels mem nogrep: run inside run.lua with M (the flavour module, B1T2)
	local FLV = M.PSS_FLV
	if phase == "detectrow" then
		print("ROW " .. FLV.flavour .. "," .. FLV.family .. "," .. FLV.digit)
		os.exit(0)
	elseif phase == "detect" then
		local ALL = "WOW_PROJECT_MAINLINE,WOW_PROJECT_CLASSIC,WOW_PROJECT_BURNING_CRUSADE_CLASSIC,WOW_PROJECT_CAMELOT,WOW_PROJECT_MISTS_CLASSIC"
		local rows = {
			{ "1", "", "120007", "retail,mainline,1" },
			{ "18", "", "16001", "forever,mainline,2" },
			{ "5", "", "20506", "tbc,classic,3" },
			{ "2", "", "11509", "era,classic,4" },
			{ "19", "", "50504", "mists,classic,5" },
			{ "18", "WOW_PROJECT_CAMELOT", "16001", "forever,mainline,2" },
			{ "14", "", "40402", "unknown,classic,0" },
			{ "nil", ALL, "nil", "retail,mainline,1" },
		}
		for i, r in ipairs(rows) do
			local cmd = "env -u PSS_CAMELOT PSS_FLAVOUR=retail PSS_STUB_PID=" .. r[1] .. " PSS_STUB_IFACE=" .. r[3] ..
				" PSS_STUB_NOCONST=" .. r[2] .. " PSS_PHASE=detectrow lua5.1 " .. here .. "/run.lua . - - " .. here .. "/check_flavour.lua 2>&1"
			local f = io.popen(cmd)
			local out = f:read("*a")
			f:close()
			local got = out:match("ROW ([^\n]*)")
			ok(got == r[4], "detect row " .. i .. " got " .. tostring(got) .. " expected " .. r[4])
		end
	elseif phase == "blank" then
		ok(FLV.flavour == "tbc", "blank flavour " .. tostring(FLV.flavour))
		ok(FLV.interface == 20506, "blank interface " .. tostring(FLV.interface))
	elseif phase == "can" then
		local t = M.PSS_Test
		local was = t.strict
		t.strict = false
		ok(M.PSS_Can("nope") == false, "can nope strict off")
		t.strict = true
		local good, err = pcall(M.PSS_Can, "nope")
		ok(not good and tostring(err):find("unknown capability: nope", 1, true), "can nope strict on: " .. tostring(err))
		t.strict = was
		FLV.caps.zz = "degraded"
		ok(M.PSS_Can("zz") == true, "degraded cap is true")
		ok(M.PSS_CapLevel("zz") == "degraded", "degraded level")
		FLV.caps.zz = nil
		ok(M.PSS_CapLevel("nope") == "off", "unknown level off")
	elseif phase == "probe" then
		-- presence of a probed global is the stub's; the level must follow it
		ok(M.PSS_CapLevel("cContainer") == (C_Container and "supported" or "off"), "cContainer follows C_Container")
		ok(M.PSS_CapLevel("modernMenu") == ((Menu and Menu.ModifyMenu) and "supported" or "off"), "modernMenu follows Menu")
		local env = "PSS_STUB_OFF=C_Container"
		for _, c in ipairs({ { "retail", "C_Container", "cContainer" }, { "tbc", "Menu,AddonCompartmentFrame", "modernMenu" }, { "era", "Menu,AddonCompartmentFrame", "modernMenu" } }) do
			local cmd = "env -u PSS_CAMELOT PSS_FLAVOUR=" .. c[1] .. " PSS_STUB_OFF=" .. c[2] .. " PSS_PHASE=proberow lua5.1 " .. here .. "/run.lua . - - " .. here .. "/check_flavour.lua 2>&1"
			local f = io.popen(cmd)
			local out = f:read("*a")
			f:close()
			local want = c[3] == "cContainer" and "off" or "off,off"
			local got = out:match("PROBE ([^\n]*)")
			ok(got == want, "probe " .. c[1] .. " " .. c[2] .. " got " .. tostring(got) .. " expected " .. want .. " out: " .. out:sub(1, 200))
		end
	elseif phase == "proberow" then
		print("PROBE " .. (os.getenv("PSS_STUB_OFF") == "C_Container" and M.PSS_CapLevel("cContainer") or (M.PSS_CapLevel("modernMenu") .. "," .. M.PSS_CapLevel("compartment"))))
		os.exit(0)
	elseif phase == "alias" then
		ok(M.PSS_IsCamelot == M.PSS_IsForever, "IsCamelot is not the IsForever function")
		ok(M.PSS_IsForever() == (FLV.flavour == "forever"), "IsForever value")
	elseif phase == "levels" then
		local T = {
			reloadButton = "off,supported,off,off,off", gfxCommand = "off,supported,off,off,off",
			macroCommand = "off,supported,off,off,off", surnames = "off,supported,off,off,off",
			compartment = "supported,off,supported,supported,supported", modernMenu = "supported,supported,supported,supported,supported",
			cContainer = "supported,supported,supported,supported,supported", secretValues = "supported,supported,off,off,off",
			guildBank = "supported,supported,supported,off,supported", friendsAnchor = "off,off,supported,off,off",
		}
		local PRESENT = {
			compartment = function() return AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon end,
			modernMenu = function() return Menu and Menu.ModifyMenu end,
			secretValues = function() return issecretvalue end,
			cContainer = function() return C_Container end,
			guildBank = function() return GetGuildBankItemInfo end,
			friendsAnchor = function() return FriendsFrame and FriendsFrame.NineSlice end,
		}
		local idx = ({ retail = 1, forever = 2, tbc = 3, era = 4, mists = 5 })[FLV.flavour]
		for cap, row in pairs(T) do
			local want, n = nil, 0
			for v in row:gmatch("[^,]+") do n = n + 1; if n == idx then want = v end end
			if want ~= "off" and PRESENT[cap] and not PRESENT[cap]() then want = "off" end
			ok(FLV.caps[cap] == want, FLV.flavour .. " cap " .. cap .. " is " .. tostring(FLV.caps[cap]) .. " expected " .. want)
		end
	elseif phase == "mem" then
		local chunk = loadfile(here .. "/../../PourSocialScore/PSS_Flavour.lua")
		ok(chunk, "PSS_Flavour.lua loads")
		if chunk then
			-- M and V are pre-filled to 100 keys (as in game, where they hold hundreds) so a table
			-- resize is not charged to the module
			local keep = { M = {}, V = {} }
			for i = 1, 100 do keep.M["k" .. i] = true; keep.V["k" .. i] = true end
			collectgarbage(); collectgarbage()
			local before = collectgarbage("count")
			chunk("PourSocialScore", keep)
			collectgarbage(); collectgarbage()
			local kb = collectgarbage("count") - before
			print("NOTE flv mem: " .. FLV.flavour .. " " .. string.format("%.2f", kb) .. " KB")
			ok(kb <= 2, "mem " .. kb .. " KB over 2 KB")
		end
	elseif phase == "nogrep" then
		local f = io.popen("grep -rnE 'WOW_PROJECT_ID|select\\(4, GetBuildInfo' --include=*.lua PourSocialScore PourSocialScore_Libraries PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Options PourSocialScore_Communities 2>/dev/null | grep -v 'PSS_Flavour.lua' | grep -v 'PSS_Compat'")
		local hits = f:read("*a")
		f:close()
		print("NOTE flv nogrep hits (listed, pass before B3):\n" .. hits)
	else
		ok(false, "unknown phase")
	end
	done()
end
