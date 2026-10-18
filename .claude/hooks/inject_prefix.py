#!/usr/bin/env python3
"""Hooks that hand the author's rules to sub-agents and threads, and enforce them.
One source: CLAUDE.md (the Operating Instructions between the operating-instructions
markers, and the "Requirements for every interaction with the AI" section), copied verbatim.

  start   SubagentStart: the executor and planner agents (omitClaudeMd) get their tier
          of the Operating Instructions plus the requirements section as context.
  brief   PreToolUse on Agent: blocks a brief that names no lean agent type or lacks
          the fields of Operating Instructions 2.8 and 2.10.
  stop    SubagentStop: sends an executor or planner back once if its reply is over
          5 lines (Operating Instructions 5.2).
  prefix  PreToolUse on tools that start a session or a scheduled run: prefixes every
          section and the requirements section to the prompt (idempotent)."""
import json, os, re, sys

SRC = os.environ.get("PSS_OI_FILE") or os.path.join(
	os.path.dirname(os.path.abspath(__file__)), "..", "..", "CLAUDE.md")
HEAD = "# Operating Instructions\n"
REQ = "## Requirements for every interaction with the AI"
# agent type -> top-level sections of the Operating Instructions
TIERS = {"executor": ("0", "1", "5"), "planner": ("0", "1", "2", "3", "4", "5", "6", "7")}
# agent types allowed to be spawned: our two, and the read-only built-ins (no CLAUDE.md)
ALLOWED = set(TIERS) | {"Explore", "Plan", "claude-code-guide", "statusline-setup"}
FIELDS = ("Role", "Scope", "Class", "Acceptance", "Budget", "Context")
# tool name -> the input field that carries the prompt (prefix mode)
PROMPTS = {
	"CronCreate": "prompt",
	"mcp__claude-code-remote__send_message": "message",
	"mcp__claude-code-remote__create_session": "prompt",
	"mcp__claude-code-remote__create_trigger": "prompt",
	"mcp__claude-code-remote__update_trigger": "prompt",
	"mcp__claude-code-remote__send_later": "message",
	"mcp__claude-code-remote__fire_trigger": "text",
}

def load():
	with open(SRC, encoding="utf-8") as f:
		doc = f.read()
	start = "<!-- operating-instructions:start -->\n"
	a = doc.index(start) + len(start)
	body = doc[a:doc.index("<!-- operating-instructions:end -->", a)]
	secs = {}
	for m in re.finditer(r"^## (\d+)\. .*?(?=^## \d+\. |\Z)", body, re.M | re.S):
		secs[m.group(1)] = m.group(0)
	r = doc.index(REQ)
	req = doc[r:doc.index("\nThree packs", r)].rstrip() + "\n"
	return secs, req

def rules(want):
	secs, req = load()
	keys = sorted(secs, key=int)
	out = HEAD + "\n" + "".join(secs[k] for k in keys if k in want)
	left = [k for k in keys if k not in want]
	if left:
		out += ("\n(Sections not included here: %s. They are at the top of CLAUDE.md;"
			" read one only when your brief cites it.)\n" % ", ".join(left))
	return out + "\n" + req

def emit(event, **kw):
	json.dump({"hookSpecificOutput": dict(hookEventName=event, **kw)}, sys.stdout)

def start(ev):
	want = TIERS.get(ev.get("agent_type", ""))
	if want:
		emit("SubagentStart", additionalContext=rules(set(want)))

def brief(ev):
	inp = ev.get("tool_input") or {}
	kind = inp.get("subagent_type") or "general-purpose"
	text = inp.get("prompt") or ""
	why = []
	if kind not in ALLOWED:
		why.append("subagent_type %r loads CLAUDE.md and its imports (about 60k tokens);"
			" use executor (M1, M2) or planner (M3) (Operating Instructions 2.6)" % kind)
	elif kind in TIERS:
		miss = [f for f in FIELDS if not re.search(r"(?im)^\W*%s\s*:" % f, text)]
		if miss:
			why.append("the brief lacks %s: lines (Operating Instructions 2.8, 2.10;"
				" Context: is the session context file path)" % ": , ".join(miss))
		m = re.search(r"(?im)^\W*Class\s*:\s*(M[123])", text)
		if kind == "executor" and m and m.group(1) == "M3":
			why.append("an M3 task goes to the planner, not the executor (2.5)")
	if why:
		sys.stderr.write("Brief refused: " + "; ".join(why) + ".\n")
		sys.exit(2)

def stop(ev):
	if ev.get("agent_type") not in TIERS or ev.get("stop_hook_active"):
		return
	msg = ev.get("last_assistant_message") or ""
	n = len([l for l in msg.splitlines() if l.strip()])
	if n > 5:
		json.dump({"decision": "block", "reason": "Your reply has %d lines; return at most 5"
			" and keep the detail in your report under agents/<agent-id>/"
			" (Operating Instructions 5.2)." % n}, sys.stdout)

def prefix(ev):
	field = PROMPTS.get(ev.get("tool_name", ""))
	inp = ev.get("tool_input") or {}
	text = inp.get(field) if field else None
	if not isinstance(text, str) or not text or text.startswith(HEAD):
		return
	inp = dict(inp)
	inp[field] = rules(set(TIERS["planner"])) + "\n---\n\n" + text
	emit("PreToolUse", updatedInput=inp)

def main():
	mode = sys.argv[1] if len(sys.argv) > 1 else "prefix"
	{"start": start, "brief": brief, "stop": stop, "prefix": prefix}[mode](json.load(sys.stdin))

main()
