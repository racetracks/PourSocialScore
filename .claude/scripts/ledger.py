#!/usr/bin/env python3
"""Session ledger: the coordinator's only bookkeeping tool. Output is terse; each line is an instruction.

  ledger.py init                         load provision.md + TASK.md direct tasks; validate; print totals
  ledger.py spawn TASKS [--reuse AID]    gate, allocate agent ID, snapshot repo, print the spawn line
  ledger.py cont AID [--support|--review] [--add-calls N --add-out N --reason TEXT]
  ledger.py ret AID "<return line 1>" "<return line 3: spend: calls a/b · out c/d>"
  ledger.py done TASKS                   mark coordinator-inline tasks done
  ledger.py next                         ready tasks, grouped for batching, plus totals
  ledger.py decide "<one line>" [PATH]   append a decision to CONTEXT.md
  ledger.py render                       regenerate the session README.md
  ledger.py close                        render, mark the session closed

TASKS is comma-separated. TRIAGE is a built-in task for the triage consultant.
Budget defaults: .claude/agents/consultant.md (BUDGETS block). Scope fence: provision.md Writes column.
"""
import argparse
import fnmatch
import json
import os
import pathlib
import re
import subprocess
import sys
import time

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import _session  # noqa: E402

ROOT = _session.ROOT
AGENTS = ("coordinator", "consultant", "engineer", "engineer-m3")
NONE = {"", "-", "—", "n/a", "none"}
PROTECTED = ("provision.md", "specs/", "briefs/", "context/")  # session paths only consultants write
IGNORE = {".claude/.session"}
FIT_RULES = {  # consultant K0: the grade decides class and agent
    "engineer": lambda f, c: (f, c) in (("WL", "M1"), ("WM", "M2")),
    "engineer-m3": lambda f, c: f == "WH" and c == "M3",
    "consultant": lambda f, c: (f[0] in "PU" or f[1] == "H") and c == "M3",
}
FIT_HINT = {"engineer": "engineer takes WL as M1 or WM as M2",
            "engineer-m3": "engineer-m3 takes WH only",
            "consultant": "consultant takes P*, U* or *H; WL/WM go to an engineer"}
SKIP_DIRS = {".git", "node_modules", ".venv", "venv", "__pycache__", ".pytest_cache", ".mypy_cache",
             ".tox", "dist", "build", ".next", ".cache"}
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
    if agent == "engineer-m3":
        return "engineer-m3"
    return None


# ---------- ledger io ----------
def load():
    if LEDGER.exists():
        return json.loads(LEDGER.read_text())
    return {"tasks": {}, "agents": {}, "streams": {}, "triage": None, "next_agent": 1,
            "cap": {}, "prefix": "REF"}


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


def walk(base):
    out = {}
    for dp, dns, fns in os.walk(base):
        dns[:] = [d for d in dns if d not in SKIP_DIRS and d != ".scope"]
        for f in fns:
            p = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, "/")
            if p not in IGNORE:
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
            snap.update({p: sig(p) for p in paths if p not in IGNORE})
            return snap
    snap.update(walk(ROOT))
    return snap


def changed_since(snap):
    now = snapshot()
    ch = {p for p in now if snap.get(p, "absent") != now[p]}
    ch |= {p for p in snap if p not in now}
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


def agent_writes(L, aid):
    ws = []
    for t in L["agents"][aid]["tasks"]:
        ws += L["tasks"].get(t, {}).get("writes", [])
    return ws


# ---------- commands ----------
def cmd_init(a):
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
            if ag == "engineer-m3":
                if cl != "M3":
                    e("engineer-m3 rows are M3")
                if not why:
                    e("engineer-m3 needs Why (consultant K5: all three conditions)")
                if len(writes) > 3 or any(ch in w for w in writes for ch in "*?["):
                    e("engineer-m3 fence must be <=3 exact paths, no globs")
        key = budget_key(ag, cl)
        if key:
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
        if nt["status"] == "rejected":  # re-provisioned after a scope rejection
            nt["status"] = "todo"
        new[t] = nt
    if errs:
        print("INVALID — continue the triage consultant with these lines:")
        print("\n".join(errs))
        sys.exit(1)
    for t, v in L["tasks"].items():  # keep history of tasks dropped by re-triage once started
        if t not in new and v["status"] != "todo":
            new[t] = v
    L["tasks"] = new
    L["cap"], L["prefix"] = task_meta()
    save(L)
    c, o = projected(L)
    print(f"loaded {len(rows)} tasks from {' + '.join(src)} · projected calls {c} out {o}{capstr(L)}")
    cap = L["cap"]
    if (cap.get("calls") and c > cap["calls"]) or (cap.get("out") and o > cap["out"]):
        print("CAP projected spend exceeds the TASK.md cap: continue the triage consultant to re-split; "
              "if still over, ask the user")
    cmd_next(None, header=False)


def spawn_line(L, aid, kind, tasks, calls, out, note=""):
    briefs = sorted({L["tasks"][t]["brief"] for t in tasks if L["tasks"][t]["brief"]})
    T = L["tasks"]
    parts = [f"ID {aid}", f"ref {L.get('prefix', 'REF')}-{SD.name}-{aid}", f"tasks {','.join(tasks)}",
             "class " + ",".join(sorted({T[t]["cls"] for t in tasks})), f"model {model_of(kind)}"]
    if briefs:
        parts.append("brief " + "; ".join(briefs))
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
        x["agent_ids"].append(aid)
        if kind == "consultant" and x["stream"].lower() not in NONE:
            L["streams"][x["stream"]] = aid
    if tasks == ["TRIAGE"]:
        L["triage"] = aid
    open_segment(L, aid, tasks, calls, out)
    save(L)
    note = "+ ≤15-line consultant brief (coordinator C3)" if kind == "consultant" else ""
    print(spawn_line(L, aid, kind, tasks, calls, out, note))


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
    bad = [p for p in changed_since(snap) if not any(allowed(p, k, w) for k, w in active)]

    triage = L.get("triage") or "the triage consultant"
    if bad:
        for t in tasks:
            L["tasks"][t]["status"] = "rejected"
        more = " …" if len(bad) > 10 else ""
        out.append(f"SCOPE {aid} ({kind}) wrote outside its fence: {', '.join(bad[:10])}{more}")
        out.append(f"ROUTE reject; git restore those paths; continue {triage} (`cont {triage} --support`) to re-provision")
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
    elif status == "BLOCKED":
        for t in tasks:
            L["tasks"][t]["status"] = "blocked"
            L["tasks"][t]["blocks"] = L["tasks"][t].get("blocks", 0) + 1
        if kind == "consultant":
            out.append(f"ROUTE ask the user (one batched question) from agents/{aid}/QUESTIONS.md; then `cont {aid}`")
        else:
            who = L["streams"].get(L["tasks"][tasks[0]]["stream"]) if tasks else None
            who = who or triage
            out.append(f"ROUTE `cont {who} --support` with agents/{aid}/QUESTIONS.md; then `cont {aid}` (brief updated)")
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
    if status == "DONE" and not bad:
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
    body = ctx.read_text() if ctx.exists() else "# Session context\n\n## Decisions\n"
    n = len(re.findall(r"^- D\d+ ·", body, re.M)) + 1
    with open(ctx, "w") as f:
        f.write(body.rstrip("\n") + f"\n- D{n} · {text}" + (f" · {path}" if path else "") + "\n")
    return n


def cmd_decide(a):
    L = load()
    print(f"D{decide(L, a.text, a.path or '')}")


def cmd_render(a=None):
    L = load()
    T = L["tasks"]
    task = os.path.relpath(ROOT / "TASK.md", SD).replace(os.sep, "/")
    ri = ref_index()
    ri_link = f" · [reference index]({os.path.relpath(ROOT / ri, SD).replace(os.sep, '/')})" if ri else ""
    lines = [f"# Session {SD.name}", "",
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
    lines += ["", f"Total spent: calls {c} · out {o}{capstr(L)}", "", "## Artefacts"]
    for label, pat in (("Reports", "agents/*/REPORT.md"), ("Syntheses", "agents/*/SYNTHESIS.md"),
                       ("Specs", "specs/*.md"), ("Briefs", "briefs/*.md"), ("Context", "context/*.md"),
                       ("Test packages", "**/*.zip")):
        found = sorted(p.relative_to(SD).as_posix() for p in SD.glob(pat))
        if found:
            lines.append(f"- {label}: " + " · ".join(f"[{p}]({p})" for p in found))
    (SD / "README.md").write_text("\n".join(lines) + "\n")
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
    sub.add_parser("init")
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
    s = sub.add_parser("done")
    s.add_argument("tasks")
    sub.add_parser("next")
    s = sub.add_parser("decide")
    s.add_argument("text")
    s.add_argument("path", nargs="?")
    sub.add_parser("render")
    sub.add_parser("close")
    a = p.parse_args()
    SD, _ = _session.current(create=a.cmd in ("init", "spawn"))
    LEDGER = SD / "ledger.json"
    {"init": cmd_init, "spawn": cmd_spawn, "cont": cmd_cont, "ret": cmd_ret, "done": cmd_done,
     "next": cmd_next, "decide": cmd_decide, "render": cmd_render, "close": cmd_close}[a.cmd](a)


if __name__ == "__main__":
    main()
