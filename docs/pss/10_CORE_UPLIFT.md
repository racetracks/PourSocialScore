# Current project: core uplift (3.4.1 to 3.4.3)

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
  - `PSS_FlushManaged` no longer writes `_canon`, `_gkey` and `_virtual`. **`_managed` is still written:** the member count reads it while the lists are not loaded; it goes with the accessors in S2 and step 9 in S3.
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
- **Upgrade step 9, "SavedVariables performance cleanup"** (step 8 is B1's, 2.7) (decision 4; Dan's OK given, D9): one run-once step for everything below, then one validation on all four saves with identical counters.
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

### 2.4 Upgrade report (appendix 04; issue #45)
- **A step registry in `PSS_Upgrade.lua`.** Each entry has `id`, `feature`, `always` (runs every upgrade), and `fields` / `data` functions that add their counts to an `out` table. Step 1 is split into feature-tagged parts. Retired keys are pruned in one loop over `RETIRED`.
- **At the first login after a version change, one batch prints all at once (decision 9):**
  - a header;
  - a line for each feature that changed (decision 7): Chat Filtering, Player Ignore List, Guild Ignore List, Managed Communities, Block History, Options;
  - **always** "SavedVariables performance cleanup", with its counts and the size before and after;
  - today's last line, "Saved data upgraded to X (step N).", unchanged.

  Example (numbers illustrative):
  ```
  PourSocialScore: updated from 3.4.0.29 to 3.4.1.50. Upgrading your saved data:
    Chat Filtering: 3 custom filters given an id
    Guild Ignore List: 48 duplicate members merged, 267 names repaired
    Managed Communities: 184 members already on the shipped lists dropped
    SavedVariables performance cleanup: 6 old settings removed, 1208 records tidied (397 KB to 196 KB)
  PourSocialScore: saved data upgraded to 3.4.1.50 (step 9).
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

### 2.5 Fixes (appendices 01 and 02)
- **N40, expiry (decision 11):** applied at login, on a quiet event and when a list opens, as the readme says. This is a bug fix, so it needs no opt-in.
- **N41:** each hook body is gated by its option (J3), so the option applies without a /reload.
- **N42:** talent links convert to a tag the filter language knows.
- **N45:** Import with Replace on guilds keeps the shipped rules.
- **N46 to N48:** listener errors are reported, the group warning list is fixed, and `/pss list` no longer hits a nil.
- **Done in F1 (3.4.1.42):**
  - N40: `M.PSS_ExpireEntries(quiet, daily)` (core `PSS_PlayerIgnoreList.lua`), the expiry loop out of `SyncIgnoreList`. It runs at login after `M.PSS_RunUpgradeData`, on `PLAYER_REGEN_ENABLED` (the quiet event; at most once a day, no timer), in `M.PSS_OpenUI` and the Friends dock (the list opens), in `/pss list` and in `/pss sync`. One chat line names what it removed (`M.PSS_DelIgnore(i, true, quiet)`). Dan's real saves have no ignore list entries, so nothing changes on them.
  - N41: the four hook bodies return early when `useUnitHacks` / `useLFGHacks` is off. The hooks are installed at login or on the first enable (`OPTION_CHANGED`; the Group Finder waiter re-arms). The labels lost "(Requires reload to take effect)". The reload popup (N3) stays dead; P1 deletes it.
  - N42: `[talent]` / `[talent=N]` in `KNOWN_TAGS` and `TAG`; `analyse` collects `F.talentID`.
  - N45: `M.PSS_ClearGuildRules()` (core `PSS_GuildIgnoreList.lua`) replaces `db.guildData = {}` in Import Replace. Shipped rules stay; the others go with their recent counts; `ensureManagedRules`; index dirty. `existed` uses `M.PSS_NormalizeGuild`.
  - N46: `M.PSS_NoteListenerError(where, err)` (core `PSS_Events.lua`; `M.Events.errors`) for `Events.Fire` and the /who handlers: once per name in chat, counted in `/pssguild status`.
  - N47: `V.groupWarning` is rebuilt from the roster on each check; a warning only for someone new.
  - N48: `/pss list` reads the note safely.
  - Harness: `tools/harness/check_fixes.lua` ("== fixes" in `validate_all.sh`). Measured: core +2574 bytes compiled, +6.1 KB resident after login (harness). `tui_compare.sh`: only the two labels, in all three looks.
- **G21 and G26:** the Filters tab's redraw is throttled, and the guild rows' rule dim refreshes on `FILTERS_CHANGED`.
- **G27:** Dark menus grow to their content, capped at the screen height.
- **G28:** the Modern art check covers every atlas Modern draws.
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
| F1 | 3.4.1.42 | N40, N41, N42, N45, N46 to N48 | Yes | A harness case for each; in-game checks | PR #131 |
| F2 | 3.4.1.43 | G21 with G26, G27, G28 | Yes (G27 in Dark) | `tui_compare.sh`: only the Dark menu height; garbage per filter block measured | |
| U1 | 3.4.1.44 | Upgrade registry, invisible: step 1 split and tagged, `RETIRED`, counts returned, version compare | No | Saves byte-identical on all four saves | |
| U2 | 3.4.1.45 | The upgrade report (2.4); `check_upgrade_report.lua` | Yes (once per update) | 10 cases; in game, the batch prints once and the next login prints nothing | |
| U3 | 3.4.1.46 | Forward compatibility (2.3): `M.PSS_SCHEMA` and its rules check, tolerant readers, the downgrade line, unusable rules reported and kept, `/pss export unused`, the export format version | Yes (only when a rule cannot be used) | Planted newer fields survive; a planted unknown filter tag is reported, kept and exported; a downgrade case | |
| S1 | 3.4.1.47 | `History.ClearOwner` and the purge tombstone; the six copies call it | No | Identical lines and counters; 5.6 ms to about 70 us | |
| S2 | 3.4.1.48 | Accessors for every field S3 drops; the rules-check grep | No | `tui_compare.sh` identical | |
| S3 | 3.4.1.49 | Upgrade step 9 (2.2): sparse records, cap, `memberCount`, Camelot repair, `showIgnoreDebug`, filter ids | Yes (report, smaller save) | Four saves: counters identical, sizes before and after; 3.4.0.29 run on a migrated save | |
| R | 3.4.1.50 | Release: version only; one summary of 3.4.1.30 to 3.4.1.49 from their PRs; `01_HANDOVER.md` re-summarized | | Dan confirms | |

### Line 3.4.2: core performance and tidy (builds continue)
| Stage | Change |
| --- | --- |
| P1 | Dead code N1 to N15: 61 localization strings, about 25 unused `M.*` exports, `V.needSorted`, the reload popup, the compat globals, `/pss test` |
| P2 | Event-driven GC and `loadWhenQuiet` without timers (L14; closes the known breach in 02 section 12) |
| P3 | Capture events only when needed (L15) |
| P4 | Chat path: N26 (option reads without the router), N28 (guild path), N35 (per-line tables), N31 (outbox trim), benchmarked |
| P5 | Duplicated logic into functions: N17 to N25 |
| P6 | Core placement: L20 plus N37 to N39, measured before and after |
| R | Release; `01_HANDOVER.md` re-summarized |

### Line 3.4.3: window tidy
| Stage | Change |
| --- | --- |
| W1 | G11 to G14, G24, G25, G29 |
| W2 | Logic to Libraries: G1 to G10 |
| W3 | Kit functions in all three looks, plus the kit preview: G15 to G20 |
| W4 | Redraw cost: G22, G23, measured on the 3.4.0.28 save |
| R | Release; `01_HANDOVER.md` re-summarized |

## 5. Decisions (Dan, 2026-10-08; all as recommended)
1. Three lines: 3.4.1 fixes and data, 3.4.2 core performance, 3.4.3 window tidy.
2. No ID generator for players and guilds; keep the `name-realm` key and make records sparse.
3. Custom filters get a never-reused integer id.
4. One upgrade step for the whole data change, with one validation (D9 OK given). It is step 9: B1 takes step 8 (2026-10-08).
5. The Camelot name repair runs on Camelot saves only; first-name-only entries are listed once in chat.
6. The shipped lists are rebuilt: 196 entries dropped, 16 converted.
7. Report lines only for features that changed, plus the cleanup line always.
8. Today's data-move messages are kept, and the report prints after them.
9. Everything prints at once at login.
10. A downgrade prints one line and keeps the newer record. **Dan's addition:** check every saved field and rule against the code that uses it, tell the player which rules are incompatible, offer to export them, and make the layout as forward compatible as possible so the saves are not readdressed again (2.3).
11. Expiry is applied at login and when a list opens (a bug fix).
12. The name cause is confirmed in game with `/dump` before N1.
13. ~~Names show the realm as the game spells it (`GetNormalizedRealmName`, `ClassicBetaPvP`), in N2.~~ **Reversed (Dan, 2026-10-08): do not change realm names.**
14. Dan's own character has a surname: N2 fixes `M.PSS_CharKey` and moves its per-character settings to the new key (Dan, 2026-10-08).
15. "Also put listed players on Blizzard's ignore list" becomes a per-player tick (PSS is authoritative; never ignore through Blizzard unless the player asks). The global setting's value moves to the ticks in upgrade step 8 (Dan's OK for the save change, 2026-10-08).
16. A new Blizzard ignore moves into PSS: listed, taken off Blizzard's list once confirmed, note "Synced from Blizzard ignore list on <date>". For everyone (02 section 12 override).
17. People already on Blizzard's list are synced into PSS (ticked, noted) and left on Blizzard's list.
18. Someone PSS already lists still comes off Blizzard's list and keeps their note (the recommended option).
19. Removing from either list removes from both.
20. Blizzard's ignore chat lines are left alone.
21. The tick lives in the PSS window only. The right-click menu becomes a "PSS" header with "Block Player" and "Block Guild" (B2, its own stage).
22. B1 and B2 are their own stages after N2 (builds 3.4.1.35 and .36, after this plan change took 3.4.1.34); the later stages move up three builds and the release is 3.4.1.46.
23. The detail pane collision is its own fix build, stage Fix (3.4.1.39 was taken by the code map docs build, so Fix is 3.4.1.40; 3.4.1.38 was the harness notes docs build), after N3 merges; the wrapped line keeps its text and pushes the lines below it down (Dan, 2026-10-08; he chose this over shortening the text). The later stages moved up one build for each docs build (3.4.1.38, then the code map 3.4.1.39) and the release is 3.4.1.49. 3.4.1.40 did not take in game; its follow-up is Fix 2 (3.4.1.41, Dan's screenshot, 2026-10-08), the later stages moved up one more build and the release is 3.4.1.50.

## 6. Risks
| Risk | Cover |
| --- | --- |
| Counters drift | Every data stage checks the counters before and after on four saves and undoes the step on any difference |
| A reader misses a dropped field | Accessors, a rules-check grep, every tab's check in all three looks |
| The Camelot repair touches a Retail save | It runs only on a Camelot realm and client, and only for unit-discovered records |
| An older version strips newer data | Only `RETIRED` keys are deleted; unknown fields are kept (2.3) |
| Imports between versions | The export format version; every field filled; import keeps unknown fields |
