#!/usr/bin/env python3
"""Context caps (DEC-00385): is what was written cheap for the next agent to read?

Caps: the CONTEXT-CAPS block of .claude/agents/consultant.md (#context-caps).

Usage:
  check_context.py                   startup and spawn sizes, then every file changed since the base
                                     (PSS_CTX_BASE, else HEAD^1 in CI, else merge-base with origin/main);
                                     only problems the base did not have fail
  check_context.py FILE...           every problem in these files fails (the ledger's SHAPE check)
  check_context.py --sizes           print the startup and spawn sizes, never fail
Exit 1 on a failing problem. Problems print as `SHAPE <path>: <problem>`.
"""
import fnmatch
import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CAPS_FILE = ROOT / ".claude" / "agents" / "consultant.md"
BLOCK = re.compile(r"<!-- CONTEXT-CAPS:BEGIN -->(.*?)<!-- CONTEXT-CAPS:END -->", re.S)
HEAD = re.compile(r"^#{2,3} ")
FENCE = re.compile(r"^\s*(```|~~~)")


def num(cell):
    cell = cell.strip()
    return None if cell in ("-", "") else int(cell)


def load_caps():
    m = BLOCK.search(CAPS_FILE.read_text())
    if not m:
        sys.exit(f"{CAPS_FILE}: CONTEXT-CAPS markers not found")
    rows = {}
    order = []
    for line in m.group(1).splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) != 6 or cells[0] in ("Kind", "") or set(cells[0]) <= set("-"):
            continue
        kind, paths, kb, sec, fence, header = cells
        row = {"kind": kind, "paths": re.findall(r"`([^`]+)`", paths), "kb": num(kb),
            "section": num(sec), "fence": num(fence), "header": header}
        rows[kind] = row
        order.append(row)
    return rows, order


def kind_of(path, order):
    p = path.replace(os.sep, "/")
    for row in order:
        if row["kind"] in ("startup", "spawn"):
            continue
        for g in row["paths"]:
            if fnmatch.fnmatchcase(p, g) or fnmatch.fnmatchcase("/" + p, g) or fnmatch.fnmatchcase(p, "*/" + g):
                return row
    return None


def problems(path, text, row):
    """Return {key: message}; the key ignores sizes so a ratchet can compare base and head."""
    out = {}
    if row is None or row["kind"] == "exempt":
        return out
    lines = text.split("\n")
    if any("generated" in l.lower() for l in lines[:5]):
        return out
    size = len(text.encode("utf-8"))
    if row["kb"] is not None and size > row["kb"] * 1024:
        out["size"] = f"{size} bytes > {row['kb']} KB ({row['kind']}): split it or point to the detail"
    if row["header"] == "yes" and not any(re.search(r"purpose", l, re.I) for l in lines[:12]):
        out["header"] = "no header block in the first 12 lines (Purpose · owner · status · related)"
    if row["header"] == "comment":
        body = [l for l in lines if l.strip()]
        if body and body[0].startswith("#!"):
            body = body[1:]
        first = body[0].lstrip() if body else ""
        if not first.startswith(("--", "#", "//", '"""')):
            out["header"] = "no header comment naming the file's role"
    if path.endswith(".md"):
        head, count, start, fence, fstart, infence = "(top)", 0, 1, 0, 0, False
        for i, l in enumerate(lines + ["## (end)"], 1):
            if FENCE.match(l):
                if infence and row["fence"] is not None and fence > row["fence"]:
                    out[f"fence:{head}"] = f"code block at line {fstart} has {fence} lines > {row['fence']}: point to the source instead"
                infence, fence, fstart = not infence, 0, i
                continue
            if infence:
                fence += 1
                count += 1
                continue
            if HEAD.match(l):
                if row["section"] is not None and count > row["section"] and head != "## Changelog":
                    out[f"section:{head}"] = f"section '{head}' (line {start}) has {count} lines > {row['section']}: split it"
                head, count, start = l.strip(), 0, i
            else:
                count += 1
        if infence and row["fence"] is not None and fence > row["fence"]:
            out[f"fence:{head}"] = f"code block at line {fstart} is never closed and has {fence} lines > {row['fence']}"
    return out


def git(*args):
    r = subprocess.run(["git", "-C", str(ROOT)] + list(args), capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def base_ref():
    ref = os.environ.get("PSS_CTX_BASE")
    if ref:
        return ref
    if os.environ.get("GITHUB_ACTIONS") and git("rev-parse", "--verify", "-q", "HEAD^1"):
        return "HEAD^1"
    if git("rev-parse", "--verify", "-q", "origin/main"):
        mb = git("merge-base", "HEAD", "origin/main")
        return mb.strip() if mb else None
    return None


def startup(rows):
    main = ROOT / "CLAUDE.md"
    text = main.read_text()
    files = [main] + [ROOT / m for m in re.findall(r"^@(\S+)", text, re.M)]
    total = sum(f.stat().st_size for f in files if f.exists())
    agents = sorted((f.stat().st_size, f.name) for f in (ROOT / ".claude" / "agents").glob("*.md"))
    big = agents[-1] if agents else (0, "-")
    out = [f"startup {total} bytes ({len(files)} files), spawn {total + big[0]} bytes (with {big[1]})"]
    bad = []
    for kind, size in (("startup", total), ("spawn", total + big[0])):
        cap = rows.get(kind, {}).get("kb")
        if cap is not None and size > cap * 1024:
            bad.append(f"SHAPE {kind}: {size} bytes > {cap} KB: move on-demand text out of CLAUDE.md or its imports (docs/pss/15_ROUTES.md)")
    return out, bad


def check_files(paths, order, base=None):
    bad = []
    for p in paths:
        f = pathlib.Path(p)
        full = f if f.is_absolute() else ROOT / f
        if not full.is_file():
            continue
        try:
            rel = full.resolve().relative_to(ROOT).as_posix()
        except ValueError:
            rel = full.resolve().as_posix()
        row = kind_of(rel, order)
        try:
            now = problems(rel, full.read_text(), row)
        except UnicodeDecodeError:
            continue
        if base is not None:
            old = git("show", f"{base}:{rel}")
            if old is not None:
                was = problems(rel, old, row)
                now = {k: v for k, v in now.items() if k not in was}
        bad += [f"SHAPE {rel}: {v}" for v in now.values()]
    return bad


def main():
    rows, order = load_caps()
    args = sys.argv[1:]
    info, bad = startup(rows)
    if args == ["--sizes"]:
        print("\n".join(info + bad))
        return 0
    if args:
        bad = check_files(args, order)
    else:
        base = base_ref()
        if base is None:
            print("check_context: NOTE no base ref (set PSS_CTX_BASE or fetch origin/main); changed files not checked")
            changed = []
        else:
            changed = (git("diff", "--name-only", "--diff-filter=AM", base) or "").split()
        bad += check_files(changed, order, base)
    if bad:
        print("\n".join(info + bad))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
