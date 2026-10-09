# Status and next step (2026-10-09, 3.6.0.68 after release 3.5.0.62)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. History: `reference/06_status-history-to-3.4.1.30.md` (to 3.4.1.30) and `reference/combined-3.4.1.52/` (the 3.4.1.52 stages).

## Now
- **3.6.0.68, the author's three profile issues in one build** (the author, 2026-10-09: "resolve all 3 issues in same build"; PSS 02 section 12 Overrides row; awaiting the author's in-game testing): [#175](https://github.com/racetracks/PourSocialScore/issues/175) every "Set" is now "Addon Profile" (drop-down label "Profiles"; commands `/pss acp profile` and `profiles`, `set` and `sets` still work); [#176](https://github.com/racetracks/PourSocialScore/issues/176) Rename is offered on every place (free, used and the class one; a named free place is kept empty; names 1 to 32 ASCII letters, not empty, no duplicate in the store); [#177](https://github.com/racetracks/PourSocialScore/issues/177) places 1 to 5 are Core Addon Profiles, a line, then Layered (6 to 25 and the class one); the drop-down is a list of ticks (the kit's `Check`, which already keeps a menu open: no new kit control) and "Manage Addon Profiles" opens the places' actions. Selecting turns the profile's addons on; deselecting turns off only what no other selected profile, hand pick or protected addon wants; load, Enable All, Disable All and Undo reset the selection. New saved keys `addonSel` and `addonPick` (both stores, packed strings, sparse; schema entry; no migration needed, saves identical until used). Build record: scratch `docs/components/addon-manager/03_BUILD_NOTES.md`.
- **3.6.0.66, the author's two focus issues in one build** (the author, 2026-10-09: "goes as one combined build, i give permission to override"; PSS 02 section 12 Overrides row): [#171](https://github.com/racetracks/PourSocialScore/issues/171) sets the ACP way (the Sets drop-down at the bottom left, beside the count; its menu lists the 25 numbered places of the scope shown and your class's, a free one as "Set N (empty)"; a place's actions: Save (a confirm that stores the addons now on, keeping its name), Load, Add to current, Remove from current, Rename (name field; not the class set), Delete; the separate new-set step is gone; `M.PSS_AddonSlots`, `V:Slots`) and [#172](https://github.com/racetracks/PourSocialScore/issues/172) the AddOns tab after Chat Filters (tab 4; Events 5, Import/Export 6, Options 7; the last tab is saved by key, so no migration). Tested fine in game (the author, 2026-10-09; #171 and #172 closed); build record: scratch `docs/components/addon-manager/03_BUILD_NOTES.md`. Design and plan: https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/components/addon-manager
- **3.6.0.64, the addon manager, all five stages in one build** (the author, 2026-10-09: "implement the entire feature in one pass"; PSS 02 section 12 Overrides row): the AddOns tab (tab 7 then, tab 4 from 3.6.0.66; all three looks), `/pss acp` and `/acp` (only when free), the key binding "Open AddOns", the second Retail Addon Compartment entry, CPU and memory (stats row, row and header hover), sets and protected addons per character (`PSS_CharDB`) and account-wide (`PSS_OptionsDB`), the kit's `ns.Confirm` `name` field and `ns.FileTexture`. Design and plan: scratch `docs/components/addon-manager/`; build record: its `03_BUILD_NOTES.md`. Tested fine in game (the author, 2026-10-09) (design section 9, the build's list in the PR); fixes are the next builds on line 3.6.0. The line's release is when the author calls it.
- **Deviations from the design, measured (the PR has the numbers):** resident 130 KB for the two Libraries files (the design's 40 KB was an estimate; Libraries loads on first use only); core +1.7 KB resident at login (alias, binding, second compartment entry; the design said 0); the list build makes about 6 KB of garbage per rebuild at 150 addons after the first (budget 32 KB met), kept after close under 0.5 KB; Libraries objects are arrays of addon indexes read live, not a record per addon; the sets are called presets in code (`M.PSS_AddonPreset*`) because the clean-room copy guard forbids the other manager's `AddonSet` identifier, "Sets" in text.
- **Release 3.5.0.62** (Graphics settings and Macro Helper) is live (PR #158). The macros themselves are still drip-fed from umbrella issue #159 (one build per ask, now `3.6.x` numbers: the next free build).

## Waiting on the author
- Test 3.6.0.68 in game (the numbered checks in the build record); #177's decisions were built on the recommended options (core 1 to 5, union only, manual picks kept apart, load on the existing flow, class place under Layered); say so if any should differ.
- Test the release build in game (Camelot: the Macro Helper checks, design section 9 on scratch `docs/latest/macro-helper/01_DESIGN.md`; a very old save too, `11_PREFERENCES.md`), (#158 is merged: release 3.5.0.62 is live). Check the release workflow ran (jobs release and mirror, https://github.com/racetracks/PourSocialScore/actions).
- Ask for macros from #159 when ready.
- #144: add the `SCRATCH_TOKEN` secret so CI runs the real-save tests.
- #148: OK or revert P3 (inactive shipped lists no longer capture units or /who).

## Known breaches
None (02 section 12).

## Open issues (addon repo)
- #175, #176, #177: addon manager, addon profiles (built in 3.6.0.68; close them once tested).
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
