"""Shared session-directory resolution for the pack's scripts (not run directly)."""
import os
import pathlib
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
PTR = ROOT / ".claude" / ".session"


def _skeleton(d):
    (d / "prompts").mkdir(parents=True, exist_ok=True)
    ctx = d / "CONTEXT.md"
    if not ctx.exists():
        task = os.path.relpath(ROOT / "TASK.md", d).replace(os.sep, "/")
        ctx.write_text(
            "# Session context\n"
            f"Task (goal, constraints, deliverables): [TASK.md]({task}). Not copied here.\n"
            "Plan: [provision.md](provision.md) · Task table, budgets, spend: `ledger.json` · "
            "Index: [README.md](README.md)\n\n## Decisions\n"
        )
    idx = d / "prompts" / "README.md"
    if not idx.exists():
        idx.write_text("# Prompts\n| ID | Time | Author | Summary | Link |\n|---|---|---|---|---|\n")


def current(create=False):
    """Return (session_dir, created). Never switches an open session."""
    env = os.environ.get("SESSION_DIR")
    if env:
        d = (ROOT / env).resolve()
        if create and not d.exists():
            d.mkdir(parents=True)
            _skeleton(d)
            return d, True
        return d, False
    if PTR.exists():
        d = ROOT / PTR.read_text().strip()
        if d.is_dir() and not (d / "CLOSED").exists():
            return d, False
    if not create:
        sys.exit("no open session (.claude/.session missing or closed)")
    rel = f"{os.environ.get('SESSION_ROOT', 'sessions')}/{time.strftime('%Y%m%d-%H%M%S')}"
    d = ROOT / rel
    d.mkdir(parents=True, exist_ok=True)
    _skeleton(d)
    PTR.write_text(rel + "\n")
    return d, True


def rel(p):
    return os.path.relpath(p, ROOT).replace(os.sep, "/")
