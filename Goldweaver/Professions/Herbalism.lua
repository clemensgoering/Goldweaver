-- Goldweaver: Herbalism profile (WoW: Forever). Gathering profession: no recipes, so no seed path; zones describe where to level
-- each skill band. Source: Classic community leveling guides; untested on Forever. Herb node data lives in Data/Gathering.lua.
local ADDON, ns = ...

ns.Professions:Register({
  key = "herbalism",
  name = "Herbalism",
  skillLineID = ns.Professions.SKILL_LINES.herbalism,
  category = "gathering",
  crateCategories = {},
  vendorReagents = {},
  trainers = {
    Journeyman = { Horde = "Jandi (Orgrimmar), Komin Winterhoof (Thunder Bluff)",
      Alliance = "Shylamiir (Stormwind), Telonis (Darnassus)" },
    Expert = { Horde = "Herbalism trainer in a Horde capital", Alliance = "Herbalism trainer in an Alliance capital" },
    Artisan = { Horde = "Herbalism trainer in a Horde capital", Alliance = "Herbalism trainer in an Alliance capital" },
  },
  seedPath = {},
  zones = {
    { from = 1,   to = 70,  zone = "Durotar / Mulgore / Elwynn Forest / Dun Morogh / Teldrassil", note = "Peacebloom, Silverleaf, Earthroot" },
    { from = 70,  to = 115, zone = "Barrens / Westfall / Loch Modan / Darkshore", note = "Mageroyal, Briarthorn, Earthroot" },
    { from = 115, to = 150, zone = "Stonetalon Mountains / Redridge Mountains / Ashenvale", note = "Bruiseweed, Briarthorn, Stranglekelp" },
    { from = 150, to = 205, zone = "Arathi Highlands / Hillsbrad Foothills / Stranglethorn Vale", note = "Wild Steelbloom, Kingsblood, Liferoot" },
    { from = 205, to = 250, zone = "Feralas / Dustwallow Marsh / Swamp of Sorrows / Hinterlands", note = "Fadeleaf, Khadgar's Whisker, Goldthorn, Sungrass" },
    { from = 250, to = 300, zone = "Un'Goro Crater / Felwood / Eastern Plaguelands / Winterspring", note = "Sungrass, Gromsblood, Plaguebloom, Icecap" },
  },
  notes = {
    "Gather while levelling or travelling; herbs sell well at the Auction House and feed Alchemy.",
    "Nodes respawn on a timer, so a loop through one zone beats single trips.",
    "Skill band to zone mapping follows Classic guides and is untested on Forever.",
  },
})
