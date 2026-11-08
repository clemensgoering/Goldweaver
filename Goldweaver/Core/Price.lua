-- Goldweaver: price engine. Sources are tried in priority order; the first one that knows the item wins.
-- Every price is per unit in copper and carries {copper, source, age (seconds), confidence}.
-- Pure parts (Observe/Observed/Prune/Confidence) only touch ns.db so the headless tests can drive them.
local ADDON, ns = ...

local Price = { sources = {} }
ns.Price = Price

local DAY = 86400

-- fn(itemID) -> copper, ageSeconds | nil. Lower priority runs first.
function Price.RegisterSource(name, priority, fn)
  for i = #Price.sources, 1, -1 do
    if Price.sources[i].name == name then table.remove(Price.sources, i) end
  end
  Price.sources[#Price.sources + 1] = { name = name, priority = priority, fn = fn }
  table.sort(Price.sources, function(a, b) return a.priority < b.priority end)
end

function Price.Confidence(age, count)
  if not age then return "unknown" end
  if age <= DAY and (count or 1) >= 3 then return "high" end
  if age <= 7 * DAY then return "medium" end
  return "low"
end

local function marketTable(create)
  local key = ns.Chars and ns.Chars.MarketKey and ns.Chars.MarketKey() or "unknown"
  local prices = ns.db.prices
  if not prices[key] and create then prices[key] = {} end
  return prices[key], key
end

-- Record a price the player saw (search page, replicate scan, own sale). quantity defaults to 1.
function Price.Observe(itemID, unitCopper, quantity, now)
  if type(itemID) ~= "number" or type(unitCopper) ~= "number" or unitCopper <= 0 then return end
  quantity = quantity or 1
  now = now or time()
  local market = marketTable(true)
  local rec = market[itemID]
  if not rec then
    rec = { days = {} }
    market[itemID] = rec
  end
  local dayKey = math.floor(now / DAY)
  local day = rec.days[dayKey]
  if not day then
    day = { min = unitCopper, sum = 0, units = 0, n = 0 }
    rec.days[dayKey] = day
  end
  if unitCopper < day.min then day.min = unitCopper end
  day.sum = day.sum + unitCopper * quantity
  day.units = day.units + quantity
  day.n = day.n + 1
  rec.min = day.min
  rec.avg = math.floor(day.sum / day.units)
  rec.count = day.n
  rec.seen = now
  return rec
end

-- Latest observed minimum for the item: copper, ageSeconds, count.
function Price.Observed(itemID, now)
  local market = marketTable(false)
  local rec = market and market[itemID]
  if not rec or not rec.min then return nil end
  now = now or time()
  return rec.min, math.max(0, now - (rec.seen or now)), rec.count or 1
end

function Price.Prune(maxDays, now)
  now = now or time()
  local cutoff = math.floor(now / DAY) - (maxDays or 30)
  local removed = 0
  for _, market in pairs(ns.db.prices) do
    for itemID, rec in pairs(market) do
      for dayKey in pairs(rec.days or {}) do
        if dayKey < cutoff then rec.days[dayKey] = nil; removed = removed + 1 end
      end
      if next(rec.days or {}) == nil then market[itemID] = nil end
    end
  end
  return removed
end

-- Vendor sell price (what a merchant pays). nil until item data is cached.
function Price.VendorSell(itemID)
  if not (C_Item and C_Item.GetItemInfo) then return nil end
  local sell = select(11, C_Item.GetItemInfo(itemID))
  if type(sell) == "number" and sell > 0 then return sell end
  return nil
end

-- Vendor buy price: first what we saw at a merchant ourselves (Modules/Contacts.lua), then the shipped reagent list.
-- Acts as a price ceiling for unlimited-stock vendor goods.
function Price.VendorBuy(itemID)
  local seen = ns.db and ns.db.vendors and ns.db.vendors[itemID]
  if seen and seen.buy and not seen.limited then return seen.buy end
  local reagents = ns.Data and ns.Data.VendorReagents
  local entry = reagents and reagents[itemID]
  return entry and entry.buy or nil
end

function Price.Get(itemID)
  if type(itemID) ~= "number" then return nil end
  local best
  for _, src in ipairs(Price.sources) do
    local ok, copper, age, count = pcall(src.fn, itemID)
    if ok and type(copper) == "number" and copper > 0 then
      best = { copper = copper, source = src.name, age = age, confidence = Price.Confidence(age, count) }
      break
    end
  end
  local ceiling = Price.VendorBuy(itemID)
  if ceiling and (not best or ceiling < best.copper) then
    best = { copper = ceiling, source = "vendorBuy", age = 0, confidence = "high" }
  end
  return best
end

-- Convenience for formulas: copper or nil.
function Price.Copper(itemID)
  local p = Price.Get(itemID)
  return p and p.copper or nil
end

-- Default sources. Optional addons are probed at call time so load order does not matter.
Price.RegisterSource("auctionator", 10, function(itemID)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if not (api and api.GetAuctionPriceByItemID) then return nil end
  local copper = api.GetAuctionPriceByItemID(ADDON, itemID)
  local age = api.GetAuctionAgeByItemID and api.GetAuctionAgeByItemID(ADDON, itemID) or nil
  return copper, age and age * DAY or 0, 3
end)

Price.RegisterSource("tsm", 20, function(itemID)
  if not (TSM_API and TSM_API.GetCustomPriceValue) then return nil end
  return TSM_API.GetCustomPriceValue("DBMinBuyout", "i:" .. itemID), 0, 3
end)

Price.RegisterSource("observed", 30, function(itemID)
  return Price.Observed(itemID)
end)

Price.RegisterSource("vendorSell", 90, function(itemID)
  local sell = Price.VendorSell(itemID)
  return sell, 0, 1
end)

ns:RegisterModule("Price", {
  Init = function()
    Price.Prune(ns.db.settings.priceHistoryDays or 30)
  end,
})
