# Build history, 3.8.0.145 to 3.8.0.149

Purpose: the entries of 3.8.0.145 to 3.8.0.149 of `14_BUILD_HISTORY.md`, moved here word for word at 3.9.0.154 to keep that file under its size cap · owner coordinator · status read only · related docs/pss/14_BUILD_HISTORY.md

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
