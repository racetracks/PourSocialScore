-------------------------------------------------------------------------------
--  EUI_Players.lua -- the Player Ignore List tab of the window: the list
--  (search, sortable columns) and a detail pane for the selected entry with
--  three pages (EUI_Detail.lua): Summary (counts), Event History
--  and View/Edit Rule (note, expiry, W I G P C, overrides, actions).
--  Everything is read and changed through the core (PSS_PlayerQuery.lua and
--  the player setters); the core says when the list changed
--  (PLAYERS_CHANGED, PLAYER_BLOCKED) and the tab redraws if it shows.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI
local L = PourSocialScore_NS.L
local History = M.PSS_History

local DETAIL_W = 380
local TOP_H = 32
local LINE_H = 16

-- key/asc: the sort; find: the search text; index: list positions in the
-- order shown; sel: the selected entry as stored; row: the one table every
-- drawn row is read into (M.PSS_PlayerRow)
local P = { key = "name", asc = true, find = "", index = {}, count = 0, dirty = true, row = {} }
local page, list, pane

local OVERRIDE_SHORT = {
    ignoreResponse = "Ignore response",
    showDeclines   = "Show declines",
    declineDuel    = "Decline duels",
    declineTrade   = "Decline trades",
}

local function TypeText(r)
    if r.kind == "npc" then return "|cffffff99NPC|r" end
    if r.kind == "server" then return "|cffff66ccServer|r" end
    if r.faction == "Alliance" then return "|cff335effAlliance|r" end
    if r.faction == "Horde" then return "|cffe60000Horde|r" end
    return "Unknown"
end

local function ExpireText(r)
    if r.expire == 0 then return "|cff808080" .. L["EXP_NVR"] .. "|r" end
    if r.left <= 0 then return "|cffff6666" .. L["EXP_TDY"] .. "|r" end
    return r.left .. "d"
end

local function ClassColor(p)
    local c = p and p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Total(p)
    return p and M.PSS_GetPlayerBlockCounts(p).total or 0
end

local function Count(n, cat)
    return "|c" .. History.CAT_COLOR[cat] .. n .. "|r"
end

-------------------------------------------------------------------------------
--  List
-------------------------------------------------------------------------------
local function Resort()
    local _, n = M.PSS_SortPlayers(P.key, P.asc, P.find, P.index)
    P.count, P.dirty = n, false
    list:SetSort(P.key, P.asc)
    list:SetCount(n)
    local all = M.PSS_PlayerCount()
    page.count:SetText(P.find ~= "" and ("%d of %d"):format(n, all) or ("%d on the list"):format(all))
    list:SetEmptyText(all == 0 and "The list is empty. Add a player above." or "Nothing matches the search.")
end

local function DrawRow(row, i)
    local r = M.PSS_PlayerRow(P.index[i], P.row)
    local cells = row.cells
    if not r then
        for _, fs in pairs(cells) do fs:SetText("") end
        row.sel:Hide()
        return
    end
    cells.name:SetText(r.name)
    cells.name:SetTextColor(ClassColor(r.record))
    cells.server:SetText(r.server)
    cells.type:SetText(TypeText(r))
    cells.listed:SetText(r.listed .. "d")
    cells.expire:SetText(ExpireText(r))
    cells["metric:total"]:SetText(r.record and Total(r.record) or "")
    row.sel:SetShown(r.entry == P.sel)
end

local function RowTip(row, i)
    local r = M.PSS_PlayerRow(P.index[i], P.row)
    if not r then return end
    local text = r.entry
    if r.note and r.note ~= "" then text = text .. "\n\n" .. r.note end
    ns.Tip(row, text .. "\n\nClick for the details.")
end

local function SetSort(key)
    if P.key == key then
        P.asc = not P.asc
    else
        P.key, P.asc = key, true
    end
    Resort()
end

-------------------------------------------------------------------------------
--  Detail pane
-------------------------------------------------------------------------------
local function Line(parent, y)
    local fs = ns.NewText(parent, 12)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    return fs
end

local function Label(parent, text, anchor)
    local fs = ns.NewText(parent, 12)
    fs:SetPoint("LEFT", anchor, "LEFT", 0, 0)
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 0.7)
    return fs
end

local function Pos()
    return M.PSS_PlayerPosition(P.sel)
end

-- The note and expiry boxes save to the entry that was shown when typing
-- started, even when the click that ends it selects another entry.
local function EditStart()
    pane.editEntry = P.sel
end

local function EditPos()
    return M.PSS_PlayerPosition(pane.editEntry or P.sel)
end

local function ConfirmRemove()
    local entry = P.sel
    if not entry then return end
    local _, kind = M.PSS_PlayerEntry(Pos())
    EUI:ShowConfirmPopup({
        title       = "Pour Social Score",
        message     = ("Remove %s from the Player Ignore List?"):format(entry)
            .. (kind == "player" and "\n\nTheir note, settings and block history are deleted." or ""),
        confirmText = "Remove",
        cancelText  = "Cancel",
        onConfirm   = function()
            local pos = M.PSS_PlayerPosition(entry)
            if pos > 0 then M.PSS_RemovePlayerAt(pos) end
        end,
    })
end

-- The Block History view (EUI_HistoryView.lua) of one player, or of every
-- listed player.
local allPlayers
local function AllPlayers()
    if allPlayers then return allPlayers end
    allPlayers = {
        kind = "player", id = false, allText = "All Players",
        label = function() return "All Players" end,
        read = function()
            local keys = {}
            for i = 1, M.PSS_PlayerCount() do
                local e, kind = M.PSS_PlayerEntry(i)
                local k = kind == "player" and M.PSS_PlayerHistoryKey(e)
                if k then keys[k] = true end
            end
            return History.Collect(function(h) return keys[h.o] == true end)
        end,
        reset = function()
            for i = 1, M.PSS_PlayerCount() do
                local e, kind = M.PSS_PlayerEntry(i)
                if kind == "player" and M.PSS_GetPlayerRecord(e) then M.PSS_ResetPlayerBlockHistory(e) end
            end
            if M.PSS_Stats then M.PSS_Stats.Reset("player") end
        end,
    }
    return allPlayers
end

function ns.PlayerHistorySpec(entry)
    return {
        kind = "player", id = entry, allText = "All Players", all = AllPlayers,
        label = function(e) return M.PSS_PlayerPosition(e) > 0 and e or nil end,
        read = M.PSS_GetPlayerBlockHistory,
        reset = M.PSS_ResetPlayerBlockHistory,
        owner = M.PSS_PlayerHistoryKey, counts = M.PSS_GetPlayerBlockCounts,
    }
end

local function BuildPane(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -TOP_H - 4)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
    pane:SetWidth(DETAIL_W)
    ns.Panel(pane)
    pane.row = {}
    pane.player = {}            -- shown for players only

    pane.none = ns.NewText(pane, 12)
    pane.none:SetPoint("CENTER")
    pane.none:SetTextColor(1, 1, 1, 0.5)
    pane.none:SetText("Select an entry to see its details.")
    pane.none:Hide()
    -- nothing selected: the whole list's totals (a click on the selected
    -- entry deselects it)
    pane.totals = ns.NewTotals(pane, page, "players", "Player Ignore List", "Select an entry to see its details.", AllPlayers)

    local body = CreateFrame("Frame", nil, pane)
    body:SetAllPoints()
    pane.body = body

    pane.heading = ns.NewHeading(body, "")
    pane.heading:SetPoint("TOPLEFT", body, "TOPLEFT", 10, -8)
    pane.heading:SetPoint("RIGHT", body, "RIGHT", -10, 0)
    local dp = ns.NewDetailPages(body, -28, "players")
    pane.pages = dp

    -- Summary: the counts
    pane.counts = Line(dp.summary, -6)
    ns.Font(pane.counts, 11)
    pane.player[#pane.player + 1] = pane.counts
    pane.summary = ns.NewSummary(dp.summary, page, -30)

    -- View/Edit Rule
    local rule = dp.rule
    local y = -2
    pane.typeLine = Line(rule, y); y = y - LINE_H
    pane.addedLine = Line(rule, y); y = y - LINE_H
    pane.guildLine = Line(rule, y); y = y - LINE_H
    pane.inviteLine = Line(rule, y); y = y - LINE_H - 6
    pane.player[#pane.player + 1] = pane.guildLine
    pane.player[#pane.player + 1] = pane.inviteLine

    -- expiry: days after the date added, 0 = never
    local expRow = CreateFrame("Frame", nil, rule)
    expRow:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
    expRow:SetSize(DETAIL_W - 20, 22)
    Label(expRow, "Expires after", expRow)
    local exp = ns.NewNumberBox(expRow, 44)
    exp:SetPoint("LEFT", expRow, "LEFT", 90, 0)
    exp:SetMaxLetters(4)
    pane.expireNote = ns.NewText(expRow, 12)
    pane.expireNote:SetPoint("LEFT", exp, "RIGHT", 8, 0)
    ns.TipOn(exp, exp, "Days after the date added before this entry is removed by itself. 0 = never.")
    ns.OnCommit(exp, function(text)
        local pos, days = EditPos(), tonumber(text)
        if pos > 0 and days and days ~= pane.row.expire then
            M.PSS_SetExpiry(pos, days)
            M.PSS_PlayersChanged()
        end
    end, function() ns.ShowPlayerDetail() end)
    exp:SetScript("OnEditFocusGained", EditStart)
    pane.expireBox = exp
    y = y - 26

    local noteRow = CreateFrame("Frame", nil, rule)
    noteRow:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
    noteRow:SetSize(DETAIL_W - 20, 22)
    Label(noteRow, "Note", noteRow)
    local note = CreateFrame("EditBox", nil, noteRow, "InputBoxTemplate")
    note:SetPoint("LEFT", noteRow, "LEFT", 94, 0)
    note:SetPoint("RIGHT", noteRow, "RIGHT", -4, 0)
    note:SetHeight(20)
    note:SetAutoFocus(false)
    note:SetMaxLetters(128)
    ns.EditBox(note)
    ns.OnCommit(note, function(text)
        local pos = EditPos()
        text = M.trim(text) or ""
        if pos > 0 and text ~= (pane.row.note or "") then
            M.PSS_SetNote(pos, text)
            M.PSS_PlayersChanged()
        end
    end, function() ns.ShowPlayerDetail() end)
    note:SetScript("OnEditFocusGained", EditStart)
    pane.noteBox = note
    y = y - 28

    -- W I G P C (ticked = allowed; the record stores "blocked")
    local exRow = CreateFrame("Frame", nil, rule)
    exRow:SetPoint("TOPLEFT", rule, "TOPLEFT", 10, y)
    exRow:SetSize(DETAIL_W - 20, 24)
    Label(exRow, "Allowed", exRow)
    pane.excl = {}
    local prev
    for _, e in ipairs(M.EXCL) do
        local c = ns.NewCheck(exRow)
        if prev then c:SetPoint("LEFT", prev, "RIGHT", 22, 0) else c:SetPoint("LEFT", exRow, "LEFT", 90, 0) end
        local letter = ns.NewText(exRow, 12)
        letter:SetPoint("LEFT", c, "RIGHT", 0, 0)
        letter:SetText(e.letter)
        ns.TipOn(c, c, e.label .. "\n\nTicked = allowed from this player, unticked = blocked.")
        c:SetScript("OnClick", function(self)
            if P.sel then
                M.PSS_SetPlayerSetting(P.sel, e.field, not self:GetChecked())
                M.PSS_PlayersChanged()
            end
        end)
        pane.excl[e.cat] = c
        prev = letter
    end
    pane.player[#pane.player + 1] = exRow
    y = y - 28

    -- overrides of the Options for this player: Default > On > Off
    pane.overrides = {}
    local n = 0
    for _, o in ipairs(M.PSS_OPTIONS) do
        if o.target and o.kind == "bool" then
            n = n + 1
            local b = ns.NewButton(rule, "", (DETAIL_W - 26) / 2, function(self)
                local p = pane.record
                if not p then return end
                local cur = p.opts and p.opts[self.opt.key]
                local nextV
                if cur == nil then nextV = true elseif cur == true then nextV = false end
                M.PSS_SetOpt(self.opt.key, "person", nextV, p)
                ns.ShowPlayerDetail()
            end)
            b.opt = o
            local col, r = (n - 1) % 2, math.floor((n - 1) / 2)
            b:SetPoint("TOPLEFT", rule, "TOPLEFT", 10 + col * ((DETAIL_W - 26) / 2 + 6), y - r * 24)
            ns.TipOn(b, b, o.label .. "\n\nClick to change: Default (the Options tab) > On > Off.")
            pane.overrides[#pane.overrides + 1] = b
            pane.player[#pane.player + 1] = b
        end
    end

    -- the rule's actions: Remove, Add Guild
    local remove = ns.NewButton(rule, "Remove", 100, ConfirmRemove)
    pane.removeButton = remove
    remove:SetPoint("BOTTOMLEFT", rule, "BOTTOMLEFT", 10, 4)
    local addGuild = ns.NewButton(rule, "Add Guild", 100, function(self)
        if self.guild then
            M.PSS_AddGuild(self.guild)
            M.ShowMsg(("Added <%s> to the Guild Ignore List."):format(self.guild))
            ns.ShowPlayerDetail()
        end
    end)
    addGuild:SetPoint("LEFT", remove, "RIGHT", 6, 0)
    ns.TipOn(addGuild, addGuild, "Adds this player's current guild to the Guild Ignore List.")
    pane.addGuild = addGuild

    -- Event History: the block history, the whole page, Reset under it
    pane.hist = ns.NewHistory(dp.history, -2, {
        empty = "Nothing blocked from this player yet.",
        open = function(entry) ns.OpenHistoryView(page, ns.PlayerHistorySpec(entry)) end,
    })
    pane.player[#pane.player + 1] = pane.hist.frame
    local reset = ns.NewButton(dp.history, L["HISTORY_RESET"] or "Reset Block History", 130, function()
        if P.sel then M.PSS_ResetPlayerBlockHistory(P.sel) end
    end)
    reset:SetPoint("BOTTOMLEFT", dp.history, "BOTTOMLEFT", 10, 4)
    pane.player[#pane.player + 1] = reset
end

-- Redraw the pane for the selected entry (none: a hint).
function ns.ShowPlayerDetail(newEntry)
    if not pane then return end
    local pos = Pos()
    local r = pos > 0 and M.PSS_PlayerRow(pos, pane.row)
    pane.body:SetShown(r and true or false)
    if r then pane.totals:Hide() else pane.totals:Show() end
    if not r then
        P.sel, pane.record = nil, nil
        pane.hist:Clear()
        return
    end
    local p = r.record or nil
    pane.record = p
    local isPlayer = p ~= nil
    for _, f in ipairs(pane.player) do f:SetShown(isPlayer) end
    -- NPCs and servers have no counts or history: View/Edit Rule only
    pane.pages:Limit(not isPlayer and { rule = true } or nil)

    local cr, cg, cb = ClassColor(p)
    local title = (r.kind == "npc" and "NPC: ") or (r.kind == "server" and "Server: ") or ""
    pane.heading:SetText(title .. ("|cff%02x%02x%02x"):format(cr * 255, cg * 255, cb * 255)
        .. (r.kind == "server" and r.server or r.name .. (r.server ~= "All" and ("-" .. r.server) or "")) .. "|r")

    local typeText = TypeText(r)
    if p and (p.className or p.class) then typeText = typeText .. "  " .. (p.className or p.class) end
    pane.typeLine:SetText(typeText)
    local ago = r.listed or 0
    pane.addedLine:SetText(r.added and ("Added %s  |cffaaaaaa(%d %s ago)|r"):format(r.added, ago, M.dayString(ago))
        or "Added |cff808080Unknown|r")

    if not pane.expireBox:HasFocus() then pane.expireBox:SetText(tostring(tonumber(r.expire) or 0)) end
    if r.expire == 0 then pane.expireNote:SetText("days  |cff808080(never)|r")
    elseif r.left <= 0 then pane.expireNote:SetText("days  |cffff6666(today)|r")
    else pane.expireNote:SetText(("days  |cffaaaaaa(%d left)|r"):format(r.left)) end
    if not pane.noteBox:HasFocus() then pane.noteBox:SetText(r.note or "") end

    pane.addGuild:Hide()
    if not p then
        pane.hist:Clear()
        return
    end
    local now = p.currentGuild or ""
    local was = p.guildWhenBlocked or ""
    pane.guildLine:SetText("Guild " .. (now ~= "" and ("<" .. now .. ">") or "|cff808080none seen|r")
        .. ((was ~= "" and was ~= now) and ("  |cffaaaaaa(when added <" .. was .. ">)|r") or ""))
    pane.inviteLine:SetText("Last blocked invite " .. ((p.lastBlockedInvite or "") ~= "" and p.lastBlockedInvite or "|cff808080never|r"))
    if now ~= "" then
        local listed = M.PSS_IsGuildListed(now)
        pane.addGuild.guild = now
        pane.addGuild:SetText(listed and "Guild listed" or "Add Guild")
        pane.addGuild:SetEnabled(not listed)
        pane.addGuild:Show()
    end

    for _, e in ipairs(M.EXCL) do pane.excl[e.cat]:SetChecked(p[e.field] == false) end
    for _, b in ipairs(pane.overrides) do
        local cur = p.opts and p.opts[b.opt.key]
        local state = cur == nil and "|cffaaaaaaDefault|r" or (cur and "|cff00ff00On|r" or "|cffff5555Off|r")
        b:SetText((OVERRIDE_SHORT[b.opt.key] or b.opt.key) .. ": " .. state)
    end

    local c = M.PSS_GetPlayerBlockCounts(p)
    pane.counts:SetText(("Blocked %d:  Whispers %s  Invites %s  Party %s  Chat %s"):format(c.total or 0,
        Count(c.whisper or 0, "whisper"), Count((c.partyInvite or 0) + (c.guildInvite or 0), "partyInvite"),
        Count(c.partyRaid or 0, "partyRaid"), Count(c.world or 0, "world")))

    -- read again only when the entry or its count changed; the block
    -- history (PourSocialScore_Logging) loads only when asked for
    pane.hist:Set(r.entry, c.total or 0, M.PSS_GetPlayerBlockHistory, newEntry)
    pane.summary:Set(M.PSS_PlayerHistoryKey(r.entry), c.total or 0, r.name or r.entry, ns.PlayerHistorySpec, r.entry)
end

-------------------------------------------------------------------------------
--  Tab
-------------------------------------------------------------------------------
local function Refresh()
    if P.dirty then Resort() else list:Redraw() end
    ns.ShowPlayerDetail()
end

local function SelectEntry(entry)
    if pane then
        pane.noteBox:ClearFocus()       -- saves what was typed first
        pane.expireBox:ClearFocus()
        pane.editEntry = nil
    end
    P.sel = entry
    list:Redraw()
    ns.ShowPlayerDetail(true)
end

function ns.BuildPlayersTab(pg)
    page = pg

    -- top: search on the left, Add Player on the right
    local search = CreateFrame("EditBox", nil, pg, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", pg, "TOPLEFT", 16, -6)
    search:SetSize(200, 20)
    search:SetAutoFocus(false)
    ns.EditBox(search)
    local hint = ns.NewText(search, 12)
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetTextColor(1, 1, 1, 0.4)
    hint:SetText("Search name, server or note")
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        if text ~= P.find then
            P.find = text
            Resort()
            list:Top()
        end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    pg.search = search

    pg.count = ns.NewText(pg, 12)
    pg.count:SetPoint("LEFT", search, "RIGHT", 12, 0)
    pg.count:SetTextColor(1, 1, 1, 0.7)

    local add = CreateFrame("EditBox", nil, pg, "InputBoxTemplate")
    add:SetSize(170, 20)
    add:SetAutoFocus(false)
    ns.EditBox(add)
    local addHint = ns.NewText(add, 12)
    addHint:SetPoint("LEFT", add, "LEFT", 2, 0)
    addHint:SetTextColor(1, 1, 1, 0.4)
    addHint:SetText("Name-Realm")
    local function AddPlayer()
        local text = M.trim(add:GetText() or "") or ""
        add:SetText("")
        add:ClearFocus()
        if text == "" then return end
        M.PSS_AddPlayer(text)
        local pos = M.PSS_PlayerPosition(M.Proper(M.addServer(text)))
        if pos > 0 then SelectEntry((M.PSS_PlayerEntry(pos))) end
    end
    local addButton = ns.NewButton(pg, "Add Player", 100, AddPlayer)
    addButton:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -8, -5)
    add:SetPoint("RIGHT", addButton, "LEFT", -8, 0)
    add:SetScript("OnTextChanged", function(self) addHint:SetShown((self:GetText() or "") == "") end)
    add:SetScript("OnEnterPressed", AddPlayer)
    add:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ns.TipOn(addButton, addButton, "Adds the player typed in the box (Name or Name-Realm). Everything from them is blocked until you tick what to allow.")
    pg.add = add

    BuildPane(pg)

    local lf = CreateFrame("Frame", nil, pg)
    lf:SetPoint("TOPLEFT", pg, "TOPLEFT", 8, -TOP_H - 4)
    lf:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", -8, 0)
    list = ns.NewRows(lf, {
        rowH = 20, height = 300,
        cols = {
            { key = "name", text = "Name" },
            { key = "server", text = "Server", width = 112 },
            { key = "type", text = "Type", width = 72 },
            { key = "listed", text = "Listed", width = 54, justify = "RIGHT",
              tip = "Days since the entry was added." },
            { key = "expire", text = "Expires", width = 62, justify = "RIGHT",
              tip = "Days left before the entry is removed by itself." },
            { key = "metric:total", text = "Blocked", width = 62, justify = "RIGHT",
              tip = "Messages and invites blocked from this player." },
        },
        sort = SetSort,
        draw = DrawRow,
        enter = RowTip,
        click = function(row, i)
            local pos = P.index[i]
            local entry = pos and M.PSS_PlayerEntry(pos)
            if entry then SelectEntry(entry ~= P.sel and entry or nil) end
        end,
        emptyClick = function() if P.sel then SelectEntry(nil) end end,
    })
    -- a tab click (EUI_Window.lua): nothing selected
    pg.navReset = function() if P.sel then SelectEntry(nil) end end
    pg.list, pg.pane = list, pane
    P.dirty = true
    return Refresh
end

-- The core says the list changed: redraw now if the tab shows, else when it
-- next shows. Blocked lines only change counts: at most 4 redraws a second.
M.Events.Register("PLAYERS_CHANGED", function()
    P.dirty = true
    if page and page:IsVisible() then Refresh() end
end)

local pending
M.Events.Register("PLAYER_BLOCKED", function()
    if pending or not (page and page:IsVisible()) then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = nil
        if page and page:IsVisible() then
            list:Redraw()
            ns.ShowPlayerDetail()
        end
    end)
end)
