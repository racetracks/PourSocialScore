# Status and next step (2026-10-08)

Kept short and current: every PR updates it (baseline 02 E10). History up to 3.4.1.30 is in `reference/06_status-history-to-3.4.1.30.md`. The addon as it works is in `01_HANDOVER.md`; the current plan is `10_CORE_UPLIFT.md`.

## Now
- **Live release: 3.4.0.29** (full, the new PSS window; mirrored to `racetracks/Pour-Social-Score`). **Main: 3.4.1.35** (B1 merged, PR #123).
- **Current project: core uplift** (`10_CORE_UPLIFT.md`, locked by Dan on 2026-10-08). It runs on three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy.
- **Done:** N1 (3.4.1.32), N2 (3.4.1.33), plan B (3.4.1.34, docs only), B1 (3.4.1.35: PSS authoritative over Blizzard's ignore list, per-player tick, upgrade step 8).
- **On its PR: B2, 3.4.1.36** (PR #124): the right-click "PSS" header with Block Player / Block Guild (10 section 2.7 "Done in B2").
- **Next:** N3 (3.4.1.37, builder fix and the shipped lists rebuilt), then F1.
- The closed projects: the PSS window (3.4.0, `09_PSS_UI_PROJECT.md`; its code map and lessons stay the reference for the window) and parity (3.3.1, `08`).

## Waiting on Dan
1. Archive `racetracks/PourSocialScore-EllesmereUI` and close its PR #18.
2. Delete merged `claude/*` branches (Claude gets 403).
3. Close issue #78 (parity, closed at 3.3.1).

## Known breaches
In 02 section 12, each with its fix line. The idle GC cycle is fixed by core uplift P2 (3.4.2).

## Open issues (addon repo)
- #37: the guild exclusion list is not saved (its intent needs defining).
- #38: seeing a shipped-guild member loads the lists.
- #39: unload the GUI on close.
- #40: research whether a LoadOnDemand addon can unload.
- #44: clean up console output.
- #45: Questie-style upgrade output (core uplift U2).
- #78: parity (the project closed at 3.3.1).

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
