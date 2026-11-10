-- Goldweaver: Mining profile (WoW: Forever). Gathering profession: no seed path; zones describe where to level each skill band.
-- Source: Classic community leveling guides; untested on Forever. Ore node data lives in Data/Gathering.lua.
local ADDON, ns = ...

ns.Professions:Register({
  key = "mining",
  name = "Mining",
  skillLineID = ns.Professions.SKILL_LINES.mining,
  category = "gathering",
  crateCategories = {},
  vendorReagents = {},
  tools = { "Mining Pick" },
  trainers = {
    Journeyman = { Horde = "Sumi (Orgrimmar), Makaru (Thunder Bluff)",
      Alliance = "Gelman Stonehand (Stormwind), Geofram Bouldertoe (Ironforge)" },
    Expert = { Horde = "Mining trainer in a Horde capital", Alliance = "Mining trainer in an Alliance capital" },
    Artisan = { Horde = "Mining trainer in a Horde capital", Alliance = "Mining trainer in an Alliance capital" },
  },
  seedPath = {},
  zones = {
    { from = 1,   to = 65,  zone = "Durotar / Mulgore / Elwynn Forest / Dun Morogh / Teldrassil", note = "Copper Vein" },
    { from = 65,  to = 125, zone = "Barrens / Westfall / Loch Modan / Darkshore", note = "Tin Vein, Silver Vein" },
    { from = 125, to = 175, zone = "Stonetalon Mountains / Arathi Highlands / Hillsbrad Foothills / Wetlands", note = "Iron Deposit, Gold Vein" },
    { from = 175, to = 250, zone = "Badlands / Searing Gorge / Stranglethorn Vale / Desolace", note = "Mithril Deposit, Truesilver Deposit" },
    { from = 250, to = 300, zone = "Un'Goro Crater / Burning Steppes / Winterspring / Eastern Plaguelands", note = "Thorium Vein, Rich Thorium Vein" },
  },
  notes = {
    "A Mining Pick is required and must be carried in the bags.",
    "Smelting at a forge is part of Mining and turns ore into bars for Blacksmithing and Engineering.",
    "Skill band to zone mapping follows Classic guides and is untested on Forever.",
  },
})
