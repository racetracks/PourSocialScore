# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.121, Spyglass console (branch `claude/nice-noether-m6eqsa`, PR #242):** what changed, in one line; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: phase B, the Spyglass console, 3.8.0.121, then the Spyglass release 3.8.0.122, a pre-release** (`DEC-00337`; guide section G0, roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`)); journal 3.9.0.123 to .125, bags 3.10.0.126 to .128, optimisation 3.11.0.129 and .130.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- Test a very old save on 3.7.0.113 (the final pre-release), then merge the 3.7.0.114 release PR; then hand phase A its guide (section G0 of 12_02_Phase_A_Spyglass_Engine.md (`scratch:documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md`)).
- Run `CHK-00110` when the TBC stage opens (#233) and `CHK-00113` on a live realm with a guild bank (#234); `CHK-00117` and `CHK-00118` have no recorded result.
- #231: the undo check skips the planted 3.4.1.50 save.
- On request before or with S3: move the superseded drafts to history, the decisions lint and contents writer, the planned-builds registry (`DEC-00234` to `DEC-00236`).
- Drop Cheapest Thing stage 7; macros from #159 when ready.
- Closed on GitHub since the last update (sweep 2026-10-14): #144, #148, #179, #189, #192.

## Known breaches
None (02 section 12).

## Open issues (addon repo, checked 2026-10-17)
- #231: the undo check skips the planted 3.4.1.50 save.
- #233: the Syndicator import check (`CHK-00110`) waits for the TBC stage.
- #234: the guild bank check (`CHK-00113`) waits for a live realm.
- #227: Disenchant Helper integration (proposed).
- #228: Enemy Frames integration (proposed).
- Closed since 2026-10-14: #224 (built in S3, 3.7.0.104).
- #215: the scratch gate runs everywhere; strict gate green on `main` (run 38573450333).
- #217 to #220: code map findings and files to add.
- #212: Drop Cheapest Thing as an opt-in integration.
- #197: rename "Addon Manager" to "Addon Helper" (later).
- #159 to #169: Macro Helper macros, one issue per set.
- #152, #147, #146, #145, #133, #132, #125, #44, #39, #38, #37: as before (window memory, downgrade loss, member cap, leftovers, tests later, unblock guild, console output, memory on close, shipped members, guild exclusion list).

Context for each open item: scratch `docs/latest/issues/` and `docs/latest/setup/`.

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
