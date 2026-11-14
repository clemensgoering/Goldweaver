-- Goldweaver: Fishing profile (WoW: Forever). Secondary profession, gathering-like: no seed path; zones describe where to level
-- each skill band. Source: Classic community leveling guides; untested on Forever.
local ADDON, ns = ...

ns.Professions:Register({
  key = "fishing",
  name = "Fishing",
  skillLineID = ns.Professions.SKILL_LINES.fishing,
  category = "secondary",
  crateCategories = {},
  vendorReagents = {},
  tools = { "Fishing Pole" },
  trainers = {
    Journeyman = { Horde = "Lumak (Orgrimmar), Kah Mistrunner (Thunder Bluff), Armand Cromwell (Undercity)",
      Alliance = "Catherine Leland (Stormwind), Grimnur Stonebrand (Ironforge), Fylerian Nightwing (Darnassus)" },
    Expert = { Horde = "Book: Expert Fishing - The Bass and You", Alliance = "Book: Expert Fishing - The Bass and You" },
    Artisan = { Horde = "Nat Pagle quest (Dustwallow Marsh)", Alliance = "Nat Pagle quest (Dustwallow Marsh)" },
  },
  seedPath = {},
  zones = {
    { from = 1,   to = 75,  zone = "Starting-zone lakes and coast (Durotar, Elwynn Forest, Mulgore)", note = "Small fish and Oily Blackmouth" },
    { from = 75,  to = 150, zone = "Barrens / Westfall coast / Loch Modan", note = "A better pole and a lure speed this band up" },
    { from = 150, to = 225, zone = "Stranglethorn Vale / Hillsbrad Foothills / Arathi Highlands", note = "Deep water gives steadier skill-ups" },
    { from = 225, to = 300, zone = "Feralas / Dustwallow Marsh / Tanaris / Azshara", note = "Large lakes and open ocean give faster skill-ups" },
  },
  -- ways to make gold with this profession (Gold tab); English keys, translated at display
  earn = {
    { title = "Fish for cooks", detail = "Raw fish sells to players levelling Cooking; sell full stacks on the AH.", minSkill = 1, effort = "medium" },
  },
  notes = {
    "Fishing yields cooking ingredients and tradable fish; pair it with Cooking.",
    "Expert needs a book from a fishing vendor; Artisan needs the Nat Pagle quest line.",
    "Lures and better poles raise the catch chance; bands and zones are untested on Forever.",
  },
})
