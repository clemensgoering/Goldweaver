-- Goldweaver: First Aid profile (WoW: Forever). Secondary profession, crafting-like. Bandage route from Classic community guides;
-- the live planner replaces it with recipe colours. Quantities are estimates; untested on Forever.
local ADDON, ns = ...

local I = ns.Data.Item
local LINEN = I(2589, "Linen Cloth")
local WOOL = I(2592, "Wool Cloth")
local SILK = I(4306, "Silk Cloth")
local MAGEWEAVE = I(4338, "Mageweave Cloth")
local RUNECLOTH = I(14047, "Runecloth")

ns.Professions:Register({
  key = "firstaid",
  name = "First Aid",
  skillLineID = ns.Professions.SKILL_LINES.firstaid,
  category = "secondary",
  crateCategories = {},
  vendorReagents = {},
  trainers = {
    Journeyman = { Horde = "Arnok (Orgrimmar), Nurse Neela (Undercity), Pand Stonebinder (Thunder Bluff)",
      Alliance = "Michelle Belle (Stormwind), Thamner Pol (Ironforge), Dannelor (Darnassus)" },
    Expert = { Horde = "Book: Expert First Aid - Under Wraps", Alliance = "Book: Expert First Aid - Under Wraps" },
    Artisan = { Horde = "Triage quest (Hammerfall)", Alliance = "Triage quest (Theramore)" },
  },
  seedPath = {
    { from = 1,   to = 40,  recipe = "Linen Bandage",           crafts = 40, mats = { { item = LINEN, qty = 40 } } },
    { from = 40,  to = 80,  recipe = "Heavy Linen Bandage",     crafts = 40, mats = { { item = LINEN, qty = 80 } } },
    { from = 80,  to = 115, recipe = "Wool Bandage",            crafts = 35, mats = { { item = WOOL, qty = 35 } } },
    { from = 115, to = 150, recipe = "Heavy Wool Bandage",      crafts = 35, mats = { { item = WOOL, qty = 70 } } },
    { from = 150, to = 180, recipe = "Silk Bandage",            crafts = 30, mats = { { item = SILK, qty = 30 } } },
    { from = 180, to = 210, recipe = "Heavy Silk Bandage",      crafts = 30, mats = { { item = SILK, qty = 60 } } },
    { from = 210, to = 240, recipe = "Mageweave Bandage",       crafts = 30, mats = { { item = MAGEWEAVE, qty = 30 } } },
    { from = 240, to = 260, recipe = "Heavy Mageweave Bandage", crafts = 20, mats = { { item = MAGEWEAVE, qty = 40 } } },
    { from = 260, to = 290, recipe = "Runecloth Bandage",       crafts = 30, mats = { { item = RUNECLOTH, qty = 30 } }, untested = true },
    { from = 290, to = 300, recipe = "Heavy Runecloth Bandage", crafts = 10, mats = { { item = RUNECLOTH, qty = 20 } }, untested = true },
  },
  notes = {
    "Bandages sell and heal outside combat; keep a stack for yourself and your twink.",
    "Expert needs the book Expert First Aid - Under Wraps; Artisan needs the Triage quest.",
    "Cloth quantities are estimates; skill-ups may need fewer crafts. Untested on Forever.",
  },
})
