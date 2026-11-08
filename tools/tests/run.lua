-- Goldweaver headless test runner (Lua 5.1). Usage: lua tools/tests/run.lua <repo root>
-- Loads selected addon files with a minimal WoW stub environment and runs the tests in tools/tests/*_test.lua.
local root = arg[1] or "."
local ADDON, ns = "Goldweaver", {}

-- Minimal stubs for the pure-logic files. Extend as modules under test need them.
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) io.write(msg, "\n") end }
SlashCmdList = {}
C_AddOns = { GetAddOnMetadata = function() return "test" end }
-- In the game `issecretvalue` exists at load time; Core/Secret.lua captures it as an upvalue, so the stub is defined before loading.
issecretvalue = function(v) return v == "SECRET" end
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

loadAddonFile("Core/Init.lua")
loadAddonFile("Core/Util.lua")
loadAddonFile("Core/Secret.lua")
loadAddonFile("Core/Events.lua")

-- Test harness
local passed, failed = 0, 0
local function eq(a, b, label)
  if a == b then passed = passed + 1
  else failed = failed + 1; print(string.format("FAIL %s: expected %s, got %s", label or "", tostring(b), tostring(a))) end
end

-- Util.Money
eq(ns.Util.Money(0), "0c", "money zero")
eq(ns.Util.Money(99), "99c", "money copper")
eq(ns.Util.Money(150), "1s 50c", "money silver")
eq(ns.Util.Money(123456), "12g 34s 56c", "money gold")
eq(ns.Util.Money(-250), "-2s 50c", "money negative")
eq(ns.Util.AfterCut(10000, 0.05), 9500, "after cut 5%")

-- Secret helpers with the fake secret marker "SECRET"
eq(ns.Secret.IsSecret("SECRET"), true, "secret detected")
eq(ns.Secret.IsSecret(5), false, "non secret")
eq(ns.Secret.Any(1, "SECRET"), true, "any secret")
eq(ns.Secret.Safe("SECRET", "x"), "x", "safe fallback")

-- Event guard skips handlers on secret args
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
if p then
  for file in p:lines() do
    if file:match("_test%.lua$") then
      local chunk = assert(loadfile(root .. "/tools/tests/" .. file))
      local ok, err = pcall(chunk, ns, eq)
      if not ok then failed = failed + 1; print("FAIL " .. file .. ": " .. tostring(err)) end
    end
  end
  p:close()
end

print(string.format("tests: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
