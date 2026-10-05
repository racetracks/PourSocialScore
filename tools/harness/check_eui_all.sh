#!/bin/sh
# The EllesmereUI checks of the harness on their own (run from the repo root,
# needs lua5.1): the integration switch, then the window, panel pages,
# options, import/export, Players and Guilds tabs with PourSocialScore_EllesmereUI
# from its own repository (PSS_EUI_ADDON, default
# ../poursocialscore-ellesmereui/PourSocialScore_EllesmereUI).
#   sh tools/harness/check_eui_all.sh
# validate_all.sh runs it; the PourSocialScore-EllesmereUI repository's CI
# runs it against this repository.
here=$(dirname "$0")
work=${TMPDIR:-/tmp}/pss-eui
rm -rf "$work"; mkdir -p "$work"
fail=0

# EllesmereUI integration switch (3.1): option, reload prompt, commands
echo "== EllesmereUI switch"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_eui.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS eui" || fail=1

# EllesmereUI front end (3.1 E.2 on)
eui=${PSS_EUI_ADDON:-$here/../../../poursocialscore-ellesmereui/PourSocialScore_EllesmereUI}
if [ -f "$eui/PourSocialScore_EllesmereUI.toc" ]; then
	echo "== EllesmereUI window"
	x="$here/eui_stub/EllesmereUI,$eui"
	out=$(PSS_PHASE=1 PSS_EXTRA_ADDONS="$x" lua5.1 "$here/run.lua" . - "$work/sv-eui.lua" "$here/check_eui_window.lua" 2>&1 | grep -v '^|cff')
	out="$out
$(PSS_PHASE=2 PSS_EXTRA_ADDONS="$x" lua5.1 "$here/run.lua" . "$work/sv-eui.lua" - "$here/check_eui_window.lua" 2>&1 | grep -v '^|cff')"
	out="$out
$(PSS_PHASE=3 PSS_EXTRA_ADDONS="$x" lua5.1 "$here/run.lua" . "$work/sv-eui.lua" - "$here/check_eui_window.lua" 2>&1 | grep -v '^|cff')"
	echo "$out"
	for p in 1 2 3; do echo "$out" | grep -q "PASS eui window $p" || fail=1; done
	# the Players tab (3.1 E.4) and the core player queries
	echo "== EllesmereUI Players tab"
	out=$(PSS_EXTRA_ADDONS="$x" lua5.1 "$here/run.lua" . "$work/sv-eui.lua" - "$here/check_eui_players.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS eui players" || fail=1
	# the Guilds tab (3.1 E.5) and the core guild queries
	echo "== EllesmereUI Guilds tab"
	out=$(PSS_EXTRA_ADDONS="$x" lua5.1 "$here/run.lua" . "$work/sv-eui.lua" - "$here/check_eui_guilds.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS eui guilds" || fail=1
else
	echo "== EllesmereUI window: skipped (no PourSocialScore_EllesmereUI at $eui)"
	[ -n "$PSS_EUI_REQUIRED" ] && fail=1
fi

if [ $fail -eq 0 ]; then echo "All EllesmereUI checks passed"; else echo "EllesmereUI checks FAILED"; fi
exit $fail
