# Core lists: players, guilds, /who, shipped lists, Blizzard UI, Logging

Mapped at main 3.4.1.38. Line counts are approximate (`wc -l`). `PourSocialScoreDB.<key>` is what the code reads and writes; `PSS_SavedData.lua` routes each key to its real table through a metatable (LAYOUT):

| Code key (PourSocialScoreDB.x) | Saved in |
| --- | --- |
| ignoreList, typeList, factionList, dateList, notes, expList, delList, syncInfo, playerData | `PSS_PlayersDB` (PourSocialScore_Options) |
| guildData, guildExclusions, guildGroupOpen, scanFieldsDefaultV1, guildPlayerCleanupV3 | `PSS_GuildsDB` |
| filterTotal, filterCount, filterBlocked, filterBlockedLast, filterWhisperTotal, filterPrivateTotal, historyFormat, ... | `PSS_CountsDB` |
| filterList, filterDesc, filterID, ... | `PSS_RulesDB` |
| showIgnoreDebug, blizzardSync (retired), windowSizes, ... | `PSS_OptionsDB` |
| blockLog, blockKeep | `PSS_LoggingDB` (only routed while Logging is loaded) |
| imported, outbox, recent counts, upgrade record (not in LAYOUT) | `PourSocialScoreDB` itself |

---

## 1. `PourSocialScore/PSS_PlayerIgnoreList.lua` (~1625 lines)
**Purpose:** the account-wide Player Ignore List (players, NPCs, realms): list add/remove, Blizzard ignore list sync and hooks (B1), the `/pss add` path, per-player W I G P C settings and block history, the O(1) lookup index, and the "player" block source plus the NPC / realm / system handlers for the chat core.

### Exports
**List edits (setters)**
| Name | What it does |
| --- | --- |
| `M.PSS_AddIgnore(name, noNote, exactName)` | Main add. Parses "Name[-Realm] [days] [note]" via `M.PSS_SplitNameArg` unless `exactName`; empty name = target (`PSS_UnitFullName`). Refuses self (`PSS_PlayerDisplayName`). New entry: `AddToList`, stores days in `expList`, fires `ASK_NOTE` (option `asknote`), prints ADD_2; already listed prints ADD_1. Fires `PLAYERS_CHANGED`. Never touches Blizzard's list |
| `M.PSS_AddPlayer(name, note, days, unit)` | Window "Add Player": strips quotes/spaces, `PSS_AddIgnore(name, true, true)`, then sets note, expiry, `PSS_SetPlayerMeta(full, unit)`. Fires `PLAYERS_CHANGED`(true) |
| `M.PSS_DelIgnore(idxpos, isPSS)` | Remove by PSS position (any type), by name, or by Blizzard index/name; `RemoveFromList` then removes the Blizzard ignore (hook guard). Fires `PLAYERS_CHANGED` |
| `M.PSS_AddOrDelIgnore(name)` | Toggle (right-click menus, LFG). Name without realm: guesses the realm from group members and the last chat lines (`historyBuffer` `|Hplayer:` links). Then AddIgnore(exact) or DelIgnore |
| `M.ignoreFromCmd(argStr)` | `/pss add` text; empty = player target with `exact` |
| `M.AddOrDelNPC(arg)` | Toggle an NPC entry (index, name or non-player target); CMD_12/13 |
| `M.AddOrDelServer(name)` | Toggle a realm entry (type "server"); CMD_18/19 |
| `M.PSS_RemoveFromList(index)` | Raw removal: adds to `delList`, `PSS_ForgetPlayer` for players, removes the index from all 7 parallel arrays, marks index dirty |
| `M.PSS_RemoveListEntryAt(i)` / `M.PSS_ImportListEntry(name, faction, note, ltype, dateStr, exp)` | Import/Export entry points (wrap RemoveFromList / AddToList, set date and expiry) |
| `M.PSS_SetNote(index, note)`, `M.PSS_SetExpiry(index, days)` | Write `notes[i]` / `expList[i]` |
| `M.PSS_SetPlayerSetting(name, field, value)` | W I G P C field on the player record (fields in `PLAYER_FIELDS`); newly blocked W/P/C purges their chat lines (`PSS_PurgeChatFrom`) and calls `PSS_PersonIdentified` (declines an open invite) |
| `M.PSS_SetPlayerMeta(name, unit, guild)` | Listed players only: faction, class, className from the unit; `currentGuild`, `guildWhenBlocked` (secret-checked) |
| `M.PruneIgnoreList(days, doit)` | Count / remove entries listed for >= days; fires `PLAYERS_CHANGED` |
| `M.PSS_ResetIgnoreDB()` | Replaces `PourSocialScoreDB` with an empty layout (still writes `showIgnoreDebug = false`), resets spam filters, `PSS_PrepareSavedData({wipe=true})` |
| `M.PSS_ResetBlizzardIgnore()` | Removes every entry from Blizzard's list (original `DelIgnoreByIndex`, not guarded) |

**Blizzard ignore list (B1)**
| Name | What it does |
| --- | --- |
| `M.SyncIgnoreList(silent)` | `/pss sync` only (the login call in PourSocialScore.lua:129 is commented out). First time (`imported ~= true`): takes Blizzard's list on with note and tick. Then removes blank and **expired** entries (the only expiry path today: N40), then for each Blizzard entry not in PSS: `trackChanges` on and not in `delList` = take on (ticked), else remove from Blizzard. Then adds ticked players (`blizzardIgnore`) to Blizzard's list while < 50, honouring `samefaction` / `sameserver`, retrying at most 3 times per character (`syncInfo`). Fires `PLAYERS_CHANGED` |
| `M.PSS_SetBlizzardIgnore(name, on)` | The per-player tick: sets/clears `p.blizzardIgnore` and adds/removes on Blizzard's list under `pssHookGuard`; false (with a chat line) when Blizzard's list is full (50) |
| `M.PSS_TickBlizzardIgnored()` | Ticks every listed player currently on Blizzard's list (upgrade step 8); returns count |

**Queries**
| Name | What it does |
| --- | --- |
| `M.hasGlobalIgnored(name)` | Position of a player entry (exact string, then canon via the index) or 0 |
| `M.hasAnyIgnored(name)`, `M.hasNPCIgnored(name)` | Position by exact string (any type / NPC) |
| `M.hasGroupWarning(name)` | Position in `V.groupWarning` |
| `M.PSS_IsServerMatch(a, b)` | `M.Proper` equality |
| `M.PSS_IsPlayerListed(name)` | Canon lookup in the index |
| `M.PSS_ListedPosition(canon)` | List position for a canon key (verified against the list) |
| `M.PSS_PlayerBlocksAnything(p)` | Any W I G P C field true (no external caller) |
| `M.PSS_GetPlayerPrefs(name)` | `ensurePlayer`: get or **create** the `playerData` record (all five block fields true) |
| `M.PSS_GetPlayerRecord(name)` | Existing record only |
| `M.PSS_GetPlayerBlockCounts(nameOrRecord)` | `p.blockCounts` (built once from old counter fields), via `History.EnsureCounts` |
| `M.PSS_GetPlayerBlockTotals(name)` | total, whispers, chat, invites (no external caller) |
| `M.PSS_PlayerHistoryKey(x)` | `"p:<canon>"` owner key |
| `M.PSS_GetPlayerBlockHistory(name)` | `History.For(key)` newest first (loads Logging) |

**History and tidy**
| Name | What it does |
| --- | --- |
| `M.PSS_RecordPlayerBlock(name, event, msg, inviteKind, cat)` | Counts one block on `p.blockCounts` and adds a log line (`History.Add`, owner `p:<canon>`); sets `lastBlockedInvite`; fires `PLAYER_BLOCKED` |
| `M.PSS_ResetPlayerBlockHistory(name)` | Clears their log lines and recent counts, zeroes `blockCounts`; fires `PLAYERS_CHANGED` |
| `M.PSS_ForgetPlayer(name, note)` | On removal: `PSS_KeepBlockedOnBuiltIn` (shipped member stays blocked), clears their log lines only if Logging is loaded or they were ever counted (`mayHaveLines`), forgets recent counts, deletes the record |
| `M.PSS_TidyPlayerData()` | Login tidy (PSS_Upgrade): deletes records of unlisted players, drops `DROPPED_FIELDS` and empty `EMPTY_FIELDS`, `nickname == name` |
| `M.PSS_MarkIgnoreIndexDirty()` | Index rebuild on next lookup |

### Notable locals
- `pssHookGuard` (true while PSS itself changes Blizzard's list), `pendingMove` (name -> GetTime(), B1), `pendingToggle` (AddOrDelIgnore result read on next IGNORELIST_UPDATE, 10 s), `blizzSnapshot` (Blizzard list copy for `DelIgnoreByIndex`), `loginSynced`.
- `BlizzardAddIgnore`, `BlizzardDelIgnore`, `BlizzardDelIgnoreByIndex`: the original `C_FriendList` functions captured before hooking (calling them still fires the post-hooks, hence the guard).
- `maxIgnoreSize = 50`, `maxSyncTries = 3`, `maxHistorySize = 250` (delList cap), `doLoginIgnore` (hide ignore-list noise for 90 s after load).
- `idx = { players, pos, npcs, servers, count, dirty }`: lookup index keyed by `PSS_CanonPlayer` / lowercase NPC / `PSS_CanonRealm`; rebuilt only when dirty or the list size changed. `listedName(canon)` verifies position and rebuilds on a stale hit.
- `AddToList`: appends to the 7 parallel arrays, forces all block fields true on the record, removes from delList, purges their chat lines (or adds to `M.PSS__purgeBatch`), `PSS_PersonIdentified`, `PSS_LFG_Refresh`.
- `takeOn(full, tick)`, `blizzardNames()` (secret and blank entries skipped), `addFromBlizzard`, `removeFromBlizzard`, `processMoves`, `syncFromBlizzard`.

### Events
- Fires: `PLAYERS_CHANGED` (many paths; arg true = re-sort), `ASK_NOTE` (name), `PLAYER_BLOCKED`.
- WoW events (always, file-level frame): `IGNORELIST_UPDATE` (pendingToggle, login sync, processMoves, snapshot), `PLAYER_LOGIN` (snapshot only).

### Blizzard hooks / APIs
- `hooksecurefunc(C_FriendList, "AddIgnore" | "DelIgnore" | "AddOrDelIgnore" | "DelIgnoreByIndex")`, each body returns at once under `pssHookGuard`.
- Reads `C_FriendList.GetNumIgnores/GetIgnoreName`; calls the captured `AddIgnore` / `DelIgnoreByIndex` (never `DelIgnore`).
- Reads `ChatFrameN.historyBuffer` (AddOrDelIgnore realm guess), `UnitFactionGroup/UnitClass/GetGuildInfo`, `IsInGroup/GetUnitName`.
- System message handler hides `ERR_IGNORE_FULL` always, `ERR_IGNORE_NOT_FOUND` / `ERR_FRIEND_ERROR` for 90 s after login or during a quiet sync, and friend online/offline lines for listed players/realms (patterns from `ERR_FRIEND_OFFLINE_S` / `ERR_FRIEND_ONLINE_SS`).

### Saved data
- List: `ignoreList[i]` (display name "Name-Realm", NPC name or realm), `typeList[i]` ("player" / "npc" / "server"), `factionList[i]`, `dateList[i]` (`%d %b %Y`), `notes[i]`, `expList[i]` (days, 0 = never), `syncInfo[i]` (`{ "<char>@<tries>" }`), `delList` (names removed, cap 250, used by `trackChanges`), `imported` (bool, PourSocialScoreDB).
- Player record `playerData[key]` (key = `PSS_NormalizePlayer`, "name-realm" lowercase): `name`, `whenBlocked`, `whispersBlocked`, `partyInvitesBlocked`, `guildInvitesBlocked`, `partyRaidBlocked`, `channelsBlocked` (true = blocked; ticked in UI = allowed = false), `blizzardIgnore` (true only, B1), `blockCounts { total, whisper, partyInvite, guildInvite, partyRaid, world }`, `lastBlockedInvite`, `faction`, `class`, `className`, `currentGuild`, `guildWhenBlocked`, `opts` (per-person option exceptions), `nickname`.

### Depends on
`M.PSS_NormalizePlayer/DisplayPlayer/CanonPlayer/CanonRealm/NowString/IsSecret/UnitFullName/FixUnitName/PlayerDisplayName/OwnRealm` (PSS_ChatBlock), `M.PSS_SplitNameArg`, `M.Proper`, `M.addServer`, `M.removeServer`, `M.getServer`, `M.daysFromToday`, `M.trim` (PSS_Globals), `M.PSS_Opt`, `M.PSS_History` (ChatHistory), `M.PSS_PurgeChatFrom`, `M.PSS_PersonIdentified`, `M.PSS_RegisterBlockSource/Handler`, `M.PSS_EventCategory`, `M.PSS_ChannelLabel`, `M.PSS_KeepBlockedOnBuiltIn` (Guild file), `M.PSS_LFG_Refresh` (BlizzardUI), `M.Whois`, `M.ResetSpamFilters`, `M.PSS_PrepareSavedData`.

### Used by
Libraries: `PSS_Commands` (DelIgnore, ignoreFromCmd, AddOrDelNPC/Server, SyncIgnoreList, PruneIgnoreList, ResetIgnoreDB, ResetBlizzardIgnore, RemoveFromList, SetExpiry, IsServerMatch, hasGlobalIgnored, hasNPCIgnored), `PSS_PlayerView` (AddPlayer, SetBlizzardIgnore, SetPlayerSetting, SetNote, SetExpiry, PlayerSearch, PruneIgnoreList, GetPlayerBlockCounts/History, ResetPlayerBlockHistory, PlayerHistoryKey), `PSS_RowMenus` (AddPlayer), `PSS_ImportExport` (ImportListEntry, RemoveListEntryAt, GetPlayerPrefs/Record, hasNPCIgnored, MarkIgnoreIndexDirty, IsPlayerListed), `PSS_EventsQuery`, `PSS_TotalsQuery`. GUI: `PSS_Players` (GetPlayerBlockCounts/History, PlayerHistoryKey, ResetPlayerBlockHistory). Core: `PSS_Upgrade` (TickBlizzardIgnored, TidyPlayerData), `PourSocialScore.lua` (hasGroupWarning, ResetIgnoreDB, PlayerHistoryKey), `PSS_BlizzardUI`, `PSS_Globals` (IsPlayerListed).

---

## 2. `PourSocialScore/PSS_PlayerQuery.lua` (~236 lines)
**Purpose:** read helpers for the Player Ignore List so the window never reads the saved tables. Lives in core (a 3.1 file; a G2 move candidate).

| Name | What it does |
| --- | --- |
| `M.PSS_PlayerCount()` | `#ignoreList` |
| `M.PSS_PlayerRow(i, out)` | Fills the caller's reused table: entry, kind, name, server (pretty), faction, added, listed (days), expire, left, note, record (`PSS_GetPlayerPrefs`, **creates** a record if missing) |
| `M.PSS_PlayerEntry(i)` | entry, type |
| `M.PSS_PlayerPosition(entry)` | `hasAnyIgnored` |
| `M.PSS_IsGuildListed(guild)` | `guildData[PSS_NormalizeGuild(guild)]` exists |
| `M.PSS_ListedBlockTotals(sum)` | Sums counts of listed players (no caller anywhere: dead) |
| `M.PSS_SortPlayers(key, asc, findText, into)` | Filter by text (entry, pretty realm, note) and sort by name, server, type, listed, expire, note, `metric:<cat>`, `excl:<cat>`; blanks last; ties name, server, index |
| `M.PSS_RemovePlayerAt(i)` | Player: `PSS_DelIgnore(i, true)`; NPC/realm: `AddOrDelNPC/Server(i)` + `PSS_PlayersChanged` |
| `M.PSS_PlayersChanged(forced)` | Fires `PLAYERS_CHANGED` (forced sets `V.needSorted`) |

Locals: `EXCL_BY_CAT` (from `M.EXCL`), `sortValue`, `elementName/Server/Type`. Saved data: reads the player list arrays and `guildData`. Used by: Libraries `PSS_PlayerView`, `PSS_EventsQuery`, `PSS_RowMenus`; GUI `PSS_Players`; core `PSS_BlizzardUI` (PlayersChanged, IsGuildListed), `PSS_Commands`.

---

## 3. `PourSocialScore/PSS_GuildIgnoreList.lua` (~2461 lines)
**Purpose:** guild rules and their captured members, per-rule and per-member W I G P C, member block counts and history, managed (shipped) lists and their delta, the member lookup index, /who result capture, Guild Search, the Guild Exclusion List, own-guild check, unit scanning, legacy data upgrades, and the "guild" block source.

### Exports
**Guild rules (setters)**
| Name | What it does |
| --- | --- |
| `M.PSS_GetGuild(name)` | `ensureGuild`: get or create a rule (all blocked, `customScan = "1-60"`), migrates old fields |
| `M.PSS_AddGuild(name)` | ensureGuild, `ruleOrigin = "manual"`; fires `GUILDS_CHANGED` |
| `M.PSS_AddCapturedGuild(actualGuild, fromGroup)` | Promote an exact guild to its own rule: merges every stored copy of its players from other rules, purges and verifies; returns added, migrated, removedRefs, perSource, leftover; fires `GUILDS_CHANGED` |
| `M.PSS_RemoveGuild(key)` | Deletes a non-shipped rule; drops playerData of members not on the Player list; tidies history if Logging is loaded; fires `GUILD_REMOVED`, `GUILDS_CHANGED`, `PLAYERS_CHANGED`. Returns 0 (always), memberCount, true |
| `M.PSS_RemoveGuildNow(key)` | Same with a chat line; shipped guild refused with a message |
| `M.PSS_SetGuildBlock(nameOrKey, cat, value)` | Rule W I G P C; fires `GUILDS_CHANGED` |
| `M.PSS_SetGuildScanFields(g, text)` | `g.customScan` |
| `M.PSS_MigrateCustomScan(g)` | Old levelStart/End/Brackets -> `customScan` |

**Members (setters)**
| Name | What it does |
| --- | --- |
| `M.PSS_UpdateGuildMember(guild, player, unit)` | Get or create a stored member; new + active rule: purge their chat, `PSS_PersonIdentified`; updates class/faction from unit; increments `memberCount` |
| `M.PSS_UpdatePlayerUnit(name, unit, guild)` | Unit seen: `PSS_SetPlayerMeta`; if the guild already has a rule, store the member (managed rule: loads the shipped lists first, skips shipped members). Never creates a rule |
| `M.PSS_SetMemberBlock(g, m, cat, value)` | Member override (nil = inherit); newly blocked purges chat; keeps a shipped record (`keepManaged`) |
| `M.PSS_SetMemberNote(m, text)` | Note (empty removed) |
| `M.PSS_RemoveGuildMember(guild, player, srcKey, storedKey)` | Removes stored copies and tombstones a shipped member; if they are in no rule now, clears `g:<canon>` lines (only if Logging loaded or they were counted) |
| `M.PSS_KeepBlockedOnBuiltIn(name, note)` | A player leaving the Player list who is a shipped member: every category blocked on them, note "Removed from player list" or their old note (25 chars) |
| `M.PSS_MoveOtherCopies(player, keepKey, target)` | Merge every other rule's copy into target and delete it; tombstones them in another shipped guild |
| `M.PSS_MergeIntoShipped(gkey, ck, m)` | Import: merge into the shipped record, never a second stored copy |
| `M.PSS_ReconcileGuildMembers()` | Moves members whose `m.guild` belongs to a more specific rule; returns moved |
| `M.PSS_CompactMember(m)`, `M.PSS_CompactAllMembers()` | Drop default fields (Allow flags, empty block, zero counts, `online/race/className`) |
| `M.PSS_EnsureMemberBlockData(m, create)`, `M.PSS_MergeMemberBlockData(dst, src)` | Old counters folded into `blockCounts` once (`_blockV2`); merge sums counts |

**W I G P C model**
| Name | What it does |
| --- | --- |
| `M.PSS_EXCL_CATS`, `M.PSS_EXCL_INFO` | Category order and letter/label (from `M.EXCL`) |
| `M.PSS_GuildBlock(g)` | `g.block` (built from old declineGroup/declineGuild/partyRaid once) |
| `M.PSS_MemberBlock(m)` | `m.block` or shared read-only `NO_BLOCK` (errors on write); converts old `excluded*` flags |
| `M.PSS_MemberBlocks(g, m, cat)` | Effective: member override else rule |
| `M.PSS_RefreshGuildActive(g)` | `g.enabled` = anything blocked for anyone |
| `M.PSS_GuildRuleActive(g)` | enabled, and for a managed rule its group's Chat Filters rule is on (`PSS_ManagedGroupActive`) |
| `M.PSS_ExclusionText(g, m)` | Coloured "W I G P C" for diagnostics |
| `M.PSS_DEFAULT_SCAN_FIELDS` | "1-60" |

**Queries**
| Name | What it does |
| --- | --- |
| `M.PSS_NormalizeGuild(name)` | trim + lower (rule key) |
| `M.PSS_LookupGuildMember(name)` | g, gkey, member, storedKey (index, then shipped lists) |
| `M.PSS_ForEachGuildMember(g, gkey, fn, includeUntouched)` | Stored members plus shipped records (touched this session, or all: loads lists) |
| `M.PSS_GuildMemberCount(g, gkey)` | Count without building records; lists not loaded: manifest `n` - gone + stored non-`_managed`; cached per generation |
| `M.PSS_FindGuildRecord(nameOrKey)` | Rule by key or name |
| `M.PSS_GetGuildBlockCounts(nameOrKey)` | Sum of member counts (all rules when nil). Measured hot spot |
| `M.PSS_GetMemberBlockCounts(m)` | Copy of a member's counts with total |
| `M.PSS_GetGuildBlockHistory(nameOrKey)`, `M.PSS_GetMemberBlockHistory(m)` | Lines from the shared log (`g:<canon>` owners; a line shows under the rule the character is in now, else its `gk`) |
| `M.PSS_ResetGuildBlockHistory(x)`, `M.PSS_ResetMemberBlockHistory(m)` | Clear lines, recent counts and member counts |
| `M.PSS_BestGuildRowFor(actualGuild)` | Rule with the longest canon name contained in the actual guild (excluded guilds: none) |
| `M.PSS_IsGuildExcluded(g)`, `M.PSS_GuildExclusions()`, `M.PSS_AddGuildExclusion(n)`, `M.PSS_RemoveGuildExclusion(n)` | Guild Exclusion List (`guildExclusions[canon] = display`); add/remove fire `GUILDS_CHANGED` |
| `M.PSS_IsOwnGuild(actualGuild)` | Compares with `GetGuildInfo("player")` each call (cached canon), secret-safe |
| `M.PSS_Say(msg)` | `M.ChatMsg("PSS: " .. msg)` |
| `M.PSS_RequestGuildUIRefresh()` | Fires `GUILD_BLOCKS_CHANGED` at most once per 0.25 s (C_Timer) |
| `M.PSS_GUILD_BLOCK_CATEGORIES`, `M.PSS_GUILD_BLOCK_LABELS`, `M.PSS_GuildEventCategory` | Aliases of History tables / `PSS_EventCategory` (no external caller) |

**Managed (shipped) lists**
| Name | What it does |
| --- | --- |
| `M.PSS_LoadManagedData()` | `ensureManagedData`: `M.PSS_Need("Communities")`, rebuilds `managed`, prunes marks |
| `M.PSS_LoadActiveManagedData()` | Loads when any group's rule is on (login, ticking the rule, import) |
| `M.PSS_ManagedDataLoaded()`, `M.PSS_ManagedGroups()`, `M.PSS_ManagedGroupOfGuild(gkey)`, `M.PSS_IsStaticManagedGuild(gkey)` | Manifest queries (shipped rules cannot be removed) |
| `M.PSS_IsManagedStaticMember(gkey, ck)` | Shipped member of that guild (bucket lookup; nil when lists not loaded) |
| `M.PSS_ManagedRecord(ck, gkey)` | `vrec`: session record for a shipped member (`_managed`, `_virtual`, `_canon`, `_gkey`, `_playerKey`, `whenBlocked = "Managed list"`) |
| `M.PSS_KeepManaged(r)` | Holds a changed shipped record in `vkeep` until logout |
| `M.PSS_ManagedTombstone(gkey, ck)` | `g.managedGone[ck] = true`, removes stored copy |
| `M.PSS_ShippedNames(gkey)` | Split member names (weak cache) |
| `M.PSS_ManagedStats()` | `/pss mem` numbers |
| `M.PSS_PruneManagedMarks()` | Drop `managedGone` marks the lists no longer need |
| `M.PSS_EnsureManagedRules()` | Creates/tags each shipped guild's rule (`managed = group key`, `ruleOrigin = "managed"`) |
| `M.PSS_FlushManaged()` | PLAYER_LOGOUT: writes dirty shipped records into `g.members` (drops `_virtual/_canon/_gkey`, keeps `_managed`), drops unchanged shipped members, clears `memberCount` on managed rules, compacts all members |

**Scans and searches**
| Name | What it does |
| --- | --- |
| `M.PSS_ScanGuild(name, mode, restart)` | "custom": `g-"Name" <customScan>` capped by `PSS_CapWhoFilter`; else the sweep's next search (`PSS_HarvestNext`). `Whois.Request` straight from the click; `PSS_HarvestSent` only if sent; fires `GUILDS_CHANGED` next frame |
| `M.PSS_GuildSearch(text, mode, owner)` | /who for guild names (`g-"text"`, or a raw filter if it has a quote; mode "exclude" for the Exclusion picker) |
| `M.PSS_SaveGuildSearch(names)` | Ticked results become rules, with members from `M.PSS_GuildSearchCache` (600 s TTL) |
| `M.PSS_SaveGuildExclusions(names)` | Ticked results go on the Exclusion List |
| `M.PSS_GuildSearchCache` | `{ at, byGuild = { [gkey] = { info... } } }` set by finishScan |
| `M.PSS__whoCaptured`, `M.PSS__purgeBatch` | Transient flags shared across files (purge batch: canon -> true, one chat sweep per /who answer) |
| `M.PSS_UpgradeLegacyData()` | Startup data upgrade (see below) |
| `M.PSS_EnsureGuildDB()` | Creates `playerData`, `guildData`, `imported` |

### Notable locals
- `scanUnit(unit)`: players only, out of combat, GUID not secret, at most once per 120 s per GUID (`seenGUID`, reset over 600), name/realm secret-checked, `M.PSS_UnitFullName(unit)`, `GetGuildInfo`; calls `PSS_UpdatePlayerUnit`.
- `managed` (built lazily from `addon.MANAGED` and `addon.MANAGED_DATA`): `lists` (buckets + gkeys per group), `names` (packed member strings + realms), `groupOf`, `guildName`, `count`, `dataLoaded`.
- `shippedOf(ck)`: realm and first two bytes pick a bucket string; `bucketValue` plain-finds `"\n<base>="` and reads the number (`guild * 65536 + position`).
- `vcache` (weak values), `vkeep`, `splitCache` (weak), `memberCountCache` (weak keys) with `memberCountGen`.
- Member index: `memberIndexG` / `memberIndexK` (canon -> gkey / storedKey), rebuilt when dirty; on conflict prefers an active rule (+2) and the best-owning rule (+1). Stale hit triggers one rebuild.
- `lookupKept` (<= 300 cached lookup results for the chat path).
- `addWhoResultToGuildMember`, `captureWho`, `finishScan`, `guildLineMatcher`, `mergeMemberRecord` (`MERGE_SKIP`), `recountGuildMembers`, `cleanupLegacyGuildPlayers`, `exclusions()`.
- Unused local: `findGuildForPlayer` (dead); unused upvalues `CAT_COLOR`, `parseTimeString`, `normalizeEntry`, `entrySig`, guild-file `BLOCK_FIELDS`, `memberIndexBuilt` (written, never read).

### Events
- Fires: `GUILDS_CHANGED`, `GUILD_BLOCKS_CHANGED` (throttled), `GUILD_REMOVED` (key), `GUILD_SEARCH_RESULTS` (list, query, mode, owner), `GUILD_SCAN_DONE`, `PLAYERS_CHANGED` (RemoveGuild).
- `Whois.Listen` (begin / info / finish) for every /who answer, including ones the player typed.
- WoW events (own frame): `PLAYER_LOGIN` (always; then registers the rest and runs `PSS_UpgradeLegacyData` if `V.PSS_Loaded`), `PLAYER_TARGET_CHANGED`, `GROUP_ROSTER_UPDATE` (coalesced 2 s), `PLAYER_REGEN_DISABLED/ENABLED`; `UPDATE_MOUSEOVER_UNIT` and `NAME_PLATE_UNIT_ADDED` only while out of combat.

### Saved data
- Rule `guildData[gkey]` (gkey = trim+lower name): `name`, `enabled` (derived), `block { whisper, partyInvite, guildInvite, partyRaid, world }`, `customScan`, `members { [playerKey] = member }`, `memberCount` (display), legacy `declineGuild`, `declineGroup`, `partyRaid` (still written by ensureGuild), `ruleOrigin` ("manual" / "scan" / "managed"), `managed` (group key), `managedGone { [canon] = true }`, `opts`.
- Member: `name`, `guild` (actual guild), `whenBlocked`, `class`, `faction`, `level`, `note`, `block` (overrides), `blockCounts`, `lastBlockedInvite`, `opts`, `_playerKey`, `_managed` (flushed shipped record), legacy `excluded*`, `_blockV2`.
- `guildExclusions[canon] = display`; markers `historyFormat` (2..4), `scanFieldsDefaultV1`, `guildPlayerCleanupV3`.

### Legacy upgrade (`M.PSS_UpgradeLegacyData`, run from PSS_Upgrade and at PLAYER_LOGIN when loaded)
Copies list name/date/faction onto player records; `cleanupLegacyGuildPlayers` (once: removes Player list entries created by old guild capture); `ensureManagedRules`; history formats 2 (normalised lines), 3 (one shared log, `History.Absorb`), 4 (`History.Keep()`); trims the log if Logging is loaded; converts every rule and member to W I G P C; default Scan Fields once; compacts members and drops guild-level counters.

### Depends on
`M.Whois`, `M.PSS_HarvestNext/Sent/Answered`, `M.PSS_CapWhoFilter`, `M.PSS_WHO_CAP`, `M.PSS_ScanAllNextStale` (WhoisHarvest), `M.PSS_CanonPlayer/CanonGuild/NormalizePlayer/DisplayPlayer/IsSecret/NowString/UnitFullName/Trim`, `M.PSS_History`, `M.PSS_EventCategory`, `M.PSS_ChannelLabel`, `M.PSS_ManagedGroupActive` (ChatFilters), `M.PSS_Need` (Loader), `M.PSS_PurgeChatFrom`, `M.PSS_PersonIdentified`, `M.PSS_SetPlayerMeta`, `M.PSS_GetPlayerPrefs/GetPlayerBlockCounts`, `M.PSS_TidyBlockHistory`, `M.PSS_RequestGC`, `M.ChatMsg`, `M.ShowMsg`, `M.EXCL`, `M.PSS_RegisterBlockSource`.

### Used by
Libraries: `PSS_GuildView` (AddGuild, ScanGuild, GuildSearch, SaveGuildSearch/Exclusions, Set*Block, SetMemberNote, SetGuildScanFields, RemoveGuildMember, RemoveGuildNow, exclusions, Get*BlockCounts/History, Reset*, MemberBlock(s), EnsureMemberBlockData, ManagedGroups, IsGuildExcluded), `PSS_GuildQuery` (AddCapturedGuild, ForEachGuildMember, GuildMemberCount, GuildBlock, MemberBlocks, GuildExclusions, ManagedGroups, GuildSearchCache, EnsureGuildDB), `PSS_ImportExport` (GetGuild, CompactMember, GuildBlock, MemberBlock, MergeIntoShipped, RefreshGuildActive, GuildRuleActive, MarkGuildIndexDirty, LoadActiveManagedData), `PSS_Commands`, `PSS_EventsQuery`, `PSS_TotalsQuery`, `PSS_RowMenus`, `PSS_PlayerView` (AddGuild). GUI: `PSS_Guilds` (counts, history, IsStaticManagedGuild, EnsureMemberBlockData). Core: `PourSocialScore.lua` (FlushManaged, LoadActiveManagedData, LookupGuildMember), `PSS_ChatFilters` (LoadActiveManagedData, MarkGuildIndexDirty), `PSS_Upgrade` (UpgradeLegacyData, GuildMemberCount), `PSS_Options` (KeepManaged), `PSS_Perf` (ManagedStats), `PSS_BlizzardUI` (AddGuild, RemoveGuildNow, IsOwnGuild, NormalizeGuild).

---

## 4. `PourSocialScore/PSS_Whois.lua` (~306 lines)
**Purpose:** the one /who service: send, shared cooldown, read answers from the Who list or from chat lines, and hand each player to listeners.

| Name | What it does |
| --- | --- |
| `M.Whois` | Module table |
| `Whois.COOLDOWN = 6`, `Whois.ANSWER_WAIT = 5`, `Whois.EXPIRE = 30` | Seconds: cooldown, timeout to "nobody answered", stale request |
| `Whois.Request(req)` | `send(filter)` (refuses the same filter within 3 s), sets `pending`; next frame starts the cooldown; after 5 s finishes with "timeout" |
| `Whois.Listen(handler)` | Adds `{ begin, info, finish }` (each pcall-ed) |
| `Whois.CooldownRemaining/CooldownActive/StartCooldown/BlockedMsg/Pending` | Cooldown helpers (`C_Timer.NewTimer`) |
| `M.PSS_ScanCooldownActive`, `M.PSS_ScanCooldownRemaining`, `M.PSS_StartScanCooldown`, `M.PSS_ScanBlockedMsg`, `M.PSS_WhoPending()` | Older names; `ScanCooldownRemaining` and `StartScanCooldown` have no caller |

- Locals: `pending`, `listeners`, `cooldownUntil`, `lastFilter/lastTime`, `linePatterns` (built from `WHO_LIST_GUILD_FORMAT` / `WHO_LIST_GUILD_TIMERUNNING_FORMAT`, plus a language-neutral fallback while a request is pending), `chatFinishQueued` (chat answers end 1 s after the last line).
- Events fired: `WHOIS_COOLDOWN` (bool), `WHOIS_ANSWERED` (req; no listener anywhere).
- WoW events: `PLAYER_LOGIN` then always `WHO_LIST_UPDATE` and `CHAT_MSG_SYSTEM` (each line returns at once unless it holds `|Hplayer:`).
- APIs: `C_FriendList.SendWho` (or `SendWho`), `C_FriendList.GetNumWhoResults/GetWhoInfo` (or globals). Must be called straight from a click or key press (hardware event).
- Used by: `PSS_GuildIgnoreList` (Request, Listen), `PSS_PlayerIgnoreList` (PlayerSearch), Libraries `PSS_GuildView`, `PSS_PlayerView` (ScanBlockedMsg, WhoPending), GUI `PSS_Guilds`, `PSS_Players` (ScanCooldownActive).

---

## 5. `PourSocialScore/PSS_WhoisHarvest.lua` (~290 lines)
**Purpose:** plans the guild sweep (one /who per click, split until each answer is under 50) and Scan All; session-only state.

| Name | What it does |
| --- | --- |
| `M.PSS_WHO_CAP = 50` | /who result cap |
| `M.PSS_ScanLevelCap()` | Option `whoLevelCapOn` + `whoLevelCap`, else nil |
| `M.PSS_CapWhoFilter(filter)` | Cuts every unquoted level / range to the cap, adds `1-cap` when none |
| `M.PSS_HarvestFilter(name, item)` | `g-"Name" [c-"Class"] [lo-hi]` |
| `M.PSS_HarvestNext(g, restart)` | sweep, item, filter (new sweep when none, done, or restart) |
| `M.PSS_HarvestSent(sw, filter)` | Pops the queue, counts |
| `M.PSS_HarvestAnswered(scan, numWhos, total)` | Adds totals; if capped (shown >= 50 or total > shown) splits: whole guild -> level brackets (1-9, 10-19 ... max-1, max) -> classes -> single levels; marks done when the queue is empty |
| `M.PSS_GuildSweep(key)`, `M.PSS_GuildSweepSent(key)`, `M.PSS_GuildSweepLabel(key)` | Sweep state, sent count, button text ("Scan", "Scan n/m", "Rescan") |
| `M.PSS_ScanAllNext(cached)`, `M.PSS_ScanAllNextStale()` | Next unswept guild A-Z, done, total (cached for tooltips) |
| `M.PSS_ScanAll()` | One Scan All step; refuses during cooldown; when all are swept, starts a new round |
| `M.PSS_HarvestStats()` | Session totals (no caller: dead) |
| Globals | `BINDING_HEADER_POURSOCIALSCORE`, `BINDING_NAME_PSS_SCAN_ALL`, `PSS_ScanAllBinding()` (called by Bindings.xml) |

- Locals: `sweeps[gkey] = { name, queue, sent, capped, gaveUp, seen, added, moved, done }`, `sweepRound`, `stats`, `CLASSES`, `CLASSIC_ONLY` (level-60 client drops DK, Monk, DH, Evoker and the other faction's Shaman/Paladin).
- Listens: `M.Events.Register("GUILDS_CHANGED" | "GUILD_REMOVED", PSS_ScanAllNextStale)` at load (always).
- Used by: `PSS_GuildIgnoreList`, Libraries `PSS_GuildView` (ScanAllNext, GuildSweep, HarvestFilter, GuildSweepLabel), `PSS_GuildQuery` (GuildSweepSent), GUI `PSS_Guilds` (ScanAll, GuildSweepLabel).

## 6. `PourSocialScore/Bindings.xml` (5 lines)
One binding `PSS_SCAN_ALL`, header `POURSOCIALSCORE`, category ADDONS, runs `PSS_ScanAllBinding()` (a key press is a hardware event, so `SendWho` works).

---

## 7. `PourSocialScore/PSS_Communities.lua` (~134 lines, generated)
**Purpose:** the always-loaded manifest of the shipped lists. Appends to `addon.MANAGED.groups` one group: `{ key = "olympus", name/rule = "Managed Communities - Asmongold", filter = "InfluencerGuild=Olympus", id = "PSSG0001", guilds = { { name, n = member count }, ... } }`, 119 guilds, 7438 entries. No functions. Read by `buildManaged` (guild names, counts, groupOf), so rule creation and member counts work without loading the data.

## 8. `PourSocialScore_Communities/` (load on demand; ~335 KB, 386 KB resident)
- TOCs: `LoadOnDemand: 1`, `Dependencies: PourSocialScore`, no SavedVariables. One file, `PSS_GuildIgnore_Managed.lua` (776 lines, generated; header lists merges and the 2026-10-08 surname fix).
- Format: `PourSocialScore_NS.MANAGED_DATA["olympus"] = { key, name, rule, filter, id, realms = { "ClassicBetaPvP", "ClassicBetaPvP2" }, guilds = { { name, members = "First Last-1\nOther-2\n..." } (same order as the manifest), buckets = { [realm canon] = { [first two bytes of name canon] = "\n<name canon>=<guild index * 65536 + position>..." } } }`.
- Lookup: `shippedOf(canon)` splits realm/base, finds the bucket string and plain-finds `"\n<base>="`. A name whose game-lowercase differs (non-ASCII capitals) has a second key. Each character is in one guild per group.
- Loaded by `M.PSS_Need("Communities")` through `ensureManagedData` only: at login when a group's rule is on (`PSS_LoadActiveManagedData` from PourSocialScore.lua), when the rule is ticked, on import, in the members window (`includeUntouched`), on any /who capture, a member removal, a history view of a managed rule, or when a member of a managed guild is seen (`PSS_UpdatePlayerUnit`, issue #38). Chat never loads it.

## 9. `tools/PSS_BuildManaged.lua` (~448 lines)
Builds both files from OlympusMute's `OlympusDB` (`lua PSS_BuildManaged.lua <Olympus.lua> [data] [manifest]`) or rewrites an existing data file (`--reindex`). Takes leader, officers, top players, reporter and vouch names per guild census; newest census wins a character; skips `myCharacters`. `canonPlayer` must match `M.PSS_CanonPlayer`; `gameLower` adds the second index key for non-ASCII capitals. `REALMS.olympus` + `fixSurnames` (N3): a "realm" not in REALMS is a Camelot surname: `First-Last` is dropped when `First Last` is listed, else converted to `First Last-ClassicBetaPvP`; adds a `-- Fixed <date>` header note. Guild names differing only by case are merged; each character kept once (first guild sorted). Output ASCII only (decimal escapes).

---

## 10. `PourSocialScore/PSS_BlizzardUI.lua` (~340 lines)
**Purpose:** core's touch points with Blizzard UI: window openers and Friends/Social docking, core StaticPopups, Group Finder colouring/tooltip/menu, the unit right-click menu, the Addon Compartment.

| Name | What it does |
| --- | --- |
| `V.nameUI` | Player the note popup is for |
| `M.PSS_OpenUI(show)` | `M.PSS_Need("GUI")` then `M.PSS_OpenWindow(show)` |
| `M.PSS_AskReload(text)` | `PSS_RELOAD` popup; on Camelot (interface < 20000) a chat line instead (ReloadUI blocked) |
| `M.PSS_LFG_Refresh()` | Recolours visible Group Finder rows (pcall, ScrollBox.ForEachFrame) |
| `M.PSS_LFG_Update(row)` | Post-hook body: leader listed -> red name |
| `M.PSS_LFG_Tooltip(row)` | Post-hook body: adds "listed" + note lines to GameTooltip (checks `IsForbidden`) |
| `M.PSS_LFG_ApplicantMenu(owner, root)` | Menu.ModifyMenu body: title with the leader, one toggle (RCM_4 / RCM_6) -> `PSS_AddOrDelIgnore` |
| `M.PSS_UnitMenuPlayer(owner, root, contextData)` | The right-click "PSS" section (section 13c) |
| `M.PSS_HookFunctions()` | Called once at load end (PourSocialScore.lua). Installs LFG hooks if `useLFGHacks` (retries on ADDON_LOADED until the Group Finder functions exist), and unit menus if `useUnitHacks` |

- StaticPopupDialogs (PSS_-prefixed, J2 exception): `PSS_RELOAD`, `PSS_REASON` (edit note, 128 chars, writes via `PSS_SetNote`), `PSS_PARTYWARN` (15 s).
- Listens on `M.Events`: `ASK_NOTE` (shows PSS_REASON), `WHISPER_WARNING` (`RaidNotice_AddMessage` + raid warning sound), `GROUP_WARNING` (PSS_PARTYWARN with names).
- Hooks: `FriendsFrame` and (Retail 12.1) `SocialUIFrame` `HookScript("OnShow"/"OnHide")` always at load; dock only while option `openWithFriends` (`M.PSS_WindowDock(host, x)` 12 / 55, `M.PSS_WindowUndock`). `hooksecurefunc("LFGListSearchEntry_Update" | "LFGListSearchEntry_OnEnter")`, `Menu.ModifyMenu("MENU_LFG_FRAME_SEARCH_ENTRY")`, and `Menu.ModifyMenu` for 11 unit tags (pcall each). Hooks are installed only when the option is on at load and cannot be removed; bodies are not gated by the option afterwards (N41). `AddonCompartmentFrame:RegisterAddon` on Retail.
- Depends on: `PSS_Need`, `PSS_OpenWindow/WindowDock/WindowUndock` (GUI), `PSS_IsPlayerListed`, `PSS_ListedPosition`, `PSS_CanonPlayer`, `PSS_NormName`, `PSS_IsOwnGuild`, `PSS_IsGuildListed`, `PSS_AddGuild`, `PSS_RemoveGuildNow`, `PSS_NormalizeGuild`, `PSS_AddOrDelIgnore`, `PSS_PlayersChanged`, `hasAnyIgnored`, `hasGlobalIgnored`, `PSS_SetNote`.
- Used by: `PSS_Commands` and GUI `PSS_Window` (`PSS_OpenUI`), `PSS_Options` (`PSS_AskReload`), PourSocialScore.lua (`PSS_HookFunctions`), PlayerIgnoreList (`PSS_LFG_Refresh`).

---

## 11. `PourSocialScore_Logging/` (load on demand)
- TOCs: `LoadOnDemand: 1`, `Dependencies: PourSocialScore`, `SavedVariables: PSS_LoggingDB` (keys `blockLog`, `blockKeep` routed through PourSocialScoreDB).
- `PSS_LoggingData.lua` (5 lines): comment only.
- `PSS_SavedLog.lua` (~235 lines) adds to `M.PSS_History`:

| Name | What it does |
| --- | --- |
| `History.PackForSave()` | At PLAYER_LOGOUT, only if Logging loaded this session: in-play log (array of entry tables) + keep (packed strings per owner) -> `blockLog = { v = 2, [owner] = { m, n, gk, r, c, k, [1..] = lines } }`, `blockKeep = nil` |
| `History.UnpackSaved()` | When Logging loads: blockLog v2 -> log entries (sorted by ts, metatable `History.EntryMT`) and the keep (`History.PackLine`) |
| `History.KeepToLog()` | Once (`logAllV1`): saves from 3.2.0-dev3 to dev006 put kept lines back into the log, then trim |

- Line format: `<type letter><time or +delta>\t<event letter or name>\t<channel: "" usual, "~" group's c>\t<who: "" = group m/gk/r, else index into n, "\1gk\1r">\t<message, "\2" = same as before>`. Type letters `LOG_CODE`: w whisper, p partyRaid, i partyInvite, g guildInvite, c world, u guildChat, x unknown.
- **What loads Logging:** `M.PSS_LoadLogging()` (PSS_ChatHistory.lua), called by `History.Log()` / `History.Keep()` (any history view, Clear, Trim), by PSS_SavedData when PourSocialScoreDB still holds a logging key, by PSS_Upgrade, at startup only if already loaded, and by itself when the outbox reaches 200 waiting lines (`loadWhenQuiet`: out of combat and instances, a 30 s C_Timer retry). Removing a player or member loads it only if they were ever counted (`mayHaveLines`).
- **Before it loads:** `History.Add` counts on the record at once and parks the line in `PourSocialScoreDB.outbox` (capped at the log cap). On load the outbox joins the log, then `CapKeep`, `Trim(true)`, `PSS_TidyBlockHistory`.
- **Caps:** log `History.Cap()` = option `historyTotal`, default 2000 (100 to 20000), trimmed in batches 5% over; a trimmed line of a person moves to `blockKeep` (newest 10 text, 5 party invites, 5 guild invites per owner, `History.KEEP`). Owners: `p:<canon>` players, `g:<canon>` guild members (lines carry `gk`), `G:<gkey>` guild recent counts only.

---

## 12. Player list flows (a)
| Flow | Path |
| --- | --- |
| Add (command) | `/pss add Name[-Realm] [days] [note]` -> `ignoreFromCmd` -> `PSS_AddIgnore` -> `PSS_SplitNameArg` (multi-word names) -> `M.Proper(M.addServer)` -> `AddToList` (7 arrays; record forced all-blocked; delList cleared; chat purge; `PSS_PersonIdentified` declines an open invite) -> `expList` -> `ASK_NOTE` -> `PLAYERS_CHANGED` |
| Add (window) | `PSS_PlayerView` -> `PSS_AddPlayer(name, note, days, unit)` (whole text is the name) |
| Add (menu) | `PSS_UnitMenuPlayer` / LFG menu -> `PSS_AddOrDelIgnore` -> `PSS_AddIgnore(name, nil, true)` |
| Remove | `PSS_RemovePlayerAt` / `PSS_DelIgnore` -> `RemoveFromList` (delList, `PSS_ForgetPlayer`: shipped member kept blocked, lines cleared if counted, record deleted) -> Blizzard ignore removed if present |
| Expire | Only in `M.SyncIgnoreList` (`/pss sync`): `daysFromToday(dateList) >= expList`. Nothing runs it at login (the call is commented out), so expiry does not happen automatically today (N40, stage F1). `PruneIgnoreList(days)` is the manual age prune |
| W I G P C | Stored as blocked fields on `playerData`; UI tick = allowed. `PSS_SetPlayerSetting`. The "player" source's `decide`: whisper W, partyInvite I, guildInvite G, partyRaid P, world C (`~= false`), duel/trade by options `declineDuel`/`declineTrade` with `{ person = p.opts }` exceptions; everything else true |
| Blizzard ignore (B1) | Tick -> `PSS_SetBlizzardIgnore` (guarded add/remove, max 50). Blizzard Ignore / `/ignore` -> post-hook `AddIgnore` -> `addFromBlizzard`: listed with note "Synced from Blizzard ignore list on <date>", `pendingMove[full]` unless ticked -> next `IGNORELIST_UPDATE` `processMoves` removes from Blizzard (dropped after 30 s). `AddOrDelIgnore` toggle: `pendingToggle` read on next update (10 s). Unignore in Blizzard (`DelIgnore`, `DelIgnoreByIndex` via `blizzSnapshot`) -> `removeFromBlizzard` -> `RemoveFromList` (both "First-Last" and fixed forms tried). First `IGNORELIST_UPDATE` after `V.PSS_Loaded`: `syncFromBlizzard` lists every unlisted Blizzard entry with note + tick, removes nobody; `V.PSS_TickOnSync` (upgrade step 8) re-ticks |
| Auto-decline | Not in these files: the core (`PSS_ChatBlock.lua`) asks each source's `decide` for "partyInvite" / "guildInvite" / "duel" / "trade" and calls the decline APIs. These files feed it through `PSS_PersonIdentified` (decline an invite still open when someone is newly listed or blocked) |

## 13. Guild list flows (b)
| Flow | Path |
| --- | --- |
| Scan (row button) | `PSS_GuildView` -> `PSS_ScanGuild(name, "sweep", restart)` -> `PSS_HarvestNext` (first item = whole guild `g-"Name"`, `1-cap` with a level cap) -> `Whois.Request` (SendWho from the click; repeat within 3 s refused) -> next frame cooldown 6 s, `GUILDS_CHANGED`; 5 s without answer = timeout finish |
| Answer | `WHO_LIST_UPDATE` (GetWhoInfo) or `CHAT_MSG_SYSTEM` lines -> listeners: `begin` opens `M.PSS__purgeBatch`; `info` -> `captureWho`: matches the scanned rule ("contains"), else `PSS_BestGuildRowFor`; `addWhoResultToGuildMember` (skips excluded guilds, loads shipped lists; shipped member -> session record only; else `PSS_UpdateGuildMember` + `PSS_MoveOtherCopies`, sets `guild`, `class`, `level`, `_playerKey`); `finish` purges chat once, `finishScan`: `PSS_ReconcileGuildMembers`, `PSS_HarvestAnswered` (split when capped), chat summary, `GUILD_SCAN_DONE`, `PSS_RequestGC("who results")` |
| Split | Capped answer (>= 50 or total > shown): brackets -> classes -> single levels, queued first; a single level+class still capped counts as `gaveUp` |
| Scan All | GUI button or key binding `PSS_SCAN_ALL` -> `PSS_ScanAll` -> next unswept rule A-Z -> `PSS_ScanGuild(name, "sweep")`; all swept = new round |
| Custom Scan | `PSS_ScanGuild(name, "custom")`: `g-"Name" <customScan>` through `PSS_CapWhoFilter`; not part of the sweep |
| Guild Search | `PSS_GuildSearch(text, mode, owner)` -> results `GUILD_SEARCH_RESULTS`; `PSS_SaveGuildSearch(names)` creates rules and stores the players seen (cache 600 s); mode "exclude" -> `PSS_SaveGuildExclusions` |
| Members from play | `scanUnit` (target, mouseover, nameplates out of combat; group 2 s after roster burst) -> `PSS_UpdatePlayerUnit` (only into an existing rule); guild invite -> source `inviteByGuild` stores the inviter under the best rule |
| Rules | A rule is a "contains" match key; the longest contained rule name owns a member (`PSS_BestGuildRowFor`); excluded guilds belong to none; own guild never blocked by a rule (`decide`); a managed rule blocks only while its Chat Filters rule is on (`PSS_GuildRuleActive`). Duel/trade decline only for members blocked in some category, by options with `{ person, guild }` exceptions |
| Shipped lists without loading | Manifest gives guild names, counts and rule creation (`ensureManagedRules`); `PSS_GuildMemberCount` = manifest `n` - `managedGone` + stored non-`_managed`. Membership itself needs the data: `shippedOf` returns nil while it is not loaded, so with a group's rule off its shipped members are not found (and block nothing by design). With the rule on, the data loads at login |
| Delta save | Only rule records, non-shipped members, changed shipped members (note, block, opts, counts, last invite) and `managedGone` tombstones are saved (`PSS_FlushManaged` at logout) |

## 14. Right-click menu (c)
`PSS_HookFunctions` (option `useUnitHacks`, default on) -> `Menu.ModifyMenu` on `MENU_UNIT_ENEMY_PLAYER`, `_PLAYER`, `_PARTY`, `_RAID_PLAYER`, `_FRIEND`, `_FRIEND_OFFLINE`, `_CHAT_ROSTER`, `_GUILD`, `_COMMUNITIES_GUILD_MEMBER`, `_COMMUNITIES_MEMBER`, `_COMMUNITIES_WOW_MEMBER` -> `M.PSS_UnitMenuPlayer`:
1. Skips Battle.net-only entries, secret or empty names, and yourself (`UnitIsUnit(unit, "player")`).
2. Name from the unit (`UnitName`) or `contextData.name/server` (chat); built with `M.PSS_NormName(name, server, unit)` (Camelot surname rule).
3. Guild only from a real unit: `GetGuildInfo(unit)`, dropped if secret, empty or `PSS_IsOwnGuild`.
4. Adds a divider, title `L["RCM_16"]` ("PSS"), button "Block Player" (`RCM_17`) / "Unblock Player" (`RCM_18`) by `hasGlobalIgnored` -> `PSS_AddOrDelIgnore` + `PSS_PlayersChanged(true)`; then, with a guild, "Block Guild" (`RCM_19`) -> `PSS_AddGuild` or "Unblock Guild" (`RCM_20`) -> `PSS_RemoveGuildNow` (shipped guilds refuse with a chat line).
The LFG applicant menu keeps its own single toggle (`RCM_4` / `RCM_6`).

## 15. Name normalisation (d)
Defined in `PourSocialScore/PSS_ChatBlock.lua` (not in this scope's files, listed for the callers):
| Function | Result |
| --- | --- |
| `joinName(name, realm, unit)` (local) | The one join. Secret/empty -> nil. With a realm: if `isSurname(unit)` -> `"First Last-<own realm>"`, else `"Name-Realm"` |
| `isSurname(unit)` | `unit == "player"` always; else `UnitRealmRelationship(unit) == LE_REALM_RELATION_SAME` (not secret). No unit -> false |
| `M.PSS_NormName(name, realm, unit)` | display (`M.Proper(M.addServer())`), key (`name-realm` lowercase, realm spaces/dashes removed), canon (key with apostrophes stripped and inner spaces collapsed) |
| `M.PSS_UnitFullName(unit)` | `joinName(UnitName(unit), unit)` |
| `M.PSS_PlayerDisplayName()` | Your own display name (surname aware) |
| `M.PSS_FixUnitName(name)` | Hook paths: `"First-Last"` -> `"First Last-<own realm>"` when target, mouseover, focus or a group member has that name and surname |
| `M.PSS_NormalizePlayer` / `M.PSS_CanonPlayer` / `M.PSS_DisplayPlayer` | Key / canon / display of a given string (no unit) |
| `M.PSS_CanonRealm`, `M.PSS_CanonGuild`, `M.PSS_OwnRealm` | Realm canon, guild canon (trim, collapse spaces, lower), cached `GetNormalizedRealmName` |
| `M.PSS_SplitNameArg(str)` (PSS_Globals) | "Name rest" split: quotes; a word with "-" in the first three ends the name; two words are a name off Retail or when listed |
| `M.PSS_CharKey` (PSS_Options) | `NormName(n, r, "player")` key |

Where called in scope: `scanUnit` (`PSS_UnitFullName`), `PSS_UnitMenuPlayer` (`PSS_NormName` with unit), `ignoreFromCmd` / `PSS_AddIgnore` / `PSS_AddOrDelIgnore` / `AddOrDelNPC` (`PSS_UnitFullName("target")`), `addFromBlizzard` / `PSS_IgnoreToggled` / `removeFromBlizzard` (`PSS_FixUnitName`), self checks (`PSS_PlayerDisplayName`), every record key (`PSS_NormalizePlayer`), every index and history owner (`PSS_CanonPlayer`), guild keys (`PSS_NormalizeGuild` = trim+lower, `PSS_CanonGuild` for matching). Display names in the list are still built with `M.Proper(M.addServer(name))` (realm spelling from `V.serverName`; decision 13 reversed). The builder's `canonPlayer` copies `canonOf`.

---

## 16. Findings (possible bugs, dead code)
1. **Expiry never runs automatically:** `M.SyncIgnoreList` is the only expiry path and its login call is commented out (PourSocialScore.lua:129); only `/pss sync` expires entries. Known as N40 (F1).
2. **`PSS_KeepBlockedOnBuiltIn` silently fails when the shipped lists are not loaded** (group rule off): `lookupGuildMember` -> `shippedOf` finds nothing, so a removed player who is a shipped member gets no "Removed from player list" note or block flags. Harmless while the rule is off (shipped members do not block), but the member is not marked if the rule is turned on later.
3. **Dead exports (no caller in repo or harness):** `M.PSS_ListedBlockTotals`, `M.PSS_GetPlayerBlockTotals`, `M.PSS_PlayerBlocksAnything` (used only inside its file), `M.PSS_HarvestStats` (comment says the Scan tooltip shows it; nothing reads it), `M.PSS_ScanCooldownRemaining`, `M.PSS_StartScanCooldown`, `M.PSS_GUILD_BLOCK_CATEGORIES`, `M.PSS_GUILD_BLOCK_LABELS`, `M.PSS_GuildEventCategory`, `M.PSS_ManagedGroupOfGuild`, `M.PSS_FindGuildRecord` / `M.PSS_BestGuildRowFor` / `M.PSS_CompactAllMembers` / `M.PSS_EnsureManagedRules` / `M.PSS_EXCL_INFO` / `M.PSS_DEFAULT_SCAN_FIELDS` / `M.PSS_MergeMemberBlockData` / `M.PSS_RequestGuildUIRefresh` (only used inside their own file). Event `WHOIS_ANSWERED` has no listener. Local `findGuildForPlayer` and several upvalues in the guild file are unused.
4. **`M.PSS_RemoveGuild`'s first return `removedGlobal` is always 0** (kept for the old signature).
5. **Legacy fields still written:** `ensureGuild` writes `declineGuild`, `declineGroup`, `partyRaid` and `memberCount` on every new rule; `ResetIgnoreDB` writes `showIgnoreDebug = false`; these are S3 / N8 targets.
6. **`PSS_PlayerRow` creates a player record** (`PSS_GetPlayerPrefs`) for any listed player without one, just by drawing the row.
7. **`PSS_AddOrDelIgnore` realm guess** reads `ChatFrame1..20.historyBuffer` messages; `sub(msg, pos + 9, (find(":") or find("|")) - 1)` errors (arithmetic on nil) if a `|Hplayer:` link has neither a later ":" nor "|"; it also keeps only the last matched realm (the collected `pServers` list is never used).
8. **`inviteByGuild`** stores the inviter as a member under the best rule even for your own guild (the own-guild check is only in `decide`), so a broad rule can capture own-guild members on a guild invite.
9. **Hooks are not gated after install:** LFG and unit-menu hooks are installed only if their options are on at load, and turning an option off does not stop them until /reload (N41).
10. **`M.PSS_ResetBlizzardIgnore`** calls the original `DelIgnoreByIndex` without `pssHookGuard`, so each removal runs the post-hook (`removeFromBlizzard`). Harmless today: its only caller, `/pss clear confirm` (PSS_Commands.lua:143), empties the PSS list first; any other caller would also remove those players from PSS.
