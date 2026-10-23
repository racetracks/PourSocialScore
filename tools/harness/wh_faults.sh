#!/bin/sh
. "$(dirname "$0")/flavours.sh"
# Fault sweep (one-build plan TST-p154, TST-p157): every warehouse phase and the login of
# each real save run with PSS_FAULT=* (every service call fails). The addon must raise no Lua error
# of its own and print no error line (PSS_QUIET=1: the showErrors option is off, as for a player).
# A phase's own FAIL lines are expected here (its assertions are about working services) and are
# not counted. Exit 1 on the first addon error.   sh tools/harness/wh_faults.sh [saves dir]
here=$(dirname "$0")
bad=0
n=0
phases="err upg registry schema layers dict live name track caps delete ent numbers money search searchloc sweepbudget import0 tooltip everywhere cmd query2 model whoptions synapi shimfault gwlint synevents"
for ph in $phases; do
	comp=logging,warehouse,bags
	for cam in $FLAVOUR_ENVS; do
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=$comp PSS_WH_SEED=1 PSS_FAULT='*' PSS_QUIET=1 PSS_MODEL_SEEDS=3 $cam lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff[0-9a-f]*Pour Social Score: ')
		n=$((n + 1))
		if echo "$out" | grep -E '\./PourSocialScore[A-Za-z_]*/[A-Za-z_]+\.lua:[0-9]+:' | grep -vE 'PSS_Trig|attempt to call' >/dev/null || echo "$out" | grep -q 'Pour Social Score error in'; then
			bad=$((bad + 1))
			echo "FAULT $ph (${cam#PSS_FLAVOUR=}):"
			echo "$out" | grep -E '\./PourSocialScore[A-Za-z_]*/[A-Za-z_]+\.lua:[0-9]+:|Pour Social Score error in' | head -4
		fi
	done
done
# TST-p157: each real save logs in with the warehouse on and every service failing
if [ -n "$1" ]; then
	for sv in $(find -L "$1/" -name 'PourSocialScore.lua' 2>/dev/null); do
		for cam in $FLAVOUR_ENVS; do
			out=$(env PSS_COMPONENTS=logging,warehouse,bags PSS_FAULT='*' PSS_QUIET=1 $cam lua5.1 "$here/run.lua" . "$sv" - 2>&1)
			n=$((n + 1))
			if echo "$out" | grep -q 'Pour Social Score error in\|stack traceback'; then bad=$((bad + 1)); echo "FAULT login of $sv (${cam#PSS_FLAVOUR=})"; echo "$out" | grep -E 'error in|traceback' | head -3; fi
		done
	done
fi
echo "FAULTS $n runs, $bad with an addon error"
[ $bad -eq 0 ]
