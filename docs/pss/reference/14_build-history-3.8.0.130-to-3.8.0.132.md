# Build history, 3.8.0.130 to 3.8.0.132

Purpose: the entries of 3.8.0.130 to 3.8.0.132 of `14_BUILD_HISTORY.md`, moved here word for word at 3.8.0.138 to keep that file under its size cap · owner coordinator · status read only · related docs/pss/14_BUILD_HISTORY.md

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
