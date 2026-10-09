# PourSocialScore: changes in train (state at release 3.4.1.53)

**What this is.** What the core uplift changed and what is still open, so a later session (Claude or GPT) can tell shipped from open. Read it with the code map (scratch `docs/latest/code-map/`, https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/latest/code-map). The design and decisions are in `10_CORE_UPLIFT.md` (scratch `docs/latest/core-uplift/`); per-stage notes of the combined build in `reference/combined-3.4.1.52/`. Where this file and the plan differ, the plan wins; where either differs from the code, the code wins. Refreshed at each full release.

## 0. In one screen

| Item | State |
| --- | --- |
| Release | **3.4.1.53**, live (PR #143, 2026-10-09); closes the core uplift. Previous release 3.4.0.29 |
| Project | Graphics settings (`/pss gfx`, Camelot), line 3.5.0, opened by 3.5.0.56 (docs only); design on scratch `docs/latest/graphics-settings/`; 3.5.0.57 builds stages 1 to 3; graphics polish takes the next free build. Next step: the Macro Helper (`/pss macro`, Camelot), stage 1 as 3.5.0.61 (design and plan on scratch `docs/latest/macro-helper/`). Release 3.4.2.54 (PR #150) is docs only, no change in game |
| Lines 3.4.2, 3.4.3 | Not used: their stages (P1 to P6, W1 to W4) shipped inside 3.4.1.52 (decision 28, a one-time override, 02 section 12) |

Decided not to change: identity stays the lowercase `name-realm` key (no ID generator, decision 2); realm display spelling stays (decision 13 reversed); no new SavedVariables files; the three looks and the window's layout stay.

## 1. Stage table (line 3.4.1)

Docs-only builds (3.4.1.31, .34, .38, .39, .43) are left out.

| Stage | Build | PR | Change |
| --- | --- | --- | --- |
| N1 | 3.4.1.32 | #120 | `M.PSS_NormName` and the name helpers |
| N2 | 3.4.1.33 | #121 | Every name caller, multi-word names, import check, runtime fields not flushed |
| B1 | 3.4.1.35 | #123 | PSS authoritative over Blizzard's ignore list; per-player tick; upgrade step 8 |
| B2 | 3.4.1.36 | #124 | Right-click "PSS" header: Block Player / Block Guild |
| N3 | 3.4.1.37 | #126 | Builder fix, shipped lists rebuilt (7634 to 7438 entries) |
| Fix 2 | 3.4.1.41 | #130 | Guilds detail pane: width and wrapped height (`FitLines`; decision 23; Fix, 3.4.1.40, did not take) |
| F1 | 3.4.1.42 | #131 | N40, N41, N42, N45, N46, N47, N48 (checks 4 and 7 deferred: #132, #133) |
| F2 | 3.4.1.44 | #135 | G21 with G26, G27, G28 |
| U1 | 3.4.1.45 | #136 | Upgrade step registry |
| U2 | 3.4.1.46 | #137 | Upgrade report printed once per update (issue #45) |
| U3 | 3.4.1.47, .48 | #138 | Forward compatibility: `M.PSS_SCHEMA`, tolerant readers, downgrade line, unusable rules, `/pss export unused`, export format 2; `check_locals.lua` |
| S1 | 3.4.1.49 | #139 | `History.ClearOwner` and the purge tombstone (N16) |
| S2 | 3.4.1.50 | #140 | Accessors for member fields, counts totals and `memberCount`; `check_fields.lua` |
| S2b | 3.4.1.51 | #141 | Player list arrays become one array of sparse records, `list` (decision 27); step 9 |
| Combined | 3.4.1.52 | #142 | S3 (step 10, sparse saves, cap, Camelot repair, filter ids), P1 to P6, W1 to W4 (decision 28) |
| R | 3.4.1.53 | #143 | Release |

## 2. What each stage touched in the code

| Stage | Main files | Saved data? |
| --- | --- | --- |
| Fix 2 | GUI `PSS_Guilds.lua` (`BuildGroupBody`, `FitLines`) | No |
| F1 | core `PourSocialScore.lua` (login expiry, group warning), `PSS_PlayerIgnoreList.lua` (`M.PSS_ExpireEntries`), `PSS_BlizzardUI.lua` (hook bodies gated), `PSS_Events.lua` (`M.PSS_NoteListenerError`), talent tag in `PSS_ChatFilters.lua` / Libraries `PSS_FilterQuery.lua`, `M.PSS_ClearGuildRules`, Libraries `PSS_Commands.lua` | No |
| F2 | core `PSS_ChatFilters.lua`; GUI `PSS_Filters.lua`, `PSS_Guilds.lua`, `PSS_Menu.lua`, `PSS_Skin.lua` | No |
| U1 to U3 | core `PSS_Upgrade.lua`, `PSS_Schema.lua`, `PSS_Localization.lua` (`UPG_*`); Libraries `PSS_ImportExport.lua` (format 2, `more`), `PSS_Commands.lua`; GUI `PSS_Popups.lua`; `tools/check_schema.lua`, `check_locals.lua` | Record keeps the highest version |
| S1 | core `PSS_ChatHistory.lua` (`History.ClearOwner`, `History.ApplyPurge`), the six owner clears | `PourSocialScoreDB.purge` (cap 200) |
| S2 | core `PSS_GuildIgnoreList.lua` (`-- (member fields)` block), `History.CountTotal`; `tools/check_fields.lua` | No |
| S2b | core `PSS_PlayerIgnoreList.lua` (`-- (list entries)` block), step 9 | **Yes** (`PourSocialScoreDB.list`) |
| S3 | step 10; member block (`homeKey`, `compactMember`, `M.PSS_CapMembers`); `PSS_PlayerIgnoreList.lua` (W I G P C only when false); `M.PSS_NewFilterId`; `History.CompactCounts`, `History.RenameOwner`; Logging `PSS_SavedLog.lua` (log `m`); Libraries `PSS_Camelot.lua` | **Yes** (the author's OK, D9) |
| P1 | Dead code (N1 to N6, N9, N11 to N14); `PSS_MainlineCompat.lua` deleted | No |
| P2 | `PSS_Perf.lua` (no timer), `History.LoadWhenQuiet` | No |
| P3 | `PSS_Whois.lua`, `M.PSS_CaptureNeeded` / `M.PSS_ApplyCapture` | No |
| P4 | `History.Add` (outbox), `M.PSS_CanonGuild`, `M.PSS_Opt`, the player and guild sources | No |
| P5 | Shared helpers: `M.MONTHS`, `M.PSS_BLOCK_FIELDS`, `M.PSS_FILTER_ARRAYS`, `addToggle` | No |
| P6 | Libraries `PSS_PlayerRows.lua` (from `PSS_PlayerQuery.lua`, `M.prettyServer`), `PSS_Validate.lua`, `PSS_WhoisHarvest.lua`; stubs left in core | No |
| W1 to W4 | GUI tabs; W2 logic into Libraries views (`PSS_DetailQuery`, `PSS_GuildView`, `PSS_PlayerView`, `PSS_ViewNav`, `PSS_EventsView`, `PSS_FilterView`, `PSS_OptionsView`); W3 kit (`ns.NewTextArea`, `ns.NewPicker`, `ns.NewLine`, `ns.NewLabel`, `ns.NewStrip`, `ns.NewAllowedBoxes`, hinted edit box, primary button) | No |

## 3. Every finding and where it landed

"Done .52" means shipped in 3.4.1.52 (the combined build); the stage is in brackets.

### 3.1 Core, Libraries, Logging, Options (appendix 01, N1 to N48)

38 done, 10 open (2 skipped on purpose, 1 partly done).

| Id | What | State |
| --- | --- | --- |
| N1 | 61 unused English localization keys | Done .52 (P1) |
| N2 | `V.needSorted` written, never read | Done .52 (P1) |
| N3 | Dead reload popup (`PSS_RELOAD`, `M.PSS_AskReload`, `before` in `PSS_SetOpt`) | Done .52 (P1; the author: "remove in p1") |
| N4 | `gotUpdate` / `gotGroup` and their `IGNORELIST_UPDATE` registration | Done .52 (P1) |
| N5 | `PSS_MainlineCompat.lua` globals | Done .52 (P1, file deleted) |
| N6 | `V.wowIsERA` .. `V.wowName` never read | Done .52 (P1) |
| N7 | `M.debugMsg` empty; about 15 callers in `PSS_PlayerIgnoreList.lua` still build strings | **Open** |
| N8 | `showIgnoreDebug` written every login | Done .52 (S3, in `RETIRED`) |
| N9 | About 25 dead `M.*` exports | Done .52 (P1; `PSS_CompileFilter`, `PSS_EnsureManagedRules` kept) |
| N10 | Harness-only exports in shipped code | Done .52 (P1: kept, labelled as harness hooks) |
| N11 | `History.KeepAdd`, `MovePeople`, `MergeLists`, `Combine`, `Max` | Done .52 (P1) |
| N12 | Unused locals | Done .52 (P1) |
| N13 | `/pss test` empty | Done .52 (P1) |
| N14 | Dead realm-resolve block in `M.PSS_AddOrDelIgnore`; `pServers` | Done .52 (P1) |
| N15 | `M.PSS_GUILD_SEARCH_OWNER` tag (still the window's search tag) | **Open** |
| N16 | Six copies of the owner clear | Done 3.4.1.49 (S1) |
| N17 | 15 copies of a member's canon key | Done 3.4.1.50 (S2, `M.PSS_MemberCanon`; the member removal's copy differs on purpose) |
| N18 | `findGuildRecord` vs `M.PSS_FindGuildRule` | Done .52 (P5) |
| N19 | Two date parsers, two month tables | Done .52 (P5, `M.MONTHS`) |
| N20 | Category list and labels twice | Done .52 (P5) |
| N21 | W I G P C field lists in eight places | Done .52 (P5, `M.PSS_BLOCK_FIELDS`) |
| N22 | Parallel-array `table.remove` copies | Done .52 (P5 `M.PSS_FILTER_ARRAYS`; list arrays gone with S2b) |
| N23 | Five rules for "your target as a name to add" | **Open, skipped on purpose:** they differ by design |
| N24 | LFG and unit menu build the same toggle twice | Done .52 (P5, `addToggle`) |
| N25 | Two "remove older than N days" loops | **Open, skipped on purpose:** a helper measured -9 B compiled, +0.3 KB resident |
| N26 | Routed option reads about 2 us per chat line | Done .52 (P4: `M.PSS_Opt` reads `PSS_OptionsDB` directly; no value cache, on purpose) |
| N27 | `History.Clear(pred)` unpacks every kept line | Done 3.4.1.49 in practice (S1 `ClearOwner`); a batched `ClearOwners(set)` not built |
| N28 | Guild path per chat line | Done .52 (P4: 6.9 to 5.3 us) |
| N29 | `M.daysFromToday` builds tables per call | Done .52 (via N19) |
| N30 | `M.PSS_GetGuildBlockCounts` recounts every member on every resort | **Open** (G22 only avoids the second walk) |
| N31 | Outbox at cap: one `table.remove(ob, 1)` per line | Done .52 (P4: 17.4 to 2.7 us) |
| N32 | `M.PSS_RemoveGuild` walks the ignore list per member; `removedGlobal` always 0 | **Open** |
| N33 | `M.hasGlobalIgnored` linear scan before the index | **Open** |
| N34 | `CoreFilter` runs seven `isSecret` calls before the cache lookup | **Open** |
| N35 | Per-line tables on block paths | Done .52 (P4: 633 to 385 B per blocked whisper) |
| N36 | With shipped lists loaded, three `sub` and a `find` per non-member line | **Open** (related: #38) |
| N37 | `M.PSS_Validate` resident in core | Done .52 (P6, -16.7 KB) |
| N38 | `REALM_PAIRS` / `M.prettyServer` resident in core | Done .52 (P6) |
| N39 | Other core placement candidates (about 105 KB) | **Partly done** .52 (P6, -63.0 KB in all). Left: section 11 |
| N40 | Expiry never applied automatically | Done 3.4.1.42 (F1) |
| N41 | Menu / LFG hooks need a /reload | Done 3.4.1.42 (F1; check deferred, #132) |
| N42 | Talent link tag unknown to the filter language | Done 3.4.1.42 (F1) |
| N43 | Custom filter history keyed by its text | Done .52 (S3: id `nextFilterId`, history on `f:<id>`) |
| N44 | Realm guess in the dead N14 block | Done .52 (with N14) |
| N45 | Import Replace wipes shipped rules | Done 3.4.1.42 (F1) |
| N46 | Listener and /who errors swallowed | Done 3.4.1.42 (F1) |
| N47 | Group warning keeps leavers | Done 3.4.1.42 (F1; check deferred, #133) |
| N48 | `/pss list` errors on a nil note | Done 3.4.1.42 (F1) |

### 3.2 Window (appendix 02, G1 to G30)

29 done, 1 open.

| Id | What | State |
| --- | --- | --- |
| G1 | History rows and tips copy Events formatting | Done .52 (W2, `M.PSS_HistCells`, `M.PSS_HistTip`); the Events view's copy: #145 |
| G2 | Picker tick / "listed" strings in two tabs | Done .52 (W2, `M.PSS_PickerCells`) |
| G3 | Guilds tab reads rules and records directly | Done .52 (W2; the record still passed as a handle) |
| G4 | Remove Guild target decided in the GUI | Done .52 (W2, `v:RemoveTarget()`) |
| G5 | GUI writes the view's `dirty` flags | Done (F2 3.4.1.44, rest W2 .52) |
| G6 | Empty-list and hint texts chosen in the GUI | Done .52 (W2) |
| G7 | Each pane fills its Summary spec | Done .52 (W2) |
| G8 | Type-pie tip and spec copy in the GUI | Done .52 (W2) |
| G9 | Events tab reads `view.q` / `view.name` | Done .52 (W2) |
| G10 | Import/Export raw `M.PSS_IO` reads | Done .52 (W2) |
| G11 | Redundant `M.PSS_EnsureMemberBlockData` in a redraw | Done .52 (W1) |
| G12 | Unreferenced ns / M names | Done .52 (W1) |
| G13 | "comes in a later 3.4.0 build" placeholder | Done .52 (W1) |
| G14 | Header comments describe two looks | Done .52 (W1) |
| G15 to G20 | Picker, line / label / strip, W I G P C row, edit box hint, text area, primary button built per tab | Done .52 (W3, kit in all three looks) |
| G21 | Every filter block fired `FILTERS_CHANGED` | Done 3.4.1.44 (F2) |
| G22 | Selected guild's members walked twice per redraw | Done .52 (W4) |
| G23 | Whole pane redrawn per block; tips built eagerly | Done .52 (W4, Players and Guilds; Chat Filters pane: #145) |
| G24 | Leaving one menu slot re-lays every slot | Done .52 (W1) |
| G25 | Small per-call allocations | Done .52 (W1) |
| G26 | Stale "rule off" dim on guild rows | Done 3.4.1.44 (F2) |
| G27 | Dark right-click menus capped at 200 px | Done 3.4.1.44 (F2, cap 400) |
| G28 | Modern art check covers 8 atlases | Done 3.4.1.44 (F2, all 19) |
| G29 | Menu divider not one physical pixel | Done .52 (W1) |
| G30 | Two Exclusion "Remove" paths behave differently | **Open** |

### 3.3 Open findings in one list
N7, N15, N23 (skipped), N25 (skipped), N30, N32, N33, N34, N36, N39 (rest), G30; R1 to R5, R7, R8, R10 to R13, R14 (part), R16 (section 9).

## 4. SavedVariables changes (appendix 03; plan 2.2, 2.3)

Upgrade steps: 8 (B1), 9 (S2b), 10 "SavedVariables performance cleanup" (S3).

| Store | Change | By |
| --- | --- | --- |
| `PSS_GuildsDB.guildData[g].members` | Not saved: `_playerKey` (when equal to the key), `_canon`, `_gkey`, `_managed`, `_virtual`, derivable `name`, `guild` equal to the rule's name, the "Managed list" date; accessors find the key through a weak `homeKey` map | S2, S3 |
| same | Counts without zero fields; `total` only when not the sum (`History.CompactCounts`) | S3 |
| same | Cap 1500 stored members per rule (L16), at the upgrade and every logout flush; `memberCount` not saved (L12) | S3 |
| same | Camelot name repair (decision 5), Camelot saves only (`PSS_Camelot.lua`): the author's 3.4.0.28 save on a Camelot stub, 498 members repaired, 3 `delList` names | S3 |
| `PSS_PlayersDB` | W I G P C saved only when false; sparse counts | S3 |
| `PourSocialScoreDB.list` | Seven parallel list arrays become one array of sparse records | S2b |
| Player keys, log owners `p:` / `g:` | Same Camelot conversion; lines and recent counts follow (`History.RenameOwner`) | S3 |
| `PSS_LoggingDB.blockLog` | `m` not saved when derivable (`false` when a group has no name) | S3 |
| Options | `showIgnoreDebug` not saved (N8) | S3 |
| `PSS_RulesDB` / history / recent | Custom filters get a never-reused id (`nextFilterId`), keyed `f:<id>` (N43) | S3 |
| `PourSocialScoreDB.purge` | Purge tombstone, cap 200 | S1 |

Measured on the 3.4.0.28 save: `PSS_GuildsDB` 460922 to 227885 bytes (-50.6%); whole file 730451 to 483745 bytes; resident after login 3022.5 to 2731.6 KB (-290.9 KB). The migrating login loads Logging once for custom filters with counts. `homeKey` costs +80.9 KB once a window reads every record without its key.

Downgrade after step 10: #147. Not built (optional): `whenBlocked` as integer time (C1t), packed member strings (C2).

Forward compatibility (U3, plan 2.3): any field a later change saves goes in `M.PSS_SCHEMA` in the same PR; a new per-filter field goes in `filterID` or a table keyed by id; a new log or recent layout takes `v = 3`.

## 5. Upgrade helper (appendix 04; plan 2.4)

| Piece | State |
| --- | --- |
| Registry (U1) | `STEPS` rows `{ id, always, parts }`, parts `{ feature, fields, data }`, counts through `tally` |
| Steps | 1 (every login, in feature parts), 2 to 4 (3.0.0 moves), 5, 6, 7, 8 (B1), 9 (S2b), 10 (S3) |
| `RETIRED` | One list, dropped every login after the data parts |
| Report (U2) | Head line, a line per feature that changed, the cleanup line always, "Saved data upgraded to X (step N)."; prints on every update (11_PREFERENCES) |
| Downgrade, pause (U2) | One line on an older version; a red line when a step pauses |
| Unusable rules (U3) | Counted on the report; `/pss export unused` |
| Harness | `check_upgrade_steps.lua`, `check_upgrade_report.lua`, `check_forward.lua`, `check_listrecords.lua`, `check_sparse.lua`, `same_saves.sh`, `sparse_saves.sh` |

## 6. Name bugs (appendix 05; plan 2.1)

| Part | State |
| --- | --- |
| `M.PSS_NormName(name, realm, unit)` and helpers | Done (N1) |
| Every caller, multi-word names, import merge, `M.PSS_CharKey` | Done (N2) |
| Shipped lists rebuilt (196 dropped, 16 converted) | Done (N3) |
| Runtime member fields (`_managed` ...) | Done: accessors (S2), not saved (S3) |
| Stored `First-Last` records, list keys, log owners, `delList` | Done (S3 repair, Camelot saves only) |
| First-name-only entries | Partly: step 10 names entries spelled `Name-Classicbetapvp` with a faction as "may have lost their surname"; it cannot be sure. The author's saves have none. #146 |
| Realm display spelling | Not changing (decision 13 reversed) |

## 7. Older code review (scratch `docs/latest/code-review/01_REVIEW_AND_PLAN.md`)

| Items | State |
| --- | --- |
| M1 to M9, M11, M12, L1 to L11, L13, L17 (window part), L18, L19, L21, L22 | Done (R1 to R3, 3.4.0 line) |
| L12, L16 | Done (S3) |
| M10 / L14 (idle GC timer, ticker, `loadWhenQuiet` poll) | Done (P2) |
| L15 (capture events for everyone) | Done (P3); its behaviour change: #148 |
| L17 (core per-line allocations) | Done (P4, as N35) |
| L20 (core placement) | Partly (P6; the rest is N39) |
| L4 (`RemoveMessagesByPredicate`) | Approved override (decision 3) |

## 8. Rules every later change must keep

- Baseline rules are mandatory; PSS differs only where `02_RULES.md` section 12 lists it.
- Counters never come from log lines and stay identical across every data step (checked on the author's real saves on scratch `SavedVariables/`).
- Zero cost when nothing upgrades; Logging loads only when called; no new SavedVariables files; no timers as logic gates.
- Every chat, unit and hook value goes through `M.PSS_IsSecret` before any compare (baseline 02 J, PSS 02 section 10).
- Window changes work in all three looks, proven with `tui_compare.sh`.
- Saves stay forward compatible: every saved field in `M.PSS_SCHEMA`, unknown fields kept, only `RETIRED` keys deleted.
- Guild member fields and list entries through their accessors (`check_fields.lua`).

## 9. Found while mapping, not in the plan (R1 to R17)

Checked in the code at 3.4.1.53: 4 done, 1 partly, 12 open (each needs the author's call before it joins a stage).

| # | Finding | State |
| --- | --- | --- |
| R1 | `/pss check` always prints "Last 24 hours: players 0, guilds 0, filters 0" (`stats24h.*` never set; now in Libraries `PSS_Validate.lua`) | **Open** |
| R2 | Flood filter hides a duplicate line with no count; `invertSpam` does not change that | **Open** (ask the author: by design?) |
| R3 | `M.PSS_KeepBlockedOnBuiltIn` does nothing when the shipped lists are not loaded | **Open** (not checked in game) |
| R4 | `inviteByGuild` stores your own guild's inviter as a member | **Open** |
| R5 | `M.PSS_ResetBlizzardIgnore` calls `DelIgnoreByIndex` without the hook guard | **Open** (harmless today) |
| R6 | Arithmetic on nil in the realm guess | Done .52 (with N14) |
| R7 | `M.PSS_MemberEventsSpec` label for a shipped member with no record | **Open** (unverified in game) |
| R8 | `/pss clear` warning stays armed all session; `/pss dellist` uses `print` | **Open** (#44 for the print) |
| R9 | `collectGuilds` writes `g.memberCount` from Libraries | Done .52 (S3) |
| R10 | `guildGroupOpen` and `windowPoints` written directly from Libraries | **Open** (UI state; allowed, not through a setter) |
| R11 | `PSS_SetMemberBlock`, `PSS_SetMemberNote`, `PSS_SetGuildScanFields` fire no event | **Open** |
| R12 | `WHOIS_ANSWERED` fired, nothing listens | **Open** |
| R13 | `INFO_5` and `INFO_6` assigned twice | **Open** |
| R14 | New rules write legacy `declineGuild`, `declineGroup`, `partyRaid` in `ensureGuild` (`memberCount`, `showIgnoreDebug` gone in S3) | **Partly done** |
| R15 | Dead exports not named in N9 | Done .52 (P1) |
| R16 | Only the Events tab releases what it read on close | **Open** |
| R17 | `PSS_Skin.lua` header and page placeholders out of date | Done .52 (W1) |

## 10. Where the docs disagree

None (checked at 3.4.1.53).

## 11. What remains open

Every open GitHub issue on the addon repo, and the open items not yet in an issue.

| Item | Where it stands |
| --- | --- |
| #37 | The guild exclusion list is not saved; intent to define |
| #38 | Seeing a shipped-guild member loads the lists (N36 related) |
| #39, #40 | Unload the GUI on close / can an LOD addon unload: WoW cannot unload an addon; the window drops caches and requests GC on close |
| #44 | Console output cleanup (R8's `print`) |
| #45 | Questie-style upgrade output: built by U2, shipped in 3.4.1.53; closed 2026-10-09 |
| #78 | The 3.3.0 parity project issue; the project closed at 3.3.1 (08); closed 2026-10-09 |
| #125 | Right-click "Unblock Guild" on a shipped guild: turn the group's rule off instead of refusing |
| #132 | Group Finder option without a /reload (F1 check 4); needs a character that can use the Group Finder |
| #133 | Party warning names only who is in the group now (F1 check 7) |
| #144 | CI real-save tests need the `SCRATCH_TOKEN` secret |
| #145 | Combined-build leftovers: unused `stats`, option cache, Events `TimeText`, Chat Filters pane redraw (G1, G23) |
| #146 | Member cap only at logout; Camelot first-name-only names guessed |
| #147 | Going back from 3.4.1.53 loses custom filters (3.4.0.29) and later list entries |
| #148 | P3: inactive shipped lists no longer capture units or /who; needs the author's OK or a revert |
| Open findings, no issue | Section 3.3 and section 9 |
| P6 moves not made (N39 rest) | `/pss mem`, `M.PSS_AddCapturedGuild` / `M.PSS_ReconcileGuildMembers`, `M.PSS_ExplainPerson`, `History.MigrateFilterList` (needs an upgrade-record guard), upgrade steps, `M.PSS_VersionOrder`, unusable-rules code, the schema map. `M.SyncIgnoreList` stays in core (hook guard, J rules) |
| Kit note | A hinted edit box must not `SetScript` `OnTextChanged` (W3 hooks it) |
| Parked | Pack the in-play chat filter log; Dashboard / overview page (branch `claude/project-thread-pa7y7o`); global moderation (sync, curated lists, scoring); C1t and C2 save ideas |
