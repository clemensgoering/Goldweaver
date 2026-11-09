-- Goldweaver: craft profit ranking across all cached professions of this character (feeds the guide).
local ADDON, ns = ...

local CraftProfit = {}
ns.CraftProfit = CraftProfit

-- Best crafts of this character across professions: { recipe, margin, skillLine, professionName }
function CraftProfit.Top(limit)
  local rec = ns.Chars.Current()
  local out = {}
  if not (rec and rec.professions) then return out end
  for skillLine, p in pairs(rec.professions) do
    for _, entry in ipairs(ns.Planner.Profitable(skillLine, rec, limit)) do
      entry.skillLine = skillLine
      entry.professionName = p.name
      out[#out + 1] = entry
    end
  end
  table.sort(out, function(a, b) return a.margin > b.margin end)
  while #out > (limit or 5) do table.remove(out) end
  return out
end

ns:RegisterModule("CraftProfit", {})
