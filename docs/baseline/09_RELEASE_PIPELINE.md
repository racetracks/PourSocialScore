# Tag and release pipeline: full setup

The whole pipeline is **two workflow files, a rules script, the version tools and one rule: the version in the main TOC is the release.** Nobody tags by hand; merging a version bump to main publishes it: a pre-release for every build, a full release for the build `versions.json` names the latest release. Versions are `X.Y.Z.B` with a build number that never resets (02 F2).

Starter copies of every file named here are in `templates/` (`.github/workflows/`, `tools/`, the TOC set, history.txt; its README.txt says what to rename). In a working repo the live `.github/workflows/` and `tools/` win over the templates and over this page; read them for the exact code.

## 1. What you end up with
- Every PR and every push to main runs **Rules** (`.github/workflows/rules.yml`, job `check`, running `tools/check_rules.sh`), plus any harness jobs the project adds (section 5).
- Every push to main runs **Release** (`.github/workflows/release.yml`). If the main TOC's version has no release yet, it builds `<Addon>-<version>.zip`, creates the tag `v<version>` and the GitHub release with that version's history section as notes, marked a pre-release unless `versions.json` names that version the latest release. A full release's notes are one summary of every change since the previous release, written by Claude at release time (section 6). An optional `mirror` job publishes full releases on a second repo.
- Merges that don't change the version publish nothing.

## 2. Repo layout the workflows expect
```
<Addon>/                    main addon folder (its name = the TOC name = ADDON in release.yml)
  <Addon>.toc               base TOC: "## Version: X.Y.Z.B" (the version is read from here)
  <Addon>_Mainline.toc      flavour TOCs, same version
  <Addon>_Camelot.toc
  *.lua
<Addon>_<Part>/             any other addon folders (all zipped; each with its own three TOCs)
tools/check_rules.sh        the rules check (with check_style.lua, check_layers.lua, lua_segments.lua)
tools/bump_version.sh       sets the next version in every TOC, records it and adds the history section
tools/versions.py           the versions file's tool (section 6)
tools/host_build.sh         builds the test zip from HEAD and hosts it (section 7)
versions.json               latest release, pre-releases in order with their PRs, past releases (never shipped)
.github/workflows/rules.yml
.github/workflows/release.yml
readme.txt                  copied into <Addon>/ inside the zip
history.txt                 copied into <Addon>/ inside the zip; release notes come from it
```
Every folder named `<Addon>` or `<Addon>_*` at the repo root goes into the zip, at the zip's root, so it extracts straight into `Interface/AddOns`. `.github`, `tools`, `versions.json` and anything else stay out (`versions.py check` fails if `versions.json` turns up in an addon folder).

## 3. Step by step, from an empty repo
1. **Create the repo** (private is fine) with a default branch named `main`.
2. **Workflow permissions.** The release job writes tags and releases with the built-in `GITHUB_TOKEN`; `release.yml` asks for `permissions: contents: write`, enough on a personal repo. In an organisation, or if the run fails with "Resource not accessible by integration", set **Settings > Actions > General > Workflow permissions** to **Read and write permissions**. No personal token is needed (except for a mirror, section 6).
3. **Actions enabled.** Settings > Actions > General > "Allow all actions" (or at least GitHub-authored ones: the workflows use `actions/checkout@v4`, `gh`, python3 and apt).
4. **Copy the templates** from `templates/`: both workflows, `tools/check_rules.sh`, `tools/bump_version.sh`, `tools/versions.py`, `tools/host_build.sh`, the TOC set, history.txt. Copy `examples/check_style.lua`, `examples/check_layers.lua` and `examples/lua_segments.lua` into `tools/`, or delete their lines from `check_rules.sh`. Start `versions.json` at the repo root as `{ "latestRelease": null, "preReleases": [], "releases": [] }`.
5. **Rename.** Set the main folder name as `ADDON:` in release.yml, `ADDON` in `versions.py` and `host_build.sh`, and in place of `MyAddon` in `bump_version.sh`, `check_rules.sh` (the file globs), the TOCs and check_layers' file list. Set `MIRROR_REPO` in release.yml, or delete the `mirror` job; set `SCRATCH_URL` in `host_build.sh` to the hosting repo.
6. **Make check_rules.sh pass locally:** `sudo apt-get install -y lua5.1`, then `sh tools/check_rules.sh` from the repo root.
7. **First version:** `sh tools/bump_version.sh line 0.1.0 "First build"` sets `## Version: 0.1.0.1` in every TOC, records it and writes the history section; fill in its bullet:
   ```
   => 0.1.0.1 - First build

   - What changed, in plain words.
   ```
   The heading must start exactly with `=> <version> ` (arrow, space, version, space): the notes step finds the section by that prefix and stops at the next line starting with `=> `.
8. **Open the first PR**, then `sh tools/bump_version.sh pr <number>` and push. Confirm the **Rules** check appears and passes.
9. **Branch protection (recommended).** Settings > Branches > a rule (or ruleset) for `main`: require a pull request and the status check `check` (the Rules job). The check is listed only after it has run once, so do this after step 8.
10. **Merge.** Watch Actions > Release. Releases then shows `v0.1.0.1` marked **Pre-release** with the zip attached, and Tags shows `v0.1.0.1`.
11. **Every later step:** `sh tools/bump_version.sh build "Title"`, fill in the bullets, open the PR, `sh tools/bump_version.sh pr <number>`, merge.

## 4. release.yml, step by step
Triggers: `push` to `main` (a merge that does not change the version is a no-op) and `workflow_dispatch` (Actions > Release > Run workflow, to retry after a fix). `permissions: contents: write`. `env`: `ADDON` (main folder) and `MIRROR_REPO`.

**Job `release`:**
| Step | What it does, and why |
| --- | --- |
| Read version | `sed -n 's/^## Version: *//p' <Addon>/<Addon>.toc \| tr -d '\r'` (the `tr` strips Windows line endings, which otherwise end up in the tag). `python3 tools/versions.py kind <ver>` gives `release` (the latest release), `pre-release`, or `unknown`, which fails the run: nothing unrecorded is published. `gh release view v<ver>` sets `exists`; every later step is skipped when the release already exists |
| Gate (recommended) | Install lua5.1 and run `sh tools/check_rules.sh` and the full harness (`tools/harness/validate_all.sh`) before building, so nothing ships from a red main; retry with Run workflow once main is fixed. Not in the template; add it once the harness exists (checkout with `fetch-depth: 0` if the harness rebuilds old versions from history) |
| Build zip and notes | Copies every `<Addon>` and `<Addon>_*` folder into `build/`, puts readme.txt and history.txt in `build/<Addon>/`, zips from inside `build/`. Notes: an install line, then "### Changes since <previous release>" for a release (from `versions.json` `releases[0].previous`) or "### Changes", then that version's history section (an awk block from `=> <ver> ` to the next `=> `), then "Full changelog: history.txt" |
| Publish release | `gh release create v<ver> <zip> --target $GITHUB_SHA --title ... --notes-file notes.md`, with `--latest` for a release and `--prerelease` otherwise. **Creates the tag and the release together** at the merged commit. Never push tags by hand |
| Keep pre-releases marked as pre-releases | Runs every time: any release not marked pre-release whose version is a recorded pre-release (or carries a `-` suffix, the old naming) is re-flagged, so "Latest" always points at a real full release |

**Job `mirror`** (optional; `needs: release`, runs when it succeeded): keeps `MIRROR_REPO` on `python3 tools/versions.py latest`. It does nothing when there is no release yet, or when the mirror's files, its `v<ver>` tag and its release already carry that version. Otherwise it clones the mirror with `MIRROR_TOKEN`, downloads the zip and notes from this repo's release, replaces every `<Addon>` and `<Addon>_*` folder with the zip's contents (the mirror's own files, such as its readme, stay), commits and pushes, then publishes the release on that commit with the same zip and notes (`--latest`), first deleting a release whose tag is not on the release's files. Because it checks every push, a release that went across without its files is repaired by the next push or a manual run.

## 5. rules.yml and check_rules.sh
`rules.yml` runs on every `pull_request` and every push to `main`. Its `check` job installs lua5.1 and runs `sh tools/check_rules.sh`, passing the pull request's number in an env variable (`PR_NUMBER` in the template) so `versions.py check` can require the PRs.

`tools/check_rules.sh` (exit non-zero on any failure, which fails the PR check):
- compiles every `.lua` with `luac5.1 -p` (Lua 5.1 syntax);
- runs `check_style.lua`: no Lua 5.2+ features, tabs, no alignment spaces, no trailing whitespace (`--fix` repairs);
- checks that TOCs, XML, readme.txt and history.txt are ASCII;
- checks that every TOC carries one version shaped `X.Y.Z.B`, that history.txt starts with that version's section and holds no placeholder bullet;
- runs `python3 tools/versions.py check --toc <ver>` (in CI with the PR number: every entry has its PR and a pull request's newest entry its own number);
- runs `check_layers.lua` (no UI calls in core logic files).

Add checks an addon needs to the script, and more jobs to rules.yml as the project grows. A mature repo typically adds: a harness job (the window and tab checks through `run.lua`); an upgrades job running `validate_all.sh` (checkout with `fetch-depth: 0`); an informational look-compare against the base branch that always passes and reports a difference as a warning annotation with the text in the job summary; and a real-saves job that clones the private hosting repo with a read-only token secret and runs the harness on the author's saves, and that says so and passes when the secret is missing (06_HARNESS.md).

## 6. Versions: releases are defined by feature
A version line belongs to a feature (or an agreed set of features), not to a date or a pile of changes (02 F1).

| Kind | Example | Published as |
| --- | --- | --- |
| A stage of the feature | `1.4.0.1`, `1.4.0.2`, ... | **Pre-release**; the same zip is the stage's hosted test build |
| A fix while the feature is in progress | the next build (`1.4.0.5` after `1.4.0.4`) | **Pre-release**, like any build |
| The feature complete | the next build, `1.4.0.8`, recorded as the release | **Full release**, only when the author confirms the feature is done |
| A fix after the release | `1.4.1.9`, ... then its release `1.4.1.11` | Pre-releases, then a full release |
| The next feature | `1.5.0.12` | Pre-release |

- **The version rules** are 02 F2 to F6; this section is how the tools carry them.
- **`versions.json`** (repo root) is the record the pipeline trusts: `latestRelease`, `preReleases` (every build since it, in order, each `{ "version", "pr" }`) and `releases` (each past release with its `previous` release and its own `preReleases`). References only, no text; never in an addon folder, so never in a zip or the mirror.
- **`tools/bump_version.sh`**: `build "Title"` (the next build), `release "Title"` (the next build as the release: `versions.json` moves the pending pre-releases under it and names it `latestRelease`; its history bullet is a placeholder for the summary), `line X.Y.Z "Title"` (the first build of a new line), `pr <number>` (records the PR on entries without one). Each version mode sets every TOC, records the version and adds the history section on top.
- **`tools/versions.py`**: `next build|release`, `next line X.Y.Z`, `add`, `release`, `pr`, `kind <version>` (release, pre-release or unknown), `latest`, `prs [<version>]` (the versions and PRs between the previous release and `<version>`, or the pending ones), `check [--pr N] [--strict] [--toc VERSION]`. Running it with no command prints its usage.
- Ask the author which line the next piece of work belongs to when it is not obvious (a new feature line or a fix line).
- One repo, one version for every folder. A second repo means a second version line and a cross-repo token.

### Full release notes and the mirror
- **Notes:** after `bump_version.sh release`, `python3 tools/versions.py prs <version>` lists every pre-release since the previous release with its PR. Claude reads each PR (title, description, diff as needed) and writes **one player-facing summary of all the changes** as the release's history section, in place of the placeholder bullet (the rules check fails while it is there). The release notes are that summary only, under "Changes since <previous release>": no per-build lists, no PR text, no API key in the pipeline. Pre-releases keep their own history section as notes.
- **Mirror (optional):** the `mirror` job (section 4). Pre-releases are not mirrored, and neither are `versions.json`, `tools` or `.github` (only what the zip holds).
- **Secret** (Settings > Secrets and variables > Actions on the addon repo): `MIRROR_TOKEN`, a fine-grained personal access token with **Contents: Read and write** on the mirror repo only. The built-in token cannot write to another repo; the job fails with a clear error without it.
- **The mirror repo needs at least one commit**; the tag is created on its default branch.
- **Retry:** the mirror skips anything already published, so after fixing the secret, run Actions > Release > Run workflow on main.

## 7. Test zips before merge
The release only happens on merge, so each PR also gets a **test zip** built the same way and hosted with a link: `sh tools/host_build.sh <hosting checkout> [--no-commit | --no-push]`. It refuses uncommitted addon changes, builds from HEAD (`git archive`) exactly as release.yml does, writes `releases/<Addon>-<version>-<YYYY-MM-DD-hh-mm>.zip`, replaces the zip in `latest/`, updates the hosting repo's index rows, commits and pushes, and prints the links (`--no-commit` stages only, so docs can join the same commit; `--no-push` commits without pushing). The hosting rules are in the hosting pack.

## 8. Working from a Claude session
- `gh pr create` (GraphQL) can be blocked; create PRs through REST: `gh api repos/<owner>/<repo>/pulls -f title="..." -f head=<branch> -f base=main -F body=@body.md`. Without `gh`, use the session's GitHub tools.
- Assign the PR to the author: `gh api repos/<owner>/<repo>/issues/<n>/assignees -f "assignees[]=<owner>"`. Requesting the repo owner as reviewer on a PR they authored returns 422.
- Check CI: `gh api repos/<owner>/<repo>/commits/<sha>/check-runs --jq '.check_runs[]|[.name,.conclusion]|@tsv'`.
- Check a release: `gh api repos/<owner>/<repo>/releases/tags/v<version> --jq '.html_url,.prerelease'`.
- Claude cannot delete branches (403) and never tags by hand; the author merges and deletes branches.

## 9. Troubleshooting
| Symptom | Cause and fix |
| --- | --- |
| No release after a merge | The version didn't change, or a release with that tag already exists. Bump the version |
| Release fails "is not in versions.json" | The version was set by hand. Use `bump_version.sh`, which records it |
| Release fails before publishing | The gate's rules check or harness failed on main. Fix main, then Run workflow |
| Release run fails "Resource not accessible by integration" | Workflow permissions are read-only. Settings > Actions > General > Read and write permissions |
| Tag name has a stray character or the run can't find the release | CRLF in the TOC; the `tr -d '\r'` must stay |
| Release notes empty | The history heading doesn't start with `=> <version> ` exactly |
| Rules fails on versions.json in CI | An entry has no PR, or the newest entry names another PR. `sh tools/bump_version.sh pr <number>` |
| The mirror job fails | `MIRROR_TOKEN` missing or without write access, or the mirror repo has no commit. Fix it, then run the workflow by hand |
| Zip extracts into an extra folder | Zip built from the repo root instead of from inside the build folder |
| A version merged before release.yml existed has no release | Expected. Bump to a new version (or run the workflow by hand while that version is on main) |
| A broken release was published | Fix forward with the next build. To redo the same version, the author deletes the release and its tag in the GitHub UI, then runs the workflow by hand |
| Stacked PRs landed in a stale branch | PR B was based on PR A's branch and A merged first. Base every PR on main, or delete each base branch after merging so GitHub retargets the next PR. Merge the stranded work with a new PR from main |
| Changing a PR's base via the API is refused | Ask the author to change it in the GitHub UI |
| Rules fails only in CI | The runner lacks a tool the script calls; install it in rules.yml (as lua5.1 is) |
| A workflow in repo B must read private repo A | Add a fine-grained read-only token for A as a secret in B; make the job warn and pass when the secret is missing |
