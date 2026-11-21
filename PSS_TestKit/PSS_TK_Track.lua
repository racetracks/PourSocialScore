local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M
local type, pairs, ipairs, pcall, select = type, pairs, ipairs, pcall, select
local GetTime, CreateFrame = GetTime, CreateFrame

-- TestKit objective tracker (design.md#objective-tracker, api-ops.md#tk-a-43-objective, api-core-integration.md#tk-a-29-testkitpoll-need).
-- No timer of the kit's own: polls run only through the engine need M.PSS_Want (DEC-00494).
local POLLBY, POLLMAX = 0.5, 8
local reg = {}	-- "run|row|id" -> { run, row, c, o, last }
local evf, evCount = nil, {}	-- kit event frame, name -> listeners
local bus = {}	-- "run|row|id" -> { name, id }
local polls = {}	-- ordered keys of unticked poll objectives
local wanted, lastPoll = false, 0

local function have(run, row, o)
	local ck = run.checks and run.checks[row]
	return ck and ck.obj and ck.obj[o.id] or 0
end

local function argsMatch(o, ...)
	if not o.arg then return true end
	for i = 1, #o.arg do
		if select(i, ...) ~= o.arg[i] then return false end
	end
	return true
end

local function drop(k)
	local r = reg[k]
	if not r then return end
	reg[k] = nil
	local o = r.o
	if o.source == "event" then
		evCount[o.name] = (evCount[o.name] or 1) - 1
		if evCount[o.name] <= 0 then
			evCount[o.name] = nil
			if evf then pcall(evf.UnregisterEvent, evf, o.name) end
		end
	elseif o.source == "bus" and bus[k] and M.Events then
		M.Events.Unregister(bus[k].name, bus[k].id)
		bus[k] = nil
	end
end

-- a match: one store write, one TESTKIT_CHANGED
local function hit(k)
	local r = reg[k]
	if not r then return end
	local ok, run = pcall(TK.GetRun, r.run)
	if not ok or not pcall(TK.Writable) then return end
	local ck = TK.CheckRow(run, r.row)
	if type(ck.obj) ~= "table" then ck.obj = {} end
	local n = (ck.obj[r.o.id] or 0) + 1
	ck.obj[r.o.id] = n
	if n >= (r.o.need or 1) then drop(k) end
	TK.Recompute(ck, r.c)
	TK.Touch(run)
	TK.Fire(run.id, r.row)
end

local function onEvent(_, event, ...)
	for k, r in pairs(reg) do
		if r.o.source == "event" and r.o.name == event and argsMatch(r.o, ...) then hit(k) end
	end
end

local function rebuildPolls()
	local n = 0
	for i = #polls, 1, -1 do polls[i] = nil end
	for k, r in pairs(reg) do
		if r.o.source == "poll" then n = n + 1; polls[n] = k end
	end
	table.sort(polls)
end

-- TK-A-29: returns true when no unticked poll objective is left
function TK.PollStep()
	if #polls == 0 then wanted = false; return true end
	local now = GetTime()
	if now - lastPoll < POLLBY then return false end
	lastPoll = now
	for i = 1, #polls do
		if i > POLLMAX then break end
		local r = reg[polls[i]]
		if r then
			local ok, v = pcall(TK.Op.frame, r.o)
			local f = TK.Cmp[r.o.cmp]
			local pass = ok and v ~= nil and f and (f(v, r.o.want)) and true or false
			local was = r.last
			r.last = pass
			if pass and not was then hit(polls[i]) end
		end
	end
	rebuildPolls()
	if #polls == 0 then wanted = false; return true end
	return false
end

function TK.Unpoll()
	if wanted then
		wanted = false
		if M.PSS_Unwant then M.PSS_Unwant("testkit.poll") end
	end
end

-- listen for the unticked objectives of a run (idempotent); wants the poll need while a poll objective is open
function TK.Arm(runId)
	if type(runId) ~= "string" then return end
	local ok, run = pcall(TK.GetRun, runId)
	local env = ok and TK.Env(run)
	if not env or not pcall(TK.Writable) then return end
	local here = TK.Here()
	for _, c in ipairs(env.checks) do
		if (c.client == "any" or c.client == here) and c.objectives then
			local row = TK.RowId(c)
			for _, o in ipairs(c.objectives) do
				local k = runId .. "|" .. row .. "|" .. o.id
				if not reg[k] and have(run, row, o) < (o.need or 1) then
					reg[k] = { run = runId, row = row, c = c, o = o }
					if o.source == "event" then
						if not evf then
							evf = CreateFrame("Frame")
							evf:SetScript("OnEvent", onEvent)
						end
						evCount[o.name] = (evCount[o.name] or 0) + 1
						pcall(evf.RegisterEvent, evf, o.name)
					elseif o.source == "bus" and M.Events then
						bus[k] = { name = o.name, id = M.Events.Register(o.name, function(...)
							if argsMatch(o, ...) then hit(k) end
						end) }
					end
				end
			end
		end
	end
	rebuildPolls()
	if #polls > 0 and not wanted and M.PSS_Want then
		local w = pcall(M.PSS_Want, { id = "testkit.poll", source = "testkit", class = "slice", by = POLLBY, step = TK.PollStep })
		wanted = w
	end
end
