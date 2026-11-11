#!/bin/sh
# Job summary of one real-saves shard from its validate_all.sh log(s).
#   sh tools/harness/fail_summary.sh <k> <log>...
# stdout: "### Real saves shard <k>: <p> PASS, <f> FAIL", then per
# <client>/<version> a #### heading, a | save | kind | count | table and the
# first 5 FAIL lines of each kind. stderr: one
# ::error title=real-saves::<client>/<version> <kind> <count> line per group and kind.
# A FAIL line belongs to the save of the nearest line (itself or before) holding
# /<client>/<version>/<save>/PourSocialScore.lua; earlier ones to group synthetic.
# The kind is the text after "FAIL " up to the first ":". Always exits 0.
k=${1:-0}; [ $# -gt 0 ] && shift
tab=$(printf '\t')
awk '
function key(line,   m, p, n) {
	if (!match(line, /\/[^\/ \t:]+\/[^\/ \t:]+\/[^\/ \t:]+\/PourSocialScore\.lua/)) return 0
	m = substr(line, RSTART + 1, RLENGTH - 1); n = split(m, p, "/")
	grp = "1" p[1] "/" p[2]; sv = p[3]; return 1
}
BEGIN { grp = "0synthetic"; sv = "-" }
FNR == 1 { grp = "0synthetic"; sv = "-" }
{ key($0) }
/^PASS/ { pass++ }
/^FAIL / {
	fail++; kd = substr($0, 6); c = index(kd, ":"); if (c) kd = substr(kd, 1, c - 1)
	gsub(/\t/, " ", kd); print grp "\t" sv "\t" kd "\t" $0 > "/dev/stdout"
}
END { print "#\t" pass + 0 "\t" fail + 0 > "/dev/stderr" }
' "$@" 2> "${TMPDIR:-/tmp}/fail_summary.$$" | sort -t "$tab" -k1,1 -k2,2 -k3,3 -s > "${TMPDIR:-/tmp}/fail_summary.$$.f"
set -- $(awk -F "$tab" '$1 == "#" { print $2, $3 }' "${TMPDIR:-/tmp}/fail_summary.$$")
echo "### Real saves shard $k: ${1:-0} PASS, ${2:-0} FAIL"
awk -F "$tab" '
function flush(   i, j) {
	if (g == "") return
	print ""; print "#### " substr(g, 2); print ""; print "| save | kind | count |"; print "| --- | --- | --- |"
	for (i = 1; i <= nr; i++) print "| " rs[i] " | " rk[i] " | " rc[i] " |"
	for (i = 1; i <= nk; i++) {
		print "::error title=real-saves::" substr(g, 2) " " kn[i] " " kc[kn[i]] > "/dev/stderr"
		print ""; print "`" kn[i] "`:"; print "```"
		for (j = 1; j <= ks[kn[i]] && j <= 5; j++) print kl[kn[i], j]
		print "```"
	}
	nr = 0; nk = 0; split("", kc); split("", ks); split("", kl)
}
$1 != g { flush(); g = $1 }
{
	if (nr == 0 || rs[nr] != $2 || rk[nr] != $3) { nr++; rs[nr] = $2; rk[nr] = $3; rc[nr] = 0 }
	rc[nr]++
	if (!($3 in kc)) { nk++; kn[nk] = $3; kc[$3] = 0; ks[$3] = 0 }
	kc[$3]++; ks[$3]++; kl[$3, ks[$3]] = $4
}
END { flush() }
' "${TMPDIR:-/tmp}/fail_summary.$$.f"
rm -f "${TMPDIR:-/tmp}/fail_summary.$$" "${TMPDIR:-/tmp}/fail_summary.$$.f"
exit 0
