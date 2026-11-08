-- Goldweaver: namespace bootstrap. Loaded first; every other file starts with `local ADDON, ns = ...`.
local ADDON, ns = ...

ns.name = ADDON
ns.version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.modules = {}
ns.L = ns.L or {}

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

-- Modules register here; Init() is called once after ADDON_LOADED for this addon (see Core/DB.lua).
function ns:RegisterModule(name, module)
  assert(type(name) == "string" and type(module) == "table", "RegisterModule(name, table)")
  assert(not self.modules[name], "module already registered: " .. name)
  self.modules[name] = module
  return module
end

-- Slash: /gw <command> [args]. Commands are registered by modules via ns.Slash.Register.
ns.Slash = { handlers = {} }
function ns.Slash.Register(cmd, fn, help)
  ns.Slash.handlers[cmd] = { fn = fn, help = help }
end

SLASH_GOLDWEAVER1 = "/gw"
SLASH_GOLDWEAVER2 = "/goldweaver"
local function printHelp()
  ns.Print("Befehle:")
  local names = {}
  for name in pairs(ns.Slash.handlers) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    local entry = ns.Slash.handlers[name]
    ns.Print("  /gw " .. name .. (entry.help and (" - " .. entry.help) or ""))
  end
end

SlashCmdList.GOLDWEAVER = function(msg)
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    if ns.UI and ns.UI.Toggle then return ns.UI.Toggle() end
    return printHelp()
  end
  if cmd == "help" then return printHelp() end
  local h = ns.Slash.handlers[cmd]
  if h then return h.fn(rest) end
  ns.Print("Unbekannter Befehl: " .. cmd)
  printHelp()
end
