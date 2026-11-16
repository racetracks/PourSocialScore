local _, TK = ...
local addon = PourSocialScore_NS
local M = addon.M

-- TestKit bus services (design.md#bus-services). This build: open and close.
local EMPTY = { cols = { "shown" }, n = 0 }
local SHOWN = { cols = { "shown" }, n = 1, { true } }
local HIDDEN = { cols = { "shown" }, n = 1, { false } }

local function open()
	local win = TK.GetWindow()
	if win then win:Show() end
	return SHOWN
end

M.PSS_ProvideStub("testkit.open", { returns = { "shown" }, doc = "opens the TestKit window", cost = "O(1)", writes = false, onError = "empty", default = EMPTY },
	function() return open end)

M.PSS_Provide("testkit.close", function()
	local win = TK.window
	if win then win:Hide() end
	if M.PSS_Unwant then M.PSS_Unwant("testkit.poll") end
	return HIDDEN
end, { returns = { "shown" }, doc = "closes the TestKit window", cost = "O(1)", writes = false, onError = "empty", default = EMPTY })
