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

## Next step
None planned on PSS: Dan has other plans. Fixes to 3.3.1 start `3.3.2-dev001` (or ask Dan whether a fix goes straight out as `3.3.2`).

## Waiting on Dan
1. Archive `racetracks/PourSocialScore-EllesmereUI` and close its PR #18.
2. Delete merged `claude/*` branches (Claude gets 403).
3. Whether the known rule deviations (01 section 5: idle GC timer, totals pane without opt-in, OnUpdate on hover) get fixed in a later line.
4. Close issue #78 (parity), now that the project is closed at 3.3.1.

## Open issues (addon repo)
#78 parity project (closed at 3.3.1; issue still open); #37 guild exclusion list is not saved (define its intent); #38 seeing a shipped-guild member loads the lists; #39 unload the GUI on close; #40 research whether a LoadOnDemand addon can unload; #44 clean up console output; #45 Questie-style upgrade output. #77 decided (option b) and done.

## Parked or offered
- Scrolling Battle Text for WoW Forever only (MSBT behaviour, 3.4.0): design and stages in `09_SCROLLING_TEXT.md`; Dan answered most decisions 2026-10-07, open ones in its section 6; next is stage 0 (Dan's in-game checks) then 3.4.0-dev001.
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
- Native-only features (Player Search, Prune, right-click menus, resizable columns) stay native-only for now (decision 5); a later project.
