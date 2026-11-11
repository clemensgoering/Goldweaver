-- Gathering facts, zone analysis, demand, RestedXP route, autopilot role guess, step builder.
local ns, eq, T = ...
local G, Zones = ns.Data.Gathering, ns.Data.Zones

-- gathering colours (Classic: orange +25, yellow +50, green +100)
eq(G.ColorFor(10, 15), "red", "below requirement")
eq(G.ColorFor(15, 15), "orange", "at requirement")
eq(G.ColorFor(40, 15), "yellow", "+25")
eq(G.ColorFor(65, 15), "green", "+50")
eq(G.ColorFor(115, 15), "grey", "+100")
-- skinning
eq(G.SkinningRequired(10), 1, "level 10 needs 1")
eq(G.SkinningRequired(15), 50, "level 15 needs 50")
eq(G.SkinningRequired(30), 150, "level 30 needs 150")
eq(G.SkinningMaxLevel(142), 28, "142 skins up to 28")
eq(G.SkinningMaxLevel(50), 15, "50 skins up to 15")
eq(G.ClothFor(20), 2592, "wool at 20")
eq(G.ClothFor(52), 14047, "runecloth at 52")
eq(G.LeatherFor(35), 4234, "heavy leather at 35")

-- zones
eq(Zones.list[1454].city, true, "Orgrimmar is a city")
eq(Zones.ForLevel(23)[1].distance, 0, "a zone fits level 23")
local found = false
for _, h in ipairs(Zones.list[1416].herbs) do if h == 3819 then found = true end end
eq(found, true, "Wintersbite in Alterac")

-- character: herbalism 80, skinning 142, level 23
ns.db.chars = {}
UnitFullName = function() return "Cupedos", "Grel" end
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitLevel = function() return 23 end
local me = ns.Chars.Register()
me.level = 23
me.role = "main"
me.professions = { [182] = { name = "Kräuterkunde", rank = 80, maxRank = 150 }, [393] = { name = "Kürschnerei", rank = 142, maxRank = 225 } }

ns.db.prices = {}
ns.Price.Observe(2453, 300, 5, time()) -- Bruiseweed 3s
local report = ns.Field.Analyze(1413, me) -- The Barrens 10-25
eq(report.name, "The Barrens", "zone name")
eq(report.fit, "ok", "level 23 fits 10-25")
eq(#report.gather, 7, "7 herbs, ores hidden without mining")
eq(report.hidden, 3, "3 ores hidden")
local byItem = {}
for _, r in ipairs(report.gather) do byItem[r.item] = r end
eq(byItem[2450].color, "orange", "Briarthorn (70) is orange at 80")
eq(byItem[2453].color, "red", "Bruiseweed (100) too high at 80")
eq(byItem[2453].price, 300, "price attached")
eq(byItem[2770], nil, "copper not listed without mining")
eq(report.mobs.skinColor, "orange", "level 25 beasts are orange at skinning 142")
eq(report.gather[1].hasProfession, true, "own profession first")
eq(report.mobs.cloth, 2592, "wool from humanoids at level 23 in a 10-25 zone")
eq(report.mobs.skinMax, 28, "skinning reaches level 28")
eq(ns.Field.Analyze(1454, me).fit, nil, "cities have no fit")

-- own observations extend a zone
ns.Field.RecordGather("herb", { { item = 3356, qty = 2 } }, 1413)
local r2 = ns.Field.Analyze(1413, me)
local kings
for _, r in ipairs(r2.gather) do if r.item == 3356 then kings = r end end
eq(kings.observed, 2, "observed Kingsblood added to the Barrens")

-- best zones
local best = ns.Field.BestZones(me)
eq(best.herb ~= nil, true, "a herbalism zone is suggested")
eq(best.skin ~= nil, true, "a skinning zone is suggested")

-- RestedXP route (read only, guarded)
eq(ns.Field.Route(), nil, "no RestedXP -> nil")
RXP = { currentGuide = { name = "23-25 Barrens", steps = { { elements = { { zone = 1413 } } }, { elements = { { zone = 1442 }, { zone = 1413 } } } } } }
RXPCData = { currentStep = 1 }
local route = ns.Field.Route()
eq(route.guide, "23-25 Barrens", "guide name")
eq(#route.zones, 2, "two unique zones ahead")
eq(route.zones[2].id, 1442, "Stonetalon next")
RXP = { currentGuide = "broken" }
eq(ns.Field.Route(), nil, "broken RestedXP data is ignored")
RXP, RXPCData = nil, nil

-- demand: a processor with a cached tailoring plan needs bolts -> linen demand via the graph
ns.db.chars["Cupedos Bank"] = { name = "Cupedos Bank", firstName = "Cupedos", role = "processor", market = me.market, level = 6,
  professions = { [197] = { name = "Schneiderei", rank = 40, maxRank = 75, learned = { [102] = true }, learnedCount = 1, when = time() } } }
ns.db.recipes = { [197] = { name = "Schneiderei", list = {
  { id = 102, name = "Linen Belt", outputItemID = 7026, qtyMin = 1, qtyMax = 1, difficulty = 0, reagents = { { item = 2996, qty = 1 }, { item = 2320, qty = 1 } } },
} } }
ns.db.recipes[197].byID = { [102] = ns.db.recipes[197].list[1] }
ns.Demand.Invalidate()
local demand = ns.Demand.Get()
eq(demand[2996] ~= nil, true, "bolts demanded")
eq(demand[2589] ~= nil, true, "linen demanded via the bolt conversion")
eq(demand[2589].qty, demand[2996].qty * 2, "two linen per bolt")
eq(demand[2589].via, 2996, "via the bolt")
local r3 = ns.Field.Analyze(1413, me)
eq(r3.mobs.clothDemand, nil, "wool is not demanded")
eq(ns.Field.Analyze(1411, me).mobs.cloth, 2589, "Durotar humanoids drop linen")
eq(ns.Field.Analyze(1411, me).mobs.clothDemand ~= nil, true, "linen marked as demanded in Durotar")

-- autopilot role guess
local fresh = { name = "New Alt", level = 5, role = "none", market = me.market, professions = { [333] = { name = "Verzauberkunst", rank = 1 } } }
ns.db.chars["New Alt"] = fresh
eq(ns.Autopilot.GuessRole(fresh, me.market), "processor", "crafter alt becomes processor")
fresh.professions = { [182] = { rank = 1 } }
eq(ns.Autopilot.GuessRole(fresh, me.market), nil, "gatherer alt without main slot stays open")
fresh.roleSource = "manual"
eq(ns.Autopilot.GuessRole(fresh, me.market), nil, "manual choice is never overridden")
ns.db.chars["New Alt"] = nil
me.role = "none"
eq(ns.Autopilot.GuessRole(me, me.market), "main", "highest level without a main becomes main")
me.role = "main"
me.professions[165] = { name = "Lederverarbeitung", rank = 81, maxRank = 150 }

-- steps: the main gets a gather step for demanded items in a zone with linen
local steps = ns.Steps.Build(8)
eq(type(steps), "table", "steps built")
T.near(#steps >= 1 and 1 or 0, 1, 0, "at least one step")
eq(steps[1].title ~= nil, true, "steps have titles")

-- cleanup
ns.db.chars, ns.db.recipes, ns.db.prices = {}, nil, {}
ns.db.learned.zoneGathers = nil
ns.Demand.Invalidate()
UnitFullName = function() return "Testchar", "" end
GetRealmName = nil
UnitFactionGroup = function() return "Alliance", "Alliance" end
UnitLevel = function() return 20 end
