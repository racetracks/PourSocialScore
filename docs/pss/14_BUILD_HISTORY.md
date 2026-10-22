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

### 3.8.0.135 - Spyglass fields: Fields panel, raw column names, chat-filter names

- Branch: `claude/serene-bell-sdez3f`; PR #253.
- What changed and why: author results: `CHK-00190` to `CHK-00193` and `CHK-00195` to `CHK-00198` passed 2026-10-22; asks O1 to O3 answered (`DEC-00368`, `DEC-00369`). F135b (`PSS_Fields.lua`, `PSS_Psql.lua`, `PSS_Plan.lua`): chat-filter names as virtual fields `filter`, `sender`, `server` (`Q.VIRTUAL`, built per row only when named), no spaces in field names; the base had no virtual registry, so a minimal one was added. F135a (`PSS_ConsoleView.lua`): `CM:Fields` model, raw names in row detail and summary. F135c (`PSS_Console.lua`, `PSS_Chart.lua`): Fields panel opened by `>>` (heading click, Alt+click, value click, tooltips, `+N more`), raw column headers with tooltips. F135d: dead `CM:Sidebar` and `SKIPCOL` removed, two mutants repaired. Why: readable fields that match the query language.
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`.
- Tests run: `ix_phases.sh` 343 phases, 0 failed, plus `names filterdesc nospace` 6 pass (Retail and Camelot); `console_phases.sh` 182 phases, 0 failed; `ix_mutants.sh` 3 killed (`filter-pattern`, `virtual-text-field`, `name-spaces-allowed`); `console_mutants.sh` `fields-cap-8`, `header-label`, `detail-secret-shown`, `detail-raw-label` killed; `tui_compare.sh` vs origin/main: window differs (42 normalised lines, raw-name rows), not split per look; full run at 6383d98 with `PSS_SCRATCH` set and 15 real saves: `validate_all.sh` 1758 PASS, 0 FAIL, 0 SKIP; `ix_mutants.sh` 146 killed; `wh_mutants.sh` 76 killed; `console_mutants.sh` 58 of 58 killed after `label-raw` was repointed (header tooltip title, assertion added to `rawheaders`); `check_rules.sh` clean.
- Not shown by the simulation: client font widths, the three looks, tooltips and clicks in the client.
- In-game checks (each in Modern, Classic and Dark):
  - `CHK-00204`: Spyglass > System > Events; click `>>` at the right of the Results row. Expected: the panel reads `Fields` and lists every column with a count (`owner  12`); click `member`: five names with counts and percents; click one name: the bar ends `member="<that name>"` and the results narrow to that player; Alt+click `cat`: the bar ends `| table cat`; /reload and open Spyglass: Fields is closed.
  - `CHK-00205`: Spyglass > System > Events; hover the `owner` header; click a row. Expected: headers read raw names (`time`, `cat`, `owner`, `message`); the tooltip shows `Blocked by`; Event Details lists raw names and raw values, with the readable text dimmed beside values that read differently.
  - `CHK-00206`: Spyglass, bar `index=log owner="f:*"`, open Fields, click `filter`. Expected: your chat filters' names (as in Options > Chat Filters), not their patterns; click one: the bar gains `filter="<name>"` and only that filter's blocks remain.

### 3.8.0.134 (from 06 Now)

**3.8.0.134, Spyglass pane fix and layout: one list per pane, top bar, collapsible panels, wider Message (branch `claude/nice-noether-m6eqsa`, PR #242):** rows S1, L134a, L134b: stale pane rows purged, search bar always on row 1, side panels collapsible (right closed by default), Message column at least 40 % wide, Edit search removed; replaces `CHK-00176` with `CHK-00195` to `CHK-00198`; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.134 - Spyglass pane fix and layout: one list per pane, top bar, collapsible panels, wider Message

- Branch: `claude/nice-noether-m6eqsa`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: author results for 3.8.0.133: `CHK-00188` PASS ("too small", so L134 replaces E5); `CHK-00189` PASS (reported as `CHK-00187`); `CHK-00190` to `CHK-00193` not reported, kept waiting. S1 (`PSS_Chart.lua`): list frames tracked at creation, stale ones purged, `Draw` under `pcall` (defensive: `paneswitch` did not reproduce on the base, `paneerror` did; proof is in game). L134a (`PSS_Console.lua`): search bar, time picker, Run, Save and `?` always on row 1; side panels 180 wide, collapsible, right closed by default; Edit search removed (reverses `DEC-00404`); R4 moved to the full-window roadmap. L134b (`PSS_ConsoleView.lua`): `FILL_SHARE`, Message at least 40 % of the table width. Open: mutant `detail-secret-shown` is INVALID (edit changes nothing; pre-existing, outside the fence).
- Docs updated: this file; `docs/pss/reference/14_build-history-3.8.0.125-to-3.8.0.129.md` (new, 3.8.0.125 to .129 moved here); `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`.
- Tests run: `console_phases.sh` 170 phases, 0 failed; `validate_all.sh` with 15 real saves and the IX phases pass except the timing phases `segcost`, `budgetcalls` and `lazycost`, which fail identically on base f02140e (container speed, rerun 3 times); `console_mutants.sh` 56 of 58 killed (survivors: `con-cap-note`, known; `detail-secret-shown`, INVALID); `check_rules.sh` rc 0; `tui_compare.sh` vs f02140e: only Spyglass sections change, same in all three looks.
- Not shown by the simulation: client font widths, the three looks, the stale rows in the client.
- In-game checks (each in Modern, Classic and Dark):
  - `CHK-00195`: Options > Optional Features > Event Logging on; Player Ignore List > click a player in the list > Event History > Queries > Blocks by type; then Queries > the first query; then Blocks by type again. Expected: one header row each time; no old header or old line shows under the new ones.
  - `CHK-00196`: Spyglass > System > Events. Expected: the search box runs across the top with the time range, Run, Save and `?` beside it and holds the search; no Edit search button.
  - `CHK-00197`: Spyglass; click `>>` at the right of the Results row; then `<<` at its left; then /reload and open Spyglass. Expected: Top values opens as wide as the list on the left, same top and bottom; the left list hides and results widen; after /reload the left list is open and Top values closed.
  - `CHK-00198`: Spyglass > System > Events, Top values closed. Expected: the Message column shows about 45 characters of each line before it is cut.

### 3.8.0.133 - Spyglass readable reports: labels, report columns, summary header, Top values, row detail

- Branch: `claude/nice-noether-m6eqsa`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: the author's 3.8.0.132 test showed raw fields, 12 columns and a raw search in reports. B3a: `PourSocialScore_Libraries/PSS_Fields.lua` (new) gives `M.PSS_FieldLabel`, the event and index labels and the display rules; `M.PSS_CellText` takes the column kind (`PSS_Bus.lua`). U2: `M.PSS_ReportCols` and `M.PSS_REPORT_COLS` pick 6 columns (4 in the pane, `log.pane`), `M.PSS_TableWidths` keeps the `keep` columns whole, the chart draws labels (`PSS_ConsoleView.lua`, `PSS_Chart.lua`, `PSS_History.lua`). U3: `M.PSS_QuerySummary` header (`Events of <player> · newest 200 · <range>`), Edit search, status `<n> lines` (`PSS_Console.lua`, `PSS_QueryView.lua`). U4: Top values with label headings, no one-value columns, `No common values`. E6: row detail box `ns.RowDetail` (`PSS_Popups.lua`, `CM:RowDetail`). Check keys: `CHK-00172`, `CHK-00174`, `CHK-00177` and `CHK-00187` are replaced by `CHK-00188` to `CHK-00193` (`specs/plan.md#6-in-game-checks`); `CHK-00178` passed on 3.8.0.132.
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`; code map: scratch `documents/code-map/16_Registries/16_02_Export_Registry.md` and `documents/code-map/09_Current_Features.md`.
- Tests run: `validate_all.sh` with real saves 1734 passed, 0 failed (409 skipped); `console_phases.sh` 329 phases, 0 failed; `ix_phases.sh` 493 phases, 0 failed; `console_mutants.sh` 53 of 53 killed; `ix_mutants.sh` 143 of 143 killed; segcost append 3.57 us Retail, 3.53 us Camelot (best of 15, gate 5); `sh tools/check_rules.sh` rc 0 (after the secret-order operand swap at PSS_ConsoleView.lua:442 and PSS_Fields.lua:207).
- Not shown by the simulation: real column widths with the client font, the look in Modern, Classic and Dark, and Escape closing only the copy box (`CHK-00193`).
- In-game checks (each in Modern, Classic and Dark):
  - `CHK-00188`: Spyglass > System > Events. Expected: headers Time, From, Type, Channel, Blocked by, Message; no cell shows `CHAT_MSG_`, `p:` or `chat.block`; no empty column.
  - `CHK-00189`: Options > Optional Features > Event Logging on; Spyglass > System > Events; then Player Ignore List > click a player in the list > Event History. Expected: every time cell reads like `21 Oct 2026 02:59` in full; only Message is cut, and hovering a row shows the whole message.
  - `CHK-00190`: Options > Optional Features > Event Logging on; Player Ignore List > click a player in the list > Event History. Expected: columns Time, Type, Channel, Message, all inside the pane (Channel only when a line has a channel name); the line above shows `newest 200`, not a search.
  - `CHK-00191`: Options > Optional Features > Event Logging on; Player Ignore List > click a player in the list > Event History > Open in Spyglass; then Edit search; then Back: Player Ignore List. Expected: header reads `Events of <player> · newest 200 · <range>`, no search text, no From or Blocked by column; Edit search shows the search; Back returns to the pane.
  - `CHK-00192`: Spyglass > System > Events; look at Top values. Expected: headings are words (Type, Channel), values readable, no heading whose one value covers every line; when no value repeats, the panel reads `No common values`.
  - `CHK-00193`: Spyglass > System > Events; left click a row; Copy All; Escape. Expected: "Event Details" lists every field by label with readable values; the copy box holds the raw line; Escape closes the box only.

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

### 3.8.0.131 - Spyglass load fix: os is nil in the client

- Branch: `claude/pensive-davinci-osy66a`; [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: 3.8.0.130 failed at login (the author, 2026-10-21): `PourSocialScore_Libraries/PSS_Pred.lua:25` read `os.date`, and the WoW client has no `os` table, so Libraries did not load. Now `date or os.date` ([PSS_Pred.lua:25](https://github.com/racetracks/PourSocialScore/blob/claude/nice-noether-m6eqsa/PourSocialScore_Libraries/PSS_Pred.lua?plain=1#L25)); the same fault at [PSS_TimePicker.lua:171](https://github.com/racetracks/PourSocialScore/blob/claude/nice-noether-m6eqsa/PourSocialScore_GUI/PSS_TimePicker.lua?plain=1#L171) (the date picker's "..." button) is fixed too. The harness has `os`, so it never saw it: [tools/check_style.lua](https://github.com/racetracks/PourSocialScore/blob/claude/nice-noether-m6eqsa/tools/check_style.lua) now fails any `os.` in an addon file that is not an `or os.x` fallback (it flags both lines on 3.8.0.130).
- Docs updated: this file; `docs/pss/06_STATUS_AND_NEXT.md`; `history.txt`; `versions.json`.
- Tests run: `sh tools/check_rules.sh` all passed (and fails on the 3.8.0.130 code); `ix_phases.sh` 333 phases, 0 failed; `console_phases.sh` 144 phases, 0 failed.
- Not shown by the simulation: loading in the client; the harness defines `os`.
- Test zip: [PourSocialScore-3.8.0.131-2026-10-20-15-52.zip](https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/releases/PourSocialScore-3.8.0.131-2026-10-20-15-52.zip).
- In-game checks: login with no Lua error, then the 3.8.0.130 list (`CHK-00172`, `CHK-00173`, `CHK-00174`, `CHK-00178`, `CHK-00185`) on the 3.8.0.131 zip, each in Modern, Classic and Dark.

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

## Older history
- 3.8.0.125 to 3.8.0.129: [`reference/14_build-history-3.8.0.125-to-3.8.0.129.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.125-to-3.8.0.129.md)
- 3.8.0.119 to 3.8.0.124: [`reference/14_build-history-3.8.0.119-to-3.8.0.124.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.119-to-3.8.0.124.md)
- 3.6.0.69 to 3.8.0.118: [`reference/06_status-history-3.6.0.69-to-3.8.0.118.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md)
- To 3.4.1.30: [`reference/06_status-history-to-3.4.1.30.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-to-3.4.1.30.md); the combined 3.4.1.52 notes: `reference/combined-3.4.1.52/`
- Every build: `history.txt` and `versions.json`

## Changelog
| Date | Reference | Change |
| --- | --- | --- |
| 2026-10-20 | REF-15-00-00-Tue-pensive-davinci-osy66a-A11 | entries 3.8.0.119 to 3.8.0.124 moved word for word to `reference/14_build-history-3.8.0.119-to-3.8.0.124.md` (size cap) |
