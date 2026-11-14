-- Goldweaver: profession profile registry. Engine code never names a profession; it asks this registry.
-- profile = {
--   key = "tailoring", name = "Tailoring", skillLineID = 197, category = "crafting" | "gathering" | "secondary",
--   ranks = Registry.DEFAULT_RANKS (or own), crateCategories = { "textiles" }, vendorReagents = { itemID, ... },
--   destroy = { spellName = "Disenchant" } (optional), tools = { "Runed Copper Rod" } (optional),
--   seedPath = { { from = 1, to = 30, recipe = "Bolt of Linen Cloth", crafts = 30, mats = { { item = 2589, qty = 60 } } }, ... },
--   zones = { { from, to, zone = "English zone list", note = "what grows there" } } (gathering professions, optional),
--   trainers = { Journeyman = { Horde = "...", Alliance = "..." } | { both = "..." }, Expert = ..., Artisan = ... },
--   notes = { "..." },
--   earn = { { title, detail, minSkill?, minLevel?, effort = "low"|"medium"|"high", icon? } } (optional: ways this
--          profession makes gold; English keys, shown in the Gold tab through ns.L)
--   levelling = { text, drops = "cloth" | "leather" } (optional: what to collect while levelling to the next gate)
-- }
-- Ranks: crafting and secondary professions use DEFAULT_RANKS, gathering professions GATHERING_RANKS. reqLevel and
-- cost are guide values; what a trainer actually showed wins (Learn.RankRequirement).
local ADDON, ns = ...

local Registry = { profiles = {}, bySkillLine = {} }
ns.Professions = Registry

-- Forever: four ranks (Icy Veins, Boostroom, 11/2026; to be confirmed by trainers in game). cost in copper.
Registry.DEFAULT_RANKS = {
  -- name = key for profile.trainers and the English label (translated with ns.L where shown)
  { name = "Apprentice", max = 75,  reqSkill = 0,   reqLevel = 0,  cost = 10 },
  { name = "Journeyman", max = 150, reqSkill = 50,  reqLevel = 10, cost = 500 },
  { name = "Expert",     max = 225, reqSkill = 125, reqLevel = 20, cost = 5000 },
  { name = "Artisan",    max = 300, reqSkill = 200, reqLevel = 35, cost = 50000 },
}
-- gathering professions unlock earlier: Expert at 10, Artisan at 25
Registry.GATHERING_RANKS = {
  { name = "Apprentice", max = 75,  reqSkill = 0,   reqLevel = 0,  cost = 10 },
  { name = "Journeyman", max = 150, reqSkill = 50,  reqLevel = 0,  cost = 500 },
  { name = "Expert",     max = 225, reqSkill = 125, reqLevel = 10, cost = 5000 },
  { name = "Artisan",    max = 300, reqSkill = 200, reqLevel = 25, cost = 50000 },
}

Registry.SKILL_LINES = {
  alchemy = 171, blacksmithing = 164, enchanting = 333, engineering = 202, leatherworking = 165, tailoring = 197,
  cooking = 185, firstaid = 129, fishing = 356, herbalism = 182, mining = 186, skinning = 393,
}

function Registry:Register(profile)
  assert(type(profile) == "table" and profile.key, "profile needs a key")
  assert(profile.skillLineID, "profile " .. profile.key .. " needs a skillLineID")
  assert(profile.category, "profile " .. profile.key .. " needs a category")
  profile.name = profile.name or profile.key
  profile.ranks = profile.ranks or (profile.category == "gathering" and self.GATHERING_RANKS or self.DEFAULT_RANKS)
  profile.crateCategories = profile.crateCategories or {}
  profile.vendorReagents = profile.vendorReagents or {}
  profile.seedPath = profile.seedPath or {}
  self.profiles[profile.key] = profile
  self.bySkillLine[profile.skillLineID] = profile
  return profile
end

function Registry:Get(key) return self.profiles[key] end
function Registry:BySkillLine(id) return self.bySkillLine[id] end

function Registry:All()
  local list = {}
  for _, p in pairs(self.profiles) do list[#list + 1] = p end
  table.sort(list, function(a, b) return a.key < b.key end)
  return list
end

-- Zone band for a skill value (gathering profiles): { from, to, zone, note } or nil.
function Registry.ZoneFor(profile, skill)
  for _, z in ipairs(profile.zones or {}) do
    if skill >= (z.from or 0) and skill < (z.to or 0) then return z end
  end
  return nil
end

-- Rank entry for a skill value (the rank the player is in), and the next rank to train for.
function Registry.RankFor(profile, skill)
  local ranks = profile.ranks or Registry.DEFAULT_RANKS
  for i, r in ipairs(ranks) do
    if skill <= r.max then return r, ranks[i + 1] end
  end
  return ranks[#ranks], nil
end

-- Total seed-path material cost from `fromSkill` to `toSkill`, priced with priceFn. Used by the profession comparison
-- before any live recipe data exists. Returns copper, coverage (priced share of the path steps).
function Registry.SeedCost(profile, fromSkill, toSkill, priceFn)
  local cost, steps, priced = 0, 0, 0
  for _, step in ipairs(profile.seedPath or {}) do
    if step.to > fromSkill and step.from < toSkill then
      steps = steps + 1
      local stepCost, stepPriced = 0, true
      for _, m in ipairs(step.mats or {}) do
        local p = priceFn(m.item)
        if p then stepCost = stepCost + p * m.qty else stepPriced = false end
      end
      -- scale partial steps linearly
      local span = step.to - step.from
      local covered = math.min(step.to, toSkill) - math.max(step.from, fromSkill)
      local share = span > 0 and (covered / span) or 1
      cost = cost + stepCost * share
      if stepPriced then priced = priced + 1 end
    end
  end
  return math.floor(cost), steps > 0 and priced / steps or 0
end
