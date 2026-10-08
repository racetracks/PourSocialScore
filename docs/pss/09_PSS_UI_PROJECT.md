# Current project: the new PSS window (3.4.0)

One window with the EllesmereUI port's layout, features and feel, drawn only
with Blizzard's and our own resources, in three looks. It replaces both
`PourSocialScore_GUI` (old native window) and `PourSocialScore_EllesmereUI`
(the port). Started 2026-10-07. The live 3.3.1 release still ships both old
windows; their docs (01, 03, 08) stay true for it until the cutover.

**Project data on scratch (`racetracks/Pour-Social-Score_Scratch`), always
read the newest:** `docs/latest/` (the index, `docs/README.md`) holds the
newest markdown: the project plan (`docs/latest/ui uplift/`: 01_ANALYSIS,
02_PLAN, 03_CODE_CHANGES, 04_LOOK_SPEC) and these docs
(`docs/latest/pss-docs/`); history in `docs/ui uplift/`, zips
`docs/ui-uplift-<date>-vN.zip`. Test zips: `releases/` (dated) and
`latest/` (the newest). Real saves: `SavedVariables/<version>/`.

## Dan's brief and decisions (2026-10-07)
1. Every element of the EllesmereUI port becomes native. No EllesmereUI dependency and no EllesmereUI names: PSS names only (`check_rules.sh` fails on `EUI` or `Ellesmere` in `PourSocialScore_UI`, `PSS_ViewNav.lua`, `PSS_DetailQuery.lua` and `PSS_PlayerView.lua`).
2. **The port is the reference for every visual and layout choice; the old GUI is not authoritative on anything.**
3. All logic (state, navigation, queries, shaping, validation, flows) in `PourSocialScore_Libraries`; drawing only in the new `PourSocialScore_UI` ("PourSocialScore UI"), split by function. Folder name `PourSocialScore_UI`.
4. `/pss tui` (temp UI) opens it while it is built; at the cutover it takes over `/pss gui`, the Friends / Social docking and the Addon Compartment.
5. **At the cutover the new files move into `PourSocialScore_GUI`** (its Title and Notes stay), replacing the old GUI's files; `PourSocialScore_UI` then goes away and only `PourSocialScore_EllesmereUI` is deleted.
6. **Three looks** (option `uiSkin`), same layout, features and feel in each:

   | Value | Name in Options | Look | Built |
   | --- | --- | --- | --- |
   | 0 | Blizzard (Default) | Blizzard's classic templates (`ButtonFrameTemplate`, `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate`, `InsetFrameTemplate`, top tabs, `GameTooltip`) | dev002 |
   | 2 | Modern | Blizzard's new 12.x Social window (Dan's /fstack screenshots, 2026-10-07): the same metal frame (`UI-Frame-Metal` nine-slice) on black (the Social window sets its Bg to black); pages on the black under `perks-divider-short`; inset boxes as `friends-card-default`; buttons and tabs the straight gold-framed action button (`common-button-tertiary-normal`, `-pressed` while held, the same art added on top for hover and a selected tab; dev004_3, after the side-tab plate's cut corner looked uneven), the accepting button `128-RedButton` three-slice; compared in game against the Filter button art and kept (Dan, dev004_4); `checkbox-minimal` / `checkmark-minimal`; `common-searchbar-a` boxes with `common-searchbar-icon-a`; `DialogBorderTemplate` popups; drop-downs, menus and tooltips Blizzard's. Retail only; without the art it is the Blizzard look | dev004_2 |
   | 1 | Dark | The port's style in full (EllesmereUI's skin numbers): flat fills, one-pixel edges | dev002 (was named "Modern" until dev002_3; value 1 kept) |

7. **Accent = your class colour, always, in every look; no option** (Dan: "class colour is mandatory"). The look's own colour (gold; green for Dark) only if the client gives no class colour. `M.PSS_UIAccent` in Libraries.
8. **Font option `uiFont`**, both looks: the look's own (Blizzard's for Blizzard and Modern, Arial Narrow for Dark), or Game text, Unit names, Damage numbers, Friz Quadrata, Arial Narrow, Morpheus, Skurri, plus fonts other addons share through LibSharedMedia, **read only and only when another addon has loaded it** (Dan's OK for reading it). PSS ships no library and never creates `LibStub`. Expressway (EllesmereUI's font) carries "Do not distribute" and is never shipped.
9. Old-GUI-only features are ported in the port's style before the cutover: Player Search, add your target, Prune, right-click menus. Resizable columns and windows are dropped.
10. Popups: in Dark everything comes from our kit (window popups, tooltips, menus, and core's note, party warning and reload popups); Blizzard uses GameTooltip and the Menu API, and the window's popups are our own frames in Blizzard's dialog art (dev003: copy and import need a multi-line box, which StaticPopup lacks, and no `StaticPopupDialogs` entry is written). Core's StaticPopups stay as they are.
11. Window place, last tab and new settings live in the Options addon's SavedVariables (`PSS_OptionsDB`, through the routed `PourSocialScoreDB` UI keys). No new SavedVariables.
12. Version line **3.4.0**. Fixes to an unmerged dev build count up with `_N` (`3.4.0-dev002_2`, `_3`, ...); the next stage is the next devNNN.

## Stages
| Stage | Dev | What | State |
| --- | --- | --- | --- |
| A1 | dev001 | `PourSocialScore_UI` folder, loader part `UI`, option `uiSkin`, `/pss tui` empty window; `check_tui.lua`, `check_toc.sh`, PSS-names check | Merged #88 |
| A2 | dev002 (to dev002_4) | Kit part 1 in Blizzard and Dark: shared fonts, heading, button, tick box, edit / number / search box, panel, scroll frame, tab row, tooltip; option `uiFont`; three looks; class colour accent; temporary kit preview page | Merged #89 (at dev002) and #90 (dev002_2 to _4, docs) |
| A2b | dev003 (to dev003_2) | Kit part 2: drop-down and right-click menu, popups (confirm, copy, import), row list, pie | Merged #92 |
| Modern | dev004 (to dev004_2) | The Modern look across the kit (Dan chose it next, 2026-10-07); dev004_2 redone after the whole Social window, settled at dev004_4 | Merged #93 |
| A3 | dev005 | Libraries groundwork: navigation, detail maths, shared helpers; numbers equal the core's counts on the real saves (`check_viewquery.lua`); the Events view query moves to B6, with the tab that draws it | Merged #94 |
| B1 | dev006 (to dev006_2) | Window frame and navigation: six tabs, back / forward, the line by the arrows, Escape, last tab remembered; kit preview out of the window (kept in the harness) | Merged #96 |
| B2 | dev007 | Player Ignore List tab with the detail pane (three pages), totals and pies; Libraries `PSS_PlayerView.lua`; close button and title above the frame's border | PR open |
| B3 to B7 | dev008 to dev012 | One tab per PR (Guilds x2, Chat Filters, Events, Options + Import/Export) | Planned |
| C1, C2 | dev013, dev014 | Player Search, add target, Prune; right-click menus | Planned |
| D1 to D3 | dev015 to dev017 | Switch-over; files move into `PourSocialScore_GUI`, EUI folder and bridge deleted; polish | Planned |
| Release | 3.4.0 | When Dan says it is done | |

## Code map
| Where | What |
| --- | --- |
| `PourSocialScore_UI/PSS_Skin.lua` | Looks, Dark colour tokens, accent, shared font objects (`PSS_Font1..n`, repainted in place), pixel border, `ns.NoSnap`, `ns.ShowArt` (fades a template's textures, restores their own alpha) |
| `PourSocialScore_UI/PSS_Kit.lua` | The controls in each look; each widget keeps its Dark parts in `widget.pssParts` |
| `PourSocialScore_UI/PSS_Tooltip.lua` | `ns.Tip` / `ns.HideTip` / `ns.TipOn` |
| `PourSocialScore_UI/PSS_Menu.lua` | `ns.NewDropdown(parent, w, build)` (`dd:SetLabel`), `ns.ContextMenu(owner, build)`; `build(m)` adds `m:Button`, `m:Radio`, `m:Check`, `m:Divider`, `m:Title`; Blizzard's MenuUtil menus or our `PSS_Menu` list |
| `PourSocialScore_UI/PSS_Popups.lua` | `ns.Confirm`, `ns.CopyText`, `ns.ImportText` (`PSS_Confirm`, `PSS_TextPopup`) |
| `PourSocialScore_UI/PSS_Rows.lua`, `PSS_Pie.lua` | The virtual row list and the pie, carried over from our own port and drawn in the look shown |
| `PourSocialScore_UI/PSS_Window.lua` | The window, `M.PSS_TUI`; six tabs built on first open by `ns.TabBuilders[key](page)` (returns the redraw); back / forward `ns.NavBack` / `ns.NavForward` / `ns.NavUp`, `ns.NavRecord`, `ns.ResetTab`, `ns.ShowEventsTab(prepare)`, `ns.RefreshTab`; a page's `navState` / `navApply` / `navUp` / `navTitle` / `navReset` / `navClose`; Escape helper `PSS_WindowEscape` |
| `PourSocialScore_UI/PSS_Detail.lua` | The panes' shared parts: `ns.NewDetailPages(body, top, kind)` (Summary, Event History, View/Edit Rule), `ns.NewSummary` (`sm:Set(spec)`), `ns.NewTypePie`, `ns.NewTotals`; a slice or View Events calls `ns.OpenEvents` once the Events tab defines it |
| `PourSocialScore_UI/PSS_History.lua` | `ns.NewHistory(body, y, opts)`: the block history list with type ticks and the Show Block History gate |
| `PourSocialScore_UI/PSS_Players.lua` | The Player Ignore List tab (`ns.TabBuilders.players`), `ns.ShowPlayerDetail` |
| `PourSocialScore_Libraries/PSS_PlayerView.lua` | The tab's logic: `M.PSS_PlayerListNew()` (sort, search), column and pane text, edits (`M.PSS_PlayerCommitNote`, `...CommitExpiry`, `...ToggleAllowed`, `...CycleOverride`, `...AddFromText`, `...AddGuild`), Events specs |
| `tools/harness/kit_page.lua` | The kit preview (was `PSS_KitPage.lua` until dev005), built by `check_tui.lua` on a frame of its own through `H.Private("PourSocialScore_UI")` |
| `PourSocialScore_Libraries/PSS_ViewNav.lua` | `M.PSS_UISkin`, `M.PSS_UIPlace` / `M.PSS_SetUIPlace`, `M.PSS_UIFontPath`, `M.PSS_UIFontChoices`, `M.PSS_UIAccent`; tabs `M.PSS_UI_TABS`, `M.PSS_UITab` / `M.PSS_SetUITab` (saved as `windowPoints.PSS_WindowTab`, the first tab not saved); back / forward `M.PSS_NavNew(max)` (`Record`, `Back`, `Forward`, `Replace`, `BackToOther`), `M.PSS_DoubleClick`, `M.PSS_Throttle` |
| `PourSocialScore_Libraries/PSS_DetailQuery.lua` | Pane maths: `M.PSS_PERIODS`, period and type ticks, `M.PSS_SummaryValues`, `M.PSS_PeriodSlices` / `M.PSS_PeriodTip`, `M.PSS_TypeSlices`, `M.PSS_TotalsView`, `M.PSS_CountsText`, override cycle `M.PSS_NextOverride` / `M.PSS_OverrideText`, `M.PSS_ClassColor`, history type ticks `M.PSS_HistHidden` / `M.PSS_HistFilter` |
| Core | `M.PSS_PARTS.UI`, `NEEDS.UI = "Libraries"`, options `uiSkin` and `uiFont`, `HELP_21` |

## Lessons so far
- **Blizzard tab labels:** `PanelTemplates_SelectTab` / `DeselectTab` re-anchor a top tab's label 4 / 8 px below centre (made for 32 px tabs), and the tab template's `OnShow` resizes the tab to its own padding (it cut "Player Ignore List" short). The kit drops those scripts on our own tabs and sets the label and the active art itself. A centring that those functions override does nothing: check what re-anchors a region before fixing its anchor.
- **Thin lines:** at UI scales under 1 a 1-unit line blurs and loses its colour. Lines and edges are one physical pixel (`ns.OnePixel`) with grid snapping off (`ns.NoSnap`).
- **Dimmed labels:** fade with `SetAlpha` (never text colour alpha, baseline 05 known fix 1); Dark's unselected tabs sit at 0.7, readable on the dark plate.
- **Template art across looks:** fade a template's textures with alpha and restore each one's own alpha, so the template's state changes cannot bring one back and the Blizzard look is exactly as Blizzard drew it.
- **Rotated art does not stretch along the other axis** (dev004): a tall side-tab atlas turned a quarter on a wide tab showed as thin strips. Keep frame art upright and stretch only its middle with slice margins, and match a look from the whole reference window (frame, background, panels, buttons), not from a few controls.
- **Frame art has its own levels** (dev007): `ButtonFrameTemplate`'s border (its NineSlice) sits at a fixed frame level of about 500, so our close button and title at the window's level + 8 were drawn under the metal edge. Anything that must show over a Blizzard frame template goes on a frame raised above the template's own parts.
- **Ask which object a screenshot shows:** `/fstack` names only what is under the mouse; a screenshot of a highlighted region with an unrelated frame stack cannot be identified.
