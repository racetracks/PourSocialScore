# PourSocialScore: code map (2026-10-09, release 3.4.1.53)

**What this is.** A context document that describes how PourSocialScore is built: what each folder and file does, its main functions, what the window (front end) calls in the logic (back end), and what depends on what. It is written to be loaded as context (for Claude through `CLAUDE.md`, or for GPT), so it stays technical and short. The full detail, export by export, is in the appendices `reference/code-map/A_CORE_ENGINE.md`, `B_CORE_LISTS.md`, `C_LIBRARIES.md` and `D_GUI.md`. What is still open is in `13_CHANGES_IN_TRAIN.md`.

Mapped by reading every Lua file at **3.4.1.53** (the release; its code is main 3.4.1.52, commit `2b2391f`), callers found by grep. Line counts are `wc -l`. When the code and this file differ, the code wins; refresh this map at each full release.

## 1. What the addon does

PourSocialScore (PSS) is a chat moderation addon for World of Warcraft, Retail (Interface 120007) and Camelot (16001). Author Dan (in game: Boaties).

| Feature | What the player gets | Main code |
| --- | --- | --- |
| Player Ignore List | Unlimited, account-wide list of players, NPCs and whole realms, with notes, expiry (applied by itself), and per-player W I G P C ticks (Whisper, Invite, Guild invite, Party/raid, Chat; ticked = allowed). Optional per-player "also on Blizzard's ignore list" tick | core `PSS_PlayerIgnoreList.lua`; rows in Libraries `PSS_PlayerRows.lua` |
| PSS is authoritative over Blizzard's ignore list | A Blizzard Ignore lists the player in PSS and moves them off Blizzard's list; the existing Blizzard list is synced in; removing from either removes from both | core `PSS_PlayerIgnoreList.lua` (B1) |
| Guild Ignore List | Guild rules ("contains" match), members captured from /who scans, unit scans and invites (only while something can use them), per-guild and per-member W I G P C, Scan All (key binding), Custom Scan, Guild Search, Guild Exclusion List, never blocks your own guild, at most 1500 plain members per rule | core `PSS_GuildIgnoreList.lua`, `PSS_Whois.lua`; planner Libraries `PSS_WhoisHarvest.lua` |
| Managed communities | Shipped guild lists ("Managed Communities - Asmongold", 119 guilds, 7438 entries), switched on by a Chat Filters guild rule, off by default | core `PSS_Communities.lua` (manifest), folder `PourSocialScore_Communities` (data) |
| Chat filters | Built-in filters (off by default) and custom rules (never-reused ids) in a tag language compiled to closures; a chat link converter | core `PSS_ChatFilters.lua` |
| Blocking and auto-decline | Lines from listed people, guild members and matching filters are hidden; invites, duels and trades from listed people are declined; per-person and per-guild exceptions | core `PSS_ChatBlock.lua`, `PSS_Options.lua` |
| Block history and counts | Counts per session, 24 h and all time; the block log (2000 lines by default) and kept lines per listed person; removing anyone never loads the log (purge marks) | core `PSS_ChatHistory.lua`, folder `PourSocialScore_Logging` |
| Right-click menu | A "PSS" header on unit and chat-name menus: Block / Unblock Player, Block / Unblock Guild | core `PSS_BlizzardUI.lua` (B2) |
| The PSS window | One window, six tabs (Players, Guilds, Filters, Events, Import/Export, Options), three looks (Modern default, Classic, Dark) | `PourSocialScore_GUI` (drawing), `PourSocialScore_Libraries` (logic) |
| Import / Export | One text string (format 2, unknown fields kept in `more`) with chosen sections; Merge or Replace; `/pss export unused` | Libraries `PSS_ImportExport.lua` |
| Slash commands | `/pss` (window and commands), `/pssguild` (diagnostics) | Libraries `PSS_Commands.lua` |
| Upgrades and forward compatibility | Run-once save upgrades (10 steps, feature-tagged, safe to run twice), one `RETIRED` list, the upgrade report at the first login after any version change, a downgrade line; every saved field in a schema map; rules this version cannot use kept and reported; `/pss check` | core `PSS_Upgrade.lua`, `PSS_Schema.lua`; check in Libraries `PSS_Validate.lua`; Camelot repair `PSS_Camelot.lua` |

## 2. Folders, loading and the dependency graph

| Folder | Loads | SavedVariables | Role | Size |
| --- | --- | --- | --- | --- |
| `PourSocialScore` (core) | Always (needs Options) | `PourSocialScoreDB` | Chat engine, lists, counting, setters, event bus, loader, schema map, upgrades, Blizzard hooks, window openers, core popups | 19 Lua files + `Bindings.xml`, 11,232 lines |
| `PourSocialScore_Options` | Always, before core | `PSS_OptionsDB`, `PSS_PlayersDB`, `PSS_GuildsDB`, `PSS_RulesDB`, `PSS_CountsDB` | Data only (no code) | 1 file (comment) |
| `PourSocialScore_Libraries` | On demand: the first command, window open, or a core stub's first call | none | Slash commands, Import/Export, every query and view model behind the window, and rarely used core work (player rows, the save check, the scan planner, the Camelot repair) | 18 files, 5,825 lines |
| `PourSocialScore_GUI` | On demand: window open (loads Libraries first) | none | Drawing only: kit, skin, tabs, popups, menus | 15 files, 5,731 lines |
| `PourSocialScore_Logging` | On demand: only when the log is read, the outbox fills, or the purge list is full | `PSS_LoggingDB` | The block log and kept lines; packing for save | 2 files |
| `PourSocialScore_Communities` | On demand: when a managed rule is on, or a shipped member is looked up | none | Packed shipped guild lists (334,806 bytes) | 1 generated file |

Each folder has three TOCs (base, `_Mainline`, `_Camelot`), one version for all, `## Category: PSS`, `## Group: PourSocialScore`.

```
                 PourSocialScore_Options (data only, always)
                              ^
                              | Dependencies
                    PourSocialScore (core, always)
           M.PSS_Need / M.PSS_Stub (PSS_Loader.lua)
      +------------------+-------------+-----------------+
      v                  v             v                 v
 Libraries (LOD)    Logging (LOD)  Communities (LOD)   [GUI needs Libraries]
      ^                                                  |
      +-------------------- GUI (LOD) -------------------+
         calls M.* in Libraries and core setters; never the reverse
         (one exception: /pss export unused calls GUI M.PSS_CopyTextBox)
```

Rules the graph follows: core never calls the GUI (it fires `M.Events`); the GUI holds no logic or state (`tools/check_layers.lua`); Libraries reads core data and writes through core setters (the direct writes are in section 10); nothing unloads once loaded.

**Shared handles.** The addon table is the one global, `PourSocialScore_NS`. On it: `M` (every shared function), `V` (runtime state), `L` (strings, missing key returns "BAD TEXT"), `M.Events` (the bus), `M.PSS_History` (= `History`), `MANAGED` / `MANAGED_DATA` (shipped lists). The GUI keeps its own private table `ns`. Every file that uses `M` declares `local M` (`tools/check_locals.lua`).

**Loader** (`PSS_Loader.lua`): `M.PSS_PARTS` (GUI, Libraries, Logging, Communities), `NEEDS = {GUI = "Libraries"}`, `M.PSS_Need(key)` loads a part and its needs and warns once on a failed load or a version that differs from core; `M.PSS_Stub(fname, key)` puts a stand-in at `M[fname]` that loads the part on first call. Core stubs: `PSS_SlashPSS`, `PSS_SlashGuild`, `PSS_Validate`, `PSS_PrintValidation`, the six player row calls, `PSS_HarvestNext/Sent/Answered`, `PSS_CapWhoFilter`, `PSS_ScanAll`. `M.PSS_LoadLogging()` loads Logging, applies the purge marks and moves the outbox into the log.

## 3. Core folder, file by file (TOC order)

| File | Lines | Does | Key exports |
| --- | --- | --- | --- |
| `PSS_Localization.lua` | 412 | `L` table, English (169 keys) plus locale blocks | `L[...]` |
| `PSS_Globals.lua` | 262 | Creates `M` and `V`; string and name helpers, dates, message output, the W I G P C table | `M.ShowMsg`, `M.ChatMsg`, `M.Trim`, `M.Proper`, `M.addServer`, `M.removeServer`, `M.PSS_SplitNameArg`, `M.daysFromToday`, `M.MONTHS`, `M.EXCL`, `M.PSS_BLOCK_FIELDS` |
| `PSS_Loader.lua` | 67 | Loads on-demand parts | `M.PSS_Need`, `M.PSS_Stub`, `M.PSS_PARTS` |
| `PSS_SavedData.lua` | 256 | Router metatable on `PourSocialScoreDB` (section 7); moves keys from old layouts; stubs for the save check | `M.PSS_PrepareSavedData`, `M.PSS_SavedDataSplit` |
| `PSS_Schema.lua` | 67 | Data only (U3): every saved field per record kind, current and old; `tools/check_schema.lua` checks code and saves against it | `M.PSS_SCHEMA` |
| `PSS_Perf.lua` | 277 | Stepped garbage collection on request only, out of combat and instances, waiting on events (P2; no timer), `/pss mem` | `M.PSS_RequestGC(reason)`, `M.PSS_GCWatch`, `M.PSS_MemReport`, `M.PSS_GCState` |
| `PSS_Events.lua` | 71 | The core event bus; listener errors shown once (N46) | `M.Events.Register / Unregister / Fire`, `M.PSS_NoteListenerError` |
| `PSS_Whois.lua` | 339 | The one /who service: send (from a click or key), cooldown, answers from the Who list or chat lines (events only while needed, P3); planner stubs and the key binding | `M.Whois` (`Request`, `Listen`, `SetCapture`), `M.PSS_WHO_CAP`, `PSS_ScanAllBinding` |
| `PSS_Communities.lua` | 134 | Generated manifest of the shipped lists | `addon.MANAGED.groups` |
| `PSS_ChatHistory.lua` | 1325 | `History`: entries, the capped shared log, kept lines, the outbox, recent counts, owner keys, purge by owner, rename owner, sparse counts, tidy and migrations | `History.Add`, `History.ClearOwner`, `History.ApplyPurge`, `History.RenameOwner`, `History.CountTotal`, `History.CompactCounts`, `History.LoadWhenQuiet`, `History.CountRecent`, `M.PSS_LoadLogging` |
| `PSS_ChatBlock.lua` | 892 | **The chat engine**: one message filter for every chat event, decision cache, block sources and handlers, name normalisation, invites, duels, trades, warnings, chat purge | `M.PSS_IsSecret`, `M.PSS_RegisterBlockSource`, `M.PSS_NormName`, `M.PSS_CanonPlayer`, `M.PSS_NormalizePlayer`, `M.PSS_UnitFullName`, `M.PSS_FixUnitName`, `M.PSS_PurgeChatFrom`, `M.PSS_CoreFilter`, `M.PSS_ExplainPerson` |
| `PSS_ChatFilters.lua` | 1055 | Text filters: built-ins, custom rules with ids, expand/collapse, the tag compiler, the "text" handler, managed-group rules | `M.PSS_ChatFilters_Evaluate`, `M.filterComplex`, `M.PSS_CompileFilter`, `M.PSS_NewFilterId`, `M.PSS_AssignCustomFilterIds`, `M.PSS_SaveChatFilter`, `M.PSS_SetFilterActive`, `M.ResetSpamFilters`, `M.PSS_SetManagedGroupActive`, `M.PSS_FilterOwnerKey` |
| `PSS_PlayerIgnoreList.lua` | 1656 | Player Ignore List: the `list` records and their accessors, add, remove, expiry, prune, the lookup index, Blizzard ignore hooks and sync (B1), sparse player records, the "player" source plus NPC, realm and system handlers | `M.PSS_List`, `M.PSS_EntryName`, `M.PSS_NewEntry`, `M.PSS_AddIgnore`, `M.PSS_AddPlayer`, `M.PSS_DelIgnore`, `M.PSS_ExpireEntries`, `M.PSS_SetPlayerSetting`, `M.PSS_SetBlizzardIgnore`, `M.PSS_CompactPlayers`, `M.SyncIgnoreList`, `M.PSS_RecordPlayerBlock` |
| `PSS_PlayerQuery.lua` | 30 | The two list calls core makes, and stubs for the rows | `M.PSS_IsGuildListed`, `M.PSS_PlayersChanged` |
| `PSS_GuildIgnoreList.lua` | 2786 | Guild rules and members: the member field accessors, sparse members, the cap, W I G P C, counts and history, shipped lists and their delta, member index, capture on demand, /who capture, Guild Search, Exclusion List, own-guild check, the "guild" source, legacy upgrades | `M.PSS_MemberName`, `M.PSS_MemberGuildName`, `M.PSS_MemberCanon`, `M.PSS_MemberShipped`, `M.PSS_AddGuild`, `M.PSS_RemoveGuildNow`, `M.PSS_ClearGuildRules`, `M.PSS_SetGuildBlock`, `M.PSS_ScanGuild`, `M.PSS_LookupGuildMember`, `M.PSS_GuildMemberCount`, `M.PSS_CapAllMembers`, `M.PSS_ApplyCapture`, `M.PSS_FlushManaged` |
| `PSS_Upgrade.lua` | 768 | Upgrade steps 1 to 10 (registry), `RETIRED`, the report, version order, schema lookups, unusable rules | `M.PSS_RunUpgradeFields`, `M.PSS_RunUpgradeData`, `M.PSS_VersionOrder`, `M.PSS_SchemaKnows`, `M.PSS_UnusableRules` |
| `PourSocialScore.lua` | 317 | Startup, legacy import, group warning, logout work, history tidy, slash stubs | `M.PSS_TidyBlockHistory`, `SLASH_PSS1`, `SLASH_PSSGUILD1` |
| `PSS_Options.lua` | 166 | The one option table (30 keys) and its resolution: person > guild > global > default; only non-defaults saved | `M.PSS_OPTIONS`, `M.PSS_Opt`, `M.PSS_SetOpt`, `M.PSS_CharKey` |
| `PSS_BlizzardUI.lua` | 352 | Core touch points with Blizzard UI: openers, docking, core StaticPopups (`PSS_REASON`, `PSS_PARTYWARN`), Group Finder, unit right-click menu (hook bodies gated by their options, N41), Addon Compartment | `M.PSS_OpenUI` (-> GUI `M.PSS_OpenWindow`), `M.PSS_HookFunctions`, `M.PSS_UnitMenuPlayer` |
| `Bindings.xml` | 5 | Key binding `PSS_SCAN_ALL` | |

## 4. Libraries folder (the window's back end, the commands, rarely used core work)

TOC order matters: `PSS_ViewNav` before the `*View` files, `PSS_GuildView` before `PSS_RowMenus`.

| File | Lines | Kind | Does | Core files it calls |
| --- | --- | --- | --- | --- |
| `PSS_ImportExport.lua` | 528 | Action | `PSS1:<checksum>:<base64>` string (format 2, `more`), Merge / Replace, `/pss export unused` text | ChatBlock, PlayerIgnoreList, GuildIgnoreList, ChatFilters, Options, Upgrade, Perf |
| `PSS_PlayerRows.lua` | 405 | Query | (P6, from core) player rows, sort, removal, realm display names | PlayerIgnoreList, Globals |
| `PSS_Validate.lua` | 215 | Query | (P6, from core) `/pss check` and the before/after count of a key move | every store, GuildIgnoreList, ChatHistory |
| `PSS_WhoisHarvest.lua` | 282 | Planner | (P6, from core) the guild sweep and Scan All | Whois, GuildIgnoreList, Options |
| `PSS_Camelot.lua` | 160 | Action | (S3) the Camelot name repair of upgrade step 10 | ChatBlock, GuildIgnoreList, PlayerIgnoreList, ChatHistory |
| `PSS_GuildQuery.lua` | 350 | Query | Grouped guild rows (member counts worked out, not saved), a rule's members, group open state, Add Guild from a member | GuildIgnoreList, ChatFilters, ChatHistory |
| `PSS_FilterQuery.lua` | 145 | Query | Filter rows, counts, sort, history, test, chat link converter | ChatFilters, ChatHistory |
| `PSS_TotalsQuery.lua` | 118 | Query | Whole-list totals (`M.PSS_ListTotals`), per-type recent counts (adds `History.RecentByCat`) | PlayerIgnoreList, GuildIgnoreList, ChatFilters, ChatHistory |
| `PSS_EventsQuery.lua` | 268 | Query | Line types, "expired / not stored" rows, query matching, managed group reads and resets | ChatHistory, GuildIgnoreList, PlayerIgnoreList |
| `PSS_DetailQuery.lua` | 354 | Query | Pie and pane maths and text; exceptions; pane history cells and tips | ChatHistory, Options |
| `PSS_ViewNav.lua` | 299 | View | Window state (look, place, last tab, font, accent), back / forward, list mixin, picker cells | Options |
| `PSS_PlayerView.lua` | 360 | View | Players tab: list object, texts, summary spec, edits, search picker, prune, Events specs | PlayerIgnoreList, ChatBlock, Whois, GuildIgnoreList |
| `PSS_GuildView.lua` | 837 | View | Guilds tab: list object, cells, tips, pane views, summary specs, add / exclude / search, members view, edits, Events specs | GuildIgnoreList, ChatFilters, Whois, ChatHistory |
| `PSS_FilterView.lua` | 180 | View | Filters tab list object, texts, summary spec, edits, Events specs | ChatFilters, GuildIgnoreList |
| `PSS_EventsView.lua` | 437 | View | Events tab query model: period, types, source, range, sort, nav keys, reset | ChatHistory, Globals |
| `PSS_OptionsView.lua` | 206 | View | Options rows, labels, tips, search; Import/Export ticks, mode, export text and the import flow (`M.PSS_ImportStart`) | Options, Globals |
| `PSS_RowMenus.lua` | 207 | View | Right-click menus as data (`{text, act, arg}`) | PlayerIgnoreList, GuildIgnoreList, ChatFilters |
| `PSS_Commands.lua` | 474 | Command | `/pss` and `/pssguild` parsers (section 9) | most core files |

Libraries listens to two events (`PSS_WhoisHarvest.lua`: `GUILDS_CHANGED`, `GUILD_REMOVED`) and fires only through core setters (and `PSS_ApplyImport` fires `PLAYERS_CHANGED`, `GUILDS_CHANGED`, `FILTERS_CHANGED`).

## 5. GUI folder (the front end)

| File | Lines | Does |
| --- | --- | --- |
| `PSS_Skin.lua` | 347 | Looks (`uiSkin`), fonts (`uiFont`), painters (`ns.OnPaint`), pixel-exact primitives, frame art, the Modern art check (19 atlases), Escape helper, core listener registry (`ns.Listen`) |
| `PSS_Kit.lua` | 536 | The control kit: `ns.NewButton` (primary), `ns.NewCheck`, `ns.NewEditBox` (hint), `ns.NewNumberBox`, `ns.NewSearchBox`, `ns.NewPanel`, `ns.NewScrollFrame`, `ns.NewTextArea`, `ns.NewTab`, `ns.NewHeading`, `ns.OnCommit` |
| `PSS_Tooltip.lua` | 96 | `ns.Tip` (text or a function), `ns.TipOn`, `ns.HideTip` |
| `PSS_Menu.lua` | 374 | `ns.NewDropdown`, `ns.ContextMenu`, `ns.RowMenu` (Blizzard Menu API in Modern and Classic, our list in Dark; caps 200 and 400 px) |
| `PSS_Popups.lua` | 254 | `ns.Confirm`, `ns.CopyText`, `ns.ImportText`, `M.PSS_CopyTextBox` |
| `PSS_Rows.lua` | 384 | `ns.NewRows` (virtual sortable rows), `ns.NewPicker` (/who results picker) |
| `PSS_Pie.lua` | 140 | `ns.NewPie`: ring chart; OnUpdate only while hovered (approved override) |
| `PSS_Detail.lua` | 482 | Pane parts: `ns.NewDetailPages`, `ns.NewSummary`, `ns.NewTotals`, `ns.NewTypePie`, `ns.NewExceptions`, `ns.NewLine`, `ns.NewLabel`, `ns.NewStrip`, `ns.NewAllowedBoxes` |
| `PSS_History.lua` | 190 | `ns.NewHistory` (block history list in a pane), `ns.SenderMenu` |
| `PSS_Players.lua` | 497 | Players tab |
| `PSS_Guilds.lua` | 928 | Guilds tab (grouped list, members view, pane with four bodies, wrapped lines fitted, Guild Search picker) |
| `PSS_Filters.lua` | 456 | Chat Filters tab and the link-insert post-hook |
| `PSS_Events.lua` | 274 | Events tab |
| `PSS_Options.lua` | 236 | Options tab and Import/Export tab |
| `PSS_Window.lua` | 537 | `PSS_Window` (960 x 494), frame art, tab row, lazy tab building, back / forward, Escape stepping, open / close lifecycle, docking |

Tabs are built by `ns.TabBuilders[key](page)` on first open. Each tab file creates its Libraries list object at load, builds no frames until opened, and queues its listeners with `ns.Listen`. A blocked line redraws only the rows on screen and the counts part of the pane (W4).

## 6. Front end to back end (what each tab calls)

Shape: element -> Libraries function -> core setter or data. Full tables in `reference/code-map/D_GUI.md` section (a).

| Tab | Element or action | Libraries | Core |
| --- | --- | --- | --- |
| Players | List, sort, search | `PSS_PlayerListNew:Resort`, `PSS_PlayerRow`, `PSS_SortPlayers` (PlayerRows), cell texts | `M.PSS_List()` records, `playerData` |
| | Add Player / Player Search | `PSS_PlayerAddFromText`, `PSS_PlayerSearchFromText`, `PSS_PlayerPicker*`, `PSS_PickerCells` | `PSS_AddPlayer`, `PSS_PlayerSearch` (SendWho) |
| | Note, expiry, W I G P C, Blizzard tick | `PSS_PlayerCommitNote/Expiry`, `PSS_PlayerToggleAllowed`, `PSS_PlayerToggleBlizzard` | `PSS_SetNote`, `PSS_SetExpiry`, `PSS_SetPlayerSetting`, `PSS_SetBlizzardIgnore` |
| | Prune, Remove, Reset history | `PSS_PruneApply`, `PSS_PlayerRemoveText`, `PSS_RemovePlayerAt` (PlayerRows) | `PruneIgnoreList`, `PSS_DelIgnore`, `PSS_ResetPlayerBlockHistory` (straight from the GUI) |
| | Exceptions ticks | `PSS_ExceptionState`, `PSS_SetException` | `PSS_SetOpt(key, "person", v, target)` |
| Guilds | Grouped list, open a heading | `PSS_GuildListNew:Resort` -> `PSS_GuildRows`, `PSS_SetGuildGroupOpen` | rules, `PSS_GuildMemberCount`, `PSS_ManagedGroupActive` |
| | Pane | `PSS_GuildPaneView`, `PSS_MemberPaneView`, `PSS_MemberCells`, `*SummarySpec` | member accessors, counters |
| | Add / Exclude / Guild Search | `PSS_GuildAddFromText`, `PSS_GuildExcludeFromText`, `PSS_GuildSearchFromText`, `PSS_GuildPicker*` | `PSS_AddGuild`, `PSS_AddGuildExclusion`, `PSS_GuildSearch`, `PSS_SaveGuildSearch` |
| | Scan All, Scan, Custom Scan, Scan Fields | `PSS_ScanAll` (WhoisHarvest), `PSS_GuildScanNow`, `PSS_GuildCustomScan`, `PSS_GuildCommitFields` | `PSS_ScanGuild`, `PSS_SetGuildScanFields` |
| | Guild and member W I G P C, exceptions, note, remove | `PSS_GuildToggleAllowed`, `PSS_MemberToggleAllowed`, `PSS_GuildToggleException`, `PSS_MemberToggleException`, `PSS_MemberCommitNote`, `V:RemoveMember`, `PSS_GuildRemove` | `PSS_SetGuildBlock`, `PSS_SetMemberBlock`, `PSS_SetOpt`, `PSS_SetMemberNote`, `PSS_RemoveGuildMember`, `PSS_RemoveGuildNow` |
| | Managed Communities rule on / off | `PSS_GroupToggleRule`, `PSS_GuildSetAllRules` | `PSS_SetManagedGroupActive` |
| Filters | List, on tick | `PSS_FilterListNew:Resort`, `PSS_FilterRow` | `PSS_SetFilterActive` (straight from the GUI) |
| | Save, Copy, New, Remove | `PSS_FilterSave`, `PSS_FilterCopy`, `PSS_FilterNew`, `PSS_FilterRemove` | `PSS_SaveChatFilter` (keeps its id), `PSS_CopyChatFilter` / `PSS_AddCustomFilter` (new id), `RemoveChatFilter` |
| | Test, link converter | `PSS_FilterTestText`, `PSS_ConvertChatLink` | `PSS_IsSecret` on inserted links |
| | Reset count, history, defaults | none | `PSS_ResetFilterCount`, `PSS_ResetFilterHistory`, `M.ResetSpamFilters` (straight from the GUI) |
| Events | Open from a pie, a pane or View Events | `view:Open(spec)` (specs from the three `*View` files) | none until read |
| | Read, filter, sort | `view:Refresh` (a spec's `read` loads Logging), `view:Apply`, `PSS_EventCells` | `History`, `PSS_LoggingDB` |
| | Reset Block History | `view:DoReset` -> spec `reset` | the matching core reset |
| Options | Ticks, numbers, choices | `PSS_OptGroups`, `PSS_OptSetNumber`, `PSS_OptChoiceText` | `PSS_SetOpt(key, "global", v)` -> `OPTION_CHANGED` |
| Import/Export | Export, Import | `PSS_ExportText`, `PSS_ImportStart` -> `PSS_ApplyImport` | setters plus direct writes (section 10) |

Panes: Summary pies and counts come from DetailQuery and TotalsQuery over the core counters (`PSS_GetPlayerBlockCounts`, `PSS_GetGuildBlockCounts`, `PSS_FilterCounts`, `History.RecentByCat`, totals through `History.CountTotal`). History lists read the log, which loads Logging only when the player clicks for it.

**Open and close.** `/pss` -> `M.PSS_SlashPSS` (Libraries) -> `M.PSS_OpenUI` (core: expiry, then `M.PSS_Need("GUI")`) -> `M.PSS_OpenWindow`. The first open builds the window and only the last tab. OnShow registers the queued listeners and refreshes stale pages; OnHide unregisters them, releases the Events tab's lines and calls `M.PSS_RequestGC("window closed")`. `OPTION_CHANGED` stays registered after the first build so a look change repaints. Escape: popups and our menu are in `UISpecialFrames`; the window uses a helper frame `PSS_WindowEscape` that closes the top popup, then steps up one level, then hides the window.

## 7. Saved data (as saved at 3.4.1.53: sparse)

`PourSocialScoreDB` is the name the code uses; a router metatable (`PSS_SavedData.lua`) sends each listed key to its owner table while that addon is loaded. Every saved field is listed in `M.PSS_SCHEMA` (`PSS_Schema.lua`); only `RETIRED` keys are ever deleted; unknown fields are kept.

| Table (folder) | Holds | Owner code |
| --- | --- | --- |
| `PourSocialScoreDB` (core), raw keys | `upgrade {step, version, at}`, `outbox`, `purge {[owner] = true}` (only while marks wait, cap 200), `recent {v=2, last, day, [1..144]}`, `session`, `sessionStart`, import and revision markers | Upgrade, ChatHistory, PourSocialScore.lua |
| `PSS_OptionsDB` (Options) | Non-default options, `windowPoints` (window place, last tab) | PSS_Options, Libraries ViewNav |
| `PSS_PlayersDB` (Options) | `list`: one record per entry `{name, date, [kind] [faction] [note] [exp] [sync]}` (S2b, step 9); `delList`; `playerData[key]` records (W I G P C `*Blocked` saved only when false, compacted `blockCounts`, `opts`, `blizzardIgnore`) | PlayerIgnoreList |
| `PSS_GuildsDB` (Options) | `guildData[key]` rules (`block`, `opts`, `members[key]`, `managed`, `managedGone`, scan fields; no `memberCount`); members sparse (`name`, `guild`, date only when not derivable; no runtime `_` fields but `_playerKey` when it differs; at most 1500 plain members per rule); `guildExclusions`, `guildGroupOpen` | GuildIgnoreList |
| `PSS_RulesDB` (Options) | `filterList`, `filterDesc`, `filterActive`, `filterID` (custom rules: number ids), `builtinRules {id = on}`, `nextFilterId` | ChatFilters |
| `PSS_CountsDB` (Options) | `hiddenTotal`, `filterTotal`, `filterCount`, `filterBlocked` (compacted counts), `builtinStats`, whisper and private totals | ChatFilters, ChatBlock |
| `PSS_LoggingDB` (Logging) | `blockLog` (packed v2 groups; `m` only when not derivable), `blockKeep` | ChatHistory, Logging `PSS_SavedLog.lua` |

Identity is the lowercase `name-realm` key; the canon form drops apostrophes and collapses spaces. History owners: `p:<canon>` (player), `g:<canon>` (guild member), `G:<gkey>` (guild recent counts), `f:<id>` (filter; `f:t:<text>` only for a filter an older version saved without an id). Shipped members are saved only as a delta (`PSS_FlushManaged` at logout). Counts drop zero fields and a total equal to the sum (`History.CompactCounts`); every read goes through `History.EnsureCounts` / `History.CountTotal`. Member fields are read only through the accessors (`tools/check_fields.lua`).

## 8. Runtime flows

**Chat line** (`PSS_ChatBlock.lua`, `CoreFilter`, about 30 us per line):
1. The message filter is registered for 41 chat events. A secret author or GUID: pass, not counted. A secret message still reaches person rules (decision 1).
2. Decision cache per `lineID`, so the other chat windows reuse it.
3. `evaluate`: system handlers, NPC handlers, then **people** (player source by W I G P C, a missing switch blocks; guild source only while its rule is on and usable, not excluded, not your guild), then **realm** handlers, then **text** filters (`M.PSS_ChatFilters_Evaluate`).
4. A block: `History.Add(owner, counts, entry)` bumps the owner's counts and the recent counts, then queues the line in the outbox (Logging unloaded) or the log; fires `PLAYER_BLOCKED`, `GUILD_BLOCKS_CHANGED` (throttled) or `FILTER_HISTORY_CHANGED`; a whisper may get the ignore response.
5. Invites, duels and trades ask the same sources (`decide`) and decline through the API.

**Startup:** `ADDON_LOADED` and `PLAYER_ENTERING_WORLD` both seen -> `ApplicationStartup`: prepare saved data, create missing tables, option defaults, upgrade fields, expand filters, load the shipped data when a managed rule is on, `V.PSS_Loaded = true`, upgrade data steps (and the report), expiry, capture events if needed (`M.PSS_ApplyCapture`), Logging if the upgrade loaded it, `M.PSS_HookFunctions`. **Logout:** collapse filters (counts compacted), compact player records, flush the shipped delta (members sparse, cap), end the session counts, pack the log when Logging is loaded.

**Upgrade:** `M.PSS_RunUpgradeFields` (every due `fields` part), then later `M.PSS_RunUpgradeData` (every `data` part, the `RETIRED` loop, the record, the report). Step 9 zips the old player arrays into `list`; step 10 ("SavedVariables performance cleanup") repairs Camelot names (Libraries, Camelot saves only), caps members, saves records sparse, compacts player switches and gives custom filters ids. A save newer than the code prints one line and runs nothing backwards.

**Guild scan:** a click or key -> `PSS_ScanGuild` -> `PSS_HarvestNext` (Libraries) -> `Whois.Request` (SendWho) -> answers through `WHO_LIST_UPDATE` or chat lines -> `captureWho` -> member records -> split when capped -> `GUILD_SCAN_DONE`.

**Blizzard ignore (B1):** post-hooks on `C_FriendList` add / remove calls; a new Blizzard ignore lists the player with the note "Synced from Blizzard ignore list on <date>" and is moved off Blizzard's list on the next `IGNORELIST_UPDATE` unless ticked; the first update after login syncs Blizzard's list into PSS (ticked, nobody removed).

**Garbage collection:** only on request (login, /who results, import, window close); runs at once when out of combat and not in an instance, else waits for `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ALIVE` or `PLAYER_UNGHOST`, registered only while waiting.

## 9. Events and commands

**`M.Events` bus**

| Event | Fired by | Heard by |
| --- | --- | --- |
| `OPTION_CHANGED` (key) | `M.PSS_SetOpt` | GUI Options, GUI Window (permanent after build), core BlizzardUI (hooks on the first enable) |
| `PLAYERS_CHANGED` (resort) | PlayerIgnoreList, PlayerQuery, GuildIgnoreList (remove), ImportExport | GUI Players, Events; core GuildIgnoreList (capture) |
| `PLAYER_BLOCKED` | `M.PSS_RecordPlayerBlock` | GUI Players, Events (throttled 0.25 s) |
| `ASK_NOTE` (name) | PlayerIgnoreList add | core BlizzardUI (`PSS_REASON` popup) |
| `GUILDS_CHANGED` | GuildIgnoreList, ImportExport | GUI Guilds, Events; core GuildIgnoreList (capture); Libraries WhoisHarvest |
| `GUILD_BLOCKS_CHANGED` | GuildIgnoreList (at most every 0.25 s) | GUI Guilds, Events |
| `GUILD_REMOVED` (key) | `M.PSS_RemoveGuild` | GUI Guilds; Libraries WhoisHarvest |
| `GUILD_SCAN_DONE` | GuildIgnoreList scan finish | GUI Guilds |
| `GUILD_SEARCH_RESULTS` | `M.PSS_GuildSearch` | GUI Guilds |
| `WHOIS_COOLDOWN` (active) | PSS_Whois | GUI Players, Guilds |
| `WHOIS_ANSWERED` | PSS_Whois | nobody |
| `FILTERS_CHANGED` | ChatFilters edits and toggles (no longer per blocked line, G21), ImportExport | GUI Filters, Guilds (G26); core GuildIgnoreList (capture) |
| `FILTER_HISTORY_CHANGED` (i) | ChatFilters (each filter block, history reset) | GUI Filters, Events |
| `WHISPER_WARNING`, `GROUP_WARNING` | ChatBlock, PourSocialScore.lua | core BlizzardUI |

**Slash commands** (`PSS_Commands.lua`): `/pss` (also `gui`, `ui`, `eui`) opens or closes the window; `add`/`ignore`, `remove`/`delete`, `server`/`addserver`, `npc`/`addnpc`, `expire`, `list`, `prune`, `sync`, `clear` (+ `confirm`), `defexpire`, `asknote`, `showmsg`, `sameserver`, `mem`/`memory`, `check`, `export unused`, `dellist`; anything else prints help (`/pss test` is gone). `/pssguild` (status, with listener errors), `debug [all]`, `test <name>` (dry run across every list), `chat`, `check <name>`.

**Blizzard touch points** (PSS 02 section 10.3): `ChatFrameUtil.AddMessageEventFilter`; post-hooks on `C_FriendList`; `Menu.ModifyMenu` for unit menus (option `useUnitHacks`) and the LFG list (`useLFGHacks`), bodies gated by their options; `HookScript` on `FriendsFrame` / `SocialUIFrame`; `hooksecurefunc(ChatFrameUtil, "InsertLink")` (Filters tab); `PSS_` StaticPopups; `UISpecialFrames`; decline APIs (`DeclineGroup`, `DeclineGuild` / `C_GuildInfo.DeclineGuild`, `CancelDuel`); `RemoveMessagesByPredicate` for the chat purge; `C_FriendList.SendWho` only from a click or key.

## 10. Code review notes (state at 3.4.1.53)

The core uplift's findings are done or recorded as left in `13_CHANGES_IN_TRAIN.md`. The notes that matter when reading the code:
- **Direct save writes outside core setters:** `PSS_ApplyImport` writes records directly; `guildGroupOpen` and `windowPoints` are UI state written from Libraries; `PSS_RepairCamelotNames` re-keys records in step 10. The `memberCount` write on every guild redraw is gone.
- **Setters that fire no event:** `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_SetGuildScanFields` (the Guilds tab redraws itself).
- **GUI calls some core setters directly** (the reset functions, `PSS_SetFilterActive`, `PSS_ResetFilterCount`, `M.ResetSpamFilters`, `PSS_SetOpt`): allowed, uneven.
- **Only the Events tab drops what it read on close**; the other tabs keep list state and their History panes' last lines for the session.
- **Left from the plan:** `M.debugMsg` is a no-op with 16 call sites (N7); `/pss mem` stays in core (P6 skipped it); `M.PSS_AddCapturedGuild`, `M.PSS_ReconcileGuildMembers`, `M.SyncIgnoreList`, `M.PSS_ExplainPerson` and `History.MigrateFilterList` stay in core (P6, reasons in `reference/combined-3.4.1.52/`).
- **Older versions on a 3.4.1.52+ save:** 3.4.0.29 drops custom filters with number ids, and 3.4.1.50 and older show an empty Player Ignore List (the data stays in the save).

## 11. Where to look (task -> file)

| Task | Start in |
| --- | --- |
| A line is or is not blocked | core `PSS_ChatBlock.lua` (`evaluate`, sources), `/pssguild test <name>` |
| Player list behaviour, Blizzard ignore, expiry | core `PSS_PlayerIgnoreList.lua` (the `-- (list entries)` block for the records) |
| Guild rules, members, scans | core `PSS_GuildIgnoreList.lua` (the `-- (member fields)` block for any member field), `PSS_Whois.lua`; Libraries `PSS_WhoisHarvest.lua` |
| Filter language, built-ins, filter ids | core `PSS_ChatFilters.lua` |
| Counts, history, outbox, purge, log | core `PSS_ChatHistory.lua`, Logging `PSS_SavedLog.lua` |
| A saved key, routing, upgrades, the report | core `PSS_SavedData.lua`, `PSS_Upgrade.lua`; a new saved field also goes in `PSS_Schema.lua` (U3) |
| An option | core `PSS_Options.lua`; drawn by GUI `PSS_Options.lua` via Libraries `PSS_OptionsView.lua` |
| Names (Camelot surnames) | core `PSS_ChatBlock.lua` (`M.PSS_NormName`), `PSS_Globals.lua` (`M.PSS_SplitNameArg`); saved names: Libraries `PSS_Camelot.lua` |
| Right-click menu, popups, docking | core `PSS_BlizzardUI.lua` |
| Garbage collection, `/pss mem` | core `PSS_Perf.lua` |
| What a tab shows | GUI tab file, then its Libraries `*View` / `*Query` file (section 6) |
| How a control looks in each look | GUI `PSS_Skin.lua`, `PSS_Kit.lua`; preview `tools/harness/kit_page.lua` |
| A slash command | Libraries `PSS_Commands.lua` |
| Import / Export, `/pss export unused` | Libraries `PSS_ImportExport.lua` |
| `/pss check` | Libraries `PSS_Validate.lua` |
| Shipped lists | `tools/PSS_BuildManaged.lua`, core `PSS_Communities.lua`, `PourSocialScore_Communities/` |
| Checks and harness | `tools/check_rules.sh` (with `check_layers.lua`, `check_fields.lua`, `check_locals.lua`, `check_schema.lua`), `tools/harness/validate_all.sh`, `tui_compare.sh`, `same_saves.sh`, `sparse_saves.sh` (docs `07_HARNESS.md`) |
