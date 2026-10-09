# P1 notes (dead code N1 to N15), for the combined delivery

Based on main 3.4.1.51. No version, TOC version, history or versions.json change.

## Removed
- N1: 61 unused English localization keys and their 152 lines across every locale (`PSS_Localization.lua`). The `UPG_*` keys are read through `"UPG_" .. feature .. "_" .. key` and stay; `MSG_2..5` stay (`declineMsg`).
- N2: `V.needSorted` (definition and 12 writes: `PSS_Globals`, `PSS_PlayerIgnoreList`, `PSS_PlayerQuery`, Libraries `PSS_ImportExport`); the then-unused `local V` in `PSS_PlayerQuery.lua` and `PSS_ImportExport.lua`.
- N3: the reload popup: `StaticPopupDialogs["PSS_RELOAD"]`, `M.PSS_AskReload`, `camelot` local (`PSS_BlizzardUI.lua`); `def.reload` branch and the `before` read in `M.PSS_SetOpt`. Harness: `check_tui.lua` now asserts `M.PSS_AskReload == nil`; `check_options.lua` no longer tests `o.reload`.
- N4: `gotUpdate`, `gotGroup` and the `IGNORELIST_UPDATE` registration, unregistration and branch on core's main frame (`PourSocialScore.lua`).
- N5: `PSS_MainlineCompat.lua` (file, 3 TOC lines, `check_layers.lua` list entry); `PSS_Globals.lua` uses `#s` and `string.byte` instead of `strlen` / `strbyte`.
- N6: `V.wowIsERA/TBC/Wrath/Cata/MOP/Classic`, `V.wowLongName`, `V.wowName` (`V.wowIsRetail` stays).
- N9 (exports, 22): `PSS_EVENT_CATEGORY`, `PSS_BLOCK_CATEGORIES`, `PSS_GetBlockSources`, `PSS_ChatFrames`, `PSS_CoreEvents`, `PSS_ParseTimeString`, `PSS_NormalizeBlockEntry`, `PSS_FormatGuildCounts`, `PSS_FormatBlockCounts` (with `History.FormatCounts`), `PSS_GUILD_BLOCK_CATEGORIES`, `PSS_GUILD_BLOCK_LABELS`, `PSS_GuildEventCategory`, `PSS_CompactAllMembers`, `PSS_ManagedGroupOfGuild`, `PSS_RequestGuildUIRefresh`, `PSS_FindGuildRecord`, `PSS_PlayerBlocksAnything`, `PSS_GetPlayerBlockTotals` (function), `PSS_ListedBlockTotals` (function), `PSS_ScanCooldownRemaining`, `PSS_StartScanCooldown`, `PSS_HarvestStats` (function), `PSS_TypeOff` (function), `PSS_HexColor`. Kept: `PSS_CompileFilter` (U3 uses it), `PSS_EnsureManagedRules` (12_CODE_MAP says keep), `M.PSS_BLOCK_LABELS` (read).
- N11: `History.KeepAdd`, `History.MovePeople`, `History.MergeLists`, `History.Combine`, `History.Max`.
- N12: `hasFilterID`, `findGuildForPlayer`, `BLOCK_FIELDS`, the guild file's `CAT_ORDER/CAT_COLOR/parseTimeString/normalizeEntry/entrySig/eventCategory`, the history file's `CAT_COLOR/CAT_ORDER` locals, unused `V` in `PSS_Options.lua`, unused `L` in Libraries `PSS_ImportExport.lua`.
- N13: `/pss test` (`PSSTest`); the word now falls to `/pss help`. `/pssguild test` is separate and stays.
- N14: the dead "resolve the realm" block in `M.PSS_AddOrDelIgnore` (both callers pass `M.addServer(...)`; the function adds the server itself afterwards).
- N10 comment: `PSS__CoreTest` says "used only by tools/harness". Stale comment in `PSS_GuildIgnoreList.lua` fixed.

## Not done
- N7 (`M.debugMsg` and its 19 call sites): touches the same lines S3 and P5 edit; left for P5. `stats` in `PSS_WhoisHarvest.lua` is now written and never read (its only reader was `PSS_HarvestStats`); left.
- N8 (`showIgnoreDebug`): a save change, S3. N15 (guild search owner tag): touches the GUI, left.
- N10 harness-only exports kept (the checks need them).

## Shared files (merge hot spots)
`PSS_PlayerIgnoreList.lua` (needSorted lines, `PSS_AddOrDelIgnore`, two exports), `PSS_GuildIgnoreList.lua` (header block near `History`, exports, two locals), `PSS_ChatHistory.lua` (four functions and exports), `PSS_ChatBlock.lua` (4 export lines), `PSS_Globals.lua`, `PSS_Options.lua`, `PourSocialScore.lua`, the three core TOCs, `PSS_Localization.lua`, `check_layers.lua`.
Docs (`12_CODE_MAP.md`, `13_CHANGES_IN_TRAIN.md`, the plan's stage row, 06) are not touched here; the combined delivery updates them.

## Measured (3.4.0.28 save, harness, resident after login; `luac -s`)
- Resident 2934.9 to 2914.5 KB (-20.4 KB).
- Compiled core 354065 to 337448 bytes (-16617); Libraries 148166 to 147873 (-293); GUI unchanged (206247).
