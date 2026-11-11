#!/bin/sh
# Splits the built real saves (build_saves.sh) into CI shards, one save per unit.
#   sh tools/harness/shard_saves.sh plan <saves>            -> shards JSON, [0..K-1]
#   sh tools/harness/shard_saves.sh link <saves> <k> <K> <out>
# K is 0 for no saves, else min(8, ceil(N / 6)). link sorts the saves by size
# (largest first, then path) and deals them snake order: index i goes to shard
# i mod K on even rounds, K - 1 - (i mod K) on odd ones; shard k's saves are
# linked at <out>/<client>/<version>/<save>/PourSocialScore.lua. Exit 2 on bad args.
usage() { echo "usage: sh tools/harness/shard_saves.sh plan <saves> | link <saves> <k> <K> <out>" >&2; exit 2; }
int() { case "$1" in ''|*[!0-9]*) usage ;; esac; }
saves() { find -L "$1/" -name PourSocialScore.lua | sort; }
case "$1" in
plan)
	[ $# -eq 2 ] && [ -d "$2" ] || usage
	n=$(saves "$2" | wc -l)
	k=$(( (n + 5) / 6 )); [ "$k" -gt 8 ] && k=8
	i=0; s=
	while [ "$i" -lt "$k" ]; do s="$s${s:+,}$i"; i=$((i + 1)); done
	echo "[$s]" ;;
link)
	[ $# -eq 5 ] && [ -d "$2" ] || usage
	int "$3"; int "$4"
	[ "$4" -gt 0 ] && [ "$3" -lt "$4" ] || usage
	root=$(cd "$2" && pwd)
	mkdir -p "$5" || exit 2
	for sv in $(saves "$root"); do
		echo "$(wc -c < "$sv") ${sv#"$root"/}"
	done | sort -k1,1nr -k2,2 | awk -v k="$3" -v K="$4" '{
		i = NR - 1; r = i % K; s = (int(i / K) % 2 == 0) ? r : K - 1 - r
		if (s == k) print $2 }' | while read -r rel; do
		mkdir -p "$5/$(dirname "$rel")"
		ln -sf "$root/$rel" "$5/$rel"
	done ;;
*) usage ;;
esac
exit 0
