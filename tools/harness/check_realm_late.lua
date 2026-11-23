-- Realm name late at load (3.9.0.162): GetRealmName is nil or "" while the files load and present from ADDON_LOADED on.
--   PSS_REALM_LATE=nil   lua5.1 tools/harness/run.lua . - - tools/harness/check_realm_late.lua
--   PSS_REALM_LATE=empty lua5.1 tools/harness/run.lua . - - tools/harness/check_realm_late.lua
if (PSS_STUB_REALM_LATE_READS or 0) <= 0 then error("the late realm path ran during file load") end
if type(M.ShowMsg) ~= "function" then error("M.ShowMsg is a function") end
if M.addServer("Bob") ~= "Bob-" .. M.Proper(GetRealmName()) then error("addServer adds the realm") end
if M.removeServer("Tester-" .. GetRealmName()) ~= "Tester" then error("removeServer strips the realm") end
print("realm late: ok")
