# Rules compliance review (2026-10-07, main at 3.3.1)

A read-only review of every addon folder against baseline v5 (02 A to J) and the PSS pack v4 (02 sections 1 to 10). No code changed. Each finding was checked in the code; file:line is on main `af7a56f`.

Checks run: `check_rules.sh` pass, `check_rules_eui.sh` pass, `check_eui_all.sh` pass, `validate_all.sh` pass (all upgrade checks, generated saves only). **The real-save run did not happen**: `/mnt/project-files` was missing in this session.

## 1. Findings

Severity: **High** = a hard rule broken with real user risk; **Medium** = a rule broken, limited impact; **Low** = tidy-up or documentation.

### Taint, secret values, Blizzard state (baseline 02 J, PSS 02 section 10)
| # | Sev | Where | Finding | Rule |
| --- | --- | --- | --- | --- |
| T1 | High | `PourSocialScore_GUI/PSS_UI.lua:1532-1555` | Replaces the Blizzard global `ChatEdit_InsertLink` and adds global `Blizzard_ChatEdit_InsertLink`. Every link insertion in the game runs through PSS once the GUI has loaded. The EUI folder already does it right (`EUI_Filters.lua:351-366`, `hooksecurefunc`). | J3, A6, 10.3 |
| T2 | High | `PourSocialScore/PSS_ChatBlock.lua:481` | `CoreFilter` skips only a secret author or GUID. A secret **message** from a readable listed author is still hidden, counted and may get the auto-reply. | 10.1, 10.2 |
| T3 | Med | `PSS_PlayerIgnoreList.lua:590-602, 634-638, 1046` | `UnitName("target")` used (compare, `M.Proper`, add) with no `M.PSS_IsSecret` check; `/pss` add-target in an instance can throw. | J7, 10.1 |
| T4 | Med | `PSS_ChatBlock.lua:723` | Sent-whisper handler does `target == ""` before `isSecret(target)`. | 10.1 |
| T5 | Med | `PSS_ChatBlock.lua:599, 646, 688, 703` | `StaticPopup_Hide` on Blizzard-owned dialogs (PARTY_INVITE, GUILD_INVITE, DUEL_REQUESTED, TRADE). | J4, 10.3 (not on list) |
| T6 | Med | `PSS_ChatBlock.lua:630-648` | Calls `:Click()` on `GuildInviteFrameDeclineButton` and `:Hide()` on `GuildInviteFrame`. | J2, J4, 10.3 |
| T7 | Med-Low | `PSS_ChatBlock.lua:580` | `RemoveMessagesByPredicate` on Blizzard chat frames (`purgeHistory`, default ON). Predicate is secret-safe. | J4, 10.3 (not on list) |
| T8 | Low-Med | `PSS_BlizzardUI.lua:133`, `:300-308` | `RaidNotice_AddMessage` (may run in combat) and `AddonCompartmentFrame:RegisterAddon`. | J4, 10.3 |
| T9 | Low | `PSS_BlizzardUI.lua:330-358` | LFG hooks and unit-menu callbacks never re-check `useLFGHacks` / `useUnitHacks`; turning the option off does nothing until reload. `M.PSS_LFG_Refresh` recolours rows with the option off. | J3, C1 |
| T10 | Low | `PSS_BlizzardUI.lua:210-221` | `GameTooltip:AddLine/Show` in the LFG OnEnter hook without `IsForbidden()`. | J6 |
| T11 | Low | `PSS_MainlineCompat.lua:12-13` | Writes `_G.strlen` / `_G.strbyte` (Blizzard-named globals). | J2, A6 |
| T12 | Low | `PSS_ChatBlock.lua:490`, `PSS_ChatFilters.lua:945-953` | `channelIndex` / `channelBaseName` not secret-checked (only reached when the message is readable). | 10.1 |
| T13 | Low | `PSS_EUI.lua:85` | Client detected by build number `< 20000`. | B6 |
| T14 | Low | `PSS_BlizzardUI.lua:162-164` | Reads EllesmereUI's private `p._msg`, hides `EUIConfirmDimmer`. | H3 |
| T15 | Low (doc) | `PSS_BlizzardUI.lua:29-54` | `SocialUIFrame:HookScript` (3.3.0-dev005) is correct but not on the 10.3 list. | 10.3 |

### Performance, memory, GC (baseline 02 A7, C; PSS 02 section 4)
| # | Sev | Where | Finding | Rule |
| --- | --- | --- | --- | --- |
| P1 | Med | `PSS_Perf.lua:33-35, 55, 134, 155` | Known deviation still there: 10-minute idle cycle, 5-minute combat wait, a 15 s `C_Timer.NewTicker` that polls all session even with `gcEnabled` off, dormant heap-growth path; `runner` frame built at load. | C3, C15, PSS 4 |
| P2 | Med | `PSS_GuildIgnoreList.lua:1200-1222, 767-801`; `PSS_GuildUI.lua:678`; `PSS_GuildQuery.lua:94` | Guild block counts allocate per guild and per member on every call; the guild list walks every member twice per redraw (up to 4 redraws/s). Handover measured 200-350 KB garbage per pass. | C3, C9, C13 |
| P3 | Med | `PSS_Globals.lua:31-67` | `dateToJulianDate` allocates two tables per call; sorts call it per entry. **Measured 1360 KB garbage per 1000 calls.** | C13, C12 |
| P4 | Med | `PSS_PlayerIgnoreList.lua:1433-1436`, `:1445`; `PSS_GuildIgnoreList.lua:2344`; `PSS_ChatBlock.lua:359, 456` | New tables per chat line from a listed player, and per decide/hit context. | C3 |
| P5 | Med | `PSS_ChatHistory.lua:653` | Outbox at cap does `table.remove(ob, 1)` per blocked line (shifts 2000 entries). | C3 |
| P6 | Med | `PSS_ChatHistory.lua:255-258` | `loadWhenQuiet` polls every 30 s with `C_Timer.After` instead of waiting for events. | C3, C15 |
| P7 | Med | `PSS_UI.lua:1565, 1613-1621`; both UI folders | 29 `M.Events.Register` with no `Unregister`; `PSS_RequestUIRefresh` runs with the window closed; `throttled()` makes a closure per call. | A9, C8, C9 |
| P8 | Med | `PSS_GuildIgnoreList.lua:1698-1707` | Target, roster, mouseover and nameplate events registered for everyone, even with no guild rule. | C1 |
| P9 | Med | `PSS_Whois.lua:254, 289-290` | `{ msg:match(...) }` per pattern on every `CHAT_MSG_SYSTEM` player link, registered all session. | C1, C3 |
| P10 | Med | `PSS_Pie.lua:139`, `PSS_UIKit.lua:630`, `EUI_Pie.lua:123` | Known deviation: OnUpdate while hovered/dragging, new closure each time (EUI_Pie not listed in the handover). | C3 |
| P11 | Low | `PSS_ChatBlock.lua:502`, `PSS_ChatFilters.lua:938, 953` | Per-line string concatenation / `sub` for cache keys and channel names. | C3 |
| P12 | Low | `PSS_PlayerIgnoreList.lua:1009`, `PourSocialScore.lua:300`, `PSS_ChatBlock.lua:765`, `PSS_Perf.lua:141-143` | Events left registered after they are needed. | C8 |
| P13 | Low | `PSS_ChatBlock.lua:440` | `lastReplyTo` grows one entry per blocked whisperer, no cap. | C7, D2 |
| P14 | Low | `PSS_GuildQuery.lua:98`, `PSS_WhoisHarvest.lua:214`, `PSS_Globals.lua:41` | `table.insert` for appends / front insert in a loop. | C12 |
| P15 | Low | `PSS_ChatBlock.lua`, `PSS_ChatHistory.lua`, `PSS_GuildIgnoreList.lua` | Hot files use global `type`, `pcall`, `ipairs`, `GetTime`, `tostring`. | A7 |
| P16 | Low | `PSS_GuildIgnoreList.lua:1955-1970` | `canonGuild()` (trim, gsub, lower) on every decide for own-guild / exclusion. | C3 |

### Layering, data, TOCs, process (baseline 02 A, B, D, E, G; PSS 02 sections 3, 5, 6)
| # | Sev | Where | Finding | Rule |
| --- | --- | --- | --- | --- |
| L1 | Med | `tools/check_rules.sh`, `tools/check_style.lua` | No new-global check, so T1 passed CI. | A12 |
| L2 | Med | `PSS_UI.lua:257-265`, `PSS_ChatFilters.lua:972-974` | Native Chat Filters "All time" reads `filterTotal`, which also counts inverted-spam blocks; the pie and EUI read `PSS_ListTotals("filters")`. Differ when `invertSpam` is on. | D7, PSS 3 |
| L3 | Med | `PSS_GuildIgnoreList.lua:1168-1173` | Removing a guild member loads Logging (known gap; players and filters already guard it). | PSS 6.5 |
| L4 | Med | `PSS_PlayerQuery.lua` (16.7 KB loaded), `PSS_Upgrade.lua:247-438` (Validate), `PSS_WhoisHarvest.lua` (22.1 KB), parts of `PSS_GuildIgnoreList.lua` (scan, search, legacy upgrade, history readers) | Core code not on a regularly active path. | G2, PSS 5 |
| L5 | Med (doc) | `docs/pss/00, 01, 04, 05, 06`, `02 section 8`, `CLAUDE.md`, `readme.txt:2`, `history.txt` | Stale state: "main is 3.3.0-dev004", "next dev005", "3.2.0 last full release", "plain 3.3.0 when parity is done"; readme says 3.2.0; 3.3.1 history has no "- Version 3.3.1." line. | E2 |
| L6 | Med | `PourSocialScore_GUI/PSS_UI.lua:1431` | Known deviation: totals pane shows for everyone without an option. | C2 |
| L7 | Low | `PSS_GuildUI.lua` (10 reads, e.g. `:105, :201, :332`), `PSS_ChatHistoryUI.lua:59-93` vs `EUI_HistoryView.lua:167-180`, `PSS_UIKit.lua:461, 898, 1018` | GUI reads `PourSocialScoreDB.guildData` directly; history sort duplicated in both UIs; UI state written without a setter. | G1, A9 |
| L8 | Low | `PSS_ChatFilters.lua:116-117, 241-245`; `PSS_PlayerIgnoreList.lua:91-96` | Stored defaults and duplicates (`filterBlockedLast` always 0, `filterCount` duplicates counts, `notes = ""`, `syncInfo = {}`, `typeList`). Layout change: needs Dan. | D1, D3 |
| L9 | Low | `tools/check_layers.lua` | CORE list misses `PSS_SavedData`, `PSS_Loader`, `PSS_Upgrade`, `PSS_EUI` and Libraries `PSS_Commands`, `PSS_EventsQuery`, `PSS_TotalsQuery` (all clean today). | A9 |
| L10 | Low | `PSS_ChatBlock.lua:792-798` | `M.PSS__CoreTest` ships in core; its comment says "not shipped". | A11 |
| L11 | Low | `PourSocialScore/PourSocialScore.toc` | No `## OptionalDeps` line; `_Mainline` and `_Camelot` have one. | B2 |
| L12 | Low | `tools/harness/validate_all.sh` | On a shallow clone `git archive` fails yet later phases still print PASS; only the final line says FAILED. Fail fast when a commit is missing. | E4 |
| L13 | Question | every TOC | Interface 120007 while history describes Retail 12.1; `_Standard` suffix from 12.1.5 (B5). Needs `/dump select(4, GetBuildInfo())` in game. | B5 |

### Verified compliant
Secret checks on every name normaliser, invite/duel/trade handlers, ignore-list hooks, LFG and unit-menu callbacks and Whois parsing; chat filters only via `AddMessageEventFilter`; `C_FriendList` post-hooked only; `Menu.ModifyMenu` feature-detected, no `UIDropDownMenu`; no `COMBAT_LOG_EVENT`, no secure templates, no `SetScript` on Blizzard frames; `SendWho` only from a click or keybind; `WOW_PROJECT_ID` compared to the named constant; G3 (GUI and EUI never read each other); H1 (`euiIntegration` default off); no private EUI fields except T14; outbox, keep and managed stores capped; all 21 TOCs at 3.3.1 with Title, Notes, Category, Group and IconTexture intact.

## 2. Decisions for Dan (recommendation first)
1. **Version line.** (a) A `3.3.2` compliance line: each stage `3.3.2-devNNN`, plain `3.3.2` when done. **Recommended.** (b) Ship each fix straight as `3.3.2`, `3.3.3` and so on.
2. **T2, a secret message from a readable listed author.** (a) Skip it: not filtered, not counted, as 10.1 says. **Recommended**; under chat lockdown the author is usually secret too. (b) Keep hiding listed people's lines, count nothing, and amend 10.1.
3. **T5, T6: Blizzard popups and the guild invite frame.** (a) Drop `StaticPopup_Hide`, `:Click()` and `:Hide()`. The decline APIs (`DeclineGroup`, `C_GuildInfo.DeclineGuild`, `CancelDuel`, `CancelTrade`) already make Blizzard close its own dialogs. Check in game that nothing stays on screen. **Recommended.** (b) Keep them, and add them to 10.3 with a note.
4. **T7, T8: chat purge, raid notice, compartment.** (a) Add `RemoveMessagesByPredicate` to 10.3 as allowed. Move the compartment entry to the TOC `## AddonCompartmentFunc` line; this adds a TOC line but leaves Title and Notes alone. Guard `RaidNotice_AddMessage` with `InCombatLockdown()` and print instead while in combat. **Recommended.** (b) Remove the raid notice and keep chat output only.
5. **P1, GC.** You chose event-driven GC on 2026-10-07 but said not to change the code yet. Can it be changed now? (a) Yes. **Recommended.** (b) Not yet.
6. **P2, guild counts.** (a) A runtime cache with a generation number: no SavedVariables change. **Recommended.** (b) Keep the counter at event time in `guildData`, which changes the layout and needs a migration.
7. **L6, totals pane without opt-in.** (a) Record it as an accepted deviation, since it has shipped in a full release. **Recommended.** (b) Add an option, default OFF.
8. **L8, SavedVariables tidy.** (a) Park it for a later line. **Recommended.** (b) Do it now with a migration validated on the three real saves.
9. **L4, `PSS_WhoisHarvest.lua` to Libraries.** (a) Defer it: `SendWho` needs the hardware event, so test a synchronous load inside the keybind first. **Recommended.** (b) Include it in stage 8.

## 3. Implementation plan (one PR per stage, each from the latest main, never stacked)
Built on the recommended options. Every stage bumps all 21 TOCs, adds a history section and a hosted test zip, and runs the four pre-push checks plus the real-save run. A stage that should not change a window also runs `ui_compare` / `eui_compare`.

| Stage | Version | Change | Findings | Visible? | Validation |
| --- | --- | --- | --- | --- | --- |
| 0 | none (docs) | Docs refresh: 00, 01, 04, 05, 06, 02 section 8, CLAUDE.md short form, readme version and features, the 3.3.1 "- Version" line; add `SocialUIFrame` to 10.3 | L5, T15 | No | Rules check |
| 1 | 3.3.2-dev001 | Native link insert becomes `hooksecurefunc` (EUI shape), both globals removed; remove the `_G.strlen`/`strbyte` writes; rules check gains a `luac -l` SETGLOBAL scan with an allow list; `validate_all.sh` fails fast on a missing commit | T1, T11, L1, L12 | Link insertion only | Harness; in game: shift-click a link into the Chat Filters link, filter and test boxes, and into chat with the window closed; taint log clean; 10.6 restriction run |
| 2 | 3.3.2-dev002 | Secret-value gaps: `isSecret(msg)` in `CoreFilter`, sent-whisper order, `UnitName("target")` guards, channel args, tooltip `IsForbidden`, LFG and unit-menu callbacks gated on their option | T2, T3, T4, T9, T10, T12 | No (except lines under lockdown) | New harness case: secret msg, author, target and channel -> not filtered, not counted, no error; 10.6 restriction run |
| 3 | 3.3.2-dev003 | Blizzard dialogs: drop `StaticPopup_Hide` and the GuildInviteFrame click and hide; raid notice combat guard; compartment via TOC; 10.3 updated; EUI dimmer read (T14) replaced or recorded; client check via a feature test | T5, T6, T7, T8, T13, T14 | Possibly (dialogs) | In game: auto-decline party, guild, duel and trade with no dialog left behind; taint log |
| 4 | 3.3.2-dev004 | Event-driven GC: no ticker, idle cycle, growth path or combat wait; lazy runner; retry on REGEN / zone events; `loadWhenQuiet` on events | P1, P6, P12 (Perf part) | No | Harness GC checks; measured resident cost before and after; in game `/pss` GC status after combat and after leaving an instance |
| 5 | 3.3.2-dev005 | Chat-path allocations: reused lookup and ctx tables, outbox ring or batch trim, Whois `CHAT_MSG_SYSTEM` only while a /who is pending, `lastReplyTo` cap, event-name table, local shortcuts, guild events only with an active rule, one-shot unregisters | P4, P5, P8, P9, P11, P12, P13, P15, P16 | No | `bench_recent.lua` and a new per-line garbage bench (numbers in the PR); harness; option off = no events |
| 6 | 3.3.2-dev006 | Counting: native filters all-time reads `PSS_ListTotals("filters")`; Logging guard when a guild member is removed; `dateToJulianDate` without allocations | L2, L3, P3 | Number only if `invertSpam` was on | `check_match.lua` with an `invertSpam` save; `check_ondemand.lua` covers guild removal; measured garbage |
| 7 | 3.3.2-dev007 | Guild count cache (generation number), guild list sums the query pool once per redraw, UI listeners gated or unregistered on hide, `throttled()` without closures | P2, P7, P14 | No | Measured garbage per guild redraw on the real saves; `ui_compare` and `eui_compare` identical |
| 8 | 3.3.2-dev008 | G2 move: `PSS_PlayerQuery` (except `PSS_PlayersChanged`) and `PSS_Validate` to Libraries | L4 | No | Resident cost before and after; compare scripts identical; `/pss validate` still works |
| 9 | 3.3.2-dev009 | G1 tidy: `PSS_GuildUI` reads through Libraries queries; one shared history sort; `check_layers` CORE list completed; `PSS__CoreTest` comment or removal; base TOC OptionalDeps | L7, L9, L10, L11 | No | `ui_compare` identical; layers check |
| 10 | 3.3.2-dev010 | Pie and column-drag hover without per-hover closures (one handler reused, or hit frames) | P10 | No | Hover in game; measured garbage while hovering |
| Release | 3.3.2 | Version and a history section for the line | | | Full regression on real saves; Dan confirms |

Parked, needs Dan: L8 (SavedVariables tidy with migration), L6 if option (b), L13 (interface numbers and `_Standard`, checked in game at the next patch), the WhoisHarvest move.
