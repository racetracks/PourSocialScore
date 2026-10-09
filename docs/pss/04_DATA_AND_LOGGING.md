# Data and logging

## 1. SavedVariables by folder
| Folder | SavedVariables | Holds |
| --- | --- | --- |
| core | `PourSocialScoreDB` | upgrade record, outbox, `purge` marks (S1), `recent` counts, sessionStart |
| _Options | `PSS_OptionsDB`, `PSS_PlayersDB`, `PSS_GuildsDB`, `PSS_RulesDB`, `PSS_CountsDB` | options (non-defaults), lists, rules, all-time counts |
| _Logging | `PSS_LoggingDB` | `blockLog`, `blockKeep` |

Every saved field is in the schema map (`PSS_Schema.lua`, 02 section 3). Upgrades: numbered steps in `PSS_Upgrade.lua` (10_CORE_UPLIFT), run once, tracked in the upgrade record; Logging-side cleanups run when Logging loads. Window state lives in `PSS_OptionsDB`; an old save's `PSS_EllesmereUIDB` is no longer read.

## 2. Logging loads only when called
`PourSocialScore_Logging` holds PSS_LoggingDB (blockLog, blockKeep), `PSS_SavedLog.lua` (packs the log at logout, rebuilds it on load) and `PSS_LoggingData.lua`. Keeping the folder unloaded keeps its SavedVariables out of memory.

Logging loads only when:
- something reads history (the window's Events tab or a detail pane's history), or
- the outbox reaches `OUTBOX_LOAD = 200` waiting lines **and** it is a quiet moment (not in combat, not in an instance), or
- code calls `M.PSS_LoadLogging()` directly.

That load is the moment waiting lines move into the log. **Lines move to the log framework only when logs are called.** Removing or resetting anyone never loads Logging (core uplift S1): `History.ClearOwner` drops the owner's waiting lines and marks the owner in `PourSocialScoreDB.purge` (at most `History.PURGE_CAP` = 200; when full, Logging loads and clears at once).

## 3. The outbox (core, always loaded)
- A block is **counted at once** (session, recent 24 h, all time), never later from log lines.
- Its line waits in `PourSocialScoreDB.outbox` while Logging is not loaded.
- The outbox is capped at `History.Cap()` lines, so it cannot grow without bound.
- `History.Log` / `History.Keep` and every reader call the loader first.
- `M.PSS_LoadLogging()` order: PrepareSavedData -> UnpackSaved (rebuild from the grouped save) -> KeepToLog (one-time move back, flag `logAllV1`) -> ApplyPurge (the `purge` marks' lines go, the marks are cleared) -> outbox into the log -> CapKeep -> Trim -> Tidy.

## 4. The log and the keep
- **blockLog:** every blocked line (`History.LOG_ALL = true`), the newest `History.Cap()` (2000 by default). Players, guild members, chat filters, world and guild chat.
- **blockKeep:** when a listed player's or guild member's line is trimmed off the log, their newest 10 text lines (whisper, party, raid, raid warning, BG), 5 party invites and 5 guild invites move here. World and guild chat is let go. `KEEP_TOTAL = 2000` lines across everyone, oldest first, trimmed in 5% batches. A line is in exactly one place.
- In play: the log is an array of entry tables; the keep is packed per person (`"<w|p|i|g><ts>\t<event>\t<channel>\t<message>"`; `KEPT_EVENTS` is append-only).

## 5. The saved format (grouped per owner)
At logout and /reload `History.PackForSave` writes both the log and the keep as one table grouped by owner:
```
blockLog = { v = 2, [owner] = {
    m = name, n = { other names }, gk = guild rule key, r = rule tag,
    c = the group's usual channel, k = how many lines are kept lines (first),
    [1..] = "<type><time>\t<event>\t<channel>\t<who>\t<message>" } }
```
Times are the first line's time then `+<seconds>`; a repeated message is `"\2"`. `UnpackSaved` rebuilds the in-play tables when Logging loads. Nothing in PSS_SavedLog.lua runs unless Logging was loaded that session.
A log saved with `v` above 2 (a newer version's layout) is kept as it is (U3): chat says so once, blocks are still counted, and that session's lines are not added to it. A new layout of the log takes `v = 3`.

Measured on the author's save: grouping took 2000 log lines from 633 KB to 203 KB; packing the keep took 2000 kept lines from 806 KB to 165 KB.

## 6. Recent and session counts (core, always loaded)
- `PourSocialScoreDB.recent = { v=2, last, day={[owner]=n}, [1..144]={[cat]={[owner]=n}} }`: 144 slots of 10 minutes, time-major. Chosen by the author after a benchmark.
- `day` is the running 24 h total per owner; expired slots subtract from it.
- A recent table with `v` above 2 (a newer version's) is left as it is and nothing is counted in it (U3); only an untyped (oldest) table is dropped.
- Session counts are memory only and reset on login and /reload. `sessionCat[cat][owner]` gives the session pie its type breakdown.
- Owner keys: `p:` players, `g:` guild members, `G:<gkey>` guild totals, `f:` filters.
- Readers: `History.CountRecent`, `RecentCounts`, `RecentSlots`, `Where`, `ForgetRecent`, `StartSession`, `SessionStart`; `History.RecentByCat` and `RecentByCatData` live in Libraries `PSS_TotalsQuery.lua`.
- History shows "Data expired from logs" rows per type per 10-minute slot where counts exceed stored lines, and "Not stored" rows where nothing is kept.

## 7. Own guild
`M.PSS_IsOwnGuild(actualGuild)`: a guild rule never blocks your own guild. Player list entries still block. Test: `check_ownguild.lua`.

## 8. Validation
`check_keep.lua`, `check_ondemand.lua`, `check_recent.lua`, `check_saveddata.lua`, `check_growth.lua`, `check_savedlog.lua`, `check_purge.lua`, `check_schema.lua`, `check_forward.lua`, and `validate_all.sh` against every real save below (07).

Counting has one source: the session, 24 h and all-time numbers come from `History.Recent*` and the counts store, read through `M.PSS_RecentListStats` and `M.PSS_ListTotals` (Libraries). The old hourly `blockStats` table is retired (dropped by the `RETIRED` list; 08 decision 1).

Not started: pack the in-play chat filter log like the keep (06, Parked).

## Real saves (scratch `SavedVariables/<version>/`, listed in its README)
| Version | Files | Notes |
| --- | --- | --- |
| 2.0.44 | PourSocialScore.lua (1.09 MB) | Before the split: one file holds everything |
| 3.0.0 | core (151 B), _Options (365 KB), _Logging (745 KB) | First split. Its upgrade record is dated after the dev011 one |
| 3.2.0-dev011 | core (5.8 KB), _Options (372 KB), _Logging (224 KB), _EllesmereUI (137 B) | Grouped log (178 owners) |
| 3.4.0.28 | core (19 KB), _Options (398 KB), _Logging (212 KB) | First save from the one window; Camelot names with spaces |
| 3.4.1.50 | core (6.3 KB), _Options (394 KB), _Logging (202 KB) | First save with listed players; two planted "Newer test" filters (unusable-rule check); Camelot |
| 3.4.2.54 | core (13 KB), _Options (214 KB), _Logging (198 KB) | First save in the core uplift's sparse layout (`list` records, schema); player list empty, 10 names in `delList`; Camelot |

Folders are named by the save's `upgrade.version` (the version last run). `sh tools/harness/build_saves.sh <scratch checkout> <out dir>` concatenates each 3.x set into `<out dir>/<version>/PourSocialScore.lua`; 2.0.44 is copied as is. The split check in validate_all.sh only takes 2.0-layout saves (no `PSS_OptionsDB`).
