#!/bin/sh
# Warehouse checks (warehouse-helper, one-build plan; check_wh.lua), on
# Retail and on Camelot. Run from the repo root (validate_all.sh and CI call
# it); exit 1 when any phase fails. The last line is "WH n phases, f failed".
#   sh tools/harness/wh_phases.sh [phase ...]     (all phases when none is named)
here=$(dirname "$0")
fail=0
n=0
bad=0
DEFAULT="stub err codec codecprop store2 mapstore integrity idx watch upg registry schema off layers dict itemloc live name track caps delete ent numbers money search searchloc searchwin goldorphan whtab whtaboff realms sweepbudget import0 tooltip everywhere cmd query2 model edges budget budgetoff perf parity base36 whoptions synapi shimfault gwlint synevents"
phases=${*:-$DEFAULT}
full=0
[ -z "$*" ] && full=1
for ph in $phases; do
	comp=logging
	seed=
	meas=
	case $ph in budget|budgetoff) meas=1 ;; esac
	case $ph in registry|schema) comp=logging,warehouse,bags ;; dict) comp=logging,bags ;; live|itemloc) comp=logging,bags ;;
		track|caps|delete|money|search|searchloc|searchwin|goldorphan|whtab|realms|sweepbudget|import0|tooltip|everywhere|cmd|query2|model|edges|budget|perf|parity|base36|whoptions|synapi|shimfault|gwlint|synevents) comp=logging,warehouse,bags; seed=PSS_WH_SEED=1 ;; ent|numbers) comp=logging,warehouse,bags ;; off|budgetoff) comp=none ;; esac
	for cam in "" "PSS_CAMELOT=1"; do
		out=$(env PSS_PHASE=$ph PSS_COMPONENTS=$comp $seed $cam ${meas:+PSS_MEASURE=1} lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS wh $ph/PASS wh $ph ${cam:+(Camelot)}/"
		n=$((n + 1))
		if ! echo "$out" | grep -q "PASS wh $ph" || echo "$out" | grep -q "FAIL"; then
			fail=1; bad=$((bad + 1)); echo "$out" | head -8
		fi
	done
done

# TST-00121: write, reload, save again; a newer table layout is only read
if [ $full = 1 ] || echo " $phases " | grep -q " sv "; then
	for cam in "" "PSS_CAMELOT=1"; do
		w=$(mktemp -d)
		run() { env PSS_PHASE=$1 PSS_COMPONENTS=logging,warehouse,bags PSS_WH_SEED=1 $cam lua5.1 "$here/run.lua" . "$2" "$3" "$here/check_wh.lua" 2>&1 | grep -v '^|cff'; }
		o1=$(run sv1 - "$w/a.lua"); o2=$(run sv2 "$w/a.lua" "$w/b.lua"); o3=$(run sv3 "$w/b.lua" "$w/c.lua")
		# the warehouse table, as text, in the file before and after a login that changed nothing
		va=$(lua5.1 "$here/extract_var.lua" "$w/a.lua" PSS_WarehouseDB); vb=$(lua5.1 "$here/extract_var.lua" "$w/b.lua" PSS_WarehouseDB)
		vc=$(lua5.1 "$here/extract_var.lua" "$w/c.lua" PSS_WarehouseDB)
		n=$((n + 1))
		res="$o1$o2$o3"
		# b differs from a by exactly the planted layout number; c (a newer layout) is b untouched
		echo "$va" > "$w/va.txt"; echo "$vb" > "$w/vb.txt"
		changed=$(diff "$w/va.txt" "$w/vb.txt" | grep -c '^[<>]')
		if echo "$res" | grep -q "FAIL\|lua5.1:" || [ -z "$va" ] || [ "$vb" != "$vc" ] || [ "$changed" != 2 ]; then
			fail=1; bad=$((bad + 1)); echo "FAIL wh sv ${cam:+(Camelot)} (changed lines $changed)"; echo "$res" | head -6
		else
			echo "PASS wh sv ${cam:+(Camelot)}"
		fi
		rm -rf "$w"
	done
fi
# TST-p078: Syndicator loaded
for cam in "" "PSS_CAMELOT=1"; do
	if [ $full = 1 ] || echo " $phases " | grep -q " syn "; then
		out=$(env PSS_PHASE=syn PSS_COMPONENTS=logging,warehouse,bags PSS_WH_SEED=1 PSS_EXTRA_ADDONS="$here/fixtures/Syndicator" $cam lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS wh syn/PASS wh syn ${cam:+(Camelot)}/"
		n=$((n + 1))
		if ! echo "$out" | grep -q "PASS wh syn" || echo "$out" | grep -q "FAIL"; then fail=1; bad=$((bad + 1)); echo "$out" | head -8; fi
	fi
done
for cam in "" "PSS_CAMELOT=1"; do
	if [ $full = 1 ] || echo " $phases " | grep -q " synimport "; then
		out=$(env PSS_PHASE=synimport PSS_COMPONENTS=logging,warehouse,bags PSS_EXTRA_ADDONS="$here/fixtures/Syndicator" $cam lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS wh synimport/PASS wh synimport ${cam:+(Camelot)}/"
		n=$((n + 1))
		if ! echo "$out" | grep -q "PASS wh synimport" || echo "$out" | grep -q "FAIL"; then fail=1; bad=$((bad + 1)); echo "$out" | head -8; fi
	fi
done
for cam in "" "PSS_CAMELOT=1"; do
	if [ $full = 1 ] || echo " $phases " | grep -q " synother "; then
		out=$(env PSS_PHASE=synother PSS_COMPONENTS=logging,warehouse,bags PSS_WH_SEED=1 PSS_EXTRA_ADDONS="$here/fixtures/OtherSyn" $cam lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS wh synother/PASS wh synother ${cam:+(Camelot)}/"
		n=$((n + 1))
		if ! echo "$out" | grep -q "PASS wh synother" || echo "$out" | grep -q "FAIL"; then fail=1; bad=$((bad + 1)); echo "$out" | head -8; fi
	fi
done
for cam in "" "PSS_CAMELOT=1"; do
	if [ $full = 1 ] || echo " $phases " | grep -q " cmdtaken "; then
		out=$(env PSS_PHASE=cmdtaken PSS_COMPONENTS=logging,warehouse,bags PSS_WH_SEED=1 PSS_EXTRA_ADDONS="$here/fixtures/SlashTaken" $cam lua5.1 "$here/run.lua" . - - "$here/check_wh.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS wh cmdtaken/PASS wh cmdtaken ${cam:+(Camelot)}/"
		n=$((n + 1))
		if ! echo "$out" | grep -q "PASS wh cmdtaken" || echo "$out" | grep -q "FAIL"; then fail=1; bad=$((bad + 1)); echo "$out" | head -8; fi
	fi
done
echo "WH $n phases, $bad failed"
exit $fail
