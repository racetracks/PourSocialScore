# Layout and naming

Purpose: the scratch repo folder layout and naming · owner scratch pack (`docs/scratch/`) · status current · related docs/scratch/04_USAGE.md, docs/scratch/05_RULES.md

```
readme.md                               the index: one line per folder, newest file named
CLAUDE.md                               Claude's criteria for this repo
SavedVariables/<version>/               the author's WTF saves written by that version (*.lua); README lists them
releases/                               <Name>-<version>-<YYYY-MM-DD-hh-mm>.zip  every pre-release build
latest/                                 the newest build zip only
docs/
  README.md                             what each folder and pack is, and how to restart a project
  <name>-<date>-vN.zip                  every docs release / handover pack, zipped
  <project-or-feature>/                 history for a project or feature release
  latest/<project-or-feature>/          the newest markdown, unzipped
  components/<component>/               live component designs and plans (until moved to documents/, DEC-00043)
documents/                              approved documentation (the source of truth), from 2026-10-10
  addons/<addon folder>/  features/<feature>/  sub-features/<sub-feature>/  <project-wide>/ (reference-framework)
drafts/                                 drafts, same groups as documents/ (DEC-00044)
  addons/  features/  sub-features/     drafts/<group>/<name>-<YYYY-MM-DD>-draftN/
  <project-wide>-<date>-draftN/         project-wide drafts at the root
history/<addon|feature|sub-feature|project>/YYYY-MM-DD-<folder>/   retired documentation and promoted drafts (DEC-00045, DEC-00046)
temp/<YYYY>/<MM>/<DD>/<hh-mm-ss>-<Ddd>-<workspace>/  workspace memory, prompt log (the one exception to the documentation rules)
  .next/NEXT.md                         that session's latest next-session handoff, overwritten at every delivery (DEC-00398)
.next/NEXT.md                           the newest handoff of any session, read first at session start; format in .next/README.md
temp/MOVED.md                                 old flat roots (before 2026-10-15) moved into the dated layout, old path to new (DEC-00397)
summary/                                <project>-<YYYY-MM-DD-hh-mm>.md  status summaries
```

## Naming
- A moved folder leaves a pointer at its old path: a `Readme.md` and a one-line stub for every markdown file, so old links keep working (DEC-00048).
- Folder names are plain words, not codes.
- Timestamps are `YYYY-MM-DD-hh-mm`; pack versions are `<date>-v1`, `-v2`, ...
- Zip names carry the version: `<Name>-1.4.0.4-2026-10-07-21-44.zip`, `<pack>-2026-10-07-v3.zip`.
- Saves are filed by the version the author names ("this is a 1.2.0 save"), not by the date.
