#!/bin/sh
# Builds the real-save folder validate_all.sh reads (PSS_REAL_SAVES) from the
# scratch repo's SavedVariables/<version>/ (real saves are never kept here).
#   sh tools/harness/build_saves.sh <scratch checkout> [out dir]
# out dir defaults to /tmp/pss-baselines. Each save becomes
# <out>/<client>/<version>/<save>/PourSocialScore.lua: a version folder's own
# files are save main, each <save>/ subfolder holding PourSocialScore.lua is
# save <save>, none overwritten (a top-level version folder is
# client forever; SavedVariables/<client>/<version>/ keeps its client; a client
# outside retail forever tbc era mists is skipped): a 2.0 save is copied as is, a 3.x set
# is joined core first, then Options, the per-character Options
# (PourSocialScore_Options.char.lua, PSS_CharDB), Logging and EllesmereUI.
# Then: PSS_REAL_SAVES=<out dir> sh tools/harness/validate_all.sh
src=$1
out=${2:-/tmp/pss-baselines}
if [ -z "$src" ] || [ ! -d "$src/SavedVariables" ]; then
	echo "usage: sh tools/harness/build_saves.sh <scratch checkout> [out dir]"
	exit 1
fi
iw=$(lua5.1 tools/gen_toc.lua --install) || exit 1
rf=$(echo "$iw" | awk '$1=="retail"{print $2}')
ff=$(echo "$iw" | awk '$1=="forever"{print $2}')
if [ "$rf" = "$ff" ]; then p1=shared; else p1=separate; fi
echo "install forever $ff, retail $rf: P1 $p1"
n=0
seen=
clients="retail forever tbc era mists"
# one save: <dir> <client> <version> <save>; own names (bd bc bv bs), never the loop's d or v
build() {
	bd=$1; bc=$2; bv=$3; bs=$4; bo="$out/$bc/$bv/$bs/PourSocialScore.lua"
	case "$seen" in *"|$bo|"*) echo "skip $bc/$bv/$bs: already built"; return ;; esac
	seen="$seen|$bo|"
	mkdir -p "$out/$bc/$bv/$bs"
	: > "$bo"
	for part in "" _Options _Options.char _Logging _EllesmereUI; do
		f="$bd/PourSocialScore$part.lua"
		[ -f "$f" ] && cat "$f" >> "$bo"
	done
	echo "$bc/$bv/$bs: $(wc -c < "$bo") bytes"
	n=$((n + 1))
}
# one version folder: its own files are save main, each <save>/ subfolder a save
version() {
	[ -f "$1/PourSocialScore.lua" ] && build "$1" "$2" "$3" main
	for sd in "$1"/*/; do
		[ -f "$sd/PourSocialScore.lua" ] && build "${sd%/}" "$2" "$3" "$(basename "$sd")"
	done
}
for d in "$src"/SavedVariables/*/; do
	v=$(basename "$d")
	if [ -f "$d/PourSocialScore.lua" ]; then
		# a top-level version folder is a Forever save
		version "${d%/}" forever "$v"
		continue
	fi
	# a client folder holds <client>/<version>/
	ok=0
	for vd in "$d"*/; do
		[ -f "$vd/PourSocialScore.lua" ] && ok=1
	done
	[ $ok -eq 1 ] || continue
	case " $clients " in
	*" $v "*)
		for vd in "$d"*/; do
			[ -f "$vd/PourSocialScore.lua" ] && version "${vd%/}" "$v" "$(basename "$vd")"
		done ;;
	*) echo "skip $v: unknown client" ;;
	esac
done
[ "$n" -gt 0 ] || { echo "no saves found in $src/SavedVariables"; exit 1; }
echo "$n saves in $out"
