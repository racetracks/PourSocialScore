# 17_BUILD_PREFERENCES: the author's build, test and release preferences

| Header | |
| --- | --- |
| Purpose | The author's build, test and release preferences, moved word for word from `docs/pss/11_PREFERENCES.md` (`DEC-00387` a); read in full before any build, test run, PR or release |
| Owning component | PSS pack (`docs/pss/`) |
| Last updated | 3.8.0.123, session busy-fermi-qrk4qx |
| Status | Live (the author's preferences) |
| Related | `docs/pss/11_PREFERENCES.md`, `docs/pss/15_ROUTES.md#route-table` |

## Contents
- [Sessions and context](#sessions-and-context)
- [Communication](#communication)
- [How the author works](#how-the-author-works)
- [Changelog](#changelog)

## Sessions and context
- **Context is updated in every PR (2026-10-08).** Before a step's PR is final, update everything a fresh session needs to carry on:
  - the current project's stage table (state, PR, next build);
  - `06_STATUS_AND_NEXT.md`;
  - `02_RULES.md` for a new rule;
  - this file for a new preference;
  - the scratch copies (`docs/latest/pss-docs/`, the project's `docs/latest/<project>/`).

  A fresh session must be able to start from `CLAUDE.md` alone.

## Communication
- Give exact numbered in-game checks for every build, naming each look (Modern, Classic, Dark) and each client (Retail, Camelot) where it matters.
- Expect a code review pass before merging.

## How the author works
- **Simulate the WoW client while coding (the author, 2026-10-09).** Every change is exercised in the harness's simulated client (`tools/harness/wow_stub.lua` through `tools/harness/run.lua`) as it is written, not only at the end: (1) drive the path you changed: load the addon on a save (a real one for anything that touches data), fire the events, slash commands and clicks that reach the changed code, and read what it actually did (chat lines, the frame dump, the saved file) before going on; a pass line alone is not the observation. (2) Changed or new behaviour gets a harness check that fails on the old code (run it against `origin/main` to prove it). (3) The window is driven through `tui_tour.lua` and `tui_compare.sh` in all three looks, Camelot paths with `PSS_CAMELOT=1`, chat and unit paths with secret values (`check_secrets.lua`). (4) The PR and the handover say what was simulated and what a simulation cannot show (wrapped text, real combat and chat lockdown timing, taint, client art), and those go to the numbered in-game checks.
- **Claude runs every test before handover (2026-10-09).** The rules check, the full harness on the real saves from scratch `SavedVariables/`, the same-as-main or sparse-saves comparison and `tui_compare.sh` are run by Claude before a PR is handed over, and the results (counts, failures, anything skipped) are reported. CI (`rules.yml`) is a backstop, not a substitute: it cannot run the real saves, same-as-main or the look compare. The author never runs tests; where testing is relevant, the test material is packaged as a zip and linked (Operating Instructions 6); the PR states what was run and the counts. A check that prints a NOTE and skips (for example `origin/main` unknown in a single-branch clone) is not a pass: fetch the ref and run it again.
- The author tests every build in game and does every merge. "Branch, PR and release" is approval to merge and verify the release.
- Production is explicit: a full release happens only when the author says the feature is done. Before a full release goes live, the author tests a very old save on the final pre-release.
- The author uploads WTF saves and names the version ("this is a 3.4.0.28 save"); file them on scratch under `SavedVariables/<version>/`.
- Build numbers stay consistent: every build, a release included, takes the next number, and later lines count on.
- The author reads the GitHub Releases directly. Release notes are one player-facing summary of every change since the previous release.
- **Every full release has its record on scratch (2026-10-09):** a release-notes md per release (`docs/latest/release-notes/<version>.md`, one for each release in `versions.json`) and its rows in one summary of changes (`docs/latest/summary-of-changes/SUMMARY_OF_CHANGES.md`), each change linked to its build, PR and technical notes. Release notes and technical notes stay in different folders. Only the author's full releases are releases: up to 2.0.17, 2.0.18, 2.0.19, 2.0.22, 2.0.40, 2.0.44, 3.0.0, 3.3.1, 3.4.0.29, 3.4.1.53, 3.4.2.54 (3.1.0 and 3.2.0 count as pre-releases of 3.3.1).
- **Release notes and technical notes are context for change and regression (2026-10-09).** Before changing behaviour, fixing a bug, checking for a regression or weighing a feature, read the summary of changes for that area and the release notes and technical notes it links, after the code map. Every full release updates them, with the code map, in the same delivery (`05_RELEASE.md`, Full releases).

## Changelog
| Date | Reference | Change | Reason | Context |
| --- | --- | --- | --- | --- |
| 2026-10-18 | this file | created: `docs/pss/11_PREFERENCES.md` lines 10 to 17, 27, 33 and 36 to 44 moved word for word | `DEC-00387` a: preferences split | scratch `temp/2026/10/18/15-10-00-Sun-busy-fermi-qrk4qx/prompts/12.md`; before: new |
