# Status and next step (2026-10-07)

## Where things stand
- `racetracks/PourSocialScore` main = **3.3.0-dev004** (`5c39f62`, PR #82 merged 2026-10-05 20:45Z). v3.2.0 is the last full release.
- 3.3.0-dev004 has **no GitHub release**: the Release run on main was cancelled (05). Needs a manual run or is skipped in favour of dev005; Dan to choose.
- No addon work since 2026-10-05. 2026-10-07 was spent writing the general packs (baseline v4, scratch v2) and this pack; Dan said no code changes for that.
- Next dev number: **3.3.0-dev005**.

## The current project: native GUI parity (08)
| Dev | PR | What | State |
| --- | --- | --- | --- |
| 3.3.0-dev001 | #79 | Shared Events logic moved from the EUI folder to `PourSocialScore_Libraries/PSS_EventsQuery.lua` (issue #77 option b); `eui_compare.sh`; split check fixed for 3.x saves | Merged |
| 3.3.0-dev002 | #80 | One counting system: `PSS_BlockStats` removed from core (-12.1 KB), native reads `History.Recent*`, `blockStats` pruned on login, EUI filter all-time fixed; `check_match.lua` | Merged |
| 3.3.0-dev003 | #81 | Native Managed Communities parent row; `check_managed_row.lua` | Merged |
| 3.3.0-dev004 | #82 | Native totals pane with the period pie (`PSS_Pie.lua`, G9 copy, 11.4 KB); window 1290 wide (side-pane layout, the recommended option of a card Dan did not answer) | Merged; release not published |

## Next step
**3.3.0-dev005: type pie and type ticks** in the totals pane (as EUI's `ns.NewTypePie` and shared `typeOff`); ticks filter the period pie; numbers match the EUI window. Then the rest of the stage table in 08.

## Waiting on Dan
1. dev004 release: run the Release workflow by hand, or skip to dev005.
2. Archive `racetracks/PourSocialScore-EllesmereUI` and close its PR #18.
3. Delete merged `claude/*` branches (Claude gets 403).
4. Whether the known rule deviations (01 section 5: idle GC timer, totals pane without opt-in, OnUpdate on hover) get fixed inside the parity line or later.

## Open issues (addon repo)
#78 parity project; #37 guild exclusion list is not saved (define its intent); #38 seeing a shipped-guild member loads the lists; #39 unload the GUI on close; #40 research whether a LoadOnDemand addon can unload; #44 clean up console output; #45 Questie-style upgrade output. #77 decided (option b) and done.

## Parked or offered
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
- Native-only features (Player Search, Prune, right-click menus, resizable columns) stay native-only for now (decision 5); a later project.
