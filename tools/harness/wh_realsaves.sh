#!/bin/sh
# Real saves with the Warehouse on, then off again (one-build plan TST-p159): for each save and a fresh one,
#   R  the save after two logins of the code of <ref> (no Warehouse),
#   W  the save after two logins of this tree with the Warehouse and Bag manager on,
#   O  W after one more login with them off.
# Everything the Warehouse does not own is the same in R, W and O (wh_strip.lua leaves out its table and
# options and same_norm.lua the upgrade record); PSS_WarehouseDB is the same in W and O (kept untouched).
#   sh tools/harness/wh_realsaves.sh <ref> <saves dir>        (run from the repo root)
here=$(dirname "$0")
ref=${1:?usage: wh_realsaves.sh <ref> <saves dir>}
saves=${2:-$PSS_REAL_SAVES}
work=${TMPDIR:-/tmp}/pss-whreal
rm -rf "$work"; mkdir -p "$work/ref"
git archive "$ref" | tar -x -C "$work/ref" || exit 1
toc() { sed -n 's/^## Version: *//p' "$1/PourSocialScore/PourSocialScore.toc" | tr -d '\r'; }
vref=$(toc "$work/ref"); vnew=$(toc .)
fail=0; n=0
set -- -
for sv in $(find -L "$saves/" -name 'PourSocialScore.lua' | sort); do set -- "$@" "$sv"; done
i=0
for sv in "$@"; do
	i=$((i + 1))
	env PSS_WH_SEED=1 lua5.1 "$here/run.lua" "$work/ref" "$sv" "$work/r1-$i.lua" > /dev/null 2>&1
	env PSS_WH_SEED=1 lua5.1 "$here/run.lua" "$work/ref" "$work/r1-$i.lua" "$work/r2-$i.lua" > /dev/null 2>&1
	env PSS_WH_SEED=1 PSS_COMPONENTS=addons,gfx,warehouse,bags lua5.1 "$here/run.lua" . "$sv" "$work/w1-$i.lua" > /dev/null 2>&1
	env PSS_WH_SEED=1 PSS_COMPONENTS=addons,gfx,warehouse,bags lua5.1 "$here/run.lua" . "$work/w1-$i.lua" "$work/w2-$i.lua" > /dev/null 2>&1
	lua5.1 "$here/wh_strip.lua" "$work/w2-$i.lua" "$work/w2off-$i.lua" options
	env PSS_WH_SEED=1 lua5.1 "$here/run.lua" . "$work/w2off-$i.lua" "$work/o-$i.lua" > /dev/null 2>&1
	for t in r2 w2 o; do
		sed "s/$vref/VERSION/g; s/$vnew/VERSION/g; s/\\[\"version\"\\] = \"[0-9.]*\"/[\"version\"] = \"VERSION\"/" "$work/$t-$i.lua" > "$work/$t-$i.v"
		lua5.1 "$here/wh_strip.lua" "$work/$t-$i.v" "$work/$t-$i.s"
		lua5.1 "$here/same_norm.lua" "$work/$t-$i.s" "$work/$t-$i.n"
	done
	# W3-D5: every id the saved Warehouse data names is a saved character or reported unnamed, and none is reused
	out=$(env PSS_PHASE=orphanreal PSS_COMPONENTS=addons,gfx,warehouse,bags lua5.1 "$here/run.lua" . "$sv" - "$here/check_wh.lua" 2>&1 | grep -E '^(FAIL|PASS|ORPHANS)')
	echo "$out" | grep -q '^FAIL' && { echo "FAIL realsaves: $sv: $(echo "$out" | grep '^FAIL' | head -2)"; fail=1; }
	echo "$out" | grep -q '^ORPHANS [1-9]' && echo "NOTE realsaves: $sv: $(echo "$out" | grep '^ORPHANS')"
	# W-4 G3: what stays referenced after the window closes, on this save
	out=$(env PSS_PHASE=memclose PSS_COMPONENTS=addons,gfx,warehouse,bags lua5.1 "$here/run.lua" . "$sv" - "$here/check_wh.lua" 2>&1 | grep -E '^(FAIL|MEMCLOSE)')
	echo "$out" | grep -q '^FAIL' && { echo "FAIL realsaves: $sv: $(echo "$out" | grep '^FAIL' | head -1)"; fail=1; }
	echo "$out" | grep -q '^MEMCLOSE' || { echo "FAIL realsaves: $sv: memclose printed nothing"; fail=1; }
	# W-3 F9: no saved slot is the item id 0 (an empty equipment slot)
	out=$(env PSS_PHASE=zeroreal PSS_COMPONENTS=addons,gfx,warehouse,bags lua5.1 "$here/run.lua" . "$sv" - "$here/check_wh.lua" 2>&1 | grep -E '^(FAIL|ZEROS)')
	echo "$out" | grep -q '^FAIL' && { echo "FAIL realsaves: $sv: $(echo "$out" | grep '^FAIL' | head -1)"; fail=1; }
	n=$((n + 1))
	if ! cmp -s "$work/r2-$i.n" "$work/w2-$i.n"; then echo "FAIL realsaves: $sv differs from $ref apart from the Warehouse"; diff "$work/r2-$i.n" "$work/w2-$i.n" | head -6; fail=1; continue; fi
	if ! cmp -s "$work/w2-$i.n" "$work/o-$i.n"; then echo "FAIL realsaves: $sv changed when the Warehouse was turned off"; fail=1; continue; fi
	a=$(lua5.1 "$here/extract_var.lua" "$work/w2-$i.lua" PSS_WarehouseDB); b=$(lua5.1 "$here/extract_var.lua" "$work/o-$i.lua" PSS_WarehouseDB)
	[ "$a" = "$b" ] || { echo "FAIL realsaves: $sv lost warehouse data when it was turned off"; fail=1; }
done
echo "REALSAVES $n saves, $([ $fail = 0 ] && echo clean || echo FAILED)"
exit $fail
