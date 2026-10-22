#!/bin/sh
# Mutation check of the Spyglass console (search-helper phase B, TST-00932 to TST-00937, TST-00967, 3.8.0.127 fix mutants). Same runner
# as ix_mutants.sh; each row of MUTANTS is: name|file|sed expression|phases. One sed edit per mutant produces
# its named fault; at least one phase it names must fail (console_phases.sh), or this script fails.
# A sed that changes nothing is INVALID and counts as not killed.
#   sh tools/harness/console_mutants.sh [name ...]
here=$(dirname "$0")
src=$(cd "$here/../.." && pwd)
MUTANTS='fields-cap-8|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/^local FIELDS_CAP = 30$/local FIELDS_CAP = 8/|fieldspanel
side-no-skip|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if any and not one then out/if true then out/|sidebarux
chart-alloc-each|PourSocialScore_GUI/PSS_Chart.lua|s/if not o then o = MAKE\[name\](f); p\[c\] = o end/o = MAKE[name](f); p[c] = o/|chartpool
chart-cap-off|PourSocialScore_GUI/PSS_Chart.lua|s/^\tlocal cap = CAP_BARS$/\tlocal cap = 100000/|chartcaps
chart-colour-alpha|PourSocialScore_GUI/PSS_Chart.lua|s/fs:SetTextColor(1, 1, 1, 1)/fs:SetTextColor(1, 1, 1, 0.5)/|chartalpha
chart-onupdate|PourSocialScore_GUI/PSS_Chart.lua|s/b.tex:SetAllPoints(b)/b.tex:SetAllPoints(b); b:SetScript("OnUpdate", function() end)/|charthover
qv-run-tier1|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/self.loaded = self.loaded or load == true/self.loaded = true/|qvtier
qv-listen-hidden|PourSocialScore_GUI/PSS_Skin.lua|s/if listening then l.id = M.Events.Register/if true then l.id = M.Events.Register/|qvlisten
qv-redraw-each|PourSocialScore_GUI/PSS_QueryView.lua|s/M.PSS_Throttle(function() if v:IsVisible() then v:Refresh() end end)/(function() if v:IsVisible() then v:Refresh() end end)/|qvburst
con-build-early|PourSocialScore_GUI/PSS_Window.lua|s/^local function SelectTab(id)$/local function SelectTab(id)\n\tfor i = 1, #TABS do BuildTab(i) end/|contab
con-sidebar-own-count|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/{ field = col, n = 5 }/{ field = col, n = 4 }/|considebar
con-chart-ignored|PourSocialScore_GUI/PSS_Console.lua|s/if vm.plan and vm.plan.chart and chartOn then/if false and chartOn then/|conchart
save-no-confirm|PourSocialScore_GUI/PSS_QueryDialog.lua|s/m:Button("Delete", function()/m:Button("Delete", function() M.PSS_ConsoleView.call("sq.del", { id = id }) pg.refreshLeft() if true then return end/|saveround
save-cap-off|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/q.n >= (caps.records or 200)/q.n >= 1e9/|savecaps
save-broken-runs|PourSocialScore_GUI/PSS_QueryDialog.lua|s/if not d.broken then pg.run(true) end/pg.run(true)/|savebroken
button-literal-query|PourSocialScore_GUI/PSS_Players.lua|s/ns.DeepDive("player.events"/ns.DeepDive(("player.events")/|buttonregistry
pane-own-scan|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/owner=\$owner | sort -time | head 200/owner=$owner | sort -time | head 5/|panehistory
events-tab-kept|PourSocialScore_Libraries/PSS_ManagerNav.lua|/events = { tab = "console" },/d|eventstab
deep-no-back|PourSocialScore_GUI/PSS_Window.lua|s/if from == nil and win and win:IsShown() and TABS\[curTab\] then/if false then/|deepback
deep-no-load|PourSocialScore_GUI/PSS_Console.lua|/function pg.deepDive/,/^\tend/s/qv:Run(true)/qv:Run(false)/|deepearly
deep-from-service|tools/check_layers.lua|s/and not okFile then/and not okFile and false then/|deepservice
pick-edits-text|PourSocialScore_GUI/PSS_TimePicker.lua|s/function p:Range() return CV.pickerRange(choice) end/function p:Range() return nil end/|pickaxis picktyped pickrange
pick-wins-typed|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if range and CV.typedTime(self.query) then range = nil end/if false then range = nil end/|picktyped
pick-month-30d|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/text = "This month", e = "@mon"/text = "This month", e = "-30d"/|pickpresets
con-copy-raw|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if M.PSS_IsSecret(v) then/if false then/|concopysecret
con-rows-hook-once|PourSocialScore_GUI/PSS_Console.lua|s/list.Layout = function(self, ...) local r = layout(self, ...); HookRows(); return r end/list.Layout = layout/|conrowhook
save-chart-lost|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if not cs then return id, nil, cerr or "chart not saved" end/if not cs then return id end/|savepartial
con-bar-raw|PourSocialScore_GUI/PSS_Console.lua|s/return CV.unpipe(bar:GetText() or "")/return (bar:GetText() or "")/|conpipe
nav-no-clip|PourSocialScore_GUI/PSS_Nav.lua|s/nav:SetClipsChildren(true)/nav:SetClipsChildren(false)/|connavclip
deep-all-unbound|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/M.PSS_BUTTON_QUERIES\[tostring(evKind) .. ".all"\]/M.PSS_BUTTON_QUERIES[tostring(evKind) .. ".none"]/|conslice
con-size-fallback|PourSocialScore_GUI/PSS_Console.lua|s/PW = ns.PAGE_W or 780 end/PW = 780 end/|consize
con-pick-unbound|PourSocialScore_GUI/PSS_Console.lua|s/local text, missing = M.PSS_ResolveQuery(d.query, Ctx())/local text, missing = d.query/|consysq
con-quote-number|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if type(v) == "number" then return tostring(v) end/if false then return tostring(v) end/|consysq
con-run-invalid|PourSocialScore_GUI/PSS_Console.lua|s/if not r then Unbound(missing); return end/text = r or text/;s/^\t\tif err then return end$/\t\t_ = err/|consysq
cell-nil|PourSocialScore_Libraries/PSS_Bus.lua|s/if M.PSS_IsSecret(v) or v == nil then return "" end/if false then return "" end/|concell
con-cap-note|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/s = s .. ", history holds the newest " .. H.Cap() .. " lines"/s = s/|concap
qv-no-resize-chart|PourSocialScore_GUI/PSS_QueryView.lua|/v.chart:Resize(w, h - 40 - top)/d|qvresize
pane-fixed-width|PourSocialScore_GUI/PSS_History.lua|s/from = opts.from, fill = true, detail = true })/from = opts.from, fill = false, detail = true })/|panefit
con-runs-default|PourSocialScore_GUI/PSS_Console.lua|/^\t\tif text == "" then qv.status:SetText(M.PSS_CON_BLANK); return end$/d|conblank
show-no-year|PourSocialScore_Libraries/PSS_Bus.lua|s/^M.PSS_TIME_SHOW = "%d %b %Y %H:%M"/M.PSS_TIME_SHOW = "%d %b %H:%M"/|timeshow
col-no-need|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/math.ceil(need\[i\]) + PADX/COL_MIN/|colfit
col-no-cap|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/^local COL_MIN, COL_MAX, FILL_MIN, PADX = 36, 200,/local COL_MIN, COL_MAX, FILL_MIN, PADX = 36, 2000,/|colfit
fill-time|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if cols\[i\] ~= "time" and cols\[i\] ~= "ts" and nd(i) >= best/if nd(i) >= best/|colfit
label-raw|PourSocialScore_GUI/PSS_Chart.lua|s/text = M.PSS_FieldLabel(cols\[i\]), tip = cols\[i\], width/text = cols[i], tip = cols[i], width/|reportgrid
profile-off|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/^\tlocal want = type(profile) == "string" and M.PSS_REPORT_COLS\[profile\]$/\tlocal want = nil/|reportcols reportgrid
bound-shown|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if not blank and not (bound and (name == "owner" or same)) then/if not blank then/|reportcols
fill-share-off|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/^local FILL_SHARE = 0.4$/local FILL_SHARE = 0/|keepfit
keep-ignored|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/return i ~= fill and not keep\[i\]/return i ~= fill/|keepfit
summary-raw|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/^\tif type(text) ~= "string" or text == "" then return "Custom search" end$/\tif type(text) == "string" then return text end/|summary
chart-track-late|PourSocialScore_GUI/PSS_Chart.lua|0,/^\t\tf.lists\[sig\] = t$/{/^\t\tf.lists\[sig\] = t$/d}|paneerror
chart-no-pcall|PourSocialScore_GUI/PSS_Chart.lua|s/pcall(DRAW\[spec.kind\], f, set, spec)/true, DRAW[spec.kind](f, set, spec)/|paneerror
report-bar-shown|PourSocialScore_GUI/PSS_Console.lua|s/bar:SetShown(true); run_b/bar:SetShown(false); run_b/|reportmode
side-open-default|PourSocialScore_GUI/PSS_Console.lua|s/pg.leftOpen, pg.sideOpen = true, false/pg.leftOpen, pg.sideOpen = true, true/|conlayout
relayout-no-resize|PourSocialScore_GUI/PSS_Console.lua|/^\t\tqv:Resize(w, resH)$/d|conlayout
status-ms|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/local s = n == 1 and "1 line" or format("%d lines", n)/local s = format("%d rows, 0.00 ms", n)/|status
detail-any-button|PourSocialScore_GUI/PSS_QueryView.lua|s/if button ~= "LeftButton" or not self.index/if false or not self.index/|rowdetail
detail-secret-shown|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/if v ~= nil and not M.PSS_IsSecret(v) then text = M.PSS_CellText(col, v, kinds\[col\]) or "" end/if v ~= nil then text = tostring(v) end/|rowdetail
detail-raw-label|PourSocialScore_Libraries/PSS_ConsoleView.lua|s/out\[k\] = { field = M.PSS_FieldLabel(col), value = text }/out[k] = { field = col, value = text }/|rowdetail
chip-in-header|PourSocialScore_GUI/PSS_Console.lua|s/chip:SetPoint("TOPRIGHT", picker, "BOTTOMRIGHT", 0, -6)/chip:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)/|reportchip'
want="$*"
total=0; killed=0
nl='
'
IFS=$nl
for row in $MUTANTS; do
	IFS=' '
	name=${row%%|*}; rest=${row#*|}; file=${rest%%|*}; rest=${rest#*|}; phase=${rest##*|}; expr=${rest%|*}
	IFS=$nl
	if [ -n "$want" ] && ! echo " $want " | grep -q " $name "; then continue; fi
	total=$((total + 1))
	work=$(mktemp -d)
	(cd "$src" && tar cf - PourSocialScore PourSocialScore_Libraries PourSocialScore_Options PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Communities tools) | (cd "$work" && tar xf -)
	cp "$work/$file" "$work/before.txt"
	sed -i "$expr" "$work/$file"
	if cmp -s "$work/before.txt" "$work/$file"; then
		echo "INVALID $name: the edit changed nothing"
	elif (cd "$work" && sh tools/harness/console_phases.sh $phase > /dev/null 2>&1 < /dev/null); then
		echo "SURVIVED $name"
	else
		killed=$((killed + 1)); echo "KILLED $name"
	fi
	rm -rf "$work"
done
echo "MUTANTS $killed of $total killed"
[ "$killed" -eq "$total" ]
