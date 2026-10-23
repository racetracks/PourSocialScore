#!/bin/sh
# TOC set checks (TST-00978 rows 1 to 4). Run from the repo root.
# Last line: "TOC 4 rows, <f> failed"; exit 1 when <f> is not 0.
f=0
T=PourSocialScore/PourSocialScore_TBC.toc
L=PourSocialScore_Libraries
bak=$(mktemp)

ok() { if [ "$2" = ok ]; then echo "ok   $1"; else echo "FAIL $1"; f=$((f + 1)); fi; }

# 1: fresh checkout is current
out=$(lua5.1 tools/gen_toc.lua --check 2>&1) && [ -z "$out" ] && ok "1 check fresh" ok || ok "1 check fresh" no

# 2: a file line removed from the TBC TOC is reported (restored after)
cp "$T" "$bak"
ln=$(grep -n '^PSS_Loader.lua' "$T" | head -1 | cut -d: -f1)
sed "${ln}d" "$bak" > "$T"
out=$(lua5.1 tools/gen_toc.lua --check 2>&1)
rc=$?
cp "$bak" "$T"
rm -f "$bak"
[ $rc -eq 1 ] && [ "$out" = "$T: differs from manifest" ] && ok "2 stale TBC" ok || ok "2 stale TBC" no

# 3: no Macros line in the TBC Libraries TOC
[ "$(grep -c PSS_Macros.lua $L/${L}_TBC.toc)" = 0 ] && ok "3 no macros in TBC" ok || ok "3 no macros in TBC" no

# 4: Macros line in the base Libraries TOC is gated to camelot
grep -q '^PSS_Macros.lua \[AllowLoadGameType camelot\]\[ExcludeLoadGameType standard, \?tbc\]$' $L/$L.toc && ok "4 macros gated" ok || ok "4 macros gated" no

echo "TOC 4 rows, $f failed"
[ "$f" -eq 0 ]
