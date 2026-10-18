# The author's preferences and approach (the one file)

Purpose: everything about how the author works and what the author wants from Claude lives here (the author, 2026-10-08). `CLAUDE.md` loads it in every session. Other docs stay technical and close to the addon. Add new preferences here, dated, and never spread them across other files. Baseline 07 is the generic version; where they differ, this file wins.

**Build, test and release preferences** (`DEC-00387` a, the author, 2026-10-18): moved word for word to `docs/pss/17_BUILD_PREFERENCES.md`; read it in full before any build, test run, PR or release (route: `docs/pss/15_ROUTES.md#route-table`).

## Records, links and summaries (the author, 2026-10-09)
- **Every rule of this section lives word for word in the one home of the documentation rules** (`DEC-00339`, the author, 2026-10-18): scratch `documents/reference-framework/12_User_Guides/12_02_Documentation_Rules.md`, section 3 "From the author's preferences". Read it in full before writing any summary, temp README, document or record; `CLAUDE.md` keeps the rules that apply to every reply (`DEC-00067`, `DEC-00068`, `DEC-00070`).

## Sessions and context
- **One step per session (2026-10-08).** The author resets the session after each step of every implementation plan. Build only the named step, then stop.
- **Plans and designs are references (2026-10-08).** `CLAUDE.md` points to them and never copies them. At each full release, the done stages are re-summarized into `01_HANDOVER.md`, which describes how the addon works at that release, and leave the plan.

## Communication
- **Call the user "the author" (2026-10-09):** never by name, in replies, docs, PRs, commits and issues; in docs write "the author" ("the author's OK"), never a name and never gendered pronouns.
- **Response style (2026-10-09):** short, with no preamble and no recap of what was just done. Don't explain code changes unless the author asks. Don't repeat file contents back; reference line numbers (`file:line`).
- **File hosting (2026-10-09):** never host files in the Claude session; use the most relevant scratch folder (`summary/`, `releases/`, or `docs/latest/<topic>/`: `issues/`, `setup/`, `release-notes/`, `code-map/`, `pss-docs/`).
- Plain language, answer first, short; the author may read on the go.
- Numbered questions, each with a recommendation; the author answers by number ("1: yes 2: recommended").
- Always give links: scratch `raw` links for zips, `blob` links for docs, `tree` links for folders. Never only a path.
- Use measured numbers, never estimates, for memory, CPU and save size.
- Short asks want the thing: "PR?" means open it and give the link; "where release" wants the link.
- Re-read the newest message before building; the author may refine mid-flight ("wait hold").
- Study screenshots closely before guessing a fix, and ask which object a screenshot shows when `/fstack` cannot tell.
- When the author doesn't answer a fork, build on the recommended option and say so.

## How the author works
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

## Changelog
| Date | Reference | Change | Reason | Context |
| --- | --- | --- | --- | --- |
| 2026-10-18 | this file | lines 10 to 17, 27, 33 and 36 to 44 moved word for word to `docs/pss/17_BUILD_PREFERENCES.md`; pointer added under the opening line | `DEC-00387` a: preferences split | scratch `temp/2026/10/18/15-10-00-Sun-busy-fermi-qrk4qx/prompts/12.md`; before: 4470eea |
