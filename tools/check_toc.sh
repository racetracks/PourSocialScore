#!/bin/sh
# TOC checks for one addon folder (run by tools/check_rules.sh):
#   its three TOCs (base, _Mainline, _Camelot) agree on every field but
#   Interface, list the same files and every listed file exists; Version
#   equals the core's and is X.Y.Z, X.Y.Z-suffix or X.Y.Z-suffix_N.
# Usage: sh tools/check_toc.sh <folder>   (from the repo root)

dir=$1
name=$(basename "$dir")
base=$dir/$name.toc
fail=0
for t in "$base" "$dir/${name}_Mainline.toc" "$dir/${name}_Camelot.toc"; do
	[ -f "$t" ] || { echo "$t: missing"; fail=1; continue; }
	for key in Version Title Notes Category Group IconTexture LoadOnDemand Dependencies SavedVariables; do
		a=$(sed -n "s/^## $key: *//p" "$base" | tr -d '\r')
		b=$(sed -n "s/^## $key: *//p" "$t" | tr -d '\r')
		[ "$a" = "$b" ] || { echo "$t: ## $key differs from $base"; fail=1; }
	done
	if [ "$(grep -v '^#' "$base" | grep .)" != "$(grep -v '^#' "$t" | grep .)" ]; then
		echo "$t: file list differs from $base"
		fail=1
	fi
	for f in $(grep -v '^#' "$t" | tr -d '\r'); do
		[ -f "$dir/$f" ] || { echo "$t: lists $f, which does not exist"; fail=1; }
	done
done
ver=$(sed -n 's/^## Version: *//p' "$base" | tr -d '\r')
core=$(sed -n 's/^## Version: *//p' PourSocialScore/PourSocialScore.toc | tr -d '\r')
[ "$ver" = "$core" ] || { echo "$base: Version $ver differs from the core's $core"; fail=1; }
echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9]+(_[0-9]+)?)?$' || { echo "$base: Version '$ver' is not X.Y.Z, X.Y.Z-suffix or X.Y.Z-suffix_N"; fail=1; }
exit $fail
