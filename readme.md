# PourSocialScore EllesmereUI

Pour Social Score in EllesmereUI's style: the addon folder
`PourSocialScore_EllesmereUI`, loaded on demand by the Pour Social Score core
(racetracks/PourSocialScore) when "Enable EllesmereUI integration" is on and
EllesmereUI is installed.

- A Pour Social Score window next to the Friends list, painted through
  EllesmereUI's skinning API (`EllesmereUI.RegisterSkin`). Its Player and
  Guild Ignore List and Chat Filters tabs share one pooled row list (`EUI_Rows.lua`): only the
  rows that fit are made, so long lists cost the same as short ones. Their
  block history (`EUI_History.lua`) loads PourSocialScore_Logging only when
  asked for; a double-click opens the Block History view
  (`EUI_HistoryView.lua`: type boxes, a This session / Last 24 hours / All
  time picker, search, and on guilds a Guilds drop-down). The detail pane of each tab has three pages,
  picked by the buttons along its bottom (`EUI_Detail.lua`): Summary, Event
  History and View/Edit Rule. Summary is a small pie (`EUI_Pie.lua`) of this
  session / the last 24 hours / all time, with a tick box per period; a
  slice opens that period's events and View Events all of them. The session
  and 24 hour counts come from the core (PourSocialScore 3.2), so the pie
  never loads the block history. Under the pie a Stored line says how many
  of the blocks are in the 2000-line log (chat filters) or in the person's
  kept lines (once the history is loaded). Blocks that are counted but no
  longer stored show in the view as "Data expired from logs" rows, with
  their type and, for the last 24 hours, when; a person's world and guild
  chat, which the core counts but never stores (3.2), shows as "Counted,
  not stored". Back / forward arrows (and mouse buttons 4 / 5) step through
  the views; Escape goes up a level through EllesmereUI's Escape handling
  (`RegisterEscapeClose` with `onEscape`).
- A "Pour Social Score" section in the EllesmereUI panel (plugin API,
  registered by the core).
- With the integration on, the core's note prompt and party warning use
  EllesmereUI's input and confirm popups (`ShowInputPopup`,
  `ShowConfirmPopup`); that code is in the core (`PSS_BlizzardUI.lua`), so
  this folder does not have to load for them.

It uses EllesmereUI's documented public APIs only and contains no
EllesmereUI code. Code style follows EllesmereUI's CONTRIBUTING.md (Lua 5.1,
ASCII, house tooltips and popups, `W:DualRow` rows with no empty slots).

Install: copy `PourSocialScore_EllesmereUI` into `Interface/AddOns` next to
the other PourSocialScore folders. From 1.1 this folder has its own version
number; it needs PourSocialScore 3.1.0 or later (3.2 for the session and 24 hour
counts on the Summary pie) (3.1.0 was the first full
release, numbered with the core). Then tick "Enable EllesmereUI integration" in Pour Social Score's
Options (or `/pss eui enable`) and reload. The user guide is the ELLESMEREUI
section of the core readme.txt.
