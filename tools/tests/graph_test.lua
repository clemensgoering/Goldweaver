-- Conversion graph: indexing, replacement by id, margins.
local ns, eq = ...
local Graph = ns.Graph

eq(Graph.Count() >= 15, true, "static conversions loaded by Data.LoadConversions")
eq(#Graph.ForInput(2589), 1, "Linen Cloth feeds one conversion (bolt)")
eq(Graph.ForOutput(2996)[1].id, "craft:2996", "bolt produced by craft:2996")
eq(#Graph.ForInput(2840), 1, "Copper Bar is an input of bronze smelting")

local prices = { [2589] = 50, [2996] = 150, [2840] = 200, [3576] = 300, [2841] = 400 }
local priceFn = function(id) return prices[id] end

local bolt = Graph.conversions["craft:2996"]
local value, coverage = Graph.OutputValue(bolt, priceFn)
eq(value, 150, "bolt output value")
eq(coverage, 1, "fully priced")
local cost, missing = Graph.InputCost(bolt, priceFn)
eq(cost, 100, "2 linen at 50c")
eq(#missing, 0, "no missing inputs")
eq(Graph.Margin(bolt, priceFn, 0.05), math.floor(150 * 0.95 - 100), "margin after 5% cut")
eq(Graph.InputQty(bolt, 2589), 2, "input qty lookup")
eq(Graph.InputQty(bolt, 4306), 0, "non-input qty is 0")

local bronze = Graph.conversions["smelt:2841"]
eq((Graph.OutputValue(bronze, priceFn)), 800, "2 bronze bars")
eq((Graph.InputCost(bronze, priceFn, 2840)), 300, "exclude the owned item from input cost")

-- Replacing a profile edge with a live edge of the same id
Graph.Add({ id = "craft:2996", kind = "craft", profession = "tailoring", source = "live", inputs = { { item = 2589, qty = 2 } }, outputs = { { item = 2996, qty = 1 } }, name = "Bolt of Linen Cloth (live)" })
eq(#Graph.ForInput(2589), 1, "replacement does not duplicate the index")
eq(Graph.conversions["craft:2996"].source, "live", "live edge replaced the profile edge")

-- Probabilistic outputs
Graph.Add({ id = "test:prob", kind = "disenchant", source = "data", inputs = { { item = 777, qty = 1 } }, outputs = { { item = 2589, qty = 2, prob = 0.5 }, { item = 999, qty = 1, prob = 0.5 } } })
local v, cov = Graph.OutputValue(Graph.conversions["test:prob"], priceFn)
eq(v, 50, "expected value = 0.5 * 2 * 50")
eq(cov, 2 / 3, "coverage by output mass (1.0 of 1.5 priced)")
Graph.Remove("test:prob")
eq(Graph.conversions["test:prob"], nil, "removed")
eq(#Graph.ForInput(777), 0, "index cleaned")

-- RemoveSource only touches the named source/profession
local before = Graph.Count()
Graph.RemoveSource("live", "tailoring")
eq(Graph.Count(), before - 1, "live tailoring edge removed")
ns.Data.LoadConversions() -- restore for later tests
