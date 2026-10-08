# PourSocialScore: rules and context for Claude

Two packs, read in layer order. **Where they differ, the PSS pack wins for
PourSocialScore**; everything it does not mention follows the baseline.
"Baseline 02 C3" style references point into layer 1.

| Layer | Folder | Holds |
| --- | --- | --- |
| 1 | `docs/baseline/` | WoW addon baseline v5 (2026-10-07): how any addon is built, released and delivered; v5 adds 02 J (taint, secret values) and `reference/wow-api/` |
| 2 | `docs/scratch/` | Scratch repo usage pack v4 (2026-10-07; the v2 pack adapted to `racetracks/Pour-Social-Score_Scratch`): how scratch hosts builds, saves, docs and summaries. Live copy on scratch `docs/latest/scratch-repo-usage/`, criteria in its `CLAUDE.md` |
| 3 | `docs/pss/` | PSS handover pack v4 (2026-10-07), kept current since: only what is true of PourSocialScore (09 is the current project). Newest copies on scratch `docs/latest/pss-docs/` |

Loaded in every session:

@docs/baseline/README.md
@docs/baseline/02_RULES.md
@docs/baseline/07_WORKING_WITH_THE_AUTHOR.md
@docs/baseline/10_FEATURE_DESIGN_AND_DELIVERY.md
@docs/scratch/04_USAGE.md
@docs/scratch/05_RULES.md
@docs/pss/00_README.md
@docs/pss/01_HANDOVER.md
@docs/pss/02_RULES.md
@docs/pss/06_STATUS_AND_NEXT.md
@docs/pss/09_PSS_UI_PROJECT.md

Read when the task touches the topic:
- `docs/pss/03_ELLESMEREUI.md` (and `docs/ellesmereui.md`): the EUI integration, bridge, APIs, house rules, the tab shadow fix
- `docs/pss/04_DATA_AND_LOGGING.md`: SavedVariables, outbox, Logging on demand, grouped save, recent counts, real saves
- `docs/pss/05_RELEASE.md`: PSS release names, CI jobs, release history, pitfalls
- `docs/pss/07_HARNESS.md`: PSS harness commands
- `docs/pss/08_PARITY_PROJECT.md`: the closed 3.3.0 parity project (shipped as 3.3.1), decisions and stage table
- `docs/pss/09_PSS_UI_PROJECT.md`: **the current project**, the new PSS window (3.4.0): Dan's decisions, the three looks, stages, code map, lessons
- `docs/pss/reference/`: original 3.3 analysis and plan, issue #77 notes, 2026-10-07 memory snapshot (history; 06 and 08 are newer)
- `docs/baseline/01, 03, 04, 05, 06, 08, 09`: API limits, references, architecture, suite integration and known fixes, harness, lifecycle, release pipeline
- `docs/baseline/templates/`, `docs/baseline/examples/`: generic; the live copies in `tools/` and `.github/workflows/` win
- `docs/baseline/reference/wow-api/` (start with its README): WoW API reference from the Warcraft Wiki. Read for any hook, Blizzard frame, combat or instance path, chat event handling, secret values, a taint report, a TOC or Interface change, or an API that differs between clients. Reference only; baseline 02 J and B carry the rules, and its README lists where it differs from the baseline

## Short form
- The live release is **3.3.1** (full). The 3.3.0 parity project is closed at 3.3.1 (Dan, 2026-10-07); its remaining stages are dropped. Fixes to 3.3.1 would start `3.3.2-dev001`.
- **Current project: the new PSS window, line 3.4.0** (`docs/pss/09_PSS_UI_PROJECT.md`). One window with the EllesmereUI port's layout, features and feel (the port is the reference; the old GUI is not authoritative), drawn with Blizzard's and our own resources. Logic in `PourSocialScore_Libraries`, drawing in the new `PourSocialScore_UI`; `/pss tui` opens it until the cutover, when its files move into `PourSocialScore_GUI` and `PourSocialScore_EllesmereUI` is deleted. Main is on the 3.4.0-devNNN pre-releases.
- Three looks (option `uiSkin`): Modern (2, the default from 3.4.0-dev008_4; Blizzard's new Social window art, the Classic look where the client lacks it), Classic (0, Blizzard's classic art; named Blizzard (Default) until dev008_4; internal name "blizzard"), Dark (1, the port's style). The accent is always the player's class colour (no option). Font option `uiFont`; LibSharedMedia is only read, only when another addon loaded it. No `EUI` or `Ellesmere` names in new code.
- Fixes to an unmerged dev build count up with `_N`: `3.4.0-dev002_2`, `_3`; every TOC, the history section and the zip name carry it. The next stage is the next devNNN.
- Everything on `M` via `PourSocialScore_NS`; core fires `M.Events`; UIs write only through core setters. Tabs, except `PourSocialScore_EllesmereUI` (4 spaces).
- Core holds only the chat filtering engine and the launchpad; anything not regularly active, or shared by both UIs, goes in `PourSocialScore_Libraries`, with a measured resident cost.
- No application or service logic in `PourSocialScore_GUI` or `PourSocialScore_EllesmereUI`; the native GUI never reads or loads the EUI folder; the EUI folder is read only during parity work.
- Every number the EUI window shows equals the native window's. Logging loads only when logs are called.
- Taint and secrets (baseline 02 J, PSS 02 section 10): never write or replace Blizzard state; post-hooks and `Menu.ModifyMenu` only; every chat, unit and hook value goes through `M.PSS_IsSecret` before any compare or index; a secret line is neither filtered nor counted.
- Never change TOC Title or Notes. SavedVariables layout changes need Dan's OK and a migration validated on the three real saves.
- Never write to `racetracks/PourSocialScore-EllesmereUI` (retired). Read only: `EllesmereGaming/EllesmereUI` (all rights reserved), `Gethe/wow-ui-source`.
- Before pushing: `sh tools/check_rules.sh` (it also runs `check_toc.sh` on every folder, the PSS-names check and `check_rules_eui.sh`), `sh tools/harness/check_eui_all.sh`, `PSS_REAL_SAVES=/mnt/project-files/baselines sh tools/harness/validate_all.sh` (includes `check_tui.lua`), and `ui_compare.sh` / `eui_compare.sh` for any window that should not change.

## Working in a Claude Code session
- Develop on the session's `claude/...` branch from the latest `origin/main`; one step per PR, based on main; never stack.
- If `gh` is not available, use the GitHub tools the session provides instead of the `gh` commands in the packs.
- **Scratch is `racetracks/Pour-Social-Score_Scratch`** (branch `main`; scratch rules 1 to 14 in `docs/scratch/05_RULES.md`). Every "scratch" in these docs means it; the old `racetracks/scratch` is no longer used. Add it to the session to read or write there (`add_repo`); if it cannot be added, say so and ask. Pull before every change, one commit per delivery, update its `readme.md` index when a folder's newest file changes, and always reply with links (`https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/<path>`, `/blob/` to read, `/tree/` for a folder).
- **Real saves are never committed here** (baseline 02 D10). They live on scratch at `SavedVariables/<version>/` (2.0.44, 3.0.0, 3.2.0-dev011). If `/mnt/project-files` is missing, build it from there with `sh tools/harness/build_saves.sh <scratch checkout>` (needs `lua5.1` from apt for the checks), or say the real-save run did not happen; never claim it did.
- Test zips go to scratch `releases/PourSocialScore-<version>-<YYYY-MM-DD-hh-mm>.zip`, and the same commit replaces the zip in `latest/` with it (scratch rule 9); link it as `https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/<path>`.
- Update `docs/pss/06_STATUS_AND_NEXT.md` and the stage table of the current project (`docs/pss/09_PSS_UI_PROJECT.md`) when a stage merges.
- **Project data on scratch: always read `docs/latest/` first** (`docs/README.md` is the docs index, `readme.md` the repo index). It holds the newest markdown: the current project's plan (`docs/latest/ui uplift/`, the pss-ui project) and these PSS docs (`docs/latest/pss-docs/`). Each docs release is also zipped in the root of `docs/` (`<name>-<date>-vN.zip`) and a project or feature release keeps a history folder `docs/<project>/` (scratch rule 10). When a plan or these docs change, refresh `docs/latest/` in the same scratch commit. Status summaries go in `summary/<project>-<YYYY-MM-DD-hh-mm>.md`.
- The clone is shallow: before `validate_all.sh`, run `git fetch --depth=2000 origin main` (its upgrade checks rebuild old versions from history; without it the "split" checks fail on 2.0.1 and 2.0.40).
- Blizzard's UI source for a template or atlas question: a sparse clone of `Gethe/wow-ui-source` (for example `Interface/AddOns/Blizzard_SharedXML`, `Blizzard_SocialUI`); read only.
