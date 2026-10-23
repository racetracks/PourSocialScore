#!/bin/sh
# Builds the real-save folder validate_all.sh reads (PSS_REAL_SAVES) from the
# scratch repo's SavedVariables/<version>/ (real saves are never kept here).
#   sh tools/harness/build_saves.sh <scratch checkout> [out dir]
# out dir defaults to /tmp/pss-baselines. Each version becomes
# <out>/<client>/<version>/PourSocialScore.lua (a top-level version folder is
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
clients="retail forever tbc era mists"
# one save: <dir> <client> <version>
build() {
	d=$1; c=$2; v=$3
	mkdir -p "$out/$c/$v"
	: > "$out/$c/$v/PourSocialScore.lua"
	for part in "" _Options _Options.char _Logging _EllesmereUI; do
		f="$d/PourSocialScore$part.lua"
		[ -f "$f" ] && cat "$f" >> "$out/$c/$v/PourSocialScore.lua"
	done
	echo "$c/$v: $(wc -c < "$out/$c/$v/PourSocialScore.lua") bytes"
	n=$((n + 1))
}
for d in "$src"/SavedVariables/*/; do
	v=$(basename "$d")
	if [ -f "$d/PourSocialScore.lua" ]; then
		# a top-level version folder is a Forever save
		build "${d%/}" forever "$v"
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
			[ -f "$vd/PourSocialScore.lua" ] && build "${vd%/}" "$v" "$(basename "$vd")"
		done ;;
	*) echo "skip $v: unknown client" ;;
	esac
done
[ "$n" -gt 0 ] || { echo "no saves found in $src/SavedVariables"; exit 1; }
echo "$n saves in $out"
