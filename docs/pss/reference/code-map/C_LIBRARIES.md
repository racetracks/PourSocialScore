# PourSocialScore_Libraries: reference map (main, 3.4.1.38)

The load-on-demand back end: slash commands, Import/Export, and all logic for the PSS window (`PourSocialScore_GUI`). It draws nothing (except chat lines through `M.ShowMsg` / `M.ChatMsg` / `M.PSS_Say`). Every file starts with `local addon = PourSocialScore_NS; local M = addon.M` (some also take `V`, `L`, `History = M.PSS_History`).

Legend for callers: **GUI** = files in `PourSocialScore_GUI/` that reference it; **Lib** = other Libraries files; **none** = no caller outside its own file (harness callers noted).

## 0. How it loads (`PourSocialScore/PSS_Loader.lua`, 67 lines)

| Item | What it does |
| --- | --- |
| `PourSocialScore_NS = addon` | The one cross-addon global; on-demand parts reach `M`, `V`, `L` through it |
| `M.PSS_PARTS` | `GUI`, `Libraries`, `Logging`, `Communities` -> folder names |
| `NEEDS = { GUI = "Libraries" }` | Loading the GUI loads Libraries first |
| `M.PSS_Need(key)` | Returns true if loaded; else loads the part (and its NEEDS), calling `EnableAddOn(name, UnitName("player"))` then `LoadAddOn`. Warns once per part on failure (`L.PART_1`) or on a version that differs from core (`L.PART_2`). Uses `C_AddOns.*` or the old globals |
| `M.PSS_Stub(fname, key)` | Puts a stand-in at `M[fname]` that loads the part on first call and forwards to the real `M[fname]` the part defines |

Who triggers Libraries:
- `PourSocialScore.lua:301-307`: `SLASH_PSS1 = "/pss"`, `SLASH_PSSGUILD1 = "/pssguild"`; `M.PSS_Stub("PSS_SlashPSS", "Libraries")`, `M.PSS_Stub("PSS_SlashGuild", "Libraries")`; `SlashCmdList` entries call `M.PSS_SlashPSS` / `M.PSS_SlashGuild`. The first command loads Libraries.
- `PSS_BlizzardUI.lua:20,38`: `M.PSS_Need("GUI")` (opening or docking the window), which pulls Libraries in via NEEDS.
- A load-on-demand addon never unloads, so **everything module-level in Libraries lives for the rest of the session** once loaded (window closed or not).

TOC order (`PourSocialScore_Libraries.toc`, `## Dependencies: PourSocialScore`, `## LoadOnDemand: 1`): PSS_ImportExport, PSS_GuildQuery, PSS_FilterQuery, PSS_TotalsQuery, PSS_EventsQuery, PSS_DetailQuery, PSS_ViewNav, PSS_PlayerView, PSS_GuildView, PSS_FilterView, PSS_EventsView, PSS_OptionsView, PSS_RowMenus, PSS_Commands. Order matters: PSS_ViewNav must precede the three *View files (they call `M.PSS_ListMixin` at load), and PSS_GuildView must precede PSS_RowMenus (`local MANAGED = M.PSS_GUILD_MANAGED` at load).

Total: 4455 lines in 14 files.

---

## 1. PSS_ImportExport.lua (442 lines)

Purpose: export chosen sections to one text string; import with Merge or Replace. Own typed serialiser (never executes code), base64, checksum.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_EncodeExport(tbl)` | Query | Serialise + checksum + base64 -> `PSS1:<sum>:<b64>` | Lib: OptionsView |
| `M.PSS_DecodeExport(text)` | Query | Reverse; returns data or nil, error text | Lib: OptionsView |
| `M.PSS_BuildExport(sections)` | Query | Builds the data table from `PourSocialScoreDB` for the ticked sections | Lib: OptionsView |
| `M.PSS_DescribeImport(data)` | View | "3 ignore list entries, 2 guild rules (40 members), ..." | Lib: OptionsView |
| `M.PSS_ApplyImport(data, mode, sections)` | Action | Applies merge/replace; returns a report string | Lib: OptionsView |

Locals: `ser`, `deser` (depth cap 40), `b64enc`, `b64dec`, `checksum` (djb2-style mod 16777213, 6 hex), `PREF_FIELDS`, `BLOCK_CATS`, `GUILD_FIELDS`, `MEMBER_FIELDS`, `copyBlock`, `copyFields`, `copyOpts`, `importedOption` (validates an option value against its def). No caches.

Core calls: ChatBlock (`PSS_CanonGuild`, `PSS_CanonPlayer`, `PSS_NormalizePlayer`, `PSS_NowString`, `PSS_PurgeChatFrom`); PlayerIgnoreList (`PSS_GetPlayerRecord`, `PSS_GetPlayerPrefs`, `PSS_IsPlayerListed`, `hasNPCIgnored`, `PSS_ImportListEntry`, `PSS_RemoveListEntryAt`, `PSS_MarkIgnoreIndexDirty`); GuildIgnoreList (`PSS_GetGuild`, `PSS_GuildBlock`, `PSS_MemberBlock`, `PSS_MergeIntoShipped`, `PSS_CompactMember`, `PSS_GuildRuleActive`, `PSS_RefreshGuildActive`, `PSS_MarkGuildIndexDirty`, `PSS_LoadActiveManagedData`, `M.PSS__purgeBatch`); ChatFilters (`PSS_IsBuiltinFilter`, `PSS_AddCustomFilter`, `RemoveChatFilter`, `PSS_SetFilterActive`); Options (`PSS_CharKey`, `PSS_OPTIONS`, `PSS_OPTION_REG`, `PSS_SetOpt`); Perf (`PSS_RequestGC("import")`); Events (`M.Events`).

Events fired: `PLAYERS_CHANGED` (true), `GUILDS_CHANGED`, `FILTERS_CHANGED` at the end of every `PSS_ApplyImport` (plus whatever the setters fire).

SavedVariables touched (direct writes, not via setters, flagged):
- Players: `p[f] = e.prefs[f]` for PREF_FIELDS and `p.opts = copyOpts(...)` on the record from `M.PSS_GetPlayerPrefs` (direct).
- Guilds Replace: **`db.guildData = {}`** (wipes every guild rule, shipped/managed ones included; this is N45, fixed in F1).
- Guilds: `g[f]`, `g.opts`, `g.block`, `g.members[mk] = m`, **`g.memberCount`** (direct).
- `V.needSorted = true` (runtime).
- Options go through `M.PSS_SetOpt` (correct). Entries through `PSS_ImportListEntry` / `PSS_RemoveListEntryAt` (core).

---

## 2. PSS_GuildQuery.lua (361 lines)

Purpose: the Guild Ignore List's data shaping: the grouped list rows, a rule's members (sorted, searched), collapsible-group state, Add Guild on a member.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_GUILD_EXCL_OPEN = "__exclusions"` | const | Open-state key of the Guild Exclusion List row | Lib: GuildView, RowMenus |
| `M.PSS_GUILD_MANAGED_SHUT = "__managedShut"` | const | Stored only while the Managed Communities row is closed | Lib: GuildView |
| `M.PSS_GuildGroupOpen(k)` | Query | Is the collapsible row k open (`PourSocialScoreDB.guildGroupOpen`) | Lib: GuildView |
| `M.PSS_SetGuildGroupOpen(k, on)` | Action | Sets it (true or nil) | Lib: GuildView |
| `M.PSS_FindGuildRule(nameOrKey)` | Query | key, record; key first, then by display name | GUI: Guilds; Lib: GuildView, RowMenus |
| `M.PSS_GuildCount()` | Query | Number of guild rules | Lib: GuildView |
| `M.PSS_GuildRows(sortKey, asc, find, into)` | Query | The list in display order into `into[1..n]`: managed header (when `into.nest`), group headers, their guilds when open, the Exclusion header and its names, then other guilds. Sort keys: guild, members, scan, fields, custom, `metric:<cat>`, `excl:<cat>`. Search flattens groups | Lib: GuildView (`List:Resort`), TotalsQuery (reads `into.pool`) |
| `M.PSS_GuildMembers(gkey, sortKey, asc, find, into)` | Query | Stored plus shipped members of a rule, searched (name, guild, note) and sorted; `into.stored[m]` = stored key or false; returns into, n, total | Lib: GuildView (`List:MResort`) |
| `M.PSS_AddMembersGuild(gkey, actual)` | Action | Add Guild on a member: `M.PSS_AddCapturedGuild` for the member's actual guild, chat line of what moved | GUI: Guilds |
| `M.PSS_ForgetGuildSearch()` | Action | `M.PSS_GuildSearchCache = nil` | Lib: GuildView |

Locals: `collectGuilds` (pool of one item per rule in `into.pool`, reused across redraws), `sortGuildItems`, `memberSortValue`, `clearArray`. Every table belongs to the caller's `into` (the GuildView list state), so it lives as long as that list object (the GUI's tab state). `into.pool` keeps an item per guild rule.

Core calls: GuildIgnoreList (`PSS_EnsureGuildDB`, `PSS_GuildMemberCount`, `PSS_GetGuildBlockCounts`, `PSS_GetMemberBlockCounts`, `PSS_GuildBlock`, `PSS_MemberBlocks`, `PSS_GuildExclusions`, `PSS_ManagedGroups`, `PSS_ForEachGuildMember`, `PSS_NormalizeGuild`, `PSS_AddCapturedGuild`, `PSS_GuildSearchCache`); ChatFilters (`PSS_ManagedGroupActive`); WhoisHarvest (`PSS_GuildSweepSent`); ChatHistory (`History.EmptyCounts`, `History.ParseTime`); Globals (`ChatMsg`).

Events: none.

SavedVariables (direct writes, flagged):
- `PourSocialScoreDB.guildGroupOpen[k]` (UI state; even `PSS_GuildGroupOpen`, a read, creates the table).
- **`g.memberCount = M.PSS_GuildMemberCount(g, key)` on every rule at every `PSS_GuildRows`** (a saved field written by a drawing query; S3 plans to stop saving `memberCount`).

---

## 3. PSS_FilterQuery.lua (145 lines)

Purpose: Chat Filters data for the window: counts, rows, sort/search, history across filters, test, link conversion.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_FilterCount()` | Query | total, built-in, custom, on | Lib: FilterView |
| `M.PSS_FilterBlockedText(i)` | View | Blocked cell; "n/a" for a guild rule | Lib: FilterView |
| `M.PSS_FilterRow(i, into)` | Query | index, desc, filter, active, builtin, guildRule, blocked, lines | GUI: Filters; Lib: FilterView, RowMenus |
| `M.PSS_FilterRows(key, asc, find, into)` | Query | Filter numbers in display order (built-ins first; desc/state/blocked/filter) | Lib: FilterView |
| `M.PSS_AllFilterHistory()` | Query | Every filter's lines, labelled (`History.Collect`; loads Logging) | Lib: FilterView (AllFiltersSpec.read) |
| `M.PSS_ResetAllFilterHistory()` | Action | `M.PSS_ResetFilterHistory(n)` for every filter | Lib: FilterView |
| `M.PSS_TestChatFilter(filter, text)` | Query | "blocked", "passed" or "error" via `M.filterComplex` and `V.lastFilterError` | Lib: FilterView |
| `M.PSS_ConvertChatLink(link)` | Query | A chat link as `[item=ID]`, `[spell=..]`, `[talent=..]`, `[achievement=..]`, `[pet=..]`, or `[journal]`/`[trade]`/`[guild]`/`[community]`; "UNKNOWN" | GUI: Filters |

Locals: `LINK_TAGS`, `LINK_PLAIN`. Caches: `into.v/b/d` sort maps in the caller's table.

Core calls: ChatFilters (`PSS_IsBuiltinFilter`, `PSS_IsGuildRuleFilter`, `PSS_FilterOwnerKey`, `PSS_ResetFilterHistory`, `filterComplex`); ChatHistory (`History.Collect`, `History.SetSource`); reads `PourSocialScoreDB.filterList/filterDesc/filterActive/filterCount/filterBlocked` directly (reads only).

Events / SV writes: none.

Note: `[talent=ID]` is produced, but N42 says the filter language does not know `talent` (fixed in F1).

---

## 4. PSS_TotalsQuery.lua (118 lines)

Purpose: one whole list's block totals (nothing selected), and the per-type recent counts.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_ListTotals(kind, into, guildRows)` | Query | kind players/guilds/filters: total and one count per `History.ALL_CATS`; `session`, `day` from `History.RecentTotals(prefix)`. Filters add a gap (`filterCount` minus typed counts) as `unknown`. Guilds reuse `guildRows.pool` when given | Lib: DetailQuery (`PSS_TotalsView`) |
| `History.RecentByCat(owner, into, prefix)` | Query | Session and 24 h counts by type for one owner or every owner with a key prefix | Lib: DetailQuery, EventsQuery; core ChatHistory comments only |

Note: it **adds a function to the core `History` table** (`History.RecentByCat`), built on core's `History.RecentByCatData()` (PSS_ChatHistory.lua:800-803 documents this split).

Core calls: PlayerIgnoreList (`PSS_GetPlayerRecord`, `PSS_GetPlayerBlockCounts`), GuildIgnoreList (`PSS_GetGuildBlockCounts`), ChatFilters (`PSS_IsGuildRuleFilter`), ChatHistory (`ALL_CATS`, `RecentTotals`, `RecentByCatData`, `DAY_SLOTS`, `SLOT`, `Now`). Reads counters only; never loads Logging.

Events / SV writes: none.

---

## 5. PSS_EventsQuery.lua (268 lines)

Purpose: block-history logic shared by the window: line types, "expired / not stored" rows for counted lines no longer kept, query matching, group (managed list) reads and resets.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_EVENT_TYPES` | const | whisper, invite, party, raid, BG, world, guild | GUI: History |
| `M.PSS_EventType(h)` | Query | A line's type word (party/raid split by channel; "other") | GUI: History; Lib: DetailQuery, EventsView |
| `M.PSS_ParseEventTime(text)` | Query | "YYYY-MM-DD[ HH:MM]" -> `time()` seconds | Lib: EventsView |
| `M.PSS_AddExpiredEvents(lines, counts, slots, person)` | Query | Appends synthetic rows (`History.EntryMT`) for counted blocks missing from lines: per 10-min slot (recent), then per type with ts 0 | Lib: EventsView; also used by `PSS_GroupEvents` |
| `M.PSS_PeriodSince(key)` | Query | First second of "session" / "day" | none outside (used by `PSS_EventRange`) |
| `M.PSS_EventRange(q)` | Query | since, upto for a query | Lib: EventsView |
| `M.PSS_EventMatches(q, h, find, since, upto)` | Query | Type, time window, search on member/channel/message | Lib: EventsView |
| `M.PSS_SumCats(t, off)` | Query | Sum of counts by type, skipping `off` | Lib: DetailQuery |
| `M.PSS_StoredText(owner, total, who)` | View | "Stored: N in the log, M kept, ..." via `History.Where` | GUI: Detail |
| `M.PSS_GroupGuilds(k)` | Query | Guild keys of a managed list (`"__managed"` = all managed) | none outside (internal) |
| `M.PSS_GroupEvents(k)` | Query | Those guilds' lines, expired rows merged | Lib: GuildView (GroupEventsSpec.read) |
| `M.PSS_ResetGroupEvents(k)` | Action | `M.PSS_ResetGuildBlockHistory` per guild | Lib: GuildView |
| `M.PSS_GroupRecent(items, into)` | Query | Session / day totals of a group | GUI: Guilds |
| `M.PSS_GroupRecentByCat(items, into, one)` | Query | Same by type | GUI: Guilds |
| `M.PSS_ListedPlayerEvents()` | Query | Every listed player's lines | Lib: PlayerView (AllPlayersSpec.read) |
| `M.PSS_ResetListedPlayerEvents()` | Action | Reset history of every listed player | Lib: PlayerView |
| `M.PSS_ResetAllGuildEvents()` | Action | Reset history of every guild rule | Lib: GuildView |

Locals: `CAT_TYPE`, `CHANNEL_TYPE`, `EXPIRED`, `NOT_STORED`, `MANAGED = "__managed"` (duplicated in GuildView), `NONE`. No caches.

Core calls: ChatHistory (`SLOT`, `KeepKind`, `EntryMT`, `ALL_CATS`, `SessionStart`, `Now`, `Where`, `KeepsOwner`, `KEEP_TOTAL`, `LOG_ALL`, `RecentSlots`, `GuildKey`, `RecentCounts`, `Collect`); GuildIgnoreList (`PSS_GetGuildBlockHistory`, `PSS_GetGuildBlockCounts`, `PSS_ResetGuildBlockHistory`); PlayerQuery (`PSS_PlayerCount`, `PSS_PlayerEntry`); PlayerIgnoreList (`PSS_PlayerHistoryKey`, `PSS_GetPlayerRecord`, `PSS_ResetPlayerBlockHistory`). Reads `PourSocialScoreDB.guildData`.

Events / SV writes: none directly (the reset setters write).

---

## 6. PSS_DetailQuery.lua (315 lines)

Purpose: the pies and detail panes' maths and text; exceptions (per-entry overrides of the target options).

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_PERIODS` | const | session/day/all with text and colour | GUI: Detail |
| `M.PSS_PeriodOn(k)` / `M.PSS_SetPeriodOn(k, on)` | View state | Period pie ticks (all time starts off) | GUI: Detail |
| `M.PSS_TypeOff(cat)` | View state | Type pie tick off? | **none** |
| `M.PSS_SetTypeOff(cat, off)` | View state | Set it | GUI: Detail |
| `M.PSS_AnyTypeOff()` | View state | Any type unticked | **none** (harness `check_viewquery.lua` only) |
| `M.PSS_WidestPeriodOn()` | View | "day", "session" or nil | GUI: Detail |
| `M.PSS_TypesOn()` | View | `{cat=true}` of ticked types, nil if all | GUI: Detail |
| `M.PSS_SummaryValues(spec, into)` | Query | into.session/day/all for a pane (by spec.owner, .recent, .prefix, .recentByCat, .counts) | GUI: Detail |
| `M.PSS_PeriodSlices(v, slices, map, pool)` | View | Nested period slices (draw, inner, within) | GUI: Detail |
| `M.PSS_PeriodTip(title, sl, click, typed)` | View | Slice tooltip | GUI: Detail |
| `M.PSS_HexColor` | View | "aarrggbb" -> r, g, b | **none** (local `HexColor` used inside) |
| `M.PSS_TypeSlices(counts, slices, max)` | View | All-time by type, max 7 slices | GUI: Detail |
| `M.PSS_TotalsView(kind, into, guildRows)` | Query | `PSS_ListTotals` plus recent, prefix and info text | GUI: Detail |
| `M.PSS_CountsText(c)` | View | "Blocked 12: Whispers 3 ..." | GUI: Guilds, Players |
| `M.PSS_OVERRIDE_SHORT` | const | Short names of the 4 target options | Lib: RowMenus |
| `M.PSS_OverrideOptions()` | Query | Bool options with `target` (cached once in `overrideOpts`) | GUI: Detail; Lib: RowMenus |
| `M.PSS_OverrideValue(target, key)` | Query | `target.opts[key]` | **none outside** (internal; harness `check_viewquery`, `check_menus`) |
| `M.PSS_ExceptionState(target, key, parentOpts)` | Query | happens, isException, default | GUI: Detail; Lib: RowMenus |
| `M.PSS_SetException(target, scope, key, happens, parentOpts)` | Action | `M.PSS_SetOpt(key, scope, v, target)` (nil when equal to default) | GUI: Detail |
| `M.PSS_ToggleException(target, scope, key, parentOpts)` | Action | Flip it | GUI: Guilds, Players |
| `M.PSS_ExceptionHeading(who)`, `M.PSS_ExceptionText(opt, isEx)`, `M.PSS_ExceptionTip(opt, who, base)` | View | Exception texts | GUI: Detail (Heading also RowMenus) |
| `M.PSS_ClassColor(class)` | View | `RAID_CLASS_COLORS` r, g, b (white default) | GUI: Guilds, Players; Lib: GuildView, PlayerView |
| `M.PSS_HistHidden(t)` / `M.PSS_SetHistHidden(t, h)` | View state | Block-history list type ticks | GUI: History |
| `M.PSS_HistFilter(all, out)` | View | Lines of the ticked types; n | GUI: History |

Module state (lives for the session once Libraries loads, not dropped on window close): `periodOn`, `typeOff`, `histHidden`, `byCat` scratch, `overrideOpts` cache.

Core calls: ChatHistory (`RecentByCat` (Libraries-added), `RecentCounts`, `ALL_CATS`, `CAT_COLOR`, `CAT_LABEL`); Options (`PSS_OPTIONS`, `PSS_Opt`, `PSS_SetOpt`). Events: none (SetOpt fires `OPTION_CHANGED`). SV: via `PSS_SetOpt` only.

---

## 7. PSS_ViewNav.lua (290 lines)

Purpose: window state (look, place, last tab, font, accent), back/forward navigation, shared list helpers.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_UISkin()` | Query | `uiSkin` 0 -> "blizzard" (Classic), 1 -> "dark", 2 -> "modern" (default) | GUI: Skin |
| `M.PSS_UIPlace(key)` | Query | point, relPoint, x, y from `windowPoints[key]` | GUI: Window |
| `M.PSS_SetUIPlace(key, ...)` | Action | Writes `windowPoints[key]` | GUI: Window |
| `M.PSS_UI_TABS`, `M.PSS_UI_EVENTS_TAB = 4` | const | players, guilds, filters, events, importExport, options | GUI: Window |
| `M.PSS_UITab()` / `M.PSS_SetUITab(id)` | Query/Action | Last tab saved as `windowPoints.PSS_WindowTab` (key); tab 1 not stored; Events never saved or restored | GUI: Window |
| `M.PSS_UIAccent()` | Query | Player class colour | GUI: Skin |
| `M.PSS_UIFontPath()` | Query | Font file for `uiFont` (Blizzard or `lsm:<name>` through LibSharedMedia if another addon loaded it) | GUI: Skin |
| `M.PSS_UIFontChoices()` | Query | Appends LSM fonts to `M.PSS_OPTION_REG.uiFont.choices` (de-duplicated) | GUI: Window |
| `M.PSS_NavNew(max)` | View | Back/forward history object (below) | GUI: Window |
| `M.PSS_DoubleClick(state, key, now)` | View | Second click on same key within 0.35 s | GUI: Events, History |
| `M.PSS_Throttle(fn, delay)` | View | Coalesce a burst into one call after 0.25 s (`C_Timer.After`) | GUI: Events, Filters, Guilds, Players |
| `M.PSS_ListMixin(List)` | View | Copies `SortBy`, `SetFind` onto a list class | Lib: PlayerView, GuildView, FilterView |
| `M.PSS_PickerToggle(it)`, `M.PSS_PickerTickAll(items)` | View | Search-results picker ticks | GUI: Players; Lib: GuildView (aliased) |

Core calls: Options (`PSS_Opt`, `PSS_OPTION_REG`). WoW: `UnitClass`, `C_ClassColor`, `RAID_CLASS_COLORS`, `LibStub` (read only, pcall), `GetTime`, `C_Timer`.

SV (direct, UI state in a routed `PourSocialScoreDB` key held in `PSS_OptionsDB`): `PourSocialScoreDB.windowPoints[key]` and `windowPoints.PSS_WindowTab`. Runtime mutation: `M.PSS_OPTION_REG.uiFont.choices` grows with LSM fonts (not saved).

---

## 8. PSS_PlayerView.lua (335 lines)

Purpose: the Player Ignore List tab's text, sort/search, edits, search picker, prune, Events specs.

List object: `M.PSS_PlayerListNew()` -> `{key="name", asc, find, index={}, count, dirty}` with `:Resort()` (-> n, all, countText, emptyText via `M.PSS_SortPlayers`), `:SortBy`, `:SetFind` (mixin). Lives as long as the GUI keeps it.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_PlayerListNew()` | View | List state | GUI: Players |
| `M.PSS_PlayerTypeText(r)`, `M.PSS_PlayerExpireText(r)`, `M.PSS_PlayerTotal(p)`, `M.PSS_PlayerTip(r)` | View | Column texts, total blocks | GUI: Players (Total also RowMenus) |
| `M.PSS_PlayerHeading(r)`, `M.PSS_PlayerTypeLine(r)`, `M.PSS_PlayerAddedLine(r)`, `M.PSS_PlayerExpireNote(r)`, `M.PSS_PlayerGuildLine(p)`, `M.PSS_PlayerInviteLine(p)` | View | Detail pane lines | GUI: Players |
| `M.PSS_PlayerGuildState(p)` | Query | currentGuild, listed? | GUI: Players; Lib: RowMenus |
| `M.PSS_PlayerRemoveText(entry)` | View | Confirm text | GUI: Players; Lib: RowMenus |
| `M.PSS_PlayerTargetName()` | Query | Target's Name-Realm if same faction, readable (`PSS_IsSecret`) | **none outside** (used by AddFromText) |
| `M.PSS_PlayerAddFromText(text)` | Action | `M.PSS_AddPlayer(text)` or target (`unit "target"`); returns entry | GUI: Players |
| `M.PSS_PlayerSearchFromText(text, onDone)` | Action | `/who` via `M.PSS_PlayerSearch` (needs hardware event) | GUI: Players |
| `M.PSS_PlayerPickerItems(found, into)`, `...Title(n, q)`, `...Cells(it, into)`, `...Save(items)` | View/Action | Search picker; Save calls `PSS_AddPlayer` per ticked | GUI: Players |
| `M.PSS_PlayerNoneFound(q)`, `M.PSS_PlayerAddAnyway(name)` | View/Action | No results prompt; add anyway | GUI: Players |
| `M.PSS_PRUNE_DAYS = 365`, `M.PSS_PruneText()`, `M.PSS_PruneNote(days)`, `M.PSS_PruneApply(days)` | View/Action | Prune dialog; `M.PruneIgnoreList(days, false/true)` | GUI: Players |
| `M.PSS_PlayerCommitExpiry(entry, text)`, `M.PSS_PlayerCommitNote(entry, text)` | Action | `PSS_SetExpiry` / `PSS_SetNote` then `PSS_PlayersChanged()` | GUI: Players |
| `M.PSS_PlayerAllowed(p, field)`, `M.PSS_PlayerToggleAllowed(entry, field, allowed)` | Query/Action | W I G P C tick; `PSS_SetPlayerSetting(entry, field, not allowed)` + `PSS_PlayersChanged()` | GUI: Players |
| `M.PSS_BLIZZARD_TEXT`, `M.PSS_BLIZZARD_TIP`, `M.PSS_PlayerOnBlizzard(p)`, `M.PSS_PlayerToggleBlizzard(entry, on)` | View/Action | B1 tick; `PSS_SetBlizzardIgnore` + `PSS_PlayersChanged()` | GUI: Players |
| `M.PSS_PlayerAddGuild(guild)` | Action | `PSS_AddGuild` + chat line | GUI: Players |
| `M.PSS_AllPlayersSpec()` | View | Cached Events spec for every player (`allPlayers`, kept for the session) | GUI: Players; Lib: EventsView |
| `M.PSS_PlayerEventsSpec(entry)` | View | Events spec for one player | GUI: Players |

Core calls: PlayerQuery (`PSS_SortPlayers`, `PSS_PlayerCount`, `PSS_PlayerEntry`, `PSS_PlayerPosition`, `PSS_PlayerRow`, `PSS_PlayersChanged`, `PSS_IsGuildListed`); PlayerIgnoreList (`PSS_AddPlayer`, `PSS_GetPlayerBlockCounts`, `PSS_GetPlayerBlockHistory`, `PSS_ResetPlayerBlockHistory`, `PSS_PlayerHistoryKey`, `PSS_IsPlayerListed`, `PSS_PlayerSearch`, `PSS_SetExpiry`, `PSS_SetNote`, `PSS_SetPlayerSetting`, `PSS_SetBlizzardIgnore`, `PruneIgnoreList`); ChatBlock (`PSS_IsSecret`, `PSS_UnitFullName`); Whois (`PSS_ScanBlockedMsg`); GuildIgnoreList (`PSS_AddGuild`, `PSS_Say`); Globals (`trim`, `Proper`, `addServer`, `dayString`, `ShowMsg`).

Events: `PLAYERS_CHANGED` through `M.PSS_PlayersChanged` (core PlayerQuery) after edits whose setter does not fire. SV writes only through core setters.

---

## 9. PSS_GuildView.lua (717 lines, largest)

Purpose: the Guild Ignore List tab: grouped list state, selection, row cells/tips, scan tips, add/exclude/search rows and picker, members view, pane text, edits, Events specs.

List object `M.PSS_GuildListNew()`: `{key="guild", asc, find, rows={nest=true}, n, dirty, gen, view="guilds"|"members", mkey="name", masc, mfind, members={}, mn, mtotal, mdirty, selKind, sel, mguild, msel, lastKey, lastAt}`. Methods:

| Method | Meaning |
| --- | --- |
| `:Resort()` | `M.PSS_GuildRows(..., self.rows)`; stamps `counted = gen` |
| `:CountsChanged()`, `:FreshCounts(item)` | Lazy recount: bump `gen`, recount only drawn rows (3.4.0.15, avoids 180 KB garbage) |
| `:CountText()`, `:IsSel(item)`, `:Select(kind, value)`, `:ItemSel(item)` | Count line; selection (guild, group, managed, exclHeader, excl) |
| `:Click(item, now)` | Headers toggle open (saved via `PSS_SetGuildGroupOpen`) -> "resort"; guild -> "select"; second click in 0.35 s -> "members" (own `DOUBLE_CLICK`, duplicates `M.PSS_DoubleClick`) |
| `:OpenMembers(key)`, `:CloseMembers()` (wipes `members`), `:MResort()`, `:MSortBy`, `:SetMFind`, `:MembersHeading()`, `:MembersEmptyText()`, `:SelectMember(m)`, `:SetView(v)`, `:GuildRemoved(key)`, `:RemoveMember()` | Members view; RemoveMember -> `M.PSS_RemoveGuildMember` |

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_GUILD_MANAGED = "__managed"` | const | Managed Communities row id | GUI: Guilds; Lib: RowMenus |
| `M.PSS_GUILD_SEARCH_OWNER = "window"` | const | Guild Search results owner tag | GUI: Guilds; core GuildIgnoreList |
| `M.PSS_GuildListNew()` | View | List state | GUI: Guilds |
| `M.PSS_GuildRowCells(item, find, nested, into)`, `M.PSS_GuildRowTip(item)`, `M.PSS_GuildScanTip(g)` | View | Row texts (dim for a group whose rule is off), tips, sweep status | GUI: Guilds |
| `M.PSS_GuildAddFromText(text)`, `M.PSS_GuildExcludeFromText(text)` | Action | `PSS_AddGuild` / `PSS_AddGuildExclusion` + `PSS_Say` | GUI: Guilds |
| `M.PSS_GuildSearchFromText(text, mode)` | Action | `M.PSS_GuildSearch(text, mode, "window")` (/who) | GUI: Guilds |
| `M.PSS_GuildPickerItems/Title/Save/Close`, `M.PSS_GuildPickerToggle`, `M.PSS_GuildPickerTickAll` (aliases of ViewNav's) | View/Action | Picker; Save -> `PSS_SaveGuildExclusions` or `PSS_SaveGuildSearch`; Close -> `PSS_ForgetGuildSearch` | GUI: Guilds |
| `M.PSS_GuildNoneFound(q, mode)`, `M.PSS_GuildExcludeAnyway(name)` | View/Action | No results | GUI: Guilds |
| `M.PSS_MembersNavTitle(key)`, `M.PSS_MemberTip(m)` | View | Nav title, member tip | GUI: Guilds |
| `M.PSS_GuildInfoLine(g)`, `M.PSS_GuildGroupView(k, rows, into)`, `M.PSS_GuildExclView(name)` | View | Pane text for a guild, a managed list (or all), the exclusion list | GUI: Guilds |
| `M.PSS_MemberHeading(m)`, `M.PSS_MemberGuildLine(m)`, `M.PSS_MemberAddedLine(m)`, `M.PSS_MemberAllowed(gg, m, cat)`, `M.PSS_MemberOtherGuild(gg, gkey, m)` | View | Member pane | GUI: Guilds |
| `M.PSS_GuildHistoryKey(key)`, `M.PSS_MemberHistoryKey(m)` | Query | `History.GuildKey` / `History.MemberKey` | GUI: Guilds |
| `M.PSS_MemberBlockTotal(m)` | Query | Total without a table per call (`PSS_EnsureMemberBlockData`) | GUI: Guilds; Lib: RowMenus |
| `M.PSS_GuildAllowed(g, cat)`, `M.PSS_GuildToggleAllowed(key, cat, allowed)` | Query/Action | Guild W I G P C; `PSS_SetGuildBlock` | GUI: Guilds |
| `M.PSS_GuildScanNow(key, restart)`, `M.PSS_GuildCustomScan(key, fields)`, `M.PSS_GuildCommitFields(key, text)` | Action | `PSS_ScanGuild` (sweep/custom), `PSS_SetGuildScanFields` | GUI: Guilds |
| `M.PSS_GuildRemoveText(key)`, `M.PSS_GuildRemove(key)` | View/Action | `PSS_RemoveGuildNow` | GUI: Guilds |
| `M.PSS_MemberRemoveText(m)`, `M.PSS_MemberCommitNote(m, text)` (25 chars), `M.PSS_MemberToggleAllowed(gkey, m, cat, allowed, follow)` | View/Action | `PSS_SetMemberNote`, `PSS_SetMemberBlock` | GUI: Guilds |
| `M.PSS_GroupToggleRule(k)`, `M.PSS_GroupToggleOpen(k)`, `M.PSS_ExclRemove(name)` | Action | `PSS_SetManagedGroupActive`; open state; `PSS_RemoveGuildExclusion` | GUI: Guilds |
| `M.PSS_AllGuildsSpec()` (cached `allGuilds`), `M.PSS_GuildEventsSpec(key)`, `M.PSS_GroupEventsSpec(k)` (confirm=true), `M.PSS_MemberEventsSpec(m, gkey)` | View | Events specs | GUI: Guilds (AllGuilds also EventsView) |
| `M.PSS_GuildGroupLabel(k)` | View | Managed list label | **none outside** (used by GroupEventsSpec) |

Module caches: `managedItems` (reused), `allGuilds` spec (session).

Core calls: GuildIgnoreList (`PSS_AddGuild`, `PSS_AddGuildExclusion`, `PSS_RemoveGuildExclusion`, `PSS_IsGuildExcluded`, `PSS_GuildExclusions`, `PSS_SaveGuildExclusions`, `PSS_SaveGuildSearch`, `PSS_GuildSearch`, `PSS_ScanGuild`, `PSS_SetGuildBlock`, `PSS_SetGuildScanFields`, `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_RemoveGuildMember`, `PSS_RemoveGuildNow`, `PSS_GuildBlock`, `PSS_MemberBlock`, `PSS_MemberBlocks`, `PSS_ManagedGroups`, `PSS_NormalizeGuild`, `PSS_GetGuildBlockCounts`, `PSS_GetGuildBlockHistory`, `PSS_GetMemberBlockCounts`, `PSS_GetMemberBlockHistory`, `PSS_ResetGuildBlockHistory`, `PSS_ResetMemberBlockHistory`, `PSS_EnsureMemberBlockData`, `PSS_Say`); ChatFilters (`PSS_ManagedGroupActive`, `PSS_SetManagedGroupActive`); WhoisHarvest (`PSS_GuildSweep`, `PSS_GuildSweepLabel`, `PSS_HarvestFilter`, `PSS_ScanAllNext`); Whois (`PSS_ScanBlockedMsg`, `PSS_ScanCooldownActive`, `PSS_WhoPending`); PlayerQuery (`PSS_IsGuildListed`); ChatHistory (`GuildKey`, `MemberKey`, `ALL_CATS`); Globals (`trim`, `ChatMsg`).

Events: none fired here; core setters fire `GUILDS_CHANGED` (`SetGuildBlock`, `AddGuild`, exclusions, removal). **`PSS_SetMemberBlock`, `PSS_SetMemberNote` and `PSS_SetGuildScanFields` fire nothing**, so the tab must redraw itself after those.

SV writes: through core setters, plus `guildGroupOpen` via GuildQuery.

---

## 10. PSS_FilterView.lua (173 lines)

List object `M.PSS_FilterListNew()`: `{key="desc", asc, find, index, count, dirty}`, `:Resort()` -> n, countText, emptyText.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_FilterListNew()` | View | List state | GUI: Filters |
| `M.PSS_FilterRowCells(r, into)`, `M.PSS_FilterRowTip(r)`, `M.PSS_FilterHeading(r)`, `M.PSS_FilterInfo(r)`, `M.PSS_FilterHistoryLine(r)` | View | Row and editor text | GUI: Filters |
| `M.PSS_FilterSave(i, desc, text)` | Action | `PSS_SaveChatFilter` (custom only) | GUI: Filters |
| `M.PSS_FilterCopy(i)` | Action | `PSS_CopyChatFilter` (not a guild rule) | GUI: Filters |
| `M.PSS_FilterRemoveText(i)`, `M.PSS_FilterRemove(i, desc, sel)` | View/Action | `RemoveChatFilter` if still the same desc; returns adjusted selection | GUI: Filters |
| `M.PSS_FilterNew()` | Action | `PSS_AddCustomFilter("New Chat Filter", "[word=newchatfilter]", false)` | GUI: Filters |
| `M.PSS_FilterTestText(filter, line)` | View | BLOCKED / PASSED / FILTER ERROR | GUI: Filters |
| `M.PSS_AllFiltersSpec()` (cached), `M.PSS_FilterEventsSpec(i)` | View | Events specs | GUI: Filters; Lib: EventsView |

Locals: `prow`, `lrow` scratch rows; `allFilters` spec. Core: ChatFilters (`PSS_SaveChatFilter`, `PSS_CopyChatFilter`, `RemoveChatFilter`, `PSS_AddCustomFilter`, `PSS_IsGuildRuleFilter`, `PSS_FilterCounts`, `PSS_FilterHistory`, `PSS_ResetFilterHistory`, `PSS_FilterOwnerKey`), GuildIgnoreList (`PSS_Say`), Globals (`trim`). Events: setters fire `FILTERS_CHANGED`. SV: setters only.

---

## 11. PSS_EventsView.lua (430 lines)

Purpose: the Events tab's query model.

Spec contract (from Player/Guild/FilterView): `{ kind, id, label(id) -> name|nil (nil: gone), read(id) -> lines, reset(id), confirm?, owner(id), counts(id), all() -> whole-list spec, allText }`; a whole-list spec has `id = false` and `source = "players"|"guilds"|"filters"`.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_EVENT_SOURCES` | const | players/guilds/filters with their `all` spec | GUI: Events |
| `M.PSS_EVENT_TIMES` | const | session, day, all, custom | GUI: Events |
| `M.PSS_EventsViewNew()` | View | The view object | GUI: Events |
| `M.PSS_EventCells(v, h, into)`, `M.PSS_EventTip(v, h)`, `M.PSS_EventCopy(h)` | View | Cells, tip, copy popup text | GUI: Events |

View methods: `:Open(spec, opts)`, `:Refresh()` (calls spec `read`, which loads Logging; adds expired rows; scope gone -> its whole list), `:Release()` (drops lines; GUI calls it when the tab hides, `PSS_Events.lua:241`), `:Apply(find)`, `:SortBy`, `:SetPeriod`, `:RangeTexts`, `:ApplyRange(from, to)`, `:AllTypes`, `:TypeOn`, `:ToggleType`, `:SourceOn`, `:ToggleSource`, `:ScopeOff`, `:Heading(n)`, `:TimeLabel`, `:TypesLabel`, `:SourceLabel`, `:EmptyText`, `:NavKey()` (saves up to 100 query copies in `saved`, wiped when full), `:NavTitle(key)`, `:NavApply(key)`, `:Reset()`, `:ResetText()`, `:DoReset()`, `:SourceText(h)`.

Query `q = { scope, sources = {key=true}, period, from, to, cats }`.

Core calls: ChatHistory (`ALL_CATS`, `CAT_LABEL`, `CAT_COLOR`, `UNKNOWN`, `sourceLabel`, `RecentSlots`, `KEEP_TOTAL`, `LOG_ALL`, `Now`), Globals (`trim`, `removeServer`). Events / SV: none (reset via spec).

---

## 12. PSS_OptionsView.lua (193 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_OptLabel(o)`, `M.PSS_OptTip(o)`, `M.PSS_OptChoiceText(o, v)` | View | Labels/tips | GUI: Options |
| `M.PSS_OptGroups()` | View | Options by section (`M.PSS_OPTION_SECTIONS`), inline and retired left out, with search text | GUI: Options |
| `M.PSS_OptMatches(group, item, q)` | View | Search filter | GUI: Options |
| `M.PSS_OptNumberText(o)`, `M.PSS_OptSetNumber(o, text)` | View/Action | Clamped number via `PSS_SetOpt` | GUI: Options |
| `M.PSS_OptFieldOn(o)`, `M.PSS_OptFieldText(o)`, `M.PSS_OptSetFieldOn(o, on, typed)`, `M.PSS_OptSetField(o, text)` | View/Action | A tick with a required number (`o.field`, scan level cap) | GUI: Options |
| `M.PSS_IO` | state | `{players, guilds, members=false, filters, builtins, options=false, mode="merge"}` (session only, on `M`) | GUI: Options |
| `M.PSS_IOSet(key, on)`, `M.PSS_IOSetMode(key)`, `M.PSS_IO_PARTS`, `M.PSS_IO_MODES`, `M.PSS_IOPartOff(key)`, `M.PSS_IOModeText()` | View | Import/Export ticks and mode | GUI: Options |
| `M.PSS_ExportText()` | Query | `EncodeExport(BuildExport(sections))` | GUI: Options |
| `M.PSS_ImportCheck(str)` | Query | Decoded data or nil, error | GUI: Options |
| `M.PSS_ImportReplaceText(data)` | View | Replace confirm text | GUI: Options |
| `M.PSS_ImportApply(data)` | Action | `PSS_ApplyImport`; "Merged: ..." / "Replaced: ..." | GUI: Options |

Core: Options (`PSS_OPTIONS`, `PSS_OPTION_REG`, `PSS_OPTION_SECTIONS`, `PSS_Opt`, `PSS_SetOpt`), Globals (`ShowMsg`). SV via `PSS_SetOpt` (fires `OPTION_CHANGED`).

---

## 13. PSS_RowMenus.lua (207 lines)

Menus are data: `{kind="title", text}`, `{kind="divider"}`, `{text, act, arg}`, `{kind="check", text, on=fn, act, arg}`; the tab maps `act` to its own handlers.

| Export | Kind | Meaning (acts) | Callers |
| --- | --- | --- | --- |
| `M.PSS_PlayerMenu(entry)` | View | history, addGuild, noExpiry, resetHistory, exception checks, remove | GUI: Players |
| `M.PSS_GuildRowMenu(item)` | View | managed: allRules, open; group: rule, open; exclHeader: open; excl: exclRemove; guild: members, history, resetHistory, exceptions, remove (not for static managed guilds) | GUI: Guilds |
| `M.PSS_GuildSetAllRules(on)` | Action | `PSS_SetManagedGroupActive` for every managed list | GUI: Guilds |
| `M.PSS_MemberMenu(m, gkey)` | View | history, resetHistory, exceptions (parent = guild opts), remove | GUI: Guilds |
| `M.PSS_FilterMenu(i)` | View | toggle, copy, history, resetCount, resetHistory, remove | GUI: Filters |
| `M.PSS_SenderMenu(name)` | View | senderAdd / senderRemove | GUI: History |
| `M.PSS_SenderAdd(full)`, `M.PSS_SenderRemoveText(full)`, `M.PSS_SenderRemove(full)` | Action | `PSS_AddPlayer` / `PSS_RemovePlayerAt` | GUI: History |

Locals: `prow`, `frow` scratch. Core: PlayerQuery (`PSS_PlayerPosition`, `PSS_PlayerRow`, `PSS_PlayerEntry`, `PSS_RemovePlayerAt`), PlayerIgnoreList (`PSS_AddPlayer`), GuildIgnoreList (`PSS_ManagedGroups`, `PSS_IsStaticManagedGuild`), ChatFilters (`PSS_ManagedGroupActive`, `PSS_SetManagedGroupActive`), Globals (`Proper`, `addServer`). Uses Blizzard global `UNKNOWN` (read).

---

## 14. PSS_Commands.lua (461 lines)

Purpose: `/pss` and `/pssguild` parsers. Exports `M.PSS_SlashPSS(msg)` and `M.PSS_SlashGuild(msg)` (Command; called only by core `SlashCmdList`). Locals: `OnOff`, `ShowIgnoreList`, `PSSTest` (empty), `OPEN`, `firstClear` (session flag), `gp` (prefix printer). Upvalues of core functions captured at load (`RemoveFromList`, `isServerMatch`, `ResetIgnoreDB`, `ResetBlizzardIgnore`, `trim`, `canonPlayer`, `lookupGuildMember`, `ensureDB`).

Core calls: see section (a) and the dependency list. Reads `PourSocialScoreDB` (ignoreList, typeList, dateList, factionList, notes, delList, guildData, hiddenTotal) directly; writes only through setters. Writes runtime debug state `M.PSS_CoreDebug.on/allUntil` (ChatBlock).

### (a) Slash command table

Keywords are matched lowercased; the rest (`argStr`) keeps its case.

| Command | Aliases | Handler / core call | What it does |
| --- | --- | --- | --- |
| `/pss` | `/pss gui`, `ui`, `eui` | `M.PSS_OpenUI()` (BlizzardUI) | Open or close the window |
| `/pss test` | | `PSSTest()` | **Does nothing** (empty; slated for removal in P1) |
| `/pss clear` then `/pss clear confirm` | | `PSS_ResetIgnoreDB`, `PSS_ResetBlizzardIgnore` | Wipes the ignore list after a warning; the warning flag `firstClear` stays armed for the session |
| `/pss defexpire <days>` | | `PSS_SetOpt("defexpire")` | Default expiry days |
| `/pss asknote on|off|true|false` | | `PSS_SetOpt("asknote")` | Ask for a note on add |
| `/pss showmsg on|off|true|false` | | `PSS_SetOpt("chatmsg")` | Chat messages |
| `/pss sameserver on|off|true|false` | | `PSS_SetOpt("sameserver")` | Same-server option |
| `/pss list [days|name|npc|server]` | | local `ShowIgnoreList` | Print entries older than N days, by realm, NPCs or all (`pairs` over the array; `notes[key] ~= ""` concat errors if a note is nil: N48) |
| `/pss add <name>` | `ignore` | `M.ignoreFromCmd(argStr)` | Add (empty: target; multi-word names via `PSS_SplitNameArg`) |
| `/pss remove <name|index>` | `delete` | index: `AddOrDelNPC` / `AddOrDelServer` / `PSS_DelIgnore(i, true)` + `PSS_PlayersChanged(true)`; name: NPC via `hasNPCIgnored` + `PSS_RemoveFromList`, else `PSS_DelIgnore(PSS_SplitNameArg(name), true)` | Remove |
| `/pss server <realm>` | `addserver` | `AddOrDelServer` | Toggle a whole server |
| `/pss npc <name>` | `addnpc` | `AddOrDelNPC` | Toggle an NPC |
| `/pss expire <name|index> <days>` | | `PSS_SetExpiry` | Set expiry (name via `PSS_SplitNameArg`, `hasGlobalIgnored`) |
| `/pss mem [full]` | `memory` | `PSS_MemReport` (Perf) | Memory report |
| `/pss check` | | `PSS_PrintValidation` (Upgrade) | Save validation |
| `/pss sync` | | `SyncIgnoreList(false)` | Sync Blizzard's list into PSS |
| `/pss dellist` | | prints `PourSocialScoreDB.delList` with `print` | Debug list |
| `/pss prune <days>` | | `PruneIgnoreList(days, true)` | Remove entries listed that long, no confirm |
| anything else | `help` | `L.HELP_*` lines with current option states | Help |
| `/pssguild` (or `status`) | | reads `PSS_CoreStats`, `PSS_GCState`, guild rules | Chat filter status, GC status, each rule's counts |
| `/pssguild debug [all]` | | `PSS_CoreDebug.on` / `.allUntil = now + 120` | Per-line debug |
| `/pssguild test <name>` | (target) | `PSS_ExplainPerson` | Dry run across every list |
| `/pssguild chat` | | `ChatFrameUtil.GetMessageEventFilters` or `ChatFrame_GetMessageEventFilters`, `PSS_CoreFilter` | Filter registration and chat addons check |
| `/pssguild check <name>` | | `PSS_LookupGuildMember`, `PSS_CanonPlayer` | Where a member is stored |

---

## (b) Import/Export format

- String: `PSS1:<checksum>:<base64 payload>`. Tag `PSS1`; checksum = 6 hex digits (`h = (h*33 + byte) % 16777213`, seed 5381) over the raw payload; base64 standard alphabet with `=` padding; decode strips non-base64 characters (so line wraps are tolerated).
- Payload serialiser: `T` / `F` booleans, `n<number>;`, `s<len>:<bytes>`, tables `{ k v k v ... }` with keys sorted (numbers first). Only string/number keys and boolean/number/string/table values. Decoder: depth cap 40, rejects trailing data, never `loadstring`.
- Data table: `{ v = 1, addon = "PourSocialScore", made = "YYYY-MM-DD HH:MM", by = M.PSS_CharKey(), players?, guilds?, filters?, builtins?, options? }`.
  - `players[]`: `{ name, type (player|npc|server), note, date, exp, faction, prefs = {whispersBlocked, partyInvitesBlocked, guildInvitesBlocked, partyRaidBlocked, channelsBlocked, nickname}, opts }`.
  - `guilds[]`: `{ name, enabled, declineGuild, declineGroup, partyRaid, customScan, ruleOrigin, block = {whisper, partyInvite, guildInvite, partyRaid, world}, opts, members[]? }`; members (only when the members part is ticked): `{ key, name, guild, whenBlocked, note, excluded*, class, className, level, race, _playerKey, block, opts }`.
  - `filters[]` (custom only): `{ desc, filter, active }`. `builtins`: `{ [filterID] = active }`. `options`: `{ [key] = value }` for every `M.PSS_OPTIONS` key with a stored value.
- Sections the tab offers (`M.PSS_IO_PARTS`): players, guilds, members (only with guilds), filters, builtins, options; mode merge (default) or replace (asks first with `PSS_DescribeImport`).
- Apply: Merge adds what is missing (players by `PSS_IsPlayerListed` / NPC / server match; guilds by canon key; members by normalised key, merged into a shipped record via `PSS_MergeIntoShipped` when possible; filters by `filter .. "\1" .. desc`). Replace: players removed one by one (`PSS_RemoveListEntryAt`), **guildData set to `{}`** (N45), custom filters removed. Options are validated against their definition (`importedOption`; any string passes for a choice option whose default is a string) and written through `PSS_SetOpt("global")`. Newly listed guild members' chat lines are purged in one batch (`M.PSS__purgeBatch` -> `PSS_PurgeChatFrom`). Ends with index-dirty marks, `PSS_LoadActiveManagedData`, `PSS_RequestGC("import")` and the three change events.
- Unknown fields are dropped on import (copy lists are fixed), which core uplift 2.3 item 7 changes.

## (c) The window's view model (ViewNav and the *View files)

- **Tabs**: `M.PSS_UI_TABS` = players, guilds, filters, events, importExport, options (ids 1 to 6); `M.PSS_UI_EVENTS_TAB = 4`. The last tab is saved by key in `PourSocialScoreDB.windowPoints.PSS_WindowTab` (tab 1 = not stored). Events is never saved or reopened (it would load Logging before any click).
- **Places**: `M.PSS_UIPlace(key)` / `M.PSS_SetUIPlace(key, point, relPoint, x, y)` in `windowPoints[key]` (routed to `PSS_OptionsDB`). Look `M.PSS_UISkin()`, font `M.PSS_UIFontPath()`, accent `M.PSS_UIAccent()`.
- **Back / forward**: `M.PSS_NavNew(max=50)` keeps `steps = { {tab, view} }` and `pos`. `Record(tab, view)` adds a step (drops forward steps; no-op if unchanged; oldest dropped past max); `Back()`, `Forward()`, `CanBack()`, `CanForward()`, `Current()`, `Replace(tab, view)` (the view shown is gone), `BackToOther(tab)` (Escape on Events goes back to the tab it came from). `view` is a string each tab defines (for Events, `View:NavKey()` builds it from the query and keeps a copy in `saved` so `NavApply` can restore it; for Guilds the members view is titled by `M.PSS_MembersNavTitle`).
- **Levels**: Guilds has two levels in one tab (`List.view = "guilds"` or `"members"`; `OpenMembers` / `CloseMembers`, the latter wipes the member array). Escape behaviour lives in the GUI.
- **List views**: each of Players / Guilds / Filters has a `List` class (mixin `SortBy`, `SetFind`), a `Resort()` that fills a reused index from a core or Libraries query, and dirty flags. Guild rows recount lazily per drawn row (`gen` / `FreshCounts`).
- **Pane state shared across panes** (session): period ticks, type ticks (DetailQuery), history type ticks; Import/Export ticks (`M.PSS_IO`).
- **Lifetime**: nothing in Libraries is dropped on window close by itself. What is dropped is what the GUI asks for: `View:Release()` (Events lines), `List:CloseMembers()`, `M.PSS_GuildPickerClose` -> `PSS_ForgetGuildSearch`. The GUI's own tab objects hold the list states.

## (d) Dependency list: Libraries file -> core files

| Libraries file | Core files it calls |
| --- | --- |
| PSS_ImportExport | PSS_ChatBlock, PSS_PlayerIgnoreList, PSS_GuildIgnoreList, PSS_ChatFilters, PSS_Options, PSS_Perf, PSS_Events |
| PSS_GuildQuery | PSS_GuildIgnoreList, PSS_ChatFilters, PSS_WhoisHarvest, PSS_ChatHistory, PSS_Globals |
| PSS_FilterQuery | PSS_ChatFilters, PSS_ChatHistory |
| PSS_TotalsQuery | PSS_PlayerIgnoreList, PSS_GuildIgnoreList, PSS_ChatFilters, PSS_ChatHistory |
| PSS_EventsQuery | PSS_ChatHistory, PSS_GuildIgnoreList, PSS_PlayerIgnoreList, PSS_PlayerQuery |
| PSS_DetailQuery | PSS_ChatHistory, PSS_Options (+ Libraries TotalsQuery, EventsQuery) |
| PSS_ViewNav | PSS_Options |
| PSS_PlayerView | PSS_PlayerQuery, PSS_PlayerIgnoreList, PSS_ChatBlock, PSS_Whois, PSS_GuildIgnoreList, PSS_Globals |
| PSS_GuildView | PSS_GuildIgnoreList, PSS_ChatFilters, PSS_WhoisHarvest, PSS_Whois, PSS_PlayerQuery, PSS_ChatHistory, PSS_Globals |
| PSS_FilterView | PSS_ChatFilters, PSS_GuildIgnoreList (`PSS_Say`), PSS_Globals |
| PSS_EventsView | PSS_ChatHistory, PSS_Globals |
| PSS_OptionsView | PSS_Options, PSS_Globals |
| PSS_RowMenus | PSS_PlayerQuery, PSS_PlayerIgnoreList, PSS_GuildIgnoreList, PSS_ChatFilters, PSS_Globals |
| PSS_Commands | PSS_PlayerIgnoreList, PSS_GuildIgnoreList, PSS_ChatBlock, PSS_Globals, PSS_Options, PSS_PlayerQuery, PSS_Perf, PSS_Upgrade, PSS_BlizzardUI |

Libraries -> Libraries: DetailQuery uses TotalsQuery (`PSS_ListTotals`, `History.RecentByCat`) and EventsQuery (`PSS_SumCats`, `PSS_EventType`); the three *View files use ViewNav (`PSS_ListMixin`); EventsView uses the *View specs; OptionsView uses ImportExport; RowMenus uses DetailQuery, GuildView, PlayerView, FilterQuery; GuildView uses GuildQuery and EventsQuery.

## Exports with no caller outside their own file

| Export | File | Note |
| --- | --- | --- |
| `M.PSS_HexColor` | DetailQuery | Dead export (local used) |
| `M.PSS_TypeOff` | DetailQuery | Dead |
| `M.PSS_AnyTypeOff` | DetailQuery | Harness only |
| `M.PSS_OverrideValue` | DetailQuery | Internal + harness |
| `M.PSS_PeriodSince` | EventsQuery | Internal |
| `M.PSS_GroupGuilds` | EventsQuery | Internal |
| `M.PSS_GuildGroupLabel` | GuildView | Internal |
| `M.PSS_PlayerTargetName` | PlayerView | Internal |
| `M.PSS_SlashPSS`, `M.PSS_SlashGuild` | Commands | Core slash stubs only (expected) |

## Direct SavedVariables writes (not through a core setter)

| Where | Write |
| --- | --- |
| GuildQuery `collectGuilds` | `g.memberCount` on every rule, every list redraw |
| GuildQuery `PSS_GuildGroupOpen` / `PSS_SetGuildGroupOpen` | `PourSocialScoreDB.guildGroupOpen` (UI state) |
| ViewNav `PSS_SetUIPlace` / `PSS_SetUITab` | `PourSocialScoreDB.windowPoints` (UI state) |
| ImportExport `PSS_ApplyImport` | player prefs and `opts`; `db.guildData = {}` on replace; guild fields, `opts`, `block`, `members[mk]`, `memberCount` |
