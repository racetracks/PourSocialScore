#!/bin/sh
# Registers this repo's hooks (.claude/settings.json) and agents (.claude/agents/) in the
# user settings (~/.claude/), so they apply when a session starts outside this repo
# (a cloud session holding several repos starts in their parent folder).
# Run it from the environment's setup script. Idempotent.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$HOME/.claude/agents"
cp "$REPO"/.claude/agents/*.md "$HOME/.claude/agents/"
python3 - "$REPO" <<'PY'
import json, os, sys
repo = sys.argv[1]
path = os.path.expanduser("~/.claude/settings.json")
cfg = json.load(open(path)) if os.path.exists(path) else {}
ours = json.load(open(os.path.join(repo, ".claude/settings.json")))["hooks"]
hooks = cfg.setdefault("hooks", {})
for event, entries in ours.items():
	keep = [e for e in hooks.get(event, []) if "inject_prefix.py" not in json.dumps(e)]
	for e in entries:
		e = json.loads(json.dumps(e).replace("$CLAUDE_PROJECT_DIR", repo))
		keep.append(e)
	hooks[event] = keep
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(cfg, open(path, "w"), indent=2)
print("PSS hooks and agents registered in %s" % os.path.dirname(path))
PY
