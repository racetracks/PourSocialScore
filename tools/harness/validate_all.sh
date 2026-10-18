#!/bin/sh
# SavedVariables upgrade test for 2.0.1, 2.0.8, 2.0.17, 2.0.18, 2.0.19,
# 2.0.22, 2.0.35, 2.0.36, 2.0.37, 2.0.38, 2.0.39, 2.0.40, 2.0.41, 2.0.42, 2.0.43 and 2.0.44, and removals (run from the
# repo root, needs lua5.1 and git).
#   sh tools/harness/validate_all.sh
# PSS_REAL_SAVES=<dir> also loads every real save (*.lua) found under that
# directory (they are not kept in the repository).
# 2.0.18 and later: that version's code (from git) writes the save.
# 2.0.17, 2.0.8, 2.0.1: their code is not in git, so the 2.0.18 save is
# rewritten into their shape (tools/harness/downgrade.lua).
here=$(dirname "$0")
# PSS_VALIDATION_LOG=<file> keeps the whole output in that file too (for
# tools/host_tests.sh --log); the exit status is the run's own
if [ -n "$PSS_VALIDATION_LOG" ] && [ -z "$PSS_VALIDATION_TEE" ]; then
	rcfile=$(mktemp)
	{ PSS_VALIDATION_TEE=1 sh "$0" "$@"; echo $? > "$rcfile"; } 2>&1 | tee "$PSS_VALIDATION_LOG"
	rc=$(cat "$rcfile"); rm -f "$rcfile"
	exit "$rc"
fi
work=${TMPDIR:-/tmp}/pss-validate
rm -rf "$work"; mkdir -p "$work"
t0=1790000000
fail=0
# a check that could not run is listed and fails the run unless PSS_ALLOW_SKIP=1
# (a NOTE and exit 0 once hid a skipped comparison)
skipped=""
# the upgrade checks rebuild old versions from git history: a shallow clone
# (a Claude Code session) lacks it and the split checks then fail
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] && ! git cat-file -e 767c49c 2>/dev/null; then
	echo "NOTE: shallow clone without the 2.0 history; run: git fetch --depth=2000 origin main"
fi

for pair in 2.0.18:d885cd0 2.0.19:4b7066c 2.0.22:2837de0 2.0.35:9646596 2.0.36:9bfba2e 2.0.37:710d180 2.0.38:d331f82 2.0.39:24d234c 2.0.40:34092f7 2.0.41:35742b2 2.0.42:8a8a8fd 2.0.43:41444f3 2.0.44:767c49c; do
	v=${pair%%:*}; c=${pair#*:}
	mkdir -p "$work/src-$v"
	git archive "$c" | tar -x -C "$work/src-$v"
	PSS_TIME=$t0 PSS_EXPECT="$work/expect-$v.lua" \
		lua5.1 "$here/run.lua" "$work/src-$v" - "$work/sv-$v.lua" "$here/make_data.lua" | grep '^made data' || fail=1
done
for v in 2.0.17 2.0.8 2.0.1; do
	lua5.1 "$here/downgrade.lua" "$work/sv-2.0.18.lua" "$work/sv-$v.lua" "$v" > /dev/null || fail=1
	cp "$work/expect-2.0.18.lua" "$work/expect-$v.lua"
done

for v in 2.0.1 2.0.8 2.0.17 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36 2.0.37 2.0.38 2.0.39 2.0.40 2.0.41 2.0.42 2.0.43 2.0.44; do
	out=$(sh "$here/validate.sh" "$v" "$work/sv-$v.lua" "$work/expect-$v.lua" 2>&1)
	echo "$out"
	echo "$out" | grep -q "PASS phase 3" || fail=1
	# the same save with more history than the log holds (per-person keep)
	lua5.1 "$here/overflow.lua" "$work/sv-$v.lua" "$work/sv-$v-overflow.lua" \
		"$work/expect-$v.lua" "$work/expect-$v-overflow.lua" > /dev/null || fail=1
	out=$(PSS_OVERFLOW=1 sh "$here/validate.sh" "$v+overflow" "$work/sv-$v-overflow.lua" "$work/expect-$v-overflow.lua" 2>&1)
	echo "$out"
	echo "$out" | grep -q "PASS phase 5" || fail=1
	echo "$out" | grep -q "FAIL" && fail=1
done

# removals (2.0.43): a player taken off any list leaves nothing saved, and a
# built-in list member stays blocked there with a note. Run on the save each
# version's upgrade wrote (validate.sh phase 3).
for v in 2.0.1 2.0.8 2.0.17 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36 2.0.37 2.0.38 2.0.39 2.0.40 2.0.41 2.0.42 2.0.43 2.0.44; do
	echo "== $v removals"
	src=${TMPDIR:-/tmp}/pss-validate-$v/after-login2.lua
	for ph in forget1 forget2; do
		out=$(PSS_PHASE=$ph lua5.1 "$here/run.lua" . "$src" "$work/forget-$v-$ph.lua" "$here/check_forget.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS $ph" || fail=1
		src=$work/forget-$v-$ph.lua
	done
done

# guild rule blocks (2.0.39): counted once, linked to the rule, no combat
# discovery. Saves written by each version's own code (2.0.18 and later).
for v in 2.0.18 2.0.19 2.0.22 2.0.35 2.0.36 2.0.37 2.0.38 2.0.39 2.0.40 2.0.41 2.0.42 2.0.43 2.0.44; do
	echo "== $v guild rule"
	PSS_TIME=$t0 PSS_EXPECT="$work/expect-gr-$v.lua" \
		lua5.1 "$here/run.lua" "$work/src-$v" - "$work/sv-gr-$v.lua" "$here/make_guildrule.lua" | grep '^made' || fail=1
	tm=$(lua5.1 -e "print(dofile('$work/expect-gr-$v.lua').time)")
	out=$(PSS_TIME=$((tm + 3600)) PSS_EXPECT="$work/expect-gr-$v.lua" \
		lua5.1 "$here/run.lua" . "$work/sv-gr-$v.lua" "$work/sv-gr-$v-after.lua" "$here/check_guildrule.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS guild rule" || fail=1
	# the saved rule keeps no statistics of its own
	lua5.1 -e "dofile('$work/sv-gr-$v-after.lua'); assert(PSS_CountsDB.builtinStats.PSSG0001 == nil, 'rule stats saved'); assert(PSS_CountsDB.guildRuleCountsV1 == true)" || fail=1
done

# group and whisper alerts (2.0.44), on a fresh save
echo "== alerts"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_alerts.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS alerts" || fail=1

# the ignore auto-reply echo (issue 183): hidden only while the option is off
echo "== ignore reply echo"
for camel in 0 1; do
	out=$(PSS_CAMELOT=$camel lua5.1 "$here/run.lua" . - - "$here/check_ignorereply.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS ignorereply" || fail=1
done

# the PSS window (3.4.0) and the back end on demand: PourSocialScore_GUI and
# _Libraries load only when needed; /pss gui, Friends / Social and the Addon
# Compartment open it (3.4.0.23, D1; the window's folder from 3.4.0.25, D2)
echo "== new window on demand"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_tui.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS tui" || fail=1

# graphics settings (3.5.0, /pss gfx, Camelot): the logic, the history, keep
# and revert, Retail and a client without the console API; the popup, the
# keep prompt after a /reload (the apply run writes a save with a change
# waiting, each login run answers it another way) and the History view.
# The saves they write join the schema check below.
echo "== graphics settings"
for ph in logic history keep; do
	out=$(PSS_PHASE=$ph PSS_CAMELOT=1 lua5.1 "$here/run.lua" . - "$work/gfx-$ph.lua" "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS gfx $ph" || fail=1
done
out=$(PSS_PHASE=retail lua5.1 "$here/run.lua" . - "$work/gfx-retail.lua" "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS gfx retail" || fail=1
out=$(PSS_GFX_NOAPI=1 PSS_PHASE=noapi PSS_CAMELOT=1 lua5.1 "$here/run.lua" . - - "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS gfx noapi" || fail=1
out=$(PSS_GFX_OLDAPI=1 PSS_PHASE=noapi PSS_CAMELOT=1 lua5.1 "$here/run.lua" . - - "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS gfx noapi" || fail=1
for ph in popup history_ui; do
	out=$(PSS_PHASE=$ph PSS_CAMELOT=1 lua5.1 "$here/run.lua" . - "$work/gfx-$ph.lua" "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS gfx $ph" || fail=1
done
out=$(PSS_PHASE=apply PSS_CAMELOT=1 lua5.1 "$here/run.lua" . - "$work/gfx-apply.lua" "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS gfx apply" || fail=1
for run in keep timeout escape revert; do
	out=$(PSS_GFX_RUN=$run PSS_GFX_SET=graphicsQuality=2 PSS_RELOAD=1 PSS_PHASE=reload PSS_CAMELOT=1 lua5.1 "$here/run.lua" . "$work/gfx-apply.lua" "$work/gfx-reload-$run.lua" "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | sed "s/^PASS gfx reload/PASS gfx reload ($run)/"
	echo "$out" | grep -q "PASS gfx reload" || fail=1
done
# a login after the prompt was answered: nothing waits, neither part loads
out=$(PSS_GFX_RUN=none PSS_GFX_SET=graphicsQuality=2 PSS_RELOAD=1 PSS_PHASE=reload PSS_CAMELOT=1 lua5.1 "$here/run.lua" . "$work/gfx-reload-keep.lua" "$work/gfx-reload-none.lua" "$here/check_gfx.lua" 2>&1 | grep -v '^|cff')
echo "$out" | sed "s/^PASS gfx reload/PASS gfx reload (none)/"
echo "$out" | grep -q "PASS gfx reload" || fail=1

# macro helper (3.5.0, /pss macro, Camelot): the shipped data, create and
# update by name per store (account or character per macro, set, default
# or the command word), the class gate, preview, room, combat, no API,
# Retail, login, and the memory budget (resident, garbage, nothing kept)
echo "== macro helper"
for ph in data global wrongclass dynicon combat list login memory; do
	out=$(PSS_PHASE=$ph PSS_CAMELOT=1 lua5.1 "$here/run.lua" . - "$work/macro-$ph.lua" "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS macro $ph" || fail=1
done
for ph in class stores; do
	out=$(PSS_PHASE=$ph PSS_CAMELOT=1 PSS_CLASS=WARRIOR lua5.1 "$here/run.lua" . - "$work/macro-$ph.lua" "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS macro $ph" || fail=1
done
out=$(PSS_PHASE=existing PSS_CAMELOT=1 PSS_MACRO_SEED="a:Trinket 1=/say hi;a:Other=/dance;c:Trinket 2=/say char" lua5.1 "$here/run.lua" . - - "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS macro existing" || fail=1
for max in 1,18 2,18; do
	out=$(PSS_PHASE=full PSS_CAMELOT=1 PSS_MACRO_MAX=$max PSS_MACRO_SEED="a:Keep=/x" lua5.1 "$here/run.lua" . - - "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | sed "s/^PASS macro full/PASS macro full ($max)/"
	echo "$out" | grep -q "PASS macro full" || fail=1
done
out=$(PSS_PHASE=dynicon PSS_CAMELOT=1 PSS_MACRO_DYNICON=1 lua5.1 "$here/run.lua" . - - "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
echo "$out" | sed "s/^PASS macro dynicon/PASS macro dynicon (dynamic icon)/"
echo "$out" | grep -q "PASS macro dynicon" || fail=1
out=$(PSS_PHASE=noapi PSS_CAMELOT=1 PSS_MACRO_NOAPI=1 lua5.1 "$here/run.lua" . - - "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS macro noapi" || fail=1
out=$(PSS_PHASE=retail lua5.1 "$here/run.lua" . - "$work/macro-retail.lua" "$here/check_macro.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS macro retail" || fail=1

# addon manager (3.6.0, /pss acp, /acp and the AddOns tab): every phase of
# check_addons.lua on Retail and on Camelot (addons_phases.sh)
echo "== addon manager"
sh "$here/addons_phases.sh" "$work" || fail=1

# Enabled components (issue 181): defaults, the Options section, each
# component off and on, a simulated reload (components_phases.sh)
echo "== enabled components"
sh "$here/components_phases.sh" "$work" || fail=1

# The chat filter's registration (W-8): a refused add, another addon's rebuild, a faulted start-up
# stage, the client's list in both shapes (filterreg_phases.sh)
echo "== chat filter registration"
sh "$here/filterreg_phases.sh" "$work/filterreg" || fail=1

# PSS Drop Cheapest Thing (money-helper): scan, filters, act, command, button,
# round trips, the log, the merchant button, off = zero cost (dtt_phases.sh)
echo "== drop cheapest thing"
sh "$here/dtt_phases.sh" || fail=1

# the service bus and its gates (service-bus-helper): record sets, calls,
# isolation, budgets, the GUI boundary, the scratch design-proof gate when
# PSS_SCRATCH names a scratch checkout (bus_phases.sh)
echo "== service bus"
sh "$here/bus_phases.sh" || fail=1

# the Spyglass engine (search-helper phase A): check_ix.lua on Retail and Camelot, the real-save phases on
# every save when PSS_REAL_SAVES is set (ix_phases.sh)
echo "== Spyglass engine (ix_phases.sh)"
sh "$here/ix_phases.sh" || fail=1

# the warehouse (warehouse-helper, one build 3.7.0.106): every phase of
# check_wh.lua on Retail and Camelot (wh_phases.sh)
echo "== warehouse"
sh "$here/wh_phases.sh" || fail=1
# more of it: 200 random worlds, every service failing (also at the login of each real save), the 34
# mutants (each must fail a check), and the real saves with the Warehouse on and off again
PSS_MODEL_SEEDS=${PSS_MODEL_SEEDS:-200} sh "$here/wh_phases.sh" model || fail=1
sh "$here/wh_faults.sh" ${PSS_REAL_SAVES:+"$PSS_REAL_SAVES"} || fail=1
sh "$here/wh_mutants.sh" || fail=1
[ -n "$PSS_REAL_SAVES" ] && { sh "$here/wh_realsaves.sh" "${PSS_SAME_AS:-origin/main}" "$PSS_REAL_SAVES" || fail=1; }

# the new window's Libraries maths (3.4.0-dev005): pane numbers equal the
# core's counts, slices, back / forward, throttle
echo "== new window maths"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_viewquery.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS viewquery" || fail=1

# the new window's Player Ignore List tab (3.4.0-dev007)
echo "== new window Players tab"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_players.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS players" || fail=1

# the new window's right-click menus (3.4.0.21)
echo "== new window right-click menus"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_menus.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS menus" || fail=1

# the new window's Guild Ignore List tab, part 1 (3.4.0-dev008)
echo "== new window Guilds tab"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_guilds.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS guilds" || fail=1

# the view functions moved out of the window's drawing files (W2)
echo "== view functions"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_viewfns.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS viewfns" || fail=1

# the new window's Chat Filters tab (3.4.0-dev010)
echo "== new window Chat Filters tab"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_filters.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS filters" || fail=1

# the new window's Events tab (3.4.0-dev011)
echo "== new window Events tab"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_events.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS events" || fail=1

# the new window's Options and Import/Export tabs (3.4.0-dev012)
echo "== new window Options and Import/Export tabs"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_options.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "PASS|FAIL"
echo "$out" | grep -q "PASS options" || fail=1

# window tidy W2: logic of the Events, Options and Chat Filters tabs in Libraries
echo "== window tidy W2 (Events, Options, Filters)"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_w2b.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS w2b" || fail=1

# secret values: chat, unit and hook values checked, never kept (3.4.0.14)
echo "== secret values"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_secrets.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "PASS|FAIL"
echo "$out" | grep -q "PASS secrets" || fail=1

# names (core uplift N1, 3.4.1.32): M.PSS_NormName joins every name; keys
# unchanged, the Camelot surname rule, secrets
echo "== names"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_names.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "names:|PASS|FAIL"
echo "$out" | grep -q "PASS names" || fail=1

# Blizzard's ignore list (core uplift B1, 3.4.1.35): PSS is authoritative.
# Flow on a fresh save: the per-player tick, a Blizzard ignore moving into
# PSS and off Blizzard's list, removal both ways, a full list. Then a
# 3.4.1.34-style save (global option on) through upgrade step 8 and the
# login sync, with Blizzard's list there at once and arriving late.
echo "== blizzard ignore"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_blizzard.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "blizzard|PASS|FAIL"
echo "$out" | grep -q "PASS blizzard" || fail=1
PSS_PHASE=make lua5.1 "$here/run.lua" . - "$work/bz-make.lua" "$here/check_blizzard.lua" | grep -q "PASS blizzard make" || fail=1
for late in "" 1; do
	out=$(PSS_PHASE=login PSS_BLIZZ_IGNORES="Alpha;Stranger" PSS_BLIZZ_LATE=$late lua5.1 "$here/run.lua" . "$work/bz-make.lua" - "$here/check_blizzard.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -E "blizzard|PASS|FAIL"
	echo "$out" | grep -q "PASS blizzard login" || fail=1
done

# one window (3.4.0.25, D2): upgrade step 7 prunes euiIntegration (held in
# PSS_OptionsDB, no longer an option) and the old window's sizes, column
# widths and places, keeps the window's own; a PourSocialScore_EllesmereUI
# folder left on disk is named once, at the first login after the upgrade
echo "== cutover"
lua5.1 "$here/run.lua" . - "$work/co-0.lua" > /dev/null 2>&1
cat >> "$work/co-0.lua" <<'SV'
PourSocialScoreDB.upgrade.step = 6
PSS_OptionsDB.euiIntegration = true
PSS_OptionsDB.windowSizes = { main = { 900, 600 }, guildDetail = { 400, 300 } }
PSS_OptionsDB.columnWidths = { players = { 120, 80 } }
PSS_OptionsDB.windowPoints = { PSS = { "CENTER", "CENTER", 0, 0 }, PSSGuildDetail = { "LEFT", "LEFT", 5, 5 },
	PSS_Window = { "TOPLEFT", "TOPLEFT", 300, -200 }, PSS_WindowTab = "guilds" }
SV
mkdir -p "$work/old/PourSocialScore_EllesmereUI"
printf '## Interface: 120007\n## LoadOnDemand: 1\n' > "$work/old/PourSocialScore_EllesmereUI/PourSocialScore_EllesmereUI.toc"
co1=$(PSS_EXTRA_ADDONS="$work/old/PourSocialScore_EllesmereUI" PSS_PHASE=1 lua5.1 "$here/run.lua" . "$work/co-0.lua" "$work/co-1.lua" "$here/check_cutover.lua" 2>&1)
co2=$(PSS_EXTRA_ADDONS="$work/old/PourSocialScore_EllesmereUI" PSS_PHASE=2 lua5.1 "$here/run.lua" . "$work/co-1.lua" "$work/co-2.lua" "$here/check_cutover.lua" 2>&1)
printf "%s\n%s\n" "$co1" "$co2" | grep -E "PASS|FAIL"
note="safe to delete from Interface"
if echo "$co1" | grep -q "PASS cutover 1" && echo "$co2" | grep -q "PASS cutover 2" &&
	[ "$(echo "$co1" | grep -c "$note.*PourSocialScore_EllesmereUI")" = 1 ] && ! echo "$co2" | grep -q "$note"; then
	echo "PASS cutover (old folder named once)"
else
	echo "$co1"; echo "$co2"; echo "FAIL cutover"; fail=1
fi
# no folder left: no note
co3=$(lua5.1 "$here/run.lua" . "$work/co-0.lua" - 2>&1)
echo "$co3" | grep -q "$note" && { echo "FAIL cutover: the note without an old folder"; fail=1; }

# shipped guild lists on demand (3.0): PourSocialScore_Communities loads
# only when the rule is on or members are needed
echo "== Communities on demand"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_communities.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS communities" || fail=1
out=$(lua5.1 "$here/run.lua" . - - "$here/check_communities_seen.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS communities seen" || fail=1

# packed lists (3.0 Step 5.1): the same members as the unpacked dev16 list
echo "== packed lists"
git show ba5483a:PourSocialScore_Communities/PSS_GuildIgnore_Managed.lua > "$work/managed-dev16.lua"
out=$(PSS_OLD_MANAGED="$work/managed-dev16.lua" lua5.1 "$here/run.lua" . - - "$here/check_packed.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "PASS|FAIL"
echo "$out" | grep -q "PASS packed" || fail=1

# saved data split (3.0): the Options tables, key routing, undo and reset,
# on a fresh save and an upgraded 2.0.44 save
echo "== saved data"
for sv in - "$work/sv-2.0.44.lua"; do
	out=$(lua5.1 "$here/run.lua" . "$sv" - "$here/check_saveddata.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -q "PASS saved data" && echo "PASS saved data ($sv)" || { echo "$out"; echo "FAIL saved data on $sv"; fail=1; }
done

# split (3.0 Steps 4.2 to 4.5): a 2.0 save keeps every count after its data
# moves to PourSocialScore_Options and PourSocialScore_Logging (dev12 build vs
# this one), each move prints one line (2.0.1 to 2.0.17 saves have no shared
# block log to move), and the next login moves nothing
# the checks about saved data (split, upgrades, forward, same saves) run as a
# fresh install: the Enabled components at their defaults, so no option the
# harness adds changes a count or a saved byte (issue 181; run.lua PSS_COMPONENTS)
export PSS_COMPONENTS=none
echo "== split"
rm -rf "$work/src-prev"; mkdir -p "$work/src-prev"
git archive c5c8296 | tar -x -C "$work/src-prev"
git show 3cf8ed6:PourSocialScore_Communities/PSS_GuildIgnore_Managed.lua > "$work/managed-pre-n3.lua"
splitsaves="$work/sv-2.0.1.lua $work/sv-2.0.40.lua $work/sv-2.0.44.lua $work/sv-gr-2.0.44.lua"
# (2.0-layout saves only: a 3.x save already has PSS_OptionsDB, and the
# old build cannot read it)
[ -n "$PSS_REAL_SAVES" ] && splitsaves="$splitsaves $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua' -exec grep -L '^PSS_OptionsDB = ' {} +)"
for sv in $splitsaves; do
	# (optionsSet: dev12 saved every option; since 3.0.0-dev16 only changed
	# ones are saved, and optionsChanged is the count compared. leftMarks:
	# counted since 3.0.0-dev18, which drops marks the shipped list no longer
	# needs; membersShown is the count compared)
	# (log and keep sizes change at 3.2: people's lines leave the log, their
	# world chat is no longer kept; stats24h: the hourly blockStats table
	# the old build reports is pruned from 3.3.0-dev002)
	# (membersShown: the 3.4.1.37 rebuild (N3) dropped 196 surname-as-realm
	# names the old build still ships; a stored member under one of those
	# names now counts on its own, surname_stored.lua)
	drop=$((196 - $(lua5.1 "$here/surname_stored.lua" "$work/managed-pre-n3.lua" "$sv")))
	lua5.1 "$here/run.lua" "$work/src-prev" "$sv" - "$here/dump_counts.lua" 2>&1 | grep '^N ' | grep -v "^N optionsSet=\|^N kept\|^N logLines\|^N stats24h" |
		awk -F= -v drop=$drop '$1 == "N membersShown" { print $1 "=" $2 - drop; next } { print }' > "$work/split-a.txt"
	lua5.1 "$here/run.lua" . "$sv" "$work/split-1.lua" "$here/dump_counts.lua" > "$work/split-b.txt" 2>&1
	lua5.1 "$here/run.lua" . "$work/split-1.lua" - "$here/dump_counts.lua" > "$work/split-c.txt" 2>&1
	if [ -s "$work/split-a.txt" ] && grep '^N ' "$work/split-b.txt" | grep -v '^N leftMarks=\|^N kept\|^N logLines' | diff "$work/split-a.txt" - > /dev/null &&
		grep '^N ' "$work/split-c.txt" | grep -v '^N leftMarks=\|^N kept\|^N logLines' | diff "$work/split-a.txt" - > /dev/null &&
		[ "$(grep -c 'Saved data moved to PourSocialScore_Options' "$work/split-b.txt")" = 1 ] &&
		[ "$(grep -c 'Saved data moved to PourSocialScore_Logging' "$work/split-b.txt")" -le 1 ] && ! grep -q 'Saved data moved' "$work/split-c.txt"; then
		echo "PASS split ($sv)"
	else
		grep '^N ' "$work/split-b.txt" | grep -v '^N leftMarks=' | diff "$work/split-a.txt" -
		echo "FAIL split on $sv"; fail=1
	fi
done

# the saved log (3.2.0-dev007): one group per owner, every line comes back
unset PSS_COMPONENTS
echo "== saved log"
PSS_NOTE="$work/savedlog.txt" PSS_PHASE=1 lua5.1 "$here/run.lua" . - "$work/savedlog.lua" "$here/check_savedlog.lua" 2>&1 | grep -E "PASS|FAIL|saved log:" > "$work/savedlog-1.txt"
PSS_NOTE="$work/savedlog.txt" PSS_PHASE=2 lua5.1 "$here/run.lua" . "$work/savedlog.lua" - "$here/check_savedlog.lua" 2>&1 | grep -E "PASS|FAIL|was:|now:" >> "$work/savedlog-1.txt"
cat "$work/savedlog-1.txt"
grep -q "PASS saved log 1" "$work/savedlog-1.txt" && grep -q "PASS saved log 2" "$work/savedlog-1.txt" || fail=1

# PourSocialScore_Logging on demand (3.0 Step 4.4): not loaded at a normal
# login, lines wait in the outbox over a logout, opening the history or 200
# waiting lines load it
echo "== on demand"
for sv in - "$work/sv-2.0.44.lua"; do
	lua5.1 "$here/run.lua" . "$sv" "$work/od-0.lua" > /dev/null 2>&1
	src=$work/od-0.lua
	for ph in 1 2 3; do
		[ $ph = 3 ] && src=$work/od-1.lua
		out=$(PSS_PHASE=$ph lua5.1 "$here/run.lua" . "$src" "$work/od-$ph.lua" "$here/check_ondemand.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | grep -q "PASS on demand $ph" && echo "PASS on demand $ph ($sv)" || { echo "$out"; echo "FAIL on demand $ph on $sv"; fail=1; }
		src=$work/od-$ph.lua
	done
done

# memory cleanup and the Logging quiet load without timers (3.4.1.52)
echo "== gc"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_gc.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS gc" || fail=1

# capture events only while they can be used (P3, 3.4.1.52)
echo "== capture"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_capture.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS capture" || fail=1

# purge by owner (core uplift S1, 3.4.1.49): a removal never loads Logging;
# the owner is marked and their saved lines go when it loads, a person
# listed again keeps only their new lines, full marks load it at once
echo "== purge"
lua5.1 "$here/run.lua" . - "$work/pg-0.lua" > /dev/null 2>&1
src=$work/pg-0.lua
for ph in 1 2 3 4; do
	[ $ph = 4 ] && src=$work/pg-1.lua
	out=$(PSS_PHASE=$ph lua5.1 "$here/run.lua" . "$src" "$work/pg-$ph.lua" "$here/check_purge.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -q "PASS purge $ph" && echo "PASS purge $ph" || { echo "$out"; echo "FAIL purge $ph"; fail=1; }
	src=$work/pg-$ph.lua
done

# member field accessors (core uplift S2, 3.4.1.50): a record without the
# fields S3 stops saving reads the same through M.PSS_Member*; counts
# without total; the member count never reads the saved memberCount
echo "== accessors"
lua5.1 "$here/run.lua" . - "$work/ac-0.lua" > /dev/null 2>&1
out=$(lua5.1 "$here/run.lua" . "$work/ac-0.lua" "$work/ac-1.lua" "$here/check_accessors.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -q "PASS accessors" && echo "PASS accessors" || { echo "$out"; echo "FAIL accessors"; fail=1; }

# Player Ignore List records (core uplift S2b, 3.4.1.51): every save the
# harness uses (a new one, the planted 3.4.1.50 save with four listed players
# in the old layout, the 2.0 test saves, every real save) moves to one record
# per entry on one login with the same counters; a second login changes
# nothing and keeps unknown fields; entries added and removed in the middle
# never drift; removing a player still clears their record and history
echo "== list records"
lua5.1 "$here/check_listrecords.lua" --plant "$work/lr-plant.lua" > /dev/null || fail=1
lrsaves="- $work/lr-plant.lua $work/sv-2.0.1.lua $work/sv-2.0.40.lua $work/sv-2.0.44.lua $work/sv-gr-2.0.44.lua"
[ -n "$PSS_REAL_SAVES" ] && lrsaves="$lrsaves $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua')"
lrfail=0
for sv in $lrsaves; do
	for ph in login again drift; do
		case $ph in
			login) from=$sv; to="$work/lr-1.lua"; raw=$sv ;;
			again) from="$work/lr-1.lua"; to="$work/lr-2.lua"; raw="$work/lr-1.lua" ;;
			drift) from=$sv; to=-; raw=$sv ;;
		esac
		out=$(PSS_PHASE=$ph PSS_SV_IN="$raw" lua5.1 "$here/run.lua" . "$from" "$to" "$here/check_listrecords.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | grep -q "PASS list records $ph" || { echo "$out"; echo "FAIL list records $ph ($sv)"; lrfail=1; }
	done
	lua5.1 tools/check_schema.lua --saves "$work/lr-1.lua" "$work/lr-2.lua" || lrfail=1
	# the unstripped undo guarantee (A13): login 2 differs from login 1 only by the undo slot, login 3 equals login 2
	# (not the planted 3.4.1.50 save: its second login repairs a name's case on main too)
	if [ "$sv" != "$work/lr-plant.lua" ]; then
		lua5.1 "$here/run.lua" . "$work/lr-2.lua" "$work/lr-3.lua" > /dev/null 2>&1
		lua5.1 "$here/undo_check.lua" 1-to-2 "$work/lr-1.lua" "$work/lr-2.lua" > /dev/null || { echo "FAIL undo 1-to-2 ($sv)"; lrfail=1; }
		lua5.1 "$here/undo_check.lua" same "$work/lr-2.lua" "$work/lr-3.lua" > /dev/null || { echo "FAIL undo same ($sv)"; lrfail=1; }
	fi
done
[ $lrfail -eq 0 ] && echo "PASS list records ($(echo $lrsaves | wc -w) saves)" || { echo "FAIL list records"; fail=1; }

# Sparse records and the SavedVariables performance cleanup (core uplift S3,
# 3.4.1.52, upgrade step 10): a 3.4.1.51 save with a rule over the 1500 cap,
# every kind of member record, players, custom chat filters with no id and
# history under their texts migrates in one login (cap, sparse records,
# switches, ids and their history), the next login changes nothing, the
# saved file is sparse; the Camelot name repair on a Camelot stub (and not on
# Retail); then every save the harness has (a new one, the 2.0 test saves,
# every real save) shows the same through the accessors as the previous
# build, in the migrating login and when the sparse file is read back, and
# the previous build and 3.4.0.29 read it without an error
echo "== sparse records"
lua5.1 "$here/run.lua" . - "$work/sp-base.lua" > /dev/null 2>&1
lua5.1 "$here/check_sparse.lua" --plant "$work/sp-base.lua" "$work/sp-plant.lua" > /dev/null || fail=1
lua5.1 "$here/check_sparse.lua" --plant "$work/sp-base.lua" "$work/sp-plant-unique.lua" unique > /dev/null || fail=1
lua5.1 "$here/run.lua" . "$work/sp-plant.lua" "$work/sp-1.lua" > "$work/sp-1.out" 2>&1
for ph in login again; do
	if [ $ph = login ]; then from="$work/sp-plant.lua"; else from="$work/sp-1.lua"; fi
	out=$(PSS_PHASE=$ph PSS_LOGIN_OUT="$work/sp-1.out" lua5.1 "$here/run.lua" . "$from" - "$here/check_sparse.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -E "PASS|FAIL"
	echo "$out" | grep -q "PASS sparse $ph" || fail=1
done
lua5.1 "$here/run.lua" . "$work/sp-1.lua" "$work/sp-2.lua" > "$work/sp-2.out" 2>&1
lua5.1 "$here/run.lua" . "$work/sp-2.lua" "$work/sp-3.lua" > "$work/sp-3.out" 2>&1
lua5.1 "$here/undo_check.lua" 1-to-2 "$work/sp-1.lua" "$work/sp-2.lua" || fail=1
lua5.1 "$here/undo_check.lua" same "$work/sp-2.lua" "$work/sp-3.lua" || fail=1
lua5.1 "$here/strip_undo.lua" "$work/sp-1.lua" "$work/sp-1s.lua"; lua5.1 "$here/strip_undo.lua" "$work/sp-2.lua" "$work/sp-2s.lua"
cmp -s "$work/sp-1s.lua" "$work/sp-2s.lua" && ! grep -q "Upgrading your saved data" "$work/sp-2.out" || { echo "FAIL sparse: a second login changed the save or reported"; fail=1; }
lua5.1 "$here/check_sparse.lua" --after "$work/sp-1.lua" ids || fail=1
lua5.1 tools/check_schema.lua --saves "$work/sp-1.lua" "$work/sp-2.lua" || fail=1
# Camelot
PSS_CAMELOT=1 PSS_PHASE=names PSS_NOTE="$work/cam-names.txt" lua5.1 "$here/run.lua" . - - "$here/check_sparse.lua" > /dev/null 2>&1
lua5.1 "$here/check_sparse.lua" --plant-camelot "$work/sp-base.lua" "$work/cam-names.txt" "$work/cam-plant.lua" > /dev/null || fail=1
ship=$(head -1 "$work/cam-names.txt")
PSS_CAMELOT=1 lua5.1 "$here/run.lua" . "$work/cam-plant.lua" "$work/cam-1.lua" > "$work/cam-1.out" 2>&1
out=$(PSS_SHIPPED="$ship" PSS_FIRST=1 PSS_LOGIN_OUT="$work/cam-1.out" PSS_CAMELOT=1 PSS_PHASE=camelot lua5.1 "$here/run.lua" . "$work/cam-plant.lua" - "$here/check_sparse.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "PASS|FAIL"
echo "$out" | grep -q "PASS sparse camelot" || fail=1
PSS_CAMELOT=1 lua5.1 "$here/run.lua" . "$work/cam-1.lua" "$work/cam-2.lua" > /dev/null 2>&1
PSS_CAMELOT=1 lua5.1 "$here/run.lua" . "$work/cam-2.lua" "$work/cam-3.lua" > /dev/null 2>&1
lua5.1 "$here/undo_check.lua" 1-to-2 "$work/cam-1.lua" "$work/cam-2.lua" || fail=1
lua5.1 "$here/undo_check.lua" same "$work/cam-2.lua" "$work/cam-3.lua" || fail=1
lua5.1 "$here/strip_undo.lua" "$work/cam-1.lua" "$work/cam-1s.lua"; lua5.1 "$here/strip_undo.lua" "$work/cam-2.lua" "$work/cam-2s.lua"
cmp -s "$work/cam-1s.lua" "$work/cam-2s.lua" || { echo "FAIL camelot: a second login changed the save"; fail=1; }
out=$(PSS_SHIPPED="$ship" PSS_CAMELOT=1 PSS_PHASE=camelot lua5.1 "$here/run.lua" . "$work/cam-1.lua" - "$here/check_sparse.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -q "PASS sparse camelot" || { echo "$out"; echo "FAIL camelot: the repaired save"; fail=1; }
out=$(PSS_PHASE=camelot lua5.1 "$here/run.lua" . "$work/cam-plant.lua" - "$here/check_sparse.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -q "PASS sparse camelot" || { echo "$out"; echo "FAIL camelot: a Retail save was repaired"; fail=1; }
# every save: the same through the accessors as another build (core uplift S3).
# Opt-in (PSS_SPARSE_AS=<git ref>, for a change to the saved layout): it asserts
# that nothing the addon shows changed, which a feature stage legitimately breaks.
sparse_ref=${PSS_SPARSE_AS:-}
if [ -z "$sparse_ref" ]; then
	echo "== sparse saves: not requested (PSS_SPARSE_AS=<ref> compares every save with that build)"
elif git rev-parse --verify -q "$sparse_ref" > /dev/null; then
	sparsesaves="- $work/sp-plant-unique.lua $work/cam-plant.lua"
	[ -n "$PSS_REAL_SAVES" ] && sparsesaves="$sparsesaves $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua' | sort)"
	for sv in "$work"/sv-*.lua; do
		case "$sv" in *-after.lua) ;; *) sparsesaves="$sparsesaves $sv" ;; esac
	done
	out=$(TMPDIR="$work" sh "$here/sparse_saves.sh" "$sparse_ref" $sparsesaves 2>&1)
	echo "$out" | grep -E "^PASS|^FAIL"
	echo "$out" | grep -q "^PASS sparse saves" || { echo "$out" | grep -v '^same' | head -20; fail=1; }
else
	echo "SKIPPED: sparse saves: $sparse_ref is not known here (git fetch origin main:refs/remotes/origin/main)"
	skipped="$skipped sparse-saves"
fi

# recent counts (3.2): session and last-24-hour counts per owner without
# Logging; a login or /reload starts a new session (3.2.0-dev006), which
# is not saved at logout
echo "== recent counts"
lua5.1 "$here/run.lua" . - "$work/rc-0.lua" > /dev/null 2>&1
rcT=$(lua5.1 -e "print(1790000000 + 24 * 3600 + 10 * 60 + 150 * 600)")
src=$work/rc-0.lua
for ph in 1 2 3; do
	env=""
	[ $ph = 2 ] && env="PSS_RELOAD=1"
	[ $ph != 1 ] && env="$env PSS_TIME=$rcT"
	out=$(env $env PSS_PHASE=$ph lua5.1 "$here/run.lua" . "$src" "$work/rc-$ph.lua" "$here/check_recent.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -q "PASS recent $ph" && echo "PASS recent $ph" || { echo "$out"; echo "FAIL recent $ph"; fail=1; }
	if grep -q '\["session' "$work/rc-$ph.lua"; then echo "FAIL recent $ph: the session was saved"; fail=1; fi
	src=$work/rc-$ph.lua
done

# saved data stays bounded (3.2): 30 days of blocks, rules added and removed
echo "== growth"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_growth.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -q "PASS growth" && echo "$out" | grep "^growth:" && echo "PASS growth" || { echo "$out"; echo "FAIL growth"; fail=1; }

# the right-click menu (B2): a PSS header, Block Player and Block Guild
echo "== unit menu"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_unitmenu.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS unitmenu" || fail=1

# core uplift F1 (3.4.1.42): expiry, option hooks, talent tag, Replace keeps
# the shipped rules, listener errors, the group warning, /pss list
echo "== fixes"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_fixes.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS fixes" || fail=1

# your own guild (3.2): a guild rule never blocks it, a player entry does
echo "== own guild"
out=$(lua5.1 "$here/run.lua" . - - "$here/check_ownguild.lua" 2>&1 | grep -v '^|cff')
echo "$out"
echo "$out" | grep -q "PASS own guild" || fail=1

# upgrade record (3.0): a 2.0 save gets step 1 once with one chat line, the
# next login prints nothing; a fresh save is stamped without a message
export PSS_COMPONENTS=none
echo "== upgrade record"
echo 'print("steps=" .. M.PSS_UPGRADE_STEPS)' > "$work/steps.lua"
steps=$(lua5.1 "$here/run.lua" . - - "$work/steps.lua" 2>&1 | sed -n 's/^steps=//p')
o1=$(lua5.1 "$here/run.lua" . "$work/sv-gr-2.0.44.lua" "$work/up-1.lua" 2>&1)
o2=$(lua5.1 "$here/run.lua" . "$work/up-1.lua" "$work/up-2.lua" 2>&1)
o3=$(lua5.1 "$here/run.lua" . - "$work/up-3.lua" 2>&1)
if echo "$o1" | grep -q "Saved data upgraded to .* (step $steps)" && ! echo "$o2$o3" | grep -q "Saved data upgraded" &&
	lua5.1 -e "for _, f in ipairs({ '$work/up-1.lua', '$work/up-2.lua', '$work/up-3.lua' }) do
		PourSocialScoreDB = nil; dofile(f); local u = PourSocialScoreDB.upgrade
		assert(type(u) == 'table' and u.step == $steps and type(u.version) == 'string' and type(u.at) == 'number', f)
	end"; then
	echo "PASS upgrade record (step $steps)"
else
	echo "FAIL upgrade record"; fail=1
fi

# upgrade step registry (core uplift U1, 3.4.1.45): its shape, the version
# order, counts per feature only on a login that reports, retired keys gone
echo "== upgrade steps"
for sv in - "$work/sv-gr-2.0.44.lua"; do
	out=$(lua5.1 "$here/run.lua" . "$sv" - "$here/check_upgrade_steps.lua" 2>&1 | grep -v '^|cff')
	echo "$out"
	echo "$out" | grep -q "PASS upgrade steps" || fail=1
done

# the upgrade report (core uplift U2, 3.4.1.46): 10 cases on a new save, then
# each first login's output (the 2.0.44 test save and every real save) has
# the report's shape and the save checks clean
echo "== upgrade report"
reportsaves="- $work/sv-gr-2.0.44.lua"
[ -n "$PSS_REAL_SAVES" ] && reportsaves="$reportsaves $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua')"
for sv in $reportsaves; do
	login=""
	same=""
	# a save this version wrote: its first login prints no report (case 3)
	[ "$sv" != "-" ] && grep -q "\"version\"\] = \"$(sed -n 's/^## Version: //p' PourSocialScore/PourSocialScore.toc | tr -d '\r')\"" "$sv" && same=1
	if [ "$sv" != "-" ]; then
		lua5.1 "$here/run.lua" . "$sv" "$work/ur-1.lua" > "$work/ur-1.out" 2>&1
		login="$work/ur-1.out"
	else
		lua5.1 "$here/run.lua" . - "$work/ur-1.lua" > /dev/null 2>&1
	fi
	out=$(PSS_LOGIN_SAME="$same" PSS_LOGIN_OUT="$login" lua5.1 "$here/run.lua" . "$work/ur-1.lua" - "$here/check_upgrade_report.lua" 2>&1 | grep -v '^|cff')
	echo "$out ($sv)"
	echo "$out" | grep -q "PASS upgrade report" || fail=1
done

# forward compatibility (core uplift U3, 3.4.1.47): a save from a newer
# version, then from an older one, keeps every field, rule and line it does
# not know; what this version cannot use is reported, not applied and
# exported; the 3.4.0.29 release imports the format 2 export; a newer block
# log and recent counts come back unchanged
echo "== forward compatibility"
for ver in 3.4.1.99 3.4.1.46; do
	out=$(PSS_PHASE=plant PSS_FW_VERSION=$ver lua5.1 "$here/run.lua" . - "$work/fw-0.lua" "$here/check_forward.lua" 2>&1 | grep -v '^|cff')
	lua5.1 "$here/run.lua" . "$work/fw-0.lua" "$work/fw-1.lua" > "$work/fw-1.out" 2>&1
	out="$out
$(PSS_PHASE=check PSS_LOGIN_OUT="$work/fw-1.out" PSS_FW_EXPORT="$work/fw-export.txt" lua5.1 "$here/run.lua" . "$work/fw-1.lua" "$work/fw-2-$ver.lua" "$here/check_forward.lua" 2>&1 | grep -v '^|cff')
$(lua5.1 "$here/check_forward.lua" "$work/fw-2-$ver.lua" 2>&1)"
	echo "$out" | grep -E "PASS|FAIL"
	for p in plant check after; do echo "$out" | grep -q "PASS forward $p" || fail=1; done
done
rm -rf "$work/src-3.4.0.29"; mkdir -p "$work/src-3.4.0.29"
git archive 149625b | tar -x -C "$work/src-3.4.0.29"
out=$(PSS_PHASE=oldimport PSS_FW_EXPORT="$work/fw-export.txt" lua5.1 "$here/run.lua" "$work/src-3.4.0.29" - - "$here/check_forward.lua" 2>&1 | grep -v '^|cff')
echo "$out" | grep -E "PASS|FAIL"
echo "$out" | grep -q "PASS forward oldimport" || fail=1
lua5.1 "$here/run.lua" . - "$work/nl-0.lua" > /dev/null 2>&1
cat >> "$work/nl-0.lua" <<'SV'
PSS_LoggingDB = PSS_LoggingDB or {}
PSS_LoggingDB.blockLog = { v = 3, newerGroup = { "x" } }
PSS_LoggingDB.blockKeep = { newerKeep = 1 }
PourSocialScoreDB.recent = { v = 3, newerSlots = { 1 } }
SV
out=$(PSS_PHASE=newerlog lua5.1 "$here/run.lua" . "$work/nl-0.lua" "$work/nl-1.lua" "$here/check_forward.lua" 2>&1 | grep -v '^|cff'
	lua5.1 "$here/check_forward.lua" log "$work/nl-1.lua" 2>&1)
echo "$out" | grep -E "PASS|FAIL"
echo "$out" | grep -q "PASS forward newerlog" && echo "$out" | grep -q "PASS forward afterlog" || fail=1

# /pss check (3.0): no problems on a fresh save and on every upgraded 2.0.44
# test save; planted faults are reported
echo "== saved data check"
for sv in - "$work/sv-2.0.44.lua" "$work/sv-2.0.44-overflow.lua" "$work/sv-gr-2.0.44.lua"; do
	out=$(lua5.1 "$here/run.lua" . "$sv" - "$here/check_validate.lua" 2>&1 | grep -v '^|cff')
	echo "$out" | grep -q "PASS validate" || { echo "$out"; echo "FAIL validate on $sv"; fail=1; }
done
[ $fail -eq 0 ] && echo "PASS saved data check"

# multi-addon harness (3.0): child addons, LoadOnDemand, several saved tables
echo "== multi-addon harness"
sh "$here/check_multi.sh" || fail=1

# real saves: load, log in twice, keep every rule, player and member, and
# the window's tabs on each (their numbers equal the core's counts)
if [ -n "$PSS_REAL_SAVES" ]; then
	for sv in $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua'); do
		echo "== real save $sv"
		lua5.1 "$here/run.lua" . "$sv" "$work/real-1.lua" "$here/check_real.lua" | grep -v '^|cff' || fail=1
		lua5.1 "$here/run.lua" . "$work/real-1.lua" "$work/real-2.lua" "$here/check_real.lua" | grep -v '^|cff' || fail=1
		lua5.1 "$here/check_real.lua" "$sv" "$work/real-2.lua" || fail=1
		lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_validate.lua" | grep -v '^|cff' || fail=1
		out=$(lua5.1 "$here/run.lua" . "$sv" - "$here/check_names.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | grep -E "names:|PASS|FAIL"
		echo "$out" | grep -q "PASS names" || fail=1
		out=$(lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_viewquery.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS viewquery" || fail=1
		out=$(lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_players.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS players" || fail=1
		out=$(lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_menus.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS menus" || fail=1
		out=$(lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_guilds.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS guilds" || fail=1
		out=$(lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_filters.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS filters" || fail=1
		out=$(PSS_COMPONENTS=addons,gfx lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_events.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS events" || fail=1
		out=$(PSS_COMPONENTS=addons,gfx lua5.1 "$here/run.lua" . "$work/real-2.lua" - "$here/check_options.lua" 2>&1 | grep -v '^|cff')
		echo "$out" | grep -E "PASS|FAIL"
		echo "$out" | grep -q "PASS options" || fail=1
		out=$(lua5.1 "$here/run.lua" . "$sv" - "$here/check_upgrade_steps.lua" 2>&1 | grep -v '^|cff')
		echo "$out"
		echo "$out" | grep -q "PASS upgrade steps" || fail=1
		lua5.1 tools/check_schema.lua --saves "$work/real-1.lua" "$work/real-2.lua" || fail=1
	done
fi

# the schema map (core uplift U3): every field of every save this run wrote
# is in PourSocialScore/PSS_Schema.lua (fields a check planted start with
# "newer")
echo "== schema"
lua5.1 tools/check_schema.lua --saves $(ls "$work"/*.lua | grep -v '/steps\.lua$') || fail=1

# saves byte-identical with another ref (PSS_SAME_AS=origin/main, for a
# stage that must not change the saved data; same_saves.sh)
if [ -n "$PSS_SAME_AS" ] && ! git rev-parse --verify -q "$PSS_SAME_AS" > /dev/null; then
	echo "SKIPPED: same saves: $PSS_SAME_AS is not known here (git fetch origin main:refs/remotes/origin/main)"
	skipped="$skipped same-saves"
elif [ -n "$PSS_SAME_AS" ]; then
	echo "== same saves as $PSS_SAME_AS"
	out=$(TMPDIR=${TMPDIR:-/tmp} sh "$here/same_saves.sh" "$PSS_SAME_AS" 2>&1)
	echo "$out" | grep -v '^same:'
	echo "$out" | grep -q "^PASS same saves" || fail=1
fi

if [ -n "$skipped" ] && [ "$PSS_ALLOW_SKIP" != 1 ]; then
	echo "Upgrade checks INCOMPLETE: skipped$skipped (set PSS_ALLOW_SKIP=1 to accept)"
	fail=1
fi
[ $fail -eq 0 ] && echo "All upgrade checks passed" || echo "Upgrade checks FAILED"
exit $fail
