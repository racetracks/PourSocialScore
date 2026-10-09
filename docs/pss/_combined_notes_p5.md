# P5 notes (N17 to N25)

Measured on the 3.4.0.28 save in the harness: compiled bytes (luac -s, all three Lua folders) and resident KB after login.
Base: 708478 bytes, 2934.9 KB. Final: 707333 bytes (-1145), 2934.2 KB (-0.7).

| Finding | Result | Compiled |
| --- | --- | --- |
| N17 | Already done by S2 (`memberCanon`); one copy left in the guild member removal is not equivalent (canon of `memberName(m)`, not `_playerKey`), so left | 0 |
| N18 | `M.PSS_FindGuildRule` calls core `M.PSS_FindGuildRecord` (every caller reads only the record) | -198 |
| N19 | One month map (`M.MONTHS`), `dateToJulianDate` by one match, today's day number kept per day | -218 |
| N20 | `PSS_BLOCK_CATEGORIES` / `PSS_BLOCK_LABELS` from History; one explain order (`ex.order`) | -159 |
| N21 | `M.PSS_BLOCK_FIELDS` / `_SET` from `M.EXCL`; import uses them and `M.PSS_EXCL_CATS`. `ALLOW_FLAGS` is a different set, left | -103 |
| N22 | `RemoveChatFilter` loops `FILTER_ARRAYS` (`M.PSS_FILTER_ARRAYS`, shared with the upgrade). The list arrays went with S2b; the legacy cleanup copy is a loop already | -356 |
| N23 | Skipped: the rules differ on purpose (`/pss add` excludes player-controlled targets, the NPC toggle wants them); one helper would change behaviour | |
| N24 | `addToggle` for the LFG and unit menus | -111 |
| N25 | Skipped: a shared `removeEntry` measured -9 bytes compiled and +0.3 KB resident (the expiry and prune loops differ in direction, threshold and quiet flag) | |
