#!/bin/sh
# Stage close (DEC-00390): saves, validate (real saves), host (test zip), render (session README).
usage() {
	echo "usage: sh tools/stage_close.sh <scratch checkout> [--dry-run] [--no-host] [--no-push]"
	echo "  saves, validate (real saves), host (test zip), render (session README); run from the addon repo root"
}
scratch=""
dry=0
nohost=0
nopush=0
for a in "$@"; do
	case "$a" in
	--help|-h) usage; exit 0 ;;
	esac
done
for a in "$@"; do
	case "$a" in
	--dry-run) dry=1 ;;
	--no-host) nohost=1 ;;
	--no-push) nopush=1 ;;
	-*) usage >&2; exit 2 ;;
	*)
		if [ -n "$scratch" ]; then usage >&2; exit 2; fi
		scratch="$a"
		;;
	esac
done
if [ ! -f tools/harness/validate_all.sh ]; then
	echo "stage_close: run from the addon repo root"
	exit 2
fi
if [ -z "$scratch" ] || [ ! -d "$scratch/.git" ]; then
	echo "stage_close: scratch checkout not found: $scratch"
	exit 2
fi
out="${PSS_STAGE_OUT:-${TMPDIR:-/tmp}/pss-stage-close}"
hostcmd="sh tools/host_build.sh \"$scratch\""
[ "$nopush" = 1 ] && hostcmd="$hostcmd --no-push"
if [ "$dry" = 1 ]; then
	echo "would run: sh tools/harness/build_saves.sh \"$scratch\" \"$out/saves\""
	echo "would run: PSS_REAL_SAVES=\"$out/saves\" sh tools/harness/validate_all.sh"
	[ "$nohost" = 1 ] || echo "would run: $hostcmd"
	echo "would run: python3 .claude/scripts/ledger.py render"
	echo "OK dry run"
	exit 0
fi
rm -rf "$out"
mkdir -p "$out"

fail() { # step, filter
	echo "FAIL $1 (log: $out/$1.log)"
	if [ -n "$2" ]; then grep -E "$2" "$out/$1.log" | tail -n 20; else tail -n 20 "$out/$1.log"; fi
	exit 1
}

ran=""
sh tools/harness/build_saves.sh "$scratch" "$out/saves" > "$out/saves.log" 2>&1 || fail saves ""
ran="saves"
PSS_REAL_SAVES="$out/saves" sh tools/harness/validate_all.sh > "$out/validate.log" 2>&1 || fail validate "FAIL|SKIPPED|rror"
ran="$ran validate"
if [ "$nohost" = 0 ]; then
	if [ "$nopush" = 1 ]; then
		sh tools/host_build.sh "$scratch" --no-push > "$out/host.log" 2>&1 || fail host ""
	else
		sh tools/host_build.sh "$scratch" > "$out/host.log" 2>&1 || fail host ""
	fi
	grep 'https://' "$out/host.log"
	ran="$ran host"
fi
python3 .claude/scripts/ledger.py render > "$out/render.log" 2>&1 || fail render ""
grep '^tokens:' "$out/render.log"
ran="$ran render"
echo "OK stage close: $ran"
