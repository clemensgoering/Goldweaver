-- Goldweaver: Engineering profile (WoW: Forever). Seed path from Classic community leveling guides; the live planner
-- replaces it with recipe colours from the profession window. Mostly untested on Forever, recipe mats may differ.
local ADDON, ns = ...

local I = ns.Data.Item
local ROUGH_STONE, COARSE_STONE, HEAVY_STONE = I(2835, "Rough Stone"), I(2836, "Coarse Stone"), I(2838, "Heavy Stone")
local COPPER_BAR, BRONZE_BAR = I(2840, "Copper Bar"), I(2841, "Bronze Bar")
local MITHRIL_BAR, THORIUM_BAR = I(3860, "Mithril Bar"), I(12359, "Thorium Bar")
local WEAK_FLUX = I(2880, "Weak Flux")

ns.Professions:Register({
  key = "engineering",
  name = "Engineering",
  skillLineID = ns.Professions.SKILL_LINES.engineering,
  category = "crafting",
  crateCategories = {},
  vendorReagents = { WEAK_FLUX },
  stations = {},
  tools = { "Arclight Spanner" },
  -- Trainer names are from memory of Classic guides; untested on Forever.
  trainers = {
    Journeyman = { Horde = "Roxxik (Orgrimmar)", Alliance = "Lilliam Sparkspindle (Stormwind), Springspindle (Ironforge)" },
    Expert = { Horde = "Roxxik (Orgrimmar)", Alliance = "Springspindle (Ironforge)" },
    Artisan = { Horde = "Oglethorpe Obnoticus (Booty Bay)", Alliance = "Oglethorpe Obnoticus (Booty Bay)" },
  },
  seedPath = {
    { from = 1,   to = 50,  recipe = "Rough Blasting Powder",   crafts = 50, mats = { { item = ROUGH_STONE, qty = 50 } } },
    { from = 50,  to = 75,  recipe = "Handful of Copper Bolts", crafts = 25, mats = { { item = COPPER_BAR, qty = 25 } }, untested = true },
    { from = 75,  to = 100, recipe = "Copper Tube",             crafts = 25, mats = { { item = COPPER_BAR, qty = 50 }, { item = WEAK_FLUX, qty = 25 } }, untested = true },
    { from = 100, to = 125, recipe = "Coarse Blasting Powder",  crafts = 30, mats = { { item = COARSE_STONE, qty = 30 } }, untested = true },
    { from = 125, to = 150, recipe = "Bronze Tube",             crafts = 25, mats = { { item = BRONZE_BAR, qty = 50 } }, untested = true },
    { from = 150, to = 175, recipe = "Heavy Blasting Powder",   crafts = 30, mats = { { item = HEAVY_STONE, qty = 30 } }, untested = true },
    { from = 175, to = 225, recipe = "Mithril Casing",          crafts = 50, mats = { { item = MITHRIL_BAR, qty = 150 } }, untested = true },
    { from = 225, to = 300, recipe = "Thorium Widget",          crafts = 75, mats = { { item = THORIUM_BAR, qty = 150 } }, untested = true },
  },
  -- what to collect for this profession while the character levels (shown with level gates)
  levelling = { text = "Mine the ore along your levelling route; take Mining if no one in the team has it." },
  notes = {
    "Engineering needs the Arclight Spanner in the bags as a tool.",
    "Blasting powders and tubes are cheap to make and sell to other engineers.",
    "Choose Gnomish or Goblin at 200 only if you want the trinkets; the choice is permanent.",
  },
})
