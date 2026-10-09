-- The Libraries view functions that W2 (core uplift 3.4.3) moved out of the
-- window's drawing files, as a run.lua script on any save: the block history
-- line cells and tip, the type pie tip, the spec copy, the picker cells, the
-- listed-days text, and the Guild tab's pane views and list helpers. Each
-- is called by the window; none changes what is saved but one test guild.
local fails = 0
local function check(ok, msg) if not ok then print("  FAIL viewfns: " .. msg); fails = fails + 1 end end

check(M.PSS_Need("Libraries"), "Libraries did not load")

-- block history line
local h = { ts = 86400 * 365, cat = "whisper", member = "Name-Realm", channel = "Whisper", message = "hello" }
local c = M.PSS_HistCells(h, {})
check(c.time and c.time ~= "" and c.kind:find("|c", 1, true) and c.name == "Name" and c.message == "hello", "history cells")
check(M.PSS_HistCells({ ts = 0 }, {}).message:find("no message text", 1, true), "history cells: no text")
local tip = M.PSS_HistTip(h, true)
check(tip:find("Whisper", 1, true) and tip:find("Name-Realm", 1, true) and tip:find("Double-click", 1, true), "history tip")
check(not M.PSS_HistTip(h, false):find("Double-click", 1, true), "history tip without the hint")
check(type(M.PSS_HistEmptyText) == "string", "history empty text")

-- type pie tip and spec copy
local t = M.PSS_TypeTip("Title", { text = "Whisper", value = 7 }, true)
check(t:find("Title\nWhisper: 7 blocked (all time)", 1, true) and t:find("Click:", 1, true), "type tip")
check(not M.PSS_TypeTip("T", { text = "x" }, false):find("Click:", 1, true), "type tip without the hint")
local spec = { a = 1, b = 2 }
local copy = M.PSS_SpecCopy(spec)
check(copy ~= spec and copy.a == 1 and copy.b == 2, "spec copy")

-- picker cells
local pc = M.PSS_PickerCells({ listed = true }, {})
check(pc.tick:find("808080", 1, true) and pc.state:find("listed", 1, true), "picker cells: listed")
pc = M.PSS_PickerCells({ ticked = true }, {})
check(pc.tick:find("00ff00", 1, true) and pc.state == "", "picker cells: ticked")
check(M.PSS_PickerCells({}, {}).tick == "[  ]", "picker cells: plain")
check(M.PSS_PlayerPickerCells({ name = "A", listed = true }, {}).state ~= "", "player picker cells carry the state")

-- listed days
check(M.PSS_PlayerListedText({ listed = 12 }) == "12d" and M.PSS_PlayerListedText({ listed = 12 }) == "12d", "listed text")
check(M.PSS_PlayerExpireBoxText({ expire = "30" }) == "30" and M.PSS_PlayerExpireBoxText({}) == "0", "expire box text")
local _, _, text = M.PSS_PlayerGuildState({ currentGuild = "Nobody Guild Xyz" })
check(text == "Add Guild", "player guild state text")

-- guild list helpers
local v = M.PSS_GuildListNew()
check(v:EmptyText() == "No guilds yet. Add one above.", "empty text")
v.find = "x"
check(v:EmptyText() == "Nothing matches the search.", "empty text with a search")
check(v:SearchHint() == "Search guild name", "search hint")
v.view = "members"
check(v:SearchHint() == "Search name, guild or note", "search hint of the members")
v.mguild = "somekey"
check(v:RemoveTarget() == "somekey", "remove target in the members view")
v.view = "guilds"
v:Select("guild", "other")
check(v:RemoveTarget() == "other", "remove target of the selected guild")
v.dirty, v.mdirty = false, false
v:MarkDirty(true, false)
check(v.dirty and not v.mdirty, "mark dirty (guilds)")
v:MarkDirty(false, true)
check(v.mdirty, "mark dirty (members)")

-- the pane views, on one added guild
local key = M.PSS_NormalizeGuild("Viewfns Test Guild")
M.PSS_AddGuild("Viewfns Test Guild")
check(M.PSS_GuildExists(key) and not M.PSS_GuildExists("no such guild key"), "guild exists")
local gv = M.PSS_GuildPaneView(key, {})
check(gv and gv.name == "Viewfns Test Guild" and gv.record == select(2, M.PSS_FindGuildRule(key)) and gv.removable == true
	and type(gv.info) == "string" and type(gv.sweep) == "string" and gv.fields == (gv.record.customScan or ""), "guild pane view")
check(M.PSS_GuildPaneView("no such guild key", {}) == nil, "guild pane view of a missing guild")
check(M.PSS_GuildOpts(key) == gv.record.opts, "guild opts")
check(M.PSS_GuildScanTip(key) == M.PSS_GuildScanTip(gv.record), "scan tip by key equals by record")
local spec2 = M.PSS_GuildSummarySpec(key, gv.name, { total = 5 }, {})
check(spec2.allTime == 5 and spec2.title == gv.name and spec2.id == key and spec2.owner == M.PSS_GuildHistoryKey(key), "guild summary spec")
check(M.PSS_MemberPaneView(key, nil, {}) == nil and M.PSS_MemberPaneView("no such guild key", {}, {}) == nil, "member pane view of nothing")
M.PSS_RemoveGuildNow(key)
check(not M.PSS_GuildExists(key), "test guild removed")

if fails == 0 then print("PASS viewfns") else os.exit(1) end
