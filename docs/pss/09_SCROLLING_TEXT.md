# Scrolling Battle Text in PSS: design (2026-10-07)

Status: **design, decisions mostly answered** (section 6). Nothing is built. Version line: **3.4.0**.

Source studied: Mik's Scrolling Battle Text (MSBT) 6.0.3, uploaded by Dan (Interface 11504, 40400, 110002; readme 5.7.148, author Mikord). Dan, 2026-10-07: "write our own code with our own standards, port what makes sense". So MSBT is read for behaviour; PSS writes its own code to PSS rules. No MSBT file, font, sound or code is copied (baseline 02 H4; its licence is unstated).

## 1. Goal
**WoW Forever (Camelot, Interface 16001) only. Not Retail.** Scrolling Battle Text (SBT) behaves as MSBT did: incoming and outgoing damage, misses and heals, power gains, auras, kills, notifications (loot, money, currency, XP, reputation, honor, skill, combat enter/leave), triggers and cooldown alerts, in scroll areas around the character with MSBT's animation styles. Off until the player turns it on (C2); once on, MSBT's default behaviour.

## 2. What exists in MSBT
| Part | File (source size) | What it does | On Forever |
| --- | --- | --- | --- |
| Root | MikSBT.lua (8 KB) | Global `MikSBT`, slash `/msbt`, helpers | Rewrite on `M`; no new global |
| Profiles | MSBTProfiles.lua (117 KB) | Defaults, profiles, 3 global SavedVariables, sets the Blizzard floating combat text CVars at first load, calls Blizzard `CombatText_UpdateDisplayedMessages` | Defaults rewritten as one table; settings in `PSS_OptionsDB`; no automatic CVar writes (J2, J4) |
| Parser | MSBTParser.lua (42 KB) | `COMBAT_LOG_EVENT_UNFILTERED` plus `CHAT_MSG_*` global-string searches, unit and class maps | Rewrite in Libraries (CLEU exists on classic-family clients; stage 0 confirms on Forever) |
| Main | MSBTMain.lua (68 KB) | Formats events, merges and throttles bursts, power gains, combo points | Rewrite in Libraries |
| Animations | MSBTAnimations.lua (26 KB) | Scroll areas, font strings, one OnUpdate frame for every moving line | Rewrite: frames in the SBT folder, AnimationGroups where they fit (C3) |
| Animation styles | MSBTAnimationStyles.lua (40 KB) | Straight, Parabola, Static, Pow, Angled, Horizontal | Path maths in Libraries, drawing in the SBT folder |
| Triggers | MSBTTriggers.lua (41 KB) | Rules on CLEU, health and power thresholds (low health, low mana, procs) | Rewrite in Libraries |
| Cooldowns | MSBTCooldowns.lua (21 KB) | "Cooldown ready": OnUpdate polling plus `hooksecurefunc` on `UseAction`, `UseInventoryItem`, `C_Container.UseContainerItem`, `C_Item.UseItemByName` | Rewrite in Libraries, event-driven (decision 15) |
| Loot | MSBTLoot.lua (8 KB) | Loot, currency and money from `CHAT_MSG_*` | Rewrite in Libraries |
| Media | MSBTMedia.lua, 11 TTF fonts, 3 OGG sounds, LibStub, CallbackHandler, LibSharedMedia | Custom fonts and sounds | Blizzard fonts and sound kits only (A10, I1) |
| Options | MSBTOptions folder (~10 k lines, 924 KB with art) | Its own options window | A Scrolling Battle Text group in PSS options plus a config window in the SBT folder |
| Locales | de, fr, it, kr, ru, zhcn, zhtw | UTF-8 strings | English first; others later as ASCII escapes (A2) |

MSBT engine source: 379 KB of Lua, plus 844 KB of fonts and sounds. Compiled size and resident memory were not measured (no Lua 5.1 in this session); every stage PR measures what it adds.

## 3. What has to change from MSBT
1. **Placement**: none of it is chat filtering, so it cannot run from core (PSS 02 section 5). Logic goes in `PourSocialScore_Libraries`, drawing in its own UI folder.
2. **Blizzard state**: no automatic `SetCVar` on the floating combat text CVars, no calls into Blizzard's combat text Lua (J2, J4).
3. **Globals and libraries**: none of `MikSBT`, its SavedVariables globals, named frames, LibStub or LibSharedMedia (A6, A10).
4. **OnUpdate**: three OnUpdate frames; replaced by AnimationGroups and event-driven timers where they fit (C3).
5. **Retail**: none of it may load or register anything on Retail (CLEU is forbidden there, J8).
6. **Secret values**: classic-family clients have none so far; every chat and unit value still goes through `M.PSS_IsSecret` (PSS 02 section 10), which costs nothing where secrets do not exist.

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
| **`PourSocialScore_ScrollingBattleText`** (new) | The UI only: frame pool, scroll area frames, animations, the unlock/move overlay, the SBT config window. No logic (PSS 02 section 6) | On demand, only on Forever and only when SBT is on |

- The SBT folder's TOCs: a base TOC and a `_Camelot` TOC, both with `## AllowLoadGameType: camelot` and `## LoadOnDemand: 1`, `## Dependencies: PourSocialScore_Libraries`; no `_Mainline` TOC. Title `|cff69ccf0PourSocialScore|r Scrolling Battle Text`, `## Category: PSS`, `## Group: PourSocialScore`, the PSS icon, the same version as every TOC. Stage 0 confirms Retail neither lists nor loads it. The release zip already packs every `PourSocialScore_*` folder.
- The Libraries files load on Retail too (Libraries is shared), so each SBT start checks `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (guarded for nil, B6) and does nothing otherwise; the harness asserts that Retail never registers CLEU.
- On Retail the SBT option rows and group are not added to `M.PSS_OPTIONS`, so both PSS windows show nothing new and need no change; `/pss sbt` says it is for WoW Forever only.
- Libraries TOC Notes stay as they are (Dan, 2026-10-07); only file lines are added.

### Zero cost when off
`sbtEnabled` defaults off. Off: core holds only the option row, the slash branch and the login check; Libraries and the SBT folder are not loaded for it; no events, no frames. On: Libraries and the SBT folder load at login and stay loaded; frames are built on the first line shown (C5). Resident costs measured from stage 1.

### Behaviour once on
MSBT's default settings, rewritten as PSS's defaults table: the same scroll areas (Incoming, Outgoing, Notification, Static), the same events on, the same colours, crits sticky, merging and throttling as MSBT did them. Two exceptions: Blizzard fonts instead of MSBT's bundled fonts, and Blizzard sound kits instead of its OGG files (decision 13).

### Settings
One nested table, `PSS_OptionsDB.sbt`, holding only values that differ from the defaults (D3), so it stays small and bounded (fixed keys; custom triggers capped). The master switch `sbtEnabled` is a normal `M.PSS_OPTIONS` row so the PSS options window shows it. A new key only; no existing key changes, so no migration; every stage that adds settings is run against the real saves.

### Options group
A "Scrolling Battle Text" group in the PSS options (Forever only) holding: Enable Scrolling Battle Text; Open SBT settings (the SBT folder's config window); the Blizzard combat text line (decision 11).

### Animations
AnimationGroups (Translation, Alpha, Scale) for Straight, Static, Pow, Horizontal. Parabola and Angled need a curved path: an AnimationGroup `Path` animation if Forever has it (stage 0), otherwise one OnUpdate on the display frame that runs only while a curved line is moving and stops when none is (recorded as a C3 deviation, like `PSS_Pie.lua`).

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
7. and 8. Incoming and outgoing combat: yes.
9. Triggers and cooldowns: park only if not possible. On Forever they are possible (no secret values), so they are stages 10 and 11.

Open (stages are built on the recommendation until Dan answers):
10. Settings as one `PSS_OptionsDB.sbt` table of non-defaults (recommended) or flat keys?
11. Blizzard's combat text in the SBT group: a line saying where Blizzard's setting is (recommended, no Blizzard state touched), or a tickbox that changes Blizzard's CVar only when clicked, out of combat (needs your OK as an exception to PSS 02 section 10 item 3)?
12. MSBT still installed and enabled: SBT refuses to start and says why (recommended), or both run?
13. Blizzard fonts and sounds only (recommended), or do you hold the licences for MSBT's bundled fonts?
14. EllesmereUI: does it run on Forever? If not, the SBT settings are native only (recommended); if it does, an EUI stage is added.
15. Cooldown alerts from cooldown events (recommended), or MSBT's post-hooks on `UseAction` and the item use functions (allowed post-hooks, but new Blizzard functions touched, needing your OK)?

## 7. Path to 3.4.0
- Every merged stage PR sets the next `3.4.0-devNNN` in every TOC; merging publishes a GitHub **pre-release** (the pipeline marks any version with `-` as one). Each PR also hosts a test zip on scratch (`PourSocialScore/test-builds/PourSocialScore-3.4.0-devNNN.zip`) with numbered in-game checks for Forever.
- Retail users who install a dev build get no change: the SBT folder does not load there, and the option group is absent. Each PR still runs the Retail look-compares to prove it.
- A Retail or Forever bug found in the meantime ships as the next devNNN on the 3.4.0 line (baseline 02 F4), its own PR, never folded into a stage.
- When every stage has passed on Forever, a PR sets plain `3.4.0` with a history section for the feature; merging it publishes the full release. Only when Dan says it is done.

## 8. Stages (one PR each, based on main, never stacked)
| Stage | Version | Change | Visible | Validation |
| --- | --- | --- | --- | --- |
| 0 | none | In-game checks on Forever and Retail (section 9) | No | Dan's results recorded here |
| 1 | 3.4.0-dev001 | Groundwork: core `/pss sbt`, `sbtEnabled` and the options group (Forever only), part key and NEEDS; Libraries `PSS_SBTEngine.lua` with start/stop only; the new folder with its two TOCs and an empty file | Option only (Forever) | Option off: nothing loads, no events; Retail: no rows, folder never loads; resident cost of core lines measured; `ui_compare.sh` and `eui_compare.sh` identical on Retail |
| 2 | 3.4.0-dev002 | Data: `PSS_SBTSettings.lua`, MSBT-equivalent defaults, the `sbt` table, read/write through Libraries setters firing `M.Events` | No | Real saves validated; save size measured |
| 3 | 3.4.0-dev003 | Display: frame pool, the four scroll areas, Straight and Static styles, `/pss sbt test` | Yes | Pool reuse, no frames before first line; memory and CPU per line measured |
| 4 | 3.4.0-dev004 | Combat parser: CLEU incoming and outgoing damage, misses, heals; school colours; crits with Pow | Yes | Harness CLEU stub; Retail never registers CLEU; in-game fight checks |
| 5 | 3.4.0-dev005 | Merge and throttle, power gains, combo points, auras gained and faded, kills, environmental, interrupts, dispels | Yes | Merge counts match the raw lines in the harness |
| 6 | 3.4.0-dev006 | Notifications: loot, money, currency, XP, reputation, honor, skill, combat enter/leave, PSS blocked (off) | Yes | Secret check on every chat value; chat restriction CVar run if Forever has it |
| 7 | 3.4.0-dev007 | Parabola, Angled, Horizontal styles; `/pss sbt unlock` | Yes | Curved-path cost measured; OnUpdate (if any) stops when idle |
| 8 | 3.4.0-dev008 | SBT config window (areas, events, colours, fonts) in the SBT folder; "Open SBT settings" in the group | Yes | Every setting saves and reloads; only non-defaults saved |
| 9 | 3.4.0-dev009 | MSBT-installed check (decision 12), Blizzard combat text line (decision 11) | Yes | Checks with MSBT on and off |
| 10 | 3.4.0-dev010 | Triggers: MSBT's default triggers (low health, low mana, procs), custom triggers, Blizzard sounds | Yes | Trigger cap; harness thresholds |
| 11 | 3.4.0-dev011 | Cooldown-ready alerts (decision 15) | Yes | No OnUpdate polling; timers only while a cooldown runs |
| 12 | 3.4.0-dev012 | Fixes from testing, readme, locale escapes | Yes | Full regression |
| Release | 3.4.0 | Version and history only | | Dan confirms done |

Stages 10 and 11 drop to a later line if stage 0 shows Forever restricts them. If a stage grows while building, it is split and Dan is told first.

## 9. Stage 0: in-game checks for Dan
On **WoW Forever**:
1. `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, select(4, GetBuildInfo())`
2. `/dump issecretvalue ~= nil` (are secret values present at all?)
3. `/etrace`, then fight a mob: do `COMBAT_LOG_EVENT_UNFILTERED` events appear?
4. `/dump GetCVar("enableFloatingCombatText"), GetCVar("floatingCombatTextCombatDamage")`
5. `/run local a = CreateFrame("Frame"):CreateAnimationGroup():CreateAnimation("Path"); print(a and "Path ok")`

On **Retail**: after stage 1's test zip, the AddOns list shows no Scrolling Battle Text entry and `/pss sbt` says Forever only.

## 10. Risks
- With SBT on, all of Libraries stays loaded for the session, not only the SBT files: measured in stages 1 to 3.
- MSBT's full option set is large; each stage stays one concern and the config window grows by stage.
- Forever is in beta; its API may change. Each stage feature-detects what it calls (B6, J11).
