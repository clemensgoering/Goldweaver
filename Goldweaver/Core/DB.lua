-- Goldweaver: SavedVariables lifecycle. Guarantees for users who update the addon (docs/13-ARCHITEKTUR.md §4):
--   1. Data is never reset. Defaults are only filled in where a key is missing; unknown keys (from newer or older
--      versions) are left untouched.
--   2. Structure changes are schema migrations: numbered, additive, run once, and each migration is covered by a test.
--   3. Before any migration the whole database is copied to GoldweaverBackupDB (one generation), restorable with
--      /gw restore. The backup is also written before a destructive user command.
--   4. Only bounded buffers are pruned (price history older than priceHistoryDays, log ring buffers). Learned data,
--      characters, contacts, recipes and checks are kept indefinitely.
--
-- Public API
--   ns.db / ns.cdb                account / character SavedVariables (available from ADDON_LOADED on)
--   ns.DB.Stats()                 counts for the debug report
--   ns.DB.Backup(reason)          copy ns.db into GoldweaverBackupDB
--   ns.DB.RestoreBackup()         replace ns.db with the backup (asks for /reload)
--   ns.INTERFACE                  TOC interface number, compared with the client on login
local ADDON, ns = ...

ns.INTERFACE = 16001
local SCHEMA = 2

local DEFAULTS = {
  schema = SCHEMA,
  settings = { debug = false, favorValueCopper = 500, ahCut = 0.05, mailCostCopper = 30, undercutCopper = 1, priceHistoryDays = 30 },
  chars = {},        -- [fullName] = { role, market, professions = {...}, inventory = {...} }       (Core/Chars.lua)
  prices = {},       -- [marketKey][itemID] = { min, avg, count, seen, days }                        (Core/Price.lua)
  recipes = {},      -- [skillLine] = { name, list, byID, when }                                   (Professions/Adapter.lua)
  observations = {}, -- calibration logs: disenchant results                                        (Modules/Destroy.lua)
  learned = {},      -- answers learned from gameplay                                                (Modules/Learn.lua)
  checks = {},       -- automatic acceptance checks                                                  (Modules/Checks.lua)
  contacts = {},     -- visited trainers and merchants                                               (Modules/Contacts.lua)
  vendors = {},      -- [itemID] = { buy, npc, limited, teaches, when }                              (Modules/Contacts.lua)
  probe = {},        -- raw API probe results                                                        (Core/Probe.lua)
  debug = { errors = {}, log = {} },
}

-- Fills missing keys only. Existing values, including unknown keys, are never changed.
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

local function deepCopy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local out = {}
  seen[t] = out
  for k, v in pairs(t) do out[deepCopy(k, seen)] = deepCopy(v, seen) end
  return out
end

-- Migrations run in order from the stored schema to SCHEMA. Each entry: [toVersion] = function(db) end.
-- Rules: additive only (rename/move, never delete user data), idempotent, covered by tools/tests/migration_test.lua.
local MIGRATIONS = {
  [2] = function(db)
    -- 1 -> 2: "version" became "schema"; nothing else changes here. Character keys and market keys of the first
    -- builds are normalised on login by Chars.Migrate (needs the live realm name).
    db.version = nil
  end,
}

ns.DB = { MIGRATIONS = MIGRATIONS, SCHEMA = SCHEMA }

function ns.DB.Backup(reason, db)
  db = db or ns.db
  GoldweaverBackupDB = {
    when = time(), reason = reason, schema = db and (db.schema or db.version), version = ns.version,
    data = deepCopy(db),
  }
  return GoldweaverBackupDB
end

function ns.DB.HasBackup()
  return type(GoldweaverBackupDB) == "table" and type(GoldweaverBackupDB.data) == "table"
end

-- Replaces the live database with the backup. Takes effect fully after /reload (modules keep references).
function ns.DB.RestoreBackup()
  if not ns.DB.HasBackup() then return false, "kein Backup vorhanden" end
  local restored = deepCopy(GoldweaverBackupDB.data)
  for k in pairs(GoldweaverDB) do GoldweaverDB[k] = nil end
  for k, v in pairs(restored) do GoldweaverDB[k] = v end
  ns.db = GoldweaverDB
  return true
end

local function migrate(db)
  local from = db.schema or db.version or 1
  if from >= SCHEMA then return false end
  ns.DB.Backup(("migration %d -> %d"):format(from, SCHEMA), db)
  for v = from + 1, SCHEMA do
    local fn = MIGRATIONS[v]
    if fn then
      local ok, err = pcall(fn, db)
      if not ok then ns.Health.Record("migration " .. v, err) end
    end
    db.schema = v
  end
  ns.Log("migrated schema", from, "->", SCHEMA)
  return true
end

-- Runs defaults and migrations on an arbitrary table (used by tests and by ADDON_LOADED).
-- The stored schema is read BEFORE defaults are applied: a brand-new database starts at SCHEMA, an existing one
-- without a schema field is from the first builds (schema 1) and gets migrated.
function ns.DB.Prepare(db)
  local isNew = next(db) == nil
  local from = db.schema or db.version or (isNew and SCHEMA or 1)
  applyDefaults(db, DEFAULTS)
  db.schema = from
  return migrate(db)
end

function ns.DB.Stats()
  local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
  local prices = 0
  for _, market in pairs(ns.db.prices or {}) do prices = prices + count(market) end
  return {
    schema = ns.db.schema, chars = count(ns.db.chars), recipeBooks = count(ns.db.recipes), prices = prices,
    contacts = count(ns.db.contacts), vendors = count(ns.db.vendors), errors = count(ns.db.debug and ns.db.debug.errors),
    backup = ns.DB.HasBackup() and (GoldweaverBackupDB.reason .. " @ " .. tostring(GoldweaverBackupDB.when)) or "keins",
  }
end

ns.Events:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  GoldweaverDB = GoldweaverDB or {}
  GoldweaverCharDB = GoldweaverCharDB or {}
  ns.db = GoldweaverDB
  ns.cdb = GoldweaverCharDB
  ns.DB.Prepare(ns.db)

  ns:EachModule(function(modName, module)
    if type(module.Init) == "function" then
      local ok, err = pcall(module.Init, module)
      if not ok then
        ns.Health.Record("init " .. modName, err)
        ns.Print("Modul " .. modName .. " konnte nicht starten: " .. tostring(err))
      end
    end
  end)
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

ns.Slash.Register("backup", function()
  ns.DB.Backup("manuell")
  ns.Print("Backup der Goldweaver-Daten angelegt (GoldweaverBackupDB). Wiederherstellen mit /gw restore.")
end, "copy all Goldweaver data into the backup slot")

ns.Slash.Register("restore", function(arg)
  if arg ~= "confirm" then
    local s = ns.DB.HasBackup() and (GoldweaverBackupDB.reason .. ", Schema " .. tostring(GoldweaverBackupDB.schema)) or "kein Backup"
    return ns.Print(("Backup: %s. Zum Wiederherstellen: /gw restore confirm (danach /reload)."):format(s))
  end
  local ok, err = ns.DB.RestoreBackup()
  ns.Print(ok and "Backup wiederhergestellt. Bitte /reload." or ("Wiederherstellen fehlgeschlagen: " .. tostring(err)))
end, "restore the backup slot (restore confirm)")
