-- The service bus build gate's budget table (service-bus-helper DEC-00192,
-- TST-00191): data, read by check_bus.lua. A stage writes its file's measured
-- figure (loadfile plus collectgarbage("count"); luac -s) and may lower a
-- gate freely; raising one needs the author's OK. Lua 5.1 on the build
-- machine, not the client.
return {
	-- resident KB of a Libraries file after it runs on the stub; measured at
	-- the stage that adds the file
	kb = {
		["PSS_Bus.lua"] = { measured = 1.3, gate = 8, stage = "S1 (3.7.0.98)" },
		["PSS_Store.lua"] = { measured = 1.5, gate = 12, stage = "S2 (3.7.0.100)" },
		["PSS_Query.lua"] = { measured = 3.7, gate = 8, stage = "S2 (3.7.0.100)" },
		["PSS_Entity.lua"] = { measured = 6.3, gate = 10, stage = "S2 (3.7.0.100)" },
	},
	-- microseconds per hot call
	us = {
		call = { measured = 1.4, gate = 6, stage = "S1 (3.7.0.98)" },
		read = { measured = 0.8, gate = 3, stage = "S2 (3.7.0.100)" },
		join10k = { measured = 5900, gate = 20000, stage = "S2 (3.7.0.100)" },
	},
}
