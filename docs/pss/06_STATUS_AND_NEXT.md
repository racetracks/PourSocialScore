# Status and next step (2026-10-09)

Kept short and current: every PR updates it (baseline 02 E10). The addon as it works is in `01_HANDOVER.md`; the last plan, closed at 3.4.1.53, is `10_CORE_UPLIFT.md`. History: `reference/06_status-history-to-3.4.1.30.md` (to 3.4.1.30) and `reference/combined-3.4.1.52/` (the 3.4.1.52 stages).

## Now
- **Live release 3.4.2.54** (PR #150, merged 2026-10-09): docs only, no change in game since 3.4.1.53, which closed the core uplift.
- **3.4.3.55** (PR #151, docs only, opens line 3.4.3): the release notes, the summary of changes and the technical notes on scratch are named as context for any change or regression check (`CLAUDE.md`, 11), and `05_RELEASE.md` lists what a full release updates, the code map included.
- **3.5.0.56** (docs only, opens line 3.5.0): points a fresh session to the graphics settings design.
- **3.5.0.58** (docs only): sparse messages and token use; reuse a thread that already has the tools and context (`11_PREFERENCES.md`). The graphics polish build moved on.
- **3.5.0.59** (docs only): every feature's design and plan name its tests and, at release, its release workflows (02 section 1.7). The graphics polish build moves to 3.5.0.60.
- **Current project: graphics settings (`/pss gfx`, Camelot only).** Export and import every graphics setting, a preview of each change, keep or revert within 15 s after the reload, the last 5 sets kept in `PSS_OptionsDB` (restore, export). All logic in Libraries (`PSS_Graphics.lua`); core gets one route entry and, in stage 2, one line. Design and implementation plan, every decision answered (the author, 2026-10-09): scratch `docs/latest/graphics-settings/01_DESIGN.md` (https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/docs/latest/graphics-settings/01_DESIGN.md).
- **3.5.0.57 builds stages 1 to 3 in one PR** (the author's OK, 2026-10-09): logic, history and saved keys (`PSS_Graphics.lua`), the popup, the timed keep prompt and the History view; `check_gfx.lua` (phases logic, history, keep, retail, noapi, popup, history_ui, apply, reload) in `validate_all.sh` and CI. The keep prompt is started by `M.PSS_GfxAsk` (core's one line loads Libraries; the design's end-of-file block would have looped through the loader).
- **3.5.0.60** (docs only): the Macro Helper is the next step.
- **3.5.0.61 builds the Macro Helper (`/pss macro`, Camelot), the whole of stage 1 in one build.** Preloaded macros written with one command: `/pss macro global create` (account-wide by default) and `/pss macro <class> create` (character by default), each macro account-wide or character-specific (per macro, per set, or the command word `account` / `character`); PSS owns its names per store; never deletes; refused in combat; no saved data; all in Libraries (`PSS_MacroData.lua`, `PSS_Macros.lua`); `check_macro.lua` (16 runs) in `validate_all.sh` and CI. Design: scratch `docs/latest/macro-helper/01_DESIGN.md` (https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/docs/latest/macro-helper/01_DESIGN.md); plan: `02_IMPLEMENTATION_PLAN.md` (https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/docs/latest/macro-helper/02_IMPLEMENTATION_PLAN.md). Its notes for the release live in its PR. Its polish (the author's findings, the author's macros and names, the icon fallback if in-game check 10 fails) is the next free build, 3.5.0.62.
- **Graphics settings:** the author tested 3.5.0.57 on Camelot (2026-10-09): fine, no findings. Documented and ready for the release: scratch `docs/latest/graphics-settings/02_BUILD_NOTES.md` (patch notes, technical notes, results) and the release checklist `docs/latest/release-3.5.0/01_RELEASE_READINESS.md` (https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/docs/latest/release-3.5.0/01_RELEASE_READINESS.md). The only polish it needed was the `/pss gfx` entry in `readme.txt`, added in 3.5.0.61's PR. **Not a release yet:** the release is the next build when the author calls it.

## Waiting on the author
- Merge the 3.5.0.56 docs PR.
- Test 3.5.0.61 (the Macro Helper) on Camelot (design section 9) and merge its PR (#158).
- **The macros themselves are drip-fed after the release (the author, 2026-10-09): umbrella issue #159** (https://github.com/racetracks/PourSocialScore/issues/159, one issue per set, #160 global, #161 Warrior, #162 Druid, #163 Hunter, #164 Mage, #165 Paladin, #166 Priest, #167 Rogue, #168 Shaman, #169 Warlock). The author posts macros as comments on a set's issue (first line the name, the rest the body; optional `store:` / `icon:` lines) and asks for them ("add the macros from #165"); each ask is one build (3.5.0.62 first). The Paladin's first four (Cleanse, Purify, DS, HS) are already on #165. How: the umbrella's steps; context on scratch `docs/latest/issues/macro-sets/`.
- Test the Macro Helper (3.5.0.61), merge #158, then call the release of line 3.5.0: **the release ships the framework (the author, 2026-10-09); macros come after it.**
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
