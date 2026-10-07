# Feature design and delivery

How a feature goes from an idea to a production release: **design it, plan the implementation, cut it into stages, deliver each stage as its own small PR that can be tested on its own, and validate between PRs.** No big bang: no PR should be the first time two untested pieces meet.

## 1. Feature design (before any code)
One document per feature (or per agreed feature set), beside the plans in the hosting location. It holds:

| Section | What it says |
| --- | --- |
| Goal | What the user will see and do, in a few lines, from the author's request |
| What exists | The code, data and UI it touches; gaps; anything that already counts or draws something similar |
| Constraints | The rules that bite (02_RULES.md: zero cost when off, default OFF, no taint, SavedVariables growth, separation of logic and UI), API limits (01) |
| Design | Where each piece lives (core, library folder, each UI folder, 04_ARCHITECTURE.md); new settings and their defaults; new events; data layout and its migration; how each front end draws it |
| Decisions | Every open choice, numbered, with options and a recommendation. The author answers by number; record the answers with the date |
| Version line | The `X.Y.0` this feature owns (02 F) |
| Implementation plan | The stage table below |
| Validation | How each stage and the whole feature will be proven (section 4) |
| Risks | What could break existing users, and how a stage will catch it |

Rules for the design:
- **Settle data before drawing.** Counting, storage and migrations come before any UI that shows them. If two places would count the same thing differently, the first stage makes them read one counter.
- **Design for zero cost when off.** Name what loads, what registers and what is allocated only when the user enables the feature.
- **Recommend a default for every fork** and say which one the stages are built on, so work never waits on an answer.
- Play the final decisions back to the author before the first stage starts.

## 2. Implementation plan: stages
Cut the feature into stages. Each stage is one PR and one devNNN on the feature's line.

| Stage | devNNN | Change | Visible? | How it is validated |
| --- | --- | --- | --- | --- |
| 1 | `X.Y.0-dev001` | Groundwork: shared logic moved or added in the library folder, nothing visible changes | No | Harness green; look-compare "identical"; measured resident cost |
| 2 | `X.Y.0-dev002` | Data: new counters or storage, with the migration | No | Migration run on every old layout and the author's real saves; save size measured |
| 3 | `X.Y.0-dev003` | The smallest visible slice of the feature, behind its option (default OFF) | Yes | In-game checks; option off = no cost and no change |
| 4.. | `X.Y.0-dev004`.. | One more visible piece per stage (one tab, one chart, one front end) | Yes | In-game checks for that piece, plus the earlier stages still passing |
| Last | `X.Y.0-devNNN` | Polish, readme, edge cases from testing | Yes | Full regression: harness, look-compare, numbers match, real saves |
| Release | `X.Y.0` | Version only, history section for the whole feature | | The author confirms the feature is complete |

How to cut stages:
- **Each stage is installable and testable on its own**: it builds, loads, passes the checks and leaves the addon usable. A half-done feature hides behind its option, never behind a broken window.
- **Order by dependency and risk**: invisible groundwork first (proven identical), then data, then the smallest visible piece, then one piece at a time.
- **A refactor that should change nothing is its own stage**, proven unchanged, never mixed with new behaviour.
- **Keep stages small**: one concern per PR, ideally one folder or one window. If a stage grows while building, stop, split it, and tell the author before carrying on.
- **One PR per stage, based on main**, after the previous stage has merged. Never stack PRs; a stage branch is cut from the main that already contains the stage before it.
- Each stage's PR names its stage, its devNNN, what it changes and the measured cost of what it adds.

## 3. Delivering a stage
1. Branch from the latest `origin/main` (which carries the previous stage).
2. Build only that stage. Match the surrounding code (02 A3).
3. Bump every TOC to the stage's devNNN; add its history section; update the readme if users see a change.
4. Run the validation for the stage (section 4) and fix until clean.
5. Open the PR; build and host the test zip; give the author the link and a numbered list of exact in-game checks.
6. The author tests and merges. Merging publishes the stage as a **pre-release** (09_RELEASE_PIPELINE.md).
7. Update the status and the stage table (merged, next devNNN), then start the next stage.

## 4. Validation between PRs
Nothing starts on stage N+1 until stage N is merged and has passed:

| Check | When | Proves |
| --- | --- | --- |
| Rules check (CI) | Every PR | Lua 5.1, ASCII, style, no UI calls in core logic |
| Harness checks (06) | Every PR | Behaviour, events, setters, option table, loading on demand |
| Migrations on every old layout and the author's real saves | Any stage that touches saved data | No data loss, no growth, old leftovers pruned |
| Look-compare between main and the branch | Any stage that should not change a window | "Identical", or only the intended differences |
| Numbers match | Any stage where two places show the same count | Every front end shows the same numbers from one counter |
| Measured cost | Any stage that adds or moves code or data | Resident memory, compiled size, CPU, save size; numbers go in the PR |
| Option off | Any stage that adds a feature behind an option | No events, frames, hooks or memory when off; no change for users who never enable it |
| Test zip in game | Every PR | The author's numbered in-game checks pass on the real client and real saves |
| Earlier stages | Every PR | Earlier stages' checks still pass (the harness keeps them) |

If a stage fails in game: fix it as the next devNNN on the same line (a new PR from main) before the next planned stage. Never fold a fix into an unrelated stage.

## 5. Finishing the feature
- When every stage has merged and passed, run the full regression on the last devNNN.
- Ask the author to confirm the feature is complete. Only then does a PR set the plain `X.Y.0` with a history section summing up the feature; merging it publishes the full release.
- Mark the design document done, record anything learned in project memory, and park leftover ideas for a later line.

## 6. A worked shape (generic)
A feature "show a breakdown chart in the options window", line `1.5.0`:
1. `1.5.0-dev001`: move the totals query the chart needs into the library folder; the existing window calls it; look-compare identical.
2. `1.5.0-dev002`: add a capped per-type counter with a migration; validated on real saves; no UI.
3. `1.5.0-dev003`: draw the chart in the native window behind a new option (default OFF); option-off check; in-game checks.
4. `1.5.0-dev004`: the same chart in the suite front end from the same library call; numbers-match check.
5. `1.5.0-dev005`: fixes from testing, readme.
6. `1.5.0`: production release once the author confirms.
