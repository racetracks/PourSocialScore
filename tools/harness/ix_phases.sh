#!/bin/sh
# The Spyglass engine (search-helper, phase A; check_ix.lua), on Retail and on Camelot. Run from the repo
# root (validate_all.sh and CI call it); exit 1 when any phase fails. Each phase starts from a save made by
# one login with the same components (so Logging is not loaded at login, as in the game). With
# PSS_REAL_SAVES (build_saves.sh's out dir) the real-save phases also run on every save.
#   sh tools/harness/ix_phases.sh [phase ...]
#   IX_ONLY="a b" limits the run (ix_mutants.sh); PSS_SOAK sets the soak size (default 100000)
here=$(dirname "$0")
work=${TMPDIR:-/tmp}/pss-ix.$$
mkdir -p "$work"
export TZ=UTC
fail=0; n=0; bad=0

# phase -> components (default: logging); the warehouse phases start from the seeded test world
comps() {
	case "$1" in
	putoff|logoff) echo "-logging" ;;
	socialoff) echo "logging,-filtering" ;;
	whoff) echo "logging" ;;
	invst|invrows|invderive|invpush|invsum|invval|invempty|invorphan|invnewrow|invsecret|termsame|termunknown|termpending|termreal|parseexamples|parsetokens|parsetokenkinds|parsefuzz|budgetcalls) echo "logging,warehouse,dtt" ;;
	cfgnewer) echo "logging,addons" ;;
	*) echo "logging" ;;
	esac
}
seed() { case "$1" in logging,warehouse,dtt) echo 1 ;; *) echo 0 ;; esac; }

ALL="ixdecl ixbad ixdup ixoff ixraise ixlist
lineround linebytes linetrail linecut lineunknown linenegative linetype linefuzz
segappend segmonth segtrim segskip seghash segnewer segzero segreload segcost segfuzz segsoak
putorder putsecret putoff putcap putearly putsignal putact putcost putreal putsoak
dictjoin dictasync dictmissing dictreal
timeparse timemonth timebad timebucket timesession timefmt
predops predlike timelike timelike2 likeword predbool predpush predvirtual predtype predlegacy predempty
statsfns statsby statscap timechartfill timechartby topn dedup calcdiv0 statsempty statsnil statscost statsproperty
termsame termunknown termpending termreal
parseexamples parsebad parselimits parseinject parsechart parsetime parsetokens parsenoload parsefuzz parsetokenkinds
plantier planload planbudget plancache planmulti planoffmulti planpicker planreal planchaos
logrows logorder logpush countsequal logsecret logoff logcost
invst invrows invderive invpush invsum invval whoff invempty invorphan invnewrow invsecret
socialrows socialfields membersneed socialoff
cfgrows cfgreadonly cfgnewer cfgsystem
pssproduce pssonce psshot psscap pssnolog
sqsystem sqput sqcaps sqbroken sqcorrupt sqbind sqbuttons sqgolden sqfuzz sqdowngrade
alerton alertfire alertrate alertoff alertblock alerttimers
qcmd qpipe csvquote pssio pssiobad reader
covpass covfail covlist
budgetfiles budgetcalls budgetcore budgetci
dictrows dictdrift dictextend dictunknownattr dictgen
fsall fsunknown fscap fsempty valuescache
lazyitem lazyprefix lazyambig lazyplayer lazyoff lazypending lazysummary lazycost"
REAL="putreal dictreal planreal logrows countsequal socialrows cfgrows sqsystem sqgolden reader"

want="$*"
[ -n "$IX_ONLY" ] && want="$IX_ONLY"
[ -z "$want" ] && want=$(echo $ALL)

prime() {	# $1 components, $2 camelot flag, $3 seed -> a save after one login
	key=$(echo "$1-$2-$3" | tr ',' '_')
	if [ ! -f "$work/prime-$key.lua" ]; then
		env PSS_COMPONENTS="$1" ${2:+PSS_CAMELOT=1} PSS_WH_SEED="$3" lua5.1 "$here/run.lua" . - "$work/prime-$key.lua" > /dev/null 2>&1
	fi
	echo "$work/prime-$key.lua"
}

result() {	# $1 label, $2 output
	n=$((n + 1))
	if echo "$2" | grep -q "^PASS ix" && ! echo "$2" | grep -q "FAIL"; then
		echo "$2" | grep "^NOTE" | sed "s/^/  /"
		echo "PASS ix $1"
	else
		bad=$((bad + 1)); fail=1
		echo "$2" | grep -v "^PASS" | head -6
		echo "$2" | grep -q "FAIL" || echo "FAIL ix: $1: no PASS line"
	fi
}

run1() {	# $1 phase, $2 camelot, [$3 save in], [$4 save out]
	c=$(comps "$1"); s=$(seed "$c")
	src=${3:-$(prime "$c" "$2" "$s")}
	env PSS_PHASE="$1" PSS_COMPONENTS="$c" ${2:+PSS_CAMELOT=1} PSS_WH_SEED="$s" ${5:+$5} lua5.1 "$here/run.lua" . "$src" "${4:--}" "$here/check_ix.lua" 2>&1 | grep -v '^|cff'
}

for ph in $want; do
	for cam in "" 1; do
		label="$ph${cam:+ (Camelot)}"
		case "$ph" in
		psshot)
			out=$(run1 psshot "$cam" "" "$work/hot-$cam.lua")
			out2=$(env PSS_PHASE=psshot2 PSS_COMPONENTS=logging ${cam:+PSS_CAMELOT=1} lua5.1 "$here/run.lua" . "$work/hot-$cam.lua" - "$here/check_ix.lua" 2>&1 | grep -v '^|cff')
			result "$label" "$out
$out2" ;;
		sqdowngrade)
			out=$(run1 sqdowngrade "$cam" "" "$work/down-$cam.lua")
			ref=${PSS_SAME_AS:-origin/main}
			if [ ! -d "$work/ref" ]; then
				mkdir -p "$work/ref"
				# a shallow CI checkout has no origin/main: fetch it once (a SKIP is not a pass)
				git rev-parse -q --verify "$ref^{commit}" > /dev/null 2>&1 || { git fetch -q --depth=1 origin "${ref#origin/}" 2>/dev/null && ref=FETCH_HEAD; }
				git archive "$ref" 2>/dev/null | tar -x -C "$work/ref" 2>/dev/null
			fi
			if [ -f "$work/ref/PourSocialScore/PourSocialScore.toc" ]; then
				env PSS_COMPONENTS=logging ${cam:+PSS_CAMELOT=1} lua5.1 "$here/run.lua" "$work/ref" "$work/down-$cam.lua" "$work/down2-$cam.lua" > /dev/null 2>&1
				cmp=$(lua5.1 -e '
					local function load(p) local e = {} local f = assert(loadfile(p)) setfenv(f, e) f() return e end
					local a, b = load(arg[1]), load(arg[2])
					local function s(v) return H and "" or (v == nil and "nil" or tostring(v)) end
					local ser = dofile(arg[3] .. "/wow_stub.lua").serialize
					local ok = ser(a.PSS_OptionsDB and a.PSS_OptionsDB.sqSaved) == ser(b.PSS_OptionsDB and b.PSS_OptionsDB.sqSaved)
						and ser(a.PSS_LoggingDB and a.PSS_LoggingDB.pss) == ser(b.PSS_LoggingDB and b.PSS_LoggingDB.pss)
						and ser(a.PourSocialScoreDB and a.PourSocialScoreDB.pssHot) == ser(b.PourSocialScoreDB and b.PourSocialScoreDB.pssHot)
					print(ok and "DOWNGRADE same" or "FAIL ix: sqdowngrade: a key changed under " .. arg[4])' "$work/down-$cam.lua" "$work/down2-$cam.lua" "$here" "$ref" 2>&1)
				out="$out
$cmp"
			else
				out="$out
NOTE ix sqdowngrade: $ref could not be read (a SKIP is not a pass)
FAIL ix: sqdowngrade: no reference tree"
			fi
			result "$label" "$out" ;;
		reader)
			out=$(run1 sqput "$cam" "" "$work/reader-$cam.lua")
			out=$(run1 reader "$cam" "$work/reader-$cam.lua" "" "PSS_READER_SAVE=$work/reader-$cam.lua")
			result "$label" "$out" ;;
		covpass|covfail|covlist)
			if [ -n "$cam" ]; then continue; fi
			rm -rf "$work/cov"; mkdir -p "$work/cov"
			tar cf - PourSocialScore PourSocialScore_Libraries PourSocialScore_Options PourSocialScore_GUI PourSocialScore_Logging PourSocialScore_Communities tools | (cd "$work/cov" && tar xf -)
			case "$ph" in
			covpass) out=$(cd "$work/cov" && lua5.1 tools/check_indexes.lua 2>&1); want0=0 ;;
			covfail) sed -i 's/core = "upgrade outbox/core = "upgrade plantedKey outbox/' "$work/cov/PourSocialScore/PSS_Schema.lua"
				out=$(cd "$work/cov" && lua5.1 tools/check_indexes.lua 2>&1); want0=1 ;;
			covlist) sed -i 's/^local NOT_INDEXED = {$/local NOT_INDEXED = {\n\t["core.planted"] = "planted",/' "$work/cov/tools/check_indexes.lua"
				out=$(cd "$work/cov" && lua5.1 tools/check_indexes.lua 2>&1); want0=1 ;;
			esac
			code=0; echo "$out" | grep -q "^PASS indexes" || code=1
			if [ "$code" = "$want0" ] && { [ "$ph" != covfail ] || echo "$out" | grep -q "plantedKey"; }; then result "$label" "PASS ix $ph"
			else result "$label" "FAIL ix: $ph: $(echo "$out" | head -3)"; fi ;;
		*)
			out=$(run1 "$ph" "$cam")
			result "$label" "$out" ;;
		esac
	done
	if [ -n "$PSS_REAL_SAVES" ] && echo " $REAL " | grep -q " $ph "; then
		for sv in $(find -L "$PSS_REAL_SAVES/" -name 'PourSocialScore.lua' | sort); do
			v=$(basename "$(dirname "$sv")")
			if [ "$ph" = reader ]; then
				# the reader reads what this version saves (loading Logging trims an old log to its cap first)
				env PSS_PHASE=loadlog PSS_COMPONENTS=logging lua5.1 "$here/run.lua" . "$sv" "$work/rd.lua" "$here/check_ix.lua" > /dev/null 2>&1
				out=$(env PSS_PHASE=reader PSS_COMPONENTS=logging PSS_READER_SAVE="$work/rd.lua" lua5.1 "$here/run.lua" . "$work/rd.lua" - "$here/check_ix.lua" 2>&1 | grep -v '^|cff')
			else
				mkdir -p "$work/golden"
				out=$(env PSS_PHASE="$ph" PSS_COMPONENTS=logging,warehouse PSS_GOLDEN="${PSS_GOLDEN_DIR:-$work/golden}/$v.txt" lua5.1 "$here/run.lua" . "$sv" - "$here/check_ix.lua" 2>&1 | grep -v '^|cff')
			fi
			result "$ph (real $v)" "$out"
		done
	fi
done
rm -rf "$work"
echo "IX $n phases, $bad failed"
exit $fail
