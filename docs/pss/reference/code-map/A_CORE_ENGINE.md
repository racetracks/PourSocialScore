# Core engine map (PourSocialScore core folder, 3.4.1.38)

Scope: the always-loaded core files that hold the engine, the data layer and startup, plus the Options folder. Out of scope here (other sections): PSS_Whois, PSS_Communities, PSS_PlayerIgnoreList, PSS_PlayerQuery, PSS_GuildIgnoreList, PSS_WhoisHarvest, PSS_BlizzardUI. Line counts are `wc -l`.

Shared handles: `addon` (the `...` table, also global `PourSocialScore_NS`), `M` (methods), `V` (runtime state), `L` (strings), `History` (= `M.PSS_History`).

## 0. Folders, TOCs and SavedVariables declarations

| Folder | TOCs | Loads | SavedVariables | Files |
| --- | --- | --- | --- | --- |
| `PourSocialScore` | base (`120007, 16001`), `_Mainline` (120007), `_Camelot` (16001) | Always; `## Dependencies: PourSocialScore_Options` | `PourSocialScoreDB` | 20 files, order: Localization, Globals, Loader, SavedData, Perf, Events, Whois, Communities, MainlineCompat, ChatHistory, ChatBlock, ChatFilters, PlayerIgnoreList, PlayerQuery, GuildIgnoreList, WhoisHarvest, Upgrade, PourSocialScore.lua, Options, BlizzardUI |
| `PourSocialScore_Options` | same three | Always (before core) | `PSS_OptionsDB, PSS_PlayersDB, PSS_GuildsDB, PSS_RulesDB, PSS_CountsDB` | `PSS_OptionsData.lua` (4 lines, comment only: no code) |
| `PourSocialScore_Logging` | same three | On demand | `PSS_LoggingDB` | (other section) |

Every TOC carries `## Version: 3.4.1.38`, `## Category: PSS`, `## Group: PourSocialScore`.

Note: PSS_Options.lua loads AFTER PSS_Upgrade.lua and PourSocialScore.lua; it is safe because nothing reads `M.PSS_OPTIONS` until startup (ADDON_LOADED + PLAYER_ENTERING_WORLD).

---

## 1. PSS_Localization.lua (517 lines)
Purpose: creates `addon.L` with English defaults (457 `L[...]` assignments) and locale blocks (deDE, ruRU, zhCN filled; ptBR, frFR, esES/esMX, zhTW, koKR, itIT empty).

| Export | What |
| --- | --- |
| `addon.L` | String table. Metatable `__index` returns `BAD TEXT "<key>"` for a missing key (so `L[key]` is never nil). |

Key families (count): OPT 71, CMD 57, HELP 50, COL 40, RCM 35 (RCM_16..20 = B2 "PSS" header, Block/Unblock Player/Guild), BOX 33, BUT 25, OVER 19, LIST 15, LOAD 15, INFO 14, ADD 12, SYNC 12, MSG 9 (MSG_1 ignore auto-reply, MSG_2..5 decline texts), TAB 9, TIP 7, CHAT 3 (CHAT_1 group warning), PART 2 (loader messages), plus WARN_WHISPER, OLD_FOLDERS, HISTORY_*.
Notes: `INFO_5`/`INFO_6` are assigned twice (lines ~155 and ~160); `OPT_3 = "UNUSED"`. Many strings are dead (core uplift P1 says 61).
Events, hooks, SavedVariables: none. Used by: every file through `addon.L` / `PourSocialScore_NS.L`.

---

## 2. PSS_Globals.lua (473 lines)
Purpose: creates `addon.V` and `addon.M`; shared string/name helpers, realm display names, client flags, message output, the W I G P C table.

### Exports
| Group | Name | What |
| --- | --- | --- |
| Tables | `addon.V`, `addon.M` | Created here. |
| Strings | `M.trim(str)` / `M.PSS_Trim` | Trim whitespace; non-string gives "". |
| | `M.strDown(str)` | `string.lower`. |
| | `M.Proper(name, okSpaces)` | Title-case a name; keeps single spaces in the name part of "First Last-Realm" (Camelot); reused buffer. |
| | `M.PSS_SplitNameArg(str)` | Split typed "name [rest]": quotes, a "-" word in the first 3 words, or two words as one name off Retail or when "First Last" is listed (`M.PSS_IsPlayerListed`). Returns name, rest. |
| Realms | `M.prettyServer(name)` | "Aeriepeak" -> "Aerie Peak" (lazy `REALM_PAIRS` map, else insert spaces before capitals/digits). |
| | `M.getServer(name, def)` | Realm part after "-" or `def` or `V.serverName`. |
| | `M.removeServer(name, strict)` | Drop "-Realm" when it is your realm (or always with strict). |
| | `M.addServer(name)` | Append "-" .. `V.serverName` when no realm. |
| Dates | `M.dateToJulianDate(str)` | "dd Mon yyyy" -> whole day number (days since 1970). Only used by daysFromToday. |
| | `M.daysFromToday(str)` | Absolute days between that date and today, -1 when unreadable. |
| | `M.dayString(n)` | `L.DAY` / `L.DAYS`. |
| Output | `M.ChatMsg(text)` | `DEFAULT_CHAT_FRAME:AddMessage(text)` raw. |
| | `M.ShowMsg(msg)` | `print("Pour Social Score: " .. msg)` coloured. |
| | `M.debugMsg(msg)` | No-op (body commented out). |
| Data | `M.EXCL` | The 5 W I G P C categories: `{cat, letter, field, label}` for whisper/W/whispersBlocked, partyInvite/I/partyInvitesBlocked, guildInvite/G/guildInvitesBlocked, partyRaid/P/partyRaidBlocked, world/C/channelsBlocked. |

### V state set here
`V.needSorted = true` (written by many files, never read anywhere: dead), `V.serverName = M.Proper(GetRealmName())`, `V.playerName = M.addServer(GetUnitName("player"), true)` (extra arg ignored; used by PlayerIgnoreList syncInfo), `V.wowIsRetail` (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or nil), `V.wowIsERA/TBC/Wrath/Cata/MOP/Classic = false`, `V.wowLongName`, `V.wowName` (all but wowIsRetail unread).

Locals: `properBuf`, `REALM_PAIRS` (~150 pairs), `realmNames` (lazy), `realmDisplayName`, `spaceRealmName`.
Events/hooks/SV: none. Calls `GetRealmName`, `GetUnitName` at file load.
Used by: trim/Proper/addServer/ShowMsg/ChatMsg used widely in core and Libraries (`PSS_Commands`, `PSS_PlayerView`, `PSS_RowMenus`, `PSS_GuildView`, `PSS_FilterView`, `PSS_EventsView`); `M.EXCL` by GUI `PSS_Players`, `PSS_Guilds` and core Guild/PlayerQuery; `M.removeServer` by GUI `PSS_History`, Libraries `PSS_EventsView`; `M.PSS_SplitNameArg` by Libraries `PSS_Commands`.

---

## 3. PSS_Loader.lua (67 lines)
Purpose: the one way core loads its load-on-demand parts.

| Export | What |
| --- | --- |
| global `PourSocialScore_NS = addon` | The single cross-addon global. |
| `M.PSS_PARTS` | `{GUI="PourSocialScore_GUI", Libraries="PourSocialScore_Libraries", Logging="PourSocialScore_Logging", Communities="PourSocialScore_Communities"}`. |
| `M.PSS_Need(key)` | Load a part (and `NEEDS` first: `GUI -> Libraries`): `EnableAddOn(name, UnitName("player"))`, `LoadAddOn`; prints `L.PART_1` once on failure and `L.PART_2` once on a version mismatch. Returns true/false. |
| `M.PSS_Stub(fname, key)` | Puts a stub at `M[fname]` that loads the part on first call and forwards to the real `M[fname]`. |

Locals: `api(name)` (C_AddOns or old global), `version(name)`, `NEEDS`, `warned`.
Used by: core SavedData, ChatHistory, GuildIgnoreList, BlizzardUI (`PSS_Need`); PourSocialScore.lua (`PSS_Stub` for `PSS_SlashPSS`, `PSS_SlashGuild`); Perf (`PSS_PARTS`).

---

## 4. PSS_SavedData.lua (248 lines)
Purpose: splits the saved data over the Options and Logging addons. `PourSocialScoreDB` gets a router metatable so code keeps writing `PourSocialScoreDB.<key>` while routed keys live in the Options/Logging tables; also moves keys from older layouts (upgrade steps 2 to 4).

| Export | What |
| --- | --- |
| `M.PSS_SV_GROUPS` | group -> global table name: options PSS_OptionsDB, players PSS_PlayersDB, guilds PSS_GuildsDB, rules PSS_RulesDB, counts PSS_CountsDB, logging PSS_LoggingDB. |
| `M.PSS_SV_ROUTE` | key -> group (built by `buildRoute` from `LAYOUT` + every `M.PSS_OPTIONS` key). |
| `M.PSS_PrepareSavedData(opts)` | `opts.wipe` (reset), `opts.quiet`, `opts.startup`. Sets router; loads Logging when its keys still sit in PourSocialScoreDB or upgrade step is 3; creates/empties tables of loaded owners; moves keys saved in the wrong group; moves routed keys still raw in PourSocialScoreDB, validated with `M.PSS_Validate().n` before/after (undo + message if different); prints "Saved data moved to ..." lines. Returns false when PourSocialScore_Options is not loaded (startup stops). |
| `M.PSS_SavedDataSplit(owner)` | True once that owner's data is split (used by upgrade steps 2/3/4). |

Locals: `GROUPS`, `OWNER` (group -> owning addon), `ON_DEMAND` (Logging), `LAYOUT` (below), `ROUTE`, `active` (owner -> loaded), `router` metatable (`__index`/`__newindex` route a key only while its owner addon is loaded, else rawset in PourSocialScoreDB), `split`, `warned`, `compare`.
Called by: PourSocialScore.lua startup, `M.PSS_LoadLogging` (ChatHistory), PlayerIgnoreList (reset), Upgrade. Tools use ROUTE/GROUPS.

---

## 5. PSS_Perf.lua (274 lines)
Purpose: incremental garbage collection (`collectgarbage("step")` spread over frames) and the `/pss mem` report.

| Export | What |
| --- | --- |
| `M.PSS_GCState` | `{pending, running, lastCycle, leftCombat, heapAfter, supported, frames, cycles, lastReason, lastMs}`. |
| `M.PSS_RequestGC(reason)` | Marks a cycle pending; it starts on the next 15 s check when safe. |
| `M.PSS_MemReport(full)` | Prints memory of the addon and parts, block history size (by owner type, top 10 with `full`), list sizes, `M.PSS_ManagedStats()`, chat filter count, GC state. |

Constants: CHECK_INTERVAL 15 s, IDLE_INTERVAL 600 s (the known breach C15), COMBAT_COOLDOWN 300 s, STEP_KB 8, STEP_BUDGET_MS 1.0, MIN_FPS 30, MAX_FRAMES 900, GROWTH_KB nil.
Locals: `busyReason()` (combat, encounter, dead, 5 min after combat, dungeon/raid/pvp/arena), `runner` frame (OnUpdate only while a cycle runs), `startCycle`, `stopCycle`, `check`.
WoW events (always): `PLAYER_LOGIN` (request "login", start `C_Timer.NewTicker(15, check)` for the session), `PLAYER_REGEN_DISABLED` (pause), `PLAYER_REGEN_ENABLED` (stamp leftCombat).
Options read: `gcEnabled`. SV read: PourSocialScoreDB lists (ignoreList, typeList, guildData, playerData, filterList, filterActive).
Depends on: `M.PSS_Opt`, `M.PSS_History` (Loaded, Waiting, EstimateBytes, Log, Cap, KeepSize), `M.PSS_UpgradeText`, `M.PSS_ManagedStats`, `M.PSS_PARTS`.
Used by: `M.PSS_RequestGC` from GUI `PSS_Window` (close), Libraries `PSS_ImportExport`, core GuildIgnoreList, Upgrade, ChatHistory; `M.PSS_MemReport` / `M.PSS_GCState` from Libraries `PSS_Commands`.

---

## 6. PSS_Events.lua (57 lines)
Purpose: the core event bus.

| Export | What |
| --- | --- |
| `M.Events.Register(event, fn)` | Returns an id. |
| `M.Events.Unregister(event, id)` | |
| `M.Events.Fire(event, ...)` | Calls every listener in `pcall`; an error goes to `M.debugMsg`, which is a no-op, so listener errors are silently swallowed (N46). |

Locals: `listeners[event][id] = fn`, `nextId`. The header comment lists the event catalogue (section C below). Used by every file that fires or listens; GUI listens through `ns.Listen` (only while the window shows) and `PSS_Window` registers `OPTION_CHANGED` directly.

---

## 7. PSS_MainlineCompat.lua (17 lines)
Purpose: compatibility shims.
- Writes globals `_G.strlen = string.len` and `_G.strbyte = string.byte` only when missing (a write to `_G`; normally a no-op as the client defines both).
- `M.PSS_Mainline = true` (never read: dead).

---

## 8. PSS_ChatHistory.lua (1230 lines)
Purpose: the block history module (`History`): entries, the shared capped log, the per-person packed keep, the outbox while Logging is not loaded, recent counts (session and 24 h), owner keys, tidy-up and old-format migrations.

### Exports: constants and tables
| Name | What |
| --- | --- |
| `M.PSS_History` (= `History`) | The module. |
| `History.UNKNOWN` | "Unknown". |
| `History.CAT_ORDER` | whisper, partyInvite, partyRaid, world, guildInvite. |
| `History.CAT_LABEL`, `History.CAT_COLOR` | Labels / colours per cat (incl. guildChat, unknown). |
| `History.ALL_CATS` | whisper, partyInvite, guildInvite, partyRaid, world, guildChat, unknown. |
| `History.sourceLabel` | Weak-key entry -> tooltip label. `History.SetSource(h, label)`. |
| `History.DEFAULT_TOTAL/MIN_TOTAL/MAX_TOTAL` | 2000 / 100 / 20000. |
| `History.EntryMT` | Metatable deriving `time` (from ts) and `kind` (from cat). |
| `History.KEEP` | `{text=10, party=5, guild=5}` per person. `History.KEEP_TOTAL = 2000`. `History.LOG_ALL = true`. |
| `History.EventLetter`, `History.LetterEvent` | Event <-> one letter for packed lines (append-only list of 24 events). |
| `History.SLOT = 600`, `History.DAY_SLOTS = 144` | Recent-count slots (10 min, 24 h). |

### Exports: functions
| Group | Function | What |
| --- | --- | --- |
| Time | `History.Now()` | `GetServerTime()` or `time()`. |
| | `History.FormatTime(ts)` | "%d %b %Y %H:%M:%S" or Unknown. |
| | `History.ParseTime(s)` / `M.PSS_ParseTimeString` | Two old string formats -> time. |
| Entries | `History.Bucket(cat)` | "other" -> world; unknown cats -> unknown. |
| | `History.Normalize(h)` / `M.PSS_NormalizeBlockEntry` | Idempotent migration of an old entry (cat, ts, channel, drops time/kind, sets EntryMT). |
| | `History.NewEntry(cat, event, message, channel, member)` | New entry; a secret message is replaced with "(message hidden by the client)". |
| | `History.EmptyCounts()`, `History.EnsureCounts(c)` | Counts table with every cat + total (total never less than the sum). |
| Log | `History.Cap()` / `History.Max` | Option `historyTotal` clamped. |
| | `History.Loaded()` / `M.PSS_LoggingReady` | Logging loaded and merged. |
| | `History.Waiting()` | Outbox length. |
| | `M.PSS_LoadLogging()` | `PSS_Need("Logging")`, `PSS_PrepareSavedData()`, `History.UnpackSaved` and `History.KeepToLog` (both defined in Logging `PSS_SavedLog.lua`), `History.ApplyPurge()` (3.4.1.49), outbox -> log, `CapKeep(true)`, `Trim(true)`, `M.PSS_TidyBlockHistory()`. |
| | `History.Log()` | Loads Logging; returns `db.blockLog` (oldest first), metatables attached once. |
| | `History.Trim(force)` / `History.TrimAll` / `M.PSS_TrimAllHistory` | Cut the log to the cap (batches at 5 % over); people's dropped lines settle into the keep. |
| | `History.Add(owner, counts, entry, ruleTag)` | THE write path: sets `entry.o`/`r`, bumps `counts[cat]` and `counts.total`, `CountRecent`, then outbox (Logging not loaded; cap; at 200 waiting schedules `loadWhenQuiet` via `C_Timer.After(1)`) or log + `Trim(false)`. |
| Keep | `History.Keep()` | Loads Logging; returns `db.blockKeep`, repacks old entry tables once. |
| | `History.KeepKind(h)`, `History.KeepsOwner(o)` | Kind (text/party/guild) of a line; owner is "p:"/"g:". |
| | `History.PackLine(h, list)`, `History.UnpackLine(o, list, s)`, `History.UsualChannel(cat, ev)` | Packed line format `<type><ts>\t<ev>\t<channel>\t<msg>`. |
| | `History.KeptLines(o)` | A person's kept lines unpacked (only the harness calls it). |
| | `History.CapKeep(force)` | Keep at most 2000 lines, oldest first. |
| | `History.KeepAdd(h)` | Unused anywhere (dead). |
| | `History.MovePeople()` | Unused (dead). |
| | `History.SettleKeep(owners, dropped, n)`, `History.SettleAllKeep()` | Recompute keep per person. |
| | `History.KeepSize()`, `History.KeepChanged()` | Size; reset the cached keep count. |
| Walk | `History.Each(fn)`, `History.Collect(pred)`, `History.For(owner)`, `History.CountFor(owner)` (harness only), `History.Where(owner)` | Iterate / filter newest-first / count. |
| | `History.Clear(pred)` | Remove matching lines from log and keep (unpacks every kept line); requests GC. Used by the guild reset and the tidy. |
| | `History.ClearOwner(o, mayHave)` | (3.4.1.49, S1) One owner's lines: Logging loaded, a log walk comparing `o` and `keep[o] = nil`; not loaded, the owner's outbox lines go and `PourSocialScoreDB.purge[o] = true` unless `mayHave` is false (`History.PURGE_CAP` 200; full: loads Logging and clears now). Never loads Logging otherwise. Used by every remove and reset of a player, filter or member. |
| | `History.ApplyPurge()` | (S1) In `M.PSS_LoadLogging`, before the outbox joins the log: the marked owners' lines go in one walk, the marks are cleared. |
| | `History.Tidy(alive)` | Drop lines of owners that no longer exist; clear dead `r`/`gk` tags. |
| Owner keys | `History.PlayerKey(name)` -> "p:<canon>", `History.MemberKey(m)` -> "g:<canon>", `History.FilterKey(id, text)` -> "f:<id>" or "f:t:<text>", `History.GuildKey(gkey)` -> "G:<gkey>" | |
| Recent | `History.CountRecent(owner, ts, cat)` | Session count + 10-minute slot + `day[owner]`. |
| | `History.RecentCounts(owner)` | session, 24 h. |
| | `History.RecentTotals(prefix)` | Sums by owner prefix. |
| | `History.RecentByCatData()` | `sessionCat`, recent table (for Libraries `History.RecentByCat`, defined in `PSS_TotalsQuery.lua`). |
| | `History.RecentSlots(owner)` | Day by slot and type. |
| | `History.ForgetRecent(owner)` | Drop an owner's recent counts. |
| | `History.SessionStart()`, `History.StartSession(initial, reload)`, `History.EndSession()` | Session bookkeeping (PEW / PLAYER_LOGOUT). |
| Misc | `History.EstimateBytes()` | For /pss mem. |
| Migration | `History.Absorb(sources)`, `History.CountList(list)`, `History.Sig(h)`, `History.MigrateOldFilterEntry(e)`, `History.MigrateFilterList(list, last)` | Old per-owner lists and the old filter ring buffer -> the log. |
| Dead | `History.Combine`, `History.MergeLists`, `History.FormatCounts` (aliased `M.PSS_FormatGuildCounts`, `M.PSS_FormatBlockCounts`, none called) | No caller in any folder or tool. |

Locals: `ready` (Logging merged), `loadQueued`, `loadWhenQuiet` (retries every 30 s via `C_Timer.After` while in combat or an instance: a timer as gate, L14), `attached` (weak set), `keepTotal`, `sessionCat` (never saved), `KEEP_KIND`, `CAT_CODE`, `CODE_CAT`, `BYTE_KIND`, `KEPT_EVENTS`, `migratedLists` (weak), `recent(cur, create)`, `drop`.
WoW events: none. Uses `C_Timer.After`.
SavedVariables (raw in PourSocialScoreDB): `outbox`, `recent`, `session`, `sessionStart`, reads `logAllV1`; routed: `blockLog`, `blockKeep` (PSS_LoggingDB).
Depends on: `M.PSS_Opt`, `M.PSS_Need`, `M.PSS_PrepareSavedData`, `M.PSS_TidyBlockHistory`, `M.PSS_ChannelLabel`, `M.PSS_EventCategory`, `M.PSS_CanonPlayer`, `M.PSS_IsSecret`, `M.PSS_RequestGC`, Logging's `History.UnpackSaved/KeepToLog/PackForSave`.
Used by: core PlayerIgnoreList, GuildIgnoreList, ChatFilters, Upgrade, Perf, PourSocialScore.lua; Libraries `PSS_DetailQuery`, `PSS_EventsQuery`, `PSS_EventsView`, `PSS_FilterQuery`, `PSS_GuildQuery`, `PSS_GuildView`, `PSS_TotalsQuery`; GUI `PSS_Detail`, `PSS_Events`, `PSS_History` (`M.PSS_LoadLogging`, `M.PSS_LoggingReady`); Logging `PSS_SavedLog` (EntryMT, PackLine, UnpackLine, UsualChannel, KeepChanged, Trim, Log, Loaded, EventLetter/LetterEvent).

---

## 9. PSS_ChatBlock.lua (889 lines)
Purpose: the chat block core. One message-event filter for every chat event, decision cache per line, person sources and handler registries, name normalisation (N1), invites/duels/trades, group and whisper alerts, chat purge.

### Exports
| Group | Name | What |
| --- | --- | --- |
| Secrets | `M.PSS_IsSecret(v)` | `issecretvalue(v) == true` (feature-detected). |
| Names | `M.PSS_OwnRealm()` | `GetNormalizedRealmName()` (cached), fallback `GetRealmName()` without spaces/dashes. |
| | `M.PSS_NormName(name, realm, unit)` | display, key, canon (nil when secret/empty). With a unit, a second value is a surname when `UnitRealmRelationship(unit) == LE_REALM_RELATION_SAME` (always for "player"): "First Last-<own realm>". |
| | `M.PSS_UnitFullName(unit)` | Unit's "Name"/"Name-Realm"/"First Last-Realm" or nil. |
| | `M.PSS_PlayerDisplayName()` | Your own display name. |
| | `M.PSS_FixUnitName(name)` | "First-Last" -> "First Last-<realm>" when target/mouseover/focus/group member has that name+surname (hook paths). |
| | `M.PSS_NormalizePlayer(name)` | Storage key "name-realm" (lowercase, realm without spaces/dashes). |
| | `M.PSS_CanonPlayer(name)` | Matching key: also strips apostrophes in the realm, collapses spaces. |
| | `M.PSS_CanonRealm(realm)`, `M.PSS_CanonGuild(name)` | Lowercase canon forms. |
| | `M.PSS_DisplayPlayer(name)` | `M.Proper(M.addServer(name))`. |
| | `M.PSS_NowString()` | Server time "%d %b %Y %H:%M:%S". |
| Categories | `M.PSS_EVENT_CATEGORY` / `M.PSS_CoreEvents`, `M.PSS_EventCategory(event)` | Event -> whisper/partyRaid/world/guildChat/other/npc/system (41 events). |
| | `M.PSS_BLOCK_CATEGORIES`, `M.PSS_BLOCK_LABELS` | Labels (only used in this file). |
| | `M.PSS_ChannelLabel(event, channelString, chNumber, chName)` | Channel label for history ("2. Trade - City", "Whisper"...). |
| Registry | `M.PSS_RegisterBlockSource(def)` | Person source `{id, order, label, lookup(canon,ctx), decide(entry,cat,ctx), record(entry,cat,ctx), optionContext, describe, inviteByGuild}`; sorted by order. Registered: "player" (10, PlayerIgnoreList), "guild" (20, GuildIgnoreList). |
| | `M.PSS_GetBlockSources()` | The list (no outside caller). |
| | `M.PSS_RegisterBlockHandler(kind, id, fn)` | kind system/npc/realm/text. Registered: system "ignoreList", npc "npcIgnore", realm "serverIgnore" (PlayerIgnoreList), text "chatFilters" (ChatFilters). |
| Engine | `M.PSS_CoreFilter` | The filter function (see pipeline). |
| | `M.PSS_FilterAvailable` | True when a filter API exists. |
| | `M.PSS_CoreStats` | `{checked, personHits, hidden, errors, lastError, lastChecked, bySource}`. |
| | `M.PSS_CoreDebug` | `{on, allUntil}` debug switches (set by `/pssguild` in PSS_Commands). |
| | `M.PSS_PersonHits(name, cat, ctx)` | Sources blocking a person (harness only). |
| | `M.PSS_ExplainPerson(name)` | Dry-run per source and cat (diagnostics). |
| | `M.PSS_PersonListed(name)` | Listed and blocked for some cat on any source (group warning). |
| | `M.PSS_PersonIdentified(name)` | Re-check a pending party invite when a person becomes known. |
| Chat purge | `M.PSS_PurgeChatFrom(keys)` | Removes shown lines with `|Hplayer:` links of those canon keys via `frame:RemoveMessagesByPredicate` (option `purgeHistory`; approved override). |
| | `M.PSS_ChatFrames()` | `CHAT_FRAMES` or ChatFrame1..N. |
| Test | `M.PSS__CoreTest` | Handles to the invite/duel/trade/whisper handlers and cache reset, for the harness (shipped in core; comment says "not shipped"). |

### Notable locals
`isSurname`, `joinName`, `keyOf`, `canonOf`, `displayOf`, `sources`, `handlers`, `stats`, `debug`, `guidCanon` (GUID -> canon, reset at 1500), `playerGUID`/`playerCanon`, `chatScratch` (reused result tables), `decisionCache`+`ringKeys` (256-slot ring keyed by lineID), shared `ctx` (reset per line), `lastReplyTo`/`lastReplyAny` (auto-reply throttle 300 s per sender, 2 s global), `pendingInvite`, `whisperWarned`, `listedCtx`, `STAFF_FLAGS` (GM, DEV), `TEXT_CATEGORIES` (whisper, partyRaid, world, guildChat).

### WoW events and Blizzard APIs
- `ChatFrameUtil.AddMessageEventFilter` (fallback `ChatFrame_AddMessageEventFilter`) for all 41 events in `EVENT_CATEGORY`, at file load (always).
- Frame events (always): `PARTY_INVITE_REQUEST`, `PARTY_INVITE_CANCEL`, `GUILD_INVITE_REQUEST`, `DUEL_REQUESTED`, `TRADE_SHOW`, `TRADE_REQUEST` (pcall, not on every client), `GROUP_ROSTER_UPDATE` (clears pendingInvite), `CHAT_MSG_WHISPER_INFORM`.
- Calls: `DeclineGroup`, `StaticPopup_Hide("PARTY_INVITE"/"GUILD_INVITE"/"DUEL_REQUESTED"/"TRADE")`, `DeclineGuild` / `C_GuildInfo.DeclineGuild` (+ a 0.2 s re-check via `C_Timer.After`), `CancelDuel`, `CancelTrade`, `C_ChatInfo.SendChatMessage` / `SendChatMessage` (auto-reply `L.MSG_1`), `RemoveMessagesByPredicate`, `UnitRealmRelationship`, `UnitName`, `UnitGUID`, `GetNormalizedRealmName`.
- Fires: `WHISPER_WARNING (name, label)`.
- SV written: `PourSocialScoreDB.hiddenTotal` (+1 per hidden line, routed to PSS_CountsDB). Options read: `ignoreResponse`, `showDeclines`, `purgeHistory`, `listWarnings` (with person/guild context).
- Used by: name helpers everywhere in core; Libraries `PSS_ImportExport` (CanonGuild, CanonPlayer, NormalizePlayer, NowString, PurgeChatFrom), `PSS_Commands` (CanonPlayer, UnitFullName, CoreDebug, CoreFilter, CoreStats, ExplainPerson, FilterAvailable), `PSS_PlayerView` (IsSecret, UnitFullName); GUI `PSS_Filters` (IsSecret); core `PSS_Options` (NormName for CharKey).

---

## 10. PSS_ChatFilters.lua (981 lines)
Purpose: text filters: built-in rule definitions (code), custom rules (saved), the runtime expand/collapse of filter arrays, the filter language compiler, and the "text" handler.

### Built-ins
13 text filters, all default OFF: PSS0001 "Anal" spammers, PSS0002 Thunderfury, PSS0003 M+/Raid sellers, PSS0013 Tradeskill sellers, PSS0014 Power leveling, PSS0008 Guild recruitment, PSS0009 Community recruitment, PSS0010 WTS, PSS0011 Chinese/Korean/Japanese, PSS0012 American politics, PSS0015 Asmon, PSS0016 Olympus, PSS0017 Cyrillic. Plus one guild rule per `addon.MANAGED.groups` entry (from PSS_Communities.lua; "InfluencerGuild=<Name>", default off).

### Exports
| Group | Name | What |
| --- | --- | --- |
| Storage | `M.PSS_FilterOwnerKey(i)` | History owner key of filter i ("f:<id>" or "f:t:<text>" for custom; N43 will change it). |
| | `M.PSS_FilterCounts(i)` | Per-type counts table on `filterBlocked[i].counts`. |
| | `M.PSS_FilterHistory(i)` | `History.For` its lines (guild rule: {}). |
| | `M.PSS_ResetFilterHistory(i)` | Clear lines, recent counts, per-type counts; fires FILTER_HISTORY_CHANGED. |
| | `M.PSS_ResetFilterCount(i)` | Row count to 0, forget recent; FILTERS_CHANGED. |
| Edit | `M.RemoveChatFilter(i)` | Clear lines (`History.ClearOwner`; marked for later when Logging is not loaded and it has counts), remove from all 7 arrays; FILTERS_CHANGED. |
| | `M.ResetSpamFilters()` | Rebuild every array from the built-ins; clears `builtinRules`, `builtinStats`, `invertSpam`, `spamFilter`. |
| | `M.PSS_CopyChatFilter(i)` | New custom copy, off. |
| | `M.PSS_AddCustomFilter(desc, filter, active)` | Append a custom rule. |
| | `M.PSS_SetFilterActive(i, on)` | Toggle; a guild rule also loads managed data and marks the guild index dirty. |
| | `M.PSS_SaveChatFilter(i, desc, filter)` | Edit text/desc. |
| | `M.PSS_AssignLegacyFilterIDs()` | Very old saves: IDs by description (upgrade step 1). |
| Built-in vs custom | `M.PSS_IsBuiltinFilterID(id)`, `M.PSS_IsBuiltinFilter(i)` | |
| | `M.PSS_IsGuildRuleText(text)` (cached, reset at 300), `M.PSS_IsGuildRuleFilter(i)` | "influencerguild=" prefix. |
| | `M.PSS_ManagedGroupFilterIndex(groupKey)`, `M.PSS_ManagedGroupActive(groupKey)`, `M.PSS_SetManagedGroupActive(groupKey, on)` | Managed community rule on/off. |
| | `M.PSS_ExpandFilters()` | Saved (custom only + `builtinRules`/`builtinStats`) -> runtime arrays (built-ins first, then custom); 2.0.10 opt-in pass (`optInFiltersV1`); old per-filter lists absorbed into the log. Run at startup. |
| | `M.PSS_CollapseFilters()` | Runtime -> saved form, at PLAYER_LOGOUT. |
| | `M.PSS_UnlinkGuildRuleCounts()` | 2.0.39 once (`guildRuleCountsV1`): guild rule counts removed from filter totals and `h.r` tags cleared. |
| Engine | `M.PSS_CompileFilter(text)` | Text -> tree or false (cached, reset at 300). No outside caller yet (planned for U3). |
| | `M.filterComplex(filterStr, chatStr, chNumber, chName)` | Test one filter (editor; sets `V.lastFilterError`) or run every active text filter; returns true, index. Libraries `PSS_FilterQuery` calls it. |
| | `M.PSS_ChatFilters_Evaluate(ctx)` | The text handler (see pipeline). |

Filter language tags (`KNOWN_TAGS`): [word] [contains] [chname] [channel] [words] [item] [spell] [achievement] [icon] [pet] [link] [trade] [guild] [outfit] [journal] [mount] [community] [nonlatin] [cyrillic]; operators `not`, `and` (implicit), `or`, brackets, backslash escape. Compiled: `tokenize` -> `parse` -> `buildNode` closures; `filterFn` cache (300); `analyse(chatStr)` builds one reused feature table `Fbuf` (links stripped: talent, item, colour, battlepet, spell, achievement; raid icons; has* flags); `words(F)` lazy.
Locals: `filterDef*` arrays, `FILTER_ARRAYS` (filterList, filterDesc, filterActive, filterID, filterCount, filterBlocked, filterBlockedLast), `filtersExpanded`, `groupIndexCache`, flood ring `floodRing`/`floodSet`/`floodPos` (size 50).
Fires: `FILTERS_CHANGED` (9 places, including once per blocked line), `FILTER_HISTORY_CHANGED (i)`.
WoW events / hooks: none.
SV (routed): rules `filterList, filterDesc, filterActive, filterID, builtinRules, filterFormat (=2), optInFiltersV1`; counts `filterTotal, filterWhisperTotal, filterPrivateTotal, filterCount, filterBlocked, filterBlockedLast, builtinStats, guildRuleCountsV1`; options `spamFilter, invertSpam`.
Options read: `spamFilter, skipGuild, skipParty, skipPrivate, skipYourself, floodFilter, invertSpam`.
Depends on: `M.PSS_History`, `M.PSS_ChannelLabel`, `M.PSS_Opt`, `M.Proper`, `M.addServer`, `M.PSS_LoadActiveManagedData`, `M.PSS_MarkGuildIndexDirty`, `addon.MANAGED`.
Used by: Libraries `PSS_FilterView` (Add/Copy/Save/Remove/Counts/History/OwnerKey/ResetHistory), `PSS_FilterQuery` (filterComplex, IsBuiltinFilter, IsGuildRuleFilter, OwnerKey, ResetHistory), `PSS_ImportExport` (Add, Remove, SetFilterActive, IsBuiltinFilter), `PSS_TotalsQuery` (IsGuildRuleFilter), `PSS_GuildQuery`/`PSS_GuildView`/`PSS_RowMenus` (ManagedGroupActive, SetManagedGroupActive); GUI `PSS_Filters` (ResetFilterCount, ResetFilterHistory, SetFilterActive, ResetSpamFilters, FilterHistory, FilterOwnerKey); core PlayerIgnoreList (ResetSpamFilters), GuildIgnoreList (ManagedGroupActive), Upgrade, PourSocialScore.lua.

---

## 11. PSS_Upgrade.lua (489 lines)
Purpose: numbered run-once saved data upgrade steps, the upgrade record, and the saved data validation report (`/pss check`).

| Export | What |
| --- | --- |
| `M.PSS_UPGRADE_STEPS` | 8. |
| `M.PSS_RunUpgradeFields()` | Every step's `fields` part not yet done (or `always`); a part returning false blocks it and later steps this login. |
| `M.PSS_RunUpgradeData(fresh)` | Every `data` part, then writes `PourSocialScoreDB.upgrade = {step, version, at}`; prints "Saved data upgraded to X (step N)." when steps ran and not fresh. |
| `M.PSS_UpgradeText()` | "step N of 8, version V, date" (for /pss mem, check). |
| `M.PSS_Validate()` | `{n = counts, problems = list}`; counts lists, notes, guild rules/members (`M.PSS_GuildMemberCount`), filters, log/keep lines, block counters per source and cat, options changed. Read only. |
| `M.PSS_PrintValidation()` | Loads Logging, prints the report (`/pss check`). |

Locals: `db` (during a pass), `blocked`, `STEPS`, `addonVersion`, `stepsDone`, `runPart`, `LIST_ARRAYS`, `FILTER_ARRAYS`.
SV: `upgrade` (raw), plus every key the steps touch (see E).
Depends on: `M.ResetSpamFilters`, `M.PSS_AssignLegacyFilterIDs`, `M.PSS_UpgradeLegacyData` (GuildIgnoreList), `M.PSS_UnlinkGuildRuleCounts`, `M.PSS_TidyPlayerData`, `M.PSS_LoggingReady`, `M.PSS_TidyBlockHistory`, `M.PSS_RequestGC`, `M.PSS_SavedDataSplit`, `M.PSS_TickBlizzardIgnored` (PlayerIgnoreList), `M.PSS_GuildMemberCount`, `C_AddOns.DoesAddOnExist`.
Used by: PourSocialScore.lua; Libraries `PSS_Commands` (`PSS_PrintValidation`); SavedData (`PSS_Validate`); Perf (`PSS_UpgradeText`); tools.

---

## 12. PourSocialScore.lua (313 lines)
Purpose: startup, the legacy one-time import, the group warning, logout work, and the slash command stubs.

| Export | What |
| --- | --- |
| `V.PSS_Loaded`, `V.PSS_SyncOK`, `V.PSS_InSync`, `V.lastFilterError`, `V.groupWarning`, `V.PSS_LoadedTime`, `V.faction` | Runtime state (`PSS_SyncOK` is written, never read). |
| `M.PSS_TidyBlockHistory()` | Builds `alive` checks (listed players via `M.PSS_PlayerHistoryKey`, guild members via `M.PSS_LookupGuildMember`, filters via `M.PSS_FilterOwnerKey`) and calls `History.Tidy`. |
| `M.PSS_ImportLegacyDB()` | When PourSocialScoreDB is nil and an old addon's DB ("Poor"+"SocialScoreDB", "Global"+"IgnoreDB") exists: deep copy, rename GIL ids to PSS, record `importedLegacyAt`, `importedFrom`. |
| Globals | `SLASH_PSS1 = "/pss"`, `SLASH_PSSGUILD1 = "/pssguild"`, `SlashCmdList.PSS`, `SlashCmdList.PSSGUILD` -> `M.PSS_SlashPSS` / `M.PSS_SlashGuild` (stubs that load Libraries; `PSS_Commands.lua` replaces them). |

Locals: `ApplicationStartup` (see F), `EventHandler`, `CheckGroupForIgnored` (1 s after roster updates via `C_Timer.After`, deferred out of combat; warns once per name per group with `L.CHAT_1`; fires `GROUP_WARNING`), `deepCopy`, `LEGACY_DB_NAMES`, flags `gotLoaded`, `gotEntering`, `safeToLoad`, `starting`, `rosterCheckQueued/Deferred`. Dead locals: `gotUpdate` (set, never read), `gotGroup` (set, never read), `PSSFRAME` only holds the frame.
WoW events (frame `PSSFRAME`): `PLAYER_ENTERING_WORLD`, `ADDON_LOADED`, `IGNORELIST_UPDATE` (these three unregistered after startup), `GROUP_ROSTER_UPDATE`, `PLAYER_LOGOUT`, `PLAYER_REGEN_ENABLED` (always).
Fires: `GROUP_WARNING (V.groupWarning)`.
Depends on: `M.PSS_ResetIgnoreDB`, `M.PSS_PrepareSavedData`, `M.PSS_ApplyOptionDefaults`, `M.PSS_RunUpgradeFields/Data`, `M.PSS_ExpandFilters`, `M.PSS_CollapseFilters`, `M.PSS_LoadActiveManagedData`, `M.PSS_FlushManaged`, `M.PSS_LoadLogging`, `M.PSS_HookFunctions` (BlizzardUI), `M.PSS_History` (StartSession, EndSession, PackForSave, Tidy), `M.PSS_PersonListed`, `M.hasGroupWarning`, `M.PSS_IsSecret`, `M.PSS_Stub`.

---

## 13. PSS_Options.lua (152 lines)
Purpose: the one option table and its resolution (person > guild > global > default); only non-default values are saved.

| Export | What |
| --- | --- |
| `M.PSS_OPTIONS` | List of 30 option definitions (D). |
| `M.PSS_OPTION_REG` | key -> definition. |
| `M.PSS_OPTION_SECTIONS` | `L.OPT_8` (Ignore list), "Blocking Options:", `L.OPT_9` (Chat filtering), `L.OPT_15` (User interface), "Whois Scan Options:". |
| `M.PSS_CharKey()` | Your character key through `M.PSS_NormName(n, r, "player")` (cached; fills the export's `by` field). |
| `M.PSS_Opt(key, ctx)` | `ctx = {person=opts, guild=opts}` for `target = true` options; then `PourSocialScoreDB[key]` (routed to PSS_OptionsDB); then default. |
| `M.PSS_FrameStrataName()` | LOW/MEDIUM/HIGH/DIALOG from `frameStrata`. |
| `M.PSS_SetOpt(key, scope, value, target)` | "global": store or nil when default; "guild"/"person": `target.opts[key]` (calls `M.PSS_KeepManaged(target)`); fires `OPTION_CHANGED (key)`; `historyTotal` trims history now; `def.reload` prompt via `M.PSS_AskReload` (no option has a `reload` field, so this branch is dead). |
| `M.PSS_ApplyOptionDefaults()` | Drops saved values equal to their default (every login). |

Used by: `M.PSS_Opt` everywhere (core, Libraries `PSS_DetailQuery`, `PSS_OptionsView`, `PSS_Commands`, `PSS_ViewNav`; GUI `PSS_Options`); `M.PSS_SetOpt` by Libraries `PSS_DetailQuery`, `PSS_ImportExport`, `PSS_OptionsView`, `PSS_Commands` and GUI `PSS_Options`; `M.PSS_OPTIONS`/`REG` by Libraries `PSS_OptionsView`, `PSS_ImportExport`, `PSS_DetailQuery`, `PSS_ViewNav` and SavedData/Upgrade; `M.PSS_FrameStrataName` by GUI `PSS_Window`; `M.PSS_CharKey` by Libraries `PSS_ImportExport`.

---

## A. The chat line pipeline (end to end)

1. **Event in.** The client calls `CoreFilter(frame, event, msg, author, language, channelString, target, flag, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid)` (registered with `ChatFrameUtil.AddMessageEventFilter` for each event in `EVENT_CATEGORY`), once per chat window per line.
2. **Category and secrets.** `cat = EVENT_CATEGORY[event]` (unknown event: pass). Secret `author` or `guid`: pass (not counted). Secret `flag`, `channelString`, `channelIndex`, `channelBaseName` are dropped. A secret `msg` is allowed through to person rules (decision 1 exception).
3. **Decision cache.** Key = `lineID` (number), else `event..author..msg..half-second`. A cached decision is returned for the other windows.
4. **`evaluate(ctx)`** (in pcall; an error passes the line uncached):
   1. `cat == "system"`: system handlers (`ignoreList` in PlayerIgnoreList: hides ERR_IGNORE_FULL, sync noise, online/offline of listed people/servers).
   2. Not `V.PSS_Loaded`: pass. `cat == "npc"`: npc handlers (`npcIgnore`).
   3. `canon = senderCanon(author, guid)` (GUID cache, else `M.PSS_CanonPlayer`); `ctx.isSelf` (GUID or your canon).
   4. Not self: **people**: `personHits(canon, cat, ctx, chatScratch)` = every source's `lookup(canon)` then `decide(entry, cat)`. Player source decides by W I G P C fields (world blocked unless `channelsBlocked == false`; guildChat/other always blocked). Guild source: only while the managed rule is on (`guildRuleActive`), not excluded, not your own guild (`M.PSS_IsOwnGuild`), then `memberBlocks`. Hits -> `recordHits` -> each source's `record`:
      - player: `M.PSS_RecordPlayerBlock` -> `History.Add("p:<canon>", p.blockCounts, History.NewEntry(...))`, fires `PLAYER_BLOCKED`.
      - guild: `recordGuildBlock` -> `History.Add("g:<canon>", m.blockCounts, entry)` plus `History.CountRecent("G:<gkey>")`, then `GUILD_BLOCKS_CHANGED` at most every 0.25 s.
   5. Not self and not hit: **realm** handlers (`serverIgnore`).
   6. **Text** (only whisper/partyRaid/world/guildChat, not GM/DEV flag, not secret msg): `M.PSS_ChatFilters_Evaluate(ctx)`: option `spamFilter`, skips (`skipGuild`, `skipParty`, `skipPrivate`, `skipYourself`), flood filter (ring of 50; a duplicate returns true with no count), `M.filterComplex(nil, lower(msg), chNumber, chName)` over active non-guild-rule filters. On a match: `filterTotal`, `filterCount[i]`, `filterWhisperTotal`/`filterPrivateTotal` +1; `AddToBlockHistory` -> `History.Add(M.PSS_FilterOwnerKey(i), filterBlocked[i].counts, entry)`; fires `FILTER_HISTORY_CHANGED (i)` and `FILTERS_CHANGED`. Inverted mode blocks non-matching lines and only bumps `filterTotal`.
5. **After a block** (`afterBlock`, once per line): `stats.hidden`, `PourSocialScoreDB.hiddenTotal` +1; a blocked `CHAT_MSG_WHISPER` from a person or realm rule sends `L.MSG_1` when `ignoreResponse` resolves true (throttled).
6. **History.Add** (the count and the line): bumps `counts[cat]` and `counts.total` on the owner record (always loaded), `History.CountRecent` (session, 10-minute slot, 24 h `day`), then either the outbox `PourSocialScoreDB.outbox` (Logging not loaded; capped at `History.Cap()`; 200 waiting -> `loadWhenQuiet`) or `PSS_LoggingDB.blockLog` + `History.Trim`. When Logging loads, `M.PSS_LoadLogging` moves the outbox into the log; trimmed person lines settle into `blockKeep`.

Invites, duels, trades use the same sources: `handlePartyInvite` (PARTY_INVITE_REQUEST; pending re-check via `M.PSS_PersonIdentified`), `handleGuildInvite` (GUILD_INVITE_REQUEST; falls back to a source's `inviteByGuild`), `handleDuel`, `handleTrade`; each records with `recordHits` (party/guild invites only; duel/trade record nothing) and prints a decline line when `showDeclines`.

## B. SavedVariables layout map

| Saved table (addon) | Group | Keys (LAYOUT + options) | Owning code |
| --- | --- | --- | --- |
| `PourSocialScoreDB` (core) raw keys | - | `upgrade {step, version, at}`, `outbox` (entries waiting for Logging), `recent {v=2, last, day, [1..144]}`, `session`, `sessionStart`, `imported`, `importedLegacyAt`, `importedFrom`, `revision`, `logAllV1` | Upgrade, ChatHistory, PourSocialScore.lua, SavedLog |
| `PSS_OptionsDB` (Options) | options | every `M.PSS_OPTIONS` key (non-default only), `showIgnoreDebug` (written false every login by step 1: N8), `windowPoints` (PSS_Window, PSS_WindowTab), retired `windowSizes`, `columnWidths`, `charOptions`, `optionsV2012`, `euiIntegration`, `blizzardSync` | PSS_Options, Upgrade, Libraries ViewNav |
| `PSS_PlayersDB` (Options) | players | `ignoreList`, `typeList`, `factionList`, `dateList`, `notes`, `expList`, `delList`, `syncInfo` (parallel arrays), `playerData` (records keyed by player: W I G P C `*Blocked`, `blockCounts`, `opts`, `blizzardIgnore`, guild fields) | PlayerIgnoreList |
| `PSS_GuildsDB` (Options) | guilds | `guildData` (rules: `members`, `managed`, `managedGone`, `opts`...), `guildExclusions`, `guildGroupOpen`, `scanFieldsDefaultV1`, `guildPlayerCleanupV3` | GuildIgnoreList |
| `PSS_RulesDB` (Options) | rules | `filterList`, `filterDesc`, `filterActive`, `filterID` (custom rules only when saved), `builtinRules {id = on}`, `filterFormat`, `optInFiltersV1` | ChatFilters |
| `PSS_CountsDB` (Options) | counts | `blockStats` (retired, cleared by step 1), `historyFormat`, `hiddenTotal`, `filterTotal`, `filterWhisperTotal`, `filterPrivateTotal`, `filterCount`, `filterBlocked [{counts}]`, `filterBlockedLast` (always 0), `builtinStats {id = {count, blocked, blockedLast}}`, `guildRuleCountsV1` | ChatFilters, ChatBlock, GuildIgnoreList |
| `PSS_LoggingDB` (Logging, on demand) | logging | `blockLog`, `blockKeep` | ChatHistory, Logging PSS_SavedLog |

Routing: `PourSocialScoreDB`'s metatable sends a LAYOUT key to its group table only while the owning addon is loaded; otherwise the key is stored raw in PourSocialScoreDB (and moved on the next prepare).

## C. M.Events catalogue (fired by files in this scope)

| Event | Args | Fired by | Listeners |
| --- | --- | --- | --- |
| `OPTION_CHANGED` | key | `M.PSS_SetOpt` (PSS_Options) | GUI `PSS_Options` (ns.Listen), GUI `PSS_Window` (Register) |
| `FILTERS_CHANGED` | - | ChatFilters (9 sites incl. each filter block), Libraries ImportExport | GUI `PSS_Filters` |
| `FILTER_HISTORY_CHANGED` | filterNum | ChatFilters (`AddToBlockHistory`, `PSS_ResetFilterHistory`) | GUI `PSS_Filters`, GUI `PSS_Events` |
| `WHISPER_WARNING` | name, label | ChatBlock `handleWhisperSent` | core BlizzardUI |
| `GROUP_WARNING` | names | PourSocialScore.lua `CheckGroupForIgnored` | core BlizzardUI |

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
| | useUnitHacks | bool | true | label says reload needed; no `reload` field |
| | useLFGHacks | bool | true | same |
| | gcEnabled | bool | true | |
| | frameStrata | choice | 3 | 0 LOW .. 3 DIALOG |
| | uiSkin | choice | 2 | 2 Modern, 0 Classic, 1 Dark |
| | uiFont | choice | "" | "", game, names, damage, friz, arialn, morpheus, skurri |
| 5 Whois | whoLevelCapOn | bool | false | field = whoLevelCap |
| | whoLevelCap | number | nil | 1..999, inline |

## E. Upgrade steps (PSS_Upgrade.lua STEPS)

| Step | Parts | What |
| --- | --- | --- |
| 1 | fields + data, `always` (every login) | fields: `showIgnoreDebug = false` if nil, `filterTotal = 0` if nil, drop `autoIgnore/autoUpdate/autoCount/autoTime/attachFriends/syncList/filterHistory`, `ResetSpamFilters` when filter arrays missing, create `delList/expList/syncInfo/typeList/filterActive/filterBlocked/filterBlockedLast`, `revision = 1` (Proper-case names once), legacy filter IDs, numeric whisper/private totals. data: `M.PSS_UpgradeLegacyData` (guild/player history formats), `M.PSS_UnlinkGuildRuleCounts`, `blockStats = nil`, `M.PSS_TidyPlayerData`, `M.PSS_TidyBlockHistory` when Logging is loaded |
| 2 | fields | Records the Options split (`PSS_SavedDataSplit("PourSocialScore_Options")`; false = not recorded) |
| 3 | fields | Records the Logging split |
| 4 | fields | Counts moved to PSS_CountsDB (same check as step 2) |
| 5 | fields | Pre-2.0.12 save: clear `ignoreResponse`, `blizzardSync`; drop `optionsV2012`, `charOptions`, `historySize` |
| 6 | fields | (3.4.0.22) a saved `showDeclines == true` is dropped |
| 7 | fields + data | (3.4.0.25) drop `euiIntegration`, `windowSizes`, `columnWidths`; `windowPoints` keeps only PSS_Window and PSS_WindowTab; data: prints `L.OLD_FOLDERS` if `PourSocialScore_EllesmereUI` or `PourSocialScore_UI` still exist |
| 8 | data | (3.4.1.35, B1) `blizzardSync == true`: `M.PSS_TickBlizzardIgnored()`, `V.PSS_TickOnSync = true`; then `blizzardSync = nil` |

Planned (10_CORE_UPLIFT): step 9 "SavedVariables performance cleanup" (S3).

## F. Startup sequence

File load (in TOC order): L, M, V created; realm/player names read; loader global `PourSocialScore_NS`; Perf frame registers PLAYER_LOGIN/REGEN events; ChatBlock adds the message filter for 41 chat events and registers invite/duel/trade/whisper-inform events; ChatFilters registers the "text" handler; PlayerIgnoreList and GuildIgnoreList register their block sources and handlers (and their own PLAYER_LOGIN / IGNORELIST_UPDATE frames, other sections); PourSocialScore.lua creates `PSSFRAME`, the `/pss` and `/pssguild` slash stubs.

1. `ADDON_LOADED` (arg "PourSocialScore"): `M.PSS_ImportLegacyDB()` (only when no save exists); `gotLoaded = true`.
2. `PLAYER_LOGIN` (Perf): `gc.lastCycle`, request GC "login", start the 15 s GC ticker.
3. `PLAYER_ENTERING_WORLD` (isInitialLogin, isReloadingUi): `History.StartSession` (new session on login or reload); `gotEntering = true`.
4. Once both: `ApplicationStartup` (once; guarded by `starting` and `V.PSS_Loaded`):
   1. `M.ShowMsg(L.LOAD_1)`; `V.faction`.
   2. No save: `M.PSS_ResetIgnoreDB()` (PlayerIgnoreList).
   3. `M.PSS_PrepareSavedData({quiet = fresh, startup = true})` (stop if Options folder missing).
   4. Create missing list arrays (`ignoreList`, `factionList`, `dateList`, `notes`, `expList`, `typeList`, `delList`, `syncInfo`, `playerData`, `guildData`), `imported = false`.
   5. Bad `defexpire` cleared; `M.PSS_ApplyOptionDefaults()`.
   6. `M.PSS_RunUpgradeFields()`.
   7. `M.PSS_ExpandFilters()`.
   8. `M.PSS_LoadActiveManagedData()` (Communities part when a managed rule is on).
   9. `V.PSS_LoadedTime = GetTime()`, `V.PSS_Loaded = true` (chat filtering starts deciding person/text rules).
   10. `M.PSS_RunUpgradeData(fresh)` (record + message).
   11. If Logging got loaded for the upgrade: `M.PSS_LoadLogging()` (outbox, trim, tidy).
   12. `M.PSS_HookFunctions()` (BlizzardUI: menus, FriendsFrame, etc.).
   13. Unregister `IGNORELIST_UPDATE`, `PLAYER_ENTERING_WORLD`, `ADDON_LOADED` on `PSSFRAME`.
5. Later: `GROUP_ROSTER_UPDATE` -> group warning after 1 s; `PLAYER_REGEN_ENABLED` runs a deferred roster check.
6. `PLAYER_LOGOUT` (also /reload): `M.PSS_CollapseFilters()`, `pcall(M.PSS_FlushManaged)`, `History.EndSession()`, `pcall(History.PackForSave)` (only when Logging is loaded, since PackForSave lives there).

## G. Findings (bugs, dead code, rule notes)

| Where | Finding |
| --- | --- |
| PSS_Events / PSS_Globals | `Events.Fire` reports listener errors through `M.debugMsg`, which is a no-op: errors are silently swallowed (known N46). |
| PSS_Upgrade `PSS_PrintValidation` | The "Last 24 hours: players/guilds/filters" line reads `n["stats24h.*"]`, which `PSS_Validate` never sets: always prints 0 0 0 (leftover of the retired blockStats). |
| PSS_Upgrade step 1 | Writes `showIgnoreDebug = false` every login (known N8); steps 2 and 4 run the same check. |
| PSS_Options `PSS_SetOpt` | The `def.reload` / `M.PSS_AskReload` branch is dead: no option has `reload`; `useUnitHacks`/`useLFGHacks` labels still say "Requires reload". |
| PSS_ChatFilters flood filter | A duplicate line is hidden with no count, no history line and no event (a block not counted); with `invertSpam` on, duplicates are still hidden. Inverted blocks count only `filterTotal`. |
| PSS_ChatFilters | `FILTERS_CHANGED` fires once per blocked line (G21 throttle planned). Custom filter history keyed by text (`f:t:<text>`): editing loses history (N43). |
| PSS_ChatHistory | `History.KeepAdd`, `History.MovePeople`, `History.Combine`, `History.MergeLists`, `History.FormatCounts` (+ `M.PSS_FormatGuildCounts`, `M.PSS_FormatBlockCounts`) have no caller; `KeptLines`, `CountFor` only in tools. `loadWhenQuiet` uses `C_Timer.After` retries as a gate (L14). Outbox overflow uses `table.remove(ob, 1)` per line once full (O(n) per block while Logging is unloaded and the outbox is at cap). |
| PSS_ChatBlock | `M.PSS__CoreTest` ships in core though its comment says "not shipped". `M.PSS_GetBlockSources`, `M.PSS_CoreEvents`, `M.PSS_EVENT_CATEGORY`, `M.PSS_BLOCK_CATEGORIES/LABELS`, `M.PSS_ChatFrames` have no outside caller. `declineMsg` checks `L[fmtKey]`, always truthy due to the BAD TEXT metatable. |
| PSS_Globals | `V.needSorted` written in many places, never read. `V.wowIsERA/TBC/Wrath/Cata/MOP/Classic`, `V.wowName`, `V.wowLongName` unread. `M.dateToJulianDate` only internal. `M.debugMsg` no-op. `V.playerName = M.addServer(GetUnitName("player"), true)` passes an ignored arg. |
| PSS_MainlineCompat | `M.PSS_Mainline` unread; writes `_G.strlen/strbyte` if missing (a global write; normally a no-op). |
| PourSocialScore.lua | `gotUpdate`, `gotGroup` set, never read; `V.PSS_SyncOK` never read. |
| PSS_Perf | 10-minute idle cycle and the 15 s ticker run all session (the listed known breach C15; P2). |
| PSS_Localization | `INFO_5`/`INFO_6` assigned twice; `OPT_3 = "UNUSED"`. |
