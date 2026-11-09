-- Goldweaver: namespace bootstrap. Loaded first; every other file starts with `local ADDON, ns = ...`.
--
-- Module contract (see docs/13-ARCHITEKTUR.md)
--   ns:RegisterModule(name, module)  module = {
--     Init     = function(self) end,  -- called once after ADDON_LOADED, SavedVariables are ready (ns.db / ns.cdb)
--     SelfTest = function(self) -> { {name, ok, warn?, detail?} },  -- rows for /gw debug run (optional)
--   }
--   Modules register slash commands with ns.Slash.Register and events with ns.Events:On. They never touch each other's
--   SavedVariables tables directly; shared data goes through the owning module's functions (ns.Price, ns.Chars, ...).
--
-- Public API of this file
--   ns.name, ns.version                addon name and version ("dev" in an unpackaged checkout)
--   ns.Print(...)                      chat line with the gold prefix
--   ns.Log(...)                        debug log (ring buffer in GoldweaverDB.debug.log, printed with /gw debug on)
--   ns:RegisterModule(name, module)    see contract above; ns.modules[name]
--   ns.Slash.Register(cmd, fn, help)   /gw <cmd> <rest> -> fn(rest)
--   ns.L                                localisation table (Locales/*.lua), falls back to the key
local ADDON, ns = ...

ns.name = ADDON
-- The packager replaces @project-version@ with the git tag; an unpackaged working copy shows "dev".
ns.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
if type(ns.version) ~= "string" or ns.version:find("@", 1, true) or ns.version == "" then ns.version = "dev" end
ns.modules = {}
ns.L = ns.L or {}
local L = ns.L

-- Single global for slash commands and the optional public API.
Goldweaver = Goldweaver or {}
Goldweaver.ns = ns

function ns.Print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a94eGoldweaver|r: " .. table.concat(parts, " "))
end

-- Debug log: always kept in a ring buffer (last 200 lines) for the report; printed only with /gw debug on.
function ns.Log(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  local line = (date and date("%H:%M:%S") or "") .. " " .. table.concat(parts, " ")
  if ns.db then
    ns.db.debug = ns.db.debug or {}
    ns.db.debug.log = ns.db.debug.log or {}
    table.insert(ns.db.debug.log, line)
    while #ns.db.debug.log > 200 do table.remove(ns.db.debug.log, 1) end
  end
  if ns.db and ns.db.settings and ns.db.settings.debug then ns.Print("[debug]", table.concat(parts, " ")) end
end

function ns:RegisterModule(name, module)
  assert(type(name) == "string" and type(module) == "table", "RegisterModule(name, table)")
  assert(not self.modules[name], "module already registered: " .. name)
  module.name = name
  self.modules[name] = module
  return module
end

-- Sorted iteration over modules (deterministic Init order and report order).
function ns:EachModule(fn)
  local names = {}
  for name in pairs(self.modules) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do fn(name, self.modules[name]) end
end

-- Slash: /gw <command> [args]. Commands are registered by modules via ns.Slash.Register.
ns.Slash = { handlers = {} }
function ns.Slash.Register(cmd, fn, help)
  ns.Slash.handlers[cmd] = { fn = fn, help = help }
end

local function printHelp()
  ns.Print(L["Commands:"])
  local names = {}
  for name in pairs(ns.Slash.handlers) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local entry = ns.Slash.handlers[name]
    ns.Print("  /gw " .. name .. (entry.help and (" - " .. L[entry.help]) or ""))
  end
end

SLASH_GOLDWEAVER1 = "/gw"
SLASH_GOLDWEAVER2 = "/goldweaver"
SlashCmdList.GOLDWEAVER = function(msg)
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    if ns.UI and ns.UI.Toggle then return ns.UI.Toggle() end
    return printHelp()
  end
  if cmd == "help" then return printHelp() end
  local h = ns.Slash.handlers[cmd]
  if h then
    local ok, err = pcall(h.fn, rest)
    if not ok then ns.Health.Record("/gw " .. cmd, err); ns.Print((L["Command failed: %s"]):format(tostring(err))) end
    return
  end
  ns.Print((L["Unknown command: %s"]):format(cmd))
  printHelp()
end
