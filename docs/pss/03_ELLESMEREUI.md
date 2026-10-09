# EllesmereUI: the reference for UI work, and the old integration

PSS has one window (`PourSocialScore_GUI`, 09) and no EllesmereUI integration. EllesmereUI stays useful: it is a mature UI framework, and the window was ported from our own EllesmereUI window. Section 0 is how to use it; section 1 keeps the lessons of the old integration.

## 0. EllesmereUI as the reference for building UI elements (Dan, 2026-10-08)
When building or changing a UI element needs more information than our own code and Blizzard's give (how a control behaves, lays out, skins, scrolls, pools or handles a corner case), **check out the EllesmereUI repo and reference it wherever possible, as a mature framework for UI porting.**
1. **Where to look, in this order:** our window as it is (`PourSocialScore_GUI`, the kit, CLAUDE.md Interface, 09 code map); our own EllesmereUI window, the port's reference, in git history (`git fetch origin tag v3.4.0.24` then `git show v3.4.0.24:PourSocialScore_EllesmereUI/<file>`; or the tag `v3.3.1`); then EllesmereUI itself, `EllesmereGaming/EllesmereUI`.
2. **Getting EllesmereUI into a session:** add it with `add_repo` (read access; never push), then a shallow or sparse clone outside the addon repo (for example the session scratchpad). If it cannot be added, say so and ask; never guess its behaviour.
3. **Read only, all rights reserved.** EllesmereUI is a reference, never a source: read it to learn how it solves a problem, then **rewrite the solution to suit our rules**; never copy its code verbatim, and never copy its media, fonts (Expressway is "Do not distribute"), IDs or names. The baseline's I1 to I4 and H3, H4 still apply.
4. **What "rewrite to our rules" means:** Lua 5.1 and tabs (02 section 1); our kit and the three looks, every element in Modern, Classic and Dark (CLAUDE.md Interface, the first rule); logic in `PourSocialScore_Libraries`, drawing only in `PourSocialScore_GUI`; PSS names only, no `EUI` or `Ellesmere` names (`check_rules.sh`); zero cost until opened, no OnUpdate polling, frames reused (baseline C); taint and secret values (baseline 02 J, PSS 02 section 10); Blizzard's or our own resources only (baseline I1).
5. **Say where it came from:** a PR that ports behaviour from EllesmereUI names the EllesmereUI file or feature it studied, and what was rewritten and why.

## 1. The old integration (3.1.0 to 3.4.0.24): what still applies
PSS had a second front end, `PourSocialScore_EllesmereUI` (EUI), drawn with EllesmereUI's plugin and skinning APIs, beside the native window; both rendered from `M.PSS_OPTIONS`, read the same counters and wrote through core setters. It was deleted at 3.4.0.25 with its bridge (`PSS_EUI.lua`), `check_rules_eui.sh` and the EUI harness. The full code, the bridge, the plugin and skinning API use and EUI's house rules are in git history: `git show v3.4.0.24:PourSocialScore_EllesmereUI/<file>`; the full write-up of the integration (bridge, APIs, house rules, the tab fix) is `git show v3.4.1.53:docs/pss/03_ELLESMEREUI.md`.

Lessons that still apply to the window:
- **Read the screenshot first.** The tab "double shade" bug (2026-10-04) cost two wrong guesses before the screenshot showed Dan was on the plain fallback look, not the skin. Ask which look and which object a screenshot shows.
- **Fade text with the FontString's `SetAlpha`, never `SetTextColor` alpha:** colour alpha leaves the font shadow at full strength, which reads as a second, offset label (baseline 05 known fix 1, H7).
- **Every look must be checked** (then skin on and off; now Modern, Classic and Dark).
- **Link hover:** call `GameTooltip:SetHyperlink` only for link kinds with a tooltip (an allow list); a `trade:` link opens the profession window on hover otherwise (baseline 05 known fix 2, H8).
- **Guard undocumented API:** a skin function that exists but is not documented (EUI's `S.SetTabSelection`) is feature-detected before every call.
- **No test-only globals:** tests reach the addon through its namespace and frames (baseline A11).
- **Licence:** reading EllesmereUI to learn behaviour is fine; copying it is not (all rights reserved). Use only documented API, never `_` fields, never hook its functions (baseline H3, H4).
