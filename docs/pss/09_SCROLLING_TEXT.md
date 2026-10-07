# Scrolling Battle Text in PSS: design (2026-10-07)

Status: **design, decisions answered** (section 6); stage 0 partly done, the combat log question is open (section 9). Nothing is built. Version line: **3.4.0**.

Source studied: Mik's Scrolling Battle Text (MSBT) 6.0.3, uploaded by Dan (Interface 11504, 40400, 110002; readme 5.7.148, author Mikord). Dan, 2026-10-07: "write our own code with our own standards, port what makes sense". So MSBT is read for behaviour; PSS writes its own code to PSS rules. No MSBT code is copied (baseline 02 H4). Dan, 2026-10-07: "i hold the license" for MSBT's bundled fonts and sounds, so those files may ship (decision 13).

## 1. Goal
**WoW Forever (Camelot, Interface 16001) only. Not Retail.** Scrolling Battle Text (SBT) behaves as MSBT did: incoming and outgoing damage, misses and heals, power gains, auras, kills, notifications (loot, money, currency, XP, reputation, honor, skill, combat enter/leave), triggers and cooldown alerts, in scroll areas around the character with MSBT's animation styles. Off until the player turns it on (C2); once on, MSBT's default behaviour.

## 2. What exists in MSBT
| Part | File (source size) | What it does | On Forever |
| --- | --- | --- | --- |
| Root | MikSBT.lua (8 KB) | Global `MikSBT`, slash `/msbt`, helpers | Rewrite on `M`; no new global |
| Profiles | MSBTProfiles.lua (117 KB) | Defaults, profiles, 3 global SavedVariables, sets the Blizzard floating combat text CVars at first load, calls Blizzard `CombatText_UpdateDisplayedMessages` | Defaults rewritten as one table; settings in `PSS_OptionsDB`; no automatic CVar writes (J2, J4) |
| Parser | MSBTParser.lua (42 KB) | `COMBAT_LOG_EVENT_UNFILTERED` plus `CHAT_MSG_*` global-string searches, unit and class maps | Rewrite in Libraries **if Forever delivers CLEU**: stage 0 saw no CLEU in `/etrace` (section 9) |
| Main | MSBTMain.lua (68 KB) | Formats events, merges and throttles bursts, power gains, combo points | Rewrite in Libraries |
| Animations | MSBTAnimations.lua (26 KB) | Scroll areas, font strings, one OnUpdate frame for every moving line | Rewrite: frames in the SBT folder, AnimationGroups where they fit (C3) |
| Animation styles | MSBTAnimationStyles.lua (40 KB) | Straight, Parabola, Static, Pow, Angled, Horizontal | Path maths in Libraries, drawing in the SBT folder |
| Triggers | MSBTTriggers.lua (41 KB) | Rules on CLEU, health and power thresholds (low health, low mana, procs) | Rewrite in Libraries |
| Cooldowns | MSBTCooldowns.lua (21 KB) | "Cooldown ready": OnUpdate polling plus `hooksecurefunc` on `UseAction`, `UseInventoryItem`, `C_Container.UseContainerItem`, `C_Item.UseItemByName` | Rewrite in Libraries, from cooldown events, no hooks (decision 15) |
| Loot | MSBTLoot.lua (8 KB) | Loot, currency and money from `CHAT_MSG_*` | Rewrite in Libraries |
| Media | MSBTMedia.lua, 11 TTF fonts, 3 OGG sounds, LibStub, CallbackHandler, LibSharedMedia | Custom fonts and sounds | The 11 fonts and 3 sounds ship (Dan holds the licence) in `PourSocialScore_Libraries/Media/`, listed by a path table in Libraries; Blizzard fonts also offered. No LibStub or LibSharedMedia (A10) |
| Options | MSBTOptions folder (~10 k lines, 924 KB with art) | Its own options window | A Scrolling Battle Text group in PSS options (native and EllesmereUI) plus a settings window in the native look and one in the EllesmereUI look |
| Locales | de, fr, it, kr, ru, zhcn, zhtw | UTF-8 strings | English first; others later as ASCII escapes (A2) |

MSBT engine source: 379 KB of Lua, plus 844 KB of fonts and sounds. Compiled size and resident memory were not measured (no Lua 5.1 in this session); every stage PR measures what it adds.

## 3. What has to change from MSBT
1. **Placement**: none of it is chat filtering, so it cannot run from core (PSS 02 section 5). Logic goes in `PourSocialScore_Libraries`, drawing in its own UI folder.
2. **Blizzard state**: no automatic `SetCVar` on the floating combat text CVars, no calls into Blizzard's combat text Lua (J2, J4).
3. **Globals and libraries**: none of `MikSBT`, its SavedVariables globals, named frames, LibStub or LibSharedMedia (A6, A10).
4. **OnUpdate**: three OnUpdate frames; replaced by AnimationGroups and event-driven timers where they fit (C3).
5. **Retail**: none of it may load or register anything on Retail (CLEU is forbidden there, J8).
6. **Secret values**: stage 0 found `issecretvalue` on Forever, so Forever has the secret value system. Every combat, chat and unit value goes through `M.PSS_IsSecret` (PSS 02 section 10); a secret value is shown, never compared, added or indexed. Which values are secret in combat on Forever is checked in stage 0b.

## 4. Options considered
| # | Option | Verdict |
| --- | --- | --- |
| A | Bundle MSBT as a PSS folder, patched | Rejected: libraries, globals, CVar writes, licence |
| B | **New PSS code on MSBT's behaviour** | **Chosen** (Dan, 2026-10-07) |
| C | Notifications only | Not needed: Forever allows the combat parts |
| D | Do not integrate | Not what Dan asked |

## 5. Design
### Folders
| Folder | Holds | Loads |
| --- | --- | --- |
| `PourSocialScore` (core) | `/pss sbt` (the always-listening `/pss` slash, Dan's choice), the `sbtEnabled` option row in a new "Scrolling Battle Text" options group, the start at login when on, part key `ScrollingBattleText` in `M.PSS_PARTS` with `NEEDS.ScrollingBattleText = "Libraries"` | Always |
| `PourSocialScore_Libraries` | Every SBT function: `PSS_SBTEngine.lua` (start/stop, CLEU and event registration, parser, formatting, merge and throttle), `PSS_SBTTriggers.lua` (triggers, cooldowns), `PSS_SBTSettings.lua` (defaults, read and write of the saved settings, firing `M.Events`), `PSS_SBTPaths.lua` (style path maths) | On demand; at login when SBT is on |
| `PourSocialScore_Options` | The settings, in `PSS_OptionsDB` (Dan, 2026-10-07) | Always (unchanged) |
| **`PourSocialScore_ScrollingBattleText`** (new) | The UI only: frame pool, scroll area frames, animations, the unlock/move overlay, the native-look SBT settings window. No logic (PSS 02 section 6) | On demand, only on Forever and only when SBT is on |
| `PourSocialScore_EllesmereUI` | The SBT settings window in EllesmereUI's look (4-space style), drawn from the same settings definitions and saved through the same Libraries setters. It never loads a file from the SBT folder, and the SBT folder never loads one from it (PSS 02 section 6) | As today |

- The SBT folder's TOCs: a base TOC and a `_Camelot` TOC, both with `## AllowLoadGameType: camelot` and `## LoadOnDemand: 1`, `## Dependencies: PourSocialScore_Libraries`; no `_Mainline` TOC. Title `|cff69ccf0PourSocialScore|r Scrolling Battle Text`, `## Category: PSS`, `## Group: PourSocialScore`, the PSS icon, the same version as every TOC. Stage 0 confirms Retail neither lists nor loads it. The release zip already packs every `PourSocialScore_*` folder.
- The Libraries files load on Retail too (Libraries is shared), so each SBT start checks `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (guarded for nil, B6) and does nothing otherwise; the harness asserts that Retail never registers CLEU.
- On Retail the SBT option rows and group are not added to `M.PSS_OPTIONS`, so both PSS windows show nothing new and need no change; `/pss sbt` says it is for WoW Forever only.
- Libraries TOC Notes stay as they are (Dan, 2026-10-07); only file lines are added.
- Both PSS windows already draw their options from `M.PSS_OPTIONS` and `M.PSS_OPTION_SECTIONS`, so the new group appears in the native and the EllesmereUI windows with no UI code; the two SBT settings windows read one definitions table in Libraries (G5).
- **Media** (fonts, sounds) lives in Libraries, not in either UI folder, because both front ends use it (G4): the scrolling text draws with the fonts, both settings windows preview them.

### Zero cost when off
`sbtEnabled` defaults off. Off: core holds only the option row, the slash branch and the login check; Libraries and the SBT folder are not loaded for it; no events, no frames. On: Libraries and the SBT folder load at login and stay loaded; frames are built on the first line shown (C5). Resident costs measured from stage 1.

### Behaviour once on
MSBT's default settings, rewritten as PSS's defaults table: the same scroll areas (Incoming, Outgoing, Notification, Static), the same events on, the same colours, crits sticky, merging and throttling as MSBT did them. MSBT's own fonts and sounds ship with it (decision 13).

### Settings
One nested table, `PSS_OptionsDB.sbt`, holding only values that differ from the defaults (D3), so it stays small and bounded (fixed keys; custom triggers capped). The master switch `sbtEnabled` is a normal `M.PSS_OPTIONS` row so the PSS options window shows it. A new key only; no existing key changes, so no migration; every stage that adds settings is run against the real saves.

### Options group
A "Scrolling Battle Text" group in the PSS options (Forever only; native and EllesmereUI) holding: Enable Scrolling Battle Text; Open SBT settings (the settings window of whichever front end is in use); a line saying Blizzard's own combat text is under Options, Combat and can be turned off there (decision 11). PSS never changes Blizzard's combat text settings.

### Animations
AnimationGroups (Translation, Alpha, Scale) for Straight, Static, Pow, Horizontal; a `Path` animation for Parabola and Angled (stage 0: Forever has `Path`). No OnUpdate for the scrolling text.

### Commands (core)
`/pss sbt` (toggle on/off), `/pss sbt test` (one line per area), `/pss sbt unlock` (move areas), `/pss sbt config` (settings window).

### Bonus source
PSS's own `PLAYER_BLOCKED` event as a notification line ("Blocked: Name"), off by default, since MSBT had no such line.

## 6. Decisions
Answered by Dan, 2026-10-07:
1. Scope: **B**. Forever only, not Retail.
2. The UI is its own folder, `PourSocialScore_ScrollingBattleText`; every function in Libraries; settings in `PSS_OptionsDB` (Options folder); commands in core as `/pss sbt`.
3. Version line **3.4.0**, reached through `3.4.0-devNNN` pre-releases (section 7).
4. Write our own code to our own standards; port what makes sense.
5. Leave Blizzard's floating combat text alone; a Scrolling Battle Text group in options.
6. Once on, behave as MSBT did (its defaults).
7. and 8. Incoming and outgoing combat: yes (subject to stage 0b).
9. Triggers and cooldowns: park only if not possible (subject to stage 0b).
10. Settings as one `PSS_OptionsDB.sbt` table of non-defaults: yes.
11. Blizzard combat text: a line in the group saying where Blizzard's setting is; PSS never writes it ("yes" to the recommended option).
12. MSBT still installed: "dont care". No detection code; the readme says to disable MSBT.
13. Dan holds the licence for MSBT's fonts and sounds: they ship, in Libraries.
14. EllesmereUI runs on Forever: **EllesmereUI components are mandatory**. Every SBT setting and window has an EllesmereUI version.
15. Cooldown alerts from cooldown events, no hooks: yes.

## 7. Path to 3.4.0
- Every merged stage PR sets the next `3.4.0-devNNN` in every TOC; merging publishes a GitHub **pre-release** (the pipeline marks any version with `-` as one). Each PR also hosts a test zip on scratch (`PourSocialScore/test-builds/PourSocialScore-3.4.0-devNNN.zip`) with numbered in-game checks for Forever.
- Retail users who install a dev build get no change: the SBT folder does not load there, and the option group is absent. Each PR still runs the Retail look-compares to prove it.
- A Retail or Forever bug found in the meantime ships as the next devNNN on the 3.4.0 line (baseline 02 F4), its own PR, never folded into a stage.
- When every stage has passed on Forever, a PR sets plain `3.4.0` with a history section for the feature; merging it publishes the full release. Only when Dan says it is done.

## 8. Stages (one PR each, based on main, never stacked)
| Stage | Version | Change | Visible | Validation |
| --- | --- | --- | --- | --- |
| 0 | none | In-game checks on Forever (section 9) | No | Done except 0b |
| 1 | 3.4.0-dev001 | Groundwork: core `/pss sbt`, `sbtEnabled` and the options group (Forever only; both windows), part key and NEEDS; Libraries `PSS_SBTEngine.lua` with start/stop only; the new folder with its two TOCs and an empty file | Option only (Forever) | Option off: nothing loads, no events; Retail: no rows, folder never loads; resident cost of core lines measured; `ui_compare.sh` and `eui_compare.sh` identical on Retail |
| 2 | 3.4.0-dev002 | Data: `PSS_SBTSettings.lua`, MSBT-equivalent defaults, the `sbt` table, the settings definitions table both settings windows will read, Libraries setters firing `M.Events`; media in `PourSocialScore_Libraries/Media/` with its path table | No | Real saves validated; save size measured; zip size measured |
| 3 | 3.4.0-dev003 | Display: frame pool, the four scroll areas, Straight and Static styles, MSBT's fonts, `/pss sbt test` | Yes | Pool reuse, no frames before first line; memory and CPU per line measured |
| 4 | 3.4.0-dev004 | Combat, incoming and outgoing, from the source stage 0b finds (CLEU, or `UNIT_COMBAT` display only); school colours; crits with Pow | Yes | Harness event stub; Retail never registers CLEU; secret values shown, never compared |
| 5 | 3.4.0-dev005 | Merge and throttle (readable values only), power gains, combo points, auras gained and faded, kills, environmental, interrupts, dispels, as far as stage 0b allows | Yes | Merge counts match the raw lines in the harness |
| 6 | 3.4.0-dev006 | Notifications: loot, money, currency, XP, reputation, honor, skill, combat enter/leave, PSS blocked (off) | Yes | Secret check on every chat value; restriction CVar runs |
| 7 | 3.4.0-dev007 | Parabola, Angled, Horizontal styles (Path animations); `/pss sbt unlock` | Yes | No OnUpdate; cost per curved line measured |
| 8 | 3.4.0-dev008 | Native SBT settings window (areas, events, colours, fonts, sounds) in the SBT folder; "Open SBT settings" | Yes | Every setting saves and reloads; only non-defaults saved |
| 9 | 3.4.0-dev009 | EllesmereUI SBT settings window, same settings, EllesmereUI look; "Open SBT settings" opens it under EllesmereUI | Yes | Same settings both sides (a harness check like `check_match.lua`); `eui_compare.sh` on unchanged pages; skin on and off |
| 10 | 3.4.0-dev010 | Triggers: MSBT's default triggers (low health, low mana, procs), custom triggers, MSBT's sounds | Yes | Trigger cap; secret values never compared (a trigger on a secret value does not fire) |
| 11 | 3.4.0-dev011 | Cooldown-ready alerts from cooldown events | Yes | No OnUpdate polling; timers only while a cooldown runs |
| 12 | 3.4.0-dev012 | Fixes from testing, readme (disable MSBT), locale escapes | Yes | Full regression |
| Release | 3.4.0 | Version and history only | | Dan confirms done |

Stages 4, 5, 10 and 11 depend on stage 0b and shrink or drop to a later line if Forever withholds the data. Stages 1, 2, 3, 6, 7, 8 and 9 do not depend on it. If a stage grows while building, it is split and Dan is told first.

## 9. Stage 0: in-game checks on Forever
Results from Dan, 2026-10-07:
1. `WOW_PROJECT_ID` = 18, `WOW_PROJECT_CAMELOT` = 18, interface 16001. Detection works.
2. `issecretvalue` exists: Forever has the secret value system.
3. `/etrace` showed **no** `COMBAT_LOG_EVENT_UNFILTERED` while fighting. If the combat log is gone on Forever as on Retail 12.x, MSBT's parser cannot be ported as is.
4. `enableFloatingCombatText` = "1", `floatingCombatTextCombatDamage` = "1": the CVars exist (read only; PSS does not write them).
5. `Path` animations exist.

**Stage 0b** (open; decides stages 4, 5, 10, 11). Each line on Forever, in a fight:
1. `/dump CombatLogGetCurrentEventInfo ~= nil, C_EventUtils and C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")`
2. `/run local f=CreateFrame("Frame") f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") f:SetScript("OnEvent",function() print("CLEU ok") f:UnregisterAllEvents() end)` then hit a mob: "CLEU ok", an "action forbidden" message, or nothing?
3. `/run local f=CreateFrame("Frame") f:RegisterUnitEvent("UNIT_COMBAT","player","target") f:SetScript("OnEvent",function(_,_,u,a,_,n) print(u,a,issecretvalue(n) and "SECRET" or n) end)` then fight: are amounts numbers or SECRET, and do your hits on the target show?
4. With a target, in combat: `/run print(issecretvalue(UnitHealth("player")), issecretvalue(UnitPower("player")))`
5. With a spell on cooldown, in combat: `/run local c=C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(61304) print(c and issecretvalue(c.duration))`

On **Retail**: after stage 1's test zip, the AddOns list shows no Scrolling Battle Text entry and `/pss sbt` says Forever only.

## 10. Risks
- With SBT on, all of Libraries stays loaded for the session, not only the SBT files: measured in stages 1 to 3.
- MSBT's full option set is large; each stage stays one concern and the config window grows by stage.
- Forever is in beta; its API may change. Each stage feature-detects what it calls (B6, J11).
- If Forever has no combat log, outgoing numbers depend on what `UNIT_COMBAT` reports for the target, and merging and triggers cannot use secret amounts; MSBT's behaviour then cannot be matched in full, and Dan decides what ships.
- Fonts and sounds add about 844 KB to the release zip; they cost memory only when the client loads one.
