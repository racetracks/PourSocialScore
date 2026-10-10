-- Enabled components (issue 181, 3.6.0.69), as a run.lua script. The phase is
-- PSS_PHASE; each prints "PASS components <phase>" or "FAIL components: <phase>:
-- <what>". The components a run starts with come from PSS_COMPONENTS (run.lua:
-- "none" = a fresh install); a simulated reload is a second run on the first
-- run's saved file (components_phases.sh). Both clients (PSS_CAMELOT=1).
--   defaults options addonsoff addonson gfxoff gfxon filteringoff filteringon
--   loggingoff loggingon reloadset reloadread tabs
local phase = os.getenv("PSS_PHASE") or "defaults"
local fail = false
local function check(ok, msg) if not ok then print("FAIL components: " .. phase .. ": " .. msg) fail = true end return ok end
local camelot = os.getenv("PSS_CAMELOT") == "1"
local realPrint = print
local said
local function pss(cmd)
	said = {}
	print = function(s) said[#said + 1] = (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
	local ok, err = pcall(M.PSS_SlashPSS, cmd)
	print = realPrint
	check(ok, "error: " .. tostring(err))
	return said
end
local function has(lines, text)
	for _, s in ipairs(lines) do if s:find(text, 1, true) then return s end end
end
local function keysOf(tabs) local t = {} for _, x in ipairs(tabs) do t[#t + 1] = x.key end return table.concat(t, ",") end
local function stored()
	local n = #(rawget(PourSocialScoreDB, "outbox") or {})
	if M.PSS_History.Loaded() then n = n + #M.PSS_History.Log() end
	return n
end
local function hooksOn(target) local n = 0 for _, h in ipairs(H.hooks) do if h.target == target then n = n + 1 end end return n end

local phases = {}

function phases.defaults()
	check(not M.PSS_On("addons") and not M.PSS_On("gfx") and M.PSS_On("logging") and M.PSS_On("filtering"), "the four defaults")
	check(PSS_OptionsDB.useAddons == nil and PSS_OptionsDB.useGfx == nil and PSS_OptionsDB.useLogging == nil and PSS_OptionsDB.useFiltering == nil, "a default was saved")
	check(not M.PSS_ComponentPending("addons"), "pending at login")
end

function phases.options()
	check(M.PSS_Need("Libraries"), "Libraries")
	local g = M.PSS_OptGroups()
	check(g[1].title == "Enabled components", "the section is not first: " .. tostring(g[1].title))
	local labels = {}
	for _, it in ipairs(g[1].items) do labels[#labels + 1] = it.o.label end
	check(table.concat(labels, ",") == "Addon Manager,Event Logging,Graphics Settings Exporter,Social Filtering,PSS Drop Cheapest Thing", "labels: " .. table.concat(labels, ","))
	check(g[2].title == "Blocking Options" or g[2].title ~= "Enabled components", "the other sections follow")
	-- greyed rows
	local en, note = M.PSS_OptGate(M.PSS_OPTION_REG.useGfx)
	check(en == camelot, "Graphics enabled on Camelot only: " .. tostring(en))
	check(camelot or note == " (Camelot only)", "the Retail note: " .. note)
	M.PSS_SetOpt("useFiltering", "global", false)
	check(M.PSS_OptGate(M.PSS_OPTION_REG.useLogging), "Event Logging row is not greyed while filtering is off")
	check(PSS_OptionsDB.useFiltering == false, "only the non-default is saved")
	M.PSS_SetOpt("useFiltering", "global", true)
	check(PSS_OptionsDB.useFiltering == nil, "the default is not saved")
	-- a change waits for a reload
	M.PSS_SetOpt("useAddons", "global", true)
	check(PSS_OptionsDB.useAddons == true and M.PSS_ComponentPending("addons") and not M.PSS_On("addons"), "a change applies after a reload")
	local _, n2 = M.PSS_OptGate(M.PSS_OPTION_REG.useAddons)
	check(n2:find("(after reload)", 1, true), "the row says so: " .. n2)
	M.PSS_SetOpt("useAddons", "global", false)
	check(PSS_OptionsDB.useAddons == nil and not M.PSS_ComponentPending("addons"), "back to the default")
	-- the window row: a tick asks "Reload now?"
	SlashCmdList["PSS"]("gui")
	local win = _G.PSS_Window
	local ui = H.Private("PourSocialScore_GUI")
	win.tabs[4]._scripts.OnClick(win.tabs[4])
	H.Private("PourSocialScore_GUI").ManagerShow("options")
	local page = win.pages[4].pages.options
	local row
	for _, it in ipairs(page.groups[1].items) do if it.o.key == "useAddons" then row = it.row end end
	check(row and row.check, "no Addon Manager row")
	row.check:SetChecked(true)
	row.check._scripts.OnClick(row.check)
	local cf = _G.PSS_Confirm
	check(cf and cf:IsShown() and cf.text:GetText():find("Reload now?", 1, true), "no reload question")
	local before = H.reloads
	if os.getenv("PSS_CAMELOT") == "1" then
		check(_G.PSS_ReloadClick and _G.PSS_ReloadClick:IsShown(), "Camelot: no reload button over Accept")
		H.SecureClick(_G.PSS_ReloadClick)
	else
		cf.accept._scripts.OnClick(cf.accept)
	end
	check(H.reloads == before + 1, "Reload did not reload")
	row.check:SetChecked(false)
	row.check._scripts.OnClick(row.check)
	-- Event Logging: unticking asks first (OK / Cancel); Cancel leaves it on, OK turns it off and asks to reload
	local lrow
	for _, it in ipairs(page.groups[1].items) do if it.o.key == "useLogging" then lrow = it.row end end
	lrow.check:SetChecked(false)
	lrow.check._scripts.OnClick(lrow.check)
	local wf = _G.PSS_Confirm
	check(wf:IsShown() and wf.text:GetText():find("will not be able to track", 1, true) and PSS_OptionsDB.useLogging == nil, "no warning, or the option changed before OK")
	wf.cancel._scripts.OnClick(wf.cancel)
	check(PSS_OptionsDB.useLogging == nil and lrow.check:GetChecked() == true, "Cancel did not keep Event Logging on")
	lrow.check:SetChecked(false)
	lrow.check._scripts.OnClick(lrow.check)
	wf = _G.PSS_Confirm
	wf.accept._scripts.OnClick(wf.accept)
	check(PSS_OptionsDB.useLogging == false, "OK did not turn Event Logging off")
	check(_G.PSS_Confirm:IsShown() and _G.PSS_Confirm.text:GetText():find("Reload now?", 1, true), "no reload question after OK")
	_G.PSS_Confirm.cancel._scripts.OnClick(_G.PSS_Confirm.cancel)
	lrow.check:SetChecked(true)
	lrow.check._scripts.OnClick(lrow.check)
	check(PSS_OptionsDB.useLogging == nil, "ticking it on again did not clear the saved value")
	_G.PSS_Confirm.cancel._scripts.OnClick(_G.PSS_Confirm.cancel)
	row.check:SetChecked(true)
	row.check._scripts.OnClick(row.check)
	before = H.reloads
	H.combat = true
	local c2 = _G.PSS_Confirm
	if os.getenv("PSS_CAMELOT") == "1" then H.SecureClick(_G.PSS_ReloadClick) else c2.accept._scripts.OnClick(c2.accept) end
	check(H.reloads == before + 1, "the player's reload in combat did not run")
	H.combat = false
end

function phases.addonsoff()
	check(SlashCmdList["PSSACP"] == nil and SLASH_PSSACP1 == nil, "/acp exists while the Addon Manager is off")
	check(#AddonCompartmentFrame.registered == 1, "compartment entries: " .. #AddonCompartmentFrame.registered)
	check(M.PSS_Need("Libraries"), "Libraries")
	check(M.PSS_AddonList == nil and M.PSS_AddonView == nil and M.PSS_AddonCommand == nil, "the addon manager files loaded")
	check(keysOf(M.PSS_UI_TABS):find("addons", 1, true) and not M.PSS_MgrHas("addons") and M.PSS_MgrPage() == "features", "the Addon Manager tab or its pages: " .. keysOf(M.PSS_UI_TABS))
	check(has(pss("acp"), "The Addon Manager is off"), "/pss acp")
	check(has(pss("acp list"), "The Addon Manager is off"), "/pss acp list")
	local l = {}
	said = {}
	print = function(s) said[#said + 1] = tostring(s) end
	PSS_AddonsBinding()
	print = realPrint
	check(has(said, "The Addon Manager is off"), "the key")
	check(BINDING_NAME_PSS_OPEN_ADDONS == "Open Addon Manager (Addon Manager off)", "the key's label: " .. tostring(BINDING_NAME_PSS_OPEN_ADDONS))
	check(has(pss("help"), "(off)"), "help marks it off")
	-- the window opens without the tab
	SlashCmdList["PSS"]("gui")
	check(_G.PSS_Window and #_G.PSS_Window.tabs == 5, "tabs: " .. tostring(_G.PSS_Window and #_G.PSS_Window.tabs))
	check(H.Private("PourSocialScore_GUI").PageBuilders.addons == nil, "the Addons page builder exists")
end

function phases.addonson()
	check(type(SlashCmdList["PSSACP"]) == "function", "no /acp")
	check(#AddonCompartmentFrame.registered == 2, "compartment entries: " .. #AddonCompartmentFrame.registered)
	check(M.PSS_Need("Libraries") and type(M.PSS_AddonList) == "function" and type(M.PSS_AddonCommand) == "function", "the addon manager did not load")
	check(keysOf(M.PSS_UI_TABS) == "players,guilds,filters,addons,events", "tabs: " .. keysOf(M.PSS_UI_TABS))
	check(BINDING_NAME_PSS_OPEN_ADDONS == "Open Addon Manager", "the key's label")
	check(not has(pss("acp api"), "The Addon Manager is off"), "/pss acp says off")
end

function phases.gfxoff()
	check(M.PSS_Need("Libraries"), "Libraries")
	check(M.PSS_GfxOpen == nil, "the graphics file loaded while off")
	local l = pss("gfx")
	if camelot then
		check(has(l, "The Graphics Settings Exporter is off"), "/pss gfx: " .. table.concat(l, "|"))
	else
		check(has(l, "Camelot only"), "Retail: " .. table.concat(l, "|"))
	end
end

function phases.gfxon()
	check(M.PSS_Need("Libraries"), "Libraries")
	if camelot then
		check(type(M.PSS_GfxOpen) == "function", "no graphics logic on Camelot with it on")
	else
		check(M.PSS_GfxOpen == nil, "Retail defines nothing")
	end
end

function phases.filteringoff()
	check(not M.PSS_On("filtering") and M.PSS_On("logging"), "filtering reads on, or logging was switched with it")
	check(#H.filters == 0, "chat filters registered: " .. #H.filters)
	check(hooksOn(C_FriendList) == 0, "C_FriendList hooks: " .. hooksOn(C_FriendList))
	for _, e in ipairs({ "PARTY_INVITE_REQUEST", "DUEL_REQUESTED", "TRADE_SHOW", "GUILD_INVITE_REQUEST", "CHAT_MSG_WHISPER_INFORM", "IGNORELIST_UPDATE" }) do
		check(H.Listeners(e) == 0, e .. " is heard")
	end
	check(H.Listeners("UPDATE_MOUSEOVER_UNIT") == 0 and H.Listeners("PLAYER_TARGET_CHANGED") == 0, "capture is on")
	check(M.PSS_ExpireEntries() == 0, "expiry ran")
	check(M.PSS_Need("Libraries"), "Libraries")
	SlashCmdList["PSS"]("gui")
	local win = _G.PSS_Window
	check(win.offNote and win.offNote:IsShown() and win.offNote:GetText():find("nothing is blocked", 1, true), "the list tab does not say it")
	win.tabs[4]._scripts.OnClick(win.tabs[4])
	check(not win.offNote:IsShown(), "the note shows on the Addon Manager")
	check(keysOf(M.PSS_UI_TABS):find("events", 1, true), "Events tab gone with filtering off (logging is independent)")
end

function phases.filteringon()
	check(M.PSS_On("filtering"), "filtering off")
	check(#H.filters > 0, "no chat filter registered")
	check(hooksOn(C_FriendList) >= 1, "no ignore hooks")
	check(H.Listeners("PARTY_INVITE_REQUEST") == 1 and H.Listeners("DUEL_REQUESTED") == 1 and H.Listeners("TRADE_SHOW") == 1, "block events not heard")
	check(H.Listeners("IGNORELIST_UPDATE") >= 1, "the ignore sync is not heard")
	check(M.PSS_Need("Libraries"), "Libraries")
	SlashCmdList["PSS"]("gui")
	check(not _G.PSS_Window.offNote:IsShown(), "the off note shows with filtering on")
end

function phases.loggingoff()
	check(not M.PSS_On("logging") and M.PSS_On("filtering"), "logging reads on")
	local History = M.PSS_History
	local counts = {}
	local before = stored()
	History.Add("p:Someone-Realm", counts, { cat = "whisper", ts = 1790000000 })
	check((counts.whisper or 0) == 1 and (counts.total or 0) == 1, "the block was not counted")
	check(stored() == before, "a line was stored")
	check(M.PSS_Need("Libraries"), "Libraries")
	check(not keysOf(M.PSS_UI_TABS):find("events", 1, true) and M.PSS_UI_EVENTS_TAB == nil, "Events tab listed: " .. keysOf(M.PSS_UI_TABS))
	SlashCmdList["PSS"]("gui")
	check(H.Private("PourSocialScore_GUI").OpenEvents == nil, "the Events tab code loaded")
end

function phases.loggingon()
	check(M.PSS_On("logging"), "logging off")
	local History = M.PSS_History
	local counts = {}
	local before = stored()
	History.Add("p:Someone-Realm", counts, { cat = "whisper", ts = 1790000000 })
	check(stored() == before + 1 and (counts.total or 0) == 1, "the line was not stored with logging on")
	check(M.PSS_Need("Libraries"), "Libraries")
	check(M.PSS_UI_EVENTS_TAB == 5 or camelot or M.PSS_UI_EVENTS_TAB ~= nil, "no Events tab")
end

-- a reload: set and save (reloadset), then load the saved file (reloadread)
function phases.reloadset()
	M.PSS_SetOpt("useAddons", "global", true)
	M.PSS_SetOpt("useFiltering", "global", false)
	M.PSS_SetOpt("useGfx", "global", true)
	PSS_OptionsDB.newerComponentKey = { 1, 2 }	-- a newer version's key must survive
end

function phases.reloadread()
	check(M.PSS_On("addons") and not M.PSS_On("filtering") and M.PSS_On("logging"), "the saved choices were not applied")
	check(M.PSS_On("gfx") == camelot, "gfx")
	check(#H.filters == 0 and type(SlashCmdList["PSSACP"]) == "function", "the session did not start as saved")
	check(PSS_OptionsDB.newerComponentKey and PSS_OptionsDB.newerComponentKey[2] == 2, "a newer key was lost")
end

phases[phase]()
if not fail then print("PASS components " .. phase) end
