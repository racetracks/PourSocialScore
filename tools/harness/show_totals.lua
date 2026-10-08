-- Prints the totals a version shows (no changes made).
local db = PourSocialScoreDB
local sum = { total = 0, whisper = 0, partyInvite = 0, guildInvite = 0, partyRaid = 0, world = 0 }
for idx, name in ipairs(db.ignoreList or {}) do
	if db.typeList[idx] == "player" and M.PSS_GetPlayerRecord(name) then
		local c = M.PSS_GetPlayerBlockCounts(name)
		for k in pairs(sum) do sum[k] = sum[k] + (c[k] or 0) end
	end
end
local gc = M.PSS_GetGuildBlockCounts()
print(("totals: player %d (w %d, pi %d, pr %d, world %d, gi %d)  guild %d (w %d, pi %d, pr %d, world %d, gi %d)  filter %d (w %d, bn %d)  log %d"):format(
	sum.total, sum.whisper, sum.partyInvite, sum.partyRaid, sum.world, sum.guildInvite,
	gc.total, gc.whisper, gc.partyInvite, gc.partyRaid, gc.world, gc.guildInvite,
	db.filterTotal or 0, db.filterWhisperTotal or 0, db.filterPrivateTotal or 0, db.blockLog and #db.blockLog or 0))
