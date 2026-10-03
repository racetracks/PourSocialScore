-- Checks the three block count lines on the Player Ignore List, Guild
-- Ignore List and Chat Filters tabs against PSS_EXPECT (from make_data.lua).
--   PSS_PHASE=2 : first login after the upgrade. Session 0, last 24 hours =
--                 the old blocks of the last 24 hours (seeded from the log),
--                 Total = what the old version showed. Then blocks one more
--                 line per tab and checks that all three lines go up.
--   PSS_PHASE=3 : a login more than 24 hours after the old blocks. Session 0,
--                 last 24 hours = only the phase 2 lines, Total unchanged.
local expect = dofile(assert(os.getenv("PSS_EXPECT")))
local phase = tonumber(os.getenv("PSS_PHASE") or "2")
local fails = 0

local lineID = 50000 + phase * 1000
local function chat(event, msg, author)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, event, msg, author, "", "", "", "", 0,
		event == "CHAT_MSG_CHANNEL" and 2 or 0, event == "CHAT_MSG_CHANNEL" and "Trade" or "", 0, lineID, nil)
end

local function plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function readRow(stats, i)
	local r = stats.rows[i]
	local out = { total = tonumber(plain(r.total:GetText())) }
	for _, fs in ipairs(r.cats) do
		local label, n = plain(fs:GetText()):match("^(.-):%s*(%d+)$")
		out[label] = tonumber(n)
	end
	return out
end

local LABEL = { whisper = "Whispers", partyInvite = "Party Invites", partyRaid = "Party/Raid", world = "World Chat",
	guildInvite = "Guild Invites", private = "Private messages" }

local function compare(what, got, want)
	for k, v in pairs(want) do
		local g = (k == "total") and got.total or got[LABEL[k]]
		if g ~= (tonumber(v) or 0) then
			print(("  FAIL %s %s: shows %s, expected %s"):format(what, k, tostring(g), tostring(v)))
			fails = fails + 1
		end
	end
end

local function add(a, b)
	local out = {}
	for k, v in pairs(a) do out[k] = v end
	for k, v in pairs(b) do out[k] = (out[k] or 0) + v end
	return out
end
local ZERO = { total = 0 }

local function showTab(name) _G[name]:GetScript("OnClick")(_G[name]) end

local function check(label, rowsWant)
	SlashCmdList.PSS("gui")
	H.RunTimers()
	showTab("PSSTab1")
	compare(label .. " player session", readRow(PSSFrame1.stats, 1), rowsWant.player[1])
	compare(label .. " player 24h", readRow(PSSFrame1.stats, 2), rowsWant.player[2])
	compare(label .. " player total", readRow(PSSFrame1.stats, 3), rowsWant.player[3])
	showTab("PSSTabGuild")
	compare(label .. " guild session", readRow(PSSGuildTabFrame.stats, 1), rowsWant.guild[1])
	compare(label .. " guild 24h", readRow(PSSGuildTabFrame.stats, 2), rowsWant.guild[2])
	compare(label .. " guild total", readRow(PSSGuildTabFrame.stats, 3), rowsWant.guild[3])
	showTab("PSSTab2")
	compare(label .. " filter session", readRow(PSSFrame2.stats, 1), rowsWant.filter[1])
	compare(label .. " filter 24h", readRow(PSSFrame2.stats, 2), rowsWant.filter[2])
	compare(label .. " filter total", readRow(PSSFrame2.stats, 3), rowsWant.filter[3])
	showTab("PSSTab1")
end

local db = PourSocialScoreDB
assert(type(db.blockStats) == "table" and db.blockStats.v == 1, "blockStats missing after upgrade")
-- the titles are gone in list view
for _, f in ipairs({ "PSSFrame1", "PSSGuildTabFrame", "PSSFrame2" }) do
	if _G[f] and _G[f].title and _G[f].title:GetText():match("Ignore List") then
		print("  FAIL " .. f .. " still shows a title"); fails = fails + 1
	end
end

local newP = { total = 1, whisper = 1 }
local newG = { total = 1, whisper = 1 }
local newF = { total = 1 }

if phase == 2 then
	-- the last 24 hours start from the block log lines of the last 24 hours
	local seed = expect.recent
	check("after upgrade", {
		player = { ZERO, seed.player, expect.player },
		guild = { ZERO, seed.guild, expect.guild },
		filter = { ZERO, seed.filter, expect.filter },
	})
	-- one more line for each tab
	assert(chat("CHAT_MSG_WHISPER", "again", "Spammer-Realm"), "player line not blocked")
	assert(chat("CHAT_MSG_WHISPER", "again", "Grunt-Realm"), "guild line not blocked")
	assert(chat("CHAT_MSG_CHANNEL", "buygold again", "Random-Realm"), "filter line not blocked")
	H.RunTimers()
	check("after new blocks", {
		player = { newP, add(seed.player, newP), add(expect.player, newP) },
		guild = { newG, add(seed.guild, newG), add(expect.guild, newG) },
		filter = { newF, add(seed.filter, newF), add(expect.filter, newF) },
	})
else
	check("next day", {
		player = { ZERO, newP, add(expect.player, newP) },
		guild = { ZERO, newG, add(expect.guild, newG) },
		filter = { ZERO, newF, add(expect.filter, newF) },
	})
	-- no hour older than 24 hours is kept
	local oldest = math.floor(GetServerTime() / 3600) - 23
	for _, src in ipairs({ "player", "guild", "filter" }) do
		for h in pairs(db.blockStats[src]) do
			if h < oldest then print("  FAIL " .. src .. " keeps an hour older than 24 h"); fails = fails + 1 end
		end
	end
end

print(fails == 0 and ("PASS phase " .. phase) or ("FAILED phase " .. phase .. ": " .. fails))
if fails > 0 then os.exit(1) end
