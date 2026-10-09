------------------------------------------------------------------------
-- POUR SOCIAL SCORE - ADDONS VIEW (for the AddOns tab, PourSocialScore_GUI)
--
-- What the window's AddOns tab shows and does, worked out here so the tab
-- only draws (the logic is PSS_AddonsQuery.lua). One view object per tab:
--   local V = M.PSS_AddonView()
--   V.who "me" | "all", V.view "group" | "az" | "lod", V.find, V.deps
--   V:Build()                  the list and its visible lines; the lines'
--                              count, the footer text, the empty text
--   V:Row(k, out)              line k: a header or an addon, its cells
--   V:Tick(k, on)  V:Toggle(k) V:CollapseAll(on)
--   V:Tip(k)  V:Menu(k)  V:Act(k, act, arg)
--   V:Sample()                 memory, once (never in combat)
--   V:Stats()                  the CPU and memory line at the top
--   V:Slots()  V:PresetMenu(p)  V:PresetAct(p, act, name)   (addon profiles)
--   V:ProfileMenu()  V:ManageMenu()  V:ProfileSelect(p, on)
--   V:Release()                the window closed: the list is dropped
-- A line is an addon (its position in the list) or a group header.
------------------------------------------------------------------------
local addon = PourSocialScore_NS
local M = addon.M

local type, tostring, ipairs, pairs = type, tostring, ipairs, pairs
local format, floor, lower = string.format, math.floor, string.lower
local concat = table.concat

local Q = M.PSS_AddonText

local COLORS = { ok = "ffffd100", off = "ff9d9d9d", lod = "ff71d5ff", warn = "ffff8000", bad = "ffff4040", reload = "ffc07fff" }
local RED = "ffff4040"
local ALERT = "|TInterface\\DialogFrame\\DialogIcon-AlertNew-16:14|t"
local QUESTION = "Interface\\ICONS\\INV_Misc_QuestionMark"

local T = {
	loaded = "%d of %d loaded",
	footer = "%d addons, %d on for %s",
	empty = "No addons match.",
	performance = "AddOn Performance",
	current = "Current CPU",
	average = "Average CPU",
	peak = "Peak CPU",
	encounter = "Encounter CPU",
	memory = "Memory",
	notSampled = "not sampled",
	notLoaded = "Not loaded.",
	lastRefresh = "(as of the last refresh)",
	author = "Author",
	version = "Version",
	requires = "Requires",
	optional = "Optional",
	pssTip = "Pour Social Score cannot be turned off here.",
	protectedTip = "Protected: Disable All and addon profiles leave it on.",
	coreHead = "Core Addon Profiles",
	layeredHead = "Layered Addon Profiles",
	noneSaved = "None saved",
	manage = "Manage Addon Profiles",
}

local function pct(v)
	if v >= 1 then return format("%d%%", floor(v + 0.5)) end
	if v >= 0.1 then return format("%.1f%%", v) end
	if v >= 0.01 then return format("%.2f%%", v) end
	return "0%"
end
M.PSS_AddonPct = pct

local function kbText(kb)
	if kb < 1024 then return format("%d KB", floor(kb + 0.5)) end
	return format("%.1f MB", kb / 1024)
end
M.PSS_AddonKBText = kbText

local function colored(key, text)
	return "|c" .. (COLORS[key] or COLORS.ok) .. text .. "|r"
end

-- a share, red with the alert mark above the client's warning share
local function shareText(v, warn)
	if v > warn then return "|c" .. RED .. pct(v) .. "|r " .. ALERT end
	return pct(v)
end

-- an addon's own icon as text, the question mark when it has none
local function iconText(i)
	local tex, atlas = M.PSS_AddonIcon(i)
	if atlas and CreateAtlasMarkup then return CreateAtlasMarkup(atlas, 16, 16) .. " " end
	return "|T" .. (tex or QUESTION) .. ":16|t "
end

local View = M.PSS_ListMixin({})
View.__index = View

function M.PSS_AddonView()
	return setmetatable({ who = "me", view = M.PSS_AddonViewMode(), deps = true, find = "", collapsed = {}, items = {}, n = 0,
		buf = {}, sampled = false }, View)
end

-- the list and the lines it shows: positive = an addon (its position),
-- negative = a header (minus its group number); a search shows every group open
function View:Build()
	self.view = M.PSS_AddonViewMode()
	local L = M.PSS_AddonList(self.who, self.sortMem and "mem" or self.view, self.find)
	self.L = L
	local items, n, lastg, on = self.items, 0, nil, 0
	local open = self.find ~= ""
	local buf = self.buf
	for p = 1, L.n do
		local gi = L.gi[p]
		if gi then
			if gi ~= lastg then
				lastg = gi
				n = n + 1
				items[n] = -gi
			end
			if open or not self.collapsed[L.groups[gi].name] then
				n = n + 1
				items[n] = p
			end
		else
			n = n + 1
			items[n] = p
		end
		if M.PSS_AddonRow(L.idx[p], self.who, buf).enabled then on = on + 1 end
	end
	for k = #items, n + 1, -1 do items[k] = nil end
	self.n = n
	self.footer = format(T.footer, L.n, on, self.who == "all" and Q.everyone or Q.me)
	return n, self.footer, T.empty
end

function View:Count() return self.n end

-- the cells of line k; out is reused by the tab
function View:Row(k, out)
	local item = self.items[k]
	local L = self.L
	if not item or not L then return nil end
	if item < 0 then
		local g = L.groups[-item]
		out.header, out.open = true, not self.collapsed[g.name]
		out.name, out.n = g.name, g.to - g.from + 1
		out.text = format("%s (%d)", g.name, out.n)
		out.mem = kbText(M.PSS_AddonMemGroup(L, -item))
		out.status, out.load, out.locked, out.pss, out.outdated = "", false, false, false, false
		-- the group's tick: 0 none on, 1 some, 2 all
		local on = 0
		for p = g.from, g.to do
			if M.PSS_AddonRow(L.idx[p], self.who, self.buf).enabled then on = on + 1 end
		end
		out.tick = on == 0 and 0 or (on == out.n and 2 or 1)
		return out
	end
	local r = M.PSS_AddonRow(L.idx[item], self.who, self.buf)
	out.header = false
	out.i, out.name = r.i, r.name
	local indent = L.gi[item] and "      " or ""
	out.text = indent .. iconText(r.i) .. colored(r.status, r.title)
	out.status = colored(r.status, r.text) .. (r.outdated and (" " .. ALERT) or "")
	out.mem = r.loaded and kbText(M.PSS_AddonMemOf(r.i)) or ""
	out.tick = r.state == 0 and 0 or (r.state == 1 and 1 or 2)
	out.load, out.locked, out.pss, out.outdated, out.dim = r.canLoad, r.locked, r.pss, r.outdated, not self.sampled and r.loaded
	return out
end

-- a header's lines: positions a to b of the list
function View:Members(gi)
	local g = self.L and self.L.groups[gi]
	if g then return g.from, g.to end
end

function View:Tick(k, on)
	local item = self.items[k]
	if not item or not self.L then return false end
	if item < 0 then
		local a, b = self:Members(-item)
		return M.PSS_AddonTickMany(self.L, a, b, on, self.who, self.deps)
	end
	return M.PSS_AddonTick(self.L.idx[item], on, self.who, self.deps)
end

function View:Toggle(k)
	local item = self.items[k]
	if item and item < 0 and self.L then
		local name = self.L.groups[-item].name
		self.collapsed[name] = (not self.collapsed[name]) or nil
	end
end

function View:CollapseAll(on)
	for _, g in ipairs(self.L and self.L.groups or {}) do self.collapsed[g.name] = on or nil end
end

function View:Sample()
	local total = M.PSS_AddonMemory()
	self.total, self.sampled = total, total ~= nil
	return self.sampled
end

local function cpuLines(lines, warn, avg, cur, peak, enc)
	lines[#lines + 1] = format("%s: %s", T.average, shareText(avg, warn))
	lines[#lines + 1] = format("%s: %s", T.current, shareText(cur, warn))
	lines[#lines + 1] = format("%s: %s", T.peak, shareText(peak, warn))
	lines[#lines + 1] = format("%s: %s", T.encounter, shareText(enc, warn))
end

-- the tooltip of line k
function View:Tip(k)
	local item = self.items[k]
	local L = self.L
	if not item or not L then return nil end
	local lines = {}
	local warn = M.PSS_AddonWarn()
	if item < 0 then
		local gi = -item
		local g = L.groups[gi]
		local avg, cur, peak, enc, loaded, total = M.PSS_AddonCPUGroup(L, gi)
		lines[1] = g.name
		lines[2] = format(T.loaded, loaded or 0, total or 0)
		if avg then
			lines[3] = ""
			cpuLines(lines, warn, avg, cur, peak, enc)
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = format("%s: %s%s", T.memory, kbText(M.PSS_AddonMemGroup(L, gi)), self.sampled and "" or (" " .. T.lastRefresh))
		return concat(lines, "\n")
	end
	local i = L.idx[item]
	local r = M.PSS_AddonRow(i, self.who, self.buf)
	lines[1] = r.title
	local author, version = M.PSS_AddonMeta(i, "Author"), M.PSS_AddonMeta(i, "Version")
	if author then lines[#lines + 1] = format("%s: %s", T.author, author) end
	if version then lines[#lines + 1] = format("%s: %s", T.version, version) end
	if r.notes and r.notes ~= "" then lines[#lines + 1] = r.notes end
	local req, opt = M.PSS_AddonDeps(i, self.who)
	for _, set in ipairs({ { T.requires, req }, { T.optional, opt } }) do
		if #set[2] > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = set[1] .. ":"
			for _, d in ipairs(set[2]) do
				lines[#lines + 1] = "  " .. colored(d.text == "loaded" and "ok" or (d.text == "on" and "lod" or "bad"), d.name .. " (" .. d.text .. ")")
			end
		end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = colored(r.status, r.text)
	if r.pss then lines[#lines + 1] = T.pssTip elseif r.locked then lines[#lines + 1] = T.protectedTip end
	lines[#lines + 1] = ""
	if r.loaded then
		local avg, cur, peak, enc = M.PSS_AddonCPU(r.name)
		if avg then cpuLines(lines, warn, avg, cur, peak, enc) end
		lines[#lines + 1] = format("%s: %s%s", T.memory, kbText(M.PSS_AddonMemOf(i)), self.sampled and "" or (" " .. T.lastRefresh))
	else
		lines[#lines + 1] = T.notLoaded
	end
	return concat(lines, "\n")
end

-- the line at the top: CPU as the client's own list shows it (when the
-- client's profiler is on) and the memory of the last sample
function View:Stats()
	local parts = {}
	local cur, avg, peak = M.PSS_AddonCPUTotal()
	local warn = M.PSS_AddonWarn()
	if cur then
		parts[1] = T.performance
		parts[2] = format("%s %s", T.current, shareText(cur, warn))
		parts[3] = format("%s %s", T.average, shareText(avg, warn))
		parts[4] = format("%s %s", T.peak, shareText(peak, warn))
	end
	parts[#parts + 1] = format("%s %s", T.memory, self.total and kbText(self.total) or T.notSampled)
	return concat(parts, "     ")
end

------------------------------------------------------------------------
-- Menus: entries { kind, text, act, arg } as PSS_RowMenus.lua describes
------------------------------------------------------------------------
function View:Menu(k)
	local item = self.items[k]
	local L = self.L
	if not item or not L then return nil end
	local e = {}
	local function add(text, act, arg) e[#e + 1] = { kind = "button", text = text, act = act, arg = arg } end
	if item < 0 then
		local g = L.groups[-item]
		e[1] = { kind = "title", text = g.name }
		add("Turn the group on", "gon")
		add("Turn the group off", "goff")
		e[#e + 1] = { kind = "divider" }
		add("Collapse all", "collapse")
		add("Expand all", "expand")
		return e
	end
	local r = M.PSS_AddonRow(L.idx[item], self.who, self.buf)
	e[1] = { kind = "title", text = r.title }
	if r.enabled then
		if not r.pss then add("Turn off", "off") end
	else
		add("Turn on", "on")
	end
	if r.canLoad then add("Load now", "load") end
	if not r.pss then add(r.locked and "Stop protecting" or "Protect", r.locked and "unlock" or "lock") end
	local presets = M.PSS_AddonPresets()
	if #presets > 0 and not r.pss then
		e[#e + 1] = { kind = "divider" }
		for _, p in ipairs(presets) do
			add("Add to " .. p.label .. (p.scope == "all" and " (all characters)" or ""), "include", p.scope .. ":" .. tostring(p.id))
		end
	end
	return e
end

-- carry out a menu entry on line k; returns text to say, if any
function View:Act(k, act, arg)
	local item = self.items[k]
	local L = self.L
	if not item or not L then return nil end
	if act == "collapse" or act == "expand" then
		self:CollapseAll(act == "collapse")
		return nil, true
	end
	if item < 0 then
		local a, b = self:Members(-item)
		if act == "gon" or act == "goff" then M.PSS_AddonTickMany(L, a, b, act == "gon", self.who, self.deps) end
		return nil
	end
	local i = L.idx[item]
	local name = M.PSS_AddonName(i)
	if act == "on" or act == "off" then
		local ok, text = M.PSS_AddonTick(i, act == "on", self.who, self.deps)
		return not ok and text or nil
	elseif act == "load" then
		local ok, text = M.PSS_AddonLoad(i)
		return not ok and text or nil
	elseif act == "lock" or act == "unlock" then
		local ok, text = M.PSS_AddonLock(name, act == "lock", self.who)
		return not ok and text or nil
	elseif act == "include" then
		local scope, id = tostring(arg):match("^(%a+):(.+)$")
		local ok, text = M.PSS_AddonPresetInclude(id, scope, name)
		return text
	end
end

------------------------------------------------------------------------
-- Addon profiles: the 25 numbered places of the scope shown (this character
-- or all characters) and your class's. Places 1 to 5 are the Core Addon
-- Profiles, the rest the Layered ones; any of them can be selected together
-- (the union of their addons, plus the hand picks, is what is on), and each
-- place can be saved into, loaded, added, taken off, renamed or deleted.
------------------------------------------------------------------------
-- the places of the menu: the engine's entries plus text, the line the
-- menu shows
function View:Slots()
	local slots = M.PSS_AddonSlots(self.who)
	for _, p in ipairs(slots) do
		p.text = p.empty and (p.label .. " (empty)") or (p.label .. " (" .. p.n .. ")")
	end
	return slots
end

-- the entries of one layer: a title, then a line per place; fn(p) says what
-- a place becomes (nil leaves it out)
local function layerEntries(e, head, slots, layer, fn)
	e[#e + 1] = { kind = "title", text = head }
	local any = false
	for _, p in ipairs(slots) do
		if p.layer == layer then
			local entry = fn(p)
			if entry then
				e[#e + 1] = entry
				any = true
			end
		end
	end
	if not any then e[#e + 1] = { kind = "title", text = T.noneSaved } end
end

-- the selection menu: Core Addon Profiles, a line, Layered Addon Profiles
-- (saved places only), each a tick that stays open, then Manage
function View:ProfileMenu()
	local who = self.who
	local slots = self:Slots()
	local e = {}
	local function check(p)
		if p.empty then return nil end
		return { kind = "check", text = p.text, act = "select", p = p,
			on = function() return M.PSS_AddonProfileSelected(p.id, who) end }
	end
	layerEntries(e, T.coreHead, slots, "core", check)
	e[#e + 1] = { kind = "divider" }
	layerEntries(e, T.layeredHead, slots, "layered", check)
	e[#e + 1] = { kind = "divider" }
	e[#e + 1] = { kind = "button", text = T.manage, act = "manage" }
	return e
end

-- every place, a free one shown as empty; a click opens that place's actions
function View:ManageMenu()
	local slots = self:Slots()
	local e = {}
	local function button(p) return { kind = "button", text = p.text, act = "place", p = p } end
	layerEntries(e, T.coreHead, slots, "core", button)
	e[#e + 1] = { kind = "divider" }
	layerEntries(e, T.layeredHead, slots, "layered", button)
	return e
end

-- tick or untick a profile; returns the line to say
function View:ProfileSelect(p, on)
	local _, text = M.PSS_AddonProfileSelect(p.id, on, self.who)
	return text
end

-- the actions on one slot p (an entry of Slots): a free place only saves
function View:PresetMenu(p)
	local e = { { kind = "title", text = p.label .. (p.class and "" or (p.scope == "all" and " (all characters)" or " (this character)")) } }
	local function add(text, act) e[#e + 1] = { kind = "button", text = text, act = act } end
	if p.empty then
		add("Save", "save")
		add("Rename", "rename")
		return e
	end
	add("Load", "load")
	add("Add to current", "add")
	add("Remove from current", "remove")
	e[#e + 1] = { kind = "divider" }
	add("Save", "save")
	add("Rename", "rename")
	add("Delete", "delete")
	return e
end

-- one action on slot p; returns the line to say (a save keeps the name)
function View:PresetAct(p, act, name)
	local ok, text
	if act == "load" then
		ok, text = M.PSS_AddonPresetLoad(p.id, p.scope, self.who)
	elseif act == "add" then
		ok, text = M.PSS_AddonPresetAdd(p.id, p.scope, self.who)
	elseif act == "remove" then
		ok, text = M.PSS_AddonPresetRemove(p.id, p.scope, self.who)
	elseif act == "save" then
		ok, text = M.PSS_AddonPresetSave(p.id, p.name, self.who)
	elseif act == "rename" then
		ok, text = M.PSS_AddonPresetRename(p.id, name, p.scope)
	elseif act == "delete" then
		ok, text = M.PSS_AddonPresetDelete(p.id, p.scope)
	end
	return text
end

function View:Pending()
	return M.PSS_AddonPending(self.who)
end

-- the window closed: the list goes, the choices stay
function View:Release()
	self.L, self.items, self.n, self.total, self.sampled = nil, {}, 0, nil, false
	M.PSS_AddonRelease()
end
