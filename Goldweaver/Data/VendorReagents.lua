-- Goldweaver: reagents that merchants always sell, with their vendor buy price in copper.
-- These prices cap the price engine (nobody pays more on the AH than the vendor asks). Classic prices; verify at a vendor.
local ADDON, ns = ...

local Data = ns.Data
local I = Data.Item

Data.VendorReagents = {
  -- tailoring
  [I(2320, "Coarse Thread")]        = { buy = 10 },
  [I(2321, "Fine Thread")]          = { buy = 100 },
  [I(4291, "Silken Thread")]        = { buy = 500 },
  [I(8343, "Heavy Silken Thread")]  = { buy = 2000 },
  [I(14341, "Rune Thread")]         = { buy = 5000 },
  [I(2324, "Bleach")]               = { buy = 25 },
  [I(2604, "Red Dye")]              = { buy = 50 },
  [I(6260, "Blue Dye")]             = { buy = 50 },
  [I(4340, "Gray Dye")]             = { buy = 100 },
  [I(2605, "Green Dye")]            = { buy = 100 },
  [I(4341, "Yellow Dye")]           = { buy = 500 },
  [I(4342, "Purple Dye")]           = { buy = 2500 },
  [I(10290, "Pink Dye")]            = { buy = 2500 },
  [I(14256, "Felcloth")]            = nil, -- drop, listed so the name registry knows it
  -- enchanting rods (blacksmith-made rods are not vendor items; only the base rod)
  [I(6217, "Copper Rod")]           = { buy = 124 },
  -- alchemy / enchanting vials
  [I(3371, "Empty Vial")]           = { buy = 20 },
  [I(3372, "Leaded Vial")]          = { buy = 200 },
  [I(8925, "Crystal Vial")]         = { buy = 2000 },
  -- blacksmithing / engineering
  [I(2880, "Weak Flux")]            = { buy = 100 },
  [I(3466, "Strong Flux")]          = { buy = 2000 },
  [I(3857, "Coal")]                 = { buy = 500 },
  [I(4289, "Salt")]                 = { buy = 50 },
  -- cooking
  [I(2678, "Mild Spices")]          = { buy = 10 },
  [I(2692, "Hot Spices")]           = { buy = 40 },
  [I(3713, "Soothing Spices")]      = { buy = 200 },
}
Data.VendorReagents.verified = false
