# The offline harness

WoW can't run in CI, so the addon runs under plain `lua5.1` with a stub of the WoW API: a simulated client. Starters are in `examples/` (real tooling from a working addon, renamed to MyAddon; its README.txt says where each file goes). Once copied, the addon repo's live `tools/` and `tools/harness/` win; the addon pack's harness doc names the live scripts and commands.

## Pieces
| Piece | Starter | What it does |
| --- | --- | --- |
| `wow_stub.lua` | examples/ | Fake globals: CreateFrame (frames, textures, font strings, lines), C_AddOns, C_Timer (queued, run by the harness), GetTime/time with a settable clock, chat events, StaticPopup, GameTooltip, GetCursorPosition. Grow it as the addon uses more API |
| `run.lua <addonDir> <svIn or -> <svOut or -> [script.lua]` | examples/ | Reads TOCs like the client (dependencies first, LoadOnDemand only on LoadAddOn, a private `...` per addon, ADDON_LOADED after files run), loads SavedVariables, logs in, runs a check script with the stub and the addon's root table as globals, logs out and writes SavedVariables back |
| `check_*.lua` | addon-specific | One script per behaviour; prints PASS / FAIL lines |
| `validate_all.sh` | addon-specific | Generates saves for every old layout, runs the migrations on them and on **the author's real saves**, then every check; must end with 0 FAIL, and a check that could not run is a failure, not a pass |
| `ui_compare.sh [ref] [save]` | examples/ (the tour script is addon-specific) | Builds every window and tab on both trees through a tour script, snapshots every frame (anchors, sizes, texts, calls) and diffs. One per front end; a suite UI gets its own tour |
| `check_style.lua`, `check_layers.lua` (with `lua_segments.lua`) | examples/ | Lua 5.1 bans, tabs, trailing whitespace (`--fix`); no UI calls in core logic files (02 A9). Called from `check_rules.sh` (templates/tools/) |

## What to test
- Migrations from every released version's save and from every real save the author sends.
- Caps: fill a store past its cap; it trims and the save shrinks (a growth check).
- Load on demand: a part stays unloaded through login and normal events and loads only when called.
- Counting: counts at event time match; nothing doubles.
- **Numbers match** when two windows show the same data: read both on every real save and fail on any difference.
- Each UI: every page builds, every option has a row, a change in one UI shows in the other.
- Chat and unit paths with secret values (02 J7).

## Habits that paid off
- **Drive the changed path while coding**: load a save, fire the events, commands and clicks that reach the change, and read the real output, not only the PASS line.
- **Look-compare every UI change** against the base branch on a real save. A UI-neutral change comes out identical; a UI change differs only where intended, and the PR lists which differences remain.
- **Sabotage each new check once**: break the code on purpose, see it fail (or run it against main), restore.
- **Silence setup phases** whose failures are expected.
- **Real saves by version** live in the hosting repo (never the addon repo, 02 D10). A small script builds the runner's input from them: one file per version, the save files concatenated core first.
- A check that needs a load-on-demand part loads it first through the loader.
- Say in the PR what a simulation cannot show (wrapped text, combat and chat lockdown timing, taint, client art) and cover it in the in-game checks.

## Setup in a session
```sh
apt-get install -y lua5.1             # if missing
git fetch --depth=2000 origin main    # deep enough for the upgrade checks to rebuild old versions
sh tools/check_rules.sh
sh tools/harness/build_saves.sh <hosting checkout> <out dir>
MYADDON_REAL_SAVES=<out dir> sh tools/harness/validate_all.sh
sh tools/harness/ui_compare.sh origin/main <out dir>/<version>/MyAddon.lua
```
