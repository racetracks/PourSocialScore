# PourSocialScore project instructions (paste into the Claude project)

You are working on PourSocialScore (PSS), Dan's WoW chat moderation addon. It follows the WoW addon baseline pack (rules, pipeline, staged delivery) and the scratch usage pack; this PSS pack adds and overrides for PSS. Read the baseline README, 02_RULES, 07 and 10, the scratch pack README, then this pack's 00_README and 06_STATUS_AND_NEXT before the first step.

Repos: racetracks/PourSocialScore (seven folders, one version) and racetracks/scratch (hosting). Never write to racetracks/PourSocialScore-EllesmereUI (retired). Read only: EllesmereGaming/EllesmereUI (all rights reserved), Gethe/wow-ui-source.

Clients: Retail 120007 and Camelot 16001, three TOCs per folder. Everything on M via PourSocialScore_NS; core fires M.Events; UIs write only through core setters. Tabs, except PourSocialScore_EllesmereUI (4 spaces).

Live release: 3.3.1 (the 3.3.0 parity project is closed). Current feature: the new PSS window, version line 3.4.0 (docs/pss/09_PSS_UI_PROJECT.md): one window in the EllesmereUI port's layout (the port is the reference; the old GUI is not authoritative), logic in PourSocialScore_Libraries, drawing in PourSocialScore_UI, opened with /pss tui until the cutover (its files then move into PourSocialScore_GUI). Three looks: Blizzard (Default), Modern (Blizzard's new Social window art), Dark (the port's style); accent always the class colour. Fixes to an unmerged dev build count up as devNNN_2, _3. Project data on scratch: always read latest/ first (latest/README.md).

PSS rules (02_RULES in the PSS pack):
- Core holds only the chat filtering engine and the launchpad; anything not regularly active, including code both UIs share, goes in PourSocialScore_Libraries, with a measured resident cost.
- No application or service logic in PourSocialScore_GUI or PourSocialScore_EllesmereUI. The native GUI never reads or loads a file from the EllesmereUI folder; the EUI folder is read only during parity work.
- Ports to native use only our own or Blizzard resources, look as close as possible to the EUI version, and may copy our own EUI code when it is smaller (never EllesmereUI's code).
- Every number the EUI window shows equals the native window's. Logging loads only when logs are called.
- Taint and secrets (baseline 02 J, PSS 02 section 10): never write or replace Blizzard state, post-hooks and Menu.ModifyMenu only; every chat, unit and hook value goes through M.PSS_IsSecret before any compare or index; a secret line is neither filtered nor counted; test chat and hook changes with addonChatRestrictionsForced and addonCombatRestrictionsForced.
- Never change TOC Title or Notes. SavedVariables layout changes need Dan's OK and a migration validated on the three real saves.
- Before pushing: sh tools/check_rules.sh, sh tools/harness/check_eui_all.sh, PSS_REAL_SAVES=/mnt/project-files/baselines sh tools/harness/validate_all.sh, and ui_compare.sh / eui_compare.sh for any window that should not change.
- Test zips on scratch PourSocialScore/test-builds/, linked as https://github.com/racetracks/scratch/raw/main/<path>. Never commit real saves to the addon repo.
- Dan tests in game and merges. Numbered questions with a recommendation; answer first; measure, don't estimate.
