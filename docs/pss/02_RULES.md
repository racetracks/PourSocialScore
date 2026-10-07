# PourSocialScore: project rules (only what PSS adds to the baseline)

The baseline's 02_RULES applies in full. This file holds what is specific to PSS: the concrete values, Dan's PSS decisions, and where PSS overrides the baseline. Dates are when Dan set them. If the claude.ai project instructions differ, they win.

## 1. Code and style
1. Core and native folders indent with tabs. **`PourSocialScore_EllesmereUI` uses EllesmereUI's 4-space style**, enforced by `tools/check_rules_eui.sh` (which also checks that folder's Version equals core's).
2. Everything shared hangs on `M` via `PourSocialScore_NS` (the project's root table); use `M.ShowMsg`, `M.Trim` and the UIKit builders.
3. Core fires `M.Events`; UIs listen and write only through core setters (`tools/check_layers.lua` enforces it).
4. The 8 StaticPopup dialogs stay as they are in the native mode.

## 2. TOCs
- Title `|cff69ccf0PourSocialScore|r <Part>`.
- Core Notes are Dan's wording: "Sometimes you dont wanna know when a man gotta slur a little". Never change Title or Notes unless asked.
- Every TOC: `## Category: PSS`, `## Group: PourSocialScore`, `## IconTexture: Interface\FriendsFrame\Battlenet-Portrait`.
- Base TOC interface `120007, 16001`; `_Mainline`; `_Camelot`. Every TOC in the repo carries one version.

## 3. Behaviour rules
- **Counting:** counters are never derived from log lines; nothing counted twice; guild rule blocks count only as guild blocks (the Chat Filters row shows "n/a"); a rule turned off disables every guild in it (`M.PSS_GuildRuleActive`).
- **A guild rule never blocks your own guild** (`M.PSS_IsOwnGuild`). Player list entries for people in your guild still block.
- **Removal** deletes all of a player's saved data. A player on a shipped guild list stays blocked with a member note.
- **W I G P C:** ticked = allowed; a new entry blocks everything; built-in filters start off.
- **Every number the EllesmereUI window shows must equal the native window's**, with the same definitions ("this session" = since login or /reload). `check_match.lua` gates it.
- Every window closes on Escape. Native Blizzard look in our GUI, EllesmereUI's look under EllesmereUI.
- No guild discovery from mouseover or nameplates in combat.

## 4. Garbage collection (changed 2026-10-07)
- Old PSS rule: GC on request (login, /who scan, import, window close) **plus a 10-minute idle cycle**; never in combat, within 5 minutes of combat, or in an instance.
- **Dan chose event-driven on 2026-10-07:** no idle timer and no 5-minute combat wait. GC runs only on request, deferred to out of combat and not in an instance, detected from events. The code (`PSS_Perf.lua`) has not been changed yet (Dan: templates only for now).

## 5. Core placement (G2, confirmed 2026-10-05 15:30Z)
> "minimal functions are stored in the poursocialscore core addon. it must only service as the core framework to handle the chat filtering and a launchpad for the addon. Functions that wont run in active memory or be considered as regularly active (chat filters etc) should be in the libraries folder."

So core = the chat filtering engine plus the loader, with what filtering needs (counting, outbox, setters, events). Anything not regularly active goes in `PourSocialScore_Libraries`, including code shared by both UIs. Core functions such as `PSS_PlayerQuery` stay only if they sit on a regularly active path; flag others as move candidates with a measured cost.

## 6. Front-end separation (2026-10-05)
1. No application or service logic in `PourSocialScore_GUI` or `PourSocialScore_EllesmereUI`.
2. The native GUI never reads or loads a file from the EllesmereUI folder, and the reverse; a user never needs both (decision 5, Dan: "I dont want the native gui reading any files from the ellesmereui port. We need to consider them independent so the user doesnt have to load multiple addons when we can accomodte it for them and just use shard functions for calls.").
3. UI resources both need go in `PourSocialScore_Libraries`, or core if always-loaded code needs them.
4. Both read `M.PSS_OPTIONS`; the EUI folder keeps only EUI-only state in `PSS_EllesmereUIDB` (window position, last tab).
5. **Logging loads only when called** (04 section 2).

## 7. Porting to the native GUI (G7 to G10, 2026-10-05)
- **G7 (15:30Z):** every texture, font, template and API a port uses is ours or Blizzard's. Nothing from EllesmereUI or any other addon.
- **G8 (15:30Z):** ports look as close as possible to the EllesmereUI version while still looking like the Blizzard UI.
- **G9 (15:33Z):** if copying a component from our `PourSocialScore_EllesmereUI` code into `PourSocialScore_GUI` gives a lower footprint, copy it as functions into `PourSocialScore_GUI` only. A copy, not shared code. EllesmereUI's own code is never copied. (Example: `PSS_Pie.lua`, 11.4 KB.)
- **G10 (15:37Z):** `PourSocialScore_EllesmereUI` is read only during parity work; shared functions serving both UIs are performance-optimized and measured. **Exception (issue #77, option b, 16:09Z):** logic found in the EUI folder moves to Libraries and the EUI file calls it, nothing visible changing (`eui_compare.sh` identical). Done in 3.3.0-dev001.

## 8. Versions on PSS
- The 3.3.0 line is the parity feature (Dan chose it on 2026-10-05). Its stages are 3.3.0-devNNN pre-releases; plain `3.3.0` only when Dan says the parity work is complete.
- Older builds used `-devN` (3.2.0-dev3). Do not copy that; three digits from 3.3.0 on.
- A fix for 3.2.0 would be `3.2.1-dev001`; ask Dan if a fix line is needed.
- **Fixes to a dev build before it merges count up with `_N` (Dan, 2026-10-07):** the first round of fixes on `3.4.0-dev002` is `3.4.0-dev002_2`, then `_3`; every TOC, the history section and the test zip name carry it. The next stage is still the next devNNN (`3.4.0-dev003`).

## 9. Hosting paths on scratch
- Test zips: `PourSocialScore/test-builds/PourSocialScore-<version>.zip` (old `pss-builds/` kept for links). Also copy to `/mnt/project-files/builds/`.
- Plans: `pss-projects/<project>/` (current: `pss-native-gui-port/`). Issue notes: `pss-issues/`.
- Saves: `pss-projects/savedvariables/<version>/` (the `PourSocialScore/savedvariables/` copies stay for old links).
- Packs: `handover-packs/` (this pack is `pss-handover-<date>-vN`).

## 10. Taint and secret values on PSS (baseline 02 J, added 2026-10-07)
PSS is a chat filter: on Retail 12.x its inputs are the values most likely to be secret (chat event arguments under chat messaging lockdown, `UnitName` and GUIDs while restricted).
1. **Every value from a chat event, unit API or popup hook goes through `M.PSS_IsSecret` (`PSS_ChatBlock.lua`) before any compare, `find`, `#`, table index or table key.** A secret author, GUID or message means the line is not filtered and not counted: return false, never error. Copy the existing shape (`if type(name) ~= "string" or M.PSS_IsSecret(name) or name == "" then return end`).
2. **A secret never reaches a counter, the outbox or SavedVariables.** Counting happens only on readable values (02 section 3); a skipped line is not a block.
3. **Blizzard state PSS may touch, and how:** chat filters only through `ChatFrame_AddMessageEventFilter`; ignore list changes only through `hooksecurefunc` on `C_FriendList` (`PSS_PlayerIgnoreList.lua`); the LFG list through `hooksecurefunc` plus `Menu.ModifyMenu`; unit menus through `Menu.ModifyMenu` (option `useUnitHacks`); `FriendsFrame` through `HookScript`, and windows may anchor to it (it is not protected); link insertion through `hooksecurefunc("ChatEdit_InsertLink")` (EUI filters); popups only as `PSS_`-prefixed `StaticPopupDialogs` entries; Escape through `UISpecialFrames`. Anything else that touches a Blizzard frame, table or function needs Dan's OK first and a note in the PR naming the J rules it meets.
4. Menus use `MenuUtil` / `Menu.ModifyMenu` (Retail). Never `UIDropDownMenu`. Camelot paths feature-detect the Menu API and skip the menu when it is missing (as `PSS_BlizzardUI.lua` does).
5. PSS creates no secure frames and calls no protected functions. The decline calls (`DeclineGroup`, `DeclineGuild` / `C_GuildInfo.DeclineGuild`, `CancelDuel`) run from their invite events and stay feature-detected; `C_FriendList.SendWho` runs only straight from a click or keybind (it needs a hardware event). Keep it that way; a feature that would need a secure frame or a protected call is a design question for Dan.
6. **In-game checks for any change on a chat, unit or hook path** include a run with `/console addonChatRestrictionsForced 1` and `/console addonCombatRestrictionsForced 1`: no Lua errors, no blocked-action message, and lines that cannot be read pass through unfiltered.

