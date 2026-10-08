#!/bin/sh
# Sets the next version in every TOC and adds its history.txt section on top
# (02 F: X.Y.Z.B, B = the build number; a plain X.Y.Z is a full release, set
# only when the author says so).
#   sh tools/bump_version.sh build "Title"         the next build:  1.4.0.3 -> 1.4.0.4
#   sh tools/bump_version.sh release "Title"       a full release:  1.4.0.9 -> 1.4.0
#   sh tools/bump_version.sh line X.Y.Z "Title"    a new line:      -> X.Y.Z.1
# Run from the repo root, then fill in the history bullets.
mode=$1
case "$mode" in
	line) line=$2; title=$3 ;;
	build|release) title=$2 ;;
	*) echo "usage: sh tools/bump_version.sh build|release \"Title\"  or  line X.Y.Z \"Title\""; exit 1 ;;
esac
if [ -z "$title" ]; then echo "a title is needed"; exit 1; fi

ver=$(sed -n 's/^## Version: *//p' MyAddon/MyAddon.toc | tr -d '\r')
base=$(echo "$ver" | sed -n 's/^\([0-9]*\.[0-9]*\.[0-9]*\).*$/\1/p')
b=$(echo "$ver" | sed -n 's/^[0-9]*\.[0-9]*\.[0-9]*\.\([0-9]*\)$/\1/p')

case "$mode" in
	build)
		if [ -z "$b" ]; then echo "$ver is a full release: start a new line with 'line'"; exit 1; fi
		new=$base.$((b + 1))
		;;
	release)
		if [ -z "$b" ]; then echo "$ver is already a full release"; exit 1; fi
		new=$base
		;;
	line)
		if ! echo "$line" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then echo "line must be X.Y.Z"; exit 1; fi
		new=$line.1
		;;
esac

for toc in MyAddon*/*.toc; do
	sed "s/^## Version: .*/## Version: $new/" "$toc" > "$toc.new" && mv "$toc.new" "$toc"
done
{
	sed -n '1,/^$/p' history.txt
	printf '=> %s - %s\n\n- What changed, in plain words.\n\n' "$new" "$title"
	sed '1,/^$/d' history.txt
} > history.txt.new && mv history.txt.new history.txt
echo "$ver -> $new"
