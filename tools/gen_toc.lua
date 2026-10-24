-- Generates every TOC of the six folders from tools/toc/manifest.txt.
--   lua5.1 tools/gen_toc.lua            write all TOCs
--   lua5.1 tools/gen_toc.lua --check    write nothing, list stale TOCs, exit 1
--   lua5.1 tools/gen_toc.lua --install  print "<flavour> <folder>" per install line
-- Run from the repo root.
local MANIFEST = "tools/toc/manifest.txt"
local ORDER = { "retail", "forever", "tbc" }
local TYPE = { retail = "standard", forever = "camelot", tbc = "tbc" }
local SUFFIX = { retail = "_Mainline", forever = "_Camelot", tbc = "_TBC" }
local BASE_IFACE = "120007, 16001, 20506"

local function fail(msg)
	io.stderr:write(msg, "\n")
	os.exit(1)
end

local function readAll(path)
	local f = io.open(path, "rb")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

local mode = arg and arg[1]
local text = readAll(MANIFEST) or fail("cannot read " .. MANIFEST)
local iface, install, folders, cur = {}, {}, {}, nil
local installLine = {}
local n = 0
for line in (text .. "\n"):gmatch("(.-)\r?\n") do
	n = n + 1
	if line:find("%S") and not line:find("^#") then
		local kind, a, b = line:match("^(%a+) (%S+) (%S+)$")
		if kind == "interface" then
			if not TYPE[a] or not b:find("^%d+$") then fail("manifest:" .. n .. ": bad interface line") end
			iface[a] = b
		elseif kind == "install" then
			if not TYPE[a] then fail("manifest:" .. n .. ": bad install flavour") end
			if not b:find("^_[a-z]+_$") then fail("manifest: bad install line " .. n) end
			install[a] = b
			installLine[#installLine + 1] = a
		else
			local fk, name = line:match("^(folder) (%S+)$")
			if fk then
				cur = { name = name, files = {} }
				folders[#folders + 1] = cur
			else
				if not cur then fail("manifest:" .. n .. ": file line before any folder") end
				local path, tag = line:match("^(%S+)$"), nil
				if not path then path, tag = line:match("^(%S+) (%S+)$") end
				if not path then fail("manifest:" .. n .. ": malformed file line") end
				if tag and not TYPE[tag] then fail("manifest:" .. n .. ": unknown flavour tag " .. tag) end
				cur.files[#cur.files + 1] = { path = path, tag = tag }
			end
		end
	end
end
for _, fl in ipairs(ORDER) do
	if not iface[fl] then fail("manifest: missing interface line for " .. fl) end
	if not install[fl] then fail("manifest: missing install line for " .. fl) end
end
if #installLine ~= #ORDER then fail("manifest: bad install line " .. (#installLine)) end
if #folders == 0 then fail("manifest: no folder lines") end

if mode == "--install" then
	for _, fl in ipairs(installLine) do print(fl .. " " .. install[fl]) end
	os.exit(0)
end

local function tagged(tag)
	local others = {}
	for _, fl in ipairs(ORDER) do
		if fl ~= tag then others[#others + 1] = TYPE[fl] end
	end
	return " [AllowLoadGameType " .. TYPE[tag] .. "][ExcludeLoadGameType " .. table.concat(others, ", ") .. "]"
end

local stale = false
for _, fo in ipairs(folders) do
	local dir = fo.name .. "/"
	local base = dir .. fo.name .. ".toc"
	local old = readAll(base) or fail("cannot read " .. base)
	local header = {}
	for l in (old .. "\n"):gmatch("(.-)\r?\n") do
		if l:find("^## ") and not l:find("^## Interface:") then header[#header + 1] = l end
	end
	local function build(interface, listFor)
		local out = { "## Interface: " .. interface }
		for _, l in ipairs(header) do out[#out + 1] = l end
		out[#out + 1] = ""
		for _, f in ipairs(fo.files) do
			if listFor == nil then
				out[#out + 1] = f.path .. (f.tag and tagged(f.tag) or "")
			elseif not f.tag or f.tag == listFor then
				out[#out + 1] = f.path
			end
		end
		return table.concat(out, "\n") .. "\n"
	end
	local jobs = { { base, build(BASE_IFACE, nil) } }
	for _, fl in ipairs(ORDER) do
		jobs[#jobs + 1] = { dir .. fo.name .. SUFFIX[fl] .. ".toc", build(iface[fl], fl) }
	end
	for _, j in ipairs(jobs) do
		if mode == "--check" then
			if readAll(j[1]) ~= j[2] then
				print(j[1] .. ": differs from manifest")
				stale = true
			end
		else
			local f = io.open(j[1], "wb") or fail("cannot write " .. j[1])
			f:write(j[2])
			f:close()
		end
	end
end
if mode == "--check" and stale then os.exit(1) end
