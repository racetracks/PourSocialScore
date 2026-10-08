# PourSocialScore project pack (2026-10-07, v4)

The **PourSocialScore-only layer.** It is written to sit on top of two general packs and does not repeat them:

| Layer | Pack | Holds |
| --- | --- | --- |
| 1 | `wow-addon-baseline-2026-10-07-v5.zip` (v4 plus 02 J and `reference/wow-api/`) | How any WoW addon is built, released and delivered with Claude: rules, architecture, harness, pipeline, feature design and staged delivery, working with the author |
| 2 | `scratch-repo-usage-2026-10-07-v4.zip` (in the repo as `docs/scratch/`) | How the scratch repo, `racetracks/Pour-Social-Score_Scratch`, hosts builds, saves, docs and summaries |
| 3 | **this pack** | Only what is true of PourSocialScore: its purpose, repos, real names, project rules, the EllesmereUI integration, its data, its pipeline details, status and next step, Dan's real saves |

**Where they differ, this pack wins for PourSocialScore.** Everything not mentioned here follows the baseline. Section numbers like "baseline 02 C3" point into layer 1.

Last state (pack written): main was **3.3.0-dev004**. Since then: 3.3.1 released (full, the parity project closed), and the new PSS window project started on the **3.4.0** line (09). Current state is always in 06; project data on scratch `docs/latest/`.

## How to restart
1. New Claude project. Attach `racetracks/PourSocialScore` (the addon) and `racetracks/Pour-Social-Score_Scratch` (hosting; the old `racetracks/scratch` is no longer used). Never attach `racetracks/PourSocialScore-EllesmereUI` (retired).
2. Paste `PROJECT_INSTRUCTIONS.md` (this pack) as the project instructions. It already folds in the baseline's key lines.
3. Upload the three zips in layer order and say: "Read the baseline README, 02_RULES, 07 and 10; then the scratch pack README; then this pack's 00_README, 06_STATUS_AND_NEXT and 01 to 05; confirm the next step."
4. The project files are the scratch repo (Dan, 2026-10-08); there is no `/mnt/project-files`. For the harness, run `sh tools/harness/build_saves.sh <scratch checkout> <out dir>`: it joins each scratch `SavedVariables/<version>/` set into `<out dir>/<version>/PourSocialScore.lua` (see 04 section 8). Never commit real saves to the addon repo.

## Files
| File | What it holds |
| --- | --- |
| 01_HANDOVER.md | Purpose and features, clients, repos, folder layout and the real names (namespace, loader, options, events), references actually used, plans with status |
| 02_RULES.md | Only the rules PSS adds to or overrides in the baseline, dated, with Dan's wording |
| 03_ELLESMEREUI.md | The EllesmereUI integration: files, bridge, APIs used, house rules, window, the PSS tab shadow fix |
| 04_DATA_AND_LOGGING.md | SavedVariables layout, outbox, Logging on demand, the grouped save, recent counts, caps, retired BlockStats, real saves |
| 05_RELEASE.md | What PSS does on top of the baseline pipeline: names, jobs, version history, test zip paths |
| 06_STATUS_AND_NEXT.md | Merged and open work, the parity project, open issues, items waiting on Dan, the next step |
| 07_HARNESS.md | PSS harness commands and checks |
| 08_PARITY_PROJECT.md | The closed 3.3.0 parity project (shipped as 3.3.1): objective, decisions, stage table |
| 09_PSS_UI_PROJECT.md | The current project (3.4.0): the new PSS window, decisions, three looks, stages, code map, lessons; plan on scratch `docs/latest/ui uplift/` |
| PROJECT_INSTRUCTIONS.md | Paste-ready project instructions |
| savedvariables/<version>/ | Dan's real saves: 2.0.44, 3.0.0, 3.2.0-dev011 (on scratch `SavedVariables/<version>/`) |
| ci/ | Copies of the live release.yml, rules.yml and check scripts from main |
| reference/ | The 3.3 parity analysis and plan, issue notes, a memory snapshot |
