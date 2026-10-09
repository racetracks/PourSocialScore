# Release: what PSS does on top of the baseline pipeline

The pipeline is the baseline's (baseline 09). The live files are `.github/workflows/release.yml`, `.github/workflows/rules.yml` and `tools/`; they win over this file. Versions and build numbers: 02 section 8.

## Names and paths
- Main TOC (version source): `PourSocialScore/PourSocialScore.toc`. Zip: `PourSocialScore-<version>.zip` holding every `PourSocialScore*` folder (six), with readme.txt and history.txt copied into the core folder; no `.github`, `tools/` or `versions.json`.
- Release title: `Pour Social Score <version>`. Tags `v<version>`.
- history.txt opens with "POUR SOCIAL SCORE - VERSION HISTORY" and "(newest first)"; each section is `=> X.Y.Z.B - Title`, a blank line, then plain bullets (`tools/bump_version.sh` writes it).

## CI: rules.yml (every pull request and every push to main)
- `check`: `sh tools/check_rules.sh`: Lua 5.1 (luac5.1 and `check_style.lua`), ASCII, tabs and trailing whitespace, no UI in core logic (`check_layers.lua`), every saved key in the schema map (`check_schema.lua`), a local `M` in every file (`check_locals.lua`), member fields only through accessors (`check_fields.lua`), `check_toc.sh` on every `PourSocialScore_*` folder (three TOCs agree, files exist, Version = core's), history.txt's top section is the TOC version and holds no placeholder bullet, `versions.py check` (in CI every entry has its PR; a pull request's newest entry is its own number, `PSS_PR`), and PSS names only (no EllesmereUI or EUI names) in the window and the Libraries view files.
- `harness`: `check_tui`, `check_viewquery`, `check_players`, `check_menus`, `check_guilds`, `check_filters`, `check_events`, `check_options` and `check_secrets`, each through `run.lua` with no save.
- `upgrades`: `sh tools/harness/validate_all.sh` on a full clone (`fetch-depth: 0`), without real saves: upgrades from every old layout, data, on demand, growth, the window checks. A check that cannot run prints `SKIPPED` and fails the run (`PSS_ALLOW_SKIP=1` accepts it). The repository variable `PSS_SPARSE_AS` (a git ref, unset by default) turns on the every-save comparison with another build (`sparse_saves.sh`, for a stage that changes the saved layout).
- `window-compare`: informational, always passes: `tui_compare.sh` against the base branch in all three looks, the output in the job summary and a warning annotation when the window differs; frame numbers are not a difference.
- `real-saves`: with the `SCRATCH_TOKEN` secret (contents: read on scratch; setup: issue #144) it builds the real saves from scratch (`build_saves.sh`) and runs the full harness on them; without the secret it prints a notice and passes. The saves are never committed or uploaded.

## release.yml (every push to main, or Run workflow)
- Reads the core TOC version and asks `python3 tools/versions.py kind`: the latest release is published as a full release (`--latest`), a recorded pre-release as a pre-release, a version not recorded fails the run. Nothing happens if the release exists.
- Before publishing it runs `check_rules.sh` and `validate_all.sh`: a red `main` publishes nothing; retry with Run workflow once fixed.
- Notes: an install line, then the version's history.txt section (under "Changes since <previous release>" for a full release, "Changes" for a pre-release).
- A last step keeps every version `versions.json` calls a pre-release (and every `-dev` tag) marked as a pre-release on GitHub.
- Job `mirror` keeps **`racetracks/Pour-Social-Score`** (`MIRROR_REPO`) on the latest full release: the release zip's contents committed as the repo's files (the addon folders at the root; the mirror's own readme.md stays), then the release, with the same zip and notes, on that commit; a release whose tag is not on its files is made again. It runs after every push and does nothing when the mirror is up to date. It needs the secret `MIRROR_TOKEN` (fine-grained, Contents: Read and write on that repo only) on the addon repo; the mirror repo needs an existing commit. Pre-releases are not mirrored. After fixing a secret, run Actions > Release > Run workflow on main.

## Tools
- `sh tools/bump_version.sh build "Title"`: every TOC to the next build, the build recorded in `versions.json`, a history section on top (fill in the bullets). `release "Title"` makes the next build the release (only when the author says it is one; the pre-releases move under it in `versions.json`); `line X.Y.Z "Title"` starts a line with the next build number. `pr <number>` records the PR that carries the new builds.
- `python3 tools/versions.py prs [<version>]` lists the versions and PRs between the previous release and a version; `kind`, `latest`, `check` serve the workflows and the rules check.
- `sh tools/host_build.sh <scratch checkout> [--no-commit | --no-push]`: builds the test zip from HEAD the way `release.yml` does, puts it in scratch `releases/` and `latest/` (replacing the old one), updates the index rows, commits and pushes, and prints the links. `--no-commit` stages only, so docs join the same commit.
- `sh tools/host_tests.sh` builds a tests bundle; not hosted unless the author asks (11_PREFERENCES).

## Full releases
- The notes are the release's history section only: one player-facing summary of every change since the previous release, written by Claude at release time from the PRs `versions.json` lists between the two (`CLAUDE.md`, Full releases). No API key in the pipeline. Pre-releases keep their own history section as notes.
- **What a full release updates (the author, 2026-10-09), all in the release PR and one scratch delivery:**
  1. The release's history section: the one summary (above).
  2. Scratch `docs/latest/release-notes/<version>.md`: the summary, every change in shipping order with build and PR, and a "Technical notes" section linking the design, findings and issue notes behind the changes; its row in `docs/latest/release-notes/README.md`.
  3. Scratch `docs/latest/summary-of-changes/SUMMARY_OF_CHANGES.md`: the release's row in the Releases table and its own table, each change linked to its release notes and its most specific technical notes.
  4. The code map, refreshed in full: scratch `docs/latest/code-map/` (`CODE_MAP.md` and the appendices checked against the code), its `README.md` naming the release's build.
  5. `01_HANDOVER.md` re-summarized, `13_CHANGES_IN_TRAIN.md` refreshed, `06_STATUS_AND_NEXT.md`, `CLAUDE.md`'s short form, and the copies on scratch `docs/latest/pss-docs/`.
- **These are context for later work:** a change or a regression check reads the summary of changes for the area, then the release notes and technical notes it links (`CLAUDE.md`, Read when the task touches the topic).

## Release history
`versions.json` `releases` is the source of truth; each release's notes are on scratch: https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/latest/release-notes

Full releases, newest first: **3.5.0.62** (2026-10-09, Graphics settings and Macro Helper: `/pss gfx` and `/pss macro`, Camelot), 3.4.2.54 (2026-10-09, docs only, no change in game), 3.4.1.53 (2026-10-09, the core uplift), 3.4.0.29 (2026-10-08, the PSS window), 3.3.1 (2026-10-07, the parity project), 3.0.0 (the load-on-demand split), 2.0.44, 2.0.40, 2.0.22, 2.0.19, 2.0.18 (recorded by commit), 2.0.17 (and the versions before it, from history.txt only).

Everything else is a pre-release of the next release, including 3.1.0 and 3.2.0 (pre-releases of 3.3.1). 3.3.0-dev004 was never published (its runs were cancelled; the author chose test zip only, 2026-10-07). Older version names (`-devN`, `-devNNN`, `_N`, plain `X.Y.Z`) stay as they were.

## Test zips
- Scratch `releases/PourSocialScore-<version>-<YYYY-MM-DD-hh-mm>.zip`; the same commit replaces the zip in `latest/`. Link `https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/<path>`.
- Builds up to 3.4.0-dev005 are on the old `racetracks/scratch` (`PourSocialScore/test-builds/`, `pss-builds/`); those links stay, nothing new goes there.

## PSS pitfalls
- Never stack PRs: in 3.2.0, PRs #71 to #74 merged into stale branches and PR #75 had to carry them to main.
- Assign PRs to `racetracks` (requesting the owner as reviewer returns 422).
- A cancelled Release run leaves a version unpublished (3.3.0-dev004): run the workflow by hand on main while that version is still current.
