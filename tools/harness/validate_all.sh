#!/bin/sh
# SavedVariables upgrade test for 2.0.1, 2.0.8, 2.0.17, 2.0.18, 2.0.19,
# 2.0.22, 2.0.35, 2.0.36, 2.0.37, 2.0.38, 2.0.39, 2.0.40, 2.0.41, 2.0.42, 2.0.43 and 2.0.44, and removals (run from the
# repo root, needs lua5.1 and git).
#   sh tools/harness/validate_all.sh
# PSS_REAL_SAVES=<dir> also loads every real save (*.lua) found under that
# directory (they are not kept in the repository).
# 2.0.18 and later: that version's code (from git) writes the save.
# 2.0.17, 2.0.8, 2.0.1: their code is not in git, so the 2.0.18 save is
# rewritten into their shape (tools/harness/downgrade.lua).
here=$(dirname "$0")
work=${TMPDIR:-/tmp}/pss-validate
rm -rf "$work"; mkdir -p "$work"
t0=1790000000
fail=0

for pair in 2.0.18:d885cd0 2.0.19:4b7066c 2.0.22:2837de0 2.0.35:9646596 2.0.36:9bfba2e 2.0.37:710d180 2.0.38:d331f82 2.0.39:24d234c 2.0.40:34092f7 2.0.41:35742b2 2.0.42:8a8a8fd 2.0.43:41444f3 2.0.44:767c49c; do
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

for v in 2.0.1 2.0.8 2.0.17 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36 2.0.37 2.0.38 2.0.39 2.0.40 2.0.41 2.0.42 2.0.43 2.0.44; do
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

# removals (2.0.43): a player taken off any list leaves nothing saved, and a
# built-in list member stays blocked there with a note. Run on the save each
# version's upgrade wrote (validate.sh phase 3).
for v in 2.0.1 2.0.8 2.0.17 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36 2.0.37 2.0.38 2.0.39 2.0.40 2.0.41 2.0.42 2.0.43 2.0.44; do
	echo "== $v removals"
	src=${TMPDIR:-/tmp}/pss-validate-$v/after-login2.lua
	for ph in forget1 forget2; do
		out=$(PSS_PHASE=$ph lua5.1 "$here/run.lua" . "$src" "$work/forget-$v-$ph.lua" "$here/check_forget.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS $ph" || fail=1
		src=$work/forget-$v-$ph.lua
	done
done

# guild rule blocks (2.0.39): counted once, linked to the rule, no combat
# discovery. Saves written by each version's own code (2.0.18 and later).
for v in 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36 2.0.37 2.0.38 2.0.39 2.0.40 2.0.41 2.0.42 2.0.43 2.0.44; do
	echo "== $v guild rule"
	PSS_TIME=$t0 PSS_EXPECT="$work/expect-gr-$v.lua" \
		lua5.1 "$here/run.lua" "$work/src-$v" - "$work/sv-gr-$v.lua" "$here/make_guildrule.lua" | grep '^made' || fail=1
	tm=$(lua5.1 -e "print(dofile('$work/expect-gr-$v.lua').time)")
	out=$(PSS_TIME=$((tm + 3600)) PSS_EXPECT="$work/expect-gr-$v.lua" \
		lua5.1 "$here/run.lua" . "$work/sv-gr-$v.lua" "$work/sv-gr-$v-after.lua" "$here/check_guildrule.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS guild rule" || fail=1
	# the saved rule keeps no statistics of its own
	lua5.1 -e "dofile('$work/sv-gr-$v-after.lua'); assert(PourSocialScoreDB.builtinStats.PSSG0001 == nil, 'rule stats saved'); assert(PourSocialScoreDB.guildRuleCountsV1 == true)" || fail=1
done

# group and whisper alerts (2.0.44), on a fresh save
echo "== alerts"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_alerts.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS alerts" || fail=1

# upgrade record (3.0): a 2.0 save gets step 1 once with one chat line, the
# next login prints nothing; a fresh save is stamped without a message
echo "== upgrade record"
echo 'print("steps=" .. M.PSS_UPGRADE_STEPS)' > "$work/steps.lua"
steps=$(lua5.1 "$here/run.lua" . - - "$work/steps.lua" 2>&1 | sed -n 's/^steps=//p')
o1=$(lua5.1 "$here/run.lua" . "$work/sv-gr-2.0.44.lua" "$work/up-1.lua" 2>&1)
o2=$(lua5.1 "$here/run.lua" . "$work/up-1.lua" "$work/up-2.lua" 2>&1)
o3=$(lua5.1 "$here/run.lua" . - "$work/up-3.lua" 2>&1)
if echo "$o1" | grep -q "Saved data upgraded to .* (step $steps)" && ! echo "$o2$o3" | grep -q "Saved data upgraded" &&
	lua5.1 -e "for _, f in ipairs({ '$work/up-1.lua', '$work/up-2.lua', '$work/up-3.lua' }) do
		PourSocialScoreDB = nil; dofile(f); local u = PourSocialScoreDB.upgrade
		assert(type(u) == 'table' and u.step == $steps and type(u.version) == 'string' and type(u.at) == 'number', f)
	end"; then
	echo "PASS upgrade record (step $steps)"
else
	echo "FAIL upgrade record"; fail=1
fi

# /pss check (3.0): no problems on a fresh save and on every upgraded 2.0.44
# test save; planted faults are reported
echo "== saved data check"
for sv in - "$work/sv-2.0.44.lua" "$work/sv-2.0.44-overflow.lua" "$work/sv-gr-2.0.44.lua"; do
	out=$(lua5.1 "$here/run.lua" . "$sv" - "$here/check_validate.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -q "PASS validate" || { echo "$out"; echo "FAIL validate on $sv"; fail=1; }
done
[ $fail -eq 0 ] && echo "PASS saved data check"

# multi-addon harness (3.0): child addons, LoadOnDemand, several saved tables
echo "== multi-addon harness"
sh "$here/check_multi.sh" || fail=1

# real saves: load, log in twice, and keep every rule, player and member
if [ -n "$PSS_REAL_SAVES" ]; then
	for sv in $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua'); do
		echo "== real save $sv"
		lua5.1 "$here/run.lua" . "$sv" "$work/real-1.lua" "$here/check_real.lua" | grep -v '^|cff' || fail=1
		lua5.1 "$here/run.lua" . "$work/real-1.lua" "$work/real-2.lua" "$here/check_real.lua" | grep -v '^|cff' || fail=1
		lua5.1 "$here/check_real.lua" "$sv" "$work/real-2.lua" || fail=1
		lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_validate.lua" | grep -v '^|cff' || fail=1
	done
fi

[ $fail -eq 0 ] && echo "All upgrade checks passed" || echo "Upgrade checks FAILED"
exit $fail
