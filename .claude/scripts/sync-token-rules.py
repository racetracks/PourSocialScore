#!/usr/bin/env python3
"""Check that the TOKEN-RULES block lives only in CLAUDE.md: every agent loads CLAUDE.md, so .claude/agents/*.md hold no copy.

Usage: sync-token-rules.py [--check]
  --check  exit 1 if any agent file holds a copy (for CI); changes nothing.
  (none)   remove the block from any agent file that holds a copy.
Place at .claude/scripts/sync-token-rules.py; repo root is two levels up.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
BLOCK = re.compile(r"<!-- TOKEN-RULES:BEGIN -->.*?<!-- TOKEN-RULES:END -->", re.S)
STRIP = re.compile(r"<!-- TOKEN-RULES:BEGIN -->.*?<!-- TOKEN-RULES:END -->\n\n?", re.S)

if not BLOCK.search((ROOT / "CLAUDE.md").read_text()):
    sys.exit("CLAUDE.md: TOKEN-RULES markers not found")

check = "--check" in sys.argv
copies = []
for f in sorted((ROOT / ".claude" / "agents").glob("*.md")):
    text = f.read_text()
    if "<!-- TOKEN-RULES:BEGIN -->" in text or "<!-- TOKEN-RULES:END -->" in text:
        copies.append(f.name)
        if not check:
            f.write_text(STRIP.sub("", text, count=1))

if check and copies:
    print("copy found: " + ", ".join(copies))
    sys.exit(1)
if copies:
    print("removed: " + ", ".join(copies))
sys.exit(0)
