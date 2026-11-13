# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.120, 3.8.0.123 to 3.8.0.135, 3.8.0.139 to 3.8.0.144, 3.8.0.148 to 3.8.0.153, 3.9.0.154, 3.9.0.155)

Purpose: current status and next step of PSS · owner coordinator · status current, updated every PR · related docs/pss/14_BUILD_HISTORY.md, docs/pss/01_HANDOVER.md

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. What each build changed and why: `docs/pss/14_BUILD_HISTORY.md` (written at every build, not loaded at start). Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`16_02_Build_Ledger.md` (`scratch:documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md`)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.9.0.155, Journal monitors (branch `claude/wonderful-cannon-zwshli`, PR: none yet):** Journal monitors: vendor and repair, basic monitors, auction houses (hooks and adapters in the build history), fuzz and gold fixes; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).
- **Harness fix, no build (from PR #267, merged into PR #269):** `tools/harness/build_saves.sh` puts a client folder's later saves under their client again (`docs/pss/07_HARNESS.md#changelog`); issue #268 (old saves fail real-saves) stays open.
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 (PR #238, merged; the author's re-test passed 2026-10-18).** What each build did: the status history (`docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`), `history.txt` and `versions.json`.
- **Next: the search speed fix is merged as 3.8.0.153 (PR #277; its CI text-search gate on `tbc/3.8.0.143` stays red, a follow-up build only if the author asks); the paused Spyglass builds follow, Journal after; the Forever re-run build goes first after 2026-11-04.** Plan: [spyglass-journal plan](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/22/14-41-37-Thu-stoic-gates-r93b6b/projects/spyglass-journal/specs/plan.md#3-build-plan).
- **Planned, not built: quoted wildcards match like Splunk** (`owner="f:*"` returns 0 rows today; quotes make `*` literal; same on 3.8.0.134). The author, 2026-10-22: make it match Splunk, plan it in the next session; a quoted value without `*` still matches exactly.
- Next for managed communities: build B (fixture), then build C (retire Olympus), from the pack `managed-communities`.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- 3.9.0.155: in-game [`CHK-00151`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/journal-helper/15_Tests.md#chk-00151), [`CHK-00152`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/journal-helper/15_Tests.md#chk-00152), [`CHK-00153`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/journal-helper/15_Tests.md#chk-00153) (Forever, once more with both restriction consoles for the first and third), [`CHK-00252`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/12-01-00-Tue-sleepy-edison-9fcgmj/projects/journal/specs/tests.md#chk-00252) (Forever, MCD); in-game steps for the five unverified APIs (baseline J11), each also in the PR's in-game check list: step 6: check `C_Container.GetContainerItemPurchase*` (unverified API); step 7: check `GetMerchantItemInfo` price and quantity (unverified API); step 8: check the loot money slot quantity read as copper (unverified API); step 9: check `GetTrainerServiceCost` (unverified API); step 10: check `QUEST_LOOT_RECEIVED` arriving before `QUEST_TURNED_IN` (unverified API).
- 3.9.0.154: in-game [`CHK-00210`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/22/14-41-37-Thu-stoic-gates-r93b6b/projects/spyglass-journal/specs/tests.md#4-in-game-checks-per-build), [`CHK-00211`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/22/14-41-37-Thu-stoic-gates-r93b6b/projects/spyglass-journal/specs/tests.md#4-in-game-checks-per-build), [`CHK-00154`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/journal-helper/15_Tests.md#chk-00154), [`CHK-00250`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/projects/journal/specs/tests.md#chk-00250) on Forever, TBC (Retail: load and version detection only); CHK-00250 is confirmation only.
- 3.8.0.153 (PR #277, merged 2026-11-13): `CHK-00255` waived (the author); CI text-search gate on `tbc/3.8.0.143` red (7.41 ms vs gate 4.9 ms); a fix build only if asked.
- 3.8.0.150: in-game [`CHK-00254`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/16_Registries/REGISTRY.md#chk-00254) (step 3); then merge the PR.
- 3.8.0.149: the global set's in-game checks (issue #160, PR #273) passed (the author, 2026-11-11); merge PR #273.
- 3.8.0.148: in-game [`CHK-00245`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/08-14-00-Tue-epic-turing-wqqpmr/projects/managed-communities/specs/managed-communities.md#chk-00245); then merge PR #271.
- 3.8.0.145 to 3.8.0.147: the Shaman (issue #168) and Priest (issue #166) sets' in-game checks in PR #270, then merge it.
- 3.8.0.143: in-game `CHK-00244` passed on Forever and TBC (the author, 2026-11-10; saves `SavedVariables/3.8.0.143-forever` and `tbc/3.8.0.143` on scratch); the 3.8.0.142 checks passed (the author, 2026-11-10), `CHK-00229` parked (no guild bank); merge PR #266.
- 3.8.0.141 results (scratch `temp/2026/11/09/04-56-47-Mon-clever-archimedes-rdplx7/results/README.md#results`): B1 `CHK-00228` pass; B2 `CHK-00229` deferred (no guild shows tab 2); B3 `CHK-00230` pass with a bug (search freezes the game up to 10 s, to the search speed build); B4 `CHK-00113` pass ("I think", closes #234 once confirmed); B5 `CHK-00225` pass; T1 `CHK-00218` fail (TBC tabs half formed, fixed by 3.8.0.142); T2 `CHK-00219` pass; T3 `CHK-00220` pass; T4 `CHK-00222` pass with a text change (Camelot to Forever, fixed by 3.8.0.142); F1 to F6 (`CHK-00223`, `CHK-00221`, `CHK-00227`) pass, ran on 3.8.0.139; F7 first Forever save done (`SavedVariables/3.8.0.139-forever-launch`).
- 3.8.0.141: merge PR #261.
- 3.8.0.139 (TBC B3): in-game `CHK-00221`, `CHK-00222`, `CHK-00110` and `CHK-00225` passed on TBC Anniversary (the author, 2026-10-27; `CHK-00110` closes #233); merge PR #260. Retail is out of scope (the author, 2026-10-27): the `CHK-00224` re-run and `CHK-00227` are not run; `CHK-00223` (Forever) blocked until 2026-11-04. Next session: scratch `temp/2026/10/24/16-08-38-Sat-b3-compat-shim-k4w9tq/next-steps/B4-prompt.md`; B4OK: the first TBC save on scratch before B4T2.
- 3.8.0.138 (TBC B2): `CHK-00217` and `CHK-00226` passed (the author, 2026-10-24).
- 3.8.0.136 (TBC B1): in-game `CHK-00224` (Retail), in Modern, Classic and Dark. `CHK-00223` (Forever) is **blocked: Forever beta down until launch on 2026-11-04** (the author, 2026-10-23): no Forever in-game checks and no new Forever saves until then; Forever is covered by the harness flavours only (scratch holds no Forever save yet); after launch one build re-runs every Forever check and captures the first Forever save; that build goes first after 2026-11-04, ahead of any build in progress (the author, 2026-10-23).
- 3.8.0.135: in-game `CHK-00204` to `CHK-00206` passed (the author, 2026-10-22); merge PR #253.
- Test a very old save on 3.7.0.113 (the final pre-release), then merge the 3.7.0.114 release PR; then hand phase A its guide (section G0 of 12_02_Phase_A_Spyglass_Engine.md (`scratch:documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md`)).
- Run `CHK-00113` on a live realm with a guild bank (#234); `CHK-00117` and `CHK-00118` have no recorded result.
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
