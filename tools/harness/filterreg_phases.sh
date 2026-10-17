#!/bin/sh
# The chat filter's registration checks (3.7.0.110, W-8; check_filterreg.lua), on Retail and Camelot, with the client's
# list in both shapes. Run from the repo root (validate_all.sh and the Rules CI job call it); exit 1 when any phase fails.
#   sh tools/harness/filterreg_phases.sh [work dir]
here=$(dirname "$0")
work=${1:-${TMPDIR:-/tmp}/pss-filterreg}
mkdir -p "$work"
fail=0
n=0
# FR_ONLY="ph ph": run only those phases (the mutant check, wh_mutants.sh)
fphase() {
	ph=$1; shift
	[ -z "$FR_ONLY" ] || echo " $FR_ONLY " | grep -q " $ph " || return 0
	for cam in "" "PSS_CAMELOT=1"; do
		for shape in object functions entries; do
			n=$((n + 1))
			out=$(env PSS_PHASE=$ph PSS_COMPONENTS=none PSS_FILTER_SHAPE=$shape $cam "$@" lua5.1 "$here/run.lua" . - "$work/f-$n.lua" "$here/check_filterreg.lua" 2>&1 | grep -v '^|cff')
			echo "$out" | sed "s/^PASS filterreg $ph/PASS filterreg $ph ${cam:+(Camelot) }[$shape]/"
			echo "$out" | grep -q "PASS filterreg $ph" || { fail=1; echo "$out" | head -6; }
			echo "$out" | grep -q "FAIL" && fail=1
		done
	done
}
fphase base
fphase regfail PSS_FILTER_FAIL=2
fphase retry
for st in snap watch ignoresync compartment components; do fphase startfault PSS_FAULT=start:$st; done
for st in expand upgradefields; do fphase startfault PSS_FAULT=start:$st; done
fphase startfault PSS_FAULT=start:defaults
fphase outcome
fphase secretsweep
fphase passwhy
exit $fail
