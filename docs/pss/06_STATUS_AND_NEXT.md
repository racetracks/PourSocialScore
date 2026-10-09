# Status and next step (2026-10-09, 3.6.0.65 after release 3.5.0.62)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. History: `reference/06_status-history-to-3.4.1.30.md` (to 3.4.1.30) and `reference/combined-3.4.1.52/` (the 3.4.1.52 stages).

## Now
- **Next, the author's two focus issues (2026-10-09; docs build 3.6.0.65 wrote them down; each is a fix build on line 3.6.0, read the addon manager folder first):** [#171](https://github.com/racetracks/PourSocialScore/issues/171) create sets exactly as ACP does, with the Sets drop-down at the bottom left (context: scratch `docs/latest/issues/addon-manager-sets-acp-way.md`; design 4.4 and decision 26, plan 4.9a); [#172](https://github.com/racetracks/PourSocialScore/issues/172) the AddOns tab after Chat Filters (context: `docs/latest/issues/addon-manager-tab-order.md`; design decision 27). Design and plan: https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/components/addon-manager
- **3.6.0.64, the addon manager, all five stages in one build** (the author, 2026-10-09: "implement the entire feature in one pass"; PSS 02 section 12 Overrides row): the AddOns tab (tab 7, all three looks), `/pss acp` and `/acp` (only when free), the key binding "Open AddOns", the second Retail Addon Compartment entry, CPU and memory (stats row, row and header hover), sets and protected addons per character (`PSS_CharDB`) and account-wide (`PSS_OptionsDB`), the kit's `ns.Confirm` `name` field and `ns.FileTexture`. Design and plan: scratch `docs/components/addon-manager/`; build record: its `03_BUILD_NOTES.md`. Waiting on the author's in-game checks (design section 9, the build's list in the PR); fixes are the next builds on line 3.6.0. The line's release is when the author calls it.
- **Deviations from the design, measured (the PR has the numbers):** resident 130 KB for the two Libraries files (the design's 40 KB was an estimate; Libraries loads on first use only); core +1.7 KB resident at login (alias, binding, second compartment entry; the design said 0); the list build makes about 6 KB of garbage per rebuild at 150 addons after the first (budget 32 KB met), kept after close under 0.5 KB; Libraries objects are arrays of addon indexes read live, not a record per addon; the sets are called presets in code (`M.PSS_AddonPreset*`) because the clean-room copy guard forbids the other manager's `AddonSet` identifier, "Sets" in text.
- **Release 3.5.0.62** (Graphics settings and Macro Helper) is live (PR #158). The macros themselves are still drip-fed from umbrella issue #159 (one build per ask, now `3.6.x` numbers: the next free build).

## Waiting on the author
- Test the addon manager build 3.6.0.64 in game (Retail and Camelot, all three looks): the numbered checks in its PR and scratch `docs/components/addon-manager/03_BUILD_NOTES.md`; tell the author-side results so the fallbacks (the star file, `bag-arrow`, the argument orders, the GUID) are confirmed.
- Test the release build in game (Camelot: the Macro Helper checks, design section 9 on scratch `docs/latest/macro-helper/01_DESIGN.md`; a very old save too, `11_PREFERENCES.md`), (#158 is merged: release 3.5.0.62 is live). Check the release workflow ran (jobs release and mirror, https://github.com/racetracks/PourSocialScore/actions).
- Ask for macros from #159 when ready.
- #144: add the `SCRATCH_TOKEN` secret so CI runs the real-save tests.
- #148: OK or revert P3 (inactive shipped lists no longer capture units or /who).

## Known breaches
None (02 section 12).

## Open issues (addon repo)
- #171: addon manager, sets the ACP way, drop-downs bottom left (next).
- #172: addon manager, AddOns tab after Chat Filters (next).
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
