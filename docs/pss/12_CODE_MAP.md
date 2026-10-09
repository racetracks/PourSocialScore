# PourSocialScore: code map (2026-10-08, main 3.4.1.38)

**What this is.** A context document that describes how PourSocialScore is built: what each folder and file does, its main functions, what the window (front end) calls in the logic (back end), and what depends on what. It is written to be loaded as context (for Claude through `CLAUDE.md`, or for GPT), so it stays technical and short. The full detail, export by export, is in the appendices `reference/code-map/A_CORE_ENGINE.md`, `B_CORE_LISTS.md`, `C_LIBRARIES.md` and `D_GUI.md`. What is about to change is in `13_CHANGES_IN_TRAIN.md`.

Mapped by reading every Lua file on main at **3.4.1.38** (commit `bd32c68`), callers found by grep. Line counts are `wc -l`. When the code and this file differ, the code wins; refresh this map at each full release.

## 1. What the addon does

PourSocialScore (PSS) is a chat moderation addon for World of Warcraft, Retail (Interface 120007) and Camelot (16001). Author Dan (in game: Boaties).

| Feature | What the player gets | Main code |
| --- | --- | --- |
| Player Ignore List | Unlimited, account-wide list of players, NPCs and whole realms, with notes, expiry, and per-player W I G P C ticks (Whisper, Invite, Guild invite, Party/raid, Chat; ticked = allowed). Optional per-player "also on Blizzard's ignore list" tick | core `PSS_PlayerIgnoreList.lua`, `PSS_PlayerQuery.lua` |
| PSS is authoritative over Blizzard's ignore list | A Blizzard Ignore lists the player in PSS and moves them off Blizzard's list; the existing Blizzard list is synced in; removing from either removes from both | core `PSS_PlayerIgnoreList.lua` (B1) |
| Guild Ignore List | Guild rules ("contains" match), members captured from /who scans, unit scans and invites, per-guild and per-member W I G P C, Scan All (key binding), Custom Scan, Guild Search, Guild Exclusion List, never blocks your own guild | core `PSS_GuildIgnoreList.lua`, `PSS_Whois.lua`, `PSS_WhoisHarvest.lua` |
| Managed communities | Shipped guild lists ("Managed Communities - Asmongold", 119 guilds, 7438 entries), switched on by a Chat Filters guild rule, off by default | core `PSS_Communities.lua` (manifest), folder `PourSocialScore_Communities` (data) |
| Chat filters | Built-in filters (off by default) and custom rules in a tag language compiled to closures; a chat link converter | core `PSS_ChatFilters.lua` |
| Blocking and auto-decline | Lines from listed people, guild members and matching filters are hidden; party and guild invites, duels and trades from listed people are declined; per-person and per-guild exceptions to the defaults | core `PSS_ChatBlock.lua`, `PSS_Options.lua` |
| Block history and counts | Counts per session, 24 h and all time; the block log (2000 lines by default) and kept lines per listed person | core `PSS_ChatHistory.lua`, folder `PourSocialScore_Logging` |
| Right-click menu | A "PSS" header on unit and chat-name menus: Block / Unblock Player, Block / Unblock Guild | core `PSS_BlizzardUI.lua` (B2) |
| The PSS window | One window, six tabs (Players, Guilds, Filters, Events, Import/Export, Options), three looks (Modern default, Classic, Dark) | `PourSocialScore_GUI` (drawing), `PourSocialScore_Libraries` (logic) |
| Import / Export | One text string with chosen sections; Merge or Replace | Libraries `PSS_ImportExport.lua` |
| Slash commands | `/pss` (window and commands), `/pssguild` (diagnostics) | Libraries `PSS_Commands.lua` |
| Upgrades | Numbered run-once save upgrades (8 steps today, feature-tagged parts, `RETIRED`, counts per feature from 3.4.1.45) and `/pss check` | core `PSS_Upgrade.lua` |

## 2. Folders, loading and the dependency graph

| Folder | Loads | SavedVariables | Role | Size |
| --- | --- | --- | --- | --- |
| `PourSocialScore` (core) | Always (needs Options) | `PourSocialScoreDB` | Chat engine, lists, counting, setters, event bus, loader, upgrades, Blizzard hooks, window openers, core popups | 20 Lua files, 11,099 lines |
| `PourSocialScore_Options` | Always, before core | `PSS_OptionsDB`, `PSS_PlayersDB`, `PSS_GuildsDB`, `PSS_RulesDB`, `PSS_CountsDB` | Data only (no code) | 1 file (comment) |
| `PourSocialScore_Libraries` | On demand: the first `/pss` command or window open | none | Slash commands, Import/Export, every query and view model behind the window | 14 files, 4455 lines |
| `PourSocialScore_GUI` | On demand: window open (loads Libraries first) | none | Drawing only: kit, skin, tabs, popups, menus | 15 files, 5,699 lines |
| `PourSocialScore_Logging` | On demand: only when the log is read, or the outbox fills | `PSS_LoggingDB` | The block log and kept lines; packing for save | 2 files |
| `PourSocialScore_Communities` | On demand: when a managed rule is on, or a shipped member is looked up | none | Packed shipped guild lists (about 335 KB file, 386 KB resident) | 1 generated file |

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
```

Rules the graph follows: core never calls the GUI (it fires `M.Events`); the GUI holds no logic or state (only drawing; `tools/check_layers.lua` checks it); Libraries reads core data and writes through core setters (a few direct writes are listed in section 10); nothing unloads once loaded (WoW cannot unload an addon).

**Shared handles.** The addon table is the one global, `PourSocialScore_NS`. On it: `M` (every shared function), `V` (runtime state), `L` (strings, missing key returns "BAD TEXT"), `M.Events` (the bus), `M.PSS_History` (= `History`), `MANAGED` / `MANAGED_DATA` (shipped lists). The GUI keeps its own private table `ns`.

**Loader** (`PSS_Loader.lua`): `M.PSS_PARTS` (GUI, Libraries, Logging, Communities), `NEEDS = {GUI = "Libraries"}`, `M.PSS_Need(key)` loads a part and its needs and warns once on a failed load or a version that differs from core; `M.PSS_Stub(fname, key)` puts a stand-in at `M[fname]` that loads the part on first call (used for `M.PSS_SlashPSS` and `M.PSS_SlashGuild`). `M.PSS_LoadLogging()` loads Logging and moves the outbox into the log.

## 3. Core folder, file by file (TOC order)

| File | Lines | Does | Key exports |
| --- | --- | --- | --- |
| `PSS_Localization.lua` | 517 | `L` table, English plus locale blocks | `L[...]` |
| `PSS_Globals.lua` | 473 | Creates `M` and `V`; string and name helpers, realm display names, client flags, message output, the W I G P C table | `M.ShowMsg`, `M.ChatMsg`, `M.Trim`, `M.Proper`, `M.addServer`, `M.removeServer`, `M.PSS_SplitNameArg`, `M.daysFromToday`, `M.prettyServer`, `V.serverName`, `V.playerName` |
| `PSS_Loader.lua` | 67 | Loads on-demand parts | `M.PSS_Need`, `M.PSS_Stub`, `M.PSS_PARTS` |
| `PSS_SavedData.lua` | 248 | Router metatable on `PourSocialScoreDB`: code writes `PourSocialScoreDB.<key>`, the key lives in its owner table (section 7); moves keys from old layouts | `M.PSS_PrepareSavedData`, `M.PSS_SavedDataSplit` |
| `PSS_Perf.lua` | 274 | Stepped garbage collection on request (deferred to out of combat, not in an instance), `/pss mem`; still has a 10-minute idle cycle and 15 s ticker (known breach, P2) | `M.PSS_RequestGC(reason)`, `M.PSS_MemReport`, `M.PSS_GCState` |
| `PSS_Events.lua` | 57 | The core event bus | `M.Events.Register / Unregister / Fire` |
| `PSS_Whois.lua` | 306 | The one /who service: send (from a click or key), shared cooldown, read answers from the Who list or chat lines | `M.Whois` (`Request`, listeners), fires `WHOIS_COOLDOWN` |
| `PSS_Communities.lua` | 134 | Generated manifest of the shipped lists: guild names and counts, no members | `addon.MANAGED.groups` |
| `PSS_MainlineCompat.lua` | 17 | Shims (`strlen`, `strbyte`) | `M.PSS_Mainline` |
| `PSS_ChatHistory.lua` | 1230 | `History`: entries, the capped shared log, kept lines per person, the outbox while Logging is unloaded, recent counts (session, 10-minute slots, 24 h), owner keys (`p:`, `g:`, `f:`), tidy and old-format migrations | `History.Add`, `History.NewEntry`, `History.CountRecent`, `History.Clear`, `History.StartSession/EndSession`, `History.Cap` |
| `PSS_ChatBlock.lua` | 889 | **The chat engine**: one message filter for every chat event, decision cache per line, block sources and handler registries, name normalisation, invites, duels, trades, whisper and group warnings, chat purge | `M.PSS_IsSecret`, `M.PSS_RegisterBlockSource`, `M.PSS_NormName`, `M.PSS_CanonPlayer`, `M.PSS_NormalizePlayer`, `M.PSS_UnitFullName`, `M.PSS_FixUnitName`, `M.PSS_PlayerDisplayName`, `M.PSS_PurgeChatFrom`, `M.PSS_CoreFilter`, `M.PSS_ExplainPerson` |
| `PSS_ChatFilters.lua` | 981 | Text filters: built-in definitions, saved custom rules, expand/collapse of the filter arrays, the tag language compiler, the "text" handler, managed-group rules | `M.PSS_ChatFilters_Evaluate`, `M.filterComplex`, `M.PSS_CompileFilter`, `M.PSS_SaveChatFilter`, `M.PSS_SetFilterActive`, `M.ResetSpamFilters`, `M.PSS_ManagedGroupActive`, `M.PSS_SetManagedGroupActive`, `M.PSS_FilterCounts` |
| `PSS_PlayerIgnoreList.lua` | 1625 | Player Ignore List: add, remove, expire, prune, the lookup index, Blizzard ignore hooks and sync (B1), the "player" block source plus NPC, realm and system handlers | `M.PSS_AddIgnore`, `M.PSS_AddPlayer`, `M.PSS_DelIgnore`, `M.PSS_SetPlayerSetting`, `M.PSS_SetBlizzardIgnore`, `M.PSS_SetNote`, `M.PSS_SetExpiry`, `M.PruneIgnoreList`, `M.SyncIgnoreList`, `M.PSS_RecordPlayerBlock`, `M.PSS_ResetPlayerBlockHistory`, `M.hasGlobalIgnored` |
| `PSS_PlayerQuery.lua` | 236 | Read helpers for the player list (so the window never reads saved tables) | `M.PSS_PlayerRow`, `M.PSS_SortPlayers`, `M.PSS_PlayerPosition`, `M.PSS_RemovePlayerAt`, `M.PSS_PlayersChanged` |
| `PSS_GuildIgnoreList.lua` | 2461 | Guild rules and members, per-rule and per-member W I G P C, member counts and history, shipped lists and their delta save, member index, /who capture, Guild Search, Exclusion List, own-guild check, unit scans, the "guild" block source, legacy upgrades | `M.PSS_AddGuild`, `M.PSS_RemoveGuildNow`, `M.PSS_SetGuildBlock`, `M.PSS_ScanGuild`, `M.PSS_GuildSearch`, `M.PSS_SaveGuildSearch`, `M.PSS_LookupGuildMember`, `M.PSS_SetMemberBlock`, `M.PSS_SetMemberNote`, `M.PSS_IsOwnGuild`, `M.PSS_GuildRuleActive`, `M.PSS_LoadActiveManagedData`, `M.PSS_FlushManaged`, `M.PSS_GetGuildBlockCounts` |
| `PSS_WhoisHarvest.lua` | 290 | Plans the guild sweep (one /who per click, split by level and class until under 50) and Scan All | `M.PSS_ScanAll`, `M.PSS_HarvestNext`, global `PSS_ScanAllBinding` (the key binding) |
| `PSS_Upgrade.lua` | 489 | Run-once upgrade steps 1 to 8 (the registry, U1), `RETIRED`, the upgrade record, version order, validation (`/pss check`) | `M.PSS_RunUpgradeFields`, `M.PSS_RunUpgradeData`, `M.PSS_VersionOrder`, `M.PSS_Validate`, `M.PSS_PrintValidation` |
| `PourSocialScore.lua` | 313 | Startup, legacy one-time import, group warning, logout work, slash stubs | `ApplicationStartup` (local), `SLASH_PSS1`, `SLASH_PSSGUILD1` |
| `PSS_Options.lua` | 152 | The one option table (30 keys) and its resolution: person > guild > global > default; only non-defaults saved | `M.PSS_OPTIONS`, `M.PSS_Opt`, `M.PSS_SetOpt`, `M.PSS_CharKey` |
| `PSS_BlizzardUI.lua` | 340 | Core touch points with Blizzard UI: window openers, docking beside Friends/Social, core StaticPopups (`PSS_RELOAD`, `PSS_REASON`, `PSS_PARTYWARN`), Group Finder colouring, tooltip and menu, unit right-click menu, Addon Compartment | `M.PSS_OpenUI` (-> GUI `M.PSS_OpenWindow`), docking (-> GUI `M.PSS_WindowDock`), `M.PSS_HookFunctions`, `M.PSS_UnitMenuPlayer`, `M.PSS_LFG_*`, `M.PSS_AskReload` |
| `Bindings.xml` | 5 | Key binding `PSS_SCAN_ALL` (a key press is a hardware event, so /who works) | |

## 4. Libraries folder (the window's back end and the commands)

TOC order matters: `PSS_ViewNav` before the three `*View` files, `PSS_GuildView` before `PSS_RowMenus`.

| File | Lines | Kind | Does | Core files it calls |
| --- | --- | --- | --- | --- |
| `PSS_ImportExport.lua` | 442 | Action | `PSS1:<checksum>:<base64>` string, own typed serialiser (never `loadstring`), Merge / Replace apply | ChatBlock, PlayerIgnoreList, GuildIgnoreList, ChatFilters, Options, Perf, Events |
| `PSS_GuildQuery.lua` | 361 | Query | Grouped guild rows, a rule's members, group open state, Add Guild from a member | GuildIgnoreList, ChatFilters, WhoisHarvest, ChatHistory, Globals |
| `PSS_FilterQuery.lua` | 145 | Query | Filter rows, counts, sort, search, history, test, chat link converter | ChatFilters, ChatHistory |
| `PSS_TotalsQuery.lua` | 118 | Query | Whole-list totals (`M.PSS_ListTotals`), per-type recent counts (adds `History.RecentByCat`) | PlayerIgnoreList, GuildIgnoreList, ChatFilters, ChatHistory |
| `PSS_EventsQuery.lua` | 268 | Query | Line types, "expired / not stored" rows, query matching, managed group reads and resets | ChatHistory, GuildIgnoreList, PlayerIgnoreList, PlayerQuery |
| `PSS_DetailQuery.lua` | 315 | Query | Pie and pane maths and text; exceptions (per-entry overrides of the target options) | ChatHistory, Options |
| `PSS_ViewNav.lua` | 290 | View | Window state (look, place, last tab, font, accent), back / forward history, list mixin | Options |
| `PSS_PlayerView.lua` | 335 | View | Players tab: list object, texts, edits, search picker, prune, Events specs | PlayerQuery, PlayerIgnoreList, ChatBlock, Whois, GuildIgnoreList, Globals |
| `PSS_GuildView.lua` | 717 | View | Guilds tab: grouped list, selection, cells, tips, add / exclude / search, picker, members view, pane text, Events specs | GuildIgnoreList, ChatFilters, WhoisHarvest, Whois, PlayerQuery, ChatHistory, Globals |
| `PSS_FilterView.lua` | 173 | View | Filters tab list object, texts, edits, Events specs | ChatFilters, GuildIgnoreList, Globals |
| `PSS_EventsView.lua` | 430 | View | Events tab query model: period, types, source, range, sort, nav keys, reset; reads through a spec `{kind, id, label, read, reset, owner, counts, all}` | ChatHistory, Globals |
| `PSS_OptionsView.lua` | 193 | View | Options rows, labels, tips, search; Import/Export ticks and mode (`M.PSS_IO`) | Options, Globals |
| `PSS_RowMenus.lua` | 207 | View | Right-click menus as data (`{text, act, arg}`), one per row kind | PlayerQuery, PlayerIgnoreList, GuildIgnoreList, ChatFilters, Globals |
| `PSS_Commands.lua` | 461 | Command | `/pss` and `/pssguild` parsers (section 9) | PlayerIgnoreList, GuildIgnoreList, ChatBlock, Globals, Options, PlayerQuery, Perf, Upgrade, BlizzardUI |

Libraries listens to no events; it fires only through core setters (and `PSS_ApplyImport` fires `PLAYERS_CHANGED`, `GUILDS_CHANGED`, `FILTERS_CHANGED`).

## 5. GUI folder (the front end)

| File | Lines | Does |
| --- | --- | --- |
| `PSS_Skin.lua` | 339 | Looks (`uiSkin`), fonts (`uiFont`), painters (`ns.OnPaint`), pixel-exact primitives (`ns.OnePixel`, `ns.NoSnap`, `ns.PixelBorder`), frame art (`ns.NewFrameArt`), art checks (`ns.HasModernArt`), Escape helper (`ns.EscapeCloses`), core listener registry (`ns.Listen`, `ns.ListenStart`, `ns.ListenStop`) |
| `PSS_Kit.lua` | 485 | The control kit: `ns.NewButton`, `ns.NewCheck`, `ns.NewEditBox`, `ns.NewNumberBox`, `ns.NewSearchBox`, `ns.NewPanel`, `ns.NewScrollFrame`, `ns.NewTab`, `ns.NewHeading`, `ns.OnCommit` |
| `PSS_Tooltip.lua` | 96 | `ns.Tip`, `ns.TipOn`, `ns.HideTip` (GameTooltip in Modern and Classic, our tooltip in Dark) |
| `PSS_Menu.lua` | 360 | `ns.NewDropdown`, `ns.ContextMenu`, `ns.RowMenu` (Blizzard Menu API in Modern and Classic, our `PSS_Menu` list in Dark) |
| `PSS_Popups.lua` | 264 | `ns.Confirm` (`PSS_Confirm`), `ns.CopyText`, `ns.ImportText` (`PSS_TextPopup`) |
| `PSS_Rows.lua` | 308 | `ns.NewRows`: virtual, sortable row list with columns, links and tips |
| `PSS_Pie.lua` | 140 | `ns.NewPie`: ring chart; OnUpdate only while hovered (approved override) |
| `PSS_Detail.lua` | 427 | Pane parts shared by Players, Guilds and Filters: `ns.NewDetailPages`, `ns.NewSummary`, `ns.NewTotals`, `ns.NewTypePie`, `ns.NewExceptions` |
| `PSS_History.lua` | 194 | `ns.NewHistory` (block history list in a pane), `ns.SenderMenu` |
| `PSS_Players.lua` | 573 | Players tab |
| `PSS_Guilds.lua` | 979 | Guilds tab (grouped list, members view, pane with four bodies, Guild Search picker) |
| `PSS_Filters.lua` | 489 | Chat Filters tab and the link-insert post-hook |
| `PSS_Events.lua` | 274 | Events tab (every blocked line, filters, sortable columns, copy, reset) |
| `PSS_Options.lua` | 240 | Options tab and Import/Export tab |
| `PSS_Window.lua` | 531 | `PSS_Window` (960 x 494), frame art, tab row, lazy tab building, back / forward, Escape stepping, open / close lifecycle, docking |

Tabs are built by `ns.TabBuilders[key](page)` on first open. Each tab file creates its Libraries list object at load (`M.PSS_PlayerListNew`, `M.PSS_GuildListNew`, `M.PSS_FilterListNew`, `M.PSS_EventsViewNew`), builds no frames until opened, and queues its listeners with `ns.Listen`.

## 6. Front end to back end (what each tab calls)

Shape: element -> Libraries function -> core setter or data. Full tables, with every GUI function, in `reference/code-map/D_GUI.md` section (a).

| Tab | Element or action | Libraries | Core |
| --- | --- | --- | --- |
| Players | List, sort, search | `PSS_PlayerListNew:Resort`, `PSS_PlayerTypeText`, `PSS_PlayerExpireText` | `PSS_PlayerRow`, `PSS_SortPlayers` |
| | Add Player / Player Search | `PSS_PlayerAddFromText`, `PSS_PlayerSearchFromText`, `PSS_PlayerPicker*` | `PSS_AddPlayer`, `PSS_PlayerSearch` (SendWho) |
| | Note, expiry, W I G P C, Blizzard tick | `PSS_PlayerCommitNote/Expiry`, `PSS_PlayerToggleAllowed`, `PSS_PlayerToggleBlizzard` | `PSS_SetNote`, `PSS_SetExpiry`, `PSS_SetPlayerSetting`, `PSS_SetBlizzardIgnore` |
| | Prune, Remove, Reset history | `PSS_PruneApply`, `PSS_PlayerRemoveText` | `PruneIgnoreList`, `PSS_RemovePlayerAt` and `PSS_ResetPlayerBlockHistory` (called straight from the GUI) |
| | Exceptions ticks | `PSS_ExceptionState`, `PSS_SetException` | `PSS_SetOpt(key, "person", v, target)` |
| Guilds | Grouped list, open a heading | `PSS_GuildListNew:Resort` -> `PSS_GuildRows`, `PSS_SetGuildGroupOpen` | GuildIgnoreList data, `PSS_ManagedGroupActive` |
| | Add / Exclude / Guild Search | `PSS_GuildAddFromText`, `PSS_GuildExcludeFromText`, `PSS_GuildSearchFromText`, `PSS_GuildPicker*` | `PSS_AddGuild`, `PSS_AddGuildExclusion`, `PSS_GuildSearch`, `PSS_SaveGuildSearch` |
| | Scan All, Scan, Custom Scan, Scan Fields | `PSS_GuildScanNow`, `PSS_GuildCustomScan`, `PSS_GuildCommitFields` | `PSS_ScanAll` (straight from GUI), `PSS_ScanGuild`, `PSS_SetGuildScanFields` |
| | Guild and member W I G P C, note, remove | `PSS_GuildToggleAllowed`, `PSS_MemberToggleAllowed`, `PSS_MemberCommitNote`, `V:RemoveMember`, `PSS_GuildRemove` | `PSS_SetGuildBlock`, `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_RemoveGuildMember`, `PSS_RemoveGuildNow` |
| | Managed Communities rule on / off | `PSS_GroupToggleRule`, `PSS_GuildSetAllRules` | `PSS_SetManagedGroupActive` |
| Filters | List, on tick | `PSS_FilterListNew:Resort`, `PSS_FilterRow` | `PSS_SetFilterActive` (straight from GUI) |
| | Save, Copy, New, Remove | `PSS_FilterSave`, `PSS_FilterCopy`, `PSS_FilterNew`, `PSS_FilterRemove` | `PSS_SaveChatFilter`, `PSS_CopyChatFilter`, `PSS_AddCustomFilter`, `RemoveChatFilter` |
| | Test, link converter | `PSS_FilterTestText`, `PSS_ConvertChatLink` | `PSS_IsSecret` on inserted links |
| | Reset count, history, defaults | none | `PSS_ResetFilterCount`, `PSS_ResetFilterHistory`, `M.ResetSpamFilters` (straight from GUI) |
| Events | Open from a pie, a pane or View Events | `view:Open(spec)` (specs from the three `*View` files) | none until read |
| | Read, filter, sort | `view:Refresh` (a spec's `read` loads Logging), `view:Apply`, `PSS_EventCells` | `History`, `PSS_LoggingDB` |
| | Reset Block History | `view:DoReset` -> spec `reset` | the matching core reset |
| Options | Ticks, numbers, choices | `PSS_OptGroups`, `PSS_OptSetNumber`, `PSS_OptChoiceText` | `PSS_SetOpt(key, "global", v)` -> `OPTION_CHANGED` |
| Import/Export | Export, Import | `PSS_ExportText`, `PSS_ImportCheck`, `PSS_ImportApply` -> `PSS_ApplyImport` | setters plus direct writes (section 10) |

Panes: Summary pies and counts come from DetailQuery and TotalsQuery over the core counters (`PSS_GetPlayerBlockCounts`, `PSS_GetGuildBlockCounts`, `PSS_FilterCounts`, `History.RecentByCat`). History lists read the log, which loads Logging only when the player clicks for it.

**Open and close.** `/pss` -> `M.PSS_SlashPSS` (Libraries) -> `M.PSS_OpenUI` (core) -> `M.PSS_Need("GUI")` (Libraries, then GUI) -> `M.PSS_OpenWindow`. The first open builds the window and only the last tab. OnShow registers the queued listeners and refreshes stale pages; OnHide unregisters them, releases the Events tab's lines and calls `M.PSS_RequestGC("window closed")`. `OPTION_CHANGED` stays registered after the first build so a look change repaints. Escape: popups and our menu are in `UISpecialFrames`; the window uses a helper frame `PSS_WindowEscape` that closes the top popup, then steps up one level (picker, members view, Events back), then hides the window.

## 7. Saved data

`PourSocialScoreDB` is the name the code uses; a router metatable (`PSS_SavedData.lua`) sends each listed key to its owner table while that addon is loaded.

| Table (folder) | Holds | Owner code |
| --- | --- | --- |
| `PourSocialScoreDB` (core), raw keys | `upgrade {step, version, at}`, `outbox`, `recent {v=2, last, day, [1..144]}`, `session`, `sessionStart`, import and revision markers | Upgrade, ChatHistory, PourSocialScore.lua |
| `PSS_OptionsDB` (Options) | Non-default options, `windowPoints` (window place, last tab), `showIgnoreDebug` (dead, N8) | PSS_Options, Libraries ViewNav |
| `PSS_PlayersDB` (Options) | Parallel arrays `ignoreList`, `typeList`, `factionList`, `dateList`, `notes`, `expList`, `delList`, `syncInfo`; `playerData[key]` records (W I G P C as `*Blocked`, `blockCounts`, `opts`, `blizzardIgnore`) | PlayerIgnoreList |
| `PSS_GuildsDB` (Options) | `guildData[key]` rules (`block`, `opts`, `members[key]`, `managedGone`, scan fields), `guildExclusions`, `guildGroupOpen` | GuildIgnoreList |
| `PSS_RulesDB` (Options) | `filterList`, `filterDesc`, `filterActive`, `filterID` (custom rules), `builtinRules {id = on}` | ChatFilters |
| `PSS_CountsDB` (Options) | `hiddenTotal`, `filterTotal`, `filterCount`, `filterBlocked`, `builtinStats`, whisper and private totals | ChatFilters, ChatBlock |
| `PSS_LoggingDB` (Logging) | `blockLog` (packed v2 groups), `blockKeep` (kept lines per person) | ChatHistory, Logging `PSS_SavedLog.lua` |

Identity is the lowercase `name-realm` key; the canon form drops apostrophes and collapses spaces. History owners: `p:<canon>` (player), `g:<canon>` (guild member), `f:...` (filter; today keyed by filter text, N43). Shipped members are saved only as a delta (`PSS_FlushManaged` at logout).

## 8. Runtime flows

**Chat line** (`PSS_ChatBlock.lua`, `CoreFilter`, about 30 us per line):
1. The message filter is registered for 41 chat events. A secret author or GUID: pass, not counted. A secret message still reaches person rules (decision 1).
2. Decision cache per `lineID`, so the other chat windows reuse it.
3. `evaluate`: system handlers, NPC handlers, then **people** (player source by W I G P C; guild source only while its rule is on, not excluded, not your guild), then **realm** handlers, then **text** filters (`M.PSS_ChatFilters_Evaluate`).
4. A block: `History.Add(owner, counts, entry)` bumps the owner's counts and the recent counts, then queues the line in the outbox (Logging unloaded) or the log; fires `PLAYER_BLOCKED`, `GUILD_BLOCKS_CHANGED` (throttled) or `FILTER_HISTORY_CHANGED` / `FILTERS_CHANGED`; a whisper may get the ignore response.
5. Invites, duels and trades ask the same sources (`decide`) and decline through the API.

**Startup:** `ADDON_LOADED` and `PLAYER_ENTERING_WORLD` both seen -> `ApplicationStartup`: prepare saved data, create missing arrays, option defaults, upgrade fields, expand filters, load the shipped data when a managed rule is on, `V.PSS_Loaded = true` (filtering starts deciding), upgrade data steps, Logging if the upgrade loaded it, `M.PSS_HookFunctions` (menus, Friends frame, LFG). **Logout:** collapse filters, flush the shipped delta, end the session counts, pack the log when Logging is loaded.

**Guild scan:** a click or key -> `PSS_ScanGuild` -> `PSS_HarvestNext` -> `Whois.Request` (SendWho) -> answers through `WHO_LIST_UPDATE` or chat lines -> `captureWho` -> member records -> split when capped (level brackets, classes, single levels) -> `GUILD_SCAN_DONE`.

**Blizzard ignore (B1):** post-hooks on `C_FriendList` add / remove calls; a new Blizzard ignore lists the player with the note "Synced from Blizzard ignore list on <date>" and is moved off Blizzard's list on the next `IGNORELIST_UPDATE` unless ticked; the first update after login syncs Blizzard's list into PSS (ticked, nobody removed).

## 9. Events and commands

**`M.Events` bus**

| Event | Fired by | Heard by |
| --- | --- | --- |
| `OPTION_CHANGED` (key) | `M.PSS_SetOpt` | GUI Options, GUI Window (permanent after build) |
| `PLAYERS_CHANGED` (resort) | PlayerIgnoreList, PlayerQuery, GuildIgnoreList (remove), ImportExport | GUI Players, Events |
| `PLAYER_BLOCKED` | `M.PSS_RecordPlayerBlock` | GUI Players, Events (throttled 0.25 s) |
| `ASK_NOTE` (name) | PlayerIgnoreList add | core BlizzardUI (`PSS_REASON` popup) |
| `GUILDS_CHANGED` | GuildIgnoreList, ImportExport | GUI Guilds, Events; core WhoisHarvest |
| `GUILD_BLOCKS_CHANGED` | GuildIgnoreList (at most every 0.25 s) | GUI Guilds, Events |
| `GUILD_REMOVED` (key) | `M.PSS_RemoveGuild` | GUI Guilds; core WhoisHarvest |
| `GUILD_SCAN_DONE` | GuildIgnoreList scan finish | GUI Guilds |
| `GUILD_SEARCH_RESULTS` | `M.PSS_GuildSearch` | GUI Guilds |
| `WHOIS_COOLDOWN` (active) | PSS_Whois | GUI Players, Guilds |
| `WHOIS_ANSWERED` | PSS_Whois | nobody |
| `FILTERS_CHANGED` | ChatFilters (once per blocked line, G21), ImportExport | GUI Filters |
| `FILTER_HISTORY_CHANGED` (i) | ChatFilters | GUI Filters, Events |
| `WHISPER_WARNING`, `GROUP_WARNING` | ChatBlock, PourSocialScore.lua | core BlizzardUI |

**Slash commands** (`PSS_Commands.lua`): `/pss` (also `gui`, `ui`, `eui`) opens or closes the window; `add`/`ignore`, `remove`/`delete`, `server`/`addserver`, `npc`/`addnpc`, `expire`, `list`, `prune`, `sync`, `clear` (+ `confirm`), `defexpire`, `asknote`, `showmsg`, `sameserver`, `mem`/`memory`, `check`, `dellist`, `test` (empty); anything else prints help. `/pssguild` (status), `debug [all]`, `test <name>` (dry run across every list), `chat`, `check <name>`.

**Blizzard touch points** (PSS 02 section 10.3): `ChatFrameUtil.AddMessageEventFilter`; post-hooks on `C_FriendList`; `Menu.ModifyMenu` for unit menus (option `useUnitHacks`) and the LFG list (`useLFGHacks`); `HookScript` on `FriendsFrame`; `hooksecurefunc(ChatFrameUtil, "InsertLink")` (Filters tab); `PSS_` StaticPopups; `UISpecialFrames`; decline APIs (`DeclineGroup`, `DeclineGuild` / `C_GuildInfo.DeclineGuild`, `CancelDuel`); `RemoveMessagesByPredicate` for the chat purge; `C_FriendList.SendWho` only from a click or key.

## 10. Code review notes (state of main at 3.4.1.38)

The plan's findings N1 to N48 and G1 to G30 still hold where their stage has not run. New notes from this mapping are in `13_CHANGES_IN_TRAIN.md` section 9 (R1 to R17). The ones that matter when reading the code:
- **Direct save writes outside core setters:** `PSS_GuildRows` writes `g.memberCount` on every redraw; `PSS_ApplyImport` writes records directly and Replace sets `guildData = {}` (N45); `guildGroupOpen` and `windowPoints` are UI state written from Libraries.
- **Setters that fire no event:** `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_SetGuildScanFields` (the Guilds tab redraws itself).
- **GUI calls some core setters directly** instead of through Libraries (`PSS_RemovePlayerAt`, the reset functions, `PSS_SetFilterActive`, `M.ResetSpamFilters`, `PSS_ScanAll`, `PSS_SetOpt`): allowed, uneven, a W2 target.
- **Only the Events tab drops what it read on close**; the other tabs keep list state and their History panes' last lines for the session.
- **Expiry is not applied automatically** (only `/pss sync`), N40, fixed in F1.
- **Dead code** is substantial (about 25 unused exports, 61 unused strings, unused `History` functions, `V.needSorted`); removed in P1, which must keep `M.PSS_EnsureManagedRules` and `M.PSS_CompileFilter`.

## 11. Where to look (task -> file)

| Task | Start in |
| --- | --- |
| A line is or is not blocked | core `PSS_ChatBlock.lua` (`evaluate`, sources), `/pssguild test <name>` |
| Player list behaviour, Blizzard ignore | core `PSS_PlayerIgnoreList.lua` |
| Guild rules, members, scans | core `PSS_GuildIgnoreList.lua`, `PSS_WhoisHarvest.lua`, `PSS_Whois.lua` |
| Filter language, built-ins | core `PSS_ChatFilters.lua` |
| Counts, history, outbox, log | core `PSS_ChatHistory.lua`, Logging `PSS_SavedLog.lua` |
| A saved key, routing, upgrades | core `PSS_SavedData.lua`, `PSS_Upgrade.lua` |
| An option | core `PSS_Options.lua`; drawn by GUI `PSS_Options.lua` via Libraries `PSS_OptionsView.lua` |
| Names (Camelot surnames) | core `PSS_ChatBlock.lua` (`M.PSS_NormName`), `PSS_Globals.lua` (`M.PSS_SplitNameArg`) |
| Right-click menu, popups, docking | core `PSS_BlizzardUI.lua` |
| What a tab shows | GUI tab file, then its Libraries `*View` / `*Query` file (section 6) |
| How a control looks in each look | GUI `PSS_Skin.lua`, `PSS_Kit.lua`; preview `tools/harness/kit_page.lua` |
| A slash command | Libraries `PSS_Commands.lua` |
| Import / Export | Libraries `PSS_ImportExport.lua` |
| Shipped lists | `tools/PSS_BuildManaged.lua`, core `PSS_Communities.lua`, `PourSocialScore_Communities/` |
| Checks and harness | `tools/check_rules.sh`, `tools/check_layers.lua`, `tools/harness/validate_all.sh`, `tui_compare.sh` (docs `07_HARNESS.md`) |
