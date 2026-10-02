------------------------------------------------------------
-- POUR SOCIAL SCORE - WHO HARVEST (guild sweep)
--
-- The PSS Harvest /who sweep, aimed at one guild: the guild on the row
-- whose Scan was clicked. Scan is one /who per click: the first search is
-- the whole guild (g-"Name", no level or class), and every answer that
-- hits the /who cap (50) is split into narrower searches - level brackets
-- (1-9, 10-19 ... max-1, then max on its own), then class, then single
-- levels - queued for the next clicks until every search is under the cap.
-- Scan All (top of the Guild Ignore List, or the key binding) walks every
-- guild row A-Z the same way, each guild swept to the end before the next.
--
-- This file only plans the searches and keeps the sweep state (session
-- only). Sending the /who and storing what it finds stays in
-- PSS_GuildIgnoreList.lua (M.PSS_ScanGuild, finishScan), which calls:
--   M.PSS_HarvestNext(g, restart)   -> sweep, item, filter  (next search)
--   M.PSS_HarvestSent(sw, filter)    after the /who went out
--   M.PSS_HarvestAnswered(scan, numWhos, total) -> searches split off
------------------------------------------------------------

local addonName, addon = ...
local M = addon.M

local WHO_CAP = 50
M.PSS_WHO_CAP = WHO_CAP

local sweeps = {}       -- [guildKey] = { name, queue = { items }, sent, capped, gaveUp, seen, added, moved, done }
local sweepRound = 0    -- Scan All rounds completed this session
local stats = { sent = 0, capped = 0, gaveUp = 0, seen = 0, matched = 0, added = 0, moved = 0 }

local function guildKey(name) return M.PSS_NormalizeGuild(name) end

------------------------------------------------------------------------
-- Planning: brackets, classes, filters, splits
------------------------------------------------------------------------

local function maxLevel()
    local m = tonumber((GetMaxPlayerLevel and GetMaxPlayerLevel()) or UnitLevel("player") or 60)
    return math.max(10, m or 60)
end

-- Options > Whois Scan Options > Enable scan level cap: the highest level any
-- scan searches (Scan, Scan All, Custom, Guild Search), or nil when off.
-- Ticked without a valid cap (e.g. from an import) counts as off.
function M.PSS_ScanLevelCap()
    if not M.PSS_Opt("whoLevelCapOn") then return nil end
    local cap = tonumber(M.PSS_Opt("whoLevelCap"))
    if not cap or cap < 1 then return nil end
    return math.floor(cap)
end

-- The highest level the sweep searches: the cap, or the game's max level.
local function scanMaxLevel()
    local max, cap = maxLevel(), M.PSS_ScanLevelCap()
    return cap and math.min(cap, max) or max
end

-- 1-9, 10-19, ... up to max-1, then the max level on its own (most players).
-- max is the level cap when one is set.
local function brackets()
    local max, out, lo = scanMaxLevel(), {}, 1
    while lo < max do
        local hi = math.min(lo == 1 and 9 or lo + 9, max - 1)
        out[#out + 1] = { lo, hi }
        lo = hi + 1
    end
    out[#out + 1] = { max, max }
    return out
end

local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
    SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true, DEATHKNIGHT = true, MONK = true,
    DEMONHUNTER = true, EVOKER = true }
local CLASSIC_ONLY = { DEATHKNIGHT = true, MONK = true, DEMONHUNTER = true, EVOKER = true }

-- The classes a /who can find here: on a level-60 client only the nine
-- classic classes, without the other faction's Shaman / Paladin.
local function classes()
    local out, faction = {}, UnitFactionGroup and UnitFactionGroup("player")
    local n = (GetNumClasses and GetNumClasses()) or 0
    local classic = maxLevel() <= 60
    for id = 1, math.max(n, 13) do
        local name, file = GetClassInfo(id)
        if name and file and CLASSES[file] then
            local skip = classic and (CLASSIC_ONLY[file]
                or (faction == "Alliance" and file == "SHAMAN") or (faction == "Horde" and file == "PALADIN"))
            if not skip then out[#out + 1] = name end
        end
    end
    return out
end

-- g-"Guild" [c-"Class"] [lo-hi]; an empty item is the whole guild (1-cap
-- when a level cap is set).
local function filterFor(name, it)
    local f = 'g-"' .. name:gsub('"', "") .. '"'
    if it.c then f = f .. ' c-"' .. it.c .. '"' end
    if it.lo then
        f = f .. (" %d-%d"):format(it.lo, it.hi)
    elseif M.PSS_ScanLevelCap() then
        f = f .. (" 1-%d"):format(scanMaxLevel())
    end
    return f
end

-- A /who filter typed by hand (Custom Scan Fields, Guild Search) held to the
-- level cap: every level or range outside quotes is cut to the cap, and one
-- with no level gets 1-cap. Unchanged when no cap is set.
function M.PSS_CapWhoFilter(filter)
    local cap = M.PSS_ScanLevelCap()
    if not cap or type(filter) ~= "string" then return filter end
    local quoted = {}
    local s = filter:gsub('"[^"]*"', function(q)
        quoted[#quoted + 1] = q
        return "\001" .. #quoted .. "\001"
    end)
    local out, hasLevel = {}, false
    for tok in s:gmatch("%S+") do
        local lo, hi = tok:match("^(%d+)%-(%d+)$")
        local one = tok:match("^(%d+)$")
        if lo then
            hasLevel = true
            hi = math.min(tonumber(hi), cap)
            tok = ("%d-%d"):format(math.min(tonumber(lo), hi), hi)
        elseif one then
            hasLevel = true
            tok = tostring(math.min(tonumber(one), cap))
        end
        out[#out + 1] = tok
    end
    if not hasLevel then out[#out + 1] = ("1-%d"):format(cap) end
    return (table.concat(out, " "):gsub("\001(%d+)\001", function(i) return quoted[tonumber(i)] end))
end
M.PSS_HarvestFilter = filterFor

-- The narrower searches a capped one is split into (none: as narrow as /who goes).
local function split(it)
    local out = {}
    if not it.lo then
        for _, b in ipairs(brackets()) do out[#out + 1] = { lo = b[1], hi = b[2] } end
    elseif not it.c then
        for _, c in ipairs(classes()) do out[#out + 1] = { lo = it.lo, hi = it.hi, c = c } end
    elseif it.hi > it.lo then
        for l = it.lo, it.hi do out[#out + 1] = { lo = l, hi = l, c = it.c } end
    end
    return out
end

------------------------------------------------------------------------
-- Sweep state
------------------------------------------------------------------------

-- A guild's sweep; a new one (the whole-guild search first) when there is
-- none, it is complete, or restart (shift-click) asks for it.
local function sweepFor(g, restart)
    local key = guildKey(g.name)
    local sw = key and sweeps[key]
    if restart or not sw or sw.done then
        sw = { name = g.name, queue = { {} }, sent = 0, capped = 0, gaveUp = 0, seen = 0, added = 0, moved = 0 }
        if key then sweeps[key] = sw end
    end
    return sw
end

function M.PSS_GuildSweep(key) return key and sweeps[key] end

-- Searches sent this session for a guild row (the Scan column sorts by it).
function M.PSS_GuildSweepSent(key)
    local sw = key and sweeps[key]
    return sw and sw.sent or 0
end

-- The row's Scan button text: Scan, Scan n/m (sent / planned so far), Rescan.
function M.PSS_GuildSweepLabel(key)
    local sw = key and sweeps[key]
    if not sw then return "Scan" end
    if sw.done then return "|cff00ff00Rescan|r" end
    return ("Scan %d/%d"):format(sw.sent, sw.sent + #sw.queue)
end

-- The next search for guild row g. Returns sweep, item, filter; no item
-- while the last queued search is still waiting for its answer.
function M.PSS_HarvestNext(g, restart)
    local sw = sweepFor(g, restart)
    local item = sw.queue[1]
    return sw, item, item and filterFor(g.name, item)
end

-- The /who went out: the search leaves the queue.
function M.PSS_HarvestSent(sw, filter)
    table.remove(sw.queue, 1)
    sw.sent = sw.sent + 1
    stats.sent = stats.sent + 1
    stats.last = filter
end

-- An answer to a sweep search: totals, and the split when it was capped.
-- Returns the number of narrower searches queued (0 = none).
function M.PSS_HarvestAnswered(scan, numWhos, total)
    local sw = scan and scan.sweep
    if not sw then return 0 end
    local moved = scan.moved or 0
    sw.seen, sw.added, sw.moved = sw.seen + scan.seen, sw.added + scan.added, sw.moved + moved
    stats.seen = stats.seen + scan.seen
    stats.matched = stats.matched + scan.matched
    stats.added = stats.added + scan.added
    stats.moved = stats.moved + moved
    local shown = tonumber(numWhos) or scan.seen
    local parts = 0
    if shown >= WHO_CAP or (tonumber(total) and tonumber(total) > shown) then
        sw.capped, stats.capped = sw.capped + 1, stats.capped + 1
        local list = split(scan.item)
        if #list == 0 then sw.gaveUp, stats.gaveUp = sw.gaveUp + 1, stats.gaveUp + 1 end
        for k = #list, 1, -1 do table.insert(sw.queue, 1, list[k]) end
        parts = #list
    end
    if #sw.queue == 0 then sw.done = true end
    return parts
end

------------------------------------------------------------------------
-- Scan All
------------------------------------------------------------------------

-- Every guild row that can be searched (a name with a quote can't), A-Z.
local function targets()
    local list = {}
    for key, g in pairs(PourSocialScoreDB and PourSocialScoreDB.guildData or {}) do
        if type(g) == "table" and type(g.name) == "string" and not g.name:find('"', 1, true) then
            list[#list + 1] = { key = key, g = g }
        end
    end
    table.sort(list, function(a, b)
        local la, lb = a.g.name:lower(), b.g.name:lower()
        if la ~= lb then return la < lb end
        return tostring(a.key) < tostring(b.key)
    end)
    return list
end

-- The guild row the next Scan All click searches, guilds complete, guilds in all.
function M.PSS_ScanAllNext()
    local list, done, nextG = targets(), 0, nil
    for _, it in ipairs(list) do
        local sw = sweeps[it.key]
        if sw and sw.done then done = done + 1
        elseif not nextG then nextG = it.g end
    end
    return nextG, done, #list
end

-- One Scan All click (must run inside a click or key press).
function M.PSS_ScanAll()
    if M.PSS_ScanBlockedMsg() then return false end
    local g, _, n = M.PSS_ScanAllNext()
    if n == 0 then M.ShowMsg("No guild rows to scan - add a guild first.") return false end
    if not g then
        -- every guild swept: the next round starts over (players come and go)
        sweepRound = sweepRound + 1
        for _, it in ipairs(targets()) do sweeps[it.key] = nil end
        M.ShowMsg(("Scan All: all %d guilds swept (round %d). Starting over."):format(n, sweepRound))
        g = M.PSS_ScanAllNext()
        if not g then return false end
    end
    return M.PSS_ScanGuild(g.name, "sweep")
end

-- Key binding (Bindings.xml): Key Bindings > AddOns > Pour Social Score.
BINDING_HEADER_POURSOCIALSCORE = "Pour Social Score"
BINDING_NAME_PSS_SCAN_ALL = "Scan All: next guild /who"
function PSS_ScanAllBinding() M.PSS_ScanAll() end

------------------------------------------------------------------------
-- Status tooltip (the PSS Harvest window) on the Scan buttons
------------------------------------------------------------------------

-- g: a guild row (its Scan button), or nil (Scan All). Called without an
-- owner it redraws the tooltip that is showing, if it still is.
local tipOwner, tipGuild
function M.PSS_ScanTooltip(owner, g)
    if owner then
        tipOwner, tipGuild = owner, g
    elseif not (tipOwner and GameTooltip:IsOwned(tipOwner)) then
        return
    end
    owner, g = tipOwner, tipGuild
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    local function line(t, r, gg, b) GameTooltip:AddLine(t, r or 1, gg or 0.82, b or 0, true) end
    local function pair(a, b) GameTooltip:AddDoubleLine(a, b, 0.75, 0.75, 0.75, 1, 1, 1) end
    if g then
        GameTooltip:AddLine("Scan <" .. tostring(g.name) .. ">", 1, 1, 1)
        line("One /who per click: the whole guild first. An answer of 50 (the /who cap) is split into narrower searches - level brackets, then class, then single level - until each is under the cap.", 0.85, 0.85, 0.85)
        local sw = sweeps[guildKey(g.name)]
        GameTooltip:AddLine(" ")
        if not sw then
            pair("This guild", "not swept yet")
            pair("Next", filterFor(g.name, {}))
        else
            pair("Searches", ("%d sent, %d queued"):format(sw.sent, #sw.queue))
            pair("Capped / split", ("%d%s"):format(sw.capped, sw.gaveUp > 0 and (" (" .. sw.gaveUp .. " still capped)") or ""))
            pair("Players found", ("%d  (|cff00ff00%d new|r, %d moved here)"):format(sw.seen, sw.added, sw.moved))
            if sw.done then
                line("Sweep complete - click to start it again.", 0, 1, 0)
            else
                pair("Next", sw.queue[1] and filterFor(g.name, sw.queue[1]) or "waiting for the last answer")
            end
        end
    else
        GameTooltip:AddLine("Scan All", 1, 1, 1)
        line("One /who per click across every guild row, A-Z: each guild is swept to the end (whole guild first, capped answers split by level bracket, class, single level) before the next.", 0.85, 0.85, 0.85)
        local nextG, done, n = M.PSS_ScanAllNext()
        GameTooltip:AddLine(" ")
        pair("Guilds swept", ("%d / %d%s"):format(done, n, sweepRound > 0 and (" (round " .. (sweepRound + 1) .. ")") or ""))
        if nextG then
            local sw = sweeps[guildKey(nextG.name)]
            pair("Now", ("%s  %s"):format(nextG.name, sw and ("%d/%d"):format(sw.sent, sw.sent + #sw.queue) or ""))
            pair("Next", filterFor(nextG.name, (sw and sw.queue[1]) or {}))
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("This session", 1, 0.82, 0)
    pair("Searches", ("%d sent, %d capped/split, %d still capped"):format(stats.sent, stats.capped, stats.gaveUp))
    pair("Players found", ("%d, %d in a matching guild"):format(stats.seen, stats.matched))
    pair("Captured", ("|cff00ff00%d new|r, %d moved from another rule"):format(stats.added, stats.moved))
    pair("Last", stats.last or "-")
    local cap = M.PSS_ScanLevelCap()
    pair("Level cap", cap and tostring(cap) or "off (Options > Whois Scan Options)")
    GameTooltip:AddLine(" ")
    local wait = M.PSS_ScanCooldownRemaining()
    if M.PSS_WhoPending() then
        line("Waiting for the /who answer...", 1, 1, 0)
    elseif wait > 0 then
        line(("Ready in %d s"):format(math.ceil(wait)), 1, 0.5, 0)
    else
        line("Ready - click for the next search", 0, 1, 0)
    end
    if g then line("Shift-click: start this guild's sweep over.", 0.6, 0.6, 0.6) end
    line("Key binding for Scan All: Key Bindings > AddOns > Pour Social Score.", 0.6, 0.6, 0.6)
    line("Only online players on your realm show in /who: sweep again later to catch more.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function M.PSS_RefreshScanTooltip()
    if tipOwner and tipOwner:IsVisible() and GameTooltip:IsOwned(tipOwner) then M.PSS_ScanTooltip() end
end

-- OnEnter / OnLeave for a Scan button: the tooltip, kept current once a second.
local tipTicker
function M.PSS_ScanTipEnter(owner, g)
    M.PSS_ScanTooltip(owner, g)
    if tipTicker then tipTicker:Cancel() end
    tipTicker = C_Timer.NewTicker(1, function()
        if tipOwner and tipOwner:IsVisible() and GameTooltip:IsOwned(tipOwner) then M.PSS_ScanTooltip()
        elseif tipTicker then tipTicker:Cancel(); tipTicker = nil end
    end)
end

function M.PSS_ScanTipLeave()
    if tipTicker then tipTicker:Cancel(); tipTicker = nil end
    tipOwner, tipGuild = nil, nil
    GameTooltip:Hide()
end
