#!/bin/sh
# The Spyglass console (search-helper, phase B; check_console.lua), on Retail and on Camelot. Run from the
# repo root (validate_all.sh and CI call it); exit 1 when any phase fails. Phases come from the file.
# With PSS_REAL_SAVES (build_saves.sh's out dir) the phases in REAL also run on every save.
#   sh tools/harness/console_phases.sh [phase ...]
here=$(dirname "$0")
work=${TMPDIR:-/tmp}/pss-console.$$
mkdir -p "$work"
export TZ=UTC
fail=0; n=0; bad=0

ALL=$(echo $(grep -o '^PH\.[a-z0-9]*' "$here/check_console.lua" | sed 's/^PH\.//'))
REAL="conreal buttonqueries panehistory conpipe conslice"

want="$*"
[ -z "$want" ] && want=$(echo $ALL)

prime() {	# $1 camelot flag -> a save after one login
	key=${1:-0}
	if [ ! -f "$work/prime-$key.lua" ]; then
		env PSS_COMPONENTS=logging ${1:+PSS_CAMELOT=1} lua5.1 "$here/run.lua" . - "$work/prime-$key.lua" > /dev/null 2>&1
	fi
	echo "$work/prime-$key.lua"
}

result() {	# $1 label, $2 output
	n=$((n + 1))
	if echo "$2" | grep -q "^PASS console" && ! echo "$2" | grep -q "FAIL"; then
		echo "$2" | grep "^NOTE" | sed "s/^/  /"
		echo "PASS console $1"
	else
		bad=$((bad + 1)); fail=1
		echo "$2" | grep -v "^PASS" | head -6
		echo "$2" | grep -q "FAIL" || echo "FAIL console: $1: no PASS line"
	fi
}

for ph in $want; do
	for cam in "" 1; do
		label="$ph${cam:+ (Camelot)}"
		out=$(env PSS_PHASE="$ph" PSS_COMPONENTS=logging ${cam:+PSS_CAMELOT=1} lua5.1 "$here/run.lua" . "$(prime "$cam")" - "$here/check_console.lua" 2>&1 | grep -v '^|cff')
		result "$label" "$out"
	done
	if [ -n "$PSS_REAL_SAVES" ] && echo " $REAL " | grep -q " $ph " && echo " $ALL " | grep -q " $ph "; then
		for sv in $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua' | sort); do
			v=$(basename "$(dirname "$sv")")
			out=$(env PSS_PHASE="$ph" PSS_COMPONENTS=logging,warehouse lua5.1 "$here/run.lua" . "$sv" - "$here/check_console.lua" 2>&1 | grep -v '^|cff')
			result "$ph (real $v)" "$out"
		done
	fi
done
rm -rf "$work"
echo "CONSOLE $n phases, $bad failed"
exit $fail
