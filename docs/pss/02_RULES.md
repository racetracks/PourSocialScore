# PourSocialScore: project rules (only what PSS adds to the baseline)

**The baseline's rules are mandatory** (the author, 2026-10-08). This file holds what is specific to PSS: the concrete values and the author's PSS decisions. PSS overrides a baseline rule **only** where section 12 (the Overrides table) lists it; any other difference is a bug to fix. Dates are when the author set them.

## 1. Code and style
1. Every folder indents with tabs.
2. Everything shared hangs on `M` via `PourSocialScore_NS` (the project's root table); use `M.ShowMsg`, `M.Trim` and the UIKit builders. Every file that uses `M` declares it as a local first (`local M = ns.M` or `addon.M`); there is no global `M` (`check_locals.lua`).
3. Core fires `M.Events`; UIs listen and write only through core setters (`tools/check_layers.lua` enforces it).
4. Core's two StaticPopup dialogs (`PSS_REASON`, the note; `PSS_PARTYWARN`, the party warning) stay Blizzard StaticPopups (11.8).
5. **Guild member fields are read through their accessors (core uplift S2):** `M.PSS_MemberCanon`, `M.PSS_MemberName`, `M.PSS_MemberGuildName`, `M.PSS_MemberWhenBlocked`, `M.PSS_MemberShipped`, `M.PSS_MemberPlayerKey`, and `History.CountTotal` (or `History.EnsureCounts`) for a saved counts table's total; a rule's member count from `M.PSS_GuildMemberCount`, never the saved `memberCount`. `tools/check_fields.lua` (rules check) fails the runtime fields or `memberCount` outside the accessor block.
6. **Simulate the client while coding (the author, 2026-10-09):** every change is driven through the harness's simulated WoW client as it is written, its real output read, changed behaviour gets a check that fails on `origin/main`, and the PR names what a simulation cannot show (11_PREFERENCES has the full text).

## 2. TOCs
- Title `|cff69ccf0PourSocialScore|r <Part>`.
- Core Notes are the author's wording: "Sometimes you dont wanna know when a man gotta slur a little". Never change Title or Notes unless asked.
- Every TOC: `## Category: PSS`, `## Group: PourSocialScore`, `## IconTexture: Interface\FriendsFrame\Battlenet-Portrait`.
- Base TOC interface `120007, 16001`; `_Mainline`; `_Camelot`. Every TOC in the repo carries one version.

## 3. Behaviour rules
- **Counting:** counters are never derived from log lines; nothing counted twice; guild rule blocks count only as guild blocks (the Chat Filters row shows "n/a"); a rule turned off disables every guild in it (`M.PSS_GuildRuleActive`).
- **A guild rule never blocks your own guild** (`M.PSS_IsOwnGuild`). Player list entries for people in your guild still block.
- **Removal** deletes all of a player's saved data. A player on a shipped guild list stays blocked with a member note.
- **W I G P C:** ticked = allowed; a new entry blocks everything; built-in filters start off.
- **What happens to anyone listed (the author, 2026-10-08):** by default no ignore response is sent, no decline messages are shown, and their duels and trades are declined (the Options tab sets the default). Any player, guild or guild member can be an exception; the window shows each as a tick box (ticked = it happens) marked "(exception)" where it differs from the default, and a member's default is its guild's. Stored as before: `opts[key]` holds an exception, nil the default.
- **Every number the window shows comes from the core's counters** ("this session" = since login or /reload). `check_viewquery.lua`, `check_stats.lua` and each tab's check gate it.
- Every window closes on Escape. The window's looks are Blizzard's (Modern, Classic) or our flat Dark (section 11).
- No guild discovery from mouseover or nameplates in combat.
- **Forward compatible saves (core uplift U3, plan 2.3, the author, 2026-10-08):** every field PSS saves is listed in `M.PSS_SCHEMA` (`PSS_Schema.lua`) in the PR that first saves it (`check_schema.lua` fails an unlisted one). Nothing is deleted by guesswork: only keys in `RETIRED` (`PSS_Upgrade.lua`) are dropped; a field, owner form, rule tag or built-in id this version does not know is kept and read as absent; a new layout of a whole store takes a higher `v` and an older version leaves a higher `v` untouched. A per-filter field goes in `filterID` or a table keyed by id, never a new parallel array. A rule this version cannot use is not applied, stays unchanged, is named after a version change and is exportable (`/pss export unused`). Exports carry `v` (format 2) and a record's unknown fields in `more`; the `PSS1` tag stays so older versions read them.

## 4. Garbage collection (the author, 2026-10-07)
**Event-driven:** no ticker, no idle timer, no wall-clock gate. GC runs only on request (`M.PSS_RequestGC`: login, /who scan, import, window close), and only out of combat, not dead, not in an encounter and not in a dungeon, raid, battleground or arena (`IsInInstance`). A request made at a bad moment waits for `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ALIVE` or `PLAYER_UNGHOST`, registered only while a request waits. A running cycle stops itself at the first frame that is busy. `PSS_Perf.lua` has no `C_Timer`; `loadWhenQuiet` (Logging) waits the same way (`History.LoadWhenQuiet`). `check_gc.lua` and `check_ondemand.lua` phase 3 gate it.

## 5. Core placement (G2, confirmed 2026-10-05 15:30Z)
> "minimal functions are stored in the poursocialscore core addon. it must only service as the core framework to handle the chat filtering and a launchpad for the addon. Functions that wont run in active memory or be considered as regularly active (chat filters etc) should be in the libraries folder."

So core = the chat filtering engine plus the loader, with what filtering needs (counting, outbox, setters, events). Anything not regularly active goes in `PourSocialScore_Libraries`, including code shared by both UIs. Core functions such as `PSS_PlayerQuery` stay only if they sit on a regularly active path; flag others as move candidates with a measured cost.

## 6. Front-end separation (2026-10-05)
There is one front end, `PourSocialScore_GUI`.
1. No application or service logic in `PourSocialScore_GUI`.
2. A second front end, if one is ever added, never reads or loads a file from another UI folder; a user never needs two (decision 5, the author: "I dont want the native gui reading any files from the ellesmereui port. We need to consider them independent so the user doesnt have to load multiple addons when we can accomodte it for them and just use shard functions for calls.").
3. UI resources a front end needs go in `PourSocialScore_Libraries`, or core if always-loaded code needs them.
4. Every UI reads `M.PSS_OPTIONS`; window state lives in `PSS_OptionsDB` (11.6).
5. **Logging loads only when called** (04 section 2).

## 7. Porting UI (G7 to G9, 2026-10-05)
- **G7:** every texture, font, template and API a port uses is ours or Blizzard's. Nothing from EllesmereUI or any other addon.
- **G8:** ports look as close as possible to the EllesmereUI port (git tag `v3.4.0.24`) while still looking like the Blizzard UI.
- **G9:** copying our own code is allowed when it gives a lower footprint (a copy, not shared code; example `PSS_Pie.lua`). EllesmereUI's own code is never copied.
- (G10, the EUI folder read only during parity work, ended with that folder; history in 08 and `reference/issues/eui-read-only-vs-logic-move.md`.)

## 8. Versions on PSS
- **Versions are `X.Y.Z.B` and the build number never resets (the author, 2026-10-08):** baseline 02 F applies as written. `sh tools/bump_version.sh build|release|line` sets every TOC, records the version in `versions.json` and adds the history section; `sh tools/bump_version.sh pr <number>` records the PR. `check_toc.sh` accepts only `X.Y.Z.B`; `check_rules.sh` runs `versions.py check` (in CI every entry needs its PR, a pull request's newest entry its own number) and fails a placeholder history bullet. A full release's notes are one summary of every change since the previous release (`CLAUDE.md`, Full releases).
- **Expected builds are written down and kept in step (the author, 2026-10-09):** the current plan gives every planned stage and release its expected build. A build added before them (a docs build or a fix) moves every later one up by one, and the PR that takes it updates every reference in the same PR: the plan's stage tables, 06, 13, `01_HANDOVER.md` (the next re-summary) and `CLAUDE.md`'s short form.
- A fix line is the next `X.Y.Z` with the next build number (after release 3.4.2.54, `3.4.3.55`); ask the author if a fix line is needed.
- Older names (`3.3.0-devNNN`, `-devN`, `_N` fixes, plain `3.3.1`) stay as they were in history.txt and on scratch; never use them for a new build.

## 9. Hosting on scratch (the author, 2026-10-08)
**Scratch is the project files (the author, 2026-10-08):** saves, plans, docs, zips and summaries all live there; there is no `/mnt/project-files`. Where a pack says "project files", read scratch.
Scratch is **`racetracks/Pour-Social-Score_Scratch`**; its rules and procedures are the scratch pack (`docs/scratch/`, rules in 05). The old `racetracks/scratch` is no longer used (links already given there stay valid).
- Test zips: `releases/PourSocialScore-<version>-<YYYY-MM-DD-hh-mm>.zip`; the same commit replaces the zip in `latest/` with it and updates the index rows. `sh tools/host_build.sh <scratch checkout>` does all of it from HEAD (`--no-commit` stages it so docs can join the same commit). `sh tools/host_tests.sh <scratch checkout> --log <validation log>` can build a tests bundle (`PourSocialScore-<version>-tests-<date>.zip`), but it is not hosted by default: the author does not run tests and does not want one (11_PREFERENCES); the test zip never holds `tools/`.
- Docs: the newest markdown in `docs/latest/<project>/` (these docs `docs/latest/pss-docs/`, the code map `docs/latest/code-map/`, release notes `docs/latest/release-notes/`, issue context `docs/latest/issues/`). Always read it first; refresh it whenever a plan or these docs change. Each docs release is zipped in the root of `docs/` (`<name>-<date>-vN.zip`); a project or feature release keeps a history folder `docs/<project>/`. Issue notes are docs too.
- Saves: `SavedVariables/<version>/`, with a line in `SavedVariables/README.md`.
- Packs: zipped in `docs/` (this pack is `pss-handover-<date>-vN`), listed in `docs/README.md`.
- Summaries: `summary/<project>-<YYYY-MM-DD-hh-mm>.md`.
- Update the root `readme.md` index whenever a folder's newest file changes; always reply with links.

## 10. Taint and secret values on PSS (baseline 02 J, 2026-10-07)
PSS is a chat filter: on Retail 12.x its inputs are the values most likely to be secret (chat event arguments under chat messaging lockdown, `UnitName` and GUIDs while restricted).
1. **Every value from a chat event, unit API or popup hook goes through `M.PSS_IsSecret` (`PSS_ChatBlock.lua`) before any compare, `find`, `#`, table index or table key.** A secret author, GUID or message means the line is not filtered and not counted: return false, never error. Copy the existing shape (`if type(name) ~= "string" or M.PSS_IsSecret(name) or name == "" then return end`). **Exception (code review decision 1, the author, 2026-10-08):** a line whose author is readable and listed but whose message is secret is still blocked and counted by the person rule; the counter and the outbox never see the message. Message-based rules (filters, words) still let a secret message through uncounted.
2. **A secret never reaches a counter, the outbox or SavedVariables.** Counting happens only on readable values (02 section 3); a skipped line is not a block.
3. **Blizzard state PSS may touch, and how:** chat filters only through `ChatFrame_AddMessageEventFilter`; ignore list changes only through `hooksecurefunc` on `C_FriendList` (`PSS_PlayerIgnoreList.lua`); the LFG list through `hooksecurefunc` plus `Menu.ModifyMenu`; unit menus through `Menu.ModifyMenu` (option `useUnitHacks`); `FriendsFrame` through `HookScript`, and windows may anchor to it (it is not protected); link insertion (Chat Filters) through `hooksecurefunc(ChatFrameUtil, "InsertLink")` where Retail 12.x has it (Blizzard's renamed link insert; the old name is only a deprecated copy there; the author, 2026-10-08), else `hooksecurefunc("ChatEdit_InsertLink")`; popups only as `PSS_`-prefixed `StaticPopupDialogs` entries; Escape through `UISpecialFrames`; the guild invite decline through the API only (`DeclineGuild` / `C_GuildInfo.DeclineGuild`) plus `StaticPopup_Hide("GUILD_INVITE")`, never pressing `GuildInviteFrame`'s buttons or hiding the frame (code review decision 2, the author, 2026-10-08. On Retail that window is not a StaticPopup: it closes on `GUILD_INVITE_CANCEL` or after its own 60 s, see 09 lessons); purging a newly listed person's lines from the chat frames through `RemoveMessagesByPredicate` (decision 3, the author, 2026-10-08). Anything else that touches a Blizzard frame, table or function needs the author's OK first and a note in the PR naming the J rules it meets.
4. Menus use `MenuUtil` / `Menu.ModifyMenu` (Retail). Never `UIDropDownMenu`. Camelot paths feature-detect the Menu API and skip the menu when it is missing (as `PSS_BlizzardUI.lua` does).
5. PSS creates no secure frames and calls no protected functions. The decline calls (`DeclineGroup`, `DeclineGuild` / `C_GuildInfo.DeclineGuild`, `CancelDuel`) run from their invite events and stay feature-detected; `C_FriendList.SendWho` runs only straight from a click or keybind (it needs a hardware event). Keep it that way; a feature that would need a secure frame or a protected call is a design question for the author.
6. **In-game checks for any change on a chat, unit or hook path** include a run with `/console addonChatRestrictionsForced 1` and `/console addonCombatRestrictionsForced 1`: no Lua errors, no blocked-action message, and lines that cannot be read pass through unfiltered.

## 11. The PSS window (the author, 2026-10-07; details in 09)
The full rule set is the **Interface** section of `CLAUDE.md` (one section, the author, 2026-10-08); this list is its short form.
1. The EllesmereUI port is the reference for every visual and layout choice; the old GUI is not authoritative on anything.
2. Logic in `PourSocialScore_Libraries`; drawing only in `PourSocialScore_GUI`. No `EUI` or `Ellesmere` names in new code (checked by `check_rules.sh`); never copy EllesmereUI's code or media.
3. Three looks with the same layout, features and feel, **listed in this order: Modern** (value 2, the default; Blizzard's new Social window art), then the options **Classic** (0, Blizzard's classic art) and **Dark** (1, the port's style in full). Every element works in all three (`CLAUDE.md` Interface, the first rule). Dark draws the window's own popups, menus and tooltips from our kit.
4. **The accent is always the player's class colour**, in every look; no option.
5. Fonts: the look's own, a Blizzard font, or a LibSharedMedia font read only when another addon loaded it. PSS ships no library.
6. Window state and new settings live in `PSS_OptionsDB` (routed `PourSocialScoreDB` keys); no new SavedVariables.
7. **Only the main window's title carries the addon's name.** Popup and dialog titles say what they ask ("Remove Player?"), never the addon name (the author, 2026-10-08).
8. **Core's note and party warning popups stay Blizzard StaticPopups in every look** (the author, 2026-10-08; core never loads the GUI folder for a popup; 1.4).
9. **EllesmereUI is the reference framework for UI elements (the author, 2026-10-08):** when more information is needed to build a UI element, check out `EllesmereGaming/EllesmereUI` (read only) and reference it wherever possible, as a mature framework for UI porting. Ported code is rewritten to suit our rules and uses it as a reference, never copied verbatim (03 section 0).

## 12. Overrides of the baseline (the author, 2026-10-08)
The baseline's rules are mandatory. These are the only places PSS differs, each with the author's OK; a breach waiting for a fix is listed with the line that fixes it. Add a row (with the author's OK and the date) before shipping anything else that differs; a difference not listed here is a bug.

### Approved overrides
| Baseline rule | PSS instead | The author's OK |
| --- | --- | --- |
| A10 No libraries | LibSharedMedia fonts are **read** for `uiFont`, only when another addon has loaded it; PSS ships no library and never creates `LibStub` (09 decision 8) | 2026-10-07 |
| C2 No behaviour change without opt-in | The window replaced both old windows for everyone at the cutover (D1, D2), in the Modern look by default (09 decisions 4 to 6) | 2026-10-07, Modern default 2026-10-08 |
| J4 Avoid calling Blizzard Lua that stores state | Newly listed people's lines are purged from the chat frames with `RemoveMessagesByPredicate` (10.3) | 2026-10-08 (code review decision 3) |
| J2 / J4 Never touch Blizzard state | The guild invite is declined through the API (`DeclineGuild` / `C_GuildInfo.DeclineGuild`) plus `StaticPopup_Hide("GUILD_INVITE")` (10.3) | 2026-10-08 (code review decision 2) |
| C2 No behaviour change without opt-in | A player ignored through Blizzard is moved into PSS (taken off Blizzard's list once confirmed, with a note) for everyone; PSS is authoritative over Blizzard's list (10_CORE_UPLIFT 2.7) | 2026-10-08 |
| C3 No OnUpdate polling | The window's pie (`PourSocialScore_GUI/PSS_Pie.lua`) runs OnUpdate only while the mouse is over it, so the hovered slice follows the cursor; it is cleared on leave | 2026-10-08 |
| E1 / E9 One step per PR and per session | The rest of the core uplift (S3, P1 to P6, W1 to W4) is one PR and one squashed build, 3.4.1.52, built by parallel threads; each stage proven on its own, the merged result fully validated. That delivery only (done; per-stage notes in `reference/combined-3.4.1.52/`) | 2026-10-09 (the author: "do all of the remainder of the core uplift in one merge") |

Blizzard hooks approved within the J rules (post-hooks, no override): `hooksecurefunc(ChatFrameUtil, "InsertLink")` on Retail 12.x (the author, 2026-10-08), and the rest of 10.3.

### Known breaches, with their fix
None.
