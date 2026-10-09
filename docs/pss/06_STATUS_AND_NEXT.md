# Status and next step (2026-10-09)

Kept short and current: every PR updates it (baseline 02 E10). History up to 3.4.1.30 is in `reference/06_status-history-to-3.4.1.30.md`. The addon as it works is in `01_HANDOVER.md`; the next plan is the chat path garbage plan (scratch `docs/latest/chat-garbage/`); the closed core uplift is `10_CORE_UPLIFT.md`.

## Now
- **Live release: 3.4.1.53** (full, the core uplift; 2026-10-09; Dan: "push the release now"). Its notes are one summary of 3.4.1.30 to 3.4.1.52 (history.txt). Merging its PR publishes it and mirrors it to `racetracks/Pour-Social-Score`. `01_HANDOVER.md` is re-summarized, `12_CODE_MAP.md` and `13_CHANGES_IN_TRAIN.md` refreshed, `10_CORE_UPLIFT.md` closed. The core uplift's stage notes moved to `reference/06_status-history-3.4.1.30-to-3.4.1.53.md`.
- **3.4.1.52's in-game checks** (PR #142, 1 to 12) were not reported before the release; Dan reported `/pss mem` only (below). Run them on 3.4.1.53.
- **Core memory (Dan, 2026-10-09):** `/pss mem` showed core at 4.47 MB. A full collect in game took it from 3.48 MB to 1.57 MB: garbage not yet collected, not a leak. Harness, 3.4.1.51 against 3.4.1.52 on the 3.4.1.50 save: garbage at login 2324 to 2065 KB, per 2000 chat lines 1622 to 1606 KB, window open 1276 to 1399 KB; live after login 2926 to 2581 KB. The figure looks higher because P2 removed the 10-minute idle collection (by design).
- **Next: the chat path garbage plan** (Dan, 2026-10-09: "make a detailed plan for 2"): cut the chat path's garbage per line (about 800 bytes). Plan on scratch `docs/latest/chat-garbage/`. It needs Dan's answers to its decisions before the first stage; it starts the 3.4.2 line (first build 3.4.2.54).
- Offered, not chosen: `/pss mem` collects before it reads, so it shows live memory (a small fix; Dan did not pick it).
- The closed projects: core uplift (3.4.1, `10_CORE_UPLIFT.md`), the PSS window (3.4.0, `09_PSS_UI_PROJECT.md`) and parity (3.3.1, `08`).

## Waiting on Dan
- Optional: add the repository secret `SCRATCH_TOKEN` (fine-grained token, Contents: read on `racetracks/Pour-Social-Score_Scratch`) so CI runs the real saves (`real-saves` job, 10_CORE_UPLIFT decision 29).
- Merge the 3.4.1.53 release PR, then run 3.4.1.52's in-game checks (PR #142) on it, including a very old save (2.0.44).
- Answer the chat path garbage plan's decisions.
- Dan's 3.4.1.50 login reported 2 custom chat filter rules this version cannot use (kept, not applied). Run `/pss export unused` and paste the string, so the next session can tell whether they are rules from a newer build or filters U3's check rejects wrongly.

## Known breaches
In 02 section 12, each with its fix line. None: the idle GC cycle was fixed by P2 in 3.4.1.52.

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
