#!/bin/sh
# The addon manager's harness checks (3.6.0; check_addons.lua): the list and
# its groupings, ticks and dependencies, Disable / Enable All, Load, Undo,
# sets and protected addons in both save scopes, pruning, the API
# differences (missing calls, the old argument order, Enum absent), combat,
# every command and the /acp alias (free and taken), the saved data, the
# view object, the entry points, the reused art with and without the atlas
# and the file, CPU and memory, and the memory budgets; each on Retail and
# on Camelot. Run from the repo root (validate_all.sh and the Rules CI job
# call it); exit 1 when any phase fails.
#   sh tools/harness/addons_phases.sh [work dir]
here=$(dirname "$0")
work=${1:-${TMPDIR:-/tmp}/pss-addons}
mkdir -p "$work"
fail=0
adn=0
adphase() {
	ph=$1; shift
	for cam in "" "PSS_CAMELOT=1"; do
		adn=$((adn + 1))
		out=$(env PSS_PHASE=$ph $cam "$@" lua5.1 "$here/run.lua" . - "$work/addons-$adn.lua" "$here/check_addons.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | sed "s/^PASS addons $ph/PASS addons $ph ${cam:+(Camelot)}$*/"
		echo "$out" | grep -q "PASS addons $ph" || fail=1
		echo "$out" | grep -q "FAIL" && fail=1
		if [ -f "$work/addons-$adn.lua" ] && grep -q "PSS_CharDB" "$work/addons-$adn.lua" && [ "$ph" = login ]; then
			echo "FAIL addons: login wrote PSS_CharDB"; fail=1
		fi
	done
}
for ph in list group az lod tick deps all load undo sets lock prune guid combat command slash saved charstore login forward coverage view slots setsmenu menurefresh loadentry placetick menustray menufade menuhover menuflow profiles rename selforward access nocpu perfcost profiletick; do
	adphase $ph
done
adphase reloadpath PSS_RELOAD_BLOCK=1
adphase reloadpath PSS_NO_CUI=1
adphase pending PSS_ADDONS="A:e,L;B:e,L;C:e,l"
adphase oldapi PSS_ADDON_OLDAPI=1
adphase list PSS_ADDON_OLDAPI=1
adphase tick PSS_ADDON_OLDAPI=1
adphase enum
adphase enum PSS_ADDON_NOENUM=1
adphase list PSS_ADDON_NOENUM=1
adphase tick PSS_ADDON_NOENUM=1
adphase noapi PSS_ADDON_NOAPI=EnableAddOn,DisableAddOn
adphase noapi PSS_ADDON_NOAPI=GetNumAddOns
adphase noapi PSS_ADDON_NOAPI=SaveAddOns,ResetAddOns,UpdateAddOnMemoryUsage
adphase slash PSS_ACP_TAKEN=1
adphase big PSS_ADDONS=big
adphase names PSS_ADDONS='My Addon:e;a.b-c_d:e;!Bang:e,L;_Under:e;+Plus:e;Tiny:e,t=|cffff0000Red|r |TInterface\x:16|t Title'
adphase memory PSS_ADDONS=150
adphase icons PSS_ADDONS='T1:e,L,i=Interface\Icons\Foo;T2:e,L,a=SomeAtlas;T3:e,L'
adphase art-atlas PSS_ATLAS=all
adphase art-noatlas PSS_ATLAS=all PSS_ATLAS_MISSING=bag-arrow
adphase art-noatlas
adphase art-file
adphase art-nofile 'PSS_TEX_MISSING=Interface\Glues\CharacterSelect\Glues-AddOn-Icons'
exit $fail
