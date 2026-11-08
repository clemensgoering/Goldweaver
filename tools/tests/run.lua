-- Goldweaver headless test runner (Lua 5.1 / LuaJIT). Usage: lua tools/tests/run.lua <repo root>
-- Loads the pure-logic addon files with a minimal WoW stub environment, fires ADDON_LOADED, then runs the
-- inline smoke tests and every tools/tests/*_test.lua (called as chunk(ns, eq, T)).
local root = arg[1] or "."
local ADDON, ns = "Goldweaver", {}

-- Minimal WoW stubs. Extend as modules under test need them.
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) io.write(msg, "\n") end }
SlashCmdList = {}
C_AddOns = { GetAddOnMetadata = function() return "test" end }
C_Timer = { After = function(_, fn) fn() end }
C_Item = {
  GetItemInfo = function() return nil end, GetItemInfoInstant = function() return nil end, RequestLoadItemDataByID = function() end,
  GetItemCount = function() return 0 end, GetItemNameByID = function() return nil end, GetItemIconByID = function() return nil end,
}
C_Container = nil
GetTime = os.clock
time, date = os.time, os.date
-- In the game `issecretvalue` exists at load time; Core/Secret.lua captures it as an upvalue, so the stub is defined before loading.
issecretvalue = function(v) return v == "SECRET" end
UnitFullName = function() return "Testchar", "" end
UnitFactionGroup = function() return "Alliance", "Alliance" end
UnitClassBase = function() return "MAGE" end
UnitLevel = function() return 20 end
GetNormalizedRealmName = function() return "Forever" end
GetProfessions = function() return nil end
GetProfessionInfo = function() return nil end
InCombatLockdown = function() return false end
GetBuildInfo = function() return "1.60.1", "70862", "Nov 6 2026", 16001 end
GetLocale = function() return "enUS" end
GetMoney = function() return 1421800 end
UISpecialFrames = {}
tinsert = table.insert
Minimap = nil -- UI files are not loaded headless
CreateFrame = function()
  local f = { events = {} }
  function f:RegisterEvent(e) self.events[e] = true end
  function f:UnregisterEvent(e) self.events[e] = nil end
  function f:SetScript(_, fn) self.onEvent = fn end
  return f
end

local function loadAddonFile(rel)
  local chunk, err = loadfile(root .. "/Goldweaver/" .. rel)
  assert(chunk, err)
  chunk(ADDON, ns)
end

-- Same order as the TOC for the files without UI dependencies.
for _, rel in ipairs({
  "Locales/enUS.lua", "Core/Init.lua", "Core/Util.lua", "Core/Secret.lua", "Core/Events.lua", "Core/API.lua", "Core/DB.lua",
  "Core/Chars.lua", "Core/Inventory.lua", "Core/Price.lua", "Core/Graph.lua",
  "Data/Disenchant.lua", "Data/Crates.lua", "Data/VendorReagents.lua", "Data/Conversions.lua",
  "Professions/Registry.lua", "Professions/Adapter.lua", "Professions/Tailoring.lua", "Professions/Enchanting.lua",
  "Modules/Advisor.lua", "Modules/Planner.lua", "Modules/CraftProfit.lua", "Modules/Compare.lua", "Modules/Ledger.lua",
  "Modules/Dashboard.lua",
}) do loadAddonFile(rel) end

-- Simulate the client: ADDON_LOADED initialises SavedVariables and module Init().
GoldweaverDB, GoldweaverCharDB = nil, nil
ns.Events.frame.onEvent(nil, "ADDON_LOADED", ADDON)
assert(ns.db and ns.db.settings, "DB not initialised")

-- Test harness
local T = { passed = 0, failed = 0 }
local function eq(a, b, label)
  if a == b then T.passed = T.passed + 1
  else T.failed = T.failed + 1; print(string.format("FAIL %s: expected %s, got %s", label or "", tostring(b), tostring(a))) end
end
function T.near(a, b, tol, label)
  if type(a) == "number" and math.abs(a - b) <= (tol or 1) then T.passed = T.passed + 1
  else T.failed = T.failed + 1; print(string.format("FAIL %s: expected ~%s, got %s", label or "", tostring(b), tostring(a))) end
end

-- Smoke tests for the bootstrap files
eq(ns.Util.Money(0), "0c", "money zero")
eq(ns.Util.Money(99), "99c", "money copper")
eq(ns.Util.Money(150), "1s 50c", "money silver")
eq(ns.Util.Money(123456), "12g 34s 56c", "money gold")
eq(ns.Util.Money(-250), "-2s 50c", "money negative")
eq(ns.Util.AfterCut(10000, 0.05), 9500, "after cut 5%")
eq(ns.Secret.IsSecret("SECRET"), true, "secret detected")
eq(ns.Secret.IsSecret(5), false, "non secret")
eq(ns.Secret.Any(1, "SECRET"), true, "any secret")
eq(ns.Secret.Safe("SECRET", "x"), "x", "safe fallback")
local called = 0
ns.Events:On("TEST_EVENT", function() called = called + 1 end)
ns.Events.frame.onEvent(nil, "TEST_EVENT", 1, 2)
ns.Events.frame.onEvent(nil, "TEST_EVENT", "SECRET")
eq(called, 1, "handler called once")
eq(ns.Events.skipped, 1, "one skipped")

-- Additional test files
local onWindows = package.config:sub(1, 1) == "\\"
local listCmd = onWindows and ('dir /b "' .. root:gsub("/", "\\") .. '\\tools\\tests"') or ('ls "' .. root .. '/tools/tests"')
local p = io.popen(listCmd)
local files = {}
if p then
  for file in p:lines() do if file:match("_test%.lua$") then files[#files + 1] = file end end
  p:close()
end
table.sort(files)
for _, file in ipairs(files) do
  local chunk, err = loadfile(root .. "/tools/tests/" .. file)
  if not chunk then T.failed = T.failed + 1; print("FAIL load " .. file .. ": " .. tostring(err))
  else
    local ok, runErr = pcall(chunk, ns, eq, T)
    if not ok then T.failed = T.failed + 1; print("FAIL " .. file .. ": " .. tostring(runErr)) end
  end
end

print(string.format("tests: %d passed, %d failed (%d test files)", T.passed, T.failed, #files))
os.exit(T.failed == 0 and 0 or 1)
