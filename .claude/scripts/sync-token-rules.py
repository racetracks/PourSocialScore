#!/usr/bin/env python3
"""Copy the TOKEN-RULES block from CLAUDE.md into every .claude/agents/*.md.

Usage: sync-token-rules.py [--check]
  --check  exit 1 if any agent file is out of sync (for CI); changes nothing.
Place at .claude/scripts/sync-token-rules.py; repo root is two levels up.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BLOCK = re.compile(r"<!-- TOKEN-RULES:BEGIN -->.*?<!-- TOKEN-RULES:END -->", re.S)

src = BLOCK.search((ROOT / "CLAUDE.md").read_text())
if not src:
    sys.exit("CLAUDE.md: TOKEN-RULES markers not found")

check = "--check" in sys.argv
drift = []
for f in sorted((ROOT / ".claude" / "agents").glob("*.md")):
    text = f.read_text()
    if not BLOCK.search(text):
        drift.append(f"{f.name}: markers missing")
        continue
    new = BLOCK.sub(lambda _: src.group(0), text, count=1)
    if new != text:
        drift.append(f.name)
        if not check:
            f.write_text(new)

if drift:
    print(("out of sync: " if check else "synced: ") + ", ".join(drift))
sys.exit(1 if check and drift else 0)
