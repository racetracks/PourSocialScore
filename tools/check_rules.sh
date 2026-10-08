#!/bin/sh
# Checks the coding rules that can be checked by a script:
#   1. Lua 5.1 only: every .lua file compiles with luac5.1; no goto, no
#      ::labels::, no Lua 5.2+ library calls (tools/check_style.lua)
#   2. ASCII only in .lua, .toc, .xml and the .txt files shipped in the zip
#   4. Tabs, not spaces: indentation, mid-line alignment and no trailing
#      whitespace (tools/check_style.lua; --fix there repairs these)
#   6. Core logic files hold no UI code (tools/check_layers.lua)
#   Every PourSocialScore_* folder's three TOCs agree (tools/check_toc.sh)
#   The new window (PourSocialScore_UI) and the Libraries code it calls use
#   PSS names only: no EllesmereUI or EUI names
#   PourSocialScore_EllesmereUI is checked by tools/check_rules_eui.sh
#   (the same rules in EllesmereUI's code style: spaces, not tabs)
# Usage: sh tools/check_rules.sh   (from the repo root, needs luac5.1/lua5.1)

fail=0
# every addon folder (3.0 layout: PourSocialScore/, PourSocialScore_*/)
files=$(ls PourSocialScore*/*.lua tools/*.lua tools/harness/*.lua 2>/dev/null | grep -v '^PourSocialScore_EllesmereUI/')

for f in $files; do
	luac5.1 -p "$f" || fail=1
done

lua5.1 tools/check_style.lua $files || fail=1

if LC_ALL=C grep -nP '[^\x00-\x7F]' $(ls PourSocialScore*/*.toc PourSocialScore*/*.xml 2>/dev/null) readme.txt history.txt; then
	echo "ASCII only: non-ASCII bytes found above"
	fail=1
fi

if grep -nP '^\t* |[ \t]+$' $(ls PourSocialScore*/*.xml 2>/dev/null | grep -v '^PourSocialScore_EllesmereUI/'); then
	echo "Tabs, not spaces: space indentation or trailing whitespace found above"
	fail=1
fi

lua5.1 tools/check_layers.lua || fail=1

for d in PourSocialScore_*/; do
	sh tools/check_toc.sh "${d%/}" || fail=1
done

if grep -nE 'EUI|[Ee]llesmere' PourSocialScore_UI/* PourSocialScore_Libraries/PSS_ViewNav.lua PourSocialScore_Libraries/PSS_DetailQuery.lua; then
	echo "PSS names only: an EllesmereUI or EUI name found above"
	fail=1
fi

sh tools/check_rules_eui.sh > /dev/null || { sh tools/check_rules_eui.sh; fail=1; }

[ $fail -eq 0 ] && echo "All rule checks passed"
exit $fail
