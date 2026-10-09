# Combined notes: W3 and W4 (kit and redraw cost)

## W3 (G15 to G20)
- Kit (PSS_Kit.lua): `ns.NewButton(..., primary)` (G20), `ns.NewEditBox(parent, w, max, hint)` with `e.hint` (G18, the search box uses the same helper), `ns.NewTextArea(parent, size, max, pad)` -> panel with `.edit` and `.scroll` (G19).
- PSS_Detail.lua: `ns.NewLine`, `ns.NewLabel(parent, text [, x, y])`, `ns.NewStrip(parent, y, h, w)`, `ns.NewAllowedBoxes(parent, y, w, tip, onClick, rightClicks)` (G16, G17).
- PSS_Rows.lua: `ns.NewPicker(parent, anchor, {cols, stateW, fill, toggle, tickAll, save, close})` with `:ShowItems(title)` (G15). The tick/listed texts are still built inside the picker draw (G2's Libraries move is W2's; it can replace the three text lines there).
- Tabs touched minimally: Players, Guilds (helpers, picker, hint, strips), Filters (label, text area), Popups (text area, primary). Events' `CustomBox` (label + edit box) left as is.
- tui_compare: identical except the copy/import popup's edit box (all three looks): initial width 300 instead of 440 (the scroll frame sets the real width on size) and a TOPLEFT anchor on the scroll child as the Filters box already had. Intended: the popup now shares the Filters text area (cursor-follow guards, click in the box focuses it).
- The edit box hint hooks OnTextChanged (HookScript): a caller must not SetScript OnTextChanged on a hinted box.

## W4 (G22, G23), measured with tools/harness/bench_redraw.lua on the 3.4.0.28 save
Harness (stub frames, 200 redraws, 20 visible list rows, collection stopped); read the difference, not the absolute numbers. Timing varies about 30 percent between runs; garbage and call counts are exact.

| Tab, block event | KB garbage before | after | core calls before | after |
| --- | --- | --- | --- | --- |
| Players, PLAYER_BLOCKED | 10.98 | 9.00 | exception state 4, tip 4 | 0, 0 |
| Guilds, GUILD_BLOCKS_CHANGED (selected guild on screen) | 37.69 | 33.64 | guild walks 19 | 18 |
| Chat Filters, FILTER_HISTORY_CHANGED | 8.18 | 8.18 (not changed; no selection in the stub) | | |

Time per redraw: players about 105 to 120 us before, 62 to 100 after; guilds 1110 to 1530 us before, 830 to 1200 after (noisy).
- G22: `V:GuildCounts(key)` (Libraries PSS_GuildView.lua) reuses the drawn row's count only during the block redraw (`V.share`, set by the tab), so a reset or other change never shows a stale count.
- G23: `ns.ShowPlayerCounts` (Players) and `ShowCounts` (Guilds, guild and member panes) redraw the counts line, history and Summary only; any other pane falls back to the whole redraw. The exception tooltips are built when hovered (`ns.Tip` takes a function). Chat Filters pane not changed (its block redraw is already throttled and G21 removed the extra fires); W1/W2 may take it.
- `check_guilds.lua` gains the walk count and no-exception-rebuild checks.
- tui_compare: the only differences are W3's copy popup lines.
