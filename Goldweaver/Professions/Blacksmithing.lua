-- Goldweaver: Blacksmithing profile (WoW: Forever). Seed path from Classic community leveling guides; the live planner
-- replaces it with recipe colours from the profession window. Mostly untested on Forever, recipe mats may differ.
local ADDON, ns = ...

local I = ns.Data.Item
local ROUGH_STONE, COARSE_STONE, HEAVY_STONE = I(2835, "Rough Stone"), I(2836, "Coarse Stone"), I(2838, "Heavy Stone")
local COPPER_BAR, IRON_BAR = I(2840, "Copper Bar"), I(3575, "Iron Bar")
local STEEL_BAR, MITHRIL_BAR, THORIUM_BAR = I(3859, "Steel Bar"), I(3860, "Mithril Bar"), I(12359, "Thorium Bar")
local WEAK_FLUX, STRONG_FLUX = I(2880, "Weak Flux"), I(3466, "Strong Flux")

ns.Professions:Register({
  key = "blacksmithing",
  name = "Blacksmithing",
  skillLineID = ns.Professions.SKILL_LINES.blacksmithing,
  category = "crafting",
  crateCategories = {},
  vendorReagents = { WEAK_FLUX, STRONG_FLUX },
  stations = { "Anvil", "Forge" },
  tools = { "Blacksmith Hammer" },
  -- Trainer names are from memory of Classic guides; untested on Forever.
  trainers = {
    Journeyman = { Horde = "Saru Steelfury (Orgrimmar)", Alliance = "Bengus Deepforge (Ironforge)" },
    Expert = { Horde = "Saru Steelfury (Orgrimmar)", Alliance = "Bengus Deepforge (Ironforge)" },
    Artisan = { Horde = "Kilram (Winterspring)", Alliance = "Kilram (Winterspring)" },
  },
  seedPath = {
    { from = 1,   to = 30,  recipe = "Rough Sharpening Stone",  crafts = 30, mats = { { item = ROUGH_STONE, qty = 30 } } },
    { from = 30,  to = 65,  recipe = "Copper Chain Belt",       crafts = 35, mats = { { item = COPPER_BAR, qty = 210 } }, untested = true },
    { from = 65,  to = 100, recipe = "Coarse Sharpening Stone", crafts = 40, mats = { { item = COARSE_STONE, qty = 80 } }, untested = true },
    { from = 100, to = 125, recipe = "Heavy Sharpening Stone",  crafts = 30, mats = { { item = HEAVY_STONE, qty = 60 } }, untested = true },
    { from = 125, to = 155, recipe = "Iron Buckle",             crafts = 35, mats = { { item = IRON_BAR, qty = 35 } }, untested = true },
    { from = 155, to = 200, recipe = "Steel Plate Helm",        crafts = 40, mats = { { item = STEEL_BAR, qty = 160 }, { item = STRONG_FLUX, qty = 40 } }, untested = true },
    { from = 200, to = 250, recipe = "Mithril Spurs",           crafts = 50, mats = { { item = MITHRIL_BAR, qty = 150 } }, untested = true },
    { from = 250, to = 300, recipe = "Thorium Belt",            crafts = 50, mats = { { item = THORIUM_BAR, qty = 200 } }, untested = true },
  },
  notes = {
    "Crafting needs an anvil and a forge nearby; most cities have both.",
    "Keep your Blacksmith Hammer in the bags, it is a required tool.",
    "Sharpening and weight stones sell steadily to melee players.",
  },
})
