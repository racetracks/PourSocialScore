# Scrolling text in PSS: design draft (2026-10-07)

Status: **draft, waiting on Dan's answers** (section 6). Nothing is built. Version line proposed: **3.4.0**.

Dan, 2026-10-07: "lets keep it in its own folder like you originally suggested. Don't make it dependant on the other PSS but put it in the same group structure". So it is a standalone addon folder in the PSS repo, release and AddOns group, with no `Dependencies` on any PSS folder.

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
6. **Placement**: none of it is chat filtering, so none of it may live in core (PSS 02 section 5); Dan chose a folder of its own that does not depend on PSS.
7. **Licence**: the readme states none. Treat as all rights reserved until Dan shows otherwise, so PSS writes its own code.

## 4. Options considered
| # | Option | Retail 12.x | Camelot | Cost | Verdict |
| --- | --- | --- | --- | --- | --- |
| A | Bundle MSBT as a PSS folder, patched | Errors on load (CLEU), taint risk (CVars) | Works | Large: libs, fonts, 3 SV globals | Rejected |
| B | **New PSS engine on MSBT's logic**: display engine plus the sources 12.x still allows; combat parser only where CLEU exists | Notifications, PSS events, incoming combat display-only | Same plus outgoing combat from CLEU | One load-on-demand folder, loaded only when on | **Recommended** |
| C | Notifications only (no combat numbers at all) | Yes | Yes | Smallest | Fallback if API checks in stage 0 fail |
| D | Do not integrate; keep MSBT separate, use Blizzard's floating combat text | MSBT already broken there | - | None | Not what Dan asked |

## 5. Design (option B, standalone folder)
- **Folder** `PourSocialScore_ScrollingText`, three TOCs (base `120007, 16001`, `_Mainline`, `_Camelot`), Title `|cff69ccf0PourSocialScore|r Scrolling Text`, `## Category: PSS`, `## Group: PourSocialScore`, the PSS icon, and the same version as every other TOC. It ships in the same release zip (release.yml already packs every `PourSocialScore_*` folder) and is checked by `tools/check_rules.sh` (tabs).
- **Independent**: no `## Dependencies`, not `LoadOnDemand`, never loaded by `M.PSS_Need`, not in `M.PSS_PARTS`. It runs with or without PSS core. `## OptionalDeps: PourSocialScore` only orders loading so the optional tie-in below can see PSS when both are on.
- **Opt-in** (C1, C2): the TOC carries `## DefaultState: disabled`, so updating PSS turns nothing on; the player enables it in the AddOns list. Disabled = not loaded = zero cost. Enabled, it registers only the events of the sources switched on, and builds frames on the first line shown, never at login (C5).
- **Namespace**: its own private `local addonName, ns = ...`; no new global table (A6). Globals are only its SavedVariables and its slash command.
- **Secret check**: its own copy of the `M.PSS_IsSecret` shape (a few lines; feature-detected `issecretvalue`), so nothing is read from core (PSS 02 section 10 still applies in full).
- **Engine**: a frame pool of FontStrings, each with an `AnimationGroup` (Translation plus Alpha) per style. Scroll areas: Incoming, Outgoing, Notification, each with anchor offset, style and direction. Bursts coalesce with one `C_Timer.After` per area, only for readable values.
- **Sources** (each its own toggle):
  - State: `PLAYER_REGEN_DISABLED` / `ENABLED` (+Combat / -Combat).
  - Loot, money, currency, XP, reputation, honor, skill: their `CHAT_MSG_*` events, every argument through the secret check; a secret line is skipped.
  - Incoming combat on Retail: `UNIT_COMBAT` for player and pet, **display only** (`SetFormattedText`), no merge, no colour by amount, no threshold. Payload and secrecy verified in stage 0 (J11).
  - Outgoing combat: Camelot only, from CLEU, feature-detected and never registered on Retail; only if stage 0 shows Forever delivers CLEU.
  - **Optional PSS tie-in**: if `PourSocialScore_NS` exists, subscribe to its `PLAYER_BLOCKED` event ("Blocked: Name") through the documented `M.Events` subscribe call; if PSS is absent or off, the source is hidden. Nothing in PSS knows about this folder.
- **Settings**: its own `PSS_ScrollingTextDB` (non-default values only, fixed keys, so it cannot grow) and its own settings page (decision 11). The PSS windows do not show these settings, since they must not read this folder (PSS 02 section 6 applies the same way).
- **Not ported**: health or power threshold triggers and cooldown-ready alerts (secret on Retail in exactly the moments they matter), custom fonts and sounds, profiles, MSBT's own options window. Parked.
- **Blizzard floating combat text**: never changes its CVars. The settings page says where the Blizzard setting is (Options, Gameplay, Combat).
- **Commands**: its own slash, proposed `/psst` (toggle), `/psst test` (one line per area), `/psst unlock` (drag areas).

## 6. Decisions for Dan
1. Scope: option **B** (recommended), C or D?
2. Folder name `PourSocialScore_ScrollingText` (recommended) or another?
3. Version line **3.4.0** (recommended; a new feature, so not a 3.3.x fix).
4. Licence: write our own code from MSBT's behaviour, copy nothing (recommended), or do you hold a licence that allows copying?
5. ~~Store~~ Settled by the standalone folder: its own `PSS_ScrollingTextDB` (still a new SavedVariables, so confirm).
6. Leave Blizzard's floating combat text CVars alone and only point to the setting (recommended)?
7. When first enabled: only combat enter/leave and the PSS tie-in on (recommended), or every source on?
8. Retail incoming combat numbers, display only, if stage 0 confirms `UNIT_COMBAT` works: yes (recommended) or skip?
9. Camelot outgoing combat from CLEU: yes if verified (recommended) or skip?
10. Triggers and cooldown alerts: park (recommended) or Camelot-only stage?
11. Settings page: a page in Blizzard's AddOns settings (Settings API, recommended; signatures checked per J11) or slash commands plus a small window of its own?
12. Ship it `DefaultState: disabled` (recommended), or enabled with every source off?
13. Slash `/psst` (recommended) or another?

## 7. Stages (one PR each, based on main, never stacked)
| Stage | Version | Change | Visible | Validation |
| --- | --- | --- | --- | --- |
| 0 | none | API checks in game on 120007 and 16001 (section 8); answers recorded here | No | Dan's `/dump` results |
| 1 | 3.4.0-dev001 | Folder, 3 TOCs (`DefaultState: disabled`, no Dependencies), namespace, `PSS_ScrollingTextDB` defaults, slash command; no frames, no sources | AddOns list entry | Loads alone with every other PSS folder disabled; PSS unchanged with it disabled; resident cost measured |
| 2 | 3.4.0-dev002 | Display engine: frame pool, one area, Straight style via AnimationGroup, `/psst test` | Yes | Harness: pool reuse, no frames before first line; memory and CPU per line measured |
| 3 | 3.4.0-dev003 | Sources: combat enter/leave, optional PSS `PLAYER_BLOCKED` | Yes | With and without PSS core loaded; restriction CVars run (PSS 02 s10 item 6) |
| 4 | 3.4.0-dev004 | Sources: loot, money, currency, XP, reputation, honor, skill; secret check; burst coalescing | Yes | Secret lines skipped (harness stub with `issecretvalue`); chat restrictions run |
| 5 | 3.4.0-dev005 | Three areas, styles (Straight, Parabola, Static), saved positions, `/psst unlock` | Yes | Save size measured; PSS real saves untouched (validate_all) |
| 6 | 3.4.0-dev006 | Settings page (decision 11) | Yes | Every toggle saves and reloads; PSS windows unchanged (`ui_compare.sh`, `eui_compare.sh`) |
| 7 | 3.4.0-dev007 | Retail incoming combat, display only (if decision 8 and stage 0 allow) | Yes | Combat and encounter restriction CVars; no Lua errors; no read-back of secret text |
| 8 | 3.4.0-dev008 | Camelot outgoing combat from CLEU (if decision 9 and stage 0 allow) | Yes, Camelot | Retail never registers CLEU (harness asserts it) |
| 9 | 3.4.0-dev009 | Fixes from testing, readme, locale escapes | Yes | Full regression |
| Release | 3.4.0 | Version and history only | | Dan confirms done |

Stage 6 can move before 5 if Dan wants settings early; 7 and 8 are independent and drop out if their checks fail. No stage touches a PSS folder except the shared readme and history.txt.

## 8. Stage 0: in-game checks for Dan
On Retail (120007) and Camelot (16001), outside and then inside combat (or with `/console addonCombatRestrictionsForced 1`):
1. `/dump C_EventUtils and C_EventUtils.IsEventValid("UNIT_COMBAT")` and `/dump C_EventUtils and C_EventUtils.IsEventValid("COMBAT_LOG_EVENT_UNFILTERED")`.
2. `/etrace`, filter `UNIT_COMBAT`, take and give a hit: are the damage arguments shown, or as secret?
3. Camelot only: does `/etrace` show `COMBAT_LOG_EVENT_UNFILTERED` while fighting?
4. `/etrace` `CHAT_MSG_LOOT` and `CHAT_MSG_MONEY` while looting in combat.

## 9. Risks
- Retail rules may tighten again (more events secret): every source degrades by skipping, never erroring.
- Enabled, the folder stays loaded all session: its resident cost is reported from stage 1 on and kept small.
- `## DefaultState` and the Settings API are to be confirmed on both clients (J11); stage 1 and stage 6 say so if either is missing on Camelot.
- Scope creep towards MSBT's full option set: each stage stays one concern; anything bigger is split and raised first.
