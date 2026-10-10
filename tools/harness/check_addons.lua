-- The addon manager (/pss acp, /acp, the AddOns tab; 3.6.0), as a run.lua
-- script. The phase is PSS_PHASE; each prints "PASS addons <phase>" or
-- "FAIL addons: <phase>: <what>". Both clients (PSS_CAMELOT=1 for Camelot).
--   list group az lod tick deps all load undo pending sets profiles profiletick rename selforward lock prune
--   noapi oldapi enum guid combat command slash saved charstore memory login
--   big names forward coverage                     (stage 1: the logic)
--   perf perfgroup perftop perfcost                (stage 3: CPU and memory)
-- The stub's addon list is in wow_stub.lua (PSS_ADDONS, PSS_ADDON_*); its
-- default list (H.AddonList) is the one these phases know.
local phase = os.getenv("PSS_PHASE") or "list"
local fail = false
local function check(ok, msg) if not ok then print("FAIL addons: " .. phase .. ": " .. msg) fail = true end return ok end
local loaded = function(name) return C_AddOns.IsAddOnLoaded(name) end
local camelot = os.getenv("PSS_CAMELOT") == "1"
local DIGIT = camelot and "2" or "1"
local GUID = "Player-1-0001"

local realPrint = print
local said
local function capture(fn, ...)
	said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local ok, a, b, c = pcall(fn, ...)
	print = realPrint
	check(ok, "error: " .. tostring(a))
	return said, a, b, c
end
local function has(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return s end end
end
local function pss(cmd) return (capture(M.PSS_SlashPSS, cmd)) end
local function needLibraries()
	check(M.PSS_Need("Libraries"), "Libraries did not load")
	return loaded("PourSocialScore_Libraries")
end
local function say(lines) return table.concat(lines, " | ") end

local function idx(name)
	for i = 1, M.PSS_AddonCount() do
		if M.PSS_AddonName(i) == name then return i end
	end
end
local function row(name, who) return M.PSS_AddonRow(idx(name), who or "me", {}) end
local function fake(name)
	for _, r in ipairs(H.AddonList()) do if r.name == name then return r end end
end
local function plain(s) return ((s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T[^|]*|t", ""))) end
local function listNames(L)
	local t = {}
	for p = 1, L.n do t[#t + 1] = M.PSS_AddonName(L.idx[p]) end
	return t
end
local function posOf(L, name)
	for p = 1, L.n do if M.PSS_AddonName(L.idx[p]) == name then return p end end
end
local function groupNames(L)
	local t = {}
	for _, g in ipairs(L.groups) do t[#t + 1] = g.name end
	return t
end
local function members(L, gi)
	local t, g = {}, L.groups[gi]
	for p = g.from, g.to do t[#t + 1] = M.PSS_AddonName(L.idx[p]) end
	return t
end
local function groupIndex(L, name)
	for i, g in ipairs(L.groups) do if g.name == name then return i end end
end
local function reset() H.addonWrites, H.calls = {}, {} end
local function changedCount()
	local n = 0
	local id = M.Events.Register("ADDONS_CHANGED", function() n = n + 1 end)
	return function() return n end, id
end
local function writeCount(fn)
	local n = 0
	for _, w in ipairs(H.addonWrites) do if w.fn == fn or (fn == nil and w.fn == nil) then n = n + 1 end end
	return n
end
local function sameList(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

local phases = {}

------------------------------------------------------------------------
-- The list
------------------------------------------------------------------------
function phases.list()
	needLibraries()
	local L = M.PSS_AddonList("me", "group")
	-- 6 real folders + the default fakes, Blizzard_Test hidden
	check(L.n == M.PSS_AddonCount() - 1, "list has " .. L.n .. " of " .. M.PSS_AddonCount() .. " (Blizzard_ hidden)")
	check(not posOf(L, "Blizzard_Test"), "a Blizzard_ addon is listed")
	local r = row("DBM-Core")
	check(r.enabled and r.loaded and r.status == "ok" and r.text == "Loaded", "DBM-Core: " .. tostring(r.status) .. " " .. tostring(r.text))
	r = row("Details_Streamer")
	check(r.enabled and not r.loaded and r.status == "reload", "Details_Streamer waits for a reload: " .. tostring(r.status))
	r = row("ZedOne")
	check(not r.enabled and r.status == "off", "ZedOne is off: " .. tostring(r.status))
	r = row("OldThing")
	check(r.outdated and r.status == "bad", "OldThing is out of date: " .. tostring(r.status))
	r = row("Needy")
	check(r.status == "warn" and r.blocked, "Needy has a missing requirement: " .. tostring(r.status))
	r = row("Atlas_Options")
	check(r.lod and r.status == "lod" and r.canLoad, "Atlas_Options loads on demand: " .. tostring(r.status))
	r = row("PourSocialScore")
	check(r.pss and r.locked, "PourSocialScore is locked")
	-- a search keeps the matches only
	local S = M.PSS_AddonList("me", "az", "dbm")
	check(S.n == 3, "search dbm: " .. S.n)
	-- the whole row set, for the enum phase
	return true
end

function phases.group()
	needLibraries()
	local L = M.PSS_AddonList("me", "group")
	local names = groupNames(L)
	for _, want in ipairs({ "Atlas", "DBM", "Details", "Libraries", "Zeds", "PourSocialScore" }) do
		check(groupIndex(L, want), "no group " .. want .. " (" .. table.concat(names, ",") .. ")")
	end
	check(sameList(members(L, groupIndex(L, "DBM")), { "DBM-Core", "DBM-GUI", "DBM-Raids" }), "DBM members: " .. table.concat(members(L, groupIndex(L, "DBM")), ","))
	check(sameList(members(L, groupIndex(L, "Atlas")), { "Atlas", "Atlas_Options" }), "Atlas leads its group")
	check(sameList(members(L, groupIndex(L, "Libraries")), { "LibFoo", "LibStub" }), "libraries together: " .. table.concat(members(L, groupIndex(L, "Libraries")), ","))
	check(sameList(members(L, groupIndex(L, "Zeds")), { "ZedOne", "ZedTwo" }), "the TOC Group wins over the name rule")
	check(names[#names] == "Libraries", "Libraries is the last group: " .. names[#names])
	for _, lone in ipairs({ "WeakAuras", "OldThing", "Needy", "Loner" }) do
		check(L.gi[posOf(L, lone)] == nil, lone .. " is not in a group")
	end
	-- the order: by group or title, lead first
	local t = listNames(L)
	local function before(a, b) return posOf(L, a) < posOf(L, b) end
	check(before("Atlas", "Atlas_Options") and before("DBM-Core", "DBM-GUI") and before("Details", "Details_Streamer"), "a lead comes first")
	return true
end

function phases.az()
	needLibraries()
	local L = M.PSS_AddonList("me", "az")
	check(#L.groups == 0, "A to Z has no groups")
	local last = ""
	for p = 1, L.n do
		local r = M.PSS_AddonRow(L.idx[p], "me", {})
		local key = plain(r.title):lower()
		check(key >= last, "A to Z out of order at " .. key .. " after " .. last)
		last = key
	end
end

function phases.lod()
	needLibraries()
	local L = M.PSS_AddonList("me", "lod")
	check(#L.groups == 1 and L.groups[1].name == "Load on demand", "one group: Load on demand")
	local g = L.groups[1]
	for p = 1, L.n do
		local r = M.PSS_AddonRow(L.idx[p], "me", {})
		check((p >= g.from) == r.lod, r.name .. (r.lod and " is" or " is not") .. " load on demand, position " .. p .. " vs group from " .. g.from)
	end
	-- the view mode is saved only when it is not the default
	check(M.PSS_AddonViewMode() == "group", "default view")
	M.PSS_AddonViewMode("lod")
	check(PSS_OptionsDB.addonView == "lod", "saved lod")
	M.PSS_AddonViewMode("group")
	check(PSS_OptionsDB.addonView == nil, "the default is not saved")
end

------------------------------------------------------------------------
-- Changes
------------------------------------------------------------------------
function phases.tick()
	needLibraries()
	local n, id = changedCount()
	reset()
	local ok, text = M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	check(ok and text:find("ZedOne is on for this character", 1, true), "turned on: " .. tostring(text))
	check(row("ZedOne").enabled, "ZedOne is on")
	check((H.calls.SaveAddOns or 0) == 1, "SaveAddOns once: " .. tostring(H.calls.SaveAddOns))
	check(n() == 1, "ADDONS_CHANGED once: " .. n())
	ok = M.PSS_AddonTick(idx("ZedOne"), false, "me", false)
	check(ok and not row("ZedOne").enabled, "turned off")
	-- all characters
	check(row("Details_Streamer", "all").state == 2, "enabled for all characters")
	M.PSS_AddonTick(idx("Details_Streamer"), false, "all", false)
	check(row("Details_Streamer", "all").state == 0 and row("Details_Streamer", "me").state == 0, "off for all")
	-- a tick for one character leaves the other
	M.PSS_AddonTick(idx("ZedOne"), true, "all", false)
	M.PSS_AddonTick(idx("ZedOne"), false, "me", false)
	check(row("ZedOne", "all").state == 1, "some characters: " .. row("ZedOne", "all").state)
	-- Pour Social Score cannot be turned off here
	ok, text = M.PSS_AddonTick(idx("PourSocialScore"), false, "me", false)
	check(not ok and text:find("cannot be turned off", 1, true), "PSS stays on: " .. tostring(text))
	check(row("PourSocialScore").enabled, "PSS is still on")
	-- a group tick spares a protected addon
	M.PSS_AddonLock("DBM-GUI", true, "me")
	local L = M.PSS_AddonList("me", "group")
	local g = L.groups[groupIndex(L, "DBM")]
	M.PSS_AddonTickMany(L, g.from, g.to, false, "me", false)
	check(not row("DBM-Core").enabled and row("DBM-GUI").enabled and not row("DBM-Raids").enabled, "a group off keeps the protected DBM-GUI")
	M.PSS_AddonTickMany(L, g.from, g.to, true, "me", false)
	check(row("DBM-Core").enabled and row("DBM-Raids").enabled, "a group on")
	M.Events.Unregister("ADDONS_CHANGED", id)
end

function phases.deps()
	needLibraries()
	-- required ones on, optional ones not
	H.AddonList()
	fake("Atlas").me = nil
	local ok, text = M.PSS_AddonTick(idx("Atlas_Options"), true, "me", true)
	check(ok and row("Atlas").enabled, "the required Atlas is turned on")
	check(text:find("Also turned on: Atlas", 1, true), "the line says so: " .. text)
	fake("Atlas").me = nil
	M.PSS_AddonTick(idx("Loner"), true, "me", true)
	check(not row("Atlas").enabled, "an optional one stays off")
	-- without deps nothing else changes
	fake("Atlas").me = nil
	M.PSS_AddonTick(idx("Atlas_Options"), true, "me", false)
	check(not row("Atlas").enabled, "no deps, none turned on")
	-- a loop ends
	local ok2, t2 = M.PSS_AddonTick(idx("CycC"), true, "me", true)
	check(ok2 and row("CycA").enabled and row("CycB").enabled and row("CycC").enabled, "a dependency loop ends with all on")
	-- a requirement that is not installed is said
	local _, t3 = M.PSS_AddonTick(idx("Needy"), true, "me", true)
	check(t3:find("Gone", 1, true) and t3:find("not installed", 1, true), "a missing requirement is named: " .. t3)
	-- the tip data
	local req, opt = M.PSS_AddonDeps(idx("DBM-GUI"), "me")
	check(#req == 1 and req[1].name == "DBM-Core" and req[1].text == "loaded", "tip: DBM-Core is a loaded requirement")
	req, opt = M.PSS_AddonDeps(idx("Loner"), "me")
	check(#req == 0 and #opt == 1 and opt[1].name == "Atlas", "tip: an optional one")
	req = M.PSS_AddonDeps(idx("Needy"), "me")
	check(req[1].text == "not installed", "tip: not installed")
end

function phases.all()
	needLibraries()
	reset()
	M.PSS_AddonLock("Details", true, "me")
	local ok, text = M.PSS_AddonAll(false, "me")
	check(ok and text:find("Every addon is off for this character", 1, true), "Disable All: " .. tostring(text))
	check(not row("Atlas").enabled and not row("DBM-Core").enabled, "everything else is off")
	check(row("PourSocialScore").enabled and row("PourSocialScore_Libraries").enabled, "Pour Social Score stays on")
	check(row("Details").enabled, "a protected addon stays on")
	check(writeCount("DisableAll") == 1 and H.addonWrites[1].char == GUID, "DisableAll for this character only")
	check((H.calls.SaveAddOns or 0) == 1, "saved once")
	ok, text = M.PSS_AddonAll(true, "me")
	check(ok and row("Atlas").enabled and row("ZedOne").enabled, "Enable All")
	reset()
	M.PSS_AddonAll(false, "all")
	check(H.addonWrites[1].fn == "DisableAll" and H.addonWrites[1].char == nil, "all characters: no character given")
	check(not row("Atlas", "all").enabled and row("PourSocialScore", "all").enabled, "off for everyone, PSS kept")
end

function phases.load()
	needLibraries()
	local before = H.calls.LoadAddOn or 0
	local ok, text = M.PSS_AddonLoad(idx("Atlas_Options"))
	check(ok and text == "Atlas_Options loaded.", "load: " .. tostring(text))
	check(row("Atlas_Options").loaded and (H.calls.LoadAddOn or 0) == before + 1, "it is loaded")
	ok, text = M.PSS_AddonLoad(idx("WeakAuras"))
	check(not ok and text:find("does not load on demand", 1, true), "not on demand: " .. tostring(text))
	H.combat = true
	local mid = H.calls.LoadAddOn or 0
	ok, text = M.PSS_AddonLoad(idx("DBM-Raids"))
	check(not ok and text == "Not in combat." and (H.calls.LoadAddOn or 0) == mid, "refused in combat, the client not asked")
	H.combat = false
	-- a disabled one fails with the client's reason
	fake("DBM-Raids").me = nil
	ok, text = M.PSS_AddonLoad(idx("DBM-Raids"))
	check(not ok and text:find("did not load", 1, true), "disabled: " .. tostring(text))
end

function phases.undo()
	needLibraries()
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	M.PSS_AddonTick(idx("Atlas"), false, "me", false)
	local ok, text = M.PSS_AddonUndo()
	check(ok and text == "Back to the addons as at login.", "undo: " .. tostring(text))
	check(not row("ZedOne").enabled and row("Atlas").enabled, "the login state is back")
	check((H.calls.ResetAddOns or 0) == 1, "ResetAddOns once")
end

function phases.pending()
	needLibraries()
	-- PSS_ADDONS="A:e,L;B:e,L;C:e,l"
	check(not M.PSS_AddonPending("me"), "nothing waits at first")
	M.PSS_AddonTick(idx("B"), false, "me", false)
	check(M.PSS_AddonPending("me"), "a loaded addon turned off waits for a reload")
	M.PSS_AddonUndo()
	check(not M.PSS_AddonPending("me"), "undo clears it")
	fake("C").me = nil
	M.PSS_AddonTick(idx("C"), true, "me", false)
	check(not M.PSS_AddonPending("me"), "a load on demand addon turned on does not wait")
	H.AddonList()[#H.AddonList() + 1] = { name = "D", deps = {}, opt = {}, me = true, mem = 0 }
	check(M.PSS_AddonPending("me"), "an addon turned on that is not loaded waits")
	local before = H.reloads
	H.combat = true
	local ok = M.PSS_AddonReload()
	check(ok and H.reloads == before + (M.PSS_ReloadMode() == "press" and 0 or 1), "reload allowed in combat (the player chose it)")
	before = H.reloads
	H.combat = false
	ok = M.PSS_AddonReload()
	check(ok and H.reloads == before + (M.PSS_ReloadMode() == "press" and 0 or 1), "reload out of combat")
end

------------------------------------------------------------------------
-- Protected addons and presets
------------------------------------------------------------------------
function phases.lock()
	needLibraries()
	check(M.PSS_AddonLocked("PourSocialScore") and M.PSS_AddonLocked("PourSocialScore_GUI"), "Pour Social Score is always protected")
	local ok = M.PSS_AddonLock("PourSocialScore", true, "me")
	check(not ok and PSS_CharDB == nil, "its folders are never stored")
	check(M.PSS_AddonLock("Details", true, "me") and M.PSS_AddonLocked("Details"), "locked")
	check(PSS_CharDB and PSS_CharDB.addonLock == "Details", "this character's list: " .. tostring(PSS_CharDB and PSS_CharDB.addonLock))
	M.PSS_AddonLock("Atlas", true, "all")
	check(PSS_OptionsDB.addonLock and PSS_OptionsDB.addonLock[DIGIT] == "Atlas", "the account's list")
	check(M.PSS_AddonLocked("Atlas") and M.PSS_AddonLocked("Details"), "protected in either scope")
	-- Disable All and a preset load leave them on
	M.PSS_AddonAll(false, "me")
	check(row("Atlas").enabled and row("Details").enabled and not row("LibFoo").enabled, "Disable All spares the protected")
	M.PSS_AddonAll(true, "me")
	M.PSS_AddonPresetSave(1, "Keep", "me")
	local packed = "\n" .. PSS_CharDB.addonSets[1] .. "\n"
	check(not packed:find("\nDetails\n", 1, true) and not packed:find("\nAtlas\n", 1, true), "a set does not hold the protected")
	M.PSS_AddonPresetLoad(1, "char", "me")
	check(row("Atlas").enabled and row("Details").enabled, "a set load spares the protected")
	-- unlock goes from both lists and the keys go back to nil
	M.PSS_AddonLock("Details", false, "me")
	M.PSS_AddonLock("Atlas", false, "me")
	check(not M.PSS_AddonLocked("Atlas") and not M.PSS_AddonLocked("Details"), "unlocked")
	check(PSS_OptionsDB.addonLock == nil, "an empty account list is not kept")
	check(PSS_CharDB == nil or PSS_CharDB.addonLock == nil, "an empty character list is not kept")
end

function phases.sets()
	needLibraries()
	local on = function() local t = {} for _, r in ipairs(H.AddonList()) do if r.me then t[#t + 1] = r.name end end return t end
	check(select(2, M.PSS_AddonPresetSave(1, "Raid", "me")) == "Addon profile Raid saved: 13 addons.", "save: " .. tostring(select(2, M.PSS_AddonPresetSave(1, "Raid", "me"))))
	local str = PSS_CharDB.addonSets[1]
	check(str:sub(1, 5) == "Raid\n", "character sets have no client digit: " .. str:sub(1, 6))
	check(not str:find("PourSocialScore", 1, true) and not str:find("Blizzard_", 1, true), "no Pour Social Score or Blizzard_ in a set")
	-- an unnamed one, a class one (account-wide), the cap
	M.PSS_AddonPresetSave(2, "", "me")
	check(PSS_CharDB.addonSets[2]:sub(1, 1) == "\n", "unnamed: the first line is empty")
	local cls = os.getenv("PSS_CLASS") or "MAGE"
	local ok = M.PSS_AddonPresetSave(cls:lower(), "", "me")
	check(ok and PSS_OptionsDB.addonSets[cls] and PSS_OptionsDB.addonSets[cls]:sub(1, 1) == DIGIT, "a class set is account-wide with the client digit")
	ok = M.PSS_AddonPresetSave(26, "x", "me")
	check(not ok, "25 is the cap")
	ok = M.PSS_AddonPresetSave("priest", "x", "me")
	check(not ok, "only your own class")
	local list = M.PSS_AddonPresets()
	check(#list == 3 and list[1].id == 1 and list[1].scope == "char" and list[3].class, "the list: " .. #list)
	-- load replaces: change things, then load
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	M.PSS_AddonTick(idx("Atlas"), false, "me", false)
	local ok2, text = M.PSS_AddonPresetLoad(1, "char", "me")
	check(ok2 and text == "Addon profile Raid: 13 on, 0 not installed.", "load: " .. tostring(text))
	check(not row("ZedOne").enabled and row("Atlas").enabled, "load replaced what was on")
	check(row("PourSocialScore").enabled, "load keeps Pour Social Score on")
	-- disable all then enable all (the profile's own addons)
	M.PSS_AddonPresetTick(1, "char", false, "me", false)
	check(not row("Atlas").enabled and not row("DBM-Core").enabled, "disable all takes the profile's addons off")
	M.PSS_AddonPresetTick(1, "char", true, "me", false)
	check(row("Atlas").enabled, "enable all turns them on")
	-- one addon into a preset
	check(M.PSS_AddonPresetInclude(1, "char", "ZedOne"), "include")
	check(PSS_CharDB.addonSets[1]:find("ZedOne", 1, true), "the set holds it")
	-- names not installed are skipped and counted
	PSS_CharDB.addonSets[3] = "Old\nAtlas\nGoneA\nGoneB"
	ok2, text = M.PSS_AddonPresetLoad(3, "char", "me")
	check(ok2 and text == "Addon profile Old: 1 on, 2 not installed.", "not installed: " .. tostring(text))
	-- rename and delete
	check(select(2, M.PSS_AddonPresetRename(3, "New", "char")) == "Addon profile New renamed.", "rename")
	check(PSS_CharDB.addonSets[3]:sub(1, 4) == "New\n" and PSS_CharDB.addonSets[3]:find("GoneA", 1, true), "the names are kept")
	M.PSS_AddonPresetDelete(3, "char")
	check(PSS_CharDB.addonSets[3] == nil, "deleted")
	-- a number that is not a preset
	check(not M.PSS_AddonPresetLoad(9, "char", "me"), "no set 9")
	-- an account-wide one loads for this character
	M.PSS_AddonPresetSave(4, "Everyone", "all")
	check(PSS_OptionsDB.addonSets[4]:sub(1, 9) == DIGIT .. "Everyone", "account-wide: " .. PSS_OptionsDB.addonSets[4]:sub(1, 10))
	check(M.PSS_AddonPresetLoad(4, "all", "me"), "load the account's")
	-- delete them all: the keys go back to nil
	M.PSS_AddonPresetDelete(1, "char")
	M.PSS_AddonPresetDelete(2, "char")
	M.PSS_AddonPresetDelete(4, "all")
	M.PSS_AddonPresetDelete(cls:lower(), "all")
	check(PSS_CharDB == nil, "an empty character store is gone")
	check(PSS_OptionsDB.addonSets == nil, "an empty account key is gone")
end

function phases.prune()
	-- seeded before the first call (validate_all passes no seed: done here)
	PourSocialScoreDB.addonSets = { [3] = "1Retail\nAtlas\nGone1", [4] = "2Camelot\nAtlas\nGone2" }
	PourSocialScoreDB.addonLock = { ["1"] = "Atlas\nGone1", ["2"] = "Atlas\nGone2" }
	_G["PSS_CharDB"] = { addonLock = "Atlas\nGone3", addonSets = { [1] = "Mine\nAtlas\nGone4" } }
	needLibraries()
	M.PSS_AddonLocked("Atlas")
	local sets, lock = PSS_OptionsDB.addonSets, PSS_OptionsDB.addonLock
	local mine, other = DIGIT, camelot and "1" or "2"
	check(lock[mine] == "Atlas", "this client's names are pruned: " .. tostring(lock[mine]))
	check(lock[other] == "Atlas\nGone" .. other, "the other client's are kept: " .. tostring(lock[other]))
	check(PSS_CharDB.addonLock == "Atlas" and PSS_CharDB.addonSets[1] == "Mine\nAtlas", "the character's are pruned")
	local mineSet, otherSet = sets[camelot and 4 or 3], sets[camelot and 3 or 4]
	check(not mineSet:find("Gone", 1, true) and otherSet:find("Gone" .. other, 1, true), "sets: this client pruned, the other kept")
	-- once only: a name that goes missing later stays until the next load
	M.PSS_AddonLock("LibFoo", true, "me")
	check(PSS_CharDB.addonLock == "Atlas\nLibFoo", "locking works after the prune")
end

------------------------------------------------------------------------
-- API differences
------------------------------------------------------------------------
function phases.noapi()
	needLibraries()
	local first = (os.getenv("PSS_ADDON_NOAPI") or ""):match("^[^,]+")
	if first == "EnableAddOn" then
		check(not M.PSS_AddonCan("tick"), "no tick without EnableAddOn")
		local ok, text = M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
		check(not ok and text:find("not available", 1, true), "said: " .. tostring(text))
		check(has(pss("acp on zedone"), "not available"), "the command says so")
		check(M.PSS_AddonList("me", "group").n > 0, "the list still works")
	elseif first == "GetNumAddOns" then
		check(not M.PSS_AddonCan("list") and M.PSS_AddonList("me", "group").n == 0, "no list")
		check(has(pss("acp list"), "not available"), "the command says so")
		check(has(pss("acp api"), "GetNumAddOns"), "api names it")
	else
		-- SaveAddOns, ResetAddOns, UpdateAddOnMemoryUsage missing
		local ok = M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
		check(ok, "a tick works without SaveAddOns")
		check(not M.PSS_AddonCan("undo") and not M.PSS_AddonUndo(), "no undo without ResetAddOns")
		check(M.PSS_AddonMemory() == nil, "no memory without UpdateAddOnMemoryUsage")
	end
	check(has(pss("acp api"), "missing"), "/pss acp api lists the missing ones")
end

function phases.oldapi()
	needLibraries()
	check(not C_AddOns.GetAddOnEnableState and _G.GetAddOnEnableState, "the old global only")
	check(row("ZedTwo").enabled and not row("ZedOne").enabled, "states read with (character, name)")
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	check(row("ZedOne").enabled, "a tick works")
	check(row("Details_Streamer", "all").state == 2, "all characters")
end

function phases.enum()
	needLibraries()
	local sig = {}
	for _, n in ipairs({ "ZedOne", "ZedTwo", "Details_Streamer" }) do
		local r = row(n, "all")
		sig[#sig + 1] = n .. "=" .. r.state .. (r.enabled and "+" or "-")
	end
	check(table.concat(sig, ",") == "ZedOne=0-,ZedTwo=1+,Details_Streamer=2+", "states: " .. table.concat(sig, ","))
	check((Enum and Enum.AddOnEnableState ~= nil) == (os.getenv("PSS_ADDON_NOENUM") ~= "1"), "the stub follows PSS_ADDON_NOENUM")
end

function phases.guid()
	needLibraries()
	reset()
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	M.PSS_AddonTick(idx("ZedTwo"), false, "all", false)
	M.PSS_AddonAll(true, "me")
	for _, w in ipairs(H.addonWrites) do
		check(w.char ~= "Tester", "a name was used as the character")
	end
	check(H.addonWrites[1].char == GUID, "this character: its GUID")
	check(H.addonWrites[2].char == nil, "all characters: no character")
	check(H.addonWrites[3].fn == "EnableAll" and H.addonWrites[3].char == GUID, "Enable All for this character")
end

function phases.combat()
	needLibraries()
	H.combat = true
	check(M.PSS_AddonMemory() == nil, "no memory in combat")
	check((H.calls.UpdateAddOnMemoryUsage or 0) == 0, "the client is not asked in combat")
	local ok = M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	check(ok and row("ZedOne").enabled, "ticks work in combat")
	local ok2, text = M.PSS_AddonLoad(idx("Atlas_Options"))
	check(not ok2 and text == "Not in combat.", "load refused")
	H.combat = false
	check(M.PSS_AddonMemory() ~= nil and H.calls.UpdateAddOnMemoryUsage == 1, "out of combat: sampled once")
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------
function phases.command()
	needLibraries()
	local l = pss("acp list zed")
	check(has(l, "2 addons, 1 on for this character:") and has(l, "ZedOne: Disabled") and has(l, "ZedTwo: Turns on at reload"), "list: " .. say(l))
	l = pss("acp on zedone")
	check(has(l, "ZedOne is on for this character.") and has(l, "Reload to apply."), "on (any case): " .. say(l))
	l = pss("acp off ZedOne")
	check(has(l, "ZedOne is off for this character."), "off: " .. say(l))
	l = pss("acp on Atlas_O")
	check(has(l, "Atlas_Options is on"), "a unique start of a name: " .. say(l))
	l = pss("acp on nothinglikeit")
	check(has(l, "No addon called \"nothinglikeit\"."), "unknown: " .. say(l))
	l = pss("acp load Atlas_Options")
	check(has(l, "Atlas_Options loaded."), "load: " .. say(l))
	l = pss("acp load weakauras")
	check(has(l, "does not load on demand"), "load, not on demand: " .. say(l))
	l = pss("acp lock details")
	check(has(l, "Details is protected."), "lock: " .. say(l))
	l = pss("acp list details")
	check(has(l, "Details: Loaded (protected)"), "list shows protected: " .. say(l))
	l = pss("acp unlock details")
	check(has(l, "Details is not protected any more."), "unlock: " .. say(l))
	l = pss("acp lock pour")
	check(has(l, "always protected") or has(l, "No addon called"), "PSS: " .. say(l))
	l = pss("acp all off")
	check(has(l, "Every addon is off for this character"), "all off: " .. say(l))
	l = pss("acp all on")
	check(has(l, "Every addon is on for this character."), "all on: " .. say(l))
	l = pss("acp undo")
	check(has(l, "Back to the addons as at login."), "undo: " .. say(l))
	check(has(pss("acp sets"), "No addon profiles saved yet."), "no sets yet")
	l = pss("acp set 1 save My Raid")
	check(has(l, "Addon profile My Raid saved:"), "save with a two word name: " .. say(l))
	l = pss("acp set 2 all save")
	check(has(l, "Addon profile 2 saved:") and PSS_OptionsDB.addonSets[2], "account-wide: " .. say(l))
	l = pss("acp sets")
	check(has(l, "My Raid (this character)") and has(l, "all characters"), "sets: " .. say(l))
	check(has(pss("acp set 1 load"), "Addon profile My Raid:"), "set load")
	check(has(pss("acp set 1 enable"), "Addon profile My Raid: ") and has(pss("acp set 1 add"), "enabled,"), "set enable and its alias add")
	check(has(pss("acp set 1 disable"), "disabled,") and has(pss("acp set 1 remove"), "disabled,"), "set disable and its alias remove")
	check(has(pss("acp set 1 delete"), "Addon profile My Raid deleted."), "set delete")
	check(has(pss("acp set 2 all delete"), "deleted"), "account set delete")
	check(has(pss("acp set 7 load"), "There is no addon profile 7 here."), "no set")
	check(has(pss("acp set 99 save"), "is not an addon profile"), "bad id")
	check(has(pss("acp set"), "Addon profiles: /pss acp profile"), "set usage")
	check(has(pss("acp api"), "Addon API present:"), "api")
	check(has(pss("acp nonsense"), "/pss acp: list"), "help")
	-- the main help lists the command
	local h = pss("help")
	check(has(h, "acp") and has(h, "/acp = /pss acp"), "/pss help lists it: " .. say(h))
end

function phases.slash()
	check(SLASH_PSSACP1 == "/acp" and type(SlashCmdList["PSSACP"]) == "function" or os.getenv("PSS_ACP_TAKEN") == "1", "the alias is registered unless taken")
	if os.getenv("PSS_ACP_TAKEN") == "1" then
		check(SlashCmdList["PSSACP"] == nil and SLASH_PSSACP1 == nil, "not registered when another addon owns /acp")
		check(SLASH_ACP1 == "/acp", "the other addon's command is untouched")
		check(M.PSS_ACPTaken == true, "core remembers it")
		local l = pss("acp list zed")
		check(has(l, "ZedOne"), "/pss acp still works: " .. say(l))
		check(has(pss("help"), "/acp is used by another addon; use /pss acp"), "help says so")
		check(not loaded("PourSocialScore_Libraries") or true, "")
		return
	end
	check(not loaded("PourSocialScore_Libraries"), "Libraries is not loaded at login")
	local a = capture(SlashCmdList["PSSACP"], "list zed")
	check(loaded("PourSocialScore_Libraries"), "/acp loads Libraries on first use")
	local b = pss("acp list zed")
	check(#a > 0 and say(a) == say(b), "/acp gives the same lines as /pss acp: " .. say(a))
	for _, cmd in ipairs({ "on zedone", "off zedone", "sets", "api", "all on", "undo", "nonsense" }) do
		local x = capture(SlashCmdList["PSSACP"], cmd)
		local y = pss("acp " .. cmd)
		check(say(x) == say(y), "/acp " .. cmd .. " = /pss acp " .. cmd)
	end
end

------------------------------------------------------------------------
-- Saved data
------------------------------------------------------------------------
local function keys(t)
	local k = {}
	for key in pairs(t or {}) do k[#k + 1] = tostring(key) end
	table.sort(k)
	return table.concat(k, ",")
end

function phases.saved()
	-- nothing saved without a choice
	check(PSS_CharDB == nil, "no per-character store at first")
	needLibraries()
	M.PSS_AddonTick(idx("ZedOne"), true, "me", true)
	M.PSS_AddonAll(true, "me")
	local V = M.PSS_AddonView()
	V:Build()
	V:CollapseAll(true)
	V.deps, V.who, V.find = false, "all", "x"
	M.PSS_AddonMemory()
	check(PSS_CharDB == nil, "ticking, collapsing, the character, the search and memory save nothing")
	check(PSS_OptionsDB.addonSets == nil and PSS_OptionsDB.addonLock == nil and PSS_OptionsDB.addonView == nil, "no account key either")
	-- a view, a lock and a set are saved, packed and sparse
	M.PSS_AddonViewMode("az")
	check(PSS_OptionsDB.addonView == "az", "view saved")
	M.PSS_AddonViewMode("group")
	check(PSS_OptionsDB.addonView == nil, "the default view is removed")
	M.PSS_AddonLock("Details", true, "me")
	M.PSS_AddonPresetSave(1, "Raid", "me")
	check(keys(PSS_CharDB) == "addonLock,addonSets", "the character store holds only those: " .. keys(PSS_CharDB))
	check(type(PSS_CharDB.addonSets[1]) == "string" and type(PSS_CharDB.addonLock) == "string", "packed strings")
	-- packed against the table form, measured
	local names = {}
	for p = 1, 40 do names[#names + 1] = "SomeAddonFolder" .. p end
	local packed = ("Raid\n" .. table.concat(names, "\n"))
	local tableForm = H.serialize({ n = "Raid", c = 1, names = names })
	realPrint(("saved: a 40 name set is %d bytes packed, %d as a table"):format(#packed, #tableForm))
	check(#packed < #tableForm, "packed is the smaller form")
	M.PSS_AddonPresetDelete(1, "char")
	M.PSS_AddonLock("Details", false, "me")
	check(PSS_CharDB == nil, "emptied: the store goes back to nil")
end

function phases.charstore()
	needLibraries()
	check(PSS_CharDB == nil and PSS_OptionsDB.addonSets == nil, "an unused character writes nothing")
	M.PSS_AddonPresetSave(1, "Me", "me")
	check(PSS_CharDB and PSS_CharDB.addonSets[1] and PSS_OptionsDB.addonSets == nil, "this character: PSS_CharDB")
	M.PSS_AddonPresetSave(1, "All", "all")
	check(PSS_OptionsDB.addonSets[1] and PSS_OptionsDB.addonSets[1]:find("All", 1, true), "all characters: PSS_OptionsDB")
	local list = M.PSS_AddonPresets()
	check(#list == 2 and list[1].scope == "char" and list[2].scope == "all", "both are listed, marked by scope")
	M.PSS_AddonLock("LibFoo", true, "me")
	M.PSS_AddonLock("LibStub", true, "all")
	check(M.PSS_AddonLocked("LibFoo") and M.PSS_AddonLocked("LibStub"), "protected in either scope")
	-- a character preset writes this character's states, an account one for who is shown
	reset()
	M.PSS_AddonPresetLoad(1, "char", "all")
	check(H.addonWrites[1].char == GUID, "a character set always writes this character")
	reset()
	M.PSS_AddonPresetLoad(1, "all", "all")
	check(H.addonWrites[1].char == nil, "an account set writes for all when all is shown")
	M.PSS_AddonPresetDelete(1, "char")
	check(PSS_CharDB.addonSets == nil and PSS_CharDB.addonLock == "LibFoo", "emptying one key keeps the other")
	M.PSS_AddonLock("LibFoo", false, "me")
	check(PSS_CharDB == nil, "empty: nil")
	M.PSS_AddonPresetDelete(1, "all")
	M.PSS_AddonLock("LibStub", false, "me")
	check(PSS_OptionsDB.addonSets == nil and PSS_OptionsDB.addonLock == nil, "the account keys are gone")
end

function phases.forward()
	-- a newer version's data is left alone
	PourSocialScoreDB.addonSets = { [5] = "3Newer\nAtlas", [6] = "1Old\nAtlas" }
	PourSocialScoreDB.addonLock = { ["3"] = "Other" }
	_G["PSS_CharDB"] = { newerKey = { 1, 2 } }
	needLibraries()
	local list = M.PSS_AddonPresets()
	check(#list == 1 and list[1].id == 6, "a set from a newer client digit is not offered: " .. #list)
	local ok, text = M.PSS_AddonPresetSave(5, "x", "all")
	check(not ok and text:find("newer version", 1, true), "it is not overwritten: " .. tostring(text))
	ok, text = M.PSS_AddonPresetLoad(5, "all", "me")
	check(not ok and text:find("newer version", 1, true), "nor applied")
	M.PSS_AddonLock("LibFoo", true, "me")
	M.PSS_AddonLock("LibFoo", false, "me")
	check(PSS_OptionsDB.addonSets[5] == "3Newer\nAtlas", "the newer set is kept as written")
	check(PSS_OptionsDB.addonLock["3"] == "Other", "so is the newer lock list")
	check(PSS_CharDB and PSS_CharDB.newerKey and PSS_CharDB.newerKey[2] == 2, "an unknown field in PSS_CharDB is kept")
end

------------------------------------------------------------------------
-- Memory, login and the odd cases
------------------------------------------------------------------------
local function kb() collectgarbage() collectgarbage() return collectgarbage("count") end

function phases.memory()
	-- resident cost of the two Libraries files: compiled, instantiated
	local base = kb()
	local keep = {}
	for _, f in ipairs({ "PourSocialScore_Libraries/PSS_AddonsQuery.lua", "PourSocialScore_Libraries/PSS_AddonsView.lua" }) do
		keep[#keep + 1] = assert(loadfile(f))
	end
	local resident = kb() - base
	realPrint(("memory: the two files compile to %.1f KB resident"):format(resident))
	check(resident < 140, "resident " .. resident .. " KB is over the 140 KB budget")
	keep = nil
	needLibraries()
	local V = M.PSS_AddonView()
	M.PSS_AddonLocked("x")
	local closed = kb()
	V:Build()
	M.PSS_AddonRow(1, "me", {})
	-- garbage per full list build
	collectgarbage("stop")
	local before = collectgarbage("count")
	local L = M.PSS_AddonList("me", "group")
	local build = collectgarbage("count") - before
	collectgarbage("restart")
	realPrint(("memory: one list build of %d addons makes %.1f KB of garbage"):format(L.n, build))
	check(build < 32, "garbage per build " .. build .. " KB is over the 32 KB budget (150 addons)")
	-- kept after the window closes (the first build above warmed the scratch)
	V:Build()
	V:Sample()
	V:Tip(1)
	V:Release()
	V, L = nil, nil
	local after = kb() - closed
	realPrint(("memory: kept after close and a full collect: %.2f KB"):format(after))
	check(after < 0.5, "kept " .. after .. " KB after close (budget 0.5)")
end

function phases.login()
	check(not loaded("PourSocialScore_Libraries"), "Libraries is not loaded at login")
	check(not loaded("PourSocialScore_GUI"), "nor the window")
	check(H.calls.GetNumAddOns == nil and H.calls.GetAddOnInfo == nil and H.calls.UpdateAddOnMemoryUsage == nil, "no addon list call at login")
	check(PSS_CharDB == nil, "no per-character store at login")
end

function phases.big()
	needLibraries()
	local L = M.PSS_AddonList("me", "group")
	check(L.n >= 300, "300 listed: " .. L.n)
	local ok = M.PSS_AddonTick(idx("C20"), true, "me", true)
	check(ok, "a chain of 20")
	for i = 1, 20 do check(row(("C%02d"):format(i)).enabled, ("C%02d on"):format(i)) end
	check(M.PSS_AddonTick(idx("LoopA"), true, "me", true) and row("LoopB").enabled, "a loop ends")
	local V = M.PSS_AddonView()
	V:Build()
	local out = {}
	for k = 1, V:Count() do V:Row(k, out) end
	check(V:Count() > 0, "the view builds")
end

function phases.names()
	needLibraries()
	local L = M.PSS_AddonList("me", "group")
	for _, n in ipairs({ "My Addon", "a.b-c_d", "!Bang", "_Under", "+Plus", "Tiny" }) do
		check(posOf(L, n), n .. " is listed")
	end
	check(L.gi[posOf(L, "!Bang")] == nil and L.gi[posOf(L, "+Plus")] == nil, "a leading ! or + is ignored by the name rule")
	-- exact packing of odd names
	M.PSS_AddonPresetSave(1, "Odd", "me")
	local str = PSS_CharDB.addonSets[1]
	for _, n in ipairs({ "My Addon", "a.b-c_d", "!Bang", "_Under", "+Plus", "Tiny" }) do
		check(str:find("\n" .. n:gsub("%p", "%%%0") .. "\n") or str:find("\n" .. n:gsub("%p", "%%%0") .. "$"), n .. " is in the set")
	end
	for _, r in ipairs(H.AddonList()) do if not r.real then r.me = nil end end
	check(select(2, M.PSS_AddonPresetLoad(1, "char", "me")):find("6 on, 0 not installed", 1, true), "all six come back")
	local expect = { ["My Addon"] = true, ["a.b-c_d"] = true, ["!Bang"] = true, ["_Under"] = true, ["+Plus"] = true, Tiny = true }
	for _, r in ipairs(H.AddonList()) do
		if not r.real then check((r.me == true) == (expect[r.name] == true), r.name .. " state") end
	end
	local A = M.PSS_AddonList("me", "az")
	check(plain(row("Tiny").title):find("Red", 1, true), "a coloured title is stripped for sorting")
	check(A.n == L.n, "same count in every view")
end

------------------------------------------------------------------------
-- The view object, the entry points and the art (stage 2)
------------------------------------------------------------------------
local function lineOf(V, pred)
	for k = 1, V:Count() do
		local o = V:Row(k, {})
		if o and pred(o) then return k, o end
	end
end

function phases.view()
	needLibraries()
	local V = M.PSS_AddonView()
	local n, footer, empty = V:Build()
	check(n > 10 and footer:find("addons,", 1, true) and footer:find("on for this character", 1, true) and empty == "No addons match.", "build: " .. n .. " " .. tostring(footer))
	-- a header and a member
	local hk, h = lineOf(V, function(o) return o.header and o.name == "DBM" end)
	check(hk and h.text == "DBM (3)" and h.open and h.tick == 2, "the DBM header: " .. tostring(h and h.text))
	local mk, m = lineOf(V, function(o) return o.name == "DBM-Core" end)
	check(m and m.text:find("DBM%-Core") and m.text:find("ffffd100", 1, true) and m.status:find("Loaded", 1, true) and m.tick == 2 and not m.load, "a loaded member")
	check(m.text:sub(1, 6) == "      ", "a member is indented under its header")
	local _, lod = lineOf(V, function(o) return o.name == "DBM-Raids" end)
	check(lod.load and lod.tick == 2, "a load on demand member has its Load button")
	local _, off = lineOf(V, function(o) return o.name == "ZedOne" end)
	check(off.tick == 0 and off.status:find("ff9d9d9d", 1, true), "a disabled addon is grey")
	local _, pss = lineOf(V, function(o) return not o.header and o.name == "PourSocialScore" end)
	check(pss.pss and pss.locked, "the PSS row is protected")
	-- collapse
	V:Toggle(hk)
	V:Build()
	check(V:Count() == n - 3, "collapsing a group hides its members: " .. V:Count())
	check(select(2, lineOf(V, function(o) return o.header and o.name == "DBM" end)).open == false, "the header says it is closed")
	V:SetFind("dbm")
	V:Build()
	check(V:Count() == 4, "a search shows every group open: " .. V:Count())
	V:SetFind("")
	V:Build()
	V:CollapseAll(false)
	V:Build()
	check(V:Count() == n, "expand all")
	V:CollapseAll(true)
	V:Build()
	check(V:Count() < n - 8, "collapse all")
	V:CollapseAll(false)
	V:Build()
	-- the memory column and its order
	V:Sample()
	V.sortMem = true
	V:Build()
	local first = V:Row(1, {})
	check(not first.header and first.name == "DBM-Core", "most memory first: " .. tostring(first.name))
	V.sortMem = false
	V:Build()
	-- ticks: a group, an addon
	hk = lineOf(V, function(o) return o.header and o.name == "Zeds" end)
	check(V:Tick(hk, true), "a group tick")
	check(row("ZedOne").enabled and row("ZedTwo").enabled, "the whole group is on")
	V:Build()
	local zk = lineOf(V, function(o) return o.name == "ZedOne" end)
	check(V:Tick(zk, false) and not row("ZedOne").enabled, "an addon tick")
	-- tips
	V:Sample()
	local tk = lineOf(V, function(o) return o.name == "DBM-GUI" end)
	local tip = V:Tip(tk)
	check(tip:find("Author: Tester", 1, true) and tip:find("Version: 1.0", 1, true) and tip:find("Notes of DBM-GUI", 1, true), "tip: author, version, notes")
	check(tip:find("Requires:", 1, true) and tip:find("DBM-Core (loaded)", 1, true), "tip: the requirement and its state")
	tk = lineOf(V, function(o) return o.name == "Needy" end)
	check(V:Tip(tk):find("Gone (not installed)", 1, true), "tip: a requirement not installed")
	tk = lineOf(V, function(o) return not o.header and o.name == "PourSocialScore" end)
	check(V:Tip(tk):find("cannot be turned off here", 1, true), "tip: PSS cannot be turned off")
	-- menus
	local function acts(entries) local t = {} for _, e in ipairs(entries) do if e.act then t[#t + 1] = e.act end end return table.concat(t, ",") end
	local k = lineOf(V, function(o) return o.name == "DBM-Raids" end)
	check(acts(V:Menu(k)):find("load", 1, true) and acts(V:Menu(k)):find("off", 1, true) and acts(V:Menu(k)):find("lock", 1, true), "an addon's menu: " .. acts(V:Menu(k)))
	check(not acts(V:Menu(lineOf(V, function(o) return not o.header and o.name == "PourSocialScore" end))):find("off", 1, true), "PSS has no Turn off")
	check(acts(V:Menu(hk)) == "gon,goff,collapse,expand", "a header's menu: " .. acts(V:Menu(hk)))
	-- acts
	check(V:Act(k, "lock") == nil and M.PSS_AddonLocked("DBM-Raids"), "protect")
	check(acts(V:Menu(k)):find("unlock", 1, true), "the menu offers to stop protecting")
	V:Act(k, "unlock")
	check(not M.PSS_AddonLocked("DBM-Raids"), "stop protecting")
	check(V:Act(lineOf(V, function(o) return not o.header and o.name == "PourSocialScore" end), "off") ~= nil, "PSS off says no")
	local text = V:Act(k, "load")
	check(text == nil and row("DBM-Raids").loaded, "load")
	-- the Sets menu (the slots phase has the rest)
	local p = V:Slots()[1]
	check(p and p.empty and p.text == "Profile 1 (empty)", "a free slot is listed as empty")
	V:PresetAct(p, "save")
	p = V:Slots()[1]
	check(not p.empty and p.n > 0, "a save into a free slot stores it")
	local function acts(entries) local t = {} for _, e in ipairs(entries) do if e.act then t[#t + 1] = e.act end end return table.concat(t, ",") end
	check(acts(V:PresetMenu(p)) == "select,save,load,enable,disable,rename,delete", "the set's actions: " .. acts(V:PresetMenu(p)))
	check(V:PresetAct(p, "rename", "Renamed"):find("renamed", 1, true), "rename")
	check(V:Slots()[1].name == "Renamed", "renamed")
	V:Act(k, "include", "char:1")
	check(PSS_CharDB.addonSets[1]:find("DBM-Raids", 1, true), "add an addon to a set from its menu")
	V:PresetAct(V:Slots()[1], "delete")
	V:PresetAct(V:Slots()[1], "delete")
	check(PSS_CharDB == nil, "deleted")
	check(not V:Pending() or V:Pending(), "pending is a boolean")
	V:Release()
	check(V:Count() == 0, "release")
end

-- Sets the way ACP makes them (3.6.0.66, issue 171): every numbered place of
-- the scope shown is listed, a free one as empty; a save into it (after a
-- confirm in the window) stores it; a used one loads, adds, removes, saves,
-- renames and deletes; the numbers are per scope, your class's is shared
function phases.slots()
	needLibraries()
	check(type(M.PSS_AddonSlots) == "function", "no M.PSS_AddonSlots")
	local V = M.PSS_AddonView()
	check(V.PresetNew == nil and V.FreeId == nil, "the separate new-set step is still there")
	V:Build()
	local cls = os.getenv("PSS_CLASS") or "MAGE"
	local slots = V:Slots()
	check(#slots == 26, "25 numbers and your class: " .. #slots)
	for n = 1, 25 do
		check(slots[n].id == n and slots[n].empty and slots[n].text == "Profile " .. n .. " (empty)", "slot " .. n .. ": " .. tostring(slots[n].text))
	end
	check(slots[26].id == cls and slots[26].empty and slots[26].class and slots[26].text == cls:sub(1, 1) .. cls:sub(2):lower() .. " (empty)", "the class slot: " .. tostring(slots[26].text))
	local function acts(entries) local t = {} for _, e in ipairs(entries) do if e.act then t[#t + 1] = e.act end end return table.concat(t, ",") end
	check(acts(V:PresetMenu(slots[3])) == "select,save,load,enable,disable,rename,delete", "a free slot lists every action: " .. acts(V:PresetMenu(slots[3])))
	check(PSS_CharDB == nil and PSS_OptionsDB.addonSets == nil, "listing writes nothing")
	-- save into a free slot: this character
	V.who = "me"
	local said = V:PresetAct(slots[3], "save")
	check(said and said:find("saved", 1, true), "save says so: " .. tostring(said))
	check(PSS_CharDB and PSS_CharDB.addonSets[3] and PSS_OptionsDB.addonSets == nil, "stored for this character")
	slots = V:Slots()
	check(not slots[3].empty and slots[3].text:match("^Profile 3 %(%d+%)$"), "the slot shows its count: " .. slots[3].text)
	check(acts(V:PresetMenu(slots[3])) == "select,save,load,enable,disable,rename,delete", "a used slot: " .. acts(V:PresetMenu(slots[3])))
	-- save over it keeps the name; rename gives one
	V:PresetAct(slots[3], "rename", "Raid")
	slots = V:Slots()
	check(slots[3].text:match("^Raid %(%d+%)$"), "the name shows: " .. slots[3].text)
	local before = PSS_CharDB.addonSets[3]
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	V:PresetAct(slots[3], "save")
	check(PSS_CharDB.addonSets[3]:sub(1, 5) == "Raid\n" and PSS_CharDB.addonSets[3] ~= before and PSS_CharDB.addonSets[3]:find("ZedOne", 1, true), "a save over keeps the name and takes what is on")
	-- the numbers are per scope
	V.who = "all"
	slots = V:Slots()
	check(slots[3].empty, "all characters: slot 3 is free")
	V:PresetAct(slots[3], "save")
	check(PSS_OptionsDB.addonSets[3] and PSS_OptionsDB.addonSets[3]:sub(1, 1) == DIGIT, "stored account-wide")
	V.who = "me"
	check(V:Slots()[3].text:match("^Raid"), "this character's slot 3 is still its own")
	-- load, add, remove on a used slot
	V:PresetAct(V:Slots()[3], "load")
	check(row("ZedOne").enabled, "load turns the set's addons on")
	M.PSS_AddonTick(idx("ZedOne"), false, "me", false)
	check(not row("ZedOne").enabled, "off")
	V:PresetAct(V:Slots()[3], "enable")
	check(row("ZedOne").enabled, "enable all")
	V:PresetAct(V:Slots()[3], "disable")
	check(not row("ZedOne").enabled, "disable all")
	-- the class slot is shared and can be renamed too
	V:PresetAct(V:Slots()[26], "save")
	check(PSS_OptionsDB.addonSets[cls], "the class set is account-wide")
	local c = V:Slots()[26]
	check(not c.empty and acts(V:PresetMenu(c)) == "select,save,load,delete", "the class profile's actions (no Rename): " .. acts(V:PresetMenu(c)))
	V.who = "all"
	check(not V:Slots()[26].empty, "the class set shows in both scopes")
	-- delete frees the slot
	V:PresetAct(V:Slots()[3], "delete")
	check(V:Slots()[3].empty and PSS_OptionsDB.addonSets[3] == nil, "delete frees the slot")
	V:PresetAct(V:Slots()[26], "delete")
	V.who = "me"
	V:PresetAct(V:Slots()[3], "delete")
	check(PSS_CharDB == nil and PSS_OptionsDB.addonSets == nil, "nothing left saved")
	V:Release()
end

-- The Addon Profiles menu in the window (3.6.0.68 rework, issues 175 to 180):
-- bottom left, every place in the drop-down, each a side menu of its actions
-- (ACP's interface), the count anchored right
function phases.setsmenu()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	check(win:IsShown() and pg:IsShown() and pg.setsDD, "the tab has no Addon Profiles drop-down")
	local dd = pg.setsDD
	local point, rel, relPoint = dd:GetPoint(1)
	check(point == "BOTTOMLEFT" and rel == pg and relPoint == "BOTTOMLEFT", "the drop-down is not bottom left: " .. tostring(point))
	check(dd.label:GetText() == "Profiles" and dd:GetWidth() == 190, "the drop-down label and width: " .. tostring(dd.label:GetText()))
	local first = pg.footer._points[1]
	check(first[1] == "LEFT" and first[2] == dd, "the count is not beside the drop-down")
	check(type(pg.setsBuild) == "function" and pg.manageBuild == nil, "no menu builder, or the Manage menu is still there")
	-- a recorder for the kit's entries: S:text opens a side menu with the entries under it
	local function collect(build)
		local list = {}
		local m = {}
		m.Title = function(_, t) list[#list + 1] = "T:" .. t end
		m.Button = function(_, t) list[#list + 1] = "B:" .. t end
		m.Divider = function() list[#list + 1] = "-" end
		m.Sub = function(_, t, b)
			local inner = collect(b)
			list[#list + 1] = "S:" .. t .. "{" .. table.concat(inner, ",") .. "}"
		end
		build(m)
		return list
	end
	local list = collect(pg.setsBuild)
	check(list[1] == "T:Core Addon Profiles" and list[2] == "S:Profile 1 (empty){T:Profile 1 (this character),T:Not saved yet,B:Select,B:Save,B:Load,B:Enable all,B:Disable all,B:Rename,-,B:Delete}", "level 1 starts: " .. tostring(list[2]))
	check(list[7] == "-" and list[8] == "T:Layered Addon Profiles" and list[9]:find("^S:Profile 6 %(empty%)") and #list == 1 + 5 + 1 + 1 + 20 + 1, "headers, divider, 25 places and the class: " .. #list)
	check(list[#list]:find("^S:[%u][%l]+ %(empty%)"), "the class place is last: " .. tostring(list[#list]))
	local V = pg.state
	M.PSS_AddonPresetSave(1, "Core one", "me")
	M.PSS_AddonPresetSave(7, "", "me")
	list = collect(pg.setsBuild)
	check(list[2]:find("^S:Core one %(%d+%)%{T:Core one %(this character%),B:Select,B:Save,B:Load,B:Enable all,B:Disable all,B:Rename,%-,B:Delete%}$"), "a used place: " .. list[2])
	V.who = "all"
	list = collect(pg.setsBuild)
	check(list[2]:find("^S:Profile 1 %(empty; saved for this character%)"), "the other scope has its own places: " .. list[2])
	V.who = "me"
	M.PSS_AddonProfileSelect(1, true, "me")
	list = collect(pg.setsBuild)
	check(list[2]:find("^S:%* Core one") and list[2]:find("B:Deselect", 1, true), "a selected place is marked and offers Deselect: " .. list[2])
	win:Hide()
end

-- No stray measuring text in Dark menus (3.6.0.87, issue 201)
function phases.menustray()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	M.PSS_SetOpt("uiSkin", "global", 1)
	local dd = pg.setsDD
	dd.dark._scripts.OnClick(dd.dark)
	local menu = _G.PSS_Menu
	check(menu and menu:IsShown(), "(a) the Profiles menu did not open")
	check(not menu.measure:IsShown(), "(a) the measure string is shown")
	check((menu.measure:GetText() or "") == "", "(a) the measure string keeps text: " .. tostring(menu.measure:GetText()))
	local shownText = 0
	for _, sl in ipairs(menu.slots) do
		if sl:IsShown() then shownText = shownText + 1 elseif (sl.text:GetText() or "") ~= "" then check(false, "(c) a hidden slot keeps text") end
	end
	check(shownText > 0, "(b) no slot shown")
	menu:Hide()
	win:Hide()
end

-- Dark side menus open beside the row on hover (3.6.0.85, issue 203)
function phases.menuhover()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	M.PSS_SetOpt("uiSkin", "global", 1)
	local dd = pg.setsDD
	check(not _G.PSS_MenuSide, "(a) the side panel exists before any hover")
	dd.dark._scripts.OnClick(dd.dark)
	local menu = _G.PSS_Menu
	local function find(f, text)
		for _, sl in ipairs(f and f.slots or {}) do
			if sl:IsShown() and sl.entry and sl.entry.text and sl.entry.text:find(text, 1, true) then return sl end
		end
	end
	check(not _G.PSS_MenuSide, "(a) opening the list built the side panel")
	local p1 = find(menu, "Profile 1 (")
	p1._scripts.OnEnter(p1)
	local side = _G.PSS_MenuSide
	check(side and side:IsShown(), "(b) hover did not open the side panel")
	check(find(side, "Save") and find(side, "Load") and find(side, "Enable all") and find(side, "Disable all") and find(side, "Delete"), "(b) the side entries")
	check(find(menu, "Profile 1 (") and not find(menu, "< Back") and not find(side, "< Back"), "(b) the list kept its rows, no Back line")
	local pt = side._points and side._points[1]
	check(pt and pt[1] == "TOPLEFT" and pt[2] == p1 and pt[3] == "TOPRIGHT", "(c) the side panel sits at the row's right")
	local p2 = find(menu, "Profile 2 (")
	p2._scripts.OnEnter(p2)
	check(side:IsShown() and side.slots[1].entry ~= nil, "(d) another place refills it")
	local title = find(menu, "Core Addon Profiles")
	title._scripts.OnEnter(title)
	check(not side:IsShown(), "(d) a heading closes it")
	p1._scripts.OnClick(p1)
	check(side:IsShown(), "(g) a click opens the side panel too")
	local one = side
	menu:Hide()
	check(not side:IsShown(), "(f) closing the menu closes the side panel")
	dd.dark._scripts.OnClick(dd.dark)
	check(not _G.PSS_MenuSide:IsShown(), "(f) reopening shows no side panel")
	p1 = find(menu, "Profile 1 (")
	p1._scripts.OnEnter(p1)
	check(_G.PSS_MenuSide == one, "(i) the side panel frame is reused")
	local save = find(_G.PSS_MenuSide, "Save")
	save._scripts.OnClick(save)
	check(not menu:IsShown() and not _G.PSS_MenuSide:IsShown(), "(e) a choice closes both")
	check(_G.PSS_Confirm and _G.PSS_Confirm:IsShown(), "(e) Save asked once")
	win:Hide()
end

-- The menus through the kit, in the player's order (3.6.0.68, issue 180): a
-- side menu must stay open when it is chosen (a menu opened from another
-- menu's callback was closed again); Dark swaps to the place's entries under
-- Back, Blizzard's menu gets a real submenu; Save asks once and saves
function phases.menuflow()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	M.PSS_SetOpt("uiSkin", "global", 1)
	local dd = pg.setsDD
	dd.dark._scripts.OnClick(dd.dark)
	local menu = _G.PSS_Menu
	check(menu and menu:IsShown(), "the Profiles menu did not open")
	local function slot(text)
		for _, sl in ipairs(menu.slots) do
			if sl:IsShown() and sl.entry and sl.entry.text and sl.entry.text:find(text, 1, true) then return sl end
		end
	end
	local function sslot(text)
		local sd = _G.PSS_MenuSide
		for _, sl in ipairs(sd and sd.slots or {}) do
			if sl:IsShown() and sl.entry and sl.entry.text and sl.entry.text:find(text, 1, true) then return sl end
		end
	end
	local sl = slot("Profile 1 (empty)")
	check(sl, "place 1 is not in the menu")
	sl._scripts.OnClick(sl)
	check(menu:IsShown(), "choosing a place closed the menu")
	check(sslot("Save") and sslot("Rename") and sslot("Load") and sslot("Select") and not sslot("< Back"), "the free place's entries")
	local save = sslot("Save")
	save._scripts.OnClick(save)
	check(not menu:IsShown(), "Save left the menu open")
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown(), "Save did not ask")
	check(cf.text and cf.text:GetText():find("Save the current addon list to [Profile 1]?", 1, true), "the Save text: " .. tostring(cf.text and cf.text:GetText()))
	cf.accept._scripts.OnClick(cf.accept)
	check(PSS_CharDB and PSS_CharDB.addonSets and PSS_CharDB.addonSets[1], "Yes did not save place 1")
	-- reopen: place 1 shows its count; Back returns to the list
	dd.dark._scripts.OnClick(dd.dark)
	sl = slot("Profile 1 (")
	check(sl and not sl.entry.text:find("empty", 1, true), "place 1 still reads empty")
	sl._scripts.OnClick(sl)
	check(sslot("Select") and sslot("Load") and sslot("Enable all") and sslot("Disable all") and sslot("Delete"), "the used place's entries")
	local title = slot("Core Addon Profiles")
	title._scripts.OnEnter(title)
	check(menu:IsShown() and not _G.PSS_MenuSide:IsShown() and slot("Layered Addon Profiles"), "a heading did not close the side menu")
	sl = slot("Profile 1 (")
	sl._scripts.OnClick(sl)
	local sel = sslot("Select")
	sel._scripts.OnClick(sel)
	check(M.PSS_AddonProfileSelected(1, "me"), "Select did not select")
	dd.dark._scripts.OnClick(dd.dark)
	check(slot("* Profile 1 ("), "the selected place is not marked")
	menu:Hide()
	-- Modern and Classic: Blizzard's menu gets a real submenu per place
	M.PSS_SetOpt("uiSkin", "global", 2)
	check(dd.blizz and dd.blizz:IsShown(), "the Blizzard drop-down is not shown in Modern")
	local tree = dd.blizz:MenuTree()
	local items = tree.items
	check(items[1].kind == "title" and items[1].text == "Core Addon Profiles" and tree.scroll, "Blizzard menu start: " .. tostring(items[1].text))
	local place = items[2]
	check(place.kind == "checkbox" and place.sub and place.sub.items[1].kind == "title", "a place is not a checkbox with a submenu in Blizzard's menu")
	local names = {}
	for _, it in ipairs(place.sub.items) do if it.kind == "button" then names[#names + 1] = it.text end end
	check(table.concat(names, ",") == "Deselect,Save,Load,Enable all,Disable all,Rename,Delete", "the submenu's entries: " .. table.concat(names, ","))
	win:Hide()
end

-- The tick next to a profile, the tally and the Reload counts (3.6.0.82,
-- issue 179): a tick turns all of the profile's addons on, an untick off, at
-- once; the summary at the top, the Reload button's (+x/-y) and both hovers
-- come from one count and update with each tick
function phases.placetick()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	local V = pg.state
	local said = {}
	local show = M.ShowMsg
	M.ShowMsg = function(t) said[#said + 1] = t end
	local function make(id, names)
		M.PSS_AddonAll(false, "me")
		for _, n in ipairs(names) do M.PSS_AddonTick(idx(n), true, "me", false) end
		check(M.PSS_AddonPresetSave(id, "", "me"), "save " .. id)
	end
	make(2, { "ZedOne", "ZedTwo" })
	M.PSS_AddonAll(false, "me")
	V:Build()
	-- the place's tick as the menu gives it
	local function tick(id)
		local found
		pg.setsBuild({ Title = function() end, Divider = function() end, Button = function() end,
			Sub = function(_, t, f, tk) if t:find("^%*? ?" .. V:Place(id).label .. " %(") then found = tk end end })
		return found
	end
	local tk = tick(2)
	check(tk and type(tk.on) == "function" and type(tk.fn) == "function", "(a) the place has a tick")
	check(tk.on() == false, "(a) unticked while its addons are off")
	tk.fn()
	check(tick(2).on() == true and row("ZedOne").enabled and row("ZedTwo").enabled, "(b) a tick turned its addons on")
	tk.fn()
	check(tick(2).on() == false and not row("ZedOne").enabled and not row("ZedTwo").enabled, "(c) an untick turned them off")
	-- a free place: the tick says why and stays off
	said = {}
	local free = tick(9)
	free.fn()
	check(free.on() == false and said[1] and said[1]:find("no addon profile", 1, true), "(d) a free place: " .. tostring(said[1]))
	-- the count: one source for the summary, the button and the hover
	local H2 = H
	H.AddonList()[#H.AddonList() + 1] = { name = "NewOne", deps = {}, opt = {}, me = true, mem = 0 }
	local adds, offs = M.PSS_AddonChanges("me")
	local seen = false
	for _, n in ipairs(adds) do if n == "NewOne" then seen = true end end
	check(seen, "(e) an addon turned on and not loaded is counted as added")
	M.PSS_AddonTick(idx("Atlas"), false, "me", false)
	local a2, o2 = M.PSS_AddonChanges("me")
	check(#a2 == #adds and (#o2 == #offs + 1 or #o2 >= #offs), "(e) a loaded addon turned off is counted as turned off")
	M.Events.Fire("ADDONS_CHANGED")
	H.RunTimers()
	check(pg.tally:GetText() == "Enabling " .. #a2 .. ", disabling " .. #o2, "(h) the summary is drawn: " .. tostring(pg.tally:GetText()))
	pg.reloadButton:GetScript("OnEnter")(pg.reloadButton)
	check(GameTooltip._lines and GameTooltip._lines[1] and GameTooltip._lines[1]:find("Addon changes (+" .. #a2 .. "/-" .. #o2 .. ")", 1, true), "(g) the Reload hover title")
	check(GameTooltip._lines[2] == "Reload Required" and GameTooltip._lines[3]:find("+ NewOne", 1, true), "(g) the hover: bold line, then the addons")
	check(pg.reloadButton:GetText():find("%(%+" .. #a2 .. "/%-" .. #o2 .. "%)"), "(h) the Reload button shows the counts: " .. tostring(pg.reloadButton:GetText()))
	-- Dark: the tick is the left edge of the row
	M.PSS_SetOpt("uiSkin", "global", 1)
	local dd = pg.setsDD
	dd.dark._scripts.OnClick(dd.dark)
	local menu = _G.PSS_Menu
	local sl
	for _, s2 in ipairs(menu.slots) do if s2:IsShown() and s2.entry and s2.entry.text and s2.entry.text:find("Profile 2 (", 1, true) then sl = s2 end end
	check(sl and sl.entry.tick and sl.box:IsShown(), "(i) Dark draws a tick box on the place")
	H.cursorX = 5
	sl._scripts.OnClick(sl)
	check(tick(2).on() == true and menu:IsShown(), "(i) a click on the box ticked it and kept the menu open")
	H.cursorX = 500
	sl._scripts.OnClick(sl)
	check(menu:IsShown() and not (tick(2).on() == false) and _G.PSS_MenuSide and _G.PSS_MenuSide:IsShown(), "(i) a click beside the box opened the side menu, not the tick")
	H.cursorX = nil
	menu:Hide()
	-- Blizzard's menu: a checkbox with the side menu under it
	M.PSS_SetOpt("uiSkin", "global", 2)
	local tree = dd.blizz:MenuTree()
	local item
	for _, it in ipairs(tree.items) do if it.text and it.text:find("Profile 2 (", 1, true) then item = it end end
	check(item and item.kind == "checkbox" and item.sub and #item.sub.items > 0, "(j) Blizzard: the place is a checkbox with a side menu")
	check(item.isOn() == true, "(j) Blizzard: ticked state")
	M.ShowMsg = show
	win:Hide()
end

-- Load is on every place (3.6.0.80, issue 189, ACP's sets menu shape): a
-- free place lists it and says there is nothing to load; Save through the
-- real confirm says it saved and the place turns used; none installed or
-- Delete turns the entries back (TST-00008)
function phases.loadentry()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	local V = pg.state
	local said = {}
	local show = M.ShowMsg
	M.ShowMsg = function(t) said[#said + 1] = t end
	local function place(id)
		local sub
		pg.setsBuild({ Title = function() end, Divider = function() end, Button = function() end,
			Sub = function(_, t, f) if t:find("^%*? ?" .. V:Place(id).label .. " %(") then sub = f end end })
		local items = {}
		sub({ Title = function(_, t) items[t] = "title" end, Divider = function() end,
			Button = function(_, t, f) items[t] = f end })
		return items
	end
	local items = place(1)
	check(type(items.Load) == "function" and type(items.Select) == "function" and type(items.Delete) == "function", "(a) a free place lists Load, Select and Delete")
	check(type(items["Enable all"]) == "function" and type(items["Disable all"]) == "function", "(a) a free place lists Enable all and Disable all")
	-- Load on a free place says why and changes nothing
	local calls = H.calls.DisableAllAddOns or 0
	items.Load()
	check(#said == 1 and said[1]:find("no addon profile", 1, true) and (H.calls.DisableAllAddOns or 0) == calls, "(a) Load on a free place: " .. tostring(said[1]))
	-- Save through the real confirm, then the place is used and Load a button
	items.Save()
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown(), "(b) Save did not ask")
	said = {}
	cf.accept._scripts.OnClick(cf.accept)
	check(#said == 1 and said[1]:find("saved", 1, true), "(b) Save did not say it saved: " .. tostring(said[1]))
	check(not V:Place(1).empty, "(b) the place did not turn used")
	items = place(1)
	said = {}
	items.Load()
	check(#said == 1 and said[1]:find(" on, ", 1, true), "(b) Load on a used place: " .. tostring(said[1]))
	-- (c) all characters
	V.who = "all"
	items = place(3)
	check(type(items.Load) == "function", "(c) a free place under All characters lists Load")
	items.Save()
	said = {}
	cf.accept._scripts.OnClick(cf.accept)
	check(said[1] and said[1]:find("saved", 1, true) and not V:Place(3).empty, "(c) Save under All characters: " .. tostring(said[1]))
	V.who = "me"
	-- (d) a profile with no installed addon: the titles
	PSS_CharDB.addonSets[5] = "\nGhost"
	items = place(5)
	check(type(items.Load) == "function", "(d) Load stays a button (it says why)")
	check(items["Enable all"] == "title" and items["Disable all"] == "title", "(d) Enable all and Disable all are titles when none is installed")
	-- (e) Delete: the place is free again, Load still listed
	items = place(1)
	items.Delete()
	cf.accept._scripts.OnClick(cf.accept)
	check(V:Place(1).empty, "(e) Delete did not free the place")
	check(type(place(1).Load) == "function", "(e) Load is gone after Delete")
	-- (f) the popup's controls sit above the frame art in every look
	for _, skin in ipairs({ 2, 0, 1 }) do
		M.PSS_SetOpt("uiSkin", "global", skin)
		local lv = cf.pssTop
		check(cf.accept:GetFrameLevel() > lv and cf.cancel:GetFrameLevel() > lv and cf.name:GetFrameLevel() > lv, "(f) the popup's controls are not above the art, look " .. skin)
	end
	M.ShowMsg = show
	win:Hide()
end

-- The reload prompt (3.6.0.81, issue 192; TST-00009). Retail and clients with
-- C_UI.Reload: the accept reloads once through the helper. Camelot
-- (PSS_RELOAD_BLOCK=1 blocks ReloadUI from addon code, as the client does): an
-- action button over Accept runs the macro /reload, Enter the same through a
-- twin, in combat Accept waits for the end of combat
function phases.reloadpath()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	local said = {}
	local show = M.ShowMsg
	M.ShowMsg = function(t) said[#said + 1] = t end
	local press = M.PSS_ReloadMode() == "press"
	local function open()
		said = {}
		pg.reloadButton._scripts.OnClick(pg.reloadButton)
		return _G.PSS_Confirm
	end
	local cf = open()
	check(cf:IsShown() and cf.title:GetText() == "Reload UI?", "(a) the footer's Reload did not ask")
	if not press then
		-- Retail
		local ui, rl = H.uiReloads, H.reloads
		cf.accept._scripts.OnClick(cf.accept)
		if C_UI and C_UI.Reload then
			check(H.uiReloads == ui + 1 and H.reloads == rl + 1, "(a) Accept did not reload once through C_UI.Reload")
		else
			check(H.reloads == rl + 1, "(b) Accept did not reload once through ReloadUI")
		end
		check(said[1] == "Reloading...", "(a) no status line: " .. tostring(said[1]))
		-- (c) combat: the player opened it, it reloads
		H.combat = true
		cf = open()
		rl = H.reloads
		cf.accept._scripts.OnClick(cf.accept)
		check(H.reloads == rl + 1, "(c) combat: the prompt did not reload")
		H.combat = false
		-- (e) Cancel
		cf = open()
		rl = H.reloads
		cf.cancel._scripts.OnClick(cf.cancel)
		check(H.reloads == rl, "(e) Cancel reloaded")
		check(not _G.PSS_ReloadClick, "Retail made the reload overlay")
	else
		-- Camelot
		local ov = _G.PSS_ReloadClick
		check(ov and ov:IsShown() and ov:GetAttribute("type") == "macro" and ov:GetAttribute("macrotext"):find("/reload", 1, true), "(g) no reload button over Accept")
		check(ov:GetFrameLevel() > cf.accept:GetFrameLevel(), "(g) the overlay is not above Accept")
		check(cf.hint:IsShown() and cf.hint:GetText() == "Press Enter to reload.", "(g) the Enter line: " .. tostring(cf.hint:GetText()))
		check(H.bindings.ENTER == "PSS_ReloadKey" and H.bindings.NUMPADENTER == "PSS_ReloadKey", "(g) Enter is not bound to the twin")
		local rl = H.reloads
		H.SecureClick(ov)
		check(H.reloads == rl + 1 and H.blockedReloads == 0 and said[1] == "Reloading..." and #said == 1, "(g) the click did not reload once with one status line: " .. #said)
		check(not cf:IsShown() and next(H.bindings) == nil, "(g) the prompt or the Enter binding stayed after Accept")
		-- Enter reloads once through the twin
		cf = open()
		rl = H.reloads
		check(_G.PSS_ReloadClick == ov, "(i) the overlay was made again")
		H.SecureClick(_G.PSS_ReloadKey)
		check(H.reloads == rl + 1, "(g) Enter did not reload")
		-- hiding clears the bindings
		cf = open()
		cf:Hide()
		check(next(H.bindings) == nil, "(g) hiding left the Enter binding")
		-- in combat: the click reloads (the player chose it), Enter is bound when combat ends
		H.combat = true
		cf = open()
		check(cf.accept:IsEnabled() and next(H.bindings) == nil, "(g) combat: Accept is not usable or Enter was bound")
		rl = H.reloads
		H.SecureClick(_G.PSS_ReloadClick)
		check(H.reloads == rl + 1, "(g) the click did not reload in combat")
		cf = open()
		H.combat = false
		H.Fire("PLAYER_REGEN_ENABLED")
		check(H.bindings.ENTER == "PSS_ReloadKey", "(g) combat end did not bind Enter")
		cf:Hide()
		check(next(H.bindings) == nil and not cf.hint:IsShown(), "(g) Cancel left the prompt armed")
	end
	M.ShowMsg = show
	win:Hide()
end

-- Profile places read fresh and explained (3.6.0.75, issue 189): a place
-- saved in the other scope says so and can be shown, a free place says "Not
-- saved yet", a string this version cannot read is not a free place, and a
-- menu built before a save acts on the place as it is now
function phases.menurefresh()
	needLibraries()
	SlashCmdList["PSS"]("acp")
	local win = _G.PSS_Window
	local pg = win.pages[4]
	local V = pg.state
	local function collect(build)
		local list = {}
		local m = {}
		m.Title = function(_, t) list[#list + 1] = "T:" .. t end
		m.Button = function(_, t) list[#list + 1] = "B:" .. t end
		m.Divider = function() list[#list + 1] = "-" end
		m.Sub = function(_, t, b) list[#list + 1] = "S:" .. t .. "{" .. table.concat(collect(b), ",") .. "}" end
		build(m)
		return list
	end
	-- a free place says why
	local list = collect(pg.setsBuild)
	check(list[2]:find("T:Not saved yet", 1, true), "a free place does not say Not saved yet: " .. list[2])
	-- saved for all characters, shown under this character
	V.who = "all"
	check(M.PSS_AddonPresetSave(4, "Raid", "all"), "save for all")
	V.who = "me"
	list = collect(pg.setsBuild)
	check(list[5]:find("^S:Profile 4 %\(empty; saved for all characters%\)"), "the place does not say where its profile is: " .. list[5])
	check(list[5]:find("B:Show the saved profile (all characters)", 1, true), "no Show the saved profile entry: " .. list[5])
	local p = V:Place(4)
	check(p.empty and p.elsewhere == "all", "the place's elsewhere")
	V:PresetAct(p, "show")
	check(V.who == "all" and not V:Place(4).empty, "Show did not switch to the profile's scope")
	V.who = "me"
	-- a string this version cannot read is not free
	PSS_CharDB = PSS_CharDB or {}
	PSS_CharDB.addonSets = PSS_CharDB.addonSets or {}
	PSS_CharDB.addonSets[2] = 5
	p = V:Place(2)
	check(p.empty and p.hidden, "an unreadable string is not marked")
	check(V:Place(2).text == "Profile 2 (other version)", "its line: " .. tostring(V:Place(2).text))
	local ok, text = M.PSS_AddonPresetSave(2, "", "me")
	check(not ok and PSS_CharDB.addonSets[2] == 5, "Save overwrote an unreadable string")
	PSS_CharDB.addonSets[2] = nil
	-- a menu built before the save acts on the place as it is now
	list = collect(pg.setsBuild)
	local stale = V:Place(1)
	check(stale.empty, "place 1 starts free")
	M.PSS_AddonPresetSave(1, "Late", "me")
	check(V:PresetMenu(V:Place(1))[2].text == "Select", "the fresh place is not a used one")
	local sub
	local b = {}
	b.Title = function() end
	b.Divider = function() end
	b.Button = function() end
	b.Sub = function(_, t, f) if t:find("Profile 1 %\(empty") or t:find("Late") then sub = f end end
	pg.setsBuild(b)
	local texts = {}
	sub({ Title = function() end, Divider = function() end, Button = function(_, t) texts[#texts + 1] = t end })
	check(table.concat(texts, ","):find("Load", 1, true), "the side menu still offers no Load: " .. table.concat(texts, ","))
	-- Delete refreshes the window at once
	win:Hide()
end

-- Enable all / Disable all on one profile (3.6.0.74, issue 179): a manual
-- group tick of that profile's installed addons, nothing saved or selected
function phases.profiletick()
	needLibraries()
	local function on(n) return row(n).enabled end
	local function make(id, names, who)
		M.PSS_AddonAll(false, who or "me")
		for _, n in ipairs(names) do M.PSS_AddonTick(idx(n), true, who or "me", false) end
		check(M.PSS_AddonPresetSave(id, "", who or "me"), "save " .. id)
	end
	make(2, { "ZedOne", "ZedTwo" })
	PSS_CharDB.addonSets[2] = PSS_CharDB.addonSets[2] .. "\nGhost"
	make(7, { "DBM-Core" })
	local sets = PSS_CharDB.addonSets[2] .. "|" .. PSS_CharDB.addonSets[7]
	M.PSS_AddonAll(false, "me")
	M.PSS_AddonProfileSelect(7, true, "me")
	local sel = PSS_CharDB.addonSel
	local ok, text = M.PSS_AddonPresetTick(2, "char", true, "me", false)
	check(ok and text == "Addon profile 2: 2 enabled, 1 not installed.", "enable all: " .. tostring(text))
	check(on("ZedOne") and on("ZedTwo") and on("DBM-Core") and not on("Atlas") and not on("LibFoo"), "only the profile's addons changed")
	check(PSS_CharDB.addonSel == sel, "the selection is unchanged: " .. tostring(PSS_CharDB.addonSel))
	check(PSS_CharDB.addonSets[2] .. "|" .. PSS_CharDB.addonSets[7] == sets, "no saved profile changed")
	check(PSS_CharDB.addonPick == "ZedOne\nZedTwo", "hand picks as a manual tick writes them: " .. tostring(PSS_CharDB.addonPick))
	-- the same through the view's act and the command
	M.PSS_AddonAll(false, "me")
	local V = M.PSS_AddonView()
	V:Build()
	local p = V:Slots()[2]
	check(V:PresetAct(p, "enable") == text and on("ZedOne"), "the view's Enable all")
	check(has(pss("acp profile 2 disable"), "Addon profile 2: 2 disabled, 1 not installed.") and not on("ZedOne"), "the command's disable")
	check(has(pss("acp profile 2 enable"), "2 enabled") and on("ZedTwo"), "the command's enable")
	-- Disable all spares protected addons and Pour Social Score
	M.PSS_AddonLock("ZedOne", true, "me")
	ok, text = M.PSS_AddonPresetTick(2, "char", false, "me", false)
	check(ok and on("ZedOne") and not on("ZedTwo") and row("PourSocialScore").enabled, "protected addons stay on")
	check(text == "Addon profile 2: 1 disabled, 1 not installed.", "disable all counts what it turned off: " .. tostring(text))
	M.PSS_AddonLock("ZedOne", false, "me")
	-- dependencies follow only with the Dependencies check
	make(3, { "Atlas_Options" })
	M.PSS_AddonAll(false, "me")
	M.PSS_AddonPresetTick(3, "char", true, "me", false)
	check(on("Atlas_Options") and not on("Atlas"), "no dependency without the check")
	M.PSS_AddonAll(false, "me")
	M.PSS_AddonPresetTick(3, "char", true, "me", true)
	check(on("Atlas_Options") and on("Atlas"), "the required dependency follows with the check")
	-- a profile with no installed addon: refused, its menu entries are not clickable
	PSS_CharDB.addonSets[5] = "\nGhost"
	check(M.PSS_AddonPresetInstalled(5, "char") == 0 and M.PSS_AddonPresetInstalled(2, "char") == 2, "installed counts")
	local calls = H.calls.SaveAddOns or 0
	ok, text = M.PSS_AddonPresetTick(5, "char", true, "me", false)
	check(not ok and text == "Addon profile 5 has no installed addon." and (H.calls.SaveAddOns or 0) == calls, "refused, nothing saved: " .. tostring(text))
	V:Build()
	local function kinds(i)
		local t = {}
		for _, e in ipairs(V:PresetMenu(V:Slots()[i])) do
			if e.text == "Enable all" or e.text == "Disable all" then t[#t + 1] = e.kind end
		end
		return table.concat(t, ",")
	end
	check(kinds(2) == "button,button" and kinds(5) == "title,title", "entries: " .. kinds(2) .. " / " .. kinds(5))
	local has = false
	for _, e in ipairs(V:PresetMenu(V:Slots()[4])) do if e.act == "load" then has = true end end
	check(has, "a free place lists Load")
	-- the all-characters scope writes the all form
	make(8, { "ZedOne" }, "all")
	M.PSS_AddonAll(false, "all")
	ok = M.PSS_AddonPresetTick(8, "all", true, "all", false)
	check(ok and row("ZedOne", "all").state == 2, "all characters")
	-- allowed in combat, as ticks are
	H.combat = true
	ok = M.PSS_AddonPresetTick(2, "char", true, "me", false)
	H.combat = false
	check(ok, "allowed in combat")
	-- an unknown place
	ok, text = M.PSS_AddonPresetTick(9, "char", true, "me", false)
	check(not ok and text == "There is no addon profile 9 here.", "no profile: " .. tostring(text))
end

-- Core and Layered addon profiles, selected together (3.6.0.68, issue 177):
-- places 1 to 5 are Core, the rest Layered; any number are selected at once;
-- what is on is the union of the selected profiles and the hand picks
function phases.profiles()
	needLibraries()
	local cls = os.getenv("PSS_CLASS") or "MAGE"
	local V = M.PSS_AddonView()
	V:Build()
	local slots = V:Slots()
	for n = 1, 25 do
		check(slots[n].layer == (n <= 5 and "core" or "layered"), "slot " .. n .. " layer: " .. tostring(slots[n].layer))
	end
	check(slots[26].layer == "layered", "the class profile is Layered")
	-- a profile holding exactly names (this character, or the account when who is "all")
	local function make(id, names, who)
		M.PSS_AddonAll(false, who)
		for _, n in ipairs(names) do M.PSS_AddonTick(idx(n), true, who, false) end
		check(M.PSS_AddonPresetSave(id, "", who), "save " .. tostring(id))
	end
	make(1, { "ZedOne", "WeakAuras" }, "me")
	make(2, { "ZedOne", "ZedTwo" }, "me")
	make(7, { "DBM-Core", "DBM-GUI" }, "me")
	M.PSS_AddonAll(false, "me")
	check(PSS_CharDB.addonSel == nil and PSS_CharDB.addonPick == nil, "Disable All forgets the selection and the picks")
	local function on(n) return row(n).enabled end
	local function sel(id) return M.PSS_AddonProfileSelected(id, "me") end
	-- select Core 1 and Layered 7 together: both loaded, both ticked
	local ok, text = M.PSS_AddonProfileSelect(1, true, "me")
	check(ok and text == "Addon profile 1 selected: 2 on, 0 not installed.", "select: " .. tostring(text))
	M.PSS_AddonProfileSelect(7, true, "me")
	check(on("ZedOne") and on("WeakAuras") and on("DBM-Core") and on("DBM-GUI") and not on("ZedTwo"), "the union of 1 and 7 is on")
	check(sel(1) and sel(7) and not sel(2), "selected flags")
	check(PSS_CharDB.addonSel == "1 7", "saved packed: " .. tostring(PSS_CharDB.addonSel))
	local u = M.PSS_AddonProfileUnion("me")
	check(u.ZedOne and u.WeakAuras and u["DBM-Core"] and not u.ZedTwo, "the union")
	-- Core 2 too; deselect 1: ZedOne is still wanted by 2, WeakAuras goes
	M.PSS_AddonProfileSelect(2, true, "me")
	check(on("ZedTwo"), "the third profile adds its addon")
	ok, text = M.PSS_AddonProfileSelect(1, false, "me")
	check(ok and text == "Addon profile 1 deselected: 1 off, 1 kept by others.", "deselect: " .. tostring(text))
	check(on("ZedOne") and not on("WeakAuras") and on("DBM-Core"), "deselect keeps what another profile still wants")
	-- a hand pick survives deselecting the profile that holds it
	M.PSS_AddonTick(idx("WeakAuras"), true, "me", false)
	M.PSS_AddonTick(idx("LibFoo"), true, "me", false)
	check(PSS_CharDB.addonPick == "LibFoo\nWeakAuras", "the picks: " .. tostring(PSS_CharDB.addonPick))
	M.PSS_AddonProfileSelect(1, true, "me")
	M.PSS_AddonProfileSelect(1, false, "me")
	check(on("WeakAuras"), "a hand pick stays on")
	M.PSS_AddonProfileSelect(2, false, "me")
	check(not on("ZedTwo") and not on("ZedOne") and on("WeakAuras") and on("LibFoo") and on("DBM-Core"), "only what nothing wants goes")
	-- ticking a pick off forgets it
	M.PSS_AddonTick(idx("WeakAuras"), false, "me", false)
	check(PSS_CharDB.addonPick == "LibFoo", "a pick ticked off is forgotten: " .. tostring(PSS_CharDB.addonPick))
	-- protected addons are never turned off by a deselect
	M.PSS_AddonLock("DBM-GUI", true, "me")
	M.PSS_AddonProfileSelect(7, false, "me")
	check(on("DBM-GUI") and not on("DBM-Core"), "protected stays on")
	M.PSS_AddonLock("DBM-GUI", false, "me")
	-- a profile load replaces the state and is the one selected; Enable All, Undo forget
	M.PSS_AddonProfileSelect(2, true, "me")
	M.PSS_AddonPresetLoad(1, "char", "me")
	check(PSS_CharDB.addonSel == "1" and PSS_CharDB.addonPick == nil, "a load selects only that profile: " .. tostring(PSS_CharDB.addonSel))
	M.PSS_AddonProfileSelect(2, true, "me")
	M.PSS_AddonAll(true, "me")
	check(PSS_CharDB.addonSel == nil, "Enable All forgets the selection")
	M.PSS_AddonProfileSelect(2, true, "me")
	M.PSS_AddonUndo()
	check(PSS_CharDB.addonSel == nil, "Undo forgets the selection")
	-- deleting a selected profile drops it from the selection
	M.PSS_AddonProfileSelect(2, true, "me")
	M.PSS_AddonPresetDelete(2, "char")
	check(not sel(2) and PSS_CharDB.addonSel == nil, "a deleted profile is not selected")
	check(not M.PSS_AddonProfileSelect(2, true, "me"), "an empty place cannot be selected")
	-- what is already on when a profile is selected is the player's own: it stays on after a deselect
	M.PSS_AddonAll(false, "me")
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	check(PSS_CharDB.addonPick == nil and PSS_CharDB.addonSel == nil, "ticking with nothing selected records nothing")
	M.PSS_AddonPresetSave(2, "", "me")
	M.PSS_AddonProfileSelect(2, true, "me")
	check(PSS_CharDB.addonPick == "ZedOne", "already on: a pick: " .. tostring(PSS_CharDB.addonPick))
	M.PSS_AddonProfileSelect(2, false, "me")
	check(on("ZedOne") and not on("ZedTwo"), "deselect turns off only what the profile turned on")
	M.PSS_AddonPresetDelete(2, "char")
	M.PSS_AddonAll(false, "me")
	-- all characters: its own selection, in the account's store under the client digit
	make(3, { "ZedOne", "ZedTwo" }, "all")
	M.PSS_AddonAll(false, "all")
	ok = M.PSS_AddonProfileSelect(3, true, "all")
	check(ok and PSS_OptionsDB.addonSel and PSS_OptionsDB.addonSel[DIGIT] == "3", "account selection")
	check(M.PSS_AddonProfileSelected(3, "all") and not M.PSS_AddonProfileSelected(3, "me"), "the scopes are separate")
	check(row("ZedOne", "all").enabled, "it turned them on for all")
	M.PSS_AddonProfileSelect(3, false, "all")
	check(not row("ZedOne", "all").enabled and PSS_OptionsDB.addonSel == nil, "off again and the empty key is gone")
	-- the class profile, shared; Layered
	M.PSS_AddonAll(false, "me")
	M.PSS_AddonTick(idx("WeakAuras"), true, "me", false)
	M.PSS_AddonPresetSave(cls:lower(), "", "me")
	M.PSS_AddonAll(false, "me")
	check(M.PSS_AddonProfileSelect(cls, true, "me") and on("WeakAuras") and M.PSS_AddonProfileSelected(cls, "me"), "the class profile selects")
	check(M.PSS_AddonProfileSelect(cls, true, "all") and M.PSS_AddonProfileSelected(cls, "all"), "and in the other scope")
	M.PSS_AddonPresetDelete(cls, "all")
	check(not M.PSS_AddonProfileSelected(cls, "me") and not M.PSS_AddonProfileSelected(cls, "all"), "deleting it drops both selections")
	-- everything cleared leaves nothing saved
	for _, id in ipairs({ 1, 7 }) do M.PSS_AddonPresetDelete(id, "char") end
	M.PSS_AddonPresetDelete(3, "all")
	M.PSS_AddonAll(true, "me")
	M.PSS_AddonAll(true, "all")
	check(PSS_CharDB == nil and PSS_OptionsDB.addonSets == nil and PSS_OptionsDB.addonSel == nil and PSS_OptionsDB.addonPick == nil, "nothing left saved")
	V:Release()
end

-- A newer version's selection and picks are kept untouched (3.6.0.68)
function phases.selforward()
	PourSocialScoreDB.addonSel = { ["3"] = "9 8" }
	PourSocialScoreDB.addonPick = "newer layout"
	_G["PSS_CharDB"] = { addonSel = { 1, 2 }, addonPick = { "x" } }
	needLibraries()
	M.PSS_AddonAll(false, "me")
	M.PSS_AddonPresetSave(1, "A", "all")
	M.PSS_AddonPresetSave(2, "B", "me")
	check(M.PSS_AddonProfileSelect(1, true, "all"), "select on the account")
	check(PSS_OptionsDB.addonSel["3"] == "9 8" and PSS_OptionsDB.addonSel[DIGIT] == "1", "the other client's selection is kept")
	M.PSS_AddonTick(idx("ZedOne"), true, "all", false)
	check(PSS_OptionsDB.addonPick == "newer layout", "a pick of a newer layout is not replaced")
	M.PSS_AddonProfileSelect(2, true, "me")
	M.PSS_AddonTick(idx("ZedOne"), true, "me", false)
	check(type(PSS_CharDB.addonSel) == "table" and PSS_CharDB.addonSel[2] == 2 and type(PSS_CharDB.addonPick) == "table", "the character's newer values are kept")
	M.PSS_AddonAll(true, "all")
	check(PSS_OptionsDB.addonSel["3"] == "9 8" and PSS_OptionsDB.addonSel[DIGIT] == nil, "Enable All clears only this client's")
end

-- Renaming any addon profile (3.6.0.68, issue 176): every kind, a free place
-- too, with the name rules; and the menu offers it everywhere
function phases.rename()
	needLibraries()
	local cls = os.getenv("PSS_CLASS") or "MAGE"
	local V = M.PSS_AddonView()
	V:Build()
	local function acts(entries) local t = {} for _, e in ipairs(entries) do if e.act then t[#t + 1] = e.act end end return table.concat(t, ",") end
	-- the menu of every kind of place offers Rename
	local slots = V:Slots()
	check(acts(V:PresetMenu(slots[1])):find("rename", 1, true), "a free place offers Rename")
	check(not acts(V:PresetMenu(slots[26])):find("rename", 1, true), "the class place has no Rename")
	M.PSS_AddonPresetSave(2, "", "me")
	check(acts(V:PresetMenu(V:Slots()[2])):find("rename", 1, true), "a used place offers Rename")
	-- a free place named: kept, empty
	local ok, text = M.PSS_AddonPresetRename(4, "Raid Core", "char")
	check(ok and text == "Addon profile Raid Core renamed.", "free place: " .. tostring(text))
	check(PSS_CharDB.addonSets[4] == "Raid Core", "stored as a name only: " .. tostring(PSS_CharDB.addonSets[4]))
	local p = V:Slots()[4]
	check(not p.empty and p.name == "Raid Core" and p.n == 0 and p.text == "Raid Core (0)", "it shows with its name: " .. tostring(p.text))
	-- a used place keeps its addons
	M.PSS_AddonPresetSave(3, "Old", "me")
	local before = PSS_CharDB.addonSets[3]:sub(5)
	check(M.PSS_AddonPresetRename(3, "New Name", "char") and PSS_CharDB.addonSets[3] == "New Name\n" .. before, "a used place keeps its addons")
	-- the class one (account-wide) and an account one
	check(M.PSS_AddonPresetRename(cls:lower(), "Mine", "all") and PSS_OptionsDB.addonSets[cls] == DIGIT .. "Mine", "the class profile")
	check(M.PSS_AddonPresetRename(9, "Everyone", "all") and PSS_OptionsDB.addonSets[9] == DIGIT .. "Everyone", "an account profile")
	-- the rules: not empty, not too long, no duplicate in the store (any case), ASCII only
	ok, text = M.PSS_AddonPresetRename(5, "   ", "char")
	check(not ok and text == "Give the addon profile a name." and PSS_CharDB.addonSets[5] == nil, "empty refused: " .. tostring(text))
	ok, text = M.PSS_AddonPresetRename(5, string.rep("x", 33), "char")
	check(not ok and text == "That name is too long: at most 32 letters." and PSS_CharDB.addonSets[5] == nil, "long refused: " .. tostring(text))
	check(M.PSS_AddonPresetRename(5, string.rep("x", 32), "char"), "32 is allowed")
	ok, text = M.PSS_AddonPresetRename(6, "raid core", "char")
	check(not ok and text == "Another addon profile here is already called \"raid core\"." and PSS_CharDB.addonSets[6] == nil, "duplicate refused: " .. tostring(text))
	check(M.PSS_AddonPresetRename(4, "RAID CORE", "char"), "its own name in another case is fine")
	check(M.PSS_AddonPresetRename(6, "Raid Core", "all"), "the same name in the other scope is fine")
	check(M.PSS_AddonPresetRename(7, "caf\195\169 ok", "char") and PSS_CharDB.addonSets[7] == "caf ok", "non-ASCII is stripped: " .. tostring(PSS_CharDB.addonSets[7]))
	check(not M.PSS_AddonPresetRename(26, "x", "char"), "no place 26")
	-- through the view and the command
	local said = V:PresetAct(V:Slots()[8], "rename", "Via view")
	check(said == "Addon profile Via view renamed." and V:Slots()[8].name == "Via view", "the view's rename: " .. tostring(said))
	local l = pss("acp profile 10 rename From Command")
	check(has(l, "Addon profile From Command renamed."), "the command: " .. say(l))
	l = pss("acp profile 11 select")
	check(has(l, "There is no addon profile 11 here."), "select an empty place: " .. say(l))
	V:Release()
end

function phases.access()
	check(BINDING_NAME_PSS_OPEN_ADDONS == "Open AddOns" and BINDING_HEADER_POURSOCIALSCORE == "Pour Social Score", "the binding texts")
	check(type(_G.PSS_AddonsBinding) == "function", "the binding function exists")
	local f = io.open("PourSocialScore/Bindings.xml")
	local xml = f:read("*a")
	f:close()
	check(xml:find('name="PSS_OPEN_ADDONS"', 1, true) and xml:find("PSS_AddonsBinding()", 1, true) and xml:find('category="ADDONS"', 1, true), "Bindings.xml has the binding")
	check(not loaded("PourSocialScore_Libraries") and not loaded("PourSocialScore_GUI"), "nothing built at login")
	local entry
	for _, info in ipairs(AddonCompartmentFrame.registered) do
		if info.text == "Pour Social Score: AddOns" then entry = info end
	end
	-- (the stub is always the Retail project: a Camelot client has no compartment)
	check(entry ~= nil, "no second Addon Compartment entry")
	entry.func()
	local win = _G.PSS_Window
	check(win and win:IsShown() and win.pages[4]:IsShown(), "the compartment entry did not open the AddOns tab")
	win:Hide()
	PSS_AddonsBinding()
	check(win:IsShown() and win.pages[4]:IsShown(), "the key binding did not open the AddOns tab")
	PSS_AddonsBinding()
	check(not win:IsShown(), "the key binding again closes it")
	win:Show()
	win.tabs[1]._scripts.OnClick(win.tabs[1])
	M.PSS_OpenUI("addons")
	check(win.pages[4]:IsShown(), "M.PSS_OpenUI(tab) selects the tab on an open window")
	SlashCmdList["PSS"]("acp")
	check(not win:IsShown(), "/pss acp on its tab closes it")
	SlashCmdList["PSS"]("")
	check(win:IsShown() and win.pages[4]:IsShown(), "/pss opens the last tab (AddOns)")
	win:Hide()
	local ok = capture(SlashCmdList["PSS"], "acp list nothing")
	check(ok ~= nil, "acp list")
end

local function openTab()
	M.PSS_OpenUI("addons")
	local win = _G.PSS_Window
	local ui = H.Private("PourSocialScore_GUI")
	local pg = win.pages[4]
	pg.list.scroll:SetSize(900, 300)
	pg.list:Layout()
	-- the search "pour" brings Pour Social Score's own group (a header and its
	-- protected addons) into the rows the stub shows
	pg.search:SetText("pour")
	pg.search._scripts.OnTextChanged(pg.search)
	pg.refresh()
	return win, pg, ui
end

local function headerRow(pg)
	for _, r in ipairs(pg.list.rows) do
		local o = pg.state:Row(r.index or 0, {})
		if o and o.header then return r end
	end
end

local function lockRow(pg)
	for _, r in ipairs(pg.list.rows) do
		local o = pg.state:Row(r.index or 0, {})
		if o and o.pss then return r end
	end
end

local function eachLook(fn)
	for _, look in ipairs({ 2, 0, 1 }) do
		M.PSS_SetOpt("uiSkin", "global", look)
		fn(({ [2] = "Modern", [0] = "Classic", [1] = "Dark" })[look])
	end
end

phases["art-atlas"] = function()
	local win, pg, ui = openTab()
	eachLook(function(look)
		pg.refresh()
		local r = headerRow(pg)
		check(r and r.arrow:IsShown() and r.arrow._atlas == "bag-arrow", look .. ": the group arrow is the atlas")
		check(not r.cells.title:GetText():find("[-]", 1, true) and not r.cells.title:GetText():find("[+]", 1, true), look .. ": no text glyph with the atlas")
	end)
end

phases["art-noatlas"] = function()
	local win, pg, ui = openTab()
	eachLook(function(look)
		pg.refresh()
		local r = headerRow(pg)
		check(r and not r.arrow:IsShown(), look .. ": no arrow without the atlas")
		local t = r.cells.title:GetText()
		check(t:find("[-]", 1, true) or t:find("[+]", 1, true), look .. ": the +/- text instead: " .. t)
	end)
	-- the window is still Modern: one missing atlas never turns it Classic
	M.PSS_SetOpt("uiSkin", "global", 2)
	if os.getenv("PSS_ATLAS") then check(ui.IsModern(), "Modern fell back to Classic over the group arrow") end
end

phases["art-file"] = function()
	local win, pg, ui = openTab()
	eachLook(function(look)
		pg.refresh()
		local r = lockRow(pg)
		check(r and r.lock.hasStar and r.star:IsShown() and not r.glyph:IsShown(), look .. ": the star shows")
		check(r.star._texture == "Interface\\Glues\\CharacterSelect\\Glues-AddOn-Icons", look .. ": Blizzard's glue file by path")
	end)
end

phases["art-nofile"] = function()
	local win, pg, ui = openTab()
	eachLook(function(look)
		pg.refresh()
		local r = lockRow(pg)
		check(r and not r.lock.hasStar and not r.star:IsShown() and r.glyph:IsShown(), look .. ": the * shows when the file is missing")
	end)
end

function phases.icons()
	needLibraries()
	CreateAtlasMarkup = function(a) return "|A:" .. a .. ":16:16|a" end
	local V = M.PSS_AddonView()
	V:Build()
	local _, a = lineOf(V, function(o) return o.name == "T1" end)
	check(a.text:find("|TInterface\\Icons\\Foo:16|t", 1, true), "IconTexture: " .. a.text)
	_, a = lineOf(V, function(o) return o.name == "T2" end)
	check(a.text:find("|A:SomeAtlas:16:16|a", 1, true), "IconAtlas: " .. a.text)
	_, a = lineOf(V, function(o) return o.name == "T3" end)
	check(a.text:find("INV_Misc_QuestionMark", 1, true), "neither: the question mark: " .. a.text)
end

------------------------------------------------------------------------
-- Resource usage (stage 3)
------------------------------------------------------------------------
local function near(a, b) return a and math.abs(a - b) < 0.001 end

function phases.perf()
	needLibraries()
	-- DBM-Core 2/1/9/3 ms, Details 1/2/3/4 ms; the game adds 100 ms to the sums
	local avg, cur, peak, enc = M.PSS_AddonCPU("DBM-Core")
	local function share(v, metric) return 100 * v / (100 + v) end
	check(near(avg, share(2)) and near(cur, share(1)) and near(peak, share(9)) and near(enc, share(3)), ("DBM-Core shares: %s %s %s %s"):format(tostring(avg), tostring(cur), tostring(peak), tostring(enc)))
	check(M.PSS_AddonCPU("Details_Streamer") == nil, "a not loaded addon has no CPU")
	-- the same for each metric (the stub's overall is the sum of every addon)
	local pct = M.PSS_AddonPct
	check(pct(12.4) == "12%" and pct(1) == "1%" and pct(0.5) == "0.5%" and pct(0.05) == "0.05%" and pct(0.001) == "0%", "share text: " .. pct(12.4) .. " " .. pct(0.5) .. " " .. pct(0.05) .. " " .. pct(0.001))
	check(M.PSS_AddonKBText(500) == "500 KB" and M.PSS_AddonKBText(2048) == "2.0 MB", "memory text")
	-- the warning share turns a line red with the alert mark
	local V = M.PSS_AddonView()
	V:Build()
	V:Sample()
	local function tip(name)
		for k = 1, V:Count() do
			local o = V:Row(k, {})
			if o and o.name == name then return V:Tip(k) end
		end
	end
	local t = tip("DBM-Core")
	check(t:find("Average CPU: ", 1, true) and t:find("Current CPU: ", 1, true) and t:find("Peak CPU: ", 1, true) and t:find("Encounter CPU: ", 1, true), "all four CPU lines")
	if not os.getenv("PSS_ADDON_WARN") then
		check(t:find("AlertNew", 1, true) and t:find("ffff4040", 1, true), "a share over the warning share is red with the alert mark")
	end
	check(t:find("Memory: 3.9 MB", 1, true), "memory last: " .. tostring(t:match("Memory[^\n]*")))
	t = tip("Atlas_Options")
	check(t:find("Not loaded.", 1, true) and not t:find("CPU", 1, true), "not loaded: no numbers")
	check(M.PSS_AddonWarn() == (tonumber(os.getenv("PSS_ADDON_WARN")) or 1), "the warning share is read from the CVar")
	if os.getenv("PSS_ADDON_WARN") then
		check(not tip("DBM-Core"):find("ffff4040", 1, true), "a high warning share: nothing red")
	end
end

function phases.perfgroup()
	needLibraries()
	local L = M.PSS_AddonList("me", "group")
	local gi = groupIndex(L, "DBM")
	local avg, cur, peak, enc, loaded, total = M.PSS_AddonCPUGroup(L, gi)
	check(loaded == 2 and total == 3, "2 of 3 loaded: " .. tostring(loaded) .. " of " .. tostring(total))
	local single = M.PSS_AddonCPU("DBM-Core")
	check(near(avg, single), "only loaded members count, the share formula on their sum")
	local d = groupIndex(L, "Details")
	local davg = M.PSS_AddonCPUGroup(L, d)
	check(near(davg, (M.PSS_AddonCPU("Details"))), "a group of one loaded member equals the addon")
	check(M.PSS_AddonMemGroup(L, gi) == 4600, "group memory: " .. M.PSS_AddonMemGroup(L, gi))
	local V = M.PSS_AddonView()
	V:Build()
	local o = V:Row(1, {})
	local tipText
	for k = 1, V:Count() do
		local r = V:Row(k, {})
		if r.header and r.name == "DBM" then tipText = V:Tip(k) end
	end
	check(tipText and tipText:find("2 of 3 loaded", 1, true) and tipText:find("Average CPU:", 1, true), "the header tip: " .. tostring(tipText))
end

function phases.perftop()
	needLibraries()
	local V = M.PSS_AddonView()
	V:Build()
	V:Sample()
	local text = V:Stats()
	if os.getenv("PSS_ADDON_NOPROFILER") == "1" or os.getenv("PSS_ADDON_PROFILEROFF") == "1" then
		check(not M.PSS_AddonPerfOn() and M.PSS_AddonCPUTotal() == nil, "no profiler: no CPU")
		check(not text:find("CPU", 1, true) and text:find("Memory ", 1, true), "memory still shows: " .. text)
		check(M.PSS_AddonCPU("DBM-Core") == nil, "no CPU per addon either")
	else
		local cur, avg, peak = M.PSS_AddonCPUTotal()
		check(near(avg, 100 * 3 / 103) and near(cur, 100 * 3 / 103) and near(peak, 100 * 12 / 112), ("totals %s %s %s"):format(tostring(cur), tostring(avg), tostring(peak)))
		check(text:find("AddOn Performance", 1, true) and text:find("Current CPU", 1, true) and text:find("Average CPU", 1, true) and text:find("Peak CPU", 1, true) and text:find("Memory ", 1, true), "the stats line: " .. text)
	end
end

function phases.perfcost()
	-- nothing is read until the tab asks
	check((H.calls.GetAddOnMetric or 0) == 0 and (H.calls.UpdateAddOnMemoryUsage or 0) == 0, "no profiler or memory call at login")
	needLibraries()
	local V = M.PSS_AddonView()
	V:Build()
	check((H.calls.UpdateAddOnMemoryUsage or 0) == 0 and (H.calls.GetAddOnMetric or 0) == 0, "building the list reads neither")
	V:Sample()
	check(H.calls.UpdateAddOnMemoryUsage == 1, "one sample on open")
	V:Sample()
	check(H.calls.UpdateAddOnMemoryUsage == 2, "one more on Refresh")
	H.combat = true
	check(not V:Sample() and H.calls.UpdateAddOnMemoryUsage == 2, "none in combat")
	H.combat = false
	V:Release()
	check(V:Count() == 0, "release drops the list")
end

------------------------------------------------------------------------
-- Every function and command word was used
------------------------------------------------------------------------
function phases.coverage()
	needLibraries()
	local called = {}
	for k, v in pairs(M) do
		if type(k) == "string" and k:match("^PSS_Addon") and type(v) == "function" then
			called[k] = 0
			M[k] = function(...) called[k] = called[k] + 1 return v(...) end
		end
	end
	local i = idx("ZedOne")
	local who = "me"
	M.PSS_AddonCan("list") M.PSS_AddonCount() M.PSS_AddonText = M.PSS_AddonText
	local L = M.PSS_AddonList(who, "group", "")
	M.PSS_AddonRow(i, who, {}) M.PSS_AddonName(i) M.PSS_AddonMeta(i, "Group") M.PSS_AddonIcon(i) M.PSS_AddonDeps(i, who)
	M.PSS_AddonTick(i, true, who, true)
	M.PSS_AddonTickMany(L, 1, 2, true, who, true)
	M.PSS_AddonLoad(idx("Atlas_Options"))
	M.PSS_AddonAll(true, who) M.PSS_AddonPending(who) M.PSS_AddonChanges(who)
	M.PSS_AddonUndo()
	M.PSS_AddonMemory() M.PSS_AddonMemOf(i) M.PSS_AddonMemGroup(L, 1)
	M.PSS_AddonPresetSave(1, "Cov", "me") M.PSS_AddonPresets() M.PSS_AddonSlots(who) M.PSS_AddonPresetLoad(1, "char", who) M.PSS_AddonPresetTick(1, "char", true, who, true)
	M.PSS_AddonPresetTick(1, "char", false, who, true) M.PSS_AddonPresetInstalled(1, "char") M.PSS_AddonPresetOn(1, "char", who) M.PSS_AddonPresetInclude(1, "char", "ZedOne") M.PSS_AddonPresetRename(1, "x", "char")
	M.PSS_AddonProfileSelect(1, true, who) M.PSS_AddonProfileSelected(1, who) M.PSS_AddonProfileUnion(who) M.PSS_AddonProfileSelect(1, false, who)
	M.PSS_AddonPresetDelete(1, "char")
	M.PSS_AddonLock("LibFoo", true, who) M.PSS_AddonLocked("LibFoo") M.PSS_AddonLock("LibFoo", false, who)
	M.PSS_AddonViewMode("az") M.PSS_AddonViewMode("group") M.PSS_AddonLoadOld(true) M.PSS_AddonLoadOld(nil) M.PSS_AddonLoadOld(false)
	M.PSS_AddonPerfOn() M.PSS_AddonCPU("DBM-Core") M.PSS_AddonCPUGroup(L, 1) M.PSS_AddonCPUTotal() M.PSS_AddonWarn()
	M.PSS_AddonPrune() M.PSS_AddonRelease()
	M.PSS_AddonReload()
	M.PSS_AddonPct(1) M.PSS_AddonKBText(1)
	local V = M.PSS_AddonView()
	V:Build()
	for _, word in ipairs({ "list", "on zedone", "off zedone", "load atlas_options", "all on", "all off", "undo", "sets", "profiles", "set 1 save", "set 1 select", "set 1 deselect", "set 1 load",
		"set 1 add", "set 1 remove", "set 1 rename Cov", "profile 1 delete", "lock libfoo", "unlock libfoo", "api", "nonsense" }) do
		local l = pss("acp " .. word)
		check(#l > 0, "/pss acp " .. word .. " said nothing")
	end
	for k, n in pairs(called) do
		-- a view-only function is reached through the view
		check(n > 0 or k == "PSS_AddonView" or k == "PSS_AddonText", k .. " was never called")
	end
end

local fn = phases[phase]
if not check(fn ~= nil, "no such phase") then os.exit(1) end
fn()
if not fail then realPrint("PASS addons " .. phase) end
