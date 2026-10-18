-- The Spyglass console (search-helper, phase B, 3.8.0.119), as a run.lua script. The phase is PSS_PHASE;
-- each prints "PASS console <phase>" or "FAIL console: <phase>: <what>". Run by console_phases.sh.
local phase = os.getenv("PSS_PHASE") or "skeleton"
local fail = false
local function check(ok, msg) if not ok then print("FAIL console: " .. phase .. ": " .. tostring(msg)) fail = true end return ok end
check(M.PSS_Need("Libraries"), "Libraries did not load")
local PH = {}

local ui
local function GUI()
	if not ui then
		check(M.PSS_Need("GUI"), "GUI did not load")
		ui = H.Private("PourSocialScore_GUI")
	end
	return ui
end

-- fn(n, name) in Modern (2), Classic (0), Dark (1); the look is restored to Modern
local function looks(fn)
	local u = GUI()
	for _, p in ipairs({ { 2, "modern" }, { 0, "classic" }, { 1, "dark" } }) do
		M.PSS_SetOpt("uiSkin", "global", p[1])
		u.Fresh()
		fn(p[1], p[2])
	end
	M.PSS_SetOpt("uiSkin", "global", 2)
	u.Fresh()
end

-- UTC seconds of a civil date (Howard Hinnant's days_from_civil)
local function utc(y, m, d, h, mi, s)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = math.floor((153 * mp + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return (era * 146097 + doe - 719468) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + (s or 0)
end

-- a record set from column names and rows (n = row count)
local function set(cols, rows)
	local s = M.PSS_Set(cols)
	for i, r in ipairs(rows or {}) do s[i] = r end
	s.n = #(rows or {})
	return s
end

PH.skeleton = function()
	check(M.PSS_CONSOLE_NAME == "Spyglass", "M.PSS_CONSOLE_NAME is " .. tostring(M.PSS_CONSOLE_NAME))
end

local f = PH[phase]
if not f then
	check(false, "no such phase")
else
	local ok, e = xpcall(f, debug.traceback)
	if not ok then check(false, "raised: " .. tostring(e)) end
end
if not fail then print("PASS console " .. phase) end
