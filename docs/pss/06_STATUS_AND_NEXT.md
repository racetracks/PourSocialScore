# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.130)

Purpose: current status and next step of PSS · owner coordinator · status current, updated every PR · related docs/pss/14_BUILD_HISTORY.md, docs/pss/01_HANDOVER.md

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.130, Spyglass fixes (branch `pensive-davinci-osy66a`, PR #242):** B1 `like` on time; B1a to B1c alerts fire on blocked world-chat lines; E1 query view resizes with the window; E2 Events starts blank; E3 column widths by content; segcost gate (S1): best of 15 runs, Append us min/median/max Retail 2.48/2.525/2.67, Camelot 2.48/2.575/2.76 against gate 5 (`agents/A07/REPORT.md`); known survivor from before this build: mutant `con-cap-note`; details in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: 3.8.0.131 (B2a to B2c, K131); the Spyglass pre-release is 3.8.0.134 (#242)** (`DEC-00337`; guide section G0, roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`)); journal, bags and optimisation take the next free build numbers after it (roadmap Next Steps).
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- PR #242: answer the asks O1 to O3 (02 section 11 rules 11 and 12, the guild pane) and run in-game `CHK-00172`, `CHK-00173`, `CHK-00174`, `CHK-00178` and `CHK-00185` on the 3.8.0.130 zip, each in Modern, Classic and Dark.
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
