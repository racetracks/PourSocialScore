# Addon-specific pack layout

This baseline stays general. The addon pack holds only what is true of one addon, kept current in every PR (02 E10), with its newest copy hosted as the hosting pack describes (versioned, the markdown readable unzipped).

```
00_README.md            how to restart; file index
01_HANDOVER.md          the state document: the addon as it works at the last full release
                        (purpose, repos written and reviewed, folders, real names, crucial
                        context, plans with status); re-summarized at each release (02 E11)
02_RULES.md             only the rules this addon adds to the baseline, dated, ending with
                        the Overrides table (approved overrides, known breaches with their fix)
03_<INTEGRATION>.md     the addon's suite integration, if any: its files, APIs used, lessons
04_DATA.md              SavedVariables layout, caps, upgrade steps
05_RELEASE.md           anything the addon does differently from the baseline pipeline
06_STATUS_AND_NEXT.md   the live release, main, the current project and stage, the next
                        step, items waiting on the author, open issues
07_HARNESS.md           the live harness commands and checks
<NN>_<PLAN>.md          the current project's design and stage table (state, PR, next build)
<NN>_PREFERENCES.md     the author's preferences and approach: the one file, dated (02 E11)
reference/              older plans, handovers and snapshots (history)
```
The author's real saves live in the hosting repo by version, never in the pack or the addon repo (02 D10). The project instructions (`CLAUDE.md`) point to these files and load only the lean set every session needs.

Write it so a fresh Claude never has to ask the author something already decided.
