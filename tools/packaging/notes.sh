#!/bin/sh
# Prints the release notes of one package: sh tools/packaging/notes.sh <id> <ver> <kind>
if [ $# -ne 3 ]; then
	echo "notes.sh: usage: notes.sh <id> <ver> <kind>" >&2
	exit 2
fi
id=$1
ver=$2
kind=$3
pk=tools/packaging/folders.py
main=$(python3 $pk --field "$id" main)
hist=$(python3 $pk --field "$id" history)
echo "**Install:** extract the zip into your client's AddOns folder:"
lua5.1 tools/gen_toc.lua --install | while read -r fl folder; do
	case $fl in retail) c=Retail;; forever) c=Forever;; tbc) c="TBC Anniversary";; *) c=$fl;; esac
	echo "- $c: \`World of Warcraft/$folder/Interface/AddOns/\`"
done
echo
if [ "$id" = core ]; then
	echo "so you get \`AddOns/PourSocialScore/PourSocialScore.toc\` and the \`AddOns/PourSocialScore_*\` folders next to it."
else
	echo "so you get \`AddOns/$main/$main.toc\`."
fi
echo
if [ "$id" = core ] && [ "$kind" = release ]; then
	prev=$(python3 -c 'import json; print(json.load(open("versions.json"))["releases"][0]["previous"])')
	echo "### Changes since $prev"
else
	echo "### Changes"
fi
awk -v v="$ver" '
	index($0, "=> " v " ") == 1 { on = 1; next }
	on && /^=> / { exit }
	on { print }
' "$hist"
echo
echo "Full changelog: history.txt"
