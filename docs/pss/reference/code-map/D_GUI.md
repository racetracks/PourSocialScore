# PourSocialScore_GUI and the core openers: reference map (main, 3.4.1.38)

Folder `PourSocialScore_GUI` (LoadOnDemand; `## Dependencies: PourSocialScore, PourSocialScore_Libraries`). 15 files, 5639 lines, load order: Skin, Kit, Tooltip, Menu, Popups, Rows, Pie, Detail, History, Players, Guilds, Filters, Events, Options, Window. Private file table `ns` (the addon's `...` table); `ns.M = M` (set in Skin). No SavedVariables; no frames at load except the font objects created lazily by `ns.Font`. Looks: `ns.Skin()` returns `"blizzard"` (Classic, uiSkin 0), `"dark"` (1) or `"modern"` (2) from `M.PSS_UISkin()` (Libraries `PSS_ViewNav.lua`). `ns.IsModern()` = skin modern AND the client has the Modern atlases (else Classic paint). Backend file names below: `core/X` = `PourSocialScore/PSS_X.lua`, `Lib/X` = `PourSocialScore_Libraries/PSS_X.lua`.

## 1. PSS_Skin.lua (339 lines): looks, fonts, primitives, Escape, listeners
Purpose: the paint system (look, fonts, painters), pixel-exact primitives, frame art, Escape helper and the core-event listener registry.

| Export | Signature | What |
| --- | --- | --- |
| `ns.M` | table | `PourSocialScore_NS.M` |
| `ns.DARK` | table | Dark palette `{r,g,b,a}`: window, titleBar, border, close, closeHover, text, disabledText, panel, inset, control, box, checkBorder, hover, tab, tabWash, thumb, tip, tipBorder, tipText |
| `ns.TITLE_H` | 25 | title bar height |
| `ns.Skin()` | -> "blizzard"/"dark"/"modern" | cached `M.PSS_UISkin()` |
| `ns.IsDark()` | -> bool | skin == dark |
| `ns.HasModernArt()` | -> bool | cached check that all 8 `MODERN_ART` atlases exist (128-RedButton-Left, common-button-tertiary-normal/-pressed, friends-card-default, perks-divider-short, checkbox-minimal, checkmark-minimal, common-searchbar-a) |
| `ns.IsModern()` | -> bool | skin modern and `HasModernArt()` (fallback rule 3) |
| `ns.AtlasWidth(atlas, h)` | -> w | width keeping the atlas ratio (`C_Texture.GetAtlasInfo`) |
| `ns.Accent()` | -> r,g,b | `M.PSS_UIAccent()` (class colour), else the look's own (dark teal / gold) |
| `ns.OnPaint(fn)` | fn(dark) | registers a painter, runs it now and on every `ns.Repaint` (painters list only grows) |
| `ns.Font(size, blizz)` | -> FontObject | shared `CreateFont("PSS_FontN")` per size+Blizzard object; "Accent" = GameFontNormal face in accent colour; Dark = `Fonts\ARIALN.TTF`, white/grey, no shadow; picked `uiFont` (`M.PSS_UIFontPath()`) replaces the face if loadable |
| `ns.Repaint()` | | re-reads skin, clears the art cache, repaints every font then every painter |
| `ns.NewText(parent, size, blizz, layer)` | -> FontString | FontString on `ns.Font` |
| `ns.OnePixel(frame)` | -> units | one physical pixel at the frame's effective scale (`GetPhysicalScreenSize`) |
| `ns.NoSnap(tex)` | | `SetSnapToPixelGrid(false)`, `SetTexelSnappingBias(0)` |
| `ns.PixelBorder(frame, color)` | -> holder | child frame with 4 one-pixel strips; `holder:SetColor()`; relayouts OnSizeChanged |
| `ns.Fill(frame, color, sub, layer)` | -> tex | flat colour texture, BACKGROUND -6 default |
| `ns.HasAtlas(name)` | -> bool | `C_Texture.GetAtlasInfo(name) ~= nil` |
| `ns.Own(region)` | -> region | marks a texture as ours (weak-keyed set) so `ShowArt` never fades it |
| `ns.ShowArt(frame, dark, keep)` | | fades (alpha 0) every template texture of the frame that is not `Own`/`keep`; restores its saved alpha otherwise |
| `ns.NewFrameArt(parent)` | -> frame or nil | first of `ButtonFrameTemplate`, `PortraitFrameTemplate`, `BasicFrameTemplateWithInset` that creates; portrait, CloseButton, TitleText, Inset hidden; adds `f.pssBlack` (shown in Modern, `f.Bg` alpha 0 in Modern) |
| `ns.Round(v)` | -> int | floor(v+0.5) |
| `ns.EscapeCloses(f, name)` | | appends f to its list and `name` to `UISpecialFrames`; HookScript OnHide stamps `GetTime()` |
| `ns.EscapeTaken()` | -> bool | a registered popup/menu is shown, or one closed this same frame time |
| `ns.Listen(event, fn)` | | adds a core-event listener (registered now if listening) |
| `ns.ListenStart()` / `ns.ListenStop()` | | `M.Events.Register` / `M.Events.Unregister` every listener (window show / hide) |

- Frames: none at load; `CreateFont` objects `PSS_Font1..N` on first `ns.Font`.
- Backend: `M.PSS_UISkin`, `M.PSS_UIAccent`, `M.PSS_UIFontPath` (Lib/ViewNav), `M.Events.Register/Unregister` (core/Events).
- Blizzard: `C_Texture.GetAtlasInfo`, `GetPhysicalScreenSize`, `CreateFont`, `UISpecialFrames` (append only, J2 exception), `ButtonFrameTemplate_HidePortrait`, `GameFontNormal`/`GameFontHighlight` objects read.
- Stale: the header comment still says "blizzard" is the default and Modern "paints as Blizzard until built" (Modern is the default from 3.4.0-dev008_4 and is built).

## 2. PSS_Kit.lua (485 lines): the control kit
| Export | Signature | Looks |
| --- | --- | --- |
| `ns.NewHeading(parent, text)` | -> FontString, size 13 | accent colour in every look |
| `ns.NewButton(parent, text, w, onClick)` | -> Button 22 high, `UIPanelButtonTemplate` | Classic: template. Dark: template art faded, `DARK.control` fill, white hover, pixel edge, white label. Modern: `b.pssPrimary == true` -> red three-slice `128-RedButton-Left/_Center/Right` (+ `-Pressed`, `-Disabled`, `-Highlight`); else `common-button-tertiary-normal/-pressed` plate with ADD hover. `b.pssParts = {fill, edge, red, tertiary}`, `b.pssPaint` |
| `ns.NewCheck(parent)` | -> CheckButton 24x24, `UICheckButtonTemplate` | Dark: box inset 4 `DARK.box` + `checkBorder` edge, template tick tinted accent. Modern: `checkbox-minimal` box, `checkmark-minimal(-disabled)` tick following `SetChecked` (hooksecurefunc on our own button) |
| `ns.NewEditBox(parent, w, maxLetters)` | -> EditBox 20 high, `InputBoxTemplate` | `SkinBox`: Dark fill+edge; Modern `common-searchbar-a`; font `ChatFontNormal` |
| `ns.NewNumberBox(parent, w)` | numeric, centred | as edit box |
| `ns.OnCommit(e, commit, refresh)` | | commit(text) once on Enter or focus loss (busy guard), Escape refreshes |
| `ns.NewSearchBox(parent, w, hint, onChange)` | -> EditBox, 128 letters | magnifier `common-searchbar-icon-a` (Modern) / `common-search-magnifyingglass` (others), hint text (alpha 0.4), clear button `common-search-clearbutton`; Escape clears; `eb.hint`, `eb.clear` |
| `ns.NewPanel(parent, inset)` | -> Frame | Classic: `InsetFrameTemplate` art. Dark (or no template): `DARK.panel`/`DARK.inset` fill + edge. Modern: inset -> `friends-card-default` card; page -> `perks-divider-short` top divider |
| `ns.NewScrollFrame(parent)` | -> ScrollFrame | `ScrollFrameTemplate`, else `UIPanelScrollFrameTemplate`; Dark fades arrows/track, 4 px `DARK.thumb` strip on the thumb |
| `ns.NewTab(parent, text, onClick)` | -> Button 24 high | first of `PanelTopTabButtonTemplate`, `TabButtonTemplate` (its OnShow/OnEvent cleared, events unregistered so it does not resize); Dark/no template: `DARK.tab` plate, wash + accent underline when selected, label alpha 0.7 unselected. Modern: `common-button-tertiary-normal` side plate, ADD lit when selected, hover 0.3 |
| `ns.SetTabSelected(tab, on)` | | sets `tab.pssSelected`, shows Left/Middle/Right vs *Active art (Classic), centres the label (not Blizzard's PanelTemplates offsets) |

- Frames: none at load; every widget is built by its tab on first open.
- Backend: none directly (via Skin).
- Blizzard atlases: as listed; templates `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate`, `InsetFrameTemplate`, `ScrollFrameTemplate`/`UIPanelScrollFrameTemplate`, `PanelTopTabButtonTemplate`/`TabButtonTemplate`.
- Note: the header lists `ns.NewScrollFrame` etc. but not `NewNumberBox` modern art; `ns.NewRows`, `ns.NewDropdown`, `ns.ContextMenu`, `ns.Tip`, `ns.Confirm` live in other files (below).

## 3. PSS_Tooltip.lua (96 lines): tooltips
| Export | Signature | What |
| --- | --- | --- |
| `ns.Tip(owner, text)` | text or fn() -> text | Classic/Modern: `GameTooltip` (`IsForbidden()` checked, `ANCHOR_TOP`, wrapped white). Dark: our `PSS_Tooltip` frame (built on first use, strata TOOLTIP level 200, `DARK.tip` fill, `tipBorder` edge, 10 px centred text max 250 wide, 4 px above the owner, 0.25 s alpha fade in/out animations) |
| `ns.HideTip()` | | hides GameTooltip if we own it; fades ours out |
| `ns.TipOn(frame, owner, text)` | | SetScript OnEnter/OnLeave to Tip/HideTip |

Frames: `PSS_Tooltip` (lazy, one). Backend: none.

## 4. PSS_Menu.lua (360 lines): drop-downs and right-click menus
A menu is a build function `build(m)` filling a plain list: `m:Button(text, fn)`, `m:Radio(text, isOn, fn)`, `m:Check(text, isOn, fn)` (stays open), `m:Divider()`, `m:Title(text)`; `isOn` may be a function.

| Export | Signature | What |
| --- | --- | --- |
| `ns.NewDropdown(parent, w, build)` | -> Frame 24 high; `dd:SetLabel(text)`; `dd.blizz`, `dd.dark`, `dd.label` | Blizzard `DropdownButton` from `WowStyle1DropdownTemplate` (`SetupMenu` + `OverrideText`/`SetDefaultText`) in Classic/Modern; our Dark button (`DARK.control` fill, `checkBorder` edge, two-line chevron) opening our list in Dark or when the template is missing |
| `ns.ContextMenu(by, build)` | | Classic/Modern with `MenuUtil.CreateContextMenu`: Blizzard context menu; else our compact list at the cursor, as wide as its longest entry (min 100) |
| `ns.RowMenu(by, entries, run)` | | turns Libraries' entry list (`PSS_RowMenus.lua`: `{kind=title/divider/check/button, text, on, act, arg}`) into a ContextMenu; each click calls `run(act, arg)` |
| `ns.CloseMenu()` | | hides our list |
| `ns.DrawMenu()` | | redraws our list if shown |

- Our list: one shared frame `PSS_Menu` (UIParent, FULLSCREEN_DIALOG level 200, fill `{0.103,0.095,0.088,0.98}`, edge white 0.2), built on first use, slot pool `menu.slots` (Buttons, reused), mouse-wheel scroll with a 4 px thumb, **height capped at 200** (`MAX_H`; G27 will grow it to content). Two sizes: list (26 px items, 13 font) and compact (20 px, 12). Full-screen click catcher (Button on UIParent, level 199) closes it. `ns.EscapeCloses(menu, "PSS_Menu")`.
- Blizzard: `MenuUtil.CreateContextMenu`, root `CreateButton/CreateRadio/CreateCheckbox/CreateDivider/CreateTitle`, `MenuResponse.Refresh` (keeps a tick menu open), `SetScrollMode(400)` past 20 entries, `GetCursorPosition`.
- Backend: none directly (entries come from Libraries through the tab files).

## 5. PSS_Popups.lua (264 lines): the window's own popups
| Export | Signature | What |
| --- | --- | --- |
| `ns.Confirm(opts)` | `{title, text, accept, cancel, onAccept(n), onCancel, number, numberNote(n)}` -> frame | `PSS_Confirm` (390x176, grows with the text, +52 with a number box); `number` shows `ns.NewNumberBox` (Enter accepts) and a live note; any hide that is not Accept calls `onCancel` |
| `ns.CopyText(opts)` | `{title, subtitle, text}` | `PSS_TextPopup` read only: text re-set on user edits, all selected, one Close button |
| `ns.ImportText(opts)` | `{title, subtitle, accept, onAccept(text)}` | same frame, editable, Import + Cancel |

- Frames: `PSS_Confirm`, `PSS_TextPopup` (one each, built on first use; UIParent, FULLSCREEN_DIALOG level 100, toplevel, centred +60). Each has a `chrome` child raised above the frame art's NineSlice (+10) for the title, and a full-screen `dim` Button (Dark only; click cancels). Text popup: `ns.NewPanel(inset)` + `ns.NewScrollFrame` + multi-line EditBox (440 wide, keeps the cursor in view).
- Looks: Classic/Modern: `ns.NewFrameArt` (black under it in Modern), title 13 `GameFontNormal` in the title bar (-6); buttons via `PopupButton` (`ns.NewButton`, `pssPrimary` = accept -> Modern red button). Dark (or no frame template): flat `{0.077,0.068,0.058}` fill, white 0.15 edge, dimmed screen, title 16 lower (-20), accept edge and label in the accent, text alpha 0.53.
- Escape: `ns.EscapeCloses(confirm, "PSS_Confirm")`, `ns.EscapeCloses(f, "PSS_TextPopup")`, both after their OnHide scripts.
- Blizzard globals read: `OKAY`, `CANCEL`, `CLOSE`. Backend: none (callers pass Libraries text and callbacks).

## 6. PSS_Rows.lua (308 lines): the virtual row list
`ns.NewRows(parent, spec)` -> list. spec: `rowH` (20), `cols` `{key, text, width?, justify?, tip?, sort=false?}` (one column without width fills), `sort(key)`, `draw(row, i)`, `click(row, i, button)`, `enter(row, i)`, `emptyClick()`, `links` (hyperlinks in cells), `fontSize`, `height`.

| Method | What |
| --- | --- |
| `list:SetCount(n)` | sets the range (scroll child height n*rowH), clamps the scroll, redraws |
| `list:Redraw()` | `draw(row, first+i)` for the rows on screen only; empty text when count 0 |
| `list:Top()` | scroll to the top |
| `list:SetSort(key, asc)` | header label "Text ^"/" v" in the accent; others gold (Classic/Modern) or white 0.85 (Dark) |
| `list:Select(test)` | accent wash (0.25) on rows whose index passes |
| `list:SetEmptyText(text)` | grey line shown when empty |
| `list:Layout()` / `list:MakeRow(i)` | makes only the rows that fit (pool grows with height, never shrinks; extra rows hidden) |

- Frames: header Frame (20 high) of header Buttons (`ns.TipOn` for `tip`), `ns.NewScrollFrame` with a 1-px-wide content child (rows do not scroll; `OnVerticalScroll` hook changes `first`), row Buttons (Left/Right clicks) with one-line FontString cells.
- Looks: hover Classic/Modern `Interface\QuestFrame\UI-QuestTitleHighlight` ADD; Dark accent 0.12; header dark bar in Dark only; selected accent 0.25 in all.
- Links (`spec.links`): `SetHyperlinksEnabled`; click -> `SetItemRef` (pcall, skipped `InCombatLockdown()`); hover -> `GameTooltip:SetHyperlink` only for the `TIP_LINKS` allow list (baseline H8); a row click within 0.05 s of a link click is ignored.
- Backend: none.

## 7. PSS_Pie.lua (140 lines): ring chart
`ns.NewPie(parent, size, onClick)` -> pie; `pie:Set(slices)` with `{value, r, g, b, text, draw, within}`; `pie.tip = function(i) -> text`; `pie:Paint()`, `pie:SliceAt()`.
- A Button with 60 `CreateLine` segments (ring 24% of size, slight overlap); centre text shows the hovered slice's count; a slice's `within` set lights with it; empty = faint ring.
- **OnUpdate only while the mouse is over it** (OnEnter sets, OnLeave clears; the approved C3 override in PSS 02 section 12). Click -> `onClick(slice index)` (`GetCursorPosition` + `math.atan2`).
- Same in all three looks. Backend: none.

## 8. PSS_Detail.lua (427 lines): detail pane parts shared by Players, Guilds, Filters
| Export | Signature | What |
| --- | --- | --- |
| `ns.DETAIL_PAGES` | `{summary, history, rule}` | page keys and labels ("Summary", "Event History", "View/Edit Rule") |
| `ns.NewDetailPages(body, top, kind)` | -> dp | three page Frames + a bottom bar of three `ns.NewTab` buttons (equal widths); `dp:Select(key)` (remembers the pick per kind "players"/"guilds"/"filters" for the session), `dp:Limit(only)` (e.g. `{rule=true}` disables the others) |
| `ns.NewSummary(page, tabPage, top, size)` | -> sm; `sm:Set(spec)`, `sm:Refresh()`, `sm:Open(key)` | period pie (116 default) + a tick box per period with colour/label/count + "Stored:" line + "View Events" button; built on first visible Refresh; page OnShow hook refreshes |
| `ns.NewTypePie(parent, top, size, tabPage)` | -> tp; `tp:Set(counts, title, specFn, id)` | all-time by type pie (84) with up to 7 tick keys |
| `ns.NewTotals(pane, tabPage, kind, title, hint, allSpec)` | -> tt; `tt:Show(guildRows)`, `tt:Hide()` | a list's totals when nothing is selected: heading, info line, Summary (84) and TypePie |
| `ns.NewExceptions(parent, x, y, width, onChange)` | -> ex; `ex:Set(target, scope, who, parentOpts)`, `ex.frame`, `ex.height` | a tick per override option, two to a row, "(exception)" labels, tips |

- Shared module state (session): `picked` page per tab, `summaries` and `typePies` lists (every pie is redrawn when a period or type tick changes; `RedrawAll`). These lists only grow.
- Opening Events: a slice click or View Events calls `ns.OpenEvents(tabPage, spec, {period, cats})` (defined in PSS_Events.lua); hidden when `ns.OpenEvents` is nil.
- Looks: no per-look code (kit parts paint themselves; pies the same in all looks).

| Backend call | Defined in |
| --- | --- |
| `M.PSS_SummaryValues`, `M.PSS_PERIODS`, `M.PSS_PeriodSlices`, `M.PSS_PeriodTip`, `M.PSS_PeriodOn`, `M.PSS_SetPeriodOn`, `M.PSS_WidestPeriodOn`, `M.PSS_TypesOn`, `M.PSS_TypeSlices`, `M.PSS_SetTypeOff`, `M.PSS_TotalsView`, `M.PSS_OverrideOptions`, `M.PSS_ExceptionState`, `M.PSS_ExceptionText`, `M.PSS_ExceptionTip`, `M.PSS_ExceptionHeading`, `M.PSS_SetException` (-> core `M.PSS_SetOpt`) | Lib/DetailQuery |
| `M.PSS_StoredText` | Lib/EventsQuery |
| `M.PSS_History` (local `History`, held but unused here) | core/ChatHistory |

## 9. PSS_History.lua (194 lines): block history list in the Players and Guilds panes
| Export | Signature | What |
| --- | --- | --- |
| `ns.NewHistory(body, y, opts)` | opts `{names, empty, open(id)}` -> hv | a row of type tick boxes (one per `M.PSS_EVENT_TYPES`, shared ticks) over an `ns.NewRows` list (rowH 16, font 11; Time 118, Type 48, [Name 86], Message fill) and a gate button "Show Block History (n)" |
| `hv:Set(id, total, read, fresh)` | | reads `read(id)` only when id/total/Logging-ready changed; if Logging is not loaded and total > 0 shows the gate instead (never loads Logging for a row click) |
| `hv:Clear()` | | forget the key so the next Set reads again |
| `ns.SenderMenu(row, name)` | | right-click on a blocked line: `ns.RowMenu(row, M.PSS_SenderMenu(name), SenderAct)`; also used by the Events tab |

- Gate click: `M.PSS_LoadLogging()` then re-reads. Double left-click on a line (`M.PSS_DoubleClick`) calls `opts.open(id)` (Events tab). Sender remove asks `ns.Confirm{title="Remove Player?"}`.
- Module state: `lists` (every hv, for shared tick refresh; grows per pane built).
- Backend: `M.PSS_EVENT_TYPES`, `M.PSS_EventType` (Lib/EventsQuery); `M.PSS_HistHidden`, `M.PSS_SetHistHidden`, `M.PSS_HistFilter` (Lib/DetailQuery); `M.PSS_DoubleClick` (Lib/ViewNav); `M.PSS_SenderMenu`, `M.PSS_SenderAdd`, `M.PSS_SenderRemove`, `M.PSS_SenderRemoveText` (Lib/RowMenus); `M.PSS_LoadLogging`, `M.PSS_LoggingReady`, `M.PSS_History` (`History.UNKNOWN`, `History.CAT_COLOR`) (core/ChatHistory); `M.removeServer` (core/Globals). Blizzard: `date`.

## 10. PSS_Players.lua (573 lines): Player Ignore List tab
Purpose: list (search, sort, Add Player, Player Search, Prune), right-click row menu, detail pane (Summary / Event History / View/Edit Rule), /who results picker. Builder `ns.TabBuilders.players(pg)` -> `Refresh`.
- Exports: `ns.TabBuilders.players`, `ns.ShowPlayerDetail(newEntry)` (redraws the pane; totals when nothing selected). Page hooks set: `pg.navClose`, `pg.navUp` (close the picker), `pg.navReset` (picker closed, selection cleared), `pg.stale` (mark dirty, re-check /who cooldown), `pg.select`, `pg.search`, `pg.count`, `pg.add`, `pg.addButton`, `pg.searchButton`, `pg.pruneButton`, `pg.list`, `pg.pane`, `pg.picker`.
- Module state: `V = M.PSS_PlayerListNew()` (made at file load: sort key, find, index), `sel` (selected entry), `rowBuf` (one table every row is read into), `pickCells`.
- Frames (on first open of the tab): search box, count text, Add edit box (64 letters, "Name-Realm" hint), buttons Add Player, Player Search, Prune; `pane` = `ns.NewPanel(inset)` 380 wide with `ns.NewTotals`, heading, `ns.NewDetailPages(-28, "players")`; Summary page: counts line + `ns.NewSummary`; Rule page: four fixed-height `Line()` rows at 16 px steps (type, added, guild, invite; **fixed y, the stage Fix concern**), Expires number box (4 letters), Note edit box (128), Allowed W I G P C ticks (`M.EXCL`), Blizzard tick (B1), `ns.NewExceptions`, Remove + Add Guild buttons; History page: `ns.NewHistory` + Reset Block History button; list `ns.NewRows` (Name fill, Server 112, Type 72, Listed 54, Expires 62, Blocked 62); picker Frame with its own `ns.NewRows` (tick, Name, Level, Class, Guild, state) + Save (`pssPrimary`), Tick All, Cancel.
- Looks: none of its own (kit only; Save is the Modern red button).
- Listens: `PLAYERS_CHANGED` (dirty; refresh if visible), `PLAYER_BLOCKED` (throttled 0.25 s redraw of rows + pane via `M.PSS_Throttle`), `WHOIS_COOLDOWN(active)` (Player Search enabled).
- Popups: `ns.Confirm` "Remove Player?", "Add Player?" (none found, Add Anyway), "Prune Players?" (number box, `M.PSS_PRUNE_DAYS` = 365, live `M.PSS_PruneNote`).
- `L["HISTORY_RESET"]` read from `PourSocialScore_NS.L`.

| Backend call | Defined in |
| --- | --- |
| `M.PSS_PlayerListNew` (V:Resort/SortBy/SetFind), `M.PSS_PlayerTypeText`, `M.PSS_PlayerExpireText`, `M.PSS_PlayerTotal`, `M.PSS_PlayerTip`, `M.PSS_PlayerHeading`, `M.PSS_PlayerTypeLine`, `M.PSS_PlayerAddedLine`, `M.PSS_PlayerExpireNote`, `M.PSS_PlayerGuildLine`, `M.PSS_PlayerInviteLine`, `M.PSS_PlayerGuildState`, `M.PSS_PlayerRemoveText`, `M.PSS_PlayerAddFromText`, `M.PSS_PlayerSearchFromText`, `M.PSS_PlayerPickerItems/Title/Cells/Save`, `M.PSS_PlayerNoneFound`, `M.PSS_PlayerAddAnyway`, `M.PSS_PRUNE_DAYS`, `M.PSS_PruneText`, `M.PSS_PruneNote`, `M.PSS_PruneApply`, `M.PSS_PlayerCommitExpiry`, `M.PSS_PlayerCommitNote`, `M.PSS_PlayerAllowed`, `M.PSS_PlayerToggleAllowed`, `M.PSS_BLIZZARD_TEXT`, `M.PSS_BLIZZARD_TIP`, `M.PSS_PlayerOnBlizzard`, `M.PSS_PlayerToggleBlizzard`, `M.PSS_PlayerAddGuild`, `M.PSS_AllPlayersSpec`, `M.PSS_PlayerEventsSpec` | Lib/PlayerView |
| `M.PSS_PlayerMenu` | Lib/RowMenus |
| `M.PSS_ClassColor`, `M.PSS_CountsText`, `M.PSS_ToggleException` | Lib/DetailQuery |
| `M.PSS_PickerToggle`, `M.PSS_PickerTickAll`, `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_PlayerRow`, `M.PSS_PlayerEntry`, `M.PSS_PlayerPosition`, `M.PSS_RemovePlayerAt` | core/PlayerQuery |
| `M.PSS_GetPlayerBlockCounts`, `M.PSS_GetPlayerBlockHistory`, `M.PSS_ResetPlayerBlockHistory`, `M.PSS_PlayerHistoryKey` | core/PlayerIgnoreList |
| `M.PSS_ScanCooldownActive` | core/Whois |
| `M.EXCL` | core/Globals |

## 11. PSS_Guilds.lua (979 lines, largest): Guild Ignore List tab
Purpose: grouped guild list (Managed Communities + default lists, Guild Exclusion List, other guilds), a guild's members view in place of the list, Scan All, Add/Exclude entry rows with Guild Search, the Guild Search picker, and a pane with four bodies. Builder `ns.TabBuilders.guilds(pg)` -> `Refresh`.
- Exports: `ns.TabBuilders.guilds` only. Page hooks: `pg.navState` (members guild key or nil), `pg.navTitle = M.PSS_MembersNavTitle`, `pg.navApply(key)` (open/close members), `pg.navClose` (picker), `pg.navUp` (picker, then members), `pg.navReset`, `pg.stale`, `pg.select`, `pg.openMembers`, `pg.selectMember`, `pg.search`, `pg.count`, `pg.add`/`searchButton`/`addButton`, `pg.excl`/`exclSearchButton`/`exclButton`, `pg.scanAll`, `pg.list`, `pg.members`, `pg.membersView`, `pg.pane`, `pg.picker`, `pg.state` (= V). Uses `page.refresh` (set by the window) and `ns.NavRecord()` (window) after opening/closing members.
- Module state: `V = M.PSS_GuildListNew()` (made at file load), `cells` (row text buffer), `groupView` (reused), `scanButtons` (follow the /who cooldown).
- Frames (first open): search box + count; two `EntryRow`s (edit box 64 letters + "Guild Search" + Add Guild / Exclude), Scan All; `pane` (`ns.NewPanel` inset, 380 wide, below TOP_H 58) with `ns.NewTotals` and four bodies:
  - `pane.guild` (`BuildGuildBody`): info `Line` at -28, `ns.NewDetailPages(-46, "guilds")`; Summary counts + `ns.NewSummary`; Rule: W I G P C ticks, Scan (shift = restart) + Custom Scan Fields box (128) + Custom Scan, `ns.NewExceptions`, Members, Remove Guild (disabled for a shipped guild); History: `ns.NewHistory(names=true)` + Reset.
  - `pane.group` (`BuildGroupBody`, a default list or Managed Communities): **info, rule, state, counts `Line`s at fixed 16 px steps from -28, pies (`ns.NewSummary` + `ns.NewTypePie`, 84) at a fixed top below them** (the stage Fix target: a wrapped "Rule on the Chat Filters tab: ..." line runs into "Rule is OFF"); rule toggle and open/close buttons.
  - `pane.info` (`BuildInfoBody`): Exclusion List / excluded guild text (160 high, wraps) + "Remove from Exclusion List".
  - `pane.member` (`BuildMemberBody`): DetailPages; Rule: guild and added `Line`s, Note box (25 letters), W I G P C (dimmed = follows the guild; right-click = follow again), exceptions measured against the guild's opts, Remove Member, Add Guild (member's real guild differs); History + Reset.
  - lists: guild `ns.NewRows` (Guild fill, Members 70, Blocked 62, Scan 90; rows dimmed 0.55 for a group whose rule is off), members `mview` (All Guilds back button, heading, `ns.NewRows` Name/Guild 130/Note 110/Blocked 62), picker (tick, Guild, state; Save `pssPrimary`, Tick All, Cancel).
- Looks: none of its own (kit only).
- Listens: `GUILDS_CHANGED`, `GUILD_SCAN_DONE` (dirty; one redraw per frame via `C_Timer.After(0)`), `GUILD_REMOVED(key)` (`V:GuildRemoved`), `GUILD_BLOCKS_CHANGED` (throttled count redraw, `V:CountsChanged()`), `WHOIS_COOLDOWN(active)` (scan buttons), `GUILD_SEARCH_RESULTS(found, query, mode, owner)` (only `owner == M.PSS_GUILD_SEARCH_OWNER`). **Not `FILTERS_CHANGED`** (G26: the group rows' rule dim is stale after a rule change on the Filters tab until the next dirty event).
- Popups: `ns.Confirm` "Remove Guild?", "Remove Member?", "Exclude Guild?" (exclude mode with no results, Add Anyway; add mode with no results only prints a chat line via `M.PSS_Say`).
- Blizzard: `IsShiftKeyDown`, `C_Timer.After`.

| Backend call | Defined in |
| --- | --- |
| `M.PSS_GuildListNew` (V:Resort, MResort, Click, Select, ItemSel, IsSel, SelectMember, OpenMembers, CloseMembers, SetView, SetFind, SetMFind, SortBy, MSortBy, CountText, MembersHeading, MembersEmptyText, FreshCounts, CountsChanged, GuildRemoved, RemoveMember), `M.PSS_GUILD_MANAGED`, `M.PSS_GUILD_SEARCH_OWNER`, `M.PSS_GuildRowCells`, `M.PSS_GuildRowTip`, `M.PSS_GuildScanTip`, `M.PSS_GuildAddFromText`, `M.PSS_GuildExcludeFromText`, `M.PSS_GuildSearchFromText`, `M.PSS_GuildPickerItems/Title/Save/Close/Toggle/TickAll`, `M.PSS_GuildNoneFound`, `M.PSS_GuildExcludeAnyway`, `M.PSS_MembersNavTitle`, `M.PSS_MemberTip`, `M.PSS_GuildInfoLine`, `M.PSS_GuildGroupView`, `M.PSS_GuildExclView`, `M.PSS_MemberHeading`, `M.PSS_MemberGuildLine`, `M.PSS_MemberAddedLine`, `M.PSS_MemberAllowed`, `M.PSS_MemberOtherGuild`, `M.PSS_GuildHistoryKey`, `M.PSS_MemberHistoryKey`, `M.PSS_MemberBlockTotal`, `M.PSS_GuildAllowed`, `M.PSS_GuildToggleAllowed`, `M.PSS_GuildScanNow`, `M.PSS_GuildCustomScan`, `M.PSS_GuildCommitFields`, `M.PSS_GuildRemoveText`, `M.PSS_GuildRemove`, `M.PSS_MemberRemoveText`, `M.PSS_MemberCommitNote`, `M.PSS_MemberToggleAllowed`, `M.PSS_GroupToggleRule`, `M.PSS_GroupToggleOpen`, `M.PSS_ExclRemove`, `M.PSS_AllGuildsSpec`, `M.PSS_GuildEventsSpec`, `M.PSS_GroupEventsSpec`, `M.PSS_MemberEventsSpec` | Lib/GuildView |
| `M.PSS_GuildRowMenu`, `M.PSS_MemberMenu`, `M.PSS_GuildSetAllRules` | Lib/RowMenus |
| `M.PSS_FindGuildRule`, `M.PSS_AddMembersGuild` | Lib/GuildQuery |
| `M.PSS_GroupRecent`, `M.PSS_GroupRecentByCat` | Lib/EventsQuery |
| `M.PSS_ClassColor`, `M.PSS_CountsText`, `M.PSS_ToggleException` | Lib/DetailQuery |
| `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_GetGuildBlockCounts`, `M.PSS_GetGuildBlockHistory`, `M.PSS_GetMemberBlockCounts`, `M.PSS_GetMemberBlockHistory`, `M.PSS_EnsureMemberBlockData`, `M.PSS_ResetGuildBlockHistory`, `M.PSS_ResetMemberBlockHistory`, `M.PSS_IsStaticManagedGuild` | core/GuildIgnoreList |
| `M.PSS_ScanAll`, `M.PSS_GuildSweepLabel` | core/WhoisHarvest |
| `M.PSS_ScanCooldownActive` | core/Whois |
| `M.EXCL` | core/Globals |

## 12. PSS_Filters.lua (489 lines): Chat Filters tab
Purpose: filter list (built-ins first, search, sort), right-click menu, pane (Summary / Event History / View/Edit Rule: On, Description, Filter text, Save Filter / Copy / Remove / Reset Count, Test, Link converter), New Filter, Reset Defaults; the link-insert post-hook. Builder `ns.TabBuilders.filters(pg)` -> `Refresh`.
- Exports: `ns.TabBuilders.filters`, `ns.ShowFilterDetail(fresh)`. Page hooks: `pg.navReset`, `pg.stale`, `pg.select`, `pg.selected()`, `pg.linkHook()` (which hook was made, for the harness), `pg.search`, `pg.count`, `pg.newButton`, `pg.resetButton`, `pg.list`, `pg.pane`, `pg.state` (= V).
- Module state: `V = M.PSS_FilterListNew()` (file load), `sel` (filter index), `cells`, `rowBuf`, `paneRow`, `hooked`.
- Frames (first open): search + count, New Filter, Reset Defaults (`L["BUT_7"]`); `pane` (NewPanel inset 380) with `ns.NewTotals("filters")`, body: heading, info line, `ns.NewDetailPages(-44, "filters")`; Rule: On check, Description box (100), "?" help button (`L["TIP_1"]`), built-in lock note, filter box = `ns.NewPanel` + `ns.NewScrollFrame` + raw multi-line EditBox (1000 letters, follows the cursor), Save Filter / Copy / Remove / Reset Count, Test box (255) + Test button + result text, Link box (255; Enter converts); Summary: counts line + `ns.NewSummary`; History: `ns.NewHistory(names=true)` to the page bottom. List `ns.NewRows` (Description 190, On 40, Blocked 60, Filter fill).
- Built-ins: desc/filter not editable (alpha 0.5), Save/Remove disabled; guild rules: Copy and Reset Count disabled, `pages:Limit({rule=true})`.
- **Hook (J3, approved in PSS 02 12):** first open runs `HookLinks()` once: `hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)` on Retail 12.x, else `hooksecurefunc("ChatEdit_InsertLink", ...)`. Body returns at once unless the pane is visible; text checked with `M.PSS_IsSecret` first; inserts into the focused filter / test / link box.
- Listens: `FILTERS_CHANGED` (dirty; one redraw per frame via `C_Timer.After(0)`), `FILTER_HISTORY_CHANGED` (throttled 0.25 s).
- Popups: `ns.Confirm` "Remove Rule?", "Reset Chat Filters?" (`L["BOX_2"]`).
- Looks: none of its own.

| Backend call | Defined in |
| --- | --- |
| `M.PSS_FilterListNew`, `M.PSS_FilterRowCells`, `M.PSS_FilterRowTip`, `M.PSS_FilterHeading`, `M.PSS_FilterInfo`, `M.PSS_FilterHistoryLine`, `M.PSS_FilterRemoveText`, `M.PSS_FilterRemove`, `M.PSS_FilterSave`, `M.PSS_FilterCopy`, `M.PSS_FilterNew`, `M.PSS_FilterTestText`, `M.PSS_FilterEventsSpec`, `M.PSS_AllFiltersSpec` | Lib/FilterView |
| `M.PSS_FilterRow`, `M.PSS_ConvertChatLink` | Lib/FilterQuery |
| `M.PSS_FilterMenu` | Lib/RowMenus |
| `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_SetFilterActive`, `M.PSS_ResetFilterCount`, `M.PSS_ResetFilterHistory`, `M.PSS_FilterHistory`, `M.PSS_FilterOwnerKey`, `M.ResetSpamFilters` | core/ChatFilters |
| `M.PSS_IsSecret` | core/ChatBlock |

## 13. PSS_Events.lua (274 lines): Events tab
Purpose: the blocked lines of every list: Time / Types / Source drop-downs, custom range, search, sortable columns (Time 136, Source 140, Player 130, Type 60, Channel 120, Message fill; links live), double-click copies a line, right-click sender menu, Reset Block History for a scoped entry. Builder `ns.TabBuilders.events(pg)` -> refresh fn.
- Exports: `ns.TabBuilders.events`, `ns.OpenEvents(_, spec, opts)` (calls `ns.ShowEventsTab(fn)` from the window, then `view:Open(spec, opts)`, clears the search, scrolls to top; returns the view). Page hooks: `pg.navState` (`view:NavKey()`), `pg.navTitle`, `pg.navApply` (`view:NavApply` + refresh), `pg.navReset` (`view:Reset()`, search cleared), `pg.release` (`view:Release()` + `list:SetCount(0)`, also hooked on the page's OnHide), `pg.view`, `pg.list`, `pg.ui`.
- Module state: `view = M.PSS_EventsViewNew()` (file load), `cells`, `ui`, `clicks`.
- Frames (first open): heading, Reset button (`L["HISTORY_RESET"]`), bar with three `ns.NewDropdown` (Time 190: `m:Radio` per `M.PSS_EVENT_TIMES`; Types 150: "All types" + `m:Check` per `History.ALL_CATS`; Source 230: "Only <entry>" + `m:Check` per `M.PSS_EVENT_SOURCES`), `ns.NewSearchBox` (240), custom range row (From / To edit boxes 20 letters, Apply, error text; moves the list down 26 px when shown), `ns.NewRows(links=true, rowH 18)`.
- Every drop-down change and Apply records a back/forward step (`ns.NavRecord()`).
- Logging: `view:Refresh()` calls the spec's `read`, which loads `PourSocialScore_Logging`; the tab is never restored on reopen (Libraries `M.PSS_UITab`).
- Listens (each throttled 0.25 s, only while visible): `PLAYER_BLOCKED`, `GUILD_BLOCKS_CHANGED`, `FILTER_HISTORY_CHANGED`, `PLAYERS_CHANGED`, `GUILDS_CHANGED`.
- Popups: `ns.CopyText` "Copy Event", `ns.Confirm` "Reset Block History?" (only when `view:ResetText()` gives text).
- Looks: none of its own (drop-downs: Blizzard `WowStyle1DropdownTemplate` vs our list in Dark).

| Backend call | Defined in |
| --- | --- |
| `M.PSS_EventsViewNew` (view:Apply, Refresh, Release, Open, SortBy, SetPeriod, RangeTexts, ApplyRange, AllTypes, TypeOn, ToggleType, SourceOn, ToggleSource, ScopeOff, Heading, TimeLabel, TypesLabel, SourceLabel, EmptyText, NavKey, NavTitle, NavApply, Reset, ResetText, DoReset), `M.PSS_EVENT_TIMES`, `M.PSS_EVENT_SOURCES`, `M.PSS_EventCells`, `M.PSS_EventTip`, `M.PSS_EventCopy` | Lib/EventsView |
| `M.PSS_DoubleClick`, `M.PSS_Throttle` | Lib/ViewNav |
| `M.PSS_History` (`ALL_CATS`, `CAT_LABEL`) | core/ChatHistory |

## 14. PSS_Options.lua (240 lines): Options and Import/Export tabs
Two builders: `ns.TabBuilders.options(page)` and `ns.TabBuilders.importExport(page)`, each returning its refresh fn.
- Options: a scrolling page (`ns.NewScrollFrame` + content) with a heading per section (`M.PSS_OptGroups()`) and one 26 px row per option: bool -> `ns.NewCheck` (`M.PSS_SetOpt(key, "global", v)`); bool with `field` (scan level cap) -> check + `ns.NewNumberBox` (`M.PSS_OptSetFieldOn` / `M.PSS_OptSetField`); number -> number box (`M.PSS_OptSetNumber`); choice -> `ns.NewDropdown` 170 (`m:Radio` per `o.choices`, read when opened so LSM fonts appear; `M.PSS_SetOpt`). Label gets " *" for options with `target` (can be per guild/player). A search box (200) sits on the window's tab row (`ns.TAB_ROW_Y - 2`, anchored to the page's parent, shown with the page) and re-lays out by `M.PSS_OptMatches`; "No options match." line. Page fields: `page.search`, `page.groups`, `page.none`, `page.shownCount`. The look (`uiSkin`) and font (`uiFont`) are ordinary choice rows: the window repaints on `OPTION_CHANGED` (section 15).
- Import/Export: help text, a tick per `M.PSS_IO_PARTS` (indented when `p.under`; disabled by `M.PSS_IOPartOff`), Import mode drop-down (`M.PSS_IO_MODES`, `M.PSS_IOSetMode`), Export (`ns.CopyText` "Export", subtitle with the length) and Import (`ns.ImportText` "Import" -> `M.PSS_ImportCheck`; errors and results to chat via `M.ShowMsg`; Replace asks `ns.Confirm` "Replace on Import?"). Page fields: `page.checks`, `page.mode`, `page.exportButton`, `page.importButton`. Ticks are session state `M.PSS_IO`.
- Listens: `OPTION_CHANGED` -> `ns.RefreshTab()` when either page is visible.

| Backend call | Defined in |
| --- | --- |
| `M.PSS_OptLabel`, `M.PSS_OptTip`, `M.PSS_OptChoiceText`, `M.PSS_OptGroups`, `M.PSS_OptMatches`, `M.PSS_OptNumberText`, `M.PSS_OptSetNumber`, `M.PSS_OptFieldOn`, `M.PSS_OptFieldText`, `M.PSS_OptSetFieldOn`, `M.PSS_OptSetField`, `M.PSS_IO`, `M.PSS_IOSet`, `M.PSS_IOSetMode`, `M.PSS_IO_PARTS`, `M.PSS_IO_MODES`, `M.PSS_IOPartOff`, `M.PSS_IOModeText`, `M.PSS_ExportText`, `M.PSS_ImportCheck`, `M.PSS_ImportReplaceText`, `M.PSS_ImportApply` | Lib/OptionsView (export/import through Lib/ImportExport) |
| `M.PSS_Opt`, `M.PSS_SetOpt` | core/Options |
| `M.ShowMsg` | core/Globals |

## 15. PSS_Window.lua (531 lines): the window, tabs, back/forward, Escape
Purpose: the 960 x 494 window `PSS_Window`, its three-look frame art, title and close, the tab row, lazy tab building, back/forward with a breadcrumb line, Escape stepping, open/close lifecycle, dock beside Friends/Social.

| Export | Signature | What |
| --- | --- | --- |
| `M.PSS_OpenWindow(show)` | | builds on first call; toggles (show=true never closes); clears `byFriends`, restores the saved place, refreshes `M.PSS_UIFontChoices()`, Show + Raise |
| `M.PSS_WindowDock(host, x)` | | builds if needed; anchors TOPLEFT to `host` (FriendsFrame / SocialUIFrame) TOPRIGHT +x,-10; `byFriends = true`; Show |
| `M.PSS_WindowUndock()` | | hides only if it was opened by docking |
| `ns.TabBuilders` | table | key -> builder(page) returning refresh (players, guilds, filters, events, importExport, options) |
| `ns.TAB_ROW_Y` | number | tab row y (Options search box) |
| `ns.RefreshTab()` | | calls the shown page's `refresh` |
| `ns.NavRecord()` | | `nav:Record(curTab, page.navState())` unless applying; updates the arrows and line |
| `ns.NavBack()` / `ns.NavForward()` | | overlay close first, then `Go(nav:Back()/Forward())` |
| `ns.NavUp()` | -> bool | Escape step: `navClose`, `navUp`, Events -> `nav:BackToOther(EVENTS)`; false = close |
| `ns.ResetTab(id)` | | closes overlays, `navUp` up to 10 times, `navReset`, select, record |
| `ns.ShowEventsTab(prepare)` | | builds Events, closes the shown page's overlay, runs prepare, selects Events, records |

- Frames (all on first open): `PSS_Window` (UIParent, strata `M.PSS_FrameStrataName()`, toplevel, clamped, movable by drag; place saved on drag stop via `M.PSS_SetUIPlace("PSS_Window", ...)` rounded); `ns.NewFrameArt` (Classic/Modern); `DarkFrame` (fill `DARK.window`, title strip 25 high `DARK.titleBar`, `AdventureMap_TopBorder` atlas edge or pixel border); `chrome` frame raised above the art's NineSlice (+10) holding the title "Pour Social Score" (13, GameFontNormal; the only place the addon name is a title), `UIPanelCloseButton` (Classic/Modern; OnClick replaced on our own button) and `DarkClose` (`uitools-icon-close` atlas or `Interface\Buttons\UI-StopButton`); Modern/Classic band: `Interface\FrameGeneral\UI-Background-Rock` tiled band (Modern only) and `_UI-Frame-TopTileStreaks` streaks (ours if the atlas exists, else the template's `TopTileStreaks`); `PSS_WindowEscape` helper; six `ns.NewTab` + six `ns.NewPanel` pages (each with a fallback note "... comes in a later 3.4.0 build." hidden once built; stale text); back `<` and forward `>` `ns.NewButton`s (26 x 20), `win.where` line + `win.measure` + crumb Buttons pool (`win.crumbs`, accent underline on hover). `win.art = {blizzard, dark, blizzardClose, darkClose, black, band, streaks}` for the harness.
- Looks: Dark (or a client with no frame template) shows `DarkFrame` + `DarkClose`; Classic shows the template art + `UIPanelCloseButton`; Modern also shows the art's black (`pssBlack`), the rock band and streaks.
- Tabs: `BuildTab(id)` runs the builder in `xpcall(..., geterrorhandler())` once (a failed build retries on the next click); `SelectTab(id)` shows the page, runs `page.refresh()`, saves `M.PSS_SetUITab(id)`. A tab click calls `ResetTab` (even on the shown tab). First select on build: `M.PSS_UITab()` (never Events).
- Events: `ns.ListenStart()` on show (then every `page.stale()`, `ns.RefreshTab()`, `RegisterEvent("GLOBAL_MOUSE_UP")` in pcall for mouse buttons 4/5); `ns.ListenStop()` on hide. **`OPTION_CHANGED` is registered with `M.Events.Register` once at build and never removed** (comment: always heard so the look repaints): `frameStrata` -> `SetFrameStrata`; `uiSkin`/`uiFont` -> `ns.Repaint()` + `UpdateNav()`.

| Backend call | Defined in |
| --- | --- |
| `M.PSS_UI_TABS`, `M.PSS_UI_EVENTS_TAB`, `M.PSS_UIPlace`, `M.PSS_SetUIPlace`, `M.PSS_UITab`, `M.PSS_SetUITab`, `M.PSS_UIFontChoices`, `M.PSS_NavNew` (nav:Record, Back, Forward, CanBack, CanForward, Replace, BackToOther) | Lib/ViewNav |
| `M.PSS_FrameStrataName` | core/Options |
| `M.PSS_RequestGC` | core/Perf |
| `M.Events.Register` | core/Events |

## 16. Core openers: PourSocialScore/PSS_BlizzardUI.lua (340 lines; window part lines 12-51 and 279-288)
| Item | What |
| --- | --- |
| `M.PSS_OpenUI(show)` | `M.PSS_Need("GUI")` (core/Loader; loads Libraries first through `NEEDS = {GUI="Libraries"}`, then the GUI folder) then `M.PSS_OpenWindow(show)` |
| Friends/Social dock | `hosts = {FriendsFrame, SocialUIFrame?}`, `HOST_X` 12 / 55; `HookScript("OnShow", hostShow)` (only when `M.PSS_Opt("openWithFriends")`: `PSS_Need("GUI")` + `M.PSS_WindowDock(host, x)`), `HookScript("OnHide", hostHide)` (when no host is shown: `M.PSS_WindowUndock()` if the GUI is loaded). Hooks are set at core load for everyone; the bodies are cheap when the option is off (hostHide still loops 1-2 hosts) |
| Addon Compartment | Retail only (`V.wowIsRetail`): `AddonCompartmentFrame:RegisterAddon{text="Pour Social Score", icon="Interface\Icons\ui_chat.blp", func = M.PSS_OpenUI}` |
| Also in this file (not window) | StaticPopups `PSS_RELOAD` (`M.PSS_AskReload`; Camelot prints instead), `PSS_REASON` (note), `PSS_PARTYWARN`; LFG hooks; `M.PSS_UnitMenuPlayer` (B2 "PSS" header); `M.PSS_HookFunctions`. These stay Blizzard StaticPopups in every look |

Other callers of `M.PSS_OpenUI`: `PourSocialScore_Libraries/PSS_Commands.lua:134` (`/pss` alone or an `OPEN` alias `gui`/`ui`/`eui`). No keybinding opens the window.

---

## (a) Front end to back end, per tab
Format: element/action -> GUI function -> Libraries -> core setter/data. "core X" = `PourSocialScore/PSS_X.lua`.

### Players (PSS_Players.lua)
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| List rows, sort, search | `Resort`, `DrawRow`, `V:SortBy/SetFind` | `PSS_PlayerListNew` (`:Resort` -> `M.PSS_SortPlayers`), `PSS_PlayerTypeText`, `PSS_PlayerExpireText`, `PSS_PlayerTotal`, `PSS_ClassColor` | PlayerQuery `PSS_PlayerRow`, `PSS_SortPlayers` |
| Add Player (box / target) | `AddPlayer` | `PSS_PlayerAddFromText` | PlayerIgnoreList `PSS_AddPlayer` |
| Player Search (/who) -> picker -> Save | searchButton, `ShowSearchResults`, picker Save | `PSS_PlayerSearchFromText`, `PSS_PlayerPickerItems/Title/Cells/Save`, `PSS_PickerToggle/TickAll`; none found: `PSS_PlayerNoneFound`, `PSS_PlayerAddAnyway` | PlayerIgnoreList `PSS_PlayerSearch` (SendWho), `PSS_AddPlayer` |
| Prune | `ConfirmPrune` (number box) | `PSS_PruneText`, `PSS_PruneNote`, `PSS_PruneApply` | `M.PruneIgnoreList(days)` |
| Expiry / Note boxes | `ns.OnCommit` | `PSS_PlayerCommitExpiry`, `PSS_PlayerCommitNote` | PlayerIgnoreList `PSS_SetExpiry`, `PSS_SetNote`, PlayerQuery `PSS_PlayersChanged` (fires PLAYERS_CHANGED) |
| W I G P C ticks | OnClick | `PSS_PlayerAllowed`, `PSS_PlayerToggleAllowed` | `PSS_SetPlayerSetting` + `PSS_PlayersChanged` |
| Blizzard tick (B1) | OnClick | `PSS_PlayerOnBlizzard`, `PSS_PlayerToggleBlizzard` | PlayerIgnoreList `PSS_SetBlizzardIgnore` (C_FriendList through the hook guard) |
| Exceptions ticks | `ns.NewExceptions` | DetailQuery `PSS_ExceptionState`, `PSS_SetException` | Options `PSS_SetOpt(key, "person", v, target)` (OPTION_CHANGED) |
| Add Guild | addGuild button | `PSS_PlayerGuildState`, `PSS_PlayerAddGuild` | GuildIgnoreList `PSS_AddGuild` |
| Remove | `ConfirmRemove` | `PSS_PlayerRemoveText` | PlayerQuery `PSS_PlayerPosition`, `PSS_RemovePlayerAt` (called straight from GUI) |
| Reset Block History | reset button | (none) | PlayerIgnoreList `PSS_ResetPlayerBlockHistory` (straight from GUI) |
| Summary pie / counts / history | `ns.ShowPlayerDetail` | `PSS_CountsText`, DetailQuery pies, `PSS_PlayerHistoryKey` | PlayerIgnoreList `PSS_GetPlayerBlockCounts`, `PSS_GetPlayerBlockHistory` (Logging, only when loaded or the gate is clicked) |
| Right-click row | `RowMenu`/`RowAct` | RowMenus `PSS_PlayerMenu` (acts history, addGuild, noExpiry, resetHistory, exception, remove) | as the buttons above; exception via `PSS_ToggleException` |
| Totals (nothing selected) | `ns.NewTotals("players")` | DetailQuery `PSS_TotalsView` -> TotalsQuery `PSS_ListTotals`; `PSS_AllPlayersSpec` | ChatHistory recent counts |

### Guilds (PSS_Guilds.lua)
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| Grouped list, sort, search, open/close a heading | `Resort`, `DrawRow`, `ClickRow` | `PSS_GuildListNew` (`:Resort` -> GuildQuery `PSS_GuildRows`; `:Click`; `PSS_SetGuildGroupOpen` writes `PourSocialScoreDB.guildGroupOpen` directly), `PSS_GuildRowCells`, `PSS_GuildRowTip` | GuildIgnoreList data, ChatFilters `PSS_ManagedGroupActive` |
| Add Guild / Exclude | `EntryRow` onAdd | `PSS_GuildAddFromText`, `PSS_GuildExcludeFromText` | GuildIgnoreList `PSS_AddGuild`, `PSS_AddGuildExclusion` (GUILDS_CHANGED) |
| Guild Search (both rows) -> picker | `EntryRow` onSearch, `GUILD_SEARCH_RESULTS` -> `ShowSearchResults` | `PSS_GuildSearchFromText(text, mode)`, `PSS_GuildPickerItems/Title/Toggle/TickAll/Save/Close`, `PSS_GuildNoneFound`, `PSS_GuildExcludeAnyway` | GuildIgnoreList `PSS_GuildSearch`, `PSS_SaveGuildSearch` / `PSS_SaveGuildExclusions`, `PSS_ForgetGuildSearch` |
| Scan All / Scan / Custom Scan / Scan Fields | buttons, `ns.OnCommit` | `PSS_GuildScanNow`, `PSS_GuildCustomScan`, `PSS_GuildCommitFields`, `PSS_GuildScanTip` | WhoisHarvest `PSS_ScanAll` (straight from GUI), GuildIgnoreList `PSS_ScanGuild`, `PSS_SetGuildScanFields` (fires nothing) |
| Guild W I G P C | `ExclBoxes` | `PSS_GuildAllowed`, `PSS_GuildToggleAllowed` | GuildIgnoreList `PSS_SetGuildBlock` |
| Exceptions (guild, member) | `ns.NewExceptions` | `PSS_SetException` / `PSS_ToggleException` (member measured against `PSS_FindGuildRule(...).opts`) | Options `PSS_SetOpt(key, "guild"/"person", v, target)` |
| Members view (double-click, Members button, menu) | `OpenMembers`, `CloseMembers`, `DrawMember` | `V:OpenMembers/CloseMembers/MResort`, `PSS_MemberBlockTotal`, `PSS_MemberTip`, `PSS_MembersNavTitle` | GuildIgnoreList `PSS_EnsureMemberBlockData` |
| Member note / W I G P C / Remove / Add Guild | member body | `PSS_MemberCommitNote`, `PSS_MemberToggleAllowed`, `V:RemoveMember`, GuildQuery `PSS_AddMembersGuild` | `PSS_SetMemberNote`, `PSS_SetMemberBlock` (fire nothing: the tab redraws itself), `PSS_RemoveGuildMember` |
| Remove Guild | `ConfirmRemoveGuild` | `PSS_GuildRemoveText`, `PSS_GuildRemove` | GuildIgnoreList `PSS_RemoveGuildNow` (GUILD_REMOVED) |
| Default list / Managed Communities rule toggle, open | group body buttons, menu `allRules`/`rule`/`open` | `PSS_GroupToggleRule`, `PSS_GroupToggleOpen`, RowMenus `PSS_GuildSetAllRules` | ChatFilters `PSS_SetManagedGroupActive` |
| Exclusion list remove | info body, menu `exclRemove` | `PSS_ExclRemove` | GuildIgnoreList `PSS_RemoveGuildExclusion` |
| Reset history (guild / member) | reset buttons, menu | (none) | GuildIgnoreList `PSS_ResetGuildBlockHistory`, `PSS_ResetMemberBlockHistory` (straight from GUI) |
| Pane text and pies | `ShowGuild`, `ShowGroup`, `ShowExcl`, `ShowMember` | `PSS_GuildInfoLine`, `PSS_GuildGroupView`, `PSS_GuildExclView`, `PSS_MemberHeading/GuildLine/AddedLine/Allowed/OtherGuild`, `PSS_GuildSweepLabel` (core), EventsQuery `PSS_GroupRecent/RecentByCat`, `PSS_CountsText` | GuildIgnoreList `PSS_GetGuildBlockCounts/History`, `PSS_GetMemberBlockCounts/History`, `PSS_IsStaticManagedGuild` |

### Filters (PSS_Filters.lua)
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| List, sort, search | `Resort`, `DrawRow` | `PSS_FilterListNew`, FilterQuery `PSS_FilterRow`, `PSS_FilterRowCells`, `PSS_FilterRowTip` | ChatFilters data, `PSS_FilterCounts` |
| On tick / menu toggle | OnClick | (none) | ChatFilters `PSS_SetFilterActive` (straight from GUI; FILTERS_CHANGED) |
| Save Filter | `Save` | `PSS_FilterSave` | `PSS_SaveChatFilter` |
| Copy / New Filter | buttons | `PSS_FilterCopy`, `PSS_FilterNew` | `PSS_CopyChatFilter`, `PSS_AddCustomFilter` |
| Remove | `ConfirmRemove` | `PSS_FilterRemoveText`, `PSS_FilterRemove` | `RemoveChatFilter` |
| Reset Count / Reset history (menu) | button, menu | (none) | `PSS_ResetFilterCount`, `PSS_ResetFilterHistory` (straight from GUI) |
| Reset Defaults | confirm | (none) | `M.ResetSpamFilters` (straight from GUI) |
| Test / Link converter / link insert hook | `RunTest`, link box, `OnInsertLink` | `PSS_FilterTestText`, FilterQuery `PSS_ConvertChatLink` | ChatBlock `PSS_IsSecret` |
| Summary / history | `ns.ShowFilterDetail` | `PSS_FilterHeading`, `PSS_FilterInfo`, `PSS_FilterHistoryLine`, `PSS_FilterEventsSpec`, `PSS_AllFiltersSpec` | ChatFilters `PSS_FilterHistory`, `PSS_FilterOwnerKey` |

### Events (PSS_Events.lua)
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| Open from a pie, View Events, double-click in a pane history | `ns.OpenEvents` -> `ns.ShowEventsTab` | `view:Open(spec, opts)` (specs from Player/Guild/FilterView) | (none until Refresh) |
| Read, filter, sort, draw | `Refresh`, `Apply`, `Draw` | `view:Refresh` (spec `read` loads Logging), `view:Apply`, `PSS_EventCells`, `PSS_EventTip` | ChatHistory (`RecentSlots`, `LOG_ALL`, ...), Logging data |
| Time / Types / Source / custom range | drop-downs, Apply | `view:SetPeriod/RangeTexts/ApplyRange/AllTypes/ToggleType/ToggleSource/ScopeOff` | (none) |
| Reset Block History (scoped entry) | `ResetHistory` | `view:ResetText`, `view:DoReset` -> spec `reset` (`PSS_ResetPlayerBlockHistory`, `PSS_ResetGuildBlockHistory`, `PSS_ResetMemberBlockHistory`, `PSS_ResetFilterHistory`, `PSS_ResetGroupEvents`, `PSS_ResetListedPlayerEvents`, `PSS_ResetAllGuildEvents`, `PSS_ResetAllFilterHistory`) | the matching core reset |
| Double-click copy | `Click` | `PSS_EventCopy` | (none) |
| Right-click sender | `ns.SenderMenu` (History) | RowMenus `PSS_SenderMenu`, `PSS_SenderAdd`, `PSS_SenderRemoveText`, `PSS_SenderRemove` | `PSS_AddPlayer`, `PSS_RemovePlayerAt` |
| Back / forward | `pg.navState/navApply/navTitle` | `view:NavKey/NavApply/NavTitle` | (none) |
| Close / tab change | `pg.release` | `view:Release()` drops the lines | (none) |

### Options and Import/Export (PSS_Options.lua)
| Element / action | GUI | Libraries | Core |
| --- | --- | --- | --- |
| Sections, rows, search | `OptionRow`, `Layout` | OptionsView `PSS_OptGroups`, `PSS_OptLabel`, `PSS_OptTip`, `PSS_OptMatches` | Options `PSS_OPTIONS`, `PSS_OPTION_SECTIONS` |
| Tick | OnClick | (none) | Options `PSS_SetOpt(key, "global", v)` (straight from GUI; OPTION_CHANGED) |
| Number | `ns.OnCommit` | `PSS_OptNumberText`, `PSS_OptSetNumber` | `PSS_SetOpt` |
| Tick + number (scan level cap) | check + box | `PSS_OptFieldOn/FieldText/SetFieldOn/SetField` | `PSS_SetOpt` |
| Choice (incl. uiSkin, uiFont, frameStrata) | `ns.NewDropdown` | `PSS_OptChoiceText`; ViewNav `PSS_UIFontChoices` (on window open) | `PSS_SetOpt`; window repaints on OPTION_CHANGED |
| Import/Export ticks, mode | checks, drop-down | `PSS_IO`, `PSS_IOSet`, `PSS_IOSetMode`, `PSS_IO_PARTS`, `PSS_IO_MODES`, `PSS_IOPartOff`, `PSS_IOModeText` | (session state on M) |
| Export | `Export` -> `ns.CopyText` | `PSS_ExportText` -> ImportExport encode | reads every store |
| Import | `Import` -> `ns.ImportText` -> `ns.Confirm` on Replace | `PSS_ImportCheck`, `PSS_ImportReplaceText`, `PSS_ImportApply` -> ImportExport `PSS_ApplyImport` | setters plus direct writes in `PSS_ApplyImport` (libraries map) ; result via `M.ShowMsg` |

## (b) Open / close lifecycle
1. `/pss` (or `gui`, `ui`, `eui`) -> core `SlashCmdList` stub -> `M.PSS_Stub` loads Libraries -> `M.PSS_SlashPSS` (Lib/Commands) -> `M.PSS_OpenUI()`. The Addon Compartment (Retail) calls `M.PSS_OpenUI()` straight; Friends/Social OnShow with `openWithFriends` calls `M.PSS_WindowDock`.
2. `M.PSS_OpenUI(show)` (core BlizzardUI) -> `M.PSS_Need("GUI")` (core Loader: loads `PourSocialScore_Libraries` then `PourSocialScore_GUI`; warns once on a failed load or version mismatch) -> `M.PSS_OpenWindow(show)`.
3. GUI load (file scope): fonts table empty; each tab file creates its list-state object (`M.PSS_PlayerListNew`, `M.PSS_GuildListNew`, `M.PSS_FilterListNew`, `M.PSS_EventsViewNew`) and queues its `ns.Listen` entries (not registered yet); Throttle closures made. No frames.
4. First `M.PSS_OpenWindow`: `Build()` makes the window, art, chrome, Escape helper, tab row, six empty pages, nav buttons, `nav = M.PSS_NavNew()`, hooks OnShow/OnHide, registers `OPTION_CHANGED` permanently, then `SelectTab(M.PSS_UITab())` builds only that tab (`ns.TabBuilders[key](page)` in xpcall) and `ns.NavRecord()`.
5. Every open: toggle check; `RestorePlace()` (`M.PSS_UIPlace("PSS_Window")` or centre); `M.PSS_UIFontChoices()`; `Show()` -> OnShow: `ns.ListenStart()` (all queued core listeners `M.Events.Register`), every built page's `stale()` (dirty flags, cooldown state), `ns.RefreshTab()`, `GLOBAL_MOUSE_UP` registered; `Raise()`.
6. Use: other tabs build on first click; pane parts (Summary pies, Dark tooltip, our menu, popups) build on first use; Logging loads only from the History gate button or the Events tab's read.
7. Close (close button, Escape at the top level, toggle, undock): OnHide -> `GLOBAL_MOUSE_UP` unregistered, `ns.ListenStop()` (every core listener unregistered), each page's `release()` (**only Events defines one**: `view:Release()` + `list:SetCount(0)`), `M.PSS_RequestGC("window closed")` (core Perf: sets `gc.pending`; the stepped collection runs at its next quiet check).
8. Kept after close for the session: every built frame (load-on-demand never unloads), the font objects, painters list, the tab list-state objects (`V` in Players/Guilds/Filters with their index arrays and member arrays until `CloseMembers`), the pane History lists' `all` arrays (they hold the last read history lines until the next Set or Clear), Libraries caches (`allPlayers`/`allGuilds`/`allFilters` specs, period/type ticks, `M.PSS_IO`), the `OPTION_CHANGED` listener.

## (c) Kit catalogue (who uses what)
| Builder (file) | Used by |
| --- | --- |
| `ns.NewText`, `ns.Font` (Skin) | every file |
| `ns.NewHeading` (Kit) | Detail, Players, Guilds, Filters, Events, Options |
| `ns.NewButton` (Kit) | Detail, History, Players, Guilds, Filters, Events, Options, Popups, Window |
| `ns.NewCheck` (Kit) | Detail, History, Players, Guilds, Filters, Options |
| `ns.NewEditBox` (Kit) | Players, Guilds, Filters, Events |
| `ns.NewNumberBox` (Kit) | Players, Options, Popups |
| `ns.OnCommit` (Kit) | Players, Guilds, Options |
| `ns.NewSearchBox` (Kit) | Players, Guilds, Filters, Events, Options |
| `ns.NewPanel` (Kit) | Players, Guilds, Filters (panes, filter box), Popups (text box), Window (pages) |
| `ns.NewScrollFrame` (Kit) | Rows, Filters (filter box), Options, Popups |
| `ns.NewTab` / `ns.SetTabSelected` (Kit) | Window (tab row), Detail (page bar) |
| `ns.NewRows` (Rows) | Players (list, picker), Guilds (list, members, picker), Filters, Events, History |
| `ns.NewPie` (Pie) | Detail only (Summary, TypePie) |
| `ns.NewDropdown` (Menu) | Events (3), Options (choice rows, import mode) |
| `ns.ContextMenu` / `ns.RowMenu` (Menu) | Players, Guilds, Filters, History (SenderMenu, also Events) |
| `ns.Tip` / `ns.TipOn` / `ns.HideTip` (Tooltip) | Rows, Pie, Detail, History, Players, Guilds, Filters, Events, Options, Window |
| `ns.Confirm` (Popups) | Players, Guilds, Filters, Events, History, Options |
| `ns.CopyText` (Popups) | Events (Copy Event), Options (Export) |
| `ns.ImportText` (Popups) | Options (Import) |
| `ns.NewFrameArt` (Skin) | Window, Popups |
| `ns.NewDetailPages`, `ns.NewSummary`, `ns.NewTotals` (Detail) | Players, Guilds, Filters |
| `ns.NewTypePie` (Detail) | Guilds (group body), Detail (Totals) |
| `ns.NewExceptions` (Detail) | Players, Guilds (guild, member) |
| `ns.NewHistory`, `ns.SenderMenu` (History) | Players, Guilds (guild, member), Filters; SenderMenu also Events |
| `ns.PixelBorder`, `ns.Fill`, `ns.Own`, `ns.ShowArt`, `ns.OnePixel`, `ns.NoSnap`, `ns.HasAtlas`, `ns.AtlasWidth` (Skin) | kit internals, Menu, Tooltip, Popups, Window |

Harness: `tools/harness/kit_page.lua` (kit preview), `check_tui.lua` (kit in every look), `tui_compare.sh` / `tui_tour.lua` (window in all three looks).

## (d) Popups and menus
| Popup (frame) | Title | Opened by | Accept -> |
| --- | --- | --- | --- |
| `ns.Confirm` (`PSS_Confirm`) | Remove Player? | Players Remove / menu; History/Events sender menu | `PSS_RemovePlayerAt` / `PSS_SenderRemove` |
| | Add Player? | Player Search, nobody found | `PSS_PlayerAddAnyway` |
| | Prune Players? (number box) | Players Prune | `PSS_PruneApply(days)` |
| | Remove Guild? | Guilds Remove Guild / menu | `PSS_GuildRemove` |
| | Remove Member? | member Remove / menu | `V:RemoveMember` |
| | Exclude Guild? | Guild Search (exclude row) with no result | `PSS_GuildExcludeAnyway` |
| | Remove Rule? | Filters Remove / menu | `PSS_FilterRemove` |
| | Reset Chat Filters? | Filters Reset Defaults | `M.ResetSpamFilters` |
| | Reset Block History? | Events Reset (when text given) | `view:DoReset` |
| | Replace on Import? | Import in Replace mode | `PSS_ImportApply` |
| `ns.CopyText` (`PSS_TextPopup`) | Copy Event; Export | Events double-click; Export | read only |
| `ns.ImportText` (`PSS_TextPopup`) | Import | Import button | `PSS_ImportCheck` then apply or confirm |
| Core StaticPopups (not GUI) | `PSS_RELOAD`, `PSS_REASON`, `PSS_PARTYWARN` | core | Blizzard look always |

Menus: right-click row menus are data from Libraries `PSS_RowMenus.lua` (`PSS_PlayerMenu`, `PSS_GuildRowMenu`, `PSS_MemberMenu`, `PSS_FilterMenu`, `PSS_SenderMenu`) drawn by `ns.RowMenu` -> `ns.ContextMenu`: Blizzard `MenuUtil.CreateContextMenu` in Classic/Modern, our compact `PSS_Menu` in Dark or without the Menu API. Drop-downs (`ns.NewDropdown`): `WowStyle1DropdownTemplate` + `SetupMenu` in Classic/Modern, our `PSS_Menu` list in Dark. Every menu selects the row first, so its acts match the pane's buttons.

## (e) Escape handling
- Popups and our menu: `ns.EscapeCloses(frame, name)` appends the name to `UISpecialFrames` (`PSS_Confirm`, `PSS_TextPopup`, `PSS_Menu`), called after each frame's own OnHide is set (SetScript would drop the hook). Hiding a Confirm any way but Accept runs `onCancel`. Edit boxes in popups hide the popup on Escape too.
- Window: `PSS_Window` itself is **not** in `UISpecialFrames`; a hidden-by-default helper `PSS_WindowEscape` is (added directly in `EscapeFrame`), shown with the window. Blizzard's Escape hides it; its OnHide then decides:
  1. `ns.EscapeTaken()`: a registered popup/menu is shown, or one was hidden at this same `GetTime()` (Blizzard closes every UISpecialFrame in one Escape) -> re-show the helper, window untouched.
  2. `ns.NavUp()`: the page's `navClose()` (picker overlay), then `navUp()` (Guilds members -> guild list), then Events opened from another tab -> `nav:BackToOther(EVENTS)` -> re-show the helper.
  3. otherwise `win:Hide()`.
- Blizzard menus (Classic/Modern) close on Escape by themselves (not tracked by `EscapeTaken`).
- Edit boxes: Escape clears focus (search boxes also clear their text; Filters' boxes reload the pane text).
- Mouse buttons 4 / 5 over the window: `GLOBAL_MOUSE_UP` (registered only while shown) -> `ns.NavBack` / `ns.NavForward`.

## Notable findings (GUI)
1. Only the Events tab releases data on close (`pg.release`). Players, Guilds and Filters keep their list states and their History panes keep the last-read history line arrays (`hv.all`) after close; the "window drops what it read" rule holds only for Events.
2. `OPTION_CHANGED` is registered once with `M.Events.Register` in `Build()` and never unregistered (deliberate, commented); every other listener follows show/hide.
3. Painters (`ns.OnPaint`), `summaries`, `typePies` and History `lists` only grow (bounded by widgets built; rows add one painter each).
4. GUI calls several core setters directly rather than through a Libraries wrapper: `PSS_RemovePlayerAt`, `PSS_Reset*BlockHistory`, `PSS_SetFilterActive`, `PSS_ResetFilterCount/History`, `M.ResetSpamFilters`, `PSS_ScanAll`, `PSS_SetOpt`. Allowed (core setters), but uneven with the Libraries-wrapped paths (W2 target).
5. Guilds does not listen to `FILTERS_CHANGED` (G26 pending): a rule toggled on the Filters tab leaves the guild rows' dim stale until another dirty event.
6. Fixed-height `Line()` stacks: Players rule page (4 lines at 16 px), Guilds `BuildGroupBody` (info/rule/state/counts, pies at a fixed top), guild info line, member lines: the stage Fix (3.4.1.39) targets.
7. Dark menu height fixed at 200 (`MAX_H`, G27 pending); `ns.HasModernArt` checks 8 atlases while Modern draws more (`_128-RedButton-Center`, `-Pressed/-Disabled/-Highlight`, `checkmark-minimal-disabled`, `common-searchbar-icon-a`, `perks-divider-short`, ...; G28 pending).
8. Stale text: `PSS_Skin.lua` header still calls "blizzard" the default and Modern unbuilt; `PSS_Window.lua` header says "Blizzard look" (two looks); each page's fallback note "comes in a later 3.4.0 build" (only shows if a builder errors); `PSS_Kit.lua` header says "both looks".
9. `ns.NewTab` clears OnShow/OnEvent on our own template tab (allowed: our frame); `UIPanelCloseButton` OnClick replaced on our own button; `NewCheck` uses `hooksecurefunc(c, "SetChecked")` on our own CheckButton. No Blizzard-owned frame is written; the only Blizzard post-hook in the GUI is the link insert (Filters).
10. The core Friends/Social `OnShow`/`OnHide` hooks are installed for everyone at load; only `hostShow` checks `openWithFriends` (hostHide runs its small loop regardless; cheap, and a no-op until the GUI is loaded).
