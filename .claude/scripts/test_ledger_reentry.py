#!/usr/bin/env python3
"""Checks for the re-entry cost cuts (model by brief, ACCEPT/EXTEND, stale head, accept, all BRIEF lines).
Runs in a throwaway git repo. Prints FAIL <n> <reason> per failing check, else OK 14 checks."""
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

CLAUDE = pathlib.Path(__file__).resolve().parents[1]
HEAD = "| Task | Class | Fit | Agent | Stream | Context | Writes | Brief | Calls | Out | Depends | Review | Why |"
RULE_LINE = "- Read: `docs/baseline/02_RULES.md` and `docs/pss/02_RULES.md` in full."
G = ("# Brief G\nPurpose: test\n- Writes: `a.txt`\n" + RULE_LINE + "\n- Edit `a.txt:1`: x becomes y.\n"
     "Permitted judgement: none\n## Acceptance\n```sh\ngrep -q y a.txt && echo ACCEPT\n```\nExpected: ACCEPT\n")
fails = []
tmp = pathlib.Path()
repo = pathlib.Path()


def check(n, ok, why):
    if not ok:
        fails.append(n)
        print(f"FAIL {n} {str(why)[:400]!r}")


def row(t, writes="b.txt", agent="engineer", cls="M1", fit="WL", calls=10, out=150):
    return f"| {t} | {cls} | {fit} | {agent} | s | - | {writes} | briefs/{t}.md | {calls} | {out} | - | no | - |"


def sess(n, rows, pre="", brief=G, briefs=True):
    sd = tmp / f"s{n}"
    (sd / "briefs").mkdir(parents=True, exist_ok=True)
    for r in rows:
        t = r.split("|")[1].strip()
        if briefs:
            (sd / "briefs" / f"{t}.md").write_text(brief)
    (sd / "provision.md").write_text("# Provision\n\n" + pre + "\n" + HEAD + "\n" + "|" + "---|" * 13 + "\n" + "\n".join(rows) + "\n")


def led(n, *args):
    env = dict(os.environ, SESSION_DIR=str(tmp / f"s{n}"), LEDGER_TRANSCRIPTS=str(tmp / f"tr{n}"))
    p = subprocess.run([sys.executable, str(repo / ".claude/scripts/ledger.py"), *args], env=env, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def git(*a):
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-C", str(repo), *a],
                          capture_output=True, text=True).stdout.strip()


def transcript(n, ref, startup, context):
    d = tmp / f"tr{n}" / "x" / "subagents"
    d.mkdir(parents=True, exist_ok=True)
    msgs = [{"type": "assistant", "message": {"id": f"m{i}", "model": "claude-sonnet-5", "content": [],
             "usage": {"input_tokens": 1, "cache_read_input_tokens": 0, "cache_creation_input_tokens": v - 1,
                       "output_tokens": 1}}} for i, v in enumerate((startup, context))]
    (d / "r.jsonl").write_text(json.dumps({"type": "user", "message": {"content": f"ref {ref}"}}) + "\n"
                               + "\n".join(json.dumps(m) for m in msgs) + "\n")


def started(n, rows, task, **kw):
    sess(n, rows, **kw)
    led(n, "init")
    rc, o = led(n, "spawn", task)
    return o, (re.search(r"ref (\S+)", o) or [0, ""])[1]


def main():
    global tmp, repo
    with tempfile.TemporaryDirectory() as t:
        tmp, repo = pathlib.Path(t), pathlib.Path(t) / "repo"
        for d in ("scripts", "agents", "roles"):
            shutil.copytree(CLAUDE / d, repo / ".claude" / d, ignore=shutil.ignore_patterns("__pycache__"))
        for f in ("a.txt", "b.txt", "c.txt"):
            (repo / f).write_text("x\n")
        git("init", "-q")
        git("add", "-A")
        git("commit", "-qm", "base")
        sha = git("rev-parse", "HEAD")
        # budgets (D1)
        txt = (repo / ".claude/agents/consultant.md").read_text()
        check(1, all(re.search(rf"\| {k} \|[^\n]*\| {c} \| {o} \|", txt) for k, c, o in
                     (("support", 12, 120), ("engineer-m3", 25, 300), ("engineer-M1", 15, 200))), "budgets")
        # 2, 3: model by brief
        o, _ = started(2, [row("R1", agent="engineer-m1")], "R1", brief=G)
        check(2, "MODEL engineer" in o and o.count("SPAWN engineer:") == 1 and "model sonnet" in o, o)
        o, _ = started(3, [row("R1", agent="engineer-m1")], "R1", brief=G.replace("x becomes y.", "x becomes y, by script."))
        check(3, "MODEL engineer" not in o and "SPAWN engineer-m1:" in o, o)
        # 4, 5: DONE within 1.5x
        started(4, [row("R1")], "R1")
        rc, o = led(4, "ret", "A01", "DONE", "spend: calls 14/10 · out 100/150 · progress no · need ~0")
        check(4, "ACCEPT R1" in o and "OVERRUN A01" in o and "within 1.5x" in o and "RETRIAGE" not in o, o)
        started(5, [row("R1")], "R1")
        rc, o = led(5, "ret", "A01", "DONE", "spend: calls 16/10 · out 100/150 · progress no · need ~0")
        check(5, "ACCEPT R1" not in o and "RETRIAGE" in o, o)
        # 6 to 9: EXTEND
        bud = "spend: calls 10/10 · out 100/150 · progress yes · need ~"
        _, ref = started(6, [row("R1")], "R1")
        transcript(6, ref, 20000, 30000)
        rc, o = led(6, "ret", "A01", "BUDGET", bud + "3")
        ext = json.loads((tmp / "s6/ledger.json").read_text())["agents"]["A01"]["ext"]
        check(6, "EXTEND A01" in o and "RETRIAGE" not in o and ext[0] == 3 and ext[1] >= 0, o + str(ext))
        rc, o = led(6, "cont", "A01")
        check(7, o.startswith("CONTINUE") and "calls 3" in o, o)
        _, ref = started(7, [row("R1")], "R1")
        transcript(7, ref, 20000, 30000)
        rc, o = led(7, "ret", "A01", "BUDGET", bud + "10")
        check(8, "EXTEND" not in o and "RETRIAGE" in o, o)
        _, ref = started(8, [row("R1")], "R1")
        transcript(8, ref, 20000, 30000)
        rc, o = led(8, "ret", "A01", "BUDGET", "spend: calls 15/10 · out 100/150 · progress yes · need ~3")
        _, ref2 = started(9, [row("R1")], "R1")
        transcript(9, ref2, 20000, 30000)
        rc2, o2 = led(9, "ret", "A01", "BUDGET", "spend: calls 10/10 · out 100/150 · progress no · need ~3")
        check(9, "EXTEND" not in o + o2 and "RETRIAGE" in o and "RETRIAGE" in o2, o + o2)
        # 10, 11: stale head
        git("commit", "-q", "--allow-empty", "-m", "x")
        (repo / "a.txt").write_text("edited\n")
        git("commit", "-qam", "edit a")
        sess(10, [row("P1", "b.txt")], f"Base commit: {sha}\n")
        rc, o = led(10, "init")
        check(10, "RETRIAGE" not in o and rc == 0, o)
        sess(10, [row("P1", "b.txt"), row("P2", "a.txt"), row("P3", "c.txt")], f"Base commit: {sha}\n")
        (repo / "c.txt").write_text("edited\n")
        rc, o = led(10, "init")
        check(11, "RETRIAGE P3" in o and "RETRIAGE P2" not in o, o)
        git("checkout", "c.txt")
        # 12: accept
        sess(12, [row("R1")], "")
        led(12, "init")
        sess(12, [row("R1")], "")
        started(12, [row("R1"), row("R2")], "R1")
        led(12, "ret", "A01", "BLOCKED", "spend: calls 1/10 · out 1/150")
        sess(13, [row("C1", "-", agent="consultant", cls="M3", fit="PH", calls=30, out=400)], "")
        rc, o = led(12, "accept", "R1", "--by", "A02")
        check(12, rc == 1, o)
        L = json.loads((tmp / "s12/ledger.json").read_text())
        L["agents"]["A09"] = {"kind": "consultant", "tasks": [], "segs": [], "status": "idle", "orig": [0, 0], "ext": [0, 0], "spent": [0, 0]}
        (tmp / "s12/ledger.json").write_text(json.dumps(L))
        rc, o = led(12, "accept", "R1", "--by", "A09")
        L = json.loads((tmp / "s12/ledger.json").read_text())
        check(13, rc == 0 and L["tasks"]["R1"]["status"] == "done" and "accepted R1" in (tmp / "s12/CONTEXT.md").read_text(), o)
        # 14: every BRIEF line at once
        sess(14, [row("R1"), row("R2")], briefs=False)
        led(14, "init")
        rc, o = led(14, "spawn", "R1,R2")
        check(14, rc == 1 and "BRIEF briefs/R1.md" in o and "BRIEF briefs/R2.md" in o, o)
    if fails:
        sys.exit(1)
    print("OK 14 checks")


main()
