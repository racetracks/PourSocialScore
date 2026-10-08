-- The right-click menu (core uplift B2, 3.4.1.36): one "PSS" header with
-- "Block Player" and "Block Guild" (each "Unblock ..." when already listed).
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_unitmenu.lua
local fail = false
local function check(ok, msg) if not ok then print("FAIL unitmenu: " .. msg) fail = true end end

local realExists, realName, realGuild = _G.UnitExists, _G.UnitName, _G.GetGuildInfo
local unitName, unitGuild, own = "Menutarget", "Menu Guild", "Home Guild"
_G.UnitExists = function(u) return u == "target" end
_G.UnitName = function(u) if u == "target" then return unitName end return realName(u) end
_G.UnitIsUnit = function() return false end
_G.GetGuildInfo = function(u)
	if u == "player" then return own end
	if u == "target" then return unitGuild end
end

local function build(ctx)
	local got = {}
	local root = {}
	function root:CreateDivider() end
	function root:CreateTitle(t) got[#got + 1] = { title = t } end
	function root:CreateButton(t, fn) got[#got + 1] = { text = t, fn = fn } return {} end
	M.PSS_UnitMenuPlayer(nil, root, ctx)
	return got
end
local function find(got, text)
	for _, e in ipairs(got) do if e.text == text then return e end end
end
local function listedPlayer() return (M.PSS_ListedPosition(M.PSS_CanonPlayer("Menutarget")) or 0) > 0 end

-- a unit with a guild: header, Block Player, Block Guild
local got = build({ unit = "target" })
check(got[1] and got[1].title == "PSS", "no PSS header first")
check(find(got, "Block Player") and find(got, "Block Guild"), "Block Player / Block Guild missing")
check(not find(got, "Add to Ignore"), "the old single entry is still there")

-- Block Guild lists the guild; the entry then reads Unblock Guild
find(got, "Block Guild").fn()
check(M.PSS_IsGuildListed("Menu Guild"), "Block Guild did not list the guild")
got = build({ unit = "target" })
check(find(got, "Unblock Guild") and not find(got, "Block Guild"), "no Unblock Guild when listed")
find(got, "Unblock Guild").fn()
check(not M.PSS_IsGuildListed("Menu Guild"), "Unblock Guild did not remove the guild")

-- Block Player and Unblock Player
got = build({ unit = "target" })
find(got, "Block Player").fn()
check(listedPlayer(), "Block Player did not list the player")
got = build({ unit = "target" })
check(find(got, "Unblock Player") and not find(got, "Block Player"), "no Unblock Player when listed")
find(got, "Unblock Player").fn()
check(not listedPlayer(), "Unblock Player did not remove the player")

-- no guild entry: no guild, your own guild, a secret guild, no unit
unitGuild = nil
check(not find(build({ unit = "target" }), "Block Guild"), "Block Guild offered with no guild")
unitGuild = "home guild"
check(not find(build({ unit = "target" }), "Block Guild"), "Block Guild offered for your own guild")
unitGuild = "Menu Guild"
local realSecret = M.PSS_IsSecret
M.PSS_IsSecret = function(v) return v == "Menu Guild" end
check(not find(build({ unit = "target" }), "Block Guild"), "Block Guild offered for a secret guild")
M.PSS_IsSecret = realSecret
got = build({ name = "Menutarget", server = "" })
check(find(got, "Block Player") and not find(got, "Block Guild"), "a chat-name menu: player only")

_G.UnitExists, _G.UnitName, _G.GetGuildInfo = realExists, realName, realGuild
if not fail then print("PASS unitmenu") end
os.exit(fail and 1 or 0)
