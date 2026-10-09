# Status and next step (2026-10-09)

Kept short and current: every PR updates it (baseline 02 E10). History up to 3.4.1.30 is in `reference/06_status-history-to-3.4.1.30.md`. The addon as it works is in `01_HANDOVER.md`; the current plan is `10_CORE_UPLIFT.md`.

## Now
- **Live release: 3.4.0.29** (full, the new PSS window; mirrored to `racetracks/Pour-Social-Score`). **Main: 3.4.1.43** (docs build, PR #134: F1 marked merged and the later builds renumbered, decision 24; F1 merged in 3.4.1.42, PR #131).
- **Current project: core uplift** (`10_CORE_UPLIFT.md`, locked by Dan on 2026-10-08). It runs on three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy.
- **Done:** F1 (3.4.1.42, below), Fix and Fix 2 (3.4.1.40, 3.4.1.41: the Guilds tab detail pane), N1 (3.4.1.32), N2 (3.4.1.33), plan B (3.4.1.34, docs only), B1 (3.4.1.35: PSS authoritative over Blizzard's ignore list, per-player tick, upgrade step 8), B2 (3.4.1.36: the right-click "PSS" header with Block Player / Block Guild), N3 (3.4.1.37: shipped lists rebuilt, 7634 to 7438 entries).
- **F1, 3.4.1.42** (merged, PR #131): N40 expiry applied by itself (`M.PSS_ExpireEntries`), N41 option hooks without a /reload, N42 `[talent]` tag, N45 Import Replace keeps the shipped rules (`M.PSS_ClearGuildRules`), N46 listener errors shown once (`M.PSS_NoteListenerError`), N47 group warning from the current roster, N48 `/pss list` nil note. Harness `check_fixes.lua`. In game (Dan, 2026-10-09): checks 1, 2, 3, 5, 6, 8, 10 pass, 9 assumed; checks 4 and 7 are left for later as #132 and #133.
- **Next:** F2 (3.4.1.44: G21 with G26, G27, G28), then U1 (3.4.1.45). Expected builds to the end of the project are in `10_CORE_UPLIFT.md` section 4 (decision 24): the 3.4.1 release is 3.4.1.51, 3.4.2 runs 3.4.2.52 to 3.4.2.58, 3.4.3 runs 3.4.3.59 to 3.4.3.63.
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
