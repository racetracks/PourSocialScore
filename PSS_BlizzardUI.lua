-----------------------
-- BLIZZARD UI HOOKS --
-----------------------

local addonName, addon 	= ...
local L = addon.L -- localization entries
local V = addon.V -- shared variables
local M = addon.M -- shared methods

--------------------
-- LFG TOOL HACKS --
--------------------

-- Re-colour the Group Finder rows that are on screen after the list changes.
-- 2.0.8 called Blizzard's LFGListSearchPanel_UpdateResults from addon code,
-- which can taint the Group Finder (blocked "Sign Up" etc.). This only sets
-- text colours on the visible rows; Blizzard's own update recolours the rest.
function M.PSS_LFG_Refresh()
	local panel = LFGListFrame and LFGListFrame.SearchPanel
	if not (panel and panel:IsShown() and panel.ScrollBox and panel.ScrollBox.ForEachFrame) then return end
	pcall(panel.ScrollBox.ForEachFrame, panel.ScrollBox, function(row)
		if row and row.resultID and row.Name then pcall(M.PSS_LFG_Update, row) end
	end)
end

function M.PSS_LFG_Update (self)
	if not C_LFGList.HasSearchResultInfo(self.resultID) then return end
	
	local info = C_LFGList.GetSearchResultInfo(self.resultID);
	local leader = info and info.leaderName
	
	-- runs for every visible Group Finder row on every refresh: O(1) lookup,
	-- no display-name building
	if type(leader) == "string" and not M.PSS_IsSecret(leader) and leader ~= "" and M.PSS_IsPlayerListed(leader) then
		self.Name:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
	end	
end

function M.PSS_LFG_Tooltip (self)
	if not C_LFGList.HasSearchResultInfo(self.resultID) then return end

	local info = C_LFGList.GetSearchResultInfo(self.resultID);
	
	if info ~= nil and type(info.leaderName) == "string" and not M.PSS_IsSecret(info.leaderName) then
		local idx = M.PSS_ListedPosition(M.PSS_CanonPlayer(info.leaderName)) or 0
		
		if (idx > 0) then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("|c00ff0000" .. L["RCM_8"])
		
			local notes = (PourSocialScoreDB.notes[idx] or "")
				
			if (notes ~= "") then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine("|cffffffff" .. L["RCM_9"])
				GameTooltip:AddLine("|cff69CCF0"..notes)
			end
		
			GameTooltip:Show()
		end
	end
end

function M.PSS_LFG_ApplicantMenu(owner, root, contextData)
	if not owner or not owner.resultID then return end
	
	local info = C_LFGList.GetSearchResultInfo(owner.resultID);
	
	if not info or type(info.leaderName) ~= "string" or M.PSS_IsSecret(info.leaderName) or info.leaderName == "" then return end
	
	local target = M.Proper(M.addServer(info.leaderName))
	local text   = ""
	
	if M.PSS_IsPlayerListed(info.leaderName) then
		text = L["RCM_4"]				
	else
		text = L["RCM_6"]
	end	
	
	local leaderText = format(L["RCM_7"], target)
	
	root:CreateDivider()
	root:CreateTitle(leaderText)
	root:CreateButton(text,
		function(owner, root, contextData)
			M.PSS_AddOrDelIgnore(M.addServer(info.leaderName))
			M.PSSUpdateUI(true)
		end)	
end

----------------------
-- UNIT MENU- HACKS --
----------------------

function M.PSS_UnitMenuPlayer (owner, root, contextData)
	if type(contextData) ~= "table" then return end
	if contextData.bnetIDAccount and not contextData.unit then return end   -- a Battle.net friend, not a character
	local target, server
	if contextData.unit and UnitExists(contextData.unit) then
		target, server = UnitName(contextData.unit)
	else
		-- menus opened from a name in chat carry the name, not a unit
		target, server = contextData.name, contextData.server
	end
	-- secret check first: a secret value can't even be compared with ""
	if type(target) ~= "string" or M.PSS_IsSecret(target) or target == "" then return end
	if server ~= nil and (type(server) ~= "string" or M.PSS_IsSecret(server)) then server = nil end
	if contextData.unit and UnitIsUnit and UnitExists(contextData.unit) and UnitIsUnit(contextData.unit, "player") then return end

	if server == nil or server == "" then
		target = M.addServer(target)
	else
		target = target .. "-" .. server
	end

	target = M.Proper(target, true)

	local text = ""
	
	if (M.hasGlobalIgnored(M.addServer(target)) > 0) then
		text = L["RCM_4"]				
	else
		text = L["RCM_6"]
	end	

	root:CreateDivider()
	root:CreateButton(text,
		function(owner, root, contextData)
			M.PSS_AddOrDelIgnore(M.addServer(target))
			M.PSSUpdateUI(true)
		end)
end

-----------------------
-- ADDON COMPARTMENT --
-----------------------

if V.wowIsRetail == true and AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
	AddonCompartmentFrame:RegisterAddon({
		text = "Pour Social Score",
		icon = "Interface\\Icons\\ui_chat.blp",
		notCheckable = true,
		func = function(button, menuInputData, menu)
			M.PSS_GUI()
		end,
	})
end

--------------
-- UI HOOKS --
--------------

-- The Group Finder functions may not exist yet (load-on-demand addon) or at all
-- on some client builds (e.g. WoW Forever).  Hook only what is present, once,
-- and retry when the Group Finder addon loads.
local lfgHooked = false

local function hookLFG()
	if lfgHooked then return true end
	if not (PourSocialScoreDB and M.PSS_Opt("useLFGHacks") == true) then return true end
	if not (C_LFGList and Menu and Menu.ModifyMenu) then return true end

	if type(_G.LFGListSearchEntry_Update) ~= "function"
		or type(_G.LFGListSearchEntry_OnEnter) ~= "function" then
		return false -- not available (yet)
	end

	hooksecurefunc("LFGListSearchEntry_Update", M.PSS_LFG_Update)
	hooksecurefunc("LFGListSearchEntry_OnEnter", M.PSS_LFG_Tooltip)
	Menu.ModifyMenu("MENU_LFG_FRAME_SEARCH_ENTRY", M.PSS_LFG_ApplicantMenu)

	lfgHooked = true
	return true
end

function M.PSS_HookFunctions()
	-- /script Menu.PrintOpenMenuTags()

	if not hookLFG() then
		local waiter = CreateFrame("Frame")
		waiter:RegisterEvent("ADDON_LOADED")
		waiter:SetScript("OnEvent", function(self)
			if hookLFG() then
				self:UnregisterAllEvents()
			end
		end)
	end

	if M.PSS_Opt("useUnitHacks") == true and Menu and Menu.ModifyMenu then
		-- FRIEND is the menu for a name clicked in chat; the COMMUNITIES and
		-- GUILD ones are the guild / community rosters. (Battle.net friend
		-- menus are left alone: they carry a Battle.net name, not a character.)
		for _, tag in ipairs({ "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER",
		                       "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_GUILD",
		                       "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER" }) do
			pcall(Menu.ModifyMenu, tag, M.PSS_UnitMenuPlayer)
		end
	end
end
