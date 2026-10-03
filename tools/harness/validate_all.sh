#!/bin/sh
# SavedVariables upgrade test for 2.0.1, 2.0.8, 2.0.17, 2.0.18, 2.0.19,
# 2.0.22, 2.0.35 and 2.0.36 (run from the repo root, needs lua5.1 and git).
#   sh tools/harness/validate_all.sh
# 2.0.18 and later: that version's code (from git) writes the save.
# 2.0.17, 2.0.8, 2.0.1: their code is not in git, so the 2.0.18 save is
# rewritten into their shape (tools/harness/downgrade.lua).
here=$(dirname "$0")
work=${TMPDIR:-/tmp}/pss-validate
rm -rf "$work"; mkdir -p "$work"
t0=1790000000
fail=0

for pair in 2.0.18:d885cd0 2.0.19:4b7066c 2.0.22:2837de0 2.0.35:9646596 2.0.36:9bfba2e; do
	v=${pair%%:*}; c=${pair#*:}
	mkdir -p "$work/src-$v"
	git archive "$c" | tar -x -C "$work/src-$v"
	PSS_TIME=$t0 PSS_EXPECT="$work/expect-$v.lua" \
		lua5.1 "$here/run.lua" "$work/src-$v" - "$work/sv-$v.lua" "$here/make_data.lua" | grep '^made data' || fail=1
done
for v in 2.0.17 2.0.8 2.0.1; do
	lua5.1 "$here/downgrade.lua" "$work/sv-2.0.18.lua" "$work/sv-$v.lua" "$v" > /dev/null || fail=1
	cp "$work/expect-2.0.18.lua" "$work/expect-$v.lua"
done

for v in 2.0.1 2.0.8 2.0.17 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36; do
	out=$(sh "$here/validate.sh" "$v" "$work/sv-$v.lua" "$work/expect-$v.lua" 2>&1)
	echo "$out"
	echo "$out" | grep -q "PASS phase 3" || fail=1
	# the same save with more history than the log holds (per-person keep)
	lua5.1 "$here/overflow.lua" "$work/sv-$v.lua" "$work/sv-$v-overflow.lua" \
		"$work/expect-$v.lua" "$work/expect-$v-overflow.lua" > /dev/null || fail=1
	out=$(PSS_OVERFLOW=1 sh "$here/validate.sh" "$v+overflow" "$work/sv-$v-overflow.lua" "$work/expect-$v-overflow.lua" 2>&1)
	echo "$out"
	echo "$out" | grep -q "PASS phase 5" || fail=1
	echo "$out" | grep -q "FAIL" && fail=1
done

[ $fail -eq 0 ] && echo "All upgrade checks passed" || echo "Upgrade checks FAILED"
exit $fail
