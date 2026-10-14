#!/bin/sh
# Service bus checks (service-bus-helper; check_bus.lua, check_trig.lua), on Retail and on
# Camelot. Run from the repo root (validate_all.sh and CI call it); exit 1
# when any phase fails. The gate phase runs the scratch design-proof gate
# (parity, catalogue, build gate) when PSS_SCRATCH names a scratch checkout.
# The last line says whether the gate ran. A SKIP is not a pass: with
# PSS_GATE_STRICT=1 (CI) it fails the run.
#   sh tools/harness/bus_phases.sh
here=$(dirname "$0")
fail=0
for ph in sets calls chain errors act budget gui listen store query strict; do
	for cam in "" "PSS_CAMELOT=1"; do
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=logging $cam lua5.1 "$here/run.lua" . - - "$here/check_bus.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS bus $ph/PASS bus $ph ${cam:+(Camelot)}/"
		echo "$out" | grep -q "PASS bus $ph" || { fail=1; echo "$out" | head -5; }
		echo "$out" | grep -q "FAIL" && fail=1
	done
done
for ph in off rows engine rules shipped retry cost; do
	for cam in "" "PSS_CAMELOT=1"; do
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=addons,logging $cam lua5.1 "$here/run.lua" . - - "$here/check_trig.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS trig $ph/PASS trig $ph ${cam:+(Camelot)}/"
		echo "$out" | grep -q "PASS trig $ph" || { fail=1; echo "$out" | head -5; }
		echo "$out" | grep -q "FAIL" && fail=1
	done
done
for cam in "" "PSS_CAMELOT=1"; do
	out=$(env PSS_COMPONENTS=logging $cam lua5.1 "$here/run.lua" . - - "$here/check_owned.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | sed "s/^PASS owned/PASS owned ${cam:+(Camelot)}/"
	echo "$out" | grep -q "PASS owned" || { fail=1; echo "$out" | head -5; }
	echo "$out" | grep -q "FAIL" && fail=1
done
out=$(PSS_PHASE=gate lua5.1 "$here/run.lua" . - - "$here/check_bus.lua" 2>&1 | grep -v '^|cff')
echo "$out" | tail -12
echo "$out" | grep -q "FAIL" && fail=1
if echo "$out" | grep -q "^GATE "; then
	echo "$out" | grep "^GATE " | tail -1
else
	echo "GATE did not run (SKIP is not a pass)"
	[ "$PSS_GATE_STRICT" = 1 ] && fail=1
fi
exit $fail
