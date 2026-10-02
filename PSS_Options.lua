------------------------------------------------------------------------
-- POUR SOCIAL SCORE - OPTIONS
--
-- Every option has one account-wide value (the Options tab, stored at the
-- top level of PourSocialScoreDB). Options that make sense per target (e.g.
-- "Send ignore response to ignored players") can additionally be overridden
-- per GUILD rule and per PERSON (guild member or ignored player) from their
-- right-click menus / the player detail window.
--
-- Resolution (most specific wins):  person > guild > Options tab > default
-- (2.0.12 removed the per-character layer: it had no visible effect for most
-- people and an override set there could not be seen anywhere else.)
--
--   M.PSS_Opt(key [, ctx])     ctx = { person = <opts table>, guild = <opts table> }
--   M.PSS_SetOpt(key, scope, value [, target])  scope: "global" | "guild" | "person"
--                                               value nil clears an override
------------------------------------------------------------------------
local addonName, addon = ...
local L = addon.L
local V = addon.V
local M = addon.M

local OPTIONS = {
    -- Ignore list
    { key = "asknote",        kind = "bool",   default = true, section = 1, label = L["OPT_1"] },
    { key = "sameserver",     kind = "bool",   default = true,  section = 1, label = L["OPT_4"] },
    { key = "samefaction",    kind = "bool",   default = true,  section = 1, label = L["OPT_27"] },
    { key = "trackChanges",   kind = "bool",   default = true,  section = 1, label = L["OPT_6"] },
    { key = "chatmsg",        kind = "bool",   default = true,  section = 1, label = L["OPT_26"] },
    { key = "showWarning",    kind = "bool",   default = true, section = 1, label = L["OPT_18"] },
    { key = "defexpire",      kind = "number", default = 0,     section = 1, label = L["OPT_5"] },
    -- Blocking (people)
    { key = "blizzardSync",   kind = "bool",   default = false, section = 1, label = "Also put listed players on Blizzard's ignore list (it ignores exclusions)" },
    { key = "ignoreResponse", kind = "bool",   default = false,  section = 2, label = L["OPT_24"], target = true },
    { key = "showDeclines",   kind = "bool",   default = true,  section = 2, label = L["OPT_28"], target = true },
    { key = "declineDuel",    kind = "bool",   default = true,  section = 2, label = "Decline duels from blocked players", target = true },
    { key = "declineTrade",   kind = "bool",   default = true,  section = 2, label = "Decline trades from blocked players", target = true },
    { key = "historyTotal",   kind = "number", default = 2000,  section = 2, min = 100, max = 20000,
      label = "Block history lines kept in total, shared by every player, guild and filter (100-20000; a larger buffer increases memory usage)" },
    { key = "purgeHistory",   kind = "bool",   default = true,  section = 2, label = "Remove a player's earlier chat lines when they become blocked" },
    -- Chat filters
    { key = "spamFilter",     kind = "bool",   default = true,  section = 3, label = L["OPT_7"] },
    { key = "invertSpam",     kind = "bool",   default = false, section = 3, label = L["OPT_10"] },
    { key = "floodFilter",    kind = "choice", default = 0,     section = 3, label = L["OPT_20"],
      choices = { { 0, L["OPT_21"] }, { 1, L["OPT_22"] }, { 2, L["OPT_23"] } } },
    { key = "skipGuild",      kind = "bool",   default = true,  section = 3, label = L["OPT_12"] },
    { key = "skipParty",      kind = "bool",   default = false, section = 3, label = L["OPT_13"] },
    { key = "skipPrivate",    kind = "bool",   default = true,  section = 3, label = L["OPT_14"] },
    { key = "skipYourself",   kind = "bool",   default = false, section = 3, label = L["OPT_19"] },
    -- User interface
    { key = "openWithFriends", kind = "bool",  default = true,  section = 4, label = L["OPT_2"] },
    { key = "useUnitHacks",   kind = "bool",   default = true,  section = 4, label = L["OPT_16"] },
    { key = "useLFGHacks",    kind = "bool",   default = true,  section = 4, label = L["OPT_17"] },
    { key = "gcEnabled",      kind = "bool",   default = true,  section = 4, label = "Background memory cleanup (out of combat, never causes a hitch)" },
    { key = "frameStrata",    kind = "choice", default = 3,     section = 4, label = L["OPT_25"],
      choices = { { 0, "LOW" }, { 1, "MEDIUM" }, { 2, "HIGH" }, { 3, "DIALOG" } } },
    -- Whois scans (Scan, Scan All, Custom, Guild Search): see PSS_WhoisHarvest.lua.
    -- The cap is drawn in the tickbox's row (field) and must be set to tick it.
    { key = "whoLevelCapOn",  kind = "bool",   default = false, section = 5, label = "Enable scan level cap", field = "whoLevelCap",
      tip = "When ticked, no /who scan searches above this level: Scan and Scan All stop their level brackets at the cap, Custom and Guild Search are limited to it." },
    { key = "whoLevelCap",    kind = "number", default = nil,   section = 5, min = 1, max = 999, inline = true, label = "Scan level cap" },
}
local SECTIONS = { L["OPT_8"], "Blocking Options:", L["OPT_9"], L["OPT_15"], "Whois Scan Options:" }

local REG = {}
for _, o in ipairs(OPTIONS) do REG[o.key] = o end
M.PSS_OPTIONS = OPTIONS
M.PSS_OPTION_REG = REG

------------------------------------------------------------------------
-- Resolution
------------------------------------------------------------------------
local charKeyCache
local function charKey()
    if not charKeyCache and UnitName then
        local n, r = UnitName("player")
        if n then charKeyCache = M.PSS_NormalizePlayer((r and r ~= "") and (n .. "-" .. r) or n) end
    end
    return charKeyCache
end
M.PSS_CharKey = charKey

function M.PSS_Opt(key, ctx)
    local def = REG[key]
    if ctx and def and def.target then
        local person, guild = ctx.person, ctx.guild
        if type(person) == "table" and person[key] ~= nil then return person[key] end
        if type(guild) == "table" and guild[key] ~= nil then return guild[key] end
    end
    local db = PourSocialScoreDB
    if db and db[key] ~= nil then return db[key] end
    if def then return def.default end
    return nil
end

local STRATA = { [0] = "LOW", [1] = "MEDIUM", [2] = "HIGH", [3] = "DIALOG" }
function M.PSS_FrameStrataName()
    return STRATA[tonumber(M.PSS_Opt("frameStrata")) or 3] or "DIALOG"
end

-- Options whose effect must be applied immediately when changed.
local function applyLive()
    local main = _G["PSS"]
    if main and main.SetFrameStrata then main:SetFrameStrata(M.PSS_FrameStrataName()) end
end

-- target: the record whose .opts holds the override (guild rule, member,
-- or player record) for scope "guild"/"person".
function M.PSS_SetOpt(key, scope, value, target)
    local db = PourSocialScoreDB
    if not db then return end
    if scope == "global" then
        db[key] = value
    elseif (scope == "guild" or scope == "person") and type(target) == "table" then
        if M.PSS_KeepManaged then M.PSS_KeepManaged(target) end   -- shipped member: save it
        target.opts = target.opts or {}
        target.opts[key] = value
        if next(target.opts) == nil then target.opts = nil end
    end
    if key == "frameStrata" then applyLive() end
    -- a smaller history buffer frees the memory now, not only as lines arrive
    if key == "historyTotal" and M.PSS_TrimAllHistory then M.PSS_TrimAllHistory() end
end

-- New options get their global default once (old ones keep saved values).
function M.PSS_ApplyOptionDefaults()
    local db = PourSocialScoreDB
    if not db then return end
    -- 2.0.12: these two are off by default. Saved values were almost always
    -- just the old default (on), so they are switched off once; turn them
    -- back on in the Options tab if you want them.
    if not db.optionsV2012 then
        db.ignoreResponse = false
        db.blizzardSync = false
        db.charOptions = nil      -- per-character overrides are gone (see top)
        db.optionsV2012 = true
    end
    for _, o in ipairs(OPTIONS) do
        if db[o.key] == nil then db[o.key] = o.default end
    end
end

------------------------------------------------------------------------
-- Override menus (guild row, member row, player row right-click)
------------------------------------------------------------------------
local function stateText(v)
    if v == nil then return "|cffaaaaaaDefault|r" end
    if v == true then return "|cff00ff00On|r" end
    if v == false then return "|cffff5555Off|r" end
    return tostring(v)
end

-- root: a Menu element description; target: record (guild / member / player)
-- scopeLabel: "guild" or "person" (shown in the title)
function M.PSS_AddOverrideMenu(root, target, scopeLabel, onChange)
    if not root or type(target) ~= "table" then return end
    local scope = (scopeLabel == "guild") and "guild" or "person"
    root:CreateDivider()
    root:CreateTitle(scope == "guild" and "Overrides for this guild" or "Overrides for this player")
    for _, o in ipairs(OPTIONS) do
        if o.target and o.kind == "bool" then
            local cur = target.opts and target.opts[o.key]
            local sub = root:CreateButton(o.label .. ": " .. stateText(cur))
            for _, choice in ipairs({ { nil, "Default (use the Options tab)" }, { true, "On" }, { false, "Off" } }) do
                local v = choice[1]
                sub:CreateButton((cur == v and "|cffffd100> |r" or "   ") .. choice[2], function()
                    M.PSS_SetOpt(o.key, scope, v, target)
                    if onChange then onChange() end
                end)
            end
        end
    end
end

------------------------------------------------------------------------
-- Options tab
------------------------------------------------------------------------
-- Columns (shared header look, see PSS_UIKit.lua)
local COL_OPTION_W, COL_ALL_W = 620, 160
local COL_GLOBAL = COL_OPTION_W + COL_ALL_W / 2            -- centre of "Setting"

function M.PSS_BuildOptionsTab(MainFrame, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_OFFSET)
    local UI = M.UI
    local frame = CreateFrame("Frame", "PSSFrame3", MainFrame, "InsetFrameTemplate")
    frame:Hide()
    frame:SetPoint("TOPLEFT", MainFrame, "TOPLEFT", 8, -84)
    frame:SetPoint("BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -11, 29)

    local title, head = UI.CreateSummary(frame, "Options", 840)
    head:SetFontObject("GameFontHighlightSmall")
    head:SetWordWrap(true)
    head:SetHeight(30)
    head:SetJustifyV("TOP")
    frame.head = head

    local rows = {}
    local hr = UI.CreateHeaderRow(frame, {
        { key = "option", text = "Option",         width = COL_OPTION_W, sort = false, minWidth = 200 },
        { key = "all",    text = "Setting",        width = COL_ALL_W,    sort = false, minWidth = 60, tip = "The setting for every character on this account." },
    }, 1, UI.HEADER_Y, nil, { id = "options", onLayout = function(h)
        if frame.Slate then frame.Slate:SetWidth(h.total) end
        for _, r in ipairs(rows) do r:SetWidth(h.total) end
    end })
    frame:HookScript("OnSizeChanged", function(self, w) if w and w > 0 then hr:SetAvailableWidth(w - 28) end end)

    local scroll = CreateFrame("ScrollFrame", "PSSSlate3", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 1, -UI.LIST_TOP)
    scroll:SetPoint("BOTTOMRIGHT", -27, 4)
    local slate = CreateFrame("Frame", nil, scroll)
    slate:SetSize(COL_OPTION_W + COL_ALL_W, 10)
    scroll:SetScrollChild(slate)
    frame.ScrollFrame, frame.Slate = scroll, slate

    frame.rows = rows
    local y = -4

    local function refreshAll()
        frame.head:SetText("These settings apply to every character on this account. "
            .. "Options marked |cff66ccff*|r can also be set per guild or per player: right-click a guild row, a guild member, or a player on the ignore list.")
        for _, r in ipairs(rows) do r.refresh() end
    end
    frame.refreshAll = refreshAll

    -- the number option drawn next to a tickbox (o.field): a valid value is
    -- required while the box is ticked
    local function fieldValue(f, text)
        local n = tonumber(text)
        if not n then return nil end
        n = math.floor(n)
        if f.min and n < f.min then n = f.min end
        if f.max and n > f.max then n = f.max end
        return n
    end

    local section = 0
    for _, o in ipairs(OPTIONS) do
      if not o.inline then
        if o.section ~= section then
            section = o.section
            y = y - 6
            local h = M.UI.Heading(slate, SECTIONS[section] or "")
            h:SetPoint("TOPLEFT", 6, y)
            y = y - 22
        end

        local row = CreateFrame("Frame", nil, slate)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetSize(COL_OPTION_W + COL_ALL_W, 24)
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hr:Track("option", function(x, w) label:ClearAllPoints(); label:SetPoint("LEFT", row, "LEFT", x + 18, 0); label:SetWidth(math.max(20, w - 24)) end)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        label:SetText((o.label or o.key) .. (o.target and " |cff66ccff*|r" or ""))
        row.option = o

        if o.tip then
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(o.label, 1, 1, 1)
                GameTooltip:AddLine(o.tip, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        if o.kind == "bool" and o.field then
            local f = REG[o.field]
            local g = M.UI.Check(row)
            local e = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            e:SetSize(50, 18); e:SetAutoFocus(false); e:SetNumeric(true); e:SetJustifyH("CENTER")
            hr:Track("all", function(x, w)
                g:ClearAllPoints(); g:SetPoint("CENTER", row, "LEFT", x + w / 2 - 34, 0)
                e:ClearAllPoints(); e:SetPoint("LEFT", g, "RIGHT", 10, 0)
            end)
            local function saved() return PourSocialScoreDB and fieldValue(f, PourSocialScoreDB[f.key]) end
            local function warn(msg)
                M.ShowMsg("|cffff5555" .. msg .. "|r")
                e:SetFocus()
            end
            g:SetScript("OnClick", function(self)
                if self:GetChecked() then
                    -- ticking needs a cap: the one being typed, else the saved one
                    local n = fieldValue(f, e:GetText()) or saved()
                    if not n then
                        self:SetChecked(false)
                        warn(("%s: enter the %s first (%d-%d)."):format(o.label, f.label:lower(), f.min, f.max))
                        return
                    end
                    M.PSS_SetOpt(f.key, "global", n)
                end
                M.PSS_SetOpt(o.key, "global", self:GetChecked() == true)
                refreshAll()
            end)
            local busy   -- ClearFocus below fires OnEditFocusLost: commit once
            local function commit(self)
                if busy then return end
                busy = true
                local n = fieldValue(f, self:GetText())
                if n then
                    M.PSS_SetOpt(f.key, "global", n)
                elseif PourSocialScoreDB and PourSocialScoreDB[o.key] then
                    -- ticked: the cap is mandatory, keep the saved one
                    M.ShowMsg(("|cffff5555%s is required while %s is ticked.|r"):format(f.label, o.label))
                else
                    M.PSS_SetOpt(f.key, "global", nil)
                end
                self:ClearFocus(); refreshAll()
                busy = false
            end
            e:SetScript("OnEnterPressed", commit)
            e:SetScript("OnEditFocusLost", commit)
            e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshAll() end)
            e:SetScript("OnEnter", row:GetScript("OnEnter"))
            e:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.global, row.field = g, e
            row.refresh = function()
                local on = PourSocialScoreDB and PourSocialScoreDB[o.key] == true and saved() ~= nil
                g:SetChecked(on)
                if not e:HasFocus() then
                    local n = saved()
                    e:SetText(n and tostring(n) or "")
                end
                e:SetTextColor(on and 1 or 0.6, on and 1 or 0.6, on and 1 or 0.6)
            end
        elseif o.kind == "bool" then
            local g = M.UI.Check(row)
            UI.TCenter(g, row, hr, "all")
            g:SetScript("OnClick", function(self) M.PSS_SetOpt(o.key, "global", self:GetChecked() == true); refreshAll() end)
            row.global = g
            row.refresh = function()
                g:SetChecked(PourSocialScoreDB and PourSocialScoreDB[o.key] == true)
            end
        elseif o.kind == "number" then
            local g = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
            g:SetSize(50, 18); UI.TCenter(g, row, hr, "all"); g:SetAutoFocus(false); g:SetNumeric(true); g:SetJustifyH("CENTER")
            g:SetScript("OnEnterPressed", function(self)
                local n = tonumber(self:GetText())
                if n then
                    if o.min and n < o.min then n = o.min end
                    if o.max and n > o.max then n = o.max end
                    M.PSS_SetOpt(o.key, "global", n)
                end
                self:ClearFocus(); refreshAll()
            end)
            g:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refreshAll() end)
            row.global = g
            row.refresh = function()
                if not g:HasFocus() then g:SetText(tostring(PourSocialScoreDB and PourSocialScoreDB[o.key] or o.default)) end
            end
        else -- choice
            local function labelFor(v)
                for _, ch in ipairs(o.choices) do if ch[1] == v then return ch[2] end end
                return tostring(v)
            end
            local g = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
            g:SetWidth(120); UI.TCenter(g, row, hr, "all")
            g:SetupMenu(function(dd, root)
                for _, ch in ipairs(o.choices) do
                    root:CreateButton(ch[2], function() M.PSS_SetOpt(o.key, "global", ch[1]); refreshAll() end)
                end
            end)
            row.global = g
            row.refresh = function()
                if g.SetDefaultText then g:SetDefaultText(labelFor(PourSocialScoreDB and PourSocialScoreDB[o.key] or o.default)) end
            end
        end
        rows[#rows + 1] = row
        y = y - 26
      end
    end

    slate:SetHeight(-y + 20)
    frame:SetScript("OnShow", refreshAll)
    return frame
end
