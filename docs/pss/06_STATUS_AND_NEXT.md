# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.135)

Purpose: current status and next step of PSS · owner coordinator · status current, updated every PR · related docs/pss/14_BUILD_HISTORY.md, docs/pss/01_HANDOVER.md

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.135, Spyglass fields: Fields panel, raw column names, chat-filter names (branch `claude/serene-bell-sdez3f`, PR #253):** rows F135a to F135d: Fields model replaces the sidebar, Fields panel (`>>`), raw column names, chat-filter names as `filter`, `sender`, `server` fields, dead Sidebar code removed; keys `CHK-00204` to `CHK-00206`; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: Spyglass 3.8.0.136 to 3.8.0.139, then Journal phases C and D; TBC compatibility after (`DEC-00409`).** Plan: [spyglass-journal plan](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/22/14-41-37-Thu-stoic-gates-r93b6b/projects/spyglass-journal/specs/plan.md#3-build-plan).
- **Planned, not built: quoted wildcards match like Splunk** (`owner="f:*"` returns 0 rows today; quotes make `*` literal; same on 3.8.0.134). The author, 2026-10-22: make it match Splunk, plan it in the next session; a quoted value without `*` still matches exactly.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- 3.8.0.135: in-game `CHK-00204` to `CHK-00206` passed (the author, 2026-10-22); merge PR #253.
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
