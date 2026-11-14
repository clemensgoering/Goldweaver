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
eq(GoldweaverBackupDB.reason, ("migration 1 -> %d"):format(ns.DB.SCHEMA), "backup reason")
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
eq(GoldweaverBackupDB.reason, ("migration 2 -> %d"):format(ns.DB.SCHEMA), "backup before migration 3")
GoldweaverBackupDB = nil

-- migration 4 merges the bank role into processor
local v3 = { schema = 3, chars = { A = { name = "A", role = "bank" }, B = { name = "B", role = "main" } } }
GoldweaverBackupDB = nil
ns.DB.Prepare(v3)
eq(v3.chars.A.role, "processor", "bank became processor")
eq(v3.chars.B.role, "main", "main unchanged")
GoldweaverBackupDB = nil

-- 4 -> 5: team view mail snapshots are optional; existing inventories stay, malformed values are dropped
local v4 = { schema = 4, chars = {
  A = { name = "A", role = "processor", inventory = { bags = { [2589] = 7 }, mail = "broken" } },
  B = { name = "B", role = "main", inventory = { bags = { [2589] = 3 }, mail = { [2589] = 2 }, incoming = { items = { [2589] = 5 }, when = 1 } } },
  C = { name = "C", role = "main" } } }
GoldweaverBackupDB = nil
ns.DB.Prepare(v4)
eq(v4.schema, ns.DB.SCHEMA, "schema current")
eq(v4.chars.A.inventory.bags[2589], 7, "bags kept")
eq(v4.chars.A.inventory.mail, nil, "malformed mail snapshot dropped")
eq(v4.chars.B.inventory.mail[2589], 2, "mail snapshot kept")
eq(v4.chars.B.inventory.incoming.items[2589], 5, "incoming kept")
eq(v4.chars.C.inventory, nil, "no inventory invented")
eq(GoldweaverBackupDB.reason, ("migration 4 -> %d"):format(ns.DB.SCHEMA), "backup before migration 5")
GoldweaverBackupDB = nil

-- 5 -> 6: costs table added empty, nothing else touched
local v5 = { schema = 5, chars = { A = { name = "A", role = "main" } } }
GoldweaverBackupDB = nil
ns.DB.Prepare(v5)
eq(type(v5.costs), "table", "costs table added")
eq(v5.chars.A.role, "main", "chars untouched by migration 6")
eq(GoldweaverBackupDB.reason, ("migration 5 -> %d"):format(ns.DB.SCHEMA), "backup before migration 6")
GoldweaverBackupDB = nil

-- 6 -> 7: node spots are optional; finds stay, malformed spots dropped
local v6 = { schema = 6, learned = { zoneGathers = { [17] = { [2447] = { kind = "herb", count = 5, spots = "x" }, [2449] = { kind = "herb", count = 2, spots = { { m = 1, x = 1, y = 2 } } } } } } }
GoldweaverBackupDB = nil
ns.DB.Prepare(v6)
eq(v6.learned.zoneGathers[17][2447].count, 5, "finds kept")
eq(v6.learned.zoneGathers[17][2447].spots, nil, "malformed spots dropped")
eq(#v6.learned.zoneGathers[17][2449].spots, 1, "spots kept")
eq(GoldweaverBackupDB.reason, ("migration 6 -> %d"):format(ns.DB.SCHEMA), "backup before migration 7")
GoldweaverBackupDB = nil

-- 7 -> 8: budget data is optional and filled on use; wrong types from test builds are dropped, the rest stays
local v7 = { schema = 7, settings = { cashFirst = "yes", ahCut = 0.05 },
  learned = { gatherPace = "fast", trainers = { Magar = { skillLine = 197 } } },
  chars = {
    A = { name = "A", role = "main", money = 1234, ridingKnown = true, classTraining = { byTrainer = { Urek = { when = 1, services = {} } } } },
    B = { name = "B", role = "processor", money = "lots", ridingKnown = 1, classTraining = { services = { x = 1 } } },
  } }
GoldweaverBackupDB = nil
ns.DB.Prepare(v7)
eq(v7.schema, ns.DB.SCHEMA, "schema current after 8")
eq(v7.chars.A.money, 1234, "money kept")
eq(v7.chars.A.ridingKnown, true, "riding flag kept")
eq(type(v7.chars.A.classTraining.byTrainer.Urek), "table", "class trainer visit kept")
eq(v7.chars.B.money, nil, "money of the wrong type dropped")
eq(v7.chars.B.ridingKnown, nil, "riding flag of the wrong type dropped")
eq(v7.chars.B.classTraining, nil, "old class training shape dropped (read again at the next visit)")
eq(v7.chars.B.role, "processor", "roles untouched by migration 8")
eq(v7.learned.gatherPace, nil, "damaged gathering pace dropped")
eq(v7.learned.trainers.Magar.skillLine, 197, "learned trainers untouched")
eq(v7.settings.cashFirst, nil, "setting of the wrong type dropped")
eq(v7.settings.ahCut, 0.05, "other settings untouched")
eq(GoldweaverBackupDB.reason, ("migration 7 -> %d"):format(ns.DB.SCHEMA), "backup before migration 8")
GoldweaverBackupDB = nil
-- running it again changes nothing (idempotent)
local again = { schema = 7, chars = { A = { name = "A", money = 5, classTraining = { byTrainer = {} } } } }
ns.DB.MIGRATIONS[8](again); ns.DB.MIGRATIONS[8](again)
eq(again.chars.A.money, 5, "migration 8 is idempotent")
GoldweaverBackupDB = nil
