-- Advisor: option ranking with injected prices.
local ns, eq = ...
local Advisor = ns.Advisor

local prices = {
  [2589] = 50,     -- Linen Cloth
  [2996] = 150,    -- Bolt of Linen
  [10940] = 100,   -- Strange Dust
  [10939] = 500,   -- Greater Magic Essence
  [10978] = 2000,  -- Small Glimmering Shard
  [5555] = 300,    -- a green item
}
local ctx = {
  price = function(id) return prices[id] end,
  graph = ns.Graph,
  settings = { ahCut = 0.05, depositRate = 0.20, sellProbability = 0.70, mailCostCopper = 30, favorValueCopper = 500 },
  disenchant = ns.Data.Disenchant,
  crates = ns.Data.Crates,
  canDisenchant = true,
  needsMail = false,
}

local function find(options, action)
  for _, o in ipairs(options) do if o.action == action then return o end end
end

-- Green level-12 armor, vendor 40c, market 3s: disenchant (437c expected, 415c after cut) beats auction (285 - deposit loss)
local item = { id = 5555, quantity = 1, reqLevel = 12, quality = 2, isWeapon = false, vendorSell = 40 }
local options = Advisor.Evaluate(item, ctx)
eq(options[1].action, "convert", "disenchant is best")
eq(options[1].conversion.kind, "disenchant", "the conversion is the disenchant")
eq(options[1].value, math.floor(437.5 * 0.95), "DE value after cut")
local auction = find(options, "auction")
-- gross 300, cut 15, deposit 40*0.2=8, loss 8*0.3=2.4 -> 282.6 -> 282
eq(auction.value, 282, "auction net")
eq(find(options, "vendor").value, 40, "vendor value")

-- Without an enchanter the disenchant option disappears
local noDE = Advisor.Evaluate(item, setmetatable({ canDisenchant = false }, { __index = ctx }))
eq(find(noDE, "convert"), nil, "no disenchant without enchanter")
eq(noDE[1].action, "auction", "auction best without enchanter")

-- Soulbound items cannot be auctioned
local bound = Advisor.Evaluate({ id = 5555, reqLevel = 12, quality = 2, vendorSell = 40, soulbound = true }, ctx)
eq(find(bound, "auction"), nil, "soulbound: no auction option")

-- Linen Cloth x20 without crates: bolt conversion 10 runs * 150*0.95 = 1425 vs auction 20*50*0.95 = 950 (vendor 0)
local noCrate = setmetatable({ crates = false }, { __index = ctx })
local linen = Advisor.Evaluate({ id = 2589, quantity = 20, vendorSell = 0 }, noCrate)
eq(linen[1].action, "convert", "bolts beat raw cloth at these prices")
eq(linen[1].value, math.floor(10 * 150 * 0.95), "bolt value for 10 runs")
eq(linen[1].runs, 10, "20 cloth = 10 bolts")
eq(find(linen, "crate"), nil, "no crate option when crates are off")
-- textiles bundles are unverified: no crate option unless the user opts in
eq(find(Advisor.Evaluate({ id = 2589, quantity = 20, vendorSell = 0 }, ctx), "crate"), nil, "unverified crate category is skipped")
ns.db.settings.unverifiedCrates = true
-- with crates: 20 linen = one textiles apprentice bundle = 10 favor * 500c = 5000c, which beats both
local withCrate = Advisor.Evaluate({ id = 2589, quantity = 20, vendorSell = 0 }, ctx)
eq(find(withCrate, "crate").value, 5000, "crate value")
eq(withCrate[1].action, "crate", "crate sorted first")
eq(find(Advisor.Evaluate({ id = 2589, quantity = 7, vendorSell = 0 }, ctx), "crate").value, 0, "partial bundle is worth nothing")
ns.db.settings.unverifiedCrates = nil
-- curiosities (verified table) always count: 20 strange dust = 1 bundle
eq(find(Advisor.Evaluate({ id = 10940, quantity = 20, vendorSell = 0 }, ctx), "crate").value, 5000, "verified category counts")

-- Mail cost applies when the item has to travel
local mailed = Advisor.Evaluate({ id = 2589, quantity = 20, vendorSell = 0 }, setmetatable({ needsMail = true, crates = false }, { __index = ctx }))
eq(find(mailed, "auction").value, math.floor(20 * 50 * 0.95) - 30, "mail cost subtracted")

-- Keep option values the item at replacement cost when the planner needs it
local kept = Advisor.Evaluate({ id = 2589, quantity = 20, vendorSell = 0 }, setmetatable({ keepFor = function() return "Bolt of Linen Cloth 1-30" end, crates = false }, { __index = ctx }))
eq(kept[1].action, "keep", "keep wins over selling when needed")
eq(kept[1].value, 1425, "keep ranks at least as high as the best selling option")
eq(kept[1].replacement, 1000, "replacement cost 20 * 50c")
eq(kept[1].detail, "Bolt of Linen Cloth 1-30", "reason passed through")

-- Best()
local best = Advisor.Best(item, ctx)
eq(best.action, "convert", "Best returns top option")

-- Registry seed cost: tailoring 1-30 = 60 linen at 50c
local tailoring = ns.Professions:Get("tailoring")
local cost, cov = ns.Professions.SeedCost(tailoring, 1, 30, ctx.price)
eq(cost, 3000, "seed cost for the first step")
eq(cov, 1, "step fully priced")
local rank, nextRank = ns.Professions.RankFor(tailoring, 80)
eq(rank.name, "Journeyman", "80 skill is journeyman")
eq(nextRank.name, "Expert", "next rank expert")
eq(ns.Professions:BySkillLine(333).key, "enchanting", "skill line lookup")
eq(#ns.Professions:All(), 4, "four profiles loaded by the test runner")
