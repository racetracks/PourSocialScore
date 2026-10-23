#!/bin/sh
# Flavour checks (multi-version suite; check_flavour.lua), every flavour. Run from
# the repo root; exit 1 when any phase fails. The last line is "FLV n phases, f failed".
#   sh tools/harness/flv_phases.sh [phase ...]     (all phases when none is named)
here=$(dirname "$0")
DEFAULT="detect stub conflict can probe alias levels mem nogrep blank"
phases=${*:-$DEFAULT}
n=0
bad=0
report() {		# $1 phase, $2 output, $3 expected PASS (1) or error text
	echo "$2" | grep -v '^|cff' | tail -3
	if [ "$(echo "$2" | grep -c "PASS flv $1")" != 1 ]; then pbad=1; fi
}
for ph in $phases; do
	n=$((n + 1)); pbad=0
	case $ph in
	stub)
		out=""
		for c in "retail 1" "forever 18" "tbc 5" "era 2"; do
			set -- $c
			out="$out$(env -u PSS_CAMELOT PSS_FLAVOUR=$1 PSS_EXPECT=$1 PSS_EXPECT_PID=$2 lua5.1 "$here/check_flavour.lua" stub 2>&1)
"
		done
		out="$out$(env -u PSS_FLAVOUR PSS_CAMELOT=1 PSS_EXPECT=forever PSS_EXPECT_PID=18 lua5.1 "$here/check_flavour.lua" stub 2>&1)
"
		if echo "$out" | grep -q FAIL || [ "$(echo "$out" | grep -c 'PASS flv stub')" != 5 ]; then out="$out
FAIL"; else out="PASS flv stub"; fi
		report stub "$out" ;;
	conflict)
		report conflict "$(PSS_FLAVOUR=tbc PSS_CAMELOT=1 lua5.1 "$here/check_flavour.lua" conflict 2>&1)" ;;
	blank)
		report blank "$(env -u PSS_CAMELOT PSS_FLAVOUR=tbc PSS_STUB_BLANK=1 PSS_PHASE=blank lua5.1 "$here/run.lua" . - - "$here/check_flavour.lua" 2>&1)" ;;
	*)
		for fl in retail forever tbc era; do
			report $ph "$(env -u PSS_CAMELOT PSS_FLAVOUR=$fl PSS_PHASE=$ph lua5.1 "$here/run.lua" . - - "$here/check_flavour.lua" 2>&1)"
		done ;;
	esac
	bad=$((bad + pbad))
done
echo "FLV $n phases, $bad failed"
[ $bad -eq 0 ]
