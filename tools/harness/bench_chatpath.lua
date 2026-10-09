-- Chat path cost (core uplift P4, baseline C17/C18): CPU per line and garbage
-- per line for the lines the filter sees most, so a change to the path can
-- be compared before and after.
--   lua5.1 tools/harness/run.lua . - /tmp/pss-bench0.lua /dev/null; lua5.1 tools/harness/run.lua . /tmp/pss-bench0.lua - tools/harness/bench_chatpath.lua
-- (the first run makes a save, so Logging is not loaded at the second login)
-- Scenarios (each N lines, a new line ID every line, so the decision cache
-- never answers):
--   unlisted    an unlisted sender, the text filter on with one filter
--   listed      a listed player's whisper (blocked, counted)
--   guild       a stored member of a guild rule, whisper (blocked, counted)
--   shipped     a shipped list member (only when the Communities lists load)
--   outbox      History.Add with the outbox at its cap (Logging not loaded)
local N = tonumber(os.getenv("PSS_BENCH_N") or "") or 60000
local lineID = 900000
local function filterLine(author, msg)
	lineID = lineID + 1
	return M.PSS_CoreFilter(nil, "CHAT_MSG_WHISPER", msg, author, "", "", "", "", 0, 0, "", 0, lineID, nil)
end
local function run(name, fn)
	collectgarbage("collect"); collectgarbage("collect")
	collectgarbage("stop")
	local k0 = collectgarbage("count")
	local t0 = os.clock()
	for i = 1, N do fn(i) end
	local t = os.clock() - t0
	local k1 = collectgarbage("count")
	collectgarbage("restart")
	print(("BENCH %-9s %7.2f us/line  %7.1f bytes garbage/line"):format(name, t / N * 1e6, (k1 - k0) * 1024 / N))
end

M.PSS_SetOpt("spamFilter", true)
M.PSS_AddCustomFilter("Bench", "[text=zzqqzz]", true)
M.PSS_AddIgnore("Listed-Realm", true)
M.PSS_AddGuild("Bench Guild")
local m = M.PSS_UpdateGuildMember("Bench Guild", "Gmember-Realm")
if m then m.guild = "Bench Guild" end
if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
_G.GetGuildInfo = function(unit) if unit == "player" then return "Home Guild", "Member", 5 end end

run("unlisted", function(i) filterLine("Nobody-Realm", "hello there friend") end)
run("listed", function(i) filterLine("Listed-Realm", "hello there friend") end)
run("guild", function(i) filterLine("Gmember-Realm", "hello there friend") end)
local History = M.PSS_History
local cap = History.Cap()
local db = PourSocialScoreDB
for _ = 1, cap + 50 do History.Add("p:bench", nil, { ts = 1, cat = "whisper" }) end
run("outbox", function(i) History.Add("p:bench", nil, { ts = 1, cat = "whisper" }) end)
print(("BENCH outbox size %d (cap %d)"):format(#rawget(db, "outbox") or {}, cap))
