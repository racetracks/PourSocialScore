# Combined notes: W3 and W4 (kit and redraw cost)

## W3 (G15 to G20)
- Kit (PSS_Kit.lua): `ns.NewButton(..., primary)` (G20), `ns.NewEditBox(parent, w, max, hint)` with `e.hint` (G18, the search box uses the same helper), `ns.NewTextArea(parent, size, max, pad)` -> panel with `.edit` and `.scroll` (G19).
- PSS_Detail.lua: `ns.NewLine`, `ns.NewLabel(parent, text [, x, y])`, `ns.NewStrip(parent, y, h, w)`, `ns.NewAllowedBoxes(parent, y, w, tip, onClick, rightClicks)` (G16, G17).
- PSS_Rows.lua: `ns.NewPicker(parent, anchor, {cols, stateW, fill, toggle, tickAll, save, close})` with `:ShowItems(title)` (G15). The tick/listed texts are still built inside the picker draw (G2's Libraries move is W2's; it can replace the three text lines there).
- Tabs touched minimally: Players, Guilds (helpers, picker, hint, strips), Filters (label, text area), Popups (text area, primary). Events' `CustomBox` (label + edit box) left as is.
- tui_compare: identical except the copy/import popup's edit box (all three looks): initial width 300 instead of 440 (the scroll frame sets the real width on size) and a TOPLEFT anchor on the scroll child as the Filters box already had. Intended: the popup now shares the Filters text area (cursor-follow guards, click in the box focuses it).
- The edit box hint hooks OnTextChanged (HookScript): a caller must not SetScript OnTextChanged on a hinted box.
