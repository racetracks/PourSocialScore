#!/bin/sh
. "$(dirname "$0")/flavours.sh"
# PSS Drop Cheapest Thing checks (money-helper; check_dtt.lua), on Retail and
# on Camelot. Run from the repo root (validate_all.sh calls it); exit 1 when
# any phase fails.   sh tools/harness/dtt_phases.sh
here=$(dirname "$0")
fail=0
phase() {
	ph=$1; comp=$2
	for cam in $FLAVOUR_ENVS; do
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=$comp $cam lua5.1 "$here/run.lua" . - - "$here/check_dtt.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS dtt $ph/PASS dtt $ph (${cam#PSS_FLAVOUR=})[$comp]/"
		echo "$out" | grep -q "PASS dtt $ph" || { fail=1; echo "$out" | head -5; }
		echo "$out" | grep -q "FAIL" && fail=1
	done
}
phase off none
phase options none
for ph in scan filters act cmd icon roundtrip mapbutton dttlog merchant options bus refresh; do phase $ph dtt; done
phase shared dtt,bags
phase scan dtt,bags
phase act dtt,warehouse,bags
phase filters dtt,bags
exit $fail
