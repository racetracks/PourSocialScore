-- Packed shipped lists (3.0 Step 5.1), as a run.lua script: every member of
-- the unpacked 3.0.0-dev16 list (PSS_OLD_MANAGED, its index included) is
-- found in the same guild with the same name by the packed lookup, and
-- names that only start or end like a member are not.
local fail = false
local function check(ok, msg) if not ok then print("FAIL packed: " .. msg) fail = true end end

local old = {}
local chunk = assert(loadfile(os.getenv("PSS_OLD_MANAGED")))
setfenv(chunk, { PourSocialScore_NS = old })
chunk()
old = old.MANAGED_DATA.olympus

check(M.PSS_LoadManagedData(), "lists not loaded")
local n, bad = 0, 0
for ck, v in pairs(old.index) do
	n = n + 1
	local gi = math.floor(v / 65536)
	local entry = old.guilds[gi]
	local gkey = M.PSS_NormalizeGuild(entry.name)
	local r = M.PSS_IsManagedStaticMember(gkey, ck) and M.PSS_ManagedRecord(ck, gkey)
	if not (r and r.name == M.PSS_DisplayPlayer(entry[v - gi * 65536])) then
		bad = bad + 1
		if bad <= 5 then check(false, ck .. " not found as " .. tostring(entry[v - gi * 65536])) end
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
-- every guild has its shipped number of names
for gi, entry in ipairs(old.guilds) do
	local names = M.PSS_ShippedNames(M.PSS_NormalizeGuild(entry.name)) or {}
	check(#names == #entry, entry.name .. ": " .. #names .. " names, expected " .. #entry)
end
check(M.PSS_ManagedStats().indexed == n, "indexed " .. M.PSS_ManagedStats().indexed .. " vs " .. n)
if not fail then print("PASS packed (" .. n .. " keys)") end
