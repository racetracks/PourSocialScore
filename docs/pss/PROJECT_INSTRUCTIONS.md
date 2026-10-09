# PourSocialScore project instructions (paste into the Claude project)

You are working on PourSocialScore (PSS), the author's WoW chat moderation addon. It follows the WoW addon baseline pack (rules, pipeline, staged delivery) and the scratch usage pack; this PSS pack adds to them and overrides only in docs/pss/02_RULES.md section 12. Start from CLAUDE.md and what it loads (baseline 02 and 10, the scratch rules, this pack's 11, 01, 02 and 06).

Repos: racetracks/PourSocialScore (six folders, one version) and racetracks/Pour-Social-Score_Scratch (hosting and the project files; scratch rules in docs/scratch/05_RULES.md; never a PR there, push to main). Never write to racetracks/PourSocialScore-EllesmereUI (retired). Read only: EllesmereGaming/EllesmereUI (all rights reserved; the reference for UI elements), Gethe/wow-ui-source.

Clients: Retail 120007 and Camelot 16001, three TOCs per folder. Everything on M via PourSocialScore_NS; core fires M.Events; UIs write only through core setters. Tabs everywhere.

State: the live release and the next step are in docs/pss/06_STATUS_AND_NEXT.md. Versions are X.Y.Z.B with a build number that never resets, recorded in versions.json (never shipped) via tools/bump_version.sh; a full release's notes are one summary of every change since the last release, written at release time from its PRs. Test zips via tools/host_build.sh. One window (PourSocialScore_GUI, logic in PourSocialScore_Libraries), opened with /pss, in three looks: Modern (the default), Classic, Dark; every element works in all three; its rules are CLAUDE.md's Interface section. Project data on scratch: always read docs/latest/ first (docs/README.md).

PSS rules (02_RULES in the PSS pack):
- Core holds only the chat filtering engine and the launchpad; anything not regularly active goes in PourSocialScore_Libraries, with a measured resident cost.
- No application or service logic in PourSocialScore_GUI. Logging loads only when logs are called. Every number the window shows comes from the core's counters.
- Taint and secrets (baseline 02 J, PSS 02 section 10): never write or replace Blizzard state, post-hooks and Menu.ModifyMenu only; every chat, unit and hook value goes through M.PSS_IsSecret before any compare or index; a secret line is neither filtered nor counted; test chat and hook changes with addonChatRestrictionsForced and addonCombatRestrictionsForced.
- Never change TOC Title or Notes. SavedVariables layout changes need the author's OK and a migration validated on the author's real saves; every saved field is in the schema map (PSS_Schema.lua).
- Simulate the client while coding (the harness's wow_stub.lua via run.lua); before pushing: sh tools/check_rules.sh, PSS_REAL_SAVES=<out dir> sh tools/harness/validate_all.sh (saves built from scratch SavedVariables/ with tools/harness/build_saves.sh), and tui_compare.sh (all three looks) for any change that should not show.
- Test zips on scratch releases/PourSocialScore-<version>-<YYYY-MM-DD-hh-mm>.zip plus the newest in latest/, linked as https://github.com/racetracks/Pour-Social-Score_Scratch/raw/main/<path>. Real saves in scratch SavedVariables/<version>/; never commit them to the addon repo.
- The author tests in game and merges. Numbered questions with a recommendation; answer first; measure, don't estimate.
