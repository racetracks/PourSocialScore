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
| E1 / E9 One step per PR and per session | The Macro Helper Priest set, 3.8.0.146, added to the Shaman set's PR #270 (3.8.0.145) as its own build and commit, each proven by its own `check_macro.lua` phase. The author, 2026-11-10, this session (scratch `temp/2026/11/10/09-04-54-Tue-tender-knuth-moxuz4/prompts/02.md`): "Same PR #270" |
| E1 / E9 One step per PR and per session | The Shaman Stormstrike macro, 3.8.0.147, added to PR #270 (3.8.0.145, 3.8.0.146) as its own build and commit. The author, 2026-11-10, this session (scratch `temp/2026/11/10/09-04-54-Tue-tender-knuth-moxuz4/prompts/03.md`): "Same PR #270" |
| E1 / E9 One step per PR and per session | The red real-saves job ([issue #268](https://github.com/racetracks/PourSocialScore/issues/268)) in one build, 3.8.0.150: cards 1, 2, 3 and 5, each proven by its own check. The author, 2026-11-10, approved the cards for one build (scratch [prompt 05](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/14-52-09-Tue-great-sagan-6nl0he/prompts/05.md)) |

## Builds
<!-- builds: newest first; tools/build_history.py roll writes here -->

### 3.8.0.150 - Real-saves job fixes

- Branch: `claude/dazzling-gates-kgpqlm`; PR: none yet.
- What changed and why: the red real-saves job ([issue #268](https://github.com/racetracks/PourSocialScore/issues/268)) had causes in the checks, not the addon. [`check_real.lua`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/check_real.lua) counts the Camelot name repair (card 1); [`ix_phases.sh`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/ix_phases.sh) reruns a failing timing phase alone (card 5); [`check_guilds.lua`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/check_guilds.lua) opens the default list before reading its dim (card 2: the window was right, the check read a closed list); [`check_console.lua`](https://github.com/racetracks/PourSocialScore/blob/claude/dazzling-gates-kgpqlm/tools/harness/check_console.lua) concap counts the log, the keep and the outbox, as `index=log` does (card 3: the log was at its cap; the trim-at-write fix was dropped, it cost 13.5 to 256 us per blocked line). No addon code changed. Card 4 (planreal on tbc/3.8.0.142 and tbc/3.8.0.143) stays red, to the search speed build.
- Docs updated: `docs/pss/07_HARNESS.md`, `docs/pss/harness/01_COMMANDS.md`, `docs/pss/harness/02_PHASES.md`, `history.txt`, this entry, `docs/pss/06_STATUS_AND_NEXT.md`.
- Tests run: `check_real.lua` on the five oldest Forever saves (2.0.44, 3.0.0, 3.2.0-dev011, 3.4.0.28, 3.4.1.50): 0 FAIL (285 before; the step 10 re-key and the shipped-member merge count as kept); `check_guilds.lua` fresh and on every Forever save: 0 FAIL, the G26 dim read with the list open; `check_console.lua` phase `concap` on every real save: 0 FAIL; `PSS_RETIME_TEST=1 sh tools/harness/ix_phases.sh segcost budgetcalls`: rc 0, 6 `re-run passed`; `check_context.py` on the split harness docs rc 0, 0 lines lost; `build_history.py check` rc 0; stage close `validate_all.sh` with the real saves (`git fetch --depth=2000 origin main` first): only the two carried planreal FAILs, tbc/3.8.0.142 6.09 ms and tbc/3.8.0.143 5.30 ms per 2,000 lines against the 4.9 ms gate (card 1, to the search speed build).
- Not shown by the simulation: the G26 dim in the real window when a list's rule is switched on from Chat Filters (in-game `CHK-00254`, in Modern, Classic and Dark); timing on the author's machine, since the harness gates measure the test host only.
- In-game checks: [`CHK-00254`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/documents/reference-framework/16_Registries/REGISTRY.md#chk-00254): on a save with a Managed Communities list whose rule is off, open the Guilds tab and expand that list (its rows are dim); on the Chat Filters tab switch that list's rule on; back on the Guilds tab its rows show at full brightness at once; in Modern, Classic and Dark.

### 3.8.0.149 (from 06 Now)

**3.8.0.149, Global macros (branch `claude/great-pascal-ja1q5e`, PR #273):** Macro Helper `global` set gains Face, RaidGroup, Focus, TarFocus, HolyWater (issue #160 of umbrella #159), data and its harness phases only; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.149 - Global macros

- Branch: `claude/great-pascal-ja1q5e`; [PR #273](https://github.com/racetracks/PourSocialScore/pull/273).
- What changed and why: the author asked for five global macros (issue #160, umbrella #159; one build per ask). `PSS_MacroData.lua` `global` gains Face (icon 132202), RaidGroup (134400, left out), Focus (132089), TarFocus (132094) and HolyWater (134400, left out), bodies as pasted, store `account` (the set's). The author named the last one `HW`, which the shaman set already uses (a global name is unique across every set); the author chose `HolyWater` (2026-11-10, this session). RaidGroup is kept as written (the author, 2026-11-10), though the convert and leave run before the invite is accepted. The memory phase now subtracts what the stub allocates for its own macro records (`stub.macroKB`, `wow_stub.lua`; the client keeps macros outside Lua): 10 creates measured 16.16 KB with 3.78 KB of it the stub's, over the 16 KB budget; the budget stays 16 KB for the addon's own garbage (the author, 2026-11-10, this session). No addon code path changed.
- Docs updated: `history.txt`, `docs/pss/06_STATUS_AND_NEXT.md`, this entry; scratch `docs/latest/issues/macro-sets/160-global.md`.
- Tests run: `check_macro.lua` phases `data` and `global` (the five new macros) fail on 3.8.0.148 and pass here; `existing`, `full`, `dynicon`, `wrongclass`, `list`, `memory` updated to 10 global macros; every macro phase passes; the rules check; `validate_all.sh` with the real saves and `PSS_SAME_AS=origin/main` (issue #268). Measured: `PSS_MacroData.lua` resident 2.74 KB (2.41 KB before); `/pss macro global create` garbage 12.17 KB (stub 3.78 KB not counted).
- Not shown by the simulation: the raid marks in /say, the invite, convert and leave, the focus commands, the Holy Water use and its tooltip icon, the icons on a bar.
- In-game checks: in the PR (Forever): `/pss macro` lists `global (10)`; preview 10, 5 `new`; create, the account tab of `/macro`, icons; run again `already current 10`. Passed (the author, 2026-11-11).

### 3.8.0.148 (from 06 Now)

**3.8.0.148, Communities: the managed community logic moves into the Communities addon (branch `claude/pss-managed-communities-build-a-nf0alx`, PR #271):** the managed community logic now loads with the Communities addon; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.148 - Communities: the managed community logic moves into the Communities addon

- Branch: `claude/pss-managed-communities-build-a-nf0alx`; [PR #271](https://github.com/racetracks/PourSocialScore/pull/271).
- What changed and why: the managed community logic moves into the Communities addon, behind the seam [`DEC-00443`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/08-14-00-Tue-epic-turing-wqqpmr/projects/managed-communities/specs/managed-communities.md#dec-00443) (`M.PSS_GuildCore` and `M.PSS_Community`); build A of three ([`DEC-00444`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/08-14-00-Tue-epic-turing-wqqpmr/projects/managed-communities/specs/managed-communities.md#dec-00444)). Nothing changes in what is blocked.
- Docs updated: `docs/pss/07_HARNESS.md:41`, this file and `docs/pss/06_STATUS_AND_NEXT.md:1`.
- Tests run: [`TST-01000`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/08-14-00-Tue-epic-turing-wqqpmr/projects/managed-communities/specs/managed-communities.md#tst-01000), [`TST-01001`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/08-14-00-Tue-epic-turing-wqqpmr/projects/managed-communities/specs/managed-communities.md#tst-01001).
- Not shown by the simulation: the in-game load of the Communities addon.
- In-game checks: [`CHK-00245`](https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/temp/2026/11/10/08-14-00-Tue-epic-turing-wqqpmr/projects/managed-communities/specs/managed-communities.md#chk-00245).

### 3.8.0.147 (from 06 Now)

**3.8.0.147, Shaman Stormstrike macro (branch `claude/tender-knuth-moxuz4`, PR #270, with 3.8.0.145 and 3.8.0.146):** `SS` added to the `shaman` set (issue #168); class sets may share a name (the author, 2026-11-10); 3.8.0.146 added the `priest` set (issue #166), 3.8.0.145 the `shaman` set; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.147 - Shaman Stormstrike macro

- Branch: `claude/tender-knuth-moxuz4`; PR #270 (with 3.8.0.145 and 3.8.0.146; combined build row above).
- What changed and why: the author asked for a Shaman `SS` (Stormstrike). `SS` is also the Warrior's Shield Slam; the author, 2026-11-10: "its a shaman macro, it's unique to shaman, SS in warrior context means shield slam and in shaman context means stormstrike". So names are unique within a set, and a global name across every set; two class sets may share one (each is created only on its class, in its character store). Only the data check enforced the old rule; no code path changed.
- Docs updated: `history.txt`, `docs/pss/06_STATUS_AND_NEXT.md`, this entry and the combined build row, the comment in `PSS_MacroData.lua`; scratch `docs/latest/macro-helper/01_DESIGN.md` (name rule), `docs/latest/issues/macro-sets/159-umbrella.md` (step 1), `168-shaman.md`.
- Tests run: `check_macro.lua` `data` (5 shaman macros, SS body; the name rule now per set plus global names, a mutant reusing `Trinket 1` in a class set fails it) and `shaman` (created 5, `already current 5`) fail on 3.8.0.146 and pass here; the rules check; `validate_all.sh` with the real saves and `PSS_SAME_AS=origin/main` (issue #268).
- Not shown by the simulation: the Stormstrike cast and auto attack, the icon on a bar.
- In-game checks: in PR #270: on a Shaman, create gives 5 with `SS` casting Stormstrike; on a Warrior, `SS` stays Shield Slam.

### 3.8.0.146 (from 06 Now)

**3.8.0.146, Priest macros (branch `claude/tender-knuth-moxuz4`, PR #270, with 3.8.0.145):** Macro Helper `priest` set (13 macros; issue #166 of umbrella #159), data and its harness phase only; 3.8.0.145 added the `shaman` set (issue #168); the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.146 - Priest macros

- Branch: `claude/tender-knuth-moxuz4`; PR #270 (with 3.8.0.145; combined build row above).
- What changed and why: the author asked for the Priest macros (issue #166, umbrella #159). `PSS_MacroData.lua` gains a `priest` set, store `character` (the class default): PWS, RN, Dispel, FH, H, GH, PoM, AD, Fort, DS, SP, PI, MS, bodies as pasted. The author pasted two macros named `GH`; the author chose to name the Heal one `H` (2026-11-10, this session). No code path changed.
- Docs updated: `history.txt`, `docs/pss/06_STATUS_AND_NEXT.md`, this entry and the combined build row; scratch `docs/latest/issues/macro-sets/166-priest.md`.
- Tests run: `check_macro.lua` phase `priest` (new, `PSS_CLASS=PRIEST`) and the priest rows of `data`, `wrongclass`, `list` fail on 3.8.0.145 and pass here; the rules check; `validate_all.sh` with the real saves and `PSS_SAME_AS=origin/main`, compared with main (issue #268). `PSS_MacroData.lua` resident 2.37 KB.
- Not shown by the simulation: whether the client knows each spell (Prayer of Mending and Shadow Word: Death are later-expansion spells on some clients), the mouseover casts, the Shift buffs, the icons on a bar.
- In-game checks: in PR #270 (Forever, on a Priest): `/pss macro` lists `priest (13)`; preview 13 `new` (character); create, character tab, icons; run again `already current 13`; on another class: refused.

### 3.8.0.145 (from 06 Now)

**3.8.0.145, Shaman macros (branch `claude/tender-knuth-moxuz4`, PR #270):** Macro Helper `shaman` set (HW, LHW, CH, RT; issue #168 of umbrella #159), data and its harness phase only; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.145 - Shaman macros

- Branch: `claude/tender-knuth-moxuz4`; [PR #270](https://github.com/racetracks/PourSocialScore/pull/270).
- What changed and why: the author asked for four Shaman macros (issue #168, umbrella #159; one build per ask). `PSS_MacroData.lua` gains a `shaman` set, store `character` (the class default; the author named none): `HW`, `LHW`, `CH`, `RT`, each `#showtooltip <spell>` then `/cast [help, target=mouseover,exists,help,nodead][]<spell>`, as pasted. No code path changed.
- Docs updated: `history.txt`, `docs/pss/06_STATUS_AND_NEXT.md`, this entry; scratch `docs/latest/issues/macro-sets/168-shaman.md`.
- Tests run: `check_macro.lua` phase `shaman` (new, `PSS_CLASS=SHAMAN`) and the shaman rows of `data`, `wrongclass`, `list` fail on `origin/main` and pass here; the rules check; `validate_all.sh` with the real saves and `PSS_SAME_AS=origin/main`, compared with main (issue #268 keeps real-saves red on both).
- Not shown by the simulation: whether the client knows each spell (Riptide is a later-expansion spell; an unknown spell shows the question mark and does nothing), the mouseover cast, the icon on a bar.
- In-game checks: issue #168's five (Forever, on a Shaman): `/pss macro` lists `shaman (4)`; preview shows 4 `new` (character); create, the character tab of `/macro`, icons follow the spells; run again: `already current 4`; on another class: refused.

### 3.8.0.144 (from 06 Now)

**3.8.0.144, Search speed (branch `claude/upbeat-fermat-481m3i`, PR #269):** search timing harness only; the freeze (F-1) is not reproduced in the harness; in game one press of `f` froze 32 s (the author, 2026-11-10), the in-game `CHK-00232` quick `f` run finds where; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.144 - Search speed

- Branch: `claude/upbeat-fermat-481m3i`; PR #269.
- What changed and why: (written in the PR)
- Docs updated: `docs/pss/07_HARNESS.md`, `docs/pss/reference/07_harness-search.md`, `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md`
- Tests run: (written in the PR)
- Not shown by the simulation: (written in the PR)
- In-game checks: (written in the PR)

### 3.8.0.144 (from 06 Now)

**3.8.0.144, search timing harness only (branch `claude/upbeat-fermat-481m3i`, [PR #267](https://github.com/racetracks/PourSocialScore/pull/267) open):** the freeze (F-1, `CHK-00230`) was not reproduced by the harness; waits on the author's in-game `CHK-00232`; details in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.143 (from 06 Now)

**3.8.0.143, Fix: /pss version checks all six folders (branch `claude/clever-fermat-uesj4v`, PR #266):** `/pss version` checks all six folders and adds a save record line; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.144 - Search timing harness (no fix)

- Branch: `claude/upbeat-fermat-481m3i`; [PR #267](https://github.com/racetracks/PourSocialScore/pull/267).
- What changed and why:
  - Harness only, no addon code: [bench_search.lua](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-fermat-481m3i/tools/harness/bench_search.lua) (`TERM` and `TYPED` timing, cold item cache seed), [search_results.lua](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-fermat-481m3i/tools/harness/search_results.lua) (result dump) and [search_same.sh](https://github.com/racetracks/PourSocialScore/blob/claude/upbeat-fermat-481m3i/tools/harness/search_same.sh) (same rows as a reference, then timing, `REPRO yes|no`); detail in [07_harness-search.md](reference/07_harness-search.md). Commits d37b1a6, 88d4356, e402f90.
  - Why: F-1, the freeze the author reported (`CHK-00230`: search freezes the game up to 10 s on TBC and Forever).
  - Result: not reproduced (`REPRO no`) in 3 harness runs. Largest `TERM` max_ms 4.850 and largest `TYPED` max_ms 4.697 (both TBC 3.8.0.139 save), against the 200 ms threshold; Forever saves stay under 1 ms.
  - The fix builds (Q02 to Q04) are deferred until a freeze is reproduced.
- Docs updated: `docs/pss/07_HARNESS.md:65-67`, `docs/pss/reference/07_harness-search.md:1-16`, `docs/pss/14_BUILD_HISTORY.md:42`, `docs/pss/06_STATUS_AND_NEXT.md:1`, `docs/pss/06_STATUS_AND_NEXT.md:8`, `docs/pss/06_STATUS_AND_NEXT.md:11`.
- Not shown by the simulation: the in-game freeze (the harness item-request queue fills only as the addon requests ids).
- In-game checks: `CHK-00232` (the author runs it in game).

### 3.8.0.143 - Fix: /pss version checks all six folders

- Branch: `claude/clever-fermat-uesj4v`; [PR #266](https://github.com/racetracks/PourSocialScore/pull/266).
- What changed and why:
  - `DEC-00440`: `/pss version` checks all six folders and adds a save record line (save last upgraded by another version).
  - `DEC-00441`: flavour loops, section.
  - `DEC-00442`: not built.
- Docs updated: `docs/pss/07_HARNESS.md:41`, `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md:1`.
- Tests run: `TST-00998`, `TST-00999`.
- Not shown by the simulation: a real stale folder reporting its own TOC version.
- In-game checks: `CHK-00244`, `CHK-00235` at 3.8.0.143.

### 3.8.0.142 (from 06 Now)

**3.8.0.142, Fix: TBC tabs, Forever wording, version proof (branch `claude/forever-rerun-142`, PR #265):** F-3 Forever wording, F-2 TBC tab art, F-5 `/pss version`, 10 macros; the details are in the build history (`docs/pss/14_BUILD_HISTORY.md`).

### 3.8.0.142 - Fix: TBC tabs, Forever wording, version proof

- Branch: `claude/forever-rerun-142`; [PR #265](https://github.com/racetracks/PourSocialScore/pull/265).
- What changed and why:
  - F-3 (`DEC-00436`): player text says Forever, not Camelot (commands, Options note, gfx tip, upgrade line).
  - F-2 (`DEC-00435`): TBC tab art spans the whole tab label, selected and not (3.8.0.141 regression).
  - F-5 (`DEC-00437`): `/pss version` proves which version the client loaded.
  - F-1 (search freeze) moved to the search speed build, 3.8.0.143 (`DEC-00438`).
  - The 10 macros (`DEC-00439`): 3 global and 7 warrior macros.
- Docs updated: `docs/pss/16_INTERFACE.md`, `docs/pss/07_HARNESS.md`, `docs/pss/14_BUILD_HISTORY.md`, `docs/pss/06_STATUS_AND_NEXT.md`.
- Tests run: `TST-00991` to `TST-00997`; real-save run (`build_saves.sh` lists `forever 3.8.0.139-forever-launch`, `validate_all.sh` with `PSS_REAL_SAVES`).
  - Step 2 result: real saves: 288 FAIL, identical to main cd64591 (pre-existing, follow-up issue). Duplicate stub (#262): one 3.8.0.142 entry in history.txt and in this file.
- Not shown by the simulation: the TBC tab look, the Forever client loading this version, the macros' icons and casts.
- In-game checks: `CHK-00235` to `CHK-00243`, re-runs `CHK-00218` to `CHK-00220`, `CHK-00229`.

## Older history
- 3.8.0.138 to 3.8.0.141: [`reference/14_build-history-3.8.0.138-to-3.8.0.141.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.138-to-3.8.0.141.md)
- 3.8.0.133 to 3.8.0.137: [`reference/14_build-history-3.8.0.133-to-3.8.0.137.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.133-to-3.8.0.137.md)
- 3.8.0.130 to 3.8.0.132: [`reference/14_build-history-3.8.0.130-to-3.8.0.132.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.130-to-3.8.0.132.md)
- 3.8.0.125 to 3.8.0.129: [`reference/14_build-history-3.8.0.125-to-3.8.0.129.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.125-to-3.8.0.129.md)
- 3.8.0.119 to 3.8.0.124: [`reference/14_build-history-3.8.0.119-to-3.8.0.124.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/14_build-history-3.8.0.119-to-3.8.0.124.md)
- 3.6.0.69 to 3.8.0.118: [`reference/06_status-history-3.6.0.69-to-3.8.0.118.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-3.6.0.69-to-3.8.0.118.md)
- To 3.4.1.30: [`reference/06_status-history-to-3.4.1.30.md`](https://github.com/racetracks/PourSocialScore/blob/main/docs/pss/reference/06_status-history-to-3.4.1.30.md); the combined 3.4.1.52 notes: `reference/combined-3.4.1.52/`
- Every build: `history.txt` and `versions.json`

## Changelog
| Date | Reference | Change |
| --- | --- | --- |
| 2026-10-20 | REF-15-00-00-Tue-pensive-davinci-osy66a-A11 | entries 3.8.0.119 to 3.8.0.124 moved word for word to `reference/14_build-history-3.8.0.119-to-3.8.0.124.md` (size cap) |
| 2026-10-29 | REF-00-27-50-Thu-ccr-0503e1ee-d9m6t2-A09 | entries 3.8.0.133 to 3.8.0.137 moved word for word to `reference/14_build-history-3.8.0.133-to-3.8.0.137.md` (size cap) |
| 2026-11-10 | 3.8.0.149, branch claude/great-pascal-ja1q5e | entries 3.8.0.138 to 3.8.0.141 moved word for word to `reference/14_build-history-3.8.0.138-to-3.8.0.141.md` (size cap) |
