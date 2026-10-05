-------------------------------------------------------------------------------
--  EUI_Guilds.lua -- the Guild Ignore List tab of the window: the guild list
--  (managed groups, the Guild Exclusion List, the other guilds), a guild's
--  members in its place, a detail pane for what is selected (W I G P C,
--  Scan / Custom Scan, overrides, counts, block history), Scan All, Add
--  Guild, Guild Search and the Guild Exclusion List entry row.
--  Everything is read through the core (PSS_GuildQuery.lua) and changed
--  through the guild setters; the core says when guilds changed
--  (GUILDS_CHANGED, GUILD_SCAN_DONE, GUILD_REMOVED) and the tab redraws if
--  it shows. Scan buttons are disabled while /who cools down
--  (WHOIS_COOLDOWN).
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI
local L = PourSocialScore_NS.L
local History = M.PSS_History

local DETAIL_W = 380
local TOP_H = 58
local LINE_H = 16
local EXCL_KEY = M.PSS_GUILD_EXCL_OPEN
local DOUBLE_CLICK = 0.35

-- key/asc/find: the guild list sort and search; rows: the table the core
-- fills with the list (M.PSS_GuildRows); selKind/sel: what is selected
-- ("guild" key, "group" key, "exclHeader", "excl" name). The members view:
-- mguild (rule key), mkey/masc/mfind, members (M.PSS_GuildMembers), msel
-- (the member record).
local G = {
    key = "guild", asc = true, find = "", rows = {}, n = 0, dirty = true,
    view = "guilds",
    mkey = "name", masc = true, mfind = "", members = {}, mn = 0, mtotal = 0, mdirty = true,
}
local page, list, mlist, lf, mview, pane, picker
local scanButtons = {}

local OVERRIDE_SHORT = {
    ignoreResponse = "Ignore response",
    showDeclines   = "Show declines",
    declineDuel    = "Decline duels",
    declineTrade   = "Decline trades",
}

local function Say(msg) M.PSS_Say(msg) end

local function ClassColor(m)
    local c = m and m.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[m.class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Count(n, cat)
    return "|c" .. History.CAT_COLOR[cat] .. n .. "|r"
end

local function CountsText(c)
    return ("Blocked %d:  Whispers %s  Invites %s  Party %s  Chat %s"):format(c.total or 0,
        Count(c.whisper or 0, "whisper"), Count((c.partyInvite or 0) + (c.guildInvite or 0), "partyInvite"),
        Count(c.partyRaid or 0, "partyRaid"), Count(c.world or 0, "world"))
end

local function BoxText(box)
    local text = M.trim(box:GetText() or "") or ""
    if text == "" then return nil end
    return text
end

-- Scan buttons follow the /who cooldown.
local function ScanButton(b)
    scanButtons[#scanButtons + 1] = b
    b:SetEnabled(not M.PSS_ScanCooldownActive())
    return b
end

-- The status of a guild's sweep (g) or of Scan All (nil), for the tooltip.
local function ScanTipText(g)
    local t = {}
    local function add(s) t[#t + 1] = s end
    if g then
        add("Scan <" .. tostring(g.name) .. ">")
        add("|cffccccccOne /who per click: the whole guild first. An answer of 50 (the /who cap) is split into narrower searches until each is under the cap.|r")
        local sw = M.PSS_GuildSweep(M.PSS_NormalizeGuild(g.name))
        if not sw then
            add("Not swept yet. Next: " .. M.PSS_HarvestFilter(g.name, {}))
        else
            add(("Searches %d sent, %d queued. Players found %d (%d new)."):format(sw.sent, #sw.queue, sw.seen, sw.added))
            if sw.done then
                add("|cff00ff00Sweep complete: click to start it again.|r")
            elseif sw.queue[1] then
                add("Next: " .. M.PSS_HarvestFilter(g.name, sw.queue[1]))
            end
        end
    else
        add("Scan All")
        add("|cffccccccOne /who per click across every guild, A-Z: each guild is swept to the end before the next.|r")
        local nextG, done, n = M.PSS_ScanAllNext()
        add(("Guilds swept %d / %d."):format(done, n))
        if nextG then add("Now: " .. tostring(nextG.name)) end
    end
    if M.PSS_WhoPending() then
        add("|cffffff00Waiting for the /who answer.|r")
    elseif M.PSS_ScanCooldownActive() then
        add("|cffff8000/who is cooling down.|r")
    else
        add("|cff00ff00Ready: click for the next search.|r")
    end
    if g then add("|cff999999Shift-click: start this guild's sweep over.|r") end
    add("|cff999999Key binding for Scan All: Key Bindings > AddOns > Pour Social Score.|r")
    return table.concat(t, "\n")
end

local function IsSel(item)
    if item.header then return G.selKind == "group" and G.sel == item.groupKey end
    if item.exclHeader then return G.selKind == "exclHeader" end
    if item.exclItem then return G.selKind == "excl" and G.sel == item.name end
    return G.selKind == "guild" and G.sel == item.key
end

local ShowDetail, OpenMembers

-------------------------------------------------------------------------------
--  Guild list
-------------------------------------------------------------------------------
local function UpdateCount()
    if G.view == "members" then
        page.count:SetText(G.mfind ~= "" and ("%d of %d members"):format(G.mn, G.mtotal)
            or ("%d member%s"):format(G.mtotal, G.mtotal == 1 and "" or "s"))
        return
    end
    local all = M.PSS_GuildCount()
    page.count:SetText(G.find ~= "" and ("%d of %d"):format(G.n, all) or ("%d guild rule%s"):format(all, all == 1 and "" or "s"))
end

local function Resort()
    local _, n = M.PSS_GuildRows(G.key, G.asc, G.find, G.rows)
    G.n, G.dirty = n, false
    list:SetSort(G.key, G.asc)
    list:SetCount(n)
    list:SetEmptyText("Nothing matches the search.")
    if page then UpdateCount() end
end

local function DrawRow(row, i)
    local item = G.rows[i]
    local c = row.cells
    row:SetAlpha(1)
    if not item then
        for _, fs in pairs(c) do fs:SetText("") end
        row.sel:Hide()
        return
    end
    if item.header then
        c.guild:SetText((item.open and "[-] " or "[+] ") .. "|cffffd100" .. item.name .. "|r"
            .. ("  |cffaaaaaa(%d guilds)|r"):format(item.guilds))
        c.members:SetText(item.members)
        c["metric:total"]:SetText(item.bc.total or 0)
        c.scan:SetText(M.PSS_ManagedGroupActive(item.groupKey) and "|cff00ff00Rule ON|r" or "|cffff5555Rule OFF|r")
    elseif item.exclHeader then
        c.guild:SetText((item.open and "[-] " or "[+] ") .. "|cff4dccffGuild Exclusion List|r"
            .. ("  |cffaaaaaa(%d guilds)|r"):format(item.count))
        c.members:SetText("")
        c["metric:total"]:SetText("")
        c.scan:SetText("|cff4dccffNever|r")
    elseif item.exclItem then
        c.guild:SetText("      " .. item.name)
        c.members:SetText("")
        c["metric:total"]:SetText("")
        c.scan:SetText("|cff4dccffExcluded|r")
    else
        local g = item.g
        c.guild:SetText(((item.inGroup and G.find == "") and "      " or "") .. tostring(g.name))
        c.members:SetText(g.memberCount or 0)
        c["metric:total"]:SetText(item.bc.total or 0)
        c.scan:SetText(M.PSS_GuildSweepLabel(item.key))
        -- a group whose rule is off: dimmed (nothing in it is blocked)
        if item.inGroup and not item.groupOn then row:SetAlpha(0.55) end
    end
    row.sel:SetShown(IsSel(item))
end

local function RowTip(row, i)
    local item = G.rows[i]
    if not item then return end
    if item.header then
        local grp = M.PSS_ManagedGroups()[item.groupKey] or {}
        ns.Tip(row, (item.name or "") .. "\n\nDefault guild list. Rule on the Chat Filters tab: "
            .. tostring(grp.rule) .. " (" .. tostring(grp.filter) .. ").\n\nClick to expand or collapse.")
    elseif item.exclHeader then
        ns.Tip(row, "Guild Exclusion List\n\nGuilds that no guild rule ever blocks, captures or scans in.\n\nClick to expand or collapse.")
    elseif item.exclItem then
        ns.Tip(row, item.name .. "\n\nExcluded: never blocked by a guild rule.")
    else
        ns.Tip(row, tostring(item.g.name) .. "\n\nClick for the details, double-click for the members.")
    end
end

local function SetSort(key)
    if G.key == key then
        G.asc = not G.asc
    else
        G.key, G.asc = key, true
    end
    Resort()
end

local function Select(kind, value)
    if pane then
        pane.fieldsBox:ClearFocus()     -- saves what was typed first
        pane.noteBox:ClearFocus()
    end
    G.selKind, G.sel = kind, value
    list:Redraw()
    ShowDetail(true)
end

local lastClick, lastKey = 0, nil
local function ClickRow(row, i)
    local item = G.rows[i]
    if not item then return end
    if item.header then
        M.PSS_SetGuildGroupOpen(item.groupKey, not item.open)
        G.selKind, G.sel = "group", item.groupKey
        Resort()
        ShowDetail(true)
    elseif item.exclHeader then
        M.PSS_SetGuildGroupOpen(EXCL_KEY, not item.open)
        G.selKind, G.sel = "exclHeader", true
        Resort()
        ShowDetail(true)
    elseif item.exclItem then
        Select("excl", item.name)
    else
        local now = GetTime()
        if lastKey == item.key and now - lastClick < DOUBLE_CLICK then
            lastKey = nil
            Select("guild", item.key)
            OpenMembers(item.key)
            return
        end
        lastClick, lastKey = now, item.key
        Select("guild", item.key)
    end
end

-------------------------------------------------------------------------------
--  Members view (in place of the guild list)
-------------------------------------------------------------------------------
local function MResort()
    local _, n, total = M.PSS_GuildMembers(G.mguild, G.mkey, G.masc, G.mfind, G.members)
    if not n then
        -- the rule is gone
        G.mguild, G.msel = nil, nil
        n, total = 0, 0
    end
    G.mn, G.mtotal, G.mdirty = n, total, false
    if G.msel then
        local found = false
        for i = 1, n do if G.members[i] == G.msel then found = true break end end
        if not found and not G.members.stored[G.msel] then G.msel = nil end
    end
    mlist:SetSort(G.mkey, G.masc)
    mlist:SetCount(n)
    mlist:SetEmptyText(G.mfind ~= "" and "Nothing matches the search." or "No members yet. Scan the guild to find them.")
    local _, g = M.PSS_FindGuildRule(G.mguild)
    mview.heading:SetText("Members of |cffffd100" .. tostring(g and g.name or "?") .. "|r")
    UpdateCount()
end

local function DrawMember(row, i)
    local m = G.members[i]
    local c = row.cells
    if not m then
        for _, fs in pairs(c) do fs:SetText("") end
        row.sel:Hide()
        return
    end
    c.name:SetText(m.name or "")
    c.name:SetTextColor(ClassColor(m))
    c.guild:SetText(m.guild or "")
    c.note:SetText(m.note or "")
    c["metric:total"]:SetText(M.PSS_GetMemberBlockCounts(m).total or 0)
    row.sel:SetShown(m == G.msel)
end

local function MemberTip(row, i)
    local m = G.members[i]
    if not m then return end
    ns.Tip(row, tostring(m.name) .. ((m.guild or "") ~= "" and ("  <" .. m.guild .. ">") or "")
        .. ((m.note or "") ~= "" and ("\n\n" .. m.note) or "") .. "\n\nClick for the details.")
end

local function SetMemberSort(key)
    if G.mkey == key then
        G.masc = not G.masc
    else
        G.mkey, G.masc = key, true
    end
    MResort()
end

local function SelectMember(m)
    if pane then pane.noteBox:ClearFocus() end
    G.msel = m
    mlist:Redraw()
    ShowDetail(true)
end

local function ShowView(view)
    G.view = view
    page.search:SetText("")
    page.searchHint:SetText(view == "members" and "Search name, guild or note" or "Search guild name")
    lf:SetShown(view == "guilds")
    mview:SetShown(view == "members")
end

function OpenMembers(key)
    if not key then return end
    G.mguild, G.msel, G.mfind = key, nil, ""
    ShowView("members")
    MResort()
    mlist:Top()
    ShowDetail(true)
    ns.NavRecord()
end

local function CloseMembers()
    if pane then pane.noteBox:ClearFocus() end
    G.msel = nil
    ShowView("guilds")
    G.find = ""
    Resort()
    ShowDetail(true)
    ns.NavRecord()
end

-------------------------------------------------------------------------------
--  Detail pane
-------------------------------------------------------------------------------
local function Line(parent, y)
    local fs = ns.NewText(parent, 12)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Label(parent, text)
    local fs = ns.NewText(parent, 12)
    fs:SetPoint("LEFT", parent, "LEFT", 0, 0)
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 0.7)
    return fs
end

local function Strip(parent, y, h)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    f:SetSize(DETAIL_W - 20, h or 22)
    return f
end

-- W I G P C tickboxes (ticked = allowed). onClick(cat, box, button).
local function ExclBoxes(parent, y, tip, onClick)
    local row = Strip(parent, y, 24)
    Label(row, "Allowed")
    local boxes, prev = {}, nil
    for _, e in ipairs(M.EXCL) do
        local c = ns.NewCheck(row)
        if prev then c:SetPoint("LEFT", prev, "RIGHT", 22, 0) else c:SetPoint("LEFT", row, "LEFT", 90, 0) end
        c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local letter = ns.NewText(row, 12)
        letter:SetPoint("LEFT", c, "RIGHT", 0, 0)
        letter:SetText(e.letter)
        ns.TipOn(c, c, e.label .. "\n\n" .. tip)
        c:SetScript("OnClick", function(self, button) onClick(e.cat, self, button) end)
        boxes[e.cat] = c
        prev = letter
    end
    return boxes, row
end

-- Overrides of the Options for a guild or member record: Default > On > Off.
local function Overrides(parent, y, scope, target)
    local out, n = {}, 0
    for _, o in ipairs(M.PSS_OPTIONS) do
        if o.target and o.kind == "bool" then
            n = n + 1
            local b = ns.NewButton(parent, "", (DETAIL_W - 26) / 2, function(self)
                local t = target()
                if not t then return end
                local cur = t.opts and t.opts[self.opt.key]
                local nextV
                if cur == nil then nextV = true elseif cur == true then nextV = false end
                M.PSS_SetOpt(self.opt.key, scope, nextV, t)
                ShowDetail()
            end)
            b.opt = o
            local col, r = (n - 1) % 2, math.floor((n - 1) / 2)
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", 10 + col * ((DETAIL_W - 26) / 2 + 6), y - r * 24)
            ns.TipOn(b, b, o.label .. "\n\nClick to change: Default (the Options tab) > On > Off.")
            out[#out + 1] = b
        end
    end
    return out, math.ceil(n / 2) * 24 + 4
end

local function PaintOverrides(buttons, t)
    for _, b in ipairs(buttons) do
        local cur = t and t.opts and t.opts[b.opt.key]
        local state = cur == nil and "|cffaaaaaaDefault|r" or (cur and "|cff00ff00On|r" or "|cffff5555Off|r")
        b:SetText((OVERRIDE_SHORT[b.opt.key] or b.opt.key) .. ": " .. state)
    end
end

-- The Block History view (EUI_HistoryView.lua) of a guild, a member (All:
-- their guild) or every guild.
local allGuilds = {
    kind = "guild", id = false, allText = "All Guilds",
    label = function() return "All Guilds" end,
    read = M.PSS_GetGuildBlockHistory,
    reset = function()
        for k in pairs(PourSocialScoreDB.guildData or {}) do M.PSS_ResetGuildBlockHistory(k) end
        if M.PSS_Stats then M.PSS_Stats.Reset("guild") end
    end,
}
local function AllGuilds() return allGuilds end

-- the guild rules A-Z, for the view's Guilds drop-down (read when it opens)
local function GuildChoices()
    local out = {}
    for k, g in pairs(PourSocialScoreDB.guildData or {}) do
        if type(g) == "table" then out[#out + 1] = { key = k, name = tostring(g.name or k) } end
    end
    table.sort(out, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    return out
end
allGuilds.pick = GuildChoices
allGuilds.pickSpec = function(key) return ns.GuildHistorySpec(key) end

local function GuildLabel(key)
    local _, g = M.PSS_FindGuildRule(key)
    return g and tostring(g.name or key) or nil
end

function ns.GuildHistorySpec(key)
    return {
        kind = "guild", id = key, allText = "All Guilds", all = AllGuilds,
        label = GuildLabel, pick = GuildChoices, pickSpec = ns.GuildHistorySpec,
        read = M.PSS_GetGuildBlockHistory,
        reset = M.PSS_ResetGuildBlockHistory,
        owner = History.GuildKey, counts = M.PSS_GetGuildBlockCounts,
    }
end

function ns.MemberHistorySpec(m, gkey)
    return {
        kind = "member", id = m, allText = "Whole Guild", pick = GuildChoices, pickSpec = ns.GuildHistorySpec,
        all = function() return GuildLabel(gkey) and ns.GuildHistorySpec(gkey) or allGuilds end,
        label = function(rec)
            local _, g = M.PSS_FindGuildRule(gkey)
            if not (g and type(g.members) == "table") then return nil end
            for _, x in pairs(g.members) do
                if x == rec then return tostring(rec.name or "?") end
            end
            return nil
        end,
        read = M.PSS_GetMemberBlockHistory,
        owner = History.MemberKey, counts = M.PSS_GetMemberBlockCounts,
        reset = M.PSS_ResetMemberBlockHistory,
    }
end
local NO_WHERE, MEMBER_WHO = { noWhere = true }, { who = "this member" }
-- the selected member's spec (the guild whose members are shown)
local function MemberSpec(m) return ns.MemberHistorySpec(m, G.mguild) end

local function ConfirmRemoveGuild()
    local key = G.selKind == "guild" and G.sel or (G.view == "members" and G.mguild)
    local _, g = M.PSS_FindGuildRule(key)
    if not g then return end
    EUI:ShowConfirmPopup({
        title       = "Pour Social Score",
        message     = ("Remove <%s> from the Guild Ignore List?\n\nIts members, their notes and block history are deleted."):format(tostring(g.name)),
        confirmText = "Remove",
        cancelText  = "Cancel",
        onConfirm   = function()
            if G.view == "members" then CloseMembers() end
            M.PSS_RemoveGuildNow(key)
        end,
    })
end

local function ConfirmRemoveMember()
    local m, gkey = G.msel, G.mguild
    if not (m and gkey) then return end
    EUI:ShowConfirmPopup({
        title       = "Pour Social Score",
        message     = ("Remove %s from this guild rule?\n\nThey stay on the Player Ignore List if they are on it."):format(tostring(m.name)),
        confirmText = "Remove",
        cancelText  = "Cancel",
        onConfirm   = function()
            M.PSS_RemoveGuildMember(gkey, m.name, gkey, G.members.stored[m] or nil)
            G.msel = nil
            G.mdirty, G.dirty = true, true
            if page:IsVisible() then MResort(); ShowDetail(true) end
        end,
    })
end

local function BuildGuildBody(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetAllPoints()
    b.heading = ns.NewHeading(b, "")
    b.heading:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
    b.heading:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    b.info = Line(b, -28)
    local dp = ns.NewDetailPages(b, -46, "guilds")
    b.pages = dp
    b.counts = Line(dp.summary, -6)
    ns.Font(b.counts, 11)
    b.summary = ns.NewSummary(dp.summary, page, -30)

    -- View/Edit Rule
    local rule = dp.rule
    local y = -2
    b.excl = ExclBoxes(rule, y, "Ticked = allowed from every member of the guild, unticked = blocked. A member's own setting wins.",
        function(cat, box)
            if pane.guildKey then M.PSS_SetGuildBlock(pane.guildKey, cat, not box:GetChecked()) end
        end)
    y = y - 28

    -- Scan (the sweep), Scan Fields, Custom Scan
    local sr = Strip(rule, y, 24)
    local scan = ns.NewButton(sr, "Scan", 100, function()
        local _, g = M.PSS_FindGuildRule(pane.guildKey)
        if not g or M.PSS_ScanBlockedMsg() then return end
        M.PSS_ScanGuild(g.name, "sweep", IsShiftKeyDown())     -- /who first, UI after
    end)
    scan:SetPoint("LEFT", sr, "LEFT", 0, 0)
    scan:SetScript("OnEnter", function(self)
        local _, g = M.PSS_FindGuildRule(pane.guildKey)
        ns.Tip(self, ScanTipText(g))
    end)
    scan:SetScript("OnLeave", ns.HideTip)
    b.scan = ScanButton(scan)
    local fields = CreateFrame("EditBox", nil, sr, "InputBoxTemplate")
    fields:SetPoint("LEFT", scan, "RIGHT", 10, 0)
    fields:SetSize(120, 20)
    fields:SetAutoFocus(false)
    fields:SetMaxLetters(128)
    ns.EditBox(fields)
    -- saves to the guild shown when typing started
    fields:SetScript("OnEditFocusGained", function() pane.fieldsKey = pane.guildKey end)
    ns.OnCommit(fields, function(text)
        local _, g = M.PSS_FindGuildRule(pane.fieldsKey or pane.guildKey)
        if g then M.PSS_SetGuildScanFields(g, M.trim(text) or "") end
    end, function() ShowDetail() end)
    ns.TipOn(fields, fields, "Custom Scan Fields\n\nExtra /who filters sent with the guild name by Custom Scan.\nExamples: 80   70-80   80 c-\"Mage\"   r-\"Orc\"")
    pane.fieldsBox = fields
    local custom = ns.NewButton(sr, "Custom Scan", 96, function()
        local _, g = M.PSS_FindGuildRule(pane.guildKey)
        if not g or M.PSS_ScanBlockedMsg() then return end
        M.PSS_SetGuildScanFields(g, M.trim(fields:GetText() or "") or "")
        M.PSS_ScanGuild(g.name, "custom")      -- /who first, UI after
        fields:ClearFocus()
    end)
    custom:SetPoint("LEFT", fields, "RIGHT", 8, 0)
    ns.TipOn(custom, custom, "Custom Scan: /who for the guild plus its Scan Fields.")
    b.custom = ScanButton(custom)
    y = y - 28

    b.overrides = Overrides(rule, y, "guild", function() local _, g = M.PSS_FindGuildRule(pane.guildKey) return g end)

    local members = ns.NewButton(rule, "Members", 90, function() OpenMembers(pane.guildKey) end)
    members:SetPoint("BOTTOMLEFT", rule, "BOTTOMLEFT", 10, 4)
    ns.TipOn(members, members, "The guild's members, in place of the guild list.")
    b.membersButton = members
    local remove = ns.NewButton(rule, "Remove Guild", 100, ConfirmRemoveGuild)
    remove:SetPoint("LEFT", members, "RIGHT", 6, 0)
    b.removeButton = remove

    -- Event History: the guild's block history, the whole page
    b.hist = ns.NewHistory(dp.history, -2, {
        names = true, empty = "Nothing blocked from this guild yet.",
        open = function(key) ns.OpenHistoryView(page, ns.GuildHistorySpec(key)) end,
    })
    local reset = ns.NewButton(dp.history, L["HISTORY_RESET"] or "Reset Block History", 130, function()
        if pane.guildKey then M.PSS_ResetGuildBlockHistory(pane.guildKey) end
    end)
    reset:SetPoint("BOTTOMLEFT", dp.history, "BOTTOMLEFT", 10, 4)
    return b
end

local function BuildGroupBody(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetAllPoints()
    b.heading = ns.NewHeading(b, "")
    b.heading:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
    b.heading:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    local y = -28
    b.info = Line(b, y); y = y - LINE_H
    b.rule = Line(b, y); y = y - LINE_H
    b.state = Line(b, y); y = y - LINE_H - 4
    b.counts = Line(b, y)
    ns.Font(b.counts, 11)
    b.pieTop = y - LINE_H - 8
    local toggle = ns.NewButton(b, "", 130, function()
        local k = pane.groupKey
        if k then M.PSS_SetManagedGroupActive(k, not M.PSS_ManagedGroupActive(k)) end
        G.dirty = true
        page.refresh()
    end)
    toggle:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 8)
    ns.TipOn(toggle, toggle, "Turns this default guild list's rule on or off (the same switch as on the Chat Filters tab).")
    b.toggle = toggle
    local open = ns.NewButton(b, "", 100, function()
        local k = pane.groupKey
        if k then M.PSS_SetGuildGroupOpen(k, not M.PSS_GuildGroupOpen(k)) end
        Resort()
        ShowDetail()
    end)
    open:SetPoint("LEFT", toggle, "RIGHT", 6, 0)
    b.open = open
    return b
end

local function BuildInfoBody(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetAllPoints()
    b.heading = ns.NewHeading(b, "")
    b.heading:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
    b.heading:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    b.text = Line(b, -30)
    b.text:SetWordWrap(true)
    b.text:SetJustifyV("TOP")
    b.text:SetHeight(160)
    local remove = ns.NewButton(b, "Remove from Exclusion List", 190, function()
        local name = pane.exclName
        if name and M.PSS_RemoveGuildExclusion(name) then
            M.ChatMsg(("PSS: <%s> removed from the Guild Exclusion List."):format(name))
            G.selKind, G.sel = nil, nil
        end
    end)
    remove:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 10, 8)
    b.removeButton = remove
    return b
end

local function BuildMemberBody(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetAllPoints()
    b.heading = ns.NewHeading(b, "")
    b.heading:SetPoint("TOPLEFT", b, "TOPLEFT", 10, -8)
    b.heading:SetPoint("RIGHT", b, "RIGHT", -10, 0)
    local dp = ns.NewDetailPages(b, -28, "guilds")
    b.pages = dp
    b.counts = Line(dp.summary, -6)
    ns.Font(b.counts, 11)
    b.summary = ns.NewSummary(dp.summary, page, -30)

    -- View/Edit Rule
    local rule = dp.rule
    local y = -2
    b.guildLine = Line(rule, y); y = y - LINE_H
    b.addedLine = Line(rule, y); y = y - LINE_H - 4

    local nr = Strip(rule, y, 22)
    Label(nr, "Note")
    local note = CreateFrame("EditBox", nil, nr, "InputBoxTemplate")
    note:SetPoint("LEFT", nr, "LEFT", 94, 0)
    note:SetPoint("RIGHT", nr, "RIGHT", -4, 0)
    note:SetHeight(20)
    note:SetAutoFocus(false)
    note:SetMaxLetters(25)
    ns.EditBox(note)
    -- saves to the member shown when typing started
    note:SetScript("OnEditFocusGained", function() pane.noteMember = G.msel end)
    ns.OnCommit(note, function(text)
        local m = pane.noteMember or G.msel
        if not m then return end
        text = (M.trim(text) or ""):sub(1, 25)
        if text ~= (m.note or "") then
            M.PSS_SetMemberNote(m, text)
            G.mdirty = true
        end
    end, function() if page:IsVisible() then MResort(); ShowDetail() end end)
    pane.noteBox = note
    y = y - 28

    -- ticked = allowed; dimmed = following the guild; right-click = follow
    -- the guild again
    b.excl = ExclBoxes(rule, y, "Ticked = allowed from this player, unticked = blocked. Dimmed boxes follow the guild's setting; right-click to follow it again.",
        function(cat, box, button)
            local m = G.msel
            local _, gg = M.PSS_FindGuildRule(G.mguild)
            if not (m and gg) then return end
            if button == "RightButton" then
                M.PSS_SetMemberBlock(gg, m, cat, nil)
            else
                M.PSS_SetMemberBlock(gg, m, cat, not box:GetChecked())
            end
            G.dirty = true
            ShowDetail()
        end)
    y = y - 28

    b.overrides = Overrides(rule, y, "person", function() return G.msel end)

    local remove = ns.NewButton(rule, "Remove Member", 110, ConfirmRemoveMember)
    remove:SetPoint("BOTTOMLEFT", rule, "BOTTOMLEFT", 10, 4)
    b.removeButton = remove

    -- Event History: the member's block history, the whole page
    b.hist = ns.NewHistory(dp.history, -2, {
        empty = "Nothing blocked from this player yet.",
        open = function(m) ns.OpenHistoryView(page, ns.MemberHistorySpec(m, G.mguild)) end,
    })
    local reset = ns.NewButton(dp.history, L["HISTORY_RESET"] or "Reset Block History", 130, function()
        if G.msel then M.PSS_ResetMemberBlockHistory(G.msel) end
    end)
    reset:SetPoint("BOTTOMLEFT", dp.history, "BOTTOMLEFT", 10, 4)
    local addGuild = ns.NewButton(rule, "Add Guild", 90, function()
        local m = G.msel
        if m and M.PSS_AddMembersGuild(G.mguild, m.guild) then
            G.mdirty, G.dirty = true, true
            MResort()
            ShowDetail()
        end
    end)
    addGuild:SetPoint("LEFT", remove, "RIGHT", 6, 0)
    ns.TipOn(addGuild, addGuild, "The player's actual guild is not this rule: adds a rule for it and moves its members there.")
    b.addGuild = addGuild
    return b
end

local function BuildPane(parent)
    pane = CreateFrame("Frame", nil, parent)
    pane:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -TOP_H - 4)
    pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
    pane:SetWidth(DETAIL_W)
    ns.Panel(pane)

    pane.none = ns.NewText(pane, 12)
    pane.none:SetPoint("CENTER")
    pane.none:SetTextColor(1, 1, 1, 0.5)
    pane.none:SetText("Select a guild to see its details.")

    pane.bodies = {}
    pane.guild = BuildGuildBody(pane)
    pane.group = BuildGroupBody(pane)
    pane.info = BuildInfoBody(pane)
    pane.member = BuildMemberBody(pane)
    for _, k in ipairs({ "guild", "group", "info", "member" }) do
        pane[k]:Hide()
        pane.bodies[#pane.bodies + 1] = pane[k]
    end
end

local function ShowGuild(key, fresh)
    local _, g = M.PSS_FindGuildRule(key)
    if not g then return false end
    local b = pane.guild
    pane.guildKey = key
    b:Show()
    b.heading:SetText(tostring(g.name))
    local info = ("%d member%s"):format(g.memberCount or 0, (g.memberCount or 0) == 1 and "" or "s")
    if g.managed then
        local grp = M.PSS_ManagedGroups()[g.managed] or {}
        info = info .. "  |cffaaaaaa" .. tostring(grp.name or g.managed) .. " list, rule "
            .. (M.PSS_ManagedGroupActive(g.managed) and "|cff00ff00on|r" or "|cffff5555off|r")
    end
    b.info:SetText(info)
    local gb = M.PSS_GuildBlock(g)
    for cat, c in pairs(b.excl) do c:SetChecked(gb[cat] ~= true) end
    b.scan:SetText(M.PSS_GuildSweepLabel(key))
    if not pane.fieldsBox:HasFocus() then pane.fieldsBox:SetText(g.customScan or "") end
    PaintOverrides(b.overrides, g)
    local c = M.PSS_GetGuildBlockCounts(key)
    b.counts:SetText(CountsText(c))
    b.removeButton:SetEnabled(not M.PSS_IsStaticManagedGuild(key))
    b.membersButton:SetShown(G.view ~= "members")
    b.hist:Set(key, c.total or 0, M.PSS_GetGuildBlockHistory, fresh)
    b.summary:Set(History.GuildKey and History.GuildKey(key), c.total or 0, tostring(g.name), ns.GuildHistorySpec, key, NO_WHERE)
    return true
end

-------------------------------------------------------------------------------
--  A default guild list's two pies (1.1.0-dev006): this session / last 24
--  hours / all time, and its blocks by type (all time; the session and
--  24 hour counts are not kept by type per guild). Every count is the sum
--  of the list's guilds' own counts (History.GuildKey), so nothing here
--  loads PourSocialScore_Logging. No click-through: a list has no Block
--  History view of its own. Made the first time a list is shown.
-------------------------------------------------------------------------------
local GROUP_PIE = 84
local TYPE_SLOTS = 7

local function Legend(parent, x, y, w)
    local sq = parent:CreateTexture(nil, "ARTWORK")
    sq:SetSize(10, 10)
    sq:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 3)
    local t = ns.NewText(parent, 11)
    t:SetPoint("TOPLEFT", sq, "TOPRIGHT", 6, 2)
    t:SetWidth(w)
    return { sq = sq, text = t }
end

local function SetLegend(l, r, g, b, text)
    l.sq:SetColorTexture(r, g, b, 0.9)
    l.text:SetText(text)
    l.sq:Show()
    l.text:Show()
end

local function HideLegend(l)
    l.sq:Hide()
    l.text:Hide()
end

local function HexColor(hex)
    hex = tostring(hex or "ffffffff")
    return (tonumber(hex:sub(3, 4), 16) or 255) / 255, (tonumber(hex:sub(5, 6), 16) or 255) / 255,
        (tonumber(hex:sub(7, 8), 16) or 255) / 255
end

local function BuildGroupPies(owner)
    local b = CreateFrame("Frame", nil, owner)
    b:SetAllPoints()
    owner.pies = b
    b.heading = owner.heading
    local top = owner.pieTop
    local x = GROUP_PIE + 32
    b.periodPie = ns.NewPie(b, GROUP_PIE)
    b.periodPie.frame:SetPoint("TOPLEFT", b, "TOPLEFT", 14, top)
    b.periodPie.tip = function(i)
        local sl = b.periodSlices[i]
        return ("%s\n%s: %d blocked"):format(b.heading:GetText() or "", sl.text, sl.value or 0)
    end
    b.periodKeys, b.periodSlices, b.periodValues = {}, {}, {}
    for i, per in ipairs(ns.SUMMARY_PERIODS) do
        b.periodKeys[i] = Legend(b, x, top - 12 - (i - 1) * 20, 220)
        b.periodSlices[i] = { r = per.r, g = per.g, b = per.b, text = per.text, value = 0 }
    end

    local top2 = top - GROUP_PIE - 12
    b.typePie = ns.NewPie(b, GROUP_PIE)
    b.typePie.frame:SetPoint("TOPLEFT", b, "TOPLEFT", 14, top2)
    b.typePie.tip = function(i)
        local sl = b.typeSlices[i]
        return ("%s\n%s: %d blocked (all time)"):format(b.heading:GetText() or "", sl.text, sl.value or 0)
    end
    b.typeSlices, b.typeKeys = {}, {}
    for i = 1, TYPE_SLOTS do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        b.typeKeys[i] = Legend(b, x + col * 128, top2 - 4 - row * 20, 108)
        b.typeSlices[i] = {}
    end
    b.typeEmpty = ns.NewText(b, 11)
    b.typeEmpty:SetPoint("CENTER", b.typePie.frame, "CENTER", 0, 0)
    b.typeEmpty:SetTextColor(1, 1, 1, 0.5)
    b.typeEmpty:SetText("Nothing yet")
    b.periodEmpty = ns.NewText(b, 11)
    b.periodEmpty:SetPoint("CENTER", b.periodPie.frame, "CENTER", 0, 0)
    b.periodEmpty:SetTextColor(1, 1, 1, 0.5)
    b.periodEmpty:SetText("Nothing yet")
end

-- items: the list's guild items ({ key, bc }); bc: their counts added up
local function ShowGroupPies(owner, items, bc)
    if not owner.pies then BuildGroupPies(owner) end
    local b = owner.pies
    b:Show()
    local session, day = 0, 0
    local recent = History.RecentCounts and History.GuildKey
    if recent then
        for i = 1, #items do
            local s, d = History.RecentCounts(History.GuildKey(items[i].key))
            session, day = session + (s or 0), day + (d or 0)
        end
    end
    local values = b.periodValues
    values.session, values.day, values.all = session, day, bc.total or 0
    for i, per in ipairs(ns.SUMMARY_PERIODS) do
        local sl = b.periodSlices[i]
        sl.value = values[per.key]
        local text = per.text .. "  |cffffffff" .. sl.value .. "|r"
        if not recent and per.key ~= "all" then text = per.text .. "  |cff808080needs PourSocialScore 3.2|r" end
        SetLegend(b.periodKeys[i], per.r, per.g, per.b, text)
    end
    b.periodPie:Set(b.periodSlices)
    b.periodEmpty:SetShown(values.all == 0 and session == 0 and day == 0)

    -- by type: the types it blocked, in the core's order
    local slices, n = b.typeSlices, 0
    for _, cat in ipairs(History.ALL_CATS or {}) do
        local v = tonumber(bc[cat]) or 0
        if v > 0 and n < TYPE_SLOTS then
            n = n + 1
            local sl = slices[n]
            sl.r, sl.g, sl.b = HexColor(History.CAT_COLOR[cat])
            sl.value, sl.text, sl.cat = v, History.CAT_LABEL[cat] or cat, cat
            SetLegend(b.typeKeys[n], sl.r, sl.g, sl.b, sl.text .. "  |cffffffff" .. v .. "|r")
        end
    end
    for i = n + 1, TYPE_SLOTS do
        slices[i].value = 0
        HideLegend(b.typeKeys[i])
    end
    b.typeCount = n
    b.typePie:Set(slices)
    b.typeEmpty:SetShown(n == 0)
end

local function ShowGroup(k)
    local grp = M.PSS_ManagedGroups()[k]
    if not grp then return false end
    local item
    for i = 1, G.n do
        local it = G.rows[i]
        if it.header and it.groupKey == k then item = it break end
    end
    local b = pane.group
    pane.groupKey = k
    b:Show()
    b.heading:SetText(tostring(grp.name or k))
    b.info:SetText(item and ("%d guilds, %d members"):format(item.guilds, item.members) or "")
    b.rule:SetText(("Rule on the Chat Filters tab: %s (%s)"):format(tostring(grp.rule), tostring(grp.filter)))
    local on = M.PSS_ManagedGroupActive(k)
    b.state:SetText(on and "|cff00ff00Rule is ON|r: its guilds are blocked, minus each guild's exclusions."
        or "|cffff5555Rule is OFF|r: nothing in this list is blocked.")
    b.counts:SetText(item and CountsText(item.bc) or "")
    local items = G.rows.groups and G.rows.groups[k]
    if item and items then
        ShowGroupPies(b, items, item.bc)
    elseif b.pies then
        b.pies:Hide()
    end
    b.toggle:SetText(on and "Turn Rule Off" or "Turn Rule On")
    b.open:SetText(M.PSS_GuildGroupOpen(k) and "Collapse" or "Expand")
    return true
end

local function ShowExcl(name)
    local b = pane.info
    if name then
        if not M.PSS_IsGuildExcluded(name) then return false end
        b.heading:SetText(name)
        b.text:SetText("|cff4dccffExcluded|r: never blocked by a guild rule, even one whose name it contains.")
    else
        local n = #M.PSS_GuildExclusions()
        b.heading:SetText("Guild Exclusion List")
        b.text:SetText(("%d guild%s.\n\nGuilds that no guild rule ever blocks, captures or scans in, even a rule whose name they contain or a default list.\n\nAdd guilds with the \"Exclude a Guild\" box above."):format(n, n == 1 and "" or "s"))
    end
    pane.exclName = name
    b.removeButton:SetShown(name ~= nil)
    b:Show()
    return true
end

local function ShowMember(fresh)
    local m = G.msel
    local _, gg = M.PSS_FindGuildRule(G.mguild)
    if not (m and gg) then return false end
    local b = pane.member
    b:Show()
    local cr, cg, cb = ClassColor(m)
    b.heading:SetText(("|cff%02x%02x%02x"):format(cr * 255, cg * 255, cb * 255) .. tostring(m.name) .. "|r")
    local actual = m.guild or ""
    b.guildLine:SetText("Guild " .. (actual ~= "" and ("<" .. actual .. ">") or "|cff808080unknown|r"))
    b.addedLine:SetText("Added " .. ((m.whenBlocked or "") ~= "" and m.whenBlocked or "|cff808080unknown|r"))
    if not pane.noteBox:HasFocus() then pane.noteBox:SetText(m.note or "") end
    local own = M.PSS_MemberBlock(m)
    for cat, c in pairs(b.excl) do
        c:SetChecked(not M.PSS_MemberBlocks(gg, m, cat))
        c:SetAlpha(own[cat] == nil and 0.45 or 1)
    end
    PaintOverrides(b.overrides, m)
    local base = M.PSS_NormalizeGuild(gg.name or G.mguild)
    local ag = M.PSS_NormalizeGuild(actual)
    b.addGuild:SetShown(ag ~= nil and ag ~= "" and ag ~= base)
    M.PSS_EnsureMemberBlockData(m)
    local c = M.PSS_GetMemberBlockCounts(m)
    b.counts:SetText(CountsText(c))
    b.hist:Set(m, c.total or 0, M.PSS_GetMemberBlockHistory, fresh)
    b.summary:Set(History.MemberKey(m), c.total or 0, tostring(m.name), MemberSpec, m, MEMBER_WHO)
    return true
end

-- Redraw the pane for what is selected (nothing: a hint).
function ShowDetail(fresh)
    if not pane then return end
    for _, body in ipairs(pane.bodies) do body:Hide() end
    local shown = false
    if G.view == "members" then
        shown = (G.msel and ShowMember(fresh)) or ShowGuild(G.mguild, fresh)
    elseif G.selKind == "guild" then
        shown = ShowGuild(G.sel, fresh)
    elseif G.selKind == "group" then
        shown = ShowGroup(G.sel)
    elseif G.selKind == "exclHeader" then
        shown = ShowExcl(nil)
    elseif G.selKind == "excl" then
        shown = ShowExcl(G.sel)
    end
    if not shown then G.selKind, G.sel = nil, nil end
    pane.none:SetShown(not shown)
end

-------------------------------------------------------------------------------
--  Guild Search results (in place of the list)
-------------------------------------------------------------------------------
local function ClosePicker()
    if not picker:IsShown() then return end
    picker:Hide()
    if picker.mode ~= "exclude" then M.PSS_ForgetGuildSearch() end
    lf:SetShown(G.view == "guilds")
    mview:SetShown(G.view == "members")
end

local function DrawPick(row, i)
    local it = picker.items[i]
    local c = row.cells
    if not it then
        for _, fs in pairs(c) do fs:SetText("") end
        return
    end
    c.tick:SetText(it.listed and "|cff808080[x]|r" or (it.ticked and "|cff00ff00[x]|r" or "[  ]"))
    c.guild:SetText(it.name)
    c.state:SetText(it.listed and "|cff808080listed|r" or "")
    row.sel:SetShown(it.ticked and not it.listed)
end

local function BuildPicker(parent)
    picker = CreateFrame("Frame", nil, parent)
    picker:SetPoint("TOPLEFT", lf, "TOPLEFT", 0, 0)
    picker:SetPoint("BOTTOMRIGHT", lf, "BOTTOMRIGHT", 0, 0)
    picker:Hide()
    picker.items = {}
    picker.title = ns.NewText(picker, 12)
    picker.title:SetPoint("TOPLEFT", picker, "TOPLEFT", 4, -4)
    picker.title:SetPoint("RIGHT", picker, "RIGHT", -4, 0)
    picker.title:SetJustifyH("LEFT")
    local rf = CreateFrame("Frame", nil, picker)
    rf:SetPoint("TOPLEFT", picker, "TOPLEFT", 0, -24)
    rf:SetPoint("BOTTOMRIGHT", picker, "BOTTOMRIGHT", 0, 34)
    picker.list = ns.NewRows(rf, {
        rowH = 20, height = 240,
        cols = {
            { key = "tick", text = "", width = 36, justify = "CENTER" },
            { key = "guild", text = "Guild" },
            { key = "state", text = "", width = 70 },
        },
        draw = DrawPick,
        click = function(row, i)
            local it = picker.items[i]
            if it and not it.listed then
                it.ticked = not it.ticked
                picker.list:Redraw()
            end
        end,
    })
    local save = ns.NewButton(picker, "Save", 90, function()
        local names = {}
        for _, it in ipairs(picker.items) do
            if it.ticked and not it.listed then names[#names + 1] = it.name end
        end
        if #names > 0 then
            if picker.mode == "exclude" then M.PSS_SaveGuildExclusions(names) else M.PSS_SaveGuildSearch(names) end
        end
        ClosePicker()
    end)
    save:SetPoint("BOTTOMLEFT", picker, "BOTTOMLEFT", 4, 4)
    picker.saveButton = save
    local all = ns.NewButton(picker, "Tick All", 90, function()
        for _, it in ipairs(picker.items) do it.ticked = not it.listed end
        picker.list:Redraw()
    end)
    all:SetPoint("LEFT", save, "RIGHT", 6, 0)
    local cancel = ns.NewButton(picker, "Cancel", 90, ClosePicker)
    cancel:SetPoint("LEFT", all, "RIGHT", 6, 0)
end

local function ShowSearchResults(found, query, mode)
    local exclude = mode == "exclude"
    if not found or #found == 0 then
        if exclude then
            local name = M.trim(((query or ""):gsub('"', ""))) or ""
            if name == "" then return end
            EUI:ShowConfirmPopup({
                title       = "Pour Social Score",
                message     = ("No guild named <%s> was found online.\n\nAdd it to the Guild Exclusion List anyway?"):format(name),
                confirmText = "Add Anyway",
                cancelText  = "Cancel",
                onConfirm   = function()
                    M.PSS_AddGuildExclusion(name)
                    Say(("<%s> added to the Guild Exclusion List."):format(name))
                end,
            })
        else
            Say(("Guild Search found no guilds for \"%s\"."):format(query or ""))
        end
        return
    end
    picker.mode = mode
    picker.items = {}
    for _, name in ipairs(found) do
        local listed
        if exclude then listed = M.PSS_IsGuildExcluded(name) else listed = M.PSS_IsGuildListed(name) end
        picker.items[#picker.items + 1] = { name = name, listed = listed }
    end
    picker.title:SetText((exclude and "Guild Exclusion Search: " or "Guild Search: ")
        .. ("%d guild(s) found for \"%s\". Click the guilds to "):format(#found, query or "")
        .. (exclude and "exclude." or "add."))
    lf:Hide()
    mview:Hide()
    picker:Show()
    picker.list:SetCount(#picker.items)
    picker.list:Top()
end

-------------------------------------------------------------------------------
--  Tab
-------------------------------------------------------------------------------
local function Refresh()
    if G.view == "members" then
        if G.mdirty then MResort() else mlist:Redraw() end
        if not G.mguild then CloseMembers() return end
    end
    if G.dirty then Resort() elseif G.view == "guilds" then list:Redraw() end
    UpdateCount()
    ShowDetail()
end

-- [box] [Guild Search] [Add]: the top right entry rows
local function EntryRow(pg, y, hintText, addText, onSearch, onAdd, searchTip, addTip)
    local addButton = ns.NewButton(pg, addText, 90, nil)
    addButton:SetPoint("TOPRIGHT", pg, "TOPRIGHT", -8, y)
    local search = ns.NewButton(pg, "Guild Search", 100, nil)
    search:SetPoint("RIGHT", addButton, "LEFT", -6, 0)
    local box = CreateFrame("EditBox", nil, pg, "InputBoxTemplate")
    box:SetSize(150, 20)
    box:SetPoint("RIGHT", search, "LEFT", -8, 0)
    box:SetAutoFocus(false)
    ns.EditBox(box)
    local hint = ns.NewText(box, 12)
    hint:SetPoint("LEFT", box, "LEFT", 2, 0)
    hint:SetTextColor(1, 1, 1, 0.4)
    hint:SetText(hintText)
    box:SetScript("OnTextChanged", function(self) hint:SetShown((self:GetText() or "") == "") end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local function doSearch()
        if M.PSS_ScanBlockedMsg() then return end
        local text = BoxText(box)
        if not text then Say("Type part of a guild name in the box first.") return end
        if onSearch(text) then box:SetText("") end
    end
    local function doAdd()
        local text = BoxText(box)
        if not text then Say("Type a guild name in the box first.") return end
        if onAdd(text) then box:SetText("") end
        box:ClearFocus()
    end
    search:SetScript("OnClick", doSearch)
    addButton:SetScript("OnClick", doAdd)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); doSearch() end)
    ns.TipOn(search, search, searchTip)
    ns.TipOn(addButton, addButton, addTip)
    ScanButton(search)
    return box, search, addButton
end

function ns.BuildGuildsTab(pg)
    page = pg

    -- top left: search (guild names, or the members shown) and the count
    local search = CreateFrame("EditBox", nil, pg, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", pg, "TOPLEFT", 16, -6)
    search:SetSize(200, 20)
    search:SetAutoFocus(false)
    ns.EditBox(search)
    local hint = ns.NewText(search, 12)
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetTextColor(1, 1, 1, 0.4)
    hint:SetText("Search guild name")
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        if G.view == "members" then
            if text ~= G.mfind then
                G.mfind = text
                MResort()
                mlist:Top()
            end
        elseif text ~= G.find then
            G.find = text
            Resort()
            list:Top()
        end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    pg.search, pg.searchHint = search, hint

    pg.count = ns.NewText(pg, 12)
    pg.count:SetPoint("LEFT", search, "RIGHT", 12, 0)
    pg.count:SetTextColor(1, 1, 1, 0.7)

    -- top right: Scan All, [Add a Guild] [Guild Search] [Add Guild],
    -- under it [Exclude a Guild] [Guild Search] [Exclude]
    pg.add, pg.searchButton, pg.addButton = EntryRow(pg, -5, "Add a Guild", "Add Guild",
        function(text) return M.PSS_GuildSearch(text, nil, "eui") end,
        function(text)
            if M.PSS_IsGuildListed(text) then
                Say(("<%s> is already on the Guild Ignore List."):format(text))
                return true
            end
            M.PSS_AddGuild(text)
            Say(("<%s> added to the Guild Ignore List."):format(text))
            G.find = ""
            pg.search:SetText("")
            Resort()
            Select("guild", M.PSS_NormalizeGuild(text))
            return true
        end,
        "Guild Search\n\nRuns a /who and lists every guild found (not the players). Type part of a guild name, or a full /who filter containing quotes, e.g. g-\"Name\" 10-80.",
        "Add Guild\n\nAdds the guild typed in the box to the Guild Ignore List.")
    pg.excl, pg.exclSearchButton, pg.exclButton = EntryRow(pg, -31, "Exclude a Guild", "Exclude",
        function(text) return M.PSS_GuildSearch((text:gsub('"', "")), "exclude", "eui") end,
        function(text)
            if M.PSS_AddGuildExclusion(text) == false then
                Say(("<%s> is already on the Guild Exclusion List."):format(text))
            else
                Say(("<%s> added to the Guild Exclusion List."):format(text))
            end
            return true
        end,
        "Guild Search\n\nRuns a /who for the guild name in the box and lets you pick which guilds found go on the Guild Exclusion List. If none is found you can add the name anyway.",
        "Exclude\n\nAdds the guild typed in the box to the Guild Exclusion List: no guild rule ever blocks it, even one whose name it contains.")

    local scanAll = ns.NewButton(pg, "Scan All", 80, function() M.PSS_ScanAll() end)     -- /who first, UI after
    scanAll:SetPoint("RIGHT", pg.add, "LEFT", -10, 0)
    scanAll:SetScript("OnEnter", function(self) ns.Tip(self, ScanTipText(nil)) end)
    scanAll:SetScript("OnLeave", ns.HideTip)
    pg.scanAll = ScanButton(scanAll)

    BuildPane(pg)

    lf = CreateFrame("Frame", nil, pg)
    lf:SetPoint("TOPLEFT", pg, "TOPLEFT", 8, -TOP_H - 4)
    lf:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", -8, 0)
    list = ns.NewRows(lf, {
        rowH = 20, height = 300,
        cols = {
            { key = "guild", text = "Guild" },
            { key = "members", text = "Members", width = 70, justify = "RIGHT" },
            { key = "metric:total", text = "Blocked", width = 62, justify = "RIGHT",
              tip = "Messages and invites blocked from the guild's members." },
            { key = "scan", text = "Scan", width = 90, justify = "RIGHT",
              tip = "Scan n/m = /who searches sent / planned so far this session. Sorts by searches sent." },
        },
        sort = SetSort,
        draw = DrawRow,
        enter = RowTip,
        click = ClickRow,
    })

    -- the members of one guild, in place of the guild list
    mview = CreateFrame("Frame", nil, pg)
    mview:SetPoint("TOPLEFT", lf, "TOPLEFT", 0, 0)
    mview:SetPoint("BOTTOMRIGHT", lf, "BOTTOMRIGHT", 0, 0)
    mview:Hide()
    local back = ns.NewButton(mview, "All Guilds", 90, CloseMembers)
    back:SetPoint("TOPLEFT", mview, "TOPLEFT", 0, 0)
    ns.TipOn(back, back, "Back to the guild list.")
    mview.back = back
    mview.heading = ns.NewText(mview, 12)
    mview.heading:SetPoint("LEFT", back, "RIGHT", 10, 0)
    local mf = CreateFrame("Frame", nil, mview)
    mf:SetPoint("TOPLEFT", mview, "TOPLEFT", 0, -26)
    mf:SetPoint("BOTTOMRIGHT", mview, "BOTTOMRIGHT", 0, 0)
    mlist = ns.NewRows(mf, {
        rowH = 20, height = 280,
        cols = {
            { key = "name", text = "Name" },
            { key = "guild", text = "Guild", width = 130 },
            { key = "note", text = "Note", width = 110 },
            { key = "metric:total", text = "Blocked", width = 62, justify = "RIGHT",
              tip = "Messages and invites blocked from this player." },
        },
        sort = SetMemberSort,
        draw = DrawMember,
        enter = MemberTip,
        click = function(row, i)
            local m = G.members[i]
            if m then SelectMember(m) end
        end,
    })

    BuildPicker(pg)

    -- back / forward and Escape (EUI_Window.lua): the members of a guild
    -- are a view of their own, the Guild Search results an overlay
    pg.navState = function() return G.view == "members" and G.mguild or nil end
    pg.navTitle = function(key)
        local _, g = M.PSS_FindGuildRule(key)
        return ("Members of <%s>"):format(g and g.name or tostring(key))
    end
    pg.navApply = function(key)
        if key then
            if G.mguild ~= key or G.view ~= "members" then
                local found = M.PSS_FindGuildRule(key)
                if found then OpenMembers(key) end
            end
        elseif G.view == "members" then
            CloseMembers()
        end
    end
    pg.navClose = function()
        if not picker:IsShown() then return false end
        ClosePicker()
        return true
    end
    pg.navUp = function()
        if pg.navClose() then return true end
        if G.view == "members" then
            CloseMembers()
            return true
        end
        return false
    end

    pg.list, pg.members, pg.pane, pg.picker, pg.membersView = list, mlist, pane, picker, mview
    pg.state = G
    G.dirty = true
    return Refresh
end

-------------------------------------------------------------------------------
--  Core events: redraw now if the tab shows, else when it next shows.
-------------------------------------------------------------------------------
local queued = false
local function Changed()
    G.dirty, G.mdirty = true, true
    if queued or not (page and page:IsVisible()) then return end
    -- one redraw however many changes arrive in a frame (saving Guild
    -- Search results adds many guilds at once)
    queued = true
    C_Timer.After(0, function()
        queued = false
        if page and page:IsVisible() then Refresh() end
    end)
end
M.Events.Register("GUILDS_CHANGED", Changed)
M.Events.Register("GUILD_SCAN_DONE", Changed)

-- Blocked lines only change counts: at most 4 redraws a second, and only
-- the rows on screen read their counts again (a full re-read of every
-- guild's counts waits until the tab is next opened or sorted).
local pending
local function RedrawCounts()
    if G.view == "guilds" then
        for i = 1, list.shown or 0 do
            local it = G.rows[list.first + i]
            if it and it.key then it.bc = M.PSS_GetGuildBlockCounts(it.key) end
        end
        list:Redraw()
    else
        mlist:Redraw()
    end
    ShowDetail()
end
M.Events.Register("GUILD_BLOCKS_CHANGED", function()
    if not (page and page:IsVisible()) then
        G.dirty, G.mdirty = true, true
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = nil
        if page and page:IsVisible() then RedrawCounts() else G.dirty, G.mdirty = true, true end
    end)
end)

M.Events.Register("GUILD_REMOVED", function(key)
    if G.selKind == "guild" and G.sel == key then G.selKind, G.sel = nil, nil end
    if G.mguild == key then G.mguild, G.msel = nil, nil end
    Changed()
end)

M.Events.Register("WHOIS_COOLDOWN", function(active)
    for _, b in ipairs(scanButtons) do b:SetEnabled(not active) end
    if not active then Changed() end
end)

M.Events.Register("GUILD_SEARCH_RESULTS", function(found, query, mode, owner)
    if owner ~= "eui" or not picker then return end
    ShowSearchResults(found, query, mode)
end)
