#!/bin/sh
# Upgrade test: SavedVariables written by an older version are loaded by
# this checkout, and the block count lines are checked (check_stats.lua).
#   sh tools/harness/validate.sh <name> <sv.lua> <expect.lua>
# Phase 2 runs 1 hour after the old data was written, phase 3 a day later.
set -e
here=$(dirname "$0")
name=$1; sv=$2; expect=$3
out=${TMPDIR:-/tmp}/pss-validate-$name
mkdir -p "$out"
tm=$(lua5.1 -e "print(dofile('$expect').time)")
echo "== $name"
PSS_TIME=$((tm + 3600)) PSS_PHASE=2 PSS_EXPECT=$expect \
	lua5.1 "$here/run.lua" . "$sv" "$out/after-login1.lua" "$here/check_stats.lua" | grep -v '^|cff' || true
PSS_TIME=$((tm + 24 * 3600)) PSS_PHASE=3 PSS_EXPECT=$expect \
	lua5.1 "$here/run.lua" . "$out/after-login1.lua" "$out/after-login2.lua" "$here/check_stats.lua" | grep -v '^|cff' || true
