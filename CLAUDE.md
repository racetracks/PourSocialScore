# CLAUDE.md - PourSocialScore

PourSocialScore (PSS) is Dan's World of Warcraft chat moderation addon (in-game author Boaties): player and guild ignore lists, shipped managed community lists, a chat filter engine and block counts, drawn by a native window and, optionally, an EllesmereUI window.
Lua 5.1, WoW API only, no libraries. Clients: Retail 120007 (Midnight) and Camelot 16001; three TOCs per addon folder (base `120007, 16001`, `_Mainline`, `_Camelot`).

Repos: `racetracks/PourSocialScore` (this repo, private) and `racetracks/scratch` (test zips, handover packs, real saves).
Read-only references (learn behaviour, copy nothing, documented API only): EllesmereGaming/EllesmereUI (all rights reserved); Gethe/wow-ui-source.
Never write to `racetracks/PourSocialScore-EllesmereUI` (retired).

The full baseline this file condenses lives at
https://github.com/racetracks/scratch/tree/main/handover-packs/latest/wow-addon-baseline-files
(02_RULES, 07_WORKING_WITH_THE_AUTHOR, 09_RELEASE_PIPELINE, 10_FEATURE_DESIGN_AND_DELIVERY).
PSS's own pack (handover, rules, data and logging, status and next step) is at
https://github.com/racetracks/scratch/tree/main/handover-packs/latest/pss-handover-files
Where this file and the packs differ, this file wins for this addon.

## Layout
| Path | Loads | Role |
| --- | --- | --- |
| `PourSocialScore/` | Always | Core: chat filtering engine, block counting, outbox, setters, `M.Events`, loader (`PSS_Loader.lua`), options definitions, upgrades, GC helper (`PSS_Perf.lua`). Saves `PourSocialScoreDB` |
| `PourSocialScore_Options/` | Always | Data only: `PSS_OptionsDB`, `PSS_PlayersDB`, `PSS_GuildsDB`, `PSS_RulesDB`, `PSS_CountsDB` |
| `PourSocialScore_Libraries/` | On demand | Logic shared by both UIs: commands, guild, filter, totals and events queries, import/export |
| `PourSocialScore_GUI/` | On demand | Native Blizzard-styled window. Draws and calls core setters only |
| `PourSocialScore_EllesmereUI/` | On demand, integration on | EllesmereUI window, EllesmereUI's 4-space style. Saves `PSS_EllesmereUIDB` (EUI-only state) |
| `PourSocialScore_Logging/` | Only when logs are called | `PSS_LoggingDB` (block log, kept lines) |
| `PourSocialScore_Communities/` | On demand | Packed shipped guild lists (built with `tools/PSS_BuildManaged.lua`) |
| `tools/` | | `check_rules.sh`, `check_rules_eui.sh`, harness (`tools/harness/`) |
| `history.txt`, `readme.txt` | | Repo root; release.yml copies them into the zip |
| `.github/workflows/` | | `rules.yml` (Rules and harness checks), `release.yml` (tag and release on version bump) |

## Commands
```sh
sh tools/check_rules.sh                                   # Lua 5.1, ASCII, tabs, no UI in core; runs check_rules_eui.sh
sh tools/harness/check_eui_all.sh                         # EllesmereUI checks (CI runs them too)
PSS_REAL_SAVES=/mnt/project-files/baselines sh tools/harness/validate_all.sh   # must end 0 FAIL
sh tools/harness/ui_compare.sh origin/main <save.lua>     # look-compare, native window
sh tools/harness/eui_compare.sh origin/main <save.lua>    # look-compare, EllesmereUI window
```

## Code rules
- **Lua 5.1 only.** No goto, table.unpack, table.pack, bit32, utf8, _ENV, rawlen, 4-arg load.
- **ASCII only** in code, comments, strings, TOCs, readme.txt, history.txt. Non-ASCII as decimal escapes ("\195\169"). No em dashes or curly quotes.
- **Match the surrounding code**: copy the shape of the nearest example (naming, comment density, idiom).
- **Tabs**, no alignment spaces, no trailing whitespace (a suite integration folder follows that suite's style).
- **Localize everything.** One global root table named after the addon; nothing else global except SavedVariables and frame names the client needs. Localize hot API (`local UnitName = UnitName`), within Lua 5.1 limits.
- **No UI code in core logic.** Core fires named events on its bus; UIs subscribe while open, unsubscribe on close, write only through core setters.
- **No application logic in a UI folder.** Counting, queries, totals, scans live in core or the library folder.
- **Front ends are independent**: a UI never reads another UI's folder; anything both need lives in the library folder. One options table in core.
- No libraries (Ace, LibStub) unless the author agrees. No test-only globals.
- Copy logic, never code or IDs, from other addons. Respect licences.

## Performance and data
- **Zero cost unless enabled**; new settings **default OFF**; no behaviour change without opt-in (bug fixes excepted).
- Low cost when enabled: event-driven, no OnUpdate polling, no wall-clock timers as logic gates, no per-frame allocations.
- **Zero taint risk**: never touch secure frames or protected functions; `hooksecurefunc` only where safe; defer protected work until out of combat.
- No UI at login: windows build on first open. Reuse frames, unregister unneeded events, batch and coalesce redraws, cache and pace API queries.
- `t[#t + 1] = v`, not `table.insert`, for appends. Garbage collection only on request, at quiet moments detected from events.
- **Measure, never estimate**: `collectgarbage("count")` for resident cost, `luac -s` for size, a benchmark for CPU. Numbers go in the PR.
- **SavedVariables must not grow**: every store capped and pruned; no default-valued fields; database separate from runtime cache; lazy indexes.
- Every layout change gets a numbered run-once migration. **Ask the author before any SavedVariables layout change** and validate on every old layout and the author's real saves.
- **Never commit real saves to this repo.** They live in the hosting repo by version.

## TOCs, versions, releases
- One version in every TOC of the repo; all folders release together.
- **Never change TOC Title or Notes unless the author asks.**
- A feature owns a line `X.Y.0`. Every build before it is complete is `X.Y.0-devNNN` (three digits, from dev001, never reused). One merged PR = one devNNN.
- **Never drop the suffix early**: any version without `-` publishes as a full release.
- Bugfixes are the next devNNN. After a production release, fixes start `X.Y.1-dev001`.
- The plain `X.Y.0` is set only when the author confirms the feature is complete.

## Workflow
1. **Plan first** for anything big: numbered steps, say what is impossible, numbered questions each with a recommendation. Build on the recommendation; change course if the author picks otherwise.
2. **One step per PR, based on the latest `origin/main`.** No stacked PRs. A refactor that should change nothing is its own step.
3. Every step: bump every TOC to the next devNNN; add a history.txt section at the top (`=> X.Y.Z - Title`, plain bullets); update readme.txt if users see a change.
4. Before pushing: rules check, harness against real saves, look-compare for any window that may change.
5. Fill in the PR template: stage, devNNN, measured cost, look-compare result, numbered in-game checks.
6. Build the test zip (`git archive HEAD`, addon folders at the zip root), host it in the hosting repo under `PourSocialScore/test-builds/`, reply with the link.
7. **The author tests in game and merges.** Claude does not merge, delete branches or ship production on its own.
8. If `gh pr create` is blocked, use REST: `gh api repos/racetracks/PourSocialScore/pulls -f title=... -f head=... -f base=main -f body=...`.
9. No model names in repo files; commits and PRs carry the attribution lines the session gives.

## Communication
- Plain language, answer first, short. Always give links, never only paths.
- Questions numbered, answerable in one word, recommendation marked.
- Re-read the newest message before building; play final decisions back.
- Study screenshots closely before guessing a fix.
- "PR?" means open it now and send the link.

## Addon-specific rules
Full list with Dan's wording: `pss-handover-files/02_RULES.md` in scratch.
- **Namespace:** everything shared hangs on `M` via `PourSocialScore_NS`. Use `M.ShowMsg`, `M.Trim` and the UIKit builders (`UI.CreateWindow`, `UI.InputBox`, `UI.NumberBox`, `UI.TextArea`, `UI.ScrollList`). Options: one `M.PSS_OPTIONS` table, read `M.PSS_Opt`, write `M.PSS_SetOpt`. Load parts with `M.PSS_Need(key)`, logging with `M.PSS_LoadLogging()`.
- **Style:** tabs everywhere except `PourSocialScore_EllesmereUI` (4 spaces, `tools/check_rules_eui.sh`, which also checks its Version equals core's).
- **TOCs:** Title `|cff69ccf0PourSocialScore|r <Part>`; core Notes are Dan's wording and never change; every TOC has `## Category: PSS`, `## Group: PourSocialScore`, `## IconTexture: Interface\FriendsFrame\Battlenet-Portrait`.
- **Core placement (2026-10-05):** core is only the chat filtering engine and the launchpad. Anything not regularly active, including code both UIs share, goes in `PourSocialScore_Libraries`, with a measured resident cost.
- **Front ends independent (2026-10-05):** no application logic in `_GUI` or `_EllesmereUI`; the native GUI never reads or loads a file from the EllesmereUI folder, and the reverse.
- **Parity:** every number the EllesmereUI window shows equals the native window's, same definitions ("this session" = since login or /reload). `check_match.lua` gates it.
- **Porting to native (G7 to G10, 2026-10-05):** only our own or Blizzard resources; look as close as possible to the EUI version; copy our own EUI code as functions into `_GUI` when smaller, never EllesmereUI's code. The EUI folder is read only during parity work, except moving logic into Libraries with `eui_compare.sh` identical (issue 77, option b).
- **Counting:** never derived from log lines; guild rule blocks count only as guild blocks; a rule turned off disables every guild in it (`M.PSS_GuildRuleActive`). A guild rule never blocks your own guild (`M.PSS_IsOwnGuild`).
- **W I G P C** flags: ticked = allowed; a new entry blocks everything; built-in filters start off. Removal deletes all of a player's saved data.
- Every window closes on Escape. The 8 StaticPopup dialogs stay as they are. Logging loads only when logs are called.
- **Garbage collection (2026-10-07):** event-driven only, on request, out of combat and not in an instance. `PSS_Perf.lua` still has the old 10-minute idle cycle and heap-growth trigger; leave it until Dan asks.
- **Known deviations, record only (2026-10-07):** the dev004 totals pane shows without opt-in; `PSS_Pie.lua` and a UIKit helper use OnUpdate while hovered or dragging. Raise them when that code is next touched.
- **Versions:** the 3.3.0 line is the native GUI parity feature (issue 78); plain `3.3.0` only when Dan says parity is done. Old `-devN` (one digit) names are not copied. A 3.2.0 fix would be `3.2.1-dev001`; ask first.
- **SavedVariables:** layout changes need Dan's OK and a migration validated on the three real saves (`pss-projects/savedvariables/` in scratch: 2.0.44, 3.0.0, 3.2.0-dev011).
- **Hosting on scratch:** test zips `PourSocialScore/test-builds/PourSocialScore-<version>.zip`; plans `pss-projects/<project>/`; issue notes `pss-issues/`.
