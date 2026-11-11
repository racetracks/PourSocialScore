# Build history, 3.8.0.142 to 3.8.0.144

Purpose: the entries of 3.8.0.142 to 3.8.0.144 of `14_BUILD_HISTORY.md`, moved here word for word at 3.8.0.152 to keep that file under its size cap · owner coordinator · status read only · related docs/pss/14_BUILD_HISTORY.md

### 3.8.0.144 (from 06 Now)

**3.8.0.144, Search speed (branch `claude/upbeat-fermat-481m3i`, PR #269):** search timing harness only; the freeze (F-1) is not reproduced in the harness; in game one press of `f` froze 32 s (the author, 2026-11-10), the in-game `CHK-00232` quick `f` run finds where; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.144 - Search speed

- Branch: `claude/upbeat-fermat-481m3i`; PR #269.
- What changed and why: (written in the PR)
- Docs updated: `docs/pss/07_HARNESS.md`, `docs/pss/reference/07_harness-search.md`, `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md`
- Tests run: (written in the PR)
- Not shown by the simulation: (written in the PR)
- In-game checks: (written in the PR)

### 3.8.0.144 (from 06 Now)

**3.8.0.144, search timing harness only (branch `claude/upbeat-fermat-481m3i`, [PR #267](https://github.com/racetracks/PourSocialScore/pull/267) open):** the freeze (F-1, `CHK-00230`) was not reproduced by the harness; waits on the author's in-game `CHK-00232`; details in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.143 (from 06 Now)

**3.8.0.143, Fix: /pss version checks all six folders (branch `claude/clever-fermat-uesj4v`, PR #266):** `/pss version` checks all six folders and adds a save record line; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.144 - Search timing harness (no fix)

- Branch: `claude/upbeat-fermat-481m3i`; [PR #267](https://github.com/racetracks/PourSocialScore/pull/267).
- What changed and why:
  - Harness only, no addon code: [bench_search.lua](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-fermat-481m3i/tools/harness/bench_search.lua) (`TERM` and `TYPED` timing, cold item cache seed), [search_results.lua](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-fermat-481m3i/tools/harness/search_results.lua) (result dump) and [search_same.sh](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-fermat-481m3i/tools/harness/search_same.sh) (same rows as a reference, then timing, `REPRO yes|no`); detail in [07_harness-search.md](reference/07_harness-search.md). Commits d37b1a6, 88d4356, e402f90.
  - Why: F-1, the freeze the author reported (`CHK-00230`: search freezes the game up to 10 s on TBC and Forever).
  - Result: not reproduced (`REPRO no`) in 3 harness runs. Largest `TERM` max_ms 4.850 and largest `TYPED` max_ms 4.697 (both TBC 3.8.0.139 save), against the 200 ms threshold; Forever saves stay under 1 ms.
  - The fix builds (Q02 to Q04) are deferred until a freeze is reproduced.
- Docs updated: `docs/pss/07_HARNESS.md:65-67`, `docs/pss/reference/07_harness-search.md:1-16`, `docs/pss/14_BUILD_HISTORY.md:42`, `docs/pss/06_STATUS_AND_NEXT.md:1`, `docs/pss/06_STATUS_AND_NEXT.md:8`, `docs/pss/06_STATUS_AND_NEXT.md:11`.
- Not shown by the simulation: the in-game freeze (the harness item-request queue fills only as the addon requests ids).
- In-game checks: `CHK-00232` (the author runs it in game).

### 3.8.0.143 - Fix: /pss version checks all six folders

- Branch: `claude/clever-fermat-uesj4v`; [PR #266](https://github.com/racetracks/PourSocialScore/pull/266).
- What changed and why:
  - `DEC-00440`: `/pss version` checks all six folders and adds a save record line (save last upgraded by another version).
  - `DEC-00441`: flavour loops, section.
  - `DEC-00442`: not built.
- Docs updated: `docs/pss/07_HARNESS.md:41`, `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md:1`.
- Tests run: `TST-00998`, `TST-00999`.
- Not shown by the simulation: a real stale folder reporting its own TOC version.
- In-game checks: `CHK-00244`, `CHK-00235` at 3.8.0.143.

### 3.8.0.142 (from 06 Now)

**3.8.0.142, Fix: TBC tabs, Forever wording, version proof (branch `claude/forever-rerun-142`, PR #265):** F-3 Forever wording, F-2 TBC tab art, F-5 `/pss version`, 10 macros; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.142 - Fix: TBC tabs, Forever wording, version proof

- Branch: `claude/forever-rerun-142`; [PR #265](https://github.com/racetracks/PourSocialScore/pull/265).
- What changed and why:
  - F-3 (`DEC-00436`): player text says Forever, not Camelot (commands, Options note, gfx tip, upgrade line).
  - F-2 (`DEC-00435`): TBC tab art spans the whole tab label, selected and not (3.8.0.141 regression).
  - F-5 (`DEC-00437`): `/pss version` proves which version the client loaded.
  - F-1 (search freeze) moved to the search speed build, 3.8.0.143 (`DEC-00438`).
  - The 10 macros (`DEC-00439`): 3 global and 7 warrior macros.
- Docs updated: `docs/pss/16_INTERFACE.md`, `docs/pss/07_HARNESS.md`, `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md`.
- Tests run: `TST-00991` to `TST-00997`; real-save run (`build_saves.sh` lists `forever 3.8.0.139-forever-launch`, `validate_all.sh` with `PSS_REAL_SAVES`).
  - Step 2 result: real saves: 288 FAIL, identical to main cd64591 (pre-existing, follow-up issue). Duplicate stub (#262): one 3.8.0.142 entry in history.txt and in this file.
- Not shown by the simulation: the TBC tab look, the Forever client loading this version, the macros' icons and casts.
- In-game checks: `CHK-00235` to `CHK-00243`, re-runs `CHK-00218` to `CHK-00220`, `CHK-00229`.
