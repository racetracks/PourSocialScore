-- The core / community part seam (managed communities, build A), as a run.lua
-- script on a fresh login:
--   * before anything is switched on the part is not loaded and every core
--     wrapper answers its "not loaded" value
--   * switching the olympus rule on loads the part and the same wrappers
--     answer from it
local fail = false
local function check(ok, msg) if not ok then print("FAIL seam: " .. msg) fail = true end end
local loaded = function() return C_AddOns.IsAddOnLoaded("PourSocialScore_Communities") end
local db = PourSocialScoreDB

check(not loaded(), "part loaded at login")
check(M.PSS_Community == nil, "PSS_Community set before the part loads")
check(type(M.PSS_GuildCore) == "table", "PSS_GuildCore missing")
check(M.PSS_ShippedNames("olympus") == nil, "ShippedNames before load")
check(M.PSS_IsManagedStaticMember("olympus", "nobody-classicbetapvp") == false, "static member before load")
check(M.PSS_ManagedRecord("nobody-classicbetapvp", "olympus") == nil, "record before load")
check(M.PSS_ManagedDataLoaded() == false, "data loaded before load")
local st = M.PSS_ManagedStats()
local sum = 0
for _, entry in ipairs(PourSocialScore_NS.MANAGED.groups[1].guilds) do sum = sum + entry.n end
check(st.loaded == false, "stats loaded before load")
check(st.indexed == 0, "stats indexed before load: " .. tostring(st.indexed))
check(st.shipped == sum, "stats shipped " .. tostring(st.shipped) .. " vs " .. sum)
check(M.PSS_GuildMemberCount(db.guildData.olympus, "olympus") == 197, "olympus count before load")
check(M.PSS_PruneManagedMarks() == 0, "prune before load")
check(pcall(M.PSS_FlushManaged), "flush raised an error before load")

M.PSS_SetManagedGroupActive("olympus", true)
check(loaded(), "part not loaded after switching on")
local names = { "Build", "Loaded", "ShippedOf", "ShippedNames", "Record", "Held", "Keep",
	"Tombstone", "EachShipped", "Count", "PruneMarks", "Flush", "Stats" }
check(type(M.PSS_Community) == "table", "PSS_Community not a table after load")
if type(M.PSS_Community) == "table" then
	for _, n in ipairs(names) do
		check(type(M.PSS_Community[n]) == "function", "seam function missing: " .. n)
	end
end
local list = M.PSS_ShippedNames("olympus")
check(type(list) == "table" and type(list[1]) == "string", "first shipped name not a string")
if type(list) == "table" and type(list[1]) == "string" then
	check(M.PSS_IsManagedStaticMember("olympus", M.PSS_CanonPlayer(list[1])) == true, "first shipped name not a static member")
end
check((M.PSS_ManagedStats().indexed or 0) > 0, "indexed not above 0 after load")
check(M.PSS_GuildMemberCount(db.guildData.olympus, "olympus") == 197, "olympus count after load")

if not fail then print("PASS seam") end
