local addonName, addon = ...
-- get a reference to localization entries
local L = addon.L
-- use this array to share variables between addon files
addon.V = {}
local V = addon.V
-- use this to share methods between addon files
addon.M = {}
local M = addon.M

----------------------
-- SHARED FUNCTIONS --
----------------------

function M.PSSDUMP (o)
	if type(o) == 'table' then
		local s = '{ '

		for key, value in pairs(o) do
			if type(key) ~= 'number' then
				key = '"'..key..'"'
			end
			s = s .. '['..key..'] = ' .. M.PSSDUMP(value) .. ','
		end

		return s .. '} '
	else
		return tostring(o)
	end
end

function M.PSSDUMP2 (tbl, indent)
	if not indent then
		indent = 0
	end

	local formatting

	for key, value in pairs(tbl) do
		formatting = string.rep("  ", indent) .. key .. ": "
		if type(value) == "table" then
			print(formatting)
			M.PSSDUMP2(value, indent + 1)
		elseif type(value) == 'boolean' then
			print(formatting .. tostring(value))
		elseif type(value) == 'function' then
			print(formatting .. "function")
		else
			print(formatting .. value)
		end
	end
end

function M.popWord (str, ch)

	local idx = string.find(str, ch, 1, true)

	if idx == nil then
		return "", str
	end

	return string.sub(str, 1, idx - 1), string.sub(str, idx + 1)
end

function M.trim (str)

	local n = str:find"%S"
	return n and str:match(".*%S", n) or ""

end

function M.dateToJulianDate (dateStr)

	if dateStr == nil then
		return 0
	end

	local monthList = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
	local words     = {}

	for word in dateStr:gmatch("%w+") do
		table.insert(words, word)
	end

	local day   = tonumber(words[1])
	local year  = tonumber(words[3])
	local month = 0

	for key, value in pairs(monthList) do

		if value == words[2] then
			month = tonumber(key)

			break
		end
	end

	if (not month) or (not day) or (not year) or (month < 1) or (month > 12) or (day < 1) or (day > 31) or (year < 2014) then
		return 0
	end

	-- Whole day number (days since 1970). Midday avoids daylight-saving edges.
	-- 2.0.8 used a Julian-day formula with decimal division, so day counts
	-- could be one off around the end of a month.
	local t = time({ year = year, month = month, day = day, hour = 12 })
	if not t then return 0 end
	return math.floor(t / 86400)
end

function M.daysFromToday (dateStr)

	local addDate = M.dateToJulianDate(dateStr)
	local today   = M.dateToJulianDate(date("%d %b %Y"))

	if addDate == 0 then
		return -1
	else

		return math.abs(today - addDate)
	end
end

-- ASCII lower case (non-ASCII bytes unchanged) - same as string.lower in
-- the game's C locale. (The old version built the result a character at a
-- time.)
function M.strDown (str)
	return string.lower(str)
end

local properBuf = {}
function M.Proper (name, okSpaces)

	if name == nil then return nil end
	if name == "" then return nil end

	-- Character names can contain a space ("First Last-Realm"). For a
	-- "Name-Realm" string the spaces inside the name part are kept (single
	-- spaces, trimmed); spaces in the realm part are still removed, as before.
	local keepUntil = 0
	if okSpaces ~= true then
		local dash = string.find(name, "-", 1, true)
		if dash and dash > 1 then
			local base = string.sub(name, 1, dash - 1):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
			if string.find(base, " ", 1, true) then
				name = base .. string.sub(name, dash)
				keepUntil = strlen(base)
			end
		end
	end

	-- one pass over the bytes into a reused buffer, joined once (the old
	-- version appended to a string per character: quadratic garbage)
	local len    = #name
	local buf    = properBuf
	local n      = 0
	local needUp = true
	local gotOP  = false
	local byte, char, upper, lower = string.byte, string.char, string.upper, string.lower

	for count = 1, len do
		local c = byte(name, count)
		if c < 32 or c > 126 then
			n = n + 1; buf[n] = char(c)
			needUp = false
		elseif c ~= 32 or okSpaces == true or count <= keepUntil then
			n = n + 1
			buf[n] = needUp and upper(char(c)) or lower(char(c))
			gotOP  = (c == 40 or gotOP) and (c ~= 41)
			needUp = (c == 32 or c == 45 or gotOP == true)
		end
	end

	return table.concat(buf, "", 1, n)
end

-- Split "name [rest]" typed by the user. The name may contain a space:
--   "First Last-Realm note"   (a word with "-" within the first 3 words ends the name)
--   "\"First Last\" note"      (quotes; the name may then have no realm)
-- Anything else: the first word is the name, as before.
function M.PSS_SplitNameArg(str)
	str = M.trim(tostring(str or ""))
	if str == "" then return "", "" end
	local q, after = str:match('^"([^"]+)"%s*(.*)$')
	if q then return M.trim(q), after or "" end
	local words = {}
	for w in str:gmatch("%S+") do words[#words + 1] = w end
	local last = 1
	if not string.find(words[1], "-", 1, true) then
		for k = 2, math.min(3, #words) do
			if string.find(words[k], "-", 1, true) then last = k break end
		end
	end
	local name = table.concat(words, " ", 1, last)
	local rest = (#words > last) and table.concat(words, " ", last + 1) or ""
	return name, rest
end

function M.GetWord (str, wordnumber)

	local len     = strlen(str)
	local count   = 1
	local res     = ""
	local words   = 0
	local nextInc = true
	local c

	while count <= len do
		if nextInc then
			words = words + 1

			if words > wordnumber then
				break
			end
		end

		c = strbyte(str, count)

		nextInc = (c == 32) and nextInc == false

		if words == wordnumber and c ~= 32 then
			res = res .. string.char(c)
		end

		count = count + 1
	end

	return res
end

function M.prettyServer (origName)

	if origName == nil then return nil end

	local name = origName

	if name == "Aeriepeak" then name = "Aerie Peak"
	elseif name == "Aggra(portugu\195\170s)" then name = "Aggra (Portugu\195\170s)"
	elseif name == "Ahn'qiraj" then name = "Ahn'Qiraj"
	elseif name == "Al'akir" then name = "Al'Akir"
	elseif name == "Altarofstorms" then name = "Altar of Storms"
	elseif name == "Alteracmountains" then name = "Alterac Mountains"
	elseif name == "Aman'thul" then name = "Aman'Thul"
	elseif name == "Arathibasin" then name = "Arathi Basin"
	elseif name == "Arcanitereaper" then name = "Arcanite Reaper"
	elseif name == "Area52" then name = "Area 52"
	elseif name == "Argentdawn" then name = "Argent Dawn"
	elseif name == "Arugal(au)" then name = "Arugal (AU)"
	elseif name == "Azjol-nerub" then name = "Azjol-Nerub"
	elseif name == "Blackdragonflight" then name = "Black Dragonflight"
	elseif name == "Blackwaterraiders" then name = "Blackwater Raiders"
	elseif name == "Blackwinglair" then name = "Blackwing Lair"
	elseif name == "Blade'sedge" then name = "Blade's Edge"
	elseif name == "Bleedinghollow" then name = "Bleeding Hollow"
	elseif name == "Bloodfurnace" then name = "Blood Furnace"
	elseif name == "Bloodsailbuccaneers" then name = "Bloodsail Buccaneers"
	elseif name == "Bootybay" then name = "Booty Bay"
	elseif name == "Boreantundra" then name = "Borean Tundra"
	elseif name == "Bronzedragonflight" then name = "Bronze Dragonflight"
	elseif name == "Burningblade" then name = "Burning Blade"
	elseif name == "Burninglegion" then name = "Burning Legion"
	elseif name == "Burningsteppes" then name = "Burning Steppes"
	elseif name == "Cenarioncircle" then name = "Cenarion Circle"
	elseif name == "Chamberofaspects" then name = "Chamber of Aspects"
	elseif name == "Chants\195\169ternels" then name = "Chants \195\169ternels"
	elseif name == "Chaosbolt" then name = "Chaos Bolt"
	elseif name == "Chillwindpoint" then name = "Chillwind Point"
	elseif name == "Chromie(ru)" then name = "Chromie (RU)"
	elseif name == "Colinaspardas" then name = "Colinas Pardas"
	elseif name == "Confr\195\169rieduthorium" then name = "Confr\195\169rie du Thorium"
	elseif name == "Conseildesombres" then name = "Conseil des Ombres"
	elseif name == "Crusaderstrike" then name = "Crusader Strike"
	elseif name == "Crystalpinestinger" then name = "Crystalpine Stinger"
	elseif name == "C'thun" then name = "C'Thun"
	elseif name == "Cultedelarivenoire" then name = "Culte de la Rive noire"
	elseif name == "Darkiron" then name = "Dark Iron"
	elseif name == "Darkmoonfaire" then name = "Darkmoon Faire"
	elseif name == "Daskonsortium" then name = "Das Konsortium"
	elseif name == "Dassyndikat" then name = "Das Syndikat"
	elseif name == "Dath'remar" then name = "Dath'Remar"
	elseif name == "Defiasbrotherhood" then name = "Defias Brotherhood"
	elseif name == "Defiaspillager" then name = "Defias Pillager"
	elseif name == "Demonfallcanyon" then name = "Demon Fall Canyon"
	elseif name == "Demonsoul" then name = "Demon Soul"
	elseif name == "Derabyssischerat" then name = "Der abyssische Rat"
	elseif name == "Dermithrilorden" then name = "Der Mithrilorden"
	elseif name == "Derratvondalaran" then name = "Der Rat von Dalaran"
	elseif name == "Deviatedelight" then name = "Deviate Delight"
	elseif name == "Diealdor" then name = "Die Aldor"
	elseif name == "Diearguswacht" then name = "Die Arguswacht"
	elseif name == "Dieewigewacht" then name = "Die ewige Wacht"
	elseif name == "Dienachtwache" then name = "Die Nachtwache"
	elseif name == "Diesilbernehand" then name = "Die Silberne Hand"
	elseif name == "Dietodeskrallen" then name = "Die Todeskrallen"
	elseif name == "Dragon'scall" then name = "Dragon's Call"
	elseif name == "Drak'tharon" then name = "Drak'Tharon"
	elseif name == "Drek'thar" then name = "Drek'Thar"
	elseif name == "Dunmodr" then name = "Dun Modr"
	elseif name == "Dunmorogh" then name = "Dun Morogh"
	elseif name == "Earthenring" then name = "Earthen Ring"
	elseif name == "Echoisles" then name = "Echo Isles"
	elseif name == "Eldre'thalas" then name = "Eldre'Thalas"
	elseif name == "Emeralddream" then name = "Emerald Dream"
	elseif name == "Fengus'ferocity" then name = "Fengus' Ferocity"
	elseif name == "Festungderst\195\188rme" then name = "Festung der St\195\188rme"
	elseif name == "Flamegor(ru)" then name = "Flamegor (RU)"
	elseif name == "Grimbatol" then name = "Grim Batol"
	elseif name == "Grizzlyhills" then name = "Grizzly Hills"
	elseif name == "Harbingerofdoom(ru)" then name = "Harbinger of Doom (RU)"
	elseif name == "Howlingfjord" then name = "Howling Fjord"
	elseif name == "Hydraxianwaterlords" then name = "Hydraxian Waterlords"
	elseif name == "Jubei'thos" then name = "Jubei'Thos"
	elseif name == "Kel'thuzad" then name = "Kel'Thuzad"
	elseif name == "Khazmodan" then name = "Khaz Modan"
	elseif name == "Kirintor" then name = "Kirin Tor"
	elseif name == "Krolblade" then name = "Krol Blade"
	elseif name == "Kultiras" then name = "Kul Tiras"
	elseif name == "Kultderverdammten" then name = "Kult der Verdammten"
	elseif name == "Lacroisade\195\169carlate" then name = "La Croisade \195\169carlate"
	elseif name == "Laughingskull" then name = "Laughing Skull"
	elseif name == "Lavalash" then name = "Lava Lash"
	elseif name == "Leishen" then name = "Lei Shen"
	elseif name == "Lesclairvoyants" then name = "Les Clairvoyants"
	elseif name == "Lessentinelles" then name = "Les Sentinelles"
	elseif name == "Lichking" then name = "Lich King"
	elseif name == "Lightning'sblade" then name = "Lightning's Blade"
	elseif name == "Light'shope" then name = "Light's Hope"
	elseif name == "Livingflame" then name = "Living Flame"
	elseif name == "Lonewolf" then name = "Lone Wolf"
	elseif name == "Loserrantes" then name = "Los Errantes"
	elseif name == "Maladath(au)" then name = "Maladath (AU)"
	elseif name == "Mal'ganis" then name = "Mal'Ganis"
	elseif name == "Mar\195\169cagedezangar" then name = "Mar\195\169cage de Zangar"
	elseif name == "Mirageraceway" then name = "Mirage Raceway"
	elseif name == "Mok'nathal" then name = "Mok'Nathal"
	elseif name == "Mol'dar'smoxie" then name = "Mol'dar's Moxie"
	elseif name == "Moonguard" then name = "Moon Guard"
	elseif name == "Nek'rosh" then name = "Nek'Rosh"
	elseif name == "Nethergardekeep" then name = "Nethergarde Keep"
	elseif name == "Oldblanchy" then name = "Old Blanchy"
	elseif name == "Ookook" then name = "Ook Ook"
	elseif name == "Orderofthecloudserpent" then name = "Order of the Cloud Serpent"
	elseif name == "Penance(au)" then name = "Penance (AU)"
	elseif name == "Penance(season)" then name = "Penance (Season)"
	elseif name == "Pozzodell'eternit\195\160" then name = "Pozzo dell'Eternit\195\160"
	elseif name == "Pyrewoodvillage" then name = "Pyrewood Village"
	elseif name == "Quel'thalas" then name = "Quel'Thalas"
	elseif name == "Remulos(au)" then name = "Remulos (AU)"
	elseif name == "Rhok'delar(ru)" then name = "Rhok'delar (RU)"
	elseif name == "Scarletcrusade" then name = "Scarlet Crusade"
	elseif name == "Scarshieldlegion" then name = "Scarshield Legion"
	elseif name == "Shadowcouncil" then name = "Shadow Council"
	elseif name == "Shadowstrike(au)" then name = "Shadowstrike (AU)"
	elseif name == "Shadowstrike(season)" then name = "Shadowstrike (Season)"
	elseif name == "Shatteredhalls" then name = "Shattered Halls"
	elseif name == "Shatteredhand" then name = "Shattered Hand"
	elseif name == "Shimmeringflats" then name = "Shimmering Flats"
	elseif name == "Silverhand" then name = "Silver Hand"
	elseif name == "Silverwinghold" then name = "Silverwing Hold"
	elseif name == "Sistersofelune" then name = "Sisters of Elune"
	elseif name == "Skullrock" then name = "Skull Rock"
	elseif name == "Slip'kik'ssavvy" then name = "Slip'kik's Savvy"
	elseif name == "Steamwheedlecartel" then name = "Steamwheedle Cartel"
	elseif name == "Sundownmarsh" then name = "Sundown Marsh"
	elseif name == "Tarrenmill" then name = "Tarren Mill"
	elseif name == "Templenoir" then name = "Temple noir"
	elseif name == "Tenstorms" then name = "Ten Storms"
	elseif name == "Theforgottencoast" then name = "The Forgotten Coast"
	elseif name == "Themaelstrom" then name = "The Maelstrom"
	elseif name == "Thescryers" then name = "The Scryers"
	elseif name == "Thesha'tar" then name = "The Sha'tar"
	elseif name == "Theunderbog" then name = "The Underbog"
	elseif name == "Theventureco" then name = "The Venture Co"
	elseif name == "Thoriumbrotherhood" then name = "Thorium Brotherhood"
	elseif name == "Throk'feroth" then name = "Throk'Feroth"
	elseif name == "Tolbarad" then name = "Tol Barad"
	elseif name == "Twilight'shammer" then name = "Twilight's Hammer"
	elseif name == "Twistingnether" then name = "Twisting Nether"
	elseif name == "Un'goro" then name = "Un'Goro"
	elseif name == "Wildgrowth" then name = "Wild Growth"
	elseif name == "Worldtree" then name = "World Tree"
	elseif name == "Wyrmrestaccord" then name = "Wyrmrest Accord"
	elseif name == "Wyrmthalak(ru)" then name = "Wyrmthalak (RU)"
	elseif name == "Yojamba(au)" then name = "Yojamba (AU)"
	elseif name == "Zandalartribe" then name = "Zandalar Tribe"
	elseif name == "Zealotblade" then name = "Zealot Blade"
	elseif name == "Zirkeldescenarius" then name = "Zirkel des Cenarius"
	else
		local len  = strlen(origName)
		local sb   = strbyte
		local char = string.char
		local c1
		local c
		local gotP = false

		name = ""

		for count = 1, len do
			c  = sb(origName, count)
			c1 = sb(origName, count+1) or 32

			if ((c1 > 47 and c1 < 58) or (c1 > 64 and c1 < 91) or (c1 == 40)) and gotP == false then
				name = name .. char(c) .. " "

				if (c1 == 40) or (c1 > 47 and c1 < 58) then gotP = true end
			else
				name = name .. char(c)
			end
		end
	end

	return name
end

function M.getServer (name, def)

	local index = string.find(name, "-", 1, true)

	if index ~= nil then
		return string.sub(name, index + 1, string.len(name))
	end

	if def then return def else return V.serverName end
end

function M.removeServer (name, strict)

	if name == nil then
		return nil
	end

	local result = name

	local index = string.find(name, "-", 1, true)

	if strict == nil then
		strict = false
	end

	if index ~= nil then
		local server = M.Proper(string.sub(name, index + 1, string.len(name)));

		if strict == true or server == M.Proper(V.serverName) then
			result = string.sub(name, 1, index - 1)
		end
	end

	return result	
end

function M.addServer (name)

	if not name then return nil end

	if string.find(name, "-", 1, true) == nil then
		return name .. "-" .. V.serverName
	end

	return name
end

----------------------
-- SHARED VARIABLES --
----------------------

V.serverName		= M.Proper(GetRealmName())
V.playerName		= M.addServer(GetUnitName("player"), true)

-- Color yellow: ffff0000
-- Color white: ffffff00
-- Color red: 00ff0000
-- Color Horde red: ffe60000
-- Color Cyan: ff69CCF0

-- Client flavour. This package is built for the Mainline client (Interface
-- 120007); the Camelot TOC loads the same files. wowIsRetail is true only on
-- the real Mainline client, so Mainline-only extras (e.g. the addon
-- compartment) are skipped elsewhere; everything else checks that an API
-- exists before using it.
V.wowIsERA		= false
V.wowIsTBC		= false
V.wowIsWrath	= false
V.wowIsCata		= false
V.wowIsMOP		= false
V.wowIsRetail	= (WOW_PROJECT_ID == nil) or (WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
V.wowIsClassic	= false
V.wowLongName	= V.wowIsRetail and "Mainline" or "Other"
V.wowName		= V.wowLongName

------------------------------------------------------------------------
-- Messages (shared by every module)
------------------------------------------------------------------------
function M.debugMsg (msg)
--	if PourSocialScoreDB.showIgnoreDebug == true then
		--print("|cffffff00Pour Social Score: " .. msg)
--	end
end

function M.ShowMsg (msg)
	print ("|cff33ff99Pour Social Score: |cffffffff" .. (msg or "Critical error"))
end

function M.dayString (value)
	if value == 1 then
		return L["DAY"]
	else
		return L["DAYS"]
	end
end


------------------------------
-- RESIZABLE WINDOW SUPPORT --
------------------------------

-- Adds a drag grip to the bottom-right corner of a top-level window.
--   Left-drag the grip  : resize the window
--   Right-click the grip: reset the window to its default size
-- The size is remembered per window in PourSocialScoreDB.windowSizes[saveKey].
-- opts = { minW, minH, maxW, maxH, saveKey, onResize = function(frame, w, h) }
function M.PSS_MakeResizable(frame, opts)
	if not frame or frame.PSS_ResizeGrip then return frame and frame.PSS_ResizeGrip end
	opts = opts or {}

	local defW, defH = frame:GetWidth(), frame:GetHeight()
	local screenW = (UIParent and UIParent:GetWidth()) or 1920
	local screenH = (UIParent and UIParent:GetHeight()) or 1080
	local minW = opts.minW or math.min(defW, 300)
	local minH = opts.minH or math.min(defH, 200)
	local maxW = math.max(minW, opts.maxW or screenW)
	local maxH = math.max(minH, opts.maxH or screenH)

	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(minW, minH, maxW, maxH)
	else
		-- older client builds
		if frame.SetMinResize then frame:SetMinResize(minW, minH) end
		if frame.SetMaxResize then frame:SetMaxResize(maxW, maxH) end
	end

	local function clamp(w, h)
		return math.max(minW, math.min(maxW, w)), math.max(minH, math.min(maxH, h))
	end

	local function saved()
		local db = PourSocialScoreDB
		if type(db) ~= "table" or not opts.saveKey then return nil end
		db.windowSizes = type(db.windowSizes) == "table" and db.windowSizes or {}
		return db.windowSizes
	end

	-- Restore a previously saved size.
	local store = saved()
	local s = store and store[opts.saveKey]
	if type(s) == "table" and tonumber(s.w) and tonumber(s.h) then
		frame:SetSize(clamp(tonumber(s.w), tonumber(s.h)))
	end

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", opts.gripX or -4, opts.gripY or 4)
	grip:SetFrameLevel(frame:GetFrameLevel() + 20)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame.PSS_ResizeGrip = grip

	local function save()
		local st = saved()
		if st then st[opts.saveKey] = { w = math.floor(frame:GetWidth() + 0.5), h = math.floor(frame:GetHeight() + 0.5) } end
	end

	grip:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		frame.PSS_Sizing = true
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function(self, button)
		if frame.PSS_Sizing then
			frame.PSS_Sizing = nil
			frame:StopMovingOrSizing()
			save()
		elseif button == "RightButton" then
			frame:SetSize(clamp(defW, defH))
			local st = saved()
			if st then st[opts.saveKey] = nil end
		end
	end)
	-- Safety net if the window is hidden mid-drag.
	frame:HookScript("OnHide", function(self)
		if self.PSS_Sizing then
			self.PSS_Sizing = nil
			self:StopMovingOrSizing()
			save()
		end
	end)
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Resize", 1, 1, 1)
		GameTooltip:AddLine("Drag to resize this window.", 0.8, 0.8, 0.8)
		GameTooltip:AddLine("Right-click to reset to the default size.", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

	if opts.onResize then
		frame:HookScript("OnSizeChanged", function(self, w, h) opts.onResize(self, w, h) end)
	end
	return grip
end
