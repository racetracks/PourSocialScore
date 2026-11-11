-- Log search results dump (TST-00989, specs/search.md#10-identical-results): a run.lua script.
--   PSS_COMPONENTS=logging,warehouse lua5.1 tools/harness/run.lua . <save|-> - tools/harness/log_results.lua
-- Per query: `L <q> n=<rows>`, then one `L <q> <i> <col>...` line per row (columns tab-separated, in set.cols order).
-- Two builds give the same lines when a change is only speed.
M.PSS_Need("Libraries")
local History = M.PSS_History
local function logLoaded()
	if not M.PSS_LoggingReady() then M.PSS_LoadLogging() end
	return History.Log()
end
logLoaded()
local QUERIES = { "index=log gold", "index=log gold sell", "index=log gol*", "gold", "index=log,pss gold", "index=log gold | head 50", "index=log trade" }
for _, q in ipairs(QUERIES) do
	local set = M.PSS_Search(q, { load = true })
	print("L " .. q .. " n=" .. tostring(set and set.n or "nil"))
	if set then
		for i = 1, set.n or 0 do
			local row = set[i]
			local t = {}
			for c = 1, #(set.cols or {}) do t[c] = tostring(row and row[c]) end
			print("L " .. q .. " " .. i .. "\t" .. table.concat(t, "\t"))
		end
	end
end
