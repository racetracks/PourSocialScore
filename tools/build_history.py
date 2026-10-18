#!/usr/bin/env python3
# The build history (DEC-00341): docs/pss/14_BUILD_HISTORY.md holds what
# each build changed and why, its PR, tests and in-game checks; the "Now"
# section of docs/pss/06_STATUS_AND_NEXT.md holds only the current build.
# bump_version.sh calls it, so neither file is kept by hand.
#   python3 tools/build_history.py roll <version> "<title>" <branch>
#       moves every build entry of 06 "Now" (a bullet that opens with
#       "- **X.Y.Z.B") to the top of the history, unchanged, then writes a
#       stub for the new build in both files
#   python3 tools/build_history.py pr <number>
#       writes the PR into the stubs that have none
#   python3 tools/build_history.py check
#       fails when 06 "Now" holds more than one build entry, or when a
#       version recorded in versions.json from 3.8.0.119 on has no
#       "### <version>" entry in the history
import json, re, sys

STATUS = "docs/pss/06_STATUS_AND_NEXT.md"
HIST = "docs/pss/14_BUILD_HISTORY.md"
FIRST = (3, 8, 0, 119)
BUILD = re.compile(r"^- \*\*(\d+\.\d+\.\d+\.\d+)\b")
NOPR = "PR: none yet"
TOP = "<!-- builds: newest first; tools/build_history.py roll writes here -->"


def fail(msg):
	print("build history: " + msg)
	sys.exit(1)


def read(p):
	with open(p, encoding="utf-8") as f:
		return f.read().split("\n")


def write(p, lines):
	with open(p, "w", encoding="utf-8") as f:
		f.write("\n".join(lines))


def now_range(lines):
	try:
		a = lines.index("## Now") + 1
	except ValueError:
		fail(STATUS + " has no '## Now' section")
	b = a
	while b < len(lines) and not lines[b].startswith("## "):
		b += 1
	return a, b


def cmd_roll(args):
	if len(args) < 3:
		fail("usage: roll <version> \"<title>\" <branch>")
	ver, title, branch = args[0], args[1], args[2]
	st = read(STATUS)
	hi = read(HIST)
	if TOP not in hi:
		fail(HIST + " has no builds marker")
	a, b = now_range(st)
	moved = []
	keep = []
	for line in st[a:b]:
		m = BUILD.match(line)
		if m:
			moved.append("### " + m.group(1) + " (from 06 Now)")
			moved.append("")
			moved.append(line[2:])
			moved.append("")
		else:
			keep.append(line)
	stub06 = "- **%s, %s (branch `%s`, %s):** what changed, in one line; the details are in the build history (`%s`)." % (ver, title, branch, NOPR, HIST)
	st = st[:a] + [stub06] + keep + st[b:]
	stub = [
		"### " + ver + " - " + title,
		"",
		"- Branch: `" + branch + "`; " + NOPR + ".",
		"- What changed and why: (written in the PR)",
		"- Docs updated: (written in the PR)",
		"- Tests run: (written in the PR)",
		"- Not shown by the simulation: (written in the PR)",
		"- In-game checks: (written in the PR)",
		"",
	]
	i = hi.index(TOP) + 1
	rest = hi[i:]
	while rest and rest[0] == "":
		rest.pop(0)
	body = stub + moved
	while body and body[-1] == "":
		body.pop()
	hi = hi[:i] + [""] + body + [""] + rest
	write(STATUS, st)
	write(HIST, hi)
	print("build history: %s added; %d entr%s moved from 06" % (ver, len(moved) // 4, "y" if len(moved) == 4 else "ies"))


def cmd_pr(args):
	n = args[0]
	url = "https://github.com/racetracks/PourSocialScore/pull/" + n
	for p, rep in ((STATUS, "PR #" + n), (HIST, "[PR #" + n + "](" + url + ")")):
		s = "\n".join(read(p))
		if NOPR in s:
			write(p, s.replace(NOPR, rep).split("\n"))


def versions():
	with open("versions.json", encoding="utf-8") as f:
		d = json.load(f)
	out = [e["version"] for e in d.get("preReleases", [])]
	for r in d.get("releases", []):
		out.append(r["version"])
		out += [e["version"] for e in r.get("preReleases", [])]
	return out


def key(v):
	# older names (-devNNN, _N, plain 3.3.1) are before FIRST and never checked
	if not re.match(r"^\d+\.\d+\.\d+\.\d+$", v):
		return (0,)
	return tuple(int(x) for x in v.split("."))


def cmd_check(args):
	bad = 0
	st = read(STATUS)
	a, b = now_range(st)
	n = sum(1 for line in st[a:b] if BUILD.match(line))
	if n > 1:
		print("build history: 06 'Now' holds %d build entries; only the current build stays there (bump_version.sh moves the rest)" % n)
		bad += 1
	hi = "\n".join(read(HIST))
	for v in versions():
		if key(v) >= FIRST and not re.search(r"^### " + re.escape(v) + r"\b", hi, re.M):
			print("build history: " + v + " has no entry in " + HIST)
			bad += 1
	if bad:
		sys.exit(1)


if __name__ == "__main__":
	cmds = {"roll": cmd_roll, "pr": cmd_pr, "check": cmd_check}
	if len(sys.argv) < 2 or sys.argv[1] not in cmds:
		fail("usage: roll|pr|check")
	cmds[sys.argv[1]](sys.argv[2:])
