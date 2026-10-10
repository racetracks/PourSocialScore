# Status and next step (3.6.0.74, after release 3.5.0.62)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`docs/components/addon-manager/03_BUILD_NOTES.md`). History: `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.6.0.74 (built, awaiting the author's in-game checks; PR opened on request):** #179 Enable all / Disable all in a profile's side menu (`STP-00011`; scratch `docs/components/addon-manager/04_ENABLE_DISABLE_ALL.md` section 8: `DEC-00012`, `TST-00006`, `CHK-00001`; record `BLD-00001`). They replace Add to current selection / Remove from current selection; a manual group tick (`M.PSS_AddonPresetTick`); greyed as kit titles when the profile has no installed addon (no kit change). The author tested 3.6.0.69 on 2026-10-10: #176, #177, #180, #181 closed.
- **3.6.0.73, docs build:** the next steps are set to #176, #177, #179, #180, #181, #183, #184 (`DEC-00011`, `STP-00009` to `STP-00013`); #179 moves to 3.6.0.74, #183 to 3.6.0.75, #184 to 3.6.0.76.
- **3.6.0.72, docs build:** the reference framework gains the type `RET` (Retired, own counter from `00001`; scratch `DEC-00009`) and a `00_References.md` in every documentation folder (`DEC-00010`): `refkey.py retire` maps an old key to its replacement; `CLAUDE.md` says how (`STP-00007`, `STP-00008`). #179 moves from 3.6.0.72 to 3.6.0.73.
- **3.6.0.71, docs build:** `CLAUDE.md`, PSS 02 and baseline 02 consolidated (same rules, no dates or build history; build history lives in `history.txt` and the build records) and this file trimmed. #179 moves from 3.6.0.71 to 3.6.0.72.
- **3.6.0.69 (PR #182, merged; the author's test passed 2026-10-10):** the Addon Profiles rework for #176, #177, #180 (#175 closed) and Enabled components #181.
  - Profiles are saved ACP's way: every place in the Profiles drop-down (Core 1 to 5, a line, Layered 6 to 25 and the class one), a place's side menu (Select or Deselect, Save with one confirm, Load, Add to current selection, Remove from current selection, Rename, Delete; a selected place marked `*`), any selected together (union plus hand picks; keys `addonSel`, `addonPick`); the kit's `m:Sub` (Blizzard submenu; a swap under "< Back" in Dark) fixed the menu closing; the drop-down is 190 wide and opens down in every look; the count is right-anchored to Undo. Not built (kept different from ACP): Default set, silent no-ops, empty-name reset. #177's decisions were built on the recommended options (core 1 to 5, union only, manual picks kept apart, load on the existing flow, class place under Layered).
  - Enabled components: Options section first, `useAddons` / `useLogging` / `useGfx` / `useFiltering`, `M.PSS_On` read once per session (a change applies after a reload); the addon manager and graphics files return at the top when off; Event Logging off stores no line (counts unchanged) and drops the Events tab and the Event History page; Social Filtering off registers no chat filter, block events, ignore hooks, menus, capture or expiry and the list tabs say so. The C1/C2 breach is fixed.
  - Design: scratch `docs/components/addon-manager/04_PROFILES_REWORK.md` (in-game checks section 8) and `docs/components/enabled-components/`; build record `03_BUILD_NOTES.md`.
- **Bug found testing 3.6.0.74 (the author, 2026-10-10):** the profile side menu shows only Save and Rename, no Load, Enable all or Disable all: [#189](https://github.com/racetracks/PourSocialScore/issues/189) (`ISS-00002`; design and plan scratch `docs/components/addon-manager/06_PROFILE_MENU_NO_LOAD.md`: `DDS-00002`, `IMP-00002`). It blocks the rest of `CHK-00001`.
- **Next steps (the author, 2026-10-10; order `DEC-00011`, `DEC-00013`, plan scratch `docs/latest/next-steps/01_NEXT_STEPS.md`):**
  1. `STP-00014`: name the cause of #189 (no build; ask the author for `/pss acp profiles` output and the character drop-down).
  2. `STP-00015` and `STP-00016`: the fix and its docs as 3.6.0.75; re-run `CHK-00001` and `CHK-00002`; close #179 and #189.
  3. `STP-00012`: [#183](https://github.com/racetracks/PourSocialScore/issues/183) hide the ignore auto-reply echo, option `showIgnoreReplies` (3.6.0.76; scratch `docs/latest/issues/ignore-reply-echo/`).
  4. `STP-00013`: [#184](https://github.com/racetracks/PourSocialScore/issues/184) finish the reference framework (`STP-00003` to `STP-00006`; docs build 3.6.0.77).

  A fix build moves every later build up by one.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- Send `/pss acp profiles` output and the character drop-down value for #189; then test the fix build (`CHK-00001`, `CHK-00002`); close #179 and #189 once tested.
- Ask for macros from #159 when ready.
- #144: add the `SCRATCH_TOKEN` secret so CI runs the real-save tests.
- #148: OK or revert P3 (inactive shipped lists no longer capture units or /who).

## Known breaches
None (02 section 12).

## Open issues (addon repo)
- #189: the profile side menu shows only Save and Rename (`ISS-00002`; next `STP-00014`, fix 3.6.0.75).
- #179: Enable all / Disable all in a profile (built 3.6.0.74, `STP-00011`; blocked by #189).
- #183: ignore auto-reply, option to hide the "To player: ..." echo of the reply PSS sends (3.6.0.76, `STP-00012`).
- #184: the reference framework (`ISS-00001`); rule shipped in 3.6.0.70, remaining steps 3.6.0.77 (`STP-00013`).
- #159 to #169: Macro Helper macros, one issue per set (umbrella #159).
- #152: window memory, build fewer frames (pane parts on first use, shared between tabs).
- #37: the guild exclusion list is not saved (its intent needs defining).
- #38: seeing a shipped-guild member loads the lists.
- #39: unload the GUI on close.
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
