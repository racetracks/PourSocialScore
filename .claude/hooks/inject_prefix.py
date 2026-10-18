#!/usr/bin/env python3
"""PreToolUse hook: prefix the author's prompt (the Operating Instructions), verbatim,
to every prompt handed to a sub-agent, thread, session or scheduled task.
It lives once, at the top of CLAUDE.md, between the operating-instructions markers. Idempotent: a prompt that already starts with the text is left alone."""
import json, os, sys

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
SRC = os.environ.get("PSS_OI_FILE") or os.path.join(
	os.environ.get("CLAUDE_PROJECT_DIR", "."), "CLAUDE.md")
PARTS = ("operating-instructions",)

def part(doc, name):
	start = "<!-- %s:start -->\n" % name
	a = doc.index(start) + len(start)
	return doc[a:doc.index("<!-- %s:end -->" % name, a)]

def main():
	ev = json.load(sys.stdin)
	field = FIELDS.get(ev.get("tool_name", ""))
	inp = ev.get("tool_input") or {}
	text = inp.get(field) if field else None
	if not isinstance(text, str) or not text:
		return
	with open(SRC, encoding="utf-8") as f:
		doc = f.read()
	prefix = "\n".join(part(doc, n) for n in PARTS)
	if text.startswith(prefix):
		return
	inp = dict(inp)
	inp[field] = prefix + "\n---\n\n" + text
	json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse", "updatedInput": inp}}, sys.stdout)

main()
