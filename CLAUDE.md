# PourSocialScore: rules and context for Claude

Two packs, read in layer order. **Where they differ, the PSS pack wins for
PourSocialScore**; everything it does not mention follows the baseline.
"Baseline 02 C3" style references point into layer 1.

| Layer | Folder | Holds |
| --- | --- | --- |
| 1 | `docs/baseline/` | WoW addon baseline v5 (2026-10-07): how any addon is built, released and delivered; v5 adds 02 J (taint, secret values) and `reference/wow-api/` |
| 2 | (not in repo) | Scratch repo usage pack v2: how `racetracks/scratch` hosts builds, saves and packs |
| 3 | `docs/pss/` | PSS handover pack v4 (2026-10-07): only what is true of PourSocialScore |

Loaded in every session:

@docs/baseline/README.md
@docs/baseline/02_RULES.md
@docs/baseline/07_WORKING_WITH_THE_AUTHOR.md
@docs/baseline/10_FEATURE_DESIGN_AND_DELIVERY.md
@docs/pss/00_README.md
@docs/pss/01_HANDOVER.md
@docs/pss/02_RULES.md
@docs/pss/06_STATUS_AND_NEXT.md

Read when the task touches the topic:
- `docs/pss/03_ELLESMEREUI.md` (and `docs/ellesmereui.md`): the EUI integration, bridge, APIs, house rules, the tab shadow fix
- `docs/pss/04_DATA_AND_LOGGING.md`: SavedVariables, outbox, Logging on demand, grouped save, recent counts, real saves
- `docs/pss/05_RELEASE.md`: PSS release names, CI jobs, release history, pitfalls
- `docs/pss/07_HARNESS.md`: PSS harness commands
- `docs/pss/08_PARITY_PROJECT.md`: the current 3.3.0 parity project, decisions and stage table
- `docs/pss/09_COMPLIANCE_REVIEW.md`: the 2026-10-07 rules compliance review, decisions for Dan and the proposed 3.3.2 stage plan
- `docs/pss/reference/`: original 3.3 analysis and plan, issue #77 notes, 2026-10-07 memory snapshot (history; 06 and 08 are newer)
- `docs/baseline/01, 03, 04, 05, 06, 08, 09`: API limits, references, architecture, suite integration and known fixes, harness, lifecycle, release pipeline
- `docs/baseline/templates/`, `docs/baseline/examples/`: generic; the live copies in `tools/` and `.github/workflows/` win
- `docs/baseline/reference/wow-api/` (start with its README): WoW API reference from the Warcraft Wiki. Read for any hook, Blizzard frame, combat or instance path, chat event handling, secret values, a taint report, a TOC or Interface change, or an API that differs between clients. Reference only; baseline 02 J and B carry the rules, and its README lists where it differs from the baseline

## Short form
- Main is **3.3.1** (full release). The 3.3.0 parity project is closed at 3.3.1 (Dan, 2026-10-07); its remaining stages are dropped. No next stage is planned; fixes start `3.3.2-dev001`. Plain `3.3.0` only when Dan says parity is done.
- Everything on `M` via `PourSocialScore_NS`; core fires `M.Events`; UIs write only through core setters. Tabs, except `PourSocialScore_EllesmereUI` (4 spaces).
- Core holds only the chat filtering engine and the launchpad; anything not regularly active, or shared by both UIs, goes in `PourSocialScore_Libraries`, with a measured resident cost.
- No application or service logic in `PourSocialScore_GUI` or `PourSocialScore_EllesmereUI`; the native GUI never reads or loads the EUI folder; the EUI folder is read only during parity work.
- Every number the EUI window shows equals the native window's. Logging loads only when logs are called.
- Taint and secrets (baseline 02 J, PSS 02 section 10): never write or replace Blizzard state; post-hooks and `Menu.ModifyMenu` only; every chat, unit and hook value goes through `M.PSS_IsSecret` before any compare or index; a secret line is neither filtered nor counted.
- Never change TOC Title or Notes. SavedVariables layout changes need Dan's OK and a migration validated on the three real saves.
- Never write to `racetracks/PourSocialScore-EllesmereUI` (retired). Read only: `EllesmereGaming/EllesmereUI` (all rights reserved), `Gethe/wow-ui-source`.
- Before pushing: `sh tools/check_rules.sh`, `sh tools/check_rules_eui.sh`, `sh tools/harness/check_eui_all.sh`, `PSS_REAL_SAVES=/mnt/project-files/baselines sh tools/harness/validate_all.sh`, and `ui_compare.sh` / `eui_compare.sh` for any window that should not change.

## Working in a Claude Code session
- Develop on the session's `claude/...` branch from the latest `origin/main`; one step per PR, based on main; never stack.
- If `gh` is not available, use the GitHub tools the session provides instead of the `gh` commands in the packs.
- **Real saves are never committed here** (baseline 02 D10). They live on scratch at `pss-projects/savedvariables/<version>/` (2.0.44, 3.0.0, 3.2.0-dev011). If `/mnt/project-files` is missing, build it from there as `docs/pss/04_DATA_AND_LOGGING.md` describes, or say the real-save run did not happen; never claim it did.
- Test zips go to scratch `PourSocialScore/test-builds/PourSocialScore-<version>.zip`, linked as `https://github.com/racetracks/scratch/raw/main/<path>`. The scratch repo must be added to the session to write there; if it cannot be, say so and ask.
- Update `docs/pss/06_STATUS_AND_NEXT.md` and the stage table in `docs/pss/08_PARITY_PROJECT.md` when a stage merges.
