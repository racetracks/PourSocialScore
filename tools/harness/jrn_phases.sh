#!/bin/sh
. "$(dirname "$0")/flavours.sh"
# The Journal (build J1; check_jrn.lua and tools/harness/jrn/<area>.lua) on every flavour. Run from the repo
# root (validate_all.sh calls it); exit 1 when any area fails.
#   sh tools/harness/jrn_phases.sh [area ...]
#   JRN_ONLY="a b" limits the run (jrn_mutants.sh); PSS_JRN_AREA=<area> runs one area
here=$(dirname "$0")
export TZ=UTC
export PSS_JRN=1
fail=0; n=0; bad=0
want="$*"
[ -n "$JRN_ONLY" ] && want="$JRN_ONLY"
[ -z "$want" ] && want=${PSS_JRN_AREA:-all}
for ph in $want; do
	for fl in $FLAVOURS; do
		n=$((n + 1))
		area=$ph; [ "$ph" = all ] && area=
		out=$(env PSS_JRN_AREA="$area" PSS_COMPONENTS=logging,warehouse PSS_FLAVOUR=$fl lua5.1 "$here/run.lua" . - - "$here/check_jrn.lua" 2>&1 | grep -v '^|cff')
		if echo "$out" | grep -q "^PASS" && ! echo "$out" | grep -q "FAIL"; then
			echo "$out" | grep "^NOTE" | sed "s/^/  /"
			echo "PASS jrn $fl"
		else
			bad=$((bad + 1)); fail=1
			echo "$out" | grep -v "^PASS" | head -6
			echo "FAIL jrn: $ph ($fl)"
		fi
	done
done
echo "JRN $n phases, $bad failed"
exit $fail
