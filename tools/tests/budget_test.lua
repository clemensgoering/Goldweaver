-- Budget, gold support, level gates and ways to make gold, on the real team of 14.11.2026: a level 28 hunter main
-- (Skinning, Leatherworking) who could not pay the class skills due at 28 (75 s each), and a level 6 mage twink whose
-- Tailoring and Enchanting are stuck at 75 until level 10.
local ns, eq, T = ...

local saved = { chars = ns.db.chars, recipes = ns.db.recipes, prices = ns.db.prices, learned = ns.db.learned.trainers }
ns.db.chars, ns.db.recipes, ns.db.prices = {}, nil, {}
ns.db.learned.trainers = nil
ns.db.settings.cashFirst = nil
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
GetTime = GetTime or function() return os.clock() end

-- twink first, then the main (the main is the character at the keyboard)
UnitFullName = function() return "Cupedos", "Bank" end
UnitLevel = function() return 6 end
local twink = ns.Chars.Register()
twink.role, twink.class, twink.level, twink.money = "processor", "MAGE", 6, 2000
twink.professions[197] = { name = "Schneiderei", rank = 75, maxRank = 75 }
twink.professions[333] = { name = "Verzauberkunst", rank = 75, maxRank = 75 }

UnitFullName = function() return "Cupedos", "Grel" end
UnitLevel = function() return 28 end
local main = ns.Chars.Register()
main.role, main.class, main.level, main.money = "main", "HUNTER", 28, 5000
main.professions[393] = { name = "Kürschnerei", rank = 183, maxRank = 225 }
main.professions[165] = { name = "Lederverarbeitung", rank = 106, maxRank = 150 }
ns.Budget.Invalidate()

-- small helpers ---------------------------------------------------------------------------------------------
eq(ns.Util.MoneyShort(1200000), "120g", "short money: whole gold")
eq(ns.Util.MoneyShort(25200), "2g 52s", "short money: gold and silver")
eq(ns.Util.MoneyShort(7500), "75s", "short money: silver")
eq(ns.Learn.FirstNumber(true, "Schneiderei", 50, true), 50, "skill requirement is the first number (Forever returns the name first)")
eq(ns.Learn.FirstNumber(false, "error"), nil, "failed call gives nil")

-- level gates ----------------------------------------------------------------------------------------------
local gates = ns.Gates.For(twink)
eq(#gates, 2, "twink: two gates (Tailoring, Enchanting)")
eq(gates[1].severity, "blocked", "twink: at the cap, blocked")
eq(gates[1].reqLevel, 10, "Journeyman needs level 10")
eq(gates[1].needLevel, 4, "four levels to go")
eq(#ns.Gates.For(main), 0, "main: Skinning Artisan needs only 25 (gathering), no gate")
local skin = ns.Planner.NextRank(393, main)
eq(skin.reqLevel, 25, "gathering ranks unlock earlier: Artisan Skinning at 25")
local tailorHint = nil
for _, g in ipairs(gates) do if g.skillLine == 197 then tailorHint = ns.Gates.WhileLevelling(g) end end
eq(tailorHint ~= nil and tailorHint:find("2589") ~= nil or (tailorHint or ""):find("Linen") ~= nil or (tailorHint or ""):find("%(") ~= nil, true, "tailoring: collect cloth while levelling")

-- class trainer at level 28 (Urek, 14.11.2026): available = due now, unavailable = later ----------------------
local services = {
  { "Augen des Wildtiers", "available", 14, 1200 }, { "Untote aufspüren", "available", 18, 1600 },
  { "Elementare aufspüren", "available", 26, 7400 }, { "Gezielter Schuss", "available", 28, 7500 },
  { "Tier heilen", "available", 28, 7500 }, { "Ablenkender Schuss", "unavailable", 30, 7600 },
  { "Aspekt des Wildtiers", "unavailable", 30, 7600 },
}
GetNumTrainerServices = function() return #services end
GetTrainerServiceInfo = function(i) return services[i][1], services[i][2], 132000 end
GetTrainerServiceCost = function(i) return services[i][4] end
GetTrainerServiceLevelReq = function(i) return services[i][3] end
UnitName = function() return "Urek Thunderhorn" end
IsTradeskillTrainer = function() return false end
ns.Budget.ReadClassTrainer()
eq(main.classTraining and next(main.classTraining.byTrainer) ~= nil, true, "class trainer read")

local s = ns.Budget.Summary()
eq(s.nowDue >= 25200, true, "due now includes the five available skills (2g 52s)")
eq(s.nowGap > 0, true, "50 s in the bags cannot pay it")
eq(s.strength, "strong", "what is due now and cannot be paid means strong support")
eq(ns.Budget.CashMargin(), 1.5, "strong support: other uses must earn 50 % more")

-- a second visit after learning two skills replaces the list (no double count, learned skills drop out)
table.remove(services, 5); table.remove(services, 4)
UnitName = function() return "Ormak Grimshot" end
ns.Budget.ReadClassTrainer()
local n = 0
for _ in pairs(main.classTraining.byTrainer) do n = n + 1 end
eq(n, 1, "same class trainer group: newest visit replaces the old one")
ns.Budget.Invalidate()
eq(ns.Budget.Summary().nowDue < s.nowDue, true, "learned skills no longer count")

-- riding at 40 lies 12 levels ahead of the main: a goal, shown in the costs by level
local riding = false
for _, e in ipairs(ns.Budget.Summary().later) do if e.kind == "riding" then riding = true end end
eq(riding, true, "riding at 40 is a goal beyond the ten-level horizon of a level 28 main")
local timeline = ns.Budget.Timeline(main)
eq(timeline[1].from, 28, "timeline starts at the current level")
eq(timeline[2].riding, 1200000, "riding sits in the 30-40 band")
eq(#ns.Budget.Timeline(twink) >= 5, true, "twink: bands up to 60")
local twinkRiding = 0
for _, b in ipairs(ns.Budget.Timeline(twink)) do twinkRiding = twinkRiding + b.riding end
eq(twinkRiding, 0, "no riding for the processor (crafts in the city)")

-- gold first in the Advisor: a disenchant worth 20 % more than selling loses under strong support -----------------
local options = ns.Advisor.Evaluate({ id = 1, quantity = 1 }, { cashFirst = true, cashMargin = 1.5, price = function() return nil end,
  graph = { ForInput = function() return {} end } })
eq(#options, 0, "no options without data")
ns.Advisor.RegisterProvider("testDE", function(item) if item.id == 77 then return { action = "convert", value = 120, label = "DE" } end end)
ns.Advisor.RegisterProvider("testAH", function(item) if item.id == 77 then return { action = "auction", value = 100, label = "AH" } end end)
local strong = ns.Advisor.Evaluate({ id = 77 }, { cashFirst = true, cashMargin = 1.5 })
eq(strong[1].action, "auction", "strong support: selling 100 beats disenchanting 120")
eq(strong[1].cashFirst, true, "tooltip learns that gold first decided")
local light = ns.Advisor.Evaluate({ id = 77 }, { cashFirst = true, cashMargin = 1.15 })
eq(light[1].action, "convert", "light support: 120 beats 100 by more than 15 %")
local off = ns.Advisor.Evaluate({ id = 77 }, {})
eq(off[1].action, "convert", "no gold support: the higher value wins")
ns.Advisor.providers.testDE, ns.Advisor.providers.testAH = nil, nil
for i = #ns.Advisor.order, 1, -1 do if ns.Advisor.order[i]:find("^test") then table.remove(ns.Advisor.order, i) end end

-- the setting switches it off
ns.db.settings.cashFirst = false
ns.Budget.Invalidate()
eq(ns.Budget.NeedsCash(), false, "gold support can be switched off")
ns.db.settings.cashFirst = nil

-- ways to make gold: a list with tips for the team's professions, ranked numbers first ------------------------
ns.Earn.Invalidate()
local ways = ns.Earn.List(main)
local tips = 0
for _, w in ipairs(ways) do if not w.perHour and not w.total then tips = tips + 1 end end
eq(tips > 0, true, "profession tips of the team are listed")
eq(ns.Earn.ValueText({ perHour = 25000 }), "≈ 2g 50s 00c/h", "value text per hour")

-- cleanup
GetNumTrainerServices, GetTrainerServiceInfo, GetTrainerServiceCost, GetTrainerServiceLevelReq, IsTradeskillTrainer = nil, nil, nil, nil, nil
ns.db.chars, ns.db.recipes, ns.db.prices = saved.chars, saved.recipes, saved.prices
ns.db.learned.trainers = saved.learned
ns.Budget.Invalidate(); ns.Earn.Invalidate()
