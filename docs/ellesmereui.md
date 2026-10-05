# PourSocialScore EllesmereUI

Pour Social Score in EllesmereUI's style: the addon folder
`PourSocialScore_EllesmereUI`, loaded on demand by the Pour Social Score core
when "Enable EllesmereUI integration" is on and EllesmereUI is installed.
From 3.2.0-dev008 it lives in this repository and ships in the core zip,
with the core's version number (it was racetracks/PourSocialScore-EllesmereUI,
versions 1.1.0-dev1 to dev010, before).

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
  session / the last 24 hours / all time, with a tick box per period (all
  time starts unticked); a slice opens that period's events and View Events
  all of them. The periods are nested, so each slice is drawn as only what
  the smaller ticked periods do not already hold, and hovering a slice also
  lights the smaller slices it contains. The session
  and 24 hour counts come from the core (PourSocialScore 3.2), so the pie
  never loads the block history. Under the pie a Stored line says how many
  of the blocks are in the 2000-line log (chat filters) or in the person's
  kept lines (once the history is loaded). Blocks that are counted but no
  longer stored show in the view as "Data expired from logs" rows, with
  their type and, for the last 24 hours, when; a person's world and guild
  chat, which the core counts but never stores (3.2), shows as "Counted,
  not stored". Selecting a default guild list (its heading row on the Guild
  Ignore List tab) shows two pies for the whole list: this session / the
  last 24 hours / all time (with the same tick boxes), and its blocks by
  type (all time), each the sum of the list's guilds' own counts, so they
  never load the block history either (1.1.0-dev006). With nothing
  selected on a tab (a click on the selected entry deselects it), its pane
  shows the same two pies for the whole list (1.1.0-dev007, needs
  PourSocialScore 3.2.0-dev004). The default guild lists sit under one
  Managed Communities row that opens and closes and shows them all added
  up; a list's period pie opens its guilds' lines in the Block History view
  (View Events or a slice), and the type pie has a tick box per type, shared
  by every type pie (1.1.0-dev008, needs PourSocialScore 3.2.0-dev005).
  A new block refreshes a list heading's counts and its pane at once, and
  the small pies keep View Events beside the counts, clear of the type
  legend (1.1.0-dev009).
  With nothing selected, the list totals' pie slices and View Events open
  the whole list's events (All Players, All Guilds, All Filters), and a
  player's or guild's world and guild chat shows as its lines again, not
  "Counted, not stored" (1.1.0-dev010, with PourSocialScore 3.2.0-dev007).
  From 3.2.0-dev008 it is part of this repository and versioned with it.
  A click under a list's rows deselects like a click on the selected row;
  a tab click (the tab shown too) resets that tab; each part of the line
  by the arrows but the last goes back to it (3.2.0-dev009).
  Back / forward arrows (and mouse buttons 4 / 5) step through
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

Install: it comes with the other PourSocialScore folders in the release zip.
Then tick "Enable EllesmereUI integration" in Pour Social Score's
Options (or `/pss eui enable`) and reload. The user guide is the ELLESMEREUI
section of the core readme.txt.
