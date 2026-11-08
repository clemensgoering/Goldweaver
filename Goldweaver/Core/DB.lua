-- Goldweaver: SavedVariables lifecycle. Initialises defaults in ADDON_LOADED and then calls every module's Init().
local ADDON, ns = ...

local DEFAULTS = {
  version = 1,
  settings = { debug = false, favorValueCopper = 500, ahCut = 0.05, mailCostCopper = 30 },
  chars = {},      -- [fullName] = { role = "main"|"processor"|"bank", market = marketKey, professions = {...} }
  prices = {},     -- [marketKey][itemID] = { min, avg, count, seen, history = {...} }
  observations = {}, -- calibration logs (disenchant results, skill-ups)
  probe = {},
}

local function applyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      applyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

ns.Events:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  GoldweaverDB = GoldweaverDB or {}
  GoldweaverCharDB = GoldweaverCharDB or {}
  applyDefaults(GoldweaverDB, DEFAULTS)
  ns.db = GoldweaverDB
  ns.cdb = GoldweaverCharDB

  for modName, module in pairs(ns.modules) do
    if type(module.Init) == "function" then
      local ok, err = pcall(module.Init, module)
      if not ok then ns.Print("module " .. modName .. " failed to init: " .. tostring(err)) end
    end
  end
  ns.Log("loaded", ns.version)
end)

ns.Slash.Register("debug", function(arg)
  ns.db.settings.debug = (arg == "on")
  ns.Print("debug", ns.db.settings.debug and "on" or "off")
end, "on|off")
