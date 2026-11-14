-- Goldweaver: decision engine. Given an item and a context of injected functions it ranks every use of the item.
-- Pure logic: no WoW API calls inside Evaluate, so the headless tests cover the formulas. Callers (tooltip, bag
-- overlay, mail list) build the context with LiveContext() and render the result.
--
-- Extension point: option providers. Each provider looks at (item, ctx) and returns zero or more options.
--   ns.Advisor.RegisterProvider(name, function(item, ctx, helpers) -> option | {options} | nil end)
-- Built-in providers: vendor, auction, convert (graph edges + on-demand disenchant), crate, keep.
--
-- item = { id, quantity = 1, reqLevel, quality, isWeapon, vendorSell, soulbound }
-- ctx  = {
--   price       = function(itemID) -> copper | nil          market price per unit
--   graph       = ns.Graph                                     conversion graph
--   settings    = { ahCut, depositRate, depositFlat, sellProbability, mailCostCopper, favorValueCopper }
--   needsMail   = boolean                                      item must travel to another character first
--   canDisenchant = boolean                                    an enchanter exists on this market
--   keepFor     = function(itemID) -> reason | nil             planner says this item is needed for a skill-up
--   crates      = ns.Data.Crates | false                       crate option on/off
--   disenchant  = ns.Data.Disenchant
--   cashFirst   = boolean                                      gold is short (Modules/Budget.lua): selling outranks
--   cashMargin  = number                                       converting and crates unless they earn this factor more
-- }
-- option = { action, value (copper), label, detail?, conversion?, coverage?, runs?, unitPrice?, replacement? }
-- Evaluate returns the options sorted by value desc; ties: keep first, then alphabetical by action.
local ADDON, ns = ...
local L = ns.L

local Advisor = { providers = {}, order = {} }
ns.Advisor = Advisor

local DEFAULTS = { ahCut = 0.05, depositRate = 0.20, sellProbability = 0.70, mailCostCopper = 30, favorValueCopper = 500 }

local function setting(ctx, key)
  local s = ctx.settings or {}
  local v = s[key]
  if v == nil then v = DEFAULTS[key] end
  return v
end

-- Net proceeds of selling qty units at unitPrice: minus cut, minus expected deposit loss.
local function auctionNet(unitPrice, qty, vendorSell, ctx)
  local gross = unitPrice * qty
  local cut = gross * setting(ctx, "ahCut")
  -- deposit: a learned flat amount per auction (Forever: 1 silver observed) or a rate of the vendor price; lost when unsold
  local deposit
  local flat = ctx.settings and ctx.settings.depositFlat
  if flat then deposit = flat else deposit = (vendorSell or 0) * qty * setting(ctx, "depositRate") end
  local depositLoss = deposit * (1 - setting(ctx, "sellProbability"))
  return math.floor(gross - cut - depositLoss)
end

local helpers = { setting = setting, auctionNet = auctionNet }

function Advisor.RegisterProvider(name, fn)
  assert(type(name) == "string" and type(fn) == "function", "RegisterProvider(name, fn)")
  if not Advisor.providers[name] then Advisor.order[#Advisor.order + 1] = name end
  Advisor.providers[name] = fn
end

-- Built-in providers --------------------------------------------------------------------------------

Advisor.RegisterProvider("vendor", function(item)
  if item.vendorSell and item.vendorSell > 0 then
    return { action = "vendor", value = item.vendorSell * (item.quantity or 1), label = L["Vendor"] }
  end
end)

Advisor.RegisterProvider("auction", function(item, ctx, h)
  if item.soulbound then return nil end
  local market = ctx.price(item.id)
  if not market then return nil end
  local qty = item.quantity or 1
  local mail = ctx.needsMail and h.setting(ctx, "mailCostCopper") or 0
  return { action = "auction", value = h.auctionNet(market, qty, item.vendorSell, ctx) - mail, label = L["Auction house"], unitPrice = market }
end)

Advisor.RegisterProvider("convert", function(item, ctx, h)
  local graph = ctx.graph or ns.Graph
  local qty = item.quantity or 1
  local mail = ctx.needsMail and h.setting(ctx, "mailCostCopper") or 0
  local conversions = {}
  for _, conv in ipairs(graph.ForInput(item.id)) do conversions[#conversions + 1] = conv end
  if ctx.canDisenchant and ctx.disenchant and item.quality and item.reqLevel then
    local de = ctx.disenchant.Conversion(item.id, item.reqLevel, item.quality, item.isWeapon)
    if de then conversions[#conversions + 1] = de end
  end
  local out = {}
  for _, conv in ipairs(conversions) do
    local inputQty = graph.InputQty(conv, item.id)
    if inputQty > 0 then
      local outValue, coverage = graph.OutputValue(conv, ctx.price)
      local otherCost, missing = graph.InputCost(conv, ctx.price, item.id)
      if coverage > 0 then
        local runs = qty / inputQty
        local net = (outValue * (1 - h.setting(ctx, "ahCut")) - otherCost) * runs - mail
        out[#out + 1] = {
          action = "convert", value = math.floor(net), label = conv.name or conv.kind, conversion = conv,
          coverage = coverage, missingInputs = missing, runs = runs,
        }
      end
    end
  end
  return out
end)

Advisor.RegisterProvider("crate", function(item, ctx, h)
  if not ctx.crates then return nil end
  local qty = item.quantity or 1
  local mail = ctx.needsMail and h.setting(ctx, "mailCostCopper") or 0
  local value, entry = ctx.crates.Value(item.id, qty, h.setting(ctx, "favorValueCopper"), false)
  if not (value and entry) then return nil end
  return {
    action = "crate", value = value - mail, label = "Waylaid Crate (" .. entry.tier .. ")",
    detail = { bundleQty = entry.bundleQty, favor = entry.favor, partial = qty < entry.bundleQty },
  }
end)

-- "keep" sees the other options (passed as ctx._options) so it can outrank them when the plan needs the item.
Advisor.RegisterProvider("keep", function(item, ctx)
  if not ctx.keepFor then return nil end
  local reason = ctx.keepFor(item.id)
  if not reason then return nil end
  local market = ctx.price(item.id)
  local replacement = (market or item.vendorSell or 0) * (item.quantity or 1)
  local bestOther = 0
  for _, o in ipairs(ctx._options or {}) do if o.value > bestOther then bestOther = o.value end end
  return { action = "keep", value = math.max(replacement, bestOther), label = L["Keep"], detail = reason, replacement = replacement }
end)

-- Evaluation ----------------------------------------------------------------------------------------

local TIE = { keep = 0 }
-- Gold first: a disenchant, craft or crate only wins when it beats selling by the budget's margin (15 % when gold is
-- a little short, 50 % when it is very short), because its gold comes later (another character, another sale) or
-- never (crate favor).
local CASH_MARGIN = 1.25 -- when a caller sets cashFirst without a margin
local NON_CASH = { convert = true, crate = true }

function Advisor.Evaluate(item, ctx)
  assert(type(item) == "table" and item.id, "Advisor.Evaluate(item, ctx) needs item.id")
  ctx = ctx or {}
  ctx.price = ctx.price or function() return nil end
  ctx.graph = ctx.graph or ns.Graph
  local options = {}
  ctx._options = options
  for _, name in ipairs(Advisor.order) do
    local ok, result = pcall(Advisor.providers[name], item, ctx, helpers)
    if not ok then
      ns.Health.Record("advisor provider " .. name, result)
    elseif type(result) == "table" then
      if result.action then options[#options + 1] = result
      else for _, o in ipairs(result) do options[#options + 1] = o end end
    end
  end
  ctx._options = nil
  local topValue
  for _, o in ipairs(options) do
    o.sortValue = (ctx.cashFirst and NON_CASH[o.action] and o.value > 0) and (o.value / (ctx.cashMargin or CASH_MARGIN)) or o.value
    if not topValue or o.value > topValue then topValue = o.value end
  end
  table.sort(options, function(a, b)
    if a.sortValue ~= b.sortValue then return a.sortValue > b.sortValue end
    local ta, tb = TIE[a.action] or 1, TIE[b.action] or 1
    if ta ~= tb then return ta < tb end
    return a.action < b.action
  end)
  -- tell the tooltip when gold first changed the answer
  if options[1] and topValue and options[1].value < topValue then options[1].cashFirst = true end
  return options
end

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
    local ENCHANTING = ns.Professions and ns.Professions.SKILL_LINES.enchanting or 333
    ctx.canDisenchant = #ns.Chars.WithProfession(ENCHANTING, ns.Chars.MarketKey()) > 0
    local me = ns.Chars.Current()
    ctx.needsMail = me ~= nil and me.role == "main"
  end
  if ns.Planner and ns.Planner.KeepReason then ctx.keepFor = ns.Planner.KeepReason end
  if ns.Budget and ns.Budget.NeedsCash then ctx.cashFirst, ctx.cashMargin = ns.Budget.NeedsCash(), ns.Budget.CashMargin() end
  for k, v in pairs(overrides or {}) do ctx[k] = v end
  return ctx
end

ns:RegisterModule("Advisor", {
  SelfTest = function()
    return { { name = "Option providers", ok = #Advisor.order >= 5, detail = table.concat(Advisor.order, ", ") } }
  end,
})
