# Peer-review docs (consultant K6)
Read in full only when `TASK.md` says `Peer-review docs required: yes`; cite this file in every brief that produces these docs.

- **Peer-review docs** (only when `TASK.md` asks): mark **DRAFT — for peer review**. An engineer generates the skeleton by script; you fill judgement content only.
  - Per API (every API built or changed: public and internal functions, event handlers, callbacks, exposed interfaces):
    1. Name and signature: identifier, parameters, return values.
    2. Inputs: name, type, required/optional, valid range or format, default, example.
    3. Outputs: return values and side effects (state, saved variables, events, UI), with examples.
    4. Errors and edge cases: conditions and handling.
    5. Traffic flow: callers, callees, triggering events, data movement; a Mermaid sequence or flow diagram per significant flow.
    6. Architectural position: module/layer, dependencies, dependents.
  - Document: architecture overview (Mermaid module/layer diagram) · end-to-end flow diagram for each main user-facing or event-driven path · data structures (every table, object and saved variable: fields, types, defaults, examples) · file map · open questions and known limitations.
  - Follows K2 documentation rules. Exhaustive: never omit an API for brevity.
