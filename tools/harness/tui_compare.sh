#!/bin/sh
# Checks that the new window (/pss tui) looks the same as another version in
# all three looks: runs tui_tour.lua on both and compares what each step
# showed (3.4.0.16).
#   sh tools/harness/tui_compare.sh [git ref, default origin/main] [save.lua]
# Exit 0 when identical; the differences are printed otherwise.
here=$(dirname "$0")
ref=${1:-origin/main}
sv=${2:--}
work=${TMPDIR:-/tmp}/pss-tui-compare
rm -rf "$work"; mkdir -p "$work/base"
git archive "$ref" | tar -x -C "$work/base"
cp "$here/tui_tour.lua" "$work/"
for side in base head; do
	dir=$work/base; [ $side = head ] && dir=.
	PSS_UI_DUMP="$work/$side.txt" lua5.1 "$here/run.lua" "$dir" "$sv" - "$work/tui_tour.lua" | grep '^tui tour\|^ERROR'
done
if diff "$work/base.txt" "$work/head.txt" > "$work/diff.txt"; then
	echo "New window identical to $ref ($(grep -c '^== ' "$work/head.txt") steps)"
else
	head -40 "$work/diff.txt"
	echo "New window DIFFERS from $ref ($(wc -l < "$work/diff.txt") diff lines, $work/diff.txt)"
	exit 1
fi
