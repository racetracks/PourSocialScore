#!/bin/sh
# TOC checks for one addon folder (run by tools/check_rules.sh):
#   its four TOCs (base, _Mainline, _Camelot, _TBC) agree on every field but
#   Interface, match tools/gen_toc.lua --check and every listed file exists; Version
#   equals the core's and is X.Y.Z.B (every build, a release too; the build
#   number never resets, Dan, 2026-10-08).
# Usage: sh tools/check_toc.sh <folder>   (from the repo root)

dir=$1
name=$(basename "$dir")
base=$dir/$name.toc
fail=0
for t in "$base" "$dir/${name}_Mainline.toc" "$dir/${name}_Camelot.toc" "$dir/${name}_TBC.toc"; do
	[ -f "$t" ] || { echo "$t: missing"; fail=1; continue; }
	for key in Version Title Notes Category Group IconTexture LoadOnDemand Dependencies SavedVariables; do
		a=$(sed -n "s/^## $key: *//p" "$base" | tr -d '\r')
		b=$(sed -n "s/^## $key: *//p" "$t" | tr -d '\r')
		[ "$a" = "$b" ] || { echo "$t: ## $key differs from $base"; fail=1; }
	done
	for f in $(grep -v '^#' "$t" | tr -d '\r' | awk 'NF{print $1}'); do
		[ -f "$dir/$f" ] || { echo "$t: lists $f, which does not exist"; fail=1; }
	done
done
lua5.1 tools/gen_toc.lua --check || fail=1
ver=$(sed -n 's/^## Version: *//p' "$base" | tr -d '\r')
core=$(sed -n 's/^## Version: *//p' PourSocialScore/PourSocialScore.toc | tr -d '\r')
[ "$ver" = "$core" ] || { echo "$base: Version $ver differs from the core's $core"; fail=1; }
echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || { echo "$base: Version '$ver' is not X.Y.Z.B"; fail=1; }
exit $fail
