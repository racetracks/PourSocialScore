# Repos and references

## Repos a project writes to (all private)
| Role | Purpose |
| --- | --- |
| **Addon repo** | The addon: every addon folder (core, options/data, UI, library, shipped data, any suite integration), `tools/` (rules checks, harness), readme.txt, history.txt, `.github/workflows` (rules.yml, release.yml). One repo, one version for all folders. |
| **Hosting repo** | Where test zips, handover packs and saves are hosted. Covered by its own pack. |

Lessons:
- A separate repo for a UI suite integration means a second version line, a cross-repo CI token and test zips that must match branch names. One project merged its integration repo back into the addon repo for this reason. Prefer one repo; archive a retired repo rather than writing to it.
- Each Claude session works on its own `claude/...` branch cut from the latest main. Claude cannot delete branches (403).
- The addon-specific pack names the real repos.

## Repos worth reviewing (read only)
| Repo | Why |
| --- | --- |
| **EllesmereUI** (https://github.com/EllesmereGaming/EllesmereUI) | A full UI replacement suite: read its own docs and contributor guide before integrating with it (05_UI_SUITES_AND_KNOWN_FIXES.md). Check its licence: learn behaviour, copy nothing, call only documented API. |
| **ElvUI** (https://github.com/tukui-org/ElvUI) | How a large addon splits into an always-loaded core and load-on-demand parts (options in a `## LoadOnDemand: 1` addon loaded with `C_AddOns.EnableAddOn` / `LoadAddOn`, `RequiredDeps`). Learn the structure; copy no code |
| **Questie** (https://github.com/Questie/Questie) | Clear console output on upgrade ("upgraded from X to Y") and how a big addon handles saved data across versions. Learn the approach; copy no code |
| **wow-ui-source** (https://github.com/Gethe/wow-ui-source) | Blizzard's FrameXML source: widget templates (PortraitFrameTemplate, InsetFrameTemplate, UICheckButtonTemplate, InputBoxTemplate, FauxScrollFrameTemplate), StaticPopup, the Social UI, C_AddOns, tab templates. The reference for building a native look. |

## Third-party references that helped
| Reference | What it taught |
| --- | --- |
| **Warcraft Wiki: Interface customization** (https://warcraft.wiki.gg/wiki/Warcraft_Wiki:Interface_customization) | The starting point for addon development: TOC format, the API and widget references, events, secure code and taint |
| **wago.tools** (https://wago.tools) | Interface numbers per client, API signatures, DB2 lookups |
| **Townlong Yak** (https://www.townlong-yak.com/framexml/live, API docs at https://www.townlong-yak.com/framexml/live/Blizzard_APIDocumentation) | Blizzard's FrameXML per build and the generated API docs, including secret-value annotations (02 J11) |
| **BlizzardInterfaceResources** (https://github.com/Ketho/BlizzardInterfaceResources) | API, event and CVar dumps per client |
| **WoWUIBugs** (https://github.com/Stanzilla/WoWUIBugs) | Known UI and API bugs, before assuming a bug is ours |
| **DBM** (https://github.com/DeadlyBossMods) | `## Category`, `## Group` and coloured Titles that nest an addon's folders in the AddOns list. Copy the logic, never its IDs |

Rule for all of them: **copy logic, never code or IDs.**

## The WoW API reference set (`reference/wow-api/`)
A condensed ASCII rewrite of the Warcraft Wiki hub and its security pages, compiled 2026-10-08. Start with its README, which says which file to read for what:
- 00: load order, events, SavedVariables, hooking, Retail 12.x limits, debugging tools, links.
- 01: TOC format, directives and suffixes, interface numbers, `WOW_PROJECT_ID` (02 B5, B6).
- 02 to 06: object security, secure execution and taint, secure templates and handlers, diagnosing a taint report (02 J1 to J6, J10).
- 07: Retail 12.x secret values and the restriction CVars (02 J7 to J9).

Read it for any hook, Blizzard frame, combat or instance path, chat event, secret value, taint report, TOC or Interface change, or API that differs between clients. It is reference, not rules: 02 J and B carry the rules, and its README lists where it differs from this baseline (the baseline wins). Where it and the live wiki or Blizzard's source differ, the live source wins.
