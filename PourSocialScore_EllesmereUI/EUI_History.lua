-------------------------------------------------------------------------------
--  EUI_History.lua -- the block history list of the Players and Guilds panes.
--  The history lives in PourSocialScore_Logging, which loads on demand: a
--  pane reads it by itself only once something else loaded it, otherwise it
--  offers a Show Block History button. Types show as one word with a tick
--  box each to filter them; the guild view adds the player's name.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M
local History = M.PSS_History

local TIME_FMT = "%Y/%m/%d %H:%M:%S"

-- the filter order, and the one word shown for each line
local TYPES = { "whisper", "invite", "party", "raid", "BG", "world", "guild" }
local CAT_TYPE = {
    whisper     = "whisper",
    partyInvite = "invite",
    guildInvite = "invite",
    world       = "world",
    guildChat   = "guild",
}
local CHANNEL_TYPE = {
    ["Raid"] = "raid", ["Raid Leader"] = "raid", ["Raid Warning"] = "raid",
    ["Battleground"] = "BG", ["Battleground Leader"] = "BG",
    ["Instance"] = "BG", ["Instance Leader"] = "BG",
}

-- party / raid lines split by their channel; other: an unknown category
function ns.HistoryType(h)
    local t = CAT_TYPE[h.cat]
    if t then return t end
    if h.cat == "partyRaid" then return CHANNEL_TYPE[h.channel] or "party" end
    return "other"
end

local EMPTY = {}

-- types switched off, shared by every history list until /reload
local hidden = {}
local lists = {}

local function Filter(hv)
    local out, n = hv.shown, 0
    for i = 1, #hv.all do
        local h = hv.all[i]
        if not hidden[ns.HistoryType(h)] then
            n = n + 1
            out[n] = h
        end
    end
    for i = #out, n + 1, -1 do out[i] = nil end
    hv.list:SetCount(n)
    if #hv.all > 0 and n == 0 then
        hv.list:SetEmptyText("Every line here is of a type ticked off above.")
    else
        hv.list:SetEmptyText(hv.emptyText)
    end
end

local function Draw(hv, row, i)
    local h = hv.shown[i]
    local cells = row.cells
    if not h then
        for _, fs in pairs(cells) do fs:SetText("") end
        return
    end
    local ts = tonumber(h.ts)
    cells.time:SetText(ts and ts > 0 and date(TIME_FMT, ts) or History.UNKNOWN)
    cells.kind:SetText("|c" .. (History.CAT_COLOR[h.cat or "unknown"] or "ffffffff") .. ns.HistoryType(h) .. "|r")
    if cells.name then cells.name:SetText(M.removeServer and M.removeServer(h.member or "", true) or (h.member or "")) end
    local msg = h.message or ""
    cells.message:SetText(msg ~= "" and msg or "|cff888888(no message text)|r")
end

local function Tip(hv, row, i)
    local h = hv.shown[i]
    if not h then return end
    local ts = tonumber(h.ts)
    ns.Tip(row, (ts and ts > 0 and date(TIME_FMT, ts) or "") .. "  " .. (h.channel or "")
        .. ((h.member or "") ~= "" and ("  " .. h.member) or "") .. "\n\n" .. (h.message or ""))
end

local HV = {}
HV.__index = HV

-- Show the lines of id (read(id) returns them, loading Logging); read again
-- only when id or its count changed. fresh scrolls back to the top.
function HV:Set(id, total, read, fresh)
    local ready = M.PSS_LoggingReady()
    local key = tostring(id) .. "\001" .. total .. "\001" .. tostring(ready)
    if key == self.key then return end
    fresh = fresh or self.id ~= id
    self.key, self.id, self.total, self.read = key, id, total, read
    if total > 0 and not ready then
        -- not loaded yet: offer it rather than load it for a click on a row
        self.all = EMPTY
        self.gate:SetText(("Show Block History (%d)"):format(total))
        self.gate:Show()
        self.list:SetEmptyText("")
        self.list:SetCount(0)
        wipe(self.shown)
        return
    end
    self.gate:Hide()
    self.all = total > 0 and read(id) or EMPTY
    Filter(self)
    if fresh then self.list:Top() end
end

-- Forget what is shown (the next Set reads again).
function HV:Clear()
    self.key, self.id, self.read = nil, nil, nil
end

-- body: the pane body; y: top of the list; opts.names adds a Name column,
-- opts.empty is the text with nothing blocked. Fills the space down to the
-- buttons at the bottom of the body.
function ns.NewHistory(body, y, opts)
    local hv = setmetatable({ all = EMPTY, shown = {}, emptyText = opts.empty or "", typeOf = ns.HistoryType }, HV)
    local f = CreateFrame("Frame", nil, body)
    f:SetPoint("TOPLEFT", body, "TOPLEFT", 6, y)
    f:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -4, 36)
    hv.frame = f

    -- [x] whisper [x] invite ...: untick a type to hide its lines
    hv.boxes = {}
    local prev
    for _, t in ipairs(TYPES) do
        local c = ns.NewCheck(f)
        c:SetSize(18, 18)
        if prev then
            c:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        end
        local label = ns.NewText(f, 10)
        label:SetPoint("LEFT", c, "RIGHT", 0, 0)
        label:SetText(t)
        c:SetChecked(not hidden[t])
        c:SetScript("OnClick", function(self)
            hidden[t] = not self:GetChecked() or nil
            for _, other in ipairs(lists) do
                other.boxes[t]:SetChecked(not hidden[t])
                Filter(other)
            end
        end)
        ns.TipOn(c, c, ("Show %s lines."):format(t))
        hv.boxes[t] = c
        prev = label
    end

    local lf = CreateFrame("Frame", nil, f)
    lf:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -20)
    lf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    local cols = {
        { key = "time", text = "Time", width = 118 },
        { key = "kind", text = "Type", width = 48 },
    }
    if opts.names then cols[#cols + 1] = { key = "name", text = "Name", width = 86 } end
    cols[#cols + 1] = { key = "message", text = "Message" }
    hv.list = ns.NewRows(lf, {
        rowH = 16, fontSize = 11, height = 60, cols = cols,
        draw = function(row, i) Draw(hv, row, i) end,
        enter = function(row, i) Tip(hv, row, i) end,
    })
    hv.list:SetEmptyText(hv.emptyText)

    hv.gate = ns.NewButton(lf, "Show Block History", 170, function()
        if not M.PSS_LoadLogging() then return end
        local id, total, read = hv.id, hv.total, hv.read
        hv.key = nil
        if read then hv:Set(id, total, read, true) end
    end)
    hv.gate:SetPoint("TOP", lf, "TOP", 0, -36)
    ns.TipOn(hv.gate, hv.gate, "Loads the block history (it stays loaded until you log out or /reload).")
    hv.gate:Hide()

    lists[#lists + 1] = hv
    return hv
end
