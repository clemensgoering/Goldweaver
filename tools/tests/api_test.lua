-- Compatibility layer: resolve, safe calls, feature availability, event error isolation, schema.
local ns, eq = ...
local API, Features = ns.API, ns.Features

eq(API.Has("C_Item.GetItemInfo"), true, "stubbed API resolves")
eq(API.Has("C_Nope.Missing"), false, "missing namespace")
local ok, why = API.Call("C_Nope.Missing", 1)
eq(ok, false, "missing call returns false")
eq(why, "missing", "reason missing")
eq(API.failures["C_Nope.Missing"], 1, "failure counted")

C_Item.GetItemInfo = function(id)
  if id == 2589 then return "Linen Cloth", "link", 1, 5, 1, "Trade Goods", "Cloth", 20, "", 123, 13, 7, 5, 0 end
  if id == 666 then error("boom") end
  return nil
end
local info = API.ItemInfo(2589)
eq(info.name, "Linen Cloth", "item info normalised")
eq(info.classID, 7, "classID")
eq(info.sellPrice, 13, "sell price")
eq(API.ItemInfo(1), nil, "uncached item is nil")
eq(API.ItemInfo(666), nil, "erroring API yields nil")
eq(API.failures["C_Item.GetItemInfo"], 1, "error counted once")
C_Item.GetItemInfo = function() return nil end

-- features
local missing = Features.Missing("professions")
eq(#missing > 0, true, "professions feature missing in headless env")
eq((Features.Available("items")), true, "items feature available with stubs")
Features.SetEnabled("items", false)
local avail, reason = Features.Available("items")
eq(avail, false, "feature switched off")
eq(reason, "abgeschaltet", "reason text")
Features.SetEnabled("items", true)
eq((Features.Available("items")), true, "feature back on")
local rows = Features.Status()
eq(#rows >= 10, true, "feature status rows")

-- event error isolation: a handler that always errors is detached after 5 errors
local calls = 0
ns.Events:On("BROKEN_EVENT", function() calls = calls + 1; error("kaputt") end, "Test")
for _ = 1, 7 do ns.Events.frame.onEvent(nil, "BROKEN_EVENT") end
eq(calls, 5, "handler ran five times then was detached")
eq(ns.Health.detached[1], "BROKEN_EVENT (Test)", "detached list names the handler")
eq(#ns.Health.errors >= 5, true, "errors recorded")
eq(#ns.db.debug.errors >= 5, true, "errors persisted to db")

-- schema
eq(ns.db.schema, 2, "schema migrated to 2")
local stats = ns.DB.Stats()
eq(type(stats.chars), "number", "stats available")
