# PourSocialScore (PSS): the addon as it works (state at release 3.4.1.53)

**The state document (baseline 02 E11, Dan, 2026-10-08):** how the addon works at the last full release. It is re-summarized at every full release from the plan's done stages (last: 3.4.1.53, from the core uplift, `10_CORE_UPLIFT.md`; next: at the next full release, from the next plan). Status is in 06; Dan's preferences are in 11.

## 1. Purpose
PourSocialScore is Dan's World of Warcraft chat moderation addon (GitHub `racetracks`, in-game author Boaties). Clients: Retail (Midnight, Interface **120007**) and Camelot (Interface **16001**).

What it does:
- **Player Ignore List.** Unlimited and account-wide (players, NPCs, whole servers), with notes, expiry (applied by itself at login, after combat once a day and when a list opens; 3.4.1.42), per-player **W I G P C** flags (whisper, invite, guild, party, chat; ticked = allowed), exceptions to the defaults for listed people (3.4.0.22), a detail pane, auto-decline of duels/trades/invites, and Player Search via /who.
- **PSS is authoritative over Blizzard's ignore list (3.4.1.35):** a per-player tick "Also on Blizzard's ignore list" (off by default) puts a listed player on Blizzard's list; a Blizzard Ignore lists the player in PSS (note "Synced from Blizzard ignore list on <date>") and takes them off Blizzard's list; the existing Blizzard list is synced across at login and left in place; removal from either removes from both.
- **Right-click menus (3.4.1.36):** a "PSS" heading with Block Player and Block Guild (Unblock when listed; no Block Guild without a unit, a guild, or for your own guild).
- **Names with a surname (Camelot):** one normaliser, `M.PSS_NormName(name, realm, unit)`; a unit API's second value is a surname when `UnitRealmRelationship(unit)` is 1, giving `First Last-<own realm>`. Every name caller uses it (3.4.1.32, .33); saved `First-Last` records are repaired once by upgrade step 10 on Camelot saves.
- **Guild Ignore List.** /who scans split until each query returns under 50, Scan All (keybind), Custom Scan, 6 s cooldown, level cap, Guild Search, Guild Exclusion List.
- **Managed community lists.** Shipped guild lists ("Managed Communities - Asmongold", 119 guilds), switched on by Chat Filters guild rules, off by default. Built with `tools/PSS_BuildManaged.lua`.
- **Chat filter engine.** Built-in filters off by default. Custom rules use a tag language compiled to closures (about 30 us per line). A chat link converter on the Chat Filters tab.
- **Block history and counts.** Counts per session, per 24 h and all time; the block log (2000 lines) plus kept lines per listed person (04). Removing an owner never loads Logging: `History.ClearOwner` drops its waiting lines and marks it in `PourSocialScoreDB.purge` (cap 200), applied when Logging loads (3.4.1.49).
- **Upgrades (3.4.1.45 to .52):** a step registry (`PSS_Upgrade.lua`, steps 1 to 10, each feature-tagged and safe to run twice); keys are deleted only from one `RETIRED` list. The first login after any version change prints the upgrade report (a line per feature that changed, "SavedVariables performance cleanup" always, then "Saved data upgraded to X (step N)."); a downgrade prints one line and keeps the newer record.
- **Forward-compatible, sparse saves (3.4.1.47 to .52):** every saved field is in `M.PSS_SCHEMA` (`PSS_Schema.lua`; `check_schema.lua`); unknown fields and newer layouts are kept; rules this version cannot use are kept, not applied, reported and exported by `/pss export unused`; exports are format 2 (`v`, unknown fields in `more`). Records save only what is not derivable (member fields through accessors, counts without zero fields, W I G P C only when false, log `m` only when needed), a guild rule keeps at most 1500 members, the player list is one array of records (`list`, routed to `PSS_PlayersDB`), and custom filters have a never-reused id (`nextFilterId`; history keyed `f:<id>`). On the 3.4.0.28 save `PSS_GuildsDB` went from 460,922 to 227,885 bytes.
- **One window** (from 3.4.0.25; 09) in three looks: Modern, Classic and Dark. Until 3.4.0.24 there were two front ends: the native window, and an EllesmereUI window when EllesmereUI was installed and the integration option on (03).

Goal: "global" moderation through shared lists. Sharing happens through shipped lists and Import/Export.

## 2. Repos
| Repo | Role |
| --- | --- |
| `racetracks/PourSocialScore` (private) | The addon: six folders (eight until 3.4.0.24), one version, `tools/` (rules checks, harness, managed list builder), readme.txt, history.txt, `.github/workflows` (release.yml, rules.yml) |
| `racetracks/Pour-Social-Score_Scratch` (private) | Hosting (layer 2 pack, `docs/scratch/`). Paths: `releases/` (test zips, versioned and dated), `latest/` (the newest test zip), `SavedVariables/<version>/` (saves), `docs/` (plans, issue notes, handover packs; newest markdown in `docs/latest/<project>/`), `summary/` (status summaries). Replaces `racetracks/scratch`, no longer used |
| `racetracks/PourSocialScore-EllesmereUI` | **Retired.** Held the EllesmereUI folder on its own 1.1 version line until 3.2.0-dev008 merged it into the addon repo. Archived by Dan (its PR #18 closed, 2026-10-08). Never write to it |

Read only: `EllesmereGaming/EllesmereUI` (all rights reserved; the reference framework for building UI elements, rewritten to our rules and never copied, 03 section 0, Dan, 2026-10-08), `Gethe/wow-ui-source`. References actually used on PSS: an ElvUI zip Dan uploaded (the load-on-demand split), a DBM AddOns list screenshot (Category/Group/coloured titles), a Questie zip (upgrade output idea, issue #45), wago.tools, and the Warcraft Wiki reference set Dan uploaded on 2026-10-07 (`docs/baseline/reference/wow-api/`; rules in baseline 02 J and PSS 02 section 10).

## 3. Folders (one release zip holds all six from 3.4.0.25)
| Folder | Loads | Holds |
| --- | --- | --- |
| `PourSocialScore` (core) | Always | Chat filtering engine, block counting, outbox, setters, events, loader, options definitions, the schema map (`PSS_Schema.lua`), the window's openers and core popups (`PSS_BlizzardUI.lua`), upgrades, GC helper. SavedVariables `PourSocialScoreDB` (upgrade record, outbox, recent counts, purge marks, sessionStart; its other keys are routed to the Options folder's stores, the player list `list` to `PSS_PlayersDB`) |
| `PourSocialScore_Options` | Always | Data only: `PSS_OptionsDB`, `PSS_PlayersDB`, `PSS_GuildsDB`, `PSS_RulesDB`, `PSS_CountsDB` |
| `PourSocialScore_GUI` | On demand | The PSS window (09; from 3.4.0.25, before that the old native window): PSS_Skin, PSS_Kit, PSS_Tooltip, PSS_Menu, PSS_Popups, PSS_Rows, PSS_Pie, PSS_Detail, PSS_History, PSS_Players, PSS_Guilds, PSS_Filters, PSS_Events, PSS_Options, PSS_Window. Drawing only; no SavedVariables |
| `PourSocialScore_Libraries` | On demand | Commands, the window's logic and rarely used core work: PSS_ImportExport, PSS_PlayerRows, PSS_Validate, PSS_WhoisHarvest (the Scan All planner), PSS_Camelot (the name repair), PSS_GuildQuery, PSS_FilterQuery, PSS_TotalsQuery, PSS_EventsQuery, PSS_DetailQuery, the view files PSS_ViewNav, PSS_PlayerView, PSS_GuildView, PSS_FilterView, PSS_EventsView, PSS_OptionsView, PSS_RowMenus (09), PSS_Commands. The player rows, the save check, the planner and the repair moved here from core at 3.4.1.52 (P6, -63 KB resident at login) |
| `PourSocialScore_Logging` | On demand, only when logs are called | `PSS_LoggingDB` (blockLog, blockKeep); PSS_SavedLog.lua, PSS_LoggingData.lua |
| `PourSocialScore_Communities` | On demand | Packed shipped lists (~460 KB) |
| `PourSocialScore_EllesmereUI`, `PourSocialScore_UI` | Deleted at 3.4.0.25 (D2) | The EllesmereUI window (03) and the new window while it was built; read them from git history (3.4.0.24) |

## 4. Real names (the project's own objects)
- **Namespace:** everything hangs on `M`, shared through the global `PourSocialScore_NS`. The window's private file table is `ns` (`PourSocialScore_GUI`).
- **Events:** `M.Events` (core bus). UIs listen (for example `OPTION_CHANGED`) and write through core setters.
- **Loader** (`PSS_Loader.lua`): `M.PSS_PARTS`; `NEEDS = {GUI="Libraries"}` (3.4.0.25; the `UI` and `EllesmereUI` parts are gone); `M.PSS_Need(key)` loads a part and what it needs; a part whose version differs from core's prints a warning. Logging: `M.PSS_LoadLogging()`.
- **Options:** `M.PSS_OPTIONS` (one table; the window's Options tab renders from it); read `M.PSS_Opt`, write `M.PSS_SetOpt`; only non-defaults stored.
- **Helpers and kit:** `M.ShowMsg`, `M.Trim`; the window's kit (`ns.NewButton`, `ns.NewCheck`, `ns.NewEditBox`, `ns.NewRows`, ...; CLAUDE.md Interface, 09 code map).
- **Counting and history:** `History.*` (04); totals `M.PSS_ListTotals` (Libraries).
- **Guild rules:** `M.PSS_GuildRuleActive`, `M.PSS_IsOwnGuild`; a rule's member count from `M.PSS_GuildMemberCount`.
- **Accessors (02 section 1.5):** guild member fields through `M.PSS_MemberCanon`, `M.PSS_MemberName`, `M.PSS_MemberGuildName`, `M.PSS_MemberWhenBlocked`, `M.PSS_MemberShipped`, `M.PSS_MemberPlayerKey` (one block in `PSS_GuildIgnoreList.lua`; `check_fields.lua`); counts totals through `History.CountTotal`; player list entries through `M.PSS_List`, `M.PSS_EntryName`, `M.PSS_EntryKind`, `M.PSS_NewEntry` and the `M.PSS_SetEntry*` setters (`PSS_PlayerIgnoreList.lua`).
- **Upgrades and schema:** `M.PSS_UPGRADE_REGISTRY`, `M.PSS_UPGRADE_RETIRED`, `M.PSS_RunUpgradeFields` / `M.PSS_RunUpgradeData`, `M.PSS_VersionOrder`; `M.PSS_SCHEMA`, `M.PSS_SchemaKnows`, `M.PSS_UnusableRules`.
- **GC helper:** `PSS_Perf.lua` (stepped collection; option `gcEnabled`). Event-driven only (3.4.1.52, P2): `M.PSS_RequestGC` runs out of combat and outside instances, waiting on events, never on a timer (02 section 4).
- **Commands:** `/pss` on its own opens or closes the window, and `/pss gui`, `ui` and `eui` are the same command (one alias table, `OPEN` in `PSS_Commands.lua`; Dan, 2026-10-08, 3.4.0.28); every other word is its own command and `/pss help` (or any word it does not know) lists them; `/pss export unused` (3.4.1.47); `/pss tui` and `/pss test` are gone. On Camelot `/pss add`, `remove` and `expire` take two words as the name.
- **New window (09):** looks `M.PSS_UISkin()` (option `uiSkin`), accent `M.PSS_UIAccent()` (class colour), font `M.PSS_UIFontPath()` / `M.PSS_UIFontChoices()` (option `uiFont`), place `M.PSS_UIPlace` / `M.PSS_SetUIPlace` (Libraries `PSS_ViewNav.lua`); window `PSS_Window`, entry `M.PSS_OpenUI` (core) -> `M.PSS_OpenWindow`.

## 5. Crucial context
- Three TOCs per folder; one combined TOC broke Camelot in 3.0.0-dev6.
- **Measured hot spots:** `PSS_GetGuildBlockCounts`, the shipped member walk and `PSS_GetMemberBlockCounts` make about 200 to 350 KB of garbage per full pass on Dan's save. An estimate of 6 to 8 KB once measured 22 KB.
- **Known gaps:** none from removal (it never loads Logging from 3.4.1.49). Full parity was not reached; the project closed at 3.3.1 (08). Downgrades: 3.4.0.29 shows an empty Player Ignore List and drops custom filters with an id over a 3.4.1.53 save; 3.4.1.50 and older show about 254 more guild members until the shipped lists load; the data stays in the save.
- **Known breaches of the baseline:** none (02 section 12; the idle GC cycle was fixed at 3.4.1.52). The window's pie hover OnUpdate and the other rows there are approved overrides.

## 6. Plans and status
| Plan | Status |
| --- | --- |
| 2.0 line (to 2.0.44) | Done |
| Dashboard tab (2.0 era) | Paused, branch `claude/project-thread-pa7y7o` |
| Global moderation ideas (sync, curated lists, scoring) | Not started |
| 3.0 load-on-demand split | Done, v3.0.0 |
| EllesmereUI integration E.1 to E.7 | Done, v3.1.0 |
| Detail pane redesign, log every line, grouped save, EUI merged into the repo, EUI navigation, Events tab | Done, **v3.2.0** (full release, 2026-10-05) |
| Native GUI parity with the EllesmereUI window (3.3.0, issue #78) | Closed at **v3.3.1** (2026-10-07): dev001 to dev005 shipped, the rest dropped. 08 and 06 |
| **The new PSS window (3.4.0)**: one window in the port's layout, three looks, replaces both old windows | Done, **v3.4.0.29** (full release, 2026-10-08); started 2026-10-07; the cutover (D2) merged at 3.4.0.25. 09; plan on scratch `docs/latest/ui uplift/` |
| **Core uplift (3.4.1)**: name bugs, PSS authoritative over Blizzard's ignore list, fixes, upgrade report, sparse and forward-compatible saves, core performance and the window tidy (3.4.2 and 3.4.3 folded into 3.4.1.52, decision 28) | Done, **v3.4.1.53** (full release, 2026-10-09); `10_CORE_UPLIFT.md` keeps the decisions; design on scratch `docs/latest/core-uplift/` |

## 7. Dan's preferences
All in `11_PREFERENCES.md` (the one file, Dan, 2026-10-08).
