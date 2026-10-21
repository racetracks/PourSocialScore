# Build history, 3.8.0.125 to 3.8.0.129

Purpose: the entries of 3.8.0.125 to 3.8.0.129 of `14_BUILD_HISTORY.md`, moved here word for word at 3.8.0.134 to keep that file under its size cap · owner coordinator · status read only · related docs/pss/14_BUILD_HISTORY.md

## Builds
### 3.8.0.129 - Phase B brought up to date with main

- Branch: `claude/nice-noether-m6eqsa` (also pushed to `claude/epic-wozniak-2r69ur`); [PR #242](https://github.com/racetracks/PourSocialScore/pull/242).
- What changed and why: `main` (3.8.0.128, [PR #249](https://github.com/racetracks/PourSocialScore/pull/249)) merged into the 3.8.0.127 phase B branch, which was out of date and conflicted (TOCs, `history.txt`, `versions.json`, 06, this file); addon code unchanged from 3.8.0.127, so its in-game checks carry over; the Spyglass pre-release moves up one to 3.8.0.130 (02 section 8, expected builds).
- Docs updated: `docs/pss/06_STATUS_AND_NEXT.md`, this file, `history.txt`, `versions.json`; scratch roadmap Next Steps (`scratch:documents/code-map/Roadmaps/In_Progress/Spyglass_Journal_Bags/Readme.md#2-next-steps`).
- Tests run: (written in the PR)
- Not shown by the simulation: nothing new; code as 3.8.0.127.
- In-game checks: the 3.8.0.127 list in the PR, on the 3.8.0.129 zip; the upgrade report prints the version change.

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
