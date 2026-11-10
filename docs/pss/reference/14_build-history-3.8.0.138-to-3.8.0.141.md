# Build history, 3.8.0.138 to 3.8.0.141

Purpose: the entries of 3.8.0.138 to 3.8.0.141 of `14_BUILD_HISTORY.md`, moved here word for word at 3.8.0.149 to keep that file under its size cap · owner coordinator · status read only · related docs/pss/14_BUILD_HISTORY.md

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
