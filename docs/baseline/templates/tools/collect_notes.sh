#!/bin/sh
# Prints the history.txt sections that make up a full release: the section
# of <version> and every section below it, down to (not including) the
# previous full release (a plain X.Y.Z; builds X.Y.Z.B and older suffixed
# versions such as 1.4.0-dev004 are not full releases).
#   sh tools/collect_notes.sh 1.4.0 [history.txt]
ver=$1
file=${2:-history.txt}
if [ -z "$ver" ]; then echo "usage: sh tools/collect_notes.sh <version> [history.txt]" >&2; exit 1; fi

out=$(awk -v v="$ver" '
	/^=> / {
		split($0, a, " ")
		if (!on) { if (a[2] != v) next; on = 1 }
		else if (a[2] ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) exit
	}
	on { print }
' "$file")
if [ -z "$out" ]; then echo "no section '=> $ver ' in $file" >&2; exit 1; fi
printf '%s\n' "$out"
