# Status and next step (2026-10-09)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. History: `reference/06_status-history-to-3.4.1.30.md` (to 3.4.1.30) and `reference/combined-3.4.1.52/` (the 3.4.1.52 stages).

## Now
- **Live release: 3.4.1.53** (PR #143, published 2026-10-09 and mirrored to `racetracks/Pour-Social-Score`). It closes the core uplift.
- **3.4.2.54** (PR pending): docs only, the baseline, scratch and PSS packs trimmed to the current state; no change in game.
- **No current project.** The next step is whatever Dan names; open items are below and in `13_CHANGES_IN_TRAIN.md`. The next build is 3.4.2.55 (`sh tools/bump_version.sh build "Title"`).

## Waiting on Dan
- Name the next project or fix.
- #144: add the `SCRATCH_TOKEN` secret so CI runs the real-save tests.
- #148: OK or revert P3 (inactive shipped lists no longer capture units or /who).
- #45: built in U2 and shipped in 3.4.1.53; Dan can close it.

## Known breaches
None (02 section 12).

## Open issues (addon repo)
- #37: the guild exclusion list is not saved (its intent needs defining).
- #38: seeing a shipped-guild member loads the lists.
- #39: unload the GUI on close.
- #40: research whether a LoadOnDemand addon can unload.
- #44: clean up console output.
- #45: Questie-style upgrade output (done; can close).
- #78: the 3.3.0 parity project (closed at 3.3.1, 08; can close).
- #125: right-click "Unblock Guild" on a shipped guild should turn the group's rule off instead of refusing.
- #132: test later, the Group Finder option without a /reload (needs a character that can use the Group Finder).
- #133: test later, the party warning names only who is in the group now.
- #144: CI real-save tests need the `SCRATCH_TOKEN` secret.
- #145: leftovers from the combined build (dead `stats`, option cache, Events `TimeText`, Chat Filters pane redraw).
- #146: the guild member cap only at logout; Camelot first-name-only names guessed.
- #147: going back from 3.4.1.53 loses custom filters (3.4.0.29) and later list entries.
- #148: P3, inactive shipped lists no longer capture units or /who; needs Dan's OK or a revert.

Context for each open item: scratch `docs/latest/issues/` and `docs/latest/setup/`.

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
