# Core lists: players, guilds, /who, shipped lists, Blizzard UI, Logging

Mapped at 3.4.1.53. Line counts are `wc -l`. `PourSocialScoreDB.<key>` is what the code reads and writes; `PSS_SavedData.lua` routes each key to its real table through a metatable (LAYOUT, A section 4):

| Code key (PourSocialScoreDB.x) | Saved in |
| --- | --- |
| list, delList, playerData (retired arrays ignoreList, typeList, factionList, dateList, notes, expList, syncInfo: read once by step 9) | `PSS_PlayersDB` (PourSocialScore_Options) |
| guildData, guildExclusions, guildGroupOpen, scanFieldsDefaultV1, guildPlayerCleanupV3 | `PSS_GuildsDB` |
| filterTotal, filterCount, filterBlocked, filterBlockedLast, filterWhisperTotal, filterPrivateTotal, historyFormat, ... | `PSS_CountsDB` |
| filterList, filterDesc, filterID, nextFilterId, ... | `PSS_RulesDB` |
| windowPoints and every option | `PSS_OptionsDB` |
| blockLog, blockKeep | `PSS_LoggingDB` (only routed while Logging is loaded) |
| imported, outbox, purge, recent counts, upgrade record (not in LAYOUT) | `PourSocialScoreDB` itself |

---

## 1. `PourSocialScore/PSS_PlayerIgnoreList.lua` (1656 lines)
**Purpose:** the account-wide Player Ignore List (players, NPCs, realms): one array of sparse records (S2b), list add/remove/expire, Blizzard ignore list sync and hooks (B1), the `/pss add` path, per-player W I G P C settings and block history, the lookup index, and the "player" block source plus the NPC / realm / system handlers for the chat core.

### Exports
**List entries (S2b; one block between `-- (list entries)` and `-- (/list entries)`)**
| Name | What it does |
| --- | --- |
| `M.PSS_List()` | `db.list` (created when missing): `{ name, date, [kind] [faction] [note] [exp] [sync] }` per entry, in list order |
| `M.PSS_EntryName(i)`, `M.PSS_EntryKind(i)` | Name; kind (`e.kind or "player"`) |
| `M.PSS_NewEntry(name, kind, faction, note, exp)` | Appends a record (only set fields), returns the index |
| `M.PSS_SetEntryNote/Exp/Date/Faction(i, v)` | Set or clear one field |
| `M.PSS_EntrySync(i)`, `M.PSS_EntryAddSync(i, str)` | The `"<char>@<tries>"` sync tags |

**List edits (setters)**
| Name | What it does |
| --- | --- |
| `M.PSS_AddIgnore(name, noNote, exactName)` | Main add. Parses "Name[-Realm] [days] [note]" via `M.PSS_SplitNameArg` unless `exactName`; empty name = target (`PSS_UnitFullName`). Refuses self (`PSS_PlayerDisplayName`). New entry: `AddToList`, expiry, `ASK_NOTE` (option `asknote`), ADD_2; already listed: ADD_1 ("already ignored"). Fires `PLAYERS_CHANGED` |
| `M.PSS_AddPlayer(name, note, days, unit)` | Window "Add Player": `PSS_AddIgnore(name, true, true)`, then note, expiry, `PSS_SetPlayerMeta(full, unit)` |
| `M.PSS_DelIgnore(idxpos, isPSS, quiet)` | Remove by PSS position, by name, or by Blizzard index/name; `RemoveFromList` then the Blizzard ignore (hook guard). Fires `PLAYERS_CHANGED` |
| `M.PSS_AddOrDelIgnore(name)` | Toggle (right-click menus, LFG). Name without realm: guesses the realm from group members and the chat frames' `|Hplayer:` lines |
| `M.ignoreFromCmd(argStr)` | `/pss add` text; empty = player target with `exact` |
| `M.AddOrDelNPC(arg)`, `M.AddOrDelServer(name)` | Toggle an NPC / realm entry |
| `M.PSS_RemoveFromList(index)` | Raw removal: `delList`, `PSS_ForgetPlayer` for players, `table.remove(list, i)`, index dirty |
| `M.PSS_RemoveListEntryAt(i)`, `M.PSS_ImportListEntry(name, faction, note, ltype, dateStr, exp)` | Import/Export entry points |
| `M.PSS_SetNote(index, note)`, `M.PSS_SetExpiry(index, days)` | Through `PSS_SetEntryNote` / `PSS_SetEntryExp` |
| `M.PSS_SetPlayerSetting(name, field, value)` | W I G P C field on the record (`true` stored as nil, S3); newly blocked W/P/C purges their chat lines and calls `PSS_PersonIdentified` |
| `M.PSS_SetPlayerMeta(name, unit, guild)` | Listed players only: faction, class, className from the unit; `currentGuild`, `guildWhenBlocked` (secret-checked) |
| `M.PSS_ExpireEntries(quiet, daily)` | (N40, F1) removes entries past their expiry, backwards by position; one chat line unless quiet. Runs at login, on `PLAYER_REGEN_ENABLED` (`daily`: once a day), in `M.PSS_OpenUI` and the Friends dock, `/pss list` and `/pss sync` |
| `M.PruneIgnoreList(days, doit)` | Count / remove entries listed for >= days; fires `PLAYERS_CHANGED` |
| `M.PSS_ResetIgnoreDB()` | Replaces `PourSocialScoreDB` with an empty layout, resets spam filters, `PSS_PrepareSavedData({wipe=true})` |
| `M.PSS_ResetBlizzardIgnore()` | Removes every entry from Blizzard's list (original `DelIgnoreByIndex`, not guarded) |
| `M.PSS_CompactPlayers(legacy)` | (S3; step 10 with `legacy`, logout without) drops switches that block and zero counts; `legacy` copies the party switch to a missing guild switch first |

**Blizzard ignore list (B1)**
| Name | What it does |
| --- | --- |
| `M.SyncIgnoreList(silent)` | `/pss sync`: first time (`imported ~= true`) takes Blizzard's list on with note and tick; expiry through `M.PSS_ExpireEntries`; each Blizzard entry not in PSS: `trackChanges` on and not in `delList` = take on (ticked), else remove from Blizzard; then adds ticked players (`blizzardIgnore`) to Blizzard's list while < 50, honouring `samefaction` / `sameserver`, at most 3 tries per character (sync tags) |
| `M.PSS_SetBlizzardIgnore(name, on)` | The per-player tick: `p.blizzardIgnore` (true only) and the Blizzard add/remove under `pssHookGuard`; false (with a chat line) when Blizzard's list holds 50 |
| `M.PSS_TickBlizzardIgnored()` | Ticks every listed player on Blizzard's list now (step 8); returns count |

**Queries**
| Name | What it does |
| --- | --- |
| `M.hasGlobalIgnored(name)` | Position of a player entry (exact, then canon via the index) or 0 |
| `M.hasAnyIgnored(name)`, `M.hasNPCIgnored(name)`, `M.hasGroupWarning(name)` | Position by exact string; position in `V.groupWarning` |
| `M.PSS_IsServerMatch(a, b)`, `M.PSS_IsPlayerListed(name)`, `M.PSS_ListedPosition(canon)` | |
| `M.PSS_PlayerBlocksAnything(p)` | Any W I G P C switch blocks (`p[f] ~= false`) |
| `M.PSS_GetPlayerPrefs(name)` | `ensurePlayer`: get or **create** the `playerData` record (switches not stored: a missing one blocks) |
| `M.PSS_GetPlayerRecord(name)` | Existing record only |
| `M.PSS_GetPlayerBlockCounts(nameOrRecord)` | `p.blockCounts` via `History.EnsureCounts` |
| `M.PSS_PlayerHistoryKey(x)`, `M.PSS_GetPlayerBlockHistory(name)` | `"p:<canon>"`; `History.For(key)` (loads Logging) |

**History and tidy**
| Name | What it does |
| --- | --- |
| `M.PSS_RecordPlayerBlock(name, event, msg, inviteKind, cat)` | Counts one block (`History.Add`, owner `p:<canon>`); `lastBlockedInvite`; fires `PLAYER_BLOCKED` |
| `M.PSS_ResetPlayerBlockHistory(name)` | `History.ClearOwner`, recent counts, `blockCounts`; fires `PLAYERS_CHANGED` |
| `M.PSS_ForgetPlayer(name, note)` | On removal: `PSS_KeepBlockedOnBuiltIn`, `History.ClearOwner(o, mayHaveLines(p))` (never loads Logging, S1), forgets recent counts, deletes the record |
| `M.PSS_TidyPlayerData()` | Login tidy (step 1): records of unlisted players, dropped fields |
| `M.PSS_MarkIgnoreIndexDirty()` | Index rebuild on next lookup |

### Notable locals
- `getList`, `AddToList` (`M.PSS_NewEntry`; clears the record's switches so it blocks everything; `delList`; chat purge or `M.PSS__purgeBatch`; `PSS_PersonIdentified`; `PSS_LFG_Refresh`), `RemoveFromList`, `anyBlocked`, `BLOCK_FIELDS` (= `M.PSS_BLOCK_FIELDS`).
- `pssHookGuard`, `pendingMove` (B1), `pendingToggle`, `blizzSnapshot`, `loginSynced`; the captured `C_FriendList` originals.
- `maxIgnoreSize = 50`, `maxSyncTries = 3`, `maxHistorySize = 250` (delList cap), `doLoginIgnore`.
- `idx = { players, pos, npcs, servers, count, dirty }`: lookup index keyed by canon forms; `listedName(canon)` verifies and rebuilds on a stale hit; `lookupKept` (300) for the chat path.
- `takeOn`, `blizzardNames`, `addFromBlizzard`, `removeFromBlizzard`, `processMoves`, `syncFromBlizzard`, `takeBlizzSnapshot`.

### Events
- Fires: `PLAYERS_CHANGED` (arg true = re-sort), `ASK_NOTE` (name), `PLAYER_BLOCKED`.
- WoW events (file-level `hookFrame`): `IGNORELIST_UPDATE` (pendingToggle, login sync, processMoves, snapshot), `PLAYER_LOGIN` (snapshot).

### Blizzard hooks / APIs
- `hooksecurefunc(C_FriendList, "AddIgnore" | "DelIgnore" | "AddOrDelIgnore" | "DelIgnoreByIndex")`, each body returns at once under `pssHookGuard`.
- System message handler hides `ERR_IGNORE_FULL` always, `ERR_IGNORE_NOT_FOUND` / `ERR_FRIEND_ERROR` during a quiet sync, and friend online/offline lines for listed players/realms. Blizzard's "is now / no longer being ignored" lines are left alone (decision 20).

### Saved data
- `list[i]`: `name` (display "Name-Realm", NPC name or realm), `date` (`%d %b %Y`), and only when set `kind` ("npc" / "server"), `faction`, `note`, `exp` (days > 0), `sync` (`{ "<char>@<tries>" }`). `delList` (names removed, cap 250), `imported` (PourSocialScoreDB).
- `playerData[key]` (key = `PSS_NormalizePlayer`): `name`, `whenBlocked`, the five `*Blocked` switches **only when false** (allowed), `blizzardIgnore` (true only), `blockCounts` (compacted), `lastBlockedInvite`, `faction`, `class`, `className`, `currentGuild`, `guildWhenBlocked`, `opts`, `nickname`.

---

## 2. `PourSocialScore/PSS_PlayerQuery.lua` (30 lines)
The two player list calls core itself makes, plus stubs. The rows, sort and removal moved to Libraries `PSS_PlayerRows.lua` (P6).

| Name | What it does |
| --- | --- |
| `M.PSS_IsGuildListed(guild)` | `guildData[PSS_NormalizeGuild(guild)]` exists (menu clicks) |
| `M.PSS_PlayersChanged(forced)` | Fires `PLAYERS_CHANGED` |
| Stubs | `PSS_PlayerCount`, `PSS_PlayerRow`, `PSS_PlayerEntry`, `PSS_PlayerPosition`, `PSS_SortPlayers`, `PSS_RemovePlayerAt` load Libraries on first call |

---

## 3. `PourSocialScore/PSS_GuildIgnoreList.lua` (2786 lines)
**Purpose:** guild rules and their captured members (sparse records, accessors), per-rule and per-member W I G P C, member block counts and history, managed (shipped) lists and their delta, the member cap, the member lookup index, capture events on demand (P3), /who result capture, Guild Search, the Guild Exclusion List, own-guild check, unit scanning, legacy data upgrades, and the "guild" block source.

### Exports
**Member fields (S2, S3; one block between `-- (member fields)` and `-- (/member fields)`; `tools/check_fields.lua` fails `_playerKey`, `_canon`, `_gkey`, `_managed`, `_virtual` or `memberCount` as a field outside it)**
| Name | What it does |
| --- | --- |
| `M.PSS_MemberCanon(m, k)`, `M.PSS_MemberPlayerKey(m)` | Canon and stored key; a record without them is found through `homeKey` (weak map record -> key, filled in one walk on first need, emptied when members change; chat never fills it) |
| `M.PSS_MemberName(m, k)`, `M.PSS_MemberGuildName(m, g)` | `name`, else the key's display form; `guild`, else the rule's name |
| `M.PSS_MemberShipped(m, g)`, `M.PSS_MemberWhenBlocked(m)` | A shipped member (a record with no date in a managed rule); its date or "Managed list" |
| `M.PSS_MemberHasPlayerKey(m)` | Did /who or an invite give it `_playerKey` (Camelot repair) |
| `M.PSS_StoreMemberCount(g, n)` | Returns the count; nothing saved (S3) |

**Guild rules (setters)**
| Name | What it does |
| --- | --- |
| `M.PSS_GetGuild(name)` | `ensureGuild`: get or create a rule (all blocked, `customScan = "1-60"`) |
| `M.PSS_AddGuild(name)` | `ruleOrigin = "manual"`; fires `GUILDS_CHANGED` |
| `M.PSS_AddCapturedGuild(actualGuild, fromGroup)` | Promote an exact guild to its own rule, merging its players from other rules |
| `M.PSS_RemoveGuild(key)` | Deletes a non-shipped rule; fires `GUILD_REMOVED`, `GUILDS_CHANGED`, `PLAYERS_CHANGED`. Returns 0 (always), member count, true |
| `M.PSS_RemoveGuildNow(key)` | Same with a chat line; a shipped guild is refused |
| `M.PSS_ClearGuildRules()` | (N45) Import Replace: every rule but the shipped ones goes |
| `M.PSS_SetGuildBlock(nameOrKey, cat, value)` | Rule W I G P C; fires `GUILDS_CHANGED` |
| `M.PSS_SetGuildScanFields(g, text)`, `M.PSS_MigrateCustomScan(g)` | `g.customScan` |

**Members (setters)**
| Name | What it does |
| --- | --- |
| `M.PSS_UpdateGuildMember(guild, player, unit)` | Get or create a stored member; new + active rule: purge their chat, `PSS_PersonIdentified` |
| `M.PSS_UpdatePlayerUnit(name, unit, guild)` | Unit seen: store the member only if the guild already has a rule |
| `M.PSS_SetMemberBlock(g, m, cat, value)`, `M.PSS_SetMemberNote(m, text)` | Member override (nil = inherit); note |
| `M.PSS_RemoveGuildMember(guild, player, srcKey, storedKey)` | Removes stored copies, tombstones a shipped member; `History.ClearOwner` when they are in no rule now |
| `M.PSS_KeepBlockedOnBuiltIn(name, note)` | A player leaving the Player list who is a shipped member stays blocked with a note |
| `M.PSS_MoveOtherCopies(player, keepKey, target)`, `M.PSS_MergeMember` (= `mergeMemberRecord`; never copies `name`, `guild`, `whenBlocked` or `_` fields), `M.PSS_MergeIntoShipped(gkey, ck, m)` | Merges |
| `M.PSS_ReconcileGuildMembers()` | Moves members whose guild belongs to a more specific rule |
| `M.PSS_CompactMember(m)`, `M.PSS_CompactAllMembers()`, `M.PSS_StampFoundMembers()` | Sparse records (S3); a found member without a date gets one (step 10) |
| `M.PSS_MEMBER_CAP` (1500), `M.PSS_CapMembers(g)`, `M.PSS_CapAllMembers()` | The oldest members holding nothing of their own go (step 10, logout flush) |
| `M.PSS_EnsureMemberBlockData(m, create)`, `M.PSS_MergeMemberBlockData(dst, src)` | Old counters folded into `blockCounts` once (`_blockV2`); merge sums counts |

**W I G P C model**
| Name | What it does |
| --- | --- |
| `M.PSS_EXCL_CATS`, `M.PSS_EXCL_INFO` | Category order and letter/label (from `M.EXCL`) |
| `M.PSS_GuildBlock(g)`, `M.PSS_MemberBlock(m)`, `M.PSS_MemberBlocks(g, m, cat)` | Rule switches; member overrides (shared read-only `NO_BLOCK`); effective value |
| `M.PSS_RefreshGuildActive(g)`, `M.PSS_GuildRuleActive(g)` | `g.enabled`; enabled and, for a managed rule, its Chat Filters rule on |
| `M.PSS_ExclusionText(g, m)`, `M.PSS_DEFAULT_SCAN_FIELDS` | Diagnostics; "1-60" |

**Queries**
| Name | What it does |
| --- | --- |
| `M.PSS_NormalizeGuild(name)` | trim + lower (rule key) |
| `M.PSS_LookupGuildMember(name)` | g, gkey, member, storedKey (index, then shipped lists) |
| `M.PSS_ForEachGuildMember(g, gkey, fn, includeUntouched)` | Stored members plus shipped records |
| `M.PSS_GuildMemberCount(g, gkey)` | Worked out, never read from the save: stored members; a managed rule with lists not loaded: manifest `n` - gone + stored non-shipped; cached per generation |
| `M.PSS_FindGuildRecord(nameOrKey)` | Rule by key or name (Libraries `PSS_FindGuildRule` calls it, P5) |
| `M.PSS_GetGuildBlockCounts(nameOrKey)`, `M.PSS_GetMemberBlockCounts(m)` | Sums. Measured hot spot |
| `M.PSS_GetGuildBlockHistory`, `M.PSS_GetMemberBlockHistory`, `M.PSS_ResetGuildBlockHistory`, `M.PSS_ResetMemberBlockHistory` | Lines from the shared log; resets |
| `M.PSS_BestGuildRowFor(actualGuild)` | Rule with the longest canon name contained in the guild |
| `M.PSS_IsGuildExcluded(g)`, `M.PSS_GuildExclusions()`, `M.PSS_AddGuildExclusion(n)`, `M.PSS_RemoveGuildExclusion(n)` | Guild Exclusion List; add/remove fire `GUILDS_CHANGED` |
| `M.PSS_IsOwnGuild(actualGuild)` | Compares with `GetGuildInfo("player")`, secret-safe |
| `M.PSS_Say(msg)` | `M.ChatMsg("PSS: " .. msg)` |
| `M.PSS_CaptureNeeded()`, `M.PSS_ApplyCapture()` | (P3) a listed player, or a rule that is not managed or is an active shipped list -> register target/mouseover/nameplate/roster/regen events and `Whois.SetCapture(true)`; else drop them. Re-run at login, on `GUILDS_CHANGED`, `PLAYERS_CHANGED`, `FILTERS_CHANGED` and after the login upgrade |

**Managed (shipped) lists**
| Name | What it does |
| --- | --- |
| `M.PSS_LoadManagedData()`, `M.PSS_LoadActiveManagedData()`, `M.PSS_ManagedDataLoaded()` | `M.PSS_Need("Communities")`; only when a group's rule is on |
| `M.PSS_ManagedGroups()`, `M.PSS_IsStaticManagedGuild(gkey)`, `M.PSS_IsManagedStaticMember(gkey, ck)` | Manifest queries; shipped member test |
| `M.PSS_ManagedRecord(ck, gkey)`, `M.PSS_KeepManaged(r)`, `M.PSS_ManagedTombstone(gkey, ck)` | Session record for a shipped member; hold a changed one until logout; `managedGone[ck]` |
| `M.PSS_ShippedNames(gkey)`, `M.PSS_ManagedStats()`, `M.PSS_PruneManagedMarks()`, `M.PSS_EnsureManagedRules()` | Names; `/pss mem` numbers; marks; one rule per shipped guild |
| `M.PSS_FlushManaged()` | PLAYER_LOGOUT: a changed shipped member is saved sparse into `g.members`, unchanged ones dropped, then the cap and `compactAllMembers` |

**Scans and searches**
| Name | What it does |
| --- | --- |
| `M.PSS_ScanGuild(name, mode, restart)` | "custom": `g-"Name" <customScan>` capped by `PSS_CapWhoFilter`; else the sweep's next search (`PSS_HarvestNext`, Libraries); `Whois.Request` straight from the click |
| `M.PSS_GuildSearch(text, mode, owner)`, `M.PSS_SaveGuildSearch(names)`, `M.PSS_SaveGuildExclusions(names)` | /who for guild names; results become rules / exclusions |
| `M.PSS_GuildSearchCache` | `{ at, byGuild }` set by the search finish (600 s) |
| `M.PSS__whoCaptured`, `M.PSS__purgeBatch` | Transient flags (one chat purge per /who answer) |
| `M.PSS_UpgradeLegacyData(tally)`, `M.PSS_EnsureGuildDB()` | Startup data upgrade (step 1, counts into the report); creates `playerData`, `guildData` |
| `M.PSS_MarkGuildIndexDirty()` | Member index, `homeKey`, member count cache and the unusable-rules set rebuilt on next use |

### Notable locals
- `homeKey` / `homeMiss` (weak), `forgetHome`, `memberShipped`, `sparseMember`, `compactMember`, `derivedField`, `dropOwnFields`.
- `scanUnit(unit)`: players only, out of combat, GUID not secret, once per 120 s per GUID, `M.PSS_UnitFullName(unit)`, `GetGuildInfo`; calls `PSS_UpdatePlayerUnit`. `listenUnitScans` (mouseover and nameplates only out of combat).
- `managed` (lazy from `addon.MANAGED` and `addon.MANAGED_DATA`), `shippedOf(ck)`, `vcache`, `vkeep`, `memberCountCache` with `memberCountGen`.
- Member index `memberIndexG` / `memberIndexK` (canon -> gkey / storedKey); `lookupKept` (<= 300) for the chat path.
- `capMembers`, `addWhoResultToGuildMember`, `captureWho`, `finishScan`, `cleanupLegacyGuildPlayers`.

### Events
- Fires: `GUILDS_CHANGED`, `GUILD_BLOCKS_CHANGED` (throttled 0.25 s), `GUILD_REMOVED` (key), `GUILD_SEARCH_RESULTS` (list, query, mode, owner), `GUILD_SCAN_DONE`, `PLAYERS_CHANGED` (RemoveGuild).
- Listens: `GUILDS_CHANGED`, `PLAYERS_CHANGED`, `FILTERS_CHANGED` (`applyCapture`); `Whois.Listen` (begin / info / finish).
- WoW events: `PLAYER_LOGIN` (once: capture, legacy upgrade if loaded); only while capture is wanted: `PLAYER_TARGET_CHANGED`, `GROUP_ROSTER_UPDATE` (coalesced 2 s), `PLAYER_REGEN_DISABLED/ENABLED`, and out of combat `UPDATE_MOUSEOVER_UNIT`, `NAME_PLATE_UNIT_ADDED`.

### Saved data (sparse, S3)
- Rule `guildData[gkey]`: `name`, `enabled`, `block`, `customScan`, `members`, legacy `declineGuild`, `declineGroup`, `partyRaid` (still written by `ensureGuild`), `ruleOrigin`, `managed` (group key), `managedGone { [canon] = true }`, `opts`. No `memberCount`.
- Member: `name` (only when not the key's display form), `guild` (only when not the rule's name), `whenBlocked` (not on shipped members), `note`, `class`, `faction`, `level`, `lastBlockedInvite`, `block`, `blockCounts` (compacted), `opts`, `_playerKey` (only when it differs from the key), legacy `excluded*`, `_blockV2`. No `_canon`, `_gkey`, `_managed`, `_virtual`.
- `guildExclusions[canon] = display`; markers `historyFormat`, `scanFieldsDefaultV1`, `guildPlayerCleanupV3`.

---

## 4. `PourSocialScore/PSS_Whois.lua` (339 lines)
**Purpose:** the one /who service: send, shared cooldown, read answers from the Who list or chat lines, hand each player to listeners; the stubs for the scan planner (now in Libraries) and the key binding globals.

| Name | What it does |
| --- | --- |
| `M.Whois`, `Whois.COOLDOWN = 6`, `Whois.ANSWER_WAIT = 5`, `Whois.EXPIRE = 30` | Module, seconds |
| `Whois.Request(req)` | `send(filter)` (refuses the same filter within 3 s), sets `pending`; cooldown next frame; "timeout" finish after 5 s |
| `Whois.Listen(handler)` | `{ begin, info, finish }` (each pcall-ed; errors to `M.PSS_NoteListenerError`) |
| `Whois.SetCapture(on)` | (P3) keep the answer events while capture is wanted |
| `Whois.CooldownRemaining/CooldownActive/StartCooldown/BlockedMsg/Pending` | Cooldown helpers |
| `M.PSS_ScanCooldownActive`, `M.PSS_ScanBlockedMsg`, `M.PSS_WhoPending` | Older names |
| `M.PSS_WHO_CAP = 50`, stubs `PSS_HarvestNext`, `PSS_HarvestSent`, `PSS_HarvestAnswered`, `PSS_CapWhoFilter`, `PSS_ScanAll` | Load Libraries on first call |
| Globals | `BINDING_HEADER_POURSOCIALSCORE`, `BINDING_NAME_PSS_SCAN_ALL`, `PSS_ScanAllBinding()` (Bindings.xml) |

- WoW events: `WHO_LIST_UPDATE` and `CHAT_MSG_SYSTEM` only while a request is pending or capture is on (P3).
- Events fired: `WHOIS_COOLDOWN` (bool), `WHOIS_ANSWERED` (req; no listener).
- APIs: `C_FriendList.SendWho` from a click or key press only (hardware event).

## 5. `PourSocialScore/Bindings.xml` (5 lines)
One binding `PSS_SCAN_ALL`, header `POURSOCIALSCORE`, runs `PSS_ScanAllBinding()` (a key press is a hardware event, so `SendWho` works).

## 6. Scan planner (`PourSocialScore_Libraries/PSS_WhoisHarvest.lua`, 282 lines; moved from core in P6)
| Name | What it does |
| --- | --- |
| `M.PSS_ScanLevelCap()`, `M.PSS_CapWhoFilter(filter)` | Option `whoLevelCapOn` + `whoLevelCap`; cuts levels to the cap |
| `M.PSS_HarvestFilter(name, item)`, `M.PSS_HarvestNext(g, restart)`, `M.PSS_HarvestSent(sw, filter)`, `M.PSS_HarvestAnswered(scan, numWhos, total)` | Sweep plan; a capped answer splits: whole guild -> level brackets -> classes -> single levels |
| `M.PSS_GuildSweep(key)`, `M.PSS_GuildSweepSent(key)`, `M.PSS_GuildSweepLabel(key)` | State, sent count, button text |
| `M.PSS_ScanAllNext(cached)`, `M.PSS_ScanAllNextStale()`, `M.PSS_ScanAll()` | Next unswept guild A-Z; one Scan All step |

Listens (from Libraries load): `GUILDS_CHANGED`, `GUILD_REMOVED` -> `M.PSS_ScanAllNextStale`. Local `stats` is written and never read (its reader went in P1).

---

## 7. `PourSocialScore/PSS_Communities.lua` (134 lines, generated)
The always-loaded manifest of the shipped lists: `addon.MANAGED.groups` gets `{ key = "olympus", name/rule = "Managed Communities - Asmongold", filter = "InfluencerGuild=Olympus", id = "PSSG0001", guilds = { { name, n }, ... } }`, 119 guilds, 7438 entries. No functions.

## 8. `PourSocialScore_Communities/` (load on demand; 334,806 bytes)
- TOCs: `LoadOnDemand: 1`, `Dependencies: PourSocialScore`, no SavedVariables. One generated file, `PSS_GuildIgnore_Managed.lua`.
- Format: `PourSocialScore_NS.MANAGED_DATA["olympus"] = { key, name, rule, filter, id, realms = { "ClassicBetaPvP", "ClassicBetaPvP2" }, guilds = { { name, members = "First Last-1\n..." } }, buckets = { [realm canon] = { [first two bytes] = "\n<name canon>=<guild index * 65536 + position>..." } } }`.
- Loaded by `M.PSS_Need("Communities")` through `ensureManagedData` only: at login when a group's rule is on, when the rule is ticked, on import, in the members view, on a /who capture or a member of a managed guild seen (issue #38). Chat never loads it. With every shipped list off and nobody listed, units and typed /who no longer reach it (P3).

## 9. `tools/PSS_BuildManaged.lua`
Builds both files from OlympusMute's `OlympusDB` or rewrites the data file (`--reindex`). `REALMS.olympus` + `fixSurnames` (N3): `First-Last` is dropped when `First Last` is listed, else converted to `First Last-ClassicBetaPvP`. Output ASCII only.

---

## 10. `PourSocialScore/PSS_BlizzardUI.lua` (352 lines)
**Purpose:** core's touch points with Blizzard UI: window openers and Friends/Social docking, core StaticPopups, Group Finder colouring/tooltip/menu, the unit right-click menu, the Addon Compartment.

| Name | What it does |
| --- | --- |
| `V.nameUI` | Player the note popup is for |
| `M.PSS_OpenUI(show)` | `M.PSS_ExpireEntries()`, `M.PSS_Need("GUI")`, `M.PSS_OpenWindow(show)` |
| `M.PSS_LFG_Refresh()`, `M.PSS_LFG_Update(row)`, `M.PSS_LFG_Tooltip(row)`, `M.PSS_LFG_ApplicantMenu(owner, root)` | Group Finder: recolour, red leader name, tooltip lines, one toggle (RCM_4 / RCM_6); bodies return at once when `useLFGHacks` is off |
| `M.PSS_UnitMenuPlayer(owner, root, contextData)` | The right-click "PSS" section (section 13); returns at once when `useUnitHacks` is off (N41) |
| `M.PSS_HookFunctions()` | At startup: the LFG hooks (waits for the Group Finder) and the unit menus, each when its option is on; `OPTION_CHANGED` installs them on the first enable without a /reload (N41) |

- StaticPopupDialogs (PSS_-prefixed): `PSS_REASON` (note, 128 chars, `PSS_SetNote`), `PSS_PARTYWARN`. `PSS_RELOAD` and `M.PSS_AskReload` are gone (P1).
- Listens: `ASK_NOTE`, `WHISPER_WARNING` (`RaidNotice_AddMessage` + sound), `GROUP_WARNING`, `OPTION_CHANGED`.
- Hooks: `FriendsFrame` and (Retail 12.1) `SocialUIFrame` `HookScript("OnShow"/"OnHide")` at load; dock only while `openWithFriends`. `hooksecurefunc("LFGListSearchEntry_Update" | "LFGListSearchEntry_OnEnter")`, `Menu.ModifyMenu("MENU_LFG_FRAME_SEARCH_ENTRY")`, `Menu.ModifyMenu` for 11 unit tags (pcall each). `AddonCompartmentFrame:RegisterAddon` on Retail.

---

## 11. `PourSocialScore_Logging/` (load on demand)
- TOCs: `LoadOnDemand: 1`, `Dependencies: PourSocialScore`, `SavedVariables: PSS_LoggingDB`.
- `PSS_LoggingData.lua` (5 lines): comment only.
- `PSS_SavedLog.lua` (272 lines) adds to `M.PSS_History`:

| Name | What it does |
| --- | --- |
| `History.PackForSave()` | At PLAYER_LOGOUT, only if Logging loaded: log + keep -> `blockLog = { v = 2, [owner] = { m, n, gk, r, c, k, [1..] = lines } }`, `blockKeep = nil`. `m` is not saved when it is `M.PSS_DisplayPlayer` of a `p:`/`g:` owner key; `false` when the lines have no name (S3) |
| `History.UnpackSaved()` | When Logging loads: blockLog v2 -> log entries and the keep; derives a missing `m`; a log with `v` above 2 is kept as it is (U3) |
| `History.KeepToLog()` | Once (`logAllV1`) |

- **What loads Logging:** `M.PSS_LoadLogging()`, called by `History.Log()` / `History.Keep()` (any history view, Trim), by PSS_SavedData when PourSocialScoreDB still holds a logging key, by step 10 when a custom filter without an id may have lines, by a full purge list (200 marks), and by the outbox reaching 200 waiting lines (`History.LoadWhenQuiet`). Removing an owner never loads it (`History.ClearOwner`, S1).
- **Caps:** log `History.Cap()` (option `historyTotal`, 2000); keep 10 text, 5 party, 5 guild per owner. Owners: `p:<canon>`, `g:<canon>` (lines carry `gk`), `G:<gkey>` (recent counts only), `f:<id>` filters.

---

## 12. Player list flows
| Flow | Path |
| --- | --- |
| Add (command) | `/pss add Name[-Realm] [days] [note]` -> `ignoreFromCmd` -> `PSS_AddIgnore` -> `PSS_SplitNameArg` -> `AddToList` (`PSS_NewEntry`; record switches cleared so all block; delList cleared; chat purge; `PSS_PersonIdentified`) -> `ASK_NOTE` -> `PLAYERS_CHANGED` |
| Add (window) | Libraries `PSS_PlayerView` -> `PSS_AddPlayer(name, note, days, unit)` |
| Add (menu) | `PSS_UnitMenuPlayer` / LFG menu -> `PSS_AddOrDelIgnore` |
| Remove | `PSS_RemovePlayerAt` (Libraries) / `PSS_DelIgnore` -> `RemoveFromList` (delList, `PSS_ForgetPlayer`, `table.remove`) -> Blizzard ignore removed if present |
| Expire | `M.PSS_ExpireEntries` (login, daily after combat, window open, `/pss list`, `/pss sync`); `PruneIgnoreList(days)` is the manual age prune |
| W I G P C | Stored as blocked fields on `playerData`, saved only when false; UI tick = allowed. The "player" source's `decide`: W I G P C by `p[f] ~= false`, duel/trade by options with `{ person = p.opts }` exceptions |
| Blizzard ignore (B1) | Tick -> `PSS_SetBlizzardIgnore`. Blizzard Ignore -> post-hook -> `addFromBlizzard` (note "Synced from Blizzard ignore list on <date>", `pendingMove` unless ticked) -> next `IGNORELIST_UPDATE` `processMoves`. Unignore in Blizzard -> `removeFromBlizzard` -> `RemoveFromList`. First update after login: `syncFromBlizzard` (ticked, nobody removed) |

## 13. Guild list flows
| Flow | Path |
| --- | --- |
| Scan (row button) | Libraries `PSS_GuildView` -> `PSS_ScanGuild(name, "sweep", restart)` -> `PSS_HarvestNext` -> `Whois.Request` (SendWho from the click) -> cooldown 6 s, `GUILDS_CHANGED` |
| Answer | `WHO_LIST_UPDATE` or `CHAT_MSG_SYSTEM` -> listeners: `begin` opens `M.PSS__purgeBatch`; `info` -> `captureWho` -> `addWhoResultToGuildMember`; `finish`: one chat purge, `finishScan`: `PSS_ReconcileGuildMembers`, `PSS_HarvestAnswered`, `GUILD_SCAN_DONE`, `PSS_RequestGC("who results")` |
| Scan All | GUI button or key binding -> `PSS_ScanAll` (Libraries) -> next unswept rule -> `PSS_ScanGuild` |
| Guild Search | `PSS_GuildSearch` -> `GUILD_SEARCH_RESULTS`; `PSS_SaveGuildSearch` / `PSS_SaveGuildExclusions` |
| Members from play | Only while capture is wanted (P3): `scanUnit` -> `PSS_UpdatePlayerUnit` (only into an existing rule); a guild invite -> `inviteByGuild` |
| Rules | A rule is a "contains" match; the longest contained rule name owns a member; excluded guilds belong to none; own guild never blocked by a rule; a managed rule blocks only while its Chat Filters rule is on; a rule this version cannot use is skipped (U3) |
| Shipped lists without loading | Manifest gives names, counts and rule creation; membership needs the data, which loads at login only when a rule is on |
| Delta save | Rule records, non-shipped members (sparse), changed shipped members and `managedGone` tombstones are saved (`PSS_FlushManaged` at logout, then the 1500 cap) |

## 14. Right-click menu
`PSS_HookFunctions` (option `useUnitHacks`) -> `Menu.ModifyMenu` on `MENU_UNIT_ENEMY_PLAYER`, `_PLAYER`, `_PARTY`, `_RAID_PLAYER`, `_FRIEND`, `_FRIEND_OFFLINE`, `_CHAT_ROSTER`, `_GUILD`, `_COMMUNITIES_GUILD_MEMBER`, `_COMMUNITIES_MEMBER`, `_COMMUNITIES_WOW_MEMBER` -> `M.PSS_UnitMenuPlayer`:
1. Skips Battle.net-only entries, secret or empty names, and yourself.
2. Name from the unit or `contextData.name/server`, built with `M.PSS_NormName(name, server, unit)`.
3. Guild only from a real unit: `GetGuildInfo(unit)`, dropped if secret, empty or `PSS_IsOwnGuild`.
4. A divider, title `L["RCM_16"]` ("PSS"), "Block Player" / "Unblock Player" -> `PSS_AddOrDelIgnore` + `PSS_PlayersChanged(true)`; with a guild, "Block Guild" -> `PSS_AddGuild` or "Unblock Guild" -> `PSS_RemoveGuildNow`.
The LFG applicant menu keeps its own single toggle.

## 15. Name normalisation
Defined in `PourSocialScore/PSS_ChatBlock.lua` (A section 9):
| Function | Result |
| --- | --- |
| `joinName(name, realm, unit)`, `isSurname(unit)` (locals) | The one join; a second value is a surname for "player" or when `UnitRealmRelationship(unit) == LE_REALM_RELATION_SAME` |
| `M.PSS_NormName(name, realm, unit)` | display, key, canon |
| `M.PSS_UnitFullName(unit)`, `M.PSS_PlayerDisplayName()`, `M.PSS_FixUnitName(name)` | Unit name; your own; hook-path fix |
| `M.PSS_NormalizePlayer` / `M.PSS_CanonPlayer` / `M.PSS_DisplayPlayer` | Key / canon / display of a string |
| `M.PSS_CanonRealm`, `M.PSS_CanonGuild`, `M.PSS_OwnRealm` | Realm canon, guild canon, own realm |
| `M.PSS_SplitNameArg(str)` (PSS_Globals) | "Name rest" split |
| `M.PSS_CharKey` (PSS_Options) | `NormName(n, r, "player")` key |
| `M.PSS_RepairCamelotNames()` (Libraries `PSS_Camelot.lua`, step 10) | Saved `first-last` members (with a faction, no `_playerKey`), list entries, records and `delList` names -> `first last-<own realm>`; merges into a shipped member or a stored twin; lines and recent counts follow (`History.RenameOwner`) |

---

## 16. Findings (open)
1. **`PSS_KeepBlockedOnBuiltIn` does nothing when the shipped lists are not loaded** (group rule off): a removed player who is a shipped member gets no note or block flags.
2. **`M.PSS_RemoveGuild`'s first return is always 0** (kept for the old signature).
3. **Legacy fields still written:** `ensureGuild` writes `declineGuild`, `declineGroup`, `partyRaid` on every new rule (in the schema map, read once by `M.PSS_GuildBlock`).
4. **`PSS_PlayerRow` (Libraries) creates a player record** (`PSS_GetPlayerPrefs`) for a listed player without one, just by drawing the row.
5. **`PSS_AddOrDelIgnore` realm guess** reads `ChatFrameN.historyBuffer`; it keeps only the last matched realm.
6. **`inviteByGuild`** stores the inviter under the best rule even for your own guild (the own-guild check is only in `decide`).
7. **`M.PSS_ResetBlizzardIgnore`** calls the original `DelIgnoreByIndex` without `pssHookGuard`; harmless while its only caller (`/pss clear confirm`) empties the PSS list first.
8. **Exports used only in their own file or the harness:** `M.PSS_BestGuildRowFor`, `M.PSS_CapMembers`, `M.PSS_DEFAULT_SCAN_FIELDS`, `M.PSS_EXCL_INFO`, `M.PSS_EnsureManagedRules`, `M.PSS_MEMBER_CAP`, `M.PSS_MergeMemberBlockData`, `M.PSS_MoveOtherCopies`, `M.PSS_ReconcileGuildMembers`, `M.PSS__whoCaptured`, `M.PSS_ForgetPlayer`, `M.PSS_NewEntry`, `M.PSS_LFG_*` (hook bodies); Libraries `M.PSS_ScanLevelCap`, `M.PSS_ScanAllNextStale`, `M.prettyServer`. Event `WHOIS_ANSWERED` has no listener.
