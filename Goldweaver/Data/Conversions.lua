-- Goldweaver: static conversions that are not read from a profession window (smelting, cloth to bolt as seed values).
-- Source "profile": live recipes from the window replace these when the player opens the profession (same id).
local ADDON, ns = ...

local Data = ns.Data
local I = Data.Item

-- ore / bars
I(2770, "Copper Ore");   I(2840, "Copper Bar")
I(2771, "Tin Ore");      I(3576, "Tin Bar");       I(2841, "Bronze Bar")
I(2775, "Silver Ore");   I(2842, "Silver Bar")
I(2772, "Iron Ore");     I(3575, "Iron Bar");      I(3859, "Steel Bar")
I(2776, "Gold Ore");     I(3577, "Gold Bar")
I(3858, "Mithril Ore");  I(3860, "Mithril Bar")
I(7911, "Truesilver Ore"); I(6037, "Truesilver Bar")
I(10620, "Thorium Ore"); I(12359, "Thorium Bar")
-- cloth / bolts (cloth IDs registered in Crates.lua)
I(14047, "Runecloth");   I(14048, "Bolt of Runecloth")
-- leather
I(2934, "Ruined Leather Scraps"); I(2318, "Light Leather"); I(2319, "Medium Leather")
I(4234, "Heavy Leather"); I(4304, "Thick Leather"); I(8170, "Rugged Leather")

Data.Conversions = {
  -- Mining: smelting (skill = Classic smelting skill, kept on Forever per guides)
  { id = "smelt:2840", kind = "smelt", profession = "mining", skill = 1,   inputs = { { item = 2770, qty = 1 } }, outputs = { { item = 2840, qty = 1 } }, name = "Smelt Copper" },
  { id = "smelt:3576", kind = "smelt", profession = "mining", skill = 65,  inputs = { { item = 2771, qty = 1 } }, outputs = { { item = 3576, qty = 1 } }, name = "Smelt Tin" },
  { id = "smelt:2841", kind = "smelt", profession = "mining", skill = 65,  inputs = { { item = 2840, qty = 1 }, { item = 3576, qty = 1 } }, outputs = { { item = 2841, qty = 2 } }, name = "Smelt Bronze" },
  { id = "smelt:2842", kind = "smelt", profession = "mining", skill = 75,  inputs = { { item = 2775, qty = 1 } }, outputs = { { item = 2842, qty = 1 } }, name = "Smelt Silver" },
  { id = "smelt:3575", kind = "smelt", profession = "mining", skill = 125, inputs = { { item = 2772, qty = 1 } }, outputs = { { item = 3575, qty = 1 } }, name = "Smelt Iron" },
  { id = "smelt:3577", kind = "smelt", profession = "mining", skill = 155, inputs = { { item = 2776, qty = 1 } }, outputs = { { item = 3577, qty = 1 } }, name = "Smelt Gold" },
  { id = "smelt:3859", kind = "smelt", profession = "mining", skill = 165, inputs = { { item = 3575, qty = 1 }, { item = 3857, qty = 1 } }, outputs = { { item = 3859, qty = 1 } }, name = "Smelt Steel" },
  { id = "smelt:3860", kind = "smelt", profession = "mining", skill = 175, inputs = { { item = 3858, qty = 1 } }, outputs = { { item = 3860, qty = 1 } }, name = "Smelt Mithril" },
  { id = "smelt:6037", kind = "smelt", profession = "mining", skill = 230, inputs = { { item = 7911, qty = 1 } }, outputs = { { item = 6037, qty = 1 } }, name = "Smelt Truesilver" },
  { id = "smelt:12359", kind = "smelt", profession = "mining", skill = 250, inputs = { { item = 10620, qty = 1 } }, outputs = { { item = 12359, qty = 1 } }, name = "Smelt Thorium" },
  -- Tailoring: bolts (seed values until the window is read)
  { id = "craft:2996", kind = "craft", profession = "tailoring", skill = 1,   inputs = { { item = 2589, qty = 2 } }, outputs = { { item = 2996, qty = 1 } }, name = "Bolt of Linen Cloth" },
  { id = "craft:2997", kind = "craft", profession = "tailoring", skill = 75,  inputs = { { item = 2592, qty = 3 } }, outputs = { { item = 2997, qty = 1 } }, name = "Bolt of Woolen Cloth" },
  { id = "craft:4305", kind = "craft", profession = "tailoring", skill = 125, inputs = { { item = 4306, qty = 4 } }, outputs = { { item = 4305, qty = 1 } }, name = "Bolt of Silk Cloth" },
  { id = "craft:4339", kind = "craft", profession = "tailoring", skill = 175, inputs = { { item = 4338, qty = 5 } }, outputs = { { item = 4339, qty = 1 } }, name = "Bolt of Mageweave" },
  { id = "craft:14048", kind = "craft", profession = "tailoring", skill = 250, inputs = { { item = 14047, qty = 5 } }, outputs = { { item = 14048, qty = 1 } }, name = "Bolt of Runecloth" },
}

function Data.LoadConversions()
  local n = 0
  for _, conv in ipairs(Data.Conversions) do
    conv.source = conv.source or "profile"
    ns.Graph.Add(conv)
    n = n + 1
  end
  return n
end

ns:RegisterModule("Data", { Init = function() Data.LoadConversions() end })
