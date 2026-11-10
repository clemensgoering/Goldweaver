-- Goldweaver: Skinning profile (WoW: Forever). Gathering profession: no seed path; zones describe where to level each skill band.
-- Source: Classic community leveling guides; untested on Forever. Skinning needs kills, so bands follow mob levels.
local ADDON, ns = ...

ns.Professions:Register({
  key = "skinning",
  name = "Skinning",
  skillLineID = ns.Professions.SKILL_LINES.skinning,
  category = "gathering",
  crateCategories = {},
  vendorReagents = {},
  tools = { "Skinning Knife" },
  trainers = {
    Journeyman = { Horde = "Thuwd (Orgrimmar), Kary Thunderhorn (Thunder Bluff)",
      Alliance = "Skinning trainer in Stormwind, Ironforge or Darnassus" },
    Expert = { Horde = "Skinning trainer in a Horde capital", Alliance = "Skinning trainer in an Alliance capital" },
    Artisan = { Horde = "Skinning trainer in a Horde capital", Alliance = "Skinning trainer in an Alliance capital" },
  },
  seedPath = {},
  zones = {
    { from = 1,   to = 75,  zone = "Durotar / Mulgore / Elwynn Forest / Dun Morogh / Teldrassil", note = "Boars, wolves, raptors, bears" },
    { from = 75,  to = 150, zone = "Barrens / Westfall / Redridge Mountains / Darkshore", note = "Zhevra, lions, crocolisks, raptors" },
    { from = 150, to = 225, zone = "Stranglethorn Vale / Arathi Highlands / Hillsbrad Foothills / Desolace", note = "Panthers, tigers, raptors, scorpids" },
    { from = 225, to = 300, zone = "Tanaris / Un'Goro Crater / Felwood / Winterspring", note = "Devilsaurs, cats, bears, scorpids" },
  },
  notes = {
    "A Skinning Knife is required; skin only beasts that match your level for the best chance of skill points.",
    "Leather feeds Leatherworking and sells steadily; keep a few stacks for twinks.",
    "Skill band to zone mapping follows Classic guides and is untested on Forever.",
  },
})
