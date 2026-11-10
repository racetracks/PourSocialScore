-- Search Everywhere results dump (TST-00989, specs/search.md#10-identical-results): a run.lua script.
--   PSS_WH_SEED=1 PSS_COMPONENTS=addons,gfx,warehouse,bags lua5.1 tools/harness/run.lua . <save|-> - tools/harness/search_results.lua
-- Per text: the search stepped to done, then one `R <text> <key> <total> <where>` line per row; then
-- `H <ref> <value>` per holder ref; then the first entity but the current character is deleted through
-- `wh.delete` and the `R` lines print again as `R2`. Two builds give the same lines when a change is only speed.
M.PSS_Need("Libraries")
local TEXTS = { "e", "ep", "epi", "epic", "cloth", "potion", "epic & >400", "~epic" }

local function dump(prefix)
	for _, text in ipairs(TEXTS) do
		local rows, done = M.PSS_WhSearchRows(text, function() end)
		local n = 0
		while not done and n < 5000 do
			n = n + 1
			M.PSS_ItemSearchStep()
			H.RunTimers(1)
			rows, done = M.PSS_WhSearchRows(text, function() end)
		end
		for i = 1, #rows do
			local r = rows[i]
			print(("%s %s %s %s %s"):format(prefix, text, tostring(r.key), tostring(r.total), tostring(r.where)))
		end
	end
end

dump("R")
local list = M.PSS_WhHolders:list()
for i = 1, #list do print(("H %s %s"):format(tostring(list[i]), tostring(M.PSS_WhHolders:get(list[i])))) end

local me = M.PSS_Me and M.PSS_Me(false)
local ents = M.PSS_WhStore.Ents()
table.sort(ents)
local first
for i = 1, #ents do if ents[i] ~= me then first = ents[i]; break end end
if first then
	local ok, err = pcall(M.PSS_CallSet, "wh.delete", { cols = { "ent" }, n = 1, { first } })
	print(("DEL %s %s"):format(tostring(first), tostring(ok)))
end
dump("R2")
