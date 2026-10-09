#!/bin/sh
# Builds the tests bundle from the committed HEAD and hosts it on scratch
# beside the addon's test zip (the release and test zips never hold tools/):
# releases/PourSocialScore-<version>-tests-<YYYY-MM-DD-hh-mm>.zip. It holds
# tools/ (checks, harness, versions.py, bump script), versions.json, the CI
# rules files (.github/workflows), README_TESTS.txt and, with --log, the
# validation log. Never real saves. latest/ is not touched; the only index
# change is the tests zip's name on the releases/ row of scratch's readme.md.
# Prints the link. Run from the addon repo root.
#   sh tools/host_tests.sh <scratch checkout> [--no-commit | --no-push] [--log <file>]
# --no-commit stages the files only (one commit per delivery); --no-push
# commits without pushing. The log comes from
#   PSS_VALIDATION_LOG=<file> sh tools/harness/validate_all.sh
ADDON=PourSocialScore
SCRATCH_URL=https://github.com/racetracks/Pour-Social-Score_Scratch
scratch=
mode=
log=
while [ $# -gt 0 ]; do
	case $1 in
	--no-commit | --no-push) mode=$1 ;;
	--log) shift; log=$1 ;;
	*) if [ -z "$scratch" ]; then scratch=$1; fi ;;
	esac
	shift
done
if [ -z "$scratch" ] || [ ! -d "$scratch/.git" ]; then
	echo "usage: sh tools/host_tests.sh <scratch checkout> [--no-commit | --no-push] [--log <file>]"
	exit 1
fi
if [ -n "$log" ] && [ ! -f "$log" ]; then
	echo "log file not found: $log"
	exit 1
fi
if [ -n "$(git status --porcelain -- tools .github versions.json)" ]; then
	echo "Commit the tools changes first: the bundle is built from HEAD"
	exit 1
fi

ver=$(sed -n 's/^## Version: *//p' "$ADDON/$ADDON.toc" | tr -d '\r')
stamp=$(date -u +%Y-%m-%d-%H-%M)
name=$ADDON-$ver-tests-$stamp.zip
logname=validation-$ver-$stamp.log

work=$(mktemp -d)
mkdir "$work/zip"
git archive HEAD tools .github/workflows versions.json | tar -x -C "$work/zip" || exit 1
find "$work/zip" -name __pycache__ -type d -prune -exec rm -rf {} +
if [ -n "$log" ]; then
	cp "$log" "$work/zip/$logname"
fi
cat > "$work/zip/README_TESTS.txt" <<TXT
PourSocialScore $ver tests bundle ($stamp)

This is not an addon. The addon's test zip never holds tools/. Unzip this
bundle over a checkout of the addon repo at the same version (the checks read
the addon's folders, git history and versions.json). No real saves are in it.

1. Install Lua 5.1:  apt-get install -y lua5.1
2. The checks rebuild old versions from git history:
     git fetch --depth=2000 origin main
3. Rules check (Lua 5.1, ASCII, tabs, TOCs, layers, schema, history):
     sh tools/check_rules.sh
4. Real saves live on the scratch repo (SavedVariables/<version>/). Build the
   harness input from a scratch checkout:
     sh tools/harness/build_saves.sh <scratch checkout> <out dir>
5. The full harness (upgrades from every old layout, every tab's check, the
   real saves). Must end "All upgrade checks passed":
     PSS_REAL_SAVES=<out dir> sh tools/harness/validate_all.sh
   Add PSS_SAME_AS=origin/main for a stage that must not change the saved
   data (saves byte-identical with main). Add PSS_VALIDATION_LOG=<file> to
   keep the whole output in a file.
6. The window in all three looks (Modern, Classic, Dark), compared with a ref;
   "identical" for a change that should not show:
     sh tools/harness/tui_compare.sh [ref] [save]
7. Releases and versions (reads versions.json):
     python3 tools/versions.py check
     sh tools/bump_version.sh build "Title"

More: docs/pss/07_HARNESS.md in the addon repo.
TXT
if [ -n "$log" ]; then
	printf '\nThe validation log of this build is %s.\n' "$logname" >> "$work/zip/README_TESTS.txt"
fi
(cd "$work/zip" && zip -qr "../$name" .) || exit 1

cd "$scratch" || exit 1
git pull -q origin main || exit 1
cp "$work/$name" "releases/$name"
# the releases/ row of the index: this tests zip's name after the others
sed -e "/^| \[releases\/\]/s/, $ADDON-[0-9][0-9.]*-tests-[0-9-]*\.zip//" \
	-e "/^| \[releases\/\]/s/ |\$/, $name |/" readme.md > readme.md.new && mv readme.md.new readme.md
rm -rf "$work"

git add "releases/$name" readme.md
if [ "$mode" != "--no-commit" ]; then
	git commit -q -m "$ADDON $ver tests bundle ($stamp)" || exit 1
	if [ "$mode" != "--no-push" ]; then
		git push -q origin HEAD:main || exit 1
	fi
fi
echo "$SCRATCH_URL/raw/main/releases/$name"
