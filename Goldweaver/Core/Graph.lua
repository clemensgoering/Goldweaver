-- Goldweaver: conversion graph. Nodes are item IDs, edges are conversions (craft, disenchant, smelt, vendor, crate).
-- Live recipes from the profession window and static profile data both land here; the Advisor and Planner only read this graph.
-- Conversion = {
--   id = "craft:2996" | "smelt:2840" | "de:<itemID>",   unique, re-adding replaces
--   kind = "craft" | "disenchant" | "smelt" | "cook" | "vendor" | "crate",
--   profession = "tailoring", skill = 1, source = "live" | "profile" | "data",
--   inputs  = { { item = 2589, qty = 2 } },
--   outputs = { { item = 2996, qty = 1, prob = 1 } },   qty may be fractional (expected amount)
--   name = "Bolt of Linen Cloth", recipeID = 2963 (optional)
-- }
local ADDON, ns = ...

local Graph = { conversions = {}, byInput = {}, byOutput = {} }
ns.Graph = Graph

local function index(map, itemID, conv)
  map[itemID] = map[itemID] or {}
  map[itemID][#map[itemID] + 1] = conv
end

local function unindex(map, itemID, conv)
  local list = map[itemID]
  if not list then return end
  for i = #list, 1, -1 do
    if list[i] == conv then table.remove(list, i) end
  end
  if #list == 0 then map[itemID] = nil end
end

function Graph.Add(conv)
  assert(type(conv) == "table" and conv.id, "conversion needs an id")
  assert(type(conv.inputs) == "table" and type(conv.outputs) == "table", "conversion needs inputs and outputs")
  if Graph.conversions[conv.id] then Graph.Remove(conv.id) end
  for _, out in ipairs(conv.outputs) do out.prob = out.prob or 1 end
  Graph.conversions[conv.id] = conv
  for _, inp in ipairs(conv.inputs) do index(Graph.byInput, inp.item, conv) end
  for _, out in ipairs(conv.outputs) do index(Graph.byOutput, out.item, conv) end
  return conv
end

function Graph.Remove(id)
  local conv = Graph.conversions[id]
  if not conv then return end
  for _, inp in ipairs(conv.inputs) do unindex(Graph.byInput, inp.item, conv) end
  for _, out in ipairs(conv.outputs) do unindex(Graph.byOutput, out.item, conv) end
  Graph.conversions[id] = nil
end

-- Remove every conversion from one source (e.g. "live" when a profession window closes and reopens).
function Graph.RemoveSource(source, profession)
  for id, conv in pairs(Graph.conversions) do
    if conv.source == source and (profession == nil or conv.profession == profession) then Graph.Remove(id) end
  end
end

function Graph.ForInput(itemID) return Graph.byInput[itemID] or {} end
function Graph.ForOutput(itemID) return Graph.byOutput[itemID] or {} end

function Graph.InputQty(conv, itemID)
  for _, inp in ipairs(conv.inputs) do
    if inp.item == itemID then return inp.qty end
  end
  return 0
end

-- Expected value of all outputs, priced with priceFn(itemID) -> copper|nil. Returns value, coverage (0..1 of priced output mass).
function Graph.OutputValue(conv, priceFn)
  local value, priced, total = 0, 0, 0
  for _, out in ipairs(conv.outputs) do
    local mass = out.qty * (out.prob or 1)
    total = total + mass
    local p = priceFn(out.item)
    if p then
      value = value + mass * p
      priced = priced + mass
    end
  end
  return value, (total > 0) and (priced / total) or 0
end

-- Cost of inputs, optionally excluding one item (the one being evaluated, which the player already owns).
function Graph.InputCost(conv, priceFn, excludeItem)
  local cost, missing = 0, {}
  for _, inp in ipairs(conv.inputs) do
    if inp.item ~= excludeItem then
      local p = priceFn(inp.item)
      if p then cost = cost + inp.qty * p else missing[#missing + 1] = inp.item end
    end
  end
  return cost, missing
end

-- Net margin of running the conversion once and selling the outputs: outputs after cut minus all inputs at market.
function Graph.Margin(conv, priceFn, cut)
  cut = cut or 0.05
  local value, coverage = Graph.OutputValue(conv, priceFn)
  local cost, missing = Graph.InputCost(conv, priceFn)
  return math.floor(value * (1 - cut) - cost), coverage, missing
end

function Graph.Count()
  local n = 0
  for _ in pairs(Graph.conversions) do n = n + 1 end
  return n
end
