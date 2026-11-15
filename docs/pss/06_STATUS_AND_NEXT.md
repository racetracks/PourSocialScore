# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.135, 3.8.0.139 to 3.8.0.144, 3.8.0.148 to 3.8.0.153, 3.9.0.154, 3.9.0.155, 3.9.0.156, 3.9.0.157, 3.9.0.158, 3.9.0.159)

Purpose: current status and next step of PSS · owner coordinator · status current, updated every PR · related docs/pss/14_BUILD_HISTORY.md, docs/pss/01_HANDOVER.md

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.9.0.159, PSS TestKit shell and R158 fixes (branch `claude/inspiring-brown-p46z1p`, PR: none yet):** PSS TestKit shell (kit window `/pss test`, package TK.1), developer filter (`devMode`, off by default) and the R158 deferred fixes; no change for players; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **Harness fix, no build (from PR #267, merged into PR #269):** `tools/harness/build_saves.sh` puts a client folder's later saves under their client again (`docs/pss/07_HARNESS.md#changelog`); issue #268 (old saves fail real-saves) stays open.
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: the search speed fix is merged as 3.8.0.153 (PR #277; its CI text-search gate on `tbc/3.8.0.143` stays red, a follow-up build only if the author asks); the paused Spyglass builds follow, Journal after; the Forever re-run build goes first after 2026-11-04.** Plan: [spyglass-journal plan](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/22/14-41-37-Thu-stoic-gates-r93b6b/projects/spyglass-journal/specs/plan.md#3-build-plan).
- **Planned, not built: quoted wildcards match like Splunk** (`owner="f:*"` returns 0 rows today; quotes make `*` literal; same on 3.8.0.134). The author, 2026-10-22: make it match Splunk, plan it in the next session; a quoted value without `*` still matches exactly.
- Next for managed communities: build B (fixture), then build C (retire Olympus), from the pack `managed-communities`.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- 3.9.0.159: in-game checks CHK-00260, CHK-00261, CHK-00262 (Forever and TBC; Retail CHK-00260 and CHK-00261); answer card DEC-00501 (new saved option `devMode`); review and merge the PR.
- 3.9.0.158: no in-game checks; review and merge the PR.
- 3.9.0.155: accepted, PR #279 merged (the author, 2026-11-15); follow-up fix build in issue #281.
- 3.7.0.113 to 3.9.0.154: every PR merged (checked 2026-11-15); all checks with no recorded result waived, superseded by the accepted 3.9.0.155 (the author, 2026-11-15, "waive old checks"); the list before this change is in git history of this file.
- #231: the undo check skips the planted 3.4.1.50 save.
- On request before or with S3: move the superseded drafts to history, the decisions lint and contents writer, the planned-builds registry (`DEC-00234` to `DEC-00236`).
- Drop Cheapest Thing stage 7; macros from #159 when ready.

## Known breaches
None (02 section 12).

## Open issues
On GitHub: https://github.com/racetracks/PourSocialScore/issues (context for each: scratch `docs/latest/issues/` and `docs/latest/setup/`).

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
