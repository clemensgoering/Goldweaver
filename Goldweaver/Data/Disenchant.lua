-- Goldweaver: item registry helpers and the disenchant table for WoW: Forever.
-- Item IDs are the Classic IDs (Forever keeps them for existing items); /gw probe items verifies them against the client.
-- Source of the brackets: community disenchanting guides for Forever (see docs/03-RECHERCHE-QUELLEN.md). Marked data, not verified in game yet.
local ADDON, ns = ...

ns.Data = ns.Data or {}
local Data = ns.Data

Data.items = Data.items or {}  -- [itemID] = expected English name, used by the probe to catch wrong IDs

function Data.Item(id, name)
  Data.items[id] = name
  return id
end

function Data.ExpectedName(id) return Data.items[id] end

function Data.AllItemIDs()
  local ids = {}
  for id in pairs(Data.items) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end

-- Enchanting materials
local I = Data.Item
local STRANGE_DUST   = I(10940, "Strange Dust")
local SOUL_DUST      = I(11083, "Soul Dust")
local VISION_DUST    = I(11137, "Vision Dust")
local DREAM_DUST     = I(11176, "Dream Dust")
local ILLUSION_DUST  = I(16204, "Illusion Dust")
local L_MAGIC        = I(10938, "Lesser Magic Essence")
local G_MAGIC        = I(10939, "Greater Magic Essence")
local L_ASTRAL       = I(10998, "Lesser Astral Essence")
local G_ASTRAL       = I(11082, "Greater Astral Essence")
local L_MYSTIC       = I(11134, "Lesser Mystic Essence")
local G_MYSTIC       = I(11135, "Greater Mystic Essence")
local L_NETHER       = I(11174, "Lesser Nether Essence")
local G_NETHER       = I(11175, "Greater Nether Essence")
local L_ETERNAL      = I(16202, "Lesser Eternal Essence")
local G_ETERNAL      = I(16203, "Greater Eternal Essence")
local S_GLIMMERING   = I(10978, "Small Glimmering Shard")
local L_GLIMMERING   = I(11084, "Large Glimmering Shard")
local S_GLOWING      = I(11138, "Small Glowing Shard")
local L_GLOWING      = I(11139, "Large Glowing Shard")
local S_RADIANT      = I(11177, "Small Radiant Shard")
local L_RADIANT      = I(11178, "Large Radiant Shard")
local S_BRILLIANT    = I(14343, "Small Brilliant Shard")
local L_BRILLIANT    = I(14344, "Large Brilliant Shard")
local NEXUS_CRYSTAL  = I(20725, "Nexus Crystal")

Data.Disenchant = {
  -- Brackets by the item's "Requires Level". dust/essence = {item, min, max}; shard = item; crystal = item or nil.
  brackets = {
    { lo = 1,  hi = 10, dust = { STRANGE_DUST, 1, 2 },  essence = { L_MAGIC, 1, 2 },   shard = nil },
    { lo = 11, hi = 15, dust = { STRANGE_DUST, 2, 3 },  essence = { G_MAGIC, 1, 2 },   shard = S_GLIMMERING },
    { lo = 16, hi = 20, dust = { STRANGE_DUST, 4, 6 },  essence = { L_ASTRAL, 1, 2 },  shard = S_GLIMMERING },
    { lo = 21, hi = 25, dust = { SOUL_DUST, 1, 2 },     essence = { G_ASTRAL, 1, 2 },  shard = L_GLIMMERING },
    { lo = 26, hi = 30, dust = { SOUL_DUST, 2, 5 },     essence = { L_MYSTIC, 1, 2 },  shard = S_GLOWING },
    { lo = 31, hi = 35, dust = { VISION_DUST, 1, 2 },   essence = { G_MYSTIC, 1, 2 },  shard = L_GLOWING },
    { lo = 36, hi = 40, dust = { VISION_DUST, 2, 5 },   essence = { L_NETHER, 1, 2 },  shard = S_RADIANT },
    { lo = 41, hi = 45, dust = { DREAM_DUST, 1, 2 },    essence = { G_NETHER, 1, 2 },  shard = L_RADIANT },
    { lo = 46, hi = 50, dust = { DREAM_DUST, 2, 5 },    essence = { L_ETERNAL, 1, 2 }, shard = S_BRILLIANT },
    { lo = 51, hi = 55, dust = { ILLUSION_DUST, 1, 2 }, essence = { G_ETERNAL, 1, 2 }, shard = L_BRILLIANT, crystal = NEXUS_CRYSTAL },
    { lo = 56, hi = 60, dust = { ILLUSION_DUST, 2, 5 }, essence = { G_ETERNAL, 1, 3 }, shard = L_BRILLIANT, crystal = NEXUS_CRYSTAL },
  },
  -- Outcome probabilities by quality (2 = uncommon, 3 = rare, 4 = epic) and slot type.
  probabilities = {
    uncommonArmor  = { dust = 0.75, essence = 0.20, shard = 0.05 },
    uncommonWeapon = { dust = 0.20, essence = 0.75, shard = 0.05 },
    rare           = { shard = 1.00 },
    epicLow        = { shard = 1.00 },   -- requires level 50 or below
    epicHigh       = { crystal = 1.00 }, -- requires level 51 and above
  },
  verified = false, -- set true once /gw probe and own disenchant logs confirm the brackets
}

local function bracketFor(reqLevel)
  reqLevel = tonumber(reqLevel) or 1
  if reqLevel < 1 then reqLevel = 1 end
  if reqLevel > 60 then reqLevel = 60 end
  for _, b in ipairs(Data.Disenchant.brackets) do
    if reqLevel >= b.lo and reqLevel <= b.hi then return b end
  end
end

-- Expected outputs for disenchanting one item. quality: 2 uncommon, 3 rare, 4 epic. isWeapon: boolean.
-- Returns a list of { item, qty (expected), prob } or nil if the item cannot be disenchanted.
function Data.Disenchant.Outcomes(reqLevel, quality, isWeapon)
  if not quality or quality < 2 or quality > 4 then return nil end
  local b = bracketFor(reqLevel)
  if not b then return nil end
  local P = Data.Disenchant.probabilities
  local probs
  if quality == 2 then probs = isWeapon and P.uncommonWeapon or P.uncommonArmor
  elseif quality == 3 then probs = P.rare
  else probs = (tonumber(reqLevel) or 1) >= 51 and P.epicHigh or P.epicLow end

  local out = {}
  if probs.dust and b.dust then
    out[#out + 1] = { item = b.dust[1], qty = (b.dust[2] + b.dust[3]) / 2, prob = probs.dust }
  end
  if probs.essence and b.essence then
    out[#out + 1] = { item = b.essence[1], qty = (b.essence[2] + b.essence[3]) / 2, prob = probs.essence }
  end
  if probs.shard and b.shard then
    out[#out + 1] = { item = b.shard, qty = 1, prob = probs.shard }
  end
  if probs.crystal and b.crystal then
    out[#out + 1] = { item = b.crystal, qty = 1, prob = probs.crystal }
  end
  return out
end

-- Expected copper from disenchanting one item, priced with priceFn(itemID) -> copper|nil.
function Data.Disenchant.ExpectedValue(reqLevel, quality, isWeapon, priceFn)
  local outcomes = Data.Disenchant.Outcomes(reqLevel, quality, isWeapon)
  if not outcomes then return nil end
  local value, coverage, total = 0, 0, 0
  for _, o in ipairs(outcomes) do
    total = total + o.prob
    local p = priceFn(o.item)
    if p then
      value = value + o.qty * o.prob * p
      coverage = coverage + o.prob
    end
  end
  return math.floor(value), (total > 0) and (coverage / total) or 0
end

-- Builds a graph conversion for disenchanting a specific item (not stored; the Advisor creates it on demand).
function Data.Disenchant.Conversion(itemID, reqLevel, quality, isWeapon)
  local outcomes = Data.Disenchant.Outcomes(reqLevel, quality, isWeapon)
  if not outcomes then return nil end
  return {
    id = "de:" .. itemID, kind = "disenchant", profession = "enchanting", skill = 1, source = "data",
    inputs = { { item = itemID, qty = 1 } }, outputs = outcomes, name = "Disenchant",
  }
end
