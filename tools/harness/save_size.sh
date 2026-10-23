#!/bin/sh
# Saves lean (mv-Q5): the second-login save of every real save and of one
# fresh login per flavour, with <ref>'s code and with the working tree; the
# version strings are replaced by V (and the measured ms= timings by 0, which differ every run) and the bytes counted. Exit 1 when a delta
# is not 0, unless PSS_SIZE_ALLOW (comma list <client>/<version>:<bytes>) names it.
#   sh tools/harness/save_size.sh <ref> <saves out dir>
# Run from the repo root; needs lua5.1 and git.
here=$(dirname "$0")
ref=${1:?usage: save_size.sh <ref> <saves out dir>}
saves=${2:?usage: save_size.sh <ref> <saves out dir>}
. "$here/flavours.sh"
work=${TMPDIR:-/tmp}/pss-size
rm -rf "$work"; mkdir -p "$work/ref"
git archive "$ref" | tar -x -C "$work/ref" || exit 1
toc() { sed -n 's/^## Version: *//p' "$1/PourSocialScore/PourSocialScore.toc" | tr -d '\r'; }
vref=$(toc "$work/ref"); vnew=$(toc .)
# size <tree> <save or -> <flavour> <tag> <version>: bytes of the second login
size() {
	env PSS_FLAVOUR=$3 lua5.1 "$here/run.lua" "$1" "$2" "$work/$4-1.lua" > /dev/null 2>&1
	env PSS_FLAVOUR=$3 lua5.1 "$here/run.lua" "$1" "$work/$4-1.lua" "$work/$4-2.lua" > /dev/null 2>&1
	sed "s/$vref/V/g; s/$vnew/V/g; s/ms=[0-9.e+-]*/ms=0/g; s/\t[0-9][0-9]*\.[0-9][0-9]*\"/\t0\"/g" "$work/$4-2.lua" | wc -c
}
list=
for sv in $(find -L "$saves/" -name 'PourSocialScore.lua' | sort); do
	v=$(basename "$(dirname "$sv")"); c=$(basename "$(dirname "$(dirname "$sv")")")
	list="$list $c/$v|$sv|$c"
done
for f in $FLAVOURS; do list="$list fresh/$f|-|$f"; done
n=0; grew=0; bad=0
for e in $list; do
	name=${e%%|*}; rest=${e#*|}; sv=${rest%%|*}; fl=${rest#*|}
	a=$(size "$work/ref" "$sv" "$fl" ref)
	b=$(size . "$sv" "$fl" new)
	d=$((b - a))
	echo "$name: ref $a B, tree $b B, delta $d B"
	n=$((n + 1))
	[ $d -gt 0 ] && grew=$((grew + 1))
	if [ $d -ne 0 ]; then
		case ",$PSS_SIZE_ALLOW," in *",$name:$d,"*) ;; *) bad=1 ;; esac
	fi
done
echo "SIZE $n saves, $grew grew"
exit $bad
