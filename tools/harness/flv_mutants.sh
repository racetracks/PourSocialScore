#!/bin/sh
# Mutation check (multi-version suite, TST-00977): every mutant of flv_mutants.lua is applied to a copy of the
# addon; the phases it names must fail for it (a survivor fails this script). One line per mutant.
#   sh tools/harness/flv_mutants.sh [id ...]
here=$(dirname "$0")
src=$(cd "$here/../.." && pwd)
get() { lua5.1 - "$here/flv_mutants.lua" "$@" <<'LUA'
local l = dofile(arg[1])
local w, i = arg[2], tonumber(arg[3] or "")
if w == "count" then io.write(#l) return end
io.write(l[i][({ id = 1, file = 2, from = 3, to = 4, phases = 5 })[w]])
LUA
}
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
	out=$(cd "$work" && sh tools/harness/flv_phases.sh $phases 2>&1)
	if echo "$out" | grep -q "FAIL\|lua5.1:\|failed" && ! echo "$out" | grep -q "FLV [0-9]* phases, 0 failed"; then
		killed=$((killed + 1))
		echo "KILLED $id"
	else
		survived=$((survived + 1)); echo "SURVIVED $id"
	fi
	rm -rf "$work"
done
echo "MUTANTS $((killed + survived + invalid)): $killed killed, $survived survived, $invalid invalid"
[ $survived -eq 0 ] && [ $invalid -eq 0 ]
