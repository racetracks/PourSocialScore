# PourSocialScore: changes in train (state at 3.4.1.53, release of the core uplift)

**What this is.** A context document: what the core uplift changed, where, and what is still open after it, so a later session (Claude or GPT) can tell the shipped work apart from what is left. Read it with `12_CODE_MAP.md`. The source of truth stays the plan, `docs/pss/10_CORE_UPLIFT.md` (scratch `docs/latest/core-uplift/00_CORE_UPLIFT.md`), and the per-stage notes of the combined build in `docs/pss/reference/combined-3.4.1.52/`. Where this file and the plan differ, the plan wins.

## 0. In one screen

| Item | State on 2026-10-09 |
| --- | --- |
| Release | **3.4.1.53** (full; the core uplift; one summary of 3.4.1.30 to 3.4.1.52). The previous release is 3.4.0.29 (the new PSS window) |
| Main before the release | 3.4.1.52 (the combined build, PR #142) |
| Project | **Core uplift**, locked 2026-10-08, closed at this release. Its planned 3.4.2 and 3.4.3 stages were folded into 3.4.1.52 (decision 28) |
| Next | The chat path garbage plan (Dan, 2026-10-09; scratch `docs/latest/chat-garbage/`, waiting on Dan's decisions): the 3.4.2 line, first build **3.4.2.54** |
| Line 3.4.1 | Names (N1 to N3), Blizzard ignore authority (B1), the right-click PSS header (B2), detail pane fixes, bug fixes F1, window fixes F2, the upgrade registry, report and forward compatibility (U1 to U3), purge by owner (S1), accessors (S2), list records (S2b), then 3.4.1.52: step 10 sparse saves (S3), core performance (P1 to P6) and window tidy (W1 to W4) |
| Build numbers | `X.Y.Z.B`; B never resets; every build (stage, fix, release) takes the next one |
| How work is delivered | One stage per PR, one stage per session, based on main, test zip on scratch, Dan tests in game and merges. 3.4.1.52 was the one approved exception (02 section 12) |
| Left open | Section 3.3 (findings), section 9 (review findings), section 11 (issues and parked work) |

What did **not** change (decided): player and guild identity stays the lowercase `name-realm` key (no ID generator, decision 2); realm display spelling stays as it was (decision 13 reversed); no new SavedVariables files; the three looks and the window's layout stay.

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
| Docs | 3.4.1.38 | Harness notes for a list rebuild; docs only | No | Merged (#127) |
| Docs | 3.4.1.39 | The code map and this file; docs only | No | Merged (#128) |
| Fix | 3.4.1.40 | Guilds tab detail pane: a wrapped line pushes the lines and pies below it down (decision 23) | Yes | Merged (#129), did not take in game |
| Fix 2 | 3.4.1.41 | The same pane: the lines get a set width and their wrapped height (`FitLines`) | Yes | Merged (#130), works in game |
| F1 | 3.4.1.42 | N40 expiry applied, N41 hooks gated by option, N42 talent links, N45 Import Replace keeps shipped rules, N46 listener errors reported, N47 group warning list, N48 `/pss list` nil note | Yes | Merged (#131); in-game checks 4 and 7 left as #132, #133 |
| Docs | 3.4.1.43 | F1 marked merged; builds renumbered (decision 24); docs only | No | Merged (#134) |
| F2 | 3.4.1.44 | G21 filter redraw throttle with G26 rule dim refresh, G27 Dark menu height, G28 Modern art check | Yes (Dark menus) | Merged (#135) |
| U1 | 3.4.1.45 | Upgrade step registry, invisible (step 1 split and tagged, `RETIRED`, counts, version compare) | No | Merged (#136) |
| U2 | 3.4.1.46 | Upgrade report printed once per update (issue #45) | Once per update | Merged (#137) |
| U3 | 3.4.1.47 | Forward compatibility: `M.PSS_SCHEMA`, tolerant readers, downgrade line, unusable rules kept and reported, `/pss export unused`, export format 2 | Only when a rule cannot be used | Merged (#138) |
| U3 fix | 3.4.1.48 | The missing `local M` in `PSS_Popups.lua`; harness without a global `M`; `check_locals.lua` | Yes | Merged (#138) |
| S1 | 3.4.1.49 | `History.ClearOwner` and the purge tombstone (N16) | No | Merged (#139) |
| S2 | 3.4.1.50 | Accessors for the guild member fields, counts totals and `memberCount`; `check_fields.lua` | No | Merged (#140) |
| S2b | 3.4.1.51 | The player list arrays become one array of sparse records, `list` (decision 27); upgrade step 9 | No | Merged (#141) |
| S3 | 3.4.1.52 | Upgrade step 10 "SavedVariables performance cleanup": sparse records, cap 1500, no `memberCount`, Camelot repair, `showIgnoreDebug` gone, custom filter ids, W I G P C saved only when false, log `m` | Report, smaller save | Done in 3.4.1.52 (#142) |
| P1 to P6 | 3.4.1.52 | Core performance (section 2) | No (P3: a small behaviour change) | Done in 3.4.1.52 (#142) |
| W1 to W4 | 3.4.1.52 | Window tidy (section 2) | No (only the copy popup's edit box) | Done in 3.4.1.52 (#142) |
| R | 3.4.1.53 | Release; one summary of every change since 3.4.0.29; `01_HANDOVER.md` re-summarized | | This build |

The planned P and W stages (expected builds 3.4.2.54 to 3.4.3.65) are inside 3.4.1.52 (decision 28), so those numbers were never used for them. The next line, 3.4.2, is the chat path garbage plan and starts at 3.4.2.54.

## 2. What each stage touched in the code

Use with `12_CODE_MAP.md` to find the file.

| Stage | Files that changed (main ones) | Saved data? |
| --- | --- | --- |
| Fix, Fix 2 | GUI `PSS_Guilds.lua` (`BuildGroupBody`, `FitLines`) | No |
| F1 | core `PourSocialScore.lua` (login expiry, group warning), `PSS_PlayerIgnoreList.lua` (`M.PSS_ExpireEntries`), `PSS_BlizzardUI.lua` (hook bodies gated), `PSS_Events.lua` + `PSS_Whois.lua` (`M.PSS_NoteListenerError`), `PSS_ChatFilters.lua` (talent tag), `PSS_GuildIgnoreList.lua` (`M.PSS_ClearGuildRules`), Libraries `PSS_ImportExport.lua`, `PSS_Commands.lua` | No |
| F2 | core `PSS_ChatFilters.lua` (no `FILTERS_CHANGED` per block), GUI `PSS_Filters.lua`, `PSS_Guilds.lua`, `PSS_Menu.lua`, `PSS_Skin.lua` | No |
| U1 to U3 | core `PSS_Upgrade.lua` (registry, report, compare, unusable rules), new core `PSS_Schema.lua` (`M.PSS_SCHEMA`), `PSS_SavedData.lua`, Libraries `PSS_ImportExport.lua` (format 2, `more`), `PSS_Commands.lua` (`/pss export unused`), `tools/check_schema.lua`, `check_locals.lua` | Record keeps the highest version |
| S1 | core `PSS_ChatHistory.lua` (`History.ClearOwner`, `History.ApplyPurge`), the six owner clears | `PourSocialScoreDB.purge` (capped 200) |
| S2 | core `PSS_GuildIgnoreList.lua` (the `-- (member fields)` block), `History.CountTotal`; `tools/check_fields.lua` | No |
| S2b | core `PSS_PlayerIgnoreList.lua` (the `-- (list entries)` block), `PSS_Upgrade.lua` step 9 | **Yes**: `PourSocialScoreDB.list` |
| S3 | core `PSS_Upgrade.lua` step 10, `PSS_GuildIgnoreList.lua` (sparse members, `homeKey`, `M.PSS_CapMembers`), `PSS_ChatHistory.lua` (`History.CompactCounts`, `History.RenameOwner`), `PSS_ChatFilters.lua` (`M.PSS_NewFilterId`, `nextFilterId`), `PSS_PlayerIgnoreList.lua` (`M.PSS_CompactPlayers`), new Libraries `PSS_Camelot.lua` (the repair), Logging `PSS_SavedLog.lua` (`m`) | **Yes**: step 10, Dan's OK (D9) |
| P1 | Dead code across core (section 3.1) | No |
| P2 | core `PSS_Perf.lua` (event-driven GC, `M.PSS_GCWatch`), `PSS_ChatHistory.lua` (`History.LoadWhenQuiet`) | No |
| P3 | core `PSS_Whois.lua` (`Whois.SetCapture`), `PSS_GuildIgnoreList.lua` (`M.PSS_CaptureNeeded`, `M.PSS_ApplyCapture`) | No |
| P4 | core `PSS_ChatHistory.lua` (`History.Add`), `PSS_ChatBlock.lua` (`M.PSS_CanonGuild`), `PSS_ChatFilters.lua`, `PSS_PlayerIgnoreList.lua`, `PSS_GuildIgnoreList.lua`, `PSS_Options.lua` (`M.PSS_Opt`) | No |
| P5 | core `PSS_Globals.lua` (`M.MONTHS`), `PSS_ChatHistory.lua`, `PSS_GuildIgnoreList.lua`, `PSS_ChatFilters.lua` (`M.PSS_FILTER_ARRAYS`), `PSS_BlizzardUI.lua` (`addToggle`), Libraries `PSS_GuildQuery.lua`, `PSS_ImportExport.lua` | No |
| P6 | Moved to Libraries: `PSS_PlayerRows.lua` (player rows, sort, removal, `M.prettyServer`), `PSS_Validate.lua`, `PSS_WhoisHarvest.lua`; core keeps stubs (`M.PSS_Stub`) | No |
| W1 to W4 | GUI tabs and kit (`PSS_Kit.lua`, `PSS_Detail.lua`, `PSS_Rows.lua`, `PSS_Menu.lua`, `PSS_Window.lua`); logic to Libraries view files (`PSS_DetailQuery.lua`, `PSS_ViewNav.lua`, `PSS_GuildView.lua`, `PSS_PlayerView.lua`, `PSS_EventsView.lua`, `PSS_FilterView.lua`, `PSS_OptionsView.lua`) | No |

Measured (3.4.0.28 save, harness): `PSS_GuildsDB` 460,922 to 227,885 bytes; resident after login 3022.5 to 2731.6 KB for S3, then -20.4 KB (P1) and -63.0 KB core resident (P6). Details per stage in `reference/combined-3.4.1.52/`.

## 3. Every finding and where it landed

### 3.1 Core, Libraries, Logging, Options (appendix 01, N1 to N48)

| Id | What (one line) | File(s) | State |
| --- | --- | --- | --- |
| N1 | 61 English localization keys never read | `PSS_Localization.lua` | Done, P1 (3.4.1.52): 152 lines across locales |
| N2 | `V.needSorted` written, never read | `PSS_Globals.lua` and others | Done, P1 |
| N3 | Reload prompt dead | `PSS_Options.lua`, `PSS_BlizzardUI.lua` | Done, P1 (Dan, 2026-10-09: "remove in p1"): `PSS_RELOAD`, `M.PSS_AskReload`, `def.reload` and the `before` read gone |
| N4 | `gotUpdate` / `gotGroup` and the `IGNORELIST_UPDATE` registration on core's main frame | `PourSocialScore.lua` | Done, P1 |
| N5 | `PSS_MainlineCompat.lua` compat globals | `PSS_MainlineCompat.lua` | Done, P1: file deleted |
| N6 | `V.wowIsERA` .. `V.wowName` never read | `PSS_Globals.lua` | Done, P1 (`V.wowIsRetail` stays) |
| N7 | `M.debugMsg` is empty but callers still build strings | `PSS_PlayerIgnoreList.lua` and others | **Left**: P1 left it (same lines as S3 and P5) and P5 did not take it; 16 lines still call it |
| N8 | `showIgnoreDebug` written into every save | `PSS_Upgrade.lua`, `PSS_PlayerIgnoreList.lua` | Done, S3 (in `RETIRED`, no longer written) |
| N9 | About 25 dead `M.*` exports | several core files | Done, P1 (22 removed). Kept: `M.PSS_CompileFilter` (U3), `M.PSS_EnsureManagedRules`, `M.PSS_BLOCK_LABELS`. Restored at merge because S3 and P5 use them: `PSS_FindGuildRecord`, `PSS_CompactAllMembers`, `PSS_PlayerBlocksAnything` |
| N10 | Harness-only exports in shipped code | `PSS_ChatBlock.lua`, `PSS_DetailQuery.lua` | Done, P1: kept and labelled harness hooks (the checks need them) |
| N11 | `History.KeepAdd`, `MovePeople`, `MergeLists`, `Max`, `Combine` | `PSS_ChatHistory.lua` | Done, P1 |
| N12 | Unused locals | several | Done, P1 (`parseTimeString` restored at merge, P5 uses it) |
| N13 | `/pss test` is empty | `PSS_Commands.lua` | Done, P1 (the word falls to `/pss help`) |
| N14 | Unreachable realm-resolve block in `M.PSS_AddOrDelIgnore` | `PSS_PlayerIgnoreList.lua` | Done, P1 |
| N15 | `M.PSS_GUILD_SEARCH_OWNER` tag for the old window | `PSS_GuildView.lua`, GUI `PSS_Guilds.lua` | **Left**: P1 did not touch the GUI; the tag is still read by the window (harmless) |
| N16 | Six copies of the owner history clear | three core files | Done, S1 (3.4.1.49, `History.ClearOwner`) |
| N17 | 15 copies of "a stored member's canon key" | `PSS_GuildIgnoreList.lua` | Done, S2 (`M.PSS_MemberCanon`); one copy in member removal is not the same rule and stays |
| N18 | `findGuildRecord` vs `M.PSS_FindGuildRule` | `PSS_GuildIgnoreList.lua`, `PSS_GuildQuery.lua` | Done, P5 |
| N19 | Two date parsers, two month tables, per-call tables | `PSS_Globals.lua`, `PSS_ChatHistory.lua` | Done, P5 (`M.MONTHS`, today's day number kept per day) |
| N20 | Category list and labels defined twice | `PSS_ChatBlock.lua`, `PSS_ChatHistory.lua` | Done, P5 |
| N21 | W I G P C field lists spelled out many times | several | Done, P5 (`M.PSS_BLOCK_FIELDS`); `ALLOW_FLAGS` is a different set and stays |
| N22 | Parallel-array `table.remove` copies | several | Done: the list arrays went with S2b; P5 loops `M.PSS_FILTER_ARRAYS` |
| N23 | Five rules for "your target as a name to add" | `PSS_PlayerView`, `PSS_PlayerIgnoreList`, `PSS_Commands` | **Skipped**, P5: the rules differ on purpose (`/pss add` excludes player-controlled targets, the NPC toggle wants them); one helper would change behaviour |
| N24 | LFG and unit menu build the same toggle twice | `PSS_BlizzardUI.lua` | Done, P5 (`addToggle`) |
| N25 | Two "remove older than N days" loops | `PSS_PlayerIgnoreList.lua` | **Skipped**, P5: a shared helper measured -9 bytes compiled and +0.3 KB resident (the loops differ in direction, threshold and quiet flag) |
| N26 | Routed option reads cost about 2 us per chat line | `PSS_Options.lua`, `PSS_ChatFilters.lua` | Done, P4: `M.PSS_Opt` reads `PSS_OptionsDB` directly. The value cache was not built (options are written without `OPTION_CHANGED` by imports, resets and upgrades) |
| N27 | `History.Clear(pred)` per call on Import Replace | `PSS_ChatHistory.lua`, `PSS_ImportExport.lua` | Owner half done, S1. **Left**: a `ClearOwners(set)` for Import Replace is unscheduled |
| N28 | Guild path per chat line | `PSS_GuildIgnoreList.lua` | Done, P4 (6.9 to 5.3 us per line) |
| N29 | `M.daysFromToday` builds tables per call | `PSS_Globals.lua` | Done with N19 (P5); one `time{}` table per call remains |
| N30 | `M.PSS_GetGuildBlockCounts` recounts every member on every resort | `PSS_GuildIgnoreList.lua` | **Left** (unscheduled; G22 in W4 only avoids the double walk) |
| N31 | Outbox at cap: `table.remove(ob, 1)` per line | `PSS_ChatHistory.lua` | Done, P4 (17.4 to 2.7 us per line) |
| N32 | `M.PSS_RemoveGuild` walks the list per member; `removedGlobal` always 0 | `PSS_GuildIgnoreList.lua` | **Left** (unscheduled; still true) |
| N33 | `M.hasGlobalIgnored` linear scan before the index | `PSS_PlayerIgnoreList.lua` | **Left** (unscheduled; still true) |
| N34 | `CoreFilter` runs seven secret checks before the decision cache | `PSS_ChatBlock.lua` | **Left** (not in P4's scope) |
| N35 | Per-line tables on block paths | three core files | Done, P4 (about 630 to 385 bytes garbage per blocked line) |
| N36 | Every non-member sender costs three `sub` and a bucket `find` with shipped lists loaded | `PSS_GuildIgnoreList.lua` | **Left** (not in P4's scope) |
| N37 | `M.PSS_Validate` / `M.PSS_PrintValidation` resident in core | `PSS_Upgrade.lua` | Done, P6 (Libraries `PSS_Validate.lua`, -16.7 KB) |
| N38 | `REALM_PAIRS` / `M.prettyServer` resident in core | `PSS_Globals.lua` | Done, P6 (Libraries `PSS_PlayerRows.lua`, with the player rows, -28.7 KB) |
| N39 | Other L20 candidates | several core files | Partly done, P6: `PSS_WhoisHarvest.lua` moved (-17.6 KB). **Left** (section 3.3): `/pss mem`, `SyncIgnoreList`, `PruneIgnoreList`, `AddCapturedGuild` / `ReconcileGuildMembers`, `PSS_ExplainPerson`, `History.MigrateFilterList`, legacy import, the upgrade steps and schema map |
| N40 | Expiry never applied automatically | `PSS_PlayerIgnoreList.lua` | Done, F1 (3.4.1.42) |
| N41 | Menu / LFG hooks only if the option was on at login | `PSS_BlizzardUI.lua` | Done, F1; check 4 in game left as #132 |
| N42 | Talent link tag unknown to the filter language | `PSS_ChatFilters.lua` | Done, F1 |
| N43 | Custom filter history keyed by its text | `PSS_ChatFilters.lua` | Done, S3: integer ids (`nextFilterId`), history and recent on `f:<id>` |
| N44 | Realm guess in the dead N14 block | `PSS_PlayerIgnoreList.lua` | Done with N14 (P1) |
| N45 | Import Replace wipes shipped rules | `PSS_ImportExport.lua` | Done, F1 |
| N46 | Listener and /who handler errors swallowed | `PSS_Events.lua`, `PSS_Whois.lua` | Done, F1 |
| N47 | Group warning keeps everyone warned since joining | `PourSocialScore.lua` | Done, F1; check 7 in game left as #133 |
| N48 | `/pss list` errors on a nil note | `PSS_Commands.lua` | Done, F1 |

### 3.2 Window (appendix 02, G1 to G30)

| Id | What (one line) | File(s) (GUI unless noted) | State |
| --- | --- | --- | --- |
| G1 | History rows and tips copy Events formatting | `PSS_History.lua` | Done, W2 (`M.PSS_HistCells`, `M.PSS_HistTip`). Libraries `PSS_EventsView.lua` still has its own `TimeText` |
| G2 | Picker tick / "listed" strings built in two tabs | `PSS_Players.lua`, `PSS_Guilds.lua` | Done, W2 (`M.PSS_PickerCells`) |
| G3 | Guild tab reads rules and saved records directly | `PSS_Guilds.lua` | Done, W2 (pane views); the views still hand the record over for the tick boxes |
| G4 | Remove Guild target decided in the GUI | `PSS_Guilds.lua` | Done, W2 (`v:RemoveTarget()`) |
| G5 | GUI writes the view's `dirty` / `mdirty` | `PSS_Guilds.lua`, `PSS_Filters.lua` | Done: F2 (rule toggles), W2 (`v:MarkDirty`, the Filters line dropped) |
| G6 | Empty-list and hint texts chosen in the GUI | `PSS_Guilds.lua`, `PSS_History.lua` | Done, W2 |
| G7 | Each pane fills its Summary spec | Players, Guilds, Filters | Done, W2 (`M.PSS_*SummarySpec`) |
| G8 | Type-pie tip and spec copy in the GUI | `PSS_Detail.lua` | Done, W2 (`M.PSS_TypeTip`, `M.PSS_SpecCopy`) |
| G9 | Events tab reads `view.q` / `view.name` | `PSS_Events.lua` | Done, W2 |
| G10 | Import/Export raw `M.PSS_IO` reads | `PSS_Options.lua` | Done, W2 (`M.PSS_IOOn`, `M.PSS_IOMode`, `M.PSS_ImportStart`) |
| G11 | `M.PSS_EnsureMemberBlockData` called from a redraw | `PSS_Guilds.lua` | Done, W1 |
| G12 | Unreferenced ns / M names | several | Done, W1 (with `M.PSS_HexColor`, `M.PSS_TypeOff`, `M.PSS_AnyTypeOff`) |
| G13 | "comes in a later 3.4.0 build" placeholder | `PSS_Window.lua` | Done, W1 |
| G14 | Header comments describe two looks | Skin, Kit, Window, Rows | Done, W1 |
| G15 | Results picker built twice | Players, Guilds | Done, W3 (`ns.NewPicker`) |
| G16 | `Line` / `Label` / `Strip` copied per tab | four tabs | Done, W3 (`ns.NewLine`, `ns.NewLabel`, `ns.NewStrip`) |
| G17 | W I G P C tick row built twice | Players, Guilds | Done, W3 (`ns.NewAllowedBoxes`) |
| G18 | Edit box placeholder hand-built twice | Players, Guilds | Done, W3 (`ns.NewEditBox(..., hint)`) |
| G19 | Multi-line text area raw, twice | Filters, Popups | Done, W3 (`ns.NewTextArea`); the one visible change: the copy popup's edit box starts 300 wide and takes its real width from the scroll frame |
| G20 | `b.pssPrimary = true; b.pssPaint()` pattern | Players, Guilds, Popups | Done, W3 (`ns.NewButton(..., primary)`) |
| G21 | Every filter block fires FILTERS_CHANGED | core `PSS_ChatFilters.lua` | Done, F2 (3.4.1.44) |
| G22 | Selected guild's members walked twice per redraw | `PSS_Guilds.lua` | Done, W4 (`V.share`) |
| G23 | Whole pane redrawn per block; exception tips built eagerly | Players, Guilds, Detail | Done, W4 for Players and Guilds; the Chat Filters pane is unchanged (already throttled) |
| G24 | Leaving one menu slot re-lays every slot | `PSS_Menu.lua` | Done, W1 |
| G25 | Small per-call allocations | several | Done, W1 |
| G26 | Guild rows keep a stale "rule off" dim | `PSS_Guilds.lua` | Done, F2 |
| G27 | Dark right-click menus capped at 200 px | `PSS_Menu.lua` | Done, F2 (cap 400) |
| G28 | Modern art check covers 8 atlases | `PSS_Skin.lua` | Done, F2 (all 19) |
| G29 | Menu divider not one physical pixel | `PSS_Menu.lua` | Done, W1 |
| G30 | Two Exclusion "Remove" paths behave differently | `PSS_Guilds.lua` | **Left** (unscheduled; not in W2's list) |

Not in any appendix: stage Fix and Fix 2 (3.4.1.40, 3.4.1.41), the detail pane wrap. Other fixed-height `Line()` stacks in `PSS_Guilds.lua` and `PSS_Players.lua` were not changed; the harness stub does not wrap text, so only an in-game check with a large `uiFont` can show one.

### 3.3 Still open after 3.4.1.53

None of these is in a stage; each needs Dan's call before it joins one.
- **Findings left:** N7 (`M.debugMsg` callers), N15 (search owner tag), N23 and N25 (skipped on purpose, above), N27 (`ClearOwners(set)` for Import Replace), N30 (guild count cache), N32, N33, N34, N36, G30.
- **P6 moves skipped** (measured candidates; `reference/combined-3.4.1.52/_combined_notes_p6.md`): `/pss mem` (about 19 KB; P2 has merged, it needs a small GC state accessor), `M.SyncIgnoreList` and `M.PruneIgnoreList` (the hook guard is file local; J rules), `M.PSS_AddCapturedGuild` and `M.PSS_ReconcileGuildMembers` (21 KB; S3 has merged, so this can be looked at now), `M.PSS_ExplainPerson` (3.4 KB), `History.MigrateFilterList` (11.6 KB; runs every login, needs a guard first), the upgrade steps, `M.PSS_VersionOrder`, the unusable-rules code and the schema map.
- **Open points from the combined build** (`reference/combined-3.4.1.52/`):
  1. A custom filter with a number id is dropped by 3.4.0.29 and anything before 3.4.1.47: a downgrade past U3 after step 10 loses the custom filters (accepted as recommended; a downgrade past U3 was already unsupported).
  2. Older builds (3.4.1.50 and earlier, 3.4.0.29) read a migrated save without error and with the same member counters, but show an empty Player Ignore List (S2b), count a shipped record with no date as an extra member while the lists are not loaded, and read a player with only the guild invite blocked as fully allowed.
  3. The "first name only" Camelot entries cannot be found for sure; step 10 names list entries spelled `Name-Classicbetapvp` with a faction as "may have lost their surname".
  4. The 1500 member cap is enforced at the upgrade and at each logout, not on each capture.
  5. Two filters sharing one text: the first takes the shared history.
  6. P3 behaviour change: with every shipped list off and nobody listed, units and hand-typed /who results no longer touch inactive shipped guild rules.
  7. `stats` in `PSS_WhoisHarvest.lua` is written and never read (its reader `PSS_HarvestStats` went in P1).
  8. The edit box hint hooks `OnTextChanged`: a caller must not `SetScript` it on a hinted box.
- **Waiting on Dan:** the `SCRATCH_TOKEN` secret for the CI real-save job (decision 29); `/pss export unused` from his 3.4.1.50 login (2 custom rules reported unusable), to tell whether they are newer rules or a false rejection by U3's check.

## 4. SavedVariables changes (appendix 03; plan 2.2, 2.3)

Done. Step 8 is B1's (3.4.1.35), step 9 S2b's (3.4.1.51, the list records), step 10 S3's (3.4.1.52, "SavedVariables performance cleanup"), Dan's OK given (decision 4, D9).

| Store | Change | State |
| --- | --- | --- |
| `PSS_GuildsDB.guildData[g].members` | No `_playerKey` (when equal to the key), `_canon`, `_gkey`, `_managed`, `_virtual`; `name` only when not derivable; `guild` only when not the rule's; no "Managed list" date | Done, S3 (accessors from S2; the record's key from the weak map `homeKey`) |
| same | Counts without zero fields, `total` only when not the sum (`History.CompactCounts`) | Done, S3 |
| same | Cap 1500 stored members per rule (L16); `g.memberCount` no longer saved (L12) | Done, S3 |
| same | Camelot name repair, Camelot saves only (Libraries `PSS_Camelot.lua`) | Done, S3: Dan's 3.4.0.28 save on a Camelot stub, 498 members repaired, 3 `delList` names, counts identical |
| `PourSocialScoreDB.list` | The seven parallel arrays become one array of sparse records | Done, S2b |
| `PSS_PlayersDB.playerData` | W I G P C saved only when false; sparse counts | Done, S3 (`M.PSS_CompactPlayers`) |
| Player keys, log owners `p:` / `g:` | Camelot conversion | Done, S3 (`History.RenameOwner`) |
| `PSS_LoggingDB.blockLog` | Group `m` not saved when derivable (`false` for a group with no name) | Done, S3 (at logout) |
| Options | `showIgnoreDebug` no longer saved (N8) | Done, S3 |
| `PSS_RulesDB` / history / recent | Custom filter ids, `nextFilterId`; history and recent on `f:<id>` (N43) | Done, S3 |
| `PourSocialScoreDB.purge` | Purge tombstone, cap 200 | Done, S1 |

| Item | Value |
| --- | --- |
| `PSS_GuildsDB` (harness serializer, 3.4.0.28 save) | 460,922 to 227,885 bytes (-50.6%); whole file 730,451 to 483,745 |
| Resident after login | 3022.5 to 2731.6 KB (-290.9 KB); the migrating login is 3774.3 KB once (it loads Logging for custom filters with counts) |
| Integer IDs for players / guilds | Rejected (decision 2) |
| Optional later | C1t (`whenBlocked` as integer time), C2 packed member strings. Not in any stage |
| Validation | `sparse_saves.sh` on 53 saves (fresh, planted, the 2.0 test saves, the five real saves) shows the same for every record, number and total before and after; 3.4.0.29 reads a migrated save with no Lua error |

Forward compatibility (U3, 3.4.1.47): `M.PSS_SCHEMA` lists every saved field (`check_schema.lua`); unknown fields kept; only `RETIRED` keys deleted; steps only grow and are safe to run twice; a downgrade prints one line; unusable rules are kept, reported and exportable (`/pss export unused`); exports carry format 2 and `more`.

## 5. Upgrade helper (appendix 04; plan 2.4)

Done (U1 3.4.1.45, U2 3.4.1.46, U3 3.4.1.47). Record `PourSocialScoreDB.upgrade = { step, version, at }`; steps 1 (every login, fields and data), 2 to 4 (3.0.0 moves), 5, 6, 7, 8 (B1), 9 (S2b), 10 (S3).

| Piece | As built |
| --- | --- |
| Registry | `STEPS` in `PSS_Upgrade.lua`: `{ id, always, parts }`, each part `{ feature, fields, data }`; counts through `tally(feature, key, n)`, a no-op on a login that does not report |
| Features | `filters`, `players`, `guilds`, `managed`, `history`, `options`, `cleanup` (always printed) |
| `RETIRED` | One list, dropped every login after the data parts; S3 added `showIgnoreDebug` and the members' `memberCount` |
| Report | Head line, a line per feature that changed, the cleanup line always, then "Saved data upgraded to X (step N)."; a paused step prints a red line; printed at the first login after any version change, even when nothing changed (Dan, 2026-10-09) |
| Downgrade | One line every login while the save is newer; the record keeps the newer version |
| Version compare | `M.PSS_VersionOrder`: `X.Y.Z.B` by its numbers; older names before any `X.Y.Z.B` |
| Harness | `check_upgrade_steps.lua`, `check_upgrade_report.lua` (10 cases), `check_forward.lua`, `check_sparse.lua`, `check_listrecords.lua` |

## 6. Name bugs (appendix 05; plan 2.1)

Root cause, confirmed in game (Camelot, 2026-10-08): unit APIs return a surname where the realm goes; the second value is a surname when `UnitRealmRelationship(unit)` is 1.

| Bug / part | State |
| --- | --- |
| `M.PSS_NormName(name, realm, unit)`; name helpers call it | Done, N1 (3.4.1.32) |
| Every caller, `M.PSS_FixUnitName`, `M.PSS_SplitNameArg`, import merge, `M.PSS_CharKey` | Done, N2 (3.4.1.33) |
| Runtime fields not flushed | `_canon`, `_gkey`, `_virtual` in N2; `_managed` in S3 |
| Builder and shipped lists rebuilt | Done, N3 (3.4.1.37) |
| Realm display spelling | Not changing (decision 13 reversed) |
| Stored `First-Last` records, list keys, log owners, `delList` | Done, S3 (step 10, Camelot saves only) |

## 7. Older code review (`docs/latest/code-review/01_REVIEW_AND_PLAN.md`)

| Items | State |
| --- | --- |
| M1 to M9, M11, M12, L1 to L11, L13, L17 (window part), L18, L19, L21, L22 | Done in R1 to R3 (3.4.0.14 to 3.4.0.16) |
| L12 (`memberCount` saved), L16 (no member cap) | Done, S3 |
| M10 / L14 (idle GC timer, ticker, `loadWhenQuiet` poll) | Done, P2; the last known breach is gone (02 section 12) |
| L15 (capture events for everyone) | Done, P3 |
| L17 (core per-line allocations) | Done, P4 (N35) |
| L20 (core placement) | Partly done, P6; the skipped moves are in section 3.3 |
| L4 (`RemoveMessagesByPredicate`) | An approved override (decision 3) |

## 8. Rules every change keeps

- Baseline rules are mandatory; PSS differs only where `docs/pss/02_RULES.md` section 12 lists it.
- Counters never come from log lines and stay identical across every data step (checked on Dan's real saves).
- Zero cost when nothing upgrades; Logging loads only when called; no new SavedVariables files; no timers as logic gates.
- Every chat, unit and hook value goes through `M.PSS_IsSecret` before any compare (baseline 02 J, PSS 02 section 10).
- Window changes work in all three looks and are proven with `tui_compare.sh`.
- Saves stay forward compatible: any new saved field goes in `M.PSS_SCHEMA` in the same PR.

## 9. Found in the 3.4.1.38 review and not in the plan

Checked against the code at 3.4.1.52. Open items need Dan's call before they join a stage.

| # | Where | Finding | State |
| --- | --- | --- | --- |
| R1 | Libraries `PSS_Validate.lua` (`M.PSS_PrintValidation`, moved by P6) | `/pss check` prints "Last 24 hours" from `stats24h.*`, which `PSS_Validate` never sets | **Open** |
| R2 | core `PSS_ChatFilters.lua` flood filter | A duplicate line is hidden with no count, history line or event; with `invertSpam` on, duplicates are still hidden | **Open** (ask Dan; possibly by design) |
| R3 | core `M.PSS_KeepBlockedOnBuiltIn` | With the shipped lists not loaded, a removed player who is a shipped member gets no note or block flags | **Open** |
| R4 | core `PSS_GuildIgnoreList.lua` `inviteByGuild` | Stores a guild inviter as a member even for your own guild (nothing is blocked) | **Open** |
| R5 | core `PSS_ResetBlizzardIgnore` | Calls `DelIgnoreByIndex` without the hook guard (harmless today) | **Open** |
| R6 | the N14 realm guess | Arithmetic on nil for a malformed link | Gone with N14 (P1) |
| R7 | Libraries `PSS_GuildView.lua` `M.PSS_MemberEventsSpec` | The label for a shipped member with no own record may fall back to the guild's; unverified in game | **Open** (check first) |
| R8 | Libraries `PSS_Commands.lua` | `/pss clear` warning stays armed all session (`firstClear`); `/pss dellist` uses `print` (issue #44) | **Open** |
| R9 | Libraries `PSS_GuildQuery.lua` `collectGuilds` | Wrote `g.memberCount` on every redraw | Fixed, S3 (`memberCount` no longer saved or written) |
| R10 | Libraries `PSS_GuildQuery.lua` / `PSS_ViewNav.lua` | `guildGroupOpen` (reading it creates the table) and `windowPoints` written directly | **Open** (window state; W2 did not take it) |
| R11 | core `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_SetGuildScanFields` | Fire no event (baseline A9) | **Open** |
| R12 | core `PSS_Whois.lua` | Fires `WHOIS_ANSWERED`, which nothing listens to | **Open** |
| R13 | core `PSS_Localization.lua` | `INFO_5` and `INFO_6` assigned twice | **Open** (P1's N1 kept both) |
| R14 | core `PSS_GuildIgnoreList.lua` `ensureGuild`; `ResetIgnoreDB` | Legacy `declineGuild`, `declineGroup`, `partyRaid` still written on new rules | Partly fixed: `memberCount` and `showIgnoreDebug` gone (S3); the three legacy fields **open** |
| R15 | Dead exports not named in N9 | `PSS_ListedBlockTotals`, `PSS_HarvestStats` and the rest | Fixed, P1 |
| R16 | GUI tabs | Only tabs with a `release` drop what they read on close (Events); Players, Guilds and Filters keep their list state and History panes | **Open** |
| R17 | GUI `PSS_Skin.lua` header, page placeholders | Old look names and placeholders | Fixed, W1 (G13, G14) |

## 10. Where the docs disagree (fix in the next docs touch)

| # | Disagreement | Which is right |
| --- | --- | --- |
| D1 | Appendices 03, 04, 05 (scratch) call the data migration "step 8" | Plan: **step 10** (B1 took 8, S2b took 9) |
| D3 | Decisions 22 to 26 name older release builds and give the P and W stages builds on lines 3.4.2 and 3.4.3 | Decision 28 and the stage table: the release is **3.4.1.53** and those stages are in 3.4.1.52; 3.4.2 is now the chat path garbage line (3.4.2.54 on) |
| D4 | Decision 14 says N2 "moves its per-character settings to the new key" | Plan 2.1: nothing is keyed by `M.PSS_CharKey`, nothing moved |
| D9 | Plan 2.4's example prints "PourSocialScore:" and "(step 9)"; `M.ShowMsg` prints "Pour Social Score:" and step 10 is the last | The code; the harness does not match the example text |

Fixed since 3.4.1.39: D2 (the GC breach is fixed, P2 in 3.4.1.52), D5 (N8 went to S3 only), D6 (`M.PSS_EnsureManagedRules` and `M.PSS_CompileFilter` kept), D7 (Dan chose to remove the reload popup, P1), D8 (N24 rechecked and done in P5).

## 11. Open issues and parked work (outside the stages)

| Item | State |
| --- | --- |
| #37 guild exclusion list not saved (intent to define) | Open, unscheduled |
| #38 seeing a shipped-guild member loads the lists | Open, unscheduled (N36 is related); P3 stops units and /who touching inactive shipped rules |
| #39, #40 unload the GUI / can an LOD addon unload | Open; WoW cannot unload an addon. The window drops caches and requests GC on close; R16 is the part left |
| #44 console output cleanup | Open, unscheduled (R8's `print`) |
| #45 Questie-style upgrade output | Done, U2 (3.4.1.46); the issue can close |
| #132 the Group Finder option without a /reload (F1 check 4) | Open: test later on a character that can use the Group Finder |
| #133 the party warning names only who is in the group now (F1 check 7) | Open: test later |
| Chat path garbage (about 800 bytes per line) | Next: plan on scratch `docs/latest/chat-garbage/`, line 3.4.2 from 3.4.2.54, waiting on Dan's decisions. N34 and N36 are natural parts of it |
| `/pss mem` collects before it reads (shows live memory) | Offered, Dan did not pick it |
| 3.4.1.52's in-game checks (PR #142, 1 to 12) | Not reported yet; run on 3.4.1.53 |
| Parked: pack the in-play chat filter log | Offered, not started |
| Parked: Dashboard / overview page | Paused, branch `claude/project-thread-pa7y7o` |
| Parked: global moderation (sync, curated lists, scoring) | Not started |
| Optional save ideas: C1t, C2 | Measured in appendix 03, not in any stage |
