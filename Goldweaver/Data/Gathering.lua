-- Goldweaver: gathering facts (Classic values; Forever keeps vein/herb skills per community guides, unverified).
-- Own observations (Modules/Field.lua) confirm or extend these per zone.
--
-- Public API (ns.Data.Gathering)
--   nodes[itemID] = { kind = "herb"|"ore", skill = required skill }
--   ColorFor(skill, required) -> "orange"|"yellow"|"green"|"grey"|"red" (red = cannot gather yet)
--   ChanceFor(color) -> expected skill-up chance
--   SkinningMaxLevel(skill) -> highest mob level this skill can skin
--   SkinningRequired(mobLevel) -> skill needed for a mob level
--   ClothFor(mobLevel) / LeatherFor(mobLevel) -> itemID of the typical drop
local ADDON, ns = ...

local Data = ns.Data
local I = Data.Item
local G = {}
Data.Gathering = G

G.HERBALISM, G.MINING, G.SKINNING, G.FISHING = 182, 186, 393, 356

G.nodes = {
  -- herbs
  [I(2447, "Peacebloom")] = { kind = "herb", skill = 1 },
  [I(765, "Silverleaf")] = { kind = "herb", skill = 1 },
  [I(2449, "Earthroot")] = { kind = "herb", skill = 15 },
  [I(785, "Mageroyal")] = { kind = "herb", skill = 50 },
  [I(2450, "Briarthorn")] = { kind = "herb", skill = 70 },
  [I(3820, "Stranglekelp")] = { kind = "herb", skill = 85 },
  [I(2453, "Bruiseweed")] = { kind = "herb", skill = 100 },
  [I(3355, "Wild Steelbloom")] = { kind = "herb", skill = 115 },
  [I(3369, "Grave Moss")] = { kind = "herb", skill = 120 },
  [I(3356, "Kingsblood")] = { kind = "herb", skill = 125 },
  [I(3357, "Liferoot")] = { kind = "herb", skill = 150 },
  [I(3818, "Fadeleaf")] = { kind = "herb", skill = 160 },
  [I(3821, "Goldthorn")] = { kind = "herb", skill = 170 },
  [I(3358, "Khadgar's Whisker")] = { kind = "herb", skill = 185 },
  [I(3819, "Wintersbite")] = { kind = "herb", skill = 195 },
  [I(4625, "Firebloom")] = { kind = "herb", skill = 205 },
  [8831] = { kind = "herb", skill = 210 }, -- Purple Lotus (registered in Professions/Enchanting.lua)
  [I(8836, "Arthas' Tears")] = { kind = "herb", skill = 220 },
  [I(8838, "Sungrass")] = { kind = "herb", skill = 230 },
  [I(8839, "Blindweed")] = { kind = "herb", skill = 235 },
  [I(8845, "Ghost Mushroom")] = { kind = "herb", skill = 245 },
  [I(8846, "Gromsblood")] = { kind = "herb", skill = 250 },
  [I(13464, "Golden Sansam")] = { kind = "herb", skill = 260 },
  [I(13463, "Dreamfoil")] = { kind = "herb", skill = 270 },
  [I(13465, "Mountain Silversage")] = { kind = "herb", skill = 280 },
  [I(13466, "Plaguebloom")] = { kind = "herb", skill = 285 },
  [I(13467, "Icecap")] = { kind = "herb", skill = 290 },
  [I(13468, "Black Lotus")] = { kind = "herb", skill = 300 },
  -- ores (IDs registered in Data/Conversions.lua)
  [2770] = { kind = "ore", skill = 1 },     -- Copper Ore
  [2771] = { kind = "ore", skill = 65 },    -- Tin Ore
  [2775] = { kind = "ore", skill = 75 },    -- Silver Ore
  [2772] = { kind = "ore", skill = 125 },   -- Iron Ore
  [2776] = { kind = "ore", skill = 155 },   -- Gold Ore
  [3858] = { kind = "ore", skill = 175 },   -- Mithril Ore
  [7911] = { kind = "ore", skill = 230 },   -- Truesilver Ore
  [I(11370, "Dark Iron Ore")] = { kind = "ore", skill = 230 },
  [10620] = { kind = "ore", skill = 245 },  -- Thorium Ore
}

G.KIND_SKILL = { herb = G.HERBALISM, ore = G.MINING }

-- Classic gathering colours: orange until +25, yellow until +50, green until +100, then grey.
function G.ColorFor(skill, required)
  skill, required = tonumber(skill) or 0, tonumber(required) or 1
  if skill < required then return "red" end
  if skill < required + 25 then return "orange" end
  if skill < required + 50 then return "yellow" end
  if skill < required + 100 then return "green" end
  return "grey"
end

G.CHANCE = { red = 0, orange = 1, yellow = 0.75, green = 0.25, grey = 0 }
function G.ChanceFor(color) return G.CHANCE[color] or 0 end

G.COLORS = {
  red = { 1, 0.2, 0.2 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 }, grey = { 0.5, 0.5, 0.5 },
}

-- Skinning (Classic rule, community-confirmed for Forever's 1-60 range):
-- level 1-10 needs 1, level 11-20 needs (level*10)-100, level 21+ needs level*5.
function G.SkinningRequired(mobLevel)
  mobLevel = tonumber(mobLevel) or 1
  if mobLevel <= 10 then return 1 end
  if mobLevel <= 20 then return mobLevel * 10 - 100 end
  return mobLevel * 5
end

function G.SkinningMaxLevel(skill)
  skill = tonumber(skill) or 0
  if skill < 1 then return 0 end
  if skill <= 100 then return math.floor(skill / 10) + 10 end
  return math.floor(skill / 5)
end

-- Typical cloth from humanoids by mob level (guides disagree by a few levels at the edges).
local CLOTH = { { 1, 15, 2589 }, { 16, 27, 2592 }, { 28, 38, 4306 }, { 39, 49, 4338 }, { 50, 63, 14047 } }
function G.ClothFor(mobLevel)
  for _, r in ipairs(CLOTH) do if mobLevel >= r[1] and mobLevel <= r[2] then return r[3] end end
  return nil
end

-- Typical leather from skinning beasts by mob level.
local LEATHER = { { 1, 19, 2318 }, { 20, 29, 2319 }, { 30, 39, 4234 }, { 40, 49, 4304 }, { 50, 63, 8170 } }
function G.LeatherFor(mobLevel)
  for _, r in ipairs(LEATHER) do if mobLevel >= r[1] and mobLevel <= r[2] then return r[3] end end
  return nil
end
