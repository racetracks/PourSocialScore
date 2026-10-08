# Release: what PSS does on top of the baseline pipeline

The pipeline is the baseline's (baseline 09). Live copies of PSS's files are in `ci/`. PSS-specific details:

## Names and paths
- Main TOC (version source): `PourSocialScore/PourSocialScore.toc`. Zip: `PourSocialScore-<version>.zip` holding every `PourSocialScore*` folder (eight from 3.4.0-dev001 with `PourSocialScore_UI`), readme.txt and history.txt copied into the core folder.
- Release title: `Pour Social Score <version>`. Tags `v<version>`.
- history.txt opens with "POUR SOCIAL SCORE - VERSION HISTORY" and "(newest first)"; a release section ends with the bullet "- Version X.Y.Z.".

## CI jobs (rules.yml)
- `check`: `sh tools/check_rules.sh` (Lua 5.1 syntax, ASCII, tabs, layers) plus `tools/check_rules_eui.sh` (the EUI folder's 4-space style and Version = core's).
- `harness`: `PSS_EUI_REQUIRED=1 sh tools/harness/check_eui_all.sh`, then the new window's checks (`check_tui`, `check_viewquery`, `check_players`, `check_guilds`, `check_filters`, `check_events`, `check_options`) and `check_secrets.lua` (3.4.0.14).
- `upgrades` (3.4.0.14): `sh tools/harness/validate_all.sh` on a full clone (`fetch-depth: 0`), without real saves: upgrades from every old layout, data, on demand, growth, the window checks. The real-save run stays local (saves built from scratch).
- `check` also runs `tools/check_toc.sh` on every `PourSocialScore_*` folder (three TOCs agree, files exist, Version = core's) and the PSS-names check.

## Release history
| Version | Kind | Notes |
| --- | --- | --- |
| 3.0.0 | Full | Load-on-demand split |
| 3.1.0 | Full | EllesmereUI integration |
| 3.2.0 | Full, 2026-10-05 | **Last full release** |
| 3.3.0-dev001 to dev003 | Pre-releases | Parity stages, published on merge |
| 3.3.1 | Full, 2026-10-07 | Parity project closed (dev001 to dev005) |
| 3.4.0-dev001 to dev012 | Pre-releases | The new PSS window (09) |
| 3.4.0.13 on | Pre-releases | Build numbers replace `-devNNN` and `_N` (Dan, 2026-10-08) |
| 3.3.0-dev004 | **Not published** | PR #82 merged 2026-10-05 20:45Z, but the Release and Rules runs on main (5c39f62) were **cancelled**, so no release or tag exists. Fix: run the Release workflow by hand (`workflow_dispatch`) on main while 3.3.0-dev004 is still the version, or let the next stage (dev005) publish and leave dev004 as test-zip only. **Dan chose skip (2026-10-07)**: dev004 is test-zip only |

## Build numbers (Dan, 2026-10-08)
Every build is `X.Y.Z.B` (02 section 8): the next build number for every test zip, a stage or a fix, merged or not (`3.4.0.13`, `3.4.0.14`, ...); every TOC, a history section and the zip name carry it. `check_toc.sh` and `check_rules_eui.sh` accept only `X.Y.Z` and `X.Y.Z.B`. `release.yml` publishes a four-part version, or an older one with `-`, as a pre-release, and turns any such release that is not one back into a pre-release; a plain `X.Y.Z` is a full release, set only when Dan says so.

Until 3.4.0-dev012 a round of fixes on an unmerged dev build was `devNNN_N` (`3.4.0-dev002_2`, `_3`, ...).

## Test zips
- Scratch (`racetracks/Pour-Social-Score_Scratch`, from 2026-10-08): `releases/PourSocialScore-<version>-<YYYY-MM-DD-hh-mm>.zip`, and the same commit replaces the zip in `latest/` with it. Link `https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/<path>`.
- Builds up to 3.4.0-dev005 are on the old `racetracks/scratch` (`PourSocialScore/test-builds/`, dev001 to dev003 of 3.3.0 also in `pss-builds/`); those links stay, nothing new goes there.

## PSS pitfalls seen
- 3.2.0: PRs #71 to #74 were stacked and merged into stale branches; PR #75 carried them to main. Never stack.
- The first EUI release was dev3 because release.yml arrived late in that repo.
- 3.3.0-dev001 to dev003 test zips first went to `pss-builds/` by mistake.
- Assign PRs to `racetracks` (requesting the owner as reviewer returns 422).
