# Status and next step (2026-10-09, 3.5.1.63 after release 3.5.0.62)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. History: `reference/06_status-history-to-3.4.1.30.md` (to 3.4.1.30) and `reference/combined-3.4.1.52/` (the 3.4.1.52 stages).

## Now
- **Next workload: the addon manager** (the author, 2026-10-09): an AddOns tab in the PSS window, `/pss acp` and its alias `/acp`, the behaviour of ACP 3.5.16 rewritten clean-room, with CPU and memory per addon (hover, group sums, a stats row), sets and protected addons per character or account-wide. Line **3.6.0**, five stages, stage 1 next at the next free build. Design and plan: scratch `docs/components/addon-manager/` (https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/components/addon-manager); **ingest the whole folder before implementing** (`CLAUDE.md` read-when list), never its `reference/` zip.
- **3.5.1.63** (this PR): docs only, sets the addon manager as the next workload; the first macros from #159 move to 3.5.1.64.
- **Release 3.5.0.62, Graphics settings and Macro Helper** (the author said "send the release", 2026-10-09; PR #158, merges the Macro Helper build 3.5.0.61 and the release build together; merging publishes the full release and mirrors it). Line 3.5.0: graphics settings (`/pss gfx`, Camelot, built 3.5.0.57, tested fine by the author) and the Macro Helper framework (`/pss macro`, Camelot, built 3.5.0.61: Trinket 1, Trinket 2, Attack). Notes: scratch `docs/latest/release-notes/3.5.0.62.md` and `summary-of-changes/SUMMARY_OF_CHANGES.md`; designs `docs/latest/graphics-settings/` and `docs/latest/macro-helper/`; checklist `docs/latest/release-3.5.0/01_RELEASE_READINESS.md`.
- Before 3.5.0.62: live release 3.4.2.54 (PR #150, docs only); 3.4.3.55 to 3.5.0.60 docs builds (PRs #151, #153, #155 to #157) and 3.5.0.57 graphics settings (PR #154).
- **The macros themselves are drip-fed after the release (the author, 2026-10-09): umbrella issue #159** (https://github.com/racetracks/PourSocialScore/issues/159, one issue per set, #160 global, #161 Warrior, #162 Druid, #163 Hunter, #164 Mage, #165 Paladin, #166 Priest, #167 Rogue, #168 Shaman, #169 Warlock). The author posts macros as comments on a set's issue (first line the name, the rest the body; optional `store:` / `icon:` lines) and asks for them ("add the macros from #165"); each ask is one build, the first is 3.5.1.64 (3.5.1.63 was this docs build). The Paladin's first four (Cleanse, Purify, DS, HS) are already on #165. How: the umbrella's steps; context on scratch `docs/latest/issues/macro-sets/`.

## Waiting on the author
- Test the release build in game (Camelot: the Macro Helper checks, design section 9 on scratch `docs/latest/macro-helper/01_DESIGN.md`; a very old save too, `11_PREFERENCES.md`), (#158 is merged: release 3.5.0.62 is live). Check the release workflow ran (jobs release and mirror, https://github.com/racetracks/PourSocialScore/actions).
- Ask for macros from #159 when ready.
- #144: add the `SCRATCH_TOKEN` secret so CI runs the real-save tests.
- #148: OK or revert P3 (inactive shipped lists no longer capture units or /who).

## Known breaches
None (02 section 12).

## Open issues (addon repo)
- #37: the guild exclusion list is not saved (its intent needs defining).
- #38: seeing a shipped-guild member loads the lists.
- #39: unload the GUI on close.
- #40: research whether a LoadOnDemand addon can unload.
- #44: clean up console output.
- #125: right-click "Unblock Guild" on a shipped guild should turn the group's rule off instead of refusing.
- #132: test later, the Group Finder option without a /reload (needs a character that can use the Group Finder).
- #133: test later, the party warning names only who is in the group now.
- #144: CI real-save tests need the `SCRATCH_TOKEN` secret.
- #145: leftovers from the combined build (dead `stats`, option cache, Events `TimeText`, Chat Filters pane redraw).
- #146: the guild member cap only at logout; Camelot first-name-only names guessed.
- #147: going back from 3.4.1.53 loses custom filters (3.4.0.29) and later list entries.
- #148: P3, inactive shipped lists no longer capture units or /who; needs the author's OK or a revert.

Context for each open item: scratch `docs/latest/issues/` and `docs/latest/setup/`.

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
