-- Tab art per flavour (TST-00984, TST-00983; looks spec 9): the Classic look's tabs use
-- the flavour's template, the selected tab shows its selected art (*Active on retail and
-- forever, *Disabled on tbc), a click moves it, and Dark underlines the selected tab only.
local fail = false
local fl = os.getenv("PSS_FLAVOUR") or "retail"
local function check(ok, msg) if not ok then print("FAIL tabs (" .. fl .. "): " .. msg) fail = true end end
local ART = fl == "tbc" and "Disabled" or "Active"
local KEYS = { "Left", "Middle", "Right" }

SlashCmdList["PSS"]("gui")
local win = _G.PSS_Window
M.PSS_SetOpt("uiSkin", "global", 0)
local tabs = win.tabs

local function art(tab, selected, n)
	for _, k in ipairs(KEYS) do
		local f = tab[k .. ART]
		if f then
			if selected then check(f:IsShown(), "selected tab " .. n .. " hides its selected art")
			else check(not f:IsShown(), "unselected tab " .. n .. " shows the selected art") end
		end
	end
end

check(tabs[1].pssTemplate == "PanelTopTabButtonTemplate", "template " .. tostring(tabs[1].pssTemplate) .. " expected PanelTopTabButtonTemplate")
art(tabs[1], true, 1)
art(tabs[2], false, 2)
tabs[3]._scripts.OnClick(tabs[3])
art(tabs[3], true, 3)
art(tabs[1], false, 1)
tabs[1]._scripts.OnClick(tabs[1])
art(tabs[1], true, 1)

M.PSS_SetOpt("uiSkin", "global", 1)
check(tabs[1].pssLine and tabs[1].pssLine:IsShown() and tabs[2].pssLine and not tabs[2].pssLine:IsShown(),
	"Dark underline not on the selected tab only")
M.PSS_SetOpt("uiSkin", "global", 0)
art(tabs[1], true, 1)
SlashCmdList["PSS"]("gui")

if not fail then print("PASS tabs (" .. fl .. ")") end
