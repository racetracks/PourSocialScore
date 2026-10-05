#!/bin/sh
# Rules check for PourSocialScore_EllesmereUI, the same rules the
# PourSocialScore repo checks, in EllesmereUI's code style (run from the repo
# root; needs luac5.1). It is also the "Rules" GitHub check.
#   1. Lua 5.1 only: every .lua compiles with luac5.1; no goto, ::labels:: or
#      Lua 5.2+ library calls (table.unpack, table.pack, table.move, bit32,
#      utf8, _ENV, rawlen)
#   2. ASCII only in .lua, .toc and readme.md
#   3. EllesmereUI's style: spaces, never tabs, and no trailing whitespace
#   4. TOCs: the three TOCs carry the same Version (X.Y.Z or X.Y.Z-suffix),
#      Title, Notes, Category, Group, IconTexture, LoadOnDemand, Dependencies
#      and SavedVariables, list the same files, and every listed file exists
dir=PourSocialScore_EllesmereUI
fail=0
lua=$(ls $dir/*.lua)
tocs="$dir/PourSocialScore_EllesmereUI.toc $dir/PourSocialScore_EllesmereUI_Mainline.toc $dir/PourSocialScore_EllesmereUI_Camelot.toc"

for f in $lua; do
	luac5.1 -p "$f" || fail=1
done

if grep -nE '(^|[^[:alnum:]_.])(goto[[:space:]]|table\.unpack|table\.pack|table\.move|bit32\.|utf8\.|_ENV|rawlen)|::[A-Za-z_][A-Za-z0-9_]*::' $lua; then
	echo "Lua 5.1 only: goto, a label or a Lua 5.2+ call found above"
	fail=1
fi

if LC_ALL=C grep -nP '[^\x00-\x7F]' $lua $tocs readme.md; then
	echo "ASCII only: non-ASCII bytes found above"
	fail=1
fi

if grep -nP '\t|[ ]+$' $lua $tocs; then
	echo "EllesmereUI style: a tab or trailing whitespace found above"
	fail=1
fi

# TOCs
base=$dir/PourSocialScore_EllesmereUI.toc
for t in $tocs; do
	[ -f "$t" ] || { echo "$t: missing"; fail=1; continue; }
	for key in Version Title Notes Category Group IconTexture LoadOnDemand Dependencies SavedVariables; do
		a=$(sed -n "s/^## $key: *//p" "$base" | tr -d '\r')
		b=$(sed -n "s/^## $key: *//p" "$t" | tr -d '\r')
		[ -n "$b" ] || { echo "$t: no ## $key"; fail=1; }
		[ "$a" = "$b" ] || { echo "$t: ## $key differs from $base"; fail=1; }
	done
	if [ "$(grep -v '^#' "$base" | grep .)" != "$(grep -v '^#' "$t" | grep .)" ]; then
		echo "$t: file list differs from $base"
		fail=1
	fi
	for f in $(grep -v '^#' "$t" | tr -d '\r'); do
		[ -f "$dir/$f" ] || { echo "$t: lists $f, which does not exist"; fail=1; }
	done
done
ver=$(sed -n 's/^## Version: *//p' "$base" | tr -d '\r')
echo "$ver" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9]+)?$' || { echo "Version '$ver' is not X.Y.Z or X.Y.Z-suffix"; fail=1; }

[ $fail -eq 0 ] && echo "All rule checks passed"
exit $fail
