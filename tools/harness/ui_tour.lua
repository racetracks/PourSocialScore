-- UI tour (run.lua script): builds every PSS window and tab with the WoW
-- stub, then writes what was drawn to PSS_UI_DUMP, one line per frame:
-- path, type, template, shown, size, text, anchor points and every other
-- Set... call with its last arguments. Two dumps from before and after a
-- change must be identical when the look did not change:
--
--   lua5.1 tools/harness/run.lua . <sv.lua> - tools/harness/ui_tour.lua
--
-- Also records chat output of the slash commands and the dialog texts.
local out = assert(os.getenv("PSS_UI_DUMP"), "set PSS_UI_DUMP=<file>")

local MT = getmetatable(UIParent)
local origIndex = MT.__index
local frames, seq = {}, 0

local function track(f)
	if type(f) == "table" and getmetatable(f) == MT and not frames[f] then
		seq = seq + 1
		frames[f] = { order = seq, calls = {}, points = {} }
	end
	return f
end

local SKIP = { SetScript = true, HookScript = true, SetAttribute = true }

MT.__index = function(t, k)
	local m = origIndex(t, k)
	if type(m) ~= "function" or type(k) ~= "string" then return m end
	if k:match("^Create") then
		return function(self, ...)
			track(self)
			return track(m(self, ...))
		end
	end
	if k:match("^Set") or k:match("^Clear") or k == "Show" or k == "Hide" or k:match("^Enable") or k:match("^Disable") then
		return function(self, ...)
			local rec = track(self) and frames[self]
			if k == "SetPoint" then
				rec.points[#rec.points + 1] = { ... }
			elseif k == "ClearAllPoints" then
				rec.points = {}
			elseif not SKIP[k] then
				rec.calls[k] = { n = select("#", ...), ... }
			end
			return m(self, ...)
		end
	end
	return m
end

local origCreateFrame = CreateFrame
function CreateFrame(...)
	return track(origCreateFrame(...))
end

-- tour --------------------------------------------------------------------
local errors = {}
local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then errors[#errors + 1] = name .. ": " .. tostring(err) end
	H.RunTimers()
end
local function click(name)
	local b = _G[name]
	local fn = b and b:GetScript("OnClick")
	if fn then fn(b, "LeftButton") end
end

local db = PourSocialScoreDB
step("add player", function() M.PSS_AddPlayer("Tourplayer-Realm", "a note", 0) end)
step("add filter", function() M.PSS_AddCustomFilter("Tour filter", "[word=tourword]", true) end)
step("build", function() M.PSS_GUI() end)
step("show", function() _G.PSS:Show() end)
for _, tab in ipairs({ "PSSTab1", "PSSTabGuild", "PSSTab2", "PSSTabIO", "PSSTab3", "PSSTab1" }) do
	step("tab " .. tab, function() click(tab) end)
end
step("refresh players", function() M.PSSUpdateUI(true) end)
step("refresh guilds", function() click("PSSTabGuild"); if M.PSSUpdateGuildUI then M.PSSUpdateGuildUI() end end)

local keys = {}
for k in pairs(db.guildData or {}) do keys[#keys + 1] = k end
table.sort(keys)
local manual, managed
for _, k in ipairs(keys) do
	local g = db.guildData[k]
	if g.managed and not managed then managed = k end
	if not g.managed and not manual then manual = k end
end
if manual then step("guild detail manual", function() M.PSS_ShowGuildDetail(manual) end) end
if managed then step("guild detail managed", function() M.PSS_ShowGuildDetail(managed) end) end
step("player detail", function() M.PSS_ShowPlayerDetail("Tourplayer-Realm") end)
if manual then step("guild history", function() M.PSS_ShowGuildBlockHistory(manual) end) end
step("player history", function() M.PSS_ShowPlayerBlockHistory("Tourplayer-Realm") end)

-- changes made while the windows are open must redraw them (core events)
step("late player", function() click("PSSTab1"); M.PSS_AddIgnore("Tourlate-Realm", true) end)
step("late filter", function() click("PSSTab2"); M.PSS_AddCustomFilter("Late filter", "[word=lateword]", true) end)
step("late guild", function() click("PSSTabGuild"); M.PSS_AddGuild("Tour Late Guild") end)
if manual then step("late guild detail", function() M.PSS_ShowGuildDetail(manual); M.PSS_SetGuildBlock(manual, "whisper", false) end) end

local chatStart = #H.chat + 1
step("slash pss", function() SlashCmdList.PSS("") end)
step("slash pss mem", function() SlashCmdList.PSS("mem") end)
for _, c in ipairs({ "list", "list npc", "list 5", "clear", "help" }) do
	step("slash pss " .. c, function() SlashCmdList.PSS(c) end)
end
for _, c in ipairs({ "status", "test Tourplayer-Realm", "chat", "debug", "check Tourplayer-Realm" }) do
	step("slash pssguild " .. c, function() SlashCmdList.PSSGUILD(c) end)
end

-- dump ----------------------------------------------------------------------
local paths = {}
local function childIndex(f)
	-- position among tracked siblings with the same parent, by creation order
	local p, n = f._parent, 0
	for g, r in pairs(frames) do
		if g._parent == p and not g._name and r.order <= frames[f].order then n = n + 1 end
	end
	return n
end
local function pathOf(f)
	if paths[f] then return paths[f] end
	local own
	if f._name then
		own = f._name
	else
		own = f._kind .. "#" .. childIndex(f)
	end
	local p = f._parent
	local path = (p and p ~= UIParent and frames[p]) and (pathOf(p) .. "/" .. own) or own
	paths[f] = path
	return path
end

local function val(v)
	local t = type(v)
	if t == "number" then return ("%.2f"):format(v) end
	if t == "string" then return ("%q"):format(v) end
	if t == "table" then
		if getmetatable(v) == MT then return "@" .. (frames[v] and pathOf(v) or (v._name or "?")) end
		return "{table}"
	end
	if t == "function" then return "fn" end
	return tostring(v)
end
local function args(a)
	local parts = {}
	for i = 1, (a.n or #a) do parts[#parts + 1] = val(a[i]) end
	return table.concat(parts, ",")
end

local lines = {}
for f, rec in pairs(frames) do
	local root = f
	while root._parent and frames[root._parent] do root = root._parent end
	-- only frames that belong to a named PSS window or to UIParent
	if root._name or root._parent == UIParent then
		local parts = { pathOf(f), f._kind, tostring(f._template), f:IsShown() and "shown" or "hidden",
			("%gx%g"):format(f._w, f._h), ("%q"):format(f._text or "") }
		local pts = {}
		for _, p in ipairs(rec.points) do pts[#pts + 1] = "(" .. args({ n = #p, unpack(p) }) .. ")" end
		parts[#parts + 1] = "points=" .. table.concat(pts)
		local ck = {}
		for k in pairs(rec.calls) do ck[#ck + 1] = k end
		table.sort(ck)
		for _, k in ipairs(ck) do
			if k ~= "SetPoint" and k ~= "SetText" and k ~= "SetSize" and k ~= "SetWidth" and k ~= "SetHeight" then
				parts[#parts + 1] = k .. "(" .. args(rec.calls[k]) .. ")"
			end
		end
		lines[#lines + 1] = table.concat(parts, " | ")
	end
end
table.sort(lines)

local dlg = {}
for name, d in pairs(StaticPopupDialogs) do
	if name:match("^PSS") then
		local f = {}
		for k, v in pairs(d) do f[#f + 1] = k .. "=" .. val(v) end
		table.sort(f)
		dlg[#dlg + 1] = "dialog " .. name .. " " .. table.concat(f, " ")
	end
end
table.sort(dlg)

local fh = assert(io.open(out, "w"))
for _, l in ipairs(lines) do fh:write(l, "\n") end
for _, l in ipairs(dlg) do fh:write(l, "\n") end
-- memory figures change with garbage collection timing, not with the look
for i = chatStart, #H.chat do fh:write("chat ", (H.chat[i]:gsub("[%d%.]+ [KM]B", "n MB")), "\n") end
for _, e in ipairs(errors) do fh:write("ERROR ", e, "\n") end
fh:close()
print(("ui tour: %d frames, %d dialogs, %d errors"):format(#lines, #dlg, #errors))
for _, e in ipairs(errors) do print("ERROR " .. e) end
