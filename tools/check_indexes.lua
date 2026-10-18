-- The index coverage rule (search-helper STP-00251, DEC-00309): every key PSS saves is exposed by a Spyglass
-- index (its declaration's schemaKeys) or listed in NOT_INDEXED with the reason. A new feature that saves a
-- key adds its index (or a row here, shrink only) in the same commit. Option keys are the cfg index's.
--   lua5.1 tools/check_indexes.lua      (from the repo root; tools/check_rules.sh runs it)
-- It loads the addon in the harness (run.lua) to read the declarations.
local NOT_INDEXED = {
	["core.purge"] = "owners removed while Logging was not loaded: applied when it loads, no rows of their own",
	["core.revision"] = "a save counter for the upgrade helper",
	["core.imported"] = "import bookkeeping",
	["core.importedFrom"] = "import bookkeeping",
	["core.importedLegacyAt"] = "import bookkeeping",
	["core.logAllV1"] = "a one-time move marker",
	["options.showIgnoreDebug"] = "a debug switch",
	["options.windowSizes"] = "window places",
	["options.windowPoints"] = "window places",
	["options.columnWidths"] = "window places",
	["options.optionsV2012"] = "a one-time move marker",
	["options.euiIntegration"] = "retired integration flag",
	["options.blizzardSync"] = "the Blizzard ignore sync bookkeeping",
	["options.mapButtons"] = "minimap button places",
	["players.ignoreList"] = "old layout, read once by the upgrade",
	["players.typeList"] = "old layout, read once by the upgrade",
	["players.factionList"] = "old layout, read once by the upgrade",
	["players.dateList"] = "old layout, read once by the upgrade",
	["players.notes"] = "old layout, read once by the upgrade",
	["players.expList"] = "old layout, read once by the upgrade",
	["players.syncInfo"] = "old layout, read once by the upgrade",
	["guilds.scanFieldsDefaultV1"] = "a one-time move marker",
	["guilds.guildPlayerCleanupV3"] = "a one-time move marker",
	["rules.filterFormat"] = "a layout marker",
	["rules.optInFiltersV1"] = "a one-time move marker",
	["counts.historyFormat"] = "a layout marker",
	["counts.hiddenTotal"] = "old counters read once by the upgrade",
	["counts.filterTotal"] = "old counters read once by the upgrade",
	["counts.filterWhisperTotal"] = "old counters read once by the upgrade",
	["counts.filterPrivateTotal"] = "old counters read once by the upgrade",
	["counts.filterBlockedLast"] = "the last block of each filter, shown on its row (filters index)",
	["counts.guildRuleCountsV1"] = "a one-time move marker",
	["wh.jrn"] = "reserved for the journal (phase C declares its index)",
	["owned.bagProfileOf"] = "reserved for the bag manager (phase E declares its index)",
}

if M and M.PSS_IxNames then
	-- inside the harness: print what the declarations expose
	M.PSS_Need("Libraries")
	for _, name in ipairs(M.PSS_IxNames()) do
		for _, k in ipairs(M.PSS_Ix(name).schemaKeys or {}) do print("KEY " .. k .. " " .. name) end
	end
	print("DECLARED " .. #M.PSS_IxNames())
	return
end

local function read(path)
	local fh = assert(io.open(path, "rb"), path)
	local s = fh:read("*a")
	fh:close()
	return s
end

-- every saved key: the core keys, the routed groups (LAYOUT), the warehouse table, the owned keys
local keys = {}
PourSocialScore_NS = { M = {} }
dofile("PourSocialScore/PSS_Schema.lua")
local SCHEMA = PourSocialScore_NS.M.PSS_SCHEMA
for w in SCHEMA.core:gmatch("%S+") do keys["core." .. w] = true end
for w in SCHEMA.wh:gmatch("%S+") do keys["wh." .. w] = true end
for w in SCHEMA.owned:gmatch("%S+") do keys["owned." .. w:match("^[%a_][%w_]*")] = true end
local layout = read("PourSocialScore/PSS_SavedData.lua"):match("local LAYOUT = (%b{})")
for group, body in layout:gmatch("(%a+)%s*=%s*(%b{})") do
	for k in body:gmatch('"([%a_][%w_]*)"') do keys[group .. "." .. k] = true end
end

local h = io.popen("PSS_COMPONENTS=logging,warehouse lua5.1 tools/harness/run.lua . - - tools/check_indexes.lua 2>&1")
local out = h:read("*a")
h:close()
local covered, declared = {}, tonumber(out:match("DECLARED (%d+)"))
for k, ix in out:gmatch("KEY (%S+) (%S+)") do covered[k] = ix end
local problems = 0
if not declared or declared == 0 then print("FAIL indexes: the harness declared no index:\n" .. out:sub(1, 400)) os.exit(1) end
local list = {}
for k in pairs(keys) do list[#list + 1] = k end
table.sort(list)
for _, k in ipairs(list) do
	if not covered[k] and not NOT_INDEXED[k] then
		print("FAIL indexes: " .. k .. " is saved but no index exposes it (declare it in an index's schemaKeys, or add it to NOT_INDEXED with the reason)")
		problems = problems + 1
	end
end
-- shrink only: every NOT_INDEXED row names a key that is saved and not indexed
local APPROVED_ROWS = 34
local nrows = 0
for k in pairs(NOT_INDEXED) do
	nrows = nrows + 1
	if not keys[k] then print("FAIL indexes: NOT_INDEXED lists " .. k .. ", which is not saved (take the row out)") problems = problems + 1 end
	if covered[k] then print("FAIL indexes: NOT_INDEXED lists " .. k .. ", which index " .. covered[k] .. " exposes (take the row out)") problems = problems + 1 end
end
if nrows > APPROVED_ROWS then print("FAIL indexes: NOT_INDEXED grew to " .. nrows .. " rows (the list only shrinks)") problems = problems + 1 end
if problems > 0 then os.exit(1) end
print(("PASS indexes (%d saved keys, %d declared indexes, %d not indexed)"):format(#list, declared, nrows))
