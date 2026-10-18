#!/usr/bin/env python3
"""Checks for the machine index symbols and the @name lookup (spec ledger-m1 section 12.7).
Throwaway git repo. Prints FAIL <n> <reason> per failure, else OK 6 checks."""
import pathlib
import shutil
import subprocess
import sys
import tempfile

SRC = pathlib.Path(__file__).resolve().parent / "check_context.py"
fails = []


def run(repo, *a, git=False):
    cmd = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-C", str(repo), *a] if git else \
        [sys.executable, str(repo / ".claude/scripts/check_context.py"), *a]
    return subprocess.run(cmd, capture_output=True, text=True)


def main():
    repo = pathlib.Path(tempfile.mkdtemp())
    try:
        (repo / "PourSocialScore").mkdir()
        (repo / "tools").mkdir()
        (repo / ".claude/scripts").mkdir(parents=True)
        shutil.copy(SRC, repo / ".claude/scripts/check_context.py")
        (repo / "PourSocialScore/X.lua").write_text('local M = {}\nfunction M.Foo()\nEvents.Fire("PSS_BAR")\nSLASH_PSSX1 = "/pssx"\n')
        (repo / "tools/t.py").write_text("def go():\n    pass\n")
        run(repo, "init", "-q", git=True)
        run(repo, "add", "-A", git=True)
        run(repo, "commit", "-qm", "x", git=True)
        idx = str(repo / "idx.json")
        p = run(repo, "--index", idx)
        if p.returncode:
            print("FAIL 0", p.stderr[-300:])
            return 1
        cases = [("@Foo", "PourSocialScore/X.lua:2 export Foo", 0), ("@PSS_BAR", "PourSocialScore/X.lua:3 fires PSS_BAR", 0),
                 ("@/pssx", "PourSocialScore/X.lua:4 slash /pssx", 0), ("@go", "tools/t.py:1 export go", 0),
                 ("@Nope", "MISSING @Nope: no symbol", 1), ("X.lua:4", "OK X.lua:4", 0)]
        for n, (ref, want, rc) in enumerate(cases, 1):
            p = run(repo, "--lookup", idx, ref)
            if want not in p.stdout or p.returncode != rc:
                fails.append(n)
                print(f"FAIL {n} {p.stdout.strip()!r} rc={p.returncode}")
    finally:
        shutil.rmtree(repo, ignore_errors=True)
    if not fails:
        print("OK 6 checks")
    return 1 if fails else 0


sys.exit(main())
