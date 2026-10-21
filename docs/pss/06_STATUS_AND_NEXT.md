# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.134)

Purpose: current status and next step of PSS · owner coordinator · status current, updated every PR · related docs/pss/14_BUILD_HISTORY.md, docs/pss/01_HANDOVER.md

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.134, Spyglass pane fix and layout: one list per pane, top bar, collapsible panels, wider Message (branch `claude/nice-noether-m6eqsa`, PR #242):** rows S1, L134a, L134b: stale pane rows purged, search bar always on row 1, side panels collapsible (right closed by default), Message column at least 40 % wide, Edit search removed; replaces `CHK-00176` with `CHK-00195` to `CHK-00198`; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: TBC compatibility; the author designs it first (the author, 2026-10-21).** 3.8.0.134 is merged untested to get Spyglass live (PR #242); the Spyglass remediation builds 3.8.0.135 to .139 (friendly fields, names and filters, fluid pane and drag, time parts, pre-release) are **paused, not dropped**, and resume once the addon is TBC compatible: plan pack `scratch:temp/2026/10/21/14-56-10-Wed-great-ramanujan-8xw2kr/projects/spyglass-remediation-4/specs/plan.md`, roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`); journal, bags and optimisation follow it.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- 3.8.0.134 (merged untested, PR #242): run in-game `CHK-00195` to `CHK-00198` on the 3.8.0.134 zip, each in Modern, Classic and Dark (`CHK-00190` to `CHK-00193` from 3.8.0.133 are still unreported); the asks O1 to O3 (02 section 11 rules 11 and 12, the guild pane) are still open.
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
