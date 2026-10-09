# Core engine map (PourSocialScore core folder, 3.4.1.53)

Scope: the always-loaded core files that hold the engine, the data layer and startup, plus the Options folder. Out of scope here (other sections, `B_CORE_LISTS.md`): PSS_Whois, PSS_Communities, PSS_PlayerIgnoreList, PSS_PlayerQuery, PSS_GuildIgnoreList, PSS_BlizzardUI. Line counts are `wc -l`.

Shared handles: `addon` (the `...` table, also global `PourSocialScore_NS`), `M` (methods), `V` (runtime state), `L` (strings), `History` (= `M.PSS_History`).

## 0. Folders, TOCs and SavedVariables declarations

| Folder | TOCs | Loads | SavedVariables | Files |
| --- | --- | --- | --- | --- |
| `PourSocialScore` | base (`120007, 16001`), `_Mainline` (120007), `_Camelot` (16001) | Always; `## Dependencies: PourSocialScore_Options` | `PourSocialScoreDB` | 19 Lua files plus `Bindings.xml`, order: Localization, Globals, Loader, SavedData, Schema, Perf, Events, Whois, Communities, ChatHistory, ChatBlock, ChatFilters, PlayerIgnoreList, PlayerQuery, GuildIgnoreList, Upgrade, PourSocialScore.lua, Options, BlizzardUI |
| `PourSocialScore_Options` | same three | Always (before core) | `PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB, PSS_RulesDB, PSS_CountsDB` | `PSS_OptionsData.lua` (comment only: no code) |
| `PourSocialScore_Logging` | same three | On demand | `PSS_LoggingDB` | (B section 11) |

Every TOC carries `## Version: 3.4.1.53`, `## Category: PSS`, `## Group: PourSocialScore`. Gone since 3.4.1.38: `PSS_MainlineCompat.lua` (P1); `PSS_WhoisHarvest.lua` moved to Libraries (P6).

Note: PSS_Options.lua loads AFTER PSS_Upgrade.lua and PourSocialScore.lua; it is safe because nothing reads `M.PSS_OPTIONS` until startup (ADDON_LOADED + PLAYER_ENTERING_WORLD).

---

## 1. PSS_Localization.lua (412 lines)
Purpose: creates `addon.L` with English defaults (169 `L[...]` keys) and locale blocks (deDE, ruRU, zhCN filled; ptBR, frFR, esES/esMX, zhTW, koKR, itIT nearly empty). P1 removed 61 unused keys.

| Export | What |
| --- | --- |
| `addon.L` | String table. Metatable `__index` returns `BAD TEXT "<key>"` for a missing key (so `L[key]` is never nil). |

English key families (count): UPG 43 (the upgrade report: `UPG_HEAD`, `UPG_OLD`, `UPG_NOTHING`, `UPG_DONE`, `UPG_PAUSED`, `UPG_NEWER`, `UPG_CAMELOT_MAYBE`, `UPG_<feature>_<key>` phrases), OPT 28, HELP 19, RCM 15 (RCM_16..20 = B2 "PSS" header, Block/Unblock Player/Guild), CMD 15, MSG 5 (MSG_1 ignore auto-reply, MSG_2..5 decline texts), LOAD 5, LIST 5, BOX 5, INFO 4, ADD 4, plus TIP, SYNC, PART (loader), HISTORY, EXP, WARN, OLD_FOLDERS, NEWER, DAY/DAYS, ON/OFF, CHAT_1.
Notes: `INFO_5`/`INFO_6` are still assigned twice (lines 148 and 152/154); `OPT_3 = "UNUSED"`.
Used by: every file through `addon.L` / `PourSocialScore_NS.L`.

---

## 2. PSS_Globals.lua (262 lines)
Purpose: creates `addon.V` and `addon.M`; shared string/name helpers, dates, message output, the W I G P C table. The realm display names (`M.prettyServer`) moved to Libraries `PSS_PlayerRows.lua` (P6).

### Exports
| Group | Name | What |
| --- | --- | --- |
| Tables | `addon.V`, `addon.M` | Created here. |
| Strings | `M.trim(str)` / `M.PSS_Trim` | Trim whitespace; non-string gives "". |
| | `M.strDown(str)` | `string.lower`. |
| | `M.Proper(name, okSpaces)` | Title-case a name; keeps single spaces in the name part of "First Last-Realm" (Camelot); reused buffer. |
| | `M.PSS_SplitNameArg(str)` | Split typed "name [rest]": quotes, a "-" word in the first 3 words, or two words as one name off Retail or when "First Last" is listed (`M.PSS_IsPlayerListed`). Returns name, rest. |
| Realms | `M.getServer(name, def)` | Realm part after "-" or `def` or `V.serverName`. |
| | `M.removeServer(name, strict)` | Drop "-Realm" when it is your realm (or always with strict). |
| | `M.addServer(name)` | Append "-" .. `V.serverName` when no realm. |
| Dates | `M.MONTHS` | One month-name map (P5, N19). |
| | `M.dateToJulianDate(str)` | "dd Mon yyyy" -> whole day number, one match; today's number kept per day. |
| | `M.daysFromToday(str)` | Absolute days between that date and today, -1 when unreadable. |
| | `M.dayString(n)` | `L.DAY` / `L.DAYS`. |
| Output | `M.ChatMsg(text)` | `DEFAULT_CHAT_FRAME:AddMessage(text)` raw. |
| | `M.ShowMsg(msg)` | `print("Pour Social Score: " .. msg)` coloured. |
| | `M.debugMsg(msg)` | No-op (body commented out; 16 call sites left, N7). |
| Data | `M.EXCL` | The 5 W I G P C categories: `{cat, letter, field, label}` for whisper/W/whispersBlocked, partyInvite/I/partyInvitesBlocked, guildInvite/G/guildInvitesBlocked, partyRaid/P/partyRaidBlocked, world/C/channelsBlocked. |
| | `M.PSS_BLOCK_FIELDS`, `M.PSS_BLOCK_FIELD_SET` | The five player `*Blocked` fields from `M.EXCL` (P5, N21; PlayerIgnoreList, ImportExport). |

### V state set here
`V.serverName = M.Proper(GetRealmName())`, `V.playerName` (used by the list's sync tags), `V.wowIsRetail` (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or nil). `V.needSorted` and the other `V.wow*` flags are gone (P1).

Used by: trim/Proper/addServer/ShowMsg/ChatMsg everywhere in core and Libraries; `M.EXCL` by GUI `PSS_Players`, `PSS_Detail` and core; `M.removeServer` by Libraries `PSS_EventsView`, `PSS_DetailQuery`; `M.PSS_SplitNameArg` by core PlayerIgnoreList and Libraries `PSS_Commands`.

---

## 3. PSS_Loader.lua (67 lines)
Purpose: the one way core loads its load-on-demand parts.

| Export | What |
| --- | --- |
| global `PourSocialScore_NS = addon` | The single cross-addon global. |
| `M.PSS_PARTS` | `{GUI="PourSocialScore_GUI", Libraries="PourSocialScore_Libraries", Logging="PourSocialScore_Logging", Communities="PourSocialScore_Communities"}`. |
| `M.PSS_Need(key)` | Load a part (and `NEEDS` first: `GUI -> Libraries`): `EnableAddOn(name, UnitName("player"))`, `LoadAddOn`; prints `L.PART_1` once on failure and `L.PART_2` once on a version mismatch. Returns true/false. |
| `M.PSS_Stub(fname, key)` | Puts a stub at `M[fname]` that loads the part on first call and forwards to the real `M[fname]`. |

Stubs in core (each loads Libraries on first call): `PSS_SlashPSS`, `PSS_SlashGuild` (PourSocialScore.lua); `PSS_Validate`, `PSS_PrintValidation` (SavedData); `PSS_PlayerCount`, `PSS_PlayerRow`, `PSS_PlayerEntry`, `PSS_PlayerPosition`, `PSS_SortPlayers`, `PSS_RemovePlayerAt` (PlayerQuery); `PSS_HarvestNext`, `PSS_HarvestSent`, `PSS_HarvestAnswered`, `PSS_CapWhoFilter`, `PSS_ScanAll` (Whois).

---

## 4. PSS_SavedData.lua (256 lines)
Purpose: splits the saved data over the Options and Logging addons. `PourSocialScoreDB` gets a router metatable so code keeps writing `PourSocialScoreDB.<key>` while routed keys live in the Options/Logging tables; also moves keys from older layouts (upgrade steps 2 to 4).

| Export | What |
| --- | --- |
| `M.PSS_SV_GROUPS` | group -> global table name: options PSS_OptionsDB, players PSS_PlayersDB, guilds PSS_GuildsDB, rules PSS_RulesDB, counts PSS_CountsDB, logging PSS_LoggingDB. |
| `M.PSS_SV_ROUTE` | key -> group (built from `LAYOUT` + every `M.PSS_OPTIONS` key). |
| `M.PSS_PrepareSavedData(opts)` | `opts.wipe` (reset), `opts.quiet`, `opts.startup`. Sets router; loads Logging when its keys still sit in PourSocialScoreDB or upgrade step is 3; creates/empties tables of loaded owners; moves keys saved in the wrong group; moves routed keys still raw in PourSocialScoreDB, checked with `M.PSS_Validate().n` before/after (undo + message if different). The check runs only on a login where keys move and the save is not new (so a fresh install loads nothing extra; a 2.0 save loads Libraries once). Returns false when PourSocialScore_Options is not loaded (startup stops). |
| `M.PSS_SavedDataSplit(owner)` | True once that owner's data is split (used by upgrade steps 2/3/4). |

`LAYOUT` (retired keys stay listed so a step can still clear them in the owner table):
- options: `showIgnoreDebug`, `windowSizes`, `windowPoints`, `columnWidths`, `charOptions`, `optionsV2012`, `euiIntegration`, `blizzardSync`
- players: `list`, `delList`, `playerData`, and the retired arrays `ignoreList`, `typeList`, `factionList`, `dateList`, `notes`, `expList`, `syncInfo`
- guilds: `guildData`, `guildExclusions`, `guildGroupOpen`, `scanFieldsDefaultV1`, `guildPlayerCleanupV3`
- rules: `filterList`, `filterDesc`, `filterActive`, `filterID`, `builtinRules`, `filterFormat`, `optInFiltersV1`, `nextFilterId`
- counts: `blockStats`, `historyFormat`, `hiddenTotal`, `filterTotal`, `filterWhisperTotal`, `filterPrivateTotal`, `filterCount`, `filterBlocked`, `filterBlockedLast`, `builtinStats`, `guildRuleCountsV1`
- logging: `blockLog`, `blockKeep`

---

## 5. PSS_Schema.lua (67 lines, data only; U3, 3.4.1.47)
`M.PSS_SCHEMA`: one string per record kind listing its saved fields as `name`, `name=default` or `name@reader`. Kinds: `core` (PourSocialScoreDB's own keys: upgrade outbox purge recent session sessionStart revision imported importedFrom importedLegacyAt logAllV1), `upgrade`, `entry` (a `list` record), `player`, `playerOld`, `guild`, `guildOld` (includes `memberCount`), `member`, `memberOld` (the `_` runtime fields), `block`, `counts`, `filterStat`, `builtinStat`, `line`, `lineOld`, `logGroup`. Read through `M.PSS_SchemaKnows(kind, field)` (PSS_Upgrade.lua). `tools/check_schema.lua` fails a written key or a saved field the map does not list. **Any change that saves a new field adds it here in the same PR.**

---

## 6. PSS_Perf.lua (277 lines)
Purpose: incremental garbage collection (`collectgarbage("step")` spread over frames) on request only, and the `/pss mem` report. Event-driven since P2 (3.4.1.52): no ticker, no idle cycle, no wall-clock gate.

| Export | What |
| --- | --- |
| `M.PSS_GCState` | `{pending, running, lastCycle, heapAfter, waiting, supported, frames, cycles, lastReason, lastMs}`. |
| `M.PSS_RequestGC(reason)` | Starts a cycle now when quiet; else marks it pending and calls `M.PSS_GCWatch(true)`. |
| `M.PSS_GCWatch(on)` | Registers or drops the wake events `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ALIVE`, `PLAYER_UNGHOST` (only while a request waits). |
| `M.PSS_MemReport(full)` | Prints memory of the addon and parts, block history size (by owner type, top 10 with `full`), list sizes, `M.PSS_ManagedStats()`, chat filter count, GC state. |

Constants: STEP_KB 8, STEP_BUDGET_MS 1.0, MIN_FPS 30, MAX_FRAMES 900 (a long cycle pauses and resumes at the next wake event).
Locals: `busyReason()` (combat, encounter, dead, dungeon/raid/pvp/arena via `IsInInstance`), `runner` frame (OnUpdate only while a cycle runs; stops at the first busy frame and waits again), `startCycle`, `stopCycle`, `wake` frame.
WoW events: `PLAYER_LOGIN` once (request "login"); the wake events only while waiting. Option read: `gcEnabled` (off while waiting drops the wake events).
Used by: `M.PSS_RequestGC` from GUI `PSS_Window` (close), Libraries `PSS_ImportExport`, core GuildIgnoreList, Upgrade, ChatHistory; `M.PSS_MemReport` / `M.PSS_GCState` from Libraries `PSS_Commands`.

---

## 7. PSS_Events.lua (71 lines)
Purpose: the core event bus.

| Export | What |
| --- | --- |
| `M.Events.Register(event, fn)` | Returns an id. |
| `M.Events.Unregister(event, id)` | |
| `M.Events.Fire(event, ...)` | Calls every listener in `pcall`; an error goes to `M.PSS_NoteListenerError(event, err)`. |
| `M.PSS_NoteListenerError(where, err)` | (N46, F1) counts in `M.Events.errors {count, last, shown}`, prints once per `where` in red; `/pssguild status` shows the count. Also used by the /who handlers. |

Used by every file that fires or listens; GUI listens through `ns.Listen` (only while the window shows) and `PSS_Window` registers `OPTION_CHANGED` directly.

---

## 8. PSS_ChatHistory.lua (1325 lines)
Purpose: the block history module (`History`): entries, the shared capped log, the per-person packed keep, the outbox while Logging is not loaded, recent counts (session and 24 h), owner keys, purge by owner, tidy-up and old-format migrations.

### Exports: constants and tables
| Name | What |
| --- | --- |
| `M.PSS_History` (= `History`) | The module. |
| `History.UNKNOWN` | "Unknown". |
| `History.CAT_ORDER`, `History.CAT_LABEL`, `History.CAT_COLOR`, `History.ALL_CATS` | Category order, labels, colours (incl. guildChat, unknown); `ALL_CATS` = whisper, partyInvite, guildInvite, partyRaid, world, guildChat, unknown. |
| `History.sourceLabel` | Weak-key entry -> tooltip label. `History.SetSource(h, label)`. |
| `History.DEFAULT_TOTAL/MIN_TOTAL/MAX_TOTAL` | 2000 / 100 / 20000. |
| `History.EntryMT` | Metatable deriving `time` (from ts) and `kind` (from cat). |
| `History.KEEP` | `{text=10, party=5, guild=5}` per person. `History.KEEP_TOTAL = 2000`. `History.LOG_ALL = true`. |
| `History.EventLetter`, `History.LetterEvent` | Event <-> one letter for packed lines. |
| `History.SLOT = 600`, `History.DAY_SLOTS = 144` | Recent-count slots (10 min, 24 h). |
| `History.PURGE_CAP = 200` | Most owners marked in `PourSocialScoreDB.purge` (S1). |

### Exports: functions
| Group | Function | What |
| --- | --- | --- |
| Time | `History.Now()`, `History.FormatTime(ts)`, `History.ParseTime(s)` | Server time; "%d %b %Y %H:%M:%S"; two old string formats -> time. |
| Entries | `History.Bucket(cat)`, `History.Normalize(h)` | Category bucket; idempotent migration of an old entry. |
| | `History.NewEntry(cat, event, message, channel, member)` | New entry; a secret message is replaced with "(message hidden by the client)". |
| Counts | `History.EmptyCounts()`, `History.EnsureCounts(c)` | Counts table (a missing type reads 0). |
| | `History.CountTotal(c)` | (S2) the larger of `total` and the types added up; the one way a total is read. |
| | `History.CompactCounts(c)` | (S3) drops zero types and a `total` not above the sum; false when nothing is left to save. |
| Log | `History.Cap()` | Option `historyTotal` clamped. |
| | `History.Loaded()` / `M.PSS_LoggingReady` | Logging loaded and merged. |
| | `History.Waiting()` | Outbox length. |
| | `M.PSS_LoadLogging()` | `PSS_Need("Logging")`, `PSS_PrepareSavedData()`, `History.UnpackSaved`, `History.KeepToLog` (once), `History.ApplyPurge()`, outbox -> log, `CapKeep(true)`, `Trim(true)`, `M.PSS_TidyBlockHistory()`. |
| | `History.LoadWhenQuiet()` | (P2) loads Logging now, or out of combat and instances: waits on `PLAYER_REGEN_ENABLED`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`, registered on a frame only while waiting. |
| | `History.Log()` | Loads Logging; returns `db.blockLog` (oldest first). |
| | `History.Trim(force)` / `History.TrimAll` / `M.PSS_TrimAllHistory` | Cut the log to the cap (batches at 5 % over); people's dropped lines settle into the keep. |
| | `History.Add(owner, counts, entry, ruleTag)` | THE write path: sets `entry.o`/`r`, bumps `counts[cat]` and `counts.total` (from `CountTotal`), `CountRecent`, then outbox (Logging not loaded; past cap + max(20, cap/20) the oldest go in one move, P4 N31; at 200 waiting `C_Timer.After(1)` then `LoadWhenQuiet`) or log + `Trim(false)`. |
| Keep | `History.Keep()`, `History.KeepKind(h)`, `History.KeepsOwner(o)` | Loads Logging; kind of a line; owner is "p:"/"g:". |
| | `History.PackLine`, `History.UnpackLine`, `History.UsualChannel` | Packed line format `<type><ts>\t<ev>\t<channel>\t<msg>`. |
| | `History.KeptLines(o)` (harness), `History.CapKeep(force)`, `History.SettleKeep`, `History.SettleAllKeep`, `History.KeepSize()`, `History.KeepChanged()` | |
| Walk | `History.Each(fn)`, `History.Collect(pred)`, `History.For(owner)`, `History.CountFor(owner)` (harness), `History.Where(owner)` | Iterate / filter newest-first / count. |
| | `History.Clear(pred)` | Remove matching lines from log and keep; requests GC (guild reset). |
| | `History.ClearOwner(o, mayHave)` | (S1) one owner's lines: Logging loaded -> log walk + `keep[o] = nil`; not loaded -> its outbox lines go and, unless `mayHave == false`, `PourSocialScoreDB.purge[o] = true` (full at 200: Logging loads and clears now). Used by every removal and owner reset. |
| | `History.ApplyPurge()` | Applies and clears the purge marks (from `M.PSS_LoadLogging`). |
| | `History.RenameOwner(from, to)` | (S3) moves outbox lines, recent counts and (when loaded) log and keep from one owner to another (filter ids, Camelot repair). |
| | `History.Tidy(alive)` | Drop lines of owners that no longer exist; clear dead `r`/`gk` tags. |
| Owner keys | `History.PlayerKey(name)` -> "p:<canon>", `History.MemberKey(m)` -> "g:<canon>", `History.FilterKey(id, text)` -> "f:<id>" (string or number id) or "f:t:<text>", `History.GuildKey(gkey)` -> "G:<gkey>" | |
| Recent | `History.CountRecent(owner, ts, cat)`, `History.RecentCounts(owner)`, `History.RecentTotals(prefix)`, `History.RecentByCatData()`, `History.RecentSlots(owner)`, `History.ForgetRecent(owner)` | Session count + 10-minute slot + `day[owner]`; `History.RecentByCat` itself is defined in Libraries `PSS_TotalsQuery.lua`. |
| | `History.SessionStart()`, `History.StartSession(initial, reload)`, `History.EndSession()` | Session bookkeeping (PEW / PLAYER_LOGOUT). |
| Misc | `History.EstimateBytes()` | For /pss mem. |
| Migration | `History.Absorb(sources)`, `History.CountList(list)`, `History.Sig(h)`, `History.MigrateOldFilterEntry(e)`, `History.MigrateFilterList(list, last)` | Old per-owner lists and the old filter ring buffer -> the log. |

Locals: `ready`, `loadQueued`, `OUTBOX_LOAD` (200), `watchQuiet`, `attached` (weak set), `keepTotal`, `sessionCat` (never saved), `dropLines`, `dropWaiting`, `recent(cur, create)`.
SavedVariables (raw in PourSocialScoreDB): `outbox`, `recent`, `purge`, `session`, `sessionStart`, reads `logAllV1`; routed: `blockLog`, `blockKeep` (PSS_LoggingDB).
Used by: core PlayerIgnoreList, GuildIgnoreList, ChatFilters, Upgrade, Perf, PourSocialScore.lua; Libraries `PSS_DetailQuery`, `PSS_EventsQuery`, `PSS_EventsView`, `PSS_FilterQuery`, `PSS_GuildQuery`, `PSS_GuildView`, `PSS_TotalsQuery`, `PSS_Camelot`; GUI `PSS_Detail`, `PSS_Events`, `PSS_History`; Logging `PSS_SavedLog`.

---

## 9. PSS_ChatBlock.lua (892 lines)
Purpose: the chat block core. One message-event filter for every chat event, decision cache per line, person sources and handler registries, name normalisation (N1), invites/duels/trades, group and whisper alerts, chat purge.

### Exports
| Group | Name | What |
| --- | --- | --- |
| Secrets | `M.PSS_IsSecret(v)` | `issecretvalue(v) == true` (feature-detected). |
| Names | `M.PSS_OwnRealm()` | `GetNormalizedRealmName()` (cached), fallback `GetRealmName()` without spaces/dashes. |
| | `M.PSS_NormName(name, realm, unit)` | display, key, canon (nil when secret/empty). With a unit, a second value is a surname when `UnitRealmRelationship(unit) == LE_REALM_RELATION_SAME` (always for "player"): "First Last-<own realm>". |
| | `M.PSS_UnitFullName(unit)`, `M.PSS_PlayerDisplayName()`, `M.PSS_FixUnitName(name)` | Unit's full name; your own; hook paths' "First-Last" -> "First Last-<realm>" when a unit has that name and surname. |
| | `M.PSS_NormalizePlayer(name)`, `M.PSS_CanonPlayer(name)`, `M.PSS_DisplayPlayer(name)` | Storage key, matching key, display form of a string. |
| | `M.PSS_CanonRealm(realm)`, `M.PSS_CanonGuild(name)` | Lowercase canon forms; `CanonGuild` checks for a secret before its cache (500 entries; P4 N28). |
| | `M.PSS_NowString()` | Server time "%d %b %Y %H:%M:%S". |
| Categories | `M.PSS_EventCategory(event)` | Event -> whisper/partyRaid/world/guildChat/other/npc/system (local `EVENT_CATEGORY`, 41 events). |
| | `M.PSS_BLOCK_LABELS` | Labels from History plus other/duel/trade (debug lines). |
| | `M.PSS_ChannelLabel(event, channelString, chNumber, chName)` | Channel label for history. |
| Registry | `M.PSS_RegisterBlockSource(def)` | Person source `{id, order, label, lookup, decide, record, optionContext, describe, inviteByGuild}`. Registered: "player" (10), "guild" (20). |
| | `M.PSS_RegisterBlockHandler(kind, id, fn)` | kind system/npc/realm/text. Registered: system "ignoreList", npc "npcIgnore", realm "serverIgnore" (PlayerIgnoreList), text "chatFilters" (ChatFilters). |
| Engine | `M.PSS_CoreFilter`, `M.PSS_FilterAvailable`, `M.PSS_CoreStats`, `M.PSS_CoreDebug` | The filter function; filter API present; `{checked, personHits, hidden, errors, ...}`; debug switches (`/pssguild debug`). |
| | `M.PSS_PersonHits` (harness), `M.PSS_ExplainPerson(name)`, `M.PSS_PersonListed(name)`, `M.PSS_PersonIdentified(name)` | Dry run; listed check (group warning); re-check a pending party invite. |
| Chat purge | `M.PSS_PurgeChatFrom(keys)` | Removes shown lines with `|Hplayer:` links of those canon keys via `RemoveMessagesByPredicate` (option `purgeHistory`; approved override). |
| Test | `M.PSS__CoreTest` | Handles for the harness ("used only by tools/harness"). |

Gone since 3.4.1.38 (P1): `M.PSS_EVENT_CATEGORY`, `M.PSS_CoreEvents`, `M.PSS_BLOCK_CATEGORIES`, `M.PSS_GetBlockSources`, `M.PSS_ChatFrames`, `M.PSS_ParseTimeString`, `M.PSS_NormalizeBlockEntry`.

### WoW events and Blizzard APIs
- `ChatFrameUtil.AddMessageEventFilter` (fallback the old global) for all 41 events, at file load.
- Frame events (always): `PARTY_INVITE_REQUEST`, `PARTY_INVITE_CANCEL`, `GUILD_INVITE_REQUEST`, `DUEL_REQUESTED`, `TRADE_SHOW`, `TRADE_REQUEST` (pcall), `GROUP_ROSTER_UPDATE`, `CHAT_MSG_WHISPER_INFORM`.
- Calls: `DeclineGroup`, `StaticPopup_Hide(...)`, `DeclineGuild` / `C_GuildInfo.DeclineGuild` (+ a 0.2 s re-check), `CancelDuel`, `CancelTrade`, `C_ChatInfo.SendChatMessage` (auto-reply `L.MSG_1`, 300 s per sender, 2 s global), `RemoveMessagesByPredicate`, `UnitRealmRelationship`, `UnitName`, `UnitGUID`, `GetNormalizedRealmName`.
- Fires: `WHISPER_WARNING (name, label)`. Writes `hiddenTotal` (+1 per hidden line). Options read: `ignoreResponse`, `showDeclines`, `purgeHistory`, `listWarnings`.

---

## 10. PSS_ChatFilters.lua (1055 lines)
Purpose: text filters: built-in rule definitions (code), custom rules (saved, with never-reused ids), the runtime expand/collapse of filter arrays, the filter language compiler, and the "text" handler.

### Built-ins
13 text filters, all default OFF: PSS0001 "Anal" spammers, PSS0002 Thunderfury, PSS0003 M+/Raid sellers, PSS0013 Tradeskill sellers, PSS0014 Power leveling, PSS0008 Guild recruitment, PSS0009 Community recruitment, PSS0010 WTS, PSS0011 Chinese/Korean/Japanese, PSS0012 American politics, PSS0015 Asmon, PSS0016 Olympus, PSS0017 Cyrillic. Plus one guild rule per `addon.MANAGED.groups` entry ("InfluencerGuild=<Name>", default off).

### Exports
| Group | Name | What |
| --- | --- | --- |
| Storage | `M.PSS_FilterOwnerKey(i)` | `History.FilterKey(filterID[i], filterList[i])`: "f:<id>" for a custom filter with an id, built-ins "f:PSS00NN", "f:t:<text>" for a filter an older version saved without one. |
| | `M.PSS_FilterCounts(i)`, `M.PSS_FilterHistory(i)` | Per-type counts table; `History.For` its lines. |
| | `M.PSS_ResetFilterHistory(i)`, `M.PSS_ResetFilterCount(i)` | `History.ClearOwner` + forget recent + counts (FILTER_HISTORY_CHANGED); row count to 0 (FILTERS_CHANGED). |
| Ids | `M.PSS_NewFilterId()` | (S3) next id from `nextFilterId` (only goes up, stays above any number id found). |
| | `M.PSS_AssignCustomFilterIds()` | (step 10) gives every custom filter without one an id and moves its history with `History.RenameOwner`; loads Logging first when one may have lines. |
| | `M.PSS_AssignLegacyFilterIDs()` | Very old saves: IDs by description (step 1). |
| Edit | `M.RemoveChatFilter(i)` | `History.ClearOwner`, removes index i from every `M.PSS_FILTER_ARRAYS` array; FILTERS_CHANGED. |
| | `M.ResetSpamFilters()` | Rebuild every array from the built-ins; clears `builtinRules`, `builtinStats`, `invertSpam`, `spamFilter`. |
| | `M.PSS_CopyChatFilter(i)`, `M.PSS_AddCustomFilter(desc, filter, active)` | New custom rule (own id). |
| | `M.PSS_SetFilterActive(i, on)`, `M.PSS_SaveChatFilter(i, desc, filter)` | Toggle (a guild rule also loads managed data, marks the guild index dirty); edit text (keeps id and history). |
| Kinds | `M.PSS_IsBuiltinFilterID(id)`, `M.PSS_IsBuiltinFilter(i)`, `M.PSS_IsGuildRuleText(text)`, `M.PSS_IsGuildRuleFilter(i)` | |
| | `M.PSS_ManagedGroupFilterIndex(k)`, `M.PSS_ManagedGroupActive(k)`, `M.PSS_SetManagedGroupActive(k, on)` | Managed community rule on/off. |
| | `M.PSS_FILTER_ARRAYS` | filterList, filterDesc, filterActive, filterID, filterCount, filterBlocked, filterBlockedLast (shared with the upgrade, P5). |
| | `M.PSS_ExpandFilters()`, `M.PSS_CollapseFilters()` | Saved -> runtime arrays at startup (keeps a number id and an unknown built-in rule, U3); runtime -> saved at logout (counts compacted). |
| | `M.PSS_UnlinkGuildRuleCounts()` | 2.0.39 once (`guildRuleCountsV1`). |
| Engine | `M.PSS_CompileFilter(text)` | Text -> tree or false (cached); used by U3's unusable-rules check. |
| | `M.filterComplex(filterStr, chatStr, chNumber, chName)` | Test one filter (editor; sets `V.lastFilterError`) or run every active text filter. |
| | `M.PSS_ChatFilters_Evaluate(ctx)` | The text handler. |

Filter language tags (`KNOWN_TAGS`): [word] [contains] [chname] [channel] [words] [item] [spell] [achievement] [icon] [pet] [link] [trade] [guild] [outfit] [journal] [mount] [community] [nonlatin] [talent] (N42, F1) [cyrillic]; operators `not`, `and`, `or`, brackets, backslash escape.
Fires: `FILTERS_CHANGED` (edits, toggles, resets; no longer per blocked line, G21), `FILTER_HISTORY_CHANGED (i)` (each filter block, history reset).
SV (routed): rules `filterList, filterDesc, filterActive, filterID, builtinRules, filterFormat, optInFiltersV1, nextFilterId`; counts `filterTotal, filterWhisperTotal, filterPrivateTotal, filterCount, filterBlocked, filterBlockedLast, builtinStats, guildRuleCountsV1`. `ruleLists()` reads `filterList`/`filterActive` past the router (P4, N26).

---

## 11. PSS_Upgrade.lua (768 lines)
Purpose: numbered run-once saved data upgrade steps (a registry of feature-tagged parts, U1), the `RETIRED` list, the upgrade report (U2), version order, forward compatibility (U3: schema lookups, unusable rules). The save check moved to Libraries `PSS_Validate.lua` (P6).

| Export | What |
| --- | --- |
| `M.PSS_UPGRADE_STEPS` (10), `M.PSS_UPGRADE_REGISTRY`, `M.PSS_UPGRADE_FEATURES`, `M.PSS_UPGRADE_PHRASES`, `M.PSS_UPGRADE_RETIRED` | The registry `{id, always, parts = {{feature, fields, data}}}`, features, phrase keys per feature, retired keys (read only; the harness checks them). |
| `M.PSS_RunUpgradeFields(fresh, defaults)` | Every step's `fields` part due; decides whether this login reports (not fresh, and a step due or the version differs); a downgrade (`M.PSS_VersionOrder(rec.version, version) == 1`) prints `L.UPG_NEWER` and runs nothing. |
| `M.PSS_RunUpgradeData(fresh)` | Every `data` part, then the `RETIRED` loop, then writes `upgrade = {step, version, at}` and prints the report when it counted anything (head line, a line per feature, the cleanup line always, "Saved data upgraded to X (step N)." or the red paused line). |
| `M.PSS_UpgradeText()` | "step N of 10, version V, date" (for /pss mem, check). |
| `M.PSS_VersionOrder(a, b)` | -1, 0, 1 or nil; `X.Y.Z.B` by numbers; older names are older. |
| `M.PSS_SchemaKnows(kind, field)` | Is the field in `M.PSS_SCHEMA[kind]` (set built on first use). |
| `M.PSS_GuildRuleUnusable(g)`, `M.PSS_UnusableRules()` | A rule this version cannot use (unknown shipped list or a field the map does not name); the unusable filters, guild rules and settings (counted on the report, exported by `/pss export unused`). |

`RETIRED` (dropped every login after the data parts): `autoIgnore`, `autoUpdate`, `autoCount`, `autoTime`, `attachFriends`, `syncList`, `filterHistory`, `blockStats`, `optionsV2012`, `charOptions`, `historySize`, `euiIntegration`, `windowSizes`, `columnWidths`, `blizzardSync`, `ignoreList`, `typeList`, `factionList`, `dateList`, `notes`, `expList`, `syncInfo`, `showIgnoreDebug`.
Locals: `tally(feature, key, n)`, `dropRetired`, `runPart`, `printReport`, `isCamelot`, `hasNames`, `camelotRepair`.
Used by: PourSocialScore.lua; Libraries `PSS_Commands`, `PSS_ImportExport` (`PSS_SchemaKnows`, `PSS_UnusableRules`), `PSS_Validate`; Perf (`PSS_UpgradeText`); core GuildIgnoreList (`PSS_GuildRuleUnusable` through the unusable set).

---

## 12. PourSocialScore.lua (317 lines)
Purpose: startup, the legacy one-time import, the group warning, logout work, the history tidy, and the slash command stubs.

| Export | What |
| --- | --- |
| `V.PSS_Loaded`, `V.PSS_SyncOK`, `V.PSS_InSync`, `V.lastFilterError`, `V.groupWarning`, `V.PSS_LoadedTime`, `V.faction` | Runtime state (`PSS_SyncOK` is written, never read). |
| `M.PSS_TidyBlockHistory()` | Builds `alive` checks (listed players, guild members via `M.PSS_LookupGuildMember`, filters via `M.PSS_FilterOwnerKey`, also a filter's text key once it has an id; an owner form this version does not make is kept, U3) and calls `History.Tidy`. |
| `M.PSS_ImportLegacyDB()` | When PourSocialScoreDB is nil and an old addon's DB exists: deep copy, record `importedLegacyAt`, `importedFrom`. |
| Globals | `SLASH_PSS1 = "/pss"`, `SLASH_PSSGUILD1 = "/pssguild"`, `SlashCmdList.PSS`, `SlashCmdList.PSSGUILD` -> `M.PSS_SlashPSS` / `M.PSS_SlashGuild` (stubs that load Libraries); `PSSFRAME` (declared local, assigned at the end). |

Locals: `ApplicationStartup` (F), `EventHandler`, `CheckGroupForIgnored` (1 s after roster updates, deferred out of combat; N47: `V.groupWarning` rebuilt from the roster on each check; fires `GROUP_WARNING`), `deepCopy`.
WoW events (frame `PSSFRAME`): `PLAYER_ENTERING_WORLD`, `ADDON_LOADED` (both unregistered after startup), `GROUP_ROSTER_UPDATE`, `PLAYER_LOGOUT`, `PLAYER_REGEN_ENABLED` (deferred roster check; `M.PSS_ExpireEntries(false, true)` at most once a day). The `IGNORELIST_UPDATE` registration is gone (P1).

---

## 13. PSS_Options.lua (166 lines)
Purpose: the one option table and its resolution (person > guild > global > default); only non-default values are saved.

| Export | What |
| --- | --- |
| `M.PSS_OPTIONS` | List of 30 option definitions (D). |
| `M.PSS_OPTION_REG` | key -> definition. |
| `M.PSS_OPTION_SECTIONS` | Ignore list, Blocking Options, Chat filtering, User interface, Whois Scan Options. |
| `M.PSS_CharKey()` | Your character key through `M.PSS_NormName(n, r, "player")` (cached; fills the export's `by` field). |
| `M.PSS_Opt(key, ctx)` | `ctx = {person=opts, guild=opts}` for `target = true` options; then the raw `PourSocialScoreDB` value, then `PSS_OptionsDB` directly (no router, P4 N26); then default. |
| `M.PSS_FrameStrataName()` | LOW/MEDIUM/HIGH/DIALOG from `frameStrata`. |
| `M.PSS_SetOpt(key, scope, value, target)` | "global": store or nil when default; "guild"/"person": `target.opts[key]` (calls `M.PSS_KeepManaged(target)`); fires `OPTION_CHANGED (key)`; `historyTotal` trims history now. The reload branch is gone (P1). |
| `M.PSS_ApplyOptionDefaults()` | Drops saved values equal to their default (every login); returns the count for the report. |

---

## A. The chat line pipeline (end to end)

1. **Event in.** The client calls `CoreFilter(frame, event, msg, author, ...)` once per chat window per line.
2. **Category and secrets.** `cat = EVENT_CATEGORY[event]` (unknown: pass). Secret `author` or `guid`: pass (not counted). Secret channel fields are dropped. A secret `msg` still reaches person rules (decision 1 exception).
3. **Decision cache.** Key = `lineID`, else `event..author..msg..half-second`, 256-slot ring.
4. **`evaluate(ctx)`** (in pcall; an error passes the line uncached):
   1. `cat == "system"`: system handlers (`ignoreList`: hides ERR_IGNORE_FULL, sync noise, online/offline of listed people/servers).
   2. Not `V.PSS_Loaded`: pass. `cat == "npc"`: npc handlers.
   3. `canon` from the GUID cache or `M.PSS_CanonPlayer`; `ctx.isSelf`.
   4. Not self: **people**: every source's `lookup(canon)` then `decide(entry, cat)`. Player source: a missing W I G P C switch blocks (`p[f] ~= false`). Guild source: only while the rule is active and usable, not excluded, not your own guild, then `memberBlocks`. Hits -> each source's `record`:
      - player: `M.PSS_RecordPlayerBlock` -> `History.Add("p:<canon>", p.blockCounts, entry)`, fires `PLAYER_BLOCKED`.
      - guild: `History.Add("g:<canon>", m.blockCounts, entry)` plus `History.CountRecent("G:<gkey>")`, then `GUILD_BLOCKS_CHANGED` at most every 0.25 s.
   5. Not self and not hit: **realm** handlers (`serverIgnore`).
   6. **Text** (whisper/partyRaid/world/guildChat, not GM/DEV, not secret msg): `M.PSS_ChatFilters_Evaluate(ctx)`: `spamFilter`, skips, flood filter (ring of 50), `M.filterComplex` over active non-guild-rule filters. A match: `filterTotal`, `filterCount[i]`, whisper/private totals +1; `History.Add(M.PSS_FilterOwnerKey(i), filterBlocked[i].counts, entry)`; fires `FILTER_HISTORY_CHANGED (i)`.
5. **After a block** (once per line): `stats.hidden`, `hiddenTotal` +1; a blocked whisper from a person or realm rule may send `L.MSG_1` (`ignoreResponse`, throttled).
6. **History.Add**: counts on the owner record (always loaded), recent counts, then the outbox (Logging not loaded) or the log. When Logging loads, purge marks are applied and the outbox joins the log.

Invites, duels, trades use the same sources (`handlePartyInvite`, `handleGuildInvite` with `inviteByGuild`, `handleDuel`, `handleTrade`) and print a decline line when `showDeclines`.

## B. SavedVariables layout map (as saved at 3.4.1.53, sparse)

| Saved table (addon) | Keys | Owning code |
| --- | --- | --- |
| `PourSocialScoreDB` (core) raw keys | `upgrade {step, version, at}`, `outbox` (lines waiting for Logging), `purge {[owner] = true}` (only while marks wait), `recent {v=2, last, day, [1..144]}`, `session`, `sessionStart`, `imported`, `importedLegacyAt`, `importedFrom`, `revision`, `logAllV1` | Upgrade, ChatHistory, PourSocialScore.lua, SavedLog |
| `PSS_OptionsDB` (Options) | every `M.PSS_OPTIONS` key (non-default only), `windowPoints` (PSS_Window, PSS_WindowTab) | PSS_Options, Libraries ViewNav |
| `PSS_PlayersDB` (Options) | `list` (one sparse record per entry: `name, date [kind] [faction] [note] [exp] [sync]`, S2b), `delList`, `playerData` (records keyed by player; a W I G P C switch only when false, S3) | PlayerIgnoreList |
| `PSS_GuildsDB` (Options) | `guildData` (rules; members sparse, no `memberCount`, at most 1500 plain members per rule), `guildExclusions`, `guildGroupOpen`, `scanFieldsDefaultV1`, `guildPlayerCleanupV3` | GuildIgnoreList |
| `PSS_RulesDB` (Options) | `filterList`, `filterDesc`, `filterActive`, `filterID` (custom rules only; number ids), `builtinRules {id = on}`, `filterFormat`, `optInFiltersV1`, `nextFilterId` | ChatFilters |
| `PSS_CountsDB` (Options) | `historyFormat`, `hiddenTotal`, `filterTotal`, `filterWhisperTotal`, `filterPrivateTotal`, `filterCount`, `filterBlocked [{counts}]` (compacted), `filterBlockedLast`, `builtinStats {id = {count, blocked, blockedLast}}`, `guildRuleCountsV1` | ChatFilters, ChatBlock, GuildIgnoreList |
| `PSS_LoggingDB` (Logging, on demand) | `blockLog` (packed v2 groups; `m` only when not derivable), `blockKeep` | ChatHistory, Logging PSS_SavedLog |

Routing: `PourSocialScoreDB`'s metatable sends a LAYOUT key to its group table only while the owning addon is loaded; otherwise the key is stored raw in PourSocialScoreDB (and moved on the next prepare).

## C. M.Events catalogue (fired by files in this scope)

| Event | Args | Fired by | Listeners |
| --- | --- | --- | --- |
| `OPTION_CHANGED` | key | `M.PSS_SetOpt` | GUI `PSS_Options` (ns.Listen), GUI `PSS_Window` (Register), core BlizzardUI (hooks on the first enable, N41) |
| `FILTERS_CHANGED` | - | ChatFilters edits, Libraries ImportExport | GUI `PSS_Filters`, GUI `PSS_Guilds` (G26), core GuildIgnoreList (`M.PSS_ApplyCapture`) |
| `FILTER_HISTORY_CHANGED` | filterNum | ChatFilters | GUI `PSS_Filters`, GUI `PSS_Events` |
| `WHISPER_WARNING` | name, label | ChatBlock | core BlizzardUI |
| `GROUP_WARNING` | names | PourSocialScore.lua | core BlizzardUI |

Other events on the bus (fired outside this scope): `WHOIS_COOLDOWN`, `WHOIS_ANSWERED` (no listener), `ASK_NOTE`, `PLAYERS_CHANGED`, `PLAYER_BLOCKED`, `GUILDS_CHANGED`, `GUILD_BLOCKS_CHANGED`, `GUILD_SCAN_DONE`, `GUILD_REMOVED`, `GUILD_SEARCH_RESULTS`.

## D. Options (`M.PSS_OPTIONS`, 30 keys)

`target = true` means it can be overridden per guild rule and per person (`opts` on the record).

| Section | Key | Kind | Default | Notes |
| --- | --- | --- | --- | --- |
| 1 Ignore list | asknote | bool | true | |
| | sameserver | bool | true | |
| | samefaction | bool | true | |
| | trackChanges | bool | true | |
| | chatmsg | bool | true | |
| | listWarnings | bool | true | group / whisper warnings |
| | showWarning | bool | true | sync failure warning |
| | defexpire | number | 0 | |
| 2 Blocking | ignoreResponse | bool | false | target |
| | showDeclines | bool | false | target |
| | declineDuel | bool | true | target |
| | declineTrade | bool | true | target |
| | historyTotal | number | 2000 | min 100, max 20000 |
| | purgeHistory | bool | true | chat purge on block |
| 3 Chat filters | spamFilter | bool | true | |
| | invertSpam | bool | false | |
| | floodFilter | choice | 0 | 0 off, 1 message+player, 2 message |
| | skipGuild | bool | true | |
| | skipParty | bool | false | |
| | skipPrivate | bool | true | |
| | skipYourself | bool | false | |
| 4 UI | openWithFriends | bool | true | |
| | useUnitHacks | bool | true | applies without a /reload (N41) |
| | useLFGHacks | bool | true | same |
| | gcEnabled | bool | true | |
| | frameStrata | choice | 3 | 0 LOW .. 3 DIALOG |
| | uiSkin | choice | 2 | 2 Modern, 0 Classic, 1 Dark |
| | uiFont | choice | "" | "", game, names, damage, friz, arialn, morpheus, skurri |
| 5 Whois | whoLevelCapOn | bool | false | field = whoLevelCap |
| | whoLevelCap | number | nil | 1..999, inline |

## E. Upgrade steps (PSS_Upgrade.lua STEPS)

Every `fields` part runs before any `data` part; every part is safe to run twice; the `RETIRED` loop runs after the data parts.

| Step | Parts (feature) | What |
| --- | --- | --- |
| 1 | `always`; six parts: fields options, players, filters; data guilds (`M.PSS_UpgradeLegacyData`), filters (`M.PSS_UnlinkGuildRuleCounts`), players (`M.PSS_TidyPlayerData`), history (`M.PSS_TidyBlockHistory` when Logging is loaded) | Everything 2.0 did at login, split by feature |
| 2 | fields (options) | Records the Options split |
| 3 | fields (history) | Records the Logging split |
| 4 | fields (options) | Counts moved to PSS_CountsDB |
| 5 | fields (options) | Pre-2.0.12 save: clear `ignoreResponse`, `blizzardSync` |
| 6 | fields (players) | (3.4.0.22) a saved `showDeclines == true` is dropped |
| 7 | fields (options) + data (cleanup) | (3.4.0.25) `windowPoints` keeps only PSS_Window and PSS_WindowTab; names old folders still present on the cleanup line |
| 8 | data (players) | (3.4.1.35, B1) `blizzardSync == true`: `M.PSS_TickBlizzardIgnored()`, `V.PSS_TickOnSync = true` |
| 9 | fields (players) | (3.4.1.51, S2b) the seven parallel arrays become `list` records; a legacy duplicate keeps the first |
| 10 | data: guilds (Camelot repair via Libraries `M.PSS_RepairCamelotNames`, Camelot saves with names only), guilds (`M.PSS_CapAllMembers`), cleanup (`M.PSS_StampFoundMembers`, `M.PSS_CompactAllMembers`), players (`M.PSS_CompactPlayers(true)`), filters (`M.PSS_AssignCustomFilterIds`) | (3.4.1.52, S3) "SavedVariables performance cleanup" |

## F. Startup sequence

File load (TOC order): L, M, V created; loader global; Perf registers `PLAYER_LOGIN`; ChatBlock adds the message filter and its invite/duel/trade/whisper-inform events; ChatFilters registers the "text" handler; PlayerIgnoreList and GuildIgnoreList register their sources, handlers and their own frames (B); PourSocialScore.lua creates `PSSFRAME` and the slash stubs.

1. `ADDON_LOADED` ("PourSocialScore"): `M.PSS_ImportLegacyDB()` (only when no save exists).
2. `PLAYER_LOGIN`: Perf requests GC "login"; GuildIgnoreList runs `M.PSS_ApplyCapture()`.
3. `PLAYER_ENTERING_WORLD`: `History.StartSession`.
4. Once both 1 and 3: `ApplicationStartup` (once):
   1. `M.ShowMsg(L.LOAD_1)`; `V.faction`.
   2. No save: `M.PSS_ResetIgnoreDB()`.
   3. `M.PSS_PrepareSavedData({quiet = fresh, startup = true})` (stop if Options folder missing).
   4. Create missing `list`, `delList`, `playerData`, `guildData`; `imported = false` when nil.
   5. Bad `defexpire` cleared; `M.PSS_ApplyOptionDefaults()`.
   6. `M.PSS_RunUpgradeFields(fresh, defaults)`.
   7. `M.PSS_ExpandFilters()`.
   8. `M.PSS_LoadActiveManagedData()`.
   9. `V.PSS_LoadedTime`, `V.PSS_Loaded = true` (filtering starts deciding).
   10. `M.PSS_RunUpgradeData(fresh)` (steps, `RETIRED`, record, report).
   11. `M.PSS_ExpireEntries()` (N40).
   12. `M.PSS_ApplyCapture()` (P3: capture events only if they can be used).
   13. If Logging got loaded for the upgrade: `M.PSS_LoadLogging()`.
   14. `M.PSS_HookFunctions()` (BlizzardUI).
   15. Unregister `PLAYER_ENTERING_WORLD`, `ADDON_LOADED`.
5. Later: `GROUP_ROSTER_UPDATE` -> group warning after 1 s; `PLAYER_REGEN_ENABLED` runs a deferred roster check and the daily expiry.
6. `PLAYER_LOGOUT` (also /reload): `M.PSS_CollapseFilters()`, `pcall(M.PSS_CompactPlayers)`, `pcall(M.PSS_FlushManaged)` (shipped delta, cap, sparse members), `History.EndSession()`, `pcall(History.PackForSave)` (only when Logging is loaded).

## G. Findings (open)

| Where | Finding |
| --- | --- |
| PSS_Globals | `M.debugMsg` is a no-op with 16 call sites left (N7 not done). |
| PSS_ChatFilters flood filter | A duplicate line is hidden with no count, no history line and no event; inverted blocks count only `filterTotal`. |
| PSS_ChatBlock | `declineMsg` checks `L[fmtKey]`, always truthy due to the BAD TEXT metatable. |
| PourSocialScore.lua | `V.PSS_SyncOK` written, never read. |
| PSS_Localization | `INFO_5`/`INFO_6` assigned twice; `OPT_3 = "UNUSED"`. |
| PSS_ChatHistory | `History.MigrateFilterList` runs every login through `PSS_ExpandFilters` (P6 left it; needs a guard before a move). |
| Exports used only in their own file or the harness | `History.Bucket`, `History.CountList`, `History.FormatTime`, `History.TrimAll`, `History.SettleKeep`, `History.SettleAllKeep`, `History.MigrateOldFilterEntry`, `History.LoadWhenQuiet`, `History.ApplyPurge`, `M.PSS_ChatFilters_Evaluate`, `M.PSS_IsBuiltinFilterID`, `M.PSS_GCWatch`, `M.PSS_ImportLegacyDB`, `M.PSS_BLOCK_LABELS`. |
