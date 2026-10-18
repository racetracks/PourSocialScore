#!/usr/bin/env python3
"""Checks for the ledger M1 lane (spec ledger-m1 7.1 to 7.5). Prints FAIL <n> <reason> per failure, else OK 11 checks."""
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

LEDGER = str(pathlib.Path(__file__).resolve().parent / "ledger.py")
HEAD = "| Task | Class | Fit | Agent | Stream | Context | Writes | Brief | Calls | Out | Depends | Review | Why |"
fails = []


def row(t, cls, fit, agent):
    return f"| {t} | {cls} | {fit} | {agent} | s | - | tmp/none | briefs/{t}.md | 10 | 150 | - | yes | - |"


def session(tmp, n, rows):
    sd = pathlib.Path(tmp) / f"s{n}"
    (sd / "briefs").mkdir(parents=True)
    for r in rows:
        t = r.split("|")[1].strip()
        (sd / "briefs" / f"{t}.md").write_text("# brief\n## Acceptance\nAcceptance\n")
    (sd / "provision.md").write_text("# Provision\n\n" + HEAD + "\n" + "|" + "---|" * 13 + "\n" + "\n".join(rows) + "\n")
    return sd


def run(sd, tr, *args):
    env = dict(os.environ, SESSION_DIR=str(sd), LEDGER_TRANSCRIPTS=str(tr))
    p = subprocess.run([sys.executable, LEDGER, *args], env=env, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def check(n, ok, why):
    if not ok:
        fails.append(n)
        print(f"FAIL {n} {why}")


def main():
    with tempfile.TemporaryDirectory() as tmp:
        tr = pathlib.Path(tmp) / "tr"
        tr.mkdir()
        sd1 = session(tmp, 1, [row("R1", "M1", "WL", "engineer-m1"), row("R2", "M1", "WL", "engineer-m1")])
        rc, o = run(sd1, tr, "init")
        check(1, rc == 0 and "loaded 2 tasks" in o, o)
        rc, o = run(session(tmp, 2, [row("R9", "M3", "WL", "consultant")]), tr, "init")
        check(2, rc == 1 and "R9: Fit WL does not allow consultant M3" in o, o)
        rc, o = run(session(tmp, 3, [row("R8", "M2", "WM", "engineer-m1")]), tr, "init")
        check(3, rc == 1 and "Fit WM does not allow engineer-m1 M2" in o, o)
        spend = "spend: calls 2/10 · out 5/150"
        rc, o = run(sd1, tr, "spawn", "R1")
        check(4, o.lstrip().startswith("SPAWN engineer-m1:") and "model haiku" in o, o)
        ref1 = (re.search(r"ref (\S+)", o) or [0, ""])[1]
        rc, o = run(sd1, tr, "ret", "A01", "BLOCKED", spend)
        check(5, o.count("RERUN R1") == 1 and o.count("ROUTE re-run R1 on engineer (Sonnet)") == 1 and "--support" not in o, o)
        rc, o = run(sd1, tr, "spawn", "R1")
        check(6, o.lstrip().startswith("SPAWN engineer:") and "model sonnet" in o, o)
        rc, o = run(sd1, tr, "ret", "A02", "BLOCKED", spend)
        check(7, "re-run" not in o and "--support" in o, o)
        rc, o = run(sd1, tr, "spawn", "R2")
        rc, o = run(sd1, tr, "ret", "A03", "DONE", spend, "--failed")
        check(8, o.count("RERUN R2") == 1, o)
        # 9, 10: render
        tr9 = pathlib.Path(tmp) / "tr9" / "x" / "subagents"
        tr9.mkdir(parents=True)
        msg = {"type": "assistant", "message": {"id": "m1", "model": "claude-haiku-5-5",
               "usage": {"input_tokens": 1000, "cache_read_input_tokens": 10000,
                         "cache_creation_input_tokens": 2000, "output_tokens": 500}}}
        (tr9 / "a.jsonl").write_text(json.dumps({"type": "user", "message": {"content": f"ref {ref1}"}}) + "\n"
                                     + json.dumps(msg) + "\n" + json.dumps(msg) + "\n")
        rc, o = run(sd1, pathlib.Path(tmp) / "tr9", "render")
        rd = (sd1 / "README.md").read_text()
        check(9, rc == 0 and "| engineer-m1 | claude-haiku-5-5 | 1 | 1000 | 10000 | 2000 | 500 | 0.0007 |" in rd
              and "tokens: measured" in o, o + rd)
        rc, o = run(sd1, pathlib.Path(tmp) / "missing", "render")
        check(10, rc == 0 and "Tokens: unmeasured" in (sd1 / "README.md").read_text(), o)
        # 11
        sd4 = session(tmp, 4, [row("R1", "M1", "WL", "engineer-m1")])
        run(sd4, tr, "init")
        run(sd4, tr, "spawn", "R1")
        (sd4 / "notes.md").write_text("x")
        (sd4 / "agents" / "A01").mkdir(parents=True, exist_ok=True)
        (sd4 / "agents" / "A01" / "REPORT.md").write_text("x")
        rc, o = run(sd4, tr, "ret", "A01", "DONE", spend)
        sl = [l for l in o.splitlines() if l.startswith("SHAPE")]
        check(11, any("agents/A01/REPORT.md" in l for l in sl) and not any("notes.md" in l for l in o.splitlines()
              if l.startswith(("SHAPE", "DOCS"))), o)
    if fails:
        sys.exit(1)
    print("OK 11 checks")


main()
