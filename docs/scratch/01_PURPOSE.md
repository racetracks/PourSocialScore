# Why a scratch repo

- Anything the author needs to download or read goes in scratch and the reply carries a link; sessions cannot hand over files any other way.
- One private repo serves every addon project, so links look the same everywhere and nothing is lost between sessions.
- It is the project files: saves, plans, docs, test zips and summaries live only here. It keeps what must never enter an addon repo (real SavedVariables, test zips, handover packs).

## What goes in scratch
| Kind | Example |
| --- | --- |
| Test builds | An installable zip for every build, bugfixes included |
| Handover packs and docs | Zipped packs, and their newest markdown readable in the browser |
| SavedVariables | The author's real WTF saves, by the addon version that wrote them |
| Plans and issue notes | Analysis, plans, decisions; long write-ups linked from an addon issue |
| Summaries | Short status summaries |

## What never goes in scratch
- Secrets, tokens or anything credential-like.
- Source that belongs in an addon repo (scratch hosts builds of it, not its source of truth).
- Files over GitHub's 100 MB limit.
