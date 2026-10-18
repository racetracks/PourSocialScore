#!/usr/bin/env python3
"""Checks for plan packs: pack, init --pack, promote, pointer check at ret (spec plan-pack sections 9 and 12, checks 1 to 22).
Runs in a throwaway git repo and scratch tree. Prints FAIL <n> <reason> per failing check, else OK 22 checks."""
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

CLAUDE = pathlib.Path(__file__).resolve().parents[1]
HEAD = "| Task | Class | Fit | Agent | Stream | Context | Writes | Brief | Calls | Out | Depends | Review | Why |"
RULE_LINE = "- Read: `docs/baseline/02_RULES.md` and `docs/pss/02_RULES.md` in full."
CHANGELOG = "## Changelog\n- x\n"
READMEMD = ("# demo\nPurpose: demo\n### Goal\nx\n### Scope\nx\n### Decisions for the author\n1. x. Recommendation: y.\n"
            "### Risks\nx\n")
GRAPH = "https://github.com/racetracks/Pour-Social-Score_Scratch/blob/main/"
fails = []
tmp = pathlib.Path()
repo = pathlib.Path()
scr = pathlib.Path()


def check(n, ok, why=""):
    if not ok:
        fails.append(n)
        print(f"FAIL {n} {str(why)[:400]!r}")


def git(*a):
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-C", str(repo), *a],
                          capture_output=True, text=True).stdout.strip()


def brief(f):
    return ("# Brief G\nPurpose: test\n- Writes: `" + f + "`\n" + RULE_LINE + "\n- Edit `" + f + ":1`: x becomes y.\n"
            "Permitted judgement: none\n## Acceptance\n```sh\ngrep -q y " + f + " && echo ACCEPT\n```\nExpected: ACCEPT\n" + CHANGELOG)


def sd(n):
    return scr / "temp" / "x" / f"s{n}"


def led(n, *args):
    env = dict(os.environ, SESSION_DIR=str(sd(n)), LEDGER_TRANSCRIPTS=str(tmp / f"tr{n}"))
    p = subprocess.run([sys.executable, str(repo / ".claude/scripts/ledger.py"), *args], env=env, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def cc(*args):
    p = subprocess.run([sys.executable, str(repo / ".claude/scripts/check_context.py"), *args], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def mkpack(n, index=True, readme=READMEMD, context=True, extra=None, ctxtext=None):
    """Session s<n> with the draft pack in projects/demo/; returns the pack dir."""
    pd = sd(n) / "projects" / "demo"
    for d in ("briefs", "context", "specs"):
        (pd / d).mkdir(parents=True)
    (pd / "TASK.md").write_text("# Task\nPurpose: test\nReference prefix: T\n")
    (pd / "briefs" / "P1.md").write_text(brief("a.txt"))
    (pd / "briefs" / "P2.md").write_text(brief("b.txt"))
    if context:
        (pd / "context" / "s.md").write_text(ctxtext or ("# s\nPurpose: s\n" + CHANGELOG))
    (pd / "context" / "pack-readme.md").write_text(readme + CHANGELOG)
    rows = [f"| P1 | M1 | WL | engineer | s | - | a.txt | briefs/P1.md | 10 | 150 | - | no | - |",
            f"| P2 | M1 | WL | engineer | s | - | b.txt | briefs/P2.md | 10 | 150 | P1 | no | - |",
            f"| C9 | M3 | PH | consultant | s | - | - | - | 30 | 400 | - | no | - |"]
    sha = git("rev-parse", "HEAD")
    ih = re.search(r"hash ([0-9a-f]{12})", cc("--index", str(tmp / "ix.json"))[1]).group(1)
    pre = f"Base commit: {sha}\n" + (f"Index hash: {ih}\n" if index else "")
    (pd / "provision.md").write_text("# Provision\n\n" + pre + "\n" + HEAD + "\n" + "|" + "---|" * 13 + "\n" + "\n".join(rows) + "\n")
    for rel, text in (extra or {}).items():
        (pd / rel).write_text(text)
    return pd


def main():
    global tmp, repo, scr
    with tempfile.TemporaryDirectory() as t:
        tmp, repo, scr = pathlib.Path(t), pathlib.Path(t) / "repo", pathlib.Path(t) / "scr"
        for d in ("scripts", "agents", "roles"):
            shutil.copytree(CLAUDE / d, repo / ".claude" / d, ignore=shutil.ignore_patterns("__pycache__"))
        (repo / "CLAUDE.md").write_text("# test\n")
        (repo / "a.txt").write_text("x\n")
        (repo / "b.txt").write_text("x\n")
        git("init", "-q")
        git("add", "-A")
        git("commit", "-qm", "base")
        today = time.strftime("%Y-%m-%d", time.gmtime())
        (scr / "documents" / "reference-framework" / "16_Registries").mkdir(parents=True)
        (scr / "documents" / "00_Changelog.md").write_text("# Changelog\n\n| Date | Document |\n| --- | --- |\n")
        reg = scr / "documents" / "reference-framework" / "16_Registries" / "REGISTRY.md"
        reg.write_text("| DEC-00001 | x |\n")
        # 1, 2, 17: pack, rerun, README
        pd1 = mkpack(1)
        rc, o = led(1, "pack", "demo")
        pj = json.loads((pd1 / "pack.json").read_text()) if (pd1 / "pack.json").exists() else {}
        tk = pj.get("tasks", {}).get("P1", {})
        rd = (pd1 / "README.md").read_text() if (pd1 / "README.md").exists() else ""
        check(1, rc == 0 and tk.get("brief") == "briefs/P1.md" and tk.get("context") == "context/s.md"
              and pj.get("waves") == [["P1", "C9"], ["P2"]]
              and rd.split("\n")[1].startswith("Purpose: execution pack for demo"), o + str(pj)[:200])
        before = (pd1 / "pack.json").read_bytes()
        rc, o = led(1, "pack", "demo")
        check(2, rc == 0 and (pd1 / "pack.json").read_bytes() == before, o)
        h = hashlib.sha256(before).hexdigest()[:12]
        check(17, all(x in rd for x in ("## Summary", "## Tasks", "```mermaid", "P1 --> P2", "## Cost",
                                        GRAPH + "temp/x/s1/projects/demo/briefs/P1.md"))
              and rd.split("\n")[2] == f"Pack hash: {h}" and cc(str(pd1 / "README.md"))[0] == 0, rd[:300])
        # 3, 4, 5, 6, 7, 18, 20, 21, 22: hand-off problems
        mkpack(3, index=False)
        rc, o = led(3, "pack", "demo")
        check(3, rc == 1 and "PACK provision.md: no Index hash: line" in o and "HANDOFF refused" in o, o)
        mkpack(4, context=False)
        rc, o = led(4, "pack", "demo")
        check(4, "PACK P1: context/s.md missing" in o, o)
        x = "# x\nPurpose: x\nSee `a.txt:9`.\n" + CHANGELOG
        pd5 = mkpack(5, extra={"specs/x.md": x})
        rc, o = led(5, "pack", "demo")
        check(5, re.search(r"(?m)^POINTER .*pointer a\.txt:9: line 9 > 1", o) is not None, o)
        idx = str(sd(5) / "context" / "repo-index.json")
        rc, o, e = cc("--pointers", idx, str(pd5 / "specs" / "x.md"))
        check(6, rc == 1 and re.search(r"(?m)^POINTER .*pointer a\.txt:9: line 9 > 1", o) is not None, o + e)
        (pd5 / "specs" / "x.md").write_text(x.replace("See `a.txt:9`.", "On scratch `a.txt:9`."))
        rc, o, e = cc("--pointers", idx, str(pd5 / "specs" / "x.md"))
        check(7, rc == 0 and not o.strip(), o + e)
        mkpack(18, readme=READMEMD + "x\n" * 18)
        rc, o = led(18, "pack", "demo")
        check(18, rc == 1 and "PACK context/pack-readme.md: 26 lines, at most 25" in o, o)
        mkpack(20, extra={"specs/x.md": "# x\nPurpose: x\n"})
        rc, o = led(20, "pack", "demo")
        check(20, "PACK specs/x.md: no ## Changelog section" in o, o)
        mkpack(21, ctxtext="# s\nPurpose: s\nSee DEC-99999.\n" + CHANGELOG)
        rc, o = led(21, "pack", "demo")
        check(21, "key DEC-99999 not in the registry" in o, o)
        mkpack(22, extra={"specs/big.md": "# big\nPurpose: big\n" + "word " * 5000 + "\n" + CHANGELOG})
        rc, o = led(22, "pack", "demo")
        check(22, "PACK specs/big.md: SHAPE" in o, o)
        # 8, 9: draft load
        rc, o = led(2, "init", "--pack", str(pd1))
        check(8, rc == 1 and "is a draft" in o, o)
        rc, o = led(2, "init", "--pack", str(pd1), "--draft")
        lg = sd(2) / "ledger.json"
        check(9, rc == 0 and "DRY RUN" in o and (not lg.exists() or not json.loads(lg.read_text())["tasks"]), o)
        # 10: promote
        rc, o = led(1, "promote", str(pd1))
        ap = scr / "documents" / "projects" / "demo"
        check(10, rc == 0 and (ap / "pack.json").exists() and pd1.exists()
              and "projects/demo/" in (scr / "documents" / "00_Changelog.md").read_text(), o)
        # 11, 12: approved load
        rc, o = led(3, "init", "--pack", str(ap))
        rc2, o2 = led(3, "spawn", "P1")
        check(11, rc == 0 and "loaded 3 tasks from pack.json" in o and (sd(3) / "briefs" / "P1.md").exists()
              and rc2 == 0 and o2.lstrip().startswith("SPAWN engineer:"), o + o2)
        rc, o = led(3, "init", "--pack", str(ap))
        check(12, rc == 1 and "already has tasks" in o, o)
        # 13: changed brief
        bf = ap / "briefs" / "P1.md"
        orig = bf.read_bytes()
        bf.write_bytes(orig + b" ")
        rc, o = led(4, "init", "--pack", str(ap))
        bf.write_bytes(orig)
        check(13, rc == 1 and "PACK briefs/P1.md: changed since export" in o, o)
        # 14, 15, 16: stale fence, spawn line, pointer check at ret
        (repo / "a.txt").write_text("edited\n")
        rc, o = led(5, "init", "--pack", str(ap))
        check(14, rc == 0 and "RETRIAGE P1" in o, o)
        rc, o = led(5, "spawn", "C9")
        check(15, re.search(r"base [0-9a-f]{12}\W+index [0-9a-f]{12}", o) is not None, o)
        aid = (re.search(r"ID (\S+)", o) or [0, "A01"])[1]
        (sd(5) / "specs").mkdir(exist_ok=True)
        (sd(5) / "specs" / "y.md").write_text("# y\nPurpose: y\nSee `a.txt:9`.\n")
        rc, o = led(5, "ret", aid, "DONE", "spend: calls 1/30 · out 1/400")
        st = json.loads((sd(5) / "ledger.json").read_text())["tasks"]["C9"]["status"]
        check(16, "POINTER" in o and "ROUTE `cont" in o and st == "blocked", o + st)
        git("checkout", "a.txt")
        # 19: README not current
        rf = ap / "README.md"
        orig = rf.read_text()
        lines = orig.split("\n")
        lines[2] = "Pack hash: 000000000000"
        rf.write_text("\n".join(lines))
        rc, o = led(6, "init", "--pack", str(ap))
        rf.write_text(orig)
        check(19, rc == 1 and "PACK README.md: not current with pack.json" in o, o)
    if fails:
        return 1
    print("OK 22 checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
