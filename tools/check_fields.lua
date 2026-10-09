-- check_fields.lua
-- Core uplift S2 (3.4.1.50): every read or write of a member field that S3
-- stops saving goes through the accessors in PourSocialScore/
-- PSS_GuildIgnoreList.lua, between its "(member fields)" and
-- "(/member fields)" comments, so S3 changes them in one place. This fails
-- any of those fields used in code anywhere else (strings and comments do
-- not count: the schema map and the export's field list name them).
-- Run by tools/check_rules.sh from the repo root (Lua 5.1).
local segments = dofile((arg[0]:match("^(.*[/\\])") or "") .. "lua_segments.lua")

local FIELDS = { "_playerKey", "_canon", "_gkey", "_managed", "_virtual", "memberCount" }
local OWNER = "PourSocialScore/PSS_GuildIgnoreList.lua"
local BEGIN, END = "-- (member fields)", "-- (/member fields)"

local problems = 0
local function fail(msg)
	print(msg)
	problems = problems + 1
end

local p = io.popen("ls PourSocialScore*/*.lua")
for path in p:lines() do
	local fh = assert(io.open(path, "rb"))
	local src = fh:read("*a")
	fh:close()
	if path == OWNER then
		local b = src:find(BEGIN, 1, true)
		local e = src:find(END, 1, true)
		if not (b and e and b < e) then
			fail(path .. ": the " .. BEGIN .. " block is missing")
		else
			-- the block's lines stay, blank, so line numbers still match
			src = src:sub(1, b - 1) .. src:sub(b, e):gsub("[^\n]", "") .. src:sub(e + 1)
		end
	end
	local line = 1
	for _, seg in ipairs(segments(src)) do
		if seg.kind == "code" then
			for _, f in ipairs(FIELDS) do
				local pat = "%f[%w_]" .. f:gsub("_", "%%_") .. "%f[^%w_]"
				local at = 1
				while true do
					local s = seg.text:find(pat, at)
					if not s then break end
					local before = seg.text:sub(1, s - 1)
					local _, nl = before:gsub("\n", "")
					-- a field (x.f, x:f, { f = }); a plain local of that name is fine
					local prev = before:match("([%.:]?)%s*$")
					local after = seg.text:sub(s + #f):match("^%s*(=?=?)")
					local inTable = before:match("[{,]%s*$") and after == "="
					if prev == "." or prev == ":" or inTable then
						fail(("%s:%d: %s outside the accessors (use M.PSS_Member* or the %s block, S2)"):format(path, line + nl, f, BEGIN))
					end
					at = s + #f
				end
			end
		end
		local _, nl = seg.text:gsub("\n", "")
		line = line + nl
	end
end
p:close()
os.exit(problems == 0 and 0 or 1)
