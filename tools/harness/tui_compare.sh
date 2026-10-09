#!/bin/sh
# Checks that the window (/pss gui) looks the same as another version in
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
# the dump numbers frames in creation order, so adding or dropping a frame
# shifts every later number: compare again with the numbers stripped and the
# lines sorted before calling it a difference
norm() { sed -E 's/#[0-9]+//g' "$1" | sort; }
if diff "$work/base.txt" "$work/head.txt" > "$work/diff.txt"; then
	echo "New window identical to $ref ($(grep -c '^== ' "$work/head.txt") steps)"
else
	norm "$work/base.txt" > "$work/base.norm"; norm "$work/head.txt" > "$work/head.norm"
	if diff "$work/base.norm" "$work/head.norm" > "$work/diff.norm.txt"; then
		echo "New window identical to $ref apart from frame numbers ($(grep -c '^== ' "$work/head.txt") steps, $(wc -l < "$work/diff.txt") raw diff lines)"
	else
		head -40 "$work/diff.norm.txt"
		echo "New window DIFFERS from $ref ($(grep -c '^[<>]' "$work/diff.norm.txt") lines with frame numbers stripped, $work/diff.norm.txt)"
		exit 1
	fi
fi
