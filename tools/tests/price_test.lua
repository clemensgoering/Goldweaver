-- Price engine: observation store, source order, vendor ceiling, pruning.
local ns, eq, T = ...
local Price = ns.Price
local now = 1762600000 -- fixed timestamp

ns.db.prices = {}
eq(Price.Observed(99999), nil, "nothing observed yet")

Price.Observe(2589, 120, 20, now)      -- Linen Cloth 1s20c x20
Price.Observe(2589, 100, 5, now + 60)  -- cheaper listing later the same day
local copper, age, count = Price.Observed(2589, now + 120)
eq(copper, 100, "observed min is the cheapest of the day")
eq(age, 60, "age counts from the last observation")
eq(count, 2, "two observations")
local rec = ns.db.prices[ns.Chars.MarketKey()][2589]
eq(rec.avg, math.floor((120 * 20 + 100 * 5) / 25), "quantity-weighted average")

-- a new day resets min to that day's listings
Price.Observe(2589, 150, 1, now + 86400 * 2)
eq((Price.Observed(2589, now + 86400 * 2)), 150, "latest day drives min")

-- Source order: a fake market source with priority 5 beats the observed price
Price.RegisterSource("fake", 5, function(itemID) if itemID == 2589 then return 80, 0, 10 end end)
local got = Price.Get(2589)
eq(got.copper, 80, "lowest priority number wins")
eq(got.source, "fake", "source name reported")
eq(got.confidence, "high", "fresh + many observations = high")
Price.RegisterSource("fake", 5, function() return nil end) -- replace with a silent source
got = Price.Get(2589)
eq(got.source, "observed", "falls through to observed")
eq(Price.Confidence(10 * 86400), "low", "old price = low confidence")
eq(Price.Confidence(3 * 86400, 1), "medium", "week-old = medium")

-- Vendor ceiling: Coarse Thread costs 10c at the vendor, so an observed 50c is capped
Price.Observe(2320, 50, 1, now)
got = Price.Get(2320)
eq(got.copper, 10, "vendor buy price caps the market price")
eq(got.source, "vendorBuy", "ceiling source")

-- Unknown item without vendor data has no price
eq(Price.Get(424242), nil, "unknown item has no price")

-- Pruning removes old days and empty records
Price.Observe(4306, 300, 1, now - 86400 * 40)
local removed = Price.Prune(30, now)
eq(removed >= 1, true, "old day pruned")
eq(ns.db.prices[ns.Chars.MarketKey()][4306], nil, "empty record removed")
eq(Price.Observed(2589, now + 86400 * 2) ~= nil, true, "recent record survives pruning")

-- Market key uses the setting override
ns.db.settings.marketKey = "pvp-Horde"
eq(ns.Chars.MarketKey(), "pvp-Horde", "market key override")
ns.db.settings.marketKey = nil
eq(ns.Chars.MarketKey(), "Forever-Alliance", "market key fallback realm-faction")
T.near(1, 1, 0, "harness near works")
