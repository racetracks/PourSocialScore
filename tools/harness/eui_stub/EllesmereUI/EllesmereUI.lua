-- A stand-in for EllesmereUI's public API, enough for the PSS harness: it
-- records plugin registrations, popups and skin calls. It holds none of
-- EllesmereUI's code.
local E = {}
EllesmereUI = E
E.log = { plugins = {}, popups = {}, opened = {}, skinned = {}, escape = {}, copies = {}, refreshed = 0 }

local plugins = {}
function E.RegisterPlugin(id, spec)
	if plugins[id] then return false end
	plugins[id] = spec
	E.log.plugins[#E.log.plugins + 1] = id
	return true
end
function E.IsPluginRegistered(id) return plugins[id] ~= nil end
function E.OpenPlugin(id, key, page)
	if InCombatLockdown() then return false end
	E.log.opened[#E.log.opened + 1] = id
	return plugins[id] ~= nil
end
E.prebuild = false
function E.IsSearchPrebuild() return E.prebuild end
function E.GetPlugin(id) return plugins[id] end

-- the confirm popup also shows its screen-wide dimmer (EUIConfirmDimmer, as
-- EllesmereUI names it) with the message on EUIConfirmPopup._msg
function E:ShowConfirmPopup(opts)
	E.log.popups[#E.log.popups + 1] = opts
	if not EUIConfirmDimmer then
		local d = CreateFrame("Frame", "EUIConfirmDimmer", UIParent)
		local p = CreateFrame("Frame", "EUIConfirmPopup", d)
		p._msg = p:CreateFontString()
		EUIConfirmDimmer, EUIConfirmPopup = d, p
	end
	EUIConfirmPopup._msg:SetText(opts.message)
	EUIConfirmDimmer:Show()
end
E.log.inputs = {}
function E:ShowInputPopup(opts) E.log.inputs[#E.log.inputs + 1] = opts end
function E:ShowCopyPopup(title, subtitle, str) E.log.copies[#E.log.copies + 1] = str end
-- the import popup hands over E.importText as if it was pasted
function E:ShowImportPopup(onImport) onImport(E.importText) end
-- panel state: E.active is the module key on show
function E.GetPluginModuleKey(id, key) return "plugin:" .. id .. ":" .. key end
function E:GetActiveModule() return E.active end
function E:RefreshPage() E.log.refreshed = E.log.refreshed + 1 end
function E.ShowWidgetTooltip() end
function E.HideWidgetTooltip() end
-- E.log.escapeOpts[frame]: the opts given (onEscape runs in place of Hide)
E.log.escapeOpts = {}
function E.RegisterEscapeClose(frame, opts)
	E.log.escape[#E.log.escape + 1] = frame
	E.log.escapeOpts[frame] = opts
end
-- one Escape press over the registered frames, newest first
function E.PressEscape()
	for i = #E.log.escape, 1, -1 do
		local f = E.log.escape[i]
		if f:IsShown() then
			local o = E.log.escapeOpts[f]
			if o and o.onEscape then o.onEscape(f) else f:Hide() end
			return true
		end
	end
	return false
end
function E.GetFontPath() return "Fonts\\FRIZQT__.TTF" end
E.PanelPP = { CreateBorder = function() end }
function E.BlankRowCfg() return { type = "label", text = "" } end

-- skinning facade: every primitive records the frame it was given
E.skinsOn = true
local S = setmetatable({ apiVersion = 3 }, { __index = function(t, k)
	local f = function(frame) E.log.skinned[#E.log.skinned + 1] = k end
	rawset(t, k, f)
	return f
end })
-- which tabs show as selected (S.SetTabSelection)
E.log.tabSel = {}
function S.SetTabSelection(tab, selected) E.log.tabSel[tab] = selected end
function E.RegisterSkin(name, fn)
	if E.skinsOn then fn(S) end
	return true
end

-- widget factory: rows recorded by label, 50 high like the real rows
E.rows = {}
E.Widgets = {}
function E.Widgets:SectionHeader(parent, text, y)
	E.rows[#E.rows + 1] = { "header", text }
	return {}, 40
end
function E.Widgets:DualRow(parent, y, left, right)
	E.rows[#E.rows + 1] = { "dual", left, right }
	return {}, 50
end
