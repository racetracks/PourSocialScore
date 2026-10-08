# Status and next step (2026-10-08)

Kept short and current: every PR updates it (baseline 02 E10). History up to 3.4.1.30 is in `reference/06_status-history-to-3.4.1.30.md`. The addon as it works is in `01_HANDOVER.md`; the current plan is `10_CORE_UPLIFT.md`.

## Now
- **Live release: 3.4.0.29** (full, the new PSS window; mirrored to `racetracks/Pour-Social-Score`). **Main: 3.4.1.34** (PR #122, the B1/B2 plan; docs only).
- **Current project: core uplift** (`10_CORE_UPLIFT.md`, locked by Dan on 2026-10-08). It runs on three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy.
- **Done:** N1 (3.4.1.32, `M.PSS_NormName`), N2 (3.4.1.33, every caller; decision 13 reversed, realm names unchanged; `_managed` still saved until S2/S3), plan B (3.4.1.34, docs only).
- **On its PR: B1, 3.4.1.35** (PSS authoritative over Blizzard's ignore list; 10 section 2.7 "Done in B1"): the per-player tick in the View/Edit Rule page, a new Blizzard ignore moved into PSS with its note and off Blizzard's list, the existing Blizzard list synced across at login, removal both ways, upgrade step 8 (the global option to the ticks), Blizzard's own ignore lines no longer hidden after login.
- **Next:** B2 (3.4.1.36, the right-click "PSS" header with Block Player and Block Guild), then N3 (3.4.1.37, the shipped lists rebuilt).
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
