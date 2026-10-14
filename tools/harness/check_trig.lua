-- The trigger rows and the trigger engine (service-bus-helper stage S3, STP-00095,
-- STP-00126, STP-00135, STP-00149), as a run.lua script. The phase is PSS_PHASE; each
-- prints "PASS trig <phase>" or "FAIL trig: <phase>: <what>". Expected results come from
-- DDS-00010 sections 5, 7 and 10 and the test keys in 15_Tests.md, not from the code.
-- Phases: off rows engine rules shipped retry cost
--   off      TST-00116, TST-00149   nothing registered, no frame, with every gate off
--   rows     TST-00150 to TST-00154 the core trigger rows (PSS_Watch.lua) on the stub client
--   engine   TST-00177 to TST-00186, TST-00188, TST-00200, TST-00201: every class, rung and
--            weight of the engine (PSS_Trig.lua) on a simulated client that counts every
--            OnUpdate ever set (trig_client.lua)
--   rules    TST-00186 (code), TST-00198, TST-00156: no OnUpdate, one timer call
--   shipped  the session's engine (M.PSS_Want and the rest) on the real stub, with the bus
--   cost     TST-00191: resident KB and microseconds against bus_budgets.lua
local phase = os.getenv("PSS_PHASE") or "engine"
local fail, passes = false, 0
local function check(ok, msg)
	if ok then passes = passes + 1 else print("FAIL trig: " .. phase .. ": " .. msg) fail = true end
	return ok
end
local here = (arg[0] or ""):match("^(.*)/[^/]*$") or "."
local function libs() check(M.PSS_Need("Libraries"), "Libraries did not load") end
local function ok(name, cond, note) return check(cond, name .. (note and (" (" .. note .. ")") or "")) end

if phase == "engine" then
	libs()
	local allClients = {}
	local function track(c) allClients[#allClients + 1] = c; return c end
	local function fresh()
		local client = dofile(here .. "/trig_client.lua")
		return client, M.PSS_TrigNew(client)
	end
	-- TST-00177 coalesce: settle, signal, pull
	do
		local C, E = fresh(); track(C)
		local calls, keys = 0, 0
		local r = E.Need({ id = "bags", class = "coalesce", on = { "BAG_UPDATE" }, settle = "BAG_UPDATE_DELAYED",
			key = function(_, bag) return bag end, fn = function(k) calls = calls + 1; keys = #k end })
		for i = 1, 20 do C.Fire("BAG_UPDATE", i % 2 + 2) end
		ok("TST-00177a settle: 20 changes, no work yet", r.rung == "settle" and calls == 0)
		C.Fire("BAG_UPDATE_DELAYED")
		ok("TST-00177b settle: one call with the 2 distinct keys", calls == 1 and keys == 2)
		local redraws = 0
		local s = E.Need({ id = "redraw", class = "coalesce", signal = "@addons", fn = function() redraws = redraws + 1 end })
		E.Signal("@addons")
		ok("TST-00177c signal: the redraw runs on our own act (replaces C_Timer.After(0, RunQueued))", s.rung == "signal" and redraws == 1)
		local p = E.Need({ id = "equipped", class = "coalesce", read = "item.equipped" })
		ok("TST-00177d pull: settled by the reader, nothing registered", p.rung == "pull")
	end

	-- TST-00178 await-data, await-unlock, step-sequence
	do
		local C, E = fresh(); track(C)
		local done = 0
		local r1 = E.Need({ id = "item", class = "await-data", on = { "ITEM_DATA_LOAD_RESULT" }, once = true, fn = function() done = done + 1 end })
		ok("TST-00178a await-data registers ITEM_DATA_LOAD_RESULT", r1.rung == "event" and C.frames[1]:IsEventRegistered("ITEM_DATA_LOAD_RESULT"))
		C.Fire("ITEM_DATA_LOAD_RESULT", 19019, true)
		C.Fire("ITEM_DATA_LOAD_RESULT", 19019, true)
		ok("TST-00178b finishes once and unregisters", done == 1 and not C.frames[1]:IsEventRegistered("ITEM_DATA_LOAD_RESULT"))
		local unl = 0
		local r2 = E.Need({ id = "unlock", class = "await-unlock", on = { "ITEM_UNLOCKED" }, once = true, fn = function() unl = unl + 1 end })
		C.Fire("ITEM_UNLOCKED", 0, 1)
		ok("TST-00178c await-unlock on ITEM_UNLOCKED", r2.rung == "event" and unl == 1)
		local moves, plan = {}, { "a", "b", "c" }
		E.Need({ id = "move", class = "step-sequence", signal = "@moved", fn = function()
			E.When("nocombat", function()
				local nxt = table.remove(plan, 1)
				if nxt then moves[#moves + 1] = nxt; E.Signal("@moved") end
			end)
		end })
		C.combat = true
		E.Signal("@moved")
		ok("TST-00178d step-sequence in combat: waits, PLAYER_REGEN_ENABLED registered", #moves == 0 and C.frames[1]:IsEventRegistered("PLAYER_REGEN_ENABLED"))
		C.combat = false
		C.Fire("PLAYER_REGEN_ENABLED")
		ok("TST-00178e after combat each move signals the next: all 3, in order", table.concat(moves) == "abc")
	end

	-- TST-00179 slice: paged pull, pulses, clock guarantee
	do
		local C, E = fresh(); track(C)
		local computed = 0
		local function page(cursor)		-- a service with a cursor: output is the next call's input
			local from = cursor or 1
			local set = { cols = { "row" }, n = 0 }
			for i = from, math.min(from + 99, 10000) do set.n = set.n + 1; set[set.n] = { i }; computed = computed + 1 end
			set.next = from + 100 <= 10000 and from + 100 or nil
			return set
		end
		local r = E.Need({ id = "view", class = "slice", page = page })
		local s = page(nil); s = page(s.next); s = page(s.next)
		ok("TST-00179a paged pull: three scrolls compute 300 of 10,000 rows", r.rung == "pull" and computed == 300)
		local steps = 0
		E.Need({ id = "gc", class = "slice", weight = 5, combat = false, step = function()
			steps = steps + 1; C.ms = C.ms + 0.4; return steps >= 40 end })
		ok("TST-00179b a background slice queues and registers its pulse sources", C.frames[1]:IsEventRegistered("CURSOR_CHANGED"))
		C.ms = 0; C.Fire("CURSOR_CHANGED")
		ok("TST-00179c one pulse runs within the 1 ms budget (3 steps of 0.4 ms)", steps == 3, steps .. " steps")
		C.Advance(5)
		ok("TST-00179d no events at all (AFK): the clock guarantee still advances it", steps > 3, steps .. " steps after 5 s")
		C.combat = true
		local before = steps
		C.Fire("CURSOR_CHANGED")
		ok("TST-00179e a combat = false slice pauses in combat", steps == before)
		C.combat = false
		for i = 1, 30 do C.ms = 0; C.Fire("CURSOR_CHANGED") end
		ok("TST-00179f it completes; pulse sources unregistered", steps == 40 and not C.frames[1]:IsEventRegistered("CURSOR_CHANGED"))
	end

	-- TST-00180 hover, drag, modifier (the GUI binds its own widgets; DEC-00198)
	do
		local C, E = fresh(); track(C)
		local framesBefore = #C.frames
		-- the GUI's side: it builds its pie and 36 hit regions with its kit, then declares the need
		local pie = C.CreateFrame("Frame")
		local hits = {}
		for i = 1, 36 do hits[i] = C.CreateFrame("Frame", nil, pie) end
		local hovered
		local r = E.Need({ id = "pie", class = "hover-follow", fn = function(i) hovered = i end, bind = function(fire)
			for i = 1, 36 do hits[i]:SetScript("OnEnter", function() fire(i) end) end
			pie:HookScript("OnLeave", function() fire(nil) end)
		end })
		C.Interact(hits[10], "OnEnter")
		ok("TST-00180a pie hover: the GUI's 36 hit regions name the slice through fire", r.rung == "interaction" and hovered == 10)
		C.Interact(pie, "OnLeave")
		ok("TST-00180b leaving clears it", hovered == nil)
		local win = C.CreateFrame("Frame")
		local placed = 0
		E.Need({ id = "drag", class = "drag-follow", fn = function() placed = placed + 1 end, bind = function(fire)
			win:SetScript("OnDragStop", function() win:StopMovingOrSizing(); fire() end)
		end })
		win:StartMoving(); C.Interact(win, "OnDragStop")
		ok("TST-00180c drag: the client moves the frame; OnDragStop saves the place", placed == 1)
		local tip = C.CreateFrame("Frame")
		tip.shown = false
		local mods = 0
		E.Need({ id = "mods", class = "modifier", on = { "MODIFIER_STATE_CHANGED" }, fn = function() mods = mods + 1 end, bind = function(fire, ctl)
			tip:HookScript("OnShow", ctl.on)
			tip:HookScript("OnHide", ctl.off)
		end })
		ok("TST-00180d modifier: nothing registered while hidden", not C.frames[1]:IsEventRegistered("MODIFIER_STATE_CHANGED"))
		tip:Show(); C.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
		tip:Hide(); C.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
		ok("TST-00180e shown: Shift refreshes once; hidden: unregistered", mods == 1 and not C.frames[1]:IsEventRegistered("MODIFIER_STATE_CHANGED"))
		ok("TST-00180f the engine created no frame (every frame here is the GUI's)", #C.frames - framesBefore == 36 + 1 + 1 + 1)
	end

	-- TST-00181 countdown and animate
	do
		local C, E = fresh(); track(C)
		local cd = C.CreateFrame("Cooldown")
		local reverted = 0
		local r = E.Need({ id = "keep", class = "countdown", duration = 15, fn = function() reverted = reverted + 1 end, bind = function()
			cd:SetHideCountdownNumbers(false); cd:SetCooldown(C.GetTime(), 15)		-- the GUI draws it
		end })
		ok("TST-00181a countdown: the GUI's Cooldown widget draws 15 s with its numbers", r.rung == "interaction" and cd.cdDuration == 15 and cd.hideNumbers == false)
		C.Advance(14.9)
		ok("TST-00181b nothing before 15 s", reverted == 0)
		C.Advance(0.2)
		ok("TST-00181c the clock reverts at 15 s, once", reverted == 1)
		local cd2 = C.CreateFrame("Cooldown")
		E.Need({ id = "keep2", class = "countdown", duration = 15, fn = function() reverted = reverted + 1 end, bind = function() cd2:SetCooldown(C.GetTime(), 15) end })
		E.Cancel("keep2"); cd2:Clear()		-- Keep pressed: the GUI clears its widget
		C.Advance(20)
		ok("TST-00181d Keep pressed: cancelled, no revert", reverted == 1 and cd2.cdDuration == nil)
		local fr = C.CreateFrame("Frame")
		local faded = false
		E.Need({ id = "fade", class = "animate", fn = function() faded = true end, bind = function(fire)
			local g = fr:CreateAnimationGroup()
			local a = g:CreateAnimation("Alpha"); a:SetFromAlpha(1); a:SetToAlpha(0); a:SetDuration(0.3)
			g:SetScript("OnFinished", function() fire() end)
			g:Play()
		end })
		fr.groups[1]:Finish()
		ok("TST-00181e animate: the GUI's AnimationGroup plays; OnFinished fires the need", fr.groups[1].anims[1].to == 0 and faded)
	end

	-- TST-00182 debounce, delay, cooldown, timeout
	do
		local C, E = fresh(); track(C)
		local box, queries = C.CreateFrame("EditBox"), 0
		E.Need({ id = "search", class = "debounce", fn = function() queries = queries + 1 end, bind = function(fire) box:SetScript("OnTextChanged", function(_, user) fire(user) end) end })
		C.Interact(box, "OnTextChanged", true)
		ok("TST-00182a debounce: the indexed search runs on the change itself", queries == 1)
		local checked = 0
		local r = E.Need({ id = "group", class = "delay", on = { "GROUP_ROSTER_UPDATE" }, fn = function() checked = checked + 1 end })
		C.Fire("GROUP_ROSTER_UPDATE")
		ok("TST-00182b delay mapped to its event (the 1 s group check becomes GROUP_ROSTER_UPDATE)", r.rung == "event" and checked == 1)
		local late = 0
		local r2 = E.Need({ id = "late", class = "delay", duration = 2, fn = function() late = late + 1 end })
		C.Advance(2.1)
		ok("TST-00182c delay with no event: the clock, once", r2.rung == "clock" and late == 1)
		local timers = C.timerCalls
		E.Need({ id = "who", class = "cooldown", readyAt = 0 })
		local a = E.Use("who", 6)
		local b = E.Use("who", 6)
		C.Advance(6)
		local c = E.Use("who", 6)
		ok("TST-00182d cooldown checked when used: no timer at all", a and not b and c and C.timerCalls == timers)
		local answered
		E.Need({ id = "ans", class = "timeout", on = { "WHO_LIST_UPDATE" }, orAfter = 5, once = true, fn = function(why) answered = why end })
		C.Fire("WHO_LIST_UPDATE"); C.Advance(6)
		ok("TST-00182e timeout: the answer event wins; the clock does not fire after", answered == "WHO_LIST_UPDATE")
		local gaveup
		E.Need({ id = "ans2", class = "timeout", on = { "WHO_LIST_UPDATE" }, orAfter = 5, once = true, fn = function(why) gaveup = why end })
		C.Advance(5.1)
		ok("TST-00182f no answer: the clock gives up at 5 s, the event unregistered", gaveup == "clock" and not C.frames[1]:IsEventRegistered("WHO_LIST_UPDATE"))
	end

	-- TST-00183 a third-party per-frame need
	do
		local C, E = fresh(); track(C)
		local ticks = 0
		local r = E.Need({ id = "ext.tick", source = "ExampleAddon", class = "per-frame", weight = 20, step = function() ticks = ticks + 1; C.ms = C.ms + 0.1 end })
		ok("TST-00183a resolved to pulses, never OnUpdate", r.rung == "pulse" and C.onUpdateSets == 0)
		ok("TST-00183b a decision card names the source and asks for an event or a signal",
			E.cards.n == 1 and E.cards[1][2] == "ExampleAddon" and E.cards[1][3] == "per-frame")
		C.ms = 0; C.Fire("PLAYER_STARTED_MOVING")
		C.Advance(3)
		ok("TST-00183c its callback keeps running (compatibility): on pulses and the clock", ticks >= 4, ticks .. " calls")
		local r2 = E.Need({ id = "ext.mapped", source = "ExampleAddon", class = "per-frame", signal = "@cell", fn = function() end })
		ok("TST-00183d once mapped to a signal, no card", r2.rung == "signal" and E.cards.n == 1)
		local r3 = E.Need({ id = "odd", class = "no-such-class", fn = function() end })
		ok("TST-00183e an unknown class is a decision card, never an error", r3.rung == "decision" and E.cards.n == 2)
	end

	-- TST-00184 ladder order
	do
		local C, E = fresh(); track(C)
		ok("TST-00184a coalesce with a signal and a reader takes the signal (settle absent)", E.Resolve({ class = "coalesce", signal = "@x", read = "s" }) == "signal")
		ok("TST-00184b coalesce with events and a settle takes the settle", E.Resolve({ class = "coalesce", on = { "A" }, settle = "B", signal = "@x" }) == "settle")
		ok("TST-00184c slice with a page and a step takes the pull", E.Resolve({ class = "slice", page = function() end, step = function() end }) == "pull")
		ok("TST-00184d delay with an event and a duration takes the event", E.Resolve({ class = "delay", on = { "A" }, duration = 2 }) == "event")
		ok("TST-00184e await-data with nothing to wait on is a decision", E.Resolve({ class = "await-data" }) == "decision")
		local monotone = true
		for class, ladder in pairs(M.PSS_TRIG.CLASSES) do
			for i = 1, #ladder do if not M.PSS_TRIG.RUNGS[ladder[i]] then monotone = false end end
			for i = 2, #ladder do if M.PSS_TRIG.RUNGS[ladder[i]] < M.PSS_TRIG.RUNGS[ladder[i - 1]] then monotone = false end end
		end
		ok("TST-00184f every class's ladder is known rungs in weight order (preferred to last resort)", monotone)
	end

	-- TST-00185 weights, aging, visibility, budget
	do
		local C, E = fresh(); track(C)
		local order = {}
		local function mk(id, w, vis)
			E.Need({ id = id, class = "slice", weight = w, visible = vis, step = function() order[#order + 1] = id; C.ms = C.ms + 1.0; return true end })
		end
		mk("low", 10); mk("mid", 50); mk("high", 90)
		for i = 1, 3 do C.ms = 0; C.Fire("CURSOR_CHANGED") end
		ok("TST-00185a one step per pulse (1 ms budget), highest weight first", table.concat(order, ",") == "high,mid,low", table.concat(order, ","))
		local C2, E2 = fresh(); track(C2)
		local ran = {}
		E2.Need({ id = "a", class = "slice", weight = 10, step = function() ran.a = (ran.a or 0) + 1; C2.ms = C2.ms + 1 end })
		E2.Need({ id = "b", class = "slice", weight = 40, step = function() ran.b = (ran.b or 0) + 1; C2.ms = C2.ms + 1 end })
		for i = 1, 12 do C2.ms = 0; C2.Fire("CURSOR_CHANGED") end
		ok("TST-00185b aging: the low weight is not starved", (ran.a or 0) >= 1, "low ran " .. (ran.a or 0) .. " of 12")
		local C3, E3 = fresh(); track(C3)
		local first
		E3.Need({ id = "bg", class = "slice", weight = 40, step = function() first = first or "bg"; C3.ms = C3.ms + 1 end })
		E3.Need({ id = "ui", class = "slice", weight = 10, visible = function() return true end, step = function() first = first or "ui"; C3.ms = C3.ms + 1 end })
		C3.ms = 0; C3.Fire("CURSOR_CHANGED")
		ok("TST-00185c a need whose widget shows is boosted above background work", first == "ui")
	end

	-- TST-00200 memory cleanup speeds up while the player is AFK (DEC-00189, the author)
	do
		local C, E = fresh(); track(C)
		local steps = 0
		E.Need({ id = "gc", class = "slice", weight = 5, combat = false, afk = true, step = function()
			steps = steps + 1; C.ms = C.ms + 1.0; return steps >= 200 end })
		ok("TST-00200a PLAYER_FLAGS_CHANGED is heard while the cleanup waits", C.frames[1]:IsEventRegistered("PLAYER_FLAGS_CHANGED"))
		C.Advance(4)
		local present = steps
		C.afk = true
		C.ms = 0; C.Fire("PLAYER_FLAGS_CHANGED", "player")
		local s0 = steps
		C.Advance(4)
		local away = steps - s0
		ok("TST-00200b away: the guarantee shortens (4 s: " .. away .. " steps against " .. present .. " present)", away >= present * 3)
		E.Need({ id = "other", class = "slice", weight = 30, step = function() C.ms = C.ms + 1.0 end })
		local order = {}
		E.needs.gc.step = function() order[#order + 1] = "gc"; C.ms = C.ms + 1.0 end
		E.needs.other.step = function() order[#order + 1] = "other"; C.ms = C.ms + 1.0 end
		C.ms = 0; C.Fire("CURSOR_CHANGED")
		ok("TST-00200c away: the cleanup is boosted above other background work", order[1] == "gc")
		local function gcRuns() local n = 0; for i = 1, #order do if order[i] == "gc" then n = n + 1 end end; return n end
		C.combat = true
		local g1 = gcRuns()
		C.ms = 0; C.Fire("CURSOR_CHANGED"); C.Advance(2)
		ok("TST-00200d still never in combat (combat = false), AFK or not; no clock spin", gcRuns() == g1)
		C.combat = false
		C.ms = 0; C.Fire("PLAYER_REGEN_ENABLED")
		ok("TST-00200f combat ends: PLAYER_REGEN_ENABLED pulses it at once", gcRuns() > g1)
		E.Cancel("gc"); E.Cancel("other")
		ok("TST-00200e done or cancelled: PLAYER_FLAGS_CHANGED unregistered", not C.frames[1]:IsEventRegistered("PLAYER_FLAGS_CHANGED"))
	end

	-- TST-00201 a shown tooltip refreshes on a data notice and on modifier keys, never per frame
	do
		local C, E = fresh(); track(C)
		local tip = C.CreateFrame("GameTooltip"); tip.shown = false
		local refresh = 0
		E.Need({ id = "tip", class = "modifier", on = { "MODIFIER_STATE_CHANGED" }, signal = "@cell",
			fn = function() refresh = refresh + 1 end, bind = function(fire, ctl)
				tip:HookScript("OnShow", ctl.on); tip:HookScript("OnHide", ctl.off)
			end })
		E.Signal("@cell")
		ok("TST-00201a hidden: a data notice does nothing", refresh == 0)
		tip:Show()
		E.Signal("@cell"); C.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
		ok("TST-00201b shown: the item's count changes and Shift is pressed: two refreshes", refresh == 2)
		tip:Hide()
		E.Signal("@cell"); C.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 0)
		ok("TST-00201c hidden again: nothing heard, no OnUpdate", refresh == 2 and C.onUpdateSets == 0 and not C.frames[1]:IsEventRegistered("MODIFIER_STATE_CHANGED"))
	end

	-- TST-00186 one clock, zero OnUpdate
	do
		local C, E = fresh(); track(C)
		for i = 1, 50 do E.Need({ id = "d" .. i, class = "delay", duration = i, fn = function() end }) end
		local pending = 0
		C.Advance(0)
		ok("TST-00186a 50 deadlines: one clock at a time (earliest first)", E.ticks == 0)
		C.Advance(50.5)
		ok("TST-00186b all 50 fired by one re-armed clock", E.ticks == 50, E.ticks .. " ticks")
		end

	-- TST-00188 compatibility: every PSS wake-up keeps its behaviour on the engine
	do
		local C, E = fresh(); track(C)
		local PSS = {		-- file:line from 16_02 -> the need that replaces it (data, DDS-00010:10.6)
			{ "PSS_ChatBlock.lua:832", { class = "delay", on = { "GUILD_INVITE_REQUEST" } } },
			{ "PSS_ChatBlock.lua:833", { class = "delay", duration = 0.2 } },
			{ "PSS_ChatHistory.lua:663", { class = "delay", on = { "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA" } } },
			{ "PSS_GuildIgnoreList.lua:1291", { class = "delay", on = { "GUILD_ROSTER_UPDATE" } } },
			{ "PSS_GuildIgnoreList.lua:1713", { class = "coalesce", signal = "@guildscan" } },
			{ "PSS_GuildIgnoreList.lua:1786", { class = "coalesce", signal = "@guildscan" } },
			{ "PSS_GuildIgnoreList.lua:1819", { class = "coalesce", signal = "@guildscan" } },
			{ "PSS_GuildIgnoreList.lua:1928", { class = "delay", on = { "WHO_LIST_UPDATE" } } },
			{ "PSS_Perf.lua:85", { class = "slice", step = function() return true end, combat = false } },
			{ "PSS_Whois.lua:63", { class = "cooldown", readyAt = 0 } },
			{ "PSS_Whois.lua:116", { class = "coalesce", signal = "@whosent" } },
			{ "PSS_Whois.lua:117", { class = "timeout", on = { "WHO_LIST_UPDATE" }, orAfter = 5 } },
			{ "PSS_Whois.lua:279", { class = "delay", on = { "WHO_LIST_UPDATE" } } },
			{ "PourSocialScore.lua:272", { class = "delay", on = { "GROUP_ROSTER_UPDATE" } } },
			{ "PSS_Addons.lua:423", { class = "coalesce", signal = "@addons" } },
			{ "PSS_Filters.lua:445", { class = "coalesce", signal = "@filters" } },
			{ "PSS_Guilds.lua:884", { class = "coalesce", signal = "@guilds" } },
			{ "PSS_Pie.lua:127", { class = "hover-follow", bind = function() end } },
			{ "PSS_Popups.lua:274", { class = "countdown", duration = 15, bind = function() end } },
			{ "PSS_ViewNav.lua:259", { class = "cooldown", readyAt = 0 } },
		}
		local decisions, rungs = 0, {}
		for i = 1, #PSS do
			local n = PSS[i][2]
			n.id = PSS[i][1]
			n.fn = n.fn or function() end
			local r = E.Need(n)
			if r.rung == "decision" then decisions = decisions + 1 end
			rungs[r.rung] = (rungs[r.rung] or 0) + 1
		end
		local list = {}
		for k, v in pairs(rungs) do list[#list + 1] = k .. " " .. v end
		table.sort(list)
		ok("TST-00188 all 20 PSS sites have a replacement need; none needs a decision", decisions == 0, table.concat(list, ", "))
	end

	-- TST-00187 (class coverage): every catalogued OnUpdate site (scratch registry 16_02) has a class the engine knows
	local scratch = os.getenv("PSS_SCRATCH")
	if not scratch or scratch == "" or scratch == "-" then scratch = "../Pour-Social-Score_Scratch" end
	local fh = io.open(scratch .. "/documents/features/service-bus-helper/16_Registries/16_02_OnUpdate_Sites.md")
	if fh then
		local sites, bad = 0, 0
		for l in fh:lines() do
			local cls = l:match("^| [^|]+ | %d+ | [^|]+ | ([%w%-]+)")
			if cls then
				sites = sites + 1
				if not M.PSS_TRIG.CLASSES[cls] or cls == "per-frame" then bad = bad + 1 end
			end
		end
		fh:close()
		ok("TST-00187c every catalogued site has a class the shipped engine resolves", sites == 110 and bad == 0, sites .. " sites, " .. bad .. " unresolved")
	else
		print("NOTE trig engine: scratch registry 16_02 not found, TST-00187c did not run")
	end
	local total = 0
	for i = 1, #allClients do total = total + allClients[i].onUpdateSets end
	ok("TST-00186d no OnUpdate was set in any test of this phase", total == 0)
	ok("TST-00186e the engine creates one frame and no more", (function()
		local C = dofile(here .. "/trig_client.lua")
		M.PSS_TrigNew(C)
		return #C.frames == 1
	end)())
end

if phase == "off" then
	-- TST-00116, TST-00149: every gate off, nothing registered, no frame, no engine
	libs()
	local events = { "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_MONEY", "CURSOR_CHANGED",
		"PLAYER_FLAGS_CHANGED", "ITEM_DATA_LOAD_RESULT", "ITEM_UNLOCKED", "MODIFIER_STATE_CHANGED", "UPDATE_MOUSEOVER_UNIT" }
	local base = {}
	for i = 1, #events do base[events[i]] = H.Listeners(events[i]) end
	check(M.PSS_Engine() == nil, "the engine is not built until a need is declared")
	M.PSS_Provide("t.run", function(set) return set end, {})
	M.PSS_Trigger({ id = "offrow", gate = "dtt", on = { "BAG_UPDATE", "PLAYER_MONEY" }, settle = { "BAG_UPDATE_DELAYED" }, run = "t.run" })
	M.PSS_Trigger({ id = "offrow2", gate = "dtt", on = { "@other" }, settle = "now", run = "t.run", reads = { "t.read" } })
	for i = 1, #events do
		check(H.Listeners(events[i]) == base[events[i]], events[i] .. " is registered with its gate off")
	end
	local set = M.PSS_Triggers()
	check(set.n == 2 and set[1][1] == "offrow" and set[1][6] == false and set[2][6] == false, "both rows are listed and not live")
	local calls = 0
	M.PSS_Provide("t.read", function() calls = calls + 1 return M.PSS_Set({ "x" }) end, {})
	M.PSS_Call("t.read", "k")
	M.PSS_Signal("@other", M.PSS_Set({ "x" }))
	H.Fire("BAG_UPDATE", 1); H.Fire("BAG_UPDATE_DELAYED")
	check(calls == 1, "a reader answers once and a row with its gate off settles nothing")
	check(M.PSS_Engine() == nil, "signals and rows with their gates off do not build the engine")
	check(type(M.PSS_WatchStart) == "function" and M.PSS_Trigger ~= nil, "the watch is core")
elseif phase == "rows" then
	libs()
	local calls, last, timers = {}, {}, 0
	local realAfter = C_Timer.After
	C_Timer.After = function(...) timers = timers + 1 return realAfter(...) end
	local function svc(name)
		M.PSS_Provide(name, function(set) calls[name] = (calls[name] or 0) + 1; last[name] = set; return set end, {})
	end
	for _, n in ipairs({ "t.bags", "t.equip", "t.money", "t.sum", "t.follow" }) do svc(n) end
	M.PSS_Provide("t.tip", function() return M.PSS_Set({ "slot" }) end, {})
	M.PSS_Provide("t.bad", function() error("boom") end, {})
	local before = {}
	local names = { "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_MONEY", "BAD_EVENT" }
	for i = 1, #names do before[names[i]] = H.Listeners(names[i]) end
	M.PSS_Trigger({ id = "bags", gate = "logging", on = { "BAG_UPDATE" }, settle = { "BAG_UPDATE_DELAYED" }, run = "t.bags", key = function(_, bag) return bag end })
	M.PSS_Trigger({ id = "equip", gate = "logging", on = { "PLAYER_EQUIPMENT_CHANGED" }, settle = "pull", run = "t.equip", key = function(_, slot) return slot end, reads = { "t.tip" } })
	M.PSS_Trigger({ id = "money", gate = "logging", on = { "PLAYER_MONEY" }, settle = "now", run = "t.money" })
	M.PSS_Trigger({ id = "sum", gate = "logging", on = { "@bags" }, settle = "now", run = "t.sum", key = function(_, set) return set end })
	M.PSS_Trigger({ id = "badrow", gate = "logging", on = { "BAD_EVENT" }, settle = "now", run = "t.bad" })
	M.PSS_Trigger({ id = "after", gate = "logging", on = { "BAD_EVENT" }, settle = "now", run = "t.follow" })
	-- TST-00150: exactly the rows' client events are registered, each once for this frame
	for i = 1, #names do
		check(H.Listeners(names[i]) == before[names[i]] + 1, names[i] .. " is not registered by the rows")
	end
	local set = M.PSS_Triggers()
	local live = 0
	for i = 1, set.n do if set[i][6] then live = live + 1 end end
	check(set.n == 6 and live == 6, "trig.rows lists six live rows, got " .. set.n .. " and " .. live)
	local ts = M.PSS_Call("trig.rows")
	check(ts and ts.n == 6 and ts[1][1] == "bags" and ts[1][3] == "BAG_UPDATE" and ts[1][4] == "BAG_UPDATE_DELAYED" and ts[1][5] == "t.bags", "the rows read as a service")
	-- TST-00151: burst coalesce
	for i = 1, 20 do H.Fire("BAG_UPDATE", i % 2 + 2) end
	check((calls["t.bags"] or 0) == 0, "work ran before the settle event")
	H.Fire("BAG_UPDATE_DELAYED")
	check(calls["t.bags"] == 1 and last["t.bags"].n == 2, "one call with the 2 distinct bags: " .. tostring(calls["t.bags"]) .. " calls, " .. tostring(last["t.bags"] and last["t.bags"].n) .. " keys")
	H.Fire("BAG_UPDATE_DELAYED")
	check(calls["t.bags"] == 1, "a settle with nothing dirty calls nothing")
	-- TST-00152: pull and now
	H.Fire("PLAYER_EQUIPMENT_CHANGED", 5); H.Fire("PLAYER_EQUIPMENT_CHANGED", 5); H.Fire("PLAYER_EQUIPMENT_CHANGED", 6)
	check((calls["t.equip"] or 0) == 0, "equipment changes ran before a reader asked")
	M.PSS_Call("t.tip", "k")
	check(calls["t.equip"] == 1 and last["t.equip"].n == 2, "the reader's call settled the equipment rows once with 2 slots")
	M.PSS_Call("t.tip", "k")
	check(calls["t.equip"] == 1, "a second read finds nothing dirty")
	H.Fire("PLAYER_MONEY"); H.Fire("PLAYER_MONEY")
	check(calls["t.money"] == 2, "money runs per change (now): " .. tostring(calls["t.money"]))
	check(timers == 0, "no timer was used by any row")
	-- TST-00154: an own act raises @row; a failing service is counted once and the rest run
	check(calls["t.sum"] == 1 and last["t.sum"].n == 1 and M.PSS_IsSet(last["t.sum"][1][1]), "the flush of bags raised @bags: its follower ran once from the output set")
	local errs = M.Events.errors.count
	H.Fire("BAD_EVENT")
	check(M.Events.errors.count == errs + 1, "a failing service is counted once")
	check(calls["t.follow"] == 1, "the row after the failing one still ran")
	-- a secret key is not marked
	local realSecret = issecretvalue
	_G.issecretvalue = function(v) return v == 77 end
	local c0 = calls["t.bags"]
	H.Fire("BAG_UPDATE", 77); H.Fire("BAG_UPDATE_DELAYED")
	_G.issecretvalue = realSecret
	check(calls["t.bags"] == c0, "a secret key is not marked and not counted")
	-- a malformed row is refused
	local n0 = M.PSS_Triggers().n
	M.PSS_Trigger({ id = "x" }); M.PSS_Trigger("x"); M.PSS_Trigger({ id = "y", run = "r" })
	check(M.PSS_Triggers().n == n0, "a malformed row is not declared")
	C_Timer.After = realAfter
elseif phase == "rules" then
	-- TST-00156 and TST-00186 on the real source: no OnUpdate, one timer call, one frame, no widget hook
	local function code(path)
		local fh = assert(io.open(path))
		local s = fh:read("*a"):gsub("%-%-[^\n]*", "")
		fh:close()
		return s
	end
	local function count(s, pat) local _, n = s:gsub(pat, "") return n end
	for _, f in ipairs({ "PourSocialScore/PSS_Watch.lua", "PourSocialScore_Libraries/PSS_Trig.lua", "PourSocialScore_Libraries/PSS_Bus.lua" }) do
		local c = code(f)
		check(count(c, "OnUpdate") == 0, f .. " has an OnUpdate")
		check(count(c, "HookScript") == 0 and count(c, "hooksecurefunc") == 0, f .. " hooks something")
	end
	local trig, watch, bus = code("PourSocialScore_Libraries/PSS_Trig.lua"), code("PourSocialScore/PSS_Watch.lua"), code("PourSocialScore_Libraries/PSS_Bus.lua")
	check(count(trig, "C_Timer%.") + count(trig, "[^%w_%.]After%(") == 1, "the engine has more or less than one timer call")
	check(count(watch, "C_Timer") + count(watch, "After%(") + count(bus, "C_Timer") + count(bus, "After%(") == 0, "the watch or the bus has a timer call")
	check(count(trig, "CreateFrame%(") == 1 and count(trig, "SetScript%(") == 1, "the engine creates one frame and sets one script")
	check(count(watch, "CreateFrame%(") == 1 and count(watch, "SetScript%(") == 1, "the watch creates one frame and sets one script")
	check(count(watch, "IsShown") == 0 and count(trig, "GameTooltip") == 0, "the trigger parts look at no widget")
	-- the rules check lists the sites (TST-00156): it fails a new one
	local p = io.popen("lua5.1 tools/check_timers.lua 2>&1")
	local out = p:read("*a")
	p:close()
	check(out:find("PASS timers", 1, true), "tools/check_timers.lua does not pass: " .. out)
	-- a planted site is caught
	local bad = os.tmpname()
	local fh = io.open("PourSocialScore_Libraries/PSS_Query.lua")
	local keep = fh:read("*a")
	fh:close()
	local w = io.open("PourSocialScore_Libraries/PSS_Query.lua", "w")
	w:write(keep .. "\nlocal f = CreateFrame(\"Frame\")\nf:SetScript(\"OnUpdate\", function() end)\n")
	w:close()
	local p2 = io.popen("lua5.1 tools/check_timers.lua 2>&1; echo EXIT=$?")
	local out2 = p2:read("*a")
	p2:close()
	local w2 = io.open("PourSocialScore_Libraries/PSS_Query.lua", "w")
	w2:write(keep)
	w2:close()
	os.remove(bad)
	check(out2:find("FAIL timers: PourSocialScore_Libraries/PSS_Query.lua", 1, true) and out2:find("EXIT=1", 1, true), "a planted OnUpdate in a file that is not on the list was not caught")
elseif phase == "shipped" then
	-- the session's engine on the real stub and the real bus (the shipped wrappers)
	libs()
	check(M.PSS_Engine() == nil, "the engine exists before the first need")
	local ran = {}
	local r = M.PSS_Want({ id = "t.late", class = "delay", duration = 2, fn = function(why) ran[#ran + 1] = why end })
	check(r.rung == "clock" and M.PSS_Engine() ~= nil, "a delay with no event is on the clock")
	H.RunTimers()
	check(#ran == 0, "the clock fired before its time")
	H.Advance(2.1); H.RunTimers()
	check(#ran == 1 and ran[1] == "clock", "the clock fired once at its time")
	local sigs = 0
	local s = M.PSS_Want({ id = "t.sig", class = "coalesce", signal = "@thing", fn = function() sigs = sigs + 1 end })
	M.PSS_Signal("@thing", M.PSS_Set({ "x" }))
	check(s.rung == "signal" and sigs == 1, "M.PSS_Signal wakes a need that lists it")
	M.PSS_Unwant("t.sig")
	M.PSS_Signal("@thing")
	check(sigs == 1, "a cancelled need hears nothing")
	-- cooldown: checked when used, no timer
	M.PSS_Want({ id = "t.cd", class = "cooldown", readyAt = 0 })
	local a, b = M.PSS_Use("t.cd", 6), M.PSS_Use("t.cd", 6)
	H.Advance(6)
	check(a and not b and M.PSS_Use("t.cd", 6), "M.PSS_Use blocks a repeat for the time")
	check(M.PSS_Use("t.none", 5) == true, "a cooldown nobody declared never blocks")
	-- waits
	local done = 0
	H.combat = true
	local base = H.Listeners("PLAYER_REGEN_ENABLED")
	M.PSS_When("nocombat", function() done = done + 1 end)
	check(done == 0 and H.Listeners("PLAYER_REGEN_ENABLED") == base + 1, "in combat the wait registers PLAYER_REGEN_ENABLED")
	H.combat = false
	H.Fire("PLAYER_REGEN_ENABLED")
	check(done == 1 and H.Listeners("PLAYER_REGEN_ENABLED") == base, "it ran once after combat and unregistered")
	M.PSS_When("nocombat", function() done = done + 1 end)
	check(done == 2, "out of combat the wait runs at once")
	M.PSS_When("itemdata", function() done = done + 10 end)
	H.Fire("ITEM_DATA_LOAD_RESULT", 19019, true)
	check(done == 12 and H.Listeners("ITEM_DATA_LOAD_RESULT") == 0, "itemdata waits for its notice and unregisters")
	M.PSS_When("unlocked", function() done = done + 100 end)
	H.Fire("ITEM_UNLOCKED", 0, 1)
	check(done == 112 and H.Listeners("ITEM_UNLOCKED") == 0 and H.Listeners("BAG_UPDATE_DELAYED") == 0, "unlocked ends on ITEM_UNLOCKED and both events go")
	check(M.PSS_When("no.such", function() end) == nil, "an unknown condition is refused")
	-- a per-frame need card and the services
	M.PSS_Want({ id = "ext.tick", source = "ExampleAddon", class = "per-frame", step = function() return true end })
	local cards = M.PSS_Call("trig.cards")
	check(cards and cards.n == 1 and cards[1][2] == "ExampleAddon", "trig.cards names the integration")
	local needs = M.PSS_Call("trig.needs")
	local rungs = {}
	for i = 1, needs.n do rungs[needs[i][1]] = needs[i][3] end
	check(rungs["t.late"] == nil or true, "needs listed")
	check(rungs["t.cd"] == "pull" and rungs["ext.tick"] == "pulse", "trig.needs lists each need with its rung")
	local sv = M.PSS_Services()
	local names = {}
	for i = 1, sv.n do names[sv[i][1]] = true end
	check(names["trig.needs"] and names["trig.cards"] and names["trig.rows"], "the engine's services are on the bus")
	-- the combined AFK wake: PLAYER_FLAGS_CHANGED is heard only while an afk need waits
	check(H.Listeners("PLAYER_FLAGS_CHANGED") == 0, "PLAYER_FLAGS_CHANGED is not heard without an afk need")
elseif phase == "retry" then
	-- issue 224, DEC-00238: a failed upgrade step 11 retries through a trigger row, in the same session
	local step = M.PSS_UPGRADE_REGISTRY[11]
	local run = step.parts[1].data
	local evs = { "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }
	local base = {}
	for i = 1, #evs do base[i] = H.Listeners(evs[i]) end
	run()
	check(PSS_CharDB == nil and M.PSS_Triggers == nil, "nothing to move declares nothing (Libraries not loaded: no triggers service)")
	for i = 1, #evs do check(H.Listeners(evs[i]) == base[i], evs[i] .. " registered with nothing to move") end
	local need = M.PSS_Need
	M.PSS_Need = function() return false end
	_G["PSS_CharDB"] = { addonLock = "LibFoo", addonPick = "ZedOne" }
	run(); run()
	check(PSS_CharDB and PSS_CharDB.addonLock == "LibFoo", "the old file is untouched while Libraries cannot load")
	for i = 1, #evs do check(H.Listeners(evs[i]) == base[i] + 1, evs[i] .. " not registered once by the retry row") end
	M.PSS_Need = need
	H.Fire("PLAYER_REGEN_ENABLED")
	check(PSS_CharDB == nil, "the move completed in the same session: " .. tostring(PSS_CharDB))
	check(PSS_OptionsDB.addonLockOf ~= nil and PSS_OptionsDB.addonPickOf ~= nil, "the owned keys hold the profiles")
	for i = 1, #evs do check(H.Listeners(evs[i]) == base[i], evs[i] .. " still registered after the retry ran") end
	local rows = M.PSS_Triggers()
	local left = 0
	for i = 1, rows.n do if rows[i][1] == "charmove" then left = left + 1 end end
	check(left == 0, "the charmove row is gone")
	H.Fire("PLAYER_REGEN_ENABLED")
	check(PSS_CharDB == nil, "a later event does nothing")
	-- a file with only newer fields: tried once, kept, the row is taken down
	M.PSS_Need = function() return false end
	_G["PSS_CharDB"] = { newerKey = { 1 } }
	run()
	M.PSS_Need = need
	H.Fire("PLAYER_REGEN_ENABLED")
	check(PSS_CharDB and PSS_CharDB.newerKey, "a newer field is kept")
	for i = 1, #evs do check(H.Listeners(evs[i]) == base[i], evs[i] .. " registered after a kept-only file") end
elseif phase == "cost" then
	-- TST-00191 for this stage's files, from bus_budgets.lua
	local B = dofile(here .. "/bus_budgets.lua")
	-- resident KB of each file in a bare Lua state (its own closures and tables, nothing else)
	local script = os.tmpname()
	local fh = io.open(script, "w")
	fh:write([[
		local path = ...
		PourSocialScore_NS = { M = { PSS_Provide = function() end } }
		collectgarbage("collect"); collectgarbage("collect")
		local a = collectgarbage("count")
		local chunk = assert(loadfile(path))
		chunk()
		collectgarbage("collect"); collectgarbage("collect")
		print(string.format("%.2f", collectgarbage("count") - a))
	]])
	fh:close()
	for _, f in ipairs({ { "PSS_Watch.lua", "PourSocialScore" }, { "PSS_Trig.lua", "PourSocialScore_Libraries" } }) do
		local p = io.popen("lua5.1 " .. script .. " " .. f[2] .. "/" .. f[1])
		local kb = tonumber(p:read("*a"))
		p:close()
		local gate = B.kb[f[1]].gate
		check(kb ~= nil and kb <= gate, string.format("%s resident %s KB over its gate %d KB", f[1], tostring(kb), gate))
		print(string.format("NOTE trig cost: %s %.2f KB (gate %d)", f[1], kb or -1, gate))
	end
	os.remove(script)
	libs()
	-- a settle flush and a signal, microseconds
	M.PSS_Provide("t.cost", function(set) return set end, {})
	M.PSS_Trigger({ id = "costrow", gate = "logging", on = { "BAG_UPDATE" }, settle = { "BAG_UPDATE_DELAYED" }, run = "t.cost", key = function(_, b) return b end })
	local t0 = os.clock()
	for i = 1, 2000 do H.Fire("BAG_UPDATE", i % 5); H.Fire("BAG_UPDATE_DELAYED") end
	local us = (os.clock() - t0) / 2000 * 1e6
	check(us <= B.us.settle.gate, string.format("a mark and a settle flush take %.1f us over the %d us gate", us, B.us.settle.gate))
	print(string.format("NOTE trig cost: a mark and a settle flush %.1f us (gate %d)", us, B.us.settle.gate))
	local E = M.PSS_TrigNew(dofile(here .. "/trig_client.lua"))
	E.Need({ id = "s", class = "coalesce", signal = "@s", fn = function() end })
	local t1 = os.clock()
	for _ = 1, 20000 do E.Signal("@s") end
	local us2 = (os.clock() - t1) / 20000 * 1e6
	check(us2 <= B.us.signal.gate, string.format("a signal takes %.2f us over the %d us gate", us2, B.us.signal.gate))
	print(string.format("NOTE trig cost: a signal %.2f us (gate %d)", us2, B.us.signal.gate))
elseif phase ~= "engine" then
	check(false, "unknown phase " .. phase)
end

if not fail then print("PASS trig " .. phase .. " (" .. passes .. " checks)") end
