# Release: what PSS does on top of the baseline pipeline

The pipeline is the baseline's (baseline 09). Live copies of PSS's files are in `ci/`. PSS-specific details:

## Names and paths
- Main TOC (version source): `PourSocialScore/PourSocialScore.toc`. Zip: `PourSocialScore-<version>.zip` holding all seven `PourSocialScore*` folders, readme.txt and history.txt copied into the core folder.
- Release title: `Pour Social Score <version>`. Tags `v<version>`.
- history.txt opens with "POUR SOCIAL SCORE - VERSION HISTORY" and "(newest first)"; a release section ends with the bullet "- Version X.Y.Z.".

## CI jobs (rules.yml)
- `check`: `sh tools/check_rules.sh` (Lua 5.1 syntax, ASCII, tabs, layers) plus `tools/check_rules_eui.sh` (the EUI folder's 4-space style and Version = core's).
- `harness`: `PSS_EUI_REQUIRED=1 sh tools/harness/check_eui_all.sh`.

## Release history
| Version | Kind | Notes |
| --- | --- | --- |
| 3.0.0 | Full | Load-on-demand split |
| 3.1.0 | Full | EllesmereUI integration |
| 3.2.0 | Full, 2026-10-05 | **Last full release** |
| 3.3.0-dev001 to dev003 | Pre-releases | Parity stages, published on merge |
| 3.3.0-dev004 | **Not published** | PR #82 merged 2026-10-05 20:45Z, but the Release and Rules runs on main (5c39f62) were **cancelled**, so no release or tag exists. Fix: run the Release workflow by hand (`workflow_dispatch`) on main while 3.3.0-dev004 is still the version, or let the next stage (dev005) publish and leave dev004 as test-zip only. Ask Dan which |

## Test zips
- Scratch: `PourSocialScore/test-builds/PourSocialScore-<version>.zip`; dev001 to dev003 are also in the old `pss-builds/`. Link `https://github.com/racetracks/scratch/raw/main/<path>`. Copy to `/mnt/project-files/builds/`.

## PSS pitfalls seen
- 3.2.0: PRs #71 to #74 were stacked and merged into stale branches; PR #75 carried them to main. Never stack.
- The first EUI release was dev3 because release.yml arrived late in that repo.
- 3.3.0-dev001 to dev003 test zips first went to `pss-builds/` by mistake.
- Assign PRs to `racetracks` (requesting the owner as reviewer returns 422).
