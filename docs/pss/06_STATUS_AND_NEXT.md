# Status and next step (2026-10-09)

Kept short and current: every PR updates it (baseline 02 E10). History up to 3.4.1.30 is in `reference/06_status-history-to-3.4.1.30.md`. The addon as it works is in `01_HANDOVER.md`; the current plan is `10_CORE_UPLIFT.md`.

## Now
- **Live release: 3.4.0.29** (full, the new PSS window; mirrored to `racetracks/Pour-Social-Score`). **Main: 3.4.1.49** (S1, PR #139); **S2 open: 3.4.1.50, PR #140**.
- **Current project: core uplift** (`10_CORE_UPLIFT.md`, locked by Dan on 2026-10-08). It runs on three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy.
- **S2, 3.4.1.50** (PR #140; invisible): accessors for the guild member fields S3 stops saving. `M.PSS_MemberCanon`, `M.PSS_MemberName`, `M.PSS_MemberGuildName`, `M.PSS_MemberWhenBlocked`, `M.PSS_MemberShipped`, `M.PSS_MemberPlayerKey` (one block in core `PSS_GuildIgnoreList.lua`), `History.CountTotal` for every saved total, and no reader of the saved `memberCount`. `tools/check_fields.lua` (rules check) fails the runtime fields or `memberCount` outside the block. 50 saves byte-identical with main; `tui_compare.sh` identical; +5.3 KB resident; `check_accessors.lua`. **Dan split the stage (decision 26):** the player flags, list arrays and log `m` are S2b. Details: `10_CORE_UPLIFT.md` 2.2 "Done in S2".
- **S1, 3.4.1.49** (merged, PR #139; invisible): purge by owner. `History.ClearOwner` replaces the six owner clears; with Logging not loaded a removal drops the owner's waiting lines and marks them in `PourSocialScoreDB.purge` (cap 200), applied when Logging loads, so a removal never loads Logging. 3.43 ms and 1378 KB garbage to 36 us and none per owner (keep full); 50 saves byte-identical with main; `check_purge.lua`. Details: `10_CORE_UPLIFT.md` 2.2 "Done in S1".
- **U3 fix, 3.4.1.48** (merged, PR #138): 3.4.1.47's in-game checks 1, 2, 4, 5 and 7 passed; 3 (`/pss export unused` did nothing) and 6 (Export gave no string) failed, both because `PSS_Popups.lua` used `M` without a `local M`, which stopped the GUI folder loading. Fixed; the harness no longer gives addon code a global `M` (`run.lua`), and `check_locals.lua` in the rules check fails a file that uses `M` without a local. Decision 25: every later expected build moves up one.
- **U3, 3.4.1.47** (merged, PR #138): forward compatibility. `M.PSS_SCHEMA` (core `PSS_Schema.lua`) lists every saved field; `check_schema.lua` fails an unlisted one (rules check and every harness save). Rules this version cannot use (a filter tag, a guild rule's unknown list or field, an unknown setting) are not applied, kept, counted on the report (or after the downgrade line) and copied out by `/pss export unused`. Export format 2 carries unknown fields (`more`); 3.4.0.29 still imports it. The tidy, the filter arrays, the built-in tables, a newer block log and recent table no longer drop a newer version's data. `check_forward.lua`; 50 saves byte-identical with main; +10.5 KB resident after login. Details: `10_CORE_UPLIFT.md` 2.3 "Done in U3".
- **U2, 3.4.1.46** (merged, PR #137; no in-game result reported): the upgrade report. The first login after an update prints a head line, a line per feature that changed, the cleanup line always, then "Saved data upgraded to X (step N)."; a downgrade prints one line and keeps the newer version; a paused step prints a red line. No save size on the cleanup line (S3 decides). `check_upgrade_report.lua`; saves byte-identical with main (50); +7.1 KB resident. Details: `10_CORE_UPLIFT.md` 2.4 "Done in U2".
- **Done:** U1 (3.4.1.45, below), F2 (3.4.1.44), F1 (3.4.1.42), Fix and Fix 2 (3.4.1.40, 3.4.1.41: the Guilds tab detail pane), N1 (3.4.1.32), N2 (3.4.1.33), plan B (3.4.1.34, docs only), B1 (3.4.1.35: PSS authoritative over Blizzard's ignore list, per-player tick, upgrade step 8), B2 (3.4.1.36: the right-click "PSS" header with Block Player / Block Guild), N3 (3.4.1.37: shipped lists rebuilt, 7634 to 7438 entries).
- **F1, 3.4.1.42** (merged, PR #131): N40 expiry applied by itself (`M.PSS_ExpireEntries`), N41 option hooks without a /reload, N42 `[talent]` tag, N45 Import Replace keeps the shipped rules (`M.PSS_ClearGuildRules`), N46 listener errors shown once (`M.PSS_NoteListenerError`), N47 group warning from the current roster, N48 `/pss list` nil note. Harness `check_fixes.lua`. In game (Dan, 2026-10-09): checks 1, 2, 3, 5, 6, 8, 10 pass, 9 assumed; checks 4 and 7 are left for later as #132 and #133.
- **F2, 3.4.1.44** (merged, PR #135; in-game checks 1 to 6 pass, Dan, 2026-10-09): G21 a blocked line no longer fires `FILTERS_CHANGED` (the Filters tab redraws and re-sorts at most 4 times a second), G26 the Guilds tab hears `FILTERS_CHANGED` (the rule dim follows), G27 Dark right-click menus up to 400 px with the width from every entry, G28 the Modern art check covers all 19 atlases. Dan, 2026-10-09: the Blocked sort still follows; the cap is 400.
- **U1, 3.4.1.45** (merged, PR #136; invisible, no in-game result reported): the upgrade step registry, invisible. Steps have ids and feature-tagged parts (step 1 split in 2.0's order), one `RETIRED` list dropped every login after the data parts, counts per feature returned by `M.PSS_RunUpgradeData` on a login that reports, `M.PSS_VersionOrder`. Saves and chat byte-identical with main on 50 saves including the four real ones (`same_saves.sh`, new); `check_upgrade_steps.lua` (new); +9.6 KB resident after login. Details: `10_CORE_UPLIFT.md` 2.4 "Done in U1".
- **Next:** S2b (3.4.1.51), once S2 merges: the player W I G P C accessors, a layout for the player list arrays (`notes`, `typeList`, `syncInfo`; holes break `table.remove`, so ask Dan which layout first) and the log group's `m` (decision 26; appendix 03). Any field S2b or S3 saves goes in `M.PSS_SCHEMA` in the same PR (U3). Expected builds to the end of the project are in `10_CORE_UPLIFT.md` section 4: S3 3.4.1.52, the 3.4.1 release 3.4.1.53, 3.4.2 runs 3.4.2.54 to 3.4.2.60, 3.4.3 runs 3.4.3.61 to 3.4.3.65 (decisions 24 to 26).
- The closed projects: the PSS window (3.4.0, `09_PSS_UI_PROJECT.md`; its code map and lessons stay the reference for the window) and parity (3.3.1, `08`).

## Waiting on Dan
Nothing (the EllesmereUI repo archived, its PR #18 closed, merged branches deleted and issue #78 closed, Dan, 2026-10-08).

## Known breaches
In 02 section 12, each with its fix line. The idle GC cycle is fixed by core uplift P2 (3.4.2).

## Open issues (addon repo)
- #37: the guild exclusion list is not saved (its intent needs defining).
- #38: seeing a shipped-guild member loads the lists.
- #39: unload the GUI on close.
- #40: research whether a LoadOnDemand addon can unload.
- #44: clean up console output.
- #45: Questie-style upgrade output (core uplift U2).
- #132: test later, the Group Finder option without a /reload (F1 check 4; needs a character that can use the Group Finder).
- #133: test later, the party warning names only who is in the group now (F1 check 7).

## Parked
- Pack the in-play chat filter log (offered, not started).
- Dashboard / overview page (paused, branch `claude/project-thread-pa7y7o`).
