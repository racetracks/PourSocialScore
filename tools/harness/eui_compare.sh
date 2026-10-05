#!/bin/sh
# Checks that the EllesmereUI window looks the same as another version:
# runs eui_tour.lua on both with the EllesmereUI stand-in (the integration
# switched on first, as check_eui_window.lua phase 1 does) and compares what
# each step showed.
#   sh tools/harness/eui_compare.sh [git ref, default origin/main] [save.lua]
# Exit 0 when identical; the differences are printed otherwise.
here=$(dirname "$0")
ref=${1:-origin/main}
sv=${2:--}
work=${TMPDIR:-/tmp}/pss-eui-compare
rm -rf "$work"; mkdir -p "$work/base"
git archive "$ref" | tar -x -C "$work/base"
cp "$here/eui_tour.lua" "$here/check_eui_window.lua" "$work/"
x="$here/eui_stub/EllesmereUI"
for side in base head; do
	dir=$work/base; [ $side = head ] && dir=.
	PSS_PHASE=1 PSS_EXTRA_ADDONS="$x,$dir/PourSocialScore_EllesmereUI" lua5.1 "$here/run.lua" "$dir" "$sv" "$work/sv-$side.lua" "$work/check_eui_window.lua" > /dev/null
	PSS_UI_DUMP="$work/$side.txt" PSS_EXTRA_ADDONS="$x,$dir/PourSocialScore_EllesmereUI" lua5.1 "$here/run.lua" "$dir" "$work/sv-$side.lua" - "$work/eui_tour.lua" | grep '^eui tour\|^ERROR'
done
if diff "$work/base.txt" "$work/head.txt" > "$work/diff.txt"; then
	echo "EllesmereUI window identical to $ref ($(grep -c '^== ' "$work/head.txt") steps)"
else
	head -40 "$work/diff.txt"
	echo "EllesmereUI window DIFFERS from $ref ($(wc -l < "$work/diff.txt") diff lines, $work/diff.txt)"
	exit 1
fi
