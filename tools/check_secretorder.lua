-- Secret values (baseline 02 J7, PSS 02 section 10.1; 3.7.0.111, W-8): in PourSocialScore/PSS_ChatBlock.lua a value
-- is checked with isSecret before anything compares, indexes or measures it. A secret string has type "string" and
-- raises on ==, ~=, # and indexing, so `target == "" or isSecret(target)` crashes the handler (PSS_ChatBlock.lua:893
-- at a974459). The lint reads each line that names isSecret(x): the first isSecret(x) must come before the first
-- `x ==`, `x ~=`, `#x` or `x:` / `x.` on that line. Run: lua5.1 tools/check_secretorder.lua [file] (rules check).
-- `lua5.1 tools/check_secretorder.lua --self` proves the lint on four wrong lines (the mutants).
local function bad(line)
	local out = {}
	for v in line:gmatch("isSecret%(([%a_][%w_]*)%)") do
		local at = line:find("isSecret(" .. v .. ")", 1, true)
		for _, pat in ipairs({ "%f[%w_]" .. v .. "%s*[=~]=", "#" .. v .. "%f[^%w_]", "%f[%w_]" .. v .. "[:.%[]" }) do
			local p = line:find(pat)
			if p and p < at then out[#out + 1] = v break end
		end
	end
	return out
end

if arg[1] == "--self" then
	local cases = {
		{ 'if type(target) ~= "string" or target == "" or isSecret(target) then return end', true },
		{ 'if type(target) ~= "string" or isSecret(target) or target == "" then return end', false },
		{ 'if #name > 0 and isSecret(name) then return end', true },
		{ 'if name:lower() == x and not isSecret(name) then', true },
		{ 'if isSecret(author) or isSecret(guid) then return end', false },
	}
	local fail = false
	for _, c in ipairs(cases) do
		if (#bad(c[1]) > 0) ~= c[2] then print("FAIL secretorder self: " .. c[1]) fail = true end
	end
	if not fail then print("PASS secretorder self") end
	os.exit(fail and 1 or 0)
end

local path = arg[1] or "PourSocialScore/PSS_ChatBlock.lua"
local f = assert(io.open(path, "rb"))
local n, fail = 0, false
for line in f:lines() do
	n = n + 1
	if not line:match("^%s*%-%-") then
		for _, v in ipairs(bad(line)) do
			print(("secret order: %s:%d uses %s before isSecret(%s): %s"):format(path, n, v, v, (line:gsub("^%s+", ""))))
			fail = true
		end
	end
end
f:close()
os.exit(fail and 1 or 0)
