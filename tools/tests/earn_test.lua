-- Ways to make gold (Modules/Earn.lua) and the gathering pace (Modules/Field.lua): ranking, extension point, isolation
-- of a broken source, profession tips by skill, cloth estimate, the sell list (nothing a plan needs, only liquid uses).
local ns, eq, T = ...

local saved = { chars = ns.db.chars, prices = ns.db.prices, pace = ns.db.learned.gatherPace,
  bagItems = ns.Inventory.BagItems, itemInfo = ns.API.ItemInfo, demandFor = ns.Demand.For, best = ns.Advisor.Best }
ns.db.chars, ns.db.prices, ns.db.learned.gatherPace = {}, {}, nil
GetRealmName = function() return "CAMWOW EU4 Realm 5 PvE" end
UnitFactionGroup = function() return "Horde", "Horde" end
UnitFullName = function() return "Cupedos", "Bank" end
UnitLevel = function() return 6 end
local rec = ns.Chars.Register()
rec.role, rec.level = "processor", 6
rec.professions[197] = { name = "Tailoring", rank = 75, maxRank = 75 }

-- value texts ------------------------------------------------------------------------------------------------------------
eq(ns.Earn.ValueText({ perCraft = 3500 }), "+35s 00c each", "per craft")
eq(ns.Earn.ValueText({ total = 20000, minutes = 3 }), "≈ 2g 00s 00c · 3 min", "one-off amount")
eq(ns.Earn.ValueText({ effort = "low" }), "little effort", "tip: effort")

-- the empty bag adds no "sell" way; tips of the team's professions are filtered by skill --------------------------------------
ns.Inventory.BagItems = function() return {} end
ns.Earn.Invalidate()
local list = ns.Earn.List(rec)
local byId = {}
for _, w in ipairs(list) do byId[w.id] = w end
eq(byId.sellNow, nil, "nothing to sell, no way")
eq(byId.tailoring1 ~= nil, true, "tailoring tip at skill 75")
rec.professions[197].rank = 40
ns.Earn.Invalidate()
byId = {}
for _, w in ipairs(ns.Earn.List(rec)) do byId[w.id] = w end
eq(byId.tailoring1, nil, "tailoring tip hidden below its minimum skill")
eq(byId.tip1 ~= nil, true, "general tip for level 6")
rec.professions[197].rank = 75

-- cloth from humanoids: 20 per hour at the own price, after the cut ---------------------------------------------------------
ns.Price.Observe(2589, 100, 20)
ns.Earn.Invalidate()
byId = {}
for _, w in ipairs(ns.Earn.List(rec)) do byId[w.id] = w end
eq(byId.cloth and byId.cloth.perHour, math.floor(20 * 100 * 0.95), "cloth estimate per hour")

-- extension point: a new source is ranked by its numbers; a broken source does not break the list ---------------------------
ns.Earn.RegisterSource("testRich", function() return { { id = "rich", title = "Rich", detail = "", perHour = 10 ^ 7 } } end)
ns.Earn.RegisterSource("testBroken", function() error("broken source") end)
ns.Earn.Invalidate()
local ranked = ns.Earn.List(rec)
eq(ranked[1].id, "rich", "highest estimate first")
local tipsLast = true
local seenTip = false
for _, w in ipairs(ranked) do
  if w.score < 0 then seenTip = true elseif seenTip then tipsLast = false end
end
eq(tipsLast, true, "tips without numbers come after every estimate")
local recorded = false
for _, e in ipairs(ns.Health.errors) do if tostring(e.where):find("earn testBroken") then recorded = true end end
eq(recorded, true, "broken source recorded, list still built")
ns.Earn.sources.testRich, ns.Earn.sources.testBroken = nil, nil
for i = #ns.Earn.order, 1, -1 do if ns.Earn.order[i]:find("^test") then table.remove(ns.Earn.order, i) end end

-- sell list: only liquid uses, never what a plan needs --------------------------------------------------------------------------
ns.Inventory.BagItems = function()
  return { { itemID = 1001, count = 5, isBound = false }, { itemID = 1002, count = 1, isBound = false }, { itemID = 1003, count = 2, isBound = false } }
end
ns.API.ItemInfo = function(id) return { reqLevel = 1, quality = 1, classID = 7, sellPrice = 5 } end
ns.Demand.For = function(id) return id == 1003 and { qty = 2 } or nil end
ns.Advisor.Best = function(item)
  if item.id == 1001 then return { action = "auction", value = 500 } end
  return { action = "convert", value = 900 }
end
local sell = ns.Earn.SellList()
eq(#sell, 1, "only the item whose best use is selling and that no plan needs")
eq(sell[1].item, 1001, "the auction item")

-- gathering pace: default until a quarter of an hour of own farming, then the own pace ------------------------------------------
local nodes, perNode, own = ns.Field.GatherPace()
eq(nodes, 30, "default pace"); eq(own, false, "default is marked as not own")
local clock = 1000000
local realTime = time
time = function() return clock end
for _ = 1, 31 do
  ns.Field.RecordGather("herb", { { item = 2447, qty = 2 } }, 1413)
  clock = clock + 30
end
time = realTime
nodes, perNode, own = ns.Field.GatherPace()
eq(own, true, "own pace after 15 minutes")
T.near(nodes, 120, 1, "one node every 30 s = 120 per hour")
eq(perNode, 2, "items per node from the loot")
-- a long break does not count as farming time
ns.db.learned.gatherPace = { nodes = "x" }
nodes = ns.Field.GatherPace()
eq(nodes, 30, "damaged pace record falls back to the default")

-- cleanup
ns.db.chars, ns.db.prices, ns.db.learned.gatherPace = saved.chars, saved.prices, saved.pace
ns.db.learned.zoneGathers = nil
ns.Inventory.BagItems, ns.API.ItemInfo, ns.Demand.For, ns.Advisor.Best = saved.bagItems, saved.itemInfo, saved.demandFor, saved.best
ns.Earn.Invalidate(); ns.Budget.Invalidate()
