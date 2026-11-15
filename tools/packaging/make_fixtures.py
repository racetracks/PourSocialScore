#!/usr/bin/env python3
"""Writes tools/packaging/fixtures/: one good tree and one bad tree per guard."""
import json
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FX = os.path.join(HERE, "fixtures")
CORE = ["PourSocialScore", "PourSocialScore_Libraries", "PourSocialScore_GUI",
	"PourSocialScore_Options", "PourSocialScore_Logging", "PourSocialScore_Communities"]


def rd(p):
	with open(p, encoding="utf-8") as f:
		return f.read()


def wr(root, rel, text):
	p = os.path.join(root, rel)
	os.makedirs(os.path.dirname(p), exist_ok=True)
	with open(p, "w", encoding="utf-8", newline="\n") as f:
		f.write(text)


REAL_JSON = rd(os.path.join(HERE, "addons.json"))
MANIFEST = rd(os.path.join(REPO, "tools", "toc", "manifest.txt")).split("\n")
HEAD = [l for l in MANIFEST if l.split(" ")[0] in ("interface", "install")]


def manifest(folders):
	return "\n".join(HEAD + sum([["folder " + f, "PSS_Main.lua"] for f in folders], [])) + "\n"


def toc(f, dev=False):
	return "## Interface: 120007\n## Title: %s\n## Version: 3.9.0.155\n%sPSS_Main.lua\n" % (
		f, "## X-PSS-Developer: 1\n" if dev else "")


def tree(name, folders=None, tocs=None, js=None, man=None):
	root = os.path.join(FX, name)
	folders = CORE if folders is None else folders
	for f in tocs if tocs is not None else folders:
		wr(root, "%s/%s.toc" % (f, f), toc(f, f in DEV.get(name, ())))
	wr(root, "readme.txt", "readme\n")
	wr(root, "history.txt", "=> 3.9.0.155 - Fixture\n- fixture\n")
	wr(root, "tools/toc/manifest.txt", man if man is not None else manifest(folders))
	wr(root, "tools/packaging/addons.json", js if js is not None else REAL_JSON)


def entry(f, pkg="core", dev=False):
	return '    {"folder": "%s", "package": "%s", "developer": %s}' % (f, pkg, "true" if dev else "false")


def with_folders(extra, drop=None):
	lines = [l for l in REAL_JSON.split("\n")]
	i = max(n for n, l in enumerate(lines) if '"folder":' in l)
	lines[i] += ","
	lines[i + 1:i + 1] = [entry(*e) + ("," if k < len(extra) - 1 else "") for k, e in enumerate(extra)]
	return "\n".join(lines)


DEV = {"bad-g5": ("PSS_TestKit",), "bad-g10": ("PourSocialScore_Logging",)}
if os.path.isdir(FX):
	shutil.rmtree(FX)
tree("good")
tree("bad-g1", tocs=CORE + ["PSS_TestKit"])
tree("bad-g2", folders=CORE + ["PSS_Extra"], tocs=CORE, js=with_folders([("PSS_Extra",)]))
tree("bad-g3", folders=CORE + ["PourSocialScore_Test"], js=with_folders([("PourSocialScore_Test",)]))
tree("bad-g4", js=REAL_JSON.replace('"PourSocialScore-{version}.zip"', '"PourSocialScore.zip"'))
tree("bad-g5", folders=CORE + ["PSS_TestKit"], js=with_folders([("PSS_TestKit", "core", True)]))
tree("bad-g6", man=manifest([f for f in CORE if f != "PourSocialScore_Communities"]))
split = '    {"folder": "PourSocialScore_GUI",\n     "package": "core", "developer": false}'
tree("bad-g8", js=REAL_JSON.replace(entry("PourSocialScore_GUI"), split))
tree("bad-g10")
