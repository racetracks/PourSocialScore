# WoW addon baseline (2026-10-08, v6)

The baseline for creating and maintaining any World of Warcraft addon with Claude: the author's frameworks, rules, styles, preferences, release pipeline and references. **It names no addon and no repository of ours.** Attach it to a fresh Claude project together with:
- an **addon-specific pack** (that addon's purpose, repos, data layout, plans and status), and
- the **hosting pack** (how test zips, handovers and saves are hosted and linked).

## How to use it in a fresh Claude project
1. Attach the addon repo and the hosting repo to the project.
2. Fill in `PROJECT_INSTRUCTIONS_TEMPLATE.md` and paste it as the project instructions.
3. Upload this zip, the addon pack and the hosting pack. Start with: "Read the baseline README, 02_RULES, 07_WORKING_WITH_THE_AUTHOR and 10_FEATURE_DESIGN_AND_DELIVERY, then the hosting pack and the addon pack, and confirm the next step."
4. **This pack's rules are mandatory.** The addon pack adds what is specific to its addon and may override a rule here only by listing it in its Overrides table (rule, what applies instead, the author's OK and date; a known breach with the line that fixes it). Anything not listed follows this pack.

## Files
| File | What it holds |
| --- | --- |
| 01_PURPOSE_AND_LANGUAGES.md | What an addon can and cannot do, the languages and files involved, client flavours |
| 02_RULES.md | Every rule: code, TOCs, performance, data, process, versions, logic/UI separation, UI suites, porting between front ends |
| 03_REPOS_AND_REFERENCES.md | Repo roles, read-only repos worth reviewing, third-party references with links |
| 04_ARCHITECTURE.md | Always-loaded core plus load-on-demand parts, the loader, one config for several UIs, upgrades |
| 05_UI_SUITES_AND_KNOWN_FIXES.md | Integrating any UI suite (configured the same as the native UI, assets in different places) and known fixes with what triggered them (the font shadow ghost label, link hover, window anchoring) |
| 06_HARNESS.md | Offline Lua 5.1 harness with a WoW API stub, migration validation, look-compares |
| 07_WORKING_WITH_THE_AUTHOR.md | The step loop, communication preferences, values |
| 08_PROJECT_LIFECYCLE.md | The phases of a fresh addon project and the documents that carry it |
| 09_RELEASE_PIPELINE.md | Configuring the tag and release pipeline from an empty repo, feature-based versions, pre-releases, troubleshooting |
| 10_FEATURE_DESIGN_AND_DELIVERY.md | Feature design, implementation stages, one small testable PR per stage, validation between PRs |
| PROJECT_INSTRUCTIONS_TEMPLATE.md | Paste-ready project instructions to fill in |
| HANDOVER_TEMPLATE.md | Layout for the addon-specific pack when a thread gets long |
| templates/ | release.yml (with full-release notes and the mirror job), rules.yml, check_rules.sh, bump_version.sh, host_build.sh, collect_notes.sh, summarize_notes.sh, a TOC set, history.txt layout |
| examples/ | Harness tooling to adapt (stub, runner, style and layer checks, UI compare) |
| reference/wow-api/ | WoW API reference set from the Warcraft Wiki: load order, TOC format and interface numbers, object security, taint, secure templates and handlers, Retail 12.x secret values. Reference only; its README lists where it differs from 02 |

## Changes in v6
- **Mandatory rules:** an addon pack overrides a rule only through its Overrides table (README step 4, 02 intro).
- **Versions are `X.Y.Z.B`** (02 F, 07, 08, 09, 10, the instructions template): `B` is the build number on the line; every test zip, stage or fix takes the next one; every build is a pre-release; a plain `X.Y.Z` is the full release. Replaces `X.Y.0-devNNN`.
- The rules check also fails a version of another shape, TOCs that disagree and a history.txt whose top section is another version (02 A12).
- New tools in `templates/tools/`: `bump_version.sh` (next build, release or line), `host_build.sh` (test zip from HEAD, hosted), `collect_notes.sh` and `summarize_notes.sh` (a full release's notes, summarized for players by Claude).
- `release.yml`: four-part versions are pre-releases; a full release gets the summarized notes and an optional `mirror` job publishes it on a second repo (09 section 6).

## Changes in v5
- New 02 section J: security, taint and secret values (never write Blizzard state, post-hooks only, combat guards, `IsForbidden`, secret values on Retail 12.x, no combat log, restriction CVars, taint logs). C4 points to it.
- 02 B5 and B6: interface numbers checked every patch, new TOC suffixes, feature detection, `WOW_PROJECT_ID` constants.
- New `reference/wow-api/` (Warcraft Wiki reference set, compiled 2026-10-08, ASCII), with a table of where it differs from this baseline.
- 01 and 03 point to it; 03 adds Townlong Yak, BlizzardInterfaceResources and WoWUIBugs.

## Changes in v4
- Written for any author: no personal names.
- Criteria instead of object names (for example the core event bus, not a named table); harness examples use placeholders.
- The suite-specific file is replaced by general UI suite guidance plus a Known fixes section (05).
- New 10_FEATURE_DESIGN_AND_DELIVERY.md: design, stages, incremental PRs and validation between them.
- Releases are defined by feature: a feature owns an `X.Y.0` line, every stage is a suffixed pre-release, the full release is the completed feature (02 F, 09).

## Changes in v3
- The author's 20 performance and code rules merged into 02_RULES (A5 to A7, C1 to C16, D1 to D6); the Warcraft Wiki interface customization page added to the references.
- Garbage collection timing is now event-driven (no wall-clock gates), to fit the no-timers-as-logic-gates rule.

## Changes in v2
- References carry their repo links (ElvUI, Questie, EllesmereUI, DBM); ElvUI and Questie added to repos worth reviewing.
- Logging specifics removed (to be addressed later).
- Hosting moved to its own pack.
- The release pipeline guide now covers setup from an empty repo step by step.
- The lifecycle is written as guidance for any fresh project.
