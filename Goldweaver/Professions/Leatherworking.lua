-- Goldweaver: Leatherworking profile (WoW: Forever). Seed path from Classic community leveling guides; the live planner
-- replaces it with recipe colours from the profession window. Mostly untested on Forever, recipe mats may differ.
local ADDON, ns = ...

local I = ns.Data.Item
local LIGHT, MEDIUM, HEAVY = I(2318, "Light Leather"), I(2319, "Medium Leather"), I(4234, "Heavy Leather")
local THICK, RUGGED = I(4304, "Thick Leather"), I(8170, "Rugged Leather")
local COARSE, FINE, SILKEN = I(2320, "Coarse Thread"), I(2321, "Fine Thread"), I(4291, "Silken Thread")
local HEAVY_SILKEN, RUNE_THREAD = I(8343, "Heavy Silken Thread"), I(14341, "Rune Thread")
local SALT = I(4289, "Salt")
local GRAY_DYE, BLUE_DYE = I(4340, "Gray Dye"), I(6260, "Blue Dye")

ns.Professions:Register({
  key = "leatherworking",
  name = "Leatherworking",
  skillLineID = ns.Professions.SKILL_LINES.leatherworking,
  category = "crafting",
  crateCategories = {},
  vendorReagents = { COARSE, FINE, SILKEN, HEAVY_SILKEN, RUNE_THREAD, SALT, GRAY_DYE, BLUE_DYE },
  stations = {},
  tools = {},
  -- Trainer names are from memory of Classic guides; untested on Forever.
  trainers = {
    Journeyman = { Horde = "Karolek (Orgrimmar), Una (Undercity)", Alliance = "Brom Killian (Stormwind), Telonis (Darnassus)" },
    Expert = { Horde = "Karolek (Orgrimmar)", Alliance = "Brom Killian (Stormwind)" },
    Artisan = { Horde = "Karolek (Orgrimmar)", Alliance = "Drakk Stonehand (Burning Steppes)" },
  },
  seedPath = {
    { from = 1,   to = 40,  recipe = "Light Armor Kit",        crafts = 40, mats = { { item = LIGHT, qty = 40 } }, untested = true },
    { from = 40,  to = 85,  recipe = "Embossed Leather Boots", crafts = 45, mats = { { item = LIGHT, qty = 360 }, { item = COARSE, qty = 45 } }, untested = true },
    { from = 85,  to = 120, recipe = "Fine Leather Belt",      crafts = 35, mats = { { item = LIGHT, qty = 140 }, { item = FINE, qty = 35 } }, untested = true },
    { from = 120, to = 155, recipe = "Dark Leather Gloves",    crafts = 35, mats = { { item = MEDIUM, qty = 140 }, { item = FINE, qty = 35 } }, untested = true },
    { from = 155, to = 200, recipe = "Heavy Armor Kit",        crafts = 45, mats = { { item = HEAVY, qty = 225 } }, untested = true },
    { from = 200, to = 250, recipe = "Thick Armor Kit",        crafts = 50, mats = { { item = THICK, qty = 250 } }, untested = true },
    { from = 250, to = 300, recipe = "Rugged Armor Kit",       crafts = 50, mats = { { item = RUGGED, qty = 250 }, { item = RUNE_THREAD, qty = 50 } }, untested = true },
  },
  -- ways to make gold with this profession (Gold tab); English keys, translated at display
  earn = {
    { title = "Armor Kits", detail = "Armor Kits are cheap with your own leather and sell to levelling players.", minSkill = 1, effort = "low" },
  },
  -- what to collect for this profession while the character levels (shown with level gates)
  levelling = { text = "Skin the beasts you kill while levelling; take Skinning if no one in the team has it.", drops = "leather" },
  notes = {
    "Leather comes from skinning; the main can skin and mail it to the twink.",
    "Armor kits sell to every class and are a steady seller at the auction house.",
    "Thread and dye are cheap vendor goods; buy them in stacks.",
  },
})
