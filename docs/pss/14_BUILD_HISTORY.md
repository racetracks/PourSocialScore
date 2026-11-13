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
| E1 / E9 One step per PR and per session | The Macro Helper Priest set, 3.8.0.146, added to the Shaman set's PR #270 (3.8.0.145) as its own build and commit, each proven by its own `check_macro.lua` phase. The author, 2026-11-10, this session (scratch `temp/2026/11/10/09-04-54-Tue-tender-knuth-moxuz4/prompts/02.md`): "Same PR #270" |
| E1 / E9 One step per PR and per session | The Shaman Stormstrike macro, 3.8.0.147, added to PR #270 (3.8.0.145, 3.8.0.146) as its own build and commit. The author, 2026-11-10, this session (scratch `temp/2026/11/10/09-04-54-Tue-tender-knuth-moxuz4/prompts/03.md`): "Same PR #270" |
| E1 / E9 One step per PR and per session | The red real-saves job ([issue #268](https://github.com/racetracks/PourSocialScore/issues/268)) in one build, 3.8.0.150: cards 1, 2, 3 and 5, each proven by its own check. The author, 2026-11-10, approved the cards for one build (scratch [prompt 05](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/14-52-09-Tue-great-sagan-6nl0he/prompts/05.md)) |

## Builds
<!-- builds: newest first; tools/build_history.py roll writes here -->

### 3.9.0.155 - Journal monitors

- Branch: `claude/wonderful-cannon-zwshli`; PR: none yet.
- Rows: J2G3: seal rule and visible gold, 11 gold phases; J2D1a, J2D1b: Dark tick tests then fix in `PSS_Skin.lua`, `PSS_Kit.lua`; J2RB: real-save check `jrnoffbytes`; J2IL: warehouse auctions without item link (`whauc`); J2O2: string-table warm-up in `ix_measure.lua`; J2W: trigger rows, manifest order; J2S: stubs `wh_stub.lua`; J2X: fixture events `jrn_day.lua`; J2A: `PSS_JrnMon1.lua` vendor and repair; J2B: `PSS_JrnMonBasic.lua` basic monitors; J2C: `PSS_JrnAh.lua` auction houses; J2XF, J2CF: fuzz starts the rows and takes the baseline first; J2CR: auction house phases and mutants; J2BC: COD mail copper.
- Hooks installed (post-hooks, `DEC-00411`): `C_Container.UseContainerItem`, `BuyMerchantItem`, `BuybackItem`, `C_Container.ContainerRefundItemPurchase`, `RepairAllItems`, `SendMail`, `TakeInboxMoney`, `TakeInboxItem`, `AutoLootMailItem`, `TakeTaxiNode`, `BuyTrainerService` and the auction post calls the client has. Adapters: Retail modern (version detection only); Forever modern; TBC legacy.
- Tests: `jrn_phases.sh` all areas incl. `mon1`, `monbasic`, `ah`, `fuzz` PASS retail, forever, tbc; mutants 42/42 killed; `validate_all.sh` 1735 checks, 0 failed; real saves `jrnoffbytes` 21 PASS, 0 FAIL.
- In-game (Client, Looks): CHK-00151, CHK-00153 Forever (once more with both restriction consoles), any; CHK-00152 Forever, any; CHK-00252 Forever, MCD; plus step 6: check `C_Container.GetContainerItemPurchase*` (unverified API); step 7: check `GetMerchantItemInfo` price and quantity (unverified API); step 8: check the loot money slot quantity read as copper (unverified API); step 9: check `GetTrainerServiceCost` (unverified API); step 10: check `QUEST_LOOT_RECEIVED` arriving before `QUEST_TURNED_IN` (unverified API).
- Docs updated: `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md`, `history.txt`, `versions.json`, TOCs.

### 3.9.0.155 (from 06 Now)

**3.9.0.155, Journal monitors (branch `claude/wonderful-cannon-zwshli`, PR: none yet):** what changed, in one line; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.9.0.155 - Journal monitors

- Branch: `claude/wonderful-cannon-zwshli`; PR: none yet.
- What changed and why: (written in the PR)
- Docs updated: (written in the PR)
- Tests run: (written in the PR)
- Not shown by the simulation: (written in the PR)
- In-game checks: (written in the PR)

### 3.9.0.154 (from 06 Now)

**3.9.0.154, Journal data (branch `claude/zealous-brown-c4kxdk`, PR #278):** Journal data: capabilities, Journal option, journal index and warehouse history (rows J1H to J1W); the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`); known issue: the ix budgetfiles gate charges Lua's string-table doubling to whichever file crosses it (A10 REPORT, open issue).

### 3.9.0.154 - Journal data

- Branch: `claude/zealous-brown-c4kxdk`; [PR #278](https://github.com/racetracks/PourSocialScore/pull/278).
- Rows: J1H: harness `jrn_phases.sh`, `check_jrn.lua`; J1F: fixture `jrn_day.lua`, 23 lines; J1T: two new libraries `PSS_JrnIx.lua`, `PSS_WhHist.lua`, Options rows, Schema; J1C: capabilities in `PSS_Flavour.lua`; J1D: `M.PSS_OptCapOn`, `M.PSS_OptSetBool`, refusal and hidden rows; J1I: journal index `PSS_JrnIx.lua`; J1W: warehouse history `PSS_WhHist.lua`, `PSS_WhStore.lua`, `PSS_Money.lua`, `PSS_Seg.lua`.
- Tests: `jrn_phases.sh` PASS retail, forever, tbc for areas caps, opts, index, whh (real: Retail SKIP); mutants caps 6/6, opts 3/3, index 3/3, whh 3/3.
- In-game (Client, Looks): CHK-00210 Forever, TBC, MCD; CHK-00211 Forever, TBC, any; CHK-00154 Forever, TBC, any; CHK-00250 Forever, TBC, any (confirmation only; Retail: load and version detection only); CHK-00251 dropped (DEC-00456).
- J1X1 (Q1, D19): the 4 Retail-only caps and options `jrnMonitorCrafting`, `jrnMonitorTradingPost`, `jrnMonitorTokens`, `jrnMonitorMissions` dropped (flv memory gate 2 KB).
- J1X2 to J1X5 (Q2 to Q4, D22, D23): check expectations changed: components label `Journal`, ixlist 25, options count only cap-on rows, lazyWorld removes the real `jrn` and `whh` before planting (`tools/harness/check_ix.lua:2067`).
- The whh trigger rows `whh.net`, `whh.logout` register once in `M.PSS_WhStartMore` with the Journal on (`PourSocialScore_Libraries/PSS_WhHist.lua`).
- J1X6: `PSS_DataDictCheck` (PourSocialScore_Libraries/PSS_IxCatalog.lua:100-108) makes no per-field key string; PSS_IxCfg.lua 80.78 to 16.78 KB (string-table doubling, REPORT.md)
- Known issue: the ix budgetfiles gate charges Lua's string-table doubling to whichever file crosses it (A10 REPORT, open issue).
- Docs updated: `docs/pss/02_RULES.md` (section 3 Warehouse bullet, section 10.3 journal monitors bullet), `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md`, `history.txt`, `versions.json`, TOCs.; `history.txt`; scratch `16_02_Data_Dictionary.md`

### 3.8.0.153 - Search: faster text search in the log

- Branch: `claude/peaceful-bell-q1s5gb`; [PR #277](https://github.com/racetracks/PourSocialScore/pull/277).
- What changed and why: the log prefilter tests exactly the text fields the search shows, and words it proved are not tested again (D1, [architecture](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/10-07-10-Wed-peaceful-bell-q1s5gb/specs/architecture.md#4-chosen-design-d1-exact-prefilter-proven-text-terms)), `DEC-00434`.
- Docs updated: `PourSocialScore_Libraries/PSS_IxLog.lua:116`, `PourSocialScore_Libraries/PSS_Pred.lua:12`, `docs/pss/reference/07_harness-search.md:10-16`, this entry, `docs/pss/06_STATUS_AND_NEXT.md:1`.
- Tests run: phase `textexact`; `TST-00989` with the new `L` lines; the B05 speed table ([results](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/10-07-10-Wed-peaceful-bell-q1s5gb/results/b05/README.md)) and the B01 verdict ([results](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/10-07-10-Wed-peaceful-bell-q1s5gb/results/o1/README.md)) the F02 table ([results](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/10-07-10-Wed-peaceful-bell-q1s5gb/results/f02/README.md)) in the session temp root. K154 fix F01: the prefilter cost fix in `PourSocialScore_Libraries/PSS_IxLog.lua` ([spec 7.5](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/10-07-10-Wed-peaceful-bell-q1s5gb/specs/spec.md#75-prefilter-cost-k154)).
- Not shown by the simulation: the speed on the author's live logs in game; the CI `real-saves` timing runs only on the PR.
- In-game checks: the check of [plan section 3](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/10-07-10-Wed-peaceful-bell-q1s5gb/specs/plan.md#3-in-game-checks-380153) ([`CHK-00255`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/16_Registries/REGISTRY.md#chk-00255)).

### 3.8.0.152 (from 06 Now)

**3.8.0.152, Harness: sharded real saves (branch `claude/festive-wozniak-3uoj74`, PR #276):** several saves per version, `shard_saves.sh` and `fail_summary.sh`; the CI `real-saves` check runs sharded by save (speed steps S02, D02); no addon code changed; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.152 - Harness: sharded real saves

- Branch: `claude/festive-wozniak-3uoj74`; [PR #276](https://github.com/racetracks/PourSocialScore/pull/276).
- What changed and why: speed steps S02 and D02: [`build_saves.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/festive-wozniak-3uoj74/tools/harness/build_saves.sh) builds several saves per version (`<client>/<version>/<save>/`, `DEC-00461`); new [`shard_saves.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/festive-wozniak-3uoj74/tools/harness/shard_saves.sh) (shard plan and links) and [`fail_summary.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/festive-wozniak-3uoj74/tools/harness/fail_summary.sh) (per-version FAIL tables); the CI `real-saves` check is split into `real-saves-prep` (saves built once per scratch commit, cached), `real-saves-shard` (matrix, real-only) and `real-saves` (summaries, result). `save_key` ([`flavours.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/festive-wozniak-3uoj74/tools/harness/flavours.sh)) reads client, version and save for the loops that took them from the folder levels (`validate_all.sh`, `ix_phases.sh`, `console_phases.sh`, `save_size.sh`, `search_same.sh`); without it the new `<save>` level lost each save's flavour. No addon code changed.
- Docs updated: `docs/pss/07_HARNESS.md`, `docs/pss/harness/01_COMMANDS.md`, `docs/pss/04_DATA_AND_LOGGING.md`, `docs/pss/05_RELEASE.md`, `history.txt`, this entry, `docs/pss/06_STATUS_AND_NEXT.md`.
- Tests run: S02 and D02 acceptance as briefed; real-only on the 21 saves in the new layout (results in the session temp root).
- Not shown by the simulation: the GitHub Actions jobs themselves (cache, artifacts, matrix) run only on the PR.
- In-game checks: none (no game change).

### 3.8.0.151 (from 06 Now)

**3.8.0.151, Harness: real-only mode (branch `claude/upbeat-planck-26jtkp`, PR #275):** `PSS_REAL_ONLY=1` runs only the real-save checks and the CI `real-saves` job uses it (speed step S01); no addon code changed; planreal on tbc/3.8.0.142 and tbc/3.8.0.143 stays red for the search speed build; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.151 - Harness: real-only mode

- Branch: `claude/upbeat-planck-26jtkp`; [PR #275](https://github.com/racetracks/PourSocialScore/pull/275).
- What changed and why: speed step S01: `PSS_REAL_ONLY=1` runs only the real-save checks of [`validate_all.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-planck-26jtkp/tools/harness/validate_all.sh), `ix_phases.sh` and `console_phases.sh`; the CI `real-saves` job uses it (`docs/pss/07_HARNESS.md`). A build because every PR owns a version (the author, 2026-11-11). No addon code changed.
- Docs updated: `docs/pss/07_HARNESS.md`, `history.txt`, this entry, `docs/pss/06_STATUS_AND_NEXT.md`.
- Tests run: real-only on 21 saves rc 0, 171 s (full 390 s); same real-save checks; only planreal timing differs ([results](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/11/04-34-07-Wed-upbeat-planck-26jtkp/S01/README.md)).
- Not shown by the simulation, in-game checks: none (no game change).

### 3.8.0.150 (from 06 Now)

**3.8.0.150, Real-saves job fixes (branch `claude/dazzling-gates-kgpqlm`):** issue #268's causes fixed in the checks; planreal on tbc/3.8.0.142 and tbc/3.8.0.143 stays red for the search speed build; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.150 - Real-saves job fixes

- Branch: `claude/dazzling-gates-kgpqlm`; [PR #274](https://github.com/racetracks/PourSocialScore/pull/274).
- What changed and why: the red real-saves job ([issue #268](https://github.com/racetracks/PourSocialScore/issues/268)) had causes in the checks, not the addon. [`check_real.lua`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/check_real.lua) counts the Camelot name repair (card 1); [`ix_phases.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/ix_phases.sh) reruns a failing timing phase alone (card 5); [`check_guilds.lua`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/check_guilds.lua) opens the default list before reading its dim (card 2: the window was right, the check read a closed list); [`check_console.lua`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/check_console.lua) concap counts the log, the keep and the outbox, as `index=log` does (card 3: the log was at its cap; the trim-at-write fix was dropped, it cost 13.5 to 256 us per blocked line). No addon code changed. Card 4 (planreal on tbc/3.8.0.142 and tbc/3.8.0.143) stays red, to the search speed build.
- Docs updated: `docs/pss/07_HARNESS.md`, `docs/pss/harness/01_COMMANDS.md`, `docs/pss/harness/02_PHASES.md`, `history.txt`, this entry, `docs/pss/06_STATUS_AND_NEXT.md`.
- Tests run: `check_real.lua` on the five oldest Forever saves (2.0.44, 3.0.0, 3.2.0-dev011, 3.4.0.28, 3.4.1.50): 0 FAIL (285 before; the step 10 re-key and the shipped-member merge count as kept); `check_guilds.lua` fresh and on every Forever save: 0 FAIL, the G26 dim read with the list open; `check_console.lua` phase `concap` on every real save: 0 FAIL; `PSS_RETIME_TEST=1 sh tools/harness/ix_phases.sh segcost budgetcalls`: rc 0, 6 `re-run passed`; `check_context.py` on the split harness docs rc 0, 0 lines lost; `build_history.py check` rc 0; stage close `validate_all.sh` with the real saves (`git fetch --depth=2000 origin main` first): only the two carried planreal FAILs, tbc/3.8.0.142 6.09 ms and tbc/3.8.0.143 5.30 ms per 2,000 lines against the 4.9 ms gate (card 1, to the search speed build).
- Not shown by the simulation: the G26 dim in the real window when a list's rule is switched on from Chat Filters (in-game `CHK-00254`, in Modern, Classic and Dark); timing on the author's machine, since the harness gates measure the test host only.
- In-game checks: [`CHK-00254`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/16_Registries/REGISTRY.md#chk-00254): on a save with a Managed Communities list whose rule is off, open the Guilds tab and expand that list (its rows are dim); on the Chat Filters tab switch that list's rule on; back on the Guilds tab its rows show at full brightness at once; in Modern, Classic and Dark.

## Older history
- 3.8.0.145 to 3.8.0.149: [`reference/14_build-history-3.8.0.145-to-3.8.0.149.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.145-to-3.8.0.149.md)
- 3.8.0.142 to 3.8.0.144: [`reference/14_build-history-3.8.0.142-to-3.8.0.144.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.142-to-3.8.0.144.md)
- 3.8.0.138 to 3.8.0.141: [`reference/14_build-history-3.8.0.138-to-3.8.0.141.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.138-to-3.8.0.141.md)
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
| 2026-11-13 | this file | entries 3.8.0.145 to 3.8.0.149 moved word for word to `reference/14_build-history-3.8.0.145-to-3.8.0.149.md` (size cap after merging PR #277 into 3.9.0.154) |
| 2026-10-20 | REF-15-00-00-Tue-pensive-davinci-osy66a-A11 | entries 3.8.0.119 to 3.8.0.124 moved word for word to `reference/14_build-history-3.8.0.119-to-3.8.0.124.md` (size cap) |
| 2026-10-29 | REF-00-27-50-Thu-ccr-0503e1ee-d9m6t2-A09 | entries 3.8.0.133 to 3.8.0.137 moved word for word to `reference/14_build-history-3.8.0.133-to-3.8.0.137.md` (size cap) |
| 2026-11-10 | 3.8.0.149, branch claude/great-pascal-ja1q5e | entries 3.8.0.138 to 3.8.0.141 moved word for word to `reference/14_build-history-3.8.0.138-to-3.8.0.141.md` (size cap) |
| 2026-11-11 | 3.8.0.152, branch claude/festive-wozniak-3uoj74 | entries 3.8.0.142 to 3.8.0.144 moved word for word to `reference/14_build-history-3.8.0.142-to-3.8.0.144.md` (size cap) |
