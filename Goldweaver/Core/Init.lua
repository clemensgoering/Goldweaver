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

function ns.Log(...)
  if ns.db and ns.db.settings and ns.db.settings.debug then ns.Print("[debug]", ...) end
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
SlashCmdList.GOLDWEAVER = function(msg)
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  local h = ns.Slash.handlers[cmd]
  if h then return h.fn(rest) end
  ns.Print("Commands:")
  for name, entry in pairs(ns.Slash.handlers) do
    ns.Print("  /gw " .. name .. (entry.help and (" - " .. entry.help) or ""))
  end
end
