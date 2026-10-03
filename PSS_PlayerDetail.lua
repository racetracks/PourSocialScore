------------------------------------------------------------------------
-- POUR SOCIAL SCORE - PLAYER DETAIL WINDOW
--
-- Opened by double-clicking an entry on the Player Ignore List (or "Show
-- details" in its right-click menu). Shows everything PSS knows about the
-- entry and lets you change it in one place:
--   * name, server, faction, class, date added, guild info
--   * expiry (days after the date added, 0 = never) and the note
--   * the five per-player exclusions (same as W / I / G / P / C on the list)
--   * per-player overrides (ignore response, declines, duels, trades)
--   * block counts and the full block history, with reset
--   * remove from the list
-- NPC and server entries show the details, note, expiry and remove only.
------------------------------------------------------------------------
local addonName, addon = ...
local M = addon.M
local V = addon.V
local L = addon.L

local DETAIL_W, DETAIL_H = 780, 580


-- Short labels for the per-player override buttons (full label in tooltip).
local OVERRIDE_SHORT = {
	ignoreResponse = "Ignore response",
	showDeclines	= "Show declines",
	declineDuel		= "Decline duels",
	declineTrade	= "Decline trades",
}

local trim = M.trim

local function stateText(v)
	if v == nil then return "|cffaaaaaaDefault|r" end
	return v and "|cff00ff00On|r" or "|cffff5555Off|r"
end

local function splitName(entry, typ)
	if typ == "server" then return "All", M.prettyServer(entry) or entry end
	local dash = string.find(entry, "-", 1, true)
	if dash then
		return string.sub(entry, 1, dash - 1), M.prettyServer(string.sub(entry, dash + 1)) or ""
	end
	return entry, "All"
end

local frame		-- the window (built on first use)

local function entryIndex()
	if not frame or not frame.entryName then return 0 end
	return M.hasAnyIgnored(frame.entryName) or 0
end

local function buildFrame()
	local UI = M.UI
	-- Same window style as the main window; above it whatever strata the
	-- main window was given in Options.
	local f = UI.CreateWindow("PSSPlayerDetailFrame", "Player", DETAIL_W, DETAIL_H,
		{ strata = "FULLSCREEN", minW = 720, minH = 520, saveKey = "playerDetail" })
	frame = f
	local inset = f.inset

	f.heading, f.info = UI.CreateSummary(inset, "", 400)
	-- block metrics (same table as every player/guild report)
	f.metrics = UI.CreateMetricsTable(inset)
	f.metrics:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -6)

	------------------------------------------------------------ details
	f.fields = {}
	local ROW_Y, ROW_H = -64, 19
	local function field(key, label, row)
		local l = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		l:SetPoint("TOPLEFT", 10, ROW_Y - (row - 1) * ROW_H)
		l:SetWidth(130)
		l:SetJustifyH("LEFT")
		l:SetText(label)
		local v = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		v:SetPoint("TOPLEFT", 142, ROW_Y - (row - 1) * ROW_H)
		v:SetWidth(250)
		v:SetJustifyH("LEFT")
		v:SetWordWrap(false)
		f.fields[key] = { label = l, value = v, row = row }
		return v
	end
	field("name",		"Name:", 1)
	field("server",		"Server:", 2)
	field("type",		"Type / Faction:", 3)
	field("class",		"Class:", 4)
	field("added",		"Added:", 5)
	field("expires",	"Expires after:", 6)
	field("guildThen", "Guild when added:", 7)
	field("guildNow",	"Current guild:", 8)
	field("lastInv",	"Last blocked invite:", 9)

	-- Expiry: days after the date added (0 = never), typed in place.
	local exp = UI.NumberBox(inset, 44, UI.ROW_BUTTON_H, 4)
	exp:SetPoint("LEFT", f.fields.expires.label, "LEFT", 138, 0)
	f.expireBox = exp
	f.fields.expires.value:ClearAllPoints()
	f.fields.expires.value:SetPoint("LEFT", exp, "RIGHT", 6, 0)
	f.fields.expires.value:SetWidth(200)
	local function commitExpire()
		local idx = entryIndex()
		local days = tonumber(exp:GetText())
		if idx > 0 and days then
			M.PSS_SetExpiry(idx, days)
			if M.PSSUpdateUI then M.PSSUpdateUI() end
		end
		exp:ClearFocus()
		if M.PSS_RefreshPlayerDetail then M.PSS_RefreshPlayerDetail() end
	end
	exp:SetScript("OnEnterPressed", commitExpire)
	exp:SetScript("OnEscapePressed", function(self) self:ClearFocus(); M.PSS_RefreshPlayerDetail() end)
	exp:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Expiry", 1, 1, 1)
		GameTooltip:AddLine("Days after the date added before this entry is removed automatically. 0 = never. Press Enter to save.", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	exp:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- Add the player's current guild to the Guild Ignore List.
	local addGuild = UI.RowButton(inset, "Add Guild", 90)
	addGuild:SetPoint("LEFT", f.fields.guildNow.value, "LEFT", 170, 0)
	addGuild:SetScript("OnClick", function(self)
		if self.guildName and M.PSS_AddGuild then
			M.PSS_AddGuild(self.guildName)
			M.ShowMsg(("Added <%s> to the Guild Ignore List."):format(self.guildName))
			M.PSS_RefreshPlayerDetail()
		end
	end)
	addGuild:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Add Guild", 1, 1, 1)
		GameTooltip:AddLine("Adds this player's current guild to the Guild Ignore List.", nil, nil, nil, true)
		GameTooltip:Show()
	end)
	addGuild:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.addGuild = addGuild

	------------------------------------------------------------ exclusions
	-- exactly the Player Ignore List header and tickboxes
	local RIGHT_X = 420
	f.exclHeading = UI.Heading(inset, "Per-player exclusions")
	f.exclHeading:SetPoint("TOPLEFT", RIGHT_X, -64)
	f.exclHR = UI.CreateHeaderRow(inset, {
		{ key = "excl", letters = "excl", width = UI.EXCL_W, lettersTitle = "Per-player exclusions",
			lettersNote = "Ticked = allowed from this player, unticked = blocked." },
	}, RIGHT_X, -82, nil, { id = "detailExcl", onLayout = function(h) if f.exclRow then f.exclRow:SetWidth(h.total) end end })
	local exRow = CreateFrame("Frame", nil, inset)
	exRow:SetPoint("TOPLEFT", RIGHT_X, -82 - UI.HEADER_H)
	exRow:SetSize(f.exclHR.total, UI.ROW_H)
	f.exclRow = exRow
	f.excl = UI.CreateExclusionBoxes(exRow, f.exclHR, "excl", function(box, cat)
		if f.entryName and M.PSS_SetPlayerSetting then
			M.PSS_SetPlayerSetting(f.entryName, UI.EXCL_BY_CAT[cat].field, UI.ExclBlocked(box))
			if M.PSSUpdateUI then M.PSSUpdateUI() end
		end
	end)

	------------------------------------------------------------ overrides
	f.overrideHeading = UI.Heading(inset, "Overrides for this player")
	f.overrideHeading:SetPoint("TOPLEFT", RIGHT_X, -140)
	f.overrides = {}
	local n = 0
	for _, o in ipairs(M.PSS_OPTIONS or {}) do
		if o.target and o.kind == "bool" then
			n = n + 1
			local b = UI.RowButton(inset, "", 165)
			local col, row = (n - 1) % 2, math.floor((n - 1) / 2)
			b:SetPoint("TOPLEFT", RIGHT_X + col * 170, -158 - row * 22)
			b.opt = o
			b:SetScript("OnClick", function(self)
				local p = f.record
				if not p then return end
				local cur = p.opts and p.opts[self.opt.key]
				local nextV
				if cur == nil then nextV = true elseif cur == true then nextV = false else nextV = nil end
				M.PSS_SetOpt(self.opt.key, "person", nextV, p)
				M.PSS_RefreshPlayerDetail()
			end)
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:AddLine(self.opt.label, 1, 1, 1, true)
				GameTooltip:AddLine("Click to cycle: Default (use the Options tab) > On > Off.", 0.8, 0.8, 0.8, true)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			f.overrides[#f.overrides + 1] = b
		end
	end

	------------------------------------------------------------ note
	local noteLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	noteLabel:SetPoint("TOPLEFT", 10, -238)
	noteLabel:SetText("Note:")
	local note = UI.InputBox(inset, nil, 20, nil, 128)
	note:SetPoint("LEFT", noteLabel, "LEFT", 138, 0)
	note:SetPoint("RIGHT", inset, "RIGHT", -16, 0)
	note:SetTextInsets(2, 2, 0, 0)
	local function commitNote()
		local idx = entryIndex()
		if idx > 0 then
			M.PSS_SetNote(idx, trim(note:GetText()))
			if M.PSSUpdateUI then M.PSSUpdateUI() end
		end
	end
	note:SetScript("OnEnterPressed", function(self) commitNote(); self:ClearFocus() end)
	note:SetScript("OnEditFocusLost", commitNote)
	note:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	f.noteBox = note

	------------------------------------------------------------ history
	local body = CreateFrame("Frame", nil, inset)
	body:SetPoint("TOPLEFT", 1, -262)
	body:SetPoint("BOTTOMRIGHT", -1, 4)
	f.historyBody = body
	f.history = M.PSS_CreateHistoryList(body, 8, UI.ROW_H, DETAIL_W - 40)

	------------------------------------------------------------ bottom bar
	local remove = UI.BarButton(inset, "Remove from List", nil, 150)
	remove:SetScript("OnClick", function(self)
		-- removes straight away (no confirmation)
		local idx = entryIndex()
		if idx <= 0 then f:Hide() return end
		local typ = PourSocialScoreDB.typeList[idx]
		V.needSorted = true
		if typ == "player" then
			M.PSS_DelIgnore(idx, true)
		elseif typ == "npc" then
			M.AddOrDelNPC(idx)
			M.PSSUpdateUI()
		elseif typ == "server" then
			M.AddOrDelServer(idx)
			M.PSSUpdateUI()
		end
		f:Hide()
	end)
	f.removeButton = remove

	local reset = UI.BarButton(inset, L["HISTORY_RESET"] or "Reset Block History", remove, 150)
	reset:SetScript("OnClick", function()
		if f.entryName and M.PSS_ResetPlayerBlockHistory then
			M.PSS_ResetPlayerBlockHistory(f.entryName)
			M.PSS_RefreshPlayerDetail(true)
		end
	end)
	f.resetButton = reset

	f:HookScript("OnShow", function(self) self:Raise() end)
	return f
end

local function setFieldShown(key, shown)
	local fl = frame.fields[key]
	fl.label:SetShown(shown)
	fl.value:SetShown(shown)
end

-- Redraw from the saved data. Safe to call any time (no-op when hidden).
function M.PSS_RefreshPlayerDetail(resetScroll)
	local f = frame
	if not f or not f:IsShown() then return end
	local idx = entryIndex()
	if idx <= 0 then f:Hide() return end	-- removed from the list elsewhere

	local db = PourSocialScoreDB
	local entry = db.ignoreList[idx]
	local typ = db.typeList[idx] or "player"
	local isPlayer = (typ == "player")
	local p = isPlayer and M.PSS_GetPlayerPrefs and M.PSS_GetPlayerPrefs(entry) or nil
	f.record = p

	local shortName, server = splitName(entry, typ)
	local color = "|cffffffff"
	if p and p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class] then
		local c = RAID_CLASS_COLORS[p.class]
		color = ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
	end
	local titlePrefix = (typ == "npc" and "NPC: ") or (typ == "server" and "Server: ") or "Player: "
	f.title:SetText(titlePrefix .. (typ == "server" and server or shortName))
	f.heading:SetText(titlePrefix .. color .. (typ == "server" and server or (shortName .. (server ~= "All" and ("-" .. server) or ""))) .. "|r")

	-- details
	f.fields.name.value:SetText(color .. shortName .. "|r")
	f.fields.server.value:SetText(server)
	local fac = db.factionList[idx]
	local typeText
	if typ == "npc" then typeText = "|cffffff99NPC|r"
	elseif typ == "server" then typeText = "|cffff66ccWhole server|r"
	elseif fac == "Alliance" then typeText = "Player - |cff335effAlliance|r"
	elseif fac == "Horde" then typeText = "Player - |cffe60000Horde|r"
	else typeText = "Player - Unknown faction" end
	f.fields.type.value:SetText(typeText)
	f.fields.class.value:SetText(p and (p.className or (p.class ~= "" and p.class) or nil) or "|cff808080Unknown|r")

	local added = db.dateList[idx]
	local ago = added and M.daysFromToday(added) or 0
	f.fields.added.value:SetText(added and (("%s  |cffaaaaaa(%d %s ago)|r"):format(added, ago, M.dayString(ago))) or "|cff808080Unknown|r")

	local expDays = tonumber(db.expList[idx]) or 0
	if not f.expireBox:HasFocus() then f.expireBox:SetText(tostring(expDays)) end
	local left = expDays - ago
	if expDays == 0 then f.fields.expires.value:SetText("days  |cff808080(never expires)|r")
	elseif left <= 0 then f.fields.expires.value:SetText("days  |cffff6666(expires today)|r")
	else f.fields.expires.value:SetText(("days  |cffaaaaaa(%d %s left)|r"):format(left, M.dayString(left))) end

	for _, k in ipairs({ "class", "guildThen", "guildNow", "lastInv" }) do setFieldShown(k, isPlayer) end
	if p then
		f.fields.guildThen.value:SetText((p.guildWhenBlocked or "") ~= "" and ("<" .. p.guildWhenBlocked .. ">") or "|cff808080None seen|r")
		local now = p.currentGuild or ""
		f.fields.guildNow.value:SetText(now ~= "" and ("<" .. now .. ">") or "|cff808080None seen|r")
		f.fields.lastInv.value:SetText((p.lastBlockedInvite or "") ~= "" and p.lastBlockedInvite or "|cff808080Never|r")
		local listed = now ~= "" and db.guildData and M.PSS_NormalizeGuild and db.guildData[M.PSS_NormalizeGuild(now)]
		f.addGuild.guildName = now
		f.addGuild:SetShown(now ~= "")
		f.addGuild:SetEnabled(now ~= "" and not listed)
		f.addGuild:SetText(listed and "Listed" or "Add Guild")
	else
		f.addGuild:Hide()
	end

	-- exclusions + overrides (players only)
	f.exclHeading:SetShown(isPlayer)
	f.exclHR:SetShown(isPlayer)
	f.overrideHeading:SetShown(isPlayer)
	for _, e in ipairs(M.UI.EXCL) do
		local c = f.excl[e.cat]
		c:SetShown(isPlayer)
		if p then c:SetChecked(M.UI.ExclChecked(p[e.field] ~= false)) end
	end
	for _, b in ipairs(f.overrides) do
		b:SetShown(isPlayer)
		if p then
			local cur = p.opts and p.opts[b.opt.key]
			b:SetText((OVERRIDE_SHORT[b.opt.key] or b.opt.key) .. ": " .. stateText(cur))
		end
	end

	-- note
	if not f.noteBox:HasFocus() then f.noteBox:SetText(db.notes[idx] or "") end

	-- counts + history
	local list = {}
	if p then
		local c = M.PSS_GetPlayerBlockCounts(p)
		f.info:SetText(("Blocked |cffffff00%d|r messages and invites from this player."):format(c.total or 0))
		f.metrics:Set(c)
		f.metrics:Show()
		list = M.PSS_GetPlayerBlockHistory(entry)
	else
		f.info:SetText("|cff808080No block history is kept for " .. (typ == "npc" and "NPC" or "server") .. " entries.|r")
		f.metrics:Hide()
	end
	f.history:SetEntries(list, resetScroll)
	f.history:SetShown(isPlayer)
	f.resetButton:SetShown(isPlayer)
end

-- name: the entry exactly as stored in PourSocialScoreDB.ignoreList
function M.PSS_ShowPlayerDetail(name)
	if not name or M.hasAnyIgnored(name) == 0 then return end
	local f = frame or buildFrame()
	if f.entryName ~= name then
		f.noteBox:ClearFocus()
		f.expireBox:ClearFocus()
	end
	f.entryName = name
	f:Show()
	f:Raise()
	M.PSS_RefreshPlayerDetail(true)
end

-- The Player Block History popup (PSS_ChatHistoryUI.lua).
function M.PSS_ShowPlayerBlockHistory(name)
	local p = M.PSS_GetPlayerPrefs(name)
	if not p then return end
	M.PSS_History.ShowPopup(function()
		return "Player Block History: " .. (p.name or name), M.PSS_GetPlayerBlockHistory(name), M.PSS_GetPlayerBlockCounts(p)
	end, function() M.PSS_ResetPlayerBlockHistory(name) end)
end
