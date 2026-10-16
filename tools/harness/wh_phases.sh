#!/bin/sh
# Warehouse checks (warehouse-helper, one-build plan; check_wh.lua), on
# Retail and on Camelot. Run from the repo root (validate_all.sh and CI call
# it); exit 1 when any phase fails. The last line is "WH n phases, f failed".
#   sh tools/harness/wh_phases.sh
here=$(dirname "$0")
fail=0
n=0
bad=0
for ph in stub err codec codecprop store2 mapstore integrity idx watch upg registry schema off layers dict live name; do
	comp=logging
	case $ph in registry|schema|dict) comp=logging,warehouse,bags ;; live) comp=logging,bags ;; off) comp=none ;; esac
	for cam in "" "PSS_CAMELOT=1"; do
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=$comp $cam lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS wh $ph/PASS wh $ph ${cam:+(Camelot)}/"
		n=$((n + 1))
		if ! echo "$out" | grep -q "PASS wh $ph" || echo "$out" | grep -q "FAIL"; then
			fail=1; bad=$((bad + 1)); echo "$out" | head -8
		fi
	done
done
echo "WH $n phases, $bad failed"
exit $fail
