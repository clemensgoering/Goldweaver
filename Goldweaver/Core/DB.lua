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
local L = ns.L

ns.INTERFACE = 16001
local SCHEMA = 6

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
  costs = {},        -- [itemID] = { unit, qty, when } what the account paid (merchant, AH)          (Modules/Ledger.lua)
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
  [3] = function(db)
    -- 2 -> 3: remove evidence the first detectors produced by mistake (playtest 09.11.2026). Only machine-made
    -- false positives go; nothing the player entered or collected is touched.
    local learned = db.learned or {}
    for itemID, crate in pairs(learned.crates or {}) do
      if not crate.favor and #(crate.bundles or {}) == 0 then learned.crates[itemID] = nil end
    end
    local checks = db.checks or {}
    if checks.f7crate and tostring(checks.f7crate.detail):find("0 Bündelzeilen, Favor %?") then checks.f7crate = nil end -- locale-ok: matches old stored German text
    -- the blocked background reading turned these red; they re-evaluate on the next login
    for _, id in ipairs({ "load", "selftest", "autoRead" }) do
      if checks[id] and checks[id].status == "fail" then checks[id] = nil end
    end
    -- the client blocks background reading: keep it off unless the player enables it on purpose
    if db.settings and db.settings.autoReadProfessions ~= true then db.settings.autoReadProfessions = nil end
  end,
  [4] = function(db)
    -- 3 -> 4: the "bank" role was merged into "processor" (the processing twink is also the bank)
    for _, rec in pairs(db.chars or {}) do if rec.role == "bank" then rec.role = "processor" end end
  end,
  [5] = function(db)
    -- 4 -> 5: characters' inventory snapshots gain two optional parts for the team view (Modules/Coop.lua):
    -- inventory.mail (items in the inbox) and inventory.incoming (sent to it, not seen yet). Both are filled on
    -- use; nothing existing changes, a malformed value from a test build is dropped.
    for _, rec in pairs(db.chars or {}) do
      local inv = rec.inventory
      if type(inv) == "table" then
        if inv.mail ~= nil and type(inv.mail) ~= "table" then inv.mail = nil end
        if inv.incoming ~= nil and type(inv.incoming) ~= "table" then inv.incoming = nil end
      end
    end
  end,
  [6] = function(db)
    -- 5 -> 6: new account table "costs" (purchase prices for the break-even line); the defaults add it empty.
    if db.costs ~= nil and type(db.costs) ~= "table" then db.costs = nil end
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
  if not ns.DB.HasBackup() then return false, L["no backup available"] end
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
    backup = ns.DB.HasBackup() and (GoldweaverBackupDB.reason .. " @ " .. tostring(GoldweaverBackupDB.when)) or "none",
  }
end

ns.Events:On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  GoldweaverDB = GoldweaverDB or {}
  GoldweaverCharDB = GoldweaverCharDB or {}
  ns.db = GoldweaverDB
  ns.cdb = GoldweaverCharDB
  ns.DB.Prepare(ns.db)
  -- language before any module builds text (settings.language: nil/"auto" = game language)
  ns.Locale.Set(ns.db.settings.language)

  ns:EachModule(function(modName, module)
    if type(module.Init) == "function" then
      local ok, err = pcall(module.Init, module)
      if not ok then
        ns.Health.Record("init " .. modName, err)
        ns.Print((L["Module %s could not start: %s"]):format(modName, tostring(err)))
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
    ns.Print((L["Warning: client interface %s, addon built for %s. Please run /gw debug run and pass on the report."]):format(tostring(interface), tostring(ns.INTERFACE)))
  elseif ns.db.debug.lastBuild ~= build then
    ns.Print((L["New client build %s detected. /gw debug run checks that everything still works."]):format(tostring(build)))
  end
  ns.db.debug.lastBuild = build
end, "DB")

ns.Slash.Register("debug", function(arg)
  local sub = (arg or ""):match("^%S*"):lower()
  if sub == "on" or sub == "off" then
    ns.db.settings.debug = (sub == "on")
    ns.Print((L["debug %s"]):format(ns.db.settings.debug and L["on"] or L["off"]))
  elseif ns.Debug and (sub == "run" or sub == "" or sub == "show") then
    if sub == "show" then ns.Debug.Show() else ns.Debug.Run() end
  else
    ns.Print(L["usage: /gw debug run | show | on | off"])
  end
end, "run the self test and open the report (run|show|on|off)")

ns.Slash.Register("backup", function()
  ns.DB.Backup("manual")
  ns.Print(L["Goldweaver data backed up (GoldweaverBackupDB). Restore with /gw restore."])
end, "copy all Goldweaver data into the backup slot")

ns.Slash.Register("restore", function(arg)
  if arg ~= "confirm" then
    local s = ns.DB.HasBackup() and ((L["%s, schema %s"]):format(L[GoldweaverBackupDB.reason], tostring(GoldweaverBackupDB.schema))) or L["no backup"]
    return ns.Print((L["Backup: %s. To restore: /gw restore confirm (then /reload)."]):format(s))
  end
  local ok, err = ns.DB.RestoreBackup()
  ns.Print(ok and L["Backup restored. Please /reload."] or (L["Restore failed: %s"]):format(tostring(err)))
end, "restore the backup slot (restore confirm)")
