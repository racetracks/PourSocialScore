# Scrolling text in PSS: design draft (2026-10-07)

Status: **draft, waiting on Dan's answers** (section 6). Nothing is built. Version line proposed: **3.4.0**.

Placement (Dan, 2026-10-07): "keep as much as we could under libraries with whatever core frontend parts going into the core addon"; settings in `PSS_OptionsDB`; the Libraries TOC is left as it is. No new addon folder.

Source studied: Mik's Scrolling Battle Text (MSBT) 6.0.3, uploaded by Dan (Interface 11504, 40400, 110002; readme 5.7.148, author Mikord). Read for behaviour only; no file, font, sound or code from it is copied (baseline 02 H4, 07 "copy logic, never code").

## 1. Goal
Text that scrolls near the character: incoming combat numbers, loot and money, XP, reputation, honor, combat enter/leave, and PSS's own events (a player blocked). Off by default, zero cost when off, drawn in a native Blizzard look, configured from `M.PSS_OPTIONS` in both front ends.

## 2. What exists in MSBT
| Part | File (source size) | What it does | Fate on 12.x |
| --- | --- | --- | --- |
| Root | MikSBT.lua (8 KB) | Global `MikSBT`, slash `/msbt`, helpers | Rewrite on `M` |
| Profiles | MSBTProfiles.lua (117 KB) | Defaults, profiles, 3 global SavedVariables, **sets `enableFloatingCombatText` and other CVars, calls Blizzard `CombatText_UpdateDisplayedMessages`** | Rewrite small; CVar writes dropped (J2, J4) |
| Parser | MSBTParser.lua (42 KB) | **`COMBAT_LOG_EVENT_UNFILTERED`** plus `CHAT_MSG_*` global-string searches, unit/class maps from target and mouseover | **Dead on Retail 12.x** (CLEU forbidden, J8). Camelot only, if Forever has CLEU |
| Main | MSBTMain.lua (68 KB) | Formats events, merges and throttles bursts, power gains, combo points | Rewrite; merging needs arithmetic on amounts, impossible on secret values |
| Animations | MSBTAnimations.lua (26 KB) | Scroll areas, font strings, one **OnUpdate** frame driving every moving line | Rewrite with `AnimationGroup`s (engine-driven, no Lua per frame) |
| Animation styles | MSBTAnimationStyles.lua (40 KB) | Straight, parabola, static, Pow, angled | Rewrite the 2 or 3 we keep |
| Triggers | MSBTTriggers.lua (41 KB) | Rules on CLEU, `UNIT_HEALTH`, `UNIT_POWER_UPDATE` thresholds (low health/mana) | **Broken on Retail**: CLEU forbidden; health and power are secret in combat, so no threshold compare (J7) |
| Cooldowns | MSBTCooldowns.lua (21 KB) | "Cooldown ready": OnUpdate polling plus `hooksecurefunc` on `UseAction`, `UseInventoryItem`, `C_Container.UseContainerItem`, `C_Item.UseItemByName`, plus CLEU | **Broken on Retail**: cooldowns secret in combat (SecretWhenCooldownsRestricted, 12.0.5) |
| Loot | MSBTLoot.lua (8 KB) | Loot, currency and money lines from `CHAT_MSG_*` | Keep; chat values go through `M.PSS_IsSecret` |
| Media | MSBTMedia.lua (7 KB), Fonts (11 TTF), Sounds (3 OGG), LibStub, CallbackHandler, LibSharedMedia (22 KB) | Custom fonts and sounds | Dropped: Blizzard fonts and sounds only (A10, I1); font licences unknown |
| Options | MSBTOptions folder (~10 k lines, 924 KB with art) | Its own options window | Replaced by `M.PSS_OPTIONS` rows in both PSS windows |
| Locales | de, fr, it, kr, ru, zhcn, zhtw | UTF-8 strings | English first; others later as ASCII escapes (A2) |

MSBT engine source: 379 KB of Lua, plus 844 KB of fonts and sounds. Compiled size and resident memory were **not measured** (no Lua 5.1 in the session that wrote this); measure before any number goes in a PR.

## 3. Why MSBT cannot be dropped in as is
1. **Combat log**: registering `COMBAT_LOG_EVENT_UNFILTERED` on Retail 12.x fires `ADDON_ACTION_FORBIDDEN` (baseline 02 J8). The parser, triggers and cooldowns all depend on it.
2. **Secret values**: health, power, cooldown and aura values, `UnitName` of other units, and chat arguments under lockdown are secret while restricted. MSBT compares, adds and indexes all of them (J7). A secret can still be **shown** (`FontString:SetText`, `SetFormattedText("%s", v)`), never decided on.
3. **Blizzard state**: `SetCVar` on the floating combat text CVars and calling `CombatText_UpdateDisplayedMessages` write and run Blizzard state (J2, J4).
4. **Globals and libraries**: `MikSBT`, three SavedVariables globals, named frames, LibStub and LibSharedMedia (A6, A10).
5. **OnUpdate**: three always-ready OnUpdate frames (C3; PSS already carries OnUpdate deviations, 01 section 5).
6. **Placement**: none of it is chat filtering, so it may not run from core (PSS 02 section 5); it goes in `PourSocialScore_Libraries`, with only its launch in core.
7. **Licence**: the readme states none. Treat as all rights reserved until Dan shows otherwise, so PSS writes its own code.

## 4. Options considered
| # | Option | Retail 12.x | Camelot | Cost | Verdict |
| --- | --- | --- | --- | --- | --- |
| A | Bundle MSBT as a PSS folder, patched | Errors on load (CLEU), taint risk (CVars) | Works | Large: libs, fonts, 3 SV globals | Rejected |
| B | **New PSS engine on MSBT's logic**: display engine plus the sources 12.x still allows; combat parser only where CLEU exists | Notifications, PSS events, incoming combat display-only | Same plus outgoing combat from CLEU | New files in Libraries, which loads at login only when on | **Recommended** |
| C | Notifications only (no combat numbers at all) | Yes | Yes | Smallest | Fallback if API checks in stage 0 fail |
| D | Do not integrate; keep MSBT separate, use Blizzard's floating combat text | MSBT already broken there | - | None | Not what Dan asked |

## 5. Design (option B, in Libraries)
- **Core** (`PourSocialScore`) gains only the launch: the option rows in `M.PSS_OPTIONS` (`sctEnabled` default off, plus the per-source and area rows) and one handler that, at login and when `sctEnabled` turns on, calls `M.PSS_Need("Libraries")` and then the engine's start; when it turns off, the engine's stop. Nothing else, so players who never turn it on pay only for those lines (measured in stage 1).
- **Libraries** (`PourSocialScore_Libraries`) gets two new files:
  - `PSS_ScrollEngine.lua`: start and stop, event registration for the sources switched on only, the secret check through `M.PSS_IsSecret`, formatting, burst coalescing (one `C_Timer.After` per area, readable values only).
  - `PSS_ScrollDisplay.lua`: a frame pool of FontStrings, each with an `AnimationGroup` (Translation plus Alpha) per style, built on the first line shown, never at login (C5). Scroll areas: Incoming, Outgoing, Notification, each with offset, style and direction. This is the one drawing file in Libraries; it draws the scrolling lines only, never a window, and both front ends leave it alone.
- **Cost when on**: Libraries loads at login and stays loaded for the session (today 6 files, 68 KB of source, plus the two new ones). Opening either PSS window already loads Libraries, so that costs nothing extra. Resident memory and compiled size are measured in stage 1 and stage 2.
- **Libraries TOC**: unchanged, Notes included (Dan, 2026-10-07). Only the two file lines are added to its file list.
- **Settings**: rows in `M.PSS_OPTIONS`, saved in `PSS_OptionsDB` through `M.PSS_SetOpt`, only non-default values (Dan, 2026-10-07). Area positions are option values too. Both the native and the EllesmereUI windows draw the rows from the one table (G5). New keys only; no existing key changes, so no migration, but every stage that adds keys is run against the real saves.
- **Sources** (each its own option):
  - PSS: `PLAYER_BLOCKED` through `M.Events.Register` ("Blocked: Name").
  - State: `PLAYER_REGEN_DISABLED` / `ENABLED` (+Combat / -Combat).
  - Loot, money, currency, XP, reputation, honor, skill: their `CHAT_MSG_*` events, every argument through `M.PSS_IsSecret` (PSS 02 section 10); a secret line is skipped.
  - Incoming combat on Retail: `UNIT_COMBAT` for player and pet, **display only** (`SetFormattedText`), no merge, no colour by amount, no threshold. Payload and secrecy verified in stage 0 (J11).
  - Outgoing combat: Camelot only, from CLEU, feature-detected and never registered on Retail; only if stage 0 shows Forever delivers CLEU.
- **Not ported**: health or power threshold triggers and cooldown-ready alerts (secret on Retail in exactly the moments they matter), custom fonts and sounds, profiles, MSBT's own options window. Parked.
- **Blizzard floating combat text**: PSS never changes its CVars. The options section says where the Blizzard setting is (Options, Gameplay, Combat).
- **Commands** (in `PSS_Commands.lua`): `/pss sct` (toggle), `/pss sct test` (one line per area), `/pss sct unlock` (drag areas).

## 6. Decisions
Answered 2026-10-07:
- Placement: Libraries, with only the launch in core; no new folder.
- Settings in `PSS_OptionsDB`.
- Libraries TOC left as it is.

Open (stages are built on the recommendation until Dan answers):
1. Scope: option **B** (recommended), C or D?
2. The scrolling display in Libraries next to the engine (recommended, zero cost when off), or in core (resident for everyone, measured)?
3. Version line **3.4.0** (recommended; a new feature, so not a 3.3.x fix).
4. Licence: write our own code from MSBT's behaviour, copy nothing (recommended), or do you hold a licence that allows copying?
5. Leave Blizzard's floating combat text CVars alone and only point to the setting (recommended)?
6. When the option is turned on: start with only PSS events and combat enter/leave on (recommended), or every source on?
7. Retail incoming combat numbers, display only, if stage 0 confirms `UNIT_COMBAT` works: yes (recommended) or skip?
8. Camelot outgoing combat from CLEU: yes if verified (recommended) or skip?
9. Triggers and cooldown alerts: park (recommended) or Camelot-only stage?

## 7. Stages (one PR each, based on main, never stacked)
| Stage | Version | Change | Visible | Validation |
| --- | --- | --- | --- | --- |
| 0 | none | API checks in game on 120007 and 16001 (below); answers recorded here | No | Dan's `/dump` results |
| 1 | 3.4.0-dev001 | Core: `sctEnabled` option row (off) and the launch handler; Libraries: `PSS_ScrollEngine.lua` with start and stop only; `/pss sct` | Option only | Option off: Libraries not loaded at login, no events (harness); option on: Libraries resident cost measured; real saves |
| 2 | 3.4.0-dev002 | Libraries: `PSS_ScrollDisplay.lua`, frame pool, one area, Straight style via AnimationGroup, `/pss sct test` | Yes, behind option | Harness: pool reuse, no frames before first line; memory and CPU per line measured |
| 3 | 3.4.0-dev003 | Sources: `PLAYER_BLOCKED`, combat enter/leave | Yes | Restriction CVars run (PSS 02 s10 item 6); option off = no events |
| 4 | 3.4.0-dev004 | Sources: loot, money, currency, XP, reputation, honor, skill; secret check; burst coalescing | Yes | Secret lines skipped (harness stub with `issecretvalue`); chat restrictions run |
| 5 | 3.4.0-dev005 | Three areas, styles (Straight, Parabola, Static), positions as options, `/pss sct unlock` | Yes | New `PSS_OptionsDB` keys only, non-defaults; save size measured; validate_all on real saves |
| 6 | 3.4.0-dev006 | Native options section | Yes | `ui_compare.sh` on unchanged tabs |
| 7 | 3.4.0-dev007 | EllesmereUI options section, same rows | Yes | `eui_compare.sh` on unchanged tabs; same options both sides |
| 8 | 3.4.0-dev008 | Retail incoming combat, display only (if decision 7 and stage 0 allow) | Yes | Combat and encounter restriction CVars; no Lua errors; no read-back of secret text |
| 9 | 3.4.0-dev009 | Camelot outgoing combat from CLEU (if decision 8 and stage 0 allow) | Yes, Camelot | Retail never registers CLEU (harness asserts it) |
| 10 | 3.4.0-dev010 | Fixes from testing, readme, locale escapes | Yes | Full regression |
| Release | 3.4.0 | Version and history only | | Dan confirms done |

Stages 6 and 7 can move before 5 if Dan wants settings early; 8 and 9 are independent and drop out if their checks fail.

## 8. Stage 0: in-game checks for Dan
On Retail (120007) and Camelot (16001), outside and then inside combat (or with `/console addonCombatRestrictionsForced 1`):
1. `/dump C_EventUtils and C_EventUtils.IsEventValid("UNIT_COMBAT")` and `/dump C_EventUtils and C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")`.
2. `/etrace`, filter `UNIT_COMBAT`, take and give a hit: are the damage arguments shown, or as secret?
3. Camelot only: does `/etrace` show `COMBAT_LOG_EVENT_UNFILTERED` while fighting?
4. `/etrace` `CHAT_MSG_LOOT` and `CHAT_MSG_MONEY` while looting in combat.

## 9. Risks
- Retail rules may tighten again (more events secret): every source degrades by skipping, never erroring.
- With the option on, all of Libraries stays loaded for the session, not only the scrolling files: its resident cost is reported in stages 1 and 2. If it is too high, the fallback is moving the two files to a folder of their own (the first draft), which is Dan's call.
- A `/reload` in combat with the option on loads Libraries at login in combat; loading is not protected, but stage 3 checks it under the combat restriction CVar.
- Scope creep towards MSBT's full option set: each stage stays one concern; anything bigger is split and raised first.
