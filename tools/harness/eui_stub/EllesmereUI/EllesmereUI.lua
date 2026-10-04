-- A stand-in for EllesmereUI's public API, enough for the PSS harness: it
-- records plugin registrations, popups and skin calls. It holds none of
-- EllesmereUI's code.
local E = {}
EllesmereUI = E
E.log = { plugins = {}, popups = {}, opened = {}, skinned = {}, escape = {} }

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

function E:ShowConfirmPopup(opts) E.log.popups[#E.log.popups + 1] = opts end
function E.ShowWidgetTooltip() end
function E.HideWidgetTooltip() end
function E.RegisterEscapeClose(frame) E.log.escape[#E.log.escape + 1] = frame end
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
