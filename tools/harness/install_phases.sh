#!/bin/sh
# Install folder checks (TST-00981 rows 1 to 4). Run from the repo root.
# Rows 2 and 3 use a temporary manifest, restored after.
# Last line: "INSTALL 4 rows, <f> failed"; exit 1 when <f> is not 0.
f=0
M=tools/toc/manifest.txt
bak=$(mktemp)
scr=${PSS_SCRATCH:-../Pour-Social-Score_Scratch}

ok() { if [ "$2" = ok ]; then echo "ok   $1"; else echo "FAIL $1"; f=$((f + 1)); fi; }

# 1: manifest as committed, in manifest order
out=$(lua5.1 tools/gen_toc.lua --install | tr '\n' ' ')
want=$(grep '^install ' $M | sed 's/^install //' | tr '\n' ' ')
[ -n "$want" ] && [ "$out" = "$want" ] && ok "1 install order" ok || ok "1 install order" no

# 2: forever folder changed: --install, the text, and P1 separate
cp "$M" "$bak"
sed 's/^install forever .*/install forever _classic_/' "$bak" > "$M"
out=$(lua5.1 tools/gen_toc.lua --install | grep '^forever ')
txt=$(lua5.1 tools/gen_toc.lua --install | while read -r fl folder; do [ "$fl" = forever ] && echo "World of Warcraft/$folder/Interface/AddOns/"; done)
p1=$(sh tools/harness/build_saves.sh "$scr" "${TMPDIR:-/tmp}/pss-install-saves" 2>&1 | head -1)
cp "$bak" "$M"
[ "$out" = "forever _classic_" ] && [ "$txt" = "World of Warcraft/_classic_/Interface/AddOns/" ] && [ "$p1" = "install forever _classic_, retail _retail_: P1 separate" ] && ok "2 forever _classic_" ok || ok "2 forever _classic_" no

# 3: a second install forever line
cp "$M" "$bak"
echo "install forever _retail_" >> "$M"
out=$(lua5.1 tools/gen_toc.lua --install 2>&1)
rc=$?
cp "$bak" "$M"
case "$out" in "manifest: bad install line "*) bad=1 ;; *) bad=0 ;; esac
[ $rc -eq 1 ] && [ $bad -eq 1 ] && ok "3 duplicate install" ok || ok "3 duplicate install" no

# 4: no folder literal outside the manifest
[ -z "$(grep -rn '_retail_' tools .github | grep -v "^$M:" | grep -v 'install_phases.sh')" ] && ok "4 no literal" ok || ok "4 no literal" no

rm -f "$bak"
echo "INSTALL 4 rows, $f failed"
[ "$f" -eq 0 ]
