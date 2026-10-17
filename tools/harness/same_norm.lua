-- Normalises a saved file for same_saves.sh (3.4.1.51, core uplift S2b):
-- the Player Ignore List's old layout (seven parallel arrays) and the new
-- one (`list`, one sparse record per entry) are written in the new shape,
-- with a legacy duplicate of one kind and name dropped (the first stays),
-- and the upgrade record's step, undo slot and failure are left out (a stage that adds an upgrade
-- step moves it on purpose). Everything else is written as it is, so the
-- other stores are still compared byte for byte.
--   lua5.1 tools/harness/same_norm.lua <in.lua> <out.lua>
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local H = dofile(here .. "/wow_stub.lua")
local env = {}
local chunk = assert(loadfile(arg[1]))
setfenv(chunk, env)
chunk()

local ARRAYS = { "ignoreList", "typeList", "factionList", "dateList", "notes", "expList", "syncInfo" }
local function text(s) return type(s) == "string" and s ~= "" and s or nil end

local function record(names, i, t)
	local e = { name = names[i], date = text(t.dateList[i]), faction = text(t.factionList[i]), note = text(t.notes[i]) }
	if t.typeList[i] ~= nil and t.typeList[i] ~= "player" then e.kind = t.typeList[i] end
	if type(t.expList[i]) == "number" and t.expList[i] > 0 then e.exp = t.expList[i] end
	if type(t.syncInfo[i]) == "table" and #t.syncInfo[i] > 0 then e.sync = t.syncInfo[i] end
	return e
end

for _, holder in ipairs({ "PourSocialScoreDB", "PSS_PlayersDB" }) do
	local t = env[holder]
	if type(t) == "table" and type(t.ignoreList) == "table" then
		for _, k in ipairs(ARRAYS) do if type(t[k]) ~= "table" then t[k] = {} end end
		local list, seen = type(t.list) == "table" and t.list or {}, {}
		for i = 1, #list do seen[(list[i].kind or "player") .. ":" .. tostring(list[i].name):lower()] = true end
		for i = 1, #t.ignoreList do
			local e = record(t.ignoreList, i, t)
			local key = (e.kind or "player") .. ":" .. tostring(e.name):lower()
			if not seen[key] then seen[key] = true; list[#list + 1] = e end
		end
		t.list = list
		for _, k in ipairs(ARRAYS) do t[k] = nil end
	end
	if type(t) == "table" and type(t.list) == "table" then
		-- (a list with duplicates written by the old layout's code path)
		local out, seen = {}, {}
		for _, e in ipairs(t.list) do
			local key = (e.kind or "player") .. ":" .. tostring(e.name):lower()
			if not seen[key] then seen[key] = true; out[#out + 1] = e end
		end
		t.list = out
	end
	if type(t) == "table" and type(t.upgrade) == "table" then t.upgrade.step = nil t.upgrade.at = nil t.upgrade.undo = nil t.upgrade.fail = nil end
end

local names = {}
for k in pairs(env) do names[#names + 1] = k end
table.sort(names)
local fh = assert(io.open(arg[2], "w"))
for _, k in ipairs(names) do fh:write(k, " = ", H.serialize(env[k]), "\n") end
fh:close()
