# PourSocialScore: changes in train (2026-10-09, state at the 3.4.1.53 release)

**What this is.** A context document: what the core uplift changed, where, and what is still open after it, so a later session (Claude or GPT) can tell the shipped changes from the open ones. Read it with the code map (scratch `docs/latest/code-map/`). The source of truth stays the plan, `docs/pss/10_CORE_UPLIFT.md` (scratch `docs/latest/core-uplift/00_CORE_UPLIFT.md`), and the per-stage notes of the combined build in `docs/pss/reference/combined-3.4.1.52/`. Where this file and the plan differ, the plan wins; where either differs from the code, the code wins.

## 0. In one screen

| Item | State at 3.4.1.53 |
| --- | --- |
| Release | **3.4.1.53** (full; closes the core uplift; release PR #143, live once Dan merges it); the previous release was 3.4.0.29 |
| Last pre-release | 3.4.1.52, the combined build (S3, P1 to P6, W1 to W4; decision 28), PR #142, merged |
| Project | **Core uplift**: every stage built; it closes with this release |
| Line 3.4.1 | Names, Blizzard ignore authority, right-click PSS header, shipped lists rebuilt, detail pane fixes, F1, F2, upgrade registry, report and forward compatibility, purge by owner, accessors, player list records, step 10 sparse saves (3.4.1.30 to 3.4.1.52) |
| Lines 3.4.2, 3.4.3 | **Not used.** Their stages (P1 to P6, W1 to W4) are inside 3.4.1.52 (decision 28); their expected builds (3.4.2.54 to 3.4.3.65) were never taken |
| Build numbers | `X.Y.Z.B`; B never resets; the next build after the release is 3.4.x.54 |
| How work is delivered | One stage per PR and per session, based on main (decision 28 was a one-time override, 02 section 12) |

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
| Fix 2 | 3.4.1.41 | The same pane: set width and wrapped height (`FitLines`) | Yes | Merged (#130), works in game |
| F1 | 3.4.1.42 | N40, N41, N42, N45, N46, N47, N48 | Yes | Merged (#131); in-game checks 4 and 7 deferred (#132, #133) |
| Docs | 3.4.1.43 | F1 marked merged; later builds renumbered (decision 24); docs only | No | Merged (#134) |
| F2 | 3.4.1.44 | G21 with G26, G27, G28 | Yes (Dark menus) | Merged (#135) |
| U1 | 3.4.1.45 | Upgrade step registry, invisible | No | Merged (#136) |
| U2 | 3.4.1.46 | Upgrade report printed once per update (issue #45) | Once per update | Merged (#137) |
| U3 | 3.4.1.47 | Forward compatibility: `M.PSS_SCHEMA`, tolerant readers, downgrade line, unusable rules, `/pss export unused`, export format 2 | Only when a rule cannot be used | Merged (#138) |
| U3 fix | 3.4.1.48 | The missing `local M` in `PSS_Popups.lua`; no global `M` in the harness; `check_locals.lua` | Yes | Merged (#138) |
| S1 | 3.4.1.49 | `History.ClearOwner` and the purge tombstone (N16) | No | Merged (#139) |
| S2 | 3.4.1.50 | Accessors for the guild member fields, counts totals and `memberCount`; `check_fields.lua` | No | Merged (#140) |
| S2b | 3.4.1.51 | The player list arrays become one array of sparse records, `list` (decision 27); upgrade step 9 | No (report line once) | Merged (#141) |
| Combined | 3.4.1.52 | S3 (upgrade step 10, sparse saves, cap, Camelot repair, filter ids), P1 to P6, W1 to W4 (decision 28) | Report, smaller save | Merged (#142) |
| R | 3.4.1.53 | Release: one summary of every change since 3.4.0.29; `01_HANDOVER.md` re-summarized | | This release |

## 2. What each stage touched in the code

Use with the code map (scratch `docs/latest/code-map/` (https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/latest/code-map)) to find the file.

| Stage | Files that changed (main ones) | Saved data? |
| --- | --- | --- |
| Fix, Fix 2 | GUI `PSS_Guilds.lua` (`BuildGroupBody`, `FitLines`) | No |
| F1 | core `PourSocialScore.lua` (login expiry, group warning), `PSS_PlayerIgnoreList.lua` (`M.PSS_ExpireEntries`), `PSS_BlizzardUI.lua` (hook bodies gated), `PSS_Events.lua` (`M.PSS_NoteListenerError`), talent tag in `PSS_ChatFilters.lua` / Libraries `PSS_FilterQuery.lua`, `M.PSS_ClearGuildRules` (`PSS_GuildIgnoreList.lua`), Libraries `PSS_Commands.lua` | No |
| F2 | core `PSS_ChatFilters.lua`, GUI `PSS_Filters.lua`, `PSS_Guilds.lua`, `PSS_Menu.lua`, `PSS_Skin.lua` | No |
| U1 to U3 | core `PSS_Upgrade.lua` (registry, report, compare, unusable rules), new core `PSS_Schema.lua`, `PSS_Localization.lua` (`UPG_*`), Libraries `PSS_ImportExport.lua` (format 2, `more`), `PSS_Commands.lua` (`/pss export unused`), GUI `PSS_Popups.lua`; `tools/check_schema.lua`, `check_locals.lua` | Record keeps the highest version |
| S1 | core `PSS_ChatHistory.lua` (`History.ClearOwner`, `History.ApplyPurge`), the six owner clears; `PourSocialScoreDB.purge` | New capped key in an existing table |
| S2 | core `PSS_GuildIgnoreList.lua` (the `-- (member fields)` block), `History.CountTotal`; `tools/check_fields.lua` | No |
| S2b | core `PSS_PlayerIgnoreList.lua` (the `-- (list entries)` block), `PSS_Upgrade.lua` step 9 | **Yes** (`PourSocialScoreDB.list`) |
| S3 | `PSS_Upgrade.lua` step 10, the member block in `PSS_GuildIgnoreList.lua` (`homeKey`, `compactMember`, `M.PSS_CapMembers`), `PSS_PlayerIgnoreList.lua` (W I G P C only when false), `PSS_ChatFilters.lua` (`M.PSS_NewFilterId`), `PSS_ChatHistory.lua` (`History.CompactCounts`, `History.RenameOwner`), Logging `PSS_SavedLog.lua` (log `m`), new Libraries `PSS_Camelot.lua` | **Yes**: Dan's OK given (D9) |
| P1 | Dead code across core and Libraries (N1 to N6, N9, N11 to N14); `PSS_MainlineCompat.lua` deleted | No |
| P2 | `PSS_Perf.lua` (no timer), `History.LoadWhenQuiet` | No |
| P3 | `PSS_Whois.lua`, `M.PSS_CaptureNeeded` / `M.PSS_ApplyCapture` in `PSS_GuildIgnoreList.lua` | No |
| P4 | `History.Add` (outbox), `M.PSS_CanonGuild`, `M.PSS_Opt`, the player and guild sources | No |
| P5 | Shared helpers for N18 to N22, N24 (`M.MONTHS`, `M.PSS_BLOCK_FIELDS`, `M.PSS_FILTER_ARRAYS`, `addToggle`) | No |
| P6 | New Libraries `PSS_PlayerRows.lua` (from core `PSS_PlayerQuery.lua` and `M.prettyServer`), `PSS_Validate.lua` (from `PSS_Upgrade.lua`), `PSS_WhoisHarvest.lua` (from core); stubs left in core | No |
| W1 to W4 | GUI tabs; W2 moved logic to Libraries view files (`PSS_DetailQuery`, `PSS_GuildView`, `PSS_PlayerView`, `PSS_ViewNav`, `PSS_EventsView`, `PSS_FilterView`, `PSS_OptionsView`); W3 added kit functions (`ns.NewTextArea`, `ns.NewPicker`, `ns.NewLine`, `ns.NewLabel`, `ns.NewStrip`, `ns.NewAllowedBoxes`, hinted edit box, primary button) | No |

## 3. Every finding and where it landed

### 3.1 Core, Libraries, Logging, Options (appendix 01, N1 to N48)

38 done, 10 open (2 skipped on purpose, 1 partly done, 7 never scheduled or left).

| Id | What (one line) | File(s) | State |
| --- | --- | --- | --- |
| N1 | 61 unused English localization keys | `PSS_Localization.lua` | Done 3.4.1.52 (P1; 152 lines across locales) |
| N2 | `V.needSorted` written, never read | several | Done 3.4.1.52 (P1) |
| N3 | Reload popup dead (`PSS_RELOAD`, `M.PSS_AskReload`, `before` in `PSS_SetOpt`) | `PSS_Options.lua`, `PSS_BlizzardUI.lua` | Done 3.4.1.52 (P1; Dan, 2026-10-09: "remove in p1") |
| N4 | `gotUpdate` / `gotGroup` and their `IGNORELIST_UPDATE` registration | `PourSocialScore.lua` | Done 3.4.1.52 (P1) |
| N5 | `PSS_MainlineCompat.lua` globals | `PSS_MainlineCompat.lua` | Done 3.4.1.52 (P1; file deleted) |
| N6 | `V.wowIsERA` .. `V.wowName` never read | `PSS_Globals.lua` | Done 3.4.1.52 (P1) |
| N7 | `M.debugMsg` empty, callers still build strings | `PSS_PlayerIgnoreList.lua`, `PSS_Globals.lua` | **Open.** P1 left it for P5, P5 did not take it; about 15 callers remain in `PSS_PlayerIgnoreList.lua` (the error half was N46, F1) |
| N8 | `showIgnoreDebug` written every login | `PSS_Upgrade.lua` | Done 3.4.1.52 (S3: in `RETIRED`, no longer written) |
| N9 | About 25 dead `M.*` exports | several | Done 3.4.1.52 (P1, 24 removed; `PSS_CompileFilter` and `PSS_EnsureManagedRules` kept) |
| N10 | Harness-only exports in shipped code | `PSS_ChatBlock.lua` and others | Done 3.4.1.52 (P1: kept on purpose, labelled as harness hooks) |
| N11 | `History.KeepAdd`, `MovePeople`, `MergeLists`, `Combine`, `Max` | `PSS_ChatHistory.lua` | Done 3.4.1.52 (P1) |
| N12 | Unused locals | several | Done 3.4.1.52 (P1) |
| N13 | `/pss test` empty | `PSS_Commands.lua` | Done 3.4.1.52 (P1) |
| N14 | Dead realm-resolve block in `M.PSS_AddOrDelIgnore`; `pServers` | `PSS_PlayerIgnoreList.lua` | Done 3.4.1.52 (P1) |
| N15 | `M.PSS_GUILD_SEARCH_OWNER` tag for the old window | Libraries `PSS_GuildView.lua`, GUI `PSS_Guilds.lua` | **Open.** P1 left it (GUI file); still used as the window's search tag |
| N16 | Six copies of the owner clear | three core files | Done 3.4.1.49 (S1, `History.ClearOwner`) |
| N17 | 15 copies of a member's canon key | `PSS_GuildIgnoreList.lua` | Done 3.4.1.50 (S2 `M.PSS_MemberCanon`); one copy in the member removal differs on purpose (P5) |
| N18 | `findGuildRecord` vs `M.PSS_FindGuildRule` | core, Libraries | Done 3.4.1.52 (P5) |
| N19 | Two date parsers, two month tables | `PSS_Globals.lua`, `PSS_ChatHistory.lua` | Done 3.4.1.52 (P5, `M.MONTHS`, one match) |
| N20 | Category list and labels twice | several | Done 3.4.1.52 (P5) |
| N21 | W I G P C field lists in eight places | several | Done 3.4.1.52 (P5, `M.PSS_BLOCK_FIELDS`) |
| N22 | Parallel-array `table.remove` copies | several | Done 3.4.1.52 (P5 `M.PSS_FILTER_ARRAYS`; the list arrays went with S2b) |
| N23 | Five rules for "your target as a name to add" | Libraries, core | **Open, skipped on purpose** (P5): the rules differ by design; one helper would change behaviour |
| N24 | LFG and unit menu build the same toggle twice | `PSS_BlizzardUI.lua` | Done 3.4.1.52 (P5, `addToggle`) |
| N25 | Two "remove older than N days" loops | `PSS_PlayerIgnoreList.lua` | **Open, skipped on purpose** (P5): a shared helper measured -9 bytes compiled and +0.3 KB resident |
| N26 | Routed option reads cost about 2 us per chat line | `PSS_Options.lua`, sources | Done 3.4.1.52 (P4: `M.PSS_Opt` reads `PSS_OptionsDB` directly; no value cache, on purpose) |
| N27 | `History.Clear(pred)` unpacks every kept line; many calls on Import Replace | `PSS_ChatHistory.lua`, `PSS_ImportExport.lua` | Done 3.4.1.49 in practice (S1: each removal is a cheap `ClearOwner`); a batched `ClearOwners(set)` was not built |
| N28 | Guild path per chat line | `PSS_GuildIgnoreList.lua`, `PSS_ChatBlock.lua` | Done 3.4.1.52 (P4: 6.9 to 5.3 us) |
| N29 | `M.daysFromToday` builds tables per call | `PSS_Globals.lua` | Done 3.4.1.52 (via N19: one match, today's day number kept) |
| N30 | `M.PSS_GetGuildBlockCounts` recounts every member on every resort | `PSS_GuildIgnoreList.lua` | **Open, never scheduled** (G22 in W4 only avoids the second walk) |
| N31 | Outbox at cap: one `table.remove(ob, 1)` per line | `PSS_ChatHistory.lua` | Done 3.4.1.52 (P4: 17.4 to 2.7 us) |
| N32 | `M.PSS_RemoveGuild` walks the ignore list per member; `removedGlobal` always 0 | `PSS_GuildIgnoreList.lua` | **Open, never scheduled** |
| N33 | `M.hasGlobalIgnored` linear scan before the index | `PSS_PlayerIgnoreList.lua` | **Open, never scheduled** |
| N34 | `CoreFilter` runs seven `isSecret` calls before the cache lookup | `PSS_ChatBlock.lua` | **Open, never scheduled** (outside P4's scope) |
| N35 | Per-line tables on block paths | sources | Done 3.4.1.52 (P4: 633 to 385 B per blocked whisper) |
| N36 | With shipped lists loaded, three `sub` and a `find` per non-member line | `PSS_GuildIgnoreList.lua` | **Open, never scheduled** (outside P4's scope) |
| N37 | `M.PSS_Validate` resident in core | `PSS_Upgrade.lua` | Done 3.4.1.52 (P6, Libraries `PSS_Validate.lua`, -16.7 KB) |
| N38 | `REALM_PAIRS` / `M.prettyServer` resident in core | `PSS_Globals.lua` | Done 3.4.1.52 (P6, Libraries `PSS_PlayerRows.lua`) |
| N39 | Other core placement candidates (about 105 KB) | several | **Partly done** 3.4.1.52 (P6 moved the Scan All planner; -63.0 KB in all). Left: `/pss mem`, `M.PSS_AddCapturedGuild` / `M.PSS_ReconcileGuildMembers`, `M.PSS_ExplainPerson`, `History.MigrateFilterList`, the upgrade steps and schema (section 11) |
| N40 | Expiry never applied automatically | core | Done 3.4.1.42 (F1) |
| N41 | Menu / LFG hooks need a /reload | `PSS_BlizzardUI.lua` | Done 3.4.1.42 (F1; in-game check 4 deferred, #132) |
| N42 | Talent link tag unknown to the filter language | filters | Done 3.4.1.42 (F1) |
| N43 | Custom filter history keyed by its text | `PSS_ChatFilters.lua` | Done 3.4.1.52 (S3: never-reused id, `nextFilterId`, history on `f:<id>`) |
| N44 | Realm guess in the dead N14 block | `PSS_PlayerIgnoreList.lua` | Done 3.4.1.52 (removed with N14) |
| N45 | Import Replace wipes shipped rules | Libraries, core | Done 3.4.1.42 (F1) |
| N46 | Listener and /who errors swallowed | `PSS_Events.lua`, `PSS_Whois.lua` | Done 3.4.1.42 (F1) |
| N47 | Group warning keeps leavers | `PourSocialScore.lua` | Done 3.4.1.42 (F1; in-game check 7 deferred, #133) |
| N48 | `/pss list` errors on a nil note | `PSS_Commands.lua` | Done 3.4.1.42 (F1) |

### 3.2 Window (appendix 02, G1 to G30)

29 done, 1 open.

| Id | What (one line) | State |
| --- | --- | --- |
| G1 | History rows and tips copy Events formatting | Done 3.4.1.52 (W2: `M.PSS_HistCells`, `M.PSS_HistTip`); the Events view's own copy: issue #145 |
| G2 | Picker tick / "listed" strings in two tabs | Done 3.4.1.52 (W2, `M.PSS_PickerCells`) |
| G3 | Guilds tab reads rules and records directly | Done 3.4.1.52 (W2 pane views; the record is still passed as a handle) |
| G4 | Remove Guild target decided in the GUI | Done 3.4.1.52 (W2, `v:RemoveTarget()`) |
| G5 | GUI writes the view's `dirty` flags | Done (rule toggles in F2, 3.4.1.44; the rest in W2, 3.4.1.52) |
| G6 | Empty-list and hint texts chosen in the GUI | Done 3.4.1.52 (W2) |
| G7 | Each pane fills its Summary spec | Done 3.4.1.52 (W2, every tab) |
| G8 | Type-pie tip and spec copy in the GUI | Done 3.4.1.52 (W2) |
| G9 | Events tab reads `view.q` / `view.name` | Done 3.4.1.52 (W2) |
| G10 | Import/Export raw `M.PSS_IO` reads | Done 3.4.1.52 (W2) |
| G11 | Redundant `M.PSS_EnsureMemberBlockData` in a redraw | Done 3.4.1.52 (W1) |
| G12 | Unreferenced ns / M names | Done 3.4.1.52 (W1, with P1) |
| G13 | "comes in a later 3.4.0 build" placeholder | Done 3.4.1.52 (W1) |
| G14 | Header comments describe two looks | Done 3.4.1.52 (W1) |
| G15 to G20 | Picker, line / label / strip helpers, W I G P C row, edit box hint, text area, primary button built per tab | Done 3.4.1.52 (W3, kit functions in all three looks) |
| G21 | Every filter block fired `FILTERS_CHANGED` | Done 3.4.1.44 (F2) |
| G22 | Selected guild's members walked twice per block redraw | Done 3.4.1.52 (W4) |
| G23 | Whole pane redrawn per block; tips built eagerly | Done 3.4.1.52 (W4, Players and Guilds; the Chat Filters pane not changed) |
| G24 | Leaving one menu slot re-lays every slot | Done 3.4.1.52 (W1) |
| G25 | Small per-call allocations | Done 3.4.1.52 (W1) |
| G26 | Stale "rule off" dim on guild rows | Done 3.4.1.44 (F2) |
| G27 | Dark right-click menus capped at 200 px | Done 3.4.1.44 (F2, cap 400) |
| G28 | Modern art check covers 8 atlases | Done 3.4.1.44 (F2, all 19) |
| G29 | Menu divider not one physical pixel | Done 3.4.1.52 (W1) |
| G30 | Two Exclusion "Remove" paths behave differently | **Open, never scheduled** (no stage took it) |

Not in any appendix: stage Fix / Fix 2 (the detail pane wrap), done in 3.4.1.41.

### 3.3 Open findings in one list
N7, N15, N23 (skipped), N25 (skipped), N30, N32, N33, N34, N36, N39 (rest), G30, and R1 to R5, R7, R8, R10 to R14 (part), R16 (section 9).

## 4. SavedVariables changes (appendix 03; plan 2.2, 2.3): built

Upgrade step 10, "SavedVariables performance cleanup" (S3, in 3.4.1.52). Step 8 is B1's (3.4.1.35), step 9 is S2b's (3.4.1.51). The appendices still call the data step "step 8" (D1).

| Store | Change | State |
| --- | --- | --- |
| `PSS_GuildsDB.guildData[g].members` | `_playerKey` (when equal to the key), `_canon`, `_gkey`, `_managed`, `_virtual`, derivable `name`, `guild` equal to the rule's name, and the "Managed list" date not saved; accessors find the key through a weak `homeKey` map | Done (S2 accessors, S3) |
| same | Counts without zero fields; `total` only when not the sum (`History.CompactCounts`) | Done (S3) |
| same | Cap 1500 stored members per rule (L16), at the upgrade and every logout flush (not on each capture); `memberCount` no longer saved (L12) | Done (S3) |
| same | Camelot name repair (decision 5), Camelot saves only (Libraries `PSS_Camelot.lua`): on Dan's 3.4.0.28 save on a Camelot stub, 498 members repaired, 3 `delList` names | Done (S3) |
| `PSS_PlayersDB` | W I G P C saved only when false; sparse counts | Done (S3) |
| `PourSocialScoreDB.list` | The seven parallel list arrays become one array of sparse records | Done (S2b, step 9) |
| Player keys, log owners `p:` / `g:` | The same Camelot conversion; lines and recent counts follow (`History.RenameOwner`) | Done (S3) |
| `PSS_LoggingDB.blockLog` | `m` not saved when derivable (`false` when a group has no name) | Done (S3) |
| Options | `showIgnoreDebug` no longer saved (N8) | Done (S3) |
| `PSS_RulesDB` / history / recent | Custom filters get a never-reused id (`nextFilterId`), history and recent on `f:<id>` (N43) | Done (S3) |
| `PourSocialScoreDB.purge` | Purge tombstone, cap 200 | Done (S1) |

Measured (3.4.0.28 save, harness, 3.4.1.51 / 3.4.1.52): `PSS_GuildsDB` 460922 to 227885 bytes (-50.6%); whole file 730451 to 483745 bytes; resident after login 3022.5 to 2731.6 KB (-290.9 KB). The first login that migrates loads Logging once for custom filters with counts. `homeKey` costs +80.9 KB once a window reads every record without its key.

Downgrade after step 10: issue #147.

Not built (optional, never in a stage): `whenBlocked` as integer time (C1t), packed member strings (C2).

Forward compatibility (U3, 3.4.1.47): built as plan 2.3 says. Any field a later change saves goes in `M.PSS_SCHEMA` in the same PR; a new per-filter field goes in `filterID` or a table keyed by id; a new log or recent layout takes `v = 3`.

## 5. Upgrade helper (appendix 04; plan 2.4): built

| Piece | State |
| --- | --- |
| Registry | Done 3.4.1.45 (U1): `STEPS` rows `{ id, always, parts }`, parts `{ feature, fields, data }`, counts through `tally` |
| Steps | 1 (every login, split into feature parts), 2 to 4 (3.0.0 moves), 5, 6, 7, 8 (B1), 9 (S2b, list records), 10 (S3, cleanup) |
| `RETIRED` | One list, dropped every login after the data parts; `showIgnoreDebug` added by S3 |
| Report | Done 3.4.1.46 (U2): head line, a line per feature that changed, the cleanup line always (no save size), "Saved data upgraded to X (step N)."; every update prints it, even with nothing to tidy (11_PREFERENCES) |
| Downgrade, pause | Done (U2): one line on an older version; a red line when a step pauses |
| Unusable rules | Done 3.4.1.47 (U3): counted on the report, `/pss export unused` |
| Harness | `check_upgrade_steps.lua`, `check_upgrade_report.lua`, `check_forward.lua`, `check_listrecords.lua`, `check_sparse.lua`, `same_saves.sh`, `sparse_saves.sh` |

## 6. Name bugs (appendix 05; plan 2.1): built

| Part | State |
| --- | --- |
| `M.PSS_NormName(name, realm, unit)` and the name helpers | Done, N1 (3.4.1.32) |
| Every caller, multi-word names, import merge, `M.PSS_CharKey` | Done, N2 (3.4.1.33) |
| Shipped lists rebuilt (196 dropped, 16 converted) | Done, N3 (3.4.1.37) |
| `_managed` and the other runtime member fields | Done: accessors S2 (3.4.1.50), not saved S3 (3.4.1.52) |
| Stored `First-Last` records, list keys, log owners, `delList` | Done, S3 repair (3.4.1.52, Camelot saves only) |
| First-name-only entries | Partly: step 10 names list entries spelled `Name-Classicbetapvp` with a faction as "may have lost their surname"; it cannot be sure (combined notes, S3 point 4). Dan's saves have none |
| Realm display spelling | Not changing (decision 13 reversed) |

## 7. Older code review (`docs/latest/code-review/01_REVIEW_AND_PLAN.md`, main at 3.4.0-dev012)

| Items | State |
| --- | --- |
| M1 to M9, M11, M12, L1 to L11, L13, L17 (window part), L18, L19, L21, L22 | Done in R1 to R3 (3.4.0.14 to 3.4.0.16) |
| L12 (`memberCount` saved), L16 (no member cap) | Done 3.4.1.52 (S3) |
| M10 / L14 (idle GC timer, ticker, `loadWhenQuiet` poll) | Done 3.4.1.52 (P2); the known breach in 02 section 12 is closed |
| L15 (capture events for everyone) | Done 3.4.1.52 (P3); its behaviour change: issue #148 |
| L17 (core per-line allocations) | Done 3.4.1.52 (P4 as N35) |
| L20 (core placement) | Partly done 3.4.1.52 (P6; the rest is N39) |
| L4 (`RemoveMessagesByPredicate`) | An approved override (decision 3) |

## 8. Rules every later change must keep

- Baseline rules are mandatory; PSS differs only where `docs/pss/02_RULES.md` section 12 lists it.
- Counters never come from log lines and stay identical across every data step (checked on Dan's real saves on scratch `SavedVariables/`).
- Zero cost when nothing upgrades; Logging loads only when called; no new SavedVariables files; no timers as logic gates (P2 removed the last).
- Every chat, unit and hook value goes through `M.PSS_IsSecret` before any compare (baseline 02 J, PSS 02 section 10).
- Window changes work in all three looks and are proven with `tui_compare.sh`.
- Saves stay forward compatible: every saved field in `M.PSS_SCHEMA`, unknown fields kept, only `RETIRED` keys deleted.
- Guild member fields through their accessors (`check_fields.lua`), list entries through theirs.

## 9. Found while mapping 3.4.1.38, not in the plan (R1 to R17)

None was scheduled by id; some were fixed along the way. State checked in the code at 3.4.1.53: 4 done, 1 partly, 12 open (each needs Dan's call before it joins a stage).

| # | Finding | State |
| --- | --- | --- |
| R1 | `/pss check` always prints "Last 24 hours: players 0, guilds 0, filters 0" (`stats24h.*` never set) | **Open.** P6 moved it to Libraries `PSS_Validate.lua`; the line still reads `stats24h` |
| R2 | Flood filter hides a duplicate line with no count; `invertSpam` does not change that | **Open** (ask Dan: by design?) |
| R3 | `M.PSS_KeepBlockedOnBuiltIn` does nothing when the shipped lists are not loaded | **Open** (not checked in game) |
| R4 | `inviteByGuild` stores your own guild's inviter as a member | **Open** (no own-guild check there) |
| R5 | `M.PSS_ResetBlizzardIgnore` calls `DelIgnoreByIndex` without the hook guard | **Open** (harmless today) |
| R6 | Arithmetic on nil in the realm guess | Done 3.4.1.52 (removed with N14) |
| R7 | `M.PSS_MemberEventsSpec` label for a shipped member with no record | **Open** (unverified in game) |
| R8 | `/pss clear` warning stays armed all session; `/pss dellist` uses `print` | **Open** (issue #44 for the print) |
| R9 | `collectGuilds` writes `g.memberCount` from Libraries | Done 3.4.1.52 (S3: `memberCount` not saved, the write gone) |
| R10 | `guildGroupOpen` and `windowPoints` written directly from Libraries | **Open** (UI state; allowed, not through a setter) |
| R11 | `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_SetGuildScanFields` fire no event | **Open** |
| R12 | `WHOIS_ANSWERED` fired, nothing listens | **Open** |
| R13 | `INFO_5` and `INFO_6` assigned twice | **Open** |
| R14 | New rules write legacy `declineGuild`, `declineGroup`, `partyRaid`, `memberCount`; reset writes `showIgnoreDebug` | **Partly done** 3.4.1.52 (S3: `memberCount` and `showIgnoreDebug` gone); `ensureGuild` still writes the three legacy switches |
| R15 | Dead exports not named in N9 | Done 3.4.1.52 (P1) |
| R16 | Only the Events tab releases what it read on close | **Open** (W4 did not take it) |
| R17 | `PSS_Skin.lua` header and the page placeholders out of date | Done 3.4.1.52 (W1, G13, G14) |

## 10. Where the docs disagree (checked at 3.4.1.53)

None left. D1 to D6, found at this release, were fixed in the release PR (#143):
- D1: the data migration is **step 10** everywhere (plan 2.1, 2.4's example, decision 4; scratch appendices 03, 04, 05).
- D2: decisions 22 and 24 to 26 carry a note that their build numbers were superseded by decision 28 (release 3.4.1.53; 3.4.2 and 3.4.3 not used).
- D3: decision 14 says nothing was moved (nothing is keyed by `M.PSS_CharKey`).
- D4: plan 2.4's example shows the real output (`Pour Social Score:` prefix, the real phrases).
- D5: the S3 row is marked merged (#142).
- D6: 06 marks issue #45 built by U2.

Resolved earlier: the GC breach line in 02 and 01 (fixed at 3.4.1.52, re-summarized at this release), `CLAUDE.md` and 06 naming the 3.4.2 and 3.4.3 lines (rewritten at this release), the code map at 3.4.1.38 (refreshed at this release and moved to scratch `docs/latest/code-map/`), N8 in two stages (S3 did it), N9 and the two exports to keep (kept), the reload popup (Dan: remove in P1), N24 after B2 (P5 did it).

## 11. What remains after the release

| Item | Where it stands |
| --- | --- |
| #132 Group Finder option without a /reload (F1 check 4) | Open; needs a character that can use the Group Finder |
| #133 the party warning names only who is in the group now (F1 check 7) | Open; in-game check deferred |
| Open findings | Section 3.3 and section 9 |
| P6 moves not made (combined notes) | `/pss mem` (now possible after P2), `M.PSS_AddCapturedGuild` / `M.PSS_ReconcileGuildMembers` (now possible after S3), `M.PSS_ExplainPerson`, `History.MigrateFilterList` (needs an upgrade-record guard), upgrade steps, `M.PSS_VersionOrder`, unusable-rules code and the schema map; `M.SyncIgnoreList` stays in core (hook guard, J rules) |
| P1 leftovers | N7 (`M.debugMsg`), N15; the unused `stats`: issue #145 |
| P4 | N34, N36 not taken; the option cache: issue #145 |
| W2 to W4 leftovers | Issue #145 (Events `TimeText`, Chat Filters pane redraw); a hinted edit box must not `SetScript` `OnTextChanged` (W3 hooks it) |
| S3 points | Issue #146 (member cap timing, first-name-only names); downgrade limits: issue #147 |
| P3 behaviour change | Issue #148 (needs Dan's OK or a revert) |
| Waiting on Dan | Nothing here; setup jobs are GitHub issues (#144, the CI real-save token) |
| #37 guild exclusion list not saved | Open (intent to define) |
| #38 seeing a shipped-guild member loads the lists | Open (N36 is related) |
| #39, #40 unload the GUI / can an LOD addon unload | WoW cannot unload an addon; the window drops caches and requests GC on close |
| #44 console output cleanup | Open (R8's `print`) |
| #45 Questie-style upgrade output | Built by U2 (3.4.1.46) |
| Parked | Pack the in-play chat filter log; Dashboard / overview page (branch `claude/project-thread-pa7y7o`); global moderation (sync, curated lists, scoring); C1t and C2 save ideas |
