# Status and next step (release 3.7.0.114; built 3.8.0.116 to 3.8.0.119)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. Earlier builds: `history.txt`, `versions.json` and the build records on scratch ([`16_02_Build_Ledger.md`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/addon-helper/16_Registries/16_02_Build_Ledger.md)). History: `reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.8.0.119, docs build (branch `claude/elegant-dijkstra-2oq5s5`):** this file keeps only the current and next builds; the per-build history of 3.6.0.69 to 3.8.0.118 moved unchanged to [`reference/06_status-history-3.6.0.69-to-3.8.0.118.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md) (it loaded in every session, about 15k tokens); the unused prompt hook `.claude/hooks/inject_prefix.py` is deleted and `CLAUDE.md` says the Operating Instructions reach sub-agents through `CLAUDE.md` itself (the leftovers of the closed [PR #239](https://github.com/racetracks/PourSocialScore/pull/239)). Nothing in the addon changes. Every later planned build moves up one (the author, 2026-10-18).
- **Last code build: 3.8.0.118, Spyglass phase A with its fixes 3.8.0.117 and 3.8.0.118 ([PR #238](https://github.com/racetracks/PourSocialScore/pull/238), merged; the author's re-test passed 2026-10-18).** What each build did: the [status history](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md), `history.txt` and `versions.json`.
- **Next: phase B, the Spyglass console, 3.8.0.120, then the Spyglass release 3.8.0.121, a pre-release** ([`DEC-00337`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/00_Decisions.md#dec-00337); guide section G0, [roadmap Next Steps](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps)); journal 3.9.0.122 to .124, bags 3.10.0.125 to .127, optimisation 3.11.0.128 and .129.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- Test a very old save on 3.7.0.113 (the final pre-release), then merge the 3.7.0.114 release PR; then hand phase A its guide (section G0 of [12_02_Phase_A_Spyglass_Engine.md](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md)).
- Run `CHK-00110` when the TBC stage opens ([#233](https://github.com/racetracks/PourSocialScore/issues/233)) and `CHK-00113` on a live realm with a guild bank ([#234](https://github.com/racetracks/PourSocialScore/issues/234)); `CHK-00117` and `CHK-00118` have no recorded result.
- [#231](https://github.com/racetracks/PourSocialScore/issues/231): the undo check skips the planted 3.4.1.50 save.
- On request before or with S3: move the superseded drafts to history, the decisions lint and contents writer, the planned-builds registry ([`DEC-00234`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/00_Decisions.md#dec-00234) to [`DEC-00236`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/code-map/00_Decisions.md#dec-00236)).
- Drop Cheapest Thing stage 7; macros from [#159](https://github.com/racetracks/PourSocialScore/issues/159) when ready.
- Closed on GitHub since the last update (sweep 2026-10-14): [#144](https://github.com/racetracks/PourSocialScore/issues/144), [#148](https://github.com/racetracks/PourSocialScore/issues/148), [#179](https://github.com/racetracks/PourSocialScore/issues/179), [#189](https://github.com/racetracks/PourSocialScore/issues/189), [#192](https://github.com/racetracks/PourSocialScore/issues/192).

## Known breaches
None (02 section 12).

## Open issues (addon repo, checked 2026-10-17)
- [#231](https://github.com/racetracks/PourSocialScore/issues/231): the undo check skips the planted 3.4.1.50 save.
- [#233](https://github.com/racetracks/PourSocialScore/issues/233): the Syndicator import check (`CHK-00110`) waits for the TBC stage.
- [#234](https://github.com/racetracks/PourSocialScore/issues/234): the guild bank check (`CHK-00113`) waits for a live realm.
- [#227](https://github.com/racetracks/PourSocialScore/issues/227): Disenchant Helper integration (proposed).
- [#228](https://github.com/racetracks/PourSocialScore/issues/228): Enemy Frames integration (proposed).
- Closed since 2026-10-14: [#224](https://github.com/racetracks/PourSocialScore/issues/224) (built in S3, 3.7.0.104).
- [#215](https://github.com/racetracks/PourSocialScore/issues/215): the scratch gate runs everywhere; strict gate green on `main` ([run 38573450333](https://github.com/racetracks/PourSocialScore/actions/runs/38573450333)).
- [#217](https://github.com/racetracks/PourSocialScore/issues/217) to [#220](https://github.com/racetracks/PourSocialScore/issues/220): code map findings and files to add.
- [#212](https://github.com/racetracks/PourSocialScore/issues/212): Drop Cheapest Thing as an opt-in integration.
- [#197](https://github.com/racetracks/PourSocialScore/issues/197): rename "Addon Manager" to "Addon Helper" (later).
- [#159](https://github.com/racetracks/PourSocialScore/issues/159) to [#169](https://github.com/racetracks/PourSocialScore/issues/169): Macro Helper macros, one issue per set.
- [#152](https://github.com/racetracks/PourSocialScore/issues/152), [#147](https://github.com/racetracks/PourSocialScore/issues/147), [#146](https://github.com/racetracks/PourSocialScore/issues/146), [#145](https://github.com/racetracks/PourSocialScore/issues/145), [#133](https://github.com/racetracks/PourSocialScore/issues/133), [#132](https://github.com/racetracks/PourSocialScore/issues/132), [#125](https://github.com/racetracks/PourSocialScore/issues/125), [#44](https://github.com/racetracks/PourSocialScore/issues/44), [#39](https://github.com/racetracks/PourSocialScore/issues/39), [#38](https://github.com/racetracks/PourSocialScore/issues/38), [#37](https://github.com/racetracks/PourSocialScore/issues/37): as before (window memory, downgrade loss, member cap, leftovers, tests later, unblock guild, console output, memory on close, shipped members, guild exclusion list).

Context for each open item: scratch `docs/latest/issues/` and `docs/latest/setup/`.

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
