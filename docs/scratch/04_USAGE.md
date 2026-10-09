# Using scratch from a Claude session

## Links
| Purpose | Form |
| --- | --- |
| Download a file | `https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/<path>` |
| Read a file in the browser | `https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/<path>` |
| Browse a folder | `https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/<path>` |

Every reply that delivers a file gives the link in the text.

## Pushing
```sh
cd <scratch checkout>
git checkout main && git pull -q origin main    # always main, always the latest
mkdir -p <folder> && cp <file> <folder>/
git add <folder> && git commit -m "<what, with version>" && git push origin main
```
- Pull first; other sessions push to scratch too.
- One commit per delivery, named for the thing and its version. Never a branch or a PR (rule 15).
- Build zips in a fresh, uniquely named directory; don't `rm -rf` globs (sandboxes block it).

## Test builds (rules 9, 12)
`sh tools/host_build.sh <scratch checkout>` (addon repo) does all of it from HEAD; `--no-commit` stages it so docs join the same commit.
1. Build the zip from the committed HEAD, every addon folder at the zip root.
2. Store it as `releases/<Name>-<version>-<YYYY-MM-DD-hh-mm>.zip` and, in the same commit, replace the zip in `latest/` with it.
3. Push; reply with the link and the in-game checks.

## SavedVariables (rules 4, 13)
1. The author uploads the files from `WTF/Account/<account>/SavedVariables/` and names the version.
2. Commit them to `SavedVariables/<version>/` with a line in `SavedVariables/README.md` (what is in it, the size).
3. The harness builds its input from here (`sh tools/harness/build_saves.sh <scratch checkout> <out dir>` in the addon repo). Never commit real saves to an addon repo.

## Docs and handover packs (rule 10)
1. Put the newest markdown in `docs/latest/<project-or-feature>/`, organised into folders. Plans, analysis and long issue write-ups are docs too.
2. Zip each docs release / handover pack as `<name>-<date>-vN.zip` in the root of `docs/`.
3. For a project or feature release, also keep its files in `docs/<project-or-feature>/` for history.
4. Update `docs/README.md` (what each folder and pack is for, its version row).
5. Reply with the zip link and a link to the unzipped folder.

## Summaries
Status summaries go in `summary/<project>-<YYYY-MM-DD-hh-mm>.md`.

## Keeping it readable
- Update `readme.md` whenever a folder is added or the newest file in it changes.
- Never delete or rename a file someone was given a link to; add the new one beside it.
