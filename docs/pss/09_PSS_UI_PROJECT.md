# Current project: the new PSS window (3.4.0)

One window with the EllesmereUI port's layout, features and feel, drawn only
with Blizzard's and our own resources, in three looks. It replaces both
`PourSocialScore_GUI` (old native window) and `PourSocialScore_EllesmereUI`
(the port). Started 2026-10-07. The live 3.3.1 release still ships both old
windows; their docs (01, 03, 08) stay true for it until the cutover.

**Project data on scratch, always read the newest:** `latest/` (the index,
`latest/README.md`) holds copies of the newest markdown: the project plan
(`latest/pss-ui/`) and these docs (`latest/pss-docs/`). The working copies
are `pss-projects/pss-ui/` (01_ANALYSIS, 02_PLAN, 03_CODE_CHANGES,
04_LOOK_SPEC). Test zips: `PourSocialScore/test-builds/`. Real saves:
`pss-projects/savedvariables/<version>/`.

## Dan's brief and decisions (2026-10-07)
1. Every element of the EllesmereUI port becomes native. No EllesmereUI dependency and no EllesmereUI names: PSS names only (`check_rules.sh` fails on `EUI` or `Ellesmere` in `PourSocialScore_UI` and `PSS_ViewNav.lua`).
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
| Modern | dev004 (to dev004_2) | The Modern look across the kit (Dan chose it next, 2026-10-07); dev004_2 redone after the whole Social window | PR #93 |
| A3 | dev005 | Libraries groundwork: navigation, detail maths, event view, shared helpers; numbers match the port on the real saves | Planned |
| B1 to B7 | dev006 to dev012 | Window frame and navigation, then one tab per PR (Players, Guilds x2, Chat Filters, Events, Options + Import/Export) | Planned |
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
| `PourSocialScore_UI/PSS_KitPage.lua` | Temporary kit preview (three tabs), removed in B1 |
| `PourSocialScore_UI/PSS_Window.lua` | The window, Escape helper `PSS_WindowEscape`, `M.PSS_TUI` |
| `PourSocialScore_Libraries/PSS_ViewNav.lua` | `M.PSS_UISkin`, `M.PSS_UIPlace` / `M.PSS_SetUIPlace`, `M.PSS_UIFontPath`, `M.PSS_UIFontChoices`, `M.PSS_UIAccent` |
| Core | `M.PSS_PARTS.UI`, `NEEDS.UI = "Libraries"`, options `uiSkin` and `uiFont`, `HELP_21` |

## Lessons so far
- **Blizzard tab labels:** `PanelTemplates_SelectTab` / `DeselectTab` re-anchor a top tab's label 4 / 8 px below centre (made for 32 px tabs), and the tab template's `OnShow` resizes the tab to its own padding (it cut "Player Ignore List" short). The kit drops those scripts on our own tabs and sets the label and the active art itself. A centring that those functions override does nothing: check what re-anchors a region before fixing its anchor.
- **Thin lines:** at UI scales under 1 a 1-unit line blurs and loses its colour. Lines and edges are one physical pixel (`ns.OnePixel`) with grid snapping off (`ns.NoSnap`).
- **Dimmed labels:** fade with `SetAlpha` (never text colour alpha, baseline 05 known fix 1); Dark's unselected tabs sit at 0.7, readable on the dark plate.
- **Template art across looks:** fade a template's textures with alpha and restore each one's own alpha, so the template's state changes cannot bring one back and the Blizzard look is exactly as Blizzard drew it.
- **Rotated art does not stretch along the other axis** (dev004): a tall side-tab atlas turned a quarter on a wide tab showed as thin strips. Keep frame art upright and stretch only its middle with slice margins, and match a look from the whole reference window (frame, background, panels, buttons), not from a few controls.
- **Ask which object a screenshot shows:** `/fstack` names only what is under the mouse; a screenshot of a highlighted region with an unrelated frame stack cannot be identified.
