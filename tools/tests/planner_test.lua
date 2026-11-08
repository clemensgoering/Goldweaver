-- Planner on a fake recipe book: candidates, shopping list, next rank, keep reasons, profitable crafts.
local ns, eq, T = ...

-- fake character with Tailoring 40/75 and a cached book
ns.db.chars = {}
UnitFullName = function() return "Cupedos", "Bank" end
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitLevel = function() return 12 end
local rec = ns.Chars.Register()
rec.professions[197] = { name = "Schneiderei", rank = 40, maxRank = 75, learned = { [101] = true, [102] = true, [103] = true }, learnedCount = 3, recipeCount = 4, when = time() }
ns.db.recipes = {
  [197] = {
    name = "Schneiderei", skillLine = 197, when = time(),
    list = {
      { id = 101, name = "Bolt of Linen Cloth", icon = 1, outputItemID = 2996, qtyMin = 1, qtyMax = 1, reagents = { { item = 2589, qty = 2 } }, difficulty = 2 },          -- easy
      { id = 102, name = "Linen Belt", icon = 1, outputItemID = 7026, qtyMin = 1, qtyMax = 1, reagents = { { item = 2996, qty = 1 }, { item = 2320, qty = 1 } }, difficulty = 0 }, -- optimal
      { id = 103, name = "Grey Thing", icon = 1, outputItemID = 9999, qtyMin = 1, qtyMax = 1, reagents = { { item = 2589, qty = 1 } }, difficulty = 3 },                  -- trivial
      { id = 104, name = "Woolen Cape", icon = 1, outputItemID = 2580, qtyMin = 1, qtyMax = 1, reagents = { { item = 2997, qty = 1 } }, difficulty = 0 },                   -- not learned
    },
  },
}
ns.db.recipes[197].byID = {}
for _, r in ipairs(ns.db.recipes[197].list) do ns.db.recipes[197].byID[r.id] = r end

-- prices: linen 50c, bolt 150c, belt 400c, thread vendor 10c
ns.db.prices = {}
local now = time()
ns.Price.Observe(2589, 50, 20, now)
ns.Price.Observe(2996, 150, 10, now)
ns.Price.Observe(7026, 400, 5, now)

eq(#ns.Adapter.Learned(197), 3, "three learned recipes")
eq(#ns.Adapter.Unlearned(197), 1, "one unlearned recipe")
eq(ns.Adapter.Unlearned(197)[1].name, "Woolen Cape", "unlearned is the cape")

local candidates = ns.Planner.Candidates(197)
eq(#candidates, 2, "trivial recipe excluded from skill-up candidates")
-- belt: cost 160 (150 bolt + 10 thread), chance 1.0, product 400*0.95=380 -> net per point = -220 (earns money)
-- bolt: cost 100, chance 0.35, product 142.5 -> net per point = (100-142.5)/0.35 = -121
eq(candidates[1].recipe.name, "Linen Belt", "belt is the cheapest point (it even earns)")
eq(candidates[1].cost, 160, "belt material cost uses vendor ceiling for thread")
T.near(candidates[1].netPerPoint, -220, 1, "belt net per point")
T.near(candidates[2].netPerPoint, -121.4, 1, "bolt net per point")

local plan = ns.Planner.Plan(197)
eq(plan.best.recipe.id, 102, "plan picks the belt")
eq(plan.crafts, 20, "crafts capped at 20 (35 points to cap / chance 1.0)")
eq(#plan.shopping, 2, "two reagents on the shopping list")
eq(plan.shopping[1].need, 20, "need 20 bolts")
eq(plan.shopping[1].buy, 20, "nothing in bags -> buy 20")
eq(plan.shopping[1].cost, 3000, "20 bolts at 150c")
eq(plan.shoppingCost, 3200, "total shopping cost incl. thread")

local rank = ns.Planner.NextRank(197)
eq(rank.current.name, "Apprentice", "40 skill is apprentice")
eq(rank.next.name, "Journeyman", "next is journeyman")
eq(rank.canTrain, false, "level 12 but skill 40 < 50")
eq(rank.needSkill, 10, "ten points missing")
eq(rank.trainer ~= nil, true, "trainer hint from profile")

eq(ns.Planner.KeepReason(2996), "Skill-up: Linen Belt", "bolts are kept for the plan")
eq(ns.Planner.KeepReason(4306), nil, "silk is not needed")

local profitable = ns.Planner.Profitable(197, rec, 5)
eq(profitable[1].recipe.name, "Linen Belt", "belt is the most profitable")
eq(profitable[1].margin, math.floor(400 * 0.95 - 160), "belt margin")

local top = ns.CraftProfit.Top(3)
eq(top[1].professionName, "Schneiderei", "profit ranking carries the profession")

-- Advisor through the live context: linen should be kept (plan needs bolts -> no; linen is not a direct reagent of the belt)
local ctx = ns.Advisor.LiveContext({ crates = false })
local best = ns.Advisor.Best({ id = 2996, quantity = 5, vendorSell = 10 }, ctx)
eq(best.action, "keep", "bolts: keep for the skill-up plan")

-- Dashboard recommendations include the skill-up step
local recs = ns.Dashboard.Recommendations(3)
local found = false
for _, r in ipairs(recs) do if r.text:find("Linen Belt") then found = true end end
eq(found, true, "dashboard recommends the planned craft")

-- Graph rebuild from cached books adds the learned crafts
ns.Graph.RemoveSource("live")
local added = ns.Adapter.RebuildGraph()
eq(added, 3, "three learned crafts with outputs added to the graph")
eq(ns.Graph.conversions["craft:7026"].source, "live", "belt conversion from cached book")

-- cleanup
ns.db.chars = {}
ns.db.recipes = nil
ns.db.prices = {}
ns.Planner.cache = nil
UnitFullName = function() return "Testchar", "" end
GetRealmName = nil
UnitFactionGroup = function() return "Alliance", "Alliance" end
UnitLevel = function() return 20 end
ns.Data.LoadConversions()
