-- Issue 183 (IRE-T1 to T5, T7): the echo of the ignore auto-reply.
--   * option "showIgnoreReplies" (default on): ticked = nothing changes, no
--     filter, no token; unticked = the "To <name>" echo of the reply PSS sent
--     and the "No player named" line are hidden, nothing else is
--   * the echo raises no whisper warning; a hand-typed whisper still does
--   * secret target or text is shown, never an error; Camelot names match
--   lua5.1 tools/harness/run.lua . - - tools/harness/check_ignorereply.lua
--   PSS_CAMELOT=1 for the surname run
local fails = 0
local realPrint = print
local function eq(what, got, want)
	if got ~= want then realPrint(("  FAIL %s: %s, expected %s"):format(what, tostring(got), tostring(want))); fails = fails + 1 end
end
print = function() end

local SECRET = {}
_G.issecretvalue = function(v) return v ~= nil and SECRET[v] == true end
local sent = {}
SendChatMessage = function(text, kind, _, to) sent[#sent + 1] = { text, kind, to } end
local MSG = "[Pour Social Score] You are being ignored."
local camelot = (os.getenv("PSS_FLAVOUR") == "forever" or os.getenv("PSS_CAMELOT") == "1")
local NAME = camelot and "Bob Smith" or "Badguy"
local FROM = camelot and ("Bob Smith-" .. GetRealmName()) or ("Badguy-" .. GetRealmName())

M.PSS_AddPlayer(NAME)
M.PSS_AddPlayer("Other")
H.RunTimers()
M.PSS_SetOpt("ignoreResponse", "global", true)
M.PSS_SetOpt("listWarnings", "global", true)

local warned = 0
M.Events.Register("WHISPER_WARNING", function() warned = warned + 1 end)

local function echoFilters()
	local n = 0
	for _, f in ipairs(H.filters) do
		if f.event == "CHAT_MSG_WHISPER_INFORM" and f.fn ~= M.PSS_CoreFilter then n = n + 1 end
	end
	return n
end
local base = echoFilters()
local lineID = 910000

-- the client calls every filter of the event once per chat frame (3 frames here)
local function everyFrame(event, ...)
	local hiddenIn = 0
	for frame = 1, 3 do
		local hide = false
		for _, f in ipairs(H.filters) do
			if f.event == event then
				local ok, r = pcall(f.fn, nil, event, ...)
				if not ok then eq("filter error: " .. tostring(r), true, false) end
				if ok and r == true then hide = true end
			end
		end
		if hide then hiddenIn = hiddenIn + 1 end
	end
	return hiddenIn
end
local function whisperIn(from)
	lineID = lineID + 1
	pcall(M.PSS_CoreFilter, nil, "CHAT_MSG_WHISPER", "hello", from, "", "", "", "", 0, 0, "", 0, lineID, nil)
end
local function inform(text, to, id)
	return { text, to, "", "", "", "", 0, 0, "", 0, id, nil }
end
local function echo(text, to)
	lineID = lineID + 1
	local a = inform(text, to, lineID)
	local n = everyFrame("CHAT_MSG_WHISPER_INFORM", unpack(a, 1, 12))
	H.Fire("CHAT_MSG_WHISPER_INFORM", unpack(a, 1, 12))
	return n
end

-- IRE-T7: option on (the default): the reply goes, nothing is hidden or kept
eq("default is on", M.PSS_Opt("showIgnoreReplies"), true)
whisperIn(FROM)
eq("reply sent (on)", #sent, 1)
eq("reply text", sent[1] and sent[1][1], MSG)
eq("on: no filter registered", echoFilters(), base)
eq("on: echo shown", echo(MSG, FROM), 0)

-- IRE-T1: option off -> the echo of the reply is hidden in every chat frame
warned = 0
M.PSS_SetOpt("showIgnoreReplies", "global", false)
eq("off is the saved form", PSS_OptionsDB.showIgnoreReplies, false)
H.Advance(400)
sent = {}
M.PSS__CoreTest.resetWhisperWarned()
whisperIn(FROM)
eq("reply sent (off)", #sent, 1)
eq("off: one filter added", echoFilters(), base + 1)
-- T2 first: the frame handler may run before the filters
local a1 = inform(MSG, FROM, 920001)
H.Fire("CHAT_MSG_WHISPER_INFORM", unpack(a1, 1, 12))
eq("T2: the echo raises no warning (handler first)", warned, 0)
eq("T1: hidden in all 3 frames", everyFrame("CHAT_MSG_WHISPER_INFORM", unpack(a1, 1, 12)), 3)
-- T3: a second identical echo (another line) is shown
eq("T3: second identical echo shown", echo(MSG, FROM), 0)

-- fresh reply, filters first then handler
warned = 0
M.PSS__CoreTest.resetWhisperWarned()
H.Advance(400)
whisperIn(FROM)
local a2 = inform(MSG, FROM, 920002)
eq("T1: hidden in all 3 frames (filters first)", everyFrame("CHAT_MSG_WHISPER_INFORM", unpack(a2, 1, 12)), 3)
H.Fire("CHAT_MSG_WHISPER_INFORM", unpack(a2, 1, 12))
eq("T2: no warning (filters first)", warned, 0)

-- T2: a hand-typed whisper to the listed person still warns
M.PSS__CoreTest.resetWhisperWarned()
eq("T2: hand-typed text shown", echo("typed by hand", FROM), 0)
eq("T2: hand-typed whisper warns", warned, 1)

-- T3: shown cases: another target, other text, an old echo
H.Advance(400)
whisperIn(FROM)
eq("T3: same text, other target shown", echo(MSG, "Other"), 0)
eq("T3: other text, same target shown", echo("something else", FROM), 0)
H.Advance(11)
eq("T3: an echo older than 10 s shown", echo(MSG, FROM), 0)

-- T5: the "No player named" line
H.Advance(400)
whisperIn(FROM)
local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
eq("T5: other name shown", everyFrame("CHAT_MSG_SYSTEM", fmt:format("Stranger")), 0)
eq("T5: pending target hidden", everyFrame("CHAT_MSG_SYSTEM", fmt:format(FROM)) > 0, true)
eq("T5: second time shown", everyFrame("CHAT_MSG_SYSTEM", fmt:format(FROM)), 0)

-- T4: secrets are shown, never an error
H.Advance(400)
whisperIn(FROM)
SECRET[MSG .. " "] = true
SECRET[FROM .. " "] = true
eq("T4: secret text shown", everyFrame("CHAT_MSG_WHISPER_INFORM", MSG .. " ", FROM, "", "", "", "", 0, 0, "", 0, 920010, nil), 0)
eq("T4: secret target shown", everyFrame("CHAT_MSG_WHISPER_INFORM", MSG, FROM .. " ", "", "", "", "", 0, 0, "", 0, 920011, nil), 0)
eq("T4: secret system line shown", everyFrame("CHAT_MSG_SYSTEM", fmt:format(FROM) .. " "), 0)
eq("T4: the real echo is still hidden", everyFrame("CHAT_MSG_WHISPER_INFORM", MSG, FROM, "", "", "", "", 0, 0, "", 0, 920012, nil), 3)

-- T7: ticked again: shown again, the key is no longer saved
M.PSS_SetOpt("showIgnoreReplies", "global", true)
eq("ticked again: key not saved", PSS_OptionsDB.showIgnoreReplies, nil)
H.Advance(400)
whisperIn(FROM)
eq("ticked again: echo shown", echo(MSG, FROM), 0)

print = realPrint
if fails == 0 then print("PASS ignorereply") else print("FAIL ignorereply: " .. fails) end
