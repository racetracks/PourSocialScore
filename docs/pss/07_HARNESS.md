# PSS harness (tools/harness)

The general harness is baseline 06. PSS's commands, as of 3.3.0-dev004. Needs `lua5.1` (apt) and, for compares, `git fetch --depth=1000 origin main`.

| Command | Proves |
| --- | --- |
| `sh tools/check_rules.sh` | Lua 5.1, ASCII, tabs, layers; with `tools/check_rules_eui.sh` for the EUI folder |
| `PSS_REAL_SAVES=/mnt/project-files/baselines sh tools/harness/validate_all.sh` | Upgrades from every old layout and all three real saves; data checks; `check_match.lua` and `check_managed_row.lua` on each real save; must end 0 FAIL |
| `sh tools/harness/check_eui_all.sh` | The EllesmereUI window builds and behaves (players, guilds, filters, popups) against `tools/harness/eui_stub` |
| `sh tools/harness/ui_compare.sh <ref> <save>` | The native window is unchanged against `<ref>` ("UI identical") |
| `sh tools/harness/eui_compare.sh <ref> <save>` | The same for the EUI window: a tour (`eui_tour.lua`) clicks tabs, rows, View Events, slices, ticks and searches, about 482 snapshots |
| `lua5.1 tools/harness/run.lua . <save> - tools/harness/check_match.lua` | Both windows show the same session / 24 h / all-time and per-type numbers, including the native totals pane |

Other checks worth knowing: `check_keep`, `check_ondemand`, `check_recent`, `check_savedlog`, `check_growth`, `check_ownguild`, `check_guildrule`, `check_communities_seen`; `bench_recent.lua` (the benchmark behind the 144-slot layout); `show_totals.lua`, `dump_counts.lua` for inspection.

PSS habits: a check that needs Libraries calls `M.PSS_Need("Libraries")` first; silence eui_compare's phase 1 on a save that already has the integration on; read every diff line on a real save before claiming "intended only".
