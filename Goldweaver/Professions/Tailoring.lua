-- Goldweaver: Tailoring profile (WoW: Forever). Seed path from community beta guides (docs/03-RECHERCHE-QUELLEN.md);
-- the live planner replaces it with recipe colours from the profession window. 225-300 is untested on Forever.
local ADDON, ns = ...

local I = ns.Data.Item
local LINEN, WOOL, SILK, MAGEWEAVE = 2589, 2592, 4306, 4338
local BOLT_LINEN, BOLT_WOOL, BOLT_SILK, BOLT_MAGEWEAVE, BOLT_RUNECLOTH = 2996, 2997, 4305, 4339, 14048
local COARSE, FINE, SILKEN, HEAVY_SILKEN, RUNE_THREAD = 2320, 2321, 4291, 8343, 14341
local RED_DYE = 2604
local ELIXIR_OF_WISDOM = I(3383, "Elixir of Wisdom")
local RUGGED_LEATHER = 8170

ns.Professions:Register({
  key = "tailoring",
  name = "Tailoring",
  skillLineID = ns.Professions.SKILL_LINES.tailoring,
  category = "crafting",
  crateCategories = { "textiles" },
  vendorReagents = { COARSE, FINE, SILKEN, HEAVY_SILKEN, RUNE_THREAD, RED_DYE, 2324, 6260, 4340 },
  stations = {},
  -- Where the next rank is taught (community beta guides; the Trade Contacts recorder overrides with visited trainers).
  trainers = {
    Journeyman = { Horde = "Magar (Orgrimmar), Rhiannon Davis (Undercity), Tepa (Thunder Bluff)",
      Alliance = "Sellandus (Stormwind), Jormund Stonebrow (Ironforge), Me'lynn (Darnassus)" },
    Expert = { Horde = "Josef Gregorian (Undercity), 50 silver", Alliance = "Georgio Bolero (Stormwind), 50 silver" },
    Artisan = { Horde = "Daryl Stack (Tarren Mill)", Alliance = "Timothy Worthington (Theramore)" },
  },
  -- Materials are totals for the step (bolts counted as cloth where the guide does so).
  seedPath = {
    { from = 1,   to = 30,  recipe = "Bolt of Linen Cloth",       crafts = 30, mats = { { item = LINEN, qty = 60 } } },
    { from = 30,  to = 55,  recipe = "Linen Belt",                crafts = 28, mats = { { item = BOLT_LINEN, qty = 28 }, { item = COARSE, qty = 28 } } },
    { from = 55,  to = 80,  recipe = "Bolt of Woolen Cloth",      crafts = 45, mats = { { item = WOOL, qty = 135 } } },
    { from = 80,  to = 95,  recipe = "Woolen Cape",               crafts = 22, mats = { { item = BOLT_WOOL, qty = 22 }, { item = FINE, qty = 22 } } },
    { from = 95,  to = 100, recipe = "Double-stitched Woolen Shoulders", crafts = 5, mats = { { item = BOLT_WOOL, qty = 15 }, { item = FINE, qty = 10 } } },
    { from = 100, to = 120, recipe = "Bolt of Silk Cloth",        crafts = 54, mats = { { item = SILK, qty = 216 } } },
    { from = 120, to = 140, recipe = "Gloves of Meditation",      crafts = 29, mats = { { item = BOLT_WOOL, qty = 116 }, { item = FINE, qty = 87 }, { item = ELIXIR_OF_WISDOM, qty = 29 } } },
    { from = 140, to = 150, recipe = "Bolt of Mageweave",         crafts = 23, mats = { { item = MAGEWEAVE, qty = 115 } } },
    { from = 150, to = 170, recipe = "Crimson Silk Vest",         crafts = 20, mats = { { item = BOLT_SILK, qty = 80 }, { item = RED_DYE, qty = 40 }, { item = FINE, qty = 40 } } },
    { from = 170, to = 190, recipe = "Crimson Silk Pantaloons",   crafts = 26, mats = { { item = BOLT_SILK, qty = 104 }, { item = RED_DYE, qty = 52 }, { item = SILKEN, qty = 52 } } },
    { from = 190, to = 215, recipe = "Black Mageweave Gloves",    crafts = 38, mats = { { item = BOLT_MAGEWEAVE, qty = 76 }, { item = HEAVY_SILKEN, qty = 76 } } },
    { from = 215, to = 225, recipe = "Mageweave Bag",             crafts = 26, mats = { { item = BOLT_MAGEWEAVE, qty = 104 }, { item = SILKEN, qty = 52 } } },
    { from = 225, to = 240, recipe = "Runecloth Belt",            crafts = 24, mats = { { item = BOLT_RUNECLOTH, qty = 72 }, { item = RUNE_THREAD, qty = 24 } }, untested = true },
    { from = 240, to = 265, recipe = "Runecloth Gloves",          crafts = 43, mats = { { item = BOLT_RUNECLOTH, qty = 172 }, { item = RUGGED_LEATHER, qty = 172 }, { item = RUNE_THREAD, qty = 43 } }, untested = true },
    -- 265-300: no confirmed trainer/vendor recipe on Forever yet; filled by the live planner.
  },
  -- ways to make gold with this profession (Gold tab); English keys, translated at display
  earn = {
    { title = "Tailor bags", detail = "Woolen, silk and mageweave bags sell to every class; the Professions tab shows the margin.", minSkill = 75, effort = "low" },
  },
  -- what to collect for this profession while the character levels (shown with level gates)
  levelling = { text = "Kill humanoids while levelling: they drop the cloth Tailoring needs.", drops = "cloth" },
  notes = {
    "Forever: Apprentice has no level requirement; many Artisan recipes turn grey 25-45 points earlier than Classic.",
    "Bolt of Runecloth gives no skill points on Forever; craft bolts in advance.",
    "Bags sell to every class; crafted raid sets at 300 need Malleable Essence of Nature from raid disenchants.",
    "Tailoring Certification: 1,000 Merchant's Favor at 300.",
  },
})
