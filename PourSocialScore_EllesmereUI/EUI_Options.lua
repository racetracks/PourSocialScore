-------------------------------------------------------------------------------
--  EUI_Options.lua -- the PSS options and Import/Export, drawn from the same
--  data in two places: the EllesmereUI panel pages (W:DualRow rows) and the
--  window's Options and Import/Export tabs (skinned controls). Both read
--  M.PSS_OPTIONS and write through M.PSS_SetOpt, so they never drift; a
--  change in one shows in the other (OPTION_CHANGED -> M.EUI_Refresh).
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local EUI = EllesmereUI

local OPTIONS = M.PSS_OPTIONS
local REG = M.PSS_OPTION_REG
local SECTIONS = M.PSS_OPTION_SECTIONS

-------------------------------------------------------------------------------
--  Option values (shared by both surfaces)
-------------------------------------------------------------------------------
local function Label(o)
    return ((o.label or o.key):gsub("[:%s]+$", ""))
end

local function Tooltip(o)
    local t = Label(o)
    if o.tip then t = t .. "\n\n" .. o.tip end
    if o.target then t = t .. "\n\nCan also be set per guild or per player." end
    return t
end

local function Clamp(o, v)
    local n = tonumber(v)
    if not n then return nil end
    n = math.floor(n)
    if o.min and n < o.min then n = o.min end
    if o.max and n > o.max then n = o.max end
    return n
end

local function NumberText(o)
    local n = M.PSS_Opt(o.key)
    return n ~= nil and tostring(n) or ""
end

local function SetNumber(o, text)
    local n = Clamp(o, text)
    if n then M.PSS_SetOpt(o.key, "global", n) else M.EUI_Refresh() end
end

-- A tickbox with its number drawn next to it (o.field, the scan level cap):
-- the number must be set while the box is ticked.
local function FieldOn(o)
    return M.PSS_Opt(o.key) == true and Clamp(REG[o.field], M.PSS_Opt(o.field)) ~= nil
end

local function SetFieldOn(o, on)
    local f = REG[o.field]
    if on and not Clamp(f, M.PSS_Opt(f.key)) then
        M.ShowMsg(("|cffff5555%s: enter the %s first (%d-%d).|r"):format(o.label, f.label:lower(), f.min, f.max))
        M.EUI_Refresh()
        return
    end
    M.PSS_SetOpt(o.key, "global", on)
end

local function SetField(o, text)
    local f = REG[o.field]
    local n = Clamp(f, text)
    if n then
        M.PSS_SetOpt(f.key, "global", n)
    elseif M.PSS_Opt(o.key) then
        M.ShowMsg(("|cffff5555%s is required while %s is ticked.|r"):format(f.label, o.label))
        M.EUI_Refresh()
    else
        M.PSS_SetOpt(f.key, "global", nil)
    end
end

local function ChoiceText(o, v)
    for _, ch in ipairs(o.choices) do if ch[1] == v then return ch[2] end end
    return tostring(v)
end

-- the options of one section, in M.PSS_OPTIONS order (inline numbers are
-- drawn by their tickbox)
local function SectionOptions(section)
    local list = {}
    for _, o in ipairs(OPTIONS) do
        if o.section == section and not o.inline then list[#list + 1] = o end
    end
    return list
end

local function SectionTitle(section)
    return ((SECTIONS[section] or ""):gsub("[:%s]+$", ""))
end

-------------------------------------------------------------------------------
--  Import/Export (shared): what to include lives for the session only
-------------------------------------------------------------------------------
ns.io = { players = true, guilds = true, members = false, filters = true, builtins = true, options = false, mode = "merge" }
ns.IO_PARTS = {
    { "players",  "Player Ignore List" },
    { "guilds",   "Guild Ignore List" },
    { "members",  "Captured guild members" },
    { "filters",  "Custom chat filters" },
    { "builtins", "Built-in filter on/off" },
    { "options",  "Options (all characters)" },
}
ns.IO_MODES = { merge = "Merge (add what is missing)", replace = "Replace (only the import)" }
ns.IO_MODE_ORDER = { "merge", "replace" }

local function Sections()
    local io = ns.io
    return { players = io.players, guilds = io.guilds, members = io.guilds and io.members,
             filters = io.filters, builtins = io.builtins, options = io.options }
end

local function Imported(prefix, report)
    M.ShowMsg(prefix .. report)
    M.EUI_Refresh()
end

function ns.Export()
    local text = M.PSS_EncodeExport(M.PSS_BuildExport(Sections()))
    if EUI.ShowCopyPopup then
        EUI:ShowCopyPopup("Pour Social Score Export", ("Copy the string below (%d characters)"):format(#text), text)
    else
        EUI:ShowExportPopup(text)
    end
end

function ns.Import()
    EUI:ShowImportPopup(function(str)
        local data, err = M.PSS_DecodeExport(str)
        if not data then
            M.ShowMsg("|cffff5555Import failed: " .. tostring(err) .. "|r")
            return
        end
        local s = Sections()
        if ns.io.mode ~= "replace" then
            Imported("Merged: ", M.PSS_ApplyImport(data, "merge", s))
            return
        end
        EUI:ShowConfirmPopup({
            title       = "Pour Social Score",
            message     = "Replace the ticked sections with the imported data?\n\n" .. M.PSS_DescribeImport(data)
                .. "\n\nWhat you have now in those sections will be removed.",
            confirmText = "Replace",
            cancelText  = "Cancel",
            onConfirm   = function() Imported("Replaced: ", M.PSS_ApplyImport(data, "replace", s)) end,
        })
    end, "Pour Social Score Import", "Paste a Pour Social Score export string below")
end

-------------------------------------------------------------------------------
--  Panel pages (EllesmereUI plugin API, registered by the core)
-------------------------------------------------------------------------------
local function PanelCfgs(o, out)
    local tip = Tooltip(o)
    if o.kind == "bool" and o.field then
        local f = REG[o.field]
        out[#out + 1] = { type = "toggle", text = Label(o), tooltip = tip,
            getValue = function() return FieldOn(o) end,
            setValue = function(v) SetFieldOn(o, v) end }
        out[#out + 1] = { type = "input", text = Label(f), tooltip = tip, inputWidth = 60,
            getValue = function() local n = Clamp(f, M.PSS_Opt(f.key)); return n and tostring(n) or "" end,
            setValue = function(text) SetField(o, text) end }
    elseif o.kind == "bool" then
        out[#out + 1] = { type = "toggle", text = Label(o), tooltip = tip,
            getValue = function() return M.PSS_Opt(o.key) == true end,
            setValue = function(v) M.PSS_SetOpt(o.key, "global", v == true) end }
    elseif o.kind == "number" then
        out[#out + 1] = { type = "input", text = Label(o), tooltip = tip, inputWidth = 60,
            getValue = function() return NumberText(o) end,
            setValue = function(text) SetNumber(o, text) end }
    else
        local values, order = {}, {}
        for _, ch in ipairs(o.choices) do
            values[ch[1]] = ch[2]
            order[#order + 1] = ch[1]
        end
        out[#out + 1] = { type = "dropdown", text = Label(o), tooltip = tip, values = values, order = order,
            getValue = function() return M.PSS_Opt(o.key) end,
            setValue = function(v) M.PSS_SetOpt(o.key, "global", v) end }
    end
end

-- Two slots per row, filled left to right; only the last row may have a blank.
local function DualRows(W, parent, y, cfgs)
    local _, h
    for i = 1, #cfgs, 2 do
        _, h = W:DualRow(parent, y, cfgs[i], cfgs[i + 1] or EUI.BlankRowCfg()); y = y - h
    end
    return y
end

local function BuildOptionsPage(section, parent, y)
    local W = EUI.Widgets
    local _, h
    _, h = W:SectionHeader(parent, SectionTitle(section):upper(), y); y = y - h
    local cfgs = {}
    if section == 4 then
        cfgs[1] = { type = "labeledButton", text = "Pour Social Score window", buttonText = "Open",
            tooltip = "The window that opens next to your Friends list. /pss gui opens it too.",
            onClick = function() M.EUI_Toggle(true) end }
    end
    for _, o in ipairs(SectionOptions(section)) do PanelCfgs(o, cfgs) end
    y = DualRows(W, parent, y, cfgs)
    return math.abs(y)
end

local function BuildImportExportPage(parent, y)
    local W = EUI.Widgets
    local io = ns.io
    local _, h
    _, h = W:SectionHeader(parent, "INCLUDE", y); y = y - h
    local cfgs = {}
    for _, p in ipairs(ns.IO_PARTS) do
        local key = p[1]
        cfgs[#cfgs + 1] = { type = "toggle", text = p[2],
            disabled = key == "members" and function() return not io.guilds end or nil,
            disabledTooltip = key == "members" and "Needs Guild Ignore List ticked." or nil,
            getValue = function() return io[key] end,
            setValue = function(v) io[key] = v; M.EUI_Refresh() end }
    end
    y = DualRows(W, parent, y, cfgs)
    _, h = W:SectionHeader(parent, "IMPORT / EXPORT", y); y = y - h
    y = DualRows(W, parent, y, {
        { type = "labeledButton", text = "Export the ticked sections", buttonText = "Export",
          tooltip = "Shows a text string to copy and share.", onClick = ns.Export },
        { type = "dropdown", text = "Import mode", values = ns.IO_MODES, order = ns.IO_MODE_ORDER,
          tooltip = "Merge adds what you do not have yet. Replace makes the ticked sections exactly what was imported.",
          getValue = function() return io.mode end,
          setValue = function(v) io.mode = v; M.EUI_Refresh() end },
        { type = "labeledButton", text = "Import a string", buttonText = "Import",
          tooltip = "Paste a Pour Social Score export string; the ticked sections are applied.", onClick = ns.Import },
    })
    return math.abs(y)
end

function M.EUI_BuildPage(module, page, parent, yOffset)
    if module == "Options" then
        for i, name in ipairs(M.PSS_EUI_PAGES or {}) do
            if name == page then return BuildOptionsPage(i, parent, yOffset) end
        end
    elseif module == "ImportExport" then
        return BuildImportExportPage(parent, yOffset)
    end
    return 0
end

-------------------------------------------------------------------------------
--  Window tabs (built on first open)
-------------------------------------------------------------------------------
local ROW_H = 26
local CONTROL_X = 210       -- controls sit this far left of the row's right edge

local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    ns.Font(fs, size or 12)
    fs:SetTextColor(1, 1, 1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Heading(parent, text)
    local fs = Text(parent, 13)
    if ns.S then fs:SetTextColor(ns.S.GetAccentColor()) else fs:SetTextColor(1, 0.82, 0) end
    fs:SetText(text)
    return fs
end

local function Check(parent)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    ns.Checkbox(c)
    return c
end

local function NumberBox(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    e:SetNumeric(true)
    e:SetJustifyH("CENTER")
    ns.EditBox(e)
    return e
end

-- commit on Enter and focus loss, once (ClearFocus fires focus loss again)
local function OnCommit(e, commit, refresh)
    local busy
    local function run(self)
        if busy then return end
        busy = true
        commit(self:GetText())
        self:ClearFocus()
        refresh()
        busy = false
    end
    e:SetScript("OnEnterPressed", run)
    e:SetScript("OnEditFocusLost", run)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus(); refresh() end)
end

local function Dropdown(parent, w, choices, onPick)
    local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    d:SetWidth(w)
    d:SetupMenu(function(dd, root)
        for _, ch in ipairs(choices) do
            root:CreateButton(ch[2], function() onPick(ch[1]) end)
        end
    end)
    ns.Dropdown(d)
    return d
end

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    ns.Button(b)
    return b
end

local function TipOn(frame, owner, text)
    frame:SetScript("OnEnter", function() ns.Tip(owner, text) end)
    frame:SetScript("OnLeave", ns.HideTip)
end

local function Scroll(page)
    local scroll = CreateFrame("ScrollFrame", nil, page, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -26, 8)
    ns.ScrollBar(scroll.ScrollBar)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(math.max(scroll:GetWidth(), 400), 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w) if w and w > 0 then content:SetWidth(w) end end)
    return content
end

local function OptionRow(content, o, y, rows)
    local row = CreateFrame("Frame", nil, content)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    row:SetHeight(ROW_H)
    local label = Text(row)
    label:SetPoint("LEFT", row, "LEFT", 14, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -CONTROL_X - 10, 0)
    label:SetText(Label(o) .. (o.target and " *" or ""))
    row:EnableMouse(true)
    TipOn(row, label, Tooltip(o))

    local refresh
    if o.kind == "bool" and o.field then
        local f = REG[o.field]
        local c = Check(row)
        c:SetPoint("LEFT", row, "RIGHT", -CONTROL_X, 0)
        local e = NumberBox(row, 50)
        e:SetPoint("LEFT", c, "RIGHT", 10, 0)
        refresh = function()
            local on = FieldOn(o)
            c:SetChecked(on)
            if not e:HasFocus() then
                local n = Clamp(f, M.PSS_Opt(f.key))
                e:SetText(n and tostring(n) or "")
            end
        end
        c:SetScript("OnClick", function(self)
            -- ticking takes the cap being typed, else the saved one
            local n = Clamp(f, e:GetText())
            if self:GetChecked() and n then M.PSS_SetOpt(f.key, "global", n) end
            SetFieldOn(o, self:GetChecked() == true)
            refresh()
        end)
        OnCommit(e, function(text) SetField(o, text) end, refresh)
    elseif o.kind == "bool" then
        local c = Check(row)
        c:SetPoint("LEFT", row, "RIGHT", -CONTROL_X, 0)
        c:SetScript("OnClick", function(self) M.PSS_SetOpt(o.key, "global", self:GetChecked() == true) end)
        refresh = function() c:SetChecked(M.PSS_Opt(o.key) == true) end
    elseif o.kind == "number" then
        local e = NumberBox(row, 60)
        e:SetPoint("LEFT", row, "RIGHT", -CONTROL_X + 4, 0)
        refresh = function() if not e:HasFocus() then e:SetText(NumberText(o)) end end
        OnCommit(e, function(text) SetNumber(o, text) end, refresh)
    else
        local d = Dropdown(row, 170, o.choices, function(v) M.PSS_SetOpt(o.key, "global", v) end)
        d:SetPoint("LEFT", row, "RIGHT", -CONTROL_X, 0)
        refresh = function() if d.SetDefaultText then d:SetDefaultText(ChoiceText(o, M.PSS_Opt(o.key))) end end
    end
    rows[#rows + 1] = refresh
end

function ns.BuildOptionsTab(page)
    local content = Scroll(page)
    local rows = {}
    local y = -4
    for section = 1, #SECTIONS do
        local list = SectionOptions(section)
        if #list > 0 then
            local h = Heading(content, SectionTitle(section))
            h:SetPoint("TOPLEFT", content, "TOPLEFT", 6, y - 4)
            y = y - 28
            for _, o in ipairs(list) do
                OptionRow(content, o, y, rows)
                y = y - ROW_H
            end
            y = y - 8
        end
    end
    local note = Text(content, 11)
    note:SetPoint("TOPLEFT", content, "TOPLEFT", 6, y - 4)
    note:SetTextColor(1, 1, 1, 0.6)
    note:SetText("* can also be set per guild or per player. The same settings are in the EllesmereUI panel (/pss eui).")
    content:SetHeight(-y + 30)
    return function() for i = 1, #rows do rows[i]() end end
end

function ns.BuildImportExportTab(page)
    local io = ns.io
    local checks = {}
    local help = Text(page, 12)
    help:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    help:SetTextColor(1, 1, 1, 0.8)
    help:SetText("Tick what to include, then Export and copy the string. To import, choose a mode and paste a string into the Import box.")
    local y = -46
    for _, p in ipairs(ns.IO_PARTS) do
        local key = p[1]
        local c = Check(page)
        c:SetPoint("TOPLEFT", page, "TOPLEFT", key == "members" and 36 or 14, y)
        local label = Text(page)
        label:SetPoint("LEFT", c, "RIGHT", 4, 0)
        label:SetText(p[2])
        c:SetScript("OnClick", function(self) io[key] = self:GetChecked() == true; M.EUI_Refresh() end)
        checks[key] = { c, label }
        y = y - 28
    end
    local modeLabel = Text(page)
    modeLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y - 10)
    modeLabel:SetText("Import mode")
    local modes = {}
    for _, k in ipairs(ns.IO_MODE_ORDER) do modes[#modes + 1] = { k, ns.IO_MODES[k] } end
    local mode = Dropdown(page, 220, modes, function(v) io.mode = v; M.EUI_Refresh() end)
    mode:SetPoint("LEFT", modeLabel, "LEFT", 110, 0)
    local export = Button(page, "Export", 110, ns.Export)
    export:SetPoint("TOPLEFT", page, "TOPLEFT", 16, y - 48)
    local import = Button(page, "Import", 110, ns.Import)
    import:SetPoint("LEFT", export, "RIGHT", 10, 0)
    return function()
        for key, t in pairs(checks) do
            t[1]:SetChecked(io[key] == true)
            local off = key == "members" and not io.guilds
            t[1]:SetEnabled(not off)
            t[2]:SetAlpha(off and 0.4 or 1)
        end
        if mode.SetDefaultText then mode:SetDefaultText(ns.IO_MODES[io.mode]) end
    end
end

-------------------------------------------------------------------------------
--  Refresh: the open window tab, and the panel when it shows our section
-------------------------------------------------------------------------------
function M.EUI_Refresh()
    if ns.RefreshTabs then ns.RefreshTabs() end
    if EUI.GetPluginModuleKey and EUI.GetActiveModule and EUI.RefreshPage then
        local active = EUI:GetActiveModule()
        if active and (active == EUI.GetPluginModuleKey(ADDON_NAME, "Options")
            or active == EUI.GetPluginModuleKey(ADDON_NAME, "ImportExport")) then
            EUI:RefreshPage()
        end
    end
end

M.Events.Register("OPTION_CHANGED", function() M.EUI_Refresh() end)
