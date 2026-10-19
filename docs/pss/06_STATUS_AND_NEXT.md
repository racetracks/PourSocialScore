# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.129)

Purpose: current status and next step of PSS · owner coordinator · status current, updated every PR · related docs/pss/14_BUILD_HISTORY.md, docs/pss/01_HANDOVER.md

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.129, phase B brought up to date with main (branch `claude/nice-noether-m6eqsa`, PR #242):** `main` (3.8.0.128, PR #249) merged into the 3.8.0.127 phase B branch; no code changes beyond 3.8.0.127, so the 3.8.0.127 in-game checks carry over; the Spyglass pre-release moves up one to 3.8.0.130.
- **3.8.0.128, Docs: scratch temp folders moved into dated folders (branch `ccr-11709e26-ej241j`, PR #249):** the flat scratch `temp/` roots moved into `temp/<YYYY>/<MM>/<DD>/` (`DEC-00397`, `scratch:temp/MOVED.md`), its 9 links here repointed and `docs/scratch/03_LAYOUT.md` updated; no addon code changes; PR #242 holds 3.8.0.125 to 3.8.0.127, so its pre-release moves up one to 3.8.0.129; also (same PR, the author's ask) the next-session handoff: `CLAUDE.md` (Every session) mandates `scratch:.next/NEXT.md`, read at start and written at every delivery, one per session temp root (`DEC-00398`); the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **3.8.0.127, Spyglass search fixes** (same branch, PR #242): fixes the 3.8.0.126 results `CHK-00146`, `CHK-00147`, `CHK-00150`, `CHK-00170`, the history cap note (G8) and the Events cells (G9); rules 9 to 13 of 02 section 1 (D89). **Next: the Spyglass pre-release 3.8.0.128.** Ran: rules check rc=0; validate_all 1643 PASS, 1 FAIL (the segcost timing gate, 5.21 us over 5.0; 5.12 and 5.34 on a re-run; 5.13 and 5.15 on ec6cd9a, so a machine-speed gate not caused by this build), 0 SKIP (14 real saves); console_phases 256 phases, 0 failed; console_mutants 34 of 34 killed; data re-validation on 3.8.0.126: 10 compared, 0 mismatched, 5 recorded. In game: `CHK-00146`, `CHK-00147` a to g, `CHK-00150`, `CHK-00170` and its cap line, each in Modern, Classic and Dark.
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: the Spyglass pre-release 3.8.0.130 (#242)** once the author reports the 3.8.0.127 checks passed (`DEC-00337`; guide section G0, roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`)); journal, bags and optimisation take the next free build numbers after it (roadmap Next Steps).
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- PR #242: answer the asks O1 to O3 (02 section 11 rules 11 and 12, the guild pane) and run `CHK-00146` to `CHK-00150`, `CHK-00170`, `CHK-00171` on the 3.8.0.125 zip, each in Modern, Classic and Dark; then the 3.8.0.127 fix build (re-checks on its zip, or the 3.8.0.129 zip, which has the same code) and the pre-release 3.8.0.130.
- Test a very old save on 3.7.0.113 (the final pre-release), then merge the 3.7.0.114 release PR; then hand phase A its guide (section G0 of 12_02_Phase_A_Spyglass_Engine.md (`scratch:documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md`)).
- Run `CHK-00110` when the TBC stage opens (#233) and `CHK-00113` on a live realm with a guild bank (#234); `CHK-00117` and `CHK-00118` have no recorded result.
- #231: the undo check skips the planted 3.4.1.50 save.
- On request before or with S3: move the superseded drafts to history, the decisions lint and contents writer, the planned-builds registry (`DEC-00234` to `DEC-00236`).
- Drop Cheapest Thing stage 7; macros from #159 when ready.
- Closed on GitHub since the last update (sweep 2026-10-14): #144, #148, #179, #189, #192.

## Known breaches
None (02 section 12).

## Open issues
On GitHub: https://github.com/racetracks/PourSocialScore/issues (context for each: scratch `docs/latest/issues/` and `docs/latest/setup/`).

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
