------------------------------------------------------------------------
-- POUR SOCIAL SCORE - SCAN TOOLTIP
--
-- The client side of PSS_WhoisHarvest.lua: the status tooltip on the Scan
-- and Scan All buttons. The sweeps and /who queue stay in
-- PSS_WhoisHarvest.lua and are read here through M.PSS_GuildSweep,
-- M.PSS_HarvestFilter and M.PSS_HarvestStats.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M

local function guildKey(name) return M.PSS_NormalizeGuild(name) end
local function filterFor(name, it) return M.PSS_HarvestFilter(name, it) end

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
	local stats, sweepRound = M.PSS_HarvestStats()
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	local function line(t, r, gg, b) GameTooltip:AddLine(t, r or 1, gg or 0.82, b or 0, true) end
	local function pair(a, b) GameTooltip:AddDoubleLine(a, b, 0.75, 0.75, 0.75, 1, 1, 1) end
	if g then
		GameTooltip:AddLine("Scan <" .. tostring(g.name) .. ">", 1, 1, 1)
		line("One /who per click: the whole guild first. An answer of 50 (the /who cap) is split into narrower searches - level brackets, then class, then single level - until each is under the cap.", 0.85, 0.85, 0.85)
		local sw = M.PSS_GuildSweep(guildKey(g.name))
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
			local sw = M.PSS_GuildSweep(guildKey(nextG.name))
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

-- the cooldown countdown in an open Scan tooltip ends with the cooldown
M.Events.Register("WHOIS_COOLDOWN", function() M.PSS_RefreshScanTooltip() end)

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
