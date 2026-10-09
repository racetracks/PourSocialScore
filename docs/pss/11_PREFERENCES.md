# The author's preferences and approach (the one file)

Everything about how the author works and what the author wants from Claude lives here (the author, 2026-10-08). `CLAUDE.md` loads it in every session. Other docs stay technical and close to the addon. Add new preferences here, dated, and never spread them across other files. Baseline 07 is the generic version; where they differ, this file wins.

## Sessions and context
- **One step per session (2026-10-08).** The author resets the session after each step of every implementation plan. Build only the named step, then stop.
- **Context is updated in every PR (2026-10-08).** Before a step's PR is final, update everything a fresh session needs to carry on:
  - the current project's stage table (state, PR, next build);
  - `06_STATUS_AND_NEXT.md`;
  - `02_RULES.md` for a new rule;
  - this file for a new preference;
  - the scratch copies (`docs/latest/pss-docs/`, the project's `docs/latest/<project>/`).

  A fresh session must be able to start from `CLAUDE.md` alone.
- **Plans and designs are references (2026-10-08).** `CLAUDE.md` points to them and never copies them. At each full release, the done stages are re-summarized into `01_HANDOVER.md`, which describes how the addon works at that release, and leave the plan.
- **Keep the memory lean and technical (2026-10-08).** Load only what the step needs. Read an appendix or a reference only for the stage that uses it. Delegate wide reading to subagents, and keep only their conclusions.

## Communication
- **Call the user "the author" (2026-10-09):** never by name, in replies, docs, PRs, commits and issues; in docs write "the author" ("the author's OK"), never a name and never gendered pronouns.
- **Response style (2026-10-09):** short, with no preamble and no recap of what was just done. Don't explain code changes unless the author asks. Don't repeat file contents back; reference line numbers (`file:line`).
- **Lean memory (2026-10-09):** keep what is held in memory to a minimum. Where that would hide critical information, give it to the author anyway, as a markdown in a scratch folder (never hosted in the session), with a link. Several files go in one folder, not a zip; a crucial markdown always sits in a folder, linked.
- **Sparse messages and tokens; reuse threads (2026-10-09):** send a message or spend tokens only when required. Where possible, reuse an existing thread (subagent or session, through `SendMessage` or `send_message`) that already has the tools deployed and holds the memory and context the task needs, instead of starting a new one.
- **File hosting (2026-10-09):** never host files in the Claude session; use the most relevant scratch folder (`summary/`, `releases/`, or `docs/latest/<topic>/`: `issues/`, `setup/`, `release-notes/`, `code-map/`, `pss-docs/`).
- Plain language, answer first, short; the author may read on the go.
- Numbered questions, each with a recommendation; the author answers by number ("1: yes 2: recommended"). Play the final decisions back before building.
- Always give links: scratch `raw` links for zips, `blob` links for docs, `tree` links for folders. Never only a path.
- Give exact numbered in-game checks for every build, naming each look (Modern, Classic, Dark) and each client (Retail, Camelot) where it matters.
- Use measured numbers, never estimates, for memory, CPU and save size.
- Short asks want the thing: "PR?" means open it and give the link; "where release" wants the link.
- Re-read the newest message before building; the author may refine mid-flight ("wait hold").
- Study screenshots closely before guessing a fix, and ask which object a screenshot shows when `/fstack` cannot tell.
- When the author doesn't answer a fork, build on the recommended option and say so.
- Expect a code review pass before merging.

## How the author works
- **Simulate the WoW client while coding (the author, 2026-10-09).** Every change is exercised in the harness's simulated client (`tools/harness/wow_stub.lua` through `tools/harness/run.lua`) as it is written, not only at the end: (1) drive the path you changed: load the addon on a save (a real one for anything that touches data), fire the events, slash commands and clicks that reach the changed code, and read what it actually did (chat lines, the frame dump, the saved file) before going on; a pass line alone is not the observation. (2) Changed or new behaviour gets a harness check that fails on the old code (run it against `origin/main` to prove it). (3) The window is driven through `tui_tour.lua` and `tui_compare.sh` in all three looks, Camelot paths with `PSS_CAMELOT=1`, chat and unit paths with secret values (`check_secrets.lua`). (4) The PR and the handover say what was simulated and what a simulation cannot show (wrapped text, real combat and chat lockdown timing, taint, client art), and those go to the numbered in-game checks. (5) A subagent given a change is told this in its brief.
- **Claude runs every test before handover (2026-10-09).** The rules check, the full harness on the real saves from scratch `SavedVariables/`, the same-as-main or sparse-saves comparison and `tui_compare.sh` are run by Claude before a PR is handed over, and the results (counts, failures, anything skipped) are reported. CI (`rules.yml`) is a backstop, not a substitute: it cannot run the real saves, same-as-main or the look compare. The author never runs tests and does not want a tests bundle (2026-10-09): do not host one unless asked; the PR states what was run and the counts, and the test zip is the only download. A check that prints a NOTE and skips (for example `origin/main` unknown in a single-branch clone) is not a pass: fetch the ref and run it again.
- The author tests every build in game and does every merge. "Branch, PR and release" is approval to merge and verify the release.
- Production is explicit: a full release happens only when the author says the feature is done. Before a full release goes live, the author tests a very old save on the final pre-release.
- The author uploads WTF saves and names the version ("this is a 3.4.0.28 save"); file them on scratch under `SavedVariables/<version>/`.
- Build numbers stay consistent: every build, a release included, takes the next number, and later lines count on.
- The author reads the GitHub Releases directly. Release notes are one player-facing summary of every change since the previous release.
- **Every full release has its record on scratch (2026-10-09):** a release-notes md per release (`docs/latest/release-notes/<version>.md`, one for each release in `versions.json`) and its rows in one summary of changes (`docs/latest/summary-of-changes/SUMMARY_OF_CHANGES.md`), each change linked to its build, PR and technical notes. Release notes and technical notes stay in different folders. Only the author's full releases are releases: up to 2.0.17, 2.0.18, 2.0.19, 2.0.22, 2.0.40, 2.0.44, 3.0.0, 3.3.1, 3.4.0.29, 3.4.1.53, 3.4.2.54 (3.1.0 and 3.2.0 count as pre-releases of 3.3.1).
- **Release notes and technical notes are context for change and regression (2026-10-09).** Before changing behaviour, fixing a bug, checking for a regression or weighing a feature, read the summary of changes for that area and the release notes and technical notes it links, after the code map. Every full release updates them, with the code map, in the same delivery (`05_RELEASE.md`, Full releases).
- **Leftovers and waiting items become GitHub issues (2026-10-09):** one issue each, with a context md on scratch (`docs/latest/issues/` for work, `docs/latest/setup/` for setup jobs) whose text is also the issue body: what, why, the decision with a recommendation, the steps in order, in-game checks and reference links. The other docs only point to the issue.
- The author answers decision cards. An unanswered card means the recommended option, said so in the PR.

## Values
- **Performance and memory first:** zero cost until used, lazy UI, GC only at safe requested moments, nothing grows without a cap. Smaller saves and less resident memory are goals in themselves.
- **Upgrades are sacred.** Every save change gets the author's OK first, a validated migration on all the author's real saves, and identical counters. **Saves should never need readdressing again** (core uplift 2.3): forward compatible, unknown data kept, incompatible rules reported and exportable.
- **Lean on native tools, and build only what the stated goal needs:** Blizzard's APIs and the existing keys first, and a new mechanism (an ID generator, a library) only where it is measured to pay.
- **Human-readable output:** upgrade lines name features ("Chat Filtering", "SavedVariables performance cleanup"), not internals.
- **Native Blizzard look in Modern and Classic, and every element works in all three looks.** The EllesmereUI port is the reference for layout and feel; EllesmereUI is the reference framework for UI elements, read only.
- **Copy logic, never code or media,** from other addons, and respect licences.
- **TOC Title and Notes are the author's;** never change them unless asked.
- **Hover never opens a window.**
- **User systems must be intuitive (2026-10-08):** one action does the obvious whole thing; removing someone from one list removes them from every list they are on.
- **PSS is authoritative (2026-10-08):** PSS never acts through Blizzard's systems (its ignore list) unless the player asked for it for that person.
- **One plain merge flow:** one PR per step, based on main, never stacked.
- **Scratch never gets a PR (2026-10-09):** every scratch delivery is committed and pushed straight to scratch `main`, whatever branch the session names. PRs are for the addon repo only.
- **Every update says it happened (2026-10-09):** the upgrade report prints at the first login after any version change, even when nothing in the save changed, so the player always sees that an upgrade occurred (U2's behaviour; keep it). In-game checks expect it.
- **Ask before anything hard to undo:** save layout, deleting data, production releases.
