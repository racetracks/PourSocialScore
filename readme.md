# PourSocialScore EllesmereUI

Pour Social Score in EllesmereUI's style: the addon folder
`PourSocialScore_EllesmereUI`, loaded on demand by the Pour Social Score core
(racetracks/PourSocialScore) when "Enable EllesmereUI integration" is on and
EllesmereUI is installed.

- A Pour Social Score window next to the Friends list, painted through
  EllesmereUI's skinning API (`EllesmereUI.RegisterSkin`). Its Player Ignore
  List tab uses one pooled row list (`EUI_Rows.lua`) that the other list tabs
  will share.
- A "Pour Social Score" section in the EllesmereUI panel (plugin API,
  registered by the core).

It uses EllesmereUI's documented public APIs only and contains no
EllesmereUI code. Code style follows EllesmereUI's CONTRIBUTING.md (Lua 5.1,
ASCII, house tooltips and popups, `W:DualRow` rows with no empty slots).

Install: copy `PourSocialScore_EllesmereUI` into `Interface/AddOns` next to
the other PourSocialScore folders, same version.
