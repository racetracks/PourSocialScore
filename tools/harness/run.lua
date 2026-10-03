-- Load PourSocialScore with the WoW stub, optionally with a SavedVariables
-- file, log in, run a script, log out and write the SavedVariables back.
--   lua5.1 tools/harness/run.lua <addonDir> <svIn|-> <svOut|-> [script.lua]
-- The script runs after login with globals H (the stub) and M (addon.M).
local here = arg[0]:match("^(.*)/[^/]*$") or "."
local addonDir, svIn, svOut, script = arg[1], arg[2], arg[3], arg[4]

local H = dofile(here .. "/wow_stub.lua")
H.SetTime(tonumber(os.getenv("PSS_TIME") or "") or 1790000000)
_G.H = H


if svIn and svIn ~= "-" then dofile(svIn) end

local toc = addonDir .. "/PourSocialScore.toc"
local addon = {}
for line in io.lines(toc) do
	line = line:gsub("\r", "")
	if line:match("%.lua$") and not line:match("^#") then
		local f = assert(loadfile(addonDir .. "/" .. line))
		f("PourSocialScore", addon)
	end
end
local M = addon.M
_G.M = M

H.Fire("ADDON_LOADED", "PourSocialScore")
H.Fire("PLAYER_LOGIN")
H.Fire("PLAYER_ENTERING_WORLD", true, false)
H.Fire("IGNORELIST_UPDATE")
H.RunTimers()

if script then dofile(script) end

H.Fire("PLAYER_LOGOUT")
if svOut and svOut ~= "-" then
	local fh = assert(io.open(svOut, "w"))
	fh:write("PourSocialScoreDB = ", H.serialize(PourSocialScoreDB), "\n")
	fh:close()
end
