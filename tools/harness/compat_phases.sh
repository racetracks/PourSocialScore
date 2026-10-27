#!/bin/sh
. "$(dirname "$0")/flavours.sh"
# Compat adapter checks (multi-version suite, TST-00979; check_compat.lua), every flavour of
# $FLAVOURS and era. Run from the repo root; exit 1 when any phase fails. The last line is
# "COMPAT n phases, f failed".   sh tools/harness/compat_phases.sh
here=$(dirname "$0")
case " $FLAVOURS " in *" era "*) ALL="$FLAVOURS" ;; *) ALL="$FLAVOURS era" ;; esac
n=0
bad=0
# run <phase> <flavour> [VAR=value ...]
run() {
	ph=$1; fl=$2; shift 2
	out=$(env -u PSS_CAMELOT PSS_FLAVOUR=$fl PSS_PHASE=$ph "$@" lua5.1 "$here/run.lua" . - - "$here/check_compat.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | tail -3
	[ "$(echo "$out" | grep -c "^PASS compat $ph\$")" = 1 ] || pbad=1
}
for ph in containers guildBank secret menu compartment reload templates friendsAnchor; do
	n=$((n + 1)); pbad=0
	for fl in $ALL; do
		run $ph $fl
		case $ph in
		containers) run $ph $fl PSS_STUB_OFF=C_Container ;;
		menu) run $ph $fl PSS_STUB_OFF=Menu ;;
		compartment) run $ph $fl PSS_STUB_OFF=AddonCompartmentFrame ;;
		templates) run $ph $fl PSS_COMPAT_XML=panel ;;
		friendsAnchor) [ "$fl" = tbc ] && run $ph $fl PSS_STUB_OFF=FriendsFrame ;;
		esac
	done
	bad=$((bad + pbad))
done
echo "COMPAT $n phases, $bad failed"
[ "$bad" = 0 ]
