# PourSocialScore (PSS): handover (2026-10-07, main at 3.3.0-dev004)

## 1. Purpose
PourSocialScore is Dan's World of Warcraft chat moderation addon (GitHub `racetracks`, in-game author Boaties). Clients: Retail (Midnight, Interface **120007**) and Camelot (Interface **16001**).

What it does:
- **Player Ignore List.** Unlimited and account-wide (players, NPCs, whole servers), with notes, expiry, per-player **W I G P C** flags (whisper, invite, guild, party, chat; ticked = allowed), overrides, a detail pane, auto-decline of duels/trades/invites, and Player Search via /who.
- **Guild Ignore List.** /who scans split until each query returns under 50, Scan All (keybind), Custom Scan, 6 s cooldown, level cap, Guild Search, Guild Exclusion List.
- **Managed community lists.** Shipped guild lists ("Managed Communities - Asmongold", 119 guilds), switched on by Chat Filters guild rules, off by default. Built with `tools/PSS_BuildManaged.lua`.
- **Chat filter engine.** Built-in filters off by default. Custom rules use a tag language compiled to closures (about 30 us per line). A chat link converter on the Chat Filters tab.
- **Block history and counts.** Counts per session, per 24 h and all time; the block log (2000 lines) plus kept lines per listed person (04).
- **Two front ends:** the native Blizzard-styled window, and an EllesmereUI window when EllesmereUI is installed and the integration option is on (03).

Goal: "global" moderation through shared lists. Sharing happens through shipped lists and Import/Export.

## 2. Repos
| Repo | Role |
| --- | --- |
| `racetracks/PourSocialScore` (private) | The addon: seven folders, one version, `tools/` (rules checks, harness, managed list builder), readme.txt, history.txt, `.github/workflows` (release.yml, rules.yml) |
| `racetracks/Pour-Social-Score_Scratch` (private) | Hosting (layer 2 pack, `docs/scratch/`). Paths: `releases/` (test zips, versioned and dated), `latest/` (the newest test zip), `SavedVariables/<version>/` (saves), `docs/` (plans, issue notes, handover packs; newest markdown in `docs/latest/<project>/`), `summary/` (status summaries). Replaces `racetracks/scratch`, no longer used |
| `racetracks/PourSocialScore-EllesmereUI` | **Retired.** Held the EllesmereUI folder on its own 1.1 version line until 3.2.0-dev008 merged it into the addon repo. Dan is to archive it and close its PR #18. Never write to it |

Read only: `EllesmereGaming/EllesmereUI` (all rights reserved; 03), `Gethe/wow-ui-source`. References actually used on PSS: an ElvUI zip Dan uploaded (the load-on-demand split), a DBM AddOns list screenshot (Category/Group/coloured titles), a Questie zip (upgrade output idea, issue #45), wago.tools, and the Warcraft Wiki reference set Dan uploaded on 2026-10-07 (`docs/baseline/reference/wow-api/`; rules in baseline 02 J and PSS 02 section 10).

## 3. Folders (one release zip holds all seven)
| Folder | Loads | Holds |
| --- | --- | --- |
| `PourSocialScore` (core) | Always | Chat filtering engine, block counting, outbox, setters, events, loader, options definitions, the EUI bridge, upgrades, GC helper. SavedVariables `PourSocialScoreDB` (upgrade record, outbox, recent counts, sessionStart) |
| `PourSocialScore_Options` | Always | Data only: `PSS_OptionsDB`, `PSS_PlayersDB`, `PSS_GuildsDB`, `PSS_RulesDB`, `PSS_CountsDB` |
| `PourSocialScore_GUI` | On demand | Native window: PSS_UI, PSS_UIKit, PSS_Widgets, PSS_PlayerDetail, PSS_GuildUI, PSS_ChatHistoryUI, PSS_OptionsUI, PSS_ImportExportUI, PSS_WhoisHarvestUI, PSS_Pie |
| `PourSocialScore_Libraries` | On demand | Shared logic for both UIs: PSS_Commands, PSS_GuildQuery, PSS_FilterQuery, PSS_TotalsQuery, PSS_EventsQuery, PSS_ImportExport |
| `PourSocialScore_Logging` | On demand, only when logs are called | `PSS_LoggingDB` (blockLog, blockKeep); PSS_SavedLog.lua, PSS_LoggingData.lua |
| `PourSocialScore_Communities` | On demand | Packed shipped lists (~460 KB) |
| `PourSocialScore_EllesmereUI` | On demand, only when the integration is on | The EllesmereUI window (03); `PSS_EllesmereUIDB`. Deleted at the 3.4.0 cutover (09) |
| `PourSocialScore_UI` (from 3.4.0-dev001) | On demand, `/pss tui` only | The new PSS window while it is built (09): PSS_Skin, PSS_Kit, PSS_Tooltip, PSS_Menu, PSS_Popups, PSS_Rows, PSS_Pie, PSS_Detail, PSS_History, PSS_Players, PSS_Guilds, PSS_Filters, PSS_Events, PSS_Options, PSS_Window. Drawing only; no SavedVariables. Its files move into `PourSocialScore_GUI` at the cutover |

## 4. Real names (the project's own objects)
- **Namespace:** everything hangs on `M`, shared through the global `PourSocialScore_NS`. Private file tables are `ns` in the EUI folder.
- **Events:** `M.Events` (core bus). UIs listen (for example `OPTION_CHANGED`) and write through core setters.
- **Loader** (`PSS_Loader.lua`): `M.PSS_PARTS`; `NEEDS = {GUI="Libraries", EllesmereUI="Libraries", UI="Libraries"}`; `M.PSS_Need(key)` loads a part and what it needs; a part whose version differs from core's prints a warning. Logging: `M.PSS_LoadLogging()`.
- **Options:** `M.PSS_OPTIONS` (one table, both UIs render from it); read `M.PSS_Opt`, write `M.PSS_SetOpt`; only non-defaults stored.
- **Helpers and kit:** `M.ShowMsg`, `M.Trim`; UIKit `UI.CreateWindow`, `UI.InputBox`, `UI.NumberBox`, `UI.TextArea`, `UI.ScrollList`.
- **Counting and history:** `History.*` (04); totals `M.PSS_RecentListStats`, `M.PSS_ListTotals` (Libraries).
- **Guild rules:** `M.PSS_GuildRuleActive`, `M.PSS_IsOwnGuild`.
- **GC helper:** `PSS_Perf.lua` (stepped collection; option `gcEnabled`).
- **Commands:** `/pss`, `/pss gui`, `/pss gui force`, `/pss eui`, `/pss eui enable|disable`; `/pss tui` (the new window, 3.4.0, until the cutover).
- **New window (09):** looks `M.PSS_UISkin()` (option `uiSkin`), accent `M.PSS_UIAccent()` (class colour), font `M.PSS_UIFontPath()` / `M.PSS_UIFontChoices()` (option `uiFont`), place `M.PSS_UIPlace` / `M.PSS_SetUIPlace` (Libraries `PSS_ViewNav.lua`); window `PSS_Window`, entry `M.PSS_TUI`.

## 5. Crucial context
- Three TOCs per folder; one combined TOC broke Camelot in 3.0.0-dev6.
- **Measured hot spots:** `PSS_GetGuildBlockCounts`, the shipped member walk and `PSS_GetMemberBlockCounts` make about 200 to 350 KB of garbage per full pass on Dan's save. An estimate of 6 to 8 KB once measured 22 KB.
- **Known gaps:** removing a guild member still loads Logging. Full parity was not reached; the project closed at 3.3.1 (08).
- **Known deviations from the 2026-10-07 rules** (recorded only; Dan said not to change code for them): `PSS_Perf.lua` still runs a 10-minute idle GC cycle and a heap-growth trigger (the rule is now event-driven, 02 section 4); the dev004 totals pane shows for everyone without an opt-in; `PSS_Pie.lua` and a UIKit helper use OnUpdate while hovered or dragging. Raise them when the related code is next touched.

## 6. Plans and status
| Plan | Status |
| --- | --- |
| 2.0 line (to 2.0.44) | Done |
| Dashboard tab (2.0 era) | Paused, branch `claude/project-thread-pa7y7o` |
| Global moderation ideas (sync, curated lists, scoring) | Not started |
| 3.0 load-on-demand split | Done, v3.0.0 |
| EllesmereUI integration E.1 to E.7 | Done, v3.1.0 |
| Detail pane redesign, log every line, grouped save, EUI merged into the repo, EUI navigation, Events tab | Done, **v3.2.0 (last full release, 2026-10-05)** |
| Native GUI parity with the EllesmereUI window (3.3.0, issue #78) | Closed at **v3.3.1** (2026-10-07): dev001 to dev005 shipped, the rest dropped. 08 and 06 |
| **The new PSS window (3.4.0)**: one window in the port's layout, three looks, replaces both old windows | **Current**, started 2026-10-07. 09 and 06; plan on scratch `docs/latest/ui uplift/` |

## 7. Observations about Dan on this project
Beyond baseline 07:
- Reads GitHub Releases himself; production is explicit ("make 3.2.0 a release not a pre release").
- Uploads WTF saves and names the version ("this is a 3.0.0 save").
- Answers decision cards; when a card is unanswered, the PR is built on the recommended option and says so (dev004's layout).
- Asked for code review passes before merging stacks in 3.2.0.
