-- Prints the totals a version shows (no changes made), and the three block
-- count lines when this version has them.
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
if M.PSS_Stats then
	SlashCmdList.PSS("gui")
	H.RunTimers()
	local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	for _, t in ipairs({ { "PSSTab1", "PSSFrame1" }, { "PSSTabGuild", "PSSGuildTabFrame" }, { "PSSTab2", "PSSFrame2" } }) do
		_G[t[1]]:GetScript("OnClick")(_G[t[1]])
		print(t[2])
		for _, r in ipairs(_G[t[2]].stats.rows) do
			local line = plain(r.label:GetText()) .. " " .. plain(r.total:GetText()) .. " " .. plain(r.unit:GetText())
			for _, fs in ipairs(r.cats) do line = line .. "   " .. plain(fs:GetText()) end
			print("  " .. line)
		end
	end
end
