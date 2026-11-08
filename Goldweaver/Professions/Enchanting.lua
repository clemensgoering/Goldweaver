-- Goldweaver: Enchanting profile (WoW: Forever). Disenchant works from skill 1 and lives in the Professions window.
-- Seed path from community beta guides; 225-300 untested. Enchanting uses the Craft window API on older clients (F2).
local ADDON, ns = ...

local I = ns.Data.Item
local STRANGE, SOUL, VISION, DREAM, ILLUSION = 10940, 11083, 11137, 11176, 16204
local L_MAGIC, G_ASTRAL, G_MYSTIC, G_ETERNAL = 10938, 11082, 11135, 16203
local S_BRILLIANT, L_BRILLIANT = 14343, 14344
local COPPER_ROD = 6217
local SILVER_ROD = I(6338, "Silver Rod")
local GOLDEN_ROD = I(11128, "Golden Rod")
local TRUESILVER_ROD = I(11144, "Truesilver Rod")
local ARCANITE_ROD = I(16206, "Arcanite Rod")
local SHADOWGEM = I(1210, "Shadowgem")
local IRIDESCENT_PEARL = I(5500, "Iridescent Pearl")
local BLACK_PEARL = I(7971, "Black Pearl")
local GOLDEN_PEARL = I(13926, "Golden Pearl")
local MAPLE_SEED = I(17034, "Maple Seed")
local STRANGLETHORN_SEED = I(17035, "Stranglethorn Seed")
local PURPLE_LOTUS = I(8831, "Purple Lotus")
local LEADED_VIAL, CRYSTAL_VIAL = 3372, 8925

ns.Professions:Register({
  key = "enchanting",
  name = "Enchanting",
  skillLineID = ns.Professions.SKILL_LINES.enchanting,
  category = "crafting",
  crateCategories = { "curiosities" },
  vendorReagents = { COPPER_ROD, LEADED_VIAL, CRYSTAL_VIAL },
  destroy = { spellName = "Disenchant", spellID = 13262, minSkill = 1 },
  trainers = {
    Journeyman = "Verzauberkunst-Lehrer in jeder Hauptstadt (ab Skill 50, Level 10)",
    Expert = "Horde: Hgarth (Steinkrallengebirge, Sonnenfels); Allianz: Kitta Firewind (Wald von Elwynn, Turm von Azora), 50 Silber",
    Artisan = "Annora in Uldaman (Hintereingang), einzige Lehrerin für beide Fraktionen; erscheint erst, wenn ihr Bereich geleert ist",
  },
  tools = { "Runed Copper Rod", "Runed Silver Rod", "Runed Golden Rod", "Runed Truesilver Rod", "Runed Arcanite Rod" },
  seedPath = {
    -- Mote of Magic is a new Forever item without a known ID; the first 20 points are priced as zero until the probe resolves it.
    { from = 1,   to = 20,  recipe = "Runed Copper Rod + Enchant Bracer - Inferior Stamina", crafts = 19, mats = { { item = COPPER_ROD, qty = 1 } } },
    { from = 20,  to = 70,  recipe = "Enchant Chest - Inferior Stamina", crafts = 50, mats = { { item = STRANGE, qty = 50 } } },
    { from = 70,  to = 109, recipe = "Enchant Bracer - Minor Stamina / Cloak - Minor Protection", crafts = 39, mats = { { item = STRANGE, qty = 78 } } },
    { from = 109, to = 110, recipe = "Runed Silver Rod", crafts = 1, mats = { { item = SILVER_ROD, qty = 1 }, { item = STRANGE, qty = 3 }, { item = L_MAGIC, qty = 4 }, { item = SHADOWGEM, qty = 1 } } },
    { from = 110, to = 130, recipe = "Enchant Cloak - Minor Protection", crafts = 32, mats = { { item = STRANGE, qty = 64 } } },
    { from = 130, to = 150, recipe = "Enchant Boots - Minor Stamina", crafts = 20, mats = { { item = STRANGE, qty = 80 } } },
    { from = 150, to = 151, recipe = "Runed Golden Rod", crafts = 1, mats = { { item = GOLDEN_ROD, qty = 1 }, { item = IRIDESCENT_PEARL, qty = 1 }, { item = G_ASTRAL, qty = 1 }, { item = SOUL, qty = 1 } } },
    { from = 151, to = 165, recipe = "Minor Mana Oil", crafts = 16, mats = { { item = SOUL, qty = 16 }, { item = MAPLE_SEED, qty = 32 }, { item = LEADED_VIAL, qty = 16 } } },
    { from = 165, to = 200, recipe = "Enchant Boots - Lesser Agility", crafts = 47, mats = { { item = SOUL, qty = 47 } } },
    { from = 200, to = 201, recipe = "Runed Truesilver Rod", crafts = 1, mats = { { item = TRUESILVER_ROD, qty = 1 }, { item = BLACK_PEARL, qty = 1 }, { item = G_MYSTIC, qty = 1 }, { item = VISION, qty = 1 } } },
    { from = 201, to = 220, recipe = "Lesser Wizard Oil", crafts = 25, mats = { { item = VISION, qty = 25 }, { item = STRANGLETHORN_SEED, qty = 50 }, { item = LEADED_VIAL, qty = 25 } } },
    { from = 220, to = 225, recipe = "Enchant Cloak - Greater Defense", crafts = 5, mats = { { item = VISION, qty = 5 } } },
    { from = 225, to = 250, recipe = "Gloves Agility / Boots Stamina / Chest Superior Stamina", crafts = 30, mats = { { item = VISION, qty = 75 } }, untested = true },
    { from = 250, to = 265, recipe = "Lesser Mana Oil", crafts = 20, mats = { { item = DREAM, qty = 20 }, { item = PURPLE_LOTUS, qty = 20 }, { item = CRYSTAL_VIAL, qty = 20 } }, untested = true },
    { from = 265, to = 294, recipe = "Enchant Shield - Greater Stamina", crafts = 32, mats = { { item = DREAM, qty = 192 } }, untested = true },
    { from = 294, to = 295, recipe = "Runed Arcanite Rod", crafts = 1, untested = true,
      mats = { { item = ARCANITE_ROD, qty = 1 }, { item = GOLDEN_PEARL, qty = 1 }, { item = ILLUSION, qty = 10 },
               { item = G_ETERNAL, qty = 4 }, { item = S_BRILLIANT, qty = 4 }, { item = L_BRILLIANT, qty = 2 } } },
    { from = 295, to = 300, recipe = "Enchant Cloak - Superior Defense", crafts = 5, mats = { { item = ILLUSION, qty = 40 } }, untested = true },
  },
  notes = {
    "Disenchant is in the Professions window, not the spellbook; works on every item from skill 1.",
    "Artisan Enchanting is taught only by Annora in Uldaman (single source, unconfirmed).",
    "Crafted wands had volatile vendor prices in the beta; price them on the AH.",
    "Camp buff Arcane Salvager improves disenchant yield (effect size unknown).",
  },
})
