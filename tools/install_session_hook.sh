#!/bin/sh
# Registers .claude/hooks/inject_prefix.py in the user settings (~/.claude/settings.json),
# so the Operating Instructions prefix applies when a session starts outside this repo
# (a cloud session holding several repos starts in their parent folder).
# Run it from the environment's setup script. Idempotent.
set -e
HOOK="$(cd "$(dirname "$0")/.." && pwd)/.claude/hooks/inject_prefix.py"
python3 - "$HOOK" "$(dirname "$0")/../.claude/settings.json" <<'PY'
import json, os, sys
hook, repo = sys.argv[1], sys.argv[2]
path = os.path.expanduser("~/.claude/settings.json")
cfg = json.load(open(path)) if os.path.exists(path) else {}
entry = json.load(open(repo))["hooks"]["PreToolUse"][0]
entry = dict(entry, hooks=[dict(entry["hooks"][0], command='python3 "%s"' % hook)])
pre = cfg.setdefault("hooks", {}).setdefault("PreToolUse", [])
pre[:] = [e for e in pre if "inject_prefix.py" not in json.dumps(e)] + [entry]
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(cfg, open(path, "w"), indent=2)
print("inject_prefix hook registered in %s" % path)
PY
