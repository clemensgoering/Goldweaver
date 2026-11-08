-- Disenchant table and expected values, crate bundles.
local ns, eq, T = ...
local DE = ns.Data.Disenchant
local Crates = ns.Data.Crates

local out = DE.Outcomes(12, 2, false) -- uncommon armor, requires level 12
eq(#out, 3, "dust, essence, shard")
eq(out[1].item, 10940, "Strange Dust")
eq(out[1].qty, 2.5, "2-3 dust averages 2.5")
eq(out[1].prob, 0.75, "armor mostly dust")
eq(out[2].item, 10939, "Greater Magic Essence at 11-15")
eq(out[3].item, 10978, "Small Glimmering Shard")

local weapon = DE.Outcomes(12, 2, true)
eq(weapon[2].prob, 0.75, "weapons mostly essence")

eq(DE.Outcomes(5, 2, false)[3], nil, "no shard below level 11")
eq(#DE.Outcomes(30, 3, false), 1, "rare: shard only")
eq(DE.Outcomes(30, 3, false)[1].item, 11138, "Small Glowing Shard at 26-30")
eq(DE.Outcomes(58, 4, false)[1].item, 20725, "high epic: Nexus Crystal")
eq(DE.Outcomes(45, 4, false)[1].item, 11178, "low epic: Large Radiant Shard")
eq(DE.Outcomes(20, 1, false), nil, "common items cannot be disenchanted")
eq(DE.Outcomes(99, 2, false)[1].item, 16204, "level clamp to 60 bracket")

local prices = { [10940] = 100, [10939] = 500, [10978] = 2000 }
local priceFn = function(id) return prices[id] end
local ev, cov = DE.ExpectedValue(12, 2, false, priceFn)
-- 0.75*2.5*100 + 0.20*1.5*500 + 0.05*1*2000 = 187.5 + 150 + 100 = 437.5
eq(ev, 437, "expected value floors")
eq(cov, 1, "all outcomes priced")
local _, cov2 = DE.ExpectedValue(12, 2, false, function(id) return id == 10940 and 100 or nil end)
T.near(cov2, 0.75, 0.001, "coverage = priced probability mass")

local conv = DE.Conversion(5555, 12, 2, false)
eq(conv.id, "de:5555", "conversion id")
eq(conv.inputs[1].item, 5555, "input is the item")
eq(#conv.outputs, 3, "outputs copied")

-- Crates
local e = Crates.For(10940)
eq(e.category, "curiosities", "Strange Dust goes into Curiosities")
eq(e.tier, "apprentice", "apprentice tier")
eq(e.bundleQty, 20, "20 dust per bundle")
eq(e.favor, 10, "default favor rate")
eq(Crates.For(424242), nil, "unknown item has no crate")
local v = Crates.Value(10940, 45, 500, false)
eq(v, 2 * 10 * 500, "two whole bundles only")
v = Crates.Value(10940, 10, 500, true)
eq(v, math.floor(0.5 * 10 * 500), "partial allowed")
ns.db.settings.favorPerCrate = { apprentice = 5 }
eq(Crates.For(10940).favor, 5, "favor override from settings")
ns.db.settings.favorPerCrate = nil
