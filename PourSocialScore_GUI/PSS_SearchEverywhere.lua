------------------------------------------------------------------------
-- POUR SOCIAL SCORE UI - SEARCH EVERYWHERE (warehouse-helper, one-build
-- plan STP-p15; Syndicator parity 5 to 8, 24). One search box over every
-- character, guild bank and the warband. The window only draws: the rows
-- come from M.PSS_WhSearchRows, the gold from M.PSS_WhGold (PSS_WhView.lua,
-- Libraries). Built the first time it is asked for; a window made like a
-- popup (ns.PopupShell: the same frame in all three looks, the title says
-- what it does, Escape closes). A click on a row says where the item is
-- (M.PSS_WhShowLocation). Nothing here listens to core events; the results
-- are made again when the window shows and on every change of the text.
------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local M = ns.M

local win

local function Build()
	local f = ns.PopupShell("PSS_Everywhere", 560, 440)
	win = f
	f.title:SetText("Search Everywhere")
	f.search = ns.NewSearchBox(f, 400, "Name, keyword or numbers: epic & >400", function(text) f.Search(text) end)
	f.search:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -44)
	f.hint = ns.NewText(f, 11)
	f.hint:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -70)
	f.hint:SetAlpha(0.55)
	f.listFrame = CreateFrame("Frame", nil, f)
	f.listFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -88)
	f.listFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 46)
	f.rows = {}
	f.list = ns.NewRows(f.listFrame, {
		rowH = 20, fontSize = 12,
		cols = {
			{ key = "name", text = "Item" },
			{ key = "where", text = "Held by", width = 190 },
			{ key = "total", text = "Total", width = 56, justify = "RIGHT" },
		},
		draw = function(row, i)
			local r = f.rows[i]
			if not r then return end
			row.cells.name:SetText(r.name)
			row.cells.where:SetText(r.where)
			row.cells.total:SetText(tostring(r.total))
		end,
		click = function(_, i)
			local r = f.rows[i]
			if r then M.PSS_WhShowLocation(r.key) end
		end,
	})
	f.money = ns.NewMoneyLine(f, 250)
	f.money:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 18)
	f.money:SetLabel("Gold")
	f.close = ns.PopupButton(f, 100, 24, false)
	f.close:SetText(CLOSE or "Close")
	f.close:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 12)
	f.close:SetScript("OnClick", function() f:Hide() end)
	ns.PopupAbove(f, f.search, f.listFrame, f.money, f.close)
	function f.Search(text)
		f.rows = M.PSS_WhSearchRows(text)
		f.list:SetCount(#f.rows)
		f.list:Redraw()
		if not text or not text:find("%S") then f.hint:SetText("Type to search every character, guild bank and the warband")
		elseif #f.rows == 0 then f.hint:SetText("Nothing found")
		else f.hint:SetText(#f.rows .. " found; click one to see where it is") end
	end
	f:SetScript("OnShow", function()
		local total, breakdown = M.PSS_WhGold()
		f.money:SetMoney(total, breakdown)
		f.Search(f.search:GetText())
	end)
	ns.EscapeCloses(f, "PSS_Everywhere")
end

-- the entry Libraries calls (PSS_WhView.lua, /pss wh)
function M.PSS_EverywhereShow(text)
	ns.Fresh()
	if not win then Build() end
	if text then win.search:SetText(text) end
	win:Show()
	win:Raise()
	return win
end
