-- Goldweaver: what the team needs. Aggregates the shopping lists of every processor's skill-up plan on this market
-- and expands them one step through the conversion graph (a needed Bolt of Linen Cloth also creates demand for
-- Linen Cloth). The field view and the tooltip use this to mark items as "wanted".
--
-- Public API (ns.Demand)
--   Get() -> { [itemID] = { qty, by = { [charName] = recipeName }, via = itemID? } }   (cached 60 s)
--   For(itemID) -> entry or nil
--   Invalidate()
local ADDON, ns = ...

local Demand = { cache = nil, when = 0 }
ns.Demand = Demand

local TTL = 60

local function add(map, itemID, qty, who, why, via)
  if qty <= 0 then return end
  local e = map[itemID] or { qty = 0, by = {} }
  e.qty = e.qty + qty
  e.by[who] = why
  e.via = e.via or via
  map[itemID] = e
end

local function build()
  local map = {}
  local market = ns.Chars.MarketKey()
  for _, rec in ipairs(ns.Chars.ByRole("processor", market)) do
    for skillLine, p in pairs(rec.professions or {}) do
      if not p.former and ns.Adapter.Book(skillLine) then
        local ok, plan = pcall(ns.Planner.Plan, skillLine, rec)
        if ok and plan and plan.best then
          local why = plan.best.recipe.name
          for _, s in ipairs(plan.shopping or {}) do
            if s.buy > 0 then
              add(map, s.item, s.buy, rec.name, why)
              -- one step down the graph: raw materials that make the needed item
              for _, conv in ipairs(ns.Graph.ForOutput(s.item)) do
                if conv.kind == "craft" or conv.kind == "smelt" then
                  local perRun = conv.outputs[1] and conv.outputs[1].qty or 1
                  local runs = math.ceil(s.buy / math.max(perRun, 0.0001))
                  for _, inp in ipairs(conv.inputs) do add(map, inp.item, inp.qty * runs, rec.name, why, s.item) end
                  break
                end
              end
            end
          end
        end
      end
    end
  end
  return map
end

function Demand.Get()
  if not Demand.cache or time() - Demand.when > TTL then
    local ok, map = pcall(build)
    Demand.cache = ok and map or {}
    if not ok then ns.Health.Record("Demand.build", map) end
    Demand.when = time()
  end
  return Demand.cache
end

function Demand.For(itemID) return Demand.Get()[itemID] end
function Demand.Invalidate() Demand.cache = nil end

ns:RegisterModule("Demand", {
  Init = function()
    ns.Events:On("BAG_UPDATE_DELAYED", Demand.Invalidate, "Demand")
    ns.Events:On("TRADE_SKILL_LIST_UPDATE", Demand.Invalidate, "Demand")
  end,
  SelfTest = function()
    local n = 0
    for _ in pairs(Demand.Get()) do n = n + 1 end
    return { { name = "Processor demand", ok = true, detail = n .. " item(s) wanted" } }
  end,
})
