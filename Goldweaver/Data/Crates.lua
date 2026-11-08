-- Goldweaver: Waylaid Crate bundles and Merchant's Favor rates for WoW: Forever.
-- One crate takes exactly ONE bundle. Favor per crate is contested between guides (5/10/15 vs 10/10/20/35); values here are
-- defaults marked unverified and can be overridden in GoldweaverDB.settings.favorPerCrate[tier].
local ADDON, ns = ...

local Data = ns.Data
local I = Data.Item

Data.Crates = {
  verified = false,
  favorPerCrate = { apprentice = 10, journeyman = 10, expert = 20, artisan = 35 },
  -- category -> tier -> list of alternative bundles { item, qty }
  bundles = {
    curiosities = {
      apprentice = { { item = 10940, qty = 20 }, { item = 10939, qty = 4 }, { item = 10978, qty = 6 }, { item = 11084, qty = 2 } },
      journeyman = { { item = 11083, qty = 20 }, { item = 11082, qty = 4 }, { item = 11138, qty = 6 }, { item = 11139, qty = 2 } },
      expert     = { { item = 11137, qty = 20 }, { item = 11135, qty = 4 }, { item = 11177, qty = 6 }, { item = 11178, qty = 2 } },
      artisan    = { { item = 11176, qty = 20 }, { item = 11175, qty = 4 }, { item = 14343, qty = 6 }, { item = 14344, qty = 2 } },
    },
    -- Other categories (textiles, ore/bars, leather, herbs, food) exist in game; bundle sizes are not confirmed yet.
    -- Add them here once seen in a crate tooltip: category = { tier = { { item = ..., qty = ... } } }.
    textiles = {
      apprentice = { { item = I(2589, "Linen Cloth"), qty = 20 }, { item = I(2996, "Bolt of Linen Cloth"), qty = 10 } },
      journeyman = { { item = I(2592, "Wool Cloth"), qty = 20 }, { item = I(2997, "Bolt of Woolen Cloth"), qty = 10 } },
      expert     = { { item = I(4306, "Silk Cloth"), qty = 20 }, { item = I(4305, "Bolt of Silk Cloth"), qty = 10 } },
      artisan    = { { item = I(4338, "Mageweave Cloth"), qty = 20 }, { item = I(4339, "Bolt of Mageweave"), qty = 10 } },
    },
  },
}
Data.Crates.bundles.textiles.unverified = true

-- Index: itemID -> { category, tier, qty }
local index
local function buildIndex()
  index = {}
  for category, tiers in pairs(Data.Crates.bundles) do
    for tier, list in pairs(tiers) do
      if type(list) == "table" then
        for _, b in ipairs(list) do
          index[b.item] = { category = category, tier = tier, qty = b.qty }
        end
      end
    end
  end
end

function Data.Crates.FavorRate(tier)
  local override = ns.db and ns.db.settings and ns.db.settings.favorPerCrate
  return (override and override[tier]) or Data.Crates.favorPerCrate[tier] or 0
end

-- For an item: { category, tier, bundleQty, favor } or nil if no crate takes it.
function Data.Crates.For(itemID)
  if not index then buildIndex() end
  local e = index[itemID]
  if not e then return nil end
  return { category = e.category, tier = e.tier, bundleQty = e.qty, favor = Data.Crates.FavorRate(e.tier) }
end

-- Gold-equivalent value of putting `qty` of an item into crates, given favorValueCopper per Favor.
-- Only whole bundles count unless allowPartial is true (then the value is proportional).
function Data.Crates.Value(itemID, qty, favorValueCopper, allowPartial)
  local e = Data.Crates.For(itemID)
  if not e or not favorValueCopper or favorValueCopper <= 0 then return nil end
  local bundles = allowPartial and (qty / e.bundleQty) or math.floor(qty / e.bundleQty)
  if bundles <= 0 then return 0, e end
  return math.floor(bundles * e.favor * favorValueCopper), e
end
