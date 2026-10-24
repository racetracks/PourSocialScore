-- Compat adapter checks (multi-version suite, tests#toc-and-adapter-checks TST-00979, design#acceptance-tests,
-- tests-round2 friends anchor); run by compat_phases.sh, one process per phase and flavour.
--   PSS_PHASE=<phase> [PSS_FLAVOUR=<f>] [PSS_STUB_OFF=<globals>] [PSS_COMPAT_XML=panel|none] lua5.1 tools/harness/run.lua . - - tools/harness/check_compat.lua
local phase = os.getenv("PSS_PHASE")
local flavour = H.flavour
local off = {}
for name in (os.getenv("PSS_STUB_OFF") or ""):gmatch("[^,]+") do off[name] = true end
local fails = 0
local function ok(cond, msg) if not cond then fails = fails + 1; print("FAIL compat " .. phase .. " (" .. flavour .. "): " .. msg) end end
local function done()
	if fails == 0 then print("PASS compat " .. phase) end
	os.exit(fails == 0 and 0 or 1)
end

M.PSS_Need("Libraries")
local call = M.PSS_Call

if phase == "containers" then
	-- bag reads go through compat.containers; C_Container off: the legacy globals, no error
	local lazy = M.PSS_ServiceIsStub("compat.containers.read")
	ok(lazy, "provider built before the first call")
	if off.C_Container then
		ok(M.PSS_CapLevel("cContainer") == "off", "cContainer level with C_Container off: " .. tostring(M.PSS_CapLevel("cContainer")))
		_G.GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end
		_G.GetContainerItemInfo = function(bag, slot)
			if bag == 0 and slot == 1 then return 1, 5, false, 2, false, false, "|Hitem:6948|h", false, false, 6948, true end
			return nil
		end
		local out = {}
		local good, res = pcall(call, "compat.containers.read", 0, { out = out })
		ok(good and res == out, "legacy read raised or returned another set: " .. tostring(res))
		local want = { iconFileID = 1, stackCount = 5, isLocked = false, quality = 2, hyperlink = "|Hitem:6948|h", hasNoValue = false, itemID = 6948, isBound = true }
		local row = out[1]
		ok(type(row) == "table", "slot 1 is not a table")
		if type(row) == "table" then
			for k, v in pairs(want) do ok(row[k] == v, "slot 1 " .. k .. " = " .. tostring(row[k]) .. " expected " .. tostring(v)) end
		end
		ok(out[2] == false and out.n == 2, "empty slot 2 is false, n = " .. tostring(out.n))
		local sz = call("compat.containers.size", 0)
		ok(sz and sz[1][1] == 2, "size through the legacy global")
	else
		ok(M.PSS_CapLevel("cContainer") == "supported", "cContainer level")
		H.bags[0] = { size = 3 }
		H.bags[0][1] = { id = 6948, count = 5 }
		local out = {}
		local res = call("compat.containers.read", 0, { out = out })
		ok(res == out and out.n == 3, "read n = " .. tostring(out.n))
		ok(type(out[1]) == "table" and out[1].itemID == 6948 and out[1].stackCount == 5, "slot 1 through C_Container")
		ok(out[2] == false or out[2] == nil, "slot 2 empty")
		local sz = call("compat.containers.size", 0)
		ok(sz and sz[1][1] == 3, "size")
	end
	ok(not M.PSS_ServiceIsStub("compat.containers.read"), "provider still a stub after the first call")
	local none = call("compat.containers.size", nil)
	ok(none and none[1][1] == 0, "size of nil is 0")
	done()
elseif phase == "guildBank" then
	if flavour == "era" then
		local t = call("compat.guildBank.tabs")
		ok(t and t[1][1] == 0, "era tabs is not 0")
		ok(M.PSS_CapLevel("guildBank") == "off", "era guildBank level")
		local out = {}
		local good, r = pcall(call, "compat.guildBank.read", 1, { out = out })
		ok(good and r == out and out.n == 0, "era read: " .. tostring(r))
		done()
	end
	ok(M.PSS_CapLevel("guildBank") == "supported", "guildBank level")
	local viewable = { true, false }
	_G.GetNumGuildBankTabs = function() return 2 end
	_G.GetGuildBankTabInfo = function(i) return "Tab" .. i, 134400, viewable[i] end
	_G.GetGuildBankItemLink = function(tab, slot) if tab == 1 and slot == 1 then return "|Hitem:6948|h" end return nil end
	_G.GetGuildBankItemInfo = function(tab, slot) if tab == 1 and slot == 1 then return 134400, 4 end return nil end
	local t = call("compat.guildBank.tabs")
	ok(t and t[1][1] == 2, "tabs " .. tostring(t and t[1][1]))
	local info = call("compat.guildBank.tab", 1)
	ok(info and info[1][1] == "Tab1" and info[1][3] == true, "tab 1 info")
	local out = {}
	local r = call("compat.guildBank.read", 1, { out = out })
	ok(r == out and type(out[1]) == "table", "viewable tab 1 read")
	local nv = call("compat.guildBank.read", 2, { out = {} })
	ok(not nv or nv == false or nv.n == 0, "a tab that is not viewable returned rows")
	done()
elseif phase == "secret" then
	ok(M.PSS_IsSecret("x") == false and M.PSS_IsSecret(5) == false, "plain values are not secret")
	if flavour == "tbc" or flavour == "era" then
		ok(issecretvalue == nil, "issecretvalue present on " .. flavour)
		ok(M.PSS_IsSecret("x") == false, "tbc/era IsSecret(string)")
		ok(M.PSS_IsSecret(12) == false, "tbc/era IsSecret(number)")
	else
		local SECRET = {}
		local s = tostring(os.time()) .. "secret"
		SECRET[s] = true
		_G.issecretvalue = function(v) return SECRET[v] == true end
		ok(M.PSS_IsSecret(s) == true, "the secret stub value is not secret")
		ok(M.PSS_IsSecret("x") == false, "a plain string is secret")
	end
	done()
elseif phase == "menu" then
	local calls = 0
	if Menu then
		local real = Menu.ModifyMenu
		Menu.ModifyMenu = function(...) calls = calls + 1 end
		Menu.real = real
	end
	local good, res = pcall(M.PSS_CompatMenu, "MENU_UNIT_PLAYER", function() end)
	ok(good, "raised: " .. tostring(res))
	if off.Menu then
		ok(res == false, "Menu off: result " .. tostring(res))
		ok(M.PSS_CapLevel("modernMenu") == "off", "Menu off: level")
		ok(calls == 0, "Menu off: made a call")
		ok(Menu == nil, "stub kept Menu")
	else
		ok(res == true, "Menu present: result " .. tostring(res))
		ok(calls == 1, "Menu present: " .. calls .. " calls")
	end
	done()
elseif phase == "compartment" then
	if off.AddonCompartmentFrame then
		local good, res = pcall(M.PSS_CompatCompartment, { text = "x" })
		ok(good and res == false, "AddonCompartmentFrame off: " .. tostring(res))
		ok(M.PSS_CapLevel("compartment") == "off", "level")
	else
		local before = #AddonCompartmentFrame.registered
		local good, res = pcall(M.PSS_CompatCompartment, { text = "x" })
		ok(good, "raised: " .. tostring(res))
		if flavour == "forever" then
			ok(res == false and #AddonCompartmentFrame.registered == before, "forever registered an entry")
		else
			ok(res == true and #AddonCompartmentFrame.registered == before + 1, "entry not registered: " .. tostring(res))
		end
	end
	done()
elseif phase == "reload" then
	local mode = M.PSS_ReloadMode()
	ok(mode == (flavour == "forever" and "press" or "direct"), "mode " .. tostring(mode))
	if flavour == "retail" then
		local n = H.uiReloads
		M.PSS_ReloadUI()
		ok(H.uiReloads == n + 1, "one reload counted, got " .. (H.uiReloads - n))
	end
	if flavour == "forever" then
		local n = H.uiReloads
		local good, how = M.PSS_ReloadPrompt()
		ok(good == true and how == "press" and H.uiReloads == n, "press mode called a reload")
	end
	done()
elseif phase == "templates" then
	local want
	if os.getenv("PSS_COMPAT_XML") == "panel" then
		_G.C_XMLUtil = { GetTemplateInfo = function(name) if name == "UIPanelScrollFrameTemplate" then return {} end return nil end }
		want = "UIPanelScrollFrameTemplate"
	else
		_G.C_XMLUtil = nil
		want = "ScrollFrameTemplate"
	end
	ok(M.PSS_CompatTemplate("scroll") == want, "scroll = " .. tostring(M.PSS_CompatTemplate("scroll")) .. " expected " .. want)
	done()
elseif phase == "friendsAnchor" then
	local win
	local function dock()
		if M.PSS_Opt("openWithFriends") ~= true then M.PSS_SetOpt("openWithFriends", nil, true) end
		FriendsFrame:Show()
		win = _G.PSS_Window
	end
	if flavour == "tbc" and not off.FriendsFrame then
		ok(M.PSS_CapLevel("friendsAnchor") == "supported", "level " .. tostring(M.PSS_CapLevel("friendsAnchor")))
		dock()
		ok(win ~= nil, "window not built")
		if win then
			local p, rel, rp, x, y = win:GetPoint()
			ok(p == "TOPLEFT" and rel == FriendsFrame and rp == "TOPRIGHT" and x == 2 and y == 0, "point " .. tostring(p) .. "," .. tostring(rel) .. "," .. tostring(rp) .. "," .. tostring(x) .. "," .. tostring(y))
			ok(win:GetFrameStrata() == "MEDIUM", "strata " .. tostring(win:GetFrameStrata()))
		end
		ok(M.PSS_CompatFriendsAnchor(SocialUIFrame) == nil, "another host gave an anchor")
		ok(M.PSS_CompatFriendsAnchor(FriendsFrame) ~= nil, "FriendsFrame gave no anchor")
	elseif flavour == "tbc" then
		ok(FriendsFrame == nil, "stub kept FriendsFrame")
		ok(M.PSS_CapLevel("friendsAnchor") == "off", "level " .. tostring(M.PSS_CapLevel("friendsAnchor")))
		ok(M.PSS_CompatFriendsAnchor(SocialUIFrame) == nil, "another host gave an anchor")
	else
		ok(M.PSS_CapLevel("friendsAnchor") == "off", "level " .. tostring(M.PSS_CapLevel("friendsAnchor")))
		ok(FriendsFrame.NineSlice == nil, "stub gave FriendsFrame a NineSlice")
		dock()
		ok(win ~= nil, "window not built")
		if win then
			local p, rel, rp, x, y = win:GetPoint()
			ok(p == "TOPLEFT" and rel == FriendsFrame and rp == "TOPRIGHT" and x == 12 and y == -10, "point " .. tostring(p) .. "," .. tostring(rp) .. "," .. tostring(x) .. "," .. tostring(y))
		end
		ok(M.PSS_CompatFriendsAnchor(FriendsFrame) == nil, "anchor given while off")
	end
	done()
else
	print("FAIL compat: unknown phase " .. tostring(phase))
	os.exit(1)
end
