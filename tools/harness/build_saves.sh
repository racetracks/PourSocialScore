#!/bin/sh
# Builds the real-save folder validate_all.sh reads (PSS_REAL_SAVES) from the
# scratch repo's SavedVariables/<version>/ (real saves are never kept here).
#   sh tools/harness/build_saves.sh <scratch checkout> [out dir]
# out dir defaults to /mnt/project-files/baselines. Each version becomes
# <out>/<version>/PourSocialScore.lua: a 2.0 save is copied as is, a 3.x set
# is joined core first, then Options, Logging and EllesmereUI.
# Then: PSS_REAL_SAVES=<out dir> sh tools/harness/validate_all.sh
src=$1
out=${2:-/mnt/project-files/baselines}
if [ -z "$src" ] || [ ! -d "$src/SavedVariables" ]; then
	echo "usage: sh tools/harness/build_saves.sh <scratch checkout> [out dir]"
	exit 1
fi
n=0
for d in "$src"/SavedVariables/*/; do
	v=$(basename "$d")
	[ -f "$d/PourSocialScore.lua" ] || continue
	mkdir -p "$out/$v"
	: > "$out/$v/PourSocialScore.lua"
	for part in "" _Options _Logging _EllesmereUI; do
		f="$d/PourSocialScore$part.lua"
		[ -f "$f" ] && cat "$f" >> "$out/$v/PourSocialScore.lua"
	done
	echo "$v: $(wc -c < "$out/$v/PourSocialScore.lua") bytes"
	n=$((n + 1))
done
[ "$n" -gt 0 ] || { echo "no saves found in $src/SavedVariables"; exit 1; }
echo "$n saves in $out"
