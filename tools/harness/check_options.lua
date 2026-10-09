-- The new window's Options and Import/Export tabs (3.4.0-dev012), as a
-- run.lua script on any save, real ones included: every option of
-- M.PSS_OPTIONS (inline numbers by their tick box) under its section with
-- the saved value shown; a tick box, a number box (clamped), the scan level
-- cap (refused without a number) and a drop-down write through
-- M.PSS_SetOpt; a change from elsewhere shows at once; the search keeps the
-- matching options and its box shows with the tab only; Import/Export:
-- the parts (members only with guilds), the mode, Export round-tripping
-- through Import (merge, and replace after a confirm), a bad string.
local fail = false
local function check(ok, msg) if not ok then print("FAIL options: " .. msg) fail = true end end
local said = {}
local realShow = M.ShowMsg
M.ShowMsg = function(x) said[#said + 1] = tostring(x) realShow(x) end
local function lastSaid() return said[#said] or "" end

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window
win.tabs[7]._scripts.OnClick(win.tabs[7])
local page = win.pages[7]
check(page:IsShown() and page.groups and page.search, "Options tab not built")
check(page.note == nil, "the placeholder note is gone")

-- every option once, under its section, showing the saved value
local rowOf, n = {}, 0
for _, g in ipairs(page.groups) do
	check(g.heading:IsShown() and g.heading:GetText() == g.title, "section heading " .. tostring(g.title))
	for _, it in ipairs(g.items) do
		rowOf[it.o.key] = it.row
		n = n + 1
	end
end
local want = 0
for _, o in ipairs(M.PSS_OPTIONS) do if not o.inline and not o.retired then want = want + 1 end end
check(n == want, ("rows %d, options %d"):format(n, want))
for key, row in pairs(rowOf) do
	local o = row.option
	if row.check and not o.field then
		check(row.check:GetChecked() == (M.PSS_Opt(key) == true), "tick box value " .. key)
	elseif row.box and not o.field then
		check(row.box:GetText() == M.PSS_OptNumberText(o), "number value " .. key)
	elseif row.drop then
		check(row.drop.label:GetText() == M.PSS_OptChoiceText(o, M.PSS_Opt(key)), "drop-down value " .. key)
	end
end

-- a tick box
local boolKey
for _, o in ipairs(M.PSS_OPTIONS) do if o.kind == "bool" and not o.field and rowOf[o.key] then boolKey = o.key break end end
local bc = rowOf[boolKey].check
local was = M.PSS_Opt(boolKey) == true
bc:SetChecked(not was)
bc._scripts.OnClick(bc)
check((M.PSS_Opt(boolKey) == true) == not was, "tick box did not write " .. boolKey)
bc:SetChecked(was)
bc._scripts.OnClick(bc)
check((M.PSS_Opt(boolKey) == true) == was, "tick box did not write back " .. boolKey)
-- a change from elsewhere shows at once
M.PSS_SetOpt(boolKey, "global", not was)
check(bc:GetChecked() == not was, "a change from elsewhere not shown")
M.PSS_SetOpt(boolKey, "global", was)

-- a number box, clamped to its range
local numO
for _, o in ipairs(M.PSS_OPTIONS) do if o.kind == "number" and not o.inline and o.max and rowOf[o.key] then numO = o break end end
if numO then
	local box = rowOf[numO.key].box
	local before = M.PSS_Opt(numO.key)
	box:SetText(tostring(numO.max + 1000))
	box._scripts.OnEnterPressed(box)
	check(M.PSS_Opt(numO.key) == numO.max and box:GetText() == tostring(numO.max), "number not clamped: " .. tostring(M.PSS_Opt(numO.key)))
	box:SetText("abc")
	box._scripts.OnEnterPressed(box)
	check(M.PSS_Opt(numO.key) == numO.max, "a word changed the number")
	M.PSS_SetOpt(numO.key, "global", before)
end

-- the scan level cap: its tick box needs its number
local cap = rowOf.whoLevelCapOn
check(cap and cap.check and cap.box, "no scan level cap row with its number")
M.PSS_SetOpt("whoLevelCapOn", "global", false)
M.PSS_SetOpt("whoLevelCap", "global", nil)
cap.box:SetText("")
cap.check:SetChecked(true)
cap.check._scripts.OnClick(cap.check)
check(M.PSS_Opt("whoLevelCapOn") ~= true and not cap.check:GetChecked() and lastSaid():find("first", 1, true), "cap ticked without a number")
cap.box:SetText("70")
cap.check:SetChecked(true)
cap.check._scripts.OnClick(cap.check)
check(M.PSS_Opt("whoLevelCapOn") == true and M.PSS_Opt("whoLevelCap") == 70, "cap with a number not set")
cap.box:SetText("")
cap.box._scripts.OnEnterPressed(cap.box)
check(M.PSS_Opt("whoLevelCap") == 70 and lastSaid():find("required", 1, true), "cap emptied while ticked")
M.PSS_SetOpt("whoLevelCapOn", "global", false)

-- a drop-down (Classic: Blizzard's menu, read as entries): the window's look
local sk = rowOf.uiSkin.drop
M.PSS_SetOpt("uiSkin", "global", 0)
check(sk.label:GetText() == "Classic", "look drop-down label " .. tostring(sk.label:GetText()))
for _, it in ipairs(sk.blizz:MenuButtons()) do if it.text == "Dark" then it.fn() end end
check(M.PSS_UISkin() == "dark" and win.art.dark:IsShown() and sk.label:GetText() == "Dark", "look drop-down did not switch to Dark")
M.PSS_SetOpt("uiSkin", "global", 2)

-- search: matching options only; the box shows with this tab only
local function search(q)
	page.search:SetText(q)
	page.search._scripts.OnTextChanged(page.search, true)
end
search("window priority")
check(rowOf.frameStrata:IsShown() and not rowOf[boolKey]:IsShown() and page.shownCount >= 1, "search did not keep the match")
search("zzzz no such option")
check(page.shownCount == 0 and page.none:IsShown(), "no match not shown")
search("")
check(page.shownCount == n, "search not cleared")
check(page.search:IsVisible(), "search box hidden on the Options tab")
win.tabs[1]._scripts.OnClick(win.tabs[1])
check(not page.search:IsVisible(), "search box shown on another tab")

-- Import/Export
win.tabs[6]._scripts.OnClick(win.tabs[6])
local io = win.pages[6]
check(io:IsShown() and io.checks and io.exportButton, "Import/Export tab not built")
local mem = io.checks.members[1]
M.PSS_IO.guilds = true
io.checks.guilds[1]:SetChecked(false)
io.checks.guilds[1]._scripts.OnClick(io.checks.guilds[1])
check(M.PSS_IO.guilds == false and not mem:IsEnabled(), "members not off without guilds")
io.checks.guilds[1]:SetChecked(true)
io.checks.guilds[1]._scripts.OnClick(io.checks.guilds[1])
check(mem:IsEnabled(), "members not back with guilds")
check(io.mode.label:GetText() == "Merge (add what is missing)", "mode label")

-- Export: the copy box holds a string that decodes
local before = M.PSS_PlayerCount()
M.PSS_AddPlayer("Exported-Realm1")
io.exportButton._scripts.OnClick(io.exportButton)
local tp = _G.PSS_TextPopup
local exported = tp and tp:IsShown() and tp.edit:GetText()
check(type(exported) == "string" and #exported > 10 and M.PSS_DecodeExport(exported) ~= nil, "export string does not decode")
tp:Hide()
-- Import (merge): the player removed comes back
M.PSS_RemovePlayerAt(M.PSS_PlayerPosition("Exported-Realm1"))
check(M.PSS_PlayerPosition("Exported-Realm1") == 0, "player not removed for the import")
io.importButton._scripts.OnClick(io.importButton)
check(tp:IsShown() and tp.accept:IsShown(), "no import box")
tp.edit:SetText(exported)
tp.accept._scripts.OnClick(tp.accept)
H.RunTimers()
check(M.PSS_PlayerPosition("Exported-Realm1") > 0 and lastSaid():find("^Merged: "), "merge import: " .. lastSaid())
-- a bad string
io.importButton._scripts.OnClick(io.importButton)
tp.edit:SetText("not an export")
tp.accept._scripts.OnClick(tp.accept)
check(lastSaid():find("Import failed", 1, true) ~= nil, "a bad string not reported")
-- Replace asks first
for _, it in ipairs(io.mode.blizz:MenuButtons()) do if it.text:find("^Replace") then it.fn() end end
check(M.PSS_IO.mode == "replace" and io.mode.label:GetText():find("^Replace") ~= nil, "mode not Replace")
io.importButton._scripts.OnClick(io.importButton)
tp.edit:SetText(exported)
tp.accept._scripts.OnClick(tp.accept)
local cf = _G.PSS_Confirm
check(cf and cf:IsShown() and cf.text:GetText():find("Replace the ticked sections", 1, true), "Replace not confirmed")
cf.accept._scripts.OnClick(cf.accept)
H.RunTimers()
check(lastSaid():find("^Replaced: ") ~= nil and M.PSS_PlayerPosition("Exported-Realm1") > 0, "replace import: " .. lastSaid())
M.PSS_IO.mode = "merge"
check(M.PSS_PlayerCount() >= before + 1, "players lost in the import round trip")
-- (3.4.0.15) imported options go through the setter: a default is not
-- stored, a number is kept in range, a value not offered is refused, and
-- the window hears OPTION_CHANGED
do
	local heard = {}
	local id = M.Events.Register("OPTION_CHANGED", function(key) heard[key] = true end)
	PourSocialScoreDB.frameStrata = 1
	M.PSS_ApplyImport({ v = 1, options = {
		frameStrata = 3,			-- the default
		historyTotal = 999999,		-- over its max
		floodFilter = 7,			-- not one of its choices
		uiFont = "arialn",
		defexpire = "x",			-- not a number
	} }, "merge", { options = true })
	check(rawget(PSS_OptionsDB, "frameStrata") == nil, "an imported default was stored")
	check(M.PSS_Opt("historyTotal") == 20000, "an imported number not kept in range: " .. tostring(M.PSS_Opt("historyTotal")))
	check(M.PSS_Opt("floodFilter") == 0, "an imported choice not offered was taken")
	check(M.PSS_Opt("uiFont") == "arialn", "an imported font not taken")
	check(heard.frameStrata and heard.uiFont, "import did not fire OPTION_CHANGED")
	M.Events.Unregister("OPTION_CHANGED", id)
	M.PSS_SetOpt("historyTotal", "global", 2000)
	M.PSS_SetOpt("uiFont", "global", "")
end
M.ShowMsg = realShow

if not fail then print(("PASS options (%d options)"):format(n)) end
