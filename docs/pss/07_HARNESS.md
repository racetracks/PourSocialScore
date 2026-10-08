# PSS harness (tools/harness)

The general harness is baseline 06. PSS's commands, as of 3.4.0-dev002. Needs `lua5.1` (apt) and `git fetch --depth=2000 origin main` (compares, and `validate_all.sh`'s upgrade checks, which rebuild old versions from history: in a shallow clone its "split" checks fail on 2.0.1 and 2.0.40). Real saves: if `/mnt/project-files/baselines` is missing, copy scratch (`racetracks/Pour-Social-Score_Scratch`) `SavedVariables/<version>/` to `/mnt/project-files/savedvariables/<version>/` and concatenate each set into `/mnt/project-files/baselines/<version>/PourSocialScore.lua`.

| Command | Proves |
| --- | --- |
| `sh tools/check_rules.sh` | Lua 5.1, ASCII, tabs, layers; with `tools/check_rules_eui.sh` for the EUI folder |
| `PSS_REAL_SAVES=/mnt/project-files/baselines sh tools/harness/validate_all.sh` | Upgrades from every old layout and all three real saves; data checks; `check_match.lua` and `check_managed_row.lua` on each real save; must end 0 FAIL |
| `sh tools/harness/check_eui_all.sh` | The EllesmereUI window builds and behaves (players, guilds, filters, popups) against `tools/harness/eui_stub` |
| `sh tools/harness/ui_compare.sh <ref> <save>` | The native window is unchanged against `<ref>` ("UI identical") |
| `sh tools/harness/eui_compare.sh <ref> <save>` | The same for the EUI window: a tour (`eui_tour.lua`) clicks tabs, rows, View Events, slices, ticks and searches, about 482 snapshots |
| `lua5.1 tools/harness/run.lua . - - tools/harness/check_tui.lua` | The new window (09): not loaded at login; `/pss tui` loads Libraries and UI only; place, Escape; the three looks and repaint; the kit in Blizzard and Dark; tab labels and art; tooltips; class colour accent; fonts with LibSharedMedia present and absent. In `validate_all.sh` and the Rules CI |
| `sh tools/check_toc.sh <folder>` | A folder's three TOCs agree (all fields but Interface), list the same existing files, and carry core's version (`X.Y.Z`, `-suffix` or `-suffix_N`); run for every folder by `check_rules.sh` |
| `lua5.1 tools/harness/run.lua . <save> - tools/harness/check_match.lua` | Both windows show the same session / 24 h / all-time and per-type numbers, including the native totals pane |

Other checks worth knowing: `check_keep`, `check_ondemand`, `check_recent`, `check_savedlog`, `check_growth`, `check_ownguild`, `check_guildrule`, `check_communities_seen`; `bench_recent.lua` (the benchmark behind the 144-slot layout); `show_totals.lua`, `dump_counts.lua` for inspection.

Stub (`wow_stub.lua`) additions for the new window: font objects with `GetFont` / `SetFont` (recorded), `GetShadowOffset` / `GetShadowColor`, `CreateFont`, `GetPoint`, `IsPlaying`, `GameFontDisable`, `ChatFontNormal`, and the parts of `ScrollFrameTemplate`, `InsetFrameTemplate`, `PanelTopTabButtonTemplate`. Widgets expose their Dark parts as `widget.pssParts` and the window its looks' art as `PSS_Window.art`, so checks reach them through frames (no test-only globals). Unknown `Set*`, `Scroll*` and similar calls return a no-op, so check a template part's type before indexing it.

PSS habits: a check that needs Libraries calls `M.PSS_Need("Libraries")` first; silence eui_compare's phase 1 on a save that already has the integration on; read every diff line on a real save before claiming "intended only".
