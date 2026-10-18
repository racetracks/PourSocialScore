# Agent operating pack: maintainer notes
Purpose: maintainer notes for the agent operating pack (for humans; no agent loads it) · Owner: pack maintainers · Status: current · Related: [CLAUDE.md](../CLAUDE.md), [coordinator](roles/coordinator.md)

## Install
1. Copy `CLAUDE.md`, `TASK.template.md` and `.claude/` to the repo root. Merge `.claude/settings.json` hooks into any existing settings.
2. Add to `.gitignore`: `.claude/.session` and the session root (`sessions/` unless `SESSION_ROOT` is set).
3. CI: `python3 .claude/scripts/sync-token-rules.py --check` (fails when an agent file holds a copy of the token rules: they live only in `CLAUDE.md`, which every agent loads) and `python3 .claude/scripts/check_context.py` (context caps; needs the base commit: `fetch-depth: 2`).
4. Per task: copy `TASK.template.md` to `TASK.md` and fill it. Prompt the main thread with "Run TASK.md."

Requires Python 3.8+ and git (falls back to a tree walk without git). The spawn-logging hook matches the sub-agent tool as `Task|Agent`; change the matcher if your Claude Code version names it differently.

## Enforcement
| Mechanism | Where | What it stops |
|---|---|---|
| Token rules in `CLAUDE.md` only | `CLAUDE.md` TOKEN-RULES block, loaded by every agent; `sync-token-rules.py --check` | stale copies of the rules in agent files |
| Tool fence | `consultant.md` has no Bash | consultants running builds, tests or scripts |
| Provisioning validation | `ledger.py init` | a Fit grade (scope × complexity) that does not match its class and agent, wrong agent for a class, missing Writes fence or brief, engineer-m3 without Why or with a wide fence, over-default budgets without Why |
| Scope fence | `ledger.py ret` | any write outside the agent's Writes (consultants: session directory only; engineers: never specs, briefs, `provision.md`, `context/`) |
| Spend ledger | `ledger.py ret` / `cont` | silent overruns: BUDGET, ≥1.5× original, TASK cap; extensions need a logged reason |
| Sonnet re-run | `ledger.py ret` / `next` (`RERUN`, `ROUTE re-run`) | a failed or blocked engineer-m1 task costing a consultant turn (`DEC-00389`) |
| Token measurement | `ledger.py render` (`## Tokens`) | judging cost cuts by estimate (`DEC-00391`) |
| Stage close | `tools/stage_close.sh` | a stage closed without the real-save run, the hosted zip or the rendered README (`DEC-00390`) |
| Context caps | `consultant.md` CONTEXT-CAPS block + `check_context.py`, run by `ledger.py ret` (`SHAPE`) and `tools/check_rules.sh` | documents too big or too unstructured for the next agent's budget; code changed without its documentation (`DOCS`; code itself is never capped); `CLAUDE.md` and its imports growing past the startup cap (`DEC-00384`, `DEC-00385`) |
| Zero-token records | `log-prompt.py` hook, `ledger.py render` | the coordinator spending output tokens on logs, task tables and indexes |
| Stale pack | `ledger.py init` | a pack row whose Writes changed since the pack's `Base commit:` (`git diff --name-only`): `RETRIAGE <t>`, status `stale` |
| Brief check | `ledger.py spawn` runs `check_context.py --brief <class> <brief>` | an engineer brief without Writes, exact edits, one acceptance block, rules read, or with hedge words and bare file references: refused with `BRIEF` lines and a ROUTE to the stream consultant |
| Rules read | `ledger.py ret` reads the engineer's transcript | an engineer that did not read `docs/baseline/02_RULES.md` and `docs/pss/02_RULES.md` in full: `RULES` with ROUTE cont; `WARN RULES` when unmeasured (never a pass) |

Scope check limits: it attributes changes by time window, so with parallel agents a path is accepted if any agent active in that window may write it. It cannot see files that are git-ignored outside the session directory.

## Coverage of the original operating instructions
✅ preserved · 🔁 preserved, moved or mechanised · ⚠️ deliberately changed (see next section)

| Original rule | Status | Now |
|---|---|---|
| 0 Token minimisation is the top operating constraint; cheaper of two correct approaches | ✅ | `CLAUDE.md` §0 |
| 0 Task prompt may be section 8 alone | ✅ | `TASK.template.md` preamble |
| 1.1 Clone/pull once; local checkout, never web fetch | ✅ | token rules: Read |
| 1.1 Check session context and existing outputs before reading; never regenerate | ✅ | token rules: Context |
| 1.1 Resume from session context after restart/compaction | ✅ | token rules: Resume |
| 1.2 grep, line ranges, head/tail, --stat; Full only when marked; never re-read | ✅ | token rules: Read; `TASK.md#inputs` |
| 1.2 Summarise large tool output; no raw dumps | ✅ | token rules: Tool output |
| 1.3 Quiet output, failure-only tests, CI log tail, batched ID allocation | ✅ | token rules: Commands |
| 1.4 Targeted edits, no echoing, script-generated content, each fact once | ✅ | token rules: Write, Pointers |
| 1.5 Plan once, no narration, stop at acceptance, diagnose before retry | ✅ | token rules: Reason |
| 1.6 No greetings/narration/offers; result + paths + blockers; batched questions | ✅ | token rules: Return; `CLAUDE.md` §3; coordinator C1.7, C6 |
| 2.1 Tiering, lowest tier, records scale with tier | ⚠️ | coordinator C1.2; `CLAUDE.md` §0 |
| 2.2 Decompose and classify; task table (ID, class, owner, model, status); re-classify | 🔁 | consultant K0 (Fit grade); `ledger.json`; `README.md` via `L render`; K4 re-grade |
| 2.3 Cost model | ⚠️ | token rules header; coordinator C1 |
| 2.4 Main thread fixed model; orchestration | ✅ / ⚠️ | coordinator preamble; M3 work moved to consultants |
| 2.5 Planners write for executors; executor ambiguity = defective spec; never guess | ✅ | consultant K1, K3; engineer rule 4 |
| 2.6 Model chosen at spawn, kept for life; pinned agent types; executor only when brief suffices | ✅ | `CLAUDE.md` §2; agent frontmatter; Fit `W` required for engineers |
| 2.6 Executors at lowest reasoning effort | ✅ | `effort: low` in `engineer.md` and `engineer-m1.md` frontmatter |
| 2.7 Offload M1/M2, script first, batch, rule-based briefs, M2 stops on edge cases, verify by acceptance | ✅ | consultant K0, K3; engineer rules 3–4; coordinator C4 |
| 2.8 Spawn discipline, one agent per stream, continue over spawn, ≤5-line returns, reports opened only if needed | ✅ | coordinator C2–C4; `CLAUDE.md` §3 |
| 2.8 Brief states role, scope, class, model, acceptance, budget | 🔁 | spawn line (ID, ref, class, model, budget) + brief (scope, acceptance) |
| 2.9 Plan, proceed unless irreversible/ambiguous | 🔁 | plan = `provision.md`, linked from `CONTEXT.md`; coordinator C1.7 |
| 2.9 Executors start only with acceptance tests | 🔁 | `L spawn` refuses briefs without an acceptance check |
| 2.9 Validate cheaply; fail fast | ✅ | token rules: Commands |
| 2.10 Session context file: goal, constraints, decisions, file map, reference index, task table, plan | 🔁 | `CONTEXT.md` links `TASK.md` (goal, constraints), holds decisions, links plan + ledger; file map in `context/<stream>.md`; reference index linked from session `README.md` |
| 2.10 Briefs: path refs, section refs by number, verbatim blocks; no thread history | ✅ | coordinator C3; `TASK.md#verbatim-blocks` by pointer |
| 2.11 Parallel tool calls; commit per milestone | ✅ | token rules: Tool output; coordinator C2, C5 |
| 3.1 Single source, current truth + Changelog, self-contained, structure over prose, vocabulary, docs move with code | ✅ | consultant K2; engineer rule 6 |
| 3.2 Header block on every document | ✅ | consultant K2 (all consultant documents); agent reports carry ref ID |
| 3.3 Spec structure, exhaustive | ✅ | consultant K2 (adds 11 Review) |
| 3.4 Derivable content and reports generated by script | ✅ | token rules: Write; engineer rule 3; `ledger.py render` |
| 4 Session layout, paths relative to session dir | 🔁 | `CLAUDE.md` §5; `_session.py` |
| 4 `prompts/NN.md` verbatim + summary, dedup, index | 🔁 | `log-prompt.py` hook (zero model tokens) |
| 4 Session `README.md` index + visuals, links prompts, reports, reference index, outputs, test zips | 🔁 | `ledger.py render` |
| 5 Agent deliverables: own dir, ≤5-line return, standalone report with ref ID, inputs, method, findings, artefacts, open issues, next steps | ✅ | `CLAUDE.md` §3; consultant K6; engineer rule 7; engineer-m3 rule 5 |
| 6 Visuals, test zips linked | ✅ | consultant K6; `ledger.py render` |
| 7 Peer-review docs: DRAFT mark, script skeleton, per-API 6 items with full detail, document level, exhaustive | ✅ | consultant K6 pointer; `.claude/roles/peer-review.md` |
| 8 Current task | ✅ | `TASK.template.md` (adds budget cap, reference index, direct tasks) |

## Deliberate changes (from your design brief)
| Original | Now | Why |
|---|---|---|
| 2.4/2.8 Main thread does M3 decisions, synthesis, implementation from design docs it has read | coordinator only routes; consultants do M3, engineers implement | coordinator and consultants never write code or tests |
| 2.3 Keep reading-heavy judgement in the main thread | in consultants, reused per stream | coordinator context stays minimal |
| 2.3 No cheaper sub-agent model → work inline | still delegate; batch harder | production never enters coordinator context |
| 2.1 T1 ≤5 calls inline; T2 inline with full records | T1 ≤3 calls, no code/tests; all T2+ coordinated | any code change goes to an engineer |
| 2.5 Executor = small model | `engineer-m1` (Haiku) for `WL`, pilot with `Review: yes` and one Sonnet re-run; `engineer` (Sonnet) for `WM` | the author (`DEC-00389`) |
| 1.3 Tool-call budgets only | adds `out` ceiling | output tokens are the main cost |

New since the original: Fit grading (consultant K0), engineer-m3 (consultant K5 gate), `out` budget dimension, Direct tasks, recon lane, scope fence, TASK budget cap, acceptance gate at spawn, engineer-m1 (Haiku) with the Sonnet re-run, token measurement, stage-close script.
