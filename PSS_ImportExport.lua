------------------------------------------------------------------------
-- POUR SOCIAL SCORE - IMPORT / EXPORT
--
-- Export the chosen sections to one text string; import a string with
-- Merge (add what's missing, keep what you have) or Replace (the section
-- becomes exactly what was imported).
--
-- Format:  PSS1:<checksum>:<base64 payload>
-- The payload is a small typed serialisation (never executed as code), so
-- an import string can only ever contain data.
------------------------------------------------------------------------
local addonName, addon = ...
local L = addon.L
local V = addon.V
local M = addon.M

local FORMAT_TAG = "PSS1"

------------------------------------------------------------------------
-- Serialiser: T/F booleans, n<number>; , s<len>:<bytes>, { k v k v ... }
------------------------------------------------------------------------
local function ser(v, out)
	local t = type(v)
	if t == "boolean" then out[#out + 1] = v and "T" or "F"
	elseif t == "number" then out[#out + 1] = "n" .. tostring(v) .. ";"
	elseif t == "string" then out[#out + 1] = "s" .. #v .. ":" .. v
	elseif t == "table" then
		out[#out + 1] = "{"
		local keys = {}
		for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = k end end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			local val = v[k]
			local vt = type(val)
			if vt == "boolean" or vt == "number" or vt == "string" or vt == "table" then
				ser(k, out); ser(val, out)
			end
		end
		out[#out + 1] = "}"
	end
end

local function deser(s, pos, depth)
	if depth > 40 then error("nesting too deep") end
	local c = s:sub(pos, pos)
	if c == "T" then return true, pos + 1
	elseif c == "F" then return false, pos + 1
	elseif c == "n" then
		local e = s:find(";", pos, true)
		if not e then error("bad number") end
		local n = tonumber(s:sub(pos + 1, e - 1))
		if not n then error("bad number") end
		return n, e + 1
	elseif c == "s" then
		local colon = s:find(":", pos, true)
		if not colon then error("bad string") end
		local len = tonumber(s:sub(pos + 1, colon - 1))
		if not len or len < 0 then error("bad string length") end
		local str = s:sub(colon + 1, colon + len)
		if #str ~= len then error("truncated string") end
		return str, colon + len + 1
	elseif c == "{" then
		local t = {}
		pos = pos + 1
		while true do
			if pos > #s then error("unterminated table") end
			if s:sub(pos, pos) == "}" then return t, pos + 1 end
			local k, v
			k, pos = deser(s, pos, depth + 1)
			if type(k) ~= "string" and type(k) ~= "number" then error("bad key") end
			v, pos = deser(s, pos, depth + 1)
			t[k] = v
		end
	end
	error("unexpected data at " .. pos)
end

------------------------------------------------------------------------
-- Base64 (Lua 5.1, no bit library needed) + checksum
------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64IDX = {}
for i = 1, 64 do B64IDX[B64:sub(i, i)] = i - 1 end

local function b64enc(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) ..
			(b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function b64dec(text)
	text = text:gsub("[^%w%+/=]", "")
	if #text % 4 ~= 0 then error("damaged text (length)") end
	local out = {}
	for i = 1, #text, 4 do
		local q = { text:byte(i, i + 3) }
		local n, pad = 0, 0
		for j = 1, 4 do
			local ch = string.char(q[j])
			local v
			if ch == "=" then v = 0; pad = pad + 1 else v = B64IDX[ch] end
			if not v then error("damaged text (character)") end
			n = n * 64 + v
		end
		local a = math.floor(n / 65536) % 256
		local b = math.floor(n / 256) % 256
		local c = n % 256
		if pad == 0 then out[#out + 1] = string.char(a, b, c)
		elseif pad == 1 then out[#out + 1] = string.char(a, b)
		else out[#out + 1] = string.char(a) end
	end
	return table.concat(out)
end

local function checksum(s)
	local h = 5381
	for i = 1, #s do h = (h * 33 + s:byte(i)) % 16777213 end
	return string.format("%06x", h)
end

function M.PSS_EncodeExport(tbl)
	local out = {}
	ser(tbl, out)
	local payload = table.concat(out)
	return FORMAT_TAG .. ":" .. checksum(payload) .. ":" .. b64enc(payload)
end

function M.PSS_DecodeExport(text)
	if type(text) ~= "string" then return nil, "nothing to import" end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	local tag, sum, body = text:match("^(%w+):(%x+):(.+)$")
	if tag ~= FORMAT_TAG then return nil, "this is not a Pour Social Score export string" end
	local okB, payload = pcall(b64dec, body)
	if not okB then return nil, tostring(payload) end
	if checksum(payload) ~= sum:lower() then return nil, "the text is incomplete or was changed (checksum mismatch) - copy the whole string" end
	local okD, data, pos = pcall(deser, payload, 1, 0)
	if not okD then return nil, "could not read the data: " .. tostring(data) end
	if type(data) ~= "table" or pos ~= #payload + 1 then return nil, "could not read the data" end
	return data
end

------------------------------------------------------------------------
-- Build / apply
------------------------------------------------------------------------
local PREF_FIELDS = { "whispersBlocked", "partyInvitesBlocked", "guildInvitesBlocked", "partyRaidBlocked", "channelsBlocked", "nickname" }
local BLOCK_CATS = { "whisper", "partyInvite", "guildInvite", "partyRaid", "world" }
-- W I G P C flags (true/false; missing = inherit for members)
local function copyBlock(b)
	if type(b) ~= "table" then return nil end
	local t = {}
	for _, c in ipairs(BLOCK_CATS) do if type(b[c]) == "boolean" then t[c] = b[c] end end
	return t
end
local GUILD_FIELDS = { "enabled", "declineGuild", "declineGroup", "partyRaid", "customScan", "ruleOrigin" }
local MEMBER_FIELDS = { "name", "guild", "whenBlocked", "note", "excludedGroup", "excludedGuildInvite",
						"excludedWhispers", "excludedChat", "class", "className", "level", "race", "_playerKey" }

local function copyFields(src, fields)
	local t = {}
	for _, f in ipairs(fields) do
		local v = src[f]
		if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then t[f] = v end
	end
	return t
end

local function copyOpts(o)
	if type(o) ~= "table" then return nil end
	local t = {}
	for k, v in pairs(o) do if type(k) == "string" and (type(v) == "boolean" or type(v) == "number" or type(v) == "string") then t[k] = v end end
	return next(t) and t or nil
end

-- sections: { players, guilds, members, filters, builtins, options }
function M.PSS_BuildExport(sections)
	local db = PourSocialScoreDB
	local data = { v = 1, addon = "PourSocialScore", made = date("%Y-%m-%d %H:%M"), by = M.PSS_CharKey and M.PSS_CharKey() or "" }
	if sections.players then
		data.players = {}
		for i, name in ipairs(db.ignoreList or {}) do
			local e = {
				name = name, type = db.typeList[i] or "player", note = db.notes[i] or "",
				date = db.dateList[i] or "", exp = tonumber(db.expList[i]) or 0, faction = db.factionList[i] or "",
			}
			if e.type == "player" then
				local p = M.PSS_GetPlayerRecord and M.PSS_GetPlayerRecord(name)
				if p then e.prefs = copyFields(p, PREF_FIELDS); e.opts = copyOpts(p.opts) end
			end
			data.players[#data.players + 1] = e
		end
	end
	if sections.guilds then
		data.guilds = {}
		for key, g in pairs(db.guildData or {}) do
			if type(g) == "table" then
				local e = copyFields(g, GUILD_FIELDS)
				e.block = copyBlock(M.PSS_GuildBlock and M.PSS_GuildBlock(g) or g.block)
				e.name = g.name or key
				e.opts = copyOpts(g.opts)
				if sections.members then
					e.members = {}
					for mk, m in pairs(g.members or {}) do
						if type(m) == "table" then
							local me = copyFields(m, MEMBER_FIELDS)
							me.block = copyBlock(M.PSS_MemberBlock and M.PSS_MemberBlock(m) or m.block)
							me.key = mk
							me.opts = copyOpts(m.opts)
							e.members[#e.members + 1] = me
						end
					end
				end
				data.guilds[#data.guilds + 1] = e
			end
		end
	end
	if sections.filters then
		data.filters = {}
		for i = 1, #(db.filterList or {}) do
			if not M.PSS_IsBuiltinFilter(i) then
				data.filters[#data.filters + 1] = { desc = db.filterDesc[i] or "", filter = db.filterList[i] or "", active = db.filterActive[i] == true }
			end
		end
	end
	if sections.builtins then
		data.builtins = {}
		for i = 1, #(db.filterList or {}) do
			if M.PSS_IsBuiltinFilter(i) then data.builtins[db.filterID[i]] = db.filterActive[i] == true end
		end
	end
	if sections.options then
		data.options = {}
		for _, o in ipairs(M.PSS_OPTIONS or {}) do
			if db[o.key] ~= nil then data.options[o.key] = db[o.key] end
		end
	end
	return data
end

function M.PSS_DescribeImport(data)
	local parts = {}
	if data.players then parts[#parts + 1] = #data.players .. " ignore list entr" .. (#data.players == 1 and "y" or "ies") end
	if data.guilds then
		local m = 0
		for _, g in ipairs(data.guilds) do m = m + #(g.members or {}) end
		parts[#parts + 1] = #data.guilds .. " guild rule" .. (#data.guilds == 1 and "" or "s") .. (m > 0 and (" (" .. m .. " members)") or "")
	end
	if data.filters then parts[#parts + 1] = #data.filters .. " custom chat filter" .. (#data.filters == 1 and "" or "s") end
	if data.builtins then local n = 0; for _ in pairs(data.builtins) do n = n + 1 end; parts[#parts + 1] = n .. " built-in filter states" end
	if data.options then local n = 0; for _ in pairs(data.options) do n = n + 1 end; parts[#parts + 1] = n .. " options" end
	return #parts > 0 and table.concat(parts, ", ") or "nothing"
end

-- mode: "merge" | "replace"; sections: which parts of the data to apply
function M.PSS_ApplyImport(data, mode, sections)
	local db = PourSocialScoreDB
	local replace = mode == "replace"
	local report = {}

	local ownBatch
	if not M.PSS__purgeBatch then ownBatch = {}; M.PSS__purgeBatch = ownBatch end
	if sections.players and type(data.players) == "table" then
		if replace and M.PSS_RemoveListEntryAt then
			for i = #db.ignoreList, 1, -1 do M.PSS_RemoveListEntryAt(i) end
		end
		local added = 0
		for _, e in ipairs(data.players) do
			if type(e) == "table" and type(e.name) == "string" and e.name ~= "" then
				local t = (e.type == "npc" or e.type == "server") and e.type or "player"
				local exists
				if t == "player" then exists = M.PSS_IsPlayerListed(e.name)
				elseif t == "npc" then exists = M.hasNPCIgnored(e.name) > 0
				else exists = false; for i, n in ipairs(db.ignoreList) do if db.typeList[i] == "server" and n == e.name then exists = true end end end
				if not exists and M.PSS_ImportListEntry then
					M.PSS_ImportListEntry(e.name, e.faction, e.note, t, e.date, e.exp)
					added = added + 1
				end
				if t == "player" then
					local p = M.PSS_GetPlayerPrefs(e.name)
					if p and type(e.prefs) == "table" and (replace or not exists) then
						for _, f in ipairs(PREF_FIELDS) do if e.prefs[f] ~= nil then p[f] = e.prefs[f] end end
						p.opts = copyOpts(e.opts)
					end
				end
			end
		end
		report[#report + 1] = added .. " ignore list entries added"
	end

	if sections.guilds and type(data.guilds) == "table" then
		if replace then db.guildData = {} end
		local addedG, addedM = 0, 0
		for _, ge in ipairs(data.guilds) do
			if type(ge) == "table" and type(ge.name) == "string" and ge.name ~= "" then
				local key = M.PSS_CanonGuild(ge.name)
				local existed = db.guildData[key] ~= nil
				local g = M.PSS_GetGuild(ge.name)
				if g then
					if not existed then
						addedG = addedG + 1
						for _, f in ipairs(GUILD_FIELDS) do if ge[f] ~= nil then g[f] = ge[f] end end
						g.opts = copyOpts(ge.opts)
						-- older export strings have no W I G P C: rebuild from their old fields
						g.block = copyBlock(ge.block)
					end
					if sections.members and type(ge.members) == "table" then
						for _, me in ipairs(ge.members) do
							if type(me) == "table" and type(me.name) == "string" and me.name ~= "" then
								local mk = (type(me.key) == "string" and me.key:find("-", 1, true)) and me.key or M.PSS_NormalizePlayer(me.name)
								if mk and not g.members[mk] then
									local m = copyFields(me, MEMBER_FIELDS)
									m.opts = copyOpts(me.opts)
									m.block = copyBlock(me.block)   -- nil = converted from the old Allow fields
									m.guild = g.name
									m.whenBlocked = m.whenBlocked or M.PSS_NowString()
									for _, f in ipairs({ "excludedGroup", "excludedGuildInvite", "excludedWhispers", "excludedChat" }) do
										if m[f] ~= true then m[f] = nil end
									end
									if M.PSS_CompactMember then M.PSS_CompactMember(m) end   -- only non-default fields are kept
									g.members[mk] = m
									addedM = addedM + 1
									local ck = g.enabled and M.PSS_CanonPlayer(me.name)
									if ck and M.PSS__purgeBatch then M.PSS__purgeBatch[ck] = true end
								end
							end
						end
					end
					g.memberCount = 0
					for _ in pairs(g.members) do g.memberCount = g.memberCount + 1 end
					if M.PSS_RefreshGuildActive then M.PSS_RefreshGuildActive(g) end
				end
			end
		end
		if M.PSS_MarkGuildIndexDirty then M.PSS_MarkGuildIndexDirty() end
		report[#report + 1] = addedG .. " guild rules and " .. addedM .. " members added"
	end

	if sections.filters and type(data.filters) == "table" then
		if replace then
			for i = #db.filterList, 1, -1 do
				if not M.PSS_IsBuiltinFilter(i) then M.RemoveChatFilter(i) end
			end
		end
		local have, added = {}, 0
		for i = 1, #db.filterList do have[(db.filterList[i] or "") .. "\1" .. (db.filterDesc[i] or "")] = true end
		for _, fe in ipairs(data.filters) do
			if type(fe) == "table" and type(fe.filter) == "string" and fe.filter ~= "" then
				local sig = fe.filter .. "\1" .. tostring(fe.desc or "")
				if not have[sig] then
					M.PSS_AddCustomFilter(tostring(fe.desc or "Imported filter"), fe.filter, fe.active == true)
					have[sig] = true
					added = added + 1
				end
			end
		end
		report[#report + 1] = added .. " custom chat filters added"
	end

	if sections.builtins and type(data.builtins) == "table" then
		local n = 0
		for i = 1, #db.filterList do
			local id = db.filterID[i]
			if M.PSS_IsBuiltinFilter(i) and type(data.builtins[id]) == "boolean" then
				db.filterActive[i] = data.builtins[id]; n = n + 1
			end
		end
		report[#report + 1] = n .. " built-in filter states set"
	end

	if sections.options and type(data.options) == "table" then
		local n = 0
		for key, v in pairs(data.options) do
			local def = M.PSS_OPTION_REG and M.PSS_OPTION_REG[key]
			if def then
				local ok = (def.kind == "bool" and type(v) == "boolean") or ((def.kind == "number" or def.kind == "choice") and type(v) == "number")
				if ok then db[key] = v; n = n + 1 end
			end
		end
		report[#report + 1] = n .. " options set"
	end

	if ownBatch and M.PSS__purgeBatch == ownBatch then
		M.PSS__purgeBatch = nil
		if next(ownBatch) and M.PSS_PurgeChatFrom then M.PSS_PurgeChatFrom(ownBatch) end
	end
	if M.PSS_MarkIgnoreIndexDirty then M.PSS_MarkIgnoreIndexDirty() end
	if M.PSS_RequestGC then M.PSS_RequestGC("import") end
	V.needSorted = true
	if M.PSSUpdateUI then pcall(M.PSSUpdateUI, true) end
	if M.PSSUpdateGuildUI then pcall(M.PSSUpdateGuildUI) end
	if M.PSSUpdateChatCount then pcall(M.PSSUpdateChatCount) end
	return table.concat(report, ", ")
end

------------------------------------------------------------------------
-- Tab
------------------------------------------------------------------------
StaticPopupDialogs["PSS_IMPORT_REPLACE"] = {
	preferredIndex = 3,
	text = "Replace the selected sections with the imported data?\n\n%s\n\nWhat you have now in those sections will be removed.",
	button1 = "Replace", button2 = CANCEL,
	OnAccept = function(self, data) if data and data.run then data.run() end end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

function M.PSS_BuildImportExportTab(MainFrame, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_OFFSET)
	local f = CreateFrame("Frame", "PSSFrameImportExport", MainFrame, "InsetFrameTemplate")
	f:Hide()
	f:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -84)
	f:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -11, 29)

	local UI = M.UI
	local title, help = UI.CreateSummary(f, "Import / Export", 840)
	help:SetText("Tick what to include, then Export and copy the text (Ctrl+C). To import, paste a string into the box (Ctrl+V) and choose Merge or Replace.")

	local INCLUDE_W = 250
	local hr = UI.CreateHeaderRow(f, {
		{ key = "include", text = "Include", width = INCLUDE_W, sort = false, minWidth = 200 },
		{ key = "text",    text = "Export / import text", width = 600, sort = false, fill = true, minWidth = 200 },
	}, 1, UI.HEADER_Y, nil, { id = "importExport" })
	f:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then hr:SetAvailableWidth(w - 2) end end)

	local checks = {}
	local y = -UI.LIST_TOP - 2
	local function check(key, label, default, indent)
		local c = UI.LabeledCheck(f, label)
		c:SetPoint("TOPLEFT", 12 + (indent or 0), y)
		c:SetChecked(default)
		checks[key] = c
		y = y - 24
		return c
	end
	check("players", "Player Ignore List", true)
	check("guilds", "Guild Ignore List", true)
	check("members", "Include captured guild members", false, 20)
	check("filters", "Custom chat filters", true)
	check("builtins", "Built-in filter on/off", true)
	check("options", "Options (all characters)", false)
	f.checks = checks

	local function sections()
		local s = {}
		for k, c in pairs(checks) do s[k] = c:GetChecked() == true end
		if not s.guilds then s.members = false end
		return s
	end

	local box = CreateFrame("ScrollFrame", "PSSImportExportText", f, "InputScrollFrameTemplate")
	hr:Track("text", function(x)
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", f, "TOPLEFT", x + 14, -UI.LIST_TOP - 6)
		box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 30)
	end)
	box.EditBox:SetAutoFocus(false)
	box.EditBox:SetMaxLetters(0)
	box.EditBox:SetFontObject("ChatFontSmall")
	box.EditBox:SetWidth(WINDOW_WIDTH - 19 - 262 - 40)
	-- keep the text wrapping to the box when the main window is resized
	box:HookScript("OnSizeChanged", function(self, w)
		if w and w > 40 then self.EditBox:SetWidth(w - 24) end
	end)
	if type(box.CharCount) == "table" and box.CharCount.Hide then box.CharCount:Hide() end
	f.box = box

	local status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hr:Track("text", function(x)
		status:ClearAllPoints()
		status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x + 8, 10)
		status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 10)
	end)
	status:SetJustifyH("LEFT")
	f.status = status
	local function say(text, r, g, b) status:SetText(text); status:SetTextColor(r or 1, g or 1, b or 1) end

	local function button(label, w, anchorTo, onClick)
		-- the bottom bar under the panel, like every other tab
		local b = UI.BarButton(f, label, anchorTo, math.max(w, UI.BAR_W))
		b:SetScript("OnClick", onClick)
		return b
	end

	local function readImport()
		local data, err = M.PSS_DecodeExport(box.EditBox:GetText())
		if not data then say("Import failed: " .. tostring(err), 1, 0.4, 0.4) end
		return data
	end

	f.replaceButton = button("Import: Replace", 120, nil, function()
		local data = readImport()
		if not data then return end
		local s = sections()
		StaticPopup_Show("PSS_IMPORT_REPLACE", M.PSS_DescribeImport(data), nil, { run = function()
			say("Replaced: " .. M.PSS_ApplyImport(data, "replace", s), 0.4, 1, 0.4)
		end })
	end)
	f.mergeButton = button("Import: Merge", 120, f.replaceButton, function()
		local data = readImport()
		if not data then return end
		say("Merged: " .. M.PSS_ApplyImport(data, "merge", sections()), 0.4, 1, 0.4)
	end)
	f.clearButton = button("Clear", 70, f.mergeButton, function()
		box.EditBox:SetText(""); say("")
	end)
	f.exportButton = button("Export", 90, f.clearButton, function()
		local text = M.PSS_EncodeExport(M.PSS_BuildExport(sections()))
		box.EditBox:SetText(text)
		box.EditBox:SetFocus()
		box.EditBox:HighlightText()
		say(("Export ready (%d characters) - press Ctrl+C to copy."):format(#text), 0.4, 1, 0.4)
	end)

	box.EditBox:SetScript("OnTextChanged", function(self, userInput)
		if not userInput then return end
		local data = M.PSS_DecodeExport(self:GetText())
		if data then say("Pasted: " .. M.PSS_DescribeImport(data) .. ". Tick the sections to apply, then Merge or Replace.", 1, 0.82, 0) end
	end)
	return f
end
