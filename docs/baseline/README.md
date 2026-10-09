# WoW addon baseline (v9, 2026-10-08)

The baseline for creating and maintaining any World of Warcraft addon with Claude: the author's frameworks, rules, styles, preferences, release pipeline and references. **It names no addon and no repository of ours.** Use it together with:
- an **addon-specific pack** (that addon's purpose, repos, data layout, plans and status), and
- the **hosting pack** (how test zips, handovers and saves are hosted and linked).

## How to use it
1. Attach the addon repo and the hosting repo to the project.
2. Fill in `PROJECT_INSTRUCTIONS_TEMPLATE.md` and use it as the project instructions (`CLAUDE.md` in a Claude Code repo).
3. Read this README, 02_RULES, 07_WORKING_WITH_THE_AUTHOR and 10_FEATURE_DESIGN_AND_DELIVERY, then the hosting pack and the addon pack, and confirm the next step.
4. **This pack's rules are mandatory.** The addon pack adds what is specific to its addon and may override a rule here only by listing it in its Overrides table (rule, what applies instead, the author's OK and date; a known breach with the line that fixes it). Anything not listed follows this pack.

## Files
| File | What it is | Read it when |
| --- | --- | --- |
| 01_PURPOSE_AND_LANGUAGES.md | What an addon can and cannot do, the languages and files involved, client flavours and TOC selection | Starting on a new addon or a new client |
| 02_RULES.md | Every rule, by letter and number: A code, B TOCs, C performance, D data, E process, F versions, G logic/UI separation, H UI suites, I porting, J security, taint and secret values | Every session (mandatory) |
| 03_REPOS_AND_REFERENCES.md | Repo roles, read-only repos worth reviewing, third-party references with links | Choosing where code lives, or looking for a reference |
| 04_ARCHITECTURE.md | Always-loaded core plus load-on-demand parts, the loader, namespace, event bus, one config for several UIs, upgrades, the UI kit | Adding a folder, a part, an option or an upgrade step |
| 05_UI_SUITES_AND_KNOWN_FIXES.md | Integrating any UI suite, and known UI fixes with what triggered them | Any UI suite work, and before guessing at a UI bug |
| 06_HARNESS.md | The offline Lua 5.1 harness: WoW API stub, runner, checks, migration validation on real saves, look-compares | Writing or running checks, before every push |
| 07_WORKING_WITH_THE_AUTHOR.md | The step loop, communication habits, values (generic; the addon pack's preferences file wins) | Every session |
| 08_PROJECT_LIFECYCLE.md | The phases of a fresh addon project and the documents that carry it | Starting or handing over a project |
| 09_RELEASE_PIPELINE.md | Setting up the tag and release pipeline from an empty repo, versions, pre-releases, the mirror, troubleshooting | Setting up a repo, cutting a release, a failed release |
| 10_FEATURE_DESIGN_AND_DELIVERY.md | Feature design, implementation stages, one small testable PR per stage, validation between PRs | Every session (any feature or stage) |
| PROJECT_INSTRUCTIONS_TEMPLATE.md | Paste-ready project instructions to fill in | Setting up a project |
| HANDOVER_TEMPLATE.md | Layout of the addon-specific pack | Writing or refreshing the addon pack |
| templates/ | Starter files for a new addon repo: `.github/workflows/release.yml` (tags and publishes; `versions.json` decides release or pre-release; the `mirror` job) and `rules.yml` (the Rules CI check), `tools/check_rules.sh`, `tools/bump_version.sh`, `tools/versions.py`, `tools/host_build.sh`, a TOC set (`MyAddon.toc`, `_Mainline`, `_Camelot`), the `history.txt` layout `bump_version.sh` expects, and a README.txt on how to copy them | Setting up a new repo (09). Once copied, the live files in the addon repo (`tools/`, `.github/workflows/`) win |
| examples/ | Harness tooling from a working addon, renamed to MyAddon: `wow_stub.lua` (fake WoW API), `run.lua` (loads TOCs and SavedVariables like the client), `check_style.lua` and `check_layers.lua` (with `lua_segments.lua`; called by `check_rules.sh`), `ui_compare.sh` (look-compare), README.txt | Building a harness for a new addon (06). The addon repo's live `tools/harness/` wins |
| reference/wow-api/ | WoW API reference from the Warcraft Wiki (00 to 07): load order and events, TOC format and interface numbers, object security, secure execution and taint, secure templates and handlers, dealing with taint, Retail 12.x secret values. Reference only; 02 J and B carry the rules, and its README lists where it differs from 02 (02 wins) | Any hook, Blizzard frame, combat or instance path, chat event, secret value, taint report, TOC or Interface change, or API that differs between clients |
