# Task: restructure PSS: feature map, archive port plan and roadmap (plan only, no build)
Purpose: the session's task · owner coordinator · status live · related [prompt 01](../Pour-Social-Score_Scratch/temp/2026/11/23/04-17-30-Mon-zealous-ramanujan-qvpx71/prompts/01.md), CONTEXT.md, provision.md

**Goal:** the author changes direction: the addon keeps only Chat Filtering (all variants), Spyglass and the UI kit, plus the TestKit (may later move to its own repo). Everything else leaves PSS. Two working addons result: (A) the new lean PSS (chat filters + Spyglass + UI kit + TestKit), (B) a second working addon that is effectively all of the current addon without the chat filters. The current addon, as it stands at `origin/main` c061fab (3.9.0.163), is ported whole to a new archive repo and to scratch for reference and posterity.

**Scope change (prompts 02, 03; supersedes the goal above where they differ):** A = PSS, stays in this repo and the current scratch repo, keeps every `PourSocialScore*` name and SavedVariables global: Chat Filtering (all variants), ALL blocking (Player and Guild Ignore Lists, invite/trade/duel blocking, block events and logging), Spyglass, UI kit, TestKit. B = everything else, with no chat filters and no blocking, ported to the new repos `racetracks/wow-framework` (addon) and `racetracks/wow-framework-scratch` (scratch); all documentation comes across and is updated to reflect the change (both sides). Archive everything (the author: "everything"). Design the migration of the entire repo including the addon change.

**Mandatory deliverables** (all in the session temp root on scratch, linked from its `README.md`):
1. `reports/feature-map.md`: every current feature/module/file group, what each kept feature (Chat Filtering variants, Spyglass, UI kit, TestKit) depends on (code, saved variables, libraries, events, options, logging, communities, harness, tools, CI), and for each item: goes to A, B, both (shared), archive only, or drop.
2. `reports/plan.md`: detailed plan: archive port (new repo + scratch snapshot, history kept), split into A and B (repo layout, TOC/addon names, shared code strategy, saved-variable migration so no player data is lost, CI/release/harness per repo), risks, decisions for the author (numbered, each with a recommendation).
3. `reports/roadmap.md`: ordered workload: one stage per session, one PR per stage; each stage with agents (role and class), budgets (calls/out per `.claude/agents/consultant.md#budgets`), inputs, acceptance check, dependencies; parallel lanes marked.
4. A draft plan pack `projects/pss-restructure/` (TASK.md, provision.md, briefs/specs as needed) that a build session can load with `L init --pack`, checked by `L pack pss-restructure`.

**Completion criteria:** all four exist, pass `check_context.py`, `L pack` passes, every reference linked (`DEC-00068`); no code, TOC or save change in this session.

**Constraints:**
- Never Haiku: no `engineer-m1` rows in any provision, this session or the planned ones; mechanical work goes to `engineer` (Sonnet), judgement to consultant / engineer-m3.
- Plan only: no change to addon code, saves or releases; no new repo created in this session (creating it is a roadmap stage needing the author's OK).
- Upgrades are sacred (`docs/pss/11_PREFERENCES.md#values`): every save split/migration gets the author's OK, validated on real saves.
- Budgets per core §4; read cost minimised; consultants read the code map before source.

**Inputs** (path — Full | sections/anchors):
- `docs/pss/01_HANDOVER.md` — sections as needed (the addon as it works)
- `docs/pss/15_ROUTES.md#route-table` — rows touched
- `docs/pss/16_INTERFACE.md` — UI kit sections
- scratch `documents/code-map/01_Summary.md` (code map at bfc6849) and its siblings
- scratch `.next/NEXT.md`, `docs/pss/06_STATUS_AND_NEXT.md#now`
- repo top folders: `PourSocialScore*/`, `PSS_TestKit/`, `tools/`, `.github/workflows/`

**Verbatim blocks** (passed to agents unchanged):
- the author's prompt: [prompts/01.md](../Pour-Social-Score_Scratch/temp/2026/11/23/04-17-30-Mon-zealous-ramanujan-qvpx71/prompts/01.md)

**Peer-review docs required:** no
