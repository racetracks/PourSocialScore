local _, TK = ...

-- Every user-facing kit string (ASCII only).
TK.T = {
	TITLE = "PSS TestKit",
	IMPORT = "Import",
	IMPORT_TITLE = "Import a TestKit string",
	IMPORT_HINT = "Paste the TestKit string here.",
	CANCEL = "Cancel",
	RELOAD = "Reload",
	FOOTER = "%d unsaved \194\183 /reload saves the results.",
	ERR_FAILED = "Import failed.",
	RUN = "Run",
	PREV = "<",
	NEXT = ">",
	SHOW_DONE = "Show done",
	RERUN = "Re-run automatic",
	NO_RUN = "No tests yet. Click Import and paste the TestKit string from the build's test README.",
	SUMMARY = "%d/%d complete",
	ALL_DONE = "All checks done. /reload, then upload WTF/Account/<account>/SavedVariables/PSS_TestKit.lua to scratch.",
	GROUP = "%s %d/%d",
	ICON_OK = "[ok]",
	ICON_TODO = "[..]",
	ICON_OTHER = "[x]",
}
