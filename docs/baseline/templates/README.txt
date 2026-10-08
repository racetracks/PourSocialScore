Copy into the new repo: .github/workflows/*, tools/*.sh, and the TOC set
into the main addon folder (MyAddon/). Rename MyAddon everywhere. Add
tools/check_style.lua and tools/check_layers.lua from ../examples (adapt names)
or drop their lines from check_rules.sh. history.txt and readme.txt sit at the
repo root; release.yml copies them into the main folder of the zip.
tools/bump_version.sh sets the next version (build, release or a new line) in
every TOC and adds the history section; tools/host_build.sh builds the test
zip from HEAD and hosts it (set SCRATCH_URL); collect_notes.sh and
summarize_notes.sh write a full release's notes (release.yml calls them). Set
MIRROR_REPO in release.yml, or delete the mirror job.
