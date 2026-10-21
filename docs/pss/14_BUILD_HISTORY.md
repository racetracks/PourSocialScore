# Build history (PourSocialScore)

Purpose: what each build changed and why, its PR, the tests run and the in-game checks, newest first; and every approved combined build (baseline E1 / E9). Written by `tools/bump_version.sh` through `tools/build_history.py` at every build ([`DEC-00341`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/00_Decisions.md#dec-00341)); never imported at session start.

## Contents
- [What this file is and why](#what-this-file-is-and-why)
- [How it is written](#how-it-is-written)
- [Combined builds](#combined-builds)
- [Builds](#builds)
- [Older history](#older-history)

## What this file is and why
| File | For | Holds |
| --- | --- | --- |
| `history.txt` | Players (ships in the zip) | Patch notes, one plain-words section per build |
| `versions.json` | The release workflow | Each version and its PR |
| **This file** | The author and every session | Per build: what changed and why, the PR, tests run, what the simulation cannot show, in-game checks; the approved combined builds |
| `06_STATUS_AND_NEXT.md` | Every session (imported) | The current build, what is next, what waits on the author |

Why: the record of each build belongs beside the code, but not in the files every session loads at start. `06_STATUS_AND_NEXT.md` grew to 67,759 bytes (about 15k tokens a session) before [PR #240](https://github.com/racetracks/PourSocialScore/pull/240) moved its history out; this file keeps it from growing back. Read it, after the code map, before changing behaviour, fixing a bug or checking a regression in an area (`CLAUDE.md`, Read when the task touches the topic).

## How it is written
1. `sh tools/bump_version.sh build "Title"` (and `release`, `line`) moves the current build entry of 06 "Now" here unchanged, then writes a stub for the new build in both files.
2. The PR fills this file's entry: what changed and why (files, functions), tests run with counts, what the simulation cannot show, in-game checks. 06 keeps one line.
3. `sh tools/bump_version.sh pr <number>` writes the PR into both.
4. `sh tools/check_rules.sh` runs `python3 tools/build_history.py check`: it fails when 06 "Now" holds more than one build entry, or when a version in `versions.json` from 3.8.0.119 on has no entry here.

## Combined builds
The approvals behind the E1 / E9 Overrides row of `02_RULES.md` section 12, moved here word for word from that table at 3.8.0.120. A new combined build adds its row here, with the author's OK, before it ships.

| Baseline rule | PSS instead |
| --- | --- |
| E1 / E9 One step per PR and per session | The warehouse stages L1 (shared item layer) and W2 (persisted bags) in one build, 3.7.0.107, each proven by its own check phases. The author, 2026-10-14, [`DEC-00231`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/warehouse-helper/00_Decisions.md#dec-00231) a |
| E1 / E9 One step per PR and per session | Several stages or issues in one PR and one build, each proven by its own check phases; that delivery only: the rest of the core uplift (S3, P1 to P6, W1 to W4) as 3.4.1.52 (per-stage notes `reference/combined-3.4.1.52/`); graphics settings stages 1 to 3 as 3.5.0.57; the addon manager's five stages as 3.6.0.64; issues #171 and #172 as 3.6.0.66; #175, #176, #177 as 3.6.0.68; #175, #176, #177, #180 and #181 (Enabled components) as 3.6.0.69; #189 and #183 as 3.6.0.75 (the author, 2026-10-10: resolve all in one attempt); #189 (`STP-00018`), #192 (`STP-00020`) and the #179 rework as 3.6.0.84 (built on a branch as 3.6.0.80 to .82; the author, 2026-10-10: "do `TST-00008`, `TST-00009`", then "pr it"); #201 and #203 as 3.6.0.87 (the author, 2026-10-10: "#201 with #203", `DEC-00075` b) ; #202 (3.6.0.88), the removal of CPU from the addon manager and the Dark tab label fade as 3.6.0.89, and the removal of all memory usage from the addon manager as 3.6.0.90 (the author, 2026-10-10: asked in the same session); the Addon Manager restructure (interface-helper, [`STP-00072`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/interface-helper/07_Roadmap.md#stp-00072) to [`STP-00077`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/interface-helper/07_Roadmap.md#stp-00077), issue #211) in one build as 3.6.0.91 ([`DEC-00088`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/interface-helper/04_High_Level_Design.md#dec-00088) c, the author, 2026-10-10); the service bus stage S1 ([`STP-00093`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00093), [`STP-00138`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00138), [`STP-00140`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00140)) in one build as 3.7.0.98 ([PR #216](https://github.com/racetracks/PourSocialScore/pull/216); the live plan builds them together; the author, 2026-10-11, the implementation roadmap S1); PSS Drop Cheapest Thing, stages 1 to 6 of [`IMP-00009`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/money-helper/07_Roadmap.md#imp-00009) (3.6.0.92 and 3.6.1.93; the author, 2026-10-10: "attempt to complete all of the implementation plan in one attempt"); the service bus stage S2 ([`STP-00094`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00094), [`STP-00139`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00139), [`STP-00147`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00147) and the S1 follow-ups [`STP-00143`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00143) to [`STP-00146`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/07_Roadmap.md#stp-00146)) in one build as 3.7.0.100 (the live plan builds them together; the author, 2026-10-11: [`DEC-00210`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/04_High_Level_Design.md#dec-00210) a, [`DEC-00203`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/service-bus-helper/00_Decisions.md#dec-00203) a, and the instruction to initiate S2 from the [project roadmap](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/11/10-13-00-Sun-awesome-allen-mxrrg4/project-roadmap-2/README.md)) |
| E1 / E9 One step per PR and per session | All of phase 2 of the Warehousing and Journaling roadmap (packages `STP-p00` to `STP-p19`: the item layer, the warehouse, money, search, import, the gateway and Syndicator shim, the interface) in one build, 3.7.0.106 (its in-game test fixes are 3.7.0.107 and 3.7.0.108, the same PR), each package proven by its own check phases and its own commit ([`DEC-00263`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/code-map/00_Decisions.md)). The author, 2026-10-16 |
| E1 / E9 One step per PR and per session | Phase A of the Spyglass, Journal and Bags roadmap ([`STP-00232`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00232) to [`STP-00252`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00252), [`STP-00285`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00285) to [`STP-00287`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_02_Phase_A_Spyglass_Engine.md#stp-00287)) in one build, 3.8.0.116, each component proven by its own check phases (`ix_phases.sh`) and its own commit. The author, 2026-10-17: one PR and one pre-release per phase ([`DEC-00320`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/00_Decisions.md#dec-00320) b) |
| E1 / E9 One step per PR and per session | Phase B of the Spyglass, Journal and Bags roadmap ([`STP-00253`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00253) to [`STP-00258`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00258), [`STP-00288`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00288), [`STP-00292`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/12_User_Guides/12_03_Phase_B_Spyglass_Console.md#stp-00292)) in one build, 3.8.0.125, each component proven by its own check phases (`console_phases.sh`) and its own commit. The author, 2026-10-17: one PR and one pre-release per phase ([`DEC-00320`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/features/search-helper/00_Decisions.md#dec-00320) b) |

## Builds
<!-- builds: newest first; tools/build_history.py roll writes here -->

### 3.8.0.132 - Spyglass fixes 2: time format, content-fit columns, time like on shown text

- Branch: `claude/nice-noether-m6eqsa`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: R1 (`CHK-00187`): time cells read like `21 Oct 2026 02:59` through `M.PSS_TIME_SHOW` in PSS_Bus.lua, so the year shows and the cell fits. R2 (`CHK-00174`): `M.PSS_TableWidths` sizes columns to their content (`need`), capped, with the message column getting the room; the chart measures its cells (PSS_ConsoleView.lua, PSS_Chart.lua); `colwidths` became `colfit`. R3 (`CHK-00178`): `time like` matches the text the cell shows (PSS_Psql.lua, PSS_Pred.lua `P.timeLike`), plus a help row (16 rows). Why: the author's 3.8.0.131 test (`CHK-00174`, `CHK-00178` failed).
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`; no code map entry changed.
- Tests run: `timeshow` and `colfit` pass and fail on 492e5b2; `timelike2` fails on 492e5b2 (12 lines) and passes; console 146 phases, 0 failed; IX 335 phases, 0 failed (one earlier run showed 1 failed, a rerun 0); console and IX mutants 40 of 41 killed (`con-cap-note` survives on the base too); `sh tools/check_rules.sh` run at close.
- Not shown by the simulation: real column widths with the client font, and the look in Modern, Classic and Dark.
- In-game checks (each in Modern, Classic and Dark):
  - `CHK-00172` (re-run, I1): Player Ignore List, select a player with lines, Event History. Expected: query (2 lines max), Run, Queries, Open in Spyglass and every column inside the pane; type boxes not covered.
  - `CHK-00174` (re-run, I4): Spyglass, Events. Expected: `summary` (or `message`) is the widest column; `ent`, `index` and `item` are narrow; time shows the year in full.
  - `CHK-00178` (re-run, I3): `index=log time like 21`, then `time like oct`, then `time like 2026`, then `owner like jeff`. Expected: rows whose time cell shows `21`; October rows; every 2026 row; rows of owners containing jeff.
  - `CHK-00187` (R1): Spyglass, Events; Player Ignore List Event History. Expected: every time cell reads like `21 Oct 2026 02:59` and fits its column.

### 3.8.0.131 (from 06 Now)

**3.8.0.131, Spyglass load fix: os is nil in the client (branch `claude/pensive-davinci-osy66a`, PR #242):** 3.8.0.130 failed at login (`os.date` in `PSS_Pred.lua`); fixed there and in `PSS_TimePicker.lua`, and the rules check now fails `os.` in addon code; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.131 - Spyglass load fix: os is nil in the client

- Branch: `claude/pensive-davinci-osy66a`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: 3.8.0.130 failed at login (the author, 2026-10-21): `PourSocialScore_Libraries/PSS_Pred.lua:25` read `os.date`, and the WoW client has no `os` table, so Libraries did not load. Now `date or os.date` ([PSS_Pred.lua:25](https://github.com/racetracks/PourSocialScore/blob/claude/nice-noether-m6eqsa/PourSocialScore_Libraries/PSS_Pred.lua?plain=1#L25)); the same fault at [PSS_TimePicker.lua:171](https://github.com/racetracks/PourSocialScore/blob/claude/nice-noether-m6eqsa/PourSocialScore_GUI/PSS_TimePicker.lua?plain=1#L171) (the date picker's "..." button) is fixed too. The harness has `os`, so it never saw it: [tools/check_style.lua](https://github.com/racetracks/PourSocialScore/blob/claude/nice-noether-m6eqsa/tools/check_style.lua) now fails any `os.` in an addon file that is not an `or os.x` fallback (it flags both lines on 3.8.0.130).
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`.
- Tests run: `sh tools/check_rules.sh` all passed (and fails on the 3.8.0.130 code); `ix_phases.sh` 333 phases, 0 failed; `console_phases.sh` 144 phases, 0 failed.
- Not shown by the simulation: loading in the client; the harness defines `os`.
- Test zip: [PourSocialScore-3.8.0.131-2026-10-20-15-52.zip](https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/releases/PourSocialScore-3.8.0.131-2026-10-20-15-52.zip).
- In-game checks: login with no Lua error, then the 3.8.0.130 list (`CHK-00172`, `CHK-00173`, `CHK-00174`, `CHK-00178`, `CHK-00185`) on the 3.8.0.131 zip, each in Modern, Classic and Dark.

### 3.8.0.130 (from 06 Now)

**3.8.0.130, Spyglass fixes (branch `pensive-davinci-osy66a`, PR #242):** B1 `like` on time; B1a to B1c alerts fire on blocked world-chat lines; E1 query view resizes with the window; E2 Events starts blank; E3 column widths by content; segcost gate (S1): best of 15 runs, Append us min/median/max Retail 2.48/2.525/2.67, Camelot 2.48/2.575/2.76 against gate 5 (`agents/A07/REPORT.md`); known survivor from before this build: mutant `con-cap-note`; details in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.130 - Spyglass fixes: like on time, alerts on blocked lines, console layout

- Branch: `pensive-davinci-osy66a`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why:
  - B1 (I3): `<known field> like <value>` parses to a like node with an implicit `*`; `like` on `t` matches the time stamp (`PSS_Psql.lua` atom, `PSS_Pred.lua`); phases `timelike`, `likeword`.
  - B1a, B1c (I5): `History.Add` (`PourSocialScore/PSS_ChatHistory.lua`) puts each kept line into the log index (`M.PSS_IxPut`, gated on `PSS_On("logging")`) so alerts see blocked world-chat lines; phase `alertblock` added fail-first.
  - E1 (I1): query view, chart, history pane and dropdown resize with the window (`PSS_QueryView.lua`, `PSS_Chart.lua`, `PSS_History.lua`); phases `qvresize`, `panefit`.
  - E2 (I2): Events starts blank until a search is run (`M.PSS_CON_BLANK`, `PSS_Console.lua`, `PSS_ConsoleView.lua`); phase `conblank`.
  - E3 (I4): table column widths by content (`M.PSS_TableWidths`, `TIME_W`, `COL_MIN`, `PSS_Chart.lua` DRAW.table); phase `colwidths`.
  - S1: segcost run count 5 to 15 (`tools/harness/check_ix.lua:358`), gate untouched.
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`.
- Tests run: `ix_phases.sh` IX 333 phases, 0 failed; `console_phases.sh` CONSOLE 144 phases, 0 failed; segcost gate (S1): Append us min/median/max Retail 2.48/2.525/2.67, Camelot 2.48/2.575/2.76 against gate 5; `console_mutants.sh` known survivor from before this build: `con-cap-note` (phase `concap` skips when the save is under the cap; on head 68e1685, not fixed here).
- Test zip: [PourSocialScore-3.8.0.130-2026-10-20-15-39.zip](https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/releases/PourSocialScore-3.8.0.130-2026-10-20-15-39.zip).
- Not shown by the simulation: alerts on a live realm's world chat; wrapped text and real window resizing; client art.
- In-game checks (each in Modern, Classic and Dark): `CHK-00172` (I1), `CHK-00173` (I2, with CHK-00146 step 3 rewritten), `CHK-00174` (I4), `CHK-00178` (I3 like), `CHK-00185` (I5, CHK-00150 step 5a); steps in `specs/layout.md#9-acceptance-tests` and `specs/fields.md#94-mutants-real-saves-in-game`.

### 3.8.0.129 - Phase B brought up to date with main

- Branch: `claude/nice-noether-m6eqsa` (also pushed to `claude/epic-wozniak-2r69ur`); [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: `main` (3.8.0.128, [PR #249](https://github.com/racetracks/PourSocialScore/pull/249)) merged into the 3.8.0.127 phase B branch, which was out of date and conflicted (TOCs, `history.txt`, `versions.json`, 06, this file); addon code unchanged from 3.8.0.127, so its in-game checks carry over; the Spyglass pre-release moves up one to 3.8.0.130 (02 section 8, expected builds).
- Docs updated: `docs/pss/06_STATUS_AND_NEXT.md`, this file, `history.txt`, `versions.json`; scratch roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`).
- Tests run: (written in the PR)
- Not shown by the simulation: nothing new; code as 3.8.0.127.
- In-game checks: the 3.8.0.127 list in the PR, on the 3.8.0.129 zip; the upgrade report prints the version change.

### 3.8.0.129 (from 06 Now)

**3.8.0.129, phase B brought up to date with main (PR #242):** `main` (3.8.0.128) merged into the 3.8.0.127 branch; code unchanged from 3.8.0.127; details in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.128 - Docs: scratch temp folders moved into dated folders

- Branch: `ccr-11709e26-ej241j`; [PR #249](https://github.com/racetracks/PourSocialScore/pull/249).
- What changed and why: the scratch `temp/` flat roots (60 entries, before 2026-10-15) moved into `temp/<YYYY>/<MM>/<DD>/<hh-mm-ss>-<Ddd>-<name>/` (`DEC-00397`, the author 2026-10-19); old paths map to new in `scratch:temp/MOVED.md`. Here: the 9 links in this file and `docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md` repointed, `docs/scratch/03_LAYOUT.md` names `temp/MOVED.md`; header lines added to 06 and 03 (`check_context.py` SHAPE). PR #242 holds 3.8.0.125 to 3.8.0.127, so its planned pre-release moves up one to 3.8.0.129. No addon code changes.
- Also (the author, 2026-10-19, scratch [prompt 02](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/19/11-01-05-Mon-ccr-61c16dad-f40mr0/prompts/02.md)): the next-session handoff (`DEC-00398`). `CLAUDE.md` (Every session) makes every session read `scratch:.next/NEXT.md` at start and, at every delivery, write `.next/NEXT.md` in its temp root and copy it over the scratch root copy; format and caps in `scratch:.next/README.md#format`. `docs/scratch/03_LAYOUT.md` and `05_RULES.md` (rule 16) name the folder. Scratch `link_keys.py` no longer strips the dot of `.next/`. Enforced (scratch [prompt 05](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/19/11-01-05-Mon-ccr-61c16dad-f40mr0/prompts/05.md)): `.claude/scripts/next_handoff.py` is the SessionStart hook (`.claude/settings.json`) that prints the root handoff and the other sessions' handoffs of the last 24 h, and its `check` (run by `check_context.py` with no arguments, outside CI) fails a missing or misshapen handoff; the format gains `## Parallel`; scratch `CLAUDE.md` rule 16 removed (it repeated this rule at every start).
- Docs updated: `docs/pss/06_STATUS_AND_NEXT.md`, this file, `docs/scratch/03_LAYOUT.md`, `docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md`, `history.txt`., `CLAUDE.md`, `docs/scratch/05_RULES.md`, `docs/linked/`, `.claude/scripts/check_context.py` (usage text)
- Tests run: `check_rules.sh` pass; `check_context.py` clean; `validate_all.sh` with the 15 real saves: 971 PASS then aborts at line 388, identical on `origin/main` (973 PASS, same abort) because the clone was shallow; issue #248. The full re-run after `--unshallow` was stopped on the author's word. `tui_compare.sh` and same-as-main not run (no addon file changed).
- Not shown by the simulation: nothing; docs only.
- In-game checks: 1. Install the 3.8.0.128 zip, log in: the upgrade report prints the version change; nothing else differs from 3.8.0.124.

### 3.8.0.127 - Spyglass search fixes

- Branch: `claude/nice-noether-m6eqsa`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: G2 console fits its page; G3 System searches fill in the selected player or item (never a $); G4 only valid searches run; G5 What PSS did is now Items PSS sold or dropped; G8 the status names the 2000-line history cap (the save holds up to the cap plus 5 % slack, `History.Trim` at `PourSocialScore/PSS_ChatHistory.lua:619` cuts it to the cap on load; note added at `PourSocialScore_Libraries/PSS_ConsoleView.lua:97`); G9 Events shows dates and blank cells; rules 9 to 13 of 02 section 1 (D89). Why: the author's 3.8.0.126 in-game results and the Z02 data validation.
- Mutants: six mutants added (34 in total).
- conpipe and savebroken repointed after the pg.run guard (mutants con-bar-raw, save-broken-runs).
- Harness: phases `consize`, `consysq`, `concell` added (fail on 3.8.0.126 code) and `console_phases.sh` REAL gains `consysq concell concap`.
- G2 page size: `ns.PAGE_W`, `ns.PAGE_H` (`PourSocialScore_GUI/PSS_Window.lua:37`) size the console page (`PourSocialScore_GUI/PSS_Console.lua:19`), results height `PourSocialScore_GUI/PSS_Console.lua:23`, `pg.layout` at `PourSocialScore_GUI/PSS_Console.lua:373`.
- G3 parameters: `M.PSS_ResolveQuery`, `M.PSS_QUERY_SOURCES`, `M.PSS_UNBOUND_TEXT` (`PourSocialScore_Libraries/PSS_ConsoleView.lua:583`) fill `$owner` and `$item` before the bar; `Ctx` and `Pick` (`PourSocialScore_GUI/PSS_Console.lua:219`) use them; `ns.SelectedPlayer` (`PourSocialScore_GUI/PSS_Players.lua:25`).
- G4 valid queries: `pg.run` resolves `$`, skips a parse error (`PourSocialScore_GUI/PSS_Console.lua:229`); `pg.pick` exported (`:395`).
- G5 rename: What PSS did is Items PSS sold or dropped (`PourSocialScore_Libraries/PSS_SQ.lua:39`).
- G9 cells: `M.PSS_CellText` (`PourSocialScore_Libraries/PSS_Bus.lua:67`) used at `PourSocialScore_GUI/PSS_Chart.lua:377`.
- Docs updated: `docs/pss/02_RULES.md`, `docs/pss/06_STATUS_AND_NEXT.md`; code pointers of this section: `PourSocialScore_GUI/PSS_Window.lua`, `PourSocialScore_GUI/PSS_Console.lua`, `PourSocialScore_Libraries/PSS_SQ.lua`, `PourSocialScore_Libraries/PSS_Bus.lua`, `PourSocialScore_GUI/PSS_Chart.lua`.
- Ran: rules check rc=0; validate_all 1643 PASS, 1 FAIL (the segcost timing gate, 5.21 us over 5.0; 5.12 and 5.34 on a re-run; 5.13 and 5.15 on ec6cd9a, so a machine-speed gate not caused by this build), 0 SKIP (16 real saves); console_phases 256 phases, 0 failed; console_mutants 34 of 34 killed; data re-validation on 3.8.0.126: 10 compared, 0 mismatched, 5 recorded

### 3.8.0.126 - Spyglass console fixes

- Branch: `claude/nice-noether-m6eqsa`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why (moved from 06 "Now"): **3.8.0.126, Spyglass console fixes** (same branch, PR #242): fixes the failed checks `CHK-00146` to `CHK-00150` and `CHK-00170` of 3.8.0.125 (typed pipe, invisible bar text (plain text now, D74), left list clip and scroll, status text, pie slices of All); charts re-checked only. **Its in-game results led to the fix build 3.8.0.127.** Ran: rules check rc=0; validate_all 1563 PASS, 0 FAIL, 0 SKIP (14 real saves); console_phases 198 phases, 0 failed; console_mutants 28 of 28 killed; tui_compare vs 8a67167 only the intended diffs (search bar text plain and shown, overlay gone, status timing); conchartpick 2 phases, 0 failed. In-game: `CHK-00146` to `CHK-00150` and `CHK-00170`, each in Modern, Classic and Dark; `/pss q bar` output on open is evidence for F2.
- What changed and why: F1 typed pipe no longer read as two; F2 search bar shows plain text (D74), overlay dropped; F3 left list clipped and scrolls; F4 one Load history; F5 pie slices of All open their rows; F6 charts re-checked only. Why: the author's in-game results of 3.8.0.125 (`CHK-00146` to `CHK-00150`, `CHK-00170`).
- F1: `CV.unpipe`/`CV.pipe` at `PourSocialScore_Libraries/PSS_ConsoleView.lua:264`; `BarText`/`SetBar` at `PourSocialScore_GUI/PSS_Console.lua:30`.
- F2: plain-text bar and `Highlight` at `PourSocialScore_GUI/PSS_Console.lua:60`; `ns.ConsoleBarRaw` at `:371`; `/pss q bar` at `PourSocialScore_Libraries/PSS_IxExport.lua:204`.
- F3: clip and wheel scroll at `PourSocialScore_GUI/PSS_Nav.lua:105`.
- F4: status text at `PourSocialScore_Libraries/PSS_ConsoleView.lua:98`.
- F5: `.all` rows `PourSocialScore_Libraries/PSS_ConsoleView.lua:478`; no-id and `nothing selected` in `M.PSS_DeepDiveText` at `:516`; bar shows `vm:Text()` in `pg.deepDive` at `PourSocialScore_GUI/PSS_Console.lua:343`.
- In-game check note: `/pss q bar` prints `bar raw: ...` (the raw bar text, pipes doubled); record whether the client stores `|` or `||`.
- Docs updated: `docs/pss/02_RULES.md` (11 rule 12 retired), `docs/pss/06_STATUS_AND_NEXT.md`, this entry, `history.txt`.
- Ran: rules check rc=0; validate_all 1563 PASS, 0 FAIL, 0 SKIP (14 real saves); console_phases 198 phases, 0 failed; console_mutants 28 of 28 killed; tui_compare vs 8a67167 only the intended diffs (search bar text plain and shown, overlay gone, status timing); conchartpick 2 phases, 0 failed

### 3.8.0.125 - Spyglass console

- Branch: `claude/nice-noether-m6eqsa`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why (moved from 06 "Now"): **3.8.0.125, Spyglass phase B, the console** (branch `claude/nice-noether-m6eqsa`, [PR #242](https://github.com/racetracks/PourSocialScore/pull/242); [session temp root](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/10/18/13-08-00-Sun-nice-noether-m6eqsa/README.md)): the Spyglass tab with a colour-coded search bar, time picker, charts, the save dialog (searches, charts and alerts), the Data dictionary page, View Events and the pane histories through Spyglass; the Events tab is retired. Ran: rules check passed; `validate_all.sh` 1529 PASS / 0 FAIL; `console_phases.sh` 164 phases, 0 failed; `console_mutants.sh` 25 of 25 killed; `ix_phases.sh` 327 phases and the bus gate 7 phases, 0 failed; `tui_compare.sh` differs from `origin/main` as intended (the new tab). Sizes (KB): `PSS_Chart.lua` 40.99, `PSS_QueryView.lua` 10.71, `PSS_TimePicker.lua` 29.77, `PSS_Console.lua` 40.95, `PSS_QueryDialog.lua` 24.03, `PSS_ConsoleView.lua` 59.29. Not shown by the simulation: fonts, wrapped text, overlay alignment on the real edit box, client art, hover feel. In-game: `CHK-00146` to `CHK-00150`, each in Modern, Classic and Dark. **Next: the Spyglass release 3.8.0.127 (a pre-release).** Details in `docs/pss/14_BUILD_HISTORY.md`.
- Docs updated: `docs/pss/06_STATUS_AND_NEXT.md`, `docs/pss/02_RULES.md`, `docs/pss/15_ROUTES.md`, `docs/pss/09_PSS_UI_PROJECT.md`, `docs/pss/07_HARNESS.md`, this entry, `history.txt`; renumbered .121 to .125 and the release .122 to .126 after the merge of main.
- Tests run: (written in the PR)
- Not shown by the simulation: (written in the PR)
- In-game checks: (written in the PR)

## Older history
- 3.8.0.119 to 3.8.0.124: [`reference/14_build-history-3.8.0.119-to-3.8.0.124.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.119-to-3.8.0.124.md)
- 3.6.0.69 to 3.8.0.118: [`reference/06_status-history-3.6.0.69-to-3.8.0.118.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md)
- To 3.4.1.30: [`reference/06_status-history-to-3.4.1.30.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-to-3.4.1.30.md); the combined 3.4.1.52 notes: `reference/combined-3.4.1.52/`
- Every build: `history.txt` and `versions.json`

## Changelog
| Date | Reference | Change |
| --- | --- | --- |
| 2026-10-20 | REF-15-00-00-Tue-pensive-davinci-osy66a-A11 | entries 3.8.0.119 to 3.8.0.124 moved word for word to `reference/14_build-history-3.8.0.119-to-3.8.0.124.md` (size cap) |
