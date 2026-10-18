#!/usr/bin/env python3
"""Checks for the stale-plan, brief, rules-read and index features (spec ledger-m1 section 9 and 12.6, checks 1 to 24).
Runs in a throwaway git repo. Prints FAIL <n> <reason> per failing check, else OK 24 checks."""
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
SPEND = "spend: calls 2/10 · out 5/150"
RULE_LINE = "- Read: `docs/baseline/02_RULES.md` and `docs/pss/02_RULES.md` in full."
G = ("# Brief G\nPurpose: test\n- Writes: `a.txt`\n" + RULE_LINE + "\n- Edit `a.txt:1`: x becomes y.\n"
     "Permitted judgement: none\n## Acceptance\n```sh\ngrep -q y a.txt && echo ACCEPT\n```\nExpected: ACCEPT\n")
fails = []
tmp = pathlib.Path()
repo = pathlib.Path()


def check(n, ok, why):
    if not ok:
        fails.append(n)
        print(f"FAIL {n} {str(why)[:300]!r}")


def git(*a):
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "-C", str(repo), *a],
                          capture_output=True, text=True).stdout.strip()


def row(t, writes="b.txt", agent="engineer", cls="M1", fit="WL", calls=10, out=150, brief=None):
    brief = brief or f"briefs/{t}.md"
    return f"| {t} | {cls} | {fit} | {agent} | s | - | {writes} | {brief} | {calls} | {out} | - | no | - |"


def sess(n, rows, pre="", brief=G):
    sd = tmp / f"s{n}"
    (sd / "briefs").mkdir(parents=True)
    for r in rows:
        t = r.split("|")[1].strip()
        if "| - | 30 |" not in r:
            (sd / "briefs" / f"{t}.md").write_text(brief)
    (sd / "provision.md").write_text("# Provision\n\n" + pre + "\n" + HEAD + "\n" + "|" + "---|" * 13 + "\n" + "\n".join(rows) + "\n")
    return n


def led(n, *args):
    env = dict(os.environ, SESSION_DIR=str(tmp / f"s{n}"), LEDGER_TRANSCRIPTS=str(tmp / f"tr{n}"))
    p = subprocess.run([sys.executable, str(repo / ".claude/scripts/ledger.py"), *args], env=env, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def cc(*args):
    p = subprocess.run([sys.executable, str(repo / ".claude/scripts/check_context.py"), *args], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def plus(line):
    return G.replace("## Acceptance", line + "\n## Acceptance")


def brief_file(name, text):
    f = tmp / name
    f.write_text(text)
    return str(f)


def transcript(n, ref, reads):
    d = tmp / f"tr{n}" / "x" / "subagents"
    d.mkdir(parents=True)
    use = [{"type": "tool_use", "name": "Read", "input": dict(file_path=p, **extra)} for p, extra in reads]
    msg = {"type": "assistant", "message": {"id": "m1", "model": "claude-sonnet-5", "content": use,
           "usage": {"input_tokens": 1, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0, "output_tokens": 1}}}
    (d / "r.jsonl").write_text(json.dumps({"type": "user", "message": {"content": f"ref {ref}"}}) + "\n" + json.dumps(msg) + "\n")


def spawn_p2(n, pre=""):
    sess(n, [row("P2")], pre)
    led(n, "init")
    rc, o = led(n, "spawn", "P2")
    return rc, o, (re.search(r"ref (\S+)", o) or [0, ""])[1]


def main():
    global tmp, repo
    with tempfile.TemporaryDirectory() as t:
        tmp, repo = pathlib.Path(t), pathlib.Path(t) / "repo"
        for d in ("scripts", "agents", "roles"):
            shutil.copytree(CLAUDE / d, repo / ".claude" / d, ignore=shutil.ignore_patterns("__pycache__"))
        (repo / "a.txt").write_text("x\n")
        (repo / "b.txt").write_text("x\n")
        git("init", "-q")
        git("add", "-A")
        git("commit", "-qm", "base")
        sha = git("rev-parse", "HEAD")
        # 1 to 3: stale pack
        sess(1, [row("P1", "a.txt"), row("P2", "b.txt")], f"Base commit: {sha}\n")
        (repo / "a.txt").write_text("edited\n")
        rc, o = led(1, "init")
        check(1, rc == 0 and len(re.findall(r"(?m)^RETRIAGE P1: fence changed since pack base.*a\.txt", o)) == 1
              and "RETRIAGE P2" not in o, o)
        rc, o = led(1, "spawn", "P1")
        check(2, rc == 1 and "P1 is stale" in o, o)
        rc, o = led(1, "init")
        rc2, o2 = led(1, "spawn", "P1")
        check(3, "RETRIAGE" not in o and rc2 == 0 and o2.lstrip().startswith("SPAWN engineer:"), o + o2)
        git("checkout", "a.txt")
        # 4, 5
        sess(4, [row("P2")], "Base commit: 0000000\n")
        rc, o = led(4, "init")
        check(4, rc == 0 and o.lstrip().startswith("WARN stale-plan check skipped"), o)
        sess(5, [row("P2")])
        rc, o = led(5, "init")
        check(5, "RETRIAGE" not in o and "WARN" not in o, o)
        # 6 to 11: brief check
        rc, o, e = cc("--brief", "M1", brief_file("G.md", G))
        check(6, rc == 0 and o == "", o)
        rc, o, e = cc("--brief", "M1", brief_file("g7.md", G.replace("Permitted judgement: none\n", "")))
        check(7, rc == 1 and 'M1 brief needs the line "Permitted judgement: none"' in o, o)
        rc, o, e = cc("--brief", "M1", brief_file("g8.md", plus("Change the file, e.g. this one.")))
        check(8, 'hedge word "e.g."' in o, o)
        rc, o, e = cc("--brief", "M1", brief_file("g9.md", plus("See `x/y.py` first.")))
        check(9, "bare file reference `x/y.py`" in o, o)
        rc, o, e = cc("--brief", "M2", brief_file("G.md", G))
        check(10, 'M2 brief needs a "## Permitted judgement" section with a numbered list' in o, o)
        rc, o, e = cc("--brief", "M3", brief_file("G.md", G))
        check(11, rc == 2 and e.startswith("usage:"), e)
        # 12, 13
        sess(12, [row("P3")], brief=G.replace("- Writes: `a.txt`\n", ""))
        led(12, "init")
        rc, o = led(12, "spawn", "P3")
        check(12, rc == 1 and "BRIEF " in o and "ROUTE `cont" in o, o)
        sess(13, [row("C9", "-", "consultant", "M3", "PH", 30, 400, "-")])
        led(13, "init")
        rc, o = led(13, "spawn", "C9")
        check(13, re.search(r"base [0-9a-f]{12}", o) is not None, o)
        # 14 to 16: rules read
        full = [("/w/docs/baseline/02_RULES.md", {}), ("/w/docs/pss/02_RULES.md", {})]
        rc, o, ref = spawn_p2(14)
        transcript(14, ref, full)
        rc, o = led(14, "ret", "A01", "DONE", SPEND)
        check(14, "RULES" not in o and "ACCEPT P2" in o, o)
        rc, o, ref = spawn_p2(15)
        transcript(15, ref, [full[0], ("/w/docs/pss/02_RULES.md", {"limit": 50})])
        rc, o = led(15, "ret", "A01", "DONE", SPEND)
        check(15, "RULES A01: not read in full: docs/pss/02_RULES.md" in o and "ROUTE `cont A01`" in o, o)
        rc, o, ref = spawn_p2(16)
        rc, o = led(16, "ret", "A01", "DONE", SPEND)
        check(16, re.search(r"(?m)^WARN RULES", o) is not None and "ACCEPT" in o, o)
        # 17 to 20: index
        idx = str(tmp / "idx.json")
        rc, o, e = cc("--index", idx)
        rc, o, e = cc("--lookup", idx, "a.txt:1")
        check(17, rc == 0 and "OK a.txt:1" in o, o + e)
        rc, o, e = cc("--lookup", idx, "a.txt:9")
        check(18, rc == 1 and "MISSING a.txt:9: line 9 > 1" in o, o + e)
        rc, o, e = cc("--brief", "M1", "--index", idx, brief_file("g19.md", plus("Edit `a.txt:9`.")))
        check(19, "pointer a.txt:9" in o, o + e)
        sess(20, [row("P2")], "Index hash: 000000000000\n")
        rc, o = led(20, "init")
        check(20, re.search(r"(?m)^NOTE index changed", o) is not None, o)
        # 21: a mid-run commit is not a change
        sess(21, [row("P2")])
        (repo / "b.txt").write_text("y\n")
        led(21, "init")
        led(21, "spawn", "P2")
        git("commit", "-qam", "mid")
        rc, o = led(21, "ret", "A01", "DONE", SPEND)
        check(21, "SCOPE" not in o and not any(l.startswith("SHAPE") and "b.txt" in l for l in o.splitlines()), o)
        # 22: __pycache__ is not a change
        spawn_p2(22)
        pc = repo / ".claude/scripts/__pycache__"
        pc.mkdir(exist_ok=True)
        (pc / "x.pyc").write_text("x")
        rc, o = led(22, "ret", "A01", "DONE", SPEND)
        check(22, "SCOPE" not in o, o)
        # 23: transcript in another project folder; 24: batched fences
        rc, o, ref = spawn_p2(23)
        d = tmp / "cfg/projects/-elsewhere/s1/subagents"
        d.mkdir(parents=True)
        shutil.copy(next((tmp / "tr14").rglob("*.jsonl")), d / "agent-a.jsonl")
        (d / "agent-a.jsonl").write_text((d / "agent-a.jsonl").read_text().replace("ref REF", "ref " + ref, 1).replace(re.search(r"ref (\S+)", (d / "agent-a.jsonl").read_text()).group(1), ref))
        env = dict(os.environ, SESSION_DIR=str(tmp / "s23"), CLAUDE_CONFIG_DIR=str(tmp / "cfg"))
        env.pop("LEDGER_TRANSCRIPTS", None)
        p = subprocess.run([sys.executable, str(repo / ".claude/scripts/ledger.py"), "ret", "A01", "DONE", SPEND], env=env, capture_output=True, text=True)
        check(23, "RULES" not in p.stdout and "ACCEPT P2" in p.stdout, p.stdout + p.stderr)
        sess(24, [row("P4", "tools/t.sh"), row("P5", "docs/x.md")])
        led(24, "init")
        led(24, "spawn", "P4,P5")
        (repo / "tools").mkdir(exist_ok=True)
        (repo / "tools/t.sh").write_text("echo x\n")
        (repo / "docs").mkdir(exist_ok=True)
        (repo / "docs/x.md").write_text("# x\nPurpose: x\n")
        rc, o = led(24, "ret", "A01", "DONE", SPEND)
        check(24, "DOCS" not in o and "SHAPE" not in o, o)
    if fails:
        sys.exit(1)
    print("OK 24 checks")


main()
