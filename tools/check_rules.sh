#!/bin/sh
# Checks the coding rules that can be checked by a script:
#   1. Lua 5.1 only: every .lua file compiles with luac5.1, no goto / ::labels::
#   2. ASCII only in .lua, .toc and .xml files
#   4. Tabs, not spaces, for indentation
# Usage: sh tools/check_rules.sh   (from the repo root, needs luac5.1)

fail=0
files=$(ls *.lua tools/*.lua tools/harness/*.lua)

for f in $files; do
	luac5.1 -p "$f" || fail=1
done

if grep -nE '\bgoto\b|::[A-Za-z_][A-Za-z0-9_]*::' $files; then
	echo "Lua 5.1 only: goto / labels found above"
	fail=1
fi

if LC_ALL=C grep -nP '[^\x00-\x7F]' $files *.toc *.xml; then
	echo "ASCII only: non-ASCII bytes found above (write them as \\ddd escapes)"
	fail=1
fi

if grep -nP '^\t* ' $files *.xml; then
	echo "Tabs, not spaces: lines indented with spaces found above"
	fail=1
fi

[ $fail -eq 0 ] && echo "All rule checks passed"
exit $fail
