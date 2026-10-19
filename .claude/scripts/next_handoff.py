#!/usr/bin/env python3
"""Next-session handoff (DEC-00398): print it at session start, check its shape before a delivery.

The file lives only on scratch: `.next/NEXT.md` (newest of any session) and
`temp/<YYYY>/<MM>/<DD>/<hh-mm-ss>-<Ddd>-<name>/.next/NEXT.md` (each session's latest).
Format: scratch `.next/README.md#format`.

Usage:
  next_handoff.py start          SessionStart hook (.claude/settings.json): prints the root NEXT.md and the
                                 other sessions' handoffs from the last 24 h (## Parallel); never fails
  next_handoff.py check [FILE]   shape of FILE, else of this session's handoff; prints `NEXT <path>: <problem>`;
                                 exit 1 on a problem. Run by check_context.py outside CI.
Scratch checkout: PSS_SCRATCH, else ../Pour-Social-Score_Scratch beside this repo.
This session's temp root: PSS_TEMP_ROOT, else the root named after the checked-out branch (without claude/).
Roots created before RULE_FROM have no handoff and are not checked.
"""
import os
import pathlib
import re
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
SECTIONS = ["Prompt", "State", "Done", "Next", "Open", "Pitfalls", "Parallel"]
CAP = 60
RULE_FROM = "2026/10/19/11-01-05"
HEAD_RX = re.compile(r"^from (\S+) · (\d{4}-\d{2}-\d{2} \d{2}:\d{2}) UTC · status (ready|blocked|waiting)(?: \([^)]*\))? · temp root ")


def scratch():
    p = pathlib.Path(os.environ.get("PSS_SCRATCH") or ROOT.parent / "Pour-Social-Score_Scratch")
    return p if (p / ".next").is_dir() else None


def problems(path):
    if not path.is_file():
        return ["missing"]
    lines = path.read_text(encoding="utf-8").split("\n")
    bad = []
    if len(lines) > CAP + 1:
        bad.append(f"{len(lines) - 1} lines, cap {CAP}")
    if not lines[0].startswith("# NEXT: "):
        bad.append("line 1 is not `# NEXT: <step>`")
    if len(lines) < 3 or not HEAD_RX.match(lines[2]):
        bad.append("line 3 is not `from <session> · <YYYY-MM-DD hh:mm> UTC · status <ready|blocked|waiting> [(why)] · temp root <link>`")
    heads = [l[3:].strip() for l in lines if l.startswith("## ")]
    if heads != SECTIONS:
        bad.append(f"sections {heads}, want {SECTIONS}")
    return bad


def own_handoff(sc):
    env = os.environ.get("PSS_TEMP_ROOT")
    if env:
        return pathlib.Path(env) / ".next" / "NEXT.md"
    r = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True)
    name = r.stdout.strip().replace("claude/", "", 1)
    roots = sorted(sc.glob(f"temp/*/*/*/*-{name}")) if name and name != "HEAD" else []
    roots = [d for d in roots if d.relative_to(sc / "temp").as_posix()[:19] >= RULE_FROM]
    return roots[-1] / ".next" / "NEXT.md" if roots else None


def cli_check(args):
    sc = scratch()
    if args:
        paths = [pathlib.Path(args[0])]
    elif sc is None:
        print("next_handoff: NOTE no scratch checkout (set PSS_SCRATCH); handoff not checked")
        return 0
    else:
        own = own_handoff(sc)
        paths = [sc / ".next" / "NEXT.md"] + ([own] if own else [])
    bad = [f"NEXT {p}: {b}" for p in paths for b in problems(p)]
    if bad:
        print("\n".join(bad))
        return 1
    return 0


def cli_start():
    sc = scratch()
    if sc is None:
        print("Next-session handoff: no scratch checkout found; read scratch .next/NEXT.md after the pull (DEC-00398).")
        return 0
    root = sc / ".next" / "NEXT.md"
    text = root.read_text(encoding="utf-8") if root.is_file() else ""
    m = HEAD_RX.match((text.split("\n") + ["", "", ""])[2])
    newest = m.group(1) if m else ""
    cutoff = time.strftime("%Y-%m-%d %H:%M", time.gmtime(time.time() - 86400))
    others = []
    for p in sc.glob("temp/*/*/*/*/.next/NEXT.md"):
        lines = p.read_text(encoding="utf-8").split("\n")
        h = HEAD_RX.match(lines[2]) if len(lines) > 2 else None
        if h and h.group(1) != newest and h.group(2) >= cutoff:
            others.append((h.group(2), h.group(1), lines[0][8:], p.relative_to(sc).as_posix()))
    print("Next-session handoff (DEC-00398), scratch .next/NEXT.md, printed by the SessionStart hook; "
          "pull scratch before acting on it, the author's prompt wins:\n")
    print(text or "(none yet)")
    print("## Parallel (other handoffs, last 24 h; copy into your NEXT.md ## Parallel)")
    for row in sorted(others, reverse=True):
        print("- %s UTC · %s · %s · scratch:%s" % row)
    if not others:
        print("None")
    return 0


def main():
    args = sys.argv[1:]
    if args[:1] == ["start"]:
        try:
            return cli_start()
        except Exception as e:
            print(f"next_handoff: start failed ({e}); read scratch .next/NEXT.md yourself")
            return 0
    if args[:1] == ["check"]:
        return cli_check(args[1:])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
