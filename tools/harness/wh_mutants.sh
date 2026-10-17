#!/bin/sh
# Mutation check (one-build plan TST-p158): every mutant of wh_mutants.lua is applied to a copy of the
# addon; the phases it names must fail for it (a survivor fails this script). One line per mutant with
# the phase that killed it. Takes a few minutes.   sh tools/harness/wh_mutants.sh [id ...]
here=$(dirname "$0")
src=$(cd "$here/../.." && pwd)
get() { lua5.1 "$here/wh_mutants_get.lua" "$@"; }
count=$(get count)
want="$*"
killed=0; survived=0; invalid=0
i=1
while [ $i -le $count ]; do
	id=$(get id $i); phases=$(get phases $i)
	n=$i
	i=$((i + 1))
	if [ -n "$want" ] && ! echo " $want " | grep -q " $id "; then continue; fi
	work=$(mktemp -d)
	(cd "$src" && tar cf - PourSocialScore PourSocialScore_Libraries PourSocialScore_Options PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Communities tools) | (cd "$work" && tar xf -)
	file=$(get file $n); from=$(get from $n); to=$(get to $n)
	if ! lua5.1 "$here/wh_mutate.lua" "$work/$file" "$from" "$to" 2>"$work/err.txt"; then
		invalid=$((invalid + 1)); echo "INVALID $id: $(cat "$work/err.txt")"; rm -rf "$work"; continue
	fi
	case "$phases" in
	fr:*)	# the chat filter's registration phases (filterreg_phases.sh): killed by any failing phase
		out=$(cd "$work" && FR_ONLY=$(echo "${phases#fr:}" | tr ',' ' ') sh tools/harness/filterreg_phases.sh 2>&1) && out="" || out="FAIL wh: filterreg: $(echo "$out" | grep -m1 'FAIL filterreg' | sed 's/FAIL filterreg: \([a-z]*\):.*/\1/')"
		;;
	*)	out=$(cd "$work" && sh tools/harness/wh_phases.sh $phases 2>&1) ;;
	esac
	if echo "$out" | grep -q "FAIL\|lua5.1:\|failed" && ! echo "$out" | grep -q "failed, 0 failed\|WH [0-9]* phases, 0 failed"; then
		killed=$((killed + 1))
		by=$(echo "$out" | sed -n 's/^FAIL wh: \([a-z0-9]*\):.*/\1/p' | head -1)
		echo "KILLED $id (by ${by:-an error})"
	else
		survived=$((survived + 1)); echo "SURVIVED $id"
	fi
	rm -rf "$work"
done
echo "MUTANTS $((killed + survived + invalid)): $killed killed, $survived survived, $invalid invalid"
[ $survived -eq 0 ] && [ $invalid -eq 0 ]
