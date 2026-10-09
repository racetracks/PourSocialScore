# PourSocialScore_GUI and the core openers: reference map (3.4.1.53)

Folder `PourSocialScore_GUI` (LoadOnDemand; `## Dependencies: PourSocialScore, PourSocialScore_Libraries`). 15 files, 5731 lines, load order: Skin, Kit, Tooltip, Menu, Popups, Rows, Pie, Detail, History, Players, Guilds, Filters, Events, Options, Window. Private file table `ns` (the addon's `...` table); `ns.M = M` (set in Skin). No SavedVariables; no frames at load except the font objects created lazily by `ns.Font`. Looks: `ns.Skin()` returns `"modern"` (uiSkin 2, the default), `"blizzard"` (Classic, 0) or `"dark"` (1) from `M.PSS_UISkin()` (Libraries `PSS_ViewNav.lua`). `ns.IsModern()` = skin modern AND the client has every Modern atlas (else Classic paint). Backend file names below: `core/X` = `PourSocialScore/PSS_X.lua`, `Lib/X` = `PourSocialScore_Libraries/PSS_X.lua`.

Since 3.4.1.38: W1 (dead code, G11 to G14, G24, G25, G29), W2 (logic to Libraries: pane views, cells, summary specs, history cells), W3 (kit: `ns.NewTextArea`, `ns.NewPicker`, `ns.NewLine`, `ns.NewLabel`, `ns.NewStrip`, `ns.NewAllowedBoxes`, edit box hints, primary buttons), W4 (counts-only redraws on a block), F2 (G21, G26, G27, G28), Fix 2 (wrapped detail lines).

## 1. PSS_Skin.lua (347 lines): looks, fonts, primitives, Escape, listeners

| Export | Signature | What |
| --- | --- | --- |
| `ns.M` | table | `PourSocialScore_NS.M` |
| `ns.DARK` | table | Dark palette `{r,g,b,a}` per part |
| `ns.TITLE_H` | 25 | title bar height |
| `ns.Skin()`, `ns.IsDark()`, `ns.IsModern()` | | cached look |
| `ns.HasModernArt()` | -> bool | all 19 `MODERN_ART` atlases exist (G28: the red button parts with Pressed/Disabled/Highlight, tertiary button, friends card, perks divider, minimal checkbox and checkmarks, search bar and its icon) |
| `ns.AtlasWidth(atlas, h)`, `ns.HasAtlas(name)` | | atlas helpers |
| `ns.Accent()` | -> r,g,b | `M.PSS_UIAccent()` (class colour) |
| `ns.OnPaint(fn)`, `ns.Repaint()` | | painters; repaint every font and painter (look or font change) |
| `ns.Font(size, blizz)`, `ns.NewText(parent, size, blizz, layer)` | | shared `CreateFont("PSS_FontN")`; `uiFont` applied |
| `ns.OnePixel(frame)`, `ns.NoSnap(tex)`, `ns.PixelBorder(frame, color)`, `ns.Fill(frame, color, sub, layer)`, `ns.Round(v)` | | pixel-exact primitives |
| `ns.Own(region)`, `ns.ShowArt(frame, dark, keep)` | | template art shown or faded |
| `ns.NewFrameArt(parent)` | -> frame or nil | first of `ButtonFrameTemplate`, `PortraitFrameTemplate`, `BasicFrameTemplateWithInset`; `f.pssBlack` in Modern |
| `ns.EscapeCloses(f, name)`, `ns.EscapeTaken()` | | `UISpecialFrames` (append only) and the one-Escape guard |
| `ns.Listen(event, fn)`, `ns.ListenStart()`, `ns.ListenStop()` | | core-event listeners registered only while the window shows |

Backend: `M.PSS_UISkin`, `M.PSS_UIAccent`, `M.PSS_UIFontPath` (Lib/ViewNav), `M.Events` (core/Events).

## 2. PSS_Kit.lua (536 lines): the control kit
| Export | Signature | Looks |
| --- | --- | --- |
| `ns.NewHeading(parent, text)` | -> FontString 13 | accent colour in every look |
| `ns.NewButton(parent, text, w, onClick, primary)` | -> Button 22 high | Classic: `UIPanelButtonTemplate`. Dark: flat fill, pixel edge. Modern: `primary` -> red three-slice `128-RedButton-*`; else tertiary plate (G20: `primary` replaces setting `pssPrimary` after) |
| `ns.NewCheck(parent)` | -> CheckButton 24 | Dark box + accent tick; Modern `checkbox-minimal` / `checkmark-minimal(-disabled)` |
| `ns.NewEditBox(parent, w, maxLetters, hint)` | -> EditBox 20 high | `e.hint` grey text while empty (G18; hooks OnTextChanged, so a caller must not SetScript it) |
| `ns.NewNumberBox(parent, w)`, `ns.OnCommit(e, commit, refresh)` | | numeric box; commit once on Enter or focus loss |
| `ns.NewSearchBox(parent, w, hint, onChange)` | -> EditBox | magnifier, hint (same helper), clear button |
| `ns.NewPanel(parent, inset)` | -> Frame | Classic `InsetFrameTemplate`; Dark flat; Modern `friends-card-default` / `perks-divider-short` |
| `ns.NewScrollFrame(parent)` | -> ScrollFrame | `ScrollFrameTemplate` or `UIPanelScrollFrameTemplate`; Dark thumb strip |
| `ns.NewTextArea(parent, size, maxLetters, pad)` | -> panel with `.edit`, `.scroll` | (G19) multi-line box that follows the cursor; used by Filters and the text popup |
| `ns.NewTab(parent, text, onClick)`, `ns.SetTabSelected(tab, on)` | -> Button 24 high | tab row and page bar |

`BAR_BUTTONS` is hoisted (G25).

## 3. PSS_Tooltip.lua (96 lines): tooltips
| Export | What |
| --- | --- |
| `ns.Tip(owner, text)` | text or a function giving it (built when hovered, W4). Classic/Modern: `GameTooltip` (`IsForbidden()` checked). Dark: our `PSS_Tooltip` frame (lazy, fades) |
| `ns.HideTip()`, `ns.TipOn(frame, owner, text)` | hide; OnEnter/OnLeave on our own frame |

## 4. PSS_Menu.lua (374 lines): drop-downs and right-click menus
A menu is a build function filling a plain list: `m:Button`, `m:Radio`, `m:Check`, `m:Divider`, `m:Title`.

| Export | What |
| --- | --- |
| `ns.NewDropdown(parent, w, build)` | Blizzard `WowStyle1DropdownTemplate` in Classic/Modern; our button + list in Dark or without the template |
| `ns.ContextMenu(by, build)` | `MenuUtil.CreateContextMenu` in Classic/Modern; else our compact list at the cursor, its width measured over every entry with one measuring FontString (G27) |
| `ns.RowMenu(by, entries, run)` | Libraries' entry list (`PSS_RowMenus.lua`) -> ContextMenu; each click calls `run(act, arg)` |
| `ns.DrawMenu()` | redraws our list if shown |

- Our list: one shared frame `PSS_Menu` (FULLSCREEN_DIALOG level 200), slot pool, wheel scroll. `SIZES`: list (26 px items, cap 200) and compact (20 px, cap 400, G27). Leaving a slot resets only that slot's text alpha (G24); the divider is one physical pixel (G29). `ns.CloseMenu` is gone (W1).

## 5. PSS_Popups.lua (254 lines): the window's own popups
| Export | Signature | What |
| --- | --- | --- |
| `ns.Confirm(opts)` | `{title, text, accept, cancel, onAccept(n), onCancel, number, numberNote(n)}` | `PSS_Confirm`; optional number box; any hide but Accept runs `onCancel` |
| `ns.CopyText(opts)`, `ns.ImportText(opts)` | `{title, subtitle, text}` / `{title, subtitle, accept, onAccept(text)}` | `PSS_TextPopup` on `ns.NewTextArea` (W3) |
| `M.PSS_CopyTextBox(title, subtitle, text)` | | the copy box on its own, for `/pss export unused` (Libraries Commands; the window stays closed) |

- Frames built on first use; `chrome` child above the frame art for the title; a `dim` button in Dark. Classic/Modern: `ns.NewFrameArt`, title in the title bar; Dark: flat panel. Escape via `ns.EscapeCloses` after their scripts.
- `PSS_Popups.lua` declares `local M = ns.M` (the 3.4.1.48 fix; `tools/check_locals.lua` guards it).

## 6. PSS_Rows.lua (384 lines): row lists and the picker
`ns.NewRows(parent, spec)` -> list (spec: `rowH`, `cols`, `sort`, `draw`, `click`, `enter`, `emptyClick`, `links`, `fontSize`, `height`). Methods: `SetCount`, `Redraw` (rows on screen only), `Top`, `SetSort`, `Select`, `SetEmptyText`, `Layout`, `MakeRow`. Links: click -> `SetItemRef` (not in combat); hover -> `GameTooltip:SetHyperlink` only for the `TIP_LINKS` allow list.

`ns.NewPicker(parent, anchor, {cols, stateW, fill, toggle, tickAll, save, close})` with `:ShowItems(title)` (G15): the /who results picker used by Players and Guilds; cells from `M.PSS_PickerCells` (Lib/ViewNav).

## 7. PSS_Pie.lua (140 lines): ring chart
`ns.NewPie(parent, size, onClick)`; `pie:Set(slices)`, `pie.tip`. 60 `CreateLine` segments; **OnUpdate only while the mouse is over it** (approved C3 override). Same in all three looks.

## 8. PSS_Detail.lua (482 lines): detail pane parts
| Export | What |
| --- | --- |
| `ns.NewDetailPages(body, top, kind)` | Summary / Event History / View/Edit Rule pages and their tab bar; `dp:Select(key)`, `dp:Limit(only)` |
| `ns.NewSummary(page, tabPage, top, size)` | period pie + period ticks + "Stored:" line + View Events; `sm:Set(spec)` (`M.PSS_SpecCopy`) |
| `ns.NewTypePie(parent, top, size, tabPage)` | all-time by type pie (tips `M.PSS_TypeTip`) |
| `ns.NewTotals(pane, tabPage, kind, title, hint, allSpec)` | a list's totals when nothing is selected |
| `ns.NewExceptions(parent, x, y, width, onChange)` | a tick per override option; tips built when hovered |
| `ns.NewLine(parent, y)`, `ns.NewLabel(parent, text, x, y)`, `ns.NewStrip(parent, y, h, w)`, `ns.NewAllowedBoxes(parent, y, w, tip, onClick, rightClicks)` | (G16, G17) shared pane lines, labels, strips and the W I G P C boxes (`M.EXCL`) |

Backend: Lib/DetailQuery (summary, pies, exceptions), Lib/EventsQuery (`PSS_StoredText`). `ns.DETAIL_PAGES` is gone (W1).

## 9. PSS_History.lua (190 lines): block history list in the panes
| Export | What |
| --- | --- |
| `ns.NewHistory(body, y, opts)` | type ticks over an `ns.NewRows` list and a gate button "Show Block History (n)"; rows from `M.PSS_HistCells`, tips `M.PSS_HistTip`, empty text `M.PSS_HistEmptyText` (G1) |
| `hv:Set(id, total, read, fresh)`, `hv:Clear()` | reads only when id, total or Logging-ready changed (no key string, G25); never loads Logging for a row click |
| `ns.SenderMenu(row, name)` | right-click on a blocked line (also the Events tab) |

Backend: Lib/EventsQuery (`PSS_EVENT_TYPES`), Lib/DetailQuery (`PSS_HistHidden`, `PSS_SetHistHidden`, `PSS_HistFilter`, `PSS_HistCells`, `PSS_HistTip`), Lib/ViewNav (`PSS_DoubleClick`), Lib/RowMenus (sender menu), core/ChatHistory (`M.PSS_LoadLogging`, `M.PSS_LoggingReady`).

## 10. PSS_Players.lua (497 lines): Player Ignore List tab
- Exports: `ns.TabBuilders.players`, `ns.ShowPlayerDetail(newEntry)`, `ns.ShowPlayerCounts()` (W4: counts line, history and Summary only). Page hooks: `navClose`, `navUp` (close the picker), `navReset`, `stale`, `select`, and the widgets.
- Module state: `V = M.PSS_PlayerListNew()` (file load), `sel`, `rowBuf`.
- Frames (first open): search, count, Add box (hint "Name-Realm"), Add Player, Player Search, Prune; pane (`ns.NewPanel`, `ns.NewTotals`, `ns.NewDetailPages`): Summary, Rule (lines through `ns.NewLine`, Expires box, Note box, `ns.NewAllowedBoxes`, Blizzard tick, `ns.NewExceptions`, Remove, Add Guild), History (`ns.NewHistory` + Reset); list `ns.NewRows` (Name, Server 112, Type 72, Listed 54, Expires 62, Blocked 62); `ns.NewPicker` (Name, Level, Class, Guild).
- Listens: `PLAYERS_CHANGED` (dirty; refresh if visible), `PLAYER_BLOCKED` (throttled: rows + `ns.ShowPlayerCounts`), `WHOIS_COOLDOWN`.
- Popups: "Remove Player?", "Add Player?", "Prune Players?" (number box).

| Backend call | Defined in |
| --- | --- |
| `M.PSS_PlayerListNew`, `M.PSS_PlayerTypeText`, `M.PSS_PlayerExpireText`, `M.PSS_PlayerListedText`, `M.PSS_PlayerTotal`, `M.PSS_PlayerTip`, `M.PSS_PlayerHeading`, `M.PSS_PlayerTypeLine`, `M.PSS_PlayerAddedLine`, `M.PSS_PlayerExpireNote`, `M.PSS_PlayerExpireBoxText`, `M.PSS_PlayerGuildLine`, `M.PSS_PlayerInviteLine`, `M.PSS_PlayerGuildState`, `M.PSS_PlayerSummarySpec`, `M.PSS_PlayerRemoveText`, `M.PSS_PlayerAddFromText`, `M.PSS_PlayerSearchFromText`, `M.PSS_PlayerPickerItems/Title/Cells/Save`, `M.PSS_PlayerNoneFound`, `M.PSS_PlayerAddAnyway`, `M.PSS_PRUNE_DAYS`, `M.PSS_PruneText`, `M.PSS_PruneNote`, `M.PSS_PruneApply`, `M.PSS_PlayerCommitExpiry`, `M.PSS_PlayerCommitNote`, `M.PSS_PlayerAllowed`, `M.PSS_PlayerToggleAllowed`, `M.PSS_BLIZZARD_TEXT`, `M.PSS_BLIZZARD_TIP`, `M.PSS_PlayerOnBlizzard`, `M.PSS_PlayerToggleBlizzard`, `M.PSS_PlayerAddGuild`, `M.PSS_AllPlayersSpec`, `M.PSS_PlayerEventsSpec` | Lib/PlayerView |
| `M.PSS_PlayerRow`, `M.PSS_PlayerEntry`, `M.PSS_PlayerPosition`, `M.PSS_RemovePlayerAt` | Lib/PlayerRows |
| `M.PSS_PlayerMenu` | Lib/RowMenus |
| `M.PSS_ClassColor`, `M.PSS_CountsText`, `M.PSS_ToggleException` | Lib/DetailQuery |
| `M.PSS_PickerToggle`, `M.PSS_PickerTickAll`, `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_GetPlayerBlockCounts`, `M.PSS_GetPlayerBlockHistory`, `M.PSS_ResetPlayerBlockHistory` | core/PlayerIgnoreList |
| `M.PSS_ScanCooldownActive` | core/Whois |

## 11. PSS_Guilds.lua (928 lines, largest): Guild Ignore List tab
- Exports: `ns.TabBuilders.guilds`. Page hooks: `navState`, `navTitle`, `navApply`, `navClose`, `navUp` (picker, then members), `navReset`, `stale`, `select`, `selectMember`, and the widgets.
- Module state: `V = M.PSS_GuildListNew()`, `cells`, `groupView`, `scanButtons`.
- Frames (first open): search + count; two entry rows (Add Guild / Exclude with Guild Search), Scan All; pane with `ns.NewTotals` and four bodies: guild (`BuildGuildBody`: Summary, Rule with `ns.NewAllowedBoxes`, Scan, Custom Scan Fields, exceptions, Members, Remove; History), group (`BuildGroupBody`: four lines with a set width whose heights `FitLines` sets from `GetStringHeight` on show and repaint, pies below the last line; Fix 2), info (Exclusion List), member (`BuildMemberBody`: lines, Note box, W I G P C boxes, exceptions, Remove, Add Guild; History). Lists: guilds (Guild, Members 70, Blocked 62, Scan 90; rows dimmed for a group whose rule is off), members (Name, Guild 130, Note 110, Blocked 62), `ns.NewPicker`.
- Pane data from Libraries (W2): `M.PSS_GuildPaneView`, `M.PSS_MemberPaneView`, `M.PSS_MemberCells`, the `*SummarySpec` functions; member guild names through core `M.PSS_MemberGuildName`. `ShowCounts()` redraws only the counts, history and Summary on a block (W4).
- Listens: `GUILDS_CHANGED`, `GUILD_SCAN_DONE`, `FILTERS_CHANGED` (G26: the rule dim follows) -> one redraw per frame; `GUILD_REMOVED(key)`; `GUILD_BLOCKS_CHANGED` (throttled: rows recounted, `V.share` so the pane reuses the row's count, `ShowCounts`); `WHOIS_COOLDOWN`; `GUILD_SEARCH_RESULTS` (owner `M.PSS_GUILD_SEARCH_OWNER` only).
- Popups: "Remove Guild?", "Remove Member?", "Exclude Guild?".

| Backend call | Defined in |
| --- | --- |
| `M.PSS_GuildListNew` (and its methods), `M.PSS_GUILD_MANAGED`, `M.PSS_GUILD_SEARCH_OWNER`, `M.PSS_GuildRowCells`, `M.PSS_GuildRowTip`, `M.PSS_GuildScanTip`, `M.PSS_GuildExists`, `M.PSS_GuildPaneView`, `M.PSS_MemberPaneView`, `M.PSS_MemberCells`, `M.PSS_GuildSummarySpec`, `M.PSS_MemberSummarySpec`, `M.PSS_GroupSummarySpec`, `M.PSS_GuildAddFromText`, `M.PSS_GuildExcludeFromText`, `M.PSS_GuildSearchFromText`, `M.PSS_GuildPickerItems/Title/Save/Close`, `M.PSS_GuildNoneFound`, `M.PSS_GuildExcludeAnyway`, `M.PSS_MembersNavTitle`, `M.PSS_MemberTip`, `M.PSS_GuildGroupView`, `M.PSS_GuildExclView`, `M.PSS_MemberAllowed`, `M.PSS_GuildAllowed`, `M.PSS_GuildToggleAllowed`, `M.PSS_GuildToggleException`, `M.PSS_MemberToggleException`, `M.PSS_GuildScanNow`, `M.PSS_GuildCustomScan`, `M.PSS_GuildCommitFields`, `M.PSS_GuildRemoveText`, `M.PSS_GuildRemove`, `M.PSS_MemberRemoveText`, `M.PSS_MemberCommitNote`, `M.PSS_MemberToggleAllowed`, `M.PSS_GroupToggleRule`, `M.PSS_GroupToggleOpen`, `M.PSS_ExclRemove`, `M.PSS_AllGuildsSpec`, `M.PSS_GuildEventsSpec`, `M.PSS_GroupEventsSpec`, `M.PSS_MemberEventsSpec` | Lib/GuildView |
| `M.PSS_GuildRowMenu`, `M.PSS_MemberMenu`, `M.PSS_GuildSetAllRules` | Lib/RowMenus |
| `M.PSS_AddMembersGuild` | Lib/GuildQuery |
| `M.PSS_GroupRecentByCat` | Lib/EventsQuery |
| `M.PSS_ClassColor`, `M.PSS_CountsText` | Lib/DetailQuery |
| `M.PSS_PickerToggle`, `M.PSS_PickerTickAll`, `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_ScanAll` | Lib/WhoisHarvest (through the core stub) |
| `M.PSS_GetGuildBlockHistory`, `M.PSS_GetMemberBlockCounts`, `M.PSS_GetMemberBlockHistory`, `M.PSS_ResetGuildBlockHistory`, `M.PSS_ResetMemberBlockHistory`, `M.PSS_MemberGuildName` | core/GuildIgnoreList |
| `M.PSS_ScanCooldownActive` | core/Whois |

## 12. PSS_Filters.lua (456 lines): Chat Filters tab
- Exports: `ns.TabBuilders.filters`, `ns.ShowFilterDetail(fresh)`. Page hooks: `navReset`, `stale`, `select`, `selected()`, `linkHook()` (harness), and the widgets.
- Frames (first open): search + count, New Filter, Reset Defaults; pane with `ns.NewTotals("filters")`, heading, info, `ns.NewDetailPages`; Rule: On, Description, help, the filter box (`ns.NewTextArea`, 1000 letters), Save / Copy / Remove / Reset Count, Test, Link converter; Summary (`M.PSS_FilterSummarySpec`); History. List: Description 190, On 40, Blocked 60, Filter.
- **Hook (J3, approved):** first open runs `hooksecurefunc(ChatFrameUtil, "InsertLink", ...)` on Retail 12.x, else `hooksecurefunc("ChatEdit_InsertLink", ...)`; the body returns unless the pane is visible and checks `M.PSS_IsSecret` first.
- Listens: `FILTERS_CHANGED` (one redraw per frame), `FILTER_HISTORY_CHANGED` (G21: marks the list and redraws through the 4-a-second throttle; core no longer fires `FILTERS_CHANGED` per block).
- Popups: "Remove Rule?", "Reset Chat Filters?".

| Backend call | Defined in |
| --- | --- |
| `M.PSS_FilterListNew`, `M.PSS_FilterRowCells`, `M.PSS_FilterRowTip`, `M.PSS_FilterHeading`, `M.PSS_FilterInfo`, `M.PSS_FilterHistoryLine`, `M.PSS_FilterSummarySpec`, `M.PSS_FilterRemoveText`, `M.PSS_FilterRemove`, `M.PSS_FilterSave`, `M.PSS_FilterCopy`, `M.PSS_FilterNew`, `M.PSS_FilterTestText`, `M.PSS_FilterEventsSpec`, `M.PSS_AllFiltersSpec` | Lib/FilterView |
| `M.PSS_FilterRow`, `M.PSS_ConvertChatLink` | Lib/FilterQuery |
| `M.PSS_FilterMenu` | Lib/RowMenus |
| `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_SetFilterActive`, `M.PSS_ResetFilterCount`, `M.PSS_ResetFilterHistory`, `M.PSS_FilterHistory`, `M.ResetSpamFilters` | core/ChatFilters |
| `M.PSS_IsSecret` | core/ChatBlock |

## 13. PSS_Events.lua (274 lines): Events tab
- Exports: `ns.TabBuilders.events`, `ns.OpenEvents(_, spec, opts)`. Page hooks: `navState`, `navTitle`, `navApply`, `navReset`, `release` (`view:Release()` + `list:SetCount(0)`, also on the page's OnHide), `view`, `list`, `ui`.
- Frames (first open): heading, Reset, three `ns.NewDropdown` (Time, Types, Source), search box, custom range row, `ns.NewRows(links=true)` (Time 136, Source, Player, Type, Channel, Message).
- Logging: `view:Refresh()` calls the spec's `read`, which loads Logging; the tab is never restored on reopen.
- Listens (throttled, only while visible): `PLAYER_BLOCKED`, `GUILD_BLOCKS_CHANGED`, `FILTER_HISTORY_CHANGED`, `PLAYERS_CHANGED`, `GUILDS_CHANGED`.
- Popups: `ns.CopyText` "Copy Event", `ns.Confirm` "Reset Block History?".

| Backend call | Defined in |
| --- | --- |
| `M.PSS_EventsViewNew` (view methods), `M.PSS_EVENT_TIMES`, `M.PSS_EVENT_SOURCES`, `M.PSS_EventCells`, `M.PSS_EventTip`, `M.PSS_EventCopy` | Lib/EventsView |
| `M.PSS_DoubleClick`, `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_History` (`ALL_CATS`, `CAT_LABEL`) | core/ChatHistory |

## 14. PSS_Options.lua (236 lines): Options and Import/Export tabs
- Options: scrolling page, a heading per section (`M.PSS_OptGroups()`), one row per option: tick (`M.PSS_SetOpt(key, "global", v)`), tick with number (`M.PSS_OptSetFieldOn` / `M.PSS_OptSetField`), number (`M.PSS_OptSetNumber`), choice (`ns.NewDropdown`; `M.PSS_SetOpt`). Search box on the tab row (`M.PSS_OptMatches`).
- Import/Export: a tick per `M.PSS_IO_PARTS` (`M.PSS_IOOn`, `M.PSS_IOSet`, `M.PSS_IOPartOff`), mode drop-down (`M.PSS_IO_MODES`, `M.PSS_IOMode`, `M.PSS_IOSetMode`), Export (`M.PSS_ExportText` gives the string and subtitle -> `ns.CopyText`), Import (`ns.ImportText` -> `M.PSS_ImportStart`: an error, or a Replace confirm then the apply function; results to chat via `M.ShowMsg`).
- Listens: `OPTION_CHANGED` -> `ns.RefreshTab()` when either page is visible.

## 15. PSS_Window.lua (537 lines): the window, tabs, back/forward, Escape
| Export | What |
| --- | --- |
| `M.PSS_OpenWindow(show)` | builds on first call; toggles; restores the place; `M.PSS_UIFontChoices()`; Show + Raise |
| `M.PSS_WindowDock(host, x)`, `M.PSS_WindowUndock()` | dock beside FriendsFrame / SocialUIFrame |
| `ns.TabBuilders`, `ns.TAB_ROW_Y`, `ns.RefreshTab()` | tab builders; tab row y; refresh the shown page |
| `ns.NavRecord()`, `ns.NavBack()`, `ns.NavForward()`, `ns.NavUp()`, `ns.ShowEventsTab(prepare)` | back/forward and Escape stepping |

- Frames (first open): `PSS_Window` (960 x 494, strata `M.PSS_FrameStrataName()`, movable; place saved via `M.PSS_SetUIPlace`), `ns.NewFrameArt` (Classic/Modern) or the Dark frame and close, `chrome` with the title "Pour Social Score" (the only title with the addon name), the rock band and streaks in Modern, `PSS_WindowEscape`, six tabs and six pages, back/forward buttons and the breadcrumb line. `ResetTab` is a file local (W1: `ns.ResetTab` and the pages' "later 3.4.0 build" note are gone); `UpdateNav` reuses its tables (G25).
- Events: `ns.ListenStart()` on show (then every `page.stale()`, `ns.RefreshTab()`, `GLOBAL_MOUSE_UP` for mouse buttons 4/5); on hide `ns.ListenStop()`, each page's `release()` (only Events defines one), `M.PSS_RequestGC("window closed")`. `OPTION_CHANGED` is registered once at build and never removed (look, font and strata repaint).

| Backend call | Defined in |
| --- | --- |
| `M.PSS_UI_TABS`, `M.PSS_UI_EVENTS_TAB`, `M.PSS_UIPlace`, `M.PSS_SetUIPlace`, `M.PSS_UITab`, `M.PSS_SetUITab`, `M.PSS_UIFontChoices`, `M.PSS_NavNew` | Lib/ViewNav |
| `M.PSS_FrameStrataName` | core/Options |
| `M.PSS_RequestGC` | core/Perf |
| `M.Events.Register`, `M.PSS_OpenUI` | core |

## 16. Core openers: PourSocialScore/PSS_BlizzardUI.lua (352 lines)
| Item | What |
| --- | --- |
| `M.PSS_OpenUI(show)` | `M.PSS_ExpireEntries()`, `M.PSS_Need("GUI")` (Libraries first), `M.PSS_OpenWindow(show)` |
| Friends/Social dock | `HookScript("OnShow")` (only with `openWithFriends`: expiry, `PSS_Need("GUI")`, `M.PSS_WindowDock(host, x)`), `HookScript("OnHide")` (`M.PSS_WindowUndock()` when the GUI is loaded) |
| Addon Compartment | Retail only: `AddonCompartmentFrame:RegisterAddon{..., func = M.PSS_OpenUI}` |
| Also in this file | StaticPopups `PSS_REASON`, `PSS_PARTYWARN` (Blizzard look in every look); LFG hooks; `M.PSS_UnitMenuPlayer`; `M.PSS_HookFunctions` |

Other callers of `M.PSS_OpenUI`: Libraries `PSS_Commands.lua` (`/pss` alone or `gui`/`ui`/`eui`). No key binding opens the window.

---

## (a) Front end to back end, per tab
Format: element/action -> GUI -> Libraries -> core setter/data.

### Players
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| List rows, sort, search | `Resort`, `DrawRow` | `PSS_PlayerListNew` (-> PlayerRows `PSS_SortPlayers`), `PSS_PlayerRow`, cell texts | `M.PSS_List()` records, `playerData` |
| Add Player / Player Search -> picker | buttons, `ns.NewPicker` | `PSS_PlayerAddFromText`, `PSS_PlayerSearchFromText`, `PSS_PlayerPicker*`, `PSS_PickerCells/Toggle/TickAll` | `PSS_AddPlayer`, `PSS_PlayerSearch` (SendWho) |
| Prune | `ns.Confirm` with number | `PSS_PruneText`, `PSS_PruneNote`, `PSS_PruneApply` | `M.PruneIgnoreList` |
| Expiry / Note | `ns.OnCommit` | `PSS_PlayerCommitExpiry`, `PSS_PlayerCommitNote` | `PSS_SetExpiry`, `PSS_SetNote` + `PSS_PlayersChanged` |
| W I G P C, Blizzard tick | `ns.NewAllowedBoxes`, check | `PSS_PlayerToggleAllowed`, `PSS_PlayerToggleBlizzard` | `PSS_SetPlayerSetting`, `PSS_SetBlizzardIgnore` |
| Exceptions | `ns.NewExceptions` | `PSS_ExceptionState`, `PSS_SetException` | `PSS_SetOpt(key, "person", v, target)` |
| Add Guild | button | `PSS_PlayerGuildState`, `PSS_PlayerAddGuild` | `PSS_AddGuild` |
| Remove, Reset Block History | buttons | `PSS_PlayerRemoveText`; PlayerRows `PSS_RemovePlayerAt` | `PSS_DelIgnore`; `PSS_ResetPlayerBlockHistory` (straight from GUI) |
| Summary, history, totals | `ns.ShowPlayerDetail`, `ns.ShowPlayerCounts` | `PSS_PlayerSummarySpec`, DetailQuery, TotalsQuery | counters; Logging only on the gate click |

### Guilds
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| Grouped list, open a heading | `Resort`, `DrawRow` | `PSS_GuildListNew` (-> GuildQuery `PSS_GuildRows`), `PSS_SetGuildGroupOpen` | rules, `PSS_GuildMemberCount`, `PSS_ManagedGroupActive` |
| Add / Exclude / Guild Search | entry rows, picker | `PSS_GuildAddFromText`, `PSS_GuildExcludeFromText`, `PSS_GuildSearchFromText`, `PSS_GuildPicker*` | `PSS_AddGuild`, `PSS_AddGuildExclusion`, `PSS_GuildSearch`, `PSS_SaveGuildSearch` / `PSS_SaveGuildExclusions` |
| Scan All / Scan / Custom Scan / Fields | buttons | `PSS_GuildScanNow`, `PSS_GuildCustomScan`, `PSS_GuildCommitFields`, WhoisHarvest `PSS_ScanAll` | `PSS_ScanGuild`, `PSS_SetGuildScanFields` |
| Guild and member W I G P C, exceptions | boxes | `PSS_GuildToggleAllowed`, `PSS_MemberToggleAllowed`, `PSS_GuildToggleException`, `PSS_MemberToggleException` | `PSS_SetGuildBlock`, `PSS_SetMemberBlock`, `PSS_SetOpt` |
| Members view, member note, remove, Add Guild | `mview`, member body | `V:OpenMembers/CloseMembers/MResort`, `PSS_MemberCells`, `PSS_MemberPaneView`, `PSS_MemberCommitNote`, `V:RemoveMember`, GuildQuery `PSS_AddMembersGuild` | `PSS_SetMemberNote`, `PSS_RemoveGuildMember`, `PSS_AddCapturedGuild` |
| Remove Guild | confirm | `PSS_GuildRemoveText`, `PSS_GuildRemove` | `PSS_RemoveGuildNow` |
| Managed list rule on/off, open | group body, menu | `PSS_GroupToggleRule`, `PSS_GroupToggleOpen`, `PSS_GuildSetAllRules` | `PSS_SetManagedGroupActive` |
| Reset history | buttons, menu | (none) | `PSS_ResetGuildBlockHistory`, `PSS_ResetMemberBlockHistory` (straight from GUI) |
| Pane text and pies | `ShowGuild`, `ShowGroup`, `ShowExcl`, `ShowMember`, `ShowCounts` | `PSS_GuildPaneView`, `PSS_GuildGroupView`, `PSS_GuildExclView`, `*SummarySpec`, `V:GuildCounts`, `PSS_GroupRecentByCat` | counters, history |

### Filters
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| List, sort, search | `Resort`, `DrawRow` | `PSS_FilterListNew`, `PSS_FilterRow`, `PSS_FilterRowCells` | filter arrays, `PSS_FilterCounts` |
| On tick | OnClick | (none) | `PSS_SetFilterActive` (straight from GUI) |
| Save, Copy, New, Remove | buttons | `PSS_FilterSave`, `PSS_FilterCopy`, `PSS_FilterNew`, `PSS_FilterRemove` | `PSS_SaveChatFilter` (keeps id), `PSS_CopyChatFilter`, `PSS_AddCustomFilter` (new id), `RemoveChatFilter` |
| Reset Count / history / defaults | buttons, menu | (none) | `PSS_ResetFilterCount`, `PSS_ResetFilterHistory`, `M.ResetSpamFilters` (straight from GUI) |
| Test, link converter, link insert | boxes, hook | `PSS_FilterTestText`, `PSS_ConvertChatLink` | `PSS_IsSecret` |

### Events
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| Open from a pie, View Events, pane history | `ns.OpenEvents` -> `ns.ShowEventsTab` | `view:Open(spec, opts)` | (none until Refresh) |
| Read, filter, sort | `Refresh`, `Apply` | `view:Refresh` (spec `read` loads Logging), `PSS_EventCells` | `History`, `PSS_LoggingDB` |
| Reset Block History | button | `view:ResetText`, `view:DoReset` -> spec `reset` | the matching core reset |
| Close / tab change | `pg.release` | `view:Release()` | (none) |

### Options and Import/Export
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| Rows, search | `OptionRow`, `Layout` | OptionsView `PSS_OptGroups`, `PSS_OptLabel`, `PSS_OptTip`, `PSS_OptMatches` | `PSS_OPTIONS` |
| Tick, number, choice | controls | `PSS_OptSetNumber`, `PSS_OptSetField*`, `PSS_OptChoiceText` | `PSS_SetOpt` (OPTION_CHANGED; the window repaints) |
| Export | `ns.CopyText` | `PSS_ExportText` -> ImportExport | reads every store |
| Import | `ns.ImportText`, `ns.Confirm` | `PSS_ImportStart` -> `PSS_ApplyImport` | setters plus direct writes (C section 1) |

## (b) Open / close lifecycle
1. `/pss` -> core stub loads Libraries -> `M.PSS_SlashPSS` -> `M.PSS_OpenUI()`. The Addon Compartment calls `M.PSS_OpenUI()`; Friends/Social OnShow with `openWithFriends` calls `M.PSS_WindowDock`.
2. `M.PSS_OpenUI(show)`: expiry, `M.PSS_Need("GUI")` (Libraries then GUI), `M.PSS_OpenWindow(show)`.
3. GUI load: each tab file makes its list-state object and queues its `ns.Listen` entries. No frames.
4. First open: `Build()` makes the window, registers `OPTION_CHANGED` for good, then builds only the saved tab (`M.PSS_UITab()`, never Events).
5. Every open: place restored, font choices, `Show()` -> `ns.ListenStart()`, each page's `stale()`, `ns.RefreshTab()`, `GLOBAL_MOUSE_UP`; `Raise()`.
6. Close: `GLOBAL_MOUSE_UP` dropped, `ns.ListenStop()`, Events' `release()`, `M.PSS_RequestGC("window closed")` (runs at once when quiet, else at the next wake event).
7. Kept after close: every built frame, fonts, painters, the tab list-state objects, the pane History lists' last lines, Libraries caches and session ticks, the `OPTION_CHANGED` listener.

## (c) Kit catalogue (who uses what)
| Builder (file) | Used by |
| --- | --- |
| `ns.NewText`, `ns.Font` (Skin) | every file |
| `ns.NewHeading`, `ns.NewButton`, `ns.NewCheck`, `ns.NewEditBox`, `ns.NewNumberBox`, `ns.OnCommit`, `ns.NewSearchBox` (Kit) | tabs, Detail, History, Popups, Window |
| `ns.NewPanel`, `ns.NewScrollFrame` (Kit) | Players, Guilds, Filters, Options, Popups, Rows, Window |
| `ns.NewTextArea` (Kit) | Filters (filter box), Popups (text popup) |
| `ns.NewTab` / `ns.SetTabSelected` (Kit) | Window, Detail |
| `ns.NewRows` (Rows) | Players, Guilds, Filters, Events, History, the picker |
| `ns.NewPicker` (Rows) | Players, Guilds |
| `ns.NewPie` (Pie) | Detail |
| `ns.NewDropdown` (Menu) | Events, Options |
| `ns.ContextMenu` / `ns.RowMenu` (Menu) | Players, Guilds, Filters, History |
| `ns.Tip` / `ns.TipOn` / `ns.HideTip` (Tooltip) | Rows, Pie, Detail, History, tabs, Window |
| `ns.Confirm`, `ns.CopyText`, `ns.ImportText` (Popups) | Players, Guilds, Filters, Events, History, Options |
| `ns.NewFrameArt` (Skin) | Window, Popups |
| `ns.NewDetailPages`, `ns.NewSummary`, `ns.NewTotals`, `ns.NewTypePie`, `ns.NewExceptions` (Detail) | Players, Guilds, Filters |
| `ns.NewLine`, `ns.NewLabel`, `ns.NewStrip`, `ns.NewAllowedBoxes` (Detail) | Detail, Players, Guilds, Filters |
| `ns.NewHistory`, `ns.SenderMenu` (History) | Players, Guilds, Filters; SenderMenu also Events |

Harness: `tools/harness/kit_page.lua` (kit preview), `check_tui.lua` (kit in every look), `tui_compare.sh` / `tui_tour.lua` (window in all three looks), `check_viewfns.lua`, `check_w2b.lua` (W2 view functions).

## (d) Popups and menus
| Popup (frame) | Title | Opened by | Accept -> |
| --- | --- | --- | --- |
| `ns.Confirm` (`PSS_Confirm`) | Remove Player? | Players Remove / menu; sender menu | `PSS_RemovePlayerAt` / `PSS_SenderRemove` |
| | Add Player? | Player Search, nobody found | `PSS_PlayerAddAnyway` |
| | Prune Players? | Players Prune | `PSS_PruneApply(days)` |
| | Remove Guild? / Remove Member? / Exclude Guild? | Guilds | `PSS_GuildRemove` / `V:RemoveMember` / `PSS_GuildExcludeAnyway` |
| | Remove Rule? / Reset Chat Filters? | Filters | `PSS_FilterRemove` / `M.ResetSpamFilters` |
| | Reset Block History? | Events | `view:DoReset` |
| | Replace on Import? | Import in Replace mode | the apply function from `PSS_ImportStart` |
| `ns.CopyText` (`PSS_TextPopup`) | Copy Event; Export; Rules Not Used | Events, Export, `/pss export unused` | read only |
| `ns.ImportText` (`PSS_TextPopup`) | Import | Import button | `PSS_ImportStart` |
| Core StaticPopups (not GUI) | `PSS_REASON`, `PSS_PARTYWARN` | core | Blizzard look always |

Right-click menus are data from Libraries `PSS_RowMenus.lua` drawn by `ns.RowMenu`.

## (e) Escape handling
- Popups and our menu: `ns.EscapeCloses(frame, name)` (`PSS_Confirm`, `PSS_TextPopup`, `PSS_Menu`), after each frame's OnHide is set.
- Window: the helper `PSS_WindowEscape` is in `UISpecialFrames`, shown with the window; its OnHide: `ns.EscapeTaken()` (a popup or menu took this Escape) -> re-show; else `ns.NavUp()` (picker, members view, Events back to its tab) -> re-show; else hide the window.
- Mouse buttons 4 / 5 over the window: `ns.NavBack` / `ns.NavForward`.

## Notable findings (GUI, open)
1. Only the Events tab releases data on close; Players, Guilds and Filters keep their list states and their History panes' last lines.
2. `OPTION_CHANGED` is registered once in `Build()` and never unregistered (deliberate).
3. Painters, Summary and type pie lists, and History lists only grow (bounded by widgets built).
4. GUI still calls some core setters directly (`PSS_ResetPlayerBlockHistory`, `PSS_ResetGuildBlockHistory`, `PSS_ResetMemberBlockHistory`, `PSS_SetFilterActive`, `PSS_ResetFilterCount/History`, `M.ResetSpamFilters`, `PSS_SetOpt`) and reads `M.PSS_MemberGuildName`: allowed, uneven with the Libraries-wrapped paths.
5. The harness stub does not wrap text: wrapped lines (Guilds `FitLines`, the Players rule page lines) can only be proven in game.
