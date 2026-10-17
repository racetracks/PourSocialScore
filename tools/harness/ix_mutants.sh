#!/bin/sh
# Mutation check of the Spyglass engine (search-helper phase A, TST-00911 to TST-00931, TST-00964 to TST-00966):
# every mutant of ix_mutants.lua is applied to a copy of the addon; at least one phase it names must fail
# (ix_phases.sh), or this script fails. One line per mutant. Takes several minutes.
#   sh tools/harness/ix_mutants.sh [id ...]
here=$(dirname "$0")
src=$(cd "$here/../.." && pwd)
get() { echo 'local l = dofile(arg[1]) local w, i = arg[2], tonumber(arg[3] or "")
	if w == "count" then io.write(#l) return end
	io.write(l[i][({ id = 1, file = 2, from = 3, to = 4, phases = 5 })[w]])' | lua5.1 - "$here/ix_mutants.lua" "$@"; }
count=$(get count)
want="$*"
killed=0; survived=0; invalid=0
i=1
while [ $i -le $count ]; do
	n=$i; i=$((i + 1))
	id=$(get id $n); phases=$(get phases $n)
	if [ -n "$want" ] && ! echo " $want " | grep -q " $id "; then continue; fi
	work=$(mktemp -d)
	(cd "$src" && tar cf - PourSocialScore PourSocialScore_Libraries PourSocialScore_Options PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Communities tools) | (cd "$work" && tar xf -)
	if ! lua5.1 "$here/wh_mutate.lua" "$work/$(get file $n)" "$(get from $n)" "$(get to $n)" 2>"$work/err.txt"; then
		invalid=$((invalid + 1)); echo "INVALID $id: $(cat "$work/err.txt")"; rm -rf "$work"; continue
	fi
	out=$(cd "$work" && IX_ONLY="$phases" sh tools/harness/ix_phases.sh 2>&1)
	if echo "$out" | grep -q "^IX [0-9]* phases, 0 failed"; then
		survived=$((survived + 1)); echo "SURVIVED $id"
	else
		killed=$((killed + 1))
		by=$(echo "$out" | sed -n 's/^FAIL ix: \([a-z0-9]*\).*/\1/p' | head -1)
		echo "KILLED $id (by ${by:-an error})"
	fi
	rm -rf "$work"
done
echo "killed $killed of $((killed + survived + invalid)) ($survived survived, $invalid invalid)"
[ $survived -eq 0 ] && [ $invalid -eq 0 ]
