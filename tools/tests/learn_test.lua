-- Checks registry and learning from observations (F6 deposit, F10 mail format, F11 skill-ups, recipe sources).
local ns, eq, T = ...
local Checks, Learn = ns.Checks, ns.Learn

Checks.Reset()
local s = Checks.Summary()
eq(s.pending, s.total, "all checks pending after reset")
eq(s.total >= 25, true, "a substantial check list")
Checks.Pass("tooltip", "Goldweaver: ...")
eq(Checks.Get("tooltip").status, "pass", "pass recorded")
Checks.Fail("load", "boom")
eq(Checks.NextPending(1)[1].id, "load", "failed checks come first in order")
Checks.Pass("load", "ok")
eq(Checks.NextPending(1)[1].id, "interface", "next pending in definition order")

-- F6: flat deposit (Forever beta: 1 silver for every duration)
ns.db.learned = nil
ns.db.settings.depositFlat = nil
for i = 1, 3 do Learn.DepositSample(2589 + i, 20, 13, { 100, 100, 100 }) end
eq(ns.db.learned.deposit.model, "flat", "flat model detected")
eq(ns.db.settings.depositFlat, 100, "flat deposit applied to settings")
eq(Checks.Get("f6deposit").status, "pass", "F6 passes after three samples")
-- advisor uses the flat deposit: gross 20*50=1000, cut 50, deposit loss 100*0.3=30 -> 920
local opts = ns.Advisor.Evaluate({ id = 2589, quantity = 20, vendorSell = 13 }, { price = function() return 50 end, graph = ns.Graph, settings = ns.db.settings, crates = false })
local auction
for _, o in ipairs(opts) do if o.action == "auction" then auction = o end end
eq(auction.value, 920, "flat deposit in auction net")

-- F6: rate model when deposits scale with the vendor price
ns.db.learned = nil
ns.db.settings.depositFlat = nil
Learn.DepositSample(1, 10, 100, { 50, 200, 600 })
Learn.DepositSample(2, 1, 1000, { 50, 200, 600 })
Learn.DepositSample(3, 5, 20, { 5, 20, 60 })
eq(ns.db.learned.deposit.model, "rate", "rate model detected")
T.near(ns.db.learned.deposit.rates[2], 0.2, 0.001, "8 h rate 20 %")
eq(ns.db.settings.depositFlat, nil, "flat cleared")
T.near(ns.db.settings.depositRate, 0.2, 0.001, "rate applied")

-- F10: mail format
ns.db.learned = nil
eq(Learn.MailVariant(), "full", "full name first")
Learn.MailResult("full", false)
eq(Learn.MailVariant(), "first", "falls back to first name after rejection")
Learn.MailResult("first", true)
eq(Learn.MailVariant(), "first", "preferred variant remembered")
eq(Checks.Get("f10mail").status, "pass", "F10 passes")
ns.db.chars["Alt X"] = { name = "Alt X", firstName = "Alt", surname = "X", role = "processor", market = ns.Chars.MarketKey(), professions = {} }
eq(ns.Chars.MailName(ns.db.chars["Alt X"]), "Alt", "MailName uses the learned variant")
ns.db.chars["Alt X"] = nil

-- F11: skill-ups
ns.db.learned = nil
for i = 1, 20 do
  Learn.Craft(1, 100 + i)       -- medium
  Learn.SkillChanged(i % 2 == 0 and 101 + i or 100 + i) -- every second craft skills up
end
local chance, n = Learn.SkillupChance(1)
eq(n, 20, "twenty medium crafts observed")
T.near(chance, 0.5, 0.001, "observed chance 50 %")
eq(ns.Adapter.ChanceFor(1), 0.5, "adapter uses the observed chance")
eq(ns.Adapter.ChanceFor(0), 1.0, "rule of thumb where no data")
eq(Checks.Get("f11skillup").status, "pass", "F11 passes after 15 crafts")

-- recipe fields and enum lookup
Enum = { TradeskillRecipeSourceType = { Trainer = 1, Vendor = 2, Drop = 3 } }
Learn.RecipeFields({ name = "x", learned = false, sourceType = 2, relativeDifficulty = 0 }, { outputItemID = 1, reagentSlotSchematics = {} })
eq(ns.db.learned.recipeFields.info[1], "learned", "info fields sorted")
eq(Learn.EnumName(2, "Source"), "Vendor", "enum name resolved")
local src = Learn.RecipeSource({ id = 999, name = "Unknown Recipe", sourceType = 2 })
eq(src, "Quelle: Vendor", "source from enum")
Enum = nil

-- recipe source from a visited vendor
ns.db.vendors = { [5000] = { buy = 2500, npc = "Händler Hans", limited = true, teaches = 777 } }
ns.db.contacts = { ["Händler Hans"] = { kind = "merchant", zone = "Orgrimmar" } }
local text, kind, itemID = Learn.RecipeSource({ id = 777, name = "Muster" })
eq(kind, "vendor", "vendor source kind")
eq(itemID, 5000, "vendor item id")
eq(text:find("Händler Hans") ~= nil, true, "vendor text names the npc")
ns.db.vendors, ns.db.contacts = {}, {}

-- trainer source and rank requirement
ns.db.learned.trainers = { ["Magar"] = { skillLine = 197, services = { { name = "Muster", skillReq = 20 } }, ranks = { { name = "Geselle", skillReq = 50, levelReq = 10, cost = 500 } } } }
ns.db.contacts = { Magar = { kind = "trainer", zone = "Orgrimmar" } }
local t = Learn.RecipeSource({ id = 1, name = "Muster" })
eq(t, "Lehrer Magar (Orgrimmar) ab Skill 20", "trainer source text")
eq(Learn.TrainerFor(197, 50), "Magar (Orgrimmar), 5s 00c, ab Level 10", "trainer for next rank")
ns.db.learned = nil
ns.db.contacts = {}
Checks.Reset()
