#!/bin/sh
# Mutation check of the Spyglass console (search-helper phase B). Same runner as ix_mutants.sh; each row of
# MUTANTS is: name|file|sed expression|phase. At least one phase it names must fail (console_phases.sh), or
# this script fails. The table is empty until the phase's components exist.
#   sh tools/harness/console_mutants.sh [name ...]
here=$(dirname "$0")
src=$(cd "$here/../.." && pwd)
MUTANTS=""
want="$*"
total=0; killed=0
for row in $MUTANTS; do
	name=${row%%|*}; rest=${row#*|}; file=${rest%%|*}; rest=${rest#*|}; expr=${rest%%|*}; phase=${rest#*|}
	if [ -n "$want" ] && ! echo " $want " | grep -q " $name "; then continue; fi
	total=$((total + 1))
	work=$(mktemp -d)
	(cd "$src" && tar cf - PourSocialScore PourSocialScore_Libraries PourSocialScore_Options PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Communities tools) | (cd "$work" && tar xf -)
	sed -i "$expr" "$work/$file"
	if (cd "$work" && sh tools/harness/console_phases.sh $phase > /dev/null 2>&1); then
		echo "SURVIVED $name"
	else
		killed=$((killed + 1)); echo "KILLED $name"
	fi
	rm -rf "$work"
done
echo "MUTANTS $killed of $total killed"
[ "$killed" -eq "$total" ]
