# Status and next step (2026-10-09, release 3.4.1.53)

Kept short and current: every PR updates it (baseline 02 E10). History up to 3.4.1.30 is in `reference/06_status-history-to-3.4.1.30.md`; the core uplift's per-stage status (3.4.1.42 to 3.4.1.52) is in `10_CORE_UPLIFT.md` (Done in ...) and `reference/combined-3.4.1.52/`. The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`.

## Now
- **Release 3.4.1.53 (PR #143; Dan, 2026-10-09: "launch a release"):** version only. The 3.4.1 line's release and the end of the core uplift. Its notes (history.txt, the release body) are one player-facing summary of PRs #118 to #142 (3.4.1.30 to 3.4.1.52). `01_HANDOVER.md` is re-summarized at 3.4.1.53; `12_CODE_MAP.md` (and `reference/code-map/`) and `13_CHANGES_IN_TRAIN.md` are refreshed; `10_CORE_UPLIFT.md` is marked closed and no longer loads in every session; readme lists `/pss export unused`. Merging publishes the full release and mirrors it to `racetracks/Pour-Social-Score` (`release.yml` runs the rules check and the harness first).
- **Live release: 3.4.0.29** until the release PR merges, then **3.4.1.53**. **Main: 3.4.1.52** (the combined build: S3, P1 to P6, W1 to W4; PR #142, merged 2026-10-09).
- **No current project.** Every core uplift stage is built (3.4.1.32 to 3.4.1.52; the 3.4.2 and 3.4.3 lines were folded into 3.4.1.52, decision 28). What is left open is in `13_CHANGES_IN_TRAIN.md` and below. A fix after the release starts line 3.4.2 at build 3.4.2.54 (`sh tools/bump_version.sh line 3.4.2 "Title"`).
- **Next:** Dan merges the release PR and checks the GitHub Release and the mirror; then names the next project or fix.

## Waiting on Dan
- Merge the 3.4.1.53 release PR (#143). (Your habit is to test a very old save on the final pre-release before a full release: 3.4.1.52's test zip is the one; the harness ran it on the 2.0.44, 3.0.0, 3.2.0-dev011, 3.4.0.28 and 3.4.1.50 saves.)

## Known breaches
In 02 section 12, each with its fix line. None: the idle GC cycle was fixed by P2 in 3.4.1.52.

## Open issues (addon repo)
- #37: the guild exclusion list is not saved (its intent needs defining).
- #38: seeing a shipped-guild member loads the lists.
- #39: unload the GUI on close.
- #40: research whether a LoadOnDemand addon can unload.
- #44: clean up console output.
- #45: Questie-style upgrade output: built in U2 (3.4.1.46), ships in 3.4.1.53; Dan can close it.
- #132: test later, the Group Finder option without a /reload (F1 check 4; needs a character that can use the Group Finder).
- #133: test later, the party warning names only who is in the group now (F1 check 7).
- #144: CI real-save tests need the `SCRATCH_TOKEN` secret (setup steps in the issue).

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
