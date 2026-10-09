# Closed project: core uplift (3.4.1, released as 3.4.1.53)

**Closed at the full release 3.4.1.53 (2026-10-09).** Every stage is built and released; how the addon works now is in `01_HANDOVER.md` (re-summarized at this release). This file stays as the record of the design, the decisions and what each stage did; what is still open is in `13_CHANGES_IN_TRAIN.md` and 06. There is no current project until Dan names the next one.

**The implementation plan, locked (Dan, 2026-10-08).** Every decision in section 5 is answered; build on it as written. A change to the plan needs Dan's OK and a line in section 5.

Design and findings: scratch `docs/latest/core-uplift/` (this file is `00_CORE_UPLIFT.md` there; the five appendices are `01_CORE_LIBRARIES.md` (N1 to N48), `02_GUI.md` (G1 to G30), `03_SAVEDVARIABLES.md`, `04_UPGRADE_HELPER.md`, `05_NAME_BUGS.md`). Read an appendix only for the stage that uses it. It replaces the 3.4.1 part of the first review (`docs/latest/code-review/`), whose L12, L14 to L17 and L20 are folded in below. Reviewed at main **3.4.1.30** (`d2ab159`) on Dan's saves 3.4.0.28 (Camelot), 3.2.0-dev011, 3.0.0, 2.0.44.

**How each stage is worked (02 E9 to E11 in the baseline):** one stage per session. Dan resets the session after each stage. A fresh session reads `CLAUDE.md`, this file's stage table and 06, and builds the next stage. Every stage's PR updates this table, 06, and anything else a fresh session needs. At each release, the done stages are re-summarized into `01_HANDOVER.md` (the addon as it works) and leave this table.

## 1. Goal
Fix what players hit today, halve the always-loaded saved data, make every upgrade readable and every save forward compatible, then make the core and the window cheaper and tidier, with nothing visible changing unless a stage says so.

## 2. Design (what changes, where)

### 2.1 Names (appendix 05)
- **Cause.** On Camelot / WoW Forever the unit APIs return the surname where the realm should be. Names built from a unit become `First-Last`, while chat and /who give `First Last-ClassicBetaPvP`. **Confirm in game before N1 (decision 12):** on Camelot, target a "First Last" player and run
  - `/dump UnitName("target")`
  - `/dump UnitFullName("target")`
  - `/dump GetUnitName("target", true)`
  - `/dump UnitRealmRelationship("target")`
  - `/dump GetPlayerInfoByGUID(UnitGUID("target"))`
  - `/dump GetNormalizedRealmName()`
- **Confirmed in game (Dan, Camelot, 2026-10-08)** on "Bynathalador Darkwind": `UnitName` and `UnitFullName` give `"Bynathalador", "Darkwind"`; `GetUnitName("target", true)` gives `"Bynathalador Darkwind"`; `UnitRealmRelationship` gives `1` (same realm); `GetPlayerInfoByGUID` gives name `"Bynathalador Darkwind"` and realm `""`; `GetNormalizedRealmName()` gives `"ClassicBetaPvP"`. So the surname rule is: **a unit API's second value is a surname when `UnitRealmRelationship(unit)` is 1 (`LE_REALM_RELATION_SAME`)**; the name is then `First Last-<own realm>`. A string such as `"First-Last"` carries no unit and is left as it is (the S3 repair handles stored ones).
- **`M.PSS_NormName(name, realm, unit)`** in core (built in N1: returns display, key, canon; the surname rule needs the unit) (`PSS_ChatBlock.lua`). It checks for a secret value first, applies the Camelot surname rule and uses one realm spelling (`GetNormalizedRealmName`). `NormalizePlayer`, `CanonPlayer`, `DisplayPlayer`, `M.PSS_UnitFullName` and every name builder call it (about 14 places today).
- **Callers to change:**
  - `scanUnit` (`PSS_GuildIgnoreList.lua:106`) and the unit menu (`PSS_BlizzardUI.lua:233`).
  - The ignore hooks and `M.ignoreFromCmd` (`PSS_PlayerIgnoreList.lua:597`, which passes `exactName` for the target).
  - `M.PSS_SplitNameArg` (`PSS_Globals.lua:145`): multi-word names.
  - Import (`PSS_ImportExport.lua:344`): normalise, and check the shipped lists.
  - `PSS_FlushManaged`: stops saving the runtime fields `_canon`, `_gkey`, `_managed` and `_virtual`.
- **Left by N1 for N2 (2026-10-08; Dan answered both, decisions 13 and 14):**
  - Display keeps the realm spelling from `V.serverName` (`Classicbetapvp`). **Decision 13 reversed (Dan, 2026-10-08): realm names are not changed.**
  - `M.PSS_CharKey` is built through `M.PSS_NormName(name, realm, "player")` (decision 14, done in N2). The unit `"player"` always reads a second value as a surname. Nothing in any save is keyed by it (it only fills the export's `by` field), so there were no settings to move and no save change.
- **Done in N2 (3.4.1.33):**
  - `scanUnit` and the unit menu build names through `M.PSS_UnitFullName` / `M.PSS_NormName` with the unit.
  - `/pss add` on a target passes the whole name (`exactName`).
  - Blizzard's Ignore hooks fix a `"First-Last"` they are handed when a unit (target, mouseover, focus, group) has that name and surname (`M.PSS_FixUnitName`); a removal also looks up the old form.
  - Your own name (`M.PSS_PlayerDisplayName`) replaces `UnitName("player")` in the self checks (`isSelf`, adding yourself).
  - `M.PSS_SplitNameArg`: two words are the name off Retail, or when "First Last" is listed; quotes still work.
  - Import normalises the member key and merges a shipped member into its shipped record (`M.PSS_MergeIntoShipped`).
  - `PSS_FlushManaged` no longer writes `_canon`, `_gkey` and `_virtual`. **`_managed` is still written:** the member count reads it while the lists are not loaded; it goes with the accessors in S2 and step 10 in S3.
  - The roster warning already uses `GetUnitName(unit, true)`, which gives "First Last" (confirmed in game); unchanged.
- **Shipped lists:** `tools/PSS_BuildManaged.lua` rejects or converts surname-as-realm names. Of its 212 entries, 196 are dropped and 16 converted (decision 6); the data file is rebuilt and re-measured.
- **Done in N3 (3.4.1.37):**
  - The builder has `REALMS` (per group key; `olympus` = `ClassicBetaPvP`, `ClassicBetaPvP2`, the first being where a unit-found name belongs). `fixSurnames`, run by `write` on both paths (OlympusDB and `--reindex`), reads any other "realm" as a surname. `First-Last` is dropped when `First Last` is listed on one of the realms, otherwise it becomes `First Last-ClassicBetaPvP`. It adds a `-- Fixed <date>` header note, which `--reindex` keeps. A second reindex changes nothing.
  - The lists were rebuilt with `--reindex`: 212 names, 196 dropped, 16 converted; 7634 to 7438 entries; realms 210 to 2.
  - Measured: the data file went from 349138 to 334806 bytes (`luac -s` 339094 to 318603) and from 459.8 to 386.3 KB resident while the lists are loaded. The core manifest is unchanged in size (27.4 KB resident).
  - Harness:
    - `check_packed.lua` expects each surname-as-realm name of the dev16 list to be gone or converted.
    - `check_communities.lua`: OLYMPUS now has 197 members.
    - The split check in `validate_all.sh` expects `membersShown` to be 196 lower, plus one for each stored member under a dropped name (`surname_stored.lua`; Dan's 2.0.44 save has one, `georgette-foid`, which S3's repair merges).
  - `tui_compare.sh` shows only the member counts changing, the same in all three looks.
  - Saved records under the old `First-Last` keys are left as they are; S3's repair handles them.

### 2.2 SavedVariables (appendix 03)
- **Identity stays the lowercase `name-realm` key.** There is no ID generator for players or guilds (decision 2): IDs measured 11% smaller on disk and larger in memory. Player GUIDs are not available from /who or the shipped lists, are secret under chat lockdown, and are long.
- **Custom filters get a never-reused integer id** (decision 3). A counter, `nextFilterId`, is stored once and only ever goes up. History and recent counts key on `f:<id>` instead of the filter text (N43), so editing a filter keeps its history and Copy starts a new one. Built-in filters keep `PSS00NN`.
- **Sparse records:** derivable data is not saved.
  - Member records drop `_playerKey`, `_canon`, `_gkey`, `_managed` and `_virtual`.
  - `guild` is saved only when it differs from the rule, `name` only when `TitleCase(key)` differs, and there is no `whenBlocked` on managed records.
  - Counts drop zero fields, and `total` is saved only when it differs from the sum.
  - Player records save W I G P C only when false.
  - Lists drop empty notes, types and `syncInfo`.
  - Log groups drop `m` when it is derivable.
  - Every read of a dropped field goes through one accessor (`M.PSS_MemberGuildName`, `M.PSS_MemberCanon`, `History.EnsureCounts`), and a rules-check grep keeps raw reads out.
  - Expected on 3.4.0.28: Options file 397.7 KB to about 196 KB, always-loaded memory down 380 to 440 KB.
- **Purge by owner:** `History.ClearOwner(o)` replaces the six copies of the history clear (N16): 5.6 ms and 750 KB of garbage become about 70 us with none. When Logging is not loaded, a capped tombstone `PourSocialScoreDB.purge[o]` is applied when Logging next loads, so removing anyone never loads Logging.
- **Done in S1 (3.4.1.49, PR #139; Dan, 2026-10-09, "go": 1 the `purge` key needs no layout OK, it lives in `PourSocialScoreDB` and is saved only while marks wait; 2 a cap of 200, full marks load Logging and clear at once):**
  - `History.ClearOwner(o, mayHave)` (core `PSS_ChatHistory.lua`) replaces the six owner clears: `M.PSS_ForgetPlayer`, `M.PSS_ResetPlayerBlockHistory`, `M.RemoveChatFilter`, `M.PSS_ResetFilterHistory`, `M.PSS_RemoveGuildMember`, `M.PSS_ResetMemberBlockHistory`. Logging loaded: a log walk comparing `o`, `keep[o] = nil`, nothing unpacked. Not loaded: the owner's outbox lines go at once and, unless `mayHave` is false (nothing ever counted), `PourSocialScoreDB.purge[o] = true` (`History.PURGE_CAP` 200; full: Logging loads and clears now). The guild reset keeps `History.Clear(matcher)`; Import Replace's many clears (N27) are not part of S1.
  - `History.ApplyPurge()` in `M.PSS_LoadLogging`, after `UnpackSaved` and `KeepToLog` and before the outbox joins the log, so a person removed and listed again keeps only their new lines; the marks are then cleared. A newer version's log (U3) is left as it is and the marks are cleared.
  - `purge` is in `M.PSS_SCHEMA.core`. Removal never loads Logging (closes the gap in 01 section 5).
  - Harness: `check_purge.lua` ("== purge" in `validate_all.sh`, 4 phases; 2 and 3 fail on main). 50 saves byte-identical with main; `tui_compare.sh` identical.
  - Measured (3.4.0.28 save, harness, 20 owners with the most lines): keep filled to its 2000 cap, 3.43 ms and 1378.5 KB garbage to 36 us and none per owner; the save as it is (keep empty), 55 us to 36 us. `PSS_ChatHistory.lua` 32750 to 34554 bytes compiled; resident after login unchanged (2921.7 KB).
- **Done in S2 (3.4.1.50, PR #140; Dan, 2026-10-09: 1 yes; 2 `_managed` stays saved, S2 adds only its accessor; the stage split, decision 26):**
  - **The accessors** (core `PSS_GuildIgnoreList.lua`, one block between the comments `-- (member fields)` and `-- (/member fields)`): `M.PSS_MemberCanon(m, k)`, `M.PSS_MemberPlayerKey(m)`, `M.PSS_MemberName(m, k)` (the key's display form when `name` is missing), `M.PSS_MemberGuildName(m, g)` (the rule's name when `guild` is missing), `M.PSS_MemberWhenBlocked(m)` ("Managed list" for a shipped record), `M.PSS_MemberShipped(m)`, `M.PSS_StoreMemberCount(g, n)`; inside the block only: the shipped record's runtime fields (`newShippedRecord`, `shippedOnly`, `shippedCanon`, `shippedRule`, `settleShipped`, `dropOwnFields`) and the `memberCount` writes. `k` is the stored key and `g` the rule, when the caller has them.
  - **Counts:** `History.CountTotal(c)` (core `PSS_ChatHistory.lua`) reads a total as the larger of `total` and the categories added up, without changing the table. `History.Add`, `managedDirty`, `memberMayHaveLines`, `compactMember`, the players' and filters' "may have lines", `M.PSS_Validate`, `M.PSS_ListTotals` and the Filters tab's line count read through it.
  - **memberCount:** nothing reads the saved field. The Guilds list keeps the count on its row item (`item.count`, from `M.PSS_GuildMemberCount`), and `M.PSS_GuildInfoLine(g, key)` asks `M.PSS_GuildMemberCount`. The saved value is still written (S3 drops it).
  - **The rules check:** `tools/check_fields.lua` (in `check_rules.sh`) fails `_playerKey`, `_canon`, `_gkey`, `_managed`, `_virtual` or `memberCount` as a field in code outside the block (62 places on main). Strings and comments do not count (the schema map, the export's field list).
  - **Export:** a member's `name`, `guild` and `whenBlocked` are filled through the accessors, so an export stays whole once S3 saves less. Import's shipped merge clears the incoming record's own name fields in `M.PSS_MergeIntoShipped` (it did so in Libraries).
  - **For S3:** the window and the view functions (`M.PSS_MemberTip`, `M.PSS_MemberHeading`, `M.PSS_MemberGuildLine`, `M.PSS_MemberAddedLine`, `M.PSS_MemberRemoveText`, the Guilds tab's rows) pass only the record, with no key or rule. Before S3 drops `name` or `guild`, the accessors need the record's home (for example a weak map from record to key and rule, filled by the member index and `M.PSS_ForEachGuildMember`), measured. `mergeMemberRecord` copies any field the target lacks, so a sparse target would take the source's `name` and `guild` back; S3 skips them there. `M.PSS_GuildMemberCount` reads `M.PSS_MemberShipped` while the lists are not loaded, so dropping `_managed` needs another way to tell a stored shipped member from the manifest.
  - **In game (Dan, 2026-10-09):** checks 1 to 7 pass. Check 1 printed the upgrade report (Updated from 3.4.1.49 to 3.4.1.50, the cleanup line, step 8); that is wanted: every update says it happened (11_PREFERENCES). The report also named 2 custom chat filter rules this version cannot use (kept, not applied).
  - Harness: `check_accessors.lua` ("== accessors" in `validate_all.sh`): a member without `name`, `guild` and `_playerKey` reads the same through the accessors, the member index still finds it, counts without `total` read right and `History.Add` counts on from them, and the member count never reads the saved `memberCount`. It fails on main.
  - Measured (3.4.0.28 save, harness): resident after login 2921.8 to 2927.1 KB (+5.3 KB, the accessor closures). Compiled: core +981 bytes (`PSS_GuildIgnoreList.lua` 65712 to 66437, `PSS_ChatHistory.lua` 34554 to 34830), Libraries +595, GUI +129. An accessor read costs about 0.06 us more than the field (1 million reads, plain Lua 5.1); the guild source reads the guild twice per line it checks. 50 saves byte-identical with main (`same_saves.sh`); `tui_compare.sh` identical in all three looks (125 and 139 steps).
- **Done in S2b (3.4.1.51; Dan, 2026-10-09: layout A, all in one stage, all seven parallel arrays, a downgrade not showing the entries is fine):**
  - **Layout:** `PourSocialScoreDB.list` is one array of sparse records, `{ name, date, [kind] [faction] [note] [exp] [sync] }`, in the old order and addressed by the same index. `ignoreList`, `typeList`, `factionList`, `dateList`, `notes`, `expList` and `syncInfo` are retired (read once by step 9, then dropped by the `RETIRED` loop). `delList` (a FIFO of deleted names, not parallel) and `playerData` stay. A record is a table of its own, so the entries are not stored in `playerData` (it is walked as "players with prefs" in about ten places, and NPC and server entries and same-name entries have no place there).
  - **Accessors** (core `PSS_PlayerIgnoreList.lua`, between `-- (list entries)` and `-- (/list entries)`): `M.PSS_List`, `M.PSS_EntryName`, `M.PSS_EntryKind`, `M.PSS_NewEntry`, `M.PSS_SetEntryNote`, `M.PSS_SetEntryExp`, `M.PSS_SetEntryDate`, `M.PSS_SetEntryFaction`, `M.PSS_EntrySync`, `M.PSS_EntryAddSync`. Removal is one `table.remove(list, i)`. Defaults are read inline (`e.kind or "player"`, `e.note or ""`, `e.exp or 0`).
  - **Step 9** (`PSS_Upgrade.lua`, feature `players`, `listRecords`, `listDuplicates`): zips the arrays into `list`, keeps the first of a legacy duplicate (same lower-case name and kind), safe to run twice, runs after step 1's fields (still on the arrays) and before every data part. A newer or unknown field on a record is kept. `M.PSS_Validate` reads the records; its counters are unchanged.
  - **Harness:** `check_listrecords.lua` ("== list records": every save migrates in one login with the same counters, a second login changes nothing, a drift test with adds and removals in the middle, sparse records, unknown fields kept, removal clears the player's data); `same_saves.sh` writes the old and the new players layout in one shape (`same_norm.lua`) and ignores the upgrade step and time, every other store stays byte for byte.
  - **Measured (5000 entries, plain Lua 5.1):** the old arrays 1486.9 KB, the records 1557.4 KB (+4.7%): a record is a table, so a listed entry costs about 14 bytes more in memory than eight array slots; the gain is that no entry can drift or hold an empty table. Dan's own saves hold 4 listed players.
  - **Downgrade:** 3.4.1.50 and older read the arrays, so they show an empty list over a migrated save; the records stay in the save.
- **Upgrade step 10, "SavedVariables performance cleanup"** (step 8 is B1's, 2.7; step 9 is S2b's) (decision 4; Dan's OK given, D9): one run-once step for everything below, then one validation on all four saves with identical counters.
  - Sparse records, and the runtime fields dropped.
  - The 1500 member cap per rule, and `memberCount` no longer saved (L12, L16).
  - The Camelot name repair (decision 5), on Camelot saves only, and only for records with `faction` and no `_playerKey`:
    - About 184 records are merged into the shipped records, 48 into their stored twins, and about 267 re-keyed to `first last-realm`.
    - Player-list keys and `p:` / `g:` log owners get the same conversion.
    - First-name-only entries cannot be repaired. They are listed once in chat so Dan can re-add them.
  - `showIgnoreDebug` is no longer saved (N8).
  - Custom filter ids are assigned, and their history and recent keys moved to them.

### 2.3 Forward compatibility (decision 10, Dan's addition)
**The goal: this layout is the last time the saves are readdressed.** From 3.4.1 on, a save written by a newer version works in an older one, and the reverse, without loss:
1. **One schema map, `M.PSS_SCHEMA` (core, data only).** For every store it lists the saved fields, the function that reads each one and its default. A rules check fails any saved field the code writes that is not in the map. This is how each field is checked against a known function.
2. **Tolerant readers.** A missing field reads as its default. An unknown field is kept untouched and never deleted.
3. **Nothing is deleted by guesswork.** The cleanup removes only keys named in one `RETIRED` list, so an older version never strips a newer version's fields.
4. **Step numbers only grow, and each step is safe to run twice.** The upgrade record also keeps the highest version that has written the save.
5. **A newer save on an older version** (a downgrade) prints one line saying the save is from a newer version, keeps the newer record, and runs no step backwards.
6. **Rules this version cannot use are reported, kept and exportable.** After every version change, in either direction, each saved rule is checked against the code that applies it:
   - custom filters: does it compile with `M.PSS_CompileFilter`?
   - guild rules: are its kind and its fields in the schema map?
   - options: is it in `M.PSS_OPTIONS`?

   A rule that fails is not applied. It stays in the save unchanged, so moving back to a version that knows it restores it. The report names the rules and offers an export: "Chat Filtering: 2 rules this version cannot use (kept, not applied): /pss export unused". The command copies them to the Import/Export text so they can be saved outside the game. A rule becomes usable again the moment a version that knows it loads.
7. **Exports carry a format version** and every field (filled from the accessors), so an export is readable by older and newer versions alike. Import keeps unknown fields.
8. Releases up to 3.4.1.30 cannot run this; S3's validation runs 3.4.0.29 on a migrated save once to prove it tolerates the sparse records.
- **Done in U3 (3.4.1.47, fixed in 3.4.1.48, PR #138; Dan, 2026-10-09, "go" on the five recommendations: 1 one stage; 2 no new saved key, `upgrade.version` is the highest version (U2 keeps the newer one on a downgrade); 3 `/pss export unused` shows the window's copy box, the window stays closed; 4 the map in core, measured; 5 the format version inside the payload, the `PSS1` tag kept):**
  - **The map:** `PourSocialScore/PSS_Schema.lua` (core, data only, after `PSS_SavedData.lua` in the three TOCs). `M.PSS_SCHEMA` holds one string per record kind: `core` (PourSocialScoreDB's own keys), `upgrade`, `player`, `guild`, `member`, `block`, `counts`, `filterStat`, `builtinStat`, `line`, `logGroup`, and `<kind>Old` (fields older versions saved that this one reads once to convert). Each field is `name`, `name=default` or `name@reader`. The top-level keys are LAYOUT plus `M.PSS_OPTIONS` plus `core`. `M.PSS_SchemaKnows(kind, field)` (core `PSS_Upgrade.lua`) builds a kind's set on first use.
  - **The checks:** `tools/check_schema.lua` in `check_rules.sh` fails a top-level key the code writes (`PourSocialScoreDB.<key> =`, a `local db = PourSocialScoreDB` alias, `rawset(db, "<key>")`) that the map does not list. `check_schema.lua --saves <files>` in `validate_all.sh` ("== schema", and after each real save) fails a field of any saved record the map does not list; planted fields start with `newer`. **Any stage that saves a new field adds it to the map in the same PR.**
  - **Unusable rules** (`M.PSS_UnusableRules()`, core): a custom filter `M.PSS_CompileFilter` rejects; a guild rule whose `managed` list this version does not ship, or with a field the map does not name (`M.PSS_GuildRuleUnusable`); a key in `PSS_OptionsDB` that is neither routed nor `RETIRED`. Never applied: a filter that does not compile never was; a guild rule is skipped in the guild source's `decide` and in `guildRuleActive` through a set of only those rules, rebuilt when the member index is marked dirty. Nothing is changed in the save.
  - **Report:** after a version change the count of each goes on its feature's line (`unusable` in `PHRASES`: "N custom rule(s) this version cannot use (kept, not applied): /pss export unused", the same for guild rules, "N setting(s) this version does not know (kept)"). A downgrade prints the U2 line, then the same lines (every login while the save is newer).
  - **`/pss export unused`** (Libraries `PSS_Commands.lua`, `M.PSS_UnusedExportText` in `PSS_ImportExport.lua`): an export string (`unused = true`) of the filters, the guild rules with their members and every field, and the settings; shown in the copy box (GUI `M.PSS_CopyTextBox`, the window stays closed); "nothing to export" when there are none. `/pss help` lists it.
  - **Export format 2:** `v = 2` in the payload. A player's prefs, a guild rule and a member carry `more`: the record's fields this version does not know (not `_` fields), copied plain. Import puts `more` back only where the field is unknown and empty. 3.4.0.29 imports a format 2 string (harness `oldimport`).
  - **Tolerant readers** (each a loss the harness found on main): the history tidy keeps lines and rule tags whose owner is a form this version does not make (only `f:t:...` and `f:PSS####` filter owners, `PSS####` tags are judged); `History.FilterKey` takes a number id (`f:12`, S3's form); `M.PSS_ExpandFilters` / `M.PSS_CollapseFilters` keep a custom filter's number id and a built-in rule this version does not have (`builtinRules`, `builtinStats`); a filter's counts table keeps fields it does not know; a block log saved with `v` above 2 is kept as it is (one chat line; this session's lines are counted, not saved) and so is a recent-counts table with `v` above 2. **For S3:** a new per-filter field goes in `filterID` (the id) or a table keyed by id, never a new parallel array; a new log or recent layout takes `v = 3`.
  - Harness: `check_forward.lua` ("== forward compatibility" in `validate_all.sh`): plant (fresh save, a newer version's fields at every level, a filter tag, a number filter id with its lines and recent count, a built-in rule, an option), a plain login, check (the report or downgrade lines, not applied, the rest still blocks, the tidy, `/pss export unused` and the copy box, format 2 and `more`, a merge keeps them, the next login), after (every planted value unchanged in the saved file), for a newer (3.4.1.99) and an older (3.4.1.46) record; oldimport on 3.4.0.29's code; newerlog (a v3 log and recent table come back unchanged). On main's code the after and newerlog phases fail (8 failures). `check_keep.lua`: the removed-rule tag is `PSS9998` (a form this version makes) and a number tag stays.
  - Measured (3.4.0.28 save, harness, a save each build stamped): +10.5 KB resident after login (the map 3.2 KB of it); +1.3 KB more once a listed member's line builds the guild set; `M.PSS_UnusableRules` 0.42 ms, only on a version-change login. Compiled: core +6.7 KB (`PSS_Schema.lua` 2373 bytes, `PSS_Upgrade.lua` 20893 to 23586), Libraries `PSS_ImportExport.lua` 14899 to 17483. 50 saves byte-identical with main (`same_saves.sh`); `tui_compare.sh` identical (125 and 139 steps). The unusable-rules code and the map are P6 candidates for a measured move.
  - **Fix, 3.4.1.48 (Dan's in-game checks of 3.4.1.47: 1, 2, 4, 5, 7 pass; 3 and 6 failed):** `PSS_Popups.lua` defined `M.PSS_CopyTextBox` without a `local M`, so loading the GUI folder errored at that line: `/pss export unused` did nothing and the Export button gave no string. `local M = ns.M` fixes it. **Lesson:** `run.lua` used to set a global `M` for its scripts, which hid the missing local; it now gives `M` to the script's own environment only, and `tools/check_locals.lua` (rules check) fails any addon file that uses `M` without a local. Without the fix `check_forward.lua` and `check_options.lua` fail.

### 2.4 Upgrade report (appendix 04; issue #45)
- **A step registry in `PSS_Upgrade.lua`.** Each entry has `id`, `feature`, `always` (runs every upgrade), and `fields` / `data` functions that add their counts to an `out` table. Step 1 is split into feature-tagged parts. Retired keys are pruned in one loop over `RETIRED`.
- **At the first login after a version change, one batch prints all at once (decision 9):**
  - a header;
  - a line for each feature that changed (decision 7): Chat Filtering, Player Ignore List, Guild Ignore List, Managed Communities, Block History, Options;
  - **always** "SavedVariables performance cleanup", with its counts and the size before and after;
  - today's last line, "Saved data upgraded to X (step N).", unchanged.

  Example (numbers illustrative; each line goes through `M.ShowMsg`):
  ```
  Pour Social Score: Updated from 3.4.0.29 to 3.4.1.53. Upgrading your saved data:
  Pour Social Score:   Chat Filtering: 3 rule(s) given an ID.
  Pour Social Score:   Guild Ignore List: 267 Camelot name(s) repaired.
  Pour Social Score:   SavedVariables performance cleanup: 6 retired key(s) removed, 1,208 saved record(s) made smaller.
  Pour Social Score: Saved data upgraded to 3.4.1.53 (step 10).
  ```
- Today's data-move messages stay as they are and print before the report (decision 8). A downgrade prints one line (decision 10). A normal login builds no strings and costs nothing. All output goes through `M.ShowMsg`, in ASCII.
- **Harness:** `check_upgrade_report.lua`, 10 cases:
  - the registry's shape;
  - an upgrade from 2.0.44;
  - silence when the version is the same;
  - a fresh save;
  - a version-only bump;
  - planted retired keys;
  - a downgrade;
  - a paused step;
  - the four real saves;
  - a memory bound when nothing upgrades.

  Plus a "== upgrade report" section in `validate_all.sh`.
- **Done in U1 (3.4.1.45, merged, PR #136; invisible; Dan, 2026-10-09: 1 the retired loop runs after the data parts, 2 steps 5 and 7's keys join it, 3 a byte-identical check against main):**
  - `STEPS` rows are `{ id, always, parts }`; each part is `{ feature, fields, data }` (`M.PSS_UPGRADE_REGISTRY`, `M.PSS_UPGRADE_FEATURES`). Parts take no arguments and count through the file's `tally(feature, key, n)`. Step 1 is six parts in 2.0's order: fields options, players, filters; data legacy (guilds), unlink (filters), tidy players, tidy history. Steps 2 to 8 have one part each (step 7 two).
  - `RETIRED` (`M.PSS_UPGRADE_RETIRED`): `autoIgnore`, `autoUpdate`, `autoCount`, `autoTime`, `attachFriends`, `syncList`, `filterHistory`, `blockStats`, `optionsV2012`, `charOptions`, `historySize`, `euiIntegration`, `windowSizes`, `columnWidths`, `blizzardSync`. Dropped at every login after the data parts (step 8 reads `blizzardSync` first), counted as `cleanup.retired`. Step 5 keeps only the 2.0.12 switch-off, step 7 only the `windowPoints` prune, step 8 only the ticks.
  - `M.PSS_RunUpgradeFields(fresh, defaults)` decides whether the login reports (not fresh, and a step due or `upgrade.version` differs); only then is `out` built. `M.PSS_RunUpgradeData(fresh)` returns it: `from`, `to`, `done`, `step`, `paused` and a table per feature (keys today: `players` lists / renamed / tidied / toGuilds / declines / blizzardTicks; `filters` reset / lists / ids / unlinked; `guilds` scanFields; `managed` rules; `history` formats / tidied; `options` switchedOff / places; `cleanup` defaults / retired / oldFolders). Nothing prints from it yet (U2).
  - Count returns: `M.PSS_ApplyOptionDefaults`, `M.PSS_UnlinkGuildRuleCounts`, `ensureManagedRules` (rules created), `cleanupLegacyGuildPlayers`; `M.PSS_UpgradeLegacyData(tally)` counts formats, scan fields, managed rules and players moved to guilds.
  - `M.PSS_VersionOrder(a, b)`: -1, 0, 1, or nil when either is not a version. X.Y.Z.B by its numbers; any older name is older than an X.Y.Z.B; `X.Y.Z-devN` is older than `X.Y.Z`.
  - Harness: `check_upgrade_steps.lua` ("== upgrade steps", fresh, the 2.0.44 test save and every real save) and `same_saves.sh <ref>` (`PSS_SAME_AS=origin/main` in `validate_all.sh`): 50 saves byte-identical with main, chat too. Use it again for U2 (only the report lines may differ in chat) and S1, S2.
  - Measured: `PSS_Upgrade.lua` 15173 to 18900 bytes compiled; resident after login +9.6 KB (3.4.0.28 save, harness). The one-time steps and `M.PSS_VersionOrder` are P6 candidates for Libraries. `tui_compare.sh` identical.
- **Done in U2 (3.4.1.46, PR #137; Dan, 2026-10-09, "go" on the three recommendations: 1 no save size on the cleanup line, which the game cannot read (S3 decides); 2 the downgrade line is in U2, U3 adds the rest; 3 the prefix is `M.ShowMsg`'s):**
  - `printReport` at the end of `M.PSS_RunUpgradeData`, only when it returns counts: `L["UPG_HEAD"]` ("Updated from A to B. Upgrading your saved data:"; `L["UPG_OLD"]` "an older version" with no record), a line per feature with text, the cleanup line always (`L["UPG_NOTHING"]` "nothing to tidy"), then `L["UPG_DONE"]` "Saved data upgraded to X (step N)." (now also on a version-only change), or the red `L["UPG_PAUSED"]` instead when a step paused.
  - Phrases: `PHRASES` (`M.PSS_UPGRADE_PHRASES`) lists each feature's count keys in print order, the text is `L["UPG_<feature>_<key>"]` with `(s)` plurals and `fmtNum` (`12,480`). A key with no phrase does not print; the harness fails one. `cleanup.oldFolders` has none: the step 7 part puts the folder names on the cleanup line (`L["OLD_FOLDERS"]` after it) when the login reports, else prints the note as before.
  - Downgrade: `M.PSS_RunUpgradeFields` sees `M.PSS_VersionOrder(rec.version, version) == 1`; no counts, `L["UPG_NEWER"]` once per login on the older version, and the record keeps the newer version (its step only grows).
  - Harness: `check_upgrade_report.lua` (10 cases) as "== upgrade report" in `validate_all.sh` on a new save, the 2.0.44 test save and every real save (`PSS_LOGIN_OUT` names the first login's output). `same_saves.sh` drops the report's lines from the chat it compares (`REPORT`); the saves must still be byte-identical: 50 saves were.
  - Measured: `PSS_Upgrade.lua` 18900 to 20893 bytes compiled, `PSS_Localization.lua` 37226 to 39804; resident after login +7.1 KB (3.4.0.28 save, harness); a login with no report 0.2 KB around the two calls. `tui_compare.sh` identical.

### 2.5 Fixes (appendices 01 and 02)
- **N40, expiry (decision 11):** applied at login, on a quiet event and when a list opens, as the readme says. This is a bug fix, so it needs no opt-in.
- **N41:** each hook body is gated by its option (J3), so the option applies without a /reload.
- **N42:** talent links convert to a tag the filter language knows.
- **N45:** Import with Replace on guilds keeps the shipped rules.
- **N46 to N48:** listener errors are reported, the group warning list is fixed, and `/pss list` no longer hits a nil.
- **Done in F1 (3.4.1.42):**
  - N40: `M.PSS_ExpireEntries(quiet, daily)` (core `PSS_PlayerIgnoreList.lua`), the expiry loop out of `SyncIgnoreList`. It runs at login after `M.PSS_RunUpgradeData`, on `PLAYER_REGEN_ENABLED` (the quiet event; at most once a day, no timer), in `M.PSS_OpenUI` and the Friends dock (the list opens), in `/pss list` and in `/pss sync`. One chat line names what it removed (`M.PSS_DelIgnore(i, true, quiet)`). Dan's real saves have no ignore list entries, so nothing changes on them.
  - N41: the four hook bodies return early when `useUnitHacks` / `useLFGHacks` is off. The hooks are installed at login or on the first enable (`OPTION_CHANGED`; the Group Finder waiter re-arms). The labels lost "(Requires reload to take effect)". The reload popup (N3) stays dead; P1 deletes it (Dan, 2026-10-09: "remove in p1").
  - N42: `[talent]` / `[talent=N]` in `KNOWN_TAGS` and `TAG`; `analyse` collects `F.talentID`.
  - N45: `M.PSS_ClearGuildRules()` (core `PSS_GuildIgnoreList.lua`) replaces `db.guildData = {}` in Import Replace. Shipped rules stay; the others go with their recent counts; `ensureManagedRules`; index dirty. `existed` uses `M.PSS_NormalizeGuild`.
  - N46: `M.PSS_NoteListenerError(where, err)` (core `PSS_Events.lua`; `M.Events.errors`) for `Events.Fire` and the /who handlers: once per name in chat, counted in `/pssguild status`.
  - N47: `V.groupWarning` is rebuilt from the roster on each check; a warning only for someone new.
  - N48: `/pss list` reads the note safely.
  - Harness: `tools/harness/check_fixes.lua` ("== fixes" in `validate_all.sh`). Measured: core +2574 bytes compiled, +6.1 KB resident after login (harness). `tui_compare.sh`: only the two labels, in all three looks.
- **G21 and G26:** the Filters tab's redraw is throttled, and the guild rows' rule dim refreshes on `FILTERS_CHANGED`.
- **G27:** Dark right-click menus grow to their content, capped at 400 px (Dan, 2026-10-09; Blizzard's menu scrolls at the same height).
- **G28:** the Modern art check covers every atlas Modern draws.
- **Done in F2 (3.4.1.44, merged, PR #135; in-game checks pass; Dan, 2026-10-09: the Blocked sort still follows, the cap is 400):**
  - G21: core `PSS_ChatFilters.lua` no longer fires `FILTERS_CHANGED` after a block. `PSS_Filters.lua` sets `V.dirty` on `FILTER_HISTORY_CHANGED` and runs `Refresh` (re-sort and pane) through the existing 4-a-second throttle.
  - G26: `PSS_Guilds.lua` listens to `FILTERS_CHANGED` (`Changed`); the three `V.dirty = true` lines after the rule toggles are gone (G5's rule-toggle part).
  - G27: `PSS_Menu.lua` `SIZES` has a `cap` per size: 200 for a drop-down's list, 400 for a compact right-click menu (`MAX_H` is gone). `ns.ContextMenu` measures its width over every entry with one measuring FontString (`menu.measure`).
  - G28: `MODERN_ART` in `PSS_Skin.lua` lists all 19 atlases Modern draws.
  - Harness: `check_filters.lua` (no `FILTERS_CHANGED` per block), `check_guilds.lua` (the dim follows `M.PSS_SetManagedGroupActive`), `check_menus.lua` (an 18-entry Dark menu shows whole, width from its last entry); each fails on main. Measured: 32.5 KB to 16.9 KB garbage per block with the tab open (harness, 20 blocks a second; 0.56 KB hidden, unchanged); core -75 bytes compiled, GUI +817. `tui_compare.sh` identical in all three looks (the tour opens no long Dark menu and its stub has every atlas).
- **The detail pane fix (3.4.1.40, decision 23), its text collision's text collision** (Dan's screenshot, 2026-10-08, Dark look): the Managed Communities list's detail lines sit at fixed heights (`BuildGroupBody`, `PourSocialScore_GUI/PSS_Guilds.lua`). "Rule on the Chat Filters tab: Managed Communities - Asmongold (InfluencerGuild=Olympus)" wraps and runs into "Rule is OFF: ...". Present since 3.4.0-dev009. The fix keeps the text: each line anchors under the one above it, so a wrapped line pushes the rest down, and the pies (`ns.NewSummary`, `ns.NewTypePie`) start below the last line. **Lesson (3.4.1.41):** a FontString anchored on both sides (TOPLEFT plus RIGHT) stays one line tall in game when it wraps, so anchoring under it does not move; give it a set width and set its height from `GetStringHeight` after `SetText` and on repaint. The harness stub does not wrap, so `tui_compare.sh` cannot show this; only the in-game check can. Check every fixed-height `Line()` stack in `PSS_Guilds.lua` (guild and member panes) and `PSS_Players.lua` the same way, in all three looks and with a large `uiFont`.

### 2.6 Performance and tidy (3.4.2, 3.4.3)
Listed in section 4. Each stage is invisible and proven with `tui_compare.sh` identical in all three looks, plus measured numbers.

### 2.7 Blizzard's ignore list and the right-click menu (B1, B2; Dan, 2026-10-08, decisions 15 to 21)
**PSS is authoritative.** PSS never puts anyone on Blizzard's ignore list unless the player asked for it for that person.
- **B1, per-player Blizzard ignore** (decision 15). The global option `blizzardSync` ("Also put listed players on Blizzard's ignore list") becomes a tick box per listed player, off by default, in the player's detail pane in the PSS window (all three looks; not in the right-click menu, decision 21). Ticked: PSS adds them to Blizzard's list (when it has room). Unticked: PSS takes them off it. Stored as a non-default field on the player's prefs record (`PSS_PlayersDB.playerData`), true only.
- **A new Blizzard ignore moves into PSS** (decision 16). Ignoring someone through Blizzard (its Ignore menu entry or `/ignore`) lists them in PSS as today. On the next `IGNORELIST_UPDATE` that shows them on Blizzard's list, PSS removes them from Blizzard's list (guarded so its own hooks do not see it) and adds the note `Synced from Blizzard ignore list on <date>` (`%d %b %Y`). Someone PSS already lists comes off Blizzard's list too, and keeps their note (decision 18). Everyone gets this, without an option: an approved override of C2 (02 section 12).
- **Your existing Blizzard list is synced across, not managed** (decision 17). At login (after the first `IGNORELIST_UPDATE`), anyone on Blizzard's list whom PSS does not list is added to PSS with the note and their per-player tick on, and stays on Blizzard's list. Players are never removed from Blizzard's list by this sync.
- **Removing from either removes from both** (decision 19, "user systems must be intuitive"). Removing a player in PSS removes their Blizzard ignore if they have one (as today), and Unignore in Blizzard's window removes them from PSS (as today).
- **Blizzard's chat lines** ("X is now being ignored", "X is no longer being ignored") are left alone; PSS never filters them (decision 20).
- **Upgrade step 8 (Dan's OK, decision 15, D9):** a save with the global `blizzardSync` on gives every PSS-listed player who is on Blizzard's list the per-player tick, then the global key is retired. Validated on the four real saves; counters identical.
- J rules: `C_FriendList.AddIgnore` / `DelIgnore` are called only from a user action or `IGNORELIST_UPDATE` (as today), with the hook guard; no Blizzard frame or chat line is touched (J2, J3).
- **Done in B1 (3.4.1.35):**
  - `M.PSS_SetBlizzardIgnore(name, on)` (core, `PSS_PlayerIgnoreList.lua`) sets `p.blizzardIgnore` (true only) and puts the player on, or takes them off, Blizzard's list through the hook guard; refused with a chat line when Blizzard's list holds 50. The tick is a row "Also on Blizzard's ignore list" in the View/Edit Rule page (`PSS_Players.lua`; text, tip and the toggle in Libraries `PSS_PlayerView.lua`).
  - Blizzard's Ignore (`AddIgnore`, the toggle) lists the player with the note and queues a move (`pendingMove`); the next `IGNORELIST_UPDATE` that shows them takes them off Blizzard's list unless they are ticked (30 s, then the entry is dropped). Someone already listed is queued the same way and keeps their note.
  - The first `IGNORELIST_UPDATE` after login (once `V.PSS_Loaded`) lists everyone on Blizzard's list whom PSS does not, with the note and the tick on; nobody is taken off. The manual `/pss sync` and the first-time import use the same note and tick; the move to Blizzard now follows the ticks.
  - Upgrade step 8 (`PSS_Upgrade.lua`, `data` part): a save with `blizzardSync` on ticks the listed players Blizzard's list has now, sets `V.PSS_TickOnSync` (the first list update ticks again, as the list may not have arrived at login) and retires the key. `blizzardSync` left `M.PSS_OPTIONS`; it stays in `PSS_SavedData.lua`'s `LAYOUT.options` so the step can still read it.
  - Decision 20: the system-message filter no longer hides "is now being ignored" / "is no longer being ignored" / "already ignored" in the first 90 s after login.
  - `/pss add` on someone already listed now says "already ignored" (before, only when Blizzard's list had them).
  - `tools/harness/check_blizzard.lua` (flow, make, login with the list there and arriving late) is in `validate_all.sh`; the stub keeps a real Blizzard list (`PSS_BLIZZ_IGNORES`, `PSS_BLIZZ_LATE`).
- **B2, the right-click menu** (decision 21). The unit and chat-name menus get one "PSS" header (`root:CreateTitle`) with two entries, "Block Player" and "Block Guild", in place of today's single toggle. Each says "Unblock Player" / "Unblock Guild" when that player or guild is already listed (the recommended option; Dan did not pick this one). "Block Guild" adds the player's guild as a guild rule (`GetGuildInfo(unit)`); it is hidden when the menu has no unit or the player has no guild, and never offered for your own guild (`M.PSS_IsOwnGuild`).
- **Done in B2 (3.4.1.36):** `M.PSS_UnitMenuPlayer` (core, `PSS_BlizzardUI.lua`) now builds a divider, a "PSS" title (`L["RCM_16"]`) and "Block Player" / "Unblock Player" (`RCM_17`, `RCM_18`; the old toggle). "Block Guild" / "Unblock Guild" (`RCM_19`, `RCM_20`) is added only for a real unit whose `GetGuildInfo(unit)` is a readable, non-empty guild that is not your own (`M.PSS_IsOwnGuild`); a name clicked in chat has no unit, so it gets the player entry only. Block Guild calls `M.PSS_AddGuild`; Unblock Guild calls `M.PSS_RemoveGuildNow` (a shipped guild still says it cannot be removed). The LFG applicant menu keeps its own single entry (not part of decision 21). Same Menu API tags as before; no new hook. J rules: J2/J3 (post-hook `Menu.ModifyMenu` only, no Blizzard state written), J7 (guild checked with `M.PSS_IsSecret` before any compare). `tools/harness/check_unitmenu.lua` (header, both entries and labels, no guild, own guild, secret guild, chat-name menu) is in `validate_all.sh`.

## 3. Constraints
- Baseline 02 and PSS 02 in full.
- J rules on every name and hook path: `M.PSS_IsSecret` before any compare, plus a restriction-CVar run (02 10.6).
- No timers as logic gates (C3).
- Zero cost when nothing upgrades.
- Counters never derived from log lines, and identical before and after every data step.
- Logging loads only when called.
- No new SavedVariables. The `purge` tombstone and `nextFilterId` live in existing tables.

## 4. Stages
**Combined build 3.4.1.52 (decision 28):** S3, P1 to P6 and W1 to W4 are done in one build; what each did, its measured numbers and open points are in `docs/pss/reference/combined-3.4.1.52/`. Rows below say "Done in 3.4.1.52".
Build numbers never reset. 3.4.1.31 is this plan's own build (docs and working rules only). One stage per PR, per session.

### Line 3.4.1: fixes and data
| Stage | Build | Change | Visible? | Validated by | State |
| --- | --- | --- | --- | --- | --- |
| Plan | 3.4.1.31 | This plan; working rules (one stage per session, context updated in every PR, state re-summarized at release, Dan's preferences in `11_PREFERENCES.md`); baseline v9; CLAUDE.md loads less | No | `check_rules.sh` | PR #119 |
| (Dan) | | Run the six `/dump` lines of 2.1 on Camelot and paste the output | | Confirms the cause before N1 | Done 2026-10-08 (2.1) |
| N1 | 3.4.1.32 | `M.PSS_NormName`; the existing name helpers call it; `check_names.lua` | No (only `PSS_UnitFullName` on a Camelot surname target) | Every key on the four saves unchanged except the Camelot surname case | PR #120 |
| N2 | 3.4.1.33 | Every name caller (2.1), multi-word `/pss add/remove/expire`, import with the managed check, runtime fields not flushed; `M.PSS_CharKey` (decision 14; decision 13 reversed) | Yes | On Camelot, "First Last" added from the menu, Ignore and `/pss add`; Retail unchanged; the restriction CVars run | PR #121 |
| Plan B | 3.4.1.34 | B1 and B2 added to this plan (2.7, decisions 15 to 22); docs only | No | `check_rules.sh` | PR #122 |
| B1 | 3.4.1.35 | PSS is authoritative over Blizzard's ignore list (2.7): the per-player Blizzard ignore tick, a new Blizzard ignore moves into PSS with its note, the existing Blizzard list is synced across, removal from either removes from both; upgrade step 8 (the global option to per-player ticks) | Yes | In game on Retail and Camelot: Blizzard Ignore, the tick in all three looks, removal both ways; the four real saves | Merged, PR #123 |
| B2 | 3.4.1.36 | The right-click menu: a "PSS" header with "Block Player" and "Block Guild" (2.7) | Yes | In game on Retail and Camelot, unit and chat-name menus; the restriction CVars run | Merged, PR #124 |
| N3 | 3.4.1.37 | Builder fix and the shipped lists rebuilt | Yes (lists) | `check_packed`, `check_communities_seen`; size measured | Merged, PR #126 |
| Docs | 3.4.1.38 | `07_HARNESS.md`: checks after a shipped list rebuild (missed N3's merge); N3 marked merged; docs only | No | `check_rules.sh` | Merged, PR #127 |
| Docs | 3.4.1.39 | The code map and changes in train (`12_CODE_MAP.md`, `13_CHANGES_IN_TRAIN.md`; appendices in `reference/code-map/`), loaded on demand; the later stages move up one build; docs only | No | `check_rules.sh` | Merged, PR #128 |
| Fix | 3.4.1.40 | The Guilds tab detail pane: a line that wraps (the list's "Rule on the Chat Filters tab: ..." line in Dan's screenshot) pushes the lines and pies below it down, instead of running into the next line (section 2.5, decision 23) | Yes | `tui_compare.sh` on a narrow pane and a long rule name: no overlap in all three looks; in-game in all three looks | Merged, PR #129 (did not take in game) |
| Fix 2 | 3.4.1.41 | The same pane: 3.4.1.40's lines kept two side anchors, which hold a FontString one line tall in game, so the wrap still overlapped (Dan's screenshot, 2026-10-08). The four lines get a set width (`DETAIL_W - 20`) and `FitLines` sets each one's height from `GetStringHeight` on every show and repaint | Yes | `tui_compare.sh`: only the four lines' size and anchors, in all three looks; in game in all three looks | Merged, PR #130 (works in game) |
| F1 | 3.4.1.42 | N40, N41, N42, N45, N46 to N48 | Yes | A harness case for each; in-game checks | Merged, PR #131 (in-game checks 4 and 7 later: #132, #133) |
| Docs | 3.4.1.43 | F1 marked merged; every later stage moves up one build and the 3.4.2 and 3.4.3 stages get their expected builds (decision 24); docs only | No | `check_rules.sh` | Merged, PR #134 |
| F2 | 3.4.1.44 | G21 with G26, G27, G28 | Yes (G27 in Dark) | `tui_compare.sh`: only the Dark menu height; garbage per filter block measured | Merged, PR #135 (in-game checks pass, Dan, 2026-10-09) |
| U1 | 3.4.1.45 | Upgrade registry, invisible: step 1 split and tagged, `RETIRED`, counts returned, version compare | No | Saves byte-identical on all four saves | Merged, PR #136 |
| U2 | 3.4.1.46 | The upgrade report (2.4); `check_upgrade_report.lua` | Yes (once per update) | 10 cases; in game, the batch prints once and the next login prints nothing | Merged, PR #137 |
| U3 | 3.4.1.47 | Forward compatibility (2.3): `M.PSS_SCHEMA` and its rules check, tolerant readers, the downgrade line, unusable rules reported and kept, `/pss export unused`, the export format version | Yes (only when a rule cannot be used) | Planted newer fields survive; a planted unknown filter tag is reported, kept and exported; a downgrade case | Merged, PR #138 (in game: checks 3 and 6 failed, fixed in 3.4.1.48) |
| U3 fix | 3.4.1.48 | `PSS_Popups.lua` used `M` with no `local M`: the GUI folder stopped loading at its last line, so `/pss export unused` did nothing and the Import/Export tab gave no string (Dan, in game, 2026-10-09). `local M = ns.M`; the harness no longer has a global `M` for addon code (`run.lua`), and `tools/check_locals.lua` (rules check) fails a file that uses `M` without a local | Yes | `check_forward.lua` and `check_options.lua` fail without the fix; in game checks 3 and 6 again | Merged, PR #138 |
| S1 | 3.4.1.49 | `History.ClearOwner` and the purge tombstone; the six copies call it | No | Identical lines and counters; 5.6 ms to about 70 us | Merged, PR #139 |
| S2 | 3.4.1.50 | Accessors for the guild member fields, counts totals and `memberCount` S3 drops; `check_fields.lua` in the rules check (decision 26) | No | `tui_compare.sh` identical; 50 saves byte-identical with main | PR #140 (in-game checks 1 to 7 pass, Dan, 2026-10-09) |
| S2b | 3.4.1.51 | The player list arrays become one array of sparse records, `list` (decision 27); upgrade step 9; the W I G P C accessors and the log group's `m` move to S3 | No (the report line once) | `check_listrecords.lua`; counters identical on every save; `same_saves.sh` normalised | Merged, PR #141 |
| S3 | 3.4.1.52 | Upgrade step 10 (2.2; step 9 is S2b's); also the player W I G P C accessors and the log group's `m` (from S2b): sparse records, cap, `memberCount`, Camelot repair, `showIgnoreDebug`, filter ids | Yes (report, smaller save) | Four saves: counters identical, sizes before and after; 3.4.0.29 run on a migrated save | Merged in the combined build, PR #142 |
| R | 3.4.1.53 | Release: version only; one summary of 3.4.1.30 to 3.4.1.52 (the combined build holds S3, P1 to P6 and W1 to W4; decision 28) from their PRs; `01_HANDOVER.md` re-summarized | | Dan confirms | PR #143 (Dan, 2026-10-09: "launch a release") |

### Line 3.4.2: core performance and tidy (builds continue)
Expected builds, if nothing is added before them (decision 24).

| Stage | Build | Change |
| --- | --- | --- |
| P1 | 3.4.2.54 | Dead code N1 to N15: 61 localization strings, about 25 unused `M.*` exports, `V.needSorted`, the reload popup (`PSS_RELOAD`, `M.PSS_AskReload`, `def.reload` and the `before` read in `M.PSS_SetOpt`; Dan, 2026-10-09), the compat globals, `/pss test` | Done in 3.4.1.52 (decision 28) |
| P2 | 3.4.2.55 | Event-driven GC and `loadWhenQuiet` without timers (L14; closes the known breach in 02 section 12) | Done in 3.4.1.52 (decision 28) |
| P3 | 3.4.2.56 | Capture events only when needed (L15) | Done in 3.4.1.52 (decision 28) |
| P4 | 3.4.2.57 | Chat path: N26 (option reads without the router), N28 (guild path), N35 (per-line tables), N31 (outbox trim), benchmarked | Done in 3.4.1.52 (decision 28) |
| P5 | 3.4.2.58 | Duplicated logic into functions: N17 to N25 | Done in 3.4.1.52 (decision 28) |
| P6 | 3.4.2.59 | Core placement: L20 plus N37 to N39, measured before and after | Done in 3.4.1.52 (decision 28) |
| R | 3.4.2.60 | Release; `01_HANDOVER.md` re-summarized |

### Line 3.4.3: window tidy
Expected builds, if nothing is added before them (decision 24).

| Stage | Build | Change |
| --- | --- | --- |
| W1 | 3.4.3.61 | G11 to G14, G24, G25, G29 | Done in 3.4.1.52 (decision 28) |
| W2 | 3.4.3.62 | Logic to Libraries: G1 to G10 | Done in 3.4.1.52 (decision 28) |
| W3 | 3.4.3.63 | Kit functions in all three looks, plus the kit preview: G15 to G20 | Done in 3.4.1.52 (decision 28) |
| W4 | 3.4.3.64 | Redraw cost: G22, G23, measured on the 3.4.0.28 save | Done in 3.4.1.52 (decision 28) |
| R | 3.4.3.65 | Release; `01_HANDOVER.md` re-summarized |

## 5. Decisions (Dan, 2026-10-08; all as recommended)
1. Three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy.
2. No ID generator for players and guilds; keep the `name-realm` key and make records sparse.
3. Custom filters get a never-reused integer id.
4. One upgrade step for the whole data change, with one validation (D9 OK given). It is step 10: B1 takes step 8 (2026-10-08) and S2b step 9 (decision 27).
5. The Camelot name repair runs on Camelot saves only; first-name-only entries are listed once in chat.
6. The shipped lists are rebuilt: 196 entries dropped, 16 converted.
7. Report lines only for features that changed, plus the cleanup line always.
8. Today's data-move messages are kept, and the report prints after them.
9. Everything prints at once at login.
10. A downgrade prints one line and keeps the newer record. **Dan's addition:** check every saved field and rule against the code that uses it, tell the player which rules are incompatible, offer to export them, and make the layout as forward compatible as possible so the saves are not readdressed again (2.3).
11. Expiry is applied at login and when a list opens (a bug fix).
12. The name cause is confirmed in game with `/dump` before N1.
13. ~~Names show the realm as the game spells it (`GetNormalizedRealmName`, `ClassicBetaPvP`), in N2.~~ **Reversed (Dan, 2026-10-08): do not change realm names.**
14. Dan's own character has a surname: N2 fixes `M.PSS_CharKey` (Dan, 2026-10-08). Nothing is keyed by it (it only fills the export's `by` field), so no settings moved (2.1).
15. "Also put listed players on Blizzard's ignore list" becomes a per-player tick (PSS is authoritative; never ignore through Blizzard unless the player asks). The global setting's value moves to the ticks in upgrade step 8 (Dan's OK for the save change, 2026-10-08).
16. A new Blizzard ignore moves into PSS: listed, taken off Blizzard's list once confirmed, note "Synced from Blizzard ignore list on <date>". For everyone (02 section 12 override).
17. People already on Blizzard's list are synced into PSS (ticked, noted) and left on Blizzard's list.
18. Someone PSS already lists still comes off Blizzard's list and keeps their note (the recommended option).
19. Removing from either list removes from both.
20. Blizzard's ignore chat lines are left alone.
21. The tick lives in the PSS window only. The right-click menu becomes a "PSS" header with "Block Player" and "Block Guild" (B2, its own stage).
22. B1 and B2 are their own stages after N2 (builds 3.4.1.35 and .36, after this plan change took 3.4.1.34); the later stages move up three builds and the release is 3.4.1.46. *(Superseded: decision 28 put the rest of the project into 3.4.1.52; the release is 3.4.1.53 and the 3.4.2 and 3.4.3 lines were not used.)*
23. The detail pane collision is its own fix build, stage Fix (3.4.1.39 was taken by the code map docs build, so Fix is 3.4.1.40; 3.4.1.38 was the harness notes docs build), after N3 merges; the wrapped line keeps its text and pushes the lines below it down (Dan, 2026-10-08; he chose this over shortening the text). The later stages moved up one build for each docs build (3.4.1.38, then the code map 3.4.1.39) and the release is 3.4.1.49. 3.4.1.40 did not take in game; its follow-up is Fix 2 (3.4.1.41, Dan's screenshot, 2026-10-08), the later stages moved up one more build and the release is 3.4.1.50.
24. **Every planned build has its expected number, and an added build moves them all (Dan, 2026-10-09).** The docs build 3.4.1.43 marks F1 merged; F2 to S3 are 3.4.1.44 to 3.4.1.50 and the 3.4.1 release is 3.4.1.51. The 3.4.2 stages are 3.4.2.52 to 3.4.2.57 with its release 3.4.2.58, and the 3.4.3 stages 3.4.3.59 to 3.4.3.62 with its release 3.4.3.63. Any build added before a stage (a docs build or a fix) moves every later build up one, and the PR that takes it updates every reference (02 section 8). *(Superseded: decision 28 put the rest of the project into 3.4.1.52; the release is 3.4.1.53 and the 3.4.2 and 3.4.3 lines were not used.)*
25. **U3's fix is 3.4.1.48 (2026-10-09).** In-game checks 3 and 6 of 3.4.1.47 failed (one missing local in the GUI folder); the fix takes the next build in the same PR (#138), so S1 to S3 are 3.4.1.49 to 3.4.1.51 and the 3.4.1 release is 3.4.1.52; 3.4.2 runs 3.4.2.53 to 3.4.2.59 and 3.4.3 runs 3.4.3.60 to 3.4.3.64 (decision 24's rule). *(Superseded: decision 28 put the rest of the project into 3.4.1.52; the release is 3.4.1.53 and the 3.4.2 and 3.4.3 lines were not used.)*

27. **S2b is one record per entry (Dan, 2026-10-09).** The seven parallel list arrays become one array of sparse records in S2b (3.4.1.51), with upgrade step 9; S3's step becomes 10. The player W I G P C accessors and the log group's `m` move into S3 (no build changes). Dan chose layout A (the details attached to each listed person), asked for all the arrays in one stage, and accepted that an older version does not show a migrated list.

26. **S2 is split (Dan, 2026-10-09).** S2 (3.4.1.50) covers what saves the memory: the guild member fields, the counts' `total` and `memberCount`, with the rules-check grep. A new stage S2b (3.4.1.51) takes the player W I G P C flags, the player list arrays and the log group's `m`; the list arrays get a layout decision first, as an array with holes breaks `table.remove`. Dan's saves hold no listed players, so S2b saves them nothing. Every later build moves up one (decision 24's rule): S3 is 3.4.1.52 and the 3.4.1 release 3.4.1.53; 3.4.2 runs 3.4.2.54 to 3.4.2.60 and 3.4.3 runs 3.4.3.61 to 3.4.3.65. Dan also said yes to keeping `_managed` saved in S2: S2 adds its accessor, and S3 drops it. *(Superseded: decision 28 put the rest of the project into 3.4.1.52; the release is 3.4.1.53 and the 3.4.2 and 3.4.3 lines were not used.)*

## 6. Risks
| Risk | Cover |
| --- | --- |
| Counters drift | Every data stage checks the counters before and after on four saves and undoes the step on any difference |
| A reader misses a dropped field | Accessors, a rules-check grep, every tab's check in all three looks |
| The Camelot repair touches a Retail save | It runs only on a Camelot realm and client, and only for unit-discovered records |
| An older version strips newer data | Only `RETIRED` keys are deleted; unknown fields are kept (2.3) |
| Imports between versions | The export format version; every field filled; import keeps unknown fields |

28. **The rest of the core uplift ships as one build (Dan, 2026-10-09).** S3, P1 to P6 and W1 to W4 were built in parallel by separate threads and merged into one PR as one squashed build, **3.4.1.52**, instead of one PR per stage (an override of the one-step-per-PR and one-step-per-session rules for this delivery only; 02 section 12). No release stage ran: the 3.4.1 release stays Dan's call and takes the next build (3.4.1.53); the 3.4.2 and 3.4.3 lines are not used, because their stages are inside 3.4.1.52. Per-stage notes, numbers and the open points are in `reference/combined-3.4.1.52/`. Merge findings: P1 had removed exports and a local that S3 and P5 still used (`PSS_FindGuildRecord`, `PSS_CompactAllMembers`, `PSS_PlayerBlocksAnything`, `parseTimeString`); the full validation found each and all are restored. P3 is a small behaviour change (inactive shipped guild rules no longer see units or hand-typed /who results while nothing is listed and no shipped list is on).
29. **CI and the release gate (Dan, 2026-10-09, "all 5"; in 3.4.1.52, no addon change):** a skipped check fails `validate_all.sh`; the every-save comparison with another build is opt-in (`PSS_SPARSE_AS`); `release.yml` runs the rules check and the full harness before it publishes; CI gets an informational `window-compare` job and a `real-saves` job that runs when a `SCRATCH_TOKEN` secret exists. The token is issue #144.
