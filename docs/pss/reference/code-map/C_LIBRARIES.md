# PourSocialScore_Libraries: reference map (3.4.1.53)

The load-on-demand back end: slash commands, Import/Export, all logic for the PSS window (`PourSocialScore_GUI`), and the rarely used work moved out of core in P6 (player rows, the save check, the scan planner) and S3 (the Camelot name repair). It draws nothing (except chat lines through `M.ShowMsg` / `M.ChatMsg` / `M.PSS_Say`). Every file starts with `local addon = PourSocialScore_NS; local M = addon.M` (some also take `V`, `L`, `History = M.PSS_History`).

Legend for callers: **GUI** = files in `PourSocialScore_GUI/`; **Lib** = other Libraries files; **core** = core files.

## 0. How it loads (`PourSocialScore/PSS_Loader.lua`)

| Item | What it does |
| --- | --- |
| `PourSocialScore_NS = addon` | The one cross-addon global |
| `NEEDS = { GUI = "Libraries" }` | Loading the GUI loads Libraries first |
| `M.PSS_Need(key)` | Loads the part (and its NEEDS); warns once on failure or a version that differs from core |
| `M.PSS_Stub(fname, key)` | A stand-in at `M[fname]` that loads the part on first call |

Who triggers Libraries:
- The first `/pss` or `/pssguild` command (`M.PSS_SlashPSS` / `M.PSS_SlashGuild` stubs, `PourSocialScore.lua`).
- Opening or docking the window (`M.PSS_Need("GUI")` in `PSS_BlizzardUI.lua`).
- The first call of a core stub: player rows (`PSS_PlayerQuery.lua`), `PSS_Validate` / `PSS_PrintValidation` (`PSS_SavedData.lua`, also a login that moves 2.0 keys), the scan planner and `PSS_ScanAll` (`PSS_Whois.lua`, including the key binding).
- Upgrade step 10 on a Camelot save that holds names (`M.PSS_RepairCamelotNames`).
- A load-on-demand addon never unloads: **everything module-level in Libraries lives for the rest of the session** once loaded.

TOC order (`## Dependencies: PourSocialScore`, `## LoadOnDemand: 1`): PSS_ImportExport, PSS_PlayerRows, PSS_Validate, PSS_WhoisHarvest, PSS_Camelot, PSS_GuildQuery, PSS_FilterQuery, PSS_TotalsQuery, PSS_EventsQuery, PSS_DetailQuery, PSS_ViewNav, PSS_PlayerView, PSS_GuildView, PSS_FilterView, PSS_EventsView, PSS_OptionsView, PSS_RowMenus, PSS_Commands. PSS_ViewNav must precede the *View files (`M.PSS_ListMixin` at load); PSS_GuildView must precede PSS_RowMenus.

Total: 5825 lines in 18 files.

---

## 1. PSS_ImportExport.lua (528 lines)

Purpose: export chosen sections to one text string; import with Merge or Replace; `/pss export unused`. Own typed serialiser (never executes code), base64, checksum.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_EncodeExport(tbl)`, `M.PSS_DecodeExport(text)` | Query | `PSS1:<sum>:<b64>` and back | Lib: OptionsView |
| `M.PSS_BuildExport(sections)` | Query | The data table (format `v = 2`); every W I G P C switch filled (`p[f] ~= false`); member `name`, `guild`, `whenBlocked` through the accessors; a record's unknown fields in `more` | Lib: OptionsView |
| `M.PSS_DescribeImport(data)` | View | "3 ignore list entries, 2 guild rules (40 members), ..." | Lib: OptionsView |
| `M.PSS_ApplyImport(data, mode, sections)` | Action | Merge / Replace; returns a report | Lib: OptionsView |
| `M.PSS_UnusedExportText()` | Query | (U3) export string of the rules and settings this version cannot use (`unused = true`), or nil | Lib: Commands |

Locals: `ser`, `deser` (depth cap 40), `b64enc`, `b64dec`, `checksum`, `PREF_FIELDS` (from `M.PSS_BLOCK_FIELDS` + nickname), `BLOCK_CATS` (= `M.PSS_EXCL_CATS`), `GUILD_FIELDS`, `MEMBER_FIELDS`, `copyFields`, `copyOpts`, `moreFields`, `keepMore` (puts `more` back only where the field is unknown, `M.PSS_SchemaKnows`), `importedOption`.

Core calls: ChatBlock (canon helpers, `PSS_NowString`, `PSS_PurgeChatFrom`); PlayerIgnoreList (`PSS_GetPlayerRecord`, `PSS_GetPlayerPrefs`, `PSS_IsPlayerListed`, `hasNPCIgnored`, `PSS_ImportListEntry`, `PSS_RemoveListEntryAt`, `PSS_MarkIgnoreIndexDirty`); GuildIgnoreList (`PSS_GetGuild`, `PSS_GuildBlock`, `PSS_MemberBlock`, member accessors, `PSS_MergeIntoShipped`, `PSS_CompactMember`, `PSS_ClearGuildRules`, `PSS_RefreshGuildActive`, `PSS_MarkGuildIndexDirty`, `PSS_LoadActiveManagedData`); ChatFilters (`PSS_IsBuiltinFilter`, `PSS_AddCustomFilter`, `RemoveChatFilter`, `PSS_SetFilterActive`); Options (`PSS_CharKey`, `PSS_OPTIONS`, `PSS_OPTION_REG`, `PSS_SetOpt`); Upgrade (`PSS_SchemaKnows`, `PSS_UnusableRules`); Perf (`PSS_RequestGC("import")`).

Events fired: `PLAYERS_CHANGED` (true), `GUILDS_CHANGED`, `FILTERS_CHANGED` at the end of every `PSS_ApplyImport`.

SavedVariables written directly (not via setters): player prefs (a blocking switch stored as nil) and `opts`; guild fields, `opts`, `block`, `members[mk]`. Replace on guilds calls `M.PSS_ClearGuildRules()` (N45: shipped rules stay). Options go through `M.PSS_SetOpt`; entries through `PSS_ImportListEntry` / `PSS_RemoveListEntryAt`.

---

## 2. PSS_PlayerRows.lua (405 lines; from core `PSS_PlayerQuery.lua` in P6)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_PlayerCount()` | Query | `#M.PSS_List()` | Lib: PlayerView, EventsQuery |
| `M.PSS_PlayerRow(i, out)` | Query | Fills the caller's reused table: entry, kind, name, server (pretty), faction, added, listed, expire, left, note, record (`PSS_GetPlayerPrefs`, creates one when missing) | GUI: Players; Lib: PlayerView, RowMenus |
| `M.PSS_PlayerEntry(i)`, `M.PSS_PlayerPosition(entry)` | Query | entry, kind; position (`hasAnyIgnored`) | GUI: Players; Lib |
| `M.PSS_SortPlayers(key, asc, findText, into)` | Query | Filter by text and sort by name, server, type, listed, expire, note, `metric:<cat>`, `excl:<cat>` | Lib: PlayerView |
| `M.PSS_RemovePlayerAt(i)` | Action | Player: `PSS_DelIgnore(i, true)`; NPC/realm: `AddOrDelNPC/Server(i)` + `PSS_PlayersChanged` | GUI: Players; Lib: RowMenus |
| `M.prettyServer(name)` | View | "Aeriepeak" -> "Aerie Peak" (lazy `REALM_PAIRS` map) | this file |

Core keeps stubs for the six list calls (`PSS_PlayerQuery.lua`).

---

## 3. PSS_Validate.lua (215 lines; from core `PSS_Upgrade.lua` in P6)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_Validate()` | Query | `{n = counts, problems = list}`: lists, notes, guild rules/members (`M.PSS_GuildMemberCount`), filters, log/keep lines, block counters per source and type, options changed. Read only | core SavedData (before/after a key move) |
| `M.PSS_PrintValidation()` | Command | Loads Logging, prints the report | Lib: Commands (`/pss check`) |

---

## 4. PSS_WhoisHarvest.lua (282 lines; from core in P6)
The guild sweep planner and Scan All. Exports and flow: `B_CORE_LISTS.md` section 6. Callers: core GuildIgnoreList (`PSS_HarvestNext/Sent/Answered`, `PSS_CapWhoFilter` through core stubs), Lib GuildView (`PSS_ScanAllNext`, `PSS_GuildSweep`, `PSS_GuildSweepLabel`, `PSS_HarvestFilter`), GuildQuery (`PSS_GuildSweepSent`), GUI Guilds (`PSS_ScanAll`), the key binding.

---

## 5. PSS_Camelot.lua (160 lines; S3, step 10)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_RepairCamelotNames()` | Action | On a Camelot save only (core checks client and realm): a member keyed `first-last` with a faction and no `_playerKey` goes into the shipped member (`M.PSS_MergeIntoShipped`), else its stored twin (`M.PSS_MergeMember`), else is stored as `first last-<own realm>`; Player Ignore List entries, their records and `delList` the same; lines and recent counts follow (`History.RenameOwner`). Returns members, players, and the names that may have lost their surname (printed once) | core Upgrade (step 10) |

---

## 6. PSS_GuildQuery.lua (350 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_GUILD_EXCL_OPEN`, `M.PSS_GUILD_MANAGED_SHUT` | const | Open-state keys | Lib: GuildView, RowMenus |
| `M.PSS_GuildGroupOpen(k)`, `M.PSS_SetGuildGroupOpen(k, on)` | Query/Action | Collapsible row state (`PourSocialScoreDB.guildGroupOpen`) | Lib: GuildView |
| `M.PSS_FindGuildRule(nameOrKey)` | Query | key, record (through core `M.PSS_FindGuildRecord`, P5) | Lib: GuildView, RowMenus |
| `M.PSS_GuildCount()` | Query | Number of guild rules | Lib: GuildView |
| `M.PSS_GuildRows(sortKey, asc, find, into)` | Query | The list in display order (managed header, groups, Exclusion List, other guilds); each item's member count is `item.count` from `M.PSS_GuildMemberCount` (nothing saved) | Lib: GuildView, TotalsQuery |
| `M.PSS_GuildMembers(gkey, sortKey, asc, find, into)` | Query | Stored plus shipped members, searched and sorted | Lib: GuildView |
| `M.PSS_AddMembersGuild(gkey, actual)` | Action | Add Guild on a member (`M.PSS_AddCapturedGuild`) | GUI: Guilds |
| `M.PSS_ForgetGuildSearch()` | Action | `M.PSS_GuildSearchCache = nil` | Lib: GuildView |

SavedVariables written directly: `guildGroupOpen` (UI state). The `g.memberCount` write on every redraw is gone (S2/S3).

---

## 7. PSS_FilterQuery.lua (145 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_FilterCount()` | Query | total, built-in, custom, on | Lib: FilterView |
| `M.PSS_FilterBlockedText(i)` | View | Blocked cell; "n/a" for a guild rule | Lib: FilterView |
| `M.PSS_FilterRow(i, into)`, `M.PSS_FilterRows(key, asc, find, into)` | Query | One row; filter numbers in display order (built-ins first) | GUI: Filters; Lib |
| `M.PSS_AllFilterHistory()`, `M.PSS_ResetAllFilterHistory()` | Query/Action | Every filter's lines (loads Logging); reset all | Lib: FilterView |
| `M.PSS_TestChatFilter(filter, text)` | Query | "blocked", "passed" or "error" via `M.filterComplex` | Lib: FilterView |
| `M.PSS_ConvertChatLink(link)` | Query | A chat link as a tag (`[item=ID]`, `[talent=ID]`, ...) | GUI: Filters |

---

## 8. PSS_TotalsQuery.lua (118 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_ListTotals(kind, into, guildRows)` | Query | kind players/guilds/filters: total and one count per `History.ALL_CATS` (totals through `History.CountTotal`); session, day from `History.RecentTotals(prefix)` | Lib: DetailQuery |
| `History.RecentByCat(owner, into, prefix)` | Query | Session and 24 h counts by type; added to core's `History` table | Lib: DetailQuery, EventsQuery |

Reads counters only; never loads Logging.

---

## 9. PSS_EventsQuery.lua (268 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_EVENT_TYPES`, `M.PSS_EventType(h)` | const/Query | Line types | GUI: History; Lib |
| `M.PSS_ParseEventTime(text)`, `M.PSS_PeriodSince(key)`, `M.PSS_EventRange(q)`, `M.PSS_EventMatches(q, h, find, since, upto)` | Query | Time window and matching | Lib: EventsView |
| `M.PSS_AddExpiredEvents(lines, counts, slots, person)` | Query | Rows for counted blocks no longer stored | Lib: EventsView |
| `M.PSS_SumCats(t, off)`, `M.PSS_StoredText(owner, total, who)` | Query/View | Sum by type; "Stored: N in the log, M kept" | Lib: DetailQuery; GUI: Detail |
| `M.PSS_GroupGuilds(k)`, `M.PSS_GroupEvents(k)`, `M.PSS_ResetGroupEvents(k)`, `M.PSS_GroupRecent(items, into)`, `M.PSS_GroupRecentByCat(items, into, one)` | Query/Action | Managed list reads and resets | Lib: GuildView; GUI: Guilds |
| `M.PSS_ListedPlayerEvents()`, `M.PSS_ResetListedPlayerEvents()`, `M.PSS_ResetAllGuildEvents()` | Query/Action | Whole-list reads and resets | Lib: PlayerView, GuildView |

---

## 10. PSS_DetailQuery.lua (354 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_PERIODS`, `M.PSS_PeriodOn(k)`, `M.PSS_SetPeriodOn(k, on)`, `M.PSS_SetTypeOff(cat, off)`, `M.PSS_WidestPeriodOn()`, `M.PSS_TypesOn()` | View state | Period and type pie ticks (session) | GUI: Detail |
| `M.PSS_SummaryValues(spec, into)`, `M.PSS_PeriodSlices`, `M.PSS_PeriodTip`, `M.PSS_TypeSlices`, `M.PSS_TypeTip(title, sl, click)` | Query/View | Pie maths and tips | GUI: Detail |
| `M.PSS_SpecCopy(spec)` | View | (G8) a copy of a Summary spec | GUI: Detail |
| `M.PSS_TotalsView(kind, into, guildRows)`, `M.PSS_CountsText(c)` | Query/View | Totals; "Blocked 12: Whispers 3 ..." | GUI: Detail; Lib |
| `M.PSS_OVERRIDE_SHORT`, `M.PSS_OverrideOptions()`, `M.PSS_OverrideValue(target, key)` | Query | Target options | GUI: Detail; Lib: RowMenus |
| `M.PSS_ExceptionState`, `M.PSS_SetException`, `M.PSS_ToggleException`, `M.PSS_ExceptionHeading`, `M.PSS_ExceptionText`, `M.PSS_ExceptionTip` | Query/Action/View | Exceptions (`M.PSS_SetOpt(key, scope, v, target)`) | GUI: Detail; Lib |
| `M.PSS_ClassColor(class)` | View | Class colour | GUI; Lib |
| `M.PSS_HistHidden(t)`, `M.PSS_SetHistHidden(t, h)`, `M.PSS_HistFilter(all, out)` | View state | Pane history type ticks | GUI: History |
| `M.PSS_HistCells(h, into)`, `M.PSS_HistTip(h, canOpen)`, `M.PSS_HistEmptyText` (string) | View | (G1) pane history row, tip and empty text | GUI: History |

Gone (W1): `M.PSS_TypeOff`, `M.PSS_AnyTypeOff`, `M.PSS_HexColor`.

---

## 11. PSS_ViewNav.lua (299 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_UISkin()`, `M.PSS_UIAccent()`, `M.PSS_UIFontPath()`, `M.PSS_UIFontChoices()` | Query | Look ("modern" default, "blizzard" = Classic, "dark"), class colour, font file (LibSharedMedia read only), font choices | GUI: Skin, Window |
| `M.PSS_UIPlace(key)`, `M.PSS_SetUIPlace(key, ...)`, `M.PSS_UITab()`, `M.PSS_SetUITab(id)` | Query/Action | `windowPoints[key]` and `windowPoints.PSS_WindowTab` (Events never saved) | GUI: Window |
| `M.PSS_UI_TABS`, `M.PSS_UI_EVENTS_TAB = 4` | const | players, guilds, filters, events, importExport, options | GUI: Window |
| `M.PSS_NavNew(max)` | View | Back/forward history object | GUI: Window |
| `M.PSS_DoubleClick(state, key, now)`, `M.PSS_Throttle(fn, delay)` | View | Second click within 0.35 s; coalesce a burst (0.25 s) | GUI |
| `M.PSS_ListMixin(List)` | View | `SortBy`, `SetFind` onto a list class | Lib: *View |
| `M.PSS_PickerToggle(it)`, `M.PSS_PickerTickAll(items)`, `M.PSS_PickerCells(it, into)` | View | Search-results picker ticks and cells (G2, both pickers) | GUI: Players, Guilds, Rows |

---

## 12. PSS_PlayerView.lua (360 lines)

List object: `M.PSS_PlayerListNew()` with `:Resort()` (-> `M.PSS_SortPlayers`), `:SortBy`, `:SetFind`.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_PlayerListNew()` | View | List state | GUI: Players |
| `M.PSS_PlayerTypeText`, `M.PSS_PlayerExpireText`, `M.PSS_PlayerListedText(r)`, `M.PSS_PlayerTotal`, `M.PSS_PlayerTip` | View | Cells ("Nd" strings made once, G25), tips | GUI: Players; Lib |
| `M.PSS_PlayerHeading`, `M.PSS_PlayerTypeLine`, `M.PSS_PlayerAddedLine`, `M.PSS_PlayerExpireNote`, `M.PSS_PlayerExpireBoxText`, `M.PSS_PlayerGuildLine`, `M.PSS_PlayerInviteLine`, `M.PSS_PlayerSummarySpec(r, c, into)` | View | Pane lines and Summary spec (G7) | GUI: Players |
| `M.PSS_PlayerGuildState(p)` | Query | currentGuild, listed?, button text | GUI: Players; Lib: RowMenus |
| `M.PSS_PlayerRemoveText(entry)`, `M.PSS_PlayerTargetName()` | View/Query | Confirm text; target name (internal) | GUI; Lib |
| `M.PSS_PlayerAddFromText`, `M.PSS_PlayerSearchFromText`, `M.PSS_PlayerPickerItems/Title/Cells/Save`, `M.PSS_PlayerNoneFound`, `M.PSS_PlayerAddAnyway` | Action/View | Add, /who search (`M.PSS_PlayerSearch`), picker | GUI: Players |
| `M.PSS_PRUNE_DAYS`, `M.PSS_PruneText`, `M.PSS_PruneNote`, `M.PSS_PruneApply` | View/Action | Prune dialog | GUI: Players |
| `M.PSS_PlayerCommitExpiry`, `M.PSS_PlayerCommitNote`, `M.PSS_PlayerAllowed`, `M.PSS_PlayerToggleAllowed` | Action/Query | `PSS_SetExpiry`, `PSS_SetNote`, `PSS_SetPlayerSetting` + `PSS_PlayersChanged` | GUI: Players |
| `M.PSS_BLIZZARD_TEXT`, `M.PSS_BLIZZARD_TIP`, `M.PSS_PlayerOnBlizzard`, `M.PSS_PlayerToggleBlizzard` | View/Action | B1 tick (`PSS_SetBlizzardIgnore`) | GUI: Players |
| `M.PSS_PlayerAddGuild(guild)` | Action | `PSS_AddGuild` + chat line | GUI: Players |
| `M.PSS_AllPlayersSpec()`, `M.PSS_PlayerEventsSpec(entry)` | View | Events specs | GUI: Players; Lib: EventsView |

---

## 13. PSS_GuildView.lua (837 lines, largest)

List object `M.PSS_GuildListNew()`; methods: `Resort`, `CountsChanged`, `FreshCounts`, `GuildCounts(key)` (reuses the drawn row's count only during a block redraw, `self.share`, G22), `EmptyText`, `SearchHint`, `RemoveTarget`, `MarkDirty(guilds, members)`, `CountText`, `IsSel`, `Select`, `ItemSel`, `Click` (own 0.35 s `DOUBLE_CLICK`), `OpenMembers`, `SelectMember`, `SetView`, `GuildRemoved`, `CloseMembers`, `MResort`, `MSortBy`, `SetMFind`, `MembersHeading`, `MembersEmptyText`, `RemoveMember`.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_GUILD_MANAGED`, `M.PSS_GUILD_SEARCH_OWNER` | const | Managed row id; search owner tag | GUI: Guilds; Lib |
| `M.PSS_GuildListNew()` | View | List state | GUI: Guilds |
| `M.PSS_GuildRowCells`, `M.PSS_GuildRowTip`, `M.PSS_GuildScanTip(key or record)` | View | Row texts (dim for a group whose rule is off), tips | GUI: Guilds |
| `M.PSS_GuildExists(key)`, `M.PSS_GuildOpts(key)`, `M.PSS_GuildPaneView(key, into)`, `M.PSS_MemberPaneView(gkey, m, into)`, `M.PSS_MemberCells(m, into)` | Query/View | (G3) pane data; returns the record as a handle for the boxes; the only window reads of `m.note` and `m.class` | GUI: Guilds |
| `M.PSS_GuildSummarySpec`, `M.PSS_MemberSummarySpec`, `M.PSS_GroupSummarySpec` | View | (G7) Summary specs | GUI: Guilds |
| `M.PSS_GuildAddFromText`, `M.PSS_GuildExcludeFromText`, `M.PSS_GuildSearchFromText(text, mode)` | Action | `PSS_AddGuild`, `PSS_AddGuildExclusion`, `PSS_GuildSearch` | GUI: Guilds |
| `M.PSS_GuildPickerItems/Title/Save/Close`, `M.PSS_GuildNoneFound`, `M.PSS_GuildExcludeAnyway` | View/Action | Picker (ticks through ViewNav's `PSS_PickerToggle/TickAll`) | GUI: Guilds |
| `M.PSS_MembersNavTitle`, `M.PSS_MemberTip`, `M.PSS_GuildInfoLine(g, key)`, `M.PSS_GuildGroupView`, `M.PSS_GuildExclView`, `M.PSS_GuildGroupLabel` | View | Titles and pane text | GUI: Guilds |
| `M.PSS_MemberHeading`, `M.PSS_MemberGuildLine`, `M.PSS_MemberAddedLine`, `M.PSS_MemberAllowed`, `M.PSS_MemberOtherGuild` | View | Member pane (through the member accessors) | Lib (pane view) |
| `M.PSS_GuildHistoryKey`, `M.PSS_MemberHistoryKey`, `M.PSS_MemberBlockTotal` | Query | Owner keys; total | Lib; GUI |
| `M.PSS_GuildAllowed`, `M.PSS_GuildToggleAllowed`, `M.PSS_GuildToggleException`, `M.PSS_MemberToggleException` | Query/Action | W I G P C and exceptions | GUI: Guilds |
| `M.PSS_GuildScanNow`, `M.PSS_GuildCustomScan`, `M.PSS_GuildCommitFields` | Action | `PSS_ScanGuild`, `PSS_SetGuildScanFields` | GUI: Guilds |
| `M.PSS_GuildRemoveText`, `M.PSS_GuildRemove`, `M.PSS_MemberRemoveText`, `M.PSS_MemberCommitNote`, `M.PSS_MemberToggleAllowed` | View/Action | `PSS_RemoveGuildNow`, `PSS_SetMemberNote`, `PSS_SetMemberBlock` | GUI: Guilds |
| `M.PSS_GroupToggleRule`, `M.PSS_GroupToggleOpen`, `M.PSS_ExclRemove` | Action | `PSS_SetManagedGroupActive`; open state; `PSS_RemoveGuildExclusion` | GUI: Guilds |
| `M.PSS_AllGuildsSpec`, `M.PSS_GuildEventsSpec`, `M.PSS_GroupEventsSpec`, `M.PSS_MemberEventsSpec` | View | Events specs | GUI: Guilds; Lib: EventsView |

Gone (W1): `M.PSS_GuildPickerToggle`, `M.PSS_GuildPickerTickAll` aliases. `PSS_SetMemberBlock`, `PSS_SetMemberNote` and `PSS_SetGuildScanFields` still fire nothing; the tab redraws itself.

---

## 14. PSS_FilterView.lua (180 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_FilterListNew()` | View | List state | GUI: Filters |
| `M.PSS_FilterRowCells`, `M.PSS_FilterRowTip`, `M.PSS_FilterHeading`, `M.PSS_FilterInfo`, `M.PSS_FilterHistoryLine`, `M.PSS_FilterSummarySpec` | View | Row, editor text, Summary spec (G7) | GUI: Filters |
| `M.PSS_FilterSave`, `M.PSS_FilterCopy`, `M.PSS_FilterNew`, `M.PSS_FilterRemoveText`, `M.PSS_FilterRemove` | Action | `PSS_SaveChatFilter`, `PSS_CopyChatFilter`, `PSS_AddCustomFilter`, `RemoveChatFilter` | GUI: Filters |
| `M.PSS_FilterTestText(filter, line)` | View | BLOCKED / PASSED / FILTER ERROR | GUI: Filters |
| `M.PSS_AllFiltersSpec()`, `M.PSS_FilterEventsSpec(i)` | View | Events specs | GUI: Filters; Lib |

---

## 15. PSS_EventsView.lua (437 lines)

Spec contract: `{ kind, id, label(id), read(id), reset(id), confirm?, owner(id), counts(id), all(), allText }`; a whole-list spec has `id = false` and `source = "players"|"guilds"|"filters"`.

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_EVENT_SOURCES`, `M.PSS_EVENT_TIMES` | const | Sources; session, day, all, custom | GUI: Events |
| `M.PSS_EventsViewNew()` | View | The view object | GUI: Events |
| `M.PSS_EventCells`, `M.PSS_EventTip`, `M.PSS_EventCopy` | View | Cells, tip, copy text | GUI: Events |

View methods: `Open`, `Refresh` (spec `read` loads Logging), `Release`, `Apply`, `SortBy`, `SetPeriod`, `RangeTexts`, `ApplyRange`, `AllTypes`, `TypeOn`, `ToggleType`, `SourceOn`, `ToggleSource`, `ScopeOff`, `IsCustom`, `Scoped`, `PeriodIs`, `ScopeText` (G9), `Heading`, `TimeLabel`, `TypesLabel`, `SourceLabel`, `EmptyText`, `NavKey`, `NavTitle`, `NavApply`, `Reset`, `ResetText`, `DoReset`, `SourceText`.

---

## 16. PSS_OptionsView.lua (206 lines)

| Export | Kind | Meaning | Callers |
| --- | --- | --- | --- |
| `M.PSS_OptLabel`, `M.PSS_OptTip`, `M.PSS_OptChoiceText`, `M.PSS_OptGroups`, `M.PSS_OptMatches` | View | Rows by section, search | GUI: Options |
| `M.PSS_OptNumberText`, `M.PSS_OptSetNumber`, `M.PSS_OptFieldOn`, `M.PSS_OptFieldText`, `M.PSS_OptSetFieldOn`, `M.PSS_OptSetField` | View/Action | Numbers and tick-with-number (`PSS_SetOpt`) | GUI: Options |
| `M.PSS_IO`, `M.PSS_IOOn(key)`, `M.PSS_IOMode()`, `M.PSS_IOSet`, `M.PSS_IOSetMode`, `M.PSS_IO_PARTS`, `M.PSS_IO_MODES`, `M.PSS_IOPartOff`, `M.PSS_IOModeText` | state/View | Import/Export ticks and mode (session) | GUI: Options |
| `M.PSS_ExportText()` | Query | String and its subtitle (G10) | GUI: Options |
| `M.PSS_ImportStart(str)` | Query | err, or nil, replace confirm text, apply function (G10; calls `PSS_ImportCheck`, `PSS_ImportReplaceText`, `PSS_ImportApply`) | GUI: Options |

---

## 17. PSS_RowMenus.lua (207 lines)

Menus are data: `{kind="title", text}`, `{kind="divider"}`, `{text, act, arg}`, `{kind="check", text, on=fn, act, arg}`.

| Export | Meaning (acts) | Callers |
| --- | --- | --- |
| `M.PSS_PlayerMenu(entry)` | history, addGuild, noExpiry, resetHistory, exceptions, remove | GUI: Players |
| `M.PSS_GuildRowMenu(item)`, `M.PSS_GuildSetAllRules(on)` | managed / group / exclusion / guild rows | GUI: Guilds |
| `M.PSS_MemberMenu(m, gkey)` | history, resetHistory, exceptions, remove | GUI: Guilds |
| `M.PSS_FilterMenu(i)` | toggle, copy, history, resetCount, resetHistory, remove | GUI: Filters |
| `M.PSS_SenderMenu(name)`, `M.PSS_SenderAdd`, `M.PSS_SenderRemoveText`, `M.PSS_SenderRemove` | senderAdd / senderRemove | GUI: History |

---

## 18. PSS_Commands.lua (474 lines)

Exports `M.PSS_SlashPSS(msg)` and `M.PSS_SlashGuild(msg)` (called by core `SlashCmdList`). Locals: `OnOff`, `ShowIgnoreList`, `OPEN = {gui, ui, eui}`, `firstClear`, `gp`.

### (a) Slash command table

| Command | Aliases | Handler / core call | What it does |
| --- | --- | --- | --- |
| `/pss` | `gui`, `ui`, `eui` | `M.PSS_OpenUI()` | Open or close the window |
| `/pss clear` then `/pss clear confirm` | | `PSS_ResetIgnoreDB`, `PSS_ResetBlizzardIgnore` | Wipes the ignore list after a warning |
| `/pss defexpire <days>` | | `PSS_SetOpt("defexpire")` | Default expiry days |
| `/pss asknote`, `showmsg`, `sameserver` `on|off|true|false` | | `PSS_SetOpt` | Options |
| `/pss list [days|name|npc|server]` | | `ShowIgnoreList` (runs `PSS_ExpireEntries` first; N48 fixed) | Print entries |
| `/pss add <name>` | `ignore` | `M.ignoreFromCmd(argStr)` | Add (empty: target) |
| `/pss remove <name|index>` | `delete` | `PSS_DelIgnore`, `AddOrDelNPC/Server`, `PSS_RemoveFromList` | Remove |
| `/pss server <realm>` | `addserver` | `AddOrDelServer` | Toggle a server |
| `/pss npc <name>` | `addnpc` | `AddOrDelNPC` | Toggle an NPC |
| `/pss expire <name|index> <days>` | | `PSS_SetExpiry` | Set expiry |
| `/pss mem [full]` | `memory` | `PSS_MemReport` | Memory report |
| `/pss check` | | `PSS_PrintValidation` (Lib Validate) | Save check |
| `/pss export unused` | | `M.PSS_UnusedExportText` -> GUI `M.PSS_CopyTextBox` (window stays closed) | (U3) copy out unusable rules |
| `/pss sync` | | `SyncIgnoreList(false)` | Sync Blizzard's list into PSS |
| `/pss dellist` | | prints `delList` | Debug list |
| `/pss prune <days>` | | `PruneIgnoreList(days, true)` | Remove entries listed that long |
| anything else | `help` | `L.HELP_*` lines | Help (`/pss test` is gone, P1) |
| `/pssguild` (or `status`) | | `PSS_CoreStats`, `PSS_GCState`, `M.Events.errors`, guild rules | Status |
| `/pssguild debug [all]` | | `PSS_CoreDebug` | Per-line debug |
| `/pssguild test <name>` | (target) | `PSS_ExplainPerson` | Dry run across every list |
| `/pssguild chat` | | filter registrations, `PSS_CoreFilter` | Chat addons check |
| `/pssguild check <name>` | | `PSS_LookupGuildMember`, `PSS_CanonPlayer` | Where a member is stored |

---

## (b) Import/Export format

- String: `PSS1:<checksum>:<base64 payload>`; checksum 6 hex digits (`h = (h*33 + byte) % 16777213`, seed 5381); decode strips non-base64 characters.
- Serialiser: `T`/`F`, `n<number>;`, `s<len>:<bytes>`, tables `{ k v ... }` with sorted keys. Decoder: depth cap 40, never `loadstring`.
- Data table: `{ v = 2, addon = "PourSocialScore", made, by = M.PSS_CharKey(), players?, guilds?, filters?, builtins?, options? }` (`unused = true` for `/pss export unused`).
  - `players[]`: `{ name, type, note, date, exp, faction, prefs = {five switches (true = blocked), nickname}, opts, more }`.
  - `guilds[]`: `{ name, enabled, declineGuild, declineGroup, partyRaid, customScan, ruleOrigin, block, opts, more, members[]? }`; members: `{ key, name, guild, whenBlocked, note, excluded*, class, className, level, race, _playerKey, block, opts, more }` (name fields filled through the accessors).
  - `filters[]` (custom only): `{ desc, filter, active }`. `builtins`: `{ [id] = active }`. `options`: `{ [key] = value }`.
- Apply: Merge adds what is missing; Replace removes players one by one, `M.PSS_ClearGuildRules()` (shipped rules stay), removes custom filters. Unknown fields come back from `more` only where this version does not know them. 3.4.0.29 reads a format 2 string (it ignores `v` and `more`).

## (c) The window's view model

- **Tabs**: `M.PSS_UI_TABS` (ids 1 to 6); last tab saved as `windowPoints.PSS_WindowTab` (tab 1 not stored; Events never).
- **Back / forward**: `M.PSS_NavNew(max=50)`: `Record`, `Back`, `Forward`, `CanBack`, `CanForward`, `Current`, `Replace`, `BackToOther`.
- **List views**: Players / Guilds / Filters each have a `List` class (mixin `SortBy`, `SetFind`), a `Resort()` into a reused index, and dirty flags; guild rows recount lazily per drawn row (`gen` / `FreshCounts`).
- **Pane data** is built here and handed to the GUI as text, cells and specs (W2): `*PaneView`, `*Cells`, `*SummarySpec`, `PSS_HistCells`, `PSS_PickerCells`.
- **Lifetime**: nothing in Libraries is dropped on window close by itself; the GUI asks for `View:Release()` (Events lines), `List:CloseMembers()`, `M.PSS_GuildPickerClose`.

## (d) Dependency list: Libraries file -> core files

| Libraries file | Core files it calls |
| --- | --- |
| PSS_ImportExport | ChatBlock, PlayerIgnoreList, GuildIgnoreList, ChatFilters, Options, Upgrade, Perf, Events |
| PSS_PlayerRows | PlayerIgnoreList, Globals |
| PSS_Validate | reads every saved store; GuildIgnoreList (`PSS_GuildMemberCount`), ChatFilters (`PSS_FILTER_ARRAYS`), ChatHistory, Options, Upgrade (`PSS_UpgradeText`) |
| PSS_WhoisHarvest | Whois (`PSS_ScanBlockedMsg`, `PSS_WHO_CAP`), GuildIgnoreList (`PSS_ScanGuild`, `PSS_NormalizeGuild`), Options |
| PSS_Camelot | ChatBlock (name helpers), GuildIgnoreList (`PSS_MergeIntoShipped`, `PSS_MergeMember`, `PSS_MemberHasPlayerKey`), PlayerIgnoreList (index), ChatHistory (`RenameOwner`; loads Logging when needed) |
| PSS_GuildQuery | GuildIgnoreList, ChatFilters, ChatHistory, Globals (+ Lib WhoisHarvest) |
| PSS_FilterQuery | ChatFilters, ChatHistory |
| PSS_TotalsQuery | PlayerIgnoreList, GuildIgnoreList, ChatFilters, ChatHistory |
| PSS_EventsQuery | ChatHistory, GuildIgnoreList, PlayerIgnoreList (+ Lib PlayerRows) |
| PSS_DetailQuery | ChatHistory, Options, Globals (+ Lib TotalsQuery, EventsQuery) |
| PSS_ViewNav | Options |
| PSS_PlayerView | PlayerIgnoreList, PlayerQuery, ChatBlock, Whois, GuildIgnoreList, Globals (+ Lib PlayerRows) |
| PSS_GuildView | GuildIgnoreList, ChatFilters, Whois, PlayerQuery, ChatHistory, Globals (+ Lib WhoisHarvest, GuildQuery, EventsQuery) |
| PSS_FilterView | ChatFilters, GuildIgnoreList (`PSS_Say`), Globals |
| PSS_EventsView | ChatHistory, Globals |
| PSS_OptionsView | Options, Globals (+ Lib ImportExport) |
| PSS_RowMenus | PlayerIgnoreList, GuildIgnoreList, ChatFilters, Globals (+ Lib PlayerRows, DetailQuery, GuildView, PlayerView, FilterQuery) |
| PSS_Commands | PlayerIgnoreList, GuildIgnoreList, ChatBlock, Globals, Options, Perf, Events, BlizzardUI (+ Lib Validate, ImportExport; GUI `M.PSS_CopyTextBox`) |

## Exports with no caller outside their own file (harness callers aside)

`M.PSS_OverrideValue` (DetailQuery), `M.PSS_PeriodSince`, `M.PSS_GroupGuilds` (EventsQuery), `M.PSS_GuildGroupLabel`, `M.PSS_MemberHeading`, `M.PSS_MemberGuildLine`, `M.PSS_MemberAddedLine`, `M.PSS_MemberOtherGuild`, `M.PSS_MemberHistoryKey`, `M.PSS_GuildInfoLine`, `M.PSS_GuildOpts`, `M.PSS_GuildHistoryKey` (GuildView, read by its pane views), `M.PSS_PlayerTargetName` (PlayerView), `M.PSS_ImportCheck`, `M.PSS_ImportReplaceText`, `M.PSS_ImportApply` (OptionsView, through `PSS_ImportStart`), `M.prettyServer` (PlayerRows), `M.PSS_ScanLevelCap`, `M.PSS_ScanAllNextStale` (WhoisHarvest), `M.PSS_SlashPSS`, `M.PSS_SlashGuild` (core stubs, expected).

## Direct SavedVariables writes (not through a core setter)

| Where | Write |
| --- | --- |
| GuildQuery `PSS_GuildGroupOpen` / `PSS_SetGuildGroupOpen` | `guildGroupOpen` (UI state; the read also creates the table) |
| ViewNav `PSS_SetUIPlace` / `PSS_SetUITab` | `windowPoints` (UI state) |
| ImportExport `PSS_ApplyImport` | player prefs and `opts`; guild fields, `opts`, `block`, `members[mk]` |
| Camelot `PSS_RepairCamelotNames` | member, list and `delList` keys (step 10 only) |
