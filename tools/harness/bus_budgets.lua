-- The service bus build gate's budget table (service-bus-helper DEC-00192,
-- TST-00191): data, read by check_bus.lua. A stage writes its file's measured
-- figure (loadfile plus collectgarbage("count"); luac -s) and may lower a
-- gate freely; raising one needs the author's OK. Lua 5.1 on the build
-- machine, not the client.
return {
	-- resident KB of a Libraries file after it runs on the stub; measured at
	-- the stage that adds the file
	kb = {
		["PSS_Err.lua"] = { measured = 1.7, gate = 4, stage = "p01 (3.7.0.106)" },
		["PSS_Bus.lua"] = { measured = 4.5, gate = 8, stage = "p01 (3.7.0.106)" },
		["PSS_Store.lua"] = { measured = 1.8, gate = 12, stage = "p03 (3.7.0.106)" },
		["PSS_Index.lua"] = { measured = 2.6, gate = 4, stage = "p04 (3.7.0.106)" },
		["PSS_Query.lua"] = { measured = 6.6, gate = 8, stage = "p04 (3.7.0.106)" },
		["PSS_Entity.lua"] = { measured = 8.2, gate = 10, stage = "p04 (3.7.0.106)" },
		-- the warehouse (one-build plan, 03_Design 15): "design" is the plan's figure; a gate above it is a deviation reported in the build report
		["PSS_Codec.lua"] = { measured = 2.5, gate = 3, stage = "p02 (3.7.0.106)" },
		["PSS_Name.lua"] = { measured = 1.95, gate = 2.5, design = 1, stage = "p08 (3.7.0.106)" },
		-- the author approved the measured figures as the gates of these warehouse files (2026-10-17, coordinator prompt 12, R8-01 a)
		["PSS_WhContainers.lua"] = { measured = 11.74, gate = 12, design = 6, stage = "p07 (3.7.0.106)" },
		["PSS_ItemDict.lua"] = { measured = 3.4, gate = 6, stage = "p06 (3.7.0.106)" },
		["PSS_ItemRead.lua"] = { measured = 5.3, gate = 12, stage = "p08 (3.7.0.106)" },
		["PSS_WhStore.lua"] = { measured = 12.1, gate = 12.5, design = 12, stage = "p08 (3.7.0.106)" },
		["PSS_WhMeta.lua"] = { measured = 3.9, gate = 6, stage = "p09 (3.7.0.106)" },
		["PSS_Money.lua"] = { measured = 5.1, gate = 5.5, stage = "p11 (3.7.0.106)" },
		["PSS_MoneyValue.lua"] = { measured = 2.6, gate = 2.8, stage = "p11 (3.7.0.106)" },
		["PSS_WhIndex.lua"] = { measured = 9.4, gate = 9.5, design = 8, stage = "p10 (3.7.0.106)" },
		["PSS_ItemSearch.lua"] = { measured = 38.4, gate = 40, design = 28, stage = "p12 (3.7.0.106)" },
		["PSS_WhImport.lua"] = { measured = 2.0, gate = 3, stage = "p13 (3.7.0.106)" },
		["PSS_Gw.lua"] = { measured = 1.8, gate = 2.5, stage = "p14 (3.7.0.106)" },
		["PSS_GwSyndicator.lua"] = { measured = 19.4, gate = 20, design = 14, stage = "p14 (3.7.0.106)" },
		["PSS_WhTooltip.lua"] = { measured = 4.6, gate = 6, stage = "p15 (3.7.0.106)" },
		["PSS_WhRows.lua"] = { measured = 1.66, gate = 2, stage = "W-3 F5 (3.7.0.107)" },
		["PSS_WhView.lua"] = { measured = 0.62, gate = 1.5, stage = "W-7 (3.7.0.110)" },
		["PSS_WhCommands.lua"] = { measured = 0.8, gate = 2, stage = "p16 (3.7.0.106)" },
		["PSS_Watch.lua"] = { measured = 15.2, gate = 16, stage = "S3 (3.7.0.104), core" },
		["PSS_Trig.lua"] = { measured = 48.8, gate = 56, stage = "S3 (3.7.0.104)" },
	},
	-- microseconds per hot call
	us = {
		call = { measured = 1.1, gate = 1.6, stage = "p01 (3.7.0.106)" },
		read = { measured = 0.8, gate = 3, stage = "S2 (3.7.0.100)" },
		settle = { measured = 6.9, gate = 20, stage = "S3 (3.7.0.104)" },
		signal = { measured = 0.14, gate = 2, stage = "S3 (3.7.0.104)" },
		join10k = { measured = 5900, gate = 20000, stage = "S2 (3.7.0.100)" },
	},
}
