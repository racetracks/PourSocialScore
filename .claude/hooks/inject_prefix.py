#!/usr/bin/env python3
"""PreToolUse hook: prefix the author's prompt (the Operating Instructions), verbatim,
to every prompt handed to a sub-agent, thread, session or scheduled task.
It lives once, at the top of CLAUDE.md, between the operating-instructions markers.
Sub-agents and messages get the core sections (0, 1, 5) and a pointer to the rest;
a brief carrying [OI:orchestrate], [OI:docs] or [OI:full] adds those sections.
Tools that start a session or a scheduled run get every section.
Idempotent: a prompt that already starts with the heading is left alone."""
import json, os, re, sys

# tool name -> the input field that carries the prompt
FIELDS = {
	"Agent": "prompt",
	"Task": "prompt",
	"SendMessage": "message",
	"CronCreate": "prompt",
	"mcp__claude-code-remote__send_message": "message",
	"mcp__claude-code-remote__create_session": "prompt",
	"mcp__claude-code-remote__create_trigger": "prompt",
	"mcp__claude-code-remote__update_trigger": "prompt",
	"mcp__claude-code-remote__send_later": "message",
	"mcp__claude-code-remote__fire_trigger": "text",
}
# tools whose prompt runs as a main thread: every section
FULL = {"CronCreate", "mcp__claude-code-remote__create_session",
	"mcp__claude-code-remote__create_trigger", "mcp__claude-code-remote__update_trigger",
	"mcp__claude-code-remote__send_later", "mcp__claude-code-remote__fire_trigger"}
# tier -> top-level section numbers
TIERS = {"core": ("0", "1", "5"), "orchestrate": ("2",), "docs": ("3", "4", "6", "7")}
HEAD = "# Operating Instructions\n"
POINTER = ("\n(Sections not included here: %s. They are at the top of CLAUDE.md;"
	" read one only when this brief cites it.)\n")
# CLAUDE.md beside this hook's repo, so the hook works whatever the session's start folder
SRC = os.environ.get("PSS_OI_FILE") or os.path.join(
	os.path.dirname(os.path.abspath(__file__)), "..", "..", "CLAUDE.md")

def sections(doc):
	start = "<!-- operating-instructions:start -->\n"
	a = doc.index(start) + len(start)
	body = doc[a:doc.index("<!-- operating-instructions:end -->", a)]
	out = {}
	for m in re.finditer(r"^## (\d+)\. .*?(?=^## \d+\. |\Z)", body, re.M | re.S):
		out[m.group(1)] = m.group(0)
	return out

def main():
	ev = json.load(sys.stdin)
	tool = ev.get("tool_name", "")
	field = FIELDS.get(tool)
	inp = ev.get("tool_input") or {}
	text = inp.get(field) if field else None
	if not isinstance(text, str) or not text or text.startswith(HEAD):
		return
	with open(SRC, encoding="utf-8") as f:
		secs = sections(f.read())
	want = set(TIERS["core"])
	if tool in FULL or "[OI:full]" in text:
		want = set(secs)
	else:
		for tier in ("orchestrate", "docs"):
			if "[OI:%s]" % tier in text:
				want.update(TIERS[tier])
	keys = sorted(secs, key=int)
	prefix = HEAD + "\n" + "".join(secs[k] for k in keys if k in want)
	left = [k for k in keys if k not in want]
	if left:
		prefix += POINTER % ", ".join(left)
	inp = dict(inp)
	inp[field] = prefix + "\n---\n\n" + text
	json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": inp}}, sys.stdout)

main()
