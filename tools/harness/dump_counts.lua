-- Prints every number of M.PSS_Validate() ("N key=value", sorted), as a
-- run.lua script. validate_all.sh runs
-- it on the same save with the previous and the current build to show a
-- moving upgrade step keeps every count.
local n = M.PSS_Validate().n
local ks = {} for k in pairs(n) do ks[#ks + 1] = k end table.sort(ks)
for _, k in ipairs(ks) do print("N " .. k .. "=" .. tostring(n[k])) end
