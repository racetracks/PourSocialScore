# W2 share b notes (Filters, Events, Options tabs)

Done: G9 (Events view: IsCustom, Scoped, PeriodIs, ScopeText), G10 (M.PSS_IOOn, M.PSS_IOMode, M.PSS_ExportText returns the subtitle, M.PSS_ImportStart), G7 for the Chat Filters tab (M.PSS_FilterSummarySpec), G5 for the Chat Filters tab (the redundant V.dirty after Reset Block History dropped; FILTER_HISTORY_CHANGED marks the list).

Harness: tools/harness/check_w2b.lua (wired in validate_all.sh as "window tidy W2"); the G9, G10 and G7 cases fail on main (functions missing); G5 guards the behaviour.

Not proven: wrapped text layouts (the stub does not wrap). tui_compare identical (125 steps) after every commit.

Left to the other share: G1-G4, G6, G8, G5 and G7 parts in Players and Guilds tabs, History, Detail.
Shared file touched: tools/harness/validate_all.sh (one block for check_w2b.lua).
