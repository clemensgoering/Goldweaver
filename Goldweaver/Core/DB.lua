-- Goldweaver: SavedVariables lifecycle with schema versioning and patch detection.
-- ADDON_LOADED: defaults, migrations (SCHEMA), then every module's Init(). PLAYER_LOGIN: client interface check.
local ADDON, ns = ...

ns.INTERFACE = 16001 -- must match ## Interface in the TOC; checked against the running client on login
local SCHEMA = 2

local DEFAULTS = {
  schema = SCHEMA,
  settings = { debug = false, favorValueCopper = 500, ahCut = 0.05, mailCostCopper = 30, undercutCopper = 1 },
  chars = {},        -- [fullName] = { role, market, professions = {...}, inventory = {...} }
  prices = {},       -- [marketKey][itemID] = { min, avg, count, seen, days }
  recipes = {},      -- [skillLine] = { name, list, byID, when }
  observations = {}, -- calibration logs (disenchant results, skill-ups)
  contacts = {},     -- visited trainers and merchants
  vendors = {},      -- [itemID] = { buy, npc, limited, when }
  probe = {},
  debug = { errors = {}, log = {} },
}

local function applyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      if next(v) ~= nil then applyDefaults(dst[k], v) end
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

-- Migrations run in order from the stored schema to SCHEMA. Each entry: [toVersion] = function(db) end
local MIGRATIONS = {
  [2] = function(db)
    -- 1 -> 2: the "version" field became "schema"; character keys/market keys are normalised by Chars.Migrate on login
    db.version = nil
  end,
}

local function migrate(db)
  local from = db.schema or db.version or 1
  for v = from + 1, SCHEMA do
    local fn = MIGRATIONS[v]
    if fn then
      local ok, err = pcall(fn, db)
      if not ok then ns.Health.Record("migration " .. v, err) end
    end
    db.schema = v
  end
end

ns.DB = {}

-- Counts for the debug report.
function ns.DB.Stats()
  local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
  local prices = 0
  for _, market in pairs(ns.db.prices or {}) do prices = prices + count(market) end
  return {
    schema = ns.db.schema, chars = count(ns.db.chars), recipeBooks = count(ns.db.recipes), prices = prices,
    contacts = count(ns.db.contacts), vendors = count(ns.db.vendors), errors = count(ns.db.debug and ns.db.debug.errors),
  }
end

ns.Events:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  GoldweaverDB = GoldweaverDB or {}
  GoldweaverCharDB = GoldweaverCharDB or {}
  applyDefaults(GoldweaverDB, DEFAULTS)
  ns.db = GoldweaverDB
  ns.cdb = GoldweaverCharDB
  migrate(ns.db)

  for modName, module in pairs(ns.modules) do
    if type(module.Init) == "function" then
      local ok, err = pcall(module.Init, module)
      if not ok then
        ns.Health.Record("init " .. modName, err)
        ns.Print("Modul " .. modName .. " konnte nicht starten: " .. tostring(err))
      end
    end
  end
  ns.Log("loaded", ns.version, "schema", ns.db.schema)
end, "DB")

-- Patch detection: a different client interface than the TOC means APIs may have moved. Say so once per build.
ns.Events:On("PLAYER_LOGIN", function()
  local _, build, _, interface = GetBuildInfo()
  if ns.Secret.Any(build, interface) then return end
  ns.db.debug.lastBuild = ns.db.debug.lastBuild or build
  if interface ~= ns.INTERFACE then
    ns.Print(("Achtung: Client-Interface %s, Addon gebaut für %s. Bitte /gw debug run ausführen und den Bericht weitergeben."):format(tostring(interface), tostring(ns.INTERFACE)))
  elseif ns.db.debug.lastBuild ~= build then
    ns.Print(("Neuer Client-Build %s erkannt. /gw debug run prüft, ob alles noch funktioniert."):format(tostring(build)))
  end
  ns.db.debug.lastBuild = build
end, "DB")

ns.Slash.Register("debug", function(arg)
  local sub = (arg or ""):match("^%S*"):lower()
  if sub == "on" or sub == "off" then
    ns.db.settings.debug = (sub == "on")
    ns.Print("debug " .. (ns.db.settings.debug and "on" or "off"))
  elseif ns.Debug and (sub == "run" or sub == "" or sub == "show") then
    if sub == "show" then ns.Debug.Show() else ns.Debug.Run() end
  else
    ns.Print("usage: /gw debug run | show | on | off")
  end
end, "run the self test and open the report (run|show|on|off)")
