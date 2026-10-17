#!/bin/sh
# Sparse saves (core uplift S3, 3.4.1.52): every save logs in with the code of
# a git ref and with the working tree. What the addon shows about it
# (tools/harness/dump_view.lua: every rule, member, player, list entry,
# filter, counter, history line count and recent count, read through the
# accessors) must be the same, in the login that migrates the save and in the
# next one that reads the sparse file back; the second login must not change
# the saved file; and the ref's own code (the previous build) and the 3.4.0.29
# release must read the migrated save without an error, with the same counters.
#   sh tools/harness/sparse_saves.sh <ref> [save.lua ...]
# With no saves listed: a fresh save, every PourSocialScore.lua under
# PSS_REAL_SAVES and every sv-*.lua validate_all.sh built in
# $TMPDIR/pss-validate (not its -after saves). Run from the repo root.
here=$(dirname "$0")
ref=${1:?usage: sparse_saves.sh <ref> [save.lua ...]}
shift
work=${TMPDIR:-/tmp}/pss-sparse
rm -rf "$work"; mkdir -p "$work/ref" "$work/old"
git archive "$ref" | tar -x -C "$work/ref" || exit 1
# the 3.4.0.29 release (its list layout is not read by this build's list,
# so only its counters other than the list's are compared)
git archive 149625b | tar -x -C "$work/old" || exit 1

if [ $# -eq 0 ]; then
	set -- -
	if [ -n "$PSS_REAL_SAVES" ]; then
		for sv in $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua' | sort); do set -- "$@" "$sv"; done
	fi
	for sv in $(ls "${TMPDIR:-/tmp}/pss-validate"/sv-*.lua 2>/dev/null | grep -v -- '-after\.lua$'); do set -- "$@" "$sv"; done
fi

fail=0; n=0
for sv in "$@"; do
	n=$((n + 1))
	ok=1
	lua5.1 "$here/run.lua" "$work/ref" "$sv" - "$here/dump_view.lua" 2>&1 | grep '^V ' > "$work/a.txt"
	lua5.1 "$here/run.lua" . "$sv" "$work/new1.lua" "$here/dump_view.lua" 2>&1 | grep '^V ' > "$work/b.txt"
	lua5.1 "$here/run.lua" . "$work/new1.lua" "$work/new2.lua" "$here/dump_view.lua" 2>&1 | grep '^V ' > "$work/c.txt"
	if [ ! -s "$work/a.txt" ] || [ ! -s "$work/b.txt" ] || [ ! -s "$work/c.txt" ]; then
		echo "FAIL a dump is empty ($sv)"; ok=0
	fi
	if ! cmp -s "$work/a.txt" "$work/b.txt"; then
		echo "FAIL the migrating login shows something else ($sv)"; diff "$work/a.txt" "$work/b.txt" | head -8; ok=0
	fi
	if ! cmp -s "$work/b.txt" "$work/c.txt"; then
		echo "FAIL the sparse file reads back differently ($sv)"; diff "$work/b.txt" "$work/c.txt" | head -8; ok=0
	fi
	lua5.1 "$here/strip_undo.lua" "$work/new1.lua" "$work/new1s.lua"; lua5.1 "$here/strip_undo.lua" "$work/new2.lua" "$work/new2s.lua"
	if ! cmp -s "$work/new1s.lua" "$work/new2s.lua"; then
		echo "FAIL a second login changed the saved file ($sv)"; diff "$work/new1.lua" "$work/new2.lua" | head -8; ok=0
	fi
	# the previous build and the 3.4.0.29 release read the migrated save
	for tree in ref old; do
		if ! lua5.1 "$here/run.lua" "$work/$tree" "$work/new1.lua" "$work/$tree.out.lua" "$here/dump_counts.lua" > "$work/$tree.txt" 2>&1; then
			echo "FAIL $tree: an error reading the migrated save ($sv)"; grep -v '^|cff' "$work/$tree.txt" | head -5; ok=0
		fi
		if grep -q -i "lua error\|attempt to\|stack traceback" "$work/$tree.txt"; then
			echo "FAIL $tree: a Lua error reading the migrated save ($sv)"; grep -i "lua error\|attempt to" "$work/$tree.txt" | head -3; ok=0
		fi
	done
	lua5.1 "$here/run.lua" . "$work/new1.lua" - "$here/dump_counts.lua" 2>&1 | grep '^N ' > "$work/new.n"
	for tree in ref old; do
		# the block counts, which an older build must read the same (its member
		# count shows more shipped members while their lists are not loaded: it
		# does not know a record without a date is shipped)
		# (3.4.0.29 predates the forward compatibility of 3.4.1.47: it drops a
		# custom filter that has a number id, so its filter counters are not
		# compared; nor the players': 3.4.0.29 does not read the list records of
		# 3.4.1.51 either, S2b; the guild members' counters are)
		keys='memberCountsTotal|guildRules'
		[ "$tree" = ref ] && keys='playerCounts|memberCounts|guildRules|filterCounts|filterTotal|filterWhisper|filterPrivate|filterRowCounts|filters '
		grep '^N ' "$work/$tree.txt" | grep -E "^N ($keys)" > "$work/$tree.n"
		grep -E "^N ($keys)" "$work/new.n" > "$work/new.n2"
		if ! cmp -s "$work/new.n2" "$work/$tree.n"; then
			echo "FAIL $tree: its counters on the migrated save differ ($sv)"; diff "$work/new.n2" "$work/$tree.n" | head -8; ok=0
		fi
	done
	[ $ok -eq 1 ] && echo "same: $sv" || fail=1
done
[ $fail -eq 0 ] && echo "PASS sparse saves ($n saves, $ref)" || echo "FAIL sparse saves"
exit $fail
