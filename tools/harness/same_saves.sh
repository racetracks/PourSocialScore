#!/bin/sh
# Saves byte-identical (core uplift U1): every save logs in twice with the
# code of a git ref and with the working tree; the saved files and the chat
# lines must be identical, apart from the version string itself and the
# upgrade report's lines. For a
# change that must not touch the saved data (a refactor, the upgrade report).
#   sh tools/harness/same_saves.sh <ref> [save.lua ...]
# With no saves listed: a fresh save, every PourSocialScore.lua under
# PSS_REAL_SAVES (tools/harness/build_saves.sh) and every sv-*.lua that
# validate_all.sh built in $TMPDIR/pss-validate (run it first for those;
# its -after saves are skipped, the working tree wrote them).
# Run from the repo root; needs lua5.1 and git.
here=$(dirname "$0")
ref=${1:?usage: same_saves.sh <ref> [save.lua ...]}
shift
work=${TMPDIR:-/tmp}/pss-same
rm -rf "$work"; mkdir -p "$work/ref"
git archive "$ref" | tar -x -C "$work/ref" || exit 1
toc() { sed -n 's/^## Version: *//p' "$1/PourSocialScore/PourSocialScore.toc" | tr -d '\r'; }
vref=$(toc "$work/ref"); vnew=$(toc .)

if [ $# -eq 0 ]; then
	set -- -
	if [ -n "$PSS_REAL_SAVES" ]; then
		for sv in $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua' | sort); do set -- "$@" "$sv"; done
	fi
	# (not the -after saves: the working tree's code wrote those)
	for sv in $(ls "${TMPDIR:-/tmp}/pss-validate"/sv-*.lua 2>/dev/null | grep -v -- '-after\.lua$'); do set -- "$@" "$sv"; done
fi

# two logins with one tree; the saves and chat, version strings replaced
login() {
	tree=$1; sv=$2; tag=$3; v=$4
	lua5.1 "$here/run.lua" "$tree" "$sv" "$work/$tag-1.lua" > "$work/$tag-1.txt" 2>&1
	lua5.1 "$here/run.lua" "$tree" "$work/$tag-1.lua" "$work/$tag-2.lua" > "$work/$tag-2.txt" 2>&1
	for f in "$work/$tag-1.lua" "$work/$tag-2.lua"; do
		sed "s/$v/VERSION/g" "$f" > "$f.n"
	done
	# the upgrade report's lines (3.4.1.46, U2) are left out of the chat: a
	# version change alone now prints one; the saves still must be the same
	for f in "$work/$tag-1.txt" "$work/$tag-2.txt"; do
		sed "s/$v/VERSION/g" "$f" | grep -v -E "$REPORT" > "$f.n"
	done
}
REPORT='Upgrading your saved data:|Saved data upgraded to |Saved data upgrade paused at |older than your saved data|Pour Social Score: [|]cffffffff  [A-Z][A-Za-z ]+: '


fail=0; n=0
for sv in "$@"; do
	login "$work/ref" "$sv" ref "$vref"
	login . "$sv" new "$vnew"
	same=1
	for f in 1.lua 2.lua 1.txt 2.txt; do
		cmp -s "$work/ref-$f.n" "$work/new-$f.n" || { same=0; diff "$work/ref-$f.n" "$work/new-$f.n" | head -10; }
	done
	n=$((n + 1))
	if [ $same -eq 1 ]; then
		echo "same: $sv"
	else
		echo "FAIL differs: $sv"; fail=1
	fi
done
[ $fail -eq 0 ] && echo "PASS same saves ($n saves, $ref $vref to $vnew)" || echo "FAIL same saves"
exit $fail
