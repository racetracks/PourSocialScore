# Tag and release pipeline: full setup

Every new project struggles with this. The whole pipeline is **two workflow files, one rules script and one rule: the version in the main TOC is the release.** Nobody tags by hand; merging a version bump to main publishes the release, a pre-release for any version with a suffix.

## 1. What you end up with
- Every PR runs the **Rules** check (`.github/workflows/rules.yml` running `tools/check_rules.sh`).
- Every push to main runs **Release** (`.github/workflows/release.yml`). If the main TOC's version has no release yet, it builds `<Addon>-<version>.zip`, creates the tag `v<version>` and the GitHub release with that version's history section as notes, and marks it a pre-release when the version contains `-`.
- Merges that don't change the version publish nothing.

## 2. Repo layout the workflows expect
```
<Addon>/                    main addon folder (its name = the TOC name = ADDON in release.yml)
  <Addon>.toc               base TOC: "## Version: X.Y.Z[-devNNN]" (the version is read from here)
  <Addon>_Mainline.toc      flavour TOCs, same version
  <Addon>_Camelot.toc
  *.lua
<Addon>_<Part>/             any other addon folders (all zipped; each with its own three TOCs)
tools/check_rules.sh        the rules check (plus check_style.lua, check_layers.lua if used)
.github/workflows/rules.yml
.github/workflows/release.yml
readme.txt                  copied into <Addon>/ inside the zip
history.txt                 copied into <Addon>/ inside the zip; release notes come from it
```
Every folder named `<Addon>` or `<Addon>_*` at the repo root goes into the zip, at the zip's root, so it extracts straight into `Interface/AddOns`. `.github`, `tools` and anything else stay out.

## 3. Step by step, from an empty repo
1. **Create the repo** (private is fine) with a default branch named `main`.
2. **Workflow permissions.** The release job writes tags and releases with the built-in `GITHUB_TOKEN`. `release.yml` asks for `permissions: contents: write`, which is enough on a personal repo. In an organisation, or if the run fails with "Resource not accessible by integration", open **Settings > Actions > General > Workflow permissions** and choose **Read and write permissions**. No personal token or secret is needed.
3. **Actions enabled.** Settings > Actions > General > "Allow all actions" (or at least GitHub-authored ones: the workflows use `actions/checkout@v4`, `gh` and apt).
4. **Copy the templates** from `templates/`: `.github/workflows/release.yml`, `.github/workflows/rules.yml`, `tools/check_rules.sh`, the TOC set, history.txt. Copy `examples/check_style.lua`, `examples/check_layers.lua` and `examples/lua_segments.lua` into `tools/`, or delete their lines from `check_rules.sh`.
5. **Rename.** Set `ADDON:` in release.yml to the main folder name. Replace `MyAddon` in `check_rules.sh` (the file globs), in the TOCs and in check_layers' file list.
6. **Make check_rules.sh pass locally:** `sudo apt-get install -y lua5.1` then `sh tools/check_rules.sh` from the repo root.
7. **First version:** set `## Version: 0.1.0-dev001` in every TOC and write the first history section:
   ```
   => 0.1.0-dev001 - First build
   - What changed, in plain words.
   - Version 0.1.0-dev001.
   ```
   The heading must start exactly with `=> <version> ` (arrow, space, version, space): the notes step finds the section by that prefix and stops at the next line starting with `=> `.
8. **Open the first PR.** Confirm the **Rules** check appears and passes.
9. **Branch protection (recommended).** Settings > Branches > add a rule (or ruleset) for `main`: require a pull request and require the status check `check` (the Rules job name). The check appears in the list only after it has run once, so do this after step 8.
10. **Merge.** Watch Actions > Release. When it finishes, Releases shows `v0.1.0-dev001` marked **Pre-release** with the zip attached, and Tags shows `v0.1.0-dev001`.
11. **Every later step:** bump the version in every TOC, add a history section on top, merge. That's the whole release process.

## 4. release.yml, explained
```yaml
# Publishes a GitHub release whenever the version in $ADDON/$ADDON.toc changes
# on main: tags v<version> and attaches $ADDON-<version>.zip (every addon folder
# $ADDON and $ADDON_*, readme.txt and history.txt inside $ADDON; no .github or
# tools), with that version's section of history.txt as the notes. Does nothing
# if the release exists. Versions with a suffix (1.0.0-dev004) are pre-releases.
name: Release

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: write

env:
  ADDON: MyAddon   # main folder / TOC name

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Read version
        id: v
        run: |
          ver=$(sed -n 's/^## Version: *//p' "$ADDON/$ADDON.toc" | tr -d '\r')
          echo "version=$ver" >> "$GITHUB_OUTPUT"
          if gh release view "v$ver" >/dev/null 2>&1; then
            echo "exists=true" >> "$GITHUB_OUTPUT"
          else
            echo "exists=false" >> "$GITHUB_OUTPUT"
          fi
        env:
          GH_TOKEN: ${{ github.token }}

      - name: Build zip and notes
        if: steps.v.outputs.exists == 'false'
        run: |
          ver=${{ steps.v.outputs.version }}
          mkdir -p build
          for d in "$ADDON" "$ADDON"_*/; do
            if [ -d "$d" ]; then cp -r "${d%/}" build/; fi
          done
          cp readme.txt history.txt "build/$ADDON/"
          (cd build && zip -qr "../$ADDON-$ver.zip" .)
          {
            echo "**Install:** extract the zip into \`World of Warcraft/_retail_/Interface/AddOns/\`."
            echo
            echo "### Changes"
            awk -v v="$ver" '
              index($0, "=> " v " ") == 1 { on = 1; next }
              on && /^=> / { exit }
              on { print }
            ' history.txt
            echo
            echo "Full changelog: history.txt"
          } > notes.md

      - name: Publish release
        if: steps.v.outputs.exists == 'false'
        run: |
          ver=${{ steps.v.outputs.version }}
          pre=""
          case "$ver" in *-*) pre="--prerelease" ;; esac
          gh release create "v$ver" "$ADDON-$ver.zip" $pre \
            --target "$GITHUB_SHA" --title "$ADDON $ver" --notes-file notes.md
        env:
          GH_TOKEN: ${{ github.token }}

      - name: Mark suffixed releases as pre-releases
        run: |
          gh release list --limit 100 --json tagName,isPrerelease \
            --jq '.[] | select(.isPrerelease | not) | .tagName | select(contains("-"))' |
          while read -r tag; do gh release edit "$tag" --prerelease; done
        env:
          GH_TOKEN: ${{ github.token }}
```

| Part | Why |
| --- | --- |
| `on: push: branches: [main]` | Runs after every merge; the version check makes non-bump merges a no-op |
| `workflow_dispatch` | A "Run workflow" button under Actions, to retry after fixing a failed run |
| `permissions: contents: write` | Lets `github.token` create tags and releases |
| `sed -n 's/^## Version: *//p' ... \| tr -d '\r'` | Reads the version; strips Windows line endings, which otherwise end up in the tag name |
| `gh release view "v$ver"` | Skips everything if that release already exists |
| The copy loop over `"$ADDON" "$ADDON"_*/` | Puts every addon folder at the zip root; nothing else |
| The awk block | Copies that version's history section into the release notes |
| `case "$ver" in *-*) pre="--prerelease"` | Any suffix (`-dev004`) makes a pre-release; plain `X.Y.Z` is a full release |
| `gh release create "v$ver" ... --target "$GITHUB_SHA"` | **Creates the tag and the release together** at the merged commit. Never push tags by hand |
| The last step | Turns any older suffixed release that someone marked as full back into a pre-release |

## 5. rules.yml and check_rules.sh
```yaml
# Rules check on every pull request and push to main: tools/check_rules.sh
name: Rules

on:
  pull_request:
  push:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Lua 5.1
        run: sudo apt-get update -q && sudo apt-get install -y -q lua5.1
      - name: Check rules
        run: sh tools/check_rules.sh
```

`tools/check_rules.sh` compiles every `.lua` with `luac5.1 -p` (Lua 5.1 syntax), runs `check_style.lua` (no Lua 5.2+ features, tabs, no trailing whitespace; `--fix` repairs), checks that TOCs, XML, readme.txt and history.txt are ASCII, and runs `check_layers.lua` (no UI calls in core logic files). It exits non-zero on any failure, which fails the PR check. Add more jobs to rules.yml (for example a harness job) as the project grows.

## 6. Versions: releases are defined by feature
A version line belongs to a feature (or an agreed set of features), not to a date or a pile of changes.

| Kind | Example | Published as |
| --- | --- | --- |
| A stage of the feature | `1.4.0-dev001` .. `1.4.0-dev006` | **Pre-release** (suffix); the same zip is the stage's hosted test build |
| A bugfix while the feature is in progress | the next devNNN on the line | **Pre-release**, like any stage |
| The feature complete | `1.4.0` | **Full release**, only when the author confirms the feature is done |
| A fix after the release | `1.4.1-dev001`, then `1.4.1` | Pre-release, then a full release |
| The next feature | `1.5.0-dev001` | Pre-release |

- **Every pre-release must carry a suffix.** The pipeline decides pre-release versus full release only from the version: any `-` makes it `--prerelease`, and the "mark older suffixed releases" step keeps every earlier `-devNNN` release flagged as a pre-release (so "Latest" always points at a real production build). A missing suffix publishes a full release by mistake, which the author must then delete by hand.
- `-devNNN`: three digits, from dev001, incrementing, never reused within a line. One merged PR = one devNNN.
- The feature design (10_FEATURE_DESIGN_AND_DELIVERY.md) names the line and maps each stage to its devNNN before work starts.
- **Going to production:** a PR that sets the plain `X.Y.0` in every TOC with a history section that sums up the whole feature. Merging it publishes the full release; the stage pre-releases stay as history.
- Ask the author which line the next piece of work belongs to when it is not obvious (a new feature line or a fix line).
- One repo, one version for every folder. A second repo means a second version line and a cross-repo token.

## 7. Test zips before merge
The release only happens on merge, so each PR also gets a **test zip** built the same way from the PR's commit and hosted with a link (see the hosting pack):
```sh
mkdir -p /tmp/build-<unique>/src /tmp/build-<unique>/out
git archive HEAD | tar -x -C /tmp/build-<unique>/src
cd /tmp/build-<unique>/src
for d in MyAddon MyAddon_*/; do [ -d "$d" ] && cp -r "${d%/}" ../out/; done
cp readme.txt history.txt ../out/MyAddon/
cd ../out && zip -qr ../MyAddon-1.4.0-dev004.zip .
```

## 8. Working from a Claude session
- `gh pr create` (GraphQL) can be blocked; create PRs through REST: `gh api repos/<owner>/<repo>/pulls -f title="..." -f head=<branch> -f base=main -F body=@body.md`.
- Assign the PR to the author: `gh api repos/<owner>/<repo>/issues/<n>/assignees -f "assignees[]=<owner>"`. Requesting the repo owner as reviewer on a PR they authored returns 422.
- Check CI: `gh api repos/<owner>/<repo>/commits/<sha>/check-runs --jq '.check_runs[]|[.name,.conclusion]|@tsv'`.
- Check a release: `gh api repos/<owner>/<repo>/releases/tags/v<version> --jq '.html_url,.prerelease'`.
- Claude cannot delete branches (403) and should not tag by hand; the author merges and deletes branches.

## 9. Troubleshooting
| Symptom | Cause and fix |
| --- | --- |
| No release after a merge | The version didn't change, or a release with that tag already exists. Bump the version |
| Release run fails "Resource not accessible by integration" | Workflow permissions are read-only. Settings > Actions > General > Read and write permissions |
| Tag name has a stray character or the run can't find the release | CRLF in the TOC; the `tr -d '\r'` must stay |
| Release notes empty | The history heading doesn't start with `=> <version> ` exactly |
| Zip extracts into an extra folder | Zip built from the repo root instead of from inside the build folder |
| A version merged before release.yml existed has no release | Expected. Bump to a new version (or run the workflow by hand while that version is on main) |
| A broken release was published | Fix forward with the next devNNN. To redo the same version, the author deletes the release and its tag in the GitHub UI, then runs the workflow by hand |
| Stacked PRs landed in a stale branch | PR B was based on PR A's branch and A merged first. Base every PR on main, or delete each base branch after merging so GitHub retargets the next PR. Merge the stranded work with a new PR from main |
| Changing a PR's base via the API is refused | Ask the author to change it in the GitHub UI |
| Rules fails only in CI | The runner lacks a tool the script calls; install it in rules.yml (as lua5.1 is) |
| A workflow in repo B must read private repo A | Add a fine-grained read-only token for A as a secret in B; make the job warn and pass when the secret is missing |
