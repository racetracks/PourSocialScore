# Combined notes: P2 and P3 (thread notes for the lead, not a pack doc)

## P2 (event-driven GC and loadWhenQuiet)
- `PSS_Perf.lua`: no ticker, no `IDLE_INTERVAL`, no `COMBAT_COOLDOWN`, no heap growth code, no `PLAYER_REGEN_DISABLED`. A request starts a cycle at once when quiet, else registers the wake events (`PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`) until one starts it. A running cycle stops on its first busy frame, sets pending and waits again. Option off while waiting: the wake events are dropped. New: `M.PSS_GCWatch(on)`, `gc.waiting`. Removed from `gc`: `leftCombat`.
- `PSS_ChatHistory.lua`: `History.LoadWhenQuiet()` replaces the 30 s polling `loadWhenQuiet`; busy means three events (`PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`) on a frame made on first use and dropped at the load. The one-shot `C_Timer.After(1, ...)` that keeps the load out of the chat filter stays (not a poll, not a gate).
- Docs: 02 section 4 rewritten, section 12 known-breach row removed. Still to update by the lead: 01 section 5, 06 "Known breaches", 12_CODE_MAP.md (Perf row), 13_CHANGES_IN_TRAIN.md (P2 and D2 rows), the plan's stage table.
- Harness: `check_gc.lua` ("== gc"), `check_ondemand.lua` phase 3 (no timer, no load in combat, the event loads it, the events are dropped). Both fail on main.
- J rules: no Blizzard state touched, no hook; J5 untouched (no protected frames); the GC reads `InCombatLockdown`, `IsInInstance` only.

## P3 (capture events only when needed)
See the P3 section below once done.
