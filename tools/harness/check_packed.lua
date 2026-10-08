-- Packed shipped lists (3.0 Step 5.1), as a run.lua script: every member of
-- the unpacked 3.0.0-dev16 list (PSS_OLD_MANAGED, its index included) is
-- found in the same guild with the same name by the packed lookup, and
-- names that only start or end like a member are not. A name whose realm is
-- a Camelot surname ("First-Last", 3.4.1.37 N3) is no longer shipped: it is
-- dropped when "First Last-ClassicBetaPvP" is listed, else listed as that.
local fail = false
local function check(ok, msg) if not ok then print("FAIL packed: " .. msg) fail = true end end

local old = {}
local chunk = assert(loadfile(os.getenv("PSS_OLD_MANAGED")))
setfenv(chunk, { PourSocialScore_NS = old })
chunk()
old = old.MANAGED_DATA.olympus

local REALMS = { classicbetapvp = true, classicbetapvp2 = true }
-- the name a surname-as-realm name is shipped as, and whether it is listed
local function surname(name)
	local first, last = name:match("^([^%-]+)%-(.+)$")
	if REALMS[last:lower():gsub("[%s%-']", "")] then return nil end
	local fixed = first .. " " .. last .. "-ClassicBetaPvP"
	return fixed, old.index[M.PSS_CanonPlayer(fixed)] ~= nil
end

check(M.PSS_LoadManagedData(), "lists not loaded")
local n, bad, dropped = 0, 0, 0
for ck, v in pairs(old.index) do
	n = n + 1
	local gi = math.floor(v / 65536)
	local entry = old.guilds[gi]
	local gkey = M.PSS_NormalizeGuild(entry.name)
	local name = entry[v - gi * 65536]
	local fixed, twin = surname(name)
	if fixed then
		check(not M.PSS_IsManagedStaticMember(gkey, ck), "surname-as-realm " .. ck .. " still shipped")
		if twin then dropped = dropped + 1 else name, ck = fixed, M.PSS_CanonPlayer(fixed) end
	end
	local r = not twin and M.PSS_IsManagedStaticMember(gkey, ck) and M.PSS_ManagedRecord(ck, gkey)
	if not twin and not (r and r.name == M.PSS_DisplayPlayer(name)) then
		bad = bad + 1
		if bad <= 5 then check(false, ck .. " not found as " .. tostring(name)) end
	end
	-- a longer or shorter name on the same realm is someone else
	local base, realm = ck:match("^([^%-]+)%-(.+)$")
	if not old.index[base .. "x-" .. realm] then check(not M.PSS_IsManagedStaticMember(gkey, base .. "x-" .. realm), "prefix match " .. ck) end
	if #base > 2 and not old.index[base:sub(2) .. "-" .. realm] then
		check(not M.PSS_IsManagedStaticMember(gkey, base:sub(2) .. "-" .. realm), "suffix match " .. ck)
	end
end
check(n > 7000, "old index has only " .. n .. " keys")
check(bad == 0, bad .. " of " .. n .. " members differ")
check(dropped > 190, "only " .. dropped .. " surname-as-realm twins dropped")
-- every guild has its shipped number of names, less the dropped twins
for gi, entry in ipairs(old.guilds) do
	local want = #entry
	for _, name in ipairs(entry) do
		local fixed, twin = surname(name)
		if twin then want = want - 1 end
	end
	local names = M.PSS_ShippedNames(M.PSS_NormalizeGuild(entry.name)) or {}
	check(#names == want, entry.name .. ": " .. #names .. " names, expected " .. want)
end
check(M.PSS_ManagedStats().indexed == n - dropped, "indexed " .. M.PSS_ManagedStats().indexed .. " vs " .. n - dropped)
if not fail then print("PASS packed (" .. n .. " keys)") end
