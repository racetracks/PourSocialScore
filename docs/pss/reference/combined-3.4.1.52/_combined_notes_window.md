# Combined delivery notes: window thread (W1, W2)

Scratch notes for the lead; not part of the packs. Scope after the lead's changes: W1, then W2 for the Players tab, Guilds tab, History/Detail, shared row menus and nav only. W3, W4 and the Filters, Events and Options tab findings belong to other threads.

## W1 (G11 to G14, G24, G25, G29)
- G11: `M.PSS_EnsureMemberBlockData(m)` call dropped from `ShowMember` (the next read runs it).
- G12: removed `ns.CloseMenu`, `ns.DETAIL_PAGES`, `ns.ResetTab`, `pg.openMembers`, both `picker.cancelButton`, `M.PSS_GuildPickerToggle` / `TickAll` aliases (Guilds calls the shared names), `M.PSS_HexColor`, `M.PSS_TypeOff`, `M.PSS_AnyTypeOff` (`check_viewquery.lua` now tests `M.PSS_TypesOn()` alone).
- G13: the "comes in a later 3.4.0 build" note is not built. Harness checks of `page.note` (check_players, check_guilds, check_filters, check_options, check_tui) now assert it is gone. check_filters and check_options are other threads' tabs: one-line harness edits only.
- G14: header comments say Modern, Classic, Dark (Skin, Kit, Rows, Window). Text only.
- G24: leaving a menu slot resets that slot's text alpha only (no full redraw).
- G29: menu divider uses `ns.NoSnap` and `ns.OnePixel` (drawn height). Visible only at UI scales under 1.
- G25: `BAR_BUTTONS` hoisted in PSS_Kit.lua (one line in the kit, a hoist, no behaviour); `UpdateNav` reuses its parts tables and caches the per-tab reset closure; one `RunQueued` per file (Guilds, Filters; Filters is another thread's file, hoist only); `HV:Set` compares id, total and ready instead of building a key string; `M.PSS_PlayerListedText(r)` (Libraries PSS_PlayerView.lua) makes each "Nd" string once.
- Validation: check_rules ok; validate_all with the real saves ok ("All upgrade checks passed"); check_tui part of it.
- tui_compare vs origin/main: not byte-identical, because G13 removes one FontString per page, which shifts the dump's automatic frame numbers (`Frame#13` ...) and so the sort order. With the numbers stripped and both dumps sorted, 0 differing lines (all 125 and 139 steps, three looks). For W2 the compare is made against the W1 commit.
- Compiled (luac -s, GUI / Libraries bytes): 206247 / 148166 on main, 206010 / 147941 after W1 (the Libraries drop includes the removed aliases; `PSS_PlayerListedText` is added).

## W2 (G1 to G8, G3 to G7 for the Players and Guilds tabs; Filters, Events, Options findings left to the other thread)
- Done: G1 (history row/tip: `M.PSS_HistCells`, `M.PSS_HistTip`, `M.PSS_HistEmptyText` in PSS_DetailQuery.lua; the GUI `TIME_FMT` is gone; PSS_EventsView.lua was NOT touched, it still has its own `TimeText`, so the Events thread can later switch it to share the format), G2 (`M.PSS_PickerCells` in ViewNav, used by both pickers), G3 (`M.PSS_GuildPaneView`, `M.PSS_MemberPaneView`, `M.PSS_MemberCells`, `M.PSS_GuildExists`, `M.PSS_GuildOpts`, `M.PSS_GuildToggleException`, `M.PSS_MemberToggleException`; `M.PSS_GuildScanTip` takes a key or a record), G4 (`v:RemoveTarget()`), G5 for the Guilds tab (`v:MarkDirty(guilds, members)`; the Filters line left alone), G6 (`v:EmptyText()`, `v:SearchHint()`, history text constant), G7 (`M.PSS_GuildSummarySpec`, `M.PSS_MemberSummarySpec`, `M.PSS_GroupSummarySpec`, `M.PSS_PlayerSummarySpec`, `M.PSS_PlayerExpireBoxText`, button text as third return of `M.PSS_PlayerGuildState`; Filters left alone), G8 (`M.PSS_TypeTip`, `M.PSS_SpecCopy`).
- Skipped by scope: G9 (Events), G10 (Options), the Filters parts of G5 and G7.
- Deviation: the pane views return the saved record as a handle (`record`, `rule`, `opts`) because the exception and W I G P C boxes still take the record; the GUI no longer reads a field of it. For S3's sparse member records, `M.PSS_MemberCells` and `M.PSS_MemberPaneView` are now the only places the window reads `m.note` and `m.class`.
- Harness: new `check_viewfns.lua` ("== view functions" in validate_all.sh; every function above, fails on main where they do not exist). check_layers passes (rules check).
- Validation: check_rules ok; validate_all with the real saves "All upgrade checks passed"; tui_compare against the W1 commit: identical (125 steps, 3 looks). Wrapped-line `Line()` stacks were not changed.
- Compiled (luac -s, GUI / Libraries bytes): 206010 / 147941 after W1, 203220 / 154429 after W2 (logic moved: GUI -2790, Libraries +6488). Resident cost is Libraries only, loaded on demand with the window.
