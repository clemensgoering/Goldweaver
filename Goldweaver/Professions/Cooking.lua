-- Goldweaver: Cooking profile (WoW: Forever). Secondary profession, crafting-like. Seed path is a cheap Classic route from community
-- guides; the live planner replaces it with recipe colours. Quantities are estimates; untested on Forever.
local ADDON, ns = ...

local I = ns.Data.Item
local MILD_SPICES = I(2678, "Mild Spices")
local SOOTHING_SPICES = I(3713, "Soothing Spices")
local HOT_SPICES = I(2692, "Hot Spices")
local STRINGY_WOLF = I(2672, "Stringy Wolf Meat")
local CRAWLER_MEAT = I(2674, "Crawler Meat")
local LION_MEAT = I(3731, "Lion Meat")
local SPIDER_MEAT = I(12205, "White Spider Meat")
local RUNN_TUM = I(18255, "Runn Tum Tuber")

ns.Professions:Register({
  key = "cooking",
  name = "Cooking",
  skillLineID = ns.Professions.SKILL_LINES.cooking,
  category = "secondary",
  crateCategories = {},
  vendorReagents = { MILD_SPICES, SOOTHING_SPICES, HOT_SPICES },
  trainers = {
    Journeyman = { Horde = "Gotura Fourwinds (Orgrimmar), Eunice Burch (Undercity), Aska Mistrunner (Thunder Bluff)",
      Alliance = "Stephen Ryback (Stormwind), Daryl Riknussun (Ironforge), Alegorn (Darnassus)" },
    Expert = { Horde = "Gotura Fourwinds (Orgrimmar), Eunice Burch (Undercity), Aska Mistrunner (Thunder Bluff)",
      Alliance = "Stephen Ryback (Stormwind), Daryl Riknussun (Ironforge), Alegorn (Darnassus)" },
    Artisan = { Horde = "Dirge Quikcleave (Gadgetzan)", Alliance = "Dirge Quikcleave (Gadgetzan)" },
  },
  seedPath = {
    { from = 1,   to = 40,  recipe = "Charred Wolf Meat",       crafts = 40, mats = { { item = STRINGY_WOLF, qty = 40 } } },
    { from = 40,  to = 85,  recipe = "Spiced Wolf Meat",        crafts = 45, mats = { { item = STRINGY_WOLF, qty = 45 }, { item = MILD_SPICES, qty = 45 } } },
    { from = 85,  to = 125, recipe = "Crab Cake",               crafts = 40, mats = { { item = CRAWLER_MEAT, qty = 40 }, { item = MILD_SPICES, qty = 40 } } },
    { from = 125, to = 175, recipe = "Tasty Lion Steak",        crafts = 50, mats = { { item = LION_MEAT, qty = 50 }, { item = SOOTHING_SPICES, qty = 50 } } },
    { from = 175, to = 225, recipe = "Spider Sausage",          crafts = 50, mats = { { item = SPIDER_MEAT, qty = 100 } }, untested = true },
    { from = 225, to = 275, recipe = "Runn Tum Tuber Surprise", crafts = 50, mats = { { item = RUNN_TUM, qty = 50 } }, untested = true },
    -- 275-300: filled by the live planner (Dirge's Kickin' Chimaerok Chops and similar).
  },
  -- ways to make gold with this profession (Gold tab); English keys, translated at display
  earn = {
    { title = "Cook food for the AH", detail = "Well Fed food sells at every level; meat and fish from your own levelling keep the cost near zero.", minSkill = 1, effort = "low" },
    { title = "Resell the Expert Cookbook", detail = "The Expert Cookbook (Cooking 150-225) comes from a vendor and is tradeable; compare AH and vendor price.", minSkill = 1, effort = "low" },
  },
  -- what to collect for this profession while the character levels (shown with level gates)
  levelling = { text = "Keep the meat and fish from your levelling; most low recipes use it." },
  notes = {
    "Cooking needs a fire; use a campfire or an inn hearth fire.",
    "Cook with food drops from your own levelling to keep costs near zero.",
    "Expert and Artisan recipes need Journeyman skill first; Artisan comes from Dirge Quikcleave in Gadgetzan.",
    "Item quantities are estimates and untested on Forever.",
  },
})
