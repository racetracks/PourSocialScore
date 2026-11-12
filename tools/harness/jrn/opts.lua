-- Journal options and gates (build J1D): sparse save, the Warehouse gate, hidden cap rows, early read.
local M = PourSocialScore_NS.M
local function fail(w) print("FAIL jrn: opts: " .. w) end
local flv = M.PSS_FLV.flavour

-- jrnopts: a default is not saved, a change is
M.PSS_SetOpt("jrnMonths", "global", 13)
if PourSocialScoreDB.jrnMonths ~= nil then return fail("default jrnMonths saved") end
M.PSS_SetOpt("jrnMonths", "global", 24)
if PourSocialScoreDB.jrnMonths ~= 24 then return fail("changed jrnMonths not saved") end
M.PSS_SetOpt("jrnMonths", "global", 13)
if PourSocialScoreDB.jrnMonths ~= nil then return fail("jrnMonths back to default still saved") end

-- jrngate: Journal refused while the Warehouse is off, with the reason; allowed when on
local shown = {}
local old = M.ShowMsg
M.ShowMsg = function(t) shown[#shown + 1] = t end
M.PSS_SetOpt("useWarehouse", "global", false)
M.PSS_SetOpt("useJournal", "global", false)
local ok = M.PSS_OptSetBool({ key = "useJournal", label = "Journal" }, true)
M.ShowMsg = old
if ok ~= false then return fail("Journal ticked with the Warehouse off") end
if M.PSS_Opt("useJournal") then return fail("useJournal left on after refusal") end
if not (shown[1] and shown[1]:find("Journal needs the Warehouse: turn on Warehouse first.", 1, true)) then return fail("refusal line missing") end
M.PSS_SetOpt("useWarehouse", "global", true)
if M.PSS_OptSetBool({ key = "useJournal", label = "Journal" }, true) ~= true or not M.PSS_Opt("useJournal") then return fail("Journal refused with the Warehouse on") end
M.PSS_SetOpt("useJournal", "global", false)
M.PSS_SetOpt("useWarehouse", "global", false)

-- jrncost: Journal off draws no jrn rows that its cap hides; each cap row is drawn only when a cap is on
local drawn = {}
for _, g in ipairs(M.PSS_OptGroups()) do for _, it in ipairs(g.items) do drawn[it.o.key] = true end end
for _, o in ipairs(M.PSS_OPTIONS) do
	if o.cap then
		local caps = type(o.cap) == "table" and o.cap or { o.cap }
		local want = false
		for _, c in ipairs(caps) do if M.PSS_Can(c) then want = true end end
		if (drawn[o.key] == true) ~= want then return fail(o.key .. " drawn=" .. tostring(drawn[o.key]) .. " want " .. tostring(want) .. " on " .. flv) end
	end
end

-- jrnearly: options read before the saved tables are routed give defaults, no error
local saved = PourSocialScoreDB
PourSocialScoreDB = nil
local good, v = pcall(M.PSS_Opt, "jrnMonths")
PourSocialScoreDB = saved
if not good or v ~= 13 then return fail("early read: " .. tostring(v)) end
print("PASS opts " .. flv)
