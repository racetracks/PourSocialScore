#!/usr/bin/env python3
"""Context caps (DEC-00385) and docs with code (DEC-00384): is what was written cheap for the next
agent to read, and does every code change carry its documentation? Code itself is never capped.

Caps: the CONTEXT-CAPS block of .claude/agents/consultant.md (#context-caps).

Usage:
  check_context.py                   startup and spawn sizes, then every file changed since the base
                                     (PSS_CTX_BASE, else HEAD^1 in CI, else merge-base with origin/main);
                                     only problems the base did not have fail
  check_context.py FILE...           every problem in these files fails (the ledger's SHAPE check)
  check_context.py --sizes           print the startup and spawn sizes, never fail
  check_context.py --brief M1|M2 [--index INDEX] FILE...
                                     the brief check, run by `ledger.py spawn`; prints `BRIEF <path>: <problem>`; rules:
                                     1 Writes line with backticked paths; 2 exact edit (path:line) or "by script" with
                                     Input:, Output:, Rule: lines; 3 one ## Acceptance with one code block and an
                                     Expected: line; 4 M1 "Permitted judgement: none" / M2 numbered ## Permitted
                                     judgement; 5 one line naming both rules files "in full"; 6 no hedge words
                                     (e.g., etc., as appropriate, consider, if needed); 7 no bare file reference
                                     (give path:line, path#anchor, Full or (new)); 8 with --index, every backticked
                                     path:n[-m] or path#anchor exists. Exit 2 on a usage error.
  check_context.py --index OUT       write the machine index (git ls-files: lines and heading anchors) to OUT as JSON
  check_context.py --lookup INDEX REF...
                                     REF is path, path:n, path:n-m or path#anchor; prints OK or MISSING <ref>: <why>
  Docs with code: in a file list, code and no document prints `DOCS`; against the base, changed code needs
  the build history entry of the TOC version to fill `- Docs updated:` (docs/pss/14_BUILD_HISTORY.md).
Exit 1 on a failing problem. Problems print as `SHAPE <path>: <problem>` or `DOCS <problem>`.
"""
import fnmatch
import hashlib
import json
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


HEDGE = re.compile(r"(?i)(?<!\w)(e\.g\.|etc\.|as appropriate|consider|if needed)(?!\w)")
WRITES = re.compile(r"(?m)^\s*[-*]?\s*(\*\*)?Writes\b[^:\n]*:.*`[^`]+`")
EDIT = re.compile(r"[\w./-]+\.[A-Za-z]+:\d+(-\d+)?")
BARE = re.compile(r"`([^`\s:#]+\.(md|py|lua|sh|json|txt|toc|xml|yml|yaml))`")
POINTER = re.compile(r"`([\w./-]+)(?::(\d+)(?:-(\d+))?|#([\w.-]+))`")
SKIP_PTR = ("specs/", "briefs/", "context/", "agents/", "prompts/", "../")
EXTS = (".md", ".py", ".lua", ".sh", ".toc", ".xml", ".json", ".txt", ".yml", ".yaml")


def label(name):
    return re.compile(r"(?i)^\s*[-*]?\s*(\*\*)?" + name + r"(\*\*)?:")


def brief_problems(text, cls, index=None):
    """Brief rules 1 to 8 (spec ledger-m1 7.7, 12.4); problems in rule order."""
    prose, sec, infence, nfence, expected, has_acc, judge = [], "", False, 0, False, False, False
    for n, l in enumerate(text.split("\n"), 1):
        if sec.startswith("## Acceptance") and l.startswith("Expected:"):
            expected = True
        if FENCE.match(l):
            if sec.startswith("## Acceptance") and not infence:
                nfence += 1
            infence = not infence
            continue
        if infence:
            continue
        if l.startswith("## "):
            sec = l.strip()
            has_acc = has_acc or sec.startswith("## Acceptance")
        if sec.lower().startswith("## permitted judgement") and re.match(r"\d+\. ", l):
            judge = True
        if not sec.startswith("## Changelog"):
            prose.append((n, l, sec))
    out = []
    if not WRITES.search(text):
        out.append("no Writes line (Writes, a colon, the fence paths in backticks)")
    byscript = any("by script" in l.lower() for _, l, _ in prose)
    lab = all(any(label(k).match(l) for _, l, _ in prose) for k in ("Input", "Output", "Rule"))
    if not any(EDIT.search(l) for _, l, _ in prose) and not (byscript and lab):
        out.append('no exact edit (path:line) and no "by script" with Input:, Output: and Rule: lines')
    if not has_acc:
        out.append("no ## Acceptance section")
    else:
        if nfence != 1:
            out.append(f"## Acceptance needs exactly one code block (found {nfence})")
        if not expected:
            out.append("## Acceptance has no Expected: line")
    if cls == "M1" and not re.search(r"(?i)permitted judgement\W*none\b", text):
        out.append('M1 brief needs the line "Permitted judgement: none"')
    if cls == "M2" and not judge:
        out.append('M2 brief needs a "## Permitted judgement" section with a numbered list')
    if not any(all(k in l.lower() for k in ("docs/baseline/02_rules.md", "docs/pss/02_rules.md", "in full"))
               for l in text.split("\n")):
        out.append("no rules read: one line naming docs/baseline/02_RULES.md and docs/pss/02_RULES.md in full")
    for n, l, _ in prose:
        for m in HEDGE.finditer(l):
            out.append(f'line {n}: hedge word "{m.group(0).lower()}"')
    for n, l, s in prose:
        if (s.startswith(("## Acceptance", "## Docs")) or l.lstrip().startswith("|") or WRITES.search(l)
                or "in full" in l.lower() or re.search(r"\bFull\b", l) or "(new)" in l):
            continue
        for m in BARE.finditer(l):
            out.append(f"line {n}: bare file reference {m.group(0)}: give path:line or path#anchor, or mark it Full or (new)")
    if index:
        for n, l, _ in prose:
            for m in POINTER.finditer(l):
                if m.group(1).startswith(SKIP_PTR):
                    continue
                why = lookup_ref(index, m.group(0)[1:-1])
                if why:
                    out.append(f"line {n}: pointer {m.group(0)[1:-1]}: {why}")
    return out


def slug(h):
    return re.sub(r"[^\w -]", "", h.strip().lower()).replace(" ", "-")


def build_index(out):
    ls, head = git("ls-files"), git("rev-parse", "HEAD")
    if ls is None or head is None:
        print("check_context: git ls-files failed", file=sys.stderr)
        return 1
    files, keys = {}, []
    for rel in sorted(ls.split("\n")):
        if not rel.endswith(EXTS):
            continue
        try:
            text = (ROOT / rel).read_text(errors="replace")
        except OSError:
            continue
        n = text.count("\n") + (1 if text and not text.endswith("\n") else 0)
        anchors, fence = [], False
        if rel.endswith(".md"):
            for l in text.split("\n"):
                if FENCE.match(l):
                    fence = not fence
                m = re.match(r"#{1,6} +(.*)", l)
                if m and not fence:
                    anchors.append(slug(m.group(1)))
        files[rel] = {"lines": n, "anchors": anchors}
        keys.append(f"{rel}:{n}:{','.join(anchors)}")
    h = hashlib.sha256("\n".join(sorted(keys)).encode()).hexdigest()[:12]
    data = json.dumps({"base": head.strip(), "hash": h, "files": files}, sort_keys=True)
    o = pathlib.Path(out)
    if not o.exists() or o.read_text() != data:  # unchanged index is not rewritten (scope fence of parallel agents)
        o.parent.mkdir(parents=True, exist_ok=True)
        o.write_text(data)
    print(f"index: {len(files)} files \u00b7 hash {h}")
    return 0


def lookup_ref(index, ref):
    """None when ref resolves in the index dict, else the reason."""
    m = re.fullmatch(r"([^:#]+)(?::(\d+)(?:-(\d+))?|#(.+))?", ref)
    if not m:
        return "no file"
    files = index["files"]
    path = m.group(1) if m.group(1) in files else None
    if path is None:
        c = [p for p in files if p.endswith("/" + m.group(1))]
        path = c[0] if len(c) == 1 else None
    if path is None:
        return "no file"
    f = files[path]
    if m.group(2):
        x = max(int(m.group(2)), int(m.group(3) or 0))
        if x > f["lines"]:
            return f"line {x} > {f['lines']}"
    if m.group(4) and m.group(4).lower() not in f["anchors"]:
        return "no anchor"
    return None


def cli_brief(args):
    idx, rest, i = None, [], 1
    while i < len(args):
        if args[i] == "--index" and i + 1 < len(args):
            idx = json.loads(pathlib.Path(args[i + 1]).read_text())
            i += 2
        else:
            rest.append(args[i])
            i += 1
    if not rest or rest[0] not in ("M1", "M2") or len(rest) < 2:
        print("usage: check_context.py --brief M1|M2 [--index INDEX] FILE...", file=sys.stderr)
        return 2
    bad = [f"BRIEF {rel_of(f)}: {p}" for f in rest[1:] for p in brief_problems(pathlib.Path(f).read_text(), rest[0], idx)]
    if bad:
        print("\n".join(bad))
    return 1 if bad else 0


def cli_lookup(args):
    if len(args) < 3:
        print("usage: check_context.py --lookup INDEX REF...", file=sys.stderr)
        return 2
    idx, bad = json.loads(pathlib.Path(args[1]).read_text()), False
    for ref in args[2:]:
        why = lookup_ref(idx, ref)
        bad = bad or bool(why)
        print(f"MISSING {ref}: {why}" if why else f"OK {ref}")
    return 1 if bad else 0


CODE = ("PourSocialScore*/*.lua", "PourSocialScore*/*.xml", "tools/*", ".claude/scripts/*", ".github/workflows/*")
HIST = ROOT / "docs" / "pss" / "14_BUILD_HISTORY.md"


def is_code(rel):
    return any(fnmatch.fnmatchcase(rel, g) for g in CODE) and not rel.endswith((".md", ".toc"))


def rel_of(p):
    full = pathlib.Path(p) if pathlib.Path(p).is_absolute() else ROOT / p
    try:
        return full.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return full.resolve().as_posix()


def docs_in_list(paths):
    """A return that changed code and no document."""
    rels = [rel_of(p) for p in paths]
    code = [r for r in rels if is_code(r)]
    if code and not any(r.endswith(".md") for r in rels):
        return [f"DOCS code changed with no documentation ({', '.join(code[:5])}): update the docs the brief names (code map, feature documents)"]
    return []


def docs_in_history(changed):
    """A PR that changed code: the build history entry of the TOC version names the docs updated."""
    code = [r for r in changed if is_code(r)]
    if not code or not HIST.exists():
        return []
    toc = ROOT / "PourSocialScore" / "PourSocialScore.toc"
    m = re.search(r"^## Version: *(\S+)", toc.read_text(), re.M) if toc.exists() else None
    if not m:
        return []
    ver = m.group(1)
    text = HIST.read_text()
    e = re.search(r"^### " + re.escape(ver) + r" .*?(?=^### |\Z)", text, re.M | re.S)
    d = re.search(r"^- Docs updated: *(.*)$", e.group(0), re.M) if e else None
    if not d or "written in the PR" in d.group(1) or not re.search(r"\]\(|`", d.group(1)):
        return [f"DOCS {ver} changes code ({', '.join(code[:5])}) but its build history entry has no filled `- Docs updated:` line naming the documents changed ({HIST.relative_to(ROOT)})"]
    return []


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
    args = sys.argv[1:]
    if args[:1] == ["--brief"]:
        return cli_brief(args)
    if args[:1] == ["--lookup"]:
        return cli_lookup(args)
    if args[:1] == ["--index"]:
        return build_index(args[1]) if len(args) == 2 else 2
    rows, order = load_caps()
    info, bad = startup(rows)
    if args == ["--sizes"]:
        print("\n".join(info + bad))
        return 0
    if args:
        bad = check_files(args, order) + docs_in_list(args)
    else:
        base = base_ref()
        if base is None:
            print("check_context: NOTE no base ref (set PSS_CTX_BASE or fetch origin/main); changed files not checked")
            changed = []
        else:
            changed = (git("diff", "--name-only", "--diff-filter=AM", base) or "").split()
        bad += check_files(changed, order, base) + docs_in_history(changed)
    if bad:
        print("\n".join(info + bad))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
