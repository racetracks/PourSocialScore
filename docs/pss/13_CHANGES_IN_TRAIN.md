# PourSocialScore: changes in train (2026-10-08, main 3.4.1.38)

**What this is.** A context document: what PourSocialScore is about to change, where, and why, so a later session (Claude or GPT) can tell the shipped features apart from the planned ones. Read it with `12_CODE_MAP.md`, which describes the code as it is on main at **3.4.1.38**. The source of truth stays the locked plan, `docs/pss/10_CORE_UPLIFT.md` in the addon repo (scratch `docs/latest/core-uplift/00_CORE_UPLIFT.md`). Where this file and the plan differ, the plan wins.

## 0. In one screen

| Item | State on 2026-10-08 |
| --- | --- |
| Live release | **3.4.0.29** (full; the new PSS window in three looks; mirrored to `racetracks/Pour-Social-Score`) |
| Main | 3.4.1.38 (docs build, PR #127; N3 merged in 3.4.1.37) |
| Current project | **Core uplift**, locked 2026-10-08, three version lines |
| Line 3.4.1 | Fixes and data: names (done), Blizzard ignore authority (done), right-click PSS header (done), shipped lists rebuilt (done); next the detail pane fix, then bug fixes, the upgrade report, forward-compatible saves, and the step 9 save cleanup; release 3.4.1.49 |
| Line 3.4.2 | Core performance: dead code out, event-driven GC, events only when needed, cheaper chat path, duplicate logic merged, core placement |
| Line 3.4.3 | Window tidy: dead GUI names, logic moved from GUI to Libraries, kit functions, redraw cost |
| Build numbers | `X.Y.Z.B`; B never resets; every build (stage, fix, release) takes the next one |
| How work is delivered | One stage per PR, one stage per session, based on main, test zip on scratch, Dan tests in game and merges |

What will **not** change (decided): player and guild identity stays the lowercase `name-realm` key (no ID generator, decision 2); realm display spelling stays as today (decision 13 reversed); no new SavedVariables files; the three looks and the window's layout stay.

## 1. Stage table (line 3.4.1)

| Stage | Build | Change | Visible? | State |
| --- | --- | --- | --- | --- |
| Plan | 3.4.1.31 | The plan and working rules; docs only | No | Merged (#119) |
| N1 | 3.4.1.32 | `M.PSS_NormName` and the name helpers | Barely | Merged (#120) |
| N2 | 3.4.1.33 | Every name caller, multi-word names, import check, runtime fields not flushed | Yes | Merged (#121) |
| Plan B | 3.4.1.34 | B1 and B2 added to the plan; docs only | No | Merged (#122) |
| B1 | 3.4.1.35 | PSS authoritative over Blizzard's ignore list; per-player tick; upgrade step 8 | Yes | Merged (#123) |
| B2 | 3.4.1.36 | Right-click "PSS" header: Block Player / Block Guild | Yes | Merged (#124) |
| N3 | 3.4.1.37 | Builder fix, shipped lists rebuilt (7634 to 7438 entries) | Lists | Merged (#126) |
| Docs | 3.4.1.38 | Harness notes for a list rebuild; docs only | No | PR #127 |
| Docs | 3.4.1.39 | This code map and changes in train; docs only | No | PR #128 |
| **Fix** | 3.4.1.40 | Guilds tab detail pane: a wrapped line pushes the lines and pies below it down (decision 23) | Yes | **Next** |
| F1 | 3.4.1.41 | N40 expiry applied, N41 hooks gated by option, N42 talent links, N45 Import Replace keeps shipped rules, N46 listener errors reported, N47 group warning list, N48 `/pss list` nil note | Yes | |
| F2 | 3.4.1.42 | G21 filter redraw throttle with G26 rule dim refresh, G27 Dark menu height, G28 Modern art check | Yes (Dark menus) | |
| U1 | 3.4.1.43 | Upgrade step registry, invisible (step 1 split and tagged, `RETIRED`, counts, version compare) | No | |
| U2 | 3.4.1.44 | Upgrade report printed once per update (issue #45) | Once per update | |
| U3 | 3.4.1.45 | Forward compatibility: `M.PSS_SCHEMA`, tolerant readers, downgrade line, unusable rules kept and reported, `/pss export unused`, export format version | Only when a rule cannot be used | |
| S1 | 3.4.1.46 | `History.ClearOwner` and the purge tombstone (N16) | No | |
| S2 | 3.4.1.47 | Accessors for every field S3 drops; rules-check grep | No | |
| S3 | 3.4.1.48 | Upgrade step 9 "SavedVariables performance cleanup" | Report, smaller save | |
| R | 3.4.1.49 | Release; one summary of every change since 3.4.0.29; `01_HANDOVER.md` re-summarized | | |

Lines 3.4.2 (P1 to P6, R) and 3.4.3 (W1 to W4, R) take the build numbers after 3.4.1.49 in order.

## 2. What each planned change touches in the code

Use with `12_CODE_MAP.md` to find the file.

| Stage | Files that change (main ones) | Saved data? |
| --- | --- | --- |
| Fix | GUI `PSS_Guilds.lua` (`BuildGroupBody`, guild and member panes), GUI `PSS_Players.lua` `Line()` stacks; maybe `ns.NewSummary` / `ns.NewTypePie` anchors in `PSS_Detail.lua` | No |
| F1 | core `PourSocialScore.lua` (login expiry, group warning), `PSS_PlayerIgnoreList.lua` (expiry helper out of `SyncIgnoreList`), `PSS_BlizzardUI.lua` (hook bodies check `useUnitHacks` / `useLFGHacks`), `PSS_Events.lua` + `PSS_Whois.lua` (errors reported), Libraries `PSS_FilterQuery.lua` + core `PSS_ChatFilters.lua` (talent tag), Libraries `PSS_ImportExport.lua` + core `PSS_GuildIgnoreList.lua` (`M.PSS_EnsureManagedRules` after Replace), Libraries `PSS_Commands.lua` (`/pss list`) | No |
| F2 | core `PSS_ChatFilters.lua` (fewer `FILTERS_CHANGED`), GUI `PSS_Filters.lua`, `PSS_Guilds.lua` (listen to `FILTERS_CHANGED`), `PSS_Menu.lua` (Dark height), `PSS_Skin.lua` (atlas list) | No |
| U1 to U3 | core `PSS_Upgrade.lua` (registry, report, compare), new core data table `M.PSS_SCHEMA`, `PSS_SavedData.lua` (tolerant reads, `RETIRED`), Libraries `PSS_ImportExport.lua` (format version, keep unknown fields), Libraries `PSS_Commands.lua` (`/pss export unused`), `tools/check_rules.sh` (schema check), harness `check_upgrade_report.lua` | Record keeps highest version |
| S1 | core `PSS_ChatHistory.lua` (`History.ClearOwner`), the six `History.Clear(pred)` callers in `PSS_ChatFilters`, `PSS_PlayerIgnoreList`, `PSS_GuildIgnoreList`; `PourSocialScoreDB.purge` tombstone; Logging `PSS_SavedLog.lua` applies it | New capped key in an existing table |
| S2 | `M.PSS_MemberGuildName`, `M.PSS_MemberCanon`, `History.EnsureCounts`; every raw read of `_playerKey`, `_canon`, `_gkey`, `_managed`, `guild`, `name`, `blockCounts` fields | No |
| S3 | `PSS_Upgrade.lua` step 9 and the writers in `PSS_GuildIgnoreList.lua`, `PSS_PlayerIgnoreList.lua`, `PSS_ChatHistory.lua`, `PSS_ChatFilters.lua` (filter ids) | **Yes**: Dan's OK given (D9) |
| P1 | Dead code across core (N1 to N15). Keep `M.PSS_EnsureManagedRules` (F1 uses it) and `M.PSS_CompileFilter` (U3 uses it) | No |
| P2 | `PSS_Perf.lua` (no idle cycle, no 15 s ticker), `PSS_ChatHistory.lua` `loadWhenQuiet` (no 30 s timer) | No |
| P3 | Event registration in `PSS_ChatBlock.lua`, `PSS_GuildIgnoreList.lua`, `PSS_WhoisHarvest.lua` (capture only when a rule needs it) | No |
| P4 | Chat path: option cache (N26), guild path (N28), per-line tables (N35), outbox trim (N31) | No |
| P5 | Shared helpers for N17 to N25 | No |
| P6 | Move N37 to N39 (validation, realm pairs, rare paths) from core to Libraries | No |
| W1 to W4 | GUI files; W2 moves logic from GUI to Libraries view files; W3 adds kit functions (in all three looks and the kit preview) | No |

## 3. Every finding and where it lands

### 3.1 Core, Libraries, Logging, Options (appendix 01, N1 to N48)

| Id | What (one line) | File(s) | Fixed in |
| --- | --- | --- | --- |
| N1 | 61 of 174 English localization keys never read (old window text); 159 lines across locales | `PSS_Localization.lua` | P1 (3.4.2) |
| N2 | `V.needSorted` written in 12 places, never read | `PSS_Globals.lua`, `PSS_PlayerIgnoreList.lua`, `PSS_PlayerQuery.lua`, `PSS_ImportExport.lua` | P1 |
| N3 | Reload prompt dead: no option has `reload`; `M.PSS_AskReload`, `PSS_RELOAD` unused; `PSS_SetOpt` still reads `before` | `PSS_Options.lua`, `PSS_BlizzardUI.lua` | P1 (plan: "the reload popup"; appendix preferred keeping it for N41, Dan's call) |
| N4 | `gotUpdate` / `gotGroup` never read; `IGNORELIST_UPDATE` registered on the main frame only to set `gotUpdate` (still present at 3.4.1.37) | `PourSocialScore.lua` | P1 |
| N5 | `PSS_MainlineCompat.lua` writes `_G.strlen` / `_G.strbyte` (loads after its only users); `M.PSS_Mainline` never read | `PSS_MainlineCompat.lua`, `PSS_Globals.lua` | P1 ("the compat globals") |
| N6 | `V.wowIsERA` .. `V.wowName` written, never read | `PSS_Globals.lua` | P1 |
| N7 | `M.debugMsg` is empty but 19 callers still build strings | `PSS_Globals.lua`, `PSS_PlayerIgnoreList.lua`, `PSS_Events.lua`, `PSS_Whois.lua` | P1 (error-routing half is N46, F1) |
| N8 | `showIgnoreDebug = false` written into every save at each login, never read | `PSS_Upgrade.lua`, `PSS_PlayerIgnoreList.lua`, `PSS_SavedData.lua` | S3 (step 9, plan 2.2) and also listed under P1 (N1-N15); S3 comes first |
| N9 | About 25 dead `M.*` exports (old window API) | `PSS_ChatBlock`, `PSS_ChatFilters`, `PSS_ChatHistory`, `PSS_GuildIgnoreList`, `PSS_PlayerIgnoreList`, `PSS_PlayerQuery`, `PSS_Whois`, `PSS_WhoisHarvest`, `PSS_DetailQuery` | P1. Caution: `M.PSS_EnsureManagedRules` is reused by N45 (F1) and `M.PSS_CompileFilter` by U3 (plan 2.3.6); `PSS_TypeOff` / `PSS_HexColor` overlap G12 (W1) |
| N10 | Harness-only exports in shipped code (`PSS__CoreTest` comment says not shipped) | `PSS_ChatBlock.lua`, `PSS_DetailQuery.lua`, others | P1 (keep, label as harness hooks); `PSS_AnyTypeOff` overlaps G12 |
| N11 | `History.KeepAdd`, `MovePeople`, `MergeLists` (+`Max`), `Combine`: no caller, about 11 KB resident | `PSS_ChatHistory.lua` | P1 |
| N12 | Unused locals (`hasFilterID`, `findGuildForPlayer`, `CAT_COLOR`, ...) | `PSS_ChatFilters`, `PSS_GuildIgnoreList`, `PSS_ChatHistory`, `PSS_Options`, `PSS_ImportExport` | P1 |
| N13 | `/pss test` (`PSSTest`) is empty | `PSS_Commands.lua` | P1 |
| N14 | 70-line realm-resolve block in `M.PSS_AddOrDelIgnore` unreachable (callers pass a realm); `pServers` unused (still present) | `PSS_PlayerIgnoreList.lua` | P1 |
| N15 | `M.PSS_GUILD_SEARCH_OWNER` tag for the old window; stale comment | `PSS_GuildView.lua`, `PSS_GuildIgnoreList.lua`, GUI `PSS_Guilds.lua` | P1 |
| N16 | Six copies of `History.Clear(pred)` + `ForgetRecent` | `PSS_ChatFilters`, `PSS_PlayerIgnoreList`, `PSS_GuildIgnoreList` | S1 (`History.ClearOwner`) |
| N17 | 15 copies of "a stored member's canon key" | `PSS_GuildIgnoreList.lua` | P5 (S2's `M.PSS_MemberCanon` accessor overlaps) |
| N18 | `findGuildRecord` vs `M.PSS_FindGuildRule`: same lookup, opposite return order | `PSS_GuildIgnoreList.lua`, `PSS_GuildQuery.lua` | P5 |
| N19 | Two date parsers, two month tables, per-call tables | `PSS_Globals.lua`, `PSS_ChatHistory.lua` | P5 |
| N20 | Category list and labels defined twice | `PSS_ChatBlock.lua`, `PSS_ChatHistory.lua`, `PSS_Commands.lua` | P5 |
| N21 | W I G P C field lists spelled out in eight places | `PSS_Globals`, `PSS_PlayerIgnoreList`, `PSS_ImportExport`, `PSS_GuildIgnoreList` | P5 |
| N22 | Parallel-array `table.remove` copies; legacy copy skips cleanup | `PSS_PlayerIgnoreList`, `PSS_GuildIgnoreList`, `PSS_ChatFilters` | P5 |
| N23 | Five rules for "your target as a name to add" | `PSS_PlayerView`, `PSS_PlayerIgnoreList`, `PSS_Commands` | P5 |
| N24 | LFG and unit menu build the same toggle twice | `PSS_BlizzardUI.lua` | P5 (B2 at 3.4.1.36 already rebuilt the unit menu; recheck) |
| N25 | Two "remove older than N days" loops | `PSS_PlayerIgnoreList.lua` | P5 (the expiry half is extracted by N40 in F1) |
| N26 | Every routed `PourSocialScoreDB.<key>` read costs 0.127 us vs 0.008 us; about 2 us per chat line | `PSS_SavedData.lua`, `PSS_Options.lua`, `PSS_ChatFilters`, `PSS_PlayerIgnoreList`, `PSS_GuildIgnoreList` | P4 |
| N27 | `History.Clear(pred)` unpacks every kept line: 2.9 ms, 1.6 MB garbage per call; N calls on Import Replace | `PSS_ChatHistory.lua`, `PSS_ImportExport.lua` | Not named in the table; covered in practice by S1 (`ClearOwner`). The `ClearOwners(set)` for Import Replace is unscheduled |
| N28 | Guild path per chat line: group index walk, `canonGuild` x2, `GetGuildInfo`, `g.block` rewrites | `PSS_GuildIgnoreList.lua`, `PSS_ChatFilters.lua` | P4 |
| N29 | `M.daysFromToday` builds tables per entry in sort, rows and Prune preview | `PSS_PlayerQuery`, `PSS_PlayerIgnoreList`, `PSS_PlayerView` | Unscheduled by id; its fix is N19 (P5) |
| N30 | `M.PSS_GetGuildBlockCounts` recounts every member on every Resort (D7) | `PSS_GuildIgnoreList.lua`, `PSS_GuildQuery`, `PSS_TotalsQuery` | Unscheduled (runtime count cache; G22 in W4 only avoids the double call) |
| N31 | Outbox at cap: `table.remove(ob, 1)` per blocked line, `History.Cap()` per line | `PSS_ChatHistory.lua` | P4 |
| N32 | `M.PSS_RemoveGuild` walks the whole ignore list per member; work is redundant; `removedGlobal` always 0 | `PSS_GuildIgnoreList.lua` | Unscheduled |
| N33 | `M.hasGlobalIgnored` linear scan before the O(1) index (same for NPC / server) | `PSS_PlayerIgnoreList.lua` | Unscheduled |
| N34 | `CoreFilter` runs seven `isSecret` calls before the decision-cache lookup, per chat window | `PSS_ChatBlock.lua` | Unscheduled (natural fit P4) |
| N35 | Per-line tables on block paths (core half of L17) | `PSS_PlayerIgnoreList`, `PSS_GuildIgnoreList`, `PSS_ChatBlock` | P4 |
| N36 | With shipped lists loaded, every non-member sender costs three `sub` + a bucket `find` per line | `PSS_GuildIgnoreList.lua` | Unscheduled (natural fit P4) |
| N37 | `M.PSS_Validate` / `M.PSS_PrintValidation` resident in core (28.1 KB) | `PSS_Upgrade.lua` | P6 |
| N38 | `REALM_PAIRS` / `M.prettyServer` resident in core (25.6 KB), only window uses it | `PSS_Globals.lua` | P6 |
| N39 | Measured costs of L20 candidates plus new ones (`AddCapturedGuild` 21.1 KB, legacy import, one-time upgrades, ...); about 105 KB resident total | several core files | P6 |
| N40 | Expiry never applied automatically (only `/pss sync`); readme says it is | `PourSocialScore.lua`, `PSS_PlayerIgnoreList.lua`, `PSS_Commands.lua` | F1 (decision 11: login, quiet event, list open) |
| N41 | Menu / LFG hooks installed only if option on at login; bodies never recheck | `PSS_BlizzardUI.lua`, `PSS_Options.lua` | F1 |
| N42 | Talent link converts to `[talent=N]`, which the filter language does not know | `PSS_FilterQuery.lua`, `PSS_ChatFilters.lua` | F1 |
| N43 | Custom filter history keyed by its text: edit orphans lines, Copy shares one owner | `PSS_ChatFilters.lua` | S3 (decision 3, integer id `nextFilterId`, history and recent on `f:<id>`) |
| N44 | Realm guess in the dead N14 block: oldest chat match wins | `PSS_PlayerIgnoreList.lua` | Not in the table by id; goes with N14 (P1) per the appendix |
| N45 | Import Replace on guilds wipes shipped rules until /reload; recent counts not forgotten; `existed` uses the wrong normaliser | `PSS_ImportExport.lua`, `PSS_GuildIgnoreList.lua` | F1 |
| N46 | Listener and /who handler errors swallowed by the empty `debugMsg` | `PSS_Events.lua`, `PSS_Whois.lua` | F1 |
| N47 | Group warning keeps everyone warned since joining, shows leavers again | `PourSocialScore.lua` | F1 |
| N48 | `/pss list` errors on a nil note | `PSS_Commands.lua` | F1 |

### 3.2 Window (appendix 02, G1 to G30)

| Id | What (one line) | File(s) (GUI unless noted) | Fixed in |
| --- | --- | --- | --- |
| G1 | History rows and tips copy Events formatting | `PSS_History.lua` (Libraries `PSS_EventsView.lua`) | W2 (3.4.3) |
| G2 | Picker tick / "listed" strings built in two tabs | `PSS_Players.lua`, `PSS_Guilds.lua` | W2 |
| G3 | Guild tab reads rules and saved records directly | `PSS_Guilds.lua` | W2 |
| G4 | Remove Guild target decided in the GUI | `PSS_Guilds.lua` | W2 |
| G5 | GUI writes the view's `dirty` / `mdirty` | `PSS_Guilds.lua`, `PSS_Filters.lua` | W2 (the rule-toggle writes can go once G26 lands in F2) |
| G6 | Empty-list and hint texts chosen in the GUI | `PSS_Guilds.lua`, `PSS_History.lua` | W2 |
| G7 | Each pane fills its Summary spec and labels | `PSS_Players`, `PSS_Guilds`, `PSS_Filters` | W2 |
| G8 | Type-pie tip and spec copy in the GUI | `PSS_Detail.lua` | W2 |
| G9 | Events tab reads `view.q` / `view.name` | `PSS_Events.lua` | W2 |
| G10 | Import/Export raw `M.PSS_IO` reads and import decision chain | `PSS_Options.lua` | W2 |
| G11 | `M.PSS_EnsureMemberBlockData` called from a redraw (redundant) | `PSS_Guilds.lua` | W1 |
| G12 | Unreferenced ns / M names (`ns.CloseMenu`, `ns.DETAIL_PAGES`, `ns.ResetTab`, ...) | Menu, Detail, Window, Guilds, Players; Libraries GuildView, DetailQuery | W1 (overlaps N9 / N10 in P1) |
| G13 | "comes in a later 3.4.0 build" placeholder still built | `PSS_Window.lua` | W1 |
| G14 | Header comments describe two looks | Skin, Kit, Window, Rows | W1 |
| G15 | Results picker built twice | `PSS_Players.lua`, `PSS_Guilds.lua` | W3 |
| G16 | `Line` / `Label` / `Strip` helpers copied per tab | Players, Guilds, Filters, Events | W3 |
| G17 | W I G P C tick row built twice | `PSS_Players.lua`, `PSS_Guilds.lua` | W3 |
| G18 | Edit box placeholder hint hand-built twice | `PSS_Players.lua`, `PSS_Guilds.lua` | W3 |
| G19 | Multi-line text area is raw `CreateFrame("EditBox")`, twice | `PSS_Filters.lua`, `PSS_Popups.lua` | W3 |
| G20 | `b.pssPrimary = true; b.pssPaint()` pattern | Players, Guilds, Popups | W3 |
| G21 | Every filter block fires FILTERS_CHANGED: unthrottled Filters resort | core `PSS_ChatFilters.lua` with `PSS_Filters.lua` | F2 (3.4.1.42) |
| G22 | Selected guild's members walked twice per block redraw | `PSS_Guilds.lua`, Libraries `PSS_GuildView.lua` | W4 |
| G23 | Whole pane redrawn per block; exception tips built eagerly | Players, Guilds, Detail | W4 |
| G24 | Leaving one menu slot re-lays every slot | `PSS_Menu.lua` | W1 |
| G25 | Small per-call allocations | Kit, Window, Guilds, Filters, History, Players | W1 |
| G26 | Guild rows keep a stale "rule off" dim (no FILTERS_CHANGED listener) | `PSS_Guilds.lua` | F2 |
| G27 | Dark right-click menus capped at 200 px; width measured on visible slots only | `PSS_Menu.lua` | F2 |
| G28 | Modern art check covers only 8 of the atlases Modern draws | `PSS_Skin.lua` | F2 |
| G29 | Menu divider is 1 unit, not one physical pixel | `PSS_Menu.lua` | W1 |
| G30 | Two Exclusion "Remove" paths behave differently | `PSS_Guilds.lua` | Unscheduled (natural fit W2) |

Not in any appendix but scheduled: stage Fix (3.4.1.40), the detail pane wrap (plan 2.5, decision 23; `BuildGroupBody` and every fixed-height `Line()` stack in `PSS_Guilds.lua` and `PSS_Players.lua`).

### 3.3 Unscheduled findings in one list
N27 (Import Replace half), N29 (via N19 in P5), N30, N32, N33, N34, N36, N44 (with N14), G30. None is in the plan's stage table by id.

## 4. SavedVariables changes planned (appendix 03; plan 2.2, 2.3)

Upgrade step 9, "SavedVariables performance cleanup", stage S3 (3.4.1.48), one run-once step, Dan's OK given (decision 4, D9). Step 8 belongs to B1 (blizzardSync to per-player ticks, shipped 3.4.1.35). The appendices call this "step 8"; the plan renumbered it to 9.

| Store | Change | Measured (3.4.0.28 save unless noted) |
| --- | --- | --- |
| `PSS_GuildsDB.guildData[g].members` | Drop `_playerKey` (710 recs, 35.2 KB; always equals key), `_canon` / `_gkey` / `_managed` / `_virtual` (254 each; 11.6 / 7.5 / 5.5 KB) | Part of the -197 KB below |
| same | `guild` only when it differs from the rule's name (1205 of 1208 equal; 35.8 KB) | |
| same | `name` only when `TitleCase(key)` differs (1076 of 1208 derivable; 45.4 KB) | |
| same | No `whenBlocked` on managed records (253 hold "Managed list") | |
| same | `blockCounts` without zero fields (2416 zeros), `total` only when not the sum (69.7 KB) | |
| same | Cap 1500 stored members per rule (L16); `g.memberCount` no longer saved (L12) | |
| same | Camelot name repair (decision 5): Camelot saves only, only records with `faction` and no `_playerKey`: about 184 merged into shipped records, 48 into stored twins, about 267 re-keyed to `first last-realm`; first-name-only entries listed once in chat | 499 `first-last` member keys, 0 with block counts |
| `PSS_PlayersDB` | W I G P C saved only when false; no derivable `name`; sparse counts; lists drop `""` notes, `"player"` types, empty `syncInfo` | Dan's list is empty; synthetic 1000 players: 416.6 to 177.7 KB disk |
| `PSS_PlayersDB` keys, log owners `p:` / `g:` | Same Camelot conversion as members | |
| `PSS_LoggingDB.blockLog` (v2 groups) | Drop `m` when `TitleCase(owner key)` gives it; done in `PackForSave` at next logout, not a step | 204.7 vs 211.6 KB |
| Options | `showIgnoreDebug` no longer saved (N8) | |
| `PSS_RulesDB` / history / recent | Custom filters get a never-reused integer id; counter `nextFilterId` stored once; history and recent keyed `f:<id>` (N43, decision 3); built-ins keep `PSS00NN` | |
| `PourSocialScoreDB.purge` (new key in existing table, capped) | Purge tombstone: when Logging is not loaded, `purge[o]` is applied by `UnpackSaved` on next load; removal never loads Logging. Stage S1 (3.4.1.46), no layout OK needed per 03 | `ClearOwner` 71 us, 0 garbage vs `Clear(pred)` 5552 us, 750.5 KB garbage; tombstone 0.16 us |

Totals and rationale:

| Item | Value |
| --- | --- |
| guildData before / after (C1 sparse) | 391.5 to 194.0 KB disk; 1025.8 to 645.6 KB memory |
| Options file | 397.7 KB to about 196 KB (appendix: 189 to 200) |
| Always-loaded memory | down 380 to 440 KB (-37 to -43%) |
| Integer IDs for players / guilds | Rejected (decision 2): A0 saves 70 KB disk (11%) but needs an 81 KB name-to-ID index, memory goes up |
| Nested log under members (B) | Rejected: +116 KB always-loaded memory, breaks the Logging split |
| Optional later | C1t (`whenBlocked` as integer time, -11 KB disk, -58 KB memory); C2 packed member strings (guildData 383 KB memory). Not in the plan's stages |
| Accessors (S2, 3.4.1.47) | `M.PSS_MemberGuildName(m, gkey)`, `M.PSS_MemberCanon(k)`, `History.EnsureCounts`; rules-check grep for `_playerKey` / `_canon` / `_gkey` outside accessors |
| Validation | All four real saves (2.0.44, 3.0.0, 3.2.0-dev011, 3.4.0.28): counters identical, sizes before and after; 3.4.0.29 run once on a migrated save |

Forward compatibility (U3, 3.4.1.45; plan 2.3): `M.PSS_SCHEMA` (core, data only: every saved field, its reader and default; a rules check fails an unlisted field); tolerant readers (missing = default, unknown kept); deletion only of keys in `RETIRED`; step numbers only grow and are idempotent; the record keeps the highest version that wrote the save; a downgrade prints one line and runs nothing backwards; unusable rules (filter fails `M.PSS_CompileFilter`, guild rule kind or field not in the schema, option not in `M.PSS_OPTIONS`) are not applied, kept, reported, and exportable with `/pss export unused`; exports carry a format version and every field.

## 5. Upgrade helper essentials (appendix 04; plan 2.4)

Today: record `PourSocialScoreDB.upgrade = { step, version, at }`; steps 1 (every login, fields + data), 2 to 4 (3.0.0 moves), 5, 6 (3.4.0.22), 7 (3.4.0.25), 8 (B1, 3.4.1.35). Output is one line, `Saved data upgraded to X (step N).`; a version change with no step prints nothing. A part returning false pauses that step and all later ones for the login.

| Piece | Design |
| --- | --- |
| Registry (U1, 3.4.1.43, invisible) | `STEPS` array in `PSS_Upgrade.lua`: `{ id, feature, always, fields, data }`; ids never change; `fields` / `data` take `(db, out)`, return false to pause, else add counts to `out` (counts only, no strings) |
| Features | `filters` (Chat Filtering), `players` (Player Ignore List), `guilds` (Guild Ignore List), `managed` (Managed Communities), `history` (Block History), `options` (Options), `cleanup` (SavedVariables performance cleanup, always) |
| Step 1 | Split into feature-tagged sub-parts under id 1 (no renumbering); helpers gain count returns (`ApplyOptionDefaults`, `UnlinkGuildRuleCounts`, `ensureManagedRules`) |
| `RETIRED` | One list, one loop: `autoIgnore`, `autoUpdate`, `autoCount`, `autoTime`, `attachFriends`, `syncList`, `filterHistory`, `blockStats`, `optionsV2012`, `charOptions`, `historySize`, `euiIntegration`, `windowSizes`, `columnWidths` (later `memberCount`, and B1's `blizzardSync`, `showIgnoreDebug`) |
| `tally(out, feature, key, n)` | No-op when `out` is nil, so a normal login builds no strings (zero cost) |
| When it reports (U2, 3.4.1.44) | First login where `upgrade.version` differs or a step is due, not a fresh save; all lines at once, no timers (decision 9) |
| Format | Header "updated from A to B. Upgrading your saved data:"; one indented line per feature that changed (decision 7); the cleanup line always, with counts and size before and after; last line unchanged "Saved data upgraded to X (step N)."; existing move messages print before it (decision 8); at most 8 lines, ASCII, via `M.ShowMsg`; strings `L["UPG_*"]` |
| Pause | Red line "Saved data upgrade paused at step N: <reason>. It tries again at the next login." |
| Downgrade | One line "Running X, older than your saved data (Y). Nothing was upgraded."; the record keeps the newer version (decision 10) |
| Version compare | `X.Y.Z.B` by build; older names (`-devNNN`, plain `2.0.44`) order before any `X.Y.Z.B` |
| Harness | `check_upgrade_report.lua`, 10 cases (registry shape, 2.0.44 upgrade, same-version silence, fresh save, version-only bump, planted retired keys, downgrade, paused step, real saves, memory bound) plus "== upgrade report" in `validate_all.sh` |

## 6. Name bugs (appendix 05; plan 2.1)

Root cause, confirmed in game (Camelot, 2026-10-08): unit APIs return a surname where the realm goes; the rule is "the second value is a surname when `UnitRealmRelationship(unit)` is 1". Chat and /who give `First Last-Realm`.

| Bug / part | Status |
| --- | --- |
| `M.PSS_NormName(name, realm, unit)` in core `PSS_ChatBlock.lua`; name helpers call it; `check_names.lua` | Done, N1 (3.4.1.32, PR #120) |
| Callers: `scanUnit`, unit menu, `/pss add` target with `exactName`, Blizzard Ignore hooks fix `First-Last` via `M.PSS_FixUnitName`, self checks via `M.PSS_PlayerDisplayName`, `M.PSS_SplitNameArg` two-word names, import normalises and merges into shipped (`M.PSS_MergeIntoShipped`), `M.PSS_CharKey` through `PSS_NormName(..., "player")` | Done, N2 (3.4.1.33, PR #121) |
| `PSS_FlushManaged` stops writing `_canon`, `_gkey`, `_virtual` | Done, N2. `_managed` still written (member count reads it); goes in S2 / S3 |
| Builder rejects / converts surname-as-realm; lists rebuilt (212 names: 196 dropped, 16 converted; 7634 to 7438 entries; data file 349138 to 334806 bytes, 459.8 to 386.3 KB resident) | Done, N3 (3.4.1.37, PR #126) |
| Realm display spelling (`Classicbetapvp` from `V.serverName` vs `ClassicBetaPvP`) | Not changing: decision 13 reversed by Dan |
| Stored `First-Last` records (499 member keys on 3.4.0.28; delList `Hatti-Fnatt`, `Erlirrin-Softgale`), player-list keys, `p:` / `g:` log owners; first-name-only entries (e.g. `Archdruid-Classicbetapvp`) | Left for the S3 repair (step 9, Camelot saves only); first-name-only listed once in chat |
| `_managed` and remaining runtime fields on stored members | S2 accessors, S3 drop |

## 7. Older code review (`docs/latest/code-review/01_REVIEW_AND_PLAN.md`, main at 3.4.0-dev012)

| Items | Status |
| --- | --- |
| M1 to M9, M11, M12, L1 to L11, L13, L17 (window part), L18, L19, L21, L22 | Done in R1 (3.4.0.14, #106), R2 (3.4.0.15, #107), R3 (3.4.0.16, #108) |
| Decisions 1 to 6 | Answered 2026-10-08, all recommended; recorded in PSS 02 10.1, 10.3, section 4 |
| L12 (`memberCount` saved) | Folded: S3 |
| L16 (no member cap) | Folded: S3 (1500 per rule) |
| M10 / L14 (idle GC timer, 15 s ticker, `loadWhenQuiet` 30 s poll) | Folded: P2 (3.4.2); the known breach in 02 section 12 |
| L15 (capture and system-message events for everyone) | Folded: P3 |
| L17 (core per-line allocations) | Folded: P4 as N35 |
| L20 (core placement) | Folded: P6 with N37 to N39 |
| L4 (`RemoveMessagesByPredicate`) | Resolved as an approved override (decision 3) |

Nothing from the older review is left unfolded or unfixed.


## 8. Rules every planned change must keep

- Baseline rules are mandatory; PSS differs only where `docs/pss/02_RULES.md` section 12 lists it.
- Counters never come from log lines and stay identical across every data step (checked on Dan's four real saves: 2.0.44, 3.0.0, 3.2.0-dev011, 3.4.0.28).
- Zero cost when nothing upgrades; Logging loads only when called; no new SavedVariables files; no timers as logic gates.
- Every chat, unit and hook value goes through `M.PSS_IsSecret` before any compare (baseline 02 J, PSS 02 section 10).
- Window changes work in all three looks (Modern, Classic, Dark) and are proven with `tui_compare.sh`.
- Saves stay forward compatible after U3: unknown fields kept, only `RETIRED` keys deleted.

## 9. Found in this review and not in the plan (candidates, not decided)

These were found while mapping main at 3.4.1.38 and are in no stage by id. None is scheduled; each needs Dan's call before it joins a stage. Verified by reading the code; none tested in game.

| # | Where | Finding | Natural home |
| --- | --- | --- | --- |
| R1 | core `PSS_Upgrade.lua:478` `M.PSS_PrintValidation` | `/pss check` always prints "Last 24 hours: players 0, guilds 0, filters 0": it reads `stats24h.*` counts that `PSS_Validate` never sets (left from the retired `blockStats`) | P6 (N37 moves this file's validation to Libraries) |
| R2 | core `PSS_ChatFilters.lua` flood filter | A duplicate line is hidden with no count, no history line and no event; with `invertSpam` on, duplicates are still hidden. Possibly by design; the counting rule says every block counts | Ask Dan; F1 or P4 |
| R3 | core `PSS_PlayerIgnoreList.lua` `M.PSS_KeepBlockedOnBuiltIn` | When the shipped lists are not loaded (group rule off), a removed player who is a shipped member gets no "Removed from player list" note or block flags; if the rule is turned on later the member is not marked | S3 or F1 |
| R4 | core `PSS_GuildIgnoreList.lua` `inviteByGuild` | Stores a guild inviter as a member under the best rule even for your own guild; the own-guild check is only in `decide` (so nothing is blocked, but the record is stored) | F1 |
| R5 | core `PSS_PlayerIgnoreList.lua` `M.PSS_ResetBlizzardIgnore` | Calls `DelIgnoreByIndex` without the hook guard, so each removal runs PSS's post-hook. Harmless today (its only caller, `/pss clear confirm`, empties the PSS list first) | P5 |
| R6 | core `PSS_PlayerIgnoreList.lua` realm guess (the N14 block) | `sub(msg, pos + 9, (find ":" or find "|") - 1)` is arithmetic on nil for a malformed `|Hplayer:` link. Unreachable today (N14), goes with N14 in P1 | P1 |
| R7 | Libraries `PSS_EventsQuery.lua` `PSS_MemberEventsSpec` | The label is found only for members stored in `g.members`; for a shipped member with no own record the Events tab may fall back to the whole guild's label. Unverified in game | F1 (check first) |
| R8 | Libraries `PSS_Commands.lua` | `/pss clear` warning stays armed all session (`firstClear`), so a later `/pss clear confirm` skips a fresh warning; `/pss dellist` uses `print`, not `M.ShowMsg` (issue #44) | P1 or #44 |
| R9 | Libraries `PSS_GuildQuery.lua` `collectGuilds` | Writes `g.memberCount` into every saved rule on every list redraw (a direct save write from Libraries, not a core setter). S3 stops saving `memberCount` (L12); the write itself should go then too | S3 |
| R10 | Libraries `PSS_GuildQuery.lua` / `PSS_ViewNav.lua` | `guildGroupOpen` (reading it creates the table) and `windowPoints` are written directly (UI state; allowed as window state but not through a core setter) | W2 |
| R11 | core setters `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_SetGuildScanFields` | Fire no event; the Guilds tab redraws itself after them. Against baseline A9 (core fires a named event when data changes) | P5 or W2 |
| R12 | core `PSS_Whois.lua` | Fires `WHOIS_ANSWERED`, which nothing listens to | P1 |
| R13 | core `PSS_Localization.lua` | `INFO_5` and `INFO_6` assigned twice | P1 (N1) |
| R14 | core `PSS_GuildIgnoreList.lua` `ensureGuild`; `PSS_PlayerIgnoreList.lua` `ResetIgnoreDB` | Still write legacy `declineGuild`, `declineGroup`, `partyRaid`, `memberCount` on new rules and `showIgnoreDebug` on reset | S3 (sparse records) and N8 |
| R15 | Dead exports not named in N9 | `PSS_ListedBlockTotals`, `PSS_GetPlayerBlockTotals`, `PSS_HarvestStats`, `PSS_ScanCooldownRemaining`, `PSS_StartScanCooldown`, `PSS_GUILD_BLOCK_CATEGORIES`, `PSS_GUILD_BLOCK_LABELS`, `PSS_GuildEventCategory`, `PSS_ManagedGroupOfGuild`, `History.FormatCounts` (+ `M.PSS_FormatGuildCounts`, `M.PSS_FormatBlockCounts`). Check against N9's list before P1 | P1 |
| R16 | GUI tabs (Players, Guilds, Filters) | Only the Events tab releases what it read on close (`pg.release`); the other tabs keep list state and their History panes keep the last-read log lines (`hv.all`) for the session. The rule "the window drops what it read on close" holds only for Events | W4 |
| R17 | GUI `PSS_Skin.lua` header, page placeholders | `PSS_Skin.lua` still calls "blizzard" the default look and says Modern is not built; each page keeps a "comes in a later 3.4.0 build" placeholder (shown only if a tab builder errors) | W1 (G13, G14) |

## 10. Where the docs disagree (fix in the next docs touch)

| # | Disagreement | Which is right |
| --- | --- | --- |
| D1 | Appendices 03, 04, 05 call the data migration "step 8" | Plan: **step 9** (B1 took step 8) |
| D2 | PSS 02 section 4 and section 12 say the idle GC breach is fixed on "the 3.4.1 line" | Plan and 06: **P2 on 3.4.2** |
| D3 | Decision 22 says the release is 3.4.1.46 | Decision 23 and the stage table: **3.4.1.49** |
| D4 | Decision 14 says N2 "moves its per-character settings to the new key" | Plan 2.1: nothing is keyed by `M.PSS_CharKey`, nothing moved |
| D5 | N8 is in P1 (N1 to N15) and in S3 | S3 runs first; P1 has nothing left for N8 |
| D6 | N9 (P1) would delete `M.PSS_EnsureManagedRules` and `M.PSS_CompileFilter` | Keep both: N45 (F1) and U3 use them. N9 and N10 also overlap G12 (W1) |
| D7 | P1 deletes the reload popup (N3); the appendix preferred keeping it for N41 and called it Dan's call | Not recorded as a decision: ask Dan before P1 |
| D8 | N24 (two menu toggles) predates B2, which rebuilt the unit menu | Recheck N24 before P5 |
| D9 | Plan 2.4's example prints "PourSocialScore:"; `M.ShowMsg` prints "Pour Social Score:" | The harness should not match the example text |

## 11. Open issues and parked work (outside the stages)

| Item | Where it lands |
| --- | --- |
| #37 guild exclusion list not saved (intent to define) | Unscheduled |
| #38 seeing a shipped-guild member loads the lists | Unscheduled (N36 is related, a per-line cost) |
| #39, #40 unload the GUI / can an LOD addon unload | WoW cannot unload an addon; the window drops caches and requests GC on close; nothing more planned |
| #44 console output cleanup | Unscheduled (U2 changes upgrade output only) |
| #45 Questie-style upgrade output | U2 (3.4.1.44) |
| Parked: pack the in-play chat filter log | Offered, not started |
| Parked: Dashboard / overview page | Paused, branch `claude/project-thread-pa7y7o` |
| Parked: global moderation (sync, curated lists, scoring) | Not started |
| Optional save ideas: `whenBlocked` as integer time (C1t), packed member strings (C2) | Measured in appendix 03, not in any stage |
