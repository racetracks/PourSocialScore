# Status and next step (2026-10-08)

## Where things stand
- **Now (2026-10-08):** main = **3.4.0.15** (R2, PR #107 merged; B7, all six tabs of the new window, merged as 3.4.0-dev012 in #103). 3.3.1 is the live full release.
- **Build numbers** (`3.4.0.13`, Dan, 2026-10-08) merged as #104; R1 (3.4.0.14) #106; R2 (3.4.0.15) #107. **R3 (3.4.0.16) is on its PR.**
- **Code review** (scratch `docs/latest/code-review/01_REVIEW_AND_PLAN.md`, main at dev012): no high findings, 12 medium, about 20 low. It plans R1 to R3 before C1. **Dan answered its six decisions on 2026-10-08, all as recommended:** 1a secret message from a readable listed author still blocked and counted (02 10.1); 2a invite decline through the API only (02 10.3); 3a `RemoveMessagesByPredicate` OK (02 10.3); 4a R1 to R3 before C1; 5a core performance on a 3.4.1 line after 3.4.0; 6a cap stored guild members at **1500** per rule, with a migration (04 section 9).
- Project files are the scratch repo (Dan, 2026-10-08): saves `SavedVariables/<version>/`, plans `docs/latest/`, zips `releases/` and `latest/`. There is no `/mnt/project-files`.

History:
- `racetracks/PourSocialScore` main = **3.3.0-dev004** (`5c39f62`, PR #82 merged 2026-10-05 20:45Z). v3.2.0 is the last full release.
- 3.3.0-dev004 has **no GitHub release**: the Release run on main was cancelled (05). Dan chose 2026-10-07: skip it; dev004 stays test-zip only and dev005 publishes next.
- No addon work since 2026-10-05. 2026-10-07 was spent writing the general packs (baseline v4, scratch v2) and this pack; Dan said no code changes for that.
- Main is now **3.3.0-dev005** (PR #85 merged 2026-10-07 17:51Z): the bugfix for Retail 12.1's Social window. Dan then stamped it **3.3.1**, a full release, and closed the parity project (2026-10-07): the remaining stages are dropped.

## Closed project: native GUI parity (08), shipped as 3.3.1
| Dev | PR | What | State |
| --- | --- | --- | --- |
| 3.3.0-dev001 | #79 | Shared Events logic moved from the EUI folder to `PourSocialScore_Libraries/PSS_EventsQuery.lua` (issue #77 option b); `eui_compare.sh`; split check fixed for 3.x saves | Merged |
| 3.3.0-dev002 | #80 | One counting system: `PSS_BlockStats` removed from core (-12.1 KB), native reads `History.Recent*`, `blockStats` pruned on login, EUI filter all-time fixed; `check_match.lua` | Merged |
| 3.3.0-dev003 | #81 | Native Managed Communities parent row; `check_managed_row.lua` | Merged |
| 3.3.0-dev004 | #82 | Native totals pane with the period pie (`PSS_Pie.lua`, G9 copy, 11.4 KB); window 1290 wide (side-pane layout, the recommended option of a card Dan did not answer) | Merged; release not published |
| 3.3.0-dev005 | #85 | Bugfix: Retail 12.1 opens `SocialUIFrame` for the Friends key; core hooks it and FriendsFrame (Who tab), the window anchors to whichever opened (55 px clear of the Social side tabs) | Merged |

## Current project: the new PSS window (3.4.0)
One window with the EllesmereUI port's layout, features and feel, drawn only with Blizzard's and our own resources, in three looks (option `uiSkin`: Modern (Default from dev008_4), Classic (was Blizzard), Dark), the accent always the class colour. It replaces both `PourSocialScore_GUI` and `PourSocialScore_EllesmereUI`. Logic goes in `PourSocialScore_Libraries`, drawing in the new `PourSocialScore_UI`; `/pss tui` opens it until the cutover. Details: `09_PSS_UI_PROJECT.md`. Plan, decisions and look spec: scratch `docs/latest/ui uplift/` (history `docs/ui uplift/`).

| Stage | Dev | What | State |
| --- | --- | --- | --- |
| A1 | 3.4.0-dev001 | `PourSocialScore_UI` folder, loader part `UI`, option `uiSkin`, `/pss tui` opens the empty window in either look; `check_tui.lua`; TOC and PSS-names checks in `check_rules.sh` | Merged #88 |
| A2 | 3.4.0-dev002 to dev002_4 | Kit part 1 in Blizzard and Dark: text, heading, button, tick box, edit / number / search box, panel, scroll frame, tab row, tooltip; the `uiFont` option (Blizzard fonts, plus LibSharedMedia fonts read only when another addon loaded it); three looks (Blizzard (Default), Modern, Dark); class colour accent; Blizzard tab labels fixed; a temporary kit preview page | Merged #89 (to dev002); dev002_2 to _4 and docs in #90 |
| A2b | 3.4.0-dev003 | Kit part 2: drop-down and right-click menu (Blizzard's menus, or our Dark list), popups (confirm, copy, import), row list, pie; kit preview in three tabs | Merged #92 (dev003_2) |
| Modern | 3.4.0-dev004 | The Modern look after Blizzard's Social window: metal frame on black, divider and dark cards, straight gold-framed action-button plate for buttons and tabs (red to accept), minimal tick boxes, search-bar boxes, newer dialog border, Blizzard tabs; Blizzard where the art is missing (dev004_4) | Merged #93 |
| A3 | 3.4.0-dev005 | Libraries groundwork: `PSS_DetailQuery.lua` (pane numbers, period and type slices, totals view, overrides, class colour) and navigation, double-click and throttle in `PSS_ViewNav.lua`; `check_viewquery.lua` (pane numbers equal the core's counts on every save); Libraries +22.5 KB resident. The Events view query moved to B6 | Merged #94 |
| B1 | 3.4.0-dev006 (to dev006_2) | Window frame: the six tabs (each built on first open, a note until its stage), back / forward with mouse 4 / 5, the line by the arrows with links back, Escape up one level then closed, tab click resets, the last tab remembered (`windowPoints.PSS_WindowTab`); the kit preview moved to the harness (`tools/harness/kit_page.lua`) | Merged #96 |
| B2 | 3.4.0-dev007 | Player Ignore List tab: list, search, Add Player, the detail pane's three pages (Summary pie, Event History, View/Edit Rule), the list's totals; Libraries `PSS_PlayerView.lua`; `check_players.lua`; the close button and title raised above the frame's border (they were hidden in Blizzard and Modern) | Merged #97 |
| B3 | 3.4.0-dev008 to dev008_4 | Guild Ignore List part 1: the grouped list (Managed Communities, default lists, Guild Exclusion List, guilds), sort, search, selection, Scan All with its status tip, the Add / Exclude rows with Guild Search, the results picker, the list's totals; Libraries `PSS_GuildView.lua`; `check_guilds.lua`; Modern draws the frame's stone and streaks behind the tabs (dev008_2, _3); the streaks reach under the arrows' line in Classic and Modern, Blizzard renamed Classic and Modern made the default (dev008_4) | Merged #98 |
| B4 | 3.4.0-dev009 | Guild Ignore List part 2: the guild, default list, exclusion and member detail bodies, the members view (double-click or Members; Back and Escape return), Remove Guild and Remove Member confirms; `check_guilds.lua` extended | Merged #100 |
| B5 | 3.4.0-dev010 to dev010_2 | Chat Filters tab: list, editor (On, description, filter, Save / Copy / Remove / Reset Count), Test, link converter, Summary, Event History, totals; Libraries `PSS_FilterView.lua`; the link insert post-hook follows Retail 12.x's `ChatFrameUtil.InsertLink` (`ChatEdit_InsertLink` elsewhere; Dan's OK 2026-10-08, PSS 02 section 10.3); `check_filters.lua`; list cells kept to one line (dev010_2) | Merged #101 |
| B6 | 3.4.0-dev011 to dev011_3 | Events tab: Time (custom range), Types and Source drop-downs, search, sorting, links, copy, Reset Block History; opened from every pie, View Events and the panes' histories; Libraries `PSS_EventsView.lua` (the Events view query deferred from A3); `check_events.lua`; popups in the window's own frame and background (dev011_2, _3) | Merged #102 |
| B7 | 3.4.0-dev012 | Options tab (every option by section, search, the look and font) and Import/Export tab (parts, mode, Export, Import with Replace confirm); Libraries `PSS_OptionsView.lua`; `check_options.lua`; all six tabs built | Merged #103 |
| Versions | 3.4.0.13 | Build numbers replace `-devNNN` and `_N` (`release.yml`, `check_toc.sh`, `check_rules_eui.sh`, every TOC); no addon change | Merged #104 |
| R1 | 3.4.0.14 | Code review: secret values checked (target names through `M.PSS_UnitFullName`, channel args in CoreFilter, the link hook; a listed author's secret message blocked and counted, its text never kept), Escape on a popup or menu closes only that (`ns.EscapeCloses` / `ns.EscapeTaken`), Remove keeps the selected filter, no `SetItemRef` in combat, tooltip `IsForbidden`, guild invite declined through the API only; CI job `upgrades` runs `validate_all.sh`; `check_secrets.lua`; readme and docs | Merged #106 |
| R2 | 3.4.0.15 | Code review: Logging stays unloaded on guild removal and on removing a never-blocked member (the tidy runs when Logging loads), and the window never reopens on Events; options import validated and saved through `PSS_SetOpt`; the Events view drops its lines when its tab hides or the window closes (`View:Release`, a page's `release`), the window requests a GC on close; the members list wiped on close; block events recount only the guild rows on screen (`V:CountsChanged` / `V:FreshCounts`; 194.6 to 16.7 KB garbage per redraw on Dan's 3.2.0-dev011 save); the Scan All tip cached (19.3 to 0.3 KB per hover). L12 (`memberCount` off the saved record) moved to the 3.4.1 member cap migration (a save layout change; Dan's OK 2026-10-08) | Merged #107 |
| R3 | 3.4.0.16 | Code review: text fades through `SetAlpha` (L7); the tabs' core events through `ns.Listen`, registered only while the window shows, each page's `stale()` on open (L8; the look's `OPTION_CHANGED` stays always registered); logic moved to Libraries: `M.PSS_OverrideOptions` / `...OverrideValue`, `M.PSS_PlayerAllowed`, `M.PSS_GuildAllowed`, `M.PSS_GuildHistoryKey` / `M.PSS_MemberHistoryKey`, `M.PSS_MemberBlockTotal`, `v:SelectMember` / `v:SetView` / `v:GuildRemoved`, `M.PSS_GuildPickerToggle` / `...TickAll`, `M.PSS_IOSet` / `...SetMode` (L9); `M.PSS_ListMixin` in `PSS_ViewNav.lua`, which now loads before the views (L19); `table.insert` appends (L18); per-redraw tables (L17, window parts); `tui_tour.lua` / `tui_compare.sh` (identical in all three looks) | PR open |
| C1 | next build | Player Search (button beside Add Player, results picker like Guild Search's, add anyway), add your target when the box is empty, Prune with a confirm | Planned |
| C2 | next build | Right-click menus on rows (Menu API in Classic and Modern, our list in Dark) | Planned |
| D1 | next build | Switch-over: `/pss gui`, the Addon Compartment and Friends / Social docking open the new window | Planned |
| D2 | next build | The new files move into `PourSocialScore_GUI`; `PourSocialScore_UI`, `PourSocialScore_EllesmereUI` and the bridge deleted; `euiIntegration` pruned | Planned |
| D3 | next build | Polish from testing, readme, docs | Planned |
| Release | 3.4.0 | When Dan says it is done | |
| Next line | 3.4.1.1 on (Dan, 2026-10-08) | Core performance from the review: event-driven GC, `loadWhenQuiet` on events, capture events only when needed, stored guild members capped at 1500 per rule with a migration (and `memberCount` no longer saved, review L12; Dan's OK 2026-10-08), core placement moves | Planned |

Fixes to 3.3.1 meanwhile would be `3.3.2.1`. From 3.4.0.13 every build is `X.Y.Z.B` (the build number), not `-devNNN`.

## Waiting on Dan
1. Archive `racetracks/PourSocialScore-EllesmereUI` and close its PR #18.
2. Delete merged `claude/*` branches (Claude gets 403).
3. Whether the known rule deviations (01 section 5: idle GC timer, totals pane without opt-in, OnUpdate on hover) get fixed in a later line.
4. Close issue #78 (parity), now that the project is closed at 3.3.1.

## Open issues (addon repo)
#78 parity project (closed at 3.3.1; issue still open); #37 guild exclusion list is not saved (define its intent); #38 seeing a shipped-guild member loads the lists; #39 unload the GUI on close; #40 research whether a LoadOnDemand addon can unload; #44 clean up console output; #45 Questie-style upgrade output. #77 decided (option b) and done.

## Parked or offered
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
- Native-only features (Player Search, Prune, right-click menus, resizable columns) stay native-only for now (decision 5); a later project.
