-- Graphics settings (/pss gfx, 3.5.0, Camelot only), as a run.lua script.
-- The phase is PSS_PHASE; each prints "PASS gfx <phase>" or "FAIL gfx: ...".
--   logic    (PSS_CAMELOT=1) allow-list, export, parse, preview, apply, refusals
--   history  (PSS_CAMELOT=1) the last 5 sets: packing, cap, diff, restore
--   keep     (PSS_CAMELOT=1) Keep, Revert, the keep prompt's text
--   retail   (no PSS_CAMELOT) /pss gfx says Camelot only, nothing exists
--   noapi    (PSS_CAMELOT=1 PSS_GFX_NOAPI=1, or PSS_GFX_OLDAPI=1 for the old name)
--   popup    (PSS_CAMELOT=1) the popup: Export, Import, Reload UI, Escape, in all looks
--   apply    (PSS_CAMELOT=1) writes a save with a change waiting (gfxPending)
--   reload   (PSS_CAMELOT=1 PSS_RELOAD=1 PSS_GFX_SET=graphicsQuality=2, on the
--            "apply" save; PSS_GFX_RUN = keep | timeout | escape | revert | none)
--            the keep prompt after a /reload
--   history_ui (PSS_CAMELOT=1) the History view in the popup, in all looks
-- The stub's CVar store, console and ReloadUI are in wow_stub.lua (7.1 of the
-- design on scratch docs/latest/graphics-settings/01_DESIGN.md).
local phase = os.getenv("PSS_PHASE") or "logic"
local fail = false
local function check(ok, msg) if not ok then print("FAIL gfx: " .. phase .. ": " .. msg) fail = true end return ok end
local loaded = function(name) return C_AddOns.IsAddOnLoaded(name) end

local realPrint = print
local said
local function capture(fn, ...)
	said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local ok, a, b, c = pcall(fn, ...)
	print = realPrint
	check(ok, "error: " .. tostring(a))
	return said, a, b, c
end
local function has(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return s end end
end
local function lines(text)
	local out = {}
	for l in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = l end
	if out[#out] == "" then out[#out] = nil end
	return out
end
local function map(text)
	local out = {}
	for i, l in ipairs(lines(text)) do
		if i > 1 then
			local n, v = l:match("^([^=]+)=(.*)$")
			if n then out[n] = v end
		end
	end
	return out
end
local function setLine(text, name, value)
	local out = {}
	for _, l in ipairs(lines(text)) do
		if l:match("^" .. name .. "=") then l = name .. "=" .. value end
		out[#out + 1] = l
	end
	return table.concat(out, "\n")
end
local allWrites = {}		-- every SetCVar name of the run, across resets
local function reset()
	for _, w in ipairs(H.cvarWrites) do allWrites[#allWrites + 1] = w[1] end
	H.SeedGfx()
	H.cvarWrites, H.reloads, H.combat = {}, 0, false
	PourSocialScoreDB.gfxSets = nil
	PourSocialScoreDB.gfxPending = nil
end
local function wrote(name)
	for _, w in ipairs(H.cvarWrites) do if w[1] == name then return true end end
end
local function value(name) return H.cvars[name].value end

local ALLOWED = { "farclip", "ffxAntiAliasingMode", "graphicsLiquidDetail", "graphicsQuality", "graphicsShadowQuality",
	"graphicsTextureResolution", "graphicsViewDistance", "gxAdapter", "gxFullscreenResolution", "gxMaximize",
	"gxMonitor", "gxWindow", "particleDensity", "renderScale", "stuckGfx", "vsync" }
local NOT_ALLOWED = { "secureGfx", "readOnlyGfx", "lockedGfx", "addonCombatRestrictionsForced", "Sound_MasterVolume",
	"autoLootDefault", "gxRestart" }

local function needLibraries()
	check(M.PSS_Need("Libraries"), "Libraries did not load")
	return loaded("PourSocialScore_Libraries")
end

-- change one setting through the real path (Export, edit, Parse, Apply)
local function applyChange(name, new)
	local text = M.PSS_GfxExportText()
	local plan = M.PSS_GfxParse(setLine(text, name, new))
	if not plan then return false end
	return M.PSS_GfxApply(plan)
end

local phases = {}

------------------------------------------------------------------------
-- logic
------------------------------------------------------------------------
function phases.logic()
	check(not loaded("PourSocialScore_Libraries"), "Libraries loaded at login")
	needLibraries()
	check(M.PSS_GfxList and M.PSS_GfxExportText and M.PSS_GfxParse and M.PSS_GfxSummary and M.PSS_GfxApply,
		"the functions are not defined on Camelot")
	reset()

	-- the allow-list: graphics and display CVars in; secure, read-only, locked,
	-- addon restriction, Sound, Game and non-CVar commands out
	local list = M.PSS_GfxList()
	check(type(list) == "table" and #list == #ALLOWED, "list has " .. tostring(list and #list) .. " names, wanted " .. #ALLOWED)
	for i, n in ipairs(ALLOWED) do check(list and list[i] == n, "list[" .. i .. "] is " .. tostring(list and list[i]) .. ", wanted " .. n) end
	local inList = {}
	for _, n in ipairs(list or {}) do inList[n] = true end
	for _, n in ipairs(NOT_ALLOWED) do check(not inList[n], n .. " is on the list") end
	check(not wrote("graphicsQuality"), "listing wrote a CVar")

	-- export: header, one sorted line per allowed CVar, every value
	local text, count = M.PSS_GfxExportText()
	local ls = lines(text or "")
	check(ls[1] == "PSSGFX1 Camelot 1.0.0", "header is " .. tostring(ls[1]))
	check(count == #ALLOWED and #ls == #ALLOWED + 1, "export has " .. #ls - 1 .. " lines, count " .. tostring(count))
	for i, n in ipairs(ALLOWED) do
		check(ls[i + 1] and ls[i + 1]:match("^" .. n .. "="), "line " .. i + 1 .. " is " .. tostring(ls[i + 1]) .. ", wanted " .. n)
	end
	local m0 = map(text)
	check(m0.farclip == "1300" and m0.gxAdapter == "" and m0.graphicsQuality == "7" and m0.gxFullscreenResolution == "1920x1080",
		"export values (every value, defaults too, an empty one)")
	check(not text:find("secureGfx") and not text:find("Sound_"), "export holds a CVar that is not allowed")

	-- the same export is no change
	local plan, why = M.PSS_GfxParse(text)
	check(plan and #plan.changes == 0 and plan.same == #ALLOWED and plan.skipped == 0, "the current export is not 'no change'")

	-- round trip: change three, import the export, they come back
	H.cvars.graphicsQuality.value = "2"
	H.cvars.gxMaximize.value = "0"
	H.cvars.vsync.value = "0"
	plan, why = M.PSS_GfxParse(text)
	check(plan and #plan.changes == 3 and plan.same == #ALLOWED - 3 and plan.skipped == 0, "preview counts")
	check(#H.cvarWrites == 0, "Parse wrote a CVar")
	local c = plan and plan.changes or {}
	check(c[1] and c[1][1] == "graphicsQuality" and c[1][2] == "2" and c[1][3] == "7", "change 1 is not graphicsQuality 2 -> 7")
	check(c[2] and c[2][1] == "gxMaximize" and c[2][2] == "0" and c[2][3] == "1", "change 2 is not gxMaximize 0 -> 1")
	check(c[3] and c[3][1] == "vsync" and c[3][2] == "0" and c[3][3] == "1", "change 3 is not vsync 0 -> 1")
	local summary = M.PSS_GfxSummary(plan)
	check(summary:find("3 settings will change", 1, true), "summary lacks the count: " .. summary)
	check(summary:find("graphicsQuality: 2 -> 7", 1, true) and summary:find("vsync: 0 -> 1", 1, true), "summary lacks the change lines")
	check(summary:find("Close Blizzard's settings first", 1, true) and summary:find("15 s", 1, true), "summary lacks the instructions")
	check(not summary:find("skipped", 1, true), "summary names skipped lines when none were")
	local ok, applied, refused = M.PSS_GfxApply(plan)
	check(ok == true and applied == 3 and refused == 0, "apply returned " .. tostring(ok) .. " " .. tostring(applied) .. " " .. tostring(refused))
	check(value("graphicsQuality") == "7" and value("gxMaximize") == "1" and value("vsync") == "1", "values did not come back")
	check(H.reloads == 1, "apply reloaded " .. H.reloads .. " times")
	check(PourSocialScoreDB.gfxPending == true, "gfxPending not set")
	check(PourSocialScoreDB.gfxSets and #PourSocialScoreDB.gfxSets == 1, "the old set was not saved to the history")
	local seen = {}
	for _, w in ipairs(H.cvarWrites) do seen[w[1]] = (seen[w[1]] or 0) + 1 end
	check(#H.cvarWrites == 3 and seen.graphicsQuality == 1 and seen.gxMaximize == 1 and seen.vsync == 1, "apply wrote " .. #H.cvarWrites .. " CVars")

	-- header: missing, another client, empty, blank lines first
	reset()
	local good = M.PSS_GfxExportText()
	local body = good:gsub("^[^\n]*\n", "")
	local p1, w1 = M.PSS_GfxParse(body)
	check(p1 == nil and type(w1) == "string" and w1 ~= "", "text without a header was accepted")
	p1, w1 = M.PSS_GfxParse("PSSGFX1 Retail 12.0.7\n" .. body)
	check(p1 == nil and type(w1) == "string", "a Retail header was accepted")
	p1 = M.PSS_GfxParse("")
	check(p1 == nil, "empty text was accepted")
	p1 = M.PSS_GfxParse(nil)
	check(p1 == nil, "nil text was accepted")
	p1 = M.PSS_GfxParse("\n\n  \nPSSGFX1 Camelot 0.9\n" .. body)
	check(p1 and #p1.changes == 0, "blank lines before the header, another build number: refused")
	p1 = M.PSS_GfxParse(good:gsub("\n", "\r\n"))
	check(p1 and #p1.changes == 0 and p1.skipped == 0, "Windows line ends were not read")
	check(#H.cvarWrites == 0, "a refused text wrote a CVar")

	-- skipped lines: unknown, not graphics, secure, locked, read-only, addon*,
	-- a command, no "=", a long value, a non-ASCII byte, a control byte
	local extra = {
		"foo=1", "Sound_MasterVolume=0", "secureGfx=0", "lockedGfx=0", "readOnlyGfx=0",
		"addonCombatRestrictionsForced=1", "gxRestart=1", "garbage", "farclip=" .. ("9"):rep(256),
		"gxAdapter=caf\195\169", "vsync=\1",
	}
	local text2 = good .. "\n" .. table.concat(extra, "\n") .. "\n  graphicsQuality = 3 \n"
	local plan2 = M.PSS_GfxParse(text2)
	check(plan2 and plan2.skipped == #extra, "skipped " .. tostring(plan2 and plan2.skipped) .. ", wanted " .. #extra)
	check(plan2 and #plan2.changes == 1 and plan2.changes[1][1] == "graphicsQuality" and plan2.changes[1][3] == "3",
		"a trimmed 'name = value' line was not read")
	check(M.PSS_GfxSummary(plan2):find("%d+ skipped"), "summary lacks the skipped line")
	ok = M.PSS_GfxApply(plan2)
	check(ok == true, "apply of a plan with skipped lines failed")
	for _, n in ipairs(NOT_ALLOWED) do check(not wrote(n), n .. " was written") end
	check(not wrote("foo") and not wrote("vsync") and not wrote("gxAdapter") and not wrote("farclip"), "a skipped line was written")
	check(value("graphicsQuality") == "3", "the good line was not applied")
	local long = ("9"):rep(255)
	reset()
	local p255 = M.PSS_GfxParse(setLine(good, "gxAdapter", long))
	check(p255 and #p255.changes == 1 and p255.skipped == 0, "a 255 letter value was refused")

	-- combat: Apply refused, nothing set, no reload, nothing saved
	reset()
	H.cvars.vsync.value = "0"
	local pc = M.PSS_GfxParse(good)
	H.combat = true
	local okc, msg = M.PSS_GfxApply(pc)
	H.combat = false
	check(okc == false and type(msg) == "string" and msg:lower():find("combat"), "combat: " .. tostring(okc) .. " " .. tostring(msg))
	check(#H.cvarWrites == 0 and H.reloads == 0 and value("vsync") == "0", "combat apply wrote or reloaded")
	check(PourSocialScoreDB.gfxPending == nil and PourSocialScoreDB.gfxSets == nil, "combat apply saved something")

	-- a refused set (the client keeps the old value) is counted; with nothing
	-- applied there is no reload and no history entry
	reset()
	local ps = M.PSS_GfxParse(setLine(good, "stuckGfx", "0"))
	check(ps and #ps.changes == 1, "stuck plan")
	local oks, ap, rf = M.PSS_GfxApply(ps)
	check(oks == false and type(ap) == "string" and rf == 1, "nothing applied: " .. tostring(oks) .. " " .. tostring(ap) .. " " .. tostring(rf))
	check(H.reloads == 0 and PourSocialScoreDB.gfxPending == nil and PourSocialScoreDB.gfxSets == nil, "a refused-only apply reloaded or saved")
	H.cvars.vsync.value = "0"
	ps = M.PSS_GfxParse(setLine(good, "stuckGfx", "0"))
	oks, ap, rf = M.PSS_GfxApply(ps)
	check(oks == true and ap == 1 and rf == 1 and H.reloads == 1, "one applied, one refused: " .. tostring(oks) .. " " .. tostring(ap) .. " " .. tostring(rf))

	-- nothing to apply
	reset()
	local okn = M.PSS_GfxApply(M.PSS_GfxParse(good))
	check(okn == false and H.reloads == 0, "an empty plan reloaded")

	-- every name ever written is on the allow-list
	reset()
	check(#allWrites > 5, "no writes were recorded")
	for _, n in ipairs(allWrites) do check(inList[n], "wrote " .. n) end

	-- the command (stage 1 prints the count; with the popup it opens it)
	local out = capture(M.PSS_SlashPSS, "gfx")
	if not _G.PSS_GfxPopup then
		check(has(out, tostring(#ALLOWED) .. " graphics settings") and has(out, "farclip"), "/pss gfx line: " .. tostring(out[1]))
	end
	local help = capture(M.PSS_SlashPSS, "help")
	check(has(help, "gfx"), "/pss help lacks the gfx line")
end

------------------------------------------------------------------------
-- history
------------------------------------------------------------------------
function phases.history()
	needLibraries()
	check(M.PSS_GfxHistory and M.PSS_GfxSetDiff and M.PSS_GfxRestorePlan, "history functions missing")
	reset()
	check(#M.PSS_GfxHistory() == 0, "history not empty at the start")

	-- the first change saves the set before it: only non-defaults, with the time
	local t0 = 1790000000
	local before = {}
	local stamp = t0 + 60		-- change() advances the clock a minute first
	local function change(name, new)
		before[#before + 1] = M.PSS_GfxExportText()
		H.Advance(60)
		check(applyChange(name, new), "apply " .. name)
	end
	change("graphicsViewDistance", "3")
	local sets = PourSocialScoreDB.gfxSets
	check(sets and #sets == 1, "one set after one change")
	local want = stamp .. "\nffxAntiAliasingMode=2\ngraphicsQuality=7\ngraphicsViewDistance=7\ngxFullscreenResolution=1920x1080\ngxMaximize=1\nstuckGfx=1"
	check(sets and sets[1] == want, "packed set is " .. tostring(sets and sets[1]):gsub("\n", "|") .. " wanted " .. want:gsub("\n", "|"))
	check(rawget(PSS_OptionsDB, "gfxSets") == sets, "gfxSets is not routed to PSS_OptionsDB")
	check(M.PSS_GfxExportText(1) == before[1], "expand: set 1 does not export like the state it saved")

	-- a copy of the newest (same body, later time) is not added
	H.cvars.graphicsViewDistance.value = "7"
	H.Advance(60)
	check(applyChange("graphicsViewDistance", "3"), "second apply")
	check(#PourSocialScoreDB.gfxSets == 1, "a copy of the newest set was added (" .. #PourSocialScoreDB.gfxSets .. ")")
	check(PourSocialScoreDB.gfxSets[1] == want, "the newest set changed")
	check(H.reloads == 2 and PourSocialScoreDB.gfxPending == true, "reload count or flag")

	-- more distinct changes: newest first, the 6th drops the oldest
	H.cvars.graphicsViewDistance.value = "7"
	PourSocialScoreDB.gfxSets = nil
	before = {}
	local steps = { { "graphicsQuality", "1" }, { "renderScale", "2" }, { "farclip", "500" }, { "vsync", "0" },
		{ "particleDensity", "50" }, { "gxMonitor", "1" }, { "graphicsLiquidDetail", "0" } }
	for _, s in ipairs(steps) do change(s[1], s[2]) end
	sets = PourSocialScoreDB.gfxSets
	check(#sets == 5, "the history holds " .. #sets .. " sets, wanted 5")
	for k = 1, 5 do
		local expect = before[#before - k + 1]
		check(M.PSS_GfxExportText(k) == expect, "set " .. k .. " is not the state before change " .. (#before - k + 1))
	end
	check(not sets[5]:find("farclip=1300", 1, true), "defaults were saved")

	-- M.PSS_GfxHistory: rows newest first, when and how many differ from now
	local now = map(M.PSS_GfxExportText())
	local rows = M.PSS_GfxHistory()
	check(#rows == 5, "history rows " .. #rows)
	for k, r in ipairs(rows) do
		check(r.i == k, "row " .. k .. " index " .. tostring(r.i))
		local t = tonumber(sets[k]:match("^(%d+)\n"))
		check(r.when == t and r.whenText == date("%Y-%m-%d %H:%M", t), "row " .. k .. " time")
		local n, expect = 0, map(M.PSS_GfxExportText(k))
		for name, v in pairs(expect) do if now[name] ~= v then n = n + 1 end end
		check(r.changed == n, "row " .. k .. " changed " .. tostring(r.changed) .. " wanted " .. n)
	end
	check(rows[1].when > rows[5].when, "rows are not newest first")
	check(rows[1].changed == 1, "row 1 should differ in one setting, got " .. tostring(rows[1].changed))

	-- M.PSS_GfxSetDiff: the saved time, then name: then -> now
	local diff = M.PSS_GfxSetDiff(1)
	check(diff:find("Saved " .. rows[1].whenText, 1, true), "diff lacks the saved time")
	check(diff:find("graphicsLiquidDetail: 2 -> 0", 1, true), "diff lacks the change line: " .. diff)
	local diff5 = M.PSS_GfxSetDiff(5)
	check(diff5:find("farclip: 1300 -> 500", 1, true) and diff5:find("vsync: 1 -> 0", 1, true)
		and not diff5:find("graphicsQuality", 1, true), "diff of the oldest set")

	-- restore: the same plan shape, apply, the state of that set is back
	local target = M.PSS_GfxExportText(3)
	local plan = M.PSS_GfxRestorePlan(3)
	check(plan and #plan.changes > 0 and plan.skipped == 0, "restore plan")
	check(M.PSS_GfxSummary(plan):find("will change", 1, true), "restore summary")
	local reloads = H.reloads
	local ok = M.PSS_GfxApply(plan)
	check(ok == true and H.reloads == reloads + 1, "restore apply")
	check(M.PSS_GfxExportText() == target, "restored state differs from set 3")
	check(#PourSocialScoreDB.gfxSets == 5, "restoring changed the history size")
	check(M.PSS_GfxRestorePlan(9) == nil, "a set that does not exist gave a plan")

	-- a history export imports
	local plan2 = M.PSS_GfxParse(M.PSS_GfxExportText(2))
	check(plan2 and plan2.skipped == 0, "a history export does not parse")

	-- unknown names (forward compatibility) are kept in the string, skipped on restore
	PourSocialScoreDB.gfxSets[2] = PourSocialScoreDB.gfxSets[2] .. "\nnewerCvar=5"
	local pk = M.PSS_GfxRestorePlan(2)
	check(pk and pk.skipped == 1, "an unknown name in a set: skipped " .. tostring(pk and pk.skipped))
	check(not M.PSS_GfxExportText(2):find("newerCvar", 1, true), "an unknown name was exported")
	H.cvarWrites = {}
	M.PSS_GfxApply(pk)
	check(not wrote("newerCvar"), "an unknown name was written")
	check(PourSocialScoreDB.gfxSets[3] and PourSocialScoreDB.gfxSets[3]:find("newerCvar=5", 1, true), "an unknown name was dropped from the saved string")

	-- size of five sets
	local bytes = #table.concat(PourSocialScoreDB.gfxSets)
	print(("gfxSets: %d sets, %d bytes of strings, %d bytes serialized"):format(#PourSocialScoreDB.gfxSets, bytes, #H.serialize(PourSocialScoreDB.gfxSets)))
end

------------------------------------------------------------------------
-- keep
------------------------------------------------------------------------
function phases.keep()
	needLibraries()
	check(M.PSS_GfxKeep and M.PSS_GfxRevert and M.PSS_GfxKeepSpec and M.PSS_GfxReload, "keep functions missing")
	reset()

	-- Keep: the flag goes, the values stay, one line
	local orig = M.PSS_GfxExportText()
	check(applyChange("graphicsQuality", "2"), "change")
	local changed = M.PSS_GfxExportText()
	check(PourSocialScoreDB.gfxPending == true and #PourSocialScoreDB.gfxSets == 1, "pending state")
	local out = capture(M.PSS_GfxKeep)
	check(PourSocialScoreDB.gfxPending == nil, "Keep left gfxPending " .. tostring(PourSocialScoreDB.gfxPending))
	check(M.PSS_GfxExportText() == changed, "Keep changed the values")
	check(#PourSocialScoreDB.gfxSets == 1, "Keep changed the history")
	check(#out == 1, "Keep printed " .. #out .. " lines")

	-- Revert: set 1 back, the flag goes, no history entry, one line
	reset()
	orig = M.PSS_GfxExportText()
	local two = setLine(setLine(orig, "graphicsQuality", "2"), "gxMaximize", "0")
	check(M.PSS_GfxApply(M.PSS_GfxParse(two)), "two changes in one apply")
	check(PourSocialScoreDB.gfxPending == true, "pending before revert")
	local spec = M.PSS_GfxKeepSpec()
	check(type(spec) == "table" and spec.title == "Keep Graphics Settings?" and spec.accept == "Keep" and spec.cancel == "Revert"
		and spec.timeout == 15, "keep spec fields")
	check(spec.onAccept == M.PSS_GfxKeep and spec.onCancel == M.PSS_GfxRevert and spec.onTimeout == M.PSS_GfxRevert, "keep spec callbacks")
	check(spec.text:find("gxMaximize", 1, true) and spec.text:find("restart", 1, true), "keep text lacks the display setting and the restart note: " .. tostring(spec.text))
	check(spec.text:find("graphicsQuality", 1, true), "keep text lacks graphicsQuality")
	local sets = #PourSocialScoreDB.gfxSets
	local setOne = PourSocialScoreDB.gfxSets[1]
	H.cvarWrites = {}
	out = capture(M.PSS_GfxRevert)
	check(M.PSS_GfxExportText() == orig, "Revert did not put set 1 back")
	check(PourSocialScoreDB.gfxPending == nil, "Revert left gfxPending")
	check(#PourSocialScoreDB.gfxSets == sets and PourSocialScoreDB.gfxSets[1] == setOne, "Revert changed the history")
	check(#out == 1 and out[1]:find("graphicsQuality", 1, true) and out[1]:lower():find("reload", 1, true), "Revert line: " .. tostring(out[1]))
	check(H.reloads == 1, "Revert reloaded")
	for _, w in ipairs(H.cvarWrites) do check(w[1] ~= "secureGfx" and w[1] ~= "Sound_MasterVolume", "Revert wrote " .. w[1]) end

	-- no display setting changed: no restart note
	reset()
	check(applyChange("graphicsQuality", "2"), "change")
	check(not M.PSS_GfxKeepSpec().text:find("restart", 1, true), "restart note without a display change")

	-- Revert works in combat
	reset()
	check(applyChange("graphicsQuality", "2"), "change for combat revert")
	H.combat = true
	M.PSS_GfxRevert()
	H.combat = false
	check(value("graphicsQuality") == "7" and PourSocialScoreDB.gfxPending == nil, "Revert in combat did not work")

	-- Revert with no history, and Keep with nothing waiting: no error
	reset()
	capture(M.PSS_GfxRevert)
	capture(M.PSS_GfxKeep)
	check(PourSocialScoreDB.gfxPending == nil and #H.cvarWrites == 0, "Revert with nothing wrote")
	local rl = H.reloads
	M.PSS_GfxReload()
	check(H.reloads == rl + 1, "PSS_GfxReload did not reload")
end

------------------------------------------------------------------------
-- retail
------------------------------------------------------------------------
function phases.retail()
	local out = capture(M.PSS_SlashPSS, "gfx")
	check(has(out, "Graphics settings are for Camelot only."), "/pss gfx on Retail said: " .. tostring(out[1]))
	check(loaded("PourSocialScore_Libraries"), "the command did not load Libraries")
	check(not loaded("PourSocialScore_GUI"), "the GUI was loaded on Retail")
	check(M.PSS_GfxList == nil and M.PSS_GfxOpen == nil, "graphics functions exist on Retail")
	for k in pairs(M) do check(not tostring(k):find("^PSS_Gfx"), "M." .. k .. " exists on Retail") end
	check(next(H.cvars) == nil and #H.cvarWrites == 0 and H.reloads == 0, "Retail touched CVars")
	check(not _G.PSS_GfxPopup, "a popup frame exists on Retail")
	local help = capture(M.PSS_SlashPSS, "help")
	check(has(help, "gfx"), "/pss help lacks the gfx line")
end

------------------------------------------------------------------------
-- noapi
------------------------------------------------------------------------
function phases.noapi()
	local old = os.getenv("PSS_GFX_OLDAPI") == "1"
	needLibraries()
	if old then
		local list = M.PSS_GfxList()
		check(list and #list == #ALLOWED, "old console API: list has " .. tostring(list and #list))
		local text = M.PSS_GfxExportText()
		check(text and text:find("^PSSGFX1 Camelot"), "old console API: export")
		return
	end
	check(M.PSS_GfxList, "functions missing on Camelot")
	local list, why = M.PSS_GfxList()
	check(list == nil and type(why) == "string" and why ~= "", "no console API: list " .. tostring(list) .. " " .. tostring(why))
	check(M.PSS_GfxExportText() == nil, "export without the console API")
	check(M.PSS_GfxParse("PSSGFX1 Camelot 1.0.0\nvsync=0") == nil, "parse without the console API")
	local out = capture(M.PSS_SlashPSS, "gfx")
	check(#out == 1 and out[1] == why or (#out == 1 and out[1]:find(why, 1, true)), "/pss gfx without the API said " .. #out .. " lines: " .. tostring(out[1]))
	check(not loaded("PourSocialScore_GUI"), "the GUI loaded without the API")
	check(#H.cvarWrites == 0 and H.reloads == 0, "nothing may be set without the API")
	check(M.PSS_GfxHistory and #M.PSS_GfxHistory() == 0, "history without the API")
end

------------------------------------------------------------------------
-- popup helpers (the GUI draws; every button is a call into Libraries)
------------------------------------------------------------------------
local function under(f, root)
	while f do
		if f == root then return true end
		f = f._parent
	end
	return false
end
local function findAll(root, pred)
	local out = {}
	for _, f in ipairs(H.frames) do
		if f ~= root and under(f, root) and pred(f) then out[#out + 1] = f end
	end
	return out
end
local function btnText(f)
	local t = f._text
	if (t == nil or t == "") and f._fs then t = f._fs._text end
	return t or ""
end
local function button(root, text)
	local list = findAll(root, function(f) return f._scripts.OnClick ~= nil and btnText(f) == text end)
	return list[1]
end
local function click(btn)
	check(btn ~= nil, "a button is missing")
	if btn then btn._scripts.OnClick(btn, "LeftButton") end
end
local function editBox(root)
	return findAll(root, function(f) return f._kind == "EditBox" end)[1]
end
local function anyText(root, text)
	for _, f in ipairs(findAll(root, function(f) return f._kind == "FontString" end)) do
		if (f._text or ""):find(text, 1, true) then return true end
	end
	return false
end
local function escape()
	-- the game hides the shown frames named in UISpecialFrames
	for i = #UISpecialFrames, 1, -1 do
		local f = _G[UISpecialFrames[i]]
		if f and f:IsShown() and (UISpecialFrames[i] == "PSS_GfxPopup" or UISpecialFrames[i] == "PSS_Confirm") then f:Hide() return UISpecialFrames[i] end
	end
end
local function setLook(n)
	M.PSS_SetOpt("uiSkin", "global", n)
	M.Events.Fire("OPTION_CHANGED", "uiSkin")
end
local LOOKS = { { 2, "Modern" }, { 0, "Classic" }, { 1, "Dark" } }
local function gcCounter()
	local n = 0
	local real = M.PSS_RequestGC
	M.PSS_RequestGC = function(...) n = n + 1 if real then return real(...) end end
	return function() return n end, function() M.PSS_RequestGC = real end
end

------------------------------------------------------------------------
-- popup
------------------------------------------------------------------------
function phases.popup()
	check(not loaded("PourSocialScore_GUI"), "GUI loaded at login")
	for _, look in ipairs(LOOKS) do
		local lname = look[2]
		local function lcheck(ok, msg) check(ok, lname .. ": " .. msg) end
		reset()
		if loaded("PourSocialScore_GUI") then setLook(look[1]) else M.PSS_SetOpt("uiSkin", "global", look[1]) end
		local gcs, restore = gcCounter()
		-- the command opens the popup, the main window stays closed
		capture(M.PSS_SlashPSS, "gfx")
		local pop = _G.PSS_GfxPopup
		lcheck(pop and pop:IsShown(), "/pss gfx did not open PSS_GfxPopup")
		if not pop then restore() return end
		lcheck(not (_G.PSS_Window and _G.PSS_Window:IsShown()), "the main window opened")
		lcheck(loaded("PourSocialScore_GUI") and loaded("PourSocialScore_Libraries"), "parts not loaded")
		setLook(look[1])
		local title = pop.title and pop.title:GetText() or ""
		lcheck(title == "Graphics Settings" and not title:find("Pour Social Score", 1, true), "title is '" .. tostring(title) .. "'")
		local box = editBox(pop)
		lcheck(box ~= nil, "no text box")
		if not box then restore() return end

		-- Export fills the box
		click(button(pop, "Export"))
		local text = box:GetText() or ""
		lcheck(text:find("^PSSGFX1 Camelot 1.0.0\n"), "Export did not fill the box")
		lcheck(#lines(text) == 17, "Export has " .. #lines(text) .. " lines")
		lcheck(anyText(pop, "16 settings"), "the subtitle lacks the count")

		-- Import: preview, Cancel sets nothing
		H.cvars.graphicsQuality.value = "2"
		H.cvars.vsync.value = "0"
		H.cvarWrites = {}
		click(button(pop, "Import"))
		local cf = _G.PSS_Confirm
		lcheck(cf and cf:IsShown() and cf.title:GetText() == "Apply Graphics Settings?", "no 'Apply Graphics Settings?' confirm")
		if cf and cf:IsShown() then
			local body = cf.text:GetText() or ""
			lcheck(body:find("graphicsQuality: 2 -> 7", 1, true) and body:find("vsync: 0 -> 1", 1, true), "preview lacks the change lines")
			click(cf.cancel)
		end
		lcheck(#H.cvarWrites == 0 and H.reloads == 0 and PourSocialScoreDB.gfxPending == nil, "Cancel set something")
		lcheck(pop:IsShown(), "the popup closed with the confirm")

		-- Import then Apply: applied, one reload, flag set
		click(button(pop, "Import"))
		cf = _G.PSS_Confirm
		if cf and cf:IsShown() then click(cf.accept) else lcheck(false, "no confirm the second time") end
		lcheck(value("graphicsQuality") == "7" and value("vsync") == "1", "Apply did not set the values")
		lcheck(H.reloads == 1 and PourSocialScoreDB.gfxPending == true, "Apply: reloads " .. H.reloads)

		-- a text that is not an export: said in the popup, no confirm
		box:SetText("hello")
		click(button(pop, "Import"))
		lcheck(not (_G.PSS_Confirm and _G.PSS_Confirm:IsShown() and _G.PSS_Confirm.title:GetText() == "Apply Graphics Settings?"), "a bad text opened the confirm")
		lcheck(H.reloads == 1, "a bad text reloaded")

		-- Reload UI
		click(button(pop, "Reload UI"))
		lcheck(_G.PSS_Confirm:IsShown() and _G.PSS_Confirm.title:GetText() == "Reload UI?", "Reload UI did not ask")
		click(_G.PSS_Confirm.accept)
		lcheck(H.reloads == 2, "Reload UI reloaded " .. H.reloads - 1 .. " times")

		-- Escape closes it (one Escape), the box is emptied, GC requested
		local special = false
		for _, n in ipairs(UISpecialFrames) do if n == "PSS_GfxPopup" then special = true end end
		lcheck(special, "PSS_GfxPopup is not in UISpecialFrames")
		local before = gcs()
		lcheck(escape() == "PSS_GfxPopup" and not pop:IsShown(), "Escape did not close the popup")
		lcheck((box:GetText() or "") == "", "the box was not emptied on close")
		lcheck(gcs() == before + 1, "closing did not request a GC")
		restore()
		PourSocialScoreDB.gfxPending = nil
	end
end

------------------------------------------------------------------------
-- apply (the first half of reload: a save with a change waiting)
------------------------------------------------------------------------
function phases.apply()
	needLibraries()
	reset()
	check(applyChange("graphicsQuality", "2"), "apply")
	check(PourSocialScoreDB.gfxPending == true and #PourSocialScoreDB.gfxSets == 1, "pending state")
	check(H.reloads == 1, "reloads")
	-- the save written at logout carries gfxPending and gfxSets in PSS_OptionsDB
	check(rawget(PSS_OptionsDB, "gfxPending") == true and rawget(PSS_OptionsDB, "gfxSets") ~= nil, "not routed to PSS_OptionsDB")
end

------------------------------------------------------------------------
-- reload (the second half: the run after a /reload with a change waiting)
------------------------------------------------------------------------
function phases.reload()
	local run = os.getenv("PSS_GFX_RUN") or "keep"
	check(H.cvars.graphicsQuality and H.cvars.graphicsQuality.value == "2", "the run needs PSS_GFX_SET=graphicsQuality=2")
	if run == "none" then
		-- a login with nothing waiting loads neither part, shows no prompt
		check(PourSocialScoreDB.gfxPending == nil, "gfxPending is set in the 'none' run")
		check(not loaded("PourSocialScore_Libraries"), "Libraries loaded at a login with nothing waiting")
		check(not loaded("PourSocialScore_GUI"), "GUI loaded at a login with nothing waiting")
		check(not (_G.PSS_Confirm and _G.PSS_Confirm:IsShown()), "a prompt showed with nothing waiting")
		return
	end
	check(PourSocialScoreDB.gfxPending == true and PourSocialScoreDB.gfxSets and #PourSocialScoreDB.gfxSets == 1, "the save lost the pending change")
	check(loaded("PourSocialScore_Libraries"), "Libraries not loaded at login with a change waiting")
	check(loaded("PourSocialScore_GUI"), "GUI not loaded at login with a change waiting")
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown() and cf.title:GetText() == "Keep Graphics Settings?", "the keep prompt is not showing")
	if not (cf and cf:IsShown()) then return end
	check((cf.text:GetText() or ""):find("graphicsQuality", 1, true), "the prompt does not name what changed")
	check(btnText(cf.accept) == "Keep", "accept is '" .. btnText(cf.accept) .. "'")
	check(btnText(cf.cancel) == "Revert (15)", "cancel is '" .. btnText(cf.cancel) .. "'")
	H.RunOnUpdate(100)
	check(cf:IsShown() and btnText(cf.cancel):find("^Revert %(1[234]%)$"), "after 2 s the button reads '" .. btnText(cf.cancel) .. "'")
	check(#H.cvarWrites == 0, "the prompt wrote a CVar before an answer")
	if run == "keep" then
		click(cf.accept)
		check(PourSocialScoreDB.gfxPending == nil, "Keep left gfxPending")
		check(value("graphicsQuality") == "2" and #H.cvarWrites == 0, "Keep changed the values")
		H.RunOnUpdate(800)
		check(value("graphicsQuality") == "2", "the countdown went on after Keep")
	elseif run == "timeout" then
		H.RunOnUpdate(600)
		check(cf:IsShown() and PourSocialScoreDB.gfxPending == true, "answered before 15 s (12.1 s in)")
		H.RunOnUpdate(160)
		check(not cf:IsShown(), "the prompt is still showing after 15.2 s")
		check(value("graphicsQuality") == "7" and PourSocialScoreDB.gfxPending == nil, "the timeout did not revert")
	elseif run == "escape" then
		check(escape() == "PSS_Confirm", "Escape did not close the prompt")
		check(value("graphicsQuality") == "7" and PourSocialScoreDB.gfxPending == nil, "Escape did not revert")
	elseif run == "revert" then
		click(cf.cancel)
		check(value("graphicsQuality") == "7" and PourSocialScoreDB.gfxPending == nil, "Revert did not revert")
	end
	check(not cf:IsShown() or run == "keep" and not cf:IsShown(), "the prompt is still showing")
	check(#PourSocialScoreDB.gfxSets == 1, "the answer changed the history")
end

------------------------------------------------------------------------
-- history_ui
------------------------------------------------------------------------
function phases.history_ui()
	for _, look in ipairs(LOOKS) do
		local lname = look[2]
		local function lcheck(ok, msg) check(ok, lname .. ": " .. msg) end
		reset()
		M.PSS_SetOpt("uiSkin", "global", look[1])
		needLibraries()
		-- three changes
		local before = {}
		for _, s in ipairs({ { "graphicsQuality", "1" }, { "renderScale", "2" }, { "vsync", "0" } }) do
			before[#before + 1] = M.PSS_GfxExportText()
			H.Advance(3600)
			applyChange(s[1], s[2])
		end
		H.reloads = 0
		capture(M.PSS_SlashPSS, "gfx")
		local pop = _G.PSS_GfxPopup
		lcheck(pop and pop:IsShown(), "no popup")
		if not pop then return end
		setLook(look[1])
		-- the stub's frames are 20 high: give the list the room it has in the game (5 rows)
		for _, sf in ipairs(findAll(pop, function(f) return f._child ~= nil and f._scripts.OnSizeChanged ~= nil end)) do
			sf._h = 90
			sf._scripts.OnSizeChanged(sf)
		end
		click(button(pop, "History"))
		local rows = findAll(pop, function(f) return type(f.cells) == "table" and f._scripts.OnClick end)
		local shown = {}
		for _, r in ipairs(rows) do
			if r:IsVisible() then
				local t = ""
				for _, c in pairs(r.cells) do t = t .. " " .. tostring(c._text) end
				if t:find("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d") then shown[#shown + 1] = { row = r, text = t } end
			end
		end
		lcheck(#shown == 3, "History shows " .. #shown .. " rows, wanted 3")
		local hist = M.PSS_GfxHistory()
		for k, s in ipairs(shown) do
			lcheck(hist[k] and s.text:find(hist[k].whenText, 1, true) and s.text:find(tostring(hist[k].changed), 1, true), "row " .. k .. ": '" .. s.text .. "'")
		end
		if #shown < 3 then return end
		lcheck(shown[1].text:find(hist[1].whenText, 1, true) and not shown[1].text:find(hist[3].whenText, 1, true), "newest row is not first")
		-- a row click shows its diff
		shown[1].row._scripts.OnClick(shown[1].row, "LeftButton")
		lcheck(anyText(pop, "vsync: 1 -> 0") or (editBox(pop) and (editBox(pop):GetText() or ""):find("vsync: 1 -> 0", 1, true)), "the row did not show its diff")
		-- Export fills the box with an importable string
		click(button(pop, "Export"))
		local box = editBox(pop)
		lcheck(box and (box:GetText() or ""):find("^PSSGFX1 Camelot"), "History Export did not fill the box")
		-- Restore previews, then applies
		click(button(pop, "Restore"))
		local cf = _G.PSS_Confirm
		lcheck(cf and cf:IsShown() and cf.title:GetText() == "Apply Graphics Settings?", "Restore opened no confirm")
		if cf and cf:IsShown() then click(cf.accept) end
		lcheck(H.reloads == 1 and PourSocialScoreDB.gfxPending == true, "Restore did not apply and reload")
		lcheck(M.PSS_GfxExportText() == before[3], "Restore of the newest set did not put it back")
		-- Back returns
		click(button(pop, "Back"))
		lcheck(button(pop, "Export") and button(pop, "Import") and button(pop, "History"), "Back did not return the main view")
		escape()
		PourSocialScoreDB.gfxPending = nil
	end
end

local fn = phases[phase]
if not fn then
	print("FAIL gfx: unknown phase " .. phase)
else
	local ok, err = pcall(fn)
	if not ok then print("FAIL gfx: " .. phase .. ": error: " .. tostring(err)) fail = true end
	if not fail then print("PASS gfx " .. phase) end
end
