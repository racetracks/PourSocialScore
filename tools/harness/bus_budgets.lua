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
		-- the Spyglass engine (search-helper phase A, DDS-00031 section 2): "design" is the guide's gate
		["PSS_IxPut.lua"] = { measured = 0, gate = 1.5, design = 1.5, stage = "A STP-00235 (3.8.0.115), core" },
		["PSS_Ix.lua"] = { measured = 0, gate = 6, design = 6, stage = "A STP-00232 (3.8.0.115)" },
		["PSS_IxCatalog.lua"] = { measured = 0, gate = 4, design = 4, stage = "A STP-00285 (3.8.0.115)" },
		["PSS_Line.lua"] = { measured = 0, gate = 4, design = 4, stage = "A STP-00233 (3.8.0.115)" },
		["PSS_Seg.lua"] = { measured = 0, gate = 8, design = 8, stage = "A STP-00234 (3.8.0.115)" },
		["PSS_IxDict.lua"] = { measured = 0, gate = 4, design = 4, stage = "A STP-00236 (3.8.0.115)" },
		["PSS_Time.lua"] = { measured = 0, gate = 3, design = 3, stage = "A STP-00237 (3.8.0.115)" },
		["PSS_Pred.lua"] = { measured = 0, gate = 8, design = 8, stage = "A STP-00238 (3.8.0.115)" },
		["PSS_Stats.lua"] = { measured = 0, gate = 10, design = 10, stage = "A STP-00239 (3.8.0.115)" },
		["PSS_Terms.lua"] = { measured = 0, gate = 2, design = 2, stage = "A STP-00240 (3.8.0.115)" },
		["PSS_Psql.lua"] = { measured = 0, gate = 12, design = 12, stage = "A STP-00241 (3.8.0.115)" },
		["PSS_Plan.lua"] = { measured = 0, gate = 6, design = 6, stage = "A STP-00242 (3.8.0.115)" },
		["PSS_IxLog.lua"] = { measured = 0, gate = 5, design = 5, stage = "A STP-00243 (3.8.0.115)" },
		["PSS_IxWh.lua"] = { measured = 0, gate = 4, design = 4, stage = "A STP-00244 (3.8.0.115)" },
		["PSS_IxSocial.lua"] = { measured = 0, gate = 4, design = 4, stage = "A STP-00245 (3.8.0.115)" },
		["PSS_IxCfg.lua"] = { measured = 0, gate = 4, design = 4, stage = "A STP-00246 (3.8.0.115)" },
		["PSS_SQ.lua"] = { measured = 0, gate = 6, design = 6, stage = "A STP-00248 (3.8.0.115)" },
		["PSS_IxExport.lua"] = { measured = 0, gate = 3, design = 3, stage = "A STP-00250 (3.8.0.115)" },
	},
	-- microseconds per hot call
	us = {
		call = { measured = 1.1, gate = 1.6, stage = "p01 (3.7.0.106)" },
		read = { measured = 0.8, gate = 3, stage = "S2 (3.7.0.100)" },
		settle = { measured = 6.9, gate = 20, stage = "S3 (3.7.0.104)" },
		signal = { measured = 0.14, gate = 2, stage = "S3 (3.7.0.104)" },
		join10k = { measured = 5900, gate = 20000, stage = "S2 (3.7.0.100)" },
		-- the Spyglass engine (phase A, STP-00252)
		ixput = { measured = 0, gate = 15, design = 15, stage = "A (3.8.0.115)" },
		decode = { measured = 0, gate = 3, design = 3, stage = "A (3.8.0.115)" },
		segappend = { measured = 0, gate = 5, design = 5, stage = "A (3.8.0.115)" },
		parse = { measured = 0, gate = 500, design = 500, stage = "A (3.8.0.115)" },
		tokens = { measured = 0, gate = 200, design = 200, stage = "A (3.8.0.115)" },
		text2k = { measured = 0, gate = 500, design = 500, stage = "A (3.8.0.115), text search on 2,000 lines" },
		stats20k = { measured = 0, gate = 25000, design = 25000, stage = "A (3.8.0.115), stats count by owner on 20,000 rows" },
		namebuild = { measured = 0, gate = 20000, design = 20000, stage = "A (3.8.0.115), item name index on 5,000 items" },
	},
}
