#!/bin/sh
# Checks the coding rules that can be checked by a script:
#   1. Lua 5.1 only: every .lua file compiles with luac5.1; no goto, no
#      ::labels::, no Lua 5.2+ library calls (tools/check_style.lua)
#   2. ASCII only in .lua, .toc, .xml and the .txt files shipped in the zip
#   4. Tabs, not spaces: indentation, mid-line alignment and no trailing
#      whitespace (tools/check_style.lua; --fix there repairs these)
#   6. Core logic files hold no UI code (tools/check_layers.lua)
#   Every top-level key the code saves is in the schema map
#   (PourSocialScore/PSS_Schema.lua, tools/check_schema.lua)
#   Every addon file that uses M declares a local M (tools/check_locals.lua)
#   Every OnUpdate and timer call is on the approved list; the trigger engine
#   has no OnUpdate and one timer call (tools/check_timers.lua)
#   The member fields S3 stops saving are read only through their accessors
#   (tools/check_fields.lua)
#   Every PourSocialScore_* folder's three TOCs agree (tools/check_toc.sh)
#   history.txt starts with the section of the version every TOC carries
#   versions.json (tools/versions.py check): well formed, build numbers never
#   go back, the TOC version is its newest entry, never in an addon folder;
#   in CI every entry has its PR (PSS_PR: this pull request's number)
#   The window (PourSocialScore_GUI) and the Libraries code it calls use
#   PSS names only: no EllesmereUI or EUI names
# Usage: sh tools/check_rules.sh   (from the repo root, needs luac5.1/lua5.1)

fail=0
# every addon folder (3.0 layout: PourSocialScore/, PourSocialScore_*/)
files=$(ls PourSocialScore*/*.lua tools/*.lua tools/harness/*.lua 2>/dev/null)

for f in $files; do
	luac5.1 -p "$f" || fail=1
done

lua5.1 tools/check_style.lua $files || fail=1

if LC_ALL=C grep -nP '[^\x00-\x7F]' $(ls PourSocialScore*/*.toc PourSocialScore*/*.xml 2>/dev/null) readme.txt history.txt; then
	echo "ASCII only: non-ASCII bytes found above"
	fail=1
fi

if grep -nP '^\t* |[ \t]+$' $(ls PourSocialScore*/*.xml 2>/dev/null); then
	echo "Tabs, not spaces: space indentation or trailing whitespace found above"
	fail=1
fi

lua5.1 tools/check_layers.lua || fail=1

lua5.1 tools/check_schema.lua > /dev/null || { lua5.1 tools/check_schema.lua; fail=1; }

lua5.1 tools/check_locals.lua || fail=1

lua5.1 tools/check_timers.lua || fail=1

lua5.1 tools/check_fields.lua || fail=1

for d in PourSocialScore_*/; do
	sh tools/check_toc.sh "${d%/}" || fail=1
done

ver=$(sed -n 's/^## Version: *//p' PourSocialScore/PourSocialScore.toc | tr -d '\r')
top=$(sed -n 's/^=> \([^ ]*\) .*/\1/p' history.txt | head -n 1)
if [ "$top" != "$ver" ]; then
	echo "history.txt: the top section is '$top', the TOCs say '$ver'"
	fail=1
fi

# the top section's bullets are written (a release's summary at release time)
if awk 'NR > 1 && /^=> / { n++ } n == 1' history.txt | grep -qE '^- (What changed, in plain words\.|Summary of every change since .*written at release time)'; then
	echo "history.txt: the top section still holds the placeholder bullet"
	fail=1
fi

# the 3.7.0.106 section credits Syndicator by name and says so in plain words (no code notes)
if [ "$ver" = "3.7.0.106" ] && ! awk 'NR > 1 && /^=> / { n++ } n == 1' history.txt | grep -q 'Syndicator by plusmouse'; then
	echo "history.txt: the 3.7.0.106 section must credit Syndicator by plusmouse"
	fail=1
fi

strict=""
[ -n "$CI" ] && strict="--strict"
python3 tools/versions.py check --toc "$ver" $strict ${PSS_PR:+--pr "$PSS_PR"} || fail=1

if grep -nE 'EUI|[Ee]llesmere' PourSocialScore_GUI/* PourSocialScore_Libraries/PSS_ViewNav.lua PourSocialScore_Libraries/PSS_DetailQuery.lua PourSocialScore_Libraries/PSS_PlayerView.lua PourSocialScore_Libraries/PSS_GuildView.lua PourSocialScore_Libraries/PSS_FilterView.lua PourSocialScore_Libraries/PSS_EventsView.lua PourSocialScore_Libraries/PSS_OptionsView.lua PourSocialScore_Libraries/PSS_RowMenus.lua PourSocialScore_Libraries/PSS_Graphics.lua PourSocialScore_Libraries/PSS_MacroData.lua PourSocialScore_Libraries/PSS_Macros.lua PourSocialScore_Libraries/PSS_AddonsQuery.lua PourSocialScore_Libraries/PSS_AddonsView.lua; then
	echo "PSS names only: an EllesmereUI or EUI name found above"
	fail=1
fi

# one reload call (3.6.0.81): ReloadUI() is called only by the helper
# M.PSS_ReloadUI in PSS_OptionsView.lua; every caller goes through it
if grep -nE '(^|[^_.A-Za-z])ReloadUI\(|[^_A-Za-z]ReloadUI\)' PourSocialScore*/*.lua | grep -v 'PSS_OptionsView.lua'; then
	echo "one reload: a ReloadUI call outside M.PSS_ReloadUI (PSS_OptionsView.lua) found above"
	fail=1
fi

# the addon manager is written from its design, clean room (3.6.0): no
# identifier of the addon manager it follows in behaviour may be copied
if grep -nE 'ACP_|AddonList_|NoRecurse|NoChildren|ProtectedAddons|AddonSet|EnableRecurse|LocateEmbeds|FauxScrollFrame' PourSocialScore*/*.lua PourSocialScore*/*.xml 2>/dev/null; then
	echo "clean room: an identifier of another addon manager found above (written from the design, never copied)"
	fail=1
fi

[ $fail -eq 0 ] && echo "All rule checks passed"
exit $fail
