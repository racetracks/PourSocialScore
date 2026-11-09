# Build history (PourSocialScore)

Purpose: what each build changed and why, its PR, the tests run and the in-game checks, newest first; and every approved combined build (baseline E1 / E9). Written by `tools/bump_version.sh` through `tools/build_history.py` at every build ([`DEC-00341`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/00_Decisions.md#dec-00341)); never imported at session start.

## Contents
- [What this file is and why](#what-this-file-is-and-why)
- [How it is written](#how-it-is-written)
- [Combined builds](#combined-builds)
- [Builds](#builds)
- [Older history](#older-history)

## What this file is and why
| File | For | Holds |
| --- | --- | --- |
| `history.txt` | Players (ships in the zip) | Patch notes, one plain-words section per build |
| `versions.json` | The release workflow | Each version and its PR |
| **This file** | The author and every session | Per build: what changed and why, the PR, tests run, what the simulation cannot show, in-game checks; the approved combined builds |
| `06_STATUS_AND_NEXT.md` | Every session (imported) | The current build, what is next, what waits on the author |

Why: the record of each build belongs beside the code, but not in the files every session loads at start. `06_STATUS_AND_NEXT.md` grew to 67,759 bytes (about 15k tokens a session) before [PR #240](https://github.com/racetracks/PourSocialScore/pull/240) moved its history out; this file keeps it from growing back. Read it, after the code map, before changing behaviour, fixing a bug or checking a regression in an area (`CLAUDE.md`, Read when the task touches the topic).

## How it is written
1. `sh tools/bump_version.sh build "Title"` (and `release`, `line`) moves the current build entry of 06 "Now" here unchanged, then writes a stub for the new build in both files.
2. The PR fills this file's entry: what changed and why (files, functions), tests run with counts, what the simulation cannot show, in-game checks. 06 keeps one line.
3. `sh tools/bump_version.sh pr <number>` writes the PR into both.
4. `sh tools/check_rules.sh` runs `python3 tools/build_history.py check`: it fails when 06 "Now" holds more than one build entry, or when a version in `versions.json` from 3.8.0.119 on has no entry here.

## Combined builds
The approvals behind the E1 / E9 Overrides row of `02_RULES.md` section 12, moved here word for word from that table at 3.8.0.120. A new combined build adds its row here, with the author's OK, before it ships.

| Baseline rule | PSS instead |
| --- | --- |
| E1 / E9 One step per PR and per session | The warehouse stages L1 (shared item layer) and W2 (persisted bags) in one build, 3.7.0.107, each proven by its own check phases. The author, 2026-10-14, [`DEC-00231`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/warehouse-helper/00_Decisions.md#dec-00231) a |
| E1 / E9 One step per PR and per session | Several stages or issues in one PR and one build, each proven by its own check phases; that delivery only: the rest of the core uplift (S3, P1 to P6, W1 to W4) as 3.4.1.52 (per-stage notes `reference/combined-3.4.1.52/`); graphics settings stages 1 to 3 as 3.5.0.57; the addon manager's five stages as 3.6.0.64; issues #171 and #172 as 3.6.0.66; #175, #176, #177 as 3.6.0.68; #175, #176, #177, #180 and #181 (Enabled components) as 3.6.0.69; #189 and #183 as 3.6.0.75 (the author, 2026-10-10: resolve all in one attempt); #189 (`STP-00018`), #192 (`STP-00020`) and the #179 rework as 3.6.0.84 (built on a branch as 3.6.0.80 to .82; the author, 2026-10-10: "do `TST-00008`, `TST-00009`", then "pr it"); #201 and #203 as 3.6.0.87 (the author, 2026-10-10: "#201 with #203", `DEC-00075` b) ; #202 (3.6.0.88), the removal of CPU from the addon manager and the Dark tab label fade as 3.6.0.89, and the removal of all memory usage from the addon manager as 3.6.0.90 (the author, 2026-10-10: asked in the same session); the Addon Manager restructure (interface-helper, [`STP-00072`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/interface-helper/07_Roadmap.md#stp-00072) to [`STP-00077`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/interface-helper/07_Roadmap.md#stp-00077), issue #211) in one build as 3.6.0.91 ([`DEC-00088`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/interface-helper/04_High_Level_Design.md#dec-00088) c, the author, 2026-10-10); the service bus stage S1 ([`STP-00093`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00093), [`STP-00138`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00138), [`STP-00140`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00140)) in one build as 3.7.0.98 ([PR #216](https://github.com/racetracks/PourSocialScore/pull/216); the live plan builds them together; the author, 2026-10-11, the implementation roadmap S1); PSS Drop Cheapest Thing, stages 1 to 6 of [`IMP-00009`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/money-helper/07_Roadmap.md#imp-00009) (3.6.0.92 and 3.6.1.93; the author, 2026-10-10: "attempt to complete all of the implementation plan in one attempt"); the service bus stage S2 ([`STP-00094`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00094), [`STP-00139`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00139), [`STP-00147`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00147) and the S1 follow-ups [`STP-00143`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00143) to [`STP-00146`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00146)) in one build as 3.7.0.100 (the live plan builds them together; the author, 2026-10-11: [`DEC-00210`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/04_High_Level_Design.md#dec-00210) a, [`DEC-00203`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/00_Decisions.md#dec-00203) a, and the instruction to initiate S2 from the [project roadmap](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/11/10-13-00-Sun-awesome-allen-mxrrg4/project-roadmap-2/README.md)) |
| E1 / E9 One step per PR and per session | All of phase 2 of the Warehousing and Journaling roadmap (packages `STP-p00` to `STP-p19`: the item layer, the warehouse, money, search, import, the gateway and Syndicator shim, the interface) in one build, 3.7.0.106 (its in-game test fixes are 3.7.0.107 and 3.7.0.108, the same PR), each package proven by its own check phases and its own commit ([`DEC-00263`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/code-map/00_Decisions.md)). The author, 2026-10-16 |
| E1 / E9 One step per PR and per session | Phase A of the Spyglass, Journal and Bags roadmap ([`STP-00232`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00232) to [`STP-00252`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00252), [`STP-00285`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00285) to [`STP-00287`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00287)) in one build, 3.8.0.116, each component proven by its own check phases (`ix_phases.sh`) and its own commit. The author, 2026-10-17: one PR and one pre-release per phase ([`DEC-00320`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/00_Decisions.md#dec-00320) b) |
| E1 / E9 One step per PR and per session | Phase B of the Spyglass, Journal and Bags roadmap ([`STP-00253`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00253) to [`STP-00258`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00258), [`STP-00288`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00288), [`STP-00292`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00292)) in one build, 3.8.0.125, each component proven by its own check phases (`console_phases.sh`) and its own commit. The author, 2026-10-17: one PR and one pre-release per phase ([`DEC-00320`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/00_Decisions.md#dec-00320) b) |

## Builds
<!-- builds: newest first; tools/build_history.py roll writes here -->

### 3.8.0.141 - TBC B4 fix: tab art and guild bank

- Branch: `claude/modest-pasteur-7z5d3x`.
- What changed and why:
  - L03: TBC selected-tab art: TAB_ACTIVE per template keys (`PSS_Kit.lua`); TBC uses `PanelTopTabButtonTemplate`, which inherits `TabButtonTemplate` and keeps its selected art under `*Disabled` (L01b recon).
  - L02: stub template parts per flavour, `C_XMLUtil`; `check_tabs.lua` (TST-00983, TST-00984).
  - G01, G02: guild bank reads loaded tabs only, keeps saved tabs, item ids, count-0 auctions; import writes no live meta.
  - G03: a search row names the guild bank first (`<Guild> (guild bank) and N more`): holder entries carry the entity kind (`PSS_WhTooltip.lua:108`), `holders` in `PSS_WhRows.lua:35-41` picks the first guild holder; check G4 in `check_wh.lua`.
- Docs updated: `docs/pss/16_INTERFACE.md:22` (L03); the `docs/pss/07_HARNESS.md` row of `check_tabs.lua` (L02); the `PourSocialScore_Libraries/PSS_ItemRead.lua:15-20` header comment (G01); `PourSocialScore_Libraries/PSS_WhTooltip.lua:74` (G03).
- Tests run: `wh_phases.sh` WH 196 phases, 0 failed.
- Not shown by the simulation: the real TBC client tab art and a live realm guild bank.

### 3.8.0.140 - TBC B4: Modern and Classic looks on TBC Anniversary, TBC pre-release

- Branch: `claude/modest-pasteur-7z5d3x`; [PR #261](https://github.com/racetracks/PourSocialScore/pull/261).
- What changed and why: TBC B4 (STP-00309): the GUI picks every template through `M.PSS_CompatTemplate` (`PSS_Kit.lua`, `PSS_Skin.lua`, `PSS_DttMerchant.lua`) so the Modern and Classic looks work on TBC Anniversary; the looks text names what each client has (B4T1, commit 5251cfd); this build is the TBC pre-release (the full release waits for the author).
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `docs/pss/01_HANDOVER.md`; `docs/pss/16_INTERFACE.md`; `history.txt`; `versions.json`; every TOC.
- Tests run: `build_saves.sh` 15 forever saves and 1 tbc save (tbc/3.8.0.139: 116,848 bytes; forever 346,053 to 1,110,065 bytes); `validate_all.sh` real saves on each client's stub, totals 2272 PASS, 287 FAIL, 0 SKIP, the 289 FAIL/summary lines the same set as origin/main (SAME, pre-existing, not caused by B4); `save_size.sh origin/main` SIZE 19 saves, 0 grew (fresh/tbc delta 0 B); `tui_compare.sh` on tbc 191 steps identical to origin/main; `compat_phases.sh` COMPAT 8 phases, 0 failed; `flv_phases.sh` FLV 10 phases, 0 failed; Era bus phases (report only): bus gate 7 phases, 0 failed, no Lua error; `gen_toc.lua --check` clean; `check_toc.sh` per folder and `check_rules.sh`.
- Not shown by the simulation: the real TBC client in Modern, Classic and Dark; a live realm guild bank; Retail and Forever in game (out of scope and blocked until 2026-11-04).
- In-game checks: CHK-00218 (Modern), CHK-00219 (Classic), CHK-00220 (Dark), CHK-00113 (live realm with a guild bank; closes #234), all on TBC Anniversary; CHK-00223 (Forever) blocked.

### 3.8.0.139 (from 06 Now)

**3.8.0.139, TBC B3: compat shim, TBC adapters, Friends anchor (branch `claude/b3-compat-shim-k4w9tq`, PR #260):** compat shim for TBC Anniversary, Friends anchor, SAV-00092/93 (0 B), Syndicator IsForever on Retail bug fix (`DEC-00426`); the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.139 - TBC B3: compat shim, TBC adapters, Friends anchor

- Branch: `claude/b3-compat-shim-k4w9tq`; [PR #260](https://github.com/racetracks/PourSocialScore/pull/260).
- What changed and why: TBC B3 (STP-00308): `PSS_Compat.lua` adapters (containers, guild bank, secret values, menus, addon compartment, reload, templates) so core loads on TBC Anniversary; Friends window anchor (`PSS_BlizzardUI.lua`, DEC-00429); SAV-00092 and SAV-00093 digit reader (0 to 5; 0 bytes per save, DEC-00425). **Bug fix, named (DEC-00426):** `PSS_GwSyndicator` no longer reports Retail as Forever (Retail `IsForever` false, `IsRetail` true). Product fixes found in B3: bagMeta early return, `PSS_Call` guards, FriendsFrame nil guard.
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `docs/pss/01_HANDOVER.md`; `docs/pss/07_HARNESS.md`; `history.txt`; `versions.json`; every TOC.
- Tests run: `compat_phases.sh` COMPAT 8 phases, 0 failed (retail forever tbc, era); `flv_phases.sh` FLV 10 phases, 0 failed, `nogrep` 0 hits; `flv_mutants.sh` MUTANTS 11: 11 killed, 0 survived, 0 invalid; `validate_all.sh` real saves (15): counters identical to origin/main, the pre-existing FAIL lines are the same set as on origin/main (not caused by B3); `save_size.sh origin/main` SIZE 18 saves, 0 grew (SAV-00092 and SAV-00093: 0 B per save); `tui_compare.sh` 191 steps identical to origin/main; `gen_toc.lua --check` clean; `check_toc.sh` per folder and `check_rules.sh`.
- Not shown by the simulation: the real TBC client (Friends anchor, bag and guild bank reads, menus), the Retail Syndicator flags with a real Syndicator, Modern/Classic looks on TBC (out of scope, B4 or later).
- In-game checks: CHK-00221, CHK-00222, CHK-00110, CHK-00225, CHK-00227 (TBC Anniversary / Retail) and the CHK-00224 re-run (Retail); CHK-00223 (Forever) blocked until 2026-11-04.

### 3.8.0.138 (from 06 Now)

**3.8.0.138, TBC B2: TOC set for TBC Anniversary (branch `claude/admiring-ride-vtgwfe`, PR #259; awaiting the author's `CHK-00217` and `CHK-00226`):** TBC Anniversary TOC set: generated TOCs, `_TBC.toc` per folder (Interface 20506), install text without client folders; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.138 - TBC B2: TOC set for TBC Anniversary

- Branch: `claude/admiring-ride-vtgwfe`; [PR #259](https://github.com/racetracks/PourSocialScore/pull/259).
- What changed and why: TBC Anniversary TOC set (STP-00307): `tools/gen_toc.lua` writes every TOC of the six folders from `tools/toc/manifest.txt` (`--check`, `--install`); a `_TBC.toc` per folder with Interface 20506 (Macros gated out); `check_toc.sh` checks four TOCs per folder; `release.yml` install line built from the manifest (Forever folder is one `install forever` setting); `readme.txt` install paragraph names no client folder; flavour check gains a `blank` phase (FLV is now 10 phases, replacing the old quoted total of 30). Nothing changes for Retail and Forever players.
- Docs updated: this file; `docs/pss/reference/14_build-history-3.8.0.130-to-3.8.0.132.md` (entries moved); `docs/pss/06_STATUS_AND_NEXT.md`; `docs/pss/01_HANDOVER.md`; `docs/pss/07_HARNESS.md`; `readme.txt`; `history.txt`; `versions.json`; every TOC.
- Tests run: `gen_toc.lua --check` clean; `toc_phases.sh` TOC 6 rows, 0 failed; `check_toc.sh` per folder and `check_rules.sh`; `validate_all.sh` 15 real saves, 0 failed; `save_size.sh` SIZE 17 saves, 0 grew; `flv_phases.sh` FLV 10 phases, 0 failed; `flv_mutants.sh` MUTANTS 11: 11 killed, 0 survived, 0 invalid; `install_phases.sh` INSTALL 4 rows, 0 failed.
- Not shown by the simulation: whether the TBC Anniversary client lists every folder as current, loads them and prints the upgrade report.
- In-game checks: `CHK-00217` (TBC Anniversary: every folder loads, upgrade report prints, note the WTF folder path), `CHK-00226` (TBC Anniversary: not out of date, flavour TBC).

## Older history
- 3.8.0.133 to 3.8.0.137: [`reference/14_build-history-3.8.0.133-to-3.8.0.137.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.133-to-3.8.0.137.md)
- 3.8.0.130 to 3.8.0.132: [`reference/14_build-history-3.8.0.130-to-3.8.0.132.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.130-to-3.8.0.132.md)
- 3.8.0.125 to 3.8.0.129: [`reference/14_build-history-3.8.0.125-to-3.8.0.129.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.125-to-3.8.0.129.md)
- 3.8.0.119 to 3.8.0.124: [`reference/14_build-history-3.8.0.119-to-3.8.0.124.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.119-to-3.8.0.124.md)
- 3.6.0.69 to 3.8.0.118: [`reference/06_status-history-3.6.0.69-to-3.8.0.118.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md)
- To 3.4.1.30: [`reference/06_status-history-to-3.4.1.30.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-to-3.4.1.30.md); the combined 3.4.1.52 notes: `reference/combined-3.4.1.52/`
- Every build: `history.txt` and `versions.json`

## Changelog
| Date | Reference | Change |
| --- | --- | --- |
| 2026-10-20 | REF-15-00-00-Tue-pensive-davinci-osy66a-A11 | entries 3.8.0.119 to 3.8.0.124 moved word for word to `reference/14_build-history-3.8.0.119-to-3.8.0.124.md` (size cap) |
| 2026-10-29 | REF-00-27-50-Thu-ccr-0503e1ee-d9m6t2-A09 | entries 3.8.0.133 to 3.8.0.137 moved word for word to `reference/14_build-history-3.8.0.133-to-3.8.0.137.md` (size cap) |
