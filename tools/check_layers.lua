-- check_layers.lua
-- Rule 6: client front-end code never lives in the core logic files. Run
-- by tools/check_rules.sh from the repo root (Lua 5.1).
--
--   lua5.1 tools/check_layers.lua
--
-- The core files below may keep data, decide, and say "something changed"
-- with M.Events.Fire. They may not draw or open anything: no frames other
-- than plain event frames (CreateFrame("Frame")), no tooltips, dialogs,
-- menus, anchors or font strings, and no calls into the window code
-- (M.UI, M.Widgets, PSSUpdate*, PSS_Refresh*, PSS_Show*, the PSS window
-- frames). Strings and comments are not checked.
--
-- Allowed on purpose: PSS_ChatBlock.lua hides and checks Blizzard's own
-- invite / duel / trade popups, because declining them is the block.

local segments = dofile((arg[0]:match("^(.*[/\\])") or "") .. "lua_segments.lua")

local CORE = {
	"PSS_Localization.lua", "PSS_Globals.lua", "PSS_Perf.lua", "PSS_Watch.lua", "PSS_Trig.lua", "PSS_Events.lua", "PSS_Whois.lua",
	"PSS_Communities.lua", "PSS_ChatHistory.lua",
	"PSS_ChatBlock.lua", "PSS_ChatFilters.lua", "PSS_PlayerIgnoreList.lua", "PSS_GuildIgnoreList.lua",
	"PSS_WhContainers.lua", "PSS_ItemRead.lua", "PSS_ItemDict.lua", "PSS_WhStore.lua", "PSS_WhIndex.lua", "PSS_ItemSearch.lua", "PSS_Money.lua", "PSS_MoneyValue.lua",
	"PSS_Gw.lua", "PSS_GwSyndicator.lua", "PSS_WhImport.lua", "PSS_Err.lua", "PSS_Bus.lua", "PSS_Codec.lua", "PSS_Index.lua", "PSS_Store.lua", "PSS_Query.lua", "PSS_Entity.lua",
	"PSS_WhoisHarvest.lua", "PourSocialScore.lua", "PSS_Options.lua", "PSS_ImportExport.lua", "PSS_PlayerQuery.lua", "PSS_PlayerRows.lua", "PSS_Validate.lua", "PSS_GuildQuery.lua", "PSS_FilterQuery.lua",
	"PSS_ViewNav.lua", "PSS_ManagerNav.lua", "PSS_DetailQuery.lua", "PSS_PlayerView.lua", "PSS_GuildView.lua", "PSS_FilterView.lua", "PSS_EventsView.lua", "PSS_OptionsView.lua", "PSS_RowMenus.lua", "PSS_Graphics.lua", "PSS_MacroData.lua", "PSS_Macros.lua", "PSS_AddonsQuery.lua", "PSS_AddonsView.lua",
}

-- { Lua pattern, what it is }
local BANNED = {
	{ "CreateFrame%s*%(%s*\"[^\"]*\"%s*,", "a frame with a parent or template (only plain event frames)" },
	{ "CreateFrame%s*%(%s*\"[^\"Ff][^\"]*\"", "a frame other than an event frame" },
	{ "GameTooltip", "a tooltip" },
	{ "StaticPopupDialogs", "a dialog" },
	{ "StaticPopup_Show", "a dialog" },
	{ "MenuUtil", "a menu" },
	{ "UIParent", "a window anchor" },
	{ ":SetPoint%s*%(", "a frame anchor" },
	{ ":CreateFontString%s*%(", "a font string" },
	{ ":CreateTexture%s*%(", "a texture" },
	{ "M%.UI[%.%[]", "the UI kit" },
	{ "M%.Widgets[%.%[]", "the widgets" },
	{ "PSSUpdate%w*", "a window refresh (fire an event instead)" },
	{ "M%.PSS_Refresh%w*", "a window refresh (fire an event instead)" },
	{ "M%.PSS_Show%w*", "a window (fire an event instead)" },
	{ "M%.PSSGuild%w*Frame", "a window frame" },
	{ "_G%[\"PSS\"%]", "the main window" },
	{ "_G%.PSS%f[^%w_]", "the main window" },
}

-- Core functions that only print to chat or tidy data may still be named
-- PSS_Refresh*/PSS_Show* (definitions, not calls into the UI).
local ALLOWED_NAMES = {
	["M.PSS_RefreshGuildActive"] = true,		-- recomputes g.enabled (data)
}

local problems = 0

local function checkFile(path)
	local fh = io.open(path, "rb")
	if not fh then
		if path:find("PSS_Wh") or path:find("PSS_Item") or path:find("PSS_Money") or path:find("PSS_Gw") then return end		-- a warehouse file of a later package
		print(path .. ": missing (update the CORE list in tools/check_layers.lua)")
		problems = problems + 1
		return
	end
	local src = fh:read("*a")
	fh:close()
	local line = 1
	for _, seg in ipairs(segments(src)) do
		if seg.kind == "code" then
			for _, b in ipairs(BANNED) do
				local init = 1
				while true do
					local s, e = seg.text:find(b[1], init)
					if not s then break end
					local word = seg.text:sub(s, e)
					if not ALLOWED_NAMES[word] then
						local at = line + select(2, seg.text:sub(1, s):gsub("\n", ""))
						print(("%s:%d: %s in a core file: %s"):format(path, at, b[2], word))
						problems = problems + 1
					end
					init = e + 1
				end
			end
		end
		line = line + select(2, seg.text:gsub("\n", ""))
	end
end

------------------------------------------------------------------------
-- Services never call views (one-build plan A10, TST-p225): a file of the data
-- and service layer names no function that a *View.lua file defines, so
-- splitting Libraries later is a pure file move.
--   lua5.1 tools/check_layers.lua --services <file> ...    check those files only
------------------------------------------------------------------------
local SERVICES = { "PSS_Bus.lua", "PSS_Err.lua", "PSS_Codec.lua", "PSS_Index.lua", "PSS_Store.lua", "PSS_Query.lua", "PSS_Entity.lua",
	"PSS_WhContainers.lua", "PSS_ItemRead.lua", "PSS_ItemDict.lua", "PSS_WhStore.lua", "PSS_WhIndex.lua", "PSS_ItemSearch.lua",
	"PSS_Money.lua", "PSS_MoneyValue.lua", "PSS_Gw.lua", "PSS_GwSyndicator.lua", "PSS_WhImport.lua" }

local function viewNames()
	local names = {}
	local ls = io.popen('ls PourSocialScore_Libraries/*View.lua 2>/dev/null')
	for path in ls:lines() do
		local fh = io.open(path, "rb")
		local src = fh:read("*a")
		fh:close()
		for name in src:gmatch("function%s+M%.(PSS_[%w_]+)") do names[name] = path end
		for name in src:gmatch("\nM%.(PSS_[%w_]+)%s*=") do names[name] = path end
	end
	ls:close()
	return names
end

local function checkServices(files)
	local views, bad = viewNames(), 0
	for _, path in ipairs(files) do
		local fh = io.open(path, "rb")
		if fh then
			local src = fh:read("*a")
			fh:close()
			local line = 1
			for _, seg in ipairs(segments(src)) do
				if seg.kind == "code" then
					for name in seg.text:gmatch("M%.(PSS_[%w_]+)") do
						if views[name] then
							print(("%s: a services file uses %s, defined in the view file %s"):format(path, name, views[name]))
							bad = bad + 1
						end
					end
				end
				line = line + select(2, seg.text:gsub("\n", ""))
			end
		end
	end
	return bad
end

if arg[1] == "--services" then
	local files = {}
	for i = 2, #arg do files[#files + 1] = arg[i] end
	os.exit(checkServices(files) > 0 and 1 or 0)
end
do
	local files = {}
	for _, n in ipairs(SERVICES) do files[#files + 1] = "PourSocialScore_Libraries/" .. n end
	problems = problems + checkServices(files)
end

-- the core files live in the PourSocialScore folder (3.0 layout)
-- core logic files live in the core or in the on-demand back end
local function where(path)
	for _, dir in ipairs({ "PourSocialScore/", "PourSocialScore_Libraries/" }) do
		local fh = io.open(dir .. path, "rb")
		if fh then fh:close() return dir .. path end
	end
	return "PourSocialScore/" .. path
end
for _, path in ipairs(CORE) do checkFile(where(path)) end

------------------------------------------------------------------------
-- The GUI boundary (service-bus-helper DEC-00195, TST-00195, TST-00196):
-- the window opens only from a listed user entry, and the GUI folder
-- listens to core events only through ns.Listen (while shown).
------------------------------------------------------------------------
-- file -> { enclosing function = the user entry it serves }
local ENTRIES = {
	["PourSocialScore/PSS_BlizzardUI.lua"] = { ["M.PSS_OpenUI"] = "the dispatcher of every user entry", hostShow = "the Friends window shown, option openWithFriends", func = "an AddOns compartment click" },
	["PourSocialScore/PSS_Whois.lua"] = { PSS_AddonsBinding = "the key binding Open Addon Manager" },
	["PourSocialScore_Libraries/PSS_Commands.lua"] = { ["M.PSS_SlashPSS"] = "/pss, /acp" },
	["PourSocialScore_Libraries/PSS_DttView.lua"] = { ["M.PSS_DttCommand"] = "/pss dtt options" },
	["PourSocialScore_Libraries/PSS_WhView.lua"] = { ["M.PSS_WhOpenEverywhere"] = "/pss wh" },
	["PourSocialScore_Libraries/PSS_IxExport.lua"] = { ["M.PSS_QExport"] = "/pss q export" },
	["PourSocialScore_Libraries/PSS_Graphics.lua"] = { ["M.PSS_GfxOpen"] = "/pss gfx", ["M.PSS_GfxAsk"] = "the keep prompt after the player's import and reload" },
}

local function enclosing(ls, i)
	for j = i, 1, -1 do
		local name = ls[j]:match("^%s*function%s+([%w_%.:]+)%s*%(") or ls[j]:match("^%s*local%s+function%s+([%w_]+)%s*%(")
			or ls[j]:match("^%s*([%w_%.]+)%s*=%s*function%s*%(")
		if name then return name end
	end
	return "(file level)"
end

-- ns.DeepDive opens the console from the window's buttons only (E06)
local DEEP_OK = { "PSS_Detail", "PSS_History", "PSS_Players", "PSS_Guilds", "PSS_Filters", "PSS_QueryView", "PSS_Console", "PSS_Window" }
local function deepScan(path, ls)
	local n = 0
	local okFile = false
	for _, f in ipairs(DEEP_OK) do if path:find("^PourSocialScore_GUI/" .. f .. "%.lua$") then okFile = true end end
	for i = 1, #ls do
		local l = ls[i]:gsub("%-%-.*$", "")
		if l:find("DeepDive%(") and not l:find("function%s+ns%.DeepDive") and not okFile then
			print(("%s:%d: ns.DeepDive is called only from the window's buttons"):format(path, i))
			n = n + 1
		end
	end
	return n
end
-- the self-test of the rule: PSS_LAYERS_ONLY=<file> PSS_LAYERS_AS=<path it stands for>
if os.getenv("PSS_LAYERS_ONLY") then
	local ls = {}
	for l in io.lines(os.getenv("PSS_LAYERS_ONLY")) do ls[#ls + 1] = l end
	os.exit(deepScan(os.getenv("PSS_LAYERS_AS") or os.getenv("PSS_LAYERS_ONLY"), ls) > 0 and 1 or 0)
end

local find = io.popen('find PourSocialScore PourSocialScore_* -name "*.lua" 2>/dev/null | sort')
local seen, bad = 0, 0
for path in find:lines() do
	local ls = {}
	local fh = io.open(path, "rb")
	for l in fh:lines() do ls[#ls + 1] = l end
	fh:close()
	local inGui = path:find("^PourSocialScore_GUI/") ~= nil
	bad = bad + deepScan(path, ls)
	for i = 1, #ls do
		local l = ls[i]:gsub("%-%-.*$", "")
		if not inGui then
			local call = (l:find('PSS_Need%(%s*"GUI"%s*%)') and 'PSS_Need("GUI")')
				or (l:find("PSS_OpenUI%(") and not l:find("^%s*function%s+M%.PSS_OpenUI") and "M.PSS_OpenUI")
			if call then
				seen = seen + 1
				local fn = enclosing(ls, i)
				if not (ENTRIES[path] and ENTRIES[path][fn]) then
					print(("%s:%d: %s in %s is not a listed user entry (the window opens only as the player asks; list it in ENTRIES with its entry and in the catalogue)"):format(path, i, call, fn))
					bad = bad + 1
				end
			end
		elseif l:find('M%.Events%.Register%(%s*"') then
			print(("%s:%d: the window listens outside ns.Listen (it must hear core events only while shown)"):format(path, i))
			bad = bad + 1
		end
	end
end
find:close()
if seen == 0 then print("boundary scan found no GUI open at all: the scan is broken") bad = bad + 1 end
-- a window or a tooltip never takes a nil from a service (one-build plan TST-p204): the GUI folder asks through
-- M.PSS_CallSet (a record set always); the tooltip file checks the second value of every M.PSS_Call
local lint = io.popen('find PourSocialScore_GUI -name "*.lua" 2>/dev/null; echo PourSocialScore_Libraries/PSS_WhTooltip.lua')
for path in lint:lines() do
	local fh = io.open(path, "rb")
	if fh then
		local n = 0
		for l in fh:lines() do
			n = n + 1
			if l:find("M%.PSS_Call%(") and not l:match("^%s*%-%-") then
				local ok = path:find("PSS_WhTooltip") and (l:find("local [%w_]+, %w*err = M%.PSS_Call%(") or l:find("add%(tip, M%.PSS_Call%("))
				if not ok then
					print(("%s:%d: an unchecked M.PSS_Call in a window or tooltip file (use M.PSS_CallSet, or check the second value)"):format(path, n))
					bad = bad + 1
				end
			end
		end
		fh:close()
	end
end
lint:close()
problems = problems + bad
if problems > 0 then
	print("Core files must not hold UI code (rule 6). Move it to a UI file and fire an event from the core.")
	os.exit(1)
end
