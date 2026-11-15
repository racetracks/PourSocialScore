# Spec: specs/packaging.md#5-api-contract-toolspackagingfolderspy-new (TK-B-01)
import json
import os
import sys

MANIFEST = "tools/packaging/addons.json"
USAGE = "folders.py: usage: folders.py all|<id>|--field <id> <name>|--version <id>|--verify <id|all> <dir>"


def die(msg, code=2):
	sys.stderr.write(msg + "\n")
	sys.exit(code)


def load():
	try:
		with open(MANIFEST, encoding="utf-8") as f:
			return json.load(f)
	except (OSError, ValueError) as e:
		die("folders.py: cannot read %s: %s" % (MANIFEST, getattr(e, "strerror", None) or e))


def package(m, pid):
	for p in m["packages"]:
		if p["id"] == pid:
			return p
	die("folders.py: unknown package '%s'" % pid)


def names(m, pid):
	if pid == "all":
		return [f["folder"] for f in m["folders"]]
	package(m, pid)
	return [f["folder"] for f in m["folders"] if f["package"] == pid]


def main(a):
	if not a:
		die(USAGE)
	if a[0] == "--field" and len(a) == 3:
		m = load()
		p = package(m, a[1])
		if a[2] not in p:
			die("folders.py: unknown field '%s'" % a[2])
		v = p[a[2]]
		if a[2] == "copyIn":
			for c in v:
				print(c["src"], c["dest"])
		elif isinstance(v, bool):
			print("true" if v else "false")
		else:
			print(v)
	elif a[0] == "--version" and len(a) == 2:
		m = load()
		p = package(m, a[1])
		path = "%s/%s.toc" % (p["main"], p["main"])
		try:
			with open(path, encoding="utf-8") as f:
				for line in f:
					if line.startswith("## Version:"):
						print(line[len("## Version:"):].replace(" ", "").replace("\r", "").strip())
						return
		except OSError as e:
			die("folders.py: cannot read %s: %s" % (path, e.strerror or e))
		die("folders.py: %s has no ## Version" % path)
	elif a[0] == "--verify" and len(a) == 3:
		m = load()
		want = names(m, a[1])
		d = a[2]
		try:
			have = os.listdir(d)
		except OSError as e:
			die("folders.py: cannot read %s: %s" % (d, e.strerror or e))
		bad = []
		for n in sorted(have):
			if not os.path.isdir(os.path.join(d, n)) or n not in want:
				bad.append("%s: %s is not in package %s" % (d, n, a[1]))
		for n in want:
			if n not in have:
				bad.append("%s: %s of package %s is missing" % (d, n, a[1]))
		if bad:
			print("\n".join(bad))
			sys.exit(1)
	elif len(a) == 1 and not a[0].startswith("-"):
		m = load()
		for n in names(m, a[0]):
			print(n)
	else:
		die(USAGE)


main(sys.argv[1:])
