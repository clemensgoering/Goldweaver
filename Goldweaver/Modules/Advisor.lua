-- Goldweaver: decision engine. Given an item and a context of injected functions it ranks every use of the item.
-- Pure logic: no WoW API calls inside Evaluate, so the headless tests cover the formulas. Callers (tooltip, bag overlay,
-- mail list) build the context from the live game and render the result.
--
-- item = { id, quantity = 1, reqLevel, quality, isWeapon, vendorSell, soulbound }
-- ctx  = {
--   price       = function(itemID) -> copper | nil          market price per unit
--   graph       = ns.Graph                                     conversion graph
--   settings    = { ahCut, depositRate, sellProbability, mailCostCopper, favorValueCopper }
--   needsMail   = boolean                                      item must travel to another character first
--   canDisenchant = boolean                                    a processor with Enchanting exists
--   keepFor     = function(itemID) -> reason | nil             planner says this item is needed for a skill-up
--   crates      = ns.Data.Crates (optional)
--   disenchant  = ns.Data.Disenchant (optional)
-- }
-- Returns a list sorted by value desc: { action, value, label, detail, conversion }
local ADDON, ns = ...

local Advisor = {}
ns.Advisor = Advisor

local DEFAULTS = { ahCut = 0.05, depositRate = 0.20, sellProbability = 0.70, mailCostCopper = 30, favorValueCopper = 500 }

local function setting(ctx, key)
  local s = ctx.settings or {}
  local v = s[key]
  if v == nil then v = DEFAULTS[key] end
  return v
end

local function auctionNet(unitPrice, qty, vendorSell, ctx)
  local gross = unitPrice * qty
  local cut = gross * setting(ctx, "ahCut")
  -- deposit is based on the vendor price and lost when the auction does not sell
  local deposit = (vendorSell or 0) * qty * setting(ctx, "depositRate")
  local depositLoss = deposit * (1 - setting(ctx, "sellProbability"))
  return math.floor(gross - cut - depositLoss)
end

function Advisor.Evaluate(item, ctx)
  assert(type(item) == "table" and item.id, "Advisor.Evaluate(item, ctx) needs item.id")
  ctx = ctx or {}
  local price = ctx.price or function() return nil end
  local graph = ctx.graph or ns.Graph
  local qty = item.quantity or 1
  local mail = ctx.needsMail and setting(ctx, "mailCostCopper") or 0
  local options = {}

  -- 1. vendor
  if item.vendorSell and item.vendorSell > 0 then
    options[#options + 1] = { action = "vendor", value = item.vendorSell * qty, label = "Vendor" }
  end

  -- 2. sell raw on the auction house (not for soulbound items)
  local market = price(item.id)
  if market and not item.soulbound then
    options[#options + 1] = { action = "auction", value = auctionNet(market, qty, item.vendorSell, ctx) - mail, label = "Auction house", unitPrice = market }
  end

  -- 3. conversions where this item is an input (graph edges + on-demand disenchant)
  local conversions = {}
  for _, conv in ipairs(graph.ForInput(item.id)) do conversions[#conversions + 1] = conv end
  if ctx.canDisenchant and ctx.disenchant and item.quality and item.reqLevel then
    local de = ctx.disenchant.Conversion(item.id, item.reqLevel, item.quality, item.isWeapon)
    if de then conversions[#conversions + 1] = de end
  end
  for _, conv in ipairs(conversions) do
    local inputQty = graph.InputQty(conv, item.id)
    if inputQty > 0 then
      local outValue, coverage = graph.OutputValue(conv, price)
      local otherCost, missing = graph.InputCost(conv, price, item.id)
      if coverage > 0 then
        local runs = qty / inputQty
        local net = (outValue * (1 - setting(ctx, "ahCut")) - otherCost) * runs - mail
        options[#options + 1] = {
          action = "convert", value = math.floor(net), label = conv.name or conv.kind, conversion = conv,
          coverage = coverage, missingInputs = missing, runs = runs,
        }
      end
    end
  end

  -- 4. crate for Merchant's Favor
  if ctx.crates then
    local favorValue = setting(ctx, "favorValueCopper")
    local value, entry = ctx.crates.Value(item.id, qty, favorValue, false)
    if value and entry then
      options[#options + 1] = {
        action = "crate", value = value - mail, label = "Waylaid Crate (" .. entry.tier .. ")",
        detail = { bundleQty = entry.bundleQty, favor = entry.favor, partial = qty < entry.bundleQty },
      }
    end
  end

  -- 5. keep for a planned skill-up. Worth at least the replacement cost at market (no cut); when the planner needs
  --    the item it also outranks every selling option, otherwise the plan would have to buy the item back.
  if ctx.keepFor then
    local reason = ctx.keepFor(item.id)
    if reason then
      local replacement = (market or item.vendorSell or 0) * qty
      local bestOther = 0
      for _, o in ipairs(options) do if o.value > bestOther then bestOther = o.value end end
      options[#options + 1] = { action = "keep", value = math.max(replacement, bestOther), label = "Keep", detail = reason, replacement = replacement }
    end
  end

  -- ties: keep first (the plan needs the item), then alphabetical for a stable order
  local TIE = { keep = 0 }
  table.sort(options, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    local ta, tb = TIE[a.action] or 1, TIE[b.action] or 1
    if ta ~= tb then return ta < tb end
    return a.action < b.action
  end)
  return options
end

-- Best option or nil.
function Advisor.Best(item, ctx)
  local options = Advisor.Evaluate(item, ctx)
  return options[1], options
end

-- Builds the live context from the game state. Kept separate so modules can override pieces.
function Advisor.LiveContext(overrides)
  local ctx = {
    price = ns.Price.Copper,
    graph = ns.Graph,
    settings = ns.db and ns.db.settings or {},
    crates = ns.Data and ns.Data.Crates,
    disenchant = ns.Data and ns.Data.Disenchant,
    canDisenchant = false,
    needsMail = false,
  }
  if ns.Chars and ns.Chars.WithProfession then
    local ENCHANTING = 333
    ctx.canDisenchant = #ns.Chars.WithProfession(ENCHANTING, ns.Chars.MarketKey()) > 0
    local me = ns.Chars.Current()
    ctx.needsMail = me ~= nil and me.role == "main"
  end
  if ns.Planner and ns.Planner.KeepReason then ctx.keepFor = ns.Planner.KeepReason end
  for k, v in pairs(overrides or {}) do ctx[k] = v end
  return ctx
end

ns:RegisterModule("Advisor", {})
