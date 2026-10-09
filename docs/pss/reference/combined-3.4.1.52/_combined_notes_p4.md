# P4 notes (chat path; for the combined 3.4.1.52 build)

Bench: `tools/harness/bench_chatpath.lua` (run: make a save with one login, then run it on that save so Logging is not loaded). Plain Lua 5.1 in the harness, 60000 lines per scenario, min of several runs; the machine is noisy (about +-10%).

| Finding | Before | After |
| --- | --- | --- |
| N31 outbox at its cap, per added line | 17.4 us | 2.7 us (garbage 224 B, unchanged) |
| N35 listed player's blocked whisper, garbage per line | 632.6 B | 385.1 B |
| N35 guild member's blocked whisper, garbage per line | 528.0 B | 384.0 B |
| N28 guild decision alone (stored member), per line | 6.9 us | 5.3 us |
| N26 unlisted line, text filter on, per line | 11.0 us | 10.5 us |

Behaviour notes:
- N31: the outbox may now hold up to cap + max(20, cap/20) lines (the log's own slack) before the oldest go in one move. Logging load joins it to the log and trims to the cap as before. Counters unaffected.
- N35: only per-chat-line tables changed. The per-invite, duel, trade and sent-whisper ctx tables stay (human-rate events; no gain worth the code).
- N28: `M.PSS_CanonGuild` checks for a secret value before it touches its cache; `M.PSS_IsOwnGuild` still reads `GetGuildInfo("player")` each call.
- N26: `M.PSS_Opt` reads `PSS_OptionsDB` directly for registered options (raw `PourSocialScoreDB` value first, as through the router); `ruleLists()` in `PSS_ChatFilters.lua` does the same for `filterList` / `filterActive`. The option value cache (cleared on OPTION_CHANGED) was not built: options are also written by imports, resets and upgrade steps without that event, so a cache risks stale values for about 0.1 us per read more.
- Skipped: nothing. N34 and N36 were not in P4's scope.
- J rules: J7 (every chat/unit/hook value through `M.PSS_IsSecret` first) is untouched; `check_secrets.lua` passes. No Blizzard state is touched.

Shared files touched: `PSS_ChatHistory.lua` (History.Add), `PSS_ChatBlock.lua` (M.PSS_CanonGuild), `PSS_ChatFilters.lua` (groupFilterIndex, ruleLists, two readers), `PSS_PlayerIgnoreList.lua` (player source lookup/optionContext), `PSS_GuildIgnoreList.lua` (guildBlock, gopt, optionContext), `PSS_Options.lua` (M.PSS_Opt), `tools/harness/bench_chatpath.lua`.
