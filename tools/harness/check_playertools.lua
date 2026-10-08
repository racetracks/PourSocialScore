-- The new window's Player Ignore List tools (3.4.0.17), as a run.lua
-- script on any save, real ones included: Add Player with the box empty
-- adds your target (another player of your faction; a secret name or an
-- enemy is never added); Player Search sends the /who only from its click,
-- lists the players found in place of the list (listed ones greyed; tick,
-- Tick All, Save, Escape) and offers Add Anyway when nobody is found; the
-- button follows the /who cooldown; Prune asks the days, counts what it
-- removes as you type and removes only on Prune. Neither old window loads.
local fail = false
local function check(ok, msg) if not ok then print("FAIL playertools: " .. msg) fail = true end end
local loaded = C_AddOns.IsAddOnLoaded

-- /who: every filter sent, and the answer the next WHO_LIST_UPDATE reads
local sent, answer = {}, {}
C_FriendList.SendWho = function(filter) sent[#sent + 1] = filter end
C_FriendList.GetNumWhoResults = function() return #answer, #answer end
C_FriendList.GetWhoInfo = function(i) return answer[i] end
local function answerWho(list)
	answer = list
	H.Fire("WHO_LIST_UPDATE")
	answer = {}
end
local function lastSent() return sent[#sent] end

SlashCmdList["PSS"]("tui")
local win = _G.PSS_Window
win.tabs[1]._scripts.OnClick(win.tabs[1])
local page = win.pages[1]
local list, pane, picker = page.list, page.pane, page.picker
check(page:IsShown() and picker and page.searchButton and page.pruneButton, "Players tab tools not built")

-- your target: a player of your faction
local tName, tRealm, tFaction, secret = "Targeted", "Realm2", "Alliance", false
local oldExists, oldIsPlayer, oldName, oldFaction, oldSecret = UnitExists, UnitIsPlayer, UnitName, UnitFactionGroup, issecretvalue
UnitExists = function(u) return u == "target" or u == "player" end
UnitIsPlayer = function() return true end
UnitName = function(u)
	if u == "target" then return tName, tRealm end
	return oldName(u)
end
UnitFactionGroup = function(u) if u == "target" then return tFaction end return "Alliance" end
-- a secret name (Retail 12.x while restricted)
issecretvalue = function(v) return secret and v == tName end

page.add:SetText("")
page.addButton._scripts.OnClick(page.addButton)
check(M.PSS_PlayerPosition("Targeted-Realm2") > 0 and pane.row.entry == "Targeted-Realm2", "an empty box did not add and select the target")
-- an enemy, or a secret name, is never added
tName, tFaction = "Enemy", "Horde"
page.addButton._scripts.OnClick(page.addButton)
check(M.PSS_PlayerPosition("Enemy-Realm2") == 0, "an enemy target was added")
tName, tFaction, secret = "Hidden", "Alliance", true
page.addButton._scripts.OnClick(page.addButton)
check(M.PSS_PlayerPosition("Hidden-Realm2") == 0, "a secret target name was added")
secret = false
UnitExists, UnitIsPlayer, UnitName, UnitFactionGroup, issecretvalue = oldExists, oldIsPlayer, oldName, oldFaction, oldSecret

-- Player Search: nothing typed sends nothing
local before = #sent
page.add:SetText("")
page.searchButton._scripts.OnClick(page.searchButton)
check(#sent == before, "an empty Player Search sent a /who")

-- the results in place of the list
H.Advance(10)
page.add:SetText("Seeker-Realm1")
page.searchButton._scripts.OnClick(page.searchButton)
check(lastSent() == 'n-"Seeker"', "Player Search sent " .. tostring(lastSent()))
check(page.add:GetText() == "", "the box not cleared after the search went out")
answerWho({
	{ fullName = "Seeker-Realm1", level = 70, classStr = "Mage", fullGuildName = "Some Guild" },
	{ fullName = "Targeted-Realm2", level = 80, classStr = "Priest" },
})
H.RunTimers()
check(picker:IsShown() and not list.scroll:IsVisible() and #picker.items == 2, "Player Search results not shown")
check(picker.title:GetText():find("2 player(s) found", 1, true), "picker title " .. tostring(picker.title:GetText()))
local pi
for i, it in ipairs(picker.items) do
	if it.name == "Seeker-Realm1" then
		pi = i
		check(it.level == "70" and it.class == "Mage" and it.guild == "Some Guild" and not it.listed, "picker entry")
	end
	if it.name == "Targeted-Realm2" then check(it.listed, "a listed player not marked") end
end
picker.list.scroll:SetHeight(240)
picker.list:Layout()
picker.list.scroll:SetVerticalScroll(0)
local pr
for _, r in ipairs(picker.list.rows) do if r.index == pi then pr = r end end
check(pr and pr.cells.name:GetText() == "Seeker-Realm1" and pr.cells.class:GetText() == "Mage", "picker row cells")
pr._scripts.OnClick(pr, "LeftButton")
check(picker.items[pi].ticked, "picker click did not tick")
picker.saveButton._scripts.OnClick(picker.saveButton)
check(M.PSS_PlayerPosition("Seeker-Realm1") > 0, "Save did not add the player")
check(not picker:IsShown() and list.scroll:IsVisible(), "results not closed after Save")

-- the button follows the /who cooldown
H.RunTimers(1)
if M.PSS_ScanCooldownActive() then check(not page.searchButton:IsEnabled(), "Player Search enabled while /who cools down") end
H.RunTimers()
check(page.searchButton:IsEnabled(), "Player Search not enabled after the cooldown")

-- Escape closes the results, the window stays and nothing is added
H.Advance(10)
page.add:SetText("Other")
page.searchButton._scripts.OnClick(page.searchButton)
answerWho({ { fullName = "Other-Realm1", level = 10, classStr = "Rogue" } })
H.RunTimers()
check(picker:IsShown(), "second search not shown")
picker.allButton._scripts.OnClick(picker.allButton)
check(picker.items[1].ticked, "Tick All")
_G.PSS_WindowEscape:Hide()
check(win:IsShown() and not picker:IsShown() and list.scroll:IsVisible(), "Escape did not close the results")
check(M.PSS_PlayerPosition("Other-Realm1") == 0, "Escape added the ticked player")

-- nobody found: Add Anyway
H.Advance(10)
page.add:SetText("Nobody-Realm1")
page.searchButton._scripts.OnClick(page.searchButton)
answerWho({})
H.RunTimers()
local cf = _G.PSS_Confirm
check(cf and cf:IsShown() and cf.text:GetText():find("Nobody-Realm1", 1, true) and not cf.box:IsShown(), "no Add Anyway confirm")
cf.accept._scripts.OnClick(cf.accept)
check(M.PSS_PlayerPosition("Nobody-Realm1") > 0, "Add Anyway did not add")
H.RunTimers()

-- Prune: an entry listed long ago, the count as you type, Cancel keeps it
local old = M.PSS_PlayerPosition("Nobody-Realm1")
PourSocialScoreDB.dateList[old] = date("%d %b %Y", time() - 4000 * 86400)
local want = M.PruneIgnoreList(3000)
check(want >= 1, "prune count " .. want)
page.pruneButton._scripts.OnClick(page.pruneButton)
check(cf:IsShown() and cf.box:IsShown() and cf.box:GetText() == tostring(M.PSS_PRUNE_DAYS), "Prune popup without its days")
local function typeDays(text)
	cf.box:SetText(text)
	cf.box._scripts.OnTextChanged(cf.box, true)
end
typeDays("")
check(not cf.accept:IsEnabled() and cf.text:GetText():find("Type a number", 1, true), "Prune with no days allowed")
typeDays("3000")
check(cf.accept:IsEnabled() and cf.text:GetText():find(("%d entr"):format(want), 1, true), "Prune count text: " .. tostring(cf.text:GetText()))
cf.cancel._scripts.OnClick(cf.cancel)
check(M.PSS_PlayerPosition("Nobody-Realm1") > 0, "Cancel pruned")
-- Prune removes them
local count = M.PSS_PlayerCount()
page.pruneButton._scripts.OnClick(page.pruneButton)
typeDays("3000")
cf.accept._scripts.OnClick(cf.accept)
H.RunTimers()
check(M.PSS_PlayerPosition("Nobody-Realm1") == 0 and M.PSS_PlayerCount() == count - want, "Prune did not remove the old entries")
check(M.PSS_PlayerPosition("Seeker-Realm1") > 0, "Prune removed a new entry")

check(not loaded("PourSocialScore_GUI") and not loaded("PourSocialScore_EllesmereUI"), "an old window loaded")

if not fail then print(("PASS playertools (%d pruned)"):format(want)) end
