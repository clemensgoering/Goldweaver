-- Goldweaver: profession comparison for "which profession should I add or switch to" (guide tab, second table).
-- Uses profile seed paths priced live; live recipe data of other characters refines it later (WP2.5).
local ADDON, ns = ...

local Compare = {}
ns.Compare = Compare

-- Returns rows { profile, costTo300, coverage, synergy } sorted by cost.
function Compare.Rows()
  local rows = {}
  local me = ns.Chars.Current()
  for _, profile in ipairs(ns.Professions:All()) do
    local cost, coverage = ns.Professions.SeedCost(profile, 1, 300, ns.Price.Copper)
    -- synergy: materials of the seed path we already own across characters
    local owned = 0
    for _, step in ipairs(profile.seedPath or {}) do
      for _, m in ipairs(step.mats or {}) do
        local have = ns.Inventory.Count(m.item, { bank = true, alts = true })
        local p = ns.Price.Copper(m.item)
        if have > 0 and p then owned = owned + math.min(have, m.qty) * p end
      end
    end
    local known = me and me.professions and me.professions[profile.skillLineID]
    rows[#rows + 1] = { profile = profile, costTo300 = cost, coverage = coverage, ownedValue = owned, known = known }
  end
  table.sort(rows, function(a, b) return (a.costTo300 - a.ownedValue) < (b.costTo300 - b.ownedValue) end)
  return rows
end

ns:RegisterModule("Compare", {})
