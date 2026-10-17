-- A stand-in for an addon that reads Syndicator's API (the documented calls only, as a bag addon does). It reads
-- the global when it is first needed, never while its own file loads.
SynConsumerAtLoad = rawget(_G, "Syndicator") ~= nil
SynConsumerSeen = {}
SynConsumerEvents = {}
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
	local S = rawget(_G, "Syndicator")
	if not (S and S.API) then SynConsumerSeen.none = true return end
	local seen = SynConsumerSeen
	seen.ready = S.API.IsReady()
	seen.all = S.API.GetAllCharacters()
	seen.current = S.API.GetCurrentCharacter()
	local info = S.API.GetInventoryInfoByItemID(2589, false, false)
	for _, c in ipairs(info and info.characters or {}) do if c.character == "Alpha" then seen.linen = c.bags end end
	seen.guilds = S.API.GetAllGuilds and S.API.GetAllGuilds()
	S.CallbackRegistry:RegisterCallback("BagCacheUpdate", function(_, name, data) SynConsumerEvents[#SynConsumerEvents + 1] = name end, SynConsumerEvents)
end)
