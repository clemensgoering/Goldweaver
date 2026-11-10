-- Goldweaver: Alchemy profile (WoW: Forever). Seed path from Classic community leveling guides; the live planner
-- replaces it with recipe colours from the profession window. Mostly untested on Forever, recipe mats may differ.
local ADDON, ns = ...

local I = ns.Data.Item
local EMPTY_VIAL, LEADED_VIAL, CRYSTAL_VIAL = I(3371, "Empty Vial"), I(3372, "Leaded Vial"), I(8925, "Crystal Vial")
local PEACEBLOOM, SILVERLEAF, MAGEROYAL = I(2447, "Peacebloom"), I(765, "Silverleaf"), I(785, "Mageroyal")
local BRIARTHORN, BRUISEWEED, KINGSBLOOD = I(2450, "Briarthorn"), I(2453, "Bruiseweed"), I(3356, "Kingsblood")
local LIFEROOT, STRANGLEKELP, GOLDTHORN = I(3357, "Liferoot"), I(3820, "Stranglekelp"), I(3821, "Goldthorn")
local SUNGRASS, KHADGARS = I(8838, "Sungrass"), I(3358, "Khadgar's Whisker")

ns.Professions:Register({
  key = "alchemy",
  name = "Alchemy",
  skillLineID = ns.Professions.SKILL_LINES.alchemy,
  category = "crafting",
  crateCategories = {},
  vendorReagents = { EMPTY_VIAL, LEADED_VIAL, CRYSTAL_VIAL },
  stations = {},
  tools = {},
  -- Trainer names are from memory of Classic guides; untested on Forever.
  trainers = {
    Journeyman = { Horde = "Yelmak (Orgrimmar), Carolai Anise (Undercity)", Alliance = "Lilyssia Nightbreeze (Stormwind)" },
    Expert = { Horde = "Yelmak (Orgrimmar)", Alliance = "Lilyssia Nightbreeze (Stormwind)" },
    Artisan = { Horde = "Serge Hinott (Hinterlands)", Alliance = "Kylanna Windwhisper (Feralas)" },
  },
  seedPath = {
    { from = 1,   to = 55,  recipe = "Minor Healing Potion",    crafts = 60, mats = { { item = PEACEBLOOM, qty = 60 }, { item = SILVERLEAF, qty = 60 }, { item = EMPTY_VIAL, qty = 60 } } },
    { from = 55,  to = 80,  recipe = "Lesser Healing Potion",   crafts = 30, mats = { { item = MAGEROYAL, qty = 30 }, { item = BRIARTHORN, qty = 30 }, { item = LEADED_VIAL, qty = 30 } }, untested = true },
    { from = 80,  to = 110, recipe = "Healing Potion",          crafts = 35, mats = { { item = BRIARTHORN, qty = 35 }, { item = BRUISEWEED, qty = 35 }, { item = LEADED_VIAL, qty = 35 } }, untested = true },
    { from = 110, to = 140, recipe = "Elixir of Agility",       crafts = 35, mats = { { item = STRANGLEKELP, qty = 35 }, { item = GOLDTHORN, qty = 35 }, { item = LEADED_VIAL, qty = 35 } }, untested = true },
    { from = 140, to = 185, recipe = "Greater Healing Potion",  crafts = 50, mats = { { item = LIFEROOT, qty = 50 }, { item = KINGSBLOOD, qty = 50 }, { item = LEADED_VIAL, qty = 50 } }, untested = true },
    { from = 185, to = 230, recipe = "Superior Healing Potion", crafts = 50, mats = { { item = SUNGRASS, qty = 100 }, { item = KHADGARS, qty = 50 }, { item = CRYSTAL_VIAL, qty = 50 } }, untested = true },
    -- 230-300: depends on the server economy; filled by the live planner.
  },
  notes = {
    "Herbs are the main cost; gather them with the main character or buy them in bulk.",
    "Vials come from alchemy or general goods vendors; buy them in stacks.",
    "Healing and mana potions sell to every class, elixirs sell best before raids.",
  },
})
