# Status and next step (2026-10-07)

## Where things stand
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
One window with the EllesmereUI port's layout, features and feel, drawn only with Blizzard's and our own resources, in three looks (option `uiSkin`: Blizzard (Default), Modern, Dark), the accent always the class colour. It replaces both `PourSocialScore_GUI` and `PourSocialScore_EllesmereUI`. Logic goes in `PourSocialScore_Libraries`, drawing in the new `PourSocialScore_UI`; `/pss tui` opens it until the cutover. Details: `09_PSS_UI_PROJECT.md`. Plan, decisions and look spec: scratch `docs/latest/ui uplift/` (history `docs/ui uplift/`).

| Stage | Dev | What | State |
| --- | --- | --- | --- |
| A1 | 3.4.0-dev001 | `PourSocialScore_UI` folder, loader part `UI`, option `uiSkin`, `/pss tui` opens the empty window in either look; `check_tui.lua`; TOC and PSS-names checks in `check_rules.sh` | Merged #88 |
| A2 | 3.4.0-dev002 to dev002_4 | Kit part 1 in Blizzard and Dark: text, heading, button, tick box, edit / number / search box, panel, scroll frame, tab row, tooltip; the `uiFont` option (Blizzard fonts, plus LibSharedMedia fonts read only when another addon loaded it); three looks (Blizzard (Default), Modern, Dark); class colour accent; Blizzard tab labels fixed; a temporary kit preview page | Merged #89 (to dev002); dev002_2 to _4 and docs in #90 |
| A2b | 3.4.0-dev003 | Kit part 2: drop-down and right-click menu (Blizzard's menus, or our Dark list), popups (confirm, copy, import), row list, pie; kit preview in three tabs | Merged #92 (dev003_2) |
| Modern | 3.4.0-dev004 | The Modern look after Blizzard's Social window: metal frame on black, divider and dark cards, straight gold-framed action-button plate for buttons and tabs (red to accept), minimal tick boxes, search-bar boxes, newer dialog border, Blizzard tabs; Blizzard where the art is missing (dev004_4) | Merged #93 |
| A3 | 3.4.0-dev005 | Libraries groundwork: `PSS_DetailQuery.lua` (pane numbers, period and type slices, totals view, overrides, class colour) and navigation, double-click and throttle in `PSS_ViewNav.lua`; `check_viewquery.lua` (pane numbers equal the core's counts on every save); Libraries +22.5 KB resident. The Events view query moved to B6 | Merged #94 |
| B1 | 3.4.0-dev006 (to dev006_2) | Window frame: the six tabs (each built on first open, a note until its stage), back / forward with mouse 4 / 5, the line by the arrows with links back, Escape up one level then closed, tab click resets, the last tab remembered (`windowPoints.PSS_WindowTab`); the kit preview moved to the harness (`tools/harness/kit_page.lua`) | PR open |
| B2 to D3 | dev007 to dev017 | The six tabs' contents, old-GUI-only features, cutover (the new files move into `PourSocialScore_GUI`), removal | Planned |

Fixes to 3.3.1 meanwhile would be `3.3.2-dev001`.

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
