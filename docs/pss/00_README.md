# PourSocialScore project pack

The **PourSocialScore-only layer.** It sits on top of two general packs and does not repeat them:

| Layer | Pack | Holds |
| --- | --- | --- |
| 1 | `docs/baseline/` (`wow-addon-baseline-<date>-vN.zip` on scratch; mandatory) | How any WoW addon is built, released and delivered with Claude: rules, architecture, harness, pipeline, feature design and staged delivery, working with the author |
| 2 | `docs/scratch/` (`scratch-repo-usage-<date>-vN.zip`) | How the scratch repo, `racetracks/Pour-Social-Score_Scratch`, hosts builds, saves, docs and summaries |
| 3 | **this pack**, `docs/pss/` | Only what is true of PourSocialScore |

**The baseline's rules are mandatory** (Dan, 2026-10-08). This pack overrides one only in 02 section 12 (the Overrides table). "Baseline 02 C3" style references point into layer 1. Current state is always in 06; project data on scratch `docs/latest/`.

## How to restart
- **Claude Code session:** `CLAUDE.md` at the repo root loads what every session needs; start there.
- **Claude project:** attach `racetracks/PourSocialScore` and `racetracks/Pour-Social-Score_Scratch` (never the retired `racetracks/PourSocialScore-EllesmereUI` or the old `racetracks/scratch`), paste `PROJECT_INSTRUCTIONS.md` as the project instructions, upload the three packs in layer order and say: "Read CLAUDE.md and what it loads; confirm the next step."
- Real saves: `sh tools/harness/build_saves.sh <scratch checkout> <out dir>` builds the harness input from scratch `SavedVariables/<version>/` (04, Real saves). Never commit real saves to the addon repo.

## Files
| File | What it holds |
| --- | --- |
| 01_HANDOVER.md | The addon as it works at the last full release (re-summarized at each release): purpose, features, repos, folders, real names, plans |
| 02_RULES.md | Only the rules PSS adds to the baseline, dated, with Dan's wording; section 12 is the Overrides table |
| 03_ELLESMEREUI.md | EllesmereUI as the reference for building UI elements (section 0), and the lessons of the old integration |
| 04_DATA_AND_LOGGING.md | SavedVariables, outbox, Logging on demand, the grouped save, recent counts, caps, real saves |
| 05_RELEASE.md | What PSS does on top of the baseline pipeline: names, jobs, releases, pitfalls |
| 06_STATUS_AND_NEXT.md | Now, next step, items waiting on Dan, open issues (updated in every PR) |
| 07_HARNESS.md | PSS harness commands and checks |
| 08_PARITY_PROJECT.md | The closed 3.3.0 parity project (shipped as 3.3.1) |
| 09_PSS_UI_PROJECT.md | The closed window project (released as 3.4.0.29): decisions, code map, lessons; the reference for any window change. The window's rules are `CLAUDE.md`'s Interface section |
| 10_CORE_UPLIFT.md | The closed core uplift (released as 3.4.1.53): design, decisions, what each stage did |
| 11_PREFERENCES.md | Dan's preferences and approach: the one file, loaded in every session |
| 13_CHANGES_IN_TRAIN.md | The core uplift's findings, what shipped and what is open; on demand |
| PROJECT_INSTRUCTIONS.md | Paste-ready project instructions |
| reference/ | History, read only: the 3.3 parity analysis and plan (`plans-3.3-parity/`), the issue #77 note (`issues/`), the 2026-10-07 memory snapshot (`memory-2026-10-07/`), status history to 3.4.1.30 (`06_status-history-to-3.4.1.30.md`), the 3.4.1.52 per-stage notes (`combined-3.4.1.52/`) |

On scratch: the code map, the only copy (`docs/latest/code-map/`, https://github.com/racetracks/Pour-Social-Score_Scratch/tree/main/docs/latest/code-map; read first for code review, code change, code questions and feature requests); the real saves (`SavedVariables/<version>/`); release notes per full release (`docs/latest/release-notes/`).
