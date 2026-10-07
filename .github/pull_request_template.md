## Summary
<!-- One or two lines: what this step does for the user, or "no visible change". -->

## Stage
| Field | Value |
| --- | --- |
| Feature line | `X.Y.0` |
| Version | `X.Y.0-devNNN` |
| Stage | N of M: <groundwork / data / visible slice / polish / bugfix / release> |
| Visible change | Yes / No |
| Design doc | https://github.com/racetracks/scratch/tree/main/pss-projects/<project> |

## Changes
- 

## Measured cost
<!-- Measured, never estimated. Delete rows that do not apply. -->
| What | Before | After |
| --- | --- | --- |
| Resident memory (`collectgarbage("count")`) | | |
| Compiled size (`luac -s`) | | |
| Save size on real saves | | |
| CPU (benchmark) | | |

## Validation
- [ ] `sh tools/check_rules.sh` clean (Lua 5.1, ASCII, tabs, no UI in core logic, EUI style)
- [ ] `sh tools/harness/check_eui_all.sh` clean
- [ ] Harness `validate_all.sh`: 0 FAIL, including the author's real saves
- [ ] `ui_compare.sh` vs `origin/main`: identical / only these differences: 
- [ ] `eui_compare.sh` vs `origin/main`: identical / only these differences: 
- [ ] Migration run on every old layout and real saves (if saved data changed)
- [ ] Numbers match across front ends (`check_match.lua`)
- [ ] Option off: no events, frames, hooks or memory (if a feature sits behind an option)
- [ ] Earlier stages' checks still pass

## Housekeeping
- [ ] Every TOC bumped to this version; Title and Notes untouched
- [ ] history.txt section added at the top (`=> X.Y.Z - Title`)
- [ ] readme.txt updated (if users see a change)
- [ ] New settings default OFF
- [ ] No SavedVariables layout change, or the author approved it
- [ ] No real saves, secrets or model names committed

## Test build
Zip: https://github.com/racetracks/scratch/raw/main/PourSocialScore/test-builds/PourSocialScore-X.Y.0-devNNN.zip

## In-game checks
1. 
2. 
3. 
