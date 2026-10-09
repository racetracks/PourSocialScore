#!/bin/sh
# The Enabled components checks (issue 181; check_components.lua): defaults,
# the Options section and its reload question, each component off and on, a
# simulated reload (a second run on the first run's saved file), on Retail and
# on Camelot. Run from the repo root (validate_all.sh and the Rules CI job
# call it); exit 1 when any phase fails.
#   sh tools/harness/components_phases.sh [work dir]
here=$(dirname "$0")
work=${1:-${TMPDIR:-/tmp}/pss-components}
mkdir -p "$work"
fail=0
n=0
cphase() {
	ph=$1; comp=$2; shift 2
	for cam in "" "PSS_CAMELOT=1"; do
		n=$((n + 1))
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=$comp $cam "$@" lua5.1 "$here/run.lua" . - "$work/c-$n.lua" "$here/check_components.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS components $ph/PASS components $ph ${cam:+(Camelot)}[$comp]/"
		echo "$out" | grep -q "PASS components $ph" || { fail=1; echo "$out" | head -5; }
		echo "$out" | grep -q "FAIL" && fail=1
	done
}
cphase defaults none
cphase options none
cphase addonsoff none
cphase addonson addons
cphase gfxoff none
cphase gfxon gfx
cphase filteringoff -filtering
cphase filteringon none
cphase loggingoff -logging
cphase loggingon none
# a reload: the first run saves the choices, the second loads the saved file
for cam in "" "PSS_CAMELOT=1"; do
	n=$((n + 1))
	out=$(env PSS_PHASE=reloadset PSS_COMPONENTS=none $cam lua5.1 "$here/run.lua" . - "$work/r-$n.lua" "$here/check_components.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -q "PASS components reloadset" || { fail=1; echo "$out" | head -5; }
	out=$(env PSS_PHASE=reloadread PSS_COMPONENTS=none PSS_RELOAD=1 $cam lua5.1 "$here/run.lua" . "$work/r-$n.lua" "$work/r2-$n.lua" "$here/check_components.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | sed "s/^PASS components reloadread/PASS components reloadread ${cam:+(Camelot)}/"
	echo "$out" | grep -q "PASS components reloadread" || { fail=1; echo "$out" | head -5; }
done
exit $fail
