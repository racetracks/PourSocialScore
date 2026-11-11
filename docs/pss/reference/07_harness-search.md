# Harness: Search Everywhere timing and results
Purpose: detail of the three search harness files (TST-00988, TST-00989, CHK-00232) · owner PSS pack · status current · related [07_HARNESS.md](../07_HARNESS.md)

## Commands
| `sh tools/harness/search_same.sh <ref> <saves dir>` ([search_same.sh:1](../../tools/harness/search_same.sh)) | Search Everywhere speed work (`TST-00988`, `TST-00989`; build 3.8.0.144; not in `validate_all.sh`): per real save (`<saves dir>/<client>/<version>/`, `PSS_FLAVOUR` from the client folder) and a seeded fresh save, the rows of `search_results.lua` from `<ref>` and from the tree must be identical (last lines `same: n saves, d differ`, exit 1 when d > 0); then `bench_search.lua` on the tree; prints the `CASE`, `TERM` and nine `ADMIT` lines (max over saves) and `REPRO yes\|no` (a tbc or forever term run of 200 ms or more, `CHK-00232`) |
| `lua5.1 tools/harness/run.lua . <save or -> - tools/harness/bench_search.lua` ([bench_search.lua:1](../../tools/harness/bench_search.lua)) | The seven timing cases (holders, keys, watch, rows, restale, mine, spyglass), the `TERM` lines of the terms `a`, `ar`, `ore` and this save's `ADMIT` lines (`specs/search.md` sections 8 and 9); needs `PSS_WH_SEED=1 PSS_COMPONENTS=addons,gfx,warehouse,bags` and `PSS_BENCH_LABEL=<client>/<version>` |
| `lua5.1 tools/harness/run.lua . <save or -> - tools/harness/search_results.lua` ([search_results.lua:1](../../tools/harness/search_results.lua)) | The result dump: `R` rows for eight search texts, `H` holder lines, then after a `wh.delete` of the first other entity the `R2` rows (same environment as above) |

## Bench
Code: `tools/harness/bench_search.lua:1`. Lines: `CASE <case> <label> k=v` (holders, keys, watch, rows, restale, mine, spyglass), `TERM <client> <version> <term> max_ms= total_ms=` (terms a, ar, ore), `TYPED <client> <version> a/ar/are max_ms= total_ms= loads= refreshes=` (cold item cache, typed through the box, 50 loads per slice, every saved item id unknown), `ADMIT <id> yes|no k=v`. Environment: `PSS_WH_SEED=1`, `PSS_COMPONENTS=addons,gfx,warehouse,bags`, `PSS_BENCH_LABEL=<client>/<version>`.

## Results
Code: `tools/harness/search_results.lua:1`. Lines `R`, `H`, `DEL`, `R2`; the first entity other than the current character is deleted.

## Runner
Code: `tools/harness/search_same.sh:1`. Last lines: `same: n saves, d differ`, nine `ADMIT`, `REPRO yes|no` (a tbc or forever `TERM` or `TYPED` `max_ms` of 200 or more). `tools/harness/search_same.sh:33` also compares the `L` lines of `tools/harness/log_results.lua`; a difference prints `DIFF log: <label>`, no `L` lines `FAIL log: <label>`.

## Log results
Code: `tools/harness/log_results.lua:1`. Command: `lua5.1 tools/harness/run.lua . <save|-> - tools/harness/log_results.lua`. Environment: `PSS_COMPONENTS=logging,warehouse`. Lines `L <q> n=<rows>` and `L <q> <i> <col>...` (tab-separated, `set.cols` order) for seven queries.
