# Status and next step (3.6.0.79, after release 3.5.0.62)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. Earlier builds: `history.txt`, `versions.json` and the build records on scratch (`docs/components/addon-manager/03_BUILD_NOTES.md`). History: `reference/06_status-history-to-3.4.1.30.md` and `reference/combined-3.4.1.52/`.

## Now
- **3.6.0.79, docs build (references):** `CLAUDE.md` and `11_PREFERENCES.md` gain [`DEC-00067`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/05_Detailed_Design.md#dec-00067) (every session output is recorded in the session's scratch temp root, merged from [PR #198](https://github.com/racetracks/PourSocialScore/pull/198)) and [`DEC-00068`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/05_Detailed_Design.md#dec-00068): anything referenced (file, folder, key, issue, PR, commit, release, zip, page) is always a markdown link to it, never a bare path, number or name. The fixes move up one build: #189 3.6.0.80, #192 3.6.0.81.
- **3.6.0.78, docs build (documentation rules):** `CLAUDE.md` gains `DEC-00059` (references link the session's temp root), `DEC-00060` (changelog rows link the version before), `DEC-00061` (the session's temp root), `DEC-00062` (temp READMEs carry decisions for the author and decisions made), `DEC-00063` (every quoted key links to its context, `link_keys.py`), `DEC-00064` (`00_Decisions.md` in every documentation folder); `11_PREFERENCES.md` the same. The addon manager is documented as the feature `addon-helper` (scratch `drafts/features/addon-helper-2026-10-10-draft1/`, its `00_Decisions.md` and `07_Roadmap.md`); the author answered `DEC-00055` (a), `DEC-00056` (a), `DEC-00057` Camelot only (Retail and other clients aborted for now), `DEC-00058` (a) 140 KB, and #148 (revert P3). The fixes move up one build: #189 3.6.0.79, #192 3.6.0.80.
- **3.6.0.77, docs build (#194, `ISS-00020`):** the Mandatory Documentation Requirements in `CLAUDE.md` (root set per capability, changelogs, `claude.local.md` rules, prompt log, stakeholder inputs, credits, one-line headings with key anchors, fresh fetch at session start, the documentation process); `11_PREFERENCES.md` (temp summary table, prompt log, credits); `docs/scratch/03_LAYOUT.md` (documents, drafts groups, history). On scratch: the reference framework moved to `documents/reference-framework/` (registry `16_Registries/REGISTRY.md`, tool `08_Operations/registry-tool/refkey.py`) and the document migration ran (`CMP-00006`: drafts into groups, retired folders into `history/`). The fixes move up one build: #189 3.6.0.78, #192 3.6.0.79.
- **3.6.0.76, docs build:** these next steps, #192 and the ACP review in the repo docs. The fixes move up one build: #189 3.6.0.77, #192 3.6.0.78. 3.6.0.75 merged as PR #191 (pre-release v3.6.0.75).
- **#192 found testing 3.6.0.75 on Camelot (the author, 2026-10-10):** the AddOns tab's Reload prompt does nothing ([#192](https://github.com/racetracks/PourSocialScore/issues/192), `ISS-00019`; scratch `docs/components/addon-manager/07_RELOAD_DOES_NOTHING.md`). Cause (`DDS-00006:4.2`): Camelot blocks `ReloadUI()` from addon code even inside a click. Fix (`DDS-00006:5.1`, `DEC-00017:4.1`, the author's answers): EllesmereUI's logic, rewritten. An action-button overlay with macro `/reload` sits over Accept and Enter; in combat Accept is greyed until combat ends; no typing; every reload prompt uses it. This needs an Overrides row for 10.5 in its build.
- **3.6.0.75 (built, awaiting the author's in-game checks):** the author's "resolve all in one attempt" (Overrides row, 02 section 12): #189 and #183 in one build, #184 done on scratch.
  - #189 (`ISS-00002`, `DDS-00002`): the cause was not confirmed (the harness's menus rebuild fresh on every open; `menuflow` passes), so the build covers every ranked cause: a free place reads "Not saved yet"; a place whose profile is saved under the other character choice reads "(empty; saved for all characters)" and offers "Show the saved profile"; an unreadable saved string reads "(other version)" and is never overwritten; each menu action re-reads the place (`View:Place`); Delete refreshes the window. Harness phase `menurefresh` (`TST-00007`) fails on `origin/main`. If the side menu still shows only Save and Rename, send `/pss acp profiles` output and the character drop-down value (`STP-00014`).
  - #183 (`STP-00012`): option `showIgnoreReplies` (default on, nothing changes); off hides the "To player" echo of PSS's ignore auto-reply and the "No player named" line; lazy chat filters, nothing registered while on; `check_ignorereply.lua` (Retail and Camelot, 28 checks each, fails on `origin/main`).
  - #184 (`STP-00013`): STP-00003 to STP-00006 done on scratch (backfill of `CMP-00002` to `CMP-00004`, `RET-00001` to `RET-00028`, `ISS-00003` to `ISS-00018`, check rule in scratch `CLAUDE.md`); `refkey.py check` 0 problems.
  - Run: `check_rules.sh`; `validate_all.sh` on the 8 real saves with `PSS_SAME_AS=origin/main` (508 PASS, 0 FAIL, 54 saves identical); `tui_compare.sh`: only the new Options row (the later headings 26 px lower). Not shown by the simulation: the real Blizzard menu, echo ordering across chat frames, chat lockdown timing, taint, wrapped text, client art.
- **3.6.0.74 (built, awaiting the author's in-game checks; PR opened on request):** #179 Enable all / Disable all in a profile's side menu (`STP-00011`; scratch `docs/components/addon-manager/04_ENABLE_DISABLE_ALL.md` section 8: `DEC-00012`, `TST-00006`, `CHK-00001`; record `BLD-00001`). They replace Add to current selection / Remove from current selection; a manual group tick (`M.PSS_AddonPresetTick`); greyed as kit titles when the profile has no installed addon (no kit change). The author tested 3.6.0.69 on 2026-10-10: #176, #177, #180, #181 closed.
- **3.6.0.73, docs build:** the next steps are set to #176, #177, #179, #180, #181, #183, #184 (`DEC-00011`, `STP-00009` to `STP-00013`); #179 moves to 3.6.0.74, #183 to 3.6.0.75, #184 to 3.6.0.76.
- **3.6.0.72, docs build:** the reference framework gains the type `RET` (Retired, own counter from `00001`; scratch `DEC-00009`) and a `00_References.md` in every documentation folder (`DEC-00010`): `refkey.py retire` maps an old key to its replacement; `CLAUDE.md` says how (`STP-00007`, `STP-00008`). #179 moves from 3.6.0.72 to 3.6.0.73.
- **3.6.0.71, docs build:** `CLAUDE.md`, PSS 02 and baseline 02 consolidated (same rules, no dates or build history; build history lives in `history.txt` and the build records) and this file trimmed. #179 moves from 3.6.0.71 to 3.6.0.72.
- **3.6.0.69 (PR #182, merged; the author's test passed 2026-10-10):** the Addon Profiles rework for #176, #177, #180 (#175 closed) and Enabled components #181.
  - Profiles are saved ACP's way: every place in the Profiles drop-down (Core 1 to 5, a line, Layered 6 to 25 and the class one), a place's side menu (Select or Deselect, Save with one confirm, Load, Add to current selection, Remove from current selection, Rename, Delete; a selected place marked `*`), any selected together (union plus hand picks; keys `addonSel`, `addonPick`); the kit's `m:Sub` (Blizzard submenu; a swap under "< Back" in Dark) fixed the menu closing; the drop-down is 190 wide and opens down in every look; the count is right-anchored to Undo. Not built (kept different from ACP): Default set, silent no-ops, empty-name reset. #177's decisions were built on the recommended options (core 1 to 5, union only, manual picks kept apart, load on the existing flow, class place under Layered).
  - Enabled components: Options section first, `useAddons` / `useLogging` / `useGfx` / `useFiltering`, `M.PSS_On` read once per session (a change applies after a reload); the addon manager and graphics files return at the top when off; Event Logging off stores no line (counts unchanged) and drops the Events tab and the Event History page; Social Filtering off registers no chat filter, block events, ignore hooks, menus, capture or expiry and the list tabs say so. The C1/C2 breach is fixed.
  - Design: scratch `docs/components/addon-manager/04_PROFILES_REWORK.md` (in-game checks section 8) and `docs/components/enabled-components/`; build record `03_BUILD_NOTES.md`.
- **Bug found testing 3.6.0.74 (the author, 2026-10-10):** the profile side menu shows only Save and Rename, no Load, Enable all or Disable all: [#189](https://github.com/racetracks/PourSocialScore/issues/189) (`ISS-00002`; design and plan scratch `docs/components/addon-manager/06_PROFILE_MENU_NO_LOAD.md`: `DDS-00002`, `IMP-00002`). It blocks the rest of `CHK-00001`.
- **Re-test of 3.6.0.75 (the author, 2026-10-10):** #183 and #184 done and closed. #189: the side menus now show, but there is **no Load** in the menu (scratch `docs/components/addon-manager/06_PROFILE_MENU_NO_LOAD.md` section 12: hypotheses H6 to H10, `DEC-00015`, `TST-00008`, `CHK-00003`). In 3.6.0.75 Load shows only on a used place, so the place opened reads as free.
- **Next steps (`DEC-00016`, scratch `docs/latest/next-steps/01_NEXT_STEPS.md`):**
  1. `STP-00017`: closed (the author: no profile can be saved on Camelot; the fault is the Save path).
  2. `STP-00018`: the fix, build 3.6.0.80, built on the author's `DEC-00015` answers (2026-10-10): item 1 the side menu mimics AddonControlPanel's Sets menu (ACP's behaviour reviewed first, `ACPI`; logic copied, never code); item 2 Save says it saved and the menu turns used at once; phase `loadentry` (`TST-00008`); `CHK-00003`.
  3. `STP-00011`: #179 re-test, `CHK-00001` (1 to 8) on 3.6.0.80; close #179 and #189 when they pass. From 3.6.0.80, Enable all / Disable all are listed on every place (`DEC-00015:12.8` changes `DEC-00012`).
  4. `STP-00020`: #192 the Reload fix, build 3.6.0.81 (`DDS-00006:5.1`, phase `reloadpath` `TST-00009`, `CHK-00004`).
  The author tests on Camelot only (`DEC-00057`, 2026-10-10): Retail and other clients are aborted for now.
- The macros are drip-fed from umbrella issue #159 (one build per ask, the next free build).

## Waiting on the author
- #189: nothing to send (`STP-00017` closed); `DEC-00015` answered (2026-10-10).
- Then test 3.6.0.80 (`CHK-00003`, `CHK-00001`, `CHK-00002`) and 3.6.0.81 (`CHK-00004`); close #179, #189 and #192 once tested.
- Ask for macros from #159 when ready.
- #144: add the `SCRATCH_TOKEN` secret so CI runs the real-save tests.
- #148: answered 2026-10-10, revert P3 (watch targets, mouseovers, nameplates, group and /who in every state; never remove features); next: a code build, "build issue #148".

## Known breaches
None (02 section 12).

## Open issues (addon repo)
- #189: no Load in the profile side menu; no profile can be saved on Camelot (`ISS-00002`; fix 3.6.0.80 `STP-00018`).
- #179: Enable all / Disable all in a profile (built 3.6.0.74, `STP-00011`; blocked by #189; re-test on 3.6.0.80).
- #192: the Reload prompt does nothing on Camelot (`ISS-00019`; fix 3.6.0.81 `STP-00020`).
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
- #148: P3 to be reverted (the author, 2026-10-10): inactive shipped lists capture units and /who again; code build not started.

Context for each open item: scratch `docs/latest/issues/` and `docs/latest/setup/`.

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
