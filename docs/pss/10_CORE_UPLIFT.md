# Closed project: core uplift (3.4.1, released as 3.4.1.53)

**Closed and released.** Every stage shipped in the full release 3.4.1.53 (2026-10-09). How the addon works now is in `01_HANDOVER.md`; what is still open is in `13_CHANGES_IN_TRAIN.md` and 06. This file is the record of the design, decisions 1 to 29 and what each stage did; read it for anything that touches names, the saved data layout, the upgrade steps or forward compatibility.

Design and findings: scratch `docs/latest/core-uplift/` (this file is `00_CORE_UPLIFT.md` there; appendices `01_CORE_LIBRARIES.md` (N1 to N48), `02_GUI.md` (G1 to G30), `03_SAVEDVARIABLES.md`, `04_UPGRADE_HELPER.md`, `05_NAME_BUGS.md`). It replaced the 3.4.1 part of the first review (`docs/latest/code-review/`), whose L12, L14 to L17 and L20 are folded in below. The findings were reviewed at main 3.4.1.30 (`d2ab159`) on Dan's saves 3.4.0.28 (Camelot), 3.2.0-dev011, 3.0.0, 2.0.44. Per-stage notes for the combined build 3.4.1.52 (S3, P1 to P6, W1 to W4): `reference/combined-3.4.1.52/`.

## 1. Goal
Fix what players hit, halve the always-loaded saved data, make every upgrade readable and every save forward compatible, then make the core and the window cheaper and tidier, with nothing visible changing unless a stage says so.

## 2. Design and what was built

### 2.1 Names (appendix 05)
- **Cause.** On Camelot / WoW Forever the unit APIs return the surname where the realm should be. Names built from a unit became `First-Last`, while chat and /who give `First Last-ClassicBetaPvP`.
- **Confirmed in game (decision 12; Dan, Camelot, 2026-10-08)** on "Bynathalador Darkwind": `UnitName` and `UnitFullName` give `"Bynathalador", "Darkwind"`; `GetUnitName("target", true)` gives `"Bynathalador Darkwind"`; `UnitRealmRelationship` gives `1`; `GetPlayerInfoByGUID` gives name `"Bynathalador Darkwind"`, realm `""`; `GetNormalizedRealmName()` gives `"ClassicBetaPvP"`. **The rule: a unit API's second value is a surname when `UnitRealmRelationship(unit)` is 1 (`LE_REALM_RELATION_SAME`)**; the name is then `First Last-<own realm>`. A string such as `"First-Last"` carries no unit and is left as it is (step 10 repairs stored ones).
- **N1: `M.PSS_NormName(name, realm, unit)`** (core `PSS_ChatBlock.lua`; returns display, key, canon): checks for a secret value first, applies the surname rule, one realm spelling. `NormalizePlayer`, `CanonPlayer`, `DisplayPlayer`, `M.PSS_UnitFullName` and every name builder call it.
- **N2, every caller:**
  - `scanUnit` and the unit menu build names through `M.PSS_UnitFullName` / `M.PSS_NormName` with the unit.
  - `/pss add` on a target passes the whole name (`exactName`).
  - Blizzard's Ignore hooks fix a `"First-Last"` they are handed when a unit (target, mouseover, focus, group) has that name and surname (`M.PSS_FixUnitName`); a removal also looks up the old form.
  - Your own name (`M.PSS_PlayerDisplayName`) is used in the self checks.
  - `M.PSS_SplitNameArg`: two words are the name off Retail, or when "First Last" is listed; quotes still work.
  - Import normalises the member key and merges a shipped member into its shipped record (`M.PSS_MergeIntoShipped`).
  - `PSS_FlushManaged` no longer writes `_canon`, `_gkey`, `_virtual`.
  - `M.PSS_CharKey` is built through `M.PSS_NormName(name, realm, "player")` (decision 14). Nothing in a save is keyed by it (it fills the export's `by` field only).
  - Realm names are not changed (decision 13, reversed).
  - The roster warning already used `GetUnitName(unit, true)`; unchanged.
- **N3, the shipped lists:** `tools/PSS_BuildManaged.lua` has `REALMS` per group key (`olympus` = `ClassicBetaPvP`, `ClassicBetaPvP2`, the first being where a unit-found name belongs). `fixSurnames`, run by `write` on both paths (OlympusDB and `--reindex`), reads any other "realm" as a surname: `First-Last` is dropped when `First Last` is listed on one of the realms, otherwise it becomes `First Last-ClassicBetaPvP`; a `-- Fixed <date>` header note is kept by `--reindex`; a second reindex changes nothing. Rebuilt (decision 6): 212 names, 196 dropped, 16 converted; 7634 to 7438 entries; realms 210 to 2. Data file 349138 to 334806 bytes (`luac -s` 339094 to 318603), 459.8 to 386.3 KB resident while the lists are loaded. Harness: `check_packed.lua`, `check_communities.lua` (OLYMPUS 197 members), the split check in `validate_all.sh` (`membersShown` 196 lower, plus one per stored member under a dropped name, `surname_stored.lua`).

### 2.2 SavedVariables (appendix 03)
- **Identity stays the lowercase `name-realm` key.** No ID generator for players or guilds (decision 2): IDs measured 11% smaller on disk and larger in memory; player GUIDs are not available from /who or the shipped lists, are secret under chat lockdown, and are long.
- **Custom filters have a never-reused integer id** (decision 3): `nextFilterId` is stored once and only goes up. History and recent counts key on `f:<id>` (N43), so editing a filter keeps its history and Copy starts a new one. Built-in filters keep `PSS00NN`.
- **Sparse records:** derivable data is not saved. Member records drop `_playerKey`, `_canon`, `_gkey`, `_managed`, `_virtual`; `guild` is saved only when it differs from the rule, `name` only when the key's display form differs, no `whenBlocked` on managed records. Counts drop zero fields and save `total` only when it differs from the sum. Player records save W I G P C only when false. Lists drop empty notes, types and `syncInfo`. Log groups drop `m` when derivable. Every read of a dropped field goes through an accessor, and `check_fields.lua` keeps raw reads out.
- **S1, purge by owner:** `History.ClearOwner(o, mayHave)` (core `PSS_ChatHistory.lua`) replaces the six owner clears (N16): `M.PSS_ForgetPlayer`, `M.PSS_ResetPlayerBlockHistory`, `M.RemoveChatFilter`, `M.PSS_ResetFilterHistory`, `M.PSS_RemoveGuildMember`, `M.PSS_ResetMemberBlockHistory`. Logging loaded: one log walk, `keep[o] = nil`. Not loaded: the owner's outbox lines go at once and, unless `mayHave` is false, `PourSocialScoreDB.purge[o] = true` (`History.PURGE_CAP` 200; full: Logging loads and clears now). `History.ApplyPurge()` runs in `M.PSS_LoadLogging` after `UnpackSaved` and `KeepToLog` and before the outbox joins the log, so a person removed and listed again keeps only their new lines; a newer version's log is left as it is. `purge` is in the schema; no layout OK was needed (Dan, 2026-10-09). Removal never loads Logging. Measured (3.4.0.28 save, keep at its 2000 cap): 3.43 ms and 1378.5 KB garbage to 36 us and none per owner. The guild reset keeps `History.Clear(matcher)`; Import Replace's many clears (N27) were not part of S1. Harness `check_purge.lua`.
- **S2, the accessors** (decision 26; core `PSS_GuildIgnoreList.lua`, one block between `-- (member fields)` and `-- (/member fields)`): `M.PSS_MemberCanon(m, k)`, `M.PSS_MemberPlayerKey(m)`, `M.PSS_MemberName(m, k)`, `M.PSS_MemberGuildName(m, g)`, `M.PSS_MemberWhenBlocked(m)` ("Managed list" for a shipped record), `M.PSS_MemberShipped(m)`, `M.PSS_StoreMemberCount(g, n)`; the shipped record's runtime fields and the `memberCount` writes live only inside the block. `History.CountTotal(c)` reads a total as the larger of `total` and the categories added up. A rule's member count comes from `M.PSS_GuildMemberCount`, never the saved `memberCount`. `tools/check_fields.lua` (rules check) fails those fields outside the block (strings and comments do not count). Export fills `name`, `guild`, `whenBlocked` through the accessors. Harness `check_accessors.lua`. Measured: +5.3 KB resident after login; an accessor read about 0.06 us more than the field.
- **S2b, the player list as records** (decision 27): `PourSocialScoreDB.list` is one array of sparse records, `{ name, date, [kind] [faction] [note] [exp] [sync] }`, in the old order and addressed by the same index. `ignoreList`, `typeList`, `factionList`, `dateList`, `notes`, `expList` and `syncInfo` are retired. `delList` and `playerData` stay (entries are not stored in `playerData`: it is walked as "players with prefs", and NPC, server and same-name entries have no place there). Accessors (core `PSS_PlayerIgnoreList.lua`, between `-- (list entries)` and `-- (/list entries)`): `M.PSS_List`, `M.PSS_EntryName`, `M.PSS_EntryKind`, `M.PSS_NewEntry`, `M.PSS_SetEntryNote`, `M.PSS_SetEntryExp`, `M.PSS_SetEntryDate`, `M.PSS_SetEntryFaction`, `M.PSS_EntrySync`, `M.PSS_EntryAddSync`; removal is one `table.remove(list, i)`; defaults read inline. **Upgrade step 9** (feature `players`) zips the arrays into `list`, keeps the first of a legacy duplicate (same lower-case name and kind), runs after step 1's fields and before every data part, keeps unknown fields. Measured (5000 entries): 1486.9 KB as arrays, 1557.4 KB as records (+4.7%); no entry can drift. **Downgrade:** 3.4.1.50 and older show an empty list over a migrated save (the records stay). Harness `check_listrecords.lua`; `same_saves.sh` normalises the two layouts (`same_norm.lua`).
- **S3, upgrade step 10, "SavedVariables performance cleanup"** (decision 4; Dan's OK, D9; step 8 is B1's, 2.7; step 9 is S2b's): five parts, each safe to run twice:
  - sparse records (above), the runtime fields dropped, the player W I G P C and the log group's `m`;
  - the 1500 member cap per rule, and `memberCount` no longer saved (L12, L16);
  - the Camelot name repair (decision 5), on Camelot saves only and only for records with `faction` and no `_playerKey`: about 184 records merged into the shipped records, 48 into their stored twins, about 267 re-keyed to `first last-realm`; player-list keys and `p:` / `g:` log owners converted the same way; first-name-only entries cannot be repaired and are listed once in chat;
  - `showIgnoreDebug` no longer saved (N8; in `RETIRED`);
  - custom filter ids assigned, their history and recent keys moved to them.

  Accessors find a sparse record's key through a weak map filled on first need, never by the member index. Result on the 3.4.0.28 save: `PSS_GuildsDB` 460,922 to 227,885 bytes. Details, numbers and open points: `reference/combined-3.4.1.52/_combined_notes_core.md`; open leftovers are issues #145 and #146.

### 2.3 Forward compatibility (decision 10, Dan's addition; U3)
**The goal: this layout is the last time the saves are readdressed.** A save written by a newer version works in an older one, and the reverse, without loss:
1. **One schema map, `M.PSS_SCHEMA`** (core `PourSocialScore/PSS_Schema.lua`, data only): one string per record kind (`core`, `upgrade`, `player`, `guild`, `member`, `block`, `counts`, `filterStat`, `builtinStat`, `line`, `logGroup`, and `<kind>Old` for fields older versions saved that this one reads once to convert). Each field is `name`, `name=default` or `name@reader`. The top-level keys are LAYOUT plus `M.PSS_OPTIONS` plus `core`. `M.PSS_SchemaKnows(kind, field)` builds a kind's set on first use. `tools/check_schema.lua` fails a top-level key the code writes that the map does not list (rules check), and with `--saves` a field of any saved record it does not list (harness, every real save). **Any change that saves a new field adds it to the map in the same PR.**
2. **Tolerant readers.** A missing field reads as its default; an unknown field is kept. The history tidy judges only owner forms and tags this version makes; `History.FilterKey` takes a number id; `M.PSS_ExpandFilters` / `M.PSS_CollapseFilters` keep a number id and a built-in rule this version lacks; a filter's counts keep unknown fields; a block log or recent-counts table with `v` above 2 is kept as it is. A new per-filter field goes in `filterID` or a table keyed by id, never a new parallel array; a new log or recent layout takes `v = 3`.
3. **Nothing is deleted by guesswork.** Only keys in the one `RETIRED` list are removed.
4. **Step numbers only grow, and each step is safe to run twice.** `upgrade.version` keeps the highest version that wrote the save (no new saved key).
5. **A downgrade** prints one line, keeps the newer record and runs no step backwards.
6. **Rules this version cannot use are reported, kept and exportable** (`M.PSS_UnusableRules()`): a custom filter `M.PSS_CompileFilter` rejects; a guild rule whose `managed` list this version does not ship or with a field the map does not name (`M.PSS_GuildRuleUnusable`); a key in `PSS_OptionsDB` that is neither routed nor `RETIRED`. Never applied (guild rules are skipped in the guild source's `decide` and in `guildRuleActive`), never changed. After a version change, in either direction, the report names them ("N custom rule(s) this version cannot use (kept, not applied): /pss export unused"; the same for guild rules; "N setting(s) this version does not know (kept)"). **`/pss export unused`** (Libraries `PSS_Commands.lua`, `M.PSS_UnusedExportText`) shows them in the copy box, the window staying closed. A rule is usable again the moment a version that knows it loads.
7. **Exports carry a format version** (format 2: `v = 2` in the payload, the `PSS1` tag kept). A player's prefs, a guild rule and a member carry `more`, their fields this version does not know; import puts `more` back only where the field is unknown and empty. 3.4.0.29 imports a format 2 string.
8. Releases up to 3.4.1.30 cannot run this.

Harness: `check_forward.lua` (planted newer and older records survive, report and downgrade lines, export, a v3 log), `check_keep.lua`. Measured: +10.5 KB resident after login (the map 3.2 KB of it); `M.PSS_UnusableRules` 0.42 ms, only on a version-change login.

**Lesson (U3 fix):** `PSS_Popups.lua` defined `M.PSS_CopyTextBox` without a `local M`, so the GUI folder failed to load in game while the harness passed, because `run.lua` set a global `M`. `run.lua` now gives `M` to the script's own environment only, and `tools/check_locals.lua` (rules check) fails any addon file that uses `M` without a local.

### 2.4 Upgrade report (appendix 04; issue #45)
- **U1, a step registry in `PSS_Upgrade.lua`:** `STEPS` rows are `{ id, always, parts }`; each part is `{ feature, fields, data }` (`M.PSS_UPGRADE_REGISTRY`, `M.PSS_UPGRADE_FEATURES`). Parts take no arguments and count through `tally(feature, key, n)`. Step 1 is six feature-tagged parts in 2.0's order. `RETIRED` (`M.PSS_UPGRADE_RETIRED`) is dropped in one loop at every login after the data parts, counted as `cleanup.retired`. `M.PSS_RunUpgradeFields(fresh, defaults)` decides whether the login reports (not fresh, and a step due or `upgrade.version` differs); only then is `out` built. `M.PSS_RunUpgradeData(fresh)` returns it (`from`, `to`, `done`, `step`, `paused`, a table per feature). `M.PSS_VersionOrder(a, b)`: -1, 0, 1, or nil; X.Y.Z.B by its numbers; any older name is older than an X.Y.Z.B; `X.Y.Z-devN` is older than `X.Y.Z`.
- **U2, the report.** At the first login after any version change one batch prints at once (decisions 7 to 9): a header (`L["UPG_HEAD"]`), a line for each feature that changed (Chat Filtering, Player Ignore List, Guild Ignore List, Managed Communities, Block History, Options), **always** "SavedVariables performance cleanup" (`L["UPG_NOTHING"]` "nothing to tidy" when empty; no save size, the game cannot read it), then "Saved data upgraded to X (step N)." (`L["UPG_DONE"]`), or the red `L["UPG_PAUSED"]` when a step paused. Phrases: `PHRASES` (`M.PSS_UPGRADE_PHRASES`) lists each feature's count keys in print order; text is `L["UPG_<feature>_<key>"]` with `(s)` plurals and `fmtNum`; a key with no phrase does not print, and the harness fails one. A downgrade prints `L["UPG_NEWER"]` once per login on the older version. Data-move messages print before the report (decision 8). A normal login builds no strings. All through `M.ShowMsg`, in ASCII.

  Example (numbers illustrative):
  ```
  Pour Social Score: Updated from 3.4.0.29 to 3.4.1.53. Upgrading your saved data:
  Pour Social Score:   Chat Filtering: 3 rule(s) given an ID.
  Pour Social Score:   Guild Ignore List: 267 Camelot name(s) repaired.
  Pour Social Score:   SavedVariables performance cleanup: 6 retired key(s) removed, 1,208 saved record(s) made smaller.
  Pour Social Score: Saved data upgraded to 3.4.1.53 (step 10).
  ```
- Harness: `check_upgrade_steps.lua`, `check_upgrade_report.lua` (10 cases: registry shape, an upgrade from 2.0.44, silence on the same version, a fresh save, a version-only bump, planted retired keys, a downgrade, a paused step, the real saves, a memory bound when nothing upgrades); `same_saves.sh` (`PSS_SAME_AS=origin/main`) drops the report lines from the chat it compares. Measured: U1 +9.6 KB, U2 +7.1 KB resident after login; a login with no report 0.2 KB.

### 2.5 Fixes (appendices 01 and 02)
- **F1:**
  - N40, expiry (decision 11, a bug fix, no opt-in): `M.PSS_ExpireEntries(quiet, daily)` (core `PSS_PlayerIgnoreList.lua`) runs at login after `M.PSS_RunUpgradeData`, on `PLAYER_REGEN_ENABLED` at most once a day (no timer), when a list opens (`M.PSS_OpenUI`, the Friends dock), in `/pss list` and `/pss sync`; one chat line names what it removed.
  - N41: the four hook bodies return early when `useUnitHacks` / `useLFGHacks` is off (J3), so the option applies without a /reload; hooks install at login or on first enable.
  - N42: `[talent]` / `[talent=N]` in `KNOWN_TAGS` and `TAG`; `analyse` collects `F.talentID`.
  - N45: `M.PSS_ClearGuildRules()` in Import Replace keeps the shipped rules.
  - N46: `M.PSS_NoteListenerError(where, err)` (core `PSS_Events.lua`; `M.Events.errors`) reports listener errors once per name, counted in `/pssguild status`.
  - N47: `V.groupWarning` is rebuilt from the roster on each check.
  - N48: `/pss list` reads the note safely.
  - Harness `check_fixes.lua`. In-game checks 4 and 7 wait on issues #132 and #133.
- **F2:**
  - G21: core no longer fires `FILTERS_CHANGED` after a block; the Filters tab redraws through its 4-a-second throttle (32.5 to 16.9 KB garbage per block with the tab open).
  - G26: the Guilds tab's rule dim follows `FILTERS_CHANGED`.
  - G27: Dark right-click menus grow to their content, capped at 400 px (a drop-down's list 200; `PSS_Menu.lua` `SIZES`), width measured over every entry (Dan, 2026-10-09; Blizzard's menu scrolls at the same height).
  - G28: `MODERN_ART` in `PSS_Skin.lua` lists all 19 atlases Modern draws.
- **Fix and Fix 2, the detail pane wrap (decision 23):** on the Guilds tab (`BuildGroupBody`, `PSS_Guilds.lua`), a wrapped line ("Rule on the Chat Filters tab: ...") ran into the next. Each line now anchors under the one above it, and the pies start below the last line; the text is kept. **Lesson:** a FontString anchored on both sides (TOPLEFT plus RIGHT) stays one line tall in game when it wraps; give it a set width (`DETAIL_W - 20`) and set its height from `GetStringHeight` after `SetText` and on repaint (`FitLines`). The harness stub does not wrap, so only the in-game check shows this. Check every fixed-height `Line()` stack in `PSS_Guilds.lua` and `PSS_Players.lua` the same way, in all three looks and with a large `uiFont`.

### 2.6 Performance and tidy (P1 to P6, W1 to W4)
Each stage is invisible and proven with `tui_compare.sh` identical in all three looks, plus measured numbers. All shipped in the combined build 3.4.1.52 (decision 28); what each did is in section 4, the notes in `reference/combined-3.4.1.52/`.

### 2.7 Blizzard's ignore list and the right-click menu (B1, B2; decisions 15 to 21)
**PSS is authoritative.** PSS never puts anyone on Blizzard's ignore list unless the player asked for it for that person.
- **Per-player Blizzard ignore** (decision 15): the global option `blizzardSync` became a tick per listed player, "Also on Blizzard's ignore list", off by default, in the View/Edit Rule page of the PSS window only (decision 21). `M.PSS_SetBlizzardIgnore(name, on)` (core `PSS_PlayerIgnoreList.lua`) sets `p.blizzardIgnore` (true only) and adds or removes the Blizzard ignore through the hook guard; refused with a chat line when Blizzard's list holds 50.
- **A new Blizzard ignore moves into PSS** (decisions 16, 18): Blizzard's Ignore or `/ignore` lists the player with the note `Synced from Blizzard ignore list on <date>` (`%d %b %Y`) and queues a move (`pendingMove`); the next `IGNORELIST_UPDATE` that shows them takes them off Blizzard's list unless ticked (30 s, then dropped). Someone already listed comes off too and keeps their note. For everyone: an approved override of C2 (02 section 12).
- **The existing Blizzard list is synced across, not managed** (decision 17): the first `IGNORELIST_UPDATE` after login lists everyone PSS does not, with the note and the tick on; nobody is taken off. `/pss sync` and the first-time import use the same note and tick.
- **Removing from either removes from both** (decision 19).
- **Blizzard's chat lines** ("is now being ignored", "is no longer being ignored", "already ignored") are left alone (decision 20).
- **Upgrade step 8:** a save with `blizzardSync` on ticks the listed players on Blizzard's list, sets `V.PSS_TickOnSync` (the first list update ticks again) and retires the key. `blizzardSync` stays in `PSS_SavedData.lua`'s `LAYOUT.options` so the step can read it.
- **B2, the right-click menu** (decision 21): `M.PSS_UnitMenuPlayer` (core `PSS_BlizzardUI.lua`) builds a divider, a "PSS" title (`L["RCM_16"]`), "Block Player" / "Unblock Player" (`RCM_17`, `RCM_18`), and "Block Guild" / "Unblock Guild" (`RCM_19`, `RCM_20`) only for a real unit whose `GetGuildInfo(unit)` is readable, non-empty and not your own guild (`M.PSS_IsOwnGuild`); a chat-name click has no unit and gets the player entry only. Block Guild calls `M.PSS_AddGuild`, Unblock Guild `M.PSS_RemoveGuildNow`. The LFG applicant menu keeps its single entry.
- J rules: `C_FriendList.AddIgnore` / `DelIgnore` only from a user action or `IGNORELIST_UPDATE`, with the hook guard; menus by post-hook `Menu.ModifyMenu` only (J2, J3); the guild checked with `M.PSS_IsSecret` before any compare (J7). Harness `check_blizzard.lua` (the stub keeps a Blizzard list: `PSS_BLIZZ_IGNORES`, `PSS_BLIZZ_LATE`), `check_unitmenu.lua`.

## 3. Constraints
- Baseline 02 and PSS 02 in full.
- J rules on every name and hook path: `M.PSS_IsSecret` before any compare, plus a restriction-CVar run (02 10.6).
- No timers as logic gates (C3).
- Zero cost when nothing upgrades.
- Counters never derived from log lines, and identical before and after every data step.
- Logging loads only when called.
- No new SavedVariables. The `purge` tombstone and `nextFilterId` live in existing tables.

## 4. Stages (all released in 3.4.1.53)
| Stage | Build | What it did | PR |
| --- | --- | --- | --- |
| Plan | 3.4.1.31 | This plan; the working rules (one stage per session, context in every PR, state re-summarized at release, preferences in one file); baseline v9 | #119 |
| N1 | 3.4.1.32 | `M.PSS_NormName`; the name helpers call it; `check_names.lua` (2.1) | #120 |
| N2 | 3.4.1.33 | Every name caller, multi-word `/pss add/remove/expire`, import with the managed check, runtime fields not flushed, `M.PSS_CharKey` (2.1) | #121 |
| Plan B | 3.4.1.34 | B1 and B2 added to the plan (docs) | #122 |
| B1 | 3.4.1.35 | PSS authoritative over Blizzard's ignore list; upgrade step 8 (2.7) | #123 |
| B2 | 3.4.1.36 | The "PSS" right-click menu with Block Player and Block Guild (2.7) | #124 |
| N3 | 3.4.1.37 | Builder fix; shipped lists rebuilt (2.1) | #126 |
| Docs | 3.4.1.38, .39 | Harness notes after a list rebuild; the code map and changes in train (docs) | #127, #128 |
| Fix, Fix 2 | 3.4.1.40, .41 | The Guilds detail pane wrap (2.5) | #129, #130 |
| F1 | 3.4.1.42 | N40, N41, N42, N45, N46 to N48 (2.5) | #131 |
| Docs | 3.4.1.43 | Expected builds (docs) | #134 |
| F2 | 3.4.1.44 | G21 with G26, G27, G28 (2.5) | #135 |
| U1 | 3.4.1.45 | The upgrade registry, `RETIRED`, counts, version compare; invisible (2.4) | #136 |
| U2 | 3.4.1.46 | The upgrade report (2.4) | #137 |
| U3 | 3.4.1.47, .48 | Forward compatibility (2.3); .48 the missing `local M` fix and `check_locals.lua` | #138 |
| S1 | 3.4.1.49 | `History.ClearOwner` and the purge tombstone (2.2) | #139 |
| S2 | 3.4.1.50 | Member, counts and `memberCount` accessors; `check_fields.lua` (2.2) | #140 |
| S2b | 3.4.1.51 | The player list as one array of records; upgrade step 9 (2.2) | #141 |
| S3 | 3.4.1.52 | Upgrade step 10: sparse records, member cap, Camelot repair, filter ids (2.2) | #142 |
| P1 | 3.4.1.52 | Dead code N1 to N15: 61 localization keys, unused `M.*` exports, `V.needSorted`, the reload popup (`PSS_RELOAD`, `M.PSS_AskReload`, `def.reload`), the compat globals and `PSS_MainlineCompat.lua`, `/pss test` | #142 |
| P2 | 3.4.1.52 | Event-driven GC and `History.LoadWhenQuiet` without timers (L14; closed the last known breach, 02 section 4) | #142 |
| P3 | 3.4.1.52 | Capture events only when needed (L15); inactive shipped lists no longer capture units or /who: issue #148 | #142 |
| P4 | 3.4.1.52 | Chat path, benchmarked: N26 (option reads without the router), N28 (guild path), N35 (per-line tables), N31 (outbox trim) | #142 |
| P5 | 3.4.1.52 | Duplicated logic into functions, N17 to N25 (N23 and N25 skipped on purpose) | #142 |
| P6 | 3.4.1.52 | Core placement (L20, N37 to N39): player rows, the save check and the scan planner moved to Libraries, -63 KB resident at login | #142 |
| W1 | 3.4.1.52 | G11 to G14, G24, G25, G29 | #142 |
| W2 | 3.4.1.52 | Window logic to Libraries: G1 to G10 | #142 |
| W3 | 3.4.1.52 | Kit functions in all three looks, plus the kit preview: G15 to G20 | #142 |
| W4 | 3.4.1.52 | Redraw cost: G22, G23, measured on the 3.4.0.28 save | #142 |
| R | 3.4.1.53 | Full release: one summary of 3.4.1.30 to 3.4.1.52; `01_HANDOVER.md` re-summarized (Dan, 2026-10-09: "launch a release") | #143 |

The 3.4.2 and 3.4.3 lines planned for P1 to P6 and W1 to W4 were not used (decision 28).

## 5. Decisions (Dan, 2026-10-08 unless dated; all as recommended unless said)
1. Three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy. *(Superseded by 28: all shipped on 3.4.1.)*
2. No ID generator for players and guilds; keep the `name-realm` key and make records sparse.
3. Custom filters get a never-reused integer id.
4. One upgrade step for the whole data change, with one validation (D9 OK given). It is step 10: B1 took step 8 and S2b step 9 (decision 27).
5. The Camelot name repair runs on Camelot saves only; first-name-only entries are listed once in chat.
6. The shipped lists are rebuilt: 196 entries dropped, 16 converted.
7. Report lines only for features that changed, plus the cleanup line always.
8. The data-move messages are kept, and the report prints after them.
9. Everything prints at once at login.
10. A downgrade prints one line and keeps the newer record. **Dan's addition:** check every saved field and rule against the code that uses it, tell the player which rules are incompatible, offer to export them, and make the layout as forward compatible as possible so the saves are not readdressed again (2.3).
11. Expiry is applied at login and when a list opens (a bug fix).
12. The name cause is confirmed in game with `/dump` before N1.
13. ~~Names show the realm as the game spells it.~~ **Reversed (Dan, 2026-10-08): do not change realm names.**
14. Dan's own character has a surname: N2 fixes `M.PSS_CharKey`. Nothing is keyed by it, so no settings moved.
15. "Also put listed players on Blizzard's ignore list" becomes a per-player tick (never ignore through Blizzard unless the player asks). The global setting moves to the ticks in upgrade step 8 (Dan's OK for the save change).
16. A new Blizzard ignore moves into PSS: listed, taken off Blizzard's list once confirmed, with the note. For everyone (02 section 12 override).
17. People already on Blizzard's list are synced into PSS (ticked, noted) and left on Blizzard's list.
18. Someone PSS already lists still comes off Blizzard's list and keeps their note.
19. Removing from either list removes from both.
20. Blizzard's ignore chat lines are left alone.
21. The tick lives in the PSS window only. The right-click menu becomes a "PSS" header with "Block Player" and "Block Guild" (B2, its own stage). Unblock labels when listed (the recommended option; Dan did not pick).
22. B1 and B2 are their own stages after N2. *(Its build numbering is superseded by 28.)*
23. The detail pane collision is its own fix build; the wrapped line keeps its text and pushes the lines below it down (Dan chose this over shortening the text). 3.4.1.40 did not take in game; Fix 2 (3.4.1.41) did.
24. **Every planned build has its expected number, and an added build moves every later one (Dan, 2026-10-09).** The PR that takes the build updates every reference (02 section 8). *(The rule stands; this plan's numbers are superseded by 28.)*
25. U3's fix takes the next build (3.4.1.48) in the same PR (#138) (2026-10-09).
26. **S2 is split (Dan, 2026-10-09).** S2 covers the guild member fields, the counts' `total` and `memberCount`, with the rules-check grep; S2b takes the player list (a layout decision first, as an array with holes breaks `table.remove`). `_managed` stays saved in S2 (accessor only) and S3 drops it.
27. **S2b is one record per entry (Dan, 2026-10-09).** The seven parallel list arrays become one array of sparse records, with upgrade step 9; S3's step becomes 10; the player W I G P C accessors and the log group's `m` move into S3. Dan chose layout A (the details attached to each listed person), all arrays in one stage, and accepted that an older version does not show a migrated list.
28. **The rest of the core uplift ships as one build (Dan, 2026-10-09).** S3, P1 to P6 and W1 to W4 were built in parallel threads and merged as one squashed build, **3.4.1.52** (PR #142), an override of one step per PR and per session for this delivery only (02 section 12). The release took the next build, 3.4.1.53; the 3.4.2 and 3.4.3 lines were not used. Merge findings: P1 had removed exports and a local that S3 and P5 still used (`PSS_FindGuildRecord`, `PSS_CompactAllMembers`, `PSS_PlayerBlocksAnything`, `parseTimeString`); the full validation found each and all were restored. P3 changes behaviour for inactive shipped lists: issue #148. Notes: `reference/combined-3.4.1.52/`.
29. **CI and the release gate (Dan, 2026-10-09, "all 5"; no addon change):** a skipped check fails `validate_all.sh`; the every-save comparison with another build is opt-in (`PSS_SPARSE_AS`); `release.yml` runs the rules check and the full harness before it publishes; CI has an informational `window-compare` job and a `real-saves` job that runs when a `SCRATCH_TOKEN` secret exists (issue #144).

## 6. Risks (and how they were covered)
| Risk | Cover |
| --- | --- |
| Counters drift | Every data stage checks the counters before and after on the real saves and undoes the step on any difference |
| A reader misses a dropped field | Accessors, `check_fields.lua`, every tab's check in all three looks |
| The Camelot repair touches a Retail save | It runs only on a Camelot realm and client, and only for unit-discovered records |
| An older version strips newer data | Only `RETIRED` keys are deleted; unknown fields are kept (2.3) |
| Imports between versions | The export format version; every field filled; import keeps unknown fields |
