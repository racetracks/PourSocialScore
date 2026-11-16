# Build history 3.8.0.150 to 3.8.0.153

Purpose: builds moved out of `docs/pss/14_BUILD_HISTORY.md` (32 KB cap) - owner coordinator - status archived - related docs/pss/14_BUILD_HISTORY.md

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
