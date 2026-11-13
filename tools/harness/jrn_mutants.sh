#!/bin/sh
# Mutation check of the Journal (build J1): every mutant of every tools/harness/jrn/*_mutants.lua (a list of
# { id, file, from, to, phases }) is applied to a copy of the addon; at least one area it names must fail
# (jrn_phases.sh), or this script fails. One line per mutant.
#   sh tools/harness/jrn_mutants.sh [id ...]
here=$(dirname "$0")
src=$(cd "$here/../.." && pwd)
tab=$(mktemp)
JRN_HERE="$here" lua5.1 -e 'local base = os.getenv("JRN_HERE")
	local function enc(s) return (s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t")) end
	local p = io.popen("ls \"" .. base .. "/jrn\" 2>/dev/null")
	for n in p:lines() do
		if n:match("_mutants%.lua$") then
			for _, m in ipairs(dofile(base .. "/jrn/" .. n)) do io.write(m[1], "\t", m[2], "\t", enc(m[3]), "\t", enc(m[4]), "\t", m[5], "\n") end
		end
	end' > "$tab"
want="$*"
killed=0; survived=0; invalid=0
while IFS="	" read -r id file from to phases; do
	from=$(printf '%b' "$from"); to=$(printf '%b' "$to")
	if [ -n "$want" ] && ! echo " $want " | grep -q " $id "; then continue; fi
	work=$(mktemp -d)
	(cd "$src" && tar cf - PourSocialScore PourSocialScore_Libraries PourSocialScore_Options PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Communities tools) | (cd "$work" && tar xf -)
	if ! lua5.1 "$here/wh_mutate.lua" "$work/$file" "$from" "$to" 2>"$work/err.txt"; then
		invalid=$((invalid + 1)); echo "INVALID $id: $(cat "$work/err.txt")"; rm -rf "$work"; continue
	fi
	out=$(cd "$work" && JRN_ONLY="$phases" sh tools/harness/jrn_phases.sh 2>&1)
	if echo "$out" | grep -q "^JRN [0-9]* phases, 0 failed"; then
		survived=$((survived + 1)); echo "SURVIVED $id"
	else
		killed=$((killed + 1)); echo "KILLED $id"
	fi
	rm -rf "$work"
done < "$tab"
rm -f "$tab"
echo "killed $killed of $((killed + survived + invalid)) ($survived survived, $invalid invalid)"
[ $survived -eq 0 ] && [ $invalid -eq 0 ]
