# Combined notes: P2 and P3 (thread notes for the lead, not a pack doc)

## P2 (event-driven GC and loadWhenQuiet)
- `PSS_Perf.lua`: no ticker, no `IDLE_INTERVAL`, no `COMBAT_COOLDOWN`, no heap growth code, no `PLAYER_REGEN_DISABLED`. A request starts a cycle at once when quiet, else registers the wake events (`PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`) until one starts it. A running cycle stops on its first busy frame, sets pending and waits again. Option off while waiting: the wake events are dropped. New: `M.PSS_GCWatch(on)`, `gc.waiting`. Removed from `gc`: `leftCombat`.
- `PSS_ChatHistory.lua`: `History.LoadWhenQuiet()` replaces the 30 s polling `loadWhenQuiet`; busy means three events (`PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`) on a frame made on first use and dropped at the load. The one-shot `C_Timer.After(1, ...)` that keeps the load out of the chat filter stays (not a poll, not a gate).
- Docs: 02 section 4 rewritten, section 12 known-breach row removed. Still to update by the lead: 01 section 5, 06 "Known breaches", 12_CODE_MAP.md (Perf row), 13_CHANGES_IN_TRAIN.md (P2 and D2 rows), the plan's stage table.
- Harness: `check_gc.lua` ("== gc"), `check_ondemand.lua` phase 3 (no timer, no load in combat, the event loads it, the events are dropped). Both fail on main.
- J rules: no Blizzard state touched, no hook; J5 untouched (no protected frames); the GC reads `InCombatLockdown`, `IsInInstance` only.

## P3 (capture events only when needed)
- `PSS_Whois.lua`: `WHO_LIST_UPDATE` and `CHAT_MSG_SYSTEM` are registered only while a request is pending (`Whois.Request` to `finish`) or `Whois.SetCapture(true)`; no `PLAYER_LOGIN` frame any more.
- `PSS_GuildIgnoreList.lua`: `M.PSS_CaptureNeeded()` (a listed player, or a guild rule that is the player's own or a switched-on shipped list) and `M.PSS_ApplyCapture()` register or drop target, mouseover, nameplate, group roster and regen events and call `Whois.SetCapture`. Re-evaluated at login, on `GUILDS_CHANGED`, `PLAYERS_CHANGED`, `FILTERS_CHANGED` (shipped list toggles) and after the login upgrade (`PourSocialScore.lua`, one line). Reads `db.list` directly: `M.PSS_List()` creates the table and broke step 9 on pre-S2b saves (caught by the harness).
- Behaviour note for the lead: with every shipped list off and nobody listed, units seen in the world and hand-typed /who results no longer touch inactive shipped guild rules (before they loaded the shipped lists and stored member records for them). Saved data on the 50 harness saves is unchanged. Decision-worthy: this is L15 as written, but it is a small behaviour change for inactive shipped lists.
- Not changed: PSS_ChatBlock.lua's invite, duel, trade and `GROUP_ROSTER_UPDATE` events (rare, needed for declines) and PourSocialScore.lua's.
- Harness: `check_capture.lua` ("== capture"; fails on main), `H.Listeners(event)` in `wow_stub.lua`.
- J rules: no new hook; units and /who names still pass `M.PSS_IsSecret` as before; J6/J7 unchanged.
