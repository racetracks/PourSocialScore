# Closed project: native GUI parity with the EllesmereUI window (3.3.0, issue #78)

**Closed 2026-10-07 by Dan, shipped as 3.3.1:** "we're just going to merge whatever its at now and call that done, ive got other plans, scrap those features and just stamp this at 3.3.1". Stages 1 to 5 shipped; the rest were dropped, not parked. Both windows it covered were replaced by the one PSS window (09) at 3.4.0.25.

The original analysis and plan: `reference/plans-3.3-parity/` (the plan's step table predates the decisions; the outcome below wins). Issue #77 note: `reference/issues/eui-read-only-vs-logic-move.md`.

## Objective
The native window (`PourSocialScore_GUI`) and the EllesmereUI window (`PourSocialScore_EllesmereUI`) offer the same features and show the same numbers, each in its own look, with the folders independent (02 sections 6 and 7). Parity is not shared UI code.

## Decisions (Dan, 2026-10-05 16:32Z)
1. **Yes:** retire `PSS_BlockStats`; native reads `History.Recent*`; the `blockStats` prune is approved (shipped, stage 2).
2. **Yes:** native gets the breadcrumb and back / forward navigation (Claude had recommended no).
3. **Yes:** native gets an Events tab.
4. **Port it:** the three-page detail pane (Summary / Event History / View-Edit Rule) goes into the native window, not pies on the pop-ups.
5. The front ends are independent; shared needs become shared functions in Libraries.
Also: issue #77 decided option b (logic leaves the EUI folder for Libraries; shipped, stage 1). The layout card (side pane, 1290 wide) was never answered; built on the recommendation.

Decisions 2 to 4 were dropped with the project here and delivered later by the new window (09).

## Outcome
| Stage | Build | What | PR |
| --- | --- | --- | --- |
| 1 | 3.3.0-dev001 | Events logic to `PSS_EventsQuery.lua` (Libraries) | #79 |
| 2 | 3.3.0-dev002 | One counting system; `PSS_BlockStats` retired | #80 |
| 3 | 3.3.0-dev003 | Managed Communities row | #81 |
| 4 | 3.3.0-dev004 | Totals pane and period pie (`PSS_Pie.lua`) | #82 |
| 5 | 3.3.0-dev005 | The window opens next to Retail 12.1's Social window (`SocialUIFrame`) as well as FriendsFrame | #85 |
| 6 to 13 | | Type pie, detail pane, Events tab, breadcrumb, small matches, a UI-logic rules check | Dropped |
| Release | 3.3.1 | Version only | Released |
