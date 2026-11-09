-- Data safety: defaults never overwrite, migrations are additive, a backup is written first, restore works.
local ns, eq = ...

-- A database as the first builds wrote it (schema field "version", old char key, old market key, unknown keys)
local old = {
  version = 1,
  settings = { debug = true, favorValueCopper = 250, futureSetting = "keep me" },
  chars = { ["Cupedos-Grel"] = { name = "Cupedos-Grel", role = "main", market = "CAMWOWEU4Realm5PvE-Horde", professions = { [165] = { name = "Leder", rank = 81, maxRank = 150 } } } },
  prices = { ["CAMWOWEU4Realm5PvE-Horde"] = { [2589] = { min = 120, avg = 130, count = 3, seen = 1, days = { [20000] = { min = 120, sum = 390, units = 3, n = 3 } } } } },
  somethingFromTheFuture = { a = 1 },
}
GoldweaverBackupDB = nil
local migrated = ns.DB.Prepare(old)
eq(migrated, true, "migration ran")
eq(old.schema, ns.DB.SCHEMA, "schema set")
eq(old.version, nil, "old version field removed")
eq(old.settings.debug, true, "existing setting kept (not reset to default)")
eq(old.settings.favorValueCopper, 250, "custom value kept")
eq(old.settings.futureSetting, "keep me", "unknown setting kept")
eq(old.settings.ahCut, 0.05, "missing default filled")
eq(old.somethingFromTheFuture.a, 1, "unknown top-level table kept")
eq(old.chars["Cupedos-Grel"].role, "main", "character data untouched by schema migration")
eq(old.prices["CAMWOWEU4Realm5PvE-Horde"][2589].min, 120, "prices untouched")
eq(type(old.learned), "table", "new tables added")
eq(type(old.checks), "table", "checks table added")

-- backup written before migrating
eq(ns.DB.HasBackup(), true, "backup exists")
eq(GoldweaverBackupDB.reason, "migration 1 -> 3", "backup reason")
eq(GoldweaverBackupDB.data.version, 1, "backup holds the pre-migration state")
eq(GoldweaverBackupDB.data.chars["Cupedos-Grel"].role, "main", "backup is a deep copy with data")
GoldweaverBackupDB.data.chars["Cupedos-Grel"].role = "bank"
eq(old.chars["Cupedos-Grel"].role, "main", "backup is independent of the live table")

-- running Prepare again is a no-op (idempotent)
GoldweaverBackupDB = nil
eq(ns.DB.Prepare(old), false, "no second migration")
eq(GoldweaverBackupDB, nil, "no backup without migration")

-- the live character migration (needs the realm name) renames keys without losing roles or professions
UnitFullName = function() return "Cupedos", "Grel" end
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
local saveChars, savePrices = ns.db.chars, ns.db.prices
ns.db.chars, ns.db.prices = old.chars, old.prices
ns.Chars.Migrate()
eq(ns.db.chars["Cupedos Grel"].role, "main", "role survives key migration")
eq(ns.db.chars["Cupedos Grel"].professions[165].rank, 81, "professions survive key migration")
eq(ns.db.chars["Cupedos Grel"].market, "EU-PvE-Horde", "market key normalised")
eq(ns.db.prices["EU-PvE-Horde"][2589].min, 120, "price table moved with the market key")
ns.db.chars, ns.db.prices = saveChars, savePrices
UnitFullName = function() return "Testchar", "" end
GetRealmName = nil
UnitFactionGroup = function() return "Alliance", "Alliance" end

-- manual backup and restore on the live db
ns.db.settings.favorValueCopper = 777
ns.DB.Backup("test")
ns.db.settings.favorValueCopper = 1
local ok = ns.DB.RestoreBackup()
eq(ok, true, "restore ok")
eq(ns.db.settings.favorValueCopper, 777, "restored value")
eq(ns.db == GoldweaverDB, true, "ns.db points at the live table after restore")
ns.db.settings.favorValueCopper = 500
GoldweaverBackupDB = nil

-- migration 3 removes machine-made false positives only
local v2 = { schema = 2, settings = { autoReadProfessions = false, favorValueCopper = 300 },
  learned = { crates = { [247786] = { name = "Magiepartikel", lines = {}, bundles = {} }, [5001] = { favor = 10, bundles = { { qty = 20 } } } } },
  checks = { f7crate = { status = "pass", detail = "Magiepartikel: 0 Bündelzeilen, Favor ?" }, load = { status = "fail" }, tooltip = { status = "pass" } } }
GoldweaverBackupDB = nil
ns.DB.Prepare(v2)
eq(v2.learned.crates[247786], nil, "false crate removed")
eq(v2.learned.crates[5001].favor, 10, "real crate kept")
eq(v2.checks.f7crate, nil, "false F7 pass reset")
eq(v2.checks.load, nil, "red load check reset")
eq(v2.checks.tooltip.status, "pass", "other checks kept")
eq(v2.settings.favorValueCopper, 300, "settings kept")
eq(v2.settings.autoReadProfessions, nil, "background reading off by default")
eq(GoldweaverBackupDB.reason, "migration 2 -> 3", "backup before migration 3")
GoldweaverBackupDB = nil
