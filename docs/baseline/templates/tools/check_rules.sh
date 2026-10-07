#!/bin/sh
# Checks the coding rules that can be checked by a script:
#   1. Lua 5.1 only: every .lua file compiles with luac5.1; no goto, no
#      ::labels::, no Lua 5.2+ library calls (tools/check_style.lua)
#   2. ASCII only in .lua, .toc, .xml and the .txt files shipped in the zip
#   4. Tabs, not spaces: indentation, mid-line alignment and no trailing
#      whitespace (tools/check_style.lua; --fix there repairs these)
#   6. Core logic files hold no UI code (tools/check_layers.lua)
# Usage: sh tools/check_rules.sh   (from the repo root, needs luac5.1/lua5.1)

fail=0
# every addon folder (MyAddon/, MyAddon_*/)
files=$(ls MyAddon*/*.lua tools/*.lua tools/harness/*.lua 2>/dev/null)

for f in $files; do
	luac5.1 -p "$f" || fail=1
done

lua5.1 tools/check_style.lua $files || fail=1

if LC_ALL=C grep -nP '[^\x00-\x7F]' $(ls MyAddon*/*.toc MyAddon*/*.xml 2>/dev/null) readme.txt history.txt; then
	echo "ASCII only: non-ASCII bytes found above"
	fail=1
fi

if grep -nP '^\t* |[ \t]+$' $(ls MyAddon*/*.xml 2>/dev/null); then
	echo "Tabs, not spaces: space indentation or trailing whitespace found above"
	fail=1
fi

lua5.1 tools/check_layers.lua || fail=1

[ $fail -eq 0 ] && echo "All rule checks passed"
exit $fail
