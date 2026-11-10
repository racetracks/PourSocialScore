#!/bin/sh
# Search Everywhere: identical results and timing (TST-00988, TST-00989, specs/search.md#10-identical-results).
# For each real save (<saves dir>/<client>/<version>/PourSocialScore.lua) and a seeded fresh save:
#   search_results.lua on `git archive <ref>` and on this tree, diffed (a speed change must not change a row);
#   bench_search.lua on this tree: CASE and TERM lines, then the ADMIT lines (max over saves) and REPRO.
# Last lines: `same: <n> saves, <d> differ`, nine ADMIT lines, REPRO yes|no (any tbc/forever TERM max_ms >= 200).
#   sh tools/harness/search_same.sh <ref> <saves dir>        (run from the repo root)
here=$(dirname "$0")
ref=${1:?usage: search_same.sh <ref> <saves dir>}
saves=${2:-$PSS_REAL_SAVES}
[ -d "$saves/tbc" ] && [ -d "$saves/forever" ] || { echo "BLOCKED: $saves needs the client folders tbc and forever"; exit 2; }
work=${TMPDIR:-/tmp}/pss-search
rm -rf "$work"; mkdir -p "$work/ref"
git archive "$ref" | tar -x -C "$work/ref" || exit 1
set -- -
for sv in $(find -L "$saves/" -name 'PourSocialScore.lua' | sort); do set -- "$@" "$sv"; done
export PSS_WH_SEED=1 PSS_COMPONENTS=addons,gfx,warehouse,bags
n=0; d=0; i=0
: > "$work/bench.txt"
for sv in "$@"; do
	i=$((i + 1))
	if [ "$sv" = - ]; then label=fresh; flav=
	else
		ver=$(basename "$(dirname "$sv")"); client=$(basename "$(dirname "$(dirname "$sv")")")
		label="$client/$ver"; flav=$client
	fi
	if [ -n "$flav" ]; then export PSS_FLAVOUR=$flav; else unset PSS_FLAVOUR; fi
	lua5.1 "$here/run.lua" "$work/ref" "$sv" - "$here/search_results.lua" 2>&1 | grep -E '^(R|R2|H|DEL) ' > "$work/a-$i.txt"
	lua5.1 "$here/run.lua" . "$sv" - "$here/search_results.lua" 2>&1 | grep -E '^(R|R2|H|DEL) ' > "$work/b-$i.txt"
	n=$((n + 1))
	if [ ! -s "$work/b-$i.txt" ]; then echo "FAIL search: $label printed no results"; d=$((d + 1)); continue; fi
	cmp -s "$work/a-$i.txt" "$work/b-$i.txt" || { echo "DIFF search: $label"; diff "$work/a-$i.txt" "$work/b-$i.txt" | head -6; d=$((d + 1)); }
	env PSS_BENCH_LABEL="$label" lua5.1 "$here/run.lua" . "$sv" - "$here/bench_search.lua" 2>&1 | grep -E '^(CASE|TERM|ADMIT) ' >> "$work/bench.txt"
done
grep -E '^(CASE|TERM) ' "$work/bench.txt"
echo "same: $n saves, $d differ"
awk '/^ADMIT /{
	id=$2; if(!(id in o)){o[id]=++k; ord[k]=id}
	if($3=="yes") y[id]="yes"
	for(f=4;f<=NF;f++){split($f,p,"="); key=id SUBSEP p[1]; if(!(key in m)||p[2]+0>m[key]+0){m[key]=p[2]}; if(!(key in s)){s[key]=1; nm[id]=nm[id] " " p[1]}}
} END{for(j=1;j<=k;j++){id=ord[j]; line="ADMIT " id " " (y[id]?"yes":"no"); c=split(nm[id],a," "); for(q=1;q<=c;q++) line=line " " a[q] "=" m[id SUBSEP a[q]]; print line}}' "$work/bench.txt"
if awk '/^TERM (tbc|forever) /{split($6,p,"="); if(p[2]+0>=200) f=1} END{exit f?0:1}' "$work/bench.txt"; then echo "REPRO yes"; else echo "REPRO no"; fi
[ "$d" = 0 ]
