-- Character registry: Forever name format, market key parsing, migration.
local ns, eq = ...
local Chars = ns.Chars

-- Forever: UnitFullName returns first name and surname
UnitFullName = function() return "Cupedos", "Grel" end
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
GetNormalizedRealmName = function() return "CAMWOWEU4Realm5PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
ns.db.settings.marketKey = nil

local first, surname = Chars.Names()
eq(first, "Cupedos", "first name")
eq(surname, "Grel", "surname")
eq(Chars.FullName(), "Cupedos Grel", "full name with space")
eq(Chars.MarketKey(), "EU-PvE-Horde", "market key from realm name")

local region, ruleset = Chars.ParseRealm("CAMWOW US2 Realm 1 PvP")
eq(region, "US", "US region")
eq(ruleset, "PvP", "PvP ruleset")
region, ruleset = Chars.ParseRealm("CAMWOW EU1 Realm 3 RP PvP")
eq(ruleset, "RPPvP", "RP PvP ruleset")
eq(region, "EU", "EU region on RP PvP")
eq((Chars.ParseRealm("CAMWOW EU1 Realm 3 RP")), "EU", "RP realm region")
eq(select(2, Chars.ParseRealm("CAMWOW EU1 Realm 3 RP")), "RP", "RP ruleset")
eq(Chars.ParseRealm("Some Classic Realm"), nil, "unknown realm pattern")

-- classic-style client: second value equals the realm -> no surname
UnitFullName = function() return "Bob", "CAMWOWEU4Realm5PvE" end
eq(Chars.FullName(), "Bob", "realm as second value is not a surname")
UnitFullName = function() return "Cupedos", "Grel" end

-- Migration of the pre-verification record
ns.db.chars = {}
ns.db.chars["Cupedos-Grel"] = { name = "Cupedos-Grel", role = "main", market = "CAMWOWEU4Realm5PvE-Horde", professions = {} }
ns.db.chars["Alt Name"] = { name = "Alt Name", role = "processor", market = "CAMWOWEU4Realm5PvE-Horde", professions = {} }
ns.db.prices["CAMWOWEU4Realm5PvE-Horde"] = { [2589] = { min = 1 } }
local rec = Chars.Register()
eq(ns.db.chars["Cupedos-Grel"], nil, "old key removed")
eq(rec.name, "Cupedos Grel", "record renamed")
eq(rec.role, "main", "role survives migration")
eq(rec.market, "EU-PvE-Horde", "market normalised for the current character")
eq(ns.db.chars["Alt Name"].market, "EU-PvE-Horde", "market normalised for other characters")
-- other characters written with the old key format are renamed too
ns.db.chars["Cupedos-Bank"] = { name = "Cupedos-Bank", role = "processor", market = "EU-PvE-Horde", professions = {} }
Chars.Migrate()
eq(ns.db.chars["Cupedos-Bank"], nil, "old alt key removed")
eq(ns.db.chars["Cupedos Bank"].role, "processor", "alt renamed with role intact")
eq(ns.db.chars["Cupedos Bank"].surname, "Bank", "surname filled on migration")
eq(ns.db.prices["EU-PvE-Horde"][2589].min, 1, "price table moved to the new market key")
eq(Chars.NormalizeMarket("EU-PvE-Horde"), "EU-PvE-Horde", "already normalised stays")
eq(Chars.NormalizeMarket("Forever-Alliance"), "Forever-Alliance", "unparseable stays")
eq(#Chars.ByRole("processor", "EU-PvE-Horde"), 2, "processors on market")
eq(Chars.Unassigned(), 0, "all roles set")
eq(Chars.SetRole("Alt Name", "none"), true, "set role")
eq(Chars.Unassigned(), 1, "one unassigned")

-- UpdateProfessions merges: learned sets from the Adapter survive a SKILL_LINES_CHANGED refresh
ns.db.chars = {}
local me = Chars.Register()
me.professions[197] = { name = "Schneiderei", rank = 53, maxRank = 75, learned = { [1] = true }, learnedCount = 1, recipeCount = 471 }
GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(idx)
  if idx == 1 then return "Schneiderei", 1, 60, 75, 0, 0, 197 end
  return "Verzauberkunst", 1, 25, 75, 0, 0, 333
end
Chars.UpdateProfessions()
eq(me.professions[197].rank, 60, "rank refreshed")
eq(me.professions[197].learnedCount, 1, "learned count kept")
eq(me.professions[197].learned[1], true, "learned set kept")
eq(me.professions[333].name, "Verzauberkunst", "new profession added")
GetProfessions = function() return 1 end
Chars.UpdateProfessions()
eq(me.professions[333].former ~= nil, true, "unlearned profession marked former, not deleted")
GetProfessions = function() return nil end
GetProfessionInfo = function() return nil end

-- restore stubs for other tests
UnitFullName = function() return "Testchar", "" end
GetRealmName = nil
GetNormalizedRealmName = function() return "Forever" end
UnitFactionGroup = function() return "Alliance", "Alliance" end
ns.db.chars = {}
ns.db.prices = {}
