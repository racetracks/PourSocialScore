# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.125)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.125, Spyglass phase B, the console** (branch `claude/nice-noether-m6eqsa`, [PR #242](https://github.com/racetracks/PourSocialScore/pull/242); [session temp root](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/18/13-08-00-Sun-nice-noether-m6eqsa/README.md)): the Spyglass tab with a colour-coded search bar, time picker, charts, the save dialog (searches, charts and alerts), the Data dictionary page, View Events and the pane histories through Spyglass; the Events tab is retired. Ran: rules check passed; `validate_all.sh` 1529 PASS / 0 FAIL; `console_phases.sh` 164 phases, 0 failed; `console_mutants.sh` 25 of 25 killed; `ix_phases.sh` 327 phases and the bus gate 7 phases, 0 failed; `tui_compare.sh` differs from `origin/main` as intended (the new tab). Sizes (KB): `PSS_Chart.lua` 40.99, `PSS_QueryView.lua` 10.71, `PSS_TimePicker.lua` 29.77, `PSS_Console.lua` 40.95, `PSS_QueryDialog.lua` 24.03, `PSS_ConsoleView.lua` 59.29. Not shown by the simulation: fonts, wrapped text, overlay alignment on the real edit box, client art, hover feel. In-game: `CHK-00146` to `CHK-00150`, each in Modern, Classic and Dark. **Next: the Spyglass release 3.8.0.126 (a pre-release).** Details in `docs/pss/14_BUILD_HISTORY.md`.
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: phase B, the Spyglass console, 3.8.0.125 with the Spyglass release 3.8.0.126, a pre-release (#242)** (`DEC-00337`; guide section G0, roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`)); the docs builds 3.8.0.123 (merged) and 3.8.0.124 took the next numbers; journal 3.9.0.125 to .127, bags 3.10.0.128 to .130, optimisation 3.11.0.131 and .132.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- PR #242: answer the asks O1 to O3 (02 section 11 rules 11 and 12, the guild pane) and run `CHK-00146` to `CHK-00150`, `CHK-00170`, `CHK-00171` on the 3.8.0.125 zip, each in Modern, Classic and Dark; then the release 3.8.0.126.
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
