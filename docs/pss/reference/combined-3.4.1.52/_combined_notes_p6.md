# P6 notes (core placement; not for the final docs as they stand)

Measured on the 3.4.0.28 real save, harness, resident KB after login and a full collect (core only; Libraries not loaded), plus compiled bytes (`luac -s`) of the whole folder.

| Move | Core resident after login | Core compiled | Libraries compiled | Libraries load |
| --- | --- | --- | --- | --- |
| base (origin/main 3.4.1.51) | 2935.3 KB | 354065 | 148166 | 4.7 ms, +333.1 KB |
| 1. PlayerQuery rows/sort/removal + `M.prettyServer` (N38, L20) -> `PSS_PlayerRows.lua` | 2906.6 (-28.7) | 339782 | 162619 | 5.3 ms, +362.0 |
| 2. `M.PSS_Validate`, `M.PSS_PrintValidation` (N37) -> `PSS_Validate.lua` | 2889.9 (-16.7) | 330762 | 171896 | 5.2 ms, +378.9 |
| 3. `PSS_WhoisHarvest.lua` (scan planner) | 2872.3 (-17.6) | 323015 | 180003 | 5.7 ms, +396.8 |
| Total | -63.0 KB | -31050 | +31837 | about +1 ms, +63.7 KB, only when Libraries loads |

Load times are the harness's `os.clock` around `M.PSS_Need("Libraries")` (noisy, 4.5 to 5.7 ms in every run); the extra resident cost shows only after Libraries loads (a window, a command, a scan).

## What stayed in core
- `PSS_PlayerQuery.lua` (core, now 20 lines): `M.PSS_PlayersChanged`, `M.PSS_IsGuildListed` (menu clicks in `PSS_BlizzardUI.lua`) and `M.PSS_Stub`s for the six moved list calls (a caller that gets there first loads Libraries; harness scripts rely on this).
- `PSS_SavedData.lua`: stubs for `M.PSS_Validate` and `M.PSS_PrintValidation`. The before/after count there now runs only for a login where keys move and the save is not new or reset (`opts.wipe`, or `opts.quiet` with `opts.startup`); a new save skips it, so a fresh install loads nothing extra. A 2.0 save moving keys loads Libraries once at that login (N37's plan).
- `PSS_Whois.lua`: `M.PSS_WHO_CAP`, the key binding globals (`BINDING_*`, `PSS_ScanAllBinding`) and stubs for `PSS_HarvestNext`, `PSS_HarvestSent`, `PSS_HarvestAnswered`, `PSS_CapWhoFilter`, `PSS_ScanAll`.

## Skipped (reported, not moved)
- `/pss mem` (`PSS_Perf.lua`, 19 KB): pays, but it reads Perf's local GC state (`busyReason`, `IDLE_INTERVAL`, `heapKB`) that P2 rewrites. Do it after P2 merges (it needs `M.PSS_GCState` plus a small accessor).
- `M.SyncIgnoreList` and `M.PruneIgnoreList`: Sync toggles the file-local hook guard (`pssHookGuard`) around Blizzard's ignore calls and uses five other file locals; moving it would export those. The J rules make that not worth the risk for about 10 KB. Prune is about 1 KB.
- `M.PSS_AddCapturedGuild` and `M.PSS_ReconcileGuildMembers` (21 KB, `PSS_GuildIgnoreList.lua`): they share a dozen file locals with the member code S3 is changing (`mergeMemberRecord`, the member accessors), and core's scan finish calls Reconcile. Do after S3.
- `M.PSS_ExplainPerson` (3.4 KB): uses `lookupPeople` and `canonPlayer`, locals of `PSS_ChatBlock.lua` (P4's file).
- Legacy import (`PourSocialScore.lua`, under 2 KB resident) and Guild Search save (`saveGuildSearch`, needs `addWhoResultToGuildMember`): too small to pay.
- `History.MigrateFilterList` (11.6 KB): runs every login through `PSS_ExpandFilters`; it would need a guard on the upgrade record first. Not a pure move.
- Upgrade steps and `M.PSS_VersionOrder`, the unusable-rules code and the schema map: left in `PSS_Upgrade.lua` / `PSS_Schema.lua` (S3's files).

## Shared files touched
`PSS_Globals.lua` (realm block removed), `PSS_PlayerQuery.lua`, `PSS_Upgrade.lua` (the validation block at the end removed), `PSS_SavedData.lua`, `PSS_Whois.lua`, the three core TOCs (WhoisHarvest line), the three Libraries TOCs, `tools/check_layers.lua`. Docs not updated: `12_CODE_MAP.md`, `10_CORE_UPLIFT.md` P6 row, 06.
