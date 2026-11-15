#!/usr/bin/env python3
"""Manifest guards G1-G8, G10 for tools/packaging/addons.json (G9 runs in CI: folders.py --verify)."""
import json
import os
import re
import sys

CORE = ["PourSocialScore", "PourSocialScore_Libraries", "PourSocialScore_GUI",
	"PourSocialScore_Options", "PourSocialScore_Logging", "PourSocialScore_Communities"]
HERE = os.path.dirname(os.path.abspath(__file__))
SELF_MARK = {
	"g1": "has a .toc and no entry", "g2": "has no ", "g3": "new addon folders start with PSS_",
	"g4": "addons.json: core.zipName", "g5": "is developer-only", "g6": "disagree on",
	"g8": "keep one folder entry per line", "g10": ": developer is ",
}


def toc_dev(root, f):
	p = os.path.join(root, f, f + ".toc")
	if not os.path.isfile(p):
		return False
	with open(p, encoding="utf-8") as fh:
		for ln in fh:
			if ln.strip() == "## X-PSS-Developer: 1":
				return True
	return False


def check(root, warn=None):
	out = []
	path = os.path.join(root, "tools", "packaging", "addons.json")
	try:
		with open(path, encoding="utf-8") as fh:
			text = fh.read()
		data = json.loads(text)
	except (OSError, ValueError) as e:
		return ["addons.json: unreadable: %s" % e]
	for i, ln in enumerate(text.split("\n"), 1):
		if '"folder":' in ln and not ('"package":' in ln and '"developer":' in ln and "}" in ln):
			out.append("addons.json:%d: keep one folder entry per line" % i)
	if data.get("format") != 1:
		out.append("addons.json: format: must be 1")
	pkgs = data.get("packages") or []
	folders = data.get("folders") or []
	ids = [p.get("id") for p in pkgs]
	if "core" not in ids:
		out.append("addons.json: packages: core must be present")
	byid = {}
	seen = {"id": set(), "targetRepo": set(), "secret": set(), "zipName": set()}
	for p in pkgs:
		i = p.get("id")
		pre = "addons.json: %s." % i
		byid[i] = p
		if not isinstance(i, str) or not re.match(r"^[a-z][a-z0-9]*$", i) or i == "all":
			out.append(pre + "id: must match ^[a-z][a-z0-9]*$ and not be all")
		for k in seen:
			v = p.get(k)
			if v in seen[k]:
				out.append(pre + "%s: must be unique" % k)
			seen[k].add(v)
		if not p.get("title"):
			out.append(pre + "title: must be non-empty")
		mine = [f.get("folder") for f in folders if f.get("package") == i]
		if p.get("main") not in mine:
			out.append(pre + "main: must be a folder of this package")
		if not re.match(r"^[^/\s]+/[^/\s]+$", str(p.get("targetRepo"))):
			out.append(pre + "targetRepo: must be owner/name")
		sec = str(p.get("secret"))
		if not (sec == "MIRROR_TOKEN" if i == "core" else re.match(r"^[A-Z0-9]+_MIRROR_TOKEN$", sec)):
			out.append(pre + "secret: must be MIRROR_TOKEN (core) or <NAME>_MIRROR_TOKEN")
		z = str(p.get("zipName"))
		if "{version}" not in z or not z.endswith(".zip"):
			out.append(pre + "zipName: must contain {version} and end .zip")
		if p.get("version") not in ("suite", "package"):
			out.append(pre + "version: must be suite or package")
		h = p.get("history")
		if not isinstance(h, str) or not os.path.isfile(os.path.join(root, h)):
			out.append(pre + "history: must be an existing repo path")
		for c in p.get("copyIn") or []:
			if not os.path.exists(os.path.join(root, str(c.get("src")))):
				out.append(pre + "copyIn.src: %s must exist" % c.get("src"))
			if c.get("dest") not in mine:
				out.append(pre + "copyIn.dest: must be a folder of this package")
		if p.get("sourceRelease", False) is not (i == "core"):
			out.append(pre + "sourceRelease: true only for core")
		if p.get("mirrorOn") not in ("latestRelease", "every"):
			out.append(pre + "mirrorOn: must be latestRelease or every")
		w = str(p.get("workflow"))
		if not (w.startswith(".github/workflows/") and w.endswith(".yml")):
			out.append(pre + "workflow: must be .github/workflows/<name>.yml")
		else:
			wp = os.path.join(root, w)
			if not os.path.isfile(wp):
				if isinstance(warn, list):
					warn.append("addons.json: %s.workflow %s not written yet (package not published)" % (i, w))
			else:
				with open(wp, encoding="utf-8") as fh:
					wt = fh.read()
				if ("package: %s" % i) not in wt or ("secrets.%s" % p.get("secret")) not in wt:
					out.append("%s: does not pass package %s with secrets.%s" % (w, i, p.get("secret")))
	counts = {}
	for f in folders:
		n = f.get("folder")
		counts[n] = counts.get(n, 0) + 1
	for d in sorted(os.listdir(root)):
		dp = os.path.join(root, d)
		if d.startswith(".") or not os.path.isdir(dp):
			continue
		if any(x.endswith(".toc") for x in os.listdir(dp)):
			n = counts.get(d, 0)
			if n == 0:
				out.append("addons.json: %s has a .toc and no entry" % d)
			elif n > 1:
				out.append("addons.json: %s has %d entries" % (d, n))
	for f in folders:
		n = f.get("folder")
		if not os.path.isfile(os.path.join(root, n, n + ".toc")):
			out.append("addons.json: %s has no %s.toc" % (n, n))
		if n not in CORE and not re.match(r"^PSS_[A-Z][A-Za-z0-9]*$", str(n)):
			out.append("addons.json: %s: new addon folders start with PSS_ (docs/pss/02_RULES.md)" % n)
		if f.get("package") not in byid:
			out.append("addons.json: %s.package: must be an existing package id" % n)
		if f.get("package") == "core" and f.get("developer"):
			out.append("addons.json: %s is developer-only and cannot ship in core" % n)
		dev = toc_dev(root, n)
		if bool(f.get("developer", False)) != dev:
			out.append("addons.json: %s: developer is %s but its .toc says %s" % (
				n, str(bool(f.get("developer", False))).lower(), str(dev).lower()))
	mf = set()
	try:
		with open(os.path.join(root, "tools", "toc", "manifest.txt"), encoding="utf-8") as fh:
			for ln in fh:
				if ln.startswith("folder "):
					mf.add(ln.split()[1])
	except OSError:
		out.append("addons.json and tools/toc/manifest.txt disagree on tools/toc/manifest.txt")
	for n in sorted(mf.symmetric_difference(set(counts))):
		out.append("addons.json and tools/toc/manifest.txt disagree on %s" % n)
	return out


def selftest():
	fx = os.path.join(HERE, "fixtures")
	out = []
	r = check(os.path.join(fx, "good"))
	if r:
		out.append("check_manifest --self: good: expected no output, got %s" % r[0])
	for g, mark in SELF_MARK.items():
		t = "bad-" + g
		d = os.path.join(fx, t)
		if not os.path.isdir(d):
			out.append("check_manifest --self: %s: fixture missing" % t)
		elif not any(mark in m for m in check(d)):
			out.append("check_manifest --self: %s: expected a message containing '%s'" % (t, mark))
	return out


def main(argv):
	if "--self" in argv:
		res = selftest()
	else:
		root = "."
		if "--root" in argv:
			root = argv[argv.index("--root") + 1]
		warn = []
		res = check(root, warn)
		for m in warn:
			print(m)
	for m in res:
		print(m)
	return 1 if res else 0


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
