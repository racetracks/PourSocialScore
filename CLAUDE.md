# PourSocialScore: rules and context for Claude

This repo follows the author's **WoW addon baseline** (v4, 2026-10-07), kept in
`docs/baseline/`. The baseline is the default for everything; where this file
says something different for PourSocialScore, this file wins.

Read these before the first step of any task (they are imported here so every
session loads them):

@docs/baseline/README.md
@docs/baseline/02_RULES.md
@docs/baseline/07_WORKING_WITH_THE_AUTHOR.md
@docs/baseline/10_FEATURE_DESIGN_AND_DELIVERY.md

Read the others when the task touches their topic:
- `docs/baseline/01_PURPOSE_AND_LANGUAGES.md`: API limits, client flavours, three TOCs
- `docs/baseline/03_REPOS_AND_REFERENCES.md`: reference repos (read only, copy logic never code or IDs)
- `docs/baseline/04_ARCHITECTURE.md`: core plus load-on-demand parts, loader, event bus, one config
- `docs/baseline/05_UI_SUITES_AND_KNOWN_FIXES.md`: suite integration and known UI fixes (check before guessing at a UI bug)
- `docs/baseline/06_HARNESS.md`: the offline Lua 5.1 harness
- `docs/baseline/08_PROJECT_LIFECYCLE.md`, `docs/baseline/09_RELEASE_PIPELINE.md`: phases, release pipeline and troubleshooting
- `docs/baseline/templates/`, `docs/baseline/examples/`: generic templates; this repo's live copies are in `.github/workflows/` and `tools/`, which win

## This addon
- **PourSocialScore**: unlimited account-wide ignore list, guild ignore list and chat/spam filter engine (readme.txt). Lua 5.1, WoW API only, no libraries. Retail (Mainline) and Classic (Camelot); three TOCs per folder.
- One repo, one version for every folder. The version is `## Version:` in `PourSocialScore/PourSocialScore.toc`; every TOC carries the same one.
- Folders (roles from 04_ARCHITECTURE):
  | Folder | Role |
  | --- | --- |
  | `PourSocialScore/` | Core, always loaded: engine, setters, events, loader, upgrades, the EllesmereUI bridge |
  | `PourSocialScore_Options/` | Options / data, always loaded |
  | `PourSocialScore_Libraries/` | Library folder, on demand: queries, totals, commands, import/export |
  | `PourSocialScore_GUI/` | Native Blizzard-styled UI, on demand |
  | `PourSocialScore_EllesmereUI/` | Suite UI, on demand, only when the integration is on (see `docs/ellesmereui.md`) |
  | `PourSocialScore_Logging/` | Block history log, on demand |
  | `PourSocialScore_Communities/` | Shipped managed guild lists, on demand |
- File prefixes: `PSS_` (core, library, native UI), `EUI_` (EllesmereUI folder).
- Checks: `sh tools/check_rules.sh` and `sh tools/check_rules_eui.sh` (need `lua5.1`); harness in `tools/harness/` (`validate_all.sh`, `ui_compare.sh`, `eui_compare.sh`).
- history.txt headings: `=> X.Y.Z-devNNN - Title`, newest first.

## Working in a Claude Code session
- Develop on the session's `claude/...` branch from the latest `origin/main`; one step per PR, based on main.
- If `gh` is not available, use the GitHub tools the session provides for PRs, CI and releases instead of the `gh` commands in the baseline.
- `/mnt/project-files` (the author's real saves and baselines) may not exist here. If a step needs real saves and they are missing, say so and ask; never claim a real-save run that did not happen.
- The hosting pack and an addon-specific pack are referenced by the baseline but are not in this repo. Until they are added, ask the author where test zips go.
