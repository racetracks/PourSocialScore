-- The PSS window's three count lines on the Player Ignore List, Guild
-- Ignore List and Chat Filters tabs show the same numbers as the EllesmereUI
-- window's list totals (M.PSS_ListTotals, History.RecentByCat): this
-- session and the last 24 hours type by type, and all time (3.3.0-dev002).
-- Run on any save, real ones included; changes nothing.
local fails = 0
local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local LABEL = { whisper = "Whispers", partyInvite = "Party Invites", partyRaid = "Party/Raid", world = "World Chat",
	guildInvite = "Guild Invites" }
local function readRow(stats, i)
	local r = stats.rows[i]
	local out = { total = tonumber(plain(r.total:GetText())) }
	for _, fs in ipairs(r.cats) do
		local label, n = plain(fs:GetText()):match("^(.-):%s*([%d%-]+)$")
		out[label] = tonumber(n) or n
	end
	return out
end
if PourSocialScoreDB.blockStats ~= nil then print("  FAIL match: blockStats not pruned"); fails = fails + 1 end

SlashCmdList.PSS("gui force")
H.RunTimers()
local TABS = {
	{ kind = "players", prefix = "p:", tab = "PSSTab1", frame = "PSSFrame1" },
	{ kind = "guilds", prefix = "G:", tab = "PSSTabGuild", frame = "PSSGuildTabFrame" },
	{ kind = "filters", prefix = "f:", tab = "PSSTab2", frame = "PSSFrame2" },
}
local shown = {}
for _, t in ipairs(TABS) do
	_G[t.tab]:GetScript("OnClick")(_G[t.tab])
	H.RunTimers()
	local tot = M.PSS_ListTotals(t.kind, {})
	local by = M.PSS_History.RecentByCat(nil, {}, t.prefix)
	local want = { { total = tot.session }, { total = tot.day }, tot }
	for cat, n in pairs(by.session) do want[1][cat] = n end
	for cat, n in pairs(by.day) do want[2][cat] = n end
	for row = 1, 3 do
		local got = readRow(_G[t.frame].stats, row)
		for k, label in pairs(LABEL) do
			local w = k == "total" and want[row].total or (want[row][k] or 0)
			local g = got[label]
			if g ~= nil and g ~= w then
				print(("  FAIL match %s line %d %s: PSS window %s, EllesmereUI window %s"):format(t.kind, row, k, tostring(g), tostring(w)))
				fails = fails + 1
			end
		end
		if got.total ~= (tonumber(want[row].total) or 0) then
			print(("  FAIL match %s line %d total: PSS window %s, EllesmereUI window %s"):format(t.kind, row, tostring(got.total), tostring(want[row].total)))
			fails = fails + 1
		end
	end
	-- the totals pane beside the list (3.3.0-dev004): shown, and the same three numbers
	local tt = M.UI.TOTALS and M.UI.TOTALS[t.kind]
	if not (tt and tt.frame:IsVisible() and tt.boxes.session) then
		print(("  FAIL match %s: totals pane not shown"):format(t.kind)); fails = fails + 1
	else
		for key, w in pairs({ session = tot.session, day = tot.day, all = tot.total }) do
			local g = tonumber(tt.boxes[key].count:GetText())
			if g ~= w then
				print(("  FAIL match %s pane %s: PSS window %s, EllesmereUI window %s"):format(t.kind, key, tostring(g), tostring(w)))
				fails = fails + 1
			end
		end
	end
	shown[#shown + 1] = ("%s %d/%d/%d"):format(t.kind, tot.session, tot.day, tot.total)
end
-- no pane over the filter editor or on the Options tab
local function noPane(where)
	for kind, tt in pairs(M.UI.TOTALS or {}) do
		if tt.frame:IsVisible() then print(("  FAIL match: totals pane shown %s (%s)"):format(where, kind)); fails = fails + 1 end
	end
end
M.FilterScrollChangeState(1)
noPane("over the filter editor")
M.FilterScrollChangeState(0)
if not (M.UI.TOTALS.filters and M.UI.TOTALS.filters.frame:IsVisible()) then
	print("  FAIL match: totals pane not back after the filter editor"); fails = fails + 1
end
PSSTab3:GetScript("OnClick")(PSSTab3)
noPane("on the Options tab")
print(("match: session/day/all time %s"):format(table.concat(shown, ", ")))
print(fails == 0 and "PASS match" or ("FAIL match: " .. fails))
