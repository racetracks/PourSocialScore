#!/usr/bin/env python3
"""Session ledger: the coordinator's only bookkeeping tool. Output is terse; each line is an instruction.

  ledger.py init                         load provision.md + TASK.md direct tasks; validate; print totals
  ledger.py spawn TASKS [--reuse AID]    gate, allocate agent ID, snapshot repo, print the spawn line
  ledger.py cont AID [--support|--review] [--add-calls N --add-out N --reason TEXT]
  ledger.py ret AID "<return line 1>" "<return line 3: spend: calls a/b · out c/d>" [--failed]
  ledger.py done TASKS                   mark coordinator-inline tasks done
  ledger.py next                         ready tasks, grouped for batching, plus totals
  ledger.py decide "<one line>" [PATH]   append a decision to CONTEXT.md
  ledger.py pack PROJECT                 hand-off check of <session>/projects/PROJECT/, then write its pack.json and README.md
  ledger.py init --pack DIR [--draft]    load an approved pack (documents/projects/<project>/) into a fresh session;
                                         --draft: dry run of a <session>/projects/<project>/ folder under temp/
  ledger.py promote DRAFT                copy a drafted pack to documents/projects/<project>/ (the author's OK only)
  ledger.py render                       measure tokens from transcripts, regenerate the session README.md
  ledger.py close                        render, mark the session closed

TASKS is comma-separated. TRIAGE is a built-in task for the triage consultant.
Budget defaults: .claude/agents/consultant.md (BUDGETS block). Scope fence: provision.md Writes column.
Re-run: an engineer-m1 task that returns BLOCKED/BUDGET (or DONE with --failed) is re-run once on engineer (Sonnet).
Shape: ret runs check_context.py (CONTEXT-CAPS block; code needs its docs) on the files a DONE return changed.
Stale pack: init compares each new row's Writes with `git diff --name-only <Base commit>` of provision.md: RETRIAGE (status stale),
  WARN when the base is not in the clone, NOTE when the `Index hash:` differs; init and spawn rebuild context/repo-index.json.
Brief check: spawn runs check_context.py --brief on each M1/M2 engineer brief; BRIEF lines refuse the spawn (ROUTE to its consultant).
Pointers: ret runs check_context.py --pointers on a consultant's DONE specs/ and context/ files; POINTER lines block it.
Plan pack: pack checks the draft (briefs, context, caps, ## Changelog, registry keys, pointers) and refuses with HANDOFF refused;
  spawn lines for consultants carry `index <hash>` after `base`.
Rules read: ret reads an engineer's transcript; RULES (ROUTE cont) when docs/baseline/02_RULES.md or docs/pss/02_RULES.md was not
  read in full, WARN RULES when unmeasured (never a pass).
"""
import argparse
import fnmatch
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _session  # noqa: E402

ROOT = _session.ROOT
AGENTS = ("coordinator", "consultant", "engineer", "engineer-m1", "engineer-m3")
NONE = {"", "-", "—", "n/a", "none"}
PROTECTED = ("provision.md", "specs/", "briefs/", "context/", "projects/")  # session paths only consultants write
IGNORE = {".claude/.session"}
FIT_RULES = {  # consultant K0: the grade decides class and agent
    "engineer": lambda f, c: (f, c) in (("WL", "M1"), ("WM", "M2")),
    "engineer-m1": lambda f, c: (f, c) == ("WL", "M1"),
    "engineer-m3": lambda f, c: f == "WH" and c == "M3",
    "consultant": lambda f, c: (f[0] in "PU" or f[1] == "H") and c == "M3",
}
FIT_HINT = {"engineer": "engineer takes WL as M1 or WM as M2",
            "engineer-m1": "engineer-m1 takes WL as M1 only",
            "engineer-m3": "engineer-m3 takes WH only",
            "consultant": "consultant takes P*, U* or *H; WL/WM go to an engineer"}
SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "__pycache__", ".pytest_cache", ".mypy_cache",
             ".tox", "dist", "build", ".next", ".cache"}
PRICES = {  # USD per million tokens: (input, output); cache read 0.1x, cache write 1.25x input (assumption)
    "opus": (4.00, 20.00),
    "sonnet": (2.00, 10.00),
    "haiku": (0.10, 0.50),
}
PRICES_LONG = {"haiku": (0.50, 2.50)}  # one message whose prompt tokens exceed LONG_AT
LONG_AT = 100_000
RULES_FILES = ("docs/baseline/02_RULES.md", "docs/pss/02_RULES.md")
RULE_KINDS = ("engineer", "engineer-m1", "engineer-m3")
SD = None
LEDGER = None


def die(msg):
    print(msg)
    sys.exit(1)


# ---------- parsing ----------
def md_table(text, must):
    """First markdown table whose header holds every column in `must` -> list of row dicts (lower-case keys)."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if not line.strip().startswith("|"):
            continue
        hdr = [c.strip().lower() for c in line.strip().strip("|").split("|")]
        if all(m in hdr for m in must):
            rows = []
            for r in lines[i + 2:]:
                if not r.strip().startswith("|"):
                    break
                cells = [c.strip() for c in r.strip().strip("|").split("|")]
                if any(c for c in cells):
                    rows.append(dict(zip(hdr, cells)))
            return rows
    return None


def split(cell):
    return [x.strip().strip("`") for x in re.split(r"[;,]", cell or "") if x.strip().strip("`").lower() not in NONE]


def defaults():
    t = (ROOT / ".claude" / "agents" / "consultant.md").read_text()
    m = re.search(r"<!-- BUDGETS:BEGIN -->(.*?)<!-- BUDGETS:END -->", t, re.S)
    rows = md_table(m.group(1), ["key", "calls", "out"]) if m else None
    if not rows:
        die("consultant.md: BUDGETS block missing")
    return {r["key"].strip("`"): (int(r["calls"]), int(r["out"])) for r in rows}


def task_md():
    p = ROOT / "TASK.md"
    return p.read_text() if p.exists() else ""


def task_meta():
    t = task_md()
    cap = {}
    m = re.search(r"Budget cap[^\n]*", t)
    if m:
        for k in ("calls", "out"):
            mm = re.search(k + r"\D{0,3}(\d+)", m.group(0))
            if mm:
                cap[k] = int(mm.group(1))
    m = re.search(r"Reference prefix[ \t:*]*([A-Za-z0-9_-]+)", t)
    return cap, (m.group(1) if m else "REF")


def ref_index():
    m = re.search(r"Reference index[ \t:*]*([^\s(][^\n]*)", task_md())
    return m.group(1).strip() if m else ""


def model_of(agent):
    if agent == "coordinator":
        return "session"
    f = ROOT / ".claude" / "agents" / f"{agent}.md"
    m = re.search(r"^model:\s*(\S+)", f.read_text(), re.M) if f.exists() else None
    return m.group(1) if m else "?"


def budget_key(agent, cls):
    if agent == "consultant":
        return "consultant"
    if agent == "engineer":
        return "engineer-" + cls if cls in ("M1", "M2") else None
    if agent == "engineer-m1":
        return "engineer-m1"
    if agent == "engineer-m3":
        return "engineer-m3"
    return None


# ---------- ledger io ----------
def fresh():
    return {"tasks": {}, "agents": {}, "streams": {}, "triage": None, "next_agent": 1,
            "cap": {}, "prefix": "REF"}


def load():
    if LEDGER.exists():
        return json.loads(LEDGER.read_text())
    return fresh()


def save(L):
    LEDGER.write_text(json.dumps(L, indent=1))


def new_task(**kw):
    t = dict(cls="", fit="-", agent="", stream="", brief="", writes=[], calls=0, out=0, depends=[],
             review=False, why="", status="todo", agent_ids=[], blocks=0)
    t.update(kw)
    return t


def spent_total(L):
    c = sum(a["spent"][0] for a in L["agents"].values())
    o = sum(a["spent"][1] for a in L["agents"].values())
    return c, o


def projected(L):
    c, o = spent_total(L)
    for t in L["tasks"].values():
        if t["status"] == "todo":
            c += t["calls"]
            o += t["out"]
    return c, o


def cap_hit(L, c, o):
    cap = L.get("cap") or {}
    return (cap.get("calls") and c >= cap["calls"]) or (cap.get("out") and o >= cap["out"])


def capstr(L):
    cap = L.get("cap") or {}
    return f" (cap calls {cap.get('calls', '-')} out {cap.get('out', '-')})" if cap else ""


# ---------- scope fence ----------
def sig(p):
    try:
        s = (ROOT / p).stat()
        return [s.st_mtime_ns, s.st_size]
    except OSError:
        return None


def skipped(p):
    return p in IGNORE or "__pycache__/" in p


def walk(base):
    out = {}
    for dp, dns, fns in os.walk(base):
        dns[:] = [d for d in dns if d not in SKIP_DIRS and d != ".scope"]
        for f in fns:
            p = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/")
            if not skipped(p):
                out[p] = sig(p)
    return out


def snapshot():
    """Dirty repo files (git) or the whole tree (no git), plus the session directory, which may be git-ignored."""
    snap = walk(SD)
    if (ROOT / ".git").exists():
        r = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain", "-z", "--untracked-files=all"],
                           capture_output=True, text=True)
        if r.returncode == 0:
            paths, toks, i = [], r.stdout.split("\0"), 0
            while i < len(toks):
                tok = toks[i]
                i += 1
                if len(tok) < 4:
                    continue
                paths.append(tok[3:])
                if tok[0] in "RC":
                    i += 1  # skip rename/copy source path
            snap.update({p: sig(p) for p in paths if not skipped(p)})
            return snap
    snap.update(walk(ROOT))
    return snap


def changed_since(snap):
    now = snapshot()
    ch = {p for p in now if snap.get(p, "absent") != now[p]}
    ch |= {p for p in snap if p not in now and sig(p) != snap[p]}  # a mid-run commit is not a change
    return sorted(ch)


def allowed(path, kind, writes):
    srel = _session.rel(SD)
    if path in IGNORE:
        return True
    if path.startswith(srel + "/"):
        inner = path[len(srel) + 1:]
        if kind == "consultant":
            return True
        return not any(inner == p or (p.endswith("/") and inner.startswith(p)) for p in PROTECTED)
    if kind in ("consultant", "coordinator"):
        return False
    return any(fnmatch.fnmatchcase(path, g) for g in writes)


def shape_check(paths):
    """Context caps (consultant.md#context-caps, DEC-00385) and docs with code (DEC-00384) on a return's files."""
    tool = ROOT / ".claude" / "scripts" / "check_context.py"
    files = [str(ROOT / p) for p in paths if (ROOT / p).is_file()]
    if not tool.exists() or not files:
        return []
    r = subprocess.run([sys.executable, str(tool)] + files, capture_output=True, text=True)
    return [l for l in r.stdout.splitlines()
            if l.startswith(("SHAPE ", "DOCS ")) and not l.startswith(("SHAPE startup", "SHAPE spawn"))]


def pointer_lines(files, idx=None):
    """`POINTER ` lines of check_context.py --pointers over existing files (spec plan-pack 7.4.3); [] when no index."""
    files = [f for f in files if os.path.isfile(f)]
    if not files:
        return []
    if idx is None:
        idx, _ = build_index()
    if not idx:
        return []
    tool = ROOT / ".claude" / "scripts" / "check_context.py"
    r = subprocess.run([sys.executable, str(tool), "--pointers", str(idx)] + files, capture_output=True, text=True)
    return [l for l in r.stdout.splitlines() if l.startswith("POINTER ")]


def own_paths(L, aid, kind, changed, tasks=None):
    """The agent's own changed paths: its fence, its agents/<aid>/ folder, a consultant's session documents."""
    srel = _session.rel(SD)
    ws = [w for t in (tasks if tasks is not None else L["agents"][aid]["tasks"]) for w in L["tasks"].get(t, {}).get("writes", [])]
    pre = [f"{srel}/{d}" for d in ("specs/", "briefs/", "context/", "projects/")] if kind == "consultant" else []

    def mine(p):
        return (any(fnmatch.fnmatchcase(p, g) for g in ws) or p.startswith(f"{srel}/agents/{aid}/")
                or (kind == "consultant" and (p == f"{srel}/provision.md" or any(p.startswith(x) for x in pre))))
    return [p for p in changed if mine(p)]


def agent_writes(L, aid):
    ws = []
    for t in L["agents"][aid]["tasks"]:
        ws += L["tasks"].get(t, {}).get("writes", [])
    return ws


def build_index():
    """Rebuild <SD>/context/repo-index.json; return (path, hash) or (None, None) after a WARN."""
    idx = SD / "context" / "repo-index.json"
    tool = ROOT / ".claude" / "scripts" / "check_context.py"
    r = subprocess.run([sys.executable, str(tool), "--index", str(idx)], capture_output=True, text=True)
    m = re.search(r"hash ([0-9a-f]{12})", r.stdout)
    if r.returncode != 0 or not m:
        err = (r.stderr.strip().splitlines() or r.stdout.strip().splitlines() or ["failed"])[-1]
        print(f"WARN index not built: {err}")
        return None, None
    return idx, m.group(1)


def stale_check(L, new, prov_text):
    """Spec ledger-m1 7.6: new rows whose Writes changed since the pack's Base commit become stale."""
    m = re.search(r"(?m)^Base commit:\s*`?([0-9a-f]{7,40})`?\s*$", prov_text)
    if not m:
        return
    base = m.group(1)
    g = ["git", "-C", str(ROOT)]
    if subprocess.run(g + ["cat-file", "-e", base + "^{commit}"], capture_output=True).returncode != 0:
        print(f"WARN stale-plan check skipped: base {base} not in this clone (git fetch --depth=2000 origin main, then init)")
        return
    changed = subprocess.run(g + ["diff", "--name-only", base], capture_output=True, text=True).stdout.split("\n")
    triage = L.get("triage") or "the triage consultant"
    for t, nt in new.items():
        if t in L["tasks"] or nt["agent"] in ("consultant", "coordinator"):
            continue
        hit = sorted(p for p in changed if p and any(fnmatch.fnmatchcase(p, w) for w in nt["writes"]))
        if hit:
            nt["status"] = "stale"
            more = " \u2026" if len(hit) > 5 else ""
            print(f"RETRIAGE {t}: fence changed since pack base {base}: {', '.join(hit[:5])}{more}; "
                  f"`cont {triage} --support` to re-check its brief, then `init`")


# ---------- commands ----------
def load_rows(L, D, rows):
    """Validate provision-style rows (dicts, lower-case keys) -> (errors, new task records). Spec plan-pack 7.5.1."""
    ids = {r["task"] for r in rows}
    errs, new = [], {}
    for r in rows:
        t = r["task"]
        ag = r.get("agent", "").strip("`").lower()
        cl = r.get("class", "").strip("`").upper()
        writes = split(r.get("writes"))
        brief = "" if r.get("brief", "").strip().lower() in NONE else r["brief"].strip().strip("`")
        why = "" if r.get("why", "").strip().lower() in NONE else r["why"].strip()
        deps = split(r.get("depends"))
        fit = r.get("fit", "").strip("` ").upper()
        e = lambda m, t=t: errs.append(f"{t}: {m}")
        if ag == "coordinator":
            if fit not in ("", "-"):
                e("coordinator rows take Fit '-'")
        elif not re.fullmatch(r"[WPU][LMH]", fit):
            e("Fit must be scope W/P/U + complexity L/M/H (consultant K0)")
        else:
            want = FIT_RULES.get(ag)
            if want and not want(fit, cl):
                e(f"Fit {fit} does not allow {ag} {cl} ({FIT_HINT[ag]})")
        try:
            calls, out = int(r.get("calls") or 0), int(r.get("out") or 0)
        except ValueError:
            e("Calls and Out must be integers")
            calls = out = 0
        if t in new:
            e("duplicate task ID")
        if "_acc" in r and r["_acc"].strip().lower() in NONE:
            e("direct task needs an Acceptance command")
        for d in deps:
            if d not in ids and d not in L["tasks"]:
                e(f"unknown dependency {d}")
        if ag not in AGENTS:
            e(f"Agent must be one of {', '.join(AGENTS)}")
        elif ag == "coordinator":
            if writes:
                e("coordinator never writes outside the session: provision an engineer")
        elif ag == "consultant":
            if cl != "M3":
                e("consultant rows are M3")
            if writes:
                e("consultants write session files only: Writes must be '-'")
        else:
            if not writes:
                e("Writes fence required")
            if not brief:
                e("Brief path required")
            if ag == "engineer" and cl not in ("M1", "M2"):
                e("engineer rows are M1/M2; M3 implementation needs engineer-m3 via consultant K5")
            if ag == "engineer-m1" and cl != "M1":
                e("engineer-m1 rows are M1")
            if ag == "engineer-m3":
                if cl != "M3":
                    e("engineer-m3 rows are M3")
                if not why:
                    e("engineer-m3 needs Why (consultant K5: all three conditions)")
                if len(writes) > 3 or any(ch in w for w in writes for ch in "*?["):
                    e("engineer-m3 fence must be <=3 exact paths, no globs")
        key = budget_key(ag, cl)
        if key:
            if key not in D:
                die(f"consultant.md: BUDGETS row {key} missing")
            dc, do = D[key]
            if calls <= 0 or out <= 0:
                e("Calls and Out must be > 0")
            elif (calls > dc or out > do) and not why:
                e(f"above default {key} ({dc}/{do}) needs Why")
        old = L["tasks"].get(t, {})
        nt = new_task(cls=cl, fit=fit or "-", agent=ag, stream=r.get("stream", "").strip(), brief=brief, writes=writes,
                      calls=calls, out=out, depends=deps, review=r.get("review", "").lower().startswith("y"),
                      why=why)
        for k in ("status", "agent_ids", "blocks"):
            if k in old:
                nt[k] = old[k]
        if old.get("rerun"):  # a task already re-run keeps its mark and its switched agent
            nt["rerun"] = old["rerun"]
            nt["agent"] = old["agent"]
        if nt["status"] in ("rejected", "stale"):  # re-provisioned after a scope rejection or a stale fence
            nt["status"] = "todo"
        new[t] = nt
    return errs, new


def cmd_init(a):
    if a.pack:
        return cmd_init_pack(a)
    if a.draft:
        die("init: --draft needs --pack DIR")
    L = load()
    D = defaults()
    rows, src = [], []
    prov = SD / "provision.md"
    if prov.exists():
        pr = md_table(prov.read_text(), ["task", "class", "fit", "agent", "writes", "calls", "out", "depends"])
        if pr is None:
            die("INVALID provision.md: table needs Task|Class|Fit|Agent|Stream|Context|Writes|Brief|Calls|Out|Depends|Review|Why")
        rows += pr
        src.append("provision.md")
    dm = re.search(r"## Direct tasks(.*?)(\n## |\Z)", task_md(), re.S)
    direct = md_table(dm.group(1), ["task", "writes", "change", "acceptance"]) if dm else None
    if direct:
        dc, do = D["engineer-M1"]
        for r in direct:
            rows.append({"task": r["task"], "class": "M1", "fit": "WL", "agent": "engineer", "stream": "direct",
                         "writes": r["writes"], "brief": f"TASK.md#direct-tasks row {r['task']}",
                         "calls": str(dc), "out": str(do), "depends": "-", "review": "no", "why": "-",
                         "_acc": r.get("acceptance", "")})
        src.append("TASK.md direct tasks")
    if not rows:
        die("nothing to load: no provision.md and no TASK.md direct tasks")

    errs, new = load_rows(L, D, rows)
    prov_text = prov.read_text() if prov.exists() else ""
    _, ihash = build_index()
    stale_check(L, new, prov_text)
    mi = re.search(r"(?m)^Index hash:\s*`?([0-9a-f]{12})`?\s*$", prov_text)
    if mi and ihash and mi.group(1) != ihash:
        print(f"NOTE index changed since the pack: {mi.group(1)} \u2192 {ihash}")
    if errs:
        print("INVALID — continue the triage consultant with these lines:")
        print("\n".join(errs))
        sys.exit(1)
    finish_init(L, new, len(rows), " + ".join(src))


def finish_init(L, new, n, src):
    for t, v in L["tasks"].items():  # keep history of tasks dropped by re-triage once started
        if t not in new and v["status"] != "todo":
            new[t] = v
    L["tasks"] = new
    L["cap"], L["prefix"] = task_meta()
    save(L)
    c, o = projected(L)
    print(f"loaded {n} tasks from {src} · projected calls {c} out {o}{capstr(L)}")
    cap = L["cap"]
    if (cap.get("calls") and c > cap["calls"]) or (cap.get("out") and o > cap["out"]):
        print("CAP projected spend exceeds the TASK.md cap: continue the triage consultant to re-split; "
              "if still over, ask the user")
    cmd_next(None, header=False)


# ---------- plan packs (spec plan-pack; draft layout of its section 12) ----------
PROJECT_RE = re.compile(r"[a-z0-9][a-z0-9-]*")
KEY_RE = re.compile(r"\b[A-Z]{3}-\d{5}\b")
BASE_RE = r"(?m)^Base commit:\s*`?([0-9a-f]{7,40})`?\s*$"
INDEX_RE = r"(?m)^Index hash:\s*`?([0-9a-f]{12})`?\s*$"
SCRATCH_URL = "https://github.com/racetracks/Pour-Social-Score_Scratch/"
PROV_COLS = ["task", "class", "fit", "agent", "writes", "calls", "out", "depends"]
ENGINEERS = ("engineer", "engineer-m1", "engineer-m3")


def scratch_root(p):
    """The path before the last part named `temp`; None when there is none."""
    parts = pathlib.Path(p).resolve().parts
    for i in range(len(parts) - 1, 0, -1):
        if parts[i] == "temp":
            return pathlib.Path(*parts[:i])
    return None


def rel_in(root, p):
    p = pathlib.Path(p).resolve()
    if root:
        try:
            return p.relative_to(root).as_posix()
        except ValueError:
            pass
    return _session.rel(p)


def sha12(b):
    return hashlib.sha256(b).hexdigest()[:12]


def pack_files(pd):
    """Pack files by relative path: TASK.md, provision.md, briefs/**, specs/**, context/*.md (never pack.json or README.md)."""
    out = [n for n in ("TASK.md", "provision.md") if (pd / n).is_file()]
    for d in ("briefs", "specs"):
        out += [f.relative_to(pd).as_posix() for f in sorted((pd / d).rglob("*")) if f.is_file()]
    out += [f.relative_to(pd).as_posix() for f in sorted((pd / "context").glob("*.md"))]
    return sorted(out)


def readme_body(pd):
    """(lines after the Purpose line of context/pack-readme.md up to its ## Changelog, problems)."""
    f = pd / "context" / "pack-readme.md"
    if not f.is_file():
        return [], ["PACK context/pack-readme.md: missing"]
    lines = f.read_text().split("\n")
    i = next((k for k, l in enumerate(lines) if re.search(r"(?i)purpose:", l)), 0)
    body = lines[i + 1:]
    for k, l in enumerate(body):
        if l.startswith("## Changelog"):
            body = body[:k]
            break
    while body and not body[0].strip():
        body.pop(0)
    while body and not body[-1].strip():
        body.pop()
    probs = []
    if len(body) > 25:
        probs.append(f"PACK context/pack-readme.md: {len(body)} lines, at most 25")
    sec, num, rec = False, False, False
    for l in body:
        if l.startswith("#"):
            sec = l.startswith("### Decisions for the author")
        elif sec:
            num = num or bool(re.match(r"\s*\d+[.)] ", l))
            rec = rec or "Recommendation:" in l
    if num and not rec:
        probs.append("PACK context/pack-readme.md: decision without a Recommendation:")
    return body, probs


def waves_of(tasks):
    left, done, out = list(tasks), set(), []
    while left:
        w = [t for t in left if all(d in done or d not in tasks for d in tasks[t]["depends"])] or list(left)
        out.append(w)
        done |= set(w)
        left = [t for t in left if t not in done]
    return out


def usd_of(agent, calls, out):
    m = model_of(agent).lower()
    fam = next((f for f in PRICES if f in m), None)
    if not fam:
        return None
    i, o = PRICES[fam]
    return (calls * 30000 * 0.1 * i + calls * 2000 * i + out * 12 * o) / 1e6


def write_readme(dest, pack, root):
    """The author's review copy (spec plan-pack 5.1), from pack.json and context/pack-readme.md; never written by hand."""
    dest = pathlib.Path(dest)
    pj = (dest / "pack.json").read_bytes()
    base = rel_in(root, dest)
    url = lambda rel: f"{SCRATCH_URL}blob/main/{base}/{rel}"
    proj = pack["project"]
    body, _ = readme_body(dest)
    T = pack["tasks"]
    L = [f"# Pack {proj}",
         f"Purpose: execution pack for {proj} for the author's review · Owner: generated by .claude/scripts/ledger.py pack "
         "· Status: draft until promoted to documents/projects/",
         f"Pack hash: {sha12(pj)}", "", "## Summary"] + body + ["", "## Tasks",
         "| Task | Class | Agent (model) | Depends | Calls | Out | Est. USD | Brief |", "|---|---|---|---|---|---|---|---|"]
    tc = to = 0
    tu = 0.0
    for t, v in T.items():
        u = usd_of(v["agent"], v["calls"], v["out"])
        tc += v["calls"]
        to += v["out"]
        tu += u or 0.0
        br = f"[{v['brief']}]({url(v['brief'])})" if v["brief"] else "-"
        L.append(f"| {t} | {v['class']} | {v['agent']} ({model_of(v['agent'])}) | {'; '.join(v['depends']) or '-'} | "
                 f"{v['calls']} | {v['out']} | {'-' if u is None else f'{u:.2f}'} | {br} |")
    L.append(f"| Total | | | | {tc} | {to} | {tu:.2f} | |")
    pairs = [(d, t) for t, v in T.items() for d in v["depends"]]
    seen = {x for pr in pairs for x in pr}
    L += ["", "## Order", "```mermaid", "flowchart LR"] + [f"  {d} --> {t}" for d, t in pairs] \
        + [f"  {t}" for t in T if t not in seen] + ["```", "", "## Cost",
        "Estimate: per call 30000 cache-read and 2000 input tokens, 12 output tokens per Out line, PRICES in .claude/scripts/ledger.py (assumptions).",
        "", "## Files"] + [f"- [{r}]({url(r)})" for r in sorted(pack["files"])] + ["", "## Keys"]
    keys = sorted({k for r in pack["files"] for k in KEY_RE.findall((dest / r).read_text(errors="replace"))})
    reg = SCRATCH_URL + "blob/main/documents/reference-framework/16_Registries/REGISTRY.md#"
    L += [f"- [{k}]({reg}{k.lower()})" for k in keys] or ["None."]
    rd = dest / "README.md"
    rd.write_text("\n".join(L) + "\n")
    m = re.search(r"(?m)^Pack hash: (\S+)", rd.read_text())
    tool = ROOT / ".claude" / "scripts" / "check_context.py"
    r = subprocess.run([sys.executable, str(tool), str(rd)], capture_output=True, text=True)
    if not m or m.group(1) != sha12((dest / "pack.json").read_bytes()) or r.returncode != 0:
        first = (r.stdout.strip().splitlines() or ["hash line"])[0]
        die(f"pack: README.md not current or fails check_context: {first}")


def doc_problems(pd, root):
    """Documents checks of the hand-off (plan-pack 12.3): SHAPE caps and header, ## Changelog, registry keys."""
    out, mds = [], [f for d in ("briefs", "specs", "context") for f in sorted((pd / d).rglob("*.md"))]
    if not mds:
        return out
    tool = ROOT / ".claude" / "scripts" / "check_context.py"
    r = subprocess.run([sys.executable, str(tool)] + [str(f) for f in mds], capture_output=True, text=True)
    reg = None
    if root:
        rf = root / "documents" / "reference-framework" / "16_Registries" / "REGISTRY.md"
        reg = set(KEY_RE.findall(rf.read_text(errors="replace"))) if rf.is_file() else set()
    for f in mds:
        rel = f.relative_to(pd).as_posix()
        full = str(f.resolve())
        out += [f"PACK {rel}: {l}" for l in r.stdout.splitlines() if l.startswith(f"SHAPE {full}: ")]
        text = f.read_text(errors="replace")
        if not re.search(r"(?m)^## Changelog", text):
            out.append(f"PACK {rel}: no ## Changelog section")
        if reg is not None:
            out += [f"PACK {rel}: key {k} not in the registry" for k in sorted(set(KEY_RE.findall(text))) if k not in reg]
    return out


def cmd_pack(a):
    if not PROJECT_RE.fullmatch(a.project):
        die("pack: PROJECT is lower-case letters, digits and hyphens")
    pd = SD / "projects" / a.project
    root = scratch_root(SD)
    probs, new, base, ihash = [], {}, "", ""
    prov = pd / "provision.md"
    if not prov.is_file():
        probs.append("PACK provision.md: missing")
    if not (pd / "TASK.md").is_file():
        probs.append("PACK TASK.md: missing")
    if prov.is_file():
        ptext = prov.read_text()
        mb, mi = re.search(BASE_RE, ptext), re.search(INDEX_RE, ptext)
        if not mb:
            probs.append("PACK provision.md: no Base commit: line")
        if not mi:
            probs.append("PACK provision.md: no Index hash: line")
        base, ihash = (mb.group(1) if mb else ""), (mi.group(1) if mi else "")
        if mb and subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", base + "^{commit}"], capture_output=True).returncode != 0:
            probs.append(f"PACK base {base}: not in this clone")
        pr = md_table(ptext, PROV_COLS)
        if pr is None:
            probs.append("PACK provision.md: no task table")
        else:
            errs, new = load_rows(fresh(), defaults(), pr)
            probs += [f"PACK provision.md: {e}" for e in errs]
        idx, _ = build_index()
        if not idx:
            die("pack: index not built")
        tool = ROOT / ".claude" / "scripts" / "check_context.py"
        for t, nt in new.items():
            if nt["agent"] in ENGINEERS:
                bp = pd / nt["brief"].split("#")[0] if nt["brief"] else None
                if not bp or not bp.is_file():
                    probs.append(f"PACK {t}: brief {nt['brief'] or '-'} missing")
                elif nt["agent"] != "engineer-m3" and nt["cls"] in ("M1", "M2"):
                    r = subprocess.run([sys.executable, str(tool), "--brief", nt["cls"], "--index", str(idx), str(bp)],
                                       capture_output=True, text=True)
                    probs += [l for l in r.stdout.splitlines() if l.startswith("BRIEF ")]
                if nt["stream"].lower() not in NONE and not (pd / "context" / f"{nt['stream']}.md").is_file():
                    probs.append(f"PACK {t}: context/{nt['stream']}.md missing")
        probs += doc_problems(pd, root)
        pf = [str(f) for d in ("specs", "context") for f in sorted((pd / d).glob("*.md")) if not f.name.endswith("-index.md")]
        probs += pointer_lines(pf, idx)
        probs += readme_body(pd)[1]
    if probs:
        print("\n".join(probs))
        die(f"HANDOFF refused: {len(probs)} problems; `cont {load().get('triage') or 'the plan consultant'} --support` "
            "with these lines, then pack again")
    files = {r: sha12((pd / r).read_bytes()) for r in pack_files(pd)}
    tasks = {}
    for t, nt in new.items():
        cf = f"context/{nt['stream']}.md"
        tasks[t] = {"class": nt["cls"], "fit": nt["fit"], "agent": nt["agent"], "stream": nt["stream"], "writes": nt["writes"],
                    "brief": nt["brief"] or None, "context": cf if cf in files else None, "calls": nt["calls"],
                    "out": nt["out"], "depends": nt["depends"], "review": nt["review"], "why": nt["why"]}
    pack = {"schema": 1, "generated_by": "ledger.py pack", "project": a.project, "base": base, "index_hash": ihash,
            "files": files, "tasks": tasks, "waves": waves_of(tasks)}
    (pd / "pack.json").write_text(json.dumps(pack, indent=1))
    write_readme(pd, pack, root)
    print(f"PACK {rel_in(root, pd) if root else pd} · {len(tasks)} tasks · base {base[:12]} · index {ihash}")


def cmd_init_pack(a):
    d = pathlib.Path(a.pack)
    if not (d / "pack.json").is_file():
        die(f"init --pack: no pack.json in {a.pack}")
    pj = (d / "pack.json").read_bytes()
    pack = json.loads(pj)
    if pack.get("schema") != 1:
        die(f"init --pack: pack.json schema {pack.get('schema')} not supported")
    parts = d.resolve().parts
    draft = "temp" in parts
    if a.draft:
        if not (draft and d.resolve().parent.name == "projects"):
            die("init --pack: --draft takes a temp/.../projects/<project>/ folder")
    elif draft:
        die(f"init --pack: {a.pack} is a draft; approved packs load from documents/projects/<project>/ (pass --draft for a dry run)")
    elif not any(parts[i] == "documents" and parts[i + 1] == "projects" for i in range(len(parts) - 1)):
        die("init --pack: packs load from documents/projects/<project>/ (or a temp/.../projects/<project>/ folder with --draft)")
    L = load()
    if L["tasks"]:
        die("init --pack: this session already has tasks; use a fresh session")
    bad = []
    for rel, h in pack["files"].items():
        f = d / rel
        if not f.is_file():
            bad.append(f"PACK {rel}: missing")
        elif sha12(f.read_bytes()) != h:
            bad.append(f"PACK {rel}: changed since export")
    rd = d / "README.md"
    mh = re.search(r"(?m)^Pack hash: (\S+)", rd.read_text()) if rd.is_file() else None
    if not mh or mh.group(1) != sha12(pj):
        bad.append("PACK README.md: not current with pack.json")
    if bad:
        print("\n".join(bad))
        die("init --pack refused: re-export with ledger.py pack in the planning session")
    rows = [{"task": t, "class": v["class"], "fit": v["fit"], "agent": v["agent"], "stream": v["stream"],
             "writes": "; ".join(v["writes"]) or "-", "brief": v["brief"] or "-", "calls": str(v["calls"]),
             "out": str(v["out"]), "depends": "; ".join(v["depends"]) or "-", "review": "yes" if v["review"] else "no",
             "why": v["why"] or "-"} for t, v in pack["tasks"].items()]
    errs, new = load_rows(L, defaults(), rows)
    prov_text = (d / "provision.md").read_text()
    _, ihash = build_index()
    stale_check(L, new, prov_text)
    mi = re.search(INDEX_RE, prov_text)
    if mi and ihash and mi.group(1) != ihash:
        print(f"NOTE index changed since the pack: {mi.group(1)} → {ihash}")
    if errs:
        print("INVALID — continue the triage consultant with these lines:")
        print("\n".join(errs))
        sys.exit(1)
    if a.draft:
        print(f"loaded {len(rows)} tasks from pack.json (dry run)")
        print("DRY RUN draft pack: nothing copied, nothing saved")
        return
    rt = ROOT / "TASK.md"
    if rt.exists() and rt.read_bytes() != (d / "TASK.md").read_bytes():
        die(f"init --pack: {rt} differs from the pack's; move it aside, then init --pack again")
    shutil.copy2(d / "TASK.md", SD / "TASK.md")
    shutil.copy2(d / "TASK.md", rt)
    for n in ("provision.md", "pack.json"):
        shutil.copy2(d / n, SD / n)
    for n in ("briefs", "specs", "context"):
        if (d / n).is_dir():
            shutil.copytree(d / n, SD / n, dirs_exist_ok=True)
    finish_init(L, new, len(rows), "pack.json")


def cmd_promote(a):
    d = pathlib.Path(a.draft).resolve()
    root = scratch_root(d)
    if not (root and d.is_dir() and (d / "pack.json").is_file() and d.parent.name == "projects" and PROJECT_RE.fullmatch(d.name)):
        die(f"promote: {a.draft} is not a temp/.../projects/<project> pack with a pack.json")
    proj, today = d.name, time.strftime("%Y-%m-%d", time.gmtime())
    target, hist = root / "documents" / "projects" / proj, None
    if target.exists():
        hist = root / "history" / "project" / f"{today}-{proj}"
        n = 2
        while hist.exists():
            hist = root / "history" / "project" / f"{today}-{proj}-{n}"
            n += 1
        hist.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(target), str(hist))
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(d, target)
    write_readme(target, json.loads((target / "pack.json").read_text()), root)
    drel = rel_in(root, d)
    cl = root / "documents" / "00_Changelog.md"
    if cl.exists():
        old = f"; the earlier pack is [{rel_in(root, hist)}/]({SCRATCH_URL}tree/main/{rel_in(root, hist)}/)" if hist else ""
        row = (f"| {today} | projects/{proj}/ | - | promoted | plan pack promoted on the author's OK{old} | "
               f"[{drel}]({SCRATCH_URL}tree/main/{drel}) |")
        lines = cl.read_text().split("\n")
        i = next((k for k, l in enumerate(lines) if l.startswith("| ---")), None)
        if i is None:
            lines += [row]
        else:
            lines.insert(i + 1, row)
        cl.write_text("\n".join(lines))
    else:
        print("NOTE documents/00_Changelog.md missing: no row added")
    print(f"PROMOTED documents/projects/{proj}/ · draft stays in {drel}")
    print(f"NEXT git -C {root} add -A documents history/project && git -C {root} commit -qm \"Promote pack {proj}\" "
          f"&& git -C {root} push -q origin main")


def spawn_line(L, aid, kind, tasks, calls, out, note="", ihash=None):
    briefs = sorted({L["tasks"][t]["brief"] for t in tasks if L["tasks"][t]["brief"]})
    T = L["tasks"]
    parts = [f"ID {aid}", f"ref {L.get('prefix', 'REF')}-{SD.name}-{aid}", f"tasks {','.join(tasks)}",
             "class " + ",".join(sorted({T[t]["cls"] for t in tasks})), f"model {model_of(kind)}"]
    if briefs:
        parts.append("brief " + "; ".join(briefs))
    if kind == "consultant":
        r = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short=12", "HEAD"], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            parts.append(f"base {r.stdout.strip()}")
        if ihash:
            parts.append(f"index {ihash}")
    parts += [f"budget calls {calls} out {out}", f"session {_session.rel(SD)}"]
    if note:
        parts.append(note)
    return f"SPAWN {kind}: " + " · ".join(parts)


def open_segment(L, aid, tasks, calls, out):
    ag = L["agents"][aid]
    sdir = SD / ".scope"
    sdir.mkdir(exist_ok=True)
    snap = sdir / f"{aid}-{len(ag['segs']) + 1}.json"
    snap.write_text(json.dumps(snapshot()))
    ag["segs"].append({"tasks": tasks, "start": time.time(), "end": None, "budget": [calls, out],
                       "snap": str(snap)})
    ag["status"] = "running"


def cmd_spawn(a):
    L = load()
    D = defaults()
    L["cap"], L["prefix"] = task_meta()
    tasks = [x.strip() for x in a.tasks.split(",") if x.strip()]
    if tasks == ["TRIAGE"] and "TRIAGE" not in L["tasks"]:
        c, o = D["triage"]
        L["tasks"]["TRIAGE"] = new_task(cls="M3", agent="consultant", stream="-", calls=c, out=o)
    for t in tasks:
        if t not in L["tasks"]:
            die(f"unknown task {t}: run init, or re-triage")
    T = [L["tasks"][t] for t in tasks]
    kinds = {x["agent"] for x in T}
    if len(kinds) != 1:
        die("cannot batch different agent kinds")
    kind = kinds.pop()
    if kind == "coordinator":
        die("coordinator task: do it inline (no code/tests), then `ledger.py done " + ",".join(tasks) + "`")
    if kind == "engineer-m3" and len(tasks) > 1:
        die("engineer-m3 tasks are never batched")
    for t, x in zip(tasks, T):
        b = x["brief"]
        if kind != "consultant" and not b.startswith("TASK.md"):
            bp = SD / b.split("#")[0]
            if not bp.exists() or "acceptance" not in bp.read_text().lower():
                die(f"{t}: brief {b} missing or has no acceptance check: continue its consultant")
    idx, ihash = build_index()
    tool, probs, who = ROOT / ".claude" / "scripts" / "check_context.py", [], None
    for t, x in zip(tasks, T):
        if kind in ("engineer", "engineer-m1") and not x["brief"].startswith("TASK.md") and x["cls"] in ("M1", "M2"):
            cmd = [sys.executable, str(tool), "--brief", x["cls"]] + (["--index", str(idx)] if idx else [])
            r = subprocess.run(cmd + [str(SD / x["brief"].split("#")[0])], capture_output=True, text=True)
            if r.returncode not in (0, 1):
                die(f"brief check failed to run: {(r.stderr.strip().splitlines() or ['?'])[-1]}")
            found = [l for l in r.stdout.splitlines() if l.startswith("BRIEF ")]
            if found and who is None:
                who = L["streams"].get(x["stream"]) or L.get("triage") or "the triage consultant"
            probs += found
    if probs:
        print("\n".join(probs))
        die(f"ROUTE `cont {who} --support` with these BRIEF lines; then spawn again")
    for t, x in zip(tasks, T):
        if x["status"] != "todo":
            die(f"{t} is {x['status']}")
        unmet = [d for d in x["depends"] if L["tasks"].get(d, {}).get("status") != "done"]
        if unmet:
            die(f"{t} waits on {','.join(unmet)}")
    if cap_hit(L, *spent_total(L)):
        die("CAP reached: stop spawning; ask the user")
    calls, out = sum(x["calls"] for x in T), sum(x["out"] for x in T)
    if a.reuse:
        aid = a.reuse
        ag = L["agents"].get(aid) or die(f"unknown agent {aid}")
        if ag["status"] == "running":
            die(f"{aid} is running")
        if ag["kind"] != kind:
            die(f"{aid} is a {ag['kind']}, tasks need {kind}")
    else:
        aid = f"A{L['next_agent']:02d}"
        L["next_agent"] += 1
        ag = L["agents"][aid] = {"kind": kind, "tasks": [], "segs": [], "status": "idle",
                                 "orig": [0, 0], "ext": [0, 0], "spent": [0, 0]}
    ag["tasks"] += tasks
    ag["orig"][0] += calls
    ag["orig"][1] += out
    for t, x in zip(tasks, T):
        x["status"] = "running"
        if x.get("rerun") == 1:
            x["rerun"] = 2
        x["agent_ids"].append(aid)
        if kind == "consultant" and x["stream"].lower() not in NONE:
            L["streams"][x["stream"]] = aid
    if tasks == ["TRIAGE"]:
        L["triage"] = aid
    open_segment(L, aid, tasks, calls, out)
    save(L)
    note = "+ ≤15-line consultant brief (coordinator C3)" if kind == "consultant" else ""
    print(spawn_line(L, aid, kind, tasks, calls, out, note, ihash))


def cmd_cont(a):
    L = load()
    D = defaults()
    ag = L["agents"].get(a.aid) or die(f"unknown agent {a.aid}")
    if ag["status"] == "running":
        die(f"{a.aid} is running")
    if a.support or a.review:
        if ag["kind"] != "consultant":
            die("--support/--review continue consultants only")
        c, o = D["support" if a.support else "review"]
        ag["orig"][0] += c
        ag["orig"][1] += o
        tasks, mode = [], "support" if a.support else "review"
    else:
        if (a.add_calls or a.add_out) and not a.reason:
            die("budget extensions need --reason (the re-triage decision)")
        if a.add_calls or a.add_out:
            ag["ext"][0] += a.add_calls
            ag["ext"][1] += a.add_out
            decide(L, f"budget +{a.add_calls} calls +{a.add_out} out for {a.aid}: {a.reason}")
        tasks = [t for t in ag["tasks"] if L["tasks"][t]["status"] in ("blocked", "budget", "needs")]
        c = ag["orig"][0] + ag["ext"][0] - ag["spent"][0]
        o = ag["orig"][1] + ag["ext"][1] - ag["spent"][1]
        if c <= 0 or o <= 0:
            die(f"{a.aid} has no budget left (calls {c} out {o}): re-triage, then cont with --add-calls/--add-out --reason")
        mode = "resume: brief updated or STATE.md"
        for t in tasks:
            L["tasks"][t]["status"] = "running"
    if cap_hit(L, *spent_total(L)):
        die("CAP reached: stop spawning; ask the user")
    open_segment(L, a.aid, tasks, c, o)
    save(L)
    print(f"CONTINUE {ag['kind']}: ID {a.aid} · {mode} · budget calls {c} out {o}")


def cmd_ret(a):
    L = load()
    aid = a.aid
    ag = L["agents"].get(aid) or die(f"unknown agent {aid}")
    if ag["status"] != "running":
        die(f"{aid} is not running")
    status = re.sub(r"[^A-Z]", "", (a.line1.split() or [""])[0].upper())
    if a.failed and status == "DONE":
        status = "BLOCKED"
    mc = re.search(r"calls\D{0,3}(\d+)", a.spend)
    mo = re.search(r"out\D{0,3}(\d+)", a.spend)
    if not (mc and mo):
        die("spend line unreadable: the agent must return `spend: calls a/b · out c/d`; continue it to restate")
    sc, so = int(mc.group(1)), int(mo.group(1))
    seg = ag["segs"][-1]
    seg["end"] = time.time()
    seg["spent"] = [sc, so]
    ag["spent"][0] += sc
    ag["spent"][1] += so
    ag["status"] = "idle"
    tasks = seg["tasks"]
    kind = ag["kind"]
    out = []
    rerun_route = False
    if sc > seg["budget"][0] or so > seg["budget"][1]:
        out.append(f"OVERRUN {aid}: spent calls {sc} out {so} past budget {seg['budget'][0]}/{seg['budget'][1]}; treated as BUDGET")
        status = "BUDGET"

    # scope fence: allowed if any agent active during this segment may write the path
    snap = json.loads(pathlib.Path(seg["snap"]).read_text())
    active = []
    for oid, oag in L["agents"].items():
        for s in oag["segs"]:
            if s["start"] < seg["end"] and (s["end"] is None or s["end"] > seg["start"]):
                active.append((oag["kind"], agent_writes(L, oid)))
                break
    changed = changed_since(snap)
    bad = [p for p in changed if not any(allowed(p, k, w) for k, w in active)]
    shape = shape_check(own_paths(L, aid, kind, changed, tasks)) if status == "DONE" and not bad else []

    ptrs = []
    if kind == "consultant" and status == "DONE" and not bad:
        pf = [p for p in own_paths(L, aid, kind, changed, tasks)
              if p.endswith(".md") and ("/specs/" in p or "/context/" in p) and not p.endswith("-index.md")]
        ptrs = pointer_lines([str(ROOT / p) for p in pf])

    rules = []
    if kind in RULE_KINDS and status == "DONE" and not bad:
        miss = rules_missing(L, aid)
        if miss is None:
            out.append(f"WARN RULES {aid}: transcript unmeasured; rules read not verified (not a pass)")
        elif miss:
            rules = [f"RULES {aid}: not read in full: {', '.join(miss)}"]

    triage = L.get("triage") or "the triage consultant"
    if bad:
        for t in tasks:
            L["tasks"][t]["status"] = "rejected"
        more = " …" if len(bad) > 10 else ""
        out.append(f"SCOPE {aid} ({kind}) wrote outside its fence: {', '.join(bad[:10])}{more}")
        out.append(f"ROUTE reject; git restore those paths; continue {triage} (`cont {triage} --support`) to re-provision")
    elif shape or rules or ptrs:
        for t in tasks:
            L["tasks"][t]["status"] = "blocked"
        out += shape + rules + ptrs
        if ptrs:
            out.append(f"ROUTE `cont {aid}` with these lines: fix each pointer (a line inside the file, an existing #anchor), then return again")
        if shape:
            out.append(f"ROUTE `cont {aid}` with these lines: it reshapes its documents to the context caps (SHAPE) and updates the docs its brief names for its code (DOCS; a brief that names none: BLOCKED to its consultant), then returns again")
        if rules:
            out.append(f"ROUTE `cont {aid}` with this line: read both files in full (Read, no offset or limit), re-check the change against them, then return again")
    elif status == "DONE":
        for t in tasks:
            L["tasks"][t]["status"] = "done"
        if tasks == ["TRIAGE"]:
            out.append("NEXT run `ledger.py init`")
        elif tasks:
            out.append(f"ACCEPT {','.join(tasks)} if line 2 reports a passing acceptance check")
        for t in tasks:
            x = L["tasks"][t]
            if x["review"]:
                who = L["streams"].get(x["stream"]) or L.get("triage")
                if kind == "consultant" or not who:
                    out.append(f"REVIEW {t}: spawn a fresh consultant (mode review) with agents/{aid}/REPORT.md")
                else:
                    out.append(f"REVIEW {t}: `cont {who} --review` with agents/{aid}/diff.patch")
        if kind == "engineer-m3":
            out.append(f"ROUTE if agents/{aid}/HANDOFF.md exists: `cont {L['streams'].get(L['tasks'][tasks[0]]['stream']) or triage} --support` with it")
    elif kind == "engineer-m1" and status in ("BLOCKED", "BUDGET") and any(not L["tasks"][t].get("rerun") for t in tasks):
        rerun_route = True
        for t in tasks:
            x = L["tasks"][t]
            if x.get("rerun"):
                continue
            x["rerun"] = 1
            x["agent"] = "engineer"
            x["status"] = "todo"
            out.append(f"RERUN {t}: engineer-m1 {aid} returned {status}; re-run once on engineer (Sonnet), same brief, no consultant turn")
    elif status == "BLOCKED":
        for t in tasks:
            L["tasks"][t]["status"] = "blocked"
            L["tasks"][t]["blocks"] = L["tasks"][t].get("blocks", 0) + 1
        if kind == "consultant":
            out.append(f"ROUTE ask the user (one batched question) from agents/{aid}/QUESTIONS.md; then `cont {aid}`")
        else:
            who = L["streams"].get(L["tasks"][tasks[0]]["stream"]) if tasks else None
            who = who or triage
            qf = "REPORT.md" if a.failed else "QUESTIONS.md"
            out.append(f"ROUTE `cont {who} --support` with agents/{aid}/{qf}; then `cont {aid}` (brief updated)")
            twice = [t for t in tasks if L["tasks"][t]["blocks"] >= 2]
            if twice:
                out.append(f"ESCALATE? {','.join(twice)} blocked twice: consultant decides fix-brief or split to engineer-m3 (K5)")
    elif status == "NEEDS":
        for t in tasks:
            L["tasks"][t]["status"] = "needs"
        out.append(f"RETRIAGE `cont {triage} --support` with agents/{aid}/NEEDS.md; then `init`")
    elif status == "BUDGET":
        for t in tasks:
            L["tasks"][t]["status"] = "budget"
        out.append(f"RETRIAGE {','.join(tasks) or aid}: `cont {triage} --support` with agents/{aid}/STATE.md; "
                   f"extend only per its amended provision.md (`init`, then `cont {aid} --add-calls N --add-out N --reason D<n>`)")
    else:
        die(f"unknown status '{status}': expected DONE, BLOCKED, NEEDS or BUDGET")

    o0, o1 = ag["orig"]
    if not bad and o0 and (ag["spent"][0] >= 1.5 * o0 or ag["spent"][1] >= 1.5 * o1):
        out.append(f"RETRIAGE {aid}: cumulative spend {ag['spent'][0]}/{ag['spent'][1]} ≥1.5× original {o0}/{o1}")
    if cap_hit(L, *spent_total(L)):
        out.append("CAP reached: stop spawning; ask the user")
    save(L)
    print("\n".join(out))
    if (status == "DONE" and not bad and not shape and not rules and not ptrs) or rerun_route:
        cmd_next(None, header=False)


def cmd_done(a):
    L = load()
    for t in [x.strip() for x in a.tasks.split(",") if x.strip()]:
        x = L["tasks"].get(t) or die(f"unknown task {t}")
        if x["agent"] != "coordinator":
            die(f"{t} belongs to {x['agent']}: it reports via ret")
        x["status"] = "done"
    save(L)
    cmd_next(None, header=False)


def cmd_next(a, header=True):
    L = load()
    T = L["tasks"]
    ready = [t for t, x in T.items()
             if x["status"] == "todo" and all(T.get(d, {}).get("status") == "done" for d in x["depends"])]
    groups = {}
    for t in ready:
        x = T[t]
        if x.get("rerun") == 1:
            print(f"ROUTE re-run {t} on engineer (Sonnet): `spawn {t}` (brief {x['brief']}; once, no consultant turn)")
            continue
        key = (x["agent"], x["stream"]) if x["agent"] != "engineer-m3" else (x["agent"], t)
        groups.setdefault(key, []).append(t)
    for (agent, stream), ts in groups.items():
        if agent == "coordinator":
            print(f"READY coordinator: {','.join(ts)} (inline, then `done {','.join(ts)}`)")
            continue
        hint = ""
        if agent == "consultant":
            who = L["streams"].get(stream)
            if who and L["agents"][who]["status"] != "running":
                hint = f" --reuse {who}"
            elif L.get("triage") and L["agents"][L["triage"]]["status"] != "running":
                hint = f" (or `--reuse {L['triage']}` if triage read these inputs)"
        cmd = f"`spawn {','.join(ts)}{hint if hint.startswith(' --') else ''}`"
        print(f"READY {agent}/{stream}: {cmd}{'' if hint.startswith(' --') else hint}")
    counts = {}
    for x in T.values():
        counts[x["status"]] = counts.get(x["status"], 0) + 1
    c, o = spent_total(L)
    state = " · ".join(f"{k} {v}" for k, v in sorted(counts.items()))
    print(f"{state or 'no tasks'} · spent calls {c} out {o}{capstr(L)}")


def decide(L, text, path=""):
    ctx = SD / "CONTEXT.md"
    body = ctx.read_text() if ctx.exists() else ("# Session context\nPurpose: session decision log and links · Owner: generated by .claude/scripts/ledger.py and _session.py · "
                                 "Status: live\n\n## Decisions\n")
    n = len(re.findall(r"^- D\d+ ·", body, re.M)) + 1
    with open(ctx, "w") as f:
        f.write(body.rstrip("\n") + f"\n- D{n} · {text}" + (f" · {path}" if path else "") + "\n")
    return n


def cmd_decide(a):
    L = load()
    print(f"D{decide(L, a.text, a.path or '')}")


# ---------- token measurement ----------
def transcript_base():
    env = os.environ.get("LEDGER_TRANSCRIPTS")
    if env:
        return pathlib.Path(env)
    cfg = pathlib.Path(os.environ.get("CLAUDE_CONFIG_DIR") or (pathlib.Path.home() / ".claude"))
    return cfg / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(ROOT))


def transcripts(L, key):
    try:
        base = transcript_base()
        found = []
        if key == "coordinator":
            for f in sorted(base.glob("*.jsonl")):
                if SD.name in f.read_text(errors="replace"):
                    found.append(f)
            return found
        pat = re.compile(r"ref " + re.escape(f"{L.get('prefix', 'REF')}-{SD.name}-{key}") + r"(?![A-Za-z0-9])")

        def scan(b):
            hits = []
            for f in sorted(b.rglob("*.jsonl")):
                if "subagents" not in f.relative_to(b).parts[:-1]:
                    continue
                with open(f, errors="replace") as fh:
                    head = "".join(fh.readline() for _ in range(5))
                if pat.search(head):
                    hits.append(f)
            return hits
        found = scan(base)
        if not found and not os.environ.get("LEDGER_TRANSCRIPTS"):  # Claude Code names the folder after the launch directory
            for d in base.parent.glob("*/"):
                if d != base and d.is_dir():
                    found += scan(d)
            found.sort(key=lambda f: f.stat().st_mtime, reverse=True)
        return found
    except Exception:
        return []


def rules_missing(L, aid):
    """RULES_FILES the agent did not Read in full (no offset or limit); None when unmeasured."""
    try:
        files = transcripts(L, aid)
        if not files:
            return None
        read = set()
        for f in files:
            with open(f, errors="replace") as fh:
                for line in fh:
                    try:
                        d = json.loads(line)
                    except ValueError:
                        continue
                    m = d.get("message") if isinstance(d, dict) and d.get("type") == "assistant" else None
                    c = m.get("content") if isinstance(m, dict) else None
                    for it in c if isinstance(c, list) else []:
                        inp = it.get("input") if isinstance(it, dict) and it.get("type") == "tool_use" and it.get("name") == "Read" else None
                        if not isinstance(inp, dict) or inp.get("offset") is not None or inp.get("limit") is not None:
                            continue
                        fp = pathlib.PurePath(str(inp.get("file_path", ""))).as_posix()
                        read |= {rf for rf in RULES_FILES if fp == rf or fp.endswith("/" + rf)}
        return [rf for rf in RULES_FILES if rf not in read]
    except Exception:
        return None


def price(model, i, cr, cw, o):
    m = (model or "").lower()
    fam = next((f for f in ("opus", "sonnet", "haiku") if f in m), None)
    if not fam:
        return None
    rates = PRICES_LONG[fam] if fam in PRICES_LONG and i + cr + cw > LONG_AT else PRICES[fam]
    return (i * rates[0] + cr * 0.1 * rates[0] + cw * 1.25 * rates[0] + o * rates[1]) / 1e6


def measure(L):
    base = transcript_base()
    keys = list(L["agents"]) + ["coordinator"]
    L["tokens"] = {}
    for k in keys:
        role = "coordinator" if k == "coordinator" else L["agents"][k]["kind"]
        rec = {"role": role, "state": "unmeasured", "files": [], "by_model": {}}
        try:
            files = transcripts(L, k)
            msgs = {}
            for f in files:
                with open(f, errors="replace") as fh:
                    for n, line in enumerate(fh):
                        try:
                            d = json.loads(line)
                        except ValueError:
                            continue
                        if not isinstance(d, dict) or d.get("type") != "assistant":
                            continue
                        m = d.get("message")
                        u = m.get("usage") if isinstance(m, dict) else None
                        if not isinstance(u, dict):
                            continue
                        mid = m.get("id") or f"{f}:{n}"
                        msgs[mid] = (m.get("model") or "", u)
            if files and msgs:
                bm = {}
                for model, u in msgs.values():
                    i, cr = u.get("input_tokens") or 0, u.get("cache_read_input_tokens") or 0
                    cw, o = u.get("cache_creation_input_tokens") or 0, u.get("output_tokens") or 0
                    usd = price(model, i, cr, cw, o)
                    r = bm.setdefault(model, [0, 0, 0, 0, 0.0])
                    r[0] += i
                    r[1] += cr
                    r[2] += cw
                    r[3] += o
                    r[4] = None if (usd is None or r[4] is None) else r[4] + usd
                rec.update(state="measured", files=[os.path.relpath(f, base) for f in files], by_model=bm)
        except Exception:
            rec = {"role": role, "state": "unmeasured", "files": [], "by_model": {}}
        L["tokens"][k] = rec
    return L["tokens"]


def token_section(L):
    tok = L.get("tokens", {})
    done = {k: v for k, v in tok.items() if v["state"] == "measured"}
    if not done:
        return ["## Tokens", f"Tokens: unmeasured (no transcripts under `{transcript_base()}`)"], "tokens: unmeasured"
    rows, tot, total_usd = {}, [0, 0, 0, 0], 0.0
    for v in done.values():
        for model, r in v["by_model"].items():
            g = rows.setdefault((v["role"], model), {"n": set(), "v": [0, 0, 0, 0], "usd": 0.0})
            g["n"].add(id(v))
            for j in range(4):
                g["v"][j] += r[j]
                tot[j] += r[j]
            g["usd"] = None if (r[4] is None or g["usd"] is None) else g["usd"] + r[4]
            total_usd = None if (r[4] is None or total_usd is None) else total_usd + r[4]
    fmt = lambda x: "-" if x is None else f"{x:.4f}"
    lines = ["## Tokens", "| Role | Model | Agents | Input | Cache read | Cache write | Output | Est. USD |",
             "|---|---|---|---|---|---|---|---|"]
    for (role, model) in sorted(rows):
        g = rows[(role, model)]
        lines.append(f"| {role} | {model} | {len(g['n'])} | " + " | ".join(str(x) for x in g["v"]) + f" | {fmt(g['usd'])} |")
    lines.append(f"| Total | - | {len(done)} | " + " | ".join(str(x) for x in tot) + f" | {fmt(total_usd)} |")
    un = [k for k, v in tok.items() if v["state"] != "measured"]
    if un:
        lines += ["", "Unmeasured: " + ", ".join(un)]
    lines += ["", "Estimate: `PRICES` in .claude/scripts/ledger.py; cache read 0.1x and cache write 1.25x input are assumptions."]
    return lines, f"tokens: measured {len(done)} · est ${total_usd or 0:.4f}"


def cmd_render(a=None):
    L = load()
    T = L["tasks"]
    task = os.path.relpath(ROOT / "TASK.md", SD).replace(os.sep, "/")
    ri = ref_index()
    ri_link = f" · [reference index]({os.path.relpath(ROOT / ri, SD).replace(os.sep, '/')})" if ri else ""
    measure(L)
    save(L)
    lines = [f"# Session {SD.name}",
             "Purpose: session index, tasks, spend and tokens · Owner: generated by .claude/scripts/ledger.py render · Status: live", "",
             f"[TASK]({task}) · [CONTEXT](CONTEXT.md) · [provision](provision.md) · [prompts](prompts/README.md){ri_link}", ""]
    counts = {}
    for x in T.values():
        counts[x["status"]] = counts.get(x["status"], 0) + 1
    if counts:
        lines += ["```mermaid", "pie title Tasks by status"] + [f'  "{k}" : {v}' for k, v in counts.items()] + ["```", ""]
    lines += ["## Tasks", "| Task | Class | Fit | Agent | Model | Stream | Budget calls/out | Agents | Status |",
              "|---|---|---|---|---|---|---|---|---|"]
    for t, x in T.items():
        lines.append(f"| {t} | {x['cls']} | {x.get('fit', '-')} | {x['agent']} | {model_of(x['agent'])} | {x['stream']} | "
                     f"{x['calls']}/{x['out']} | {','.join(x['agent_ids'])} | {x['status']} |")
    lines += ["", "## Spend", "| Agent | Kind | Tasks | Spent calls/out | Budget calls/out | Status |",
              "|---|---|---|---|---|---|"]
    for aid, ag in L["agents"].items():
        b = [ag["orig"][i] + ag["ext"][i] for i in (0, 1)]
        lines.append(f"| {aid} | {ag['kind']} | {','.join(ag['tasks']) or '-'} | {ag['spent'][0]}/{ag['spent'][1]} | "
                     f"{b[0]}/{b[1]} | {ag['status']} |")
    c, o = spent_total(L)
    lines += ["", f"Total spent: calls {c} · out {o}{capstr(L)}", ""]
    tl, tmsg = token_section(L)
    lines += tl + ["", "## Artefacts"]
    for label, pat in (("Reports", "agents/*/REPORT.md"), ("Syntheses", "agents/*/SYNTHESIS.md"),
                       ("Specs", "specs/*.md"), ("Briefs", "briefs/*.md"), ("Context", "context/*.md"),
                       ("Test packages", "**/*.zip")):
        found = sorted(p.relative_to(SD).as_posix() for p in SD.glob(pat))
        if found:
            lines.append(f"- {label}: " + " · ".join(f"[{p}]({p})" for p in found))
    (SD / "README.md").write_text("\n".join(lines) + "\n")
    print(tmsg)
    return c, o


def cmd_close(a):
    c, o = cmd_render()
    (SD / "CLOSED").write_text(time.strftime("%Y-%m-%d %H:%M:%S") + "\n")
    L = load()
    print(f"closed {_session.rel(SD)} · spend calls {c} out {o}{capstr(L)}")


def main():
    global SD, LEDGER
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("init")
    s.add_argument("--pack")
    s.add_argument("--draft", action="store_true")
    s = sub.add_parser("pack")
    s.add_argument("project")
    s = sub.add_parser("promote")
    s.add_argument("draft")
    s = sub.add_parser("spawn")
    s.add_argument("tasks")
    s.add_argument("--reuse")
    s = sub.add_parser("cont")
    s.add_argument("aid")
    s.add_argument("--support", action="store_true")
    s.add_argument("--review", action="store_true")
    s.add_argument("--add-calls", type=int, default=0)
    s.add_argument("--add-out", type=int, default=0)
    s.add_argument("--reason")
    s = sub.add_parser("ret")
    s.add_argument("aid")
    s.add_argument("line1")
    s.add_argument("spend")
    s.add_argument("--failed", action="store_true")
    s = sub.add_parser("done")
    s.add_argument("tasks")
    sub.add_parser("next")
    s = sub.add_parser("decide")
    s.add_argument("text")
    s.add_argument("path", nargs="?")
    sub.add_parser("render")
    sub.add_parser("close")
    a = p.parse_args()
    if a.cmd != "promote":
        SD, _ = _session.current(create=a.cmd in ("init", "spawn"))
        LEDGER = SD / "ledger.json"
    {"init": cmd_init, "pack": cmd_pack, "promote": cmd_promote, "spawn": cmd_spawn, "cont": cmd_cont, "ret": cmd_ret, "done": cmd_done,
     "next": cmd_next, "decide": cmd_decide, "render": cmd_render, "close": cmd_close}[a.cmd](a)


if __name__ == "__main__":
    main()
