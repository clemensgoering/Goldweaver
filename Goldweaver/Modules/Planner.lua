-- Goldweaver: skill-up planner. Works on the cached recipe books (Professions/Adapter.lua) and live prices.
-- For a profession it answers: which learned recipe gives the cheapest expected skill point right now, what the next
-- rank needs, which reagents are missing (bags, bank, alts), and which items should be kept for that plan.
local ADDON, ns = ...

local Planner = {}
ns.Planner = Planner

local function priceOf(itemID) return ns.Price.Copper(itemID) end

-- Reagent cost of one craft; returns cost, coverage (0..1 of reagent quantity priced), missingPrices{}
function Planner.CraftCost(recipe)
  local cost, priced, total, missing = 0, 0, 0, {}
  for _, r in ipairs(recipe.reagents or {}) do
    total = total + r.qty
    local p = priceOf(r.item)
    if p then cost = cost + p * r.qty; priced = priced + r.qty else missing[#missing + 1] = r.item end
  end
  return cost, total > 0 and priced / total or 0, missing
end

-- Candidate steps: learned recipes that still give skill-ups, ranked by expected cost per skill point.
function Planner.Candidates(skillLine, rec)
  local out = {}
  local p = rec and rec.professions and rec.professions[skillLine]
  local skill = p and p.rank or 0
  for _, recipe in ipairs(ns.Adapter.Learned(skillLine, rec)) do
    local chance = ns.Adapter.ChanceFor(recipe.difficulty)
    -- canSkillUp/maxTrivialLevel come from the client when available and beat the colour heuristic
    if recipe.canSkillUp == false then chance = 0 end
    if recipe.maxTrivialLevel and recipe.maxTrivialLevel > 0 and skill >= recipe.maxTrivialLevel then chance = 0 end
    if chance and chance > 0 and #(recipe.reagents or {}) > 0 and not recipe.isSalvage and not recipe.isGathering then
      local cost, coverage = Planner.CraftCost(recipe)
      -- what the product is worth after the cut offsets part of the cost (sold or used)
      local productValue = 0
      if recipe.outputItemID then
        local unit = priceOf(recipe.outputItemID)
        if unit then productValue = unit * ((recipe.qtyMin + recipe.qtyMax) / 2) * (1 - (ns.db.settings.ahCut or 0.05)) end
      end
      -- points this recipe can still give before it turns grey (nil when the client does not say)
      local pointsLeft = recipe.maxTrivialLevel and recipe.maxTrivialLevel > 0 and math.max(0, recipe.maxTrivialLevel - skill) or nil
      out[#out + 1] = {
        recipe = recipe, chance = chance, cost = cost, coverage = coverage, productValue = productValue,
        netPerPoint = (cost - productValue) / chance, costPerPoint = cost / chance, pointsLeft = pointsLeft,
      }
    end
  end
  table.sort(out, function(a, b)
    if a.coverage ~= b.coverage and (a.coverage == 0 or b.coverage == 0) then return a.coverage > b.coverage end
    return a.netPerPoint < b.netPerPoint
  end)
  return out
end

-- Shopping list for `crafts` crafts of a recipe, minus what we already have.
function Planner.Shopping(recipe, crafts)
  local list = {}
  for _, r in ipairs(recipe.reagents or {}) do
    local need = r.qty * crafts
    local have, breakdown = ns.Inventory.Count(r.item, { bank = true, alts = true })
    local p = priceOf(r.item)
    local buy = math.max(0, need - have)
    list[#list + 1] = {
      item = r.item, need = need, have = have, bags = breakdown.bags, bank = breakdown.bank, alts = breakdown.alts,
      buy = buy, unitPrice = p, cost = p and buy * p or nil,
    }
  end
  return list
end

-- Next rank info for a profession on this character.
function Planner.NextRank(skillLine, rec)
  rec = rec or ns.Chars.Current()
  local p = rec and rec.professions and rec.professions[skillLine]
  local profile = ns.Professions:BySkillLine(skillLine)
  if not (p and profile) then return nil end
  local rank, nextRank = ns.Professions.RankFor(profile, p.rank or 0)
  local level = rec.level or (UnitLevel and UnitLevel("player")) or 0
  local info = { current = rank, next = nextRank, skill = p.rank or 0, maxSkill = p.maxRank or rank.max, level = level }
  if nextRank then
    info.canTrain = (p.rank or 0) >= nextRank.reqSkill and level >= nextRank.reqLevel
    info.needSkill = math.max(0, nextRank.reqSkill - (p.rank or 0))
    info.needLevel = math.max(0, nextRank.reqLevel - level)
    -- a trainer we actually met beats the guide text
    local seen = ns.Learn and ns.Learn.TrainerFor and ns.Learn.TrainerFor(skillLine, nextRank.reqSkill)
    info.trainer = seen or (profile.trainers and profile.trainers[nextRank.name]) or nil
    info.trainerSeen = seen ~= nil
  end
  info.capped = (p.rank or 0) >= (p.maxRank or rank.max)
  return info
end

-- The plan: best step now (recipe, suggested crafts until the next rank cap), shopping list, rank info.
function Planner.Plan(skillLine, rec)
  rec = rec or ns.Chars.Current()
  local rankInfo = Planner.NextRank(skillLine, rec)
  local candidates = Planner.Candidates(skillLine, rec)
  local best = candidates[1]
  local plan = { skillLine = skillLine, rank = rankInfo, candidates = candidates, best = best }
  if best and rankInfo then
    local pointsToCap = math.max(1, (rankInfo.maxSkill or 0) - (rankInfo.skill or 0))
    if best.pointsLeft and best.pointsLeft > 0 then pointsToCap = math.min(pointsToCap, best.pointsLeft) end
    local crafts = math.min(20, math.max(1, math.ceil(pointsToCap / best.chance)))
    plan.crafts = crafts
    plan.shopping = Planner.Shopping(best.recipe, crafts)
    plan.shoppingCost = 0
    plan.shoppingPriced = true
    for _, s in ipairs(plan.shopping) do
      if s.cost then plan.shoppingCost = plan.shoppingCost + s.cost elseif s.buy > 0 then plan.shoppingPriced = false end
    end
  end
  return plan
end

-- Items wanted by any plan of this character: the Advisor's "keep" reason.
function Planner.KeepReason(itemID)
  local rec = ns.Chars.Current()
  if not (rec and rec.professions) then return nil end
  for skillLine in pairs(rec.professions) do
    local plan = Planner.cache and Planner.cache[skillLine]
    if not plan or (time() - (plan.when or 0)) > 30 then
      plan = Planner.Plan(skillLine, rec)
      plan.when = time()
      Planner.cache = Planner.cache or {}
      Planner.cache[skillLine] = plan
    end
    if plan.best then
      for _, r in ipairs(plan.best.recipe.reagents or {}) do
        if r.item == itemID then return ("Skill-up: %s"):format(plan.best.recipe.name) end
      end
    end
  end
  return nil
end

-- Profitable learned recipes (margin after cut), for the guide's "Lohnt sich" block.
function Planner.Profitable(skillLine, rec, limit)
  local out = {}
  for _, recipe in ipairs(ns.Adapter.Learned(skillLine, rec)) do
    if recipe.outputItemID then
      local cost, coverage = Planner.CraftCost(recipe)
      local p = priceOf(recipe.outputItemID)
      if p and coverage > 0 then
        local value = p * ((recipe.qtyMin + recipe.qtyMax) / 2) * (1 - (ns.db.settings.ahCut or 0.05))
        out[#out + 1] = { recipe = recipe, margin = math.floor(value - cost), cost = cost, value = value, coverage = coverage }
      end
    end
  end
  table.sort(out, function(a, b) return a.margin > b.margin end)
  if limit then while #out > limit do table.remove(out) end end
  return out
end

ns:RegisterModule("Planner", {})
