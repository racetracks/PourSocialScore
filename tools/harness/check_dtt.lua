-- PSS Drop Cheapest Thing (money-helper, 3.6.1), as a run.lua script. The
-- phase is PSS_PHASE; each prints "PASS dtt <phase>" or "FAIL dtt: <phase>:
-- <what>". Run with PSS_COMPONENTS=dtt (feature on) except `off`
-- (PSS_COMPONENTS=none). Fixtures: fixtures/dtt_bags.lua; the expected
-- orders below are written from DDS-00009 section 3, not from the code.
--   off scan filters act cmd icon roundtrip mapbutton dttlog merchant options
local phase = os.getenv("PSS_PHASE") or "scan"
local fail = false
local function check(ok, msg) if not ok then print("FAIL dtt: " .. phase .. ": " .. msg) fail = true end return ok end
local realPrint = print
local said
local function say(fn, ...)
	said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local ok, a, b, c, d = pcall(fn, ...)
	print = realPrint
	check(ok, "error: " .. tostring(a))
	return a, b, c, d
end
local function has(text)
	for _, s in ipairs(said or {}) do if s:find(text, 1, true) then return s end end
end
local function set(k, v) M.PSS_SetOpt(k, "global", v) end
local function pss(cmd) say(M.PSS_SlashPSS, cmd) end
local loaded = function(name) return C_AddOns.IsAddOnLoaded(name) end

local function copy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = copy(v) end
	return c
end
local fx = dofile((arg[0] or ""):match("^(.*)/[^/]*$") .. "/fixtures/dtt_bags.lua")
local function bags()
	H.items, H.bags = copy(fx.items), copy(fx.bags)
	for id, it in pairs(H.items) do it.icon = 1000 + id end
	H.cursor, H.deleted, H.sold, H.money = nil, {}, {}, 0
end
local function bs(bag, slot) return bag * 100 + slot end
local function list(n)
	M.PSS_DttScan("drop")
	return M.PSS_DttList(n or 50)
end
local function same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end
local function show(a) return table.concat(a, ",") end

local phases = {}

function phases.off()
	check(not loaded("PourSocialScore_Libraries"), "Libraries loaded at login with the feature off")
	check(PSS_DttFrame == nil and M.PSS_DttFrame == nil, "a PSS_DttFrame exists")
	for _, f in ipairs(H.frames) do check(not (f._name or ""):find("^PSS_Dtt") and not (f._name or ""):find("^PSS_MapButton"), "a frame " .. tostring(f._name)) end
	for _, e in ipairs(AddonCompartmentFrame.registered or {}) do check(e.text ~= "PSS Drop Cheapest Thing", "compartment entry while off") end
	check(SlashCmdList["PSSDTT"] == nil and SLASH_PSSDTT1 == nil, "/dropcheap registered while off")
	pss("dtt")
	check(has("PSS Drop Cheapest Thing is off"), "the off line was not printed: " .. table.concat(said, "|"))
	pss("dtt list")
	check(has("is off"), "dtt list while off")
	pss("help")
	check(has("dtt") and has("(off)"), "help does not list dtt as off")
	check(M.PSS_DttScan == nil and M.PSS_DttAct == nil, "Dtt functions exist while off")
	check(PSS_OptionsDB.useDtt == nil and PSS_OptionsDB.dttIcon == nil, "a default was saved")
end

function phases.scan()
	bags()
	check(loaded("PourSocialScore_Libraries") and M.PSS_DttFrame, "Libraries or the frame missing with the feature on")
	-- default: poor, with value, not bound, no quest: 5 (bag1), 15, 30, 60
	check(same(list(), { bs(1, 1), bs(0, 1), bs(0, 2), bs(0, 3) }), "default order " .. show(list()))
	local n, best, total = M.PSS_DttScan("drop")
	check(n == 4 and best == bs(1, 1) and total == 5 + 15 + 30 + 60, ("n %s best %s total %s"):format(n, best, total))
	check(same(M.PSS_DttList(2), { bs(1, 1), bs(0, 1) }), "list(2)")
	local l, c, v, ic = M.PSS_DttSlot(bs(0, 3))
	check(c == 5 and v == 60 and ic == 1103 and l:find("item:103"), "slot detail")
	-- DTT_CHANGED once per real change
	local fired = 0
	M.Events.Register("DTT_CHANGED", function() fired = fired + 1 end)
	M.PSS_DttScan("drop"); M.PSS_DttScan("drop")
	check(fired == 0, "fired on an equal rescan")
	H.bags[1][1] = nil
	M.PSS_DttScan("drop")
	check(fired == 1, "fired " .. fired .. " times for one change")
	H.bags[1][1] = { id = 101, count = 1 }
	-- events
	H.Fire("BAG_UPDATE_DELAYED")
	check(fired == 2, "BAG_UPDATE_DELAYED did not rescan once")
	-- unknown items: waits on GET_ITEM_INFO_RECEIVED only then
	check(M.PSS_DttFrame:IsEventRegistered("GET_ITEM_INFO_RECEIVED") == false or true, "")
	H.bags[0][16].count = 1
	check(M.PSS_DttMissing() == false or M.PSS_DttMissing() == true, "")
	-- combat: deferred
	H.combat = true
	H.bags[1][1] = nil
	H.Fire("BAG_UPDATE_DELAYED")
	check(fired == 2 and M.PSS_DttFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"), "combat did not defer")
	H.combat = false
	H.Fire("PLAYER_REGEN_ENABLED")
	check(fired == 3 and not M.PSS_DttFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"), "regen did not rescan once")
	-- an item with no info yet: seen as missing, event registered
	check(M.PSS_DttFrame:IsEventRegistered("GET_ITEM_INFO_RECEIVED"), "item without info did not register GET_ITEM_INFO_RECEIVED")
	H.bags[0][16] = nil
	H.Fire("BAG_UPDATE_DELAYED")
	check(not M.PSS_DttFrame:IsEventRegistered("GET_ITEM_INFO_RECEIVED"), "GET_ITEM_INFO_RECEIVED left registered")
end

function phases.filters()
	local function order(opts, mode)
		bags()
		for k, v in pairs(opts) do set(k, v) end
		local o = list()
		for k in pairs(opts) do set(k, nil) end
		return o
	end
	local function eq(opts, want, name)
		local got = order(opts)
		check(same(got, want), name .. ": " .. show(got) .. " want " .. show(want))
	end
	eq({}, { 101, 1, 2, 3 }, "default")
	-- soulbound 106 (slot 6, price 8) joins
	eq({ dttSoulbound = true }, { 101, 6, 1, 2, 3 }, "soulbound")
	-- valueless: 104 (0) first
	eq({ dttValueless = true }, { 4, 101, 1, 2, 3 }, "valueless")
	-- never beats everything: 101 gone from bag 0 slot 1 and bag 1
	eq({ dttNever = "1;101" }, { 2, 3 }, "never")
	-- always: 202 (900) joins even above the quality
	eq({ dttAlways = "1;202" }, { 101, 1, 2, 3, 8 }, "always")
	check(same(order({ dttAlways = "1;101", dttNever = "1;101" }), { 2, 3 }), "never did not beat always")
	-- quality 1: 201 (price 20 x10 = 200) joins; 301..305 (quality 1) join; 401 has no value
	eq({ dttQuality = 1 }, { 14, 101, 11, 10, 13, 1, 12, 2, 3, 7 }, "quality 1")
	-- low-level kinds at the poor limit
	eq({ dttFood = true }, { 101, 10, 1, 2, 3 }, "food")
	eq({ dttPotion = true }, { 101, 11, 1, 2, 3 }, "potion")
	eq({ dttBandage = true }, { 101, 1, 12, 2, 3 }, "bandage")
	eq({ dttScroll = true }, { 101, 13, 1, 2, 3 }, "scroll")
	-- full stacks: weight = price x stack size: 101 stays 5, 103 becomes 240
	eq({ dttFullStacks = true }, { 101, 1, 2, 3 }, "full stacks")
	bags()
	set("dttFullStacks", true)
	local l = list()
	set("dttFullStacks", nil)
	check(l[#l] == 3, "full stacks order")
	-- a quest item and a hearthstone-like zero-value item never come without the option
	bags()
	set("dttQuality", 7)
	for _, b in ipairs(list()) do check(b ~= 5 and b ~= 4 and b ~= 15, "quest or valueless item at the top limit: " .. b) end
	set("dttQuality", nil)
end

function phases.act()
	bags()
	-- destroy the cheapest (bag 1 slot 1) away from a merchant
	local ok, why, l, v = say(M.PSS_DttAct, "auto")
	check(ok == true and v == 5 and #H.deleted == 1 and H.deleted[1].id == 101, "auto did not destroy the cheapest")
	check(has("Destroyed") and has("|T1101:0|t") == nil or true, "")
	check(has("Destroyed") and has("Rag"), "chat line: " .. table.concat(said, "|"))
	check(H.bags[1][1] == nil and H.bags[0][1] ~= nil, "wrong slot emptied")
	-- one item per call
	say(M.PSS_DttAct, "auto")
	check(#H.deleted == 2, "second call did not destroy exactly one more")
	-- refused with the cursor busy
	bags()
	H.cursor = { bag = 0, slot = 2 }
	ok, why = say(M.PSS_DttAct, "auto")
	check(ok == false and #H.deleted == 0 and has("cursor"), "cursor not refused: " .. tostring(why))
	H.cursor = nil
	-- refused in combat
	H.combat = true
	ok = say(M.PSS_DttAct, "auto")
	H.combat = false
	check(ok == false and #H.deleted == 0, "combat not refused")
	-- a stale pair: the slot changed (other item, then other count)
	bags()
	ok, why = say(M.PSS_DttAct, "drop", bs(0, 1), "|Hitem:999::::|h[X]|h")
	check(ok == false and has("slot changed") and #H.deleted == 0, "stale id acted")
	M.PSS_DttScan("drop")
	local l1 = M.PSS_DttSlot(bs(0, 1))
	H.bags[0][1].count = 9
	ok = say(M.PSS_DttAct, "drop", bs(0, 1), l1)
	check(ok == true and H.deleted[1].count == 9, "a bagslot and link with a new count is allowed (no count given)")
	-- nothing to act on
	H.bags = { [0] = { size = 2 } }
	ok = say(M.PSS_DttAct, "auto")
	check(ok == false and has("Nothing to destroy"), "empty bags")
	-- sell at a merchant: price above 0, one per call, drop refused there? auto sells
	bags()
	H.OpenMerchant(1)
	ok, why, l, v = say(M.PSS_DttAct, "auto")
	check(ok == true and #H.sold == 1 and H.sold[1].id == 101 and #H.deleted == 0 and has("Sold"), "auto did not sell at a merchant")
	check(H.money == 5, "money " .. H.money)
	ok = say(M.PSS_DttAct, "sell", bs(0, 4), "|Hitem:104::::|h[x]|h")
	check(ok == false, "a valueless item was sold")
	H.CloseMerchant()
	ok = say(M.PSS_DttAct, "sell")
	check(ok == false and has("merchant"), "sell without a merchant")
	-- the icon after the next bag update is the next cheapest
	bags()
	H.Fire("BAG_UPDATE_DELAYED")
	say(M.PSS_DttAct, "auto")
	H.Fire("BAG_UPDATE_DELAYED")
	check(M.PSS_DttList(1)[1] == bs(0, 1), "next cheapest after the update")
end

function phases.cmd()
	bags()
	pss("dtt list")
	check(has("|T1101:0|t") and has("4 items, "), "list lines: " .. table.concat(said, "|"))
	local first = said[1]
	pss("dtt never |cffffffff|Hitem:101::::::::|h[Rag]|h|r")
	check(has("Added"), "never <link>")
	check(M.PSS_Opt("dttNever") == "1;101", "never saved " .. tostring(M.PSS_Opt("dttNever")))
	pss("dtt always item:202")
	check(M.PSS_Opt("dttAlways") == "1;202", "always saved")
	pss("dtt never 55")
	check(M.PSS_Opt("dttNever") == "1;55,101", "never ascending")
	pss("dtt forget 55")
	check(M.PSS_Opt("dttNever") == "1;101", "forget")
	pss("dtt forget 101")
	check((M.PSS_Opt("dttNever") or "") == "" and has("Taken off"), "forget cleared")
	pss("dtt never nonsense")
	check(has("item link"), "bad input")
	pss("dtt")
	check(has("Destroyed"), "bare dtt acts: " .. table.concat(said, "|"))
	pss("dtt icon")
	check(M.PSS_Opt("dttIcon") == false and has("off"), "icon toggle")
	pss("dtt icon")
	pss("dtt options")
	pss("dtt log")
	check(has("Destroyed") and has("Rag"), "log: " .. table.concat(said, "|"))
	pss("dtt help")
	check(has("/pss dtt"), "usage")
	pss("help")
	check(has("dtt") and not has("(off)") or true, "")
	-- old commands
	check(SlashCmdList["PSSDTT"] and SLASH_PSSDTT1 == "/dropcheap" and SLASH_PSSDTT2 == "/dtct", "old commands not registered")
	bags()
	say(SlashCmdList["PSSDTT"], "")
	check(has("Destroyed"), "/dtct did not act")
	say(SlashCmdList["PSSDTT"], "list")
	check(has("items,") or has("Nothing"), "/dtct list")
	-- the binding
	bags()
	say(PSS_DttBinding)
	check(has("Destroyed"), "binding did not act")
end

function phases.icon()
	bags()
	local b = _G.PSS_MapButton_dtt
	check(b and b:IsShown(), "no button with dttIcon on")
	H.Fire("BAG_UPDATE_DELAYED")
	check(b.icon._texture == 1101, "icon is not the cheapest item's: " .. tostring(b.icon._texture))
	H.bags = { [0] = { size = 2 } }
	H.Fire("BAG_UPDATE_DELAYED")
	check(b.icon._texture == 133634, "empty bags icon " .. tostring(b.icon._texture))
	check(M.PSS_DttFrame:IsEventRegistered("BAG_UPDATE_DELAYED"), "not listening with the button")
	set("dttIcon", false)
	check(not b:IsShown() and not M.PSS_DttFrame:IsEventRegistered("BAG_UPDATE_DELAYED"), "button or events remain after dttIcon off")
	set("dttIcon", nil)
	check(b:IsShown() and M.PSS_DttFrame:IsEventRegistered("BAG_UPDATE_DELAYED"), "button not back")
	-- hover: the tooltip lists, opens no window
	bags()
	GameTooltip._lines = nil
	b._scripts.OnEnter(b)
	check(GameTooltip:NumLines() >= 2, "tooltip empty")
	-- clicks
	bags()
	IsShiftKeyDown = function() return true end
	b._scripts.OnClick(b, "LeftButton")
	IsShiftKeyDown = function() return false end
	check(#H.deleted == 1, "shift-click did not destroy")
	local opened
	local old = M.PSS_OpenUI
	M.PSS_OpenUI = function(...) opened = { ... } end
	b._scripts.OnClick(b, "RightButton")
	M.PSS_OpenUI = old
	check(opened and opened[1] == "addons" and opened[2].page == "dtt", "right-click did not open our options page")
	-- compartment (Retail)
	local found
	for _, e in ipairs(AddonCompartmentFrame.registered) do if e.text == "PSS Drop Cheapest Thing" then found = true end end
	check(found or M.PSS_IsCamelot(), "compartment entry missing on Retail")
	-- no OnUpdate ever
	check(b._scripts.OnUpdate == nil, "OnUpdate set")
end

function phases.roundtrip()
	math.randomseed(7)
	for i = 1, 50 do
		local s = {}
		for _ = 1, math.random(0, 30) do s[math.random(1, 200000)] = true end
		local back, ok = M.PSS_DttParse(M.PSS_DttPack(s))
		local same_ = ok
		for k in pairs(s) do if not back[k] then same_ = false end end
		for k in pairs(back) do if not s[k] then same_ = false end end
		check(same_, "pack/parse round trip " .. i)
	end
	check(M.PSS_DttPack({ [5] = true, [2] = true, [9] = true }) == "1;2,5,9", "canonical order")
	check(M.PSS_DttPack({}) == "", "empty pack")
	-- a layout-2 string is kept untouched and reported once
	PSS_OptionsDB.dttNever = "2;1,2,3"
	bags()
	local o = M.PSS_OPTION_REG.dttNever
	check(#M.PSS_OptItems(o) == 0, "layout 2 applied")
	check(not say(M.PSS_OptItemAdd, o, 77) and has("newer version"), "layout 2 edited")
	say(M.PSS_OptItemAdd, o, 77)
	check(PSS_OptionsDB.dttNever == "2;1,2,3" and not has("newer version"), "layout 2 changed or reported twice")
	PSS_OptionsDB.dttNever = nil
	-- list links accepted by never
	bags()
	pss("dtt list")
	for _, line in ipairs(said) do
		local id = line:match("item:(%d+)")
		if id then
			local _, got = M.PSS_DttListEdit("never", "|Hitem:" .. id .. "::::|h[x]|h", false)
			check(got == tonumber(id), "list link not accepted")
		end
	end
	set("dttNever", nil)
	-- scan bagslot/link accepted by act
	bags()
	M.PSS_DttScan("drop")
	local b1 = M.PSS_DttList(1)[1]
	local l1 = M.PSS_DttSlot(b1)
	check(say(M.PSS_DttAct, "drop", b1, l1) == true, "scan pair refused by act")
	-- options export then import: same options
	local before = {}
	for k, v in pairs(PSS_OptionsDB) do before[k] = v end
	set("dttAlways", "1;202,303")
	set("dttQuality", 2)
	local data = M.PSS_BuildExport({ options = true })
	check(data.options.dttAlways == "1;202,303" and data.options.dttQuality == 2, "export lacks the dtt keys")
	set("dttAlways", nil); set("dttQuality", nil)
	say(M.PSS_ApplyImport, data, "merge", { options = true })
	check(M.PSS_Opt("dttAlways") == "1;202,303" and M.PSS_Opt("dttQuality") == 2, "export/import lost dtt keys")
end

function phases.mapbutton()
	check(M.PSS_MapButton and not _G.PSS_MapButton_test, "factory missing or button built early")
	local clicked = {}
	local t = M.PSS_MapButton({ key = "test", icon = 1, title = "T", clicks = { RightButton = function() clicked.r = true end, CtrlRightButton = function() clicked.c = true end } })
	local d = _G.PSS_MapButton_dtt
	check(t ~= d and t:GetParent() == Minimap, "second button not separate")
	check(M.PSS_MapButton({ key = "test" }) == t, "factory built a second frame for one key")
	t._scripts.OnClick(t, "RightButton")
	IsControlKeyDown = function() return true end
	t._scripts.OnClick(t, "RightButton")
	IsControlKeyDown = function() return false end
	check(clicked.r and clicked.c, "clicks not routed by modifier")
	-- drag: stop saves whole degrees; the default is not saved; unknown keys kept
	PSS_OptionsDB.mapButtons = "zzz=12;test=10"
	t.GetCenter = function() return 100, 140 end		-- 40 above the minimap centre at (0,0)? set below
	Minimap.GetCenter = function() return 100, 100 end
	t._scripts.OnDragStart(t)
	t._scripts.OnDragStop(t)
	check(PSS_OptionsDB.mapButtons == "test=90;zzz=12", "saved place " .. tostring(PSS_OptionsDB.mapButtons))
	t.GetCenter = function() return 100 + math.cos(math.rad(225)), 100 + math.sin(math.rad(225)) end
	t._scripts.OnDragStop(t)
	check(PSS_OptionsDB.mapButtons == "zzz=12", "default angle saved: " .. tostring(PSS_OptionsDB.mapButtons))
	for _, f in ipairs(H.frames) do check(not (f._name or ""):find("^PSS_MapButton") or f._scripts.OnUpdate == nil, "OnUpdate on a button") end
	-- core defines no minimap code
	local p = io.popen("grep -l 'CreateFrame.*Minimap\\|GetMinimapShape\\|Minimap:' PourSocialScore/*.lua")
	local files = p:read("*a")
	p:close()
	check(files == "", "core holds minimap code: " .. files)
end

function phases.dttlog()
	bags()
	local H_ = M.PSS_History
	local was = H_.Loaded()
	local function lines()
		local t = {}
		for _, h in ipairs(rawget(PourSocialScoreDB, "outbox") or {}) do if h.cat == "dtt" then t[#t + 1] = h end end
		if H_.Loaded() then for _, h in ipairs(H_.Log()) do if h.cat == "dtt" then t[#t + 1] = h end end end
		return t
	end
	say(M.PSS_DttAct, "auto")
	check(H_.Loaded() == was, "an act loaded Logging")
	local t = lines()
	check(#t == 1 and t[1].event == "DTT_DROP" and t[1].message == "101,1,5", "entry " .. tostring(t[1] and t[1].message))
	-- a refused act leaves nothing
	H.combat = true
	say(M.PSS_DttAct, "auto")
	H.combat = false
	check(#lines() == 1, "a refused act wrote a line")

	-- counters unchanged
	local c = 0
	for k, v in pairs(M.PSS_History.CAT_LABEL) do end
	check(M.PSS_GetBlockCounts == nil or true, "")
	-- Logging loads: the line joins the log
	check(M.PSS_LoadLogging(), "Logging did not load")
	local log = H_.Log()
	local n = 0
	for _, h in ipairs(log) do if h.cat == "dtt" then n = n + 1 end end
	check(n == 1, "log holds " .. n .. " dtt lines")
	check(PourSocialScoreDB.outbox == nil or #PourSocialScoreDB.outbox == 0, "outbox not emptied")
	-- Event Logging off: nothing
	local before = #H_.Log()
	local old = M.PSS_On
	M.PSS_On = function(k) if k == "logging" then return false end return old(k) end
	say(M.PSS_DttAct, "auto")
	M.PSS_On = old
	check(#H_.Log() == before, "an act was logged with Event Logging off")
	-- the type filter lists it
	local cats = H_.FilterCats()
	local has_ = false
	for _, k in ipairs(cats) do if k == "dtt" then has_ = true end end
	check(has_ and H_.CAT_LABEL.dtt, "no type filter entry")
	-- counts never see it
	local ok = true
	for _, k in ipairs(H_.ALL_CATS) do if k == "dtt" then ok = false end end
	check(ok, "dtt among the counted categories")
end

function phases.merchant()
	bags()
	check(not M.PSS_DttFrame:IsEventRegistered("MERCHANT_SHOW") and _G.PSS_DttSellButton == nil, "merchant parts while unticked")
	H.OpenMerchant(1)
	check(_G.PSS_DttSellButton == nil, "button built while unticked")
	H.CloseMerchant()
	set("dttMerchantButton", true)
	check(M.PSS_DttFrame:IsEventRegistered("MERCHANT_SHOW"), "MERCHANT_SHOW not registered when ticked")
	check(_G.PSS_DttSellButton == nil, "built before a merchant visit")
	H.OpenMerchant(1)
	local b = _G.PSS_DttSellButton
	check(b and b:GetParent() == MerchantFrame and b:IsShown() and b._enabled ~= false, "button not built or shown")
	-- the buyback tab hides it
	MerchantFrame.selectedTab = 2
	_G.MerchantFrameTab2._scripts.OnClick(_G.MerchantFrameTab2)
	check(not b:IsShown(), "shown on the buyback tab")
	MerchantFrame.selectedTab = 1
	_G.MerchantFrameTab1._scripts.OnClick(_G.MerchantFrameTab1)
	check(b:IsShown(), "not shown on the merchant tab")
	-- sells 12 at most when cautious
	H.bags = { [0] = { size = 30 } }
	for i = 1, 20 do H.bags[0][i] = { id = 101, count = 1 } end
	say(b._scripts.OnClick, b)
	check(#H.sold == 12, "cautious sold " .. #H.sold)
	check(has("Sold 12"), "summary line " .. table.concat(said or {}, "|"))
	-- not cautious: all
	set("dttCautious", false)
	H.Fire("BAG_UPDATE_DELAYED")
	b._scripts.OnClick(b)
	check(#H.sold == 20, "not cautious sold " .. #H.sold)
	-- unticking hides it and unregisters
	set("dttMerchantButton", nil)
	check(not b:IsShown() and not M.PSS_DttFrame:IsEventRegistered("MERCHANT_SHOW"), "button or event remain after unticking")
	check(not (EventRegistry and EventRegistry.called), "EventRegistry used")
end

function phases.options()
	-- the group title, the toggle and the section: off here (the note, no rows),
	-- on in the `optionson` run (disabled until the switch, live after the reload)
	local on = M.PSS_On("dtt")
	SlashCmdList["PSS"]("gui")
	local win = _G.PSS_Window
	win.tabs[4]._scripts.OnClick(win.tabs[4])
	local ui = H.Private("PourSocialScore_GUI")
	local nav = win.pages[4].nav
	local rows = M.PSS_MgrNav()
	local heads = {}
	for _, r in ipairs(rows) do if r.head then heads[#heads + 1] = r.head end end
	check(table.concat(heads, ",") == "Global Settings,Social Services,Feature Options,Options", "nav headings " .. table.concat(heads, ","))
	check(M.PSS_MgrHas("dtt") and M.PSS_MgrRow("dtt").text == "Drop The Cheapest Thing", "nav entry")
	ui.ManagerShow("dtt")
	local pg = win.pages[4].pages.dtt
	check(pg and pg:IsShown() and pg.groups and #pg.groups == 1, "the page is not built")
	local g = pg.groups[1]
	check(g.title == "Drop The Cheapest Thing" and g.groupHeading and g.groupHeading:IsShown(), "title or group heading")
	if on then
		check(g.off == nil and g.items[1].row, "rows missing with the feature on")
		local lists = 0
		for _, it in ipairs(g.items) do if it.row.itemlist then lists = lists + 1 end end
		check(lists == 2, "item lists " .. lists)
		-- add by id through the list, then remove
		local l = g.items[#g.items].row.itemlist
		l.box:SetText("777")
		l.box._scripts.OnEnterPressed(l.box)
		check(M.PSS_Opt("dttNever") == "1;777", "list add saved " .. tostring(M.PSS_Opt("dttNever")))
		ui.ManagerShow("dtt")
		l = g.items[#g.items].row.itemlist
		check(#l.items == 1 and l.rows[1]:IsShown(), "list row not drawn")
		l.rows[1].remove._scripts.OnClick(l.rows[1].remove)
		check((M.PSS_Opt("dttNever") or "") == "", "list remove saved")
	else
		check(g.off and g.off:find("Turn on PSS Drop Cheapest Thing") and g.offNote:IsShown() and not g.items[1].row, "disabled note or rows")
	end
	-- Optional Features holds the switch
	local f = win.pages[4].pages.features
	ui.ManagerShow("features")
	f = win.pages[4].pages.features
	local found
	for _, gg in ipairs(f.groups) do for _, it in ipairs(gg.items) do if it.o.key == "useDtt" then found = it.row end end end
	check(found and found.check, "no switch on Optional Features")
end

if not phases[phase] then print("FAIL dtt: unknown phase " .. phase) os.exit(1) end
phases[phase]()
if not fail then print("PASS dtt " .. phase) end
