import json
import os
import subprocess
import sys
import tempfile

TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "versions.py")
TOOL = os.path.abspath(TOOL)


def run(vers, latest, cmds):
	d = tempfile.mkdtemp()
	data = {"latestRelease": "3.9.0.155", "preReleases": [], "releases": [],
		"packages": {"testkit": {"latest": latest, "versions": [{"version": v} for v in vers]}}}
	with open(os.path.join(d, "versions.json"), "w") as f:
		json.dump(data, f)
	out = []
	for c in cmds:
		r = subprocess.run([sys.executable, TOOL] + c, cwd=d, capture_output=True, text=True)
		out.append((r.stdout.strip(), r.returncode))
	return out


CASES = [
	("1", ["TK.1"], "TK.1", [["kind", "TK.1", "--package", "testkit"], ["check", "--package", "testkit", "--toc", "TK.1"]],
		[("release", 0), ("", 0)]),
	("2", ["TK.1"], "TK.1", [["kind", "TK.2", "--package", "testkit"], ["check", "--package", "testkit", "--toc", "TK.2"]],
		[("unknown", 0), None]),
	("3", ["TK.2", "TK.1"], "TK.1", [["check", "--package", "testkit", "--toc", "TK.1"]], [None]),
]

for name, vers, latest, cmds, exp in CASES:
	got = run(vers, latest, cmds)
	for g, e in zip(got, exp):
		if e is None:
			ok = g[1] == 1
		else:
			ok = g[1] == e[1] and (not e[0] or g[0] == e[0])
		if not ok:
			print("test_versions: %s failed" % name)
			sys.exit(1)
print("test_versions: ok")
